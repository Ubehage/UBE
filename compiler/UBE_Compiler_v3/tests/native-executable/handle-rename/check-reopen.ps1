param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $OutputDirectory, [ValidateSet('native-reopen', 'native-reopen-posix')][string] $Mode = 'native-reopen')
$ErrorActionPreference = 'Stop'
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$candidate = Join-Path $directory 'candidate.bin'; $destination = Join-Path $directory 'destination.bin'
[IO.File]::WriteAllText($candidate, 'candidate'); [IO.File]::WriteAllText($destination, 'old')
$id = [guid]::NewGuid().ToString('N')
$readyName = 'Local\UBE-reopen-ready-' + $id; $releaseName = 'Local\UBE-reopen-release-' + $id
$ready = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $readyName)
$release = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $releaseName)
$process = [Diagnostics.Process]::new()
try {
    $process.StartInfo.FileName = $probePath
    $process.StartInfo.Arguments = '"' + $directory + '" ' + $Mode + ' ' + $readyName + ' ' + $releaseName
    $process.StartInfo.UseShellExecute = $false; $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardError = $true
    if (-not $process.Start() -or -not $ready.WaitOne(5000)) { throw 'Guard was not ready' }
    $moved = Join-Path $directory 'moved.bin'
    [IO.File]::Move($candidate, $moved)
    [IO.File]::WriteAllText($candidate, 'substitute')
    $blocked = $false
    try {
        $stream = [IO.File]::Open($moved, [IO.FileMode]::Open, [IO.FileAccess]::Write, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $stream.Dispose()
    } catch [IO.IOException] { $blocked = $true }
    if (-not $blocked) { throw 'Writer unexpectedly opened guarded object' }
    $release.Set() | Out-Null
    if (-not $process.WaitForExit(5000)) { throw 'Probe did not exit' }
    $stderr = $process.StandardError.ReadToEnd()
    if ($process.ExitCode -ne 0) { throw "Reopen or rename failed: $stderr" }
    if ([IO.File]::ReadAllText($destination) -ne 'candidate' -or [IO.File]::ReadAllText($candidate) -ne 'substitute' -or [IO.File]::Exists($moved)) {
        throw 'Wrong file was published'
    }
    Write-Output "Read-only guard preserved file identity through path substitution and reopened rename: $directory"
} finally {
    $release.Set() | Out-Null
    if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() }
    $process.Dispose(); $ready.Dispose(); $release.Dispose()
}
