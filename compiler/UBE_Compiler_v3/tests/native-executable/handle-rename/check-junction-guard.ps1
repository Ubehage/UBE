param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $Guard, [Parameter(Mandatory=$true)][string] $OutputDirectory, [switch] $MoveParent)
$ErrorActionPreference = 'Stop'
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$guardPath = (Resolve-Path -LiteralPath $Guard).Path
$root = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
$original = Join-Path $root 'original'
$parent = Join-Path $root 'parent'
$active = if ($MoveParent) { Join-Path $parent 'active' } else { Join-Path $root 'active' }
[IO.Directory]::CreateDirectory($original) | Out-Null
if ($MoveParent) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
$encoding = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $original 'candidate.bin'), 'new', $encoding)
[IO.File]::WriteAllText((Join-Path $original 'destination.bin'), 'old', $encoding)
New-Item -ItemType Junction -Path $active -Target $original | Out-Null
$id = [guid]::NewGuid().ToString('N')
$guardReadyName = 'Local\UBE-jguard-ready-' + $id
$guardReleaseName = 'Local\UBE-jguard-release-' + $id
$renameReadyName = 'Local\UBE-jrename-ready-' + $id
$renameReleaseName = 'Local\UBE-jrename-release-' + $id
$events = @($guardReadyName, $guardReleaseName, $renameReadyName, $renameReleaseName) | ForEach-Object {
    [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $_)
}
$guardProcess = [Diagnostics.Process]::new()
$renameProcess = [Diagnostics.Process]::new()
$started = @()
try {
    $guardProcess.StartInfo.FileName = $guardPath
    $guardProcess.StartInfo.Arguments = '"' + $active + '" ' + $guardReadyName + ' ' + $guardReleaseName
    $guardProcess.StartInfo.UseShellExecute = $false
    $guardProcess.StartInfo.CreateNoWindow = $true
    if (-not $guardProcess.Start()) { throw 'Guard did not start' }
    $started += $guardProcess
    if (-not $events[0].WaitOne(5000)) { throw 'Guard was not ready' }
    $renameProcess.StartInfo.FileName = $probePath
    $renameProcess.StartInfo.Arguments = '"' + $active + '" native-relative ' + $renameReadyName + ' ' + $renameReleaseName
    $renameProcess.StartInfo.UseShellExecute = $false
    $renameProcess.StartInfo.CreateNoWindow = $true
    if (-not $renameProcess.Start()) { throw 'Rename did not start' }
    $started += $renameProcess
    if (-not $events[2].WaitOne(5000)) { throw 'Rename was not ready' }
    $moveSource = if ($MoveParent) { $parent } else { $active }
    $moveOutput = @(& $guardPath move $moveSource (Join-Path $root 'moved') 2>&1)
    $moveStatus = $LASTEXITCODE
    if ($moveStatus -ne 0 -and $moveStatus -ne 5) { throw "Unexpected move result $moveStatus : $moveOutput" }
    $blocked = $moveStatus -eq 5
    $events[3].Set() | Out-Null
    if (-not $renameProcess.WaitForExit(5000) -or $renameProcess.ExitCode -ne 0) { throw 'Guarded rename failed' }
    if ([IO.File]::ReadAllText((Join-Path $original 'destination.bin')) -ne 'new') { throw 'Original directory was not updated' }
    if ($blocked) {
        if ([IO.File]::ReadAllText((Join-Path $active 'destination.bin')) -ne 'new') { throw 'Guarded output was not visible' }
        $events[1].Set() | Out-Null
        if (-not $guardProcess.WaitForExit(5000) -or $guardProcess.ExitCode -ne 0) { throw 'Guard did not close cleanly' }
        $afterOutput = @(& $guardPath move $moveSource (Join-Path $root 'moved') 2>&1)
        if ($LASTEXITCODE -ne 0) { throw "Move after guard release failed: $afterOutput" }
        Write-Output "Guard blocked selected move ($($moveOutput -join ' ')); replacement and post-release move succeeded: $root"
    } else {
        if ([IO.Directory]::Exists($active) -or -not [IO.Directory]::Exists((Join-Path $root 'moved'))) { throw 'Moved junction not observed' }
        Write-Output "Guard did not block selected move; replacement updated original directory: $root"
    }
} finally {
    $events[3].Set() | Out-Null
    $events[1].Set() | Out-Null
    foreach ($process in $started) { if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() } }
    $guardProcess.Dispose(); $renameProcess.Dispose()
    foreach ($event in $events) { $event.Dispose() }
}
