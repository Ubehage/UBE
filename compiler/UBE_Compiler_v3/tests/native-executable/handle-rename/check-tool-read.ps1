param([Parameter(Mandatory=$true)][string] $Guard, [Parameter(Mandatory=$true)][string] $Objdump,
      [Parameter(Mandatory=$true)][string] $Executable, [Parameter(Mandatory=$true)][string] $OutputDirectory, [switch] $ReadOnly)
$ErrorActionPreference = 'Stop'
$guardPath = (Resolve-Path -LiteralPath $Guard).Path
$toolPath = (Resolve-Path -LiteralPath $Objdump).Path
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$candidate = Join-Path $directory 'candidate.exe'
[IO.File]::Copy((Resolve-Path -LiteralPath $Executable).Path, $candidate)
$beforeHash = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash
function Start-Tool([string] $path) {
    $process = [Diagnostics.Process]::new()
    $process.StartInfo.FileName = $toolPath; $process.StartInfo.Arguments = '-f "' + $path + '"'
    $process.StartInfo.UseShellExecute = $false; $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardOutput = $true; $process.StartInfo.RedirectStandardError = $true
    if (-not $process.Start()) { throw 'Tool did not start' }
    $stdout = $process.StandardOutput.ReadToEnd(); $stderr = $process.StandardError.ReadToEnd()
    if (-not $process.WaitForExit(5000)) { $process.Kill(); throw 'Tool timed out' }
    $result = @{ status = $process.ExitCode; stdout = $stdout; stderr = $stderr }
    $process.Dispose(); return $result
}
$before = Start-Tool $candidate
if ($before.status -ne 0 -or $before.stdout -notmatch 'file format') { throw 'Unguarded tool control failed' }
$id = [guid]::NewGuid().ToString('N')
$readyName = 'Local\UBE-tool-ready-' + $id; $releaseName = 'Local\UBE-tool-release-' + $id
$ready = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $readyName)
$release = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $releaseName)
$guardProcess = [Diagnostics.Process]::new()
try {
    $guardProcess.StartInfo.FileName = $guardPath
    $guardProcess.StartInfo.Arguments = '"' + $candidate + '" ' + $readyName + ' ' + $releaseName + $(if ($ReadOnly) { ' readonly' } else { '' })
    $guardProcess.StartInfo.UseShellExecute = $false; $guardProcess.StartInfo.CreateNoWindow = $true
    if (-not $guardProcess.Start() -or -not $ready.WaitOne(5000)) { throw 'Guard was not ready' }
    $during = Start-Tool $candidate
    $release.Set() | Out-Null
    if (-not $guardProcess.WaitForExit(5000) -or $guardProcess.ExitCode -ne 0) { throw 'Guard did not finish' }
    $after = Start-Tool $candidate
    if ($after.status -ne 0 -or $after.stdout -notmatch 'file format') { throw 'Post-guard control failed' }
    if ((Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash -ne $beforeHash) { throw 'Candidate bytes changed' }
    if ($during.status -eq 0 -and $during.stdout -match 'file format') { Write-Output 'Objdump read candidate while guard held.' }
    else { Write-Output "Objdump could not read candidate while guard held: status $($during.status); $($during.stderr.Trim())" }
} finally {
    $release.Set() | Out-Null
    if (-not $guardProcess.WaitForExit(10000)) { $guardProcess.Kill(); $guardProcess.WaitForExit() }
    $guardProcess.Dispose(); $ready.Dispose(); $release.Dispose()
}
