param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $Wrapper,
      [Parameter(Mandatory=$true)][string] $Inspector, [Parameter(Mandatory=$true)][string] $Executable,
      [Parameter(Mandatory=$true)][string] $OutputDirectory, [switch] $RequireBlockedFailure, [switch] $Posix, [switch] $UnguardedPosix, [switch] $RequireCommit,
      [switch] $ShareWrite, [string] $ReparseActor, [switch] $RequireShareWriteCommit,
      [string] $Preopen, [switch] $RequirePreopenFailure)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$probePath=(Resolve-Path -LiteralPath $Probe).Path; $wrapperPath=(Resolve-Path -LiteralPath $Wrapper).Path
$inspectorPath=(Resolve-Path -LiteralPath $Inspector).Path; $fixture=(Resolve-Path -LiteralPath $Executable).Path
$directory=Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N')); [IO.Directory]::CreateDirectory($directory) | Out-Null
$candidate=Join-Path $directory 'candidate.bin'; $destination=Join-Path $directory 'destination.bin'; $moved=Join-Path $directory 'actor-moved.bin'
$redirect=Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N')); [IO.Directory]::CreateDirectory($redirect) | Out-Null
[IO.File]::Copy($fixture,$candidate); $fixtureHash=(Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash
[IO.File]::WriteAllText($destination,'old'); [IO.File]::WriteAllText((Join-Path $directory 'protected.bin'),'protected')
[IO.File]::Move($destination,$moved); [IO.File]::Move($moved,$destination)
if ($ShareWrite) { [IO.File]::Move($candidate,$moved); [IO.File]::Move($moved,$candidate) }
$id=[guid]::NewGuid().ToString('N'); $names=@('ready','release','closed-ready','closed-release','inspect-ready','inspect-release','staged-ready','staged-release') | ForEach-Object { 'Local\UBE-tx-parent-' + $_ + '-' + $id }
$events=@($names | ForEach-Object { [Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$_) })
$process=[Diagnostics.Process]::new(); $started=$false
$preopenProcess=$null; $preopenStarted=$false
$preopenReadyName='Local\UBE-preopen-ready-' + $id; $preopenReleaseName='Local\UBE-preopen-release-' + $id
$preopenReady=[Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$preopenReadyName)
$preopenRelease=[Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$preopenReleaseName)
try {
    if ($Preopen) {
        $preopenProcess=[Diagnostics.Process]::new(); $preopenProcess.StartInfo.FileName=(Resolve-Path -LiteralPath $Preopen).Path
        $preopenProcess.StartInfo.Arguments='"' + $directory + '" ' + $preopenReadyName + ' ' + $preopenReleaseName
        $preopenProcess.StartInfo.UseShellExecute=$false; $preopenProcess.StartInfo.CreateNoWindow=$true
        if (-not $preopenProcess.Start()) { throw 'Preopen actor did not start' }; $preopenStarted=$true
        if (-not $preopenReady.WaitOne(5000)) { throw 'Preopen actor was not ready' }
    }
    $process.StartInfo.FileName=$probePath
    $renameMode=if ($UnguardedPosix) { 'unprotected-posix' } elseif ($ShareWrite -and $Posix) { 'parent-sharewrite-posix' } elseif ($ShareWrite) { 'parent-sharewrite' } elseif ($Posix) { 'parent-posix' } else { 'parent-guard' }
    $process.StartInfo.Arguments='"' + $directory + '" ' + (($names | Select-Object -First 6) -join ' ') + ' "' + $wrapperPath + '" "' + $inspectorPath + '" ' + ($names[6..7] -join ' ') + ' commit existing ' + $renameMode
    $process.StartInfo.UseShellExecute=$false; $process.StartInfo.CreateNoWindow=$true
    $process.StartInfo.RedirectStandardError=$true; $process.StartInfo.RedirectStandardOutput=$true
    if (-not $process.Start()) { throw 'Probe did not start' }; $started=$true
    if (-not $events[4].WaitOne(10000)) { throw 'Inspection barrier not reached' }; $events[5].Set() | Out-Null
    $guarded=$events[0].WaitOne(3000); $staged=$false; $actorMoved=$false; $actorError=''; $candidateMoved=$false; $reparseOutput=''; $reparseStatus=-1
    if ($guarded) {
        $events[1].Set() | Out-Null
        if (-not $events[2].WaitOne(5000)) { throw 'Closed-target barrier not reached' }
        try { [IO.File]::Move($destination,$moved); $actorMoved=$true } catch [IO.IOException] { $actorError=$_.Exception.Message }
        if ($actorMoved) { [IO.File]::Move($moved,$destination) }
        if ($ShareWrite) {
            try { [IO.File]::Move($candidate,$moved); $candidateMoved=$true } catch [IO.IOException] { }
            if ($candidateMoved) { [IO.File]::Move($moved,$candidate) }
        }
        if ($ReparseActor) {
            $actorPath=(Resolve-Path -LiteralPath $ReparseActor).Path
            $reparseOutput=(@(& $actorPath $directory $redirect 2>&1) -join ' ').Trim(); $reparseStatus=$LASTEXITCODE
        }
        $events[3].Set() | Out-Null
        $staged=$events[6].WaitOne(3000)
        if ($staged) { $events[7].Set() | Out-Null }
    }
    if (-not $process.WaitForExit(10000)) { throw 'Probe did not exit' }
    $stdout=$process.StandardOutput.ReadToEnd().Trim(); $stderr=$process.StandardError.ReadToEnd().Trim()
    if ($RequireBlockedFailure -and (-not $guarded -or $staged -or $actorMoved -or $process.ExitCode -eq 0 -or $stderr -notmatch 'transacted handle rename NTSTATUS: 0xC0000043')) { throw "Expected sharing failure was not observed: $stdout $stderr" }
    if ($RequireCommit -and (-not $guarded -or -not $staged -or $process.ExitCode -ne 0 -or $stdout -notmatch 'transacted handle rename committed')) { throw "Expected commit was not observed: $stdout $stderr" }
    if ($RequireShareWriteCommit -and (-not $ShareWrite -or -not $guarded -or -not $staged -or $actorMoved -or $candidateMoved -or $process.ExitCode -ne 0 -or $reparseStatus -ne 4 -or $reparseOutput -ne 'set error=145' -or $stdout -notmatch 'transacted handle rename committed')) { throw "Expected share-write observations were not met: $stdout $stderr $reparseOutput" }
    if ($RequirePreopenFailure -and (-not $Preopen -or $guarded -or $staged -or $process.ExitCode -eq 0 -or $stderr -notmatch 'directory open failed: 32')) { throw "Preexisting handle did not prevent guard acquisition: $stdout $stderr" }
    if ($process.ExitCode -eq 0) {
        if (-not $staged -or (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne $fixtureHash -or [IO.File]::Exists($candidate)) { throw 'Successful output differs from fixture' }
    } else {
        if ([IO.File]::ReadAllText($destination) -ne 'old' -or (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash -ne $fixtureHash) { throw 'Failed probe changed old output or candidate' }
    }
    Write-Output "guarded=$guarded staged=$staged actor-moved=$actorMoved candidate-moved=$candidateMoved reparse=$reparseOutput actor-error=$actorError status=$($process.ExitCode) stdout=$stdout stderr=$stderr"
    if ($Preopen) {
        $preopenRelease.Set() | Out-Null
        if (-not $preopenProcess.WaitForExit(5000) -or $preopenProcess.ExitCode -ne 0) { throw 'Preopen actor did not close cleanly' }
        $movedDirectory=$directory + '-moved'
        [IO.Directory]::Move($directory,$movedDirectory); [IO.Directory]::Move($movedDirectory,$directory)
        Write-Output 'Output directory moved and restored after preopen actor released its handle.'
    }
    Write-Output "Test-owned artifacts: $directory"
} finally {
    foreach ($n in @(1,3,5,7)) { $events[$n].Set() | Out-Null }
    $preopenRelease.Set() | Out-Null
    if ($started -and -not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() }
    $process.Dispose(); foreach ($event in $events) { $event.Dispose() }
    if ($preopenProcess) { if ($preopenStarted -and -not $preopenProcess.WaitForExit(10000)) { $preopenProcess.Kill(); $preopenProcess.WaitForExit() }; $preopenProcess.Dispose() }
    $preopenReady.Dispose(); $preopenRelease.Dispose()
}
