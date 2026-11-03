param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $OutputDirectory, [string] $Guard, [switch] $HandleRename, [switch] $Inspect, [switch] $MoveAncestor,
      [string] $Executable, [string] $Wrapper, [string] $Inspector, [string] $AncestorGuard, [switch] $ReadOnlyAncestor, [switch] $RequireBlocked, [switch] $OrdinaryChild, [string] $StructuralProbe, [switch] $GuardOutputParent, [string] $ReparseActor)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$root = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
$other = Join-Path $root 'other'; $parent = Join-Path $root 'parent'
$hasParent = $MoveAncestor -or [bool]$AncestorGuard
$active = if ($hasParent) { Join-Path $parent 'active' } else { Join-Path $root 'active' }
$original = if ($OrdinaryChild) { $active } else { Join-Path $root 'original' }
if ($OrdinaryChild -and (-not $MoveAncestor -or -not $AncestorGuard -or -not $RequireBlocked -or $Guard)) { throw 'OrdinaryChild requires MoveAncestor, AncestorGuard and RequireBlocked, without junction Guard' }
$moveSource = if ($MoveAncestor) { $parent } else { $active }; $prior = Join-Path $root 'prior-entry'
[IO.Directory]::CreateDirectory($original) | Out-Null; [IO.Directory]::CreateDirectory($other) | Out-Null
if ($hasParent) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
if ($Executable) {
    if (-not $Inspect -or -not $HandleRename -or -not $Wrapper -or -not $Inspector) { throw 'Executable mode requires Inspect, HandleRename, Wrapper and Inspector' }
    [IO.File]::Copy((Resolve-Path -LiteralPath $Executable).Path,(Join-Path $original 'candidate.bin'))
    $fixtureHash=(Get-FileHash -LiteralPath $Executable -Algorithm SHA256).Hash
} else { [IO.File]::WriteAllText((Join-Path $original 'candidate.bin'),'candidate'); $fixtureHash='' }
if ($StructuralProbe -and -not $Executable) { throw 'StructuralProbe requires Executable mode' }
if ($GuardOutputParent -and (-not $StructuralProbe -or $OrdinaryChild)) { throw 'GuardOutputParent requires StructuralProbe and a separate output directory' }
[IO.File]::WriteAllText((Join-Path $original 'destination.bin'),'old')
[IO.File]::WriteAllText((Join-Path $original 'protected.bin'),'protected')
[IO.File]::WriteAllText((Join-Path $other 'candidate.bin'),'substitute')
New-Item -ItemType HardLink -Path (Join-Path $other 'destination.bin') -Target (Join-Path $original 'protected.bin') | Out-Null
if (-not $OrdinaryChild) { New-Item -ItemType Junction -Path $active -Target $original | Out-Null }
[IO.Directory]::Move($moveSource,$prior); [IO.Directory]::Move($prior,$moveSource)
$movedOriginal=Join-Path $root 'original-moved'
if ($GuardOutputParent) { [IO.Directory]::Move($original,$movedOriginal); [IO.Directory]::Move($movedOriginal,$original) }
$id=[guid]::NewGuid().ToString('N')
$eventNames=@('ready','release','closed-ready','closed-release')
if ($Inspect) { $eventNames+=@('inspect-ready','inspect-release') }
$names=@($eventNames | ForEach-Object { 'Local\UBE-tx-junction-' + $_ + '-' + $id })
$events=@($names | ForEach-Object { [Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$_) })
$process=[Diagnostics.Process]::new()
$guardProcess=$null
$guardReadyName='Local\UBE-tx-junction-guard-ready-' + $id; $guardReleaseName='Local\UBE-tx-junction-guard-release-' + $id
$guardReady=[Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$guardReadyName)
$guardRelease=[Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$guardReleaseName)
$ancestorProcess=$null
$ancestorReadyName='Local\UBE-tx-ancestor-ready-' + $id; $ancestorReleaseName='Local\UBE-tx-ancestor-release-' + $id
$ancestorReady=[Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$ancestorReadyName)
$ancestorRelease=[Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$ancestorReleaseName)
try {
    if ($AncestorGuard) {
        $ancestorProcess=[Diagnostics.Process]::new()
        $ancestorProcess.StartInfo.FileName=(Resolve-Path -LiteralPath $AncestorGuard).Path
        $ancestorProcess.StartInfo.Arguments='"' + $parent + '" ' + $ancestorReadyName + ' ' + $ancestorReleaseName
        if ($ReadOnlyAncestor) { $ancestorProcess.StartInfo.Arguments+=' read-only' }
        $ancestorProcess.StartInfo.UseShellExecute=$false; $ancestorProcess.StartInfo.CreateNoWindow=$true
        if (-not $ancestorProcess.Start() -or -not $ancestorReady.WaitOne(5000)) { throw 'Ancestor guard was not established' }
    }
    if ($Guard) {
        $guardProcess=[Diagnostics.Process]::new()
        $guardProcess.StartInfo.FileName=(Resolve-Path -LiteralPath $Guard).Path
        $guardProcess.StartInfo.Arguments='"' + $active + '" ' + $guardReadyName + ' ' + $guardReleaseName
        $guardProcess.StartInfo.UseShellExecute=$false; $guardProcess.StartInfo.CreateNoWindow=$true
        if (-not $guardProcess.Start() -or -not $guardReady.WaitOne(5000)) { throw 'Junction guard was not established' }
    }
    $process.StartInfo.FileName=$probePath
    $process.StartInfo.Arguments='"' + $active + '" ' + ($names -join ' ')
    if ($Executable) { $process.StartInfo.Arguments+=' "' + (Resolve-Path -LiteralPath $Wrapper).Path + '" "' + (Resolve-Path -LiteralPath $Inspector).Path + '"' }
    if ($StructuralProbe) { $process.StartInfo.Arguments+=' "' + (Resolve-Path -LiteralPath $StructuralProbe).Path + '"' }
    if ($GuardOutputParent) { $process.StartInfo.Arguments+=' parent-sharewrite' }
    $process.StartInfo.UseShellExecute=$false; $process.StartInfo.CreateNoWindow=$true
    $process.StartInfo.RedirectStandardOutput=$true; $process.StartInfo.RedirectStandardError=$true
    if (-not $process.Start()) { throw 'Transaction probe did not start' }
    if ($Inspect) {
        if (-not $events[4].WaitOne(5000)) { throw 'Candidate inspection barrier was not reached' }
        $events[5].Set() | Out-Null
    }
    if (-not $events[0].WaitOne(5000)) { throw 'Transaction guard was not established' }
    $events[1].Set() | Out-Null
    if (-not $events[2].WaitOne(5000)) { throw 'Closed-handle barrier was not reached' }
    if ($GuardOutputParent) {
        $outputParentMoved=$false
        try { [IO.Directory]::Move($original,$movedOriginal); $outputParentMoved=$true } catch [IO.IOException] { }
        if ($outputParentMoved) { throw 'Output parent move was not blocked' }
        Write-Output 'Output parent move blocked while the transaction held its guard.'
        foreach ($name in @('candidate.bin','destination.bin')) {
            $file=Join-Path $original $name; $movedFile=Join-Path $root ('moved-' + $name); $fileMoved=$false
            try { [IO.File]::Move($file,$movedFile); $fileMoved=$true } catch [IO.IOException] { }
            if ($fileMoved) { throw "Guarded $name was moved" }
        }
        if ($ReparseActor) {
            $reparseOutput=(@(& (Resolve-Path -LiteralPath $ReparseActor).Path $original $other 2>&1) -join ' ').Trim()
            if ($LASTEXITCODE -ne 4 -or $reparseOutput -ne 'set error=145') { throw "Unexpected output-parent reparse result: $reparseOutput" }
            Write-Output 'Candidate and destination moves blocked; output-parent reparse operation returned error 145.'
        }
    }
    if ($Guard) {
        $clearOutput = @(& (Resolve-Path -LiteralPath $Guard).Path clear $active 2>&1)
        if ($LASTEXITCODE -ne 5 -or ($clearOutput -join ' ') -notmatch 'open failed: 32') { throw "Guard did not block clearing the junction: $clearOutput" }
        Write-Output 'Guard blocked junction reparse-point clearing (sharing violation 32).'
    }
    $swapped=$false; $actorError=''
    try { [IO.Directory]::Move($moveSource,$prior); $swapped=$true } catch [IO.IOException] { $actorError=$_.Exception.Message }
    if ($swapped) {
        if ($MoveAncestor) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
        New-Item -ItemType Junction -Path $active -Target $other | Out-Null
        if ([IO.File]::ReadAllText((Join-Path $active 'destination.bin')) -ne 'protected') { throw 'Junction did not resolve to protected alias' }
    }
    if ($RequireBlocked -and $swapped) { throw 'Selected component move was not blocked' }
    $events[3].Set() | Out-Null
    if (-not $process.WaitForExit(10000)) { throw 'Transaction probe timed out' }
    $stdout=$process.StandardOutput.ReadToEnd().Trim(); $stderr=$process.StandardError.ReadToEnd().Trim()
    if ($Inspect -and $stdout -notmatch 'inspected candidate identity matched') { throw 'Inspection identity match was not observed' }
    if ($Executable -and $stdout -notmatch 'external inspection succeeded') { throw 'External executable inspection was not observed' }
    if ($StructuralProbe -and $stdout -notmatch 'structural inspection succeeded') { throw 'Structural inspection was not observed' }
    $originalPath=Join-Path $original 'destination.bin'
    $originalDest=if ($Executable -and (Get-FileHash -LiteralPath $originalPath -Algorithm SHA256).Hash -eq $fixtureHash) { 'candidate' } else { [IO.File]::ReadAllText($originalPath) }
    $otherDest=[IO.File]::ReadAllText((Join-Path $other 'destination.bin'))
    $protected=[IO.File]::ReadAllText((Join-Path $original 'protected.bin'))
    if ($protected -ne 'protected') { throw 'Protected peer bytes changed' }
    if ($swapped -and -not $HandleRename -and $process.ExitCode -eq 0 -and ($originalDest -ne 'old' -or $otherDest -ne 'substitute' -or
        [IO.File]::ReadAllText((Join-Path $original 'candidate.bin')) -ne 'candidate' -or [IO.File]::Exists((Join-Path $other 'candidate.bin')))) { throw 'Unexpected successful redirected commit' }
    if ($swapped -and $HandleRename -and $process.ExitCode -eq 0 -and ($originalDest -ne 'candidate' -or $otherDest -ne 'protected' -or
        [IO.File]::Exists((Join-Path $original 'candidate.bin')) -or [IO.File]::ReadAllText((Join-Path $other 'candidate.bin')) -ne 'substitute')) { throw 'Unexpected handle-anchored commit' }
    if ($swapped -and $process.ExitCode -ne 0 -and ($originalDest -ne 'old' -or $otherDest -ne 'protected')) { throw 'Failed transaction changed a destination' }
    if (-not $swapped -and $process.ExitCode -eq 0 -and ($originalDest -ne 'candidate' -or $otherDest -ne 'protected' -or [IO.File]::Exists((Join-Path $original 'candidate.bin')))) { throw 'Unexpected guarded commit' }
    if (-not $swapped -and $process.ExitCode -ne 0 -and ($originalDest -ne 'old' -or $otherDest -ne 'protected' -or [IO.File]::ReadAllText((Join-Path $original 'candidate.bin')) -ne 'candidate')) { throw 'Failed guarded transaction changed files' }
    if ($RequireBlocked -and $process.ExitCode -ne 0) { throw "Transaction did not commit: $stderr" }
    Write-Output "swapped=$swapped actor-error=$actorError status=$($process.ExitCode) original=$originalDest other=$otherDest protected=$protected stdout=$stdout stderr=$stderr"
    if ($GuardOutputParent) {
        [IO.Directory]::Move($original,$movedOriginal); [IO.Directory]::Move($movedOriginal,$original)
        Write-Output 'Output parent moved and restored after transaction exit.'
    }
    if (($Guard -or $AncestorGuard) -and -not $swapped) {
        $guardRelease.Set() | Out-Null
        $ancestorRelease.Set() | Out-Null
        if ($guardProcess -and (-not $guardProcess.WaitForExit(5000) -or $guardProcess.ExitCode -ne 0)) { throw 'Guard did not close cleanly' }
        if ($ancestorProcess -and (-not $ancestorProcess.WaitForExit(5000) -or $ancestorProcess.ExitCode -ne 0)) { throw 'Ancestor guard did not close cleanly' }
        [IO.Directory]::Move($moveSource,$prior)
        Write-Output 'Selected path-component move succeeded after guard release.'
    }
    Write-Output "Test-owned artifacts: $root"
} finally {
    $events[1].Set() | Out-Null; $events[3].Set() | Out-Null
    if ($Inspect) { $events[5].Set() | Out-Null }
    $guardRelease.Set() | Out-Null
    $ancestorRelease.Set() | Out-Null
    if (-not $process.HasExited -and -not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() }
    $process.Dispose(); foreach ($event in $events) { $event.Dispose() }
    if ($guardProcess) { if (-not $guardProcess.HasExited -and -not $guardProcess.WaitForExit(10000)) { $guardProcess.Kill(); $guardProcess.WaitForExit() }; $guardProcess.Dispose() }
    if ($ancestorProcess) { if (-not $ancestorProcess.HasExited -and -not $ancestorProcess.WaitForExit(10000)) { $ancestorProcess.Kill(); $ancestorProcess.WaitForExit() }; $ancestorProcess.Dispose() }
    $guardReady.Dispose(); $guardRelease.Dispose()
    $ancestorReady.Dispose(); $ancestorRelease.Dispose()
}
