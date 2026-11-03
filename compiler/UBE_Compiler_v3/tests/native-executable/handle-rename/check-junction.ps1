param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$root = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
$original = Join-Path $root 'original'
$other = Join-Path $root 'other'
$active = Join-Path $root 'active'
[IO.Directory]::CreateDirectory($original) | Out-Null
[IO.Directory]::CreateDirectory($other) | Out-Null
$encoding = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $original 'candidate.bin'), 'new', $encoding)
[IO.File]::WriteAllText((Join-Path $original 'destination.bin'), 'old', $encoding)
[IO.File]::WriteAllText((Join-Path $other 'destination.bin'), 'other', $encoding)
New-Item -ItemType Junction -Path $active -Target $original | Out-Null
if ([IO.File]::ReadAllText((Join-Path $active 'destination.bin')) -ne 'old') { throw 'Initial junction control failed' }
$id = [guid]::NewGuid().ToString('N')
$readyName = 'Local\UBE-junction-ready-' + $id
$releaseName = 'Local\UBE-junction-release-' + $id
$ready = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $readyName)
$release = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $releaseName)
$process = [Diagnostics.Process]::new()
try {
    $process.StartInfo.FileName = $probePath
    $process.StartInfo.Arguments = '"' + $active + '" native-relative ' + $readyName + ' ' + $releaseName
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    if (-not $process.Start()) { throw 'Probe did not start' }
    if (-not $ready.WaitOne(10000)) { throw 'Readiness was not observed' }
    [IO.Directory]::Move($active, (Join-Path $root 'moved-junction'))
    New-Item -ItemType Junction -Path $active -Target $other | Out-Null
    if ([IO.File]::ReadAllText((Join-Path $active 'destination.bin')) -ne 'other') { throw 'Swapped junction control failed' }
    $release.Set() | Out-Null
    if (-not $process.WaitForExit(10000) -or $process.ExitCode -ne 0) { throw 'Rename did not complete' }
    if ([IO.File]::ReadAllText((Join-Path $original 'destination.bin')) -ne 'new' -or
        [IO.File]::ReadAllText((Join-Path $other 'destination.bin')) -ne 'other') { throw 'Unexpected destination bytes' }
    Write-Output "Junction swap redirected the path; rename remained in original directory: $root"
} finally {
    $release.Set() | Out-Null
    if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() }
    $process.Dispose(); $ready.Dispose(); $release.Dispose()
}
