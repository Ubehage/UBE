param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $OutputDirectory,
      [ValidateSet('native-parentguard', 'native-parent-nodel', 'native-parent-nowrite', 'native-parent-posix')][string] $Mode = 'native-parentguard')
$ErrorActionPreference = 'Stop'
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
[IO.File]::WriteAllText((Join-Path $directory 'candidate.bin'), 'new')
[IO.File]::WriteAllText((Join-Path $directory 'destination.bin'), 'old')
$id = [guid]::NewGuid().ToString('N')
$readyName = 'Local\UBE-pguard-ready-' + $id
$releaseName = 'Local\UBE-pguard-release-' + $id
$ready = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $readyName)
$release = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $releaseName)
$process = [Diagnostics.Process]::new()
try {
    $process.StartInfo.FileName = $probePath
    $process.StartInfo.Arguments = '"' + $directory + '" ' + $Mode + ' ' + $readyName + ' ' + $releaseName
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardError = $true
    if (-not $process.Start() -or -not $ready.WaitOne(5000)) { throw 'Guarded rename was not ready' }
    $destination = Join-Path $directory 'destination.bin'
    $blocked = $false
    try { [IO.File]::Move($destination, (Join-Path $directory 'prior.bin')) } catch [IO.IOException] { $blocked = $true }
    if (-not $blocked) { [IO.File]::WriteAllText($destination, 'interloper') }
    $release.Set() | Out-Null
    if (-not $process.WaitForExit(5000)) { throw 'Rename did not exit' }
    $stderr = $process.StandardError.ReadToEnd()
    if ($process.ExitCode -ne 0) {
        if (-not $blocked -or $stderr -notmatch 'rename failed: 32' -or [IO.File]::ReadAllText($destination) -ne 'old' -or
            [IO.File]::ReadAllText((Join-Path $directory 'candidate.bin')) -ne 'new') { throw "Unexpected failed rename: $stderr" }
        [IO.File]::Move($destination, (Join-Path $directory 'after.bin'))
        Write-Output "Parent guard blocked both destination move and intended rename ($($stderr.Trim())); post-release move succeeded: $directory"
        return
    }
    if ([IO.File]::ReadAllText($destination) -ne 'new') { throw 'Unexpected destination bytes' }
    if ($blocked) {
        [IO.File]::Move($destination, (Join-Path $directory 'after.bin'))
        if ([IO.File]::ReadAllText((Join-Path $directory 'after.bin')) -ne 'new') { throw 'Post-release move failed' }
        Write-Output "Parent guard blocked destination move; intended rename and post-release move succeeded: $directory"
    } else {
        if ([IO.File]::ReadAllText((Join-Path $directory 'prior.bin')) -ne 'old') { throw 'Prior bytes changed' }
        Write-Output "Parent guard did not prevent destination swap: $directory"
    }
} finally {
    $release.Set() | Out-Null
    if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() }
    $process.Dispose(); $ready.Dispose(); $release.Dispose()
}
