param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$encoding = New-Object Text.UTF8Encoding($false)
foreach ($item in @(@('candidate.bin', 'new'), @('destination.bin', 'old'), @('protected.bin', 'protected'))) {
    [IO.File]::WriteAllText((Join-Path $directory $item[0]), $item[1], $encoding)
}
$destination = Join-Path $directory 'destination.bin'
$protected = Join-Path $directory 'protected.bin'
$link = Join-Path $directory 'link.bin'
New-Item -ItemType SymbolicLink -Path $link -Target $protected | Out-Null
if ([IO.File]::ReadAllText($link) -ne 'protected') { throw 'Symbolic link control failed' }
$id = [guid]::NewGuid().ToString('N')
$readyName = 'Local\UBE-symlink-ready-' + $id
$releaseName = 'Local\UBE-symlink-release-' + $id
$ready = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $readyName)
$release = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $releaseName)
$process = [Diagnostics.Process]::new()
try {
    $process.StartInfo.FileName = $probePath
    $process.StartInfo.Arguments = '"' + $directory + '" native-relative ' + $readyName + ' ' + $releaseName
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    if (-not $process.Start()) { throw 'Probe did not start' }
    if (-not $ready.WaitOne(10000)) { throw 'Readiness was not observed' }
    [IO.File]::Move($destination, (Join-Path $directory 'prior.bin'))
    [IO.File]::Move($link, $destination)
    if ([IO.File]::ReadAllText($destination) -ne 'protected') { throw 'Symbolic link control failed' }
    $release.Set() | Out-Null
    if (-not $process.WaitForExit(10000) -or $process.ExitCode -ne 0) { throw 'Rename did not complete successfully' }
    if ([IO.File]::ReadAllText($destination) -ne 'new' -or [IO.File]::ReadAllText($protected) -ne 'protected' -or
        [IO.File]::ReadAllText((Join-Path $directory 'prior.bin')) -ne 'old') { throw 'Unexpected resulting bytes' }
    Write-Output "Symbolic link entry was replaced; protected target stayed intact: $directory"
} finally {
    $release.Set() | Out-Null
    if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() }
    $process.Dispose(); $ready.Dispose(); $release.Dispose()
}
