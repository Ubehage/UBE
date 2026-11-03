param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $Actor,
      [Parameter(Mandatory=$true)][string] $Wrapper, [Parameter(Mandatory=$true)][string] $Inspector,
      [Parameter(Mandatory=$true)][string] $Executable, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$probePath=(Resolve-Path -LiteralPath $Probe).Path; $actorPath=(Resolve-Path -LiteralPath $Actor).Path
$wrapperPath=(Resolve-Path -LiteralPath $Wrapper).Path; $inspectorPath=(Resolve-Path -LiteralPath $Inspector).Path
$fixture=(Resolve-Path -LiteralPath $Executable).Path; $fixtureHash=(Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash
$root=Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
foreach ($case in @('guarded','unguarded')) {
    $directory=Join-Path (Join-Path $root $case) 'active'; [IO.Directory]::CreateDirectory($directory) | Out-Null
    $moved=Join-Path (Split-Path -Parent $directory) 'moved'
    [IO.File]::Copy($fixture,(Join-Path $directory 'candidate.bin')); [IO.File]::WriteAllText((Join-Path $directory 'destination.bin'),'old'); [IO.File]::WriteAllText((Join-Path $directory 'protected.bin'),'protected')
    $id=[guid]::NewGuid().ToString('N'); $names=@('ready','release','closed-ready','closed-release','inspect-ready','inspect-release','staged-ready','staged-release','actor-ready','actor-release','retry-ready','retry-release') | ForEach-Object { 'Local\UBE-preopen-move-' + $_ + '-' + $id }
    $events=@($names | ForEach-Object { [Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$_) })
    $actorProcess=[Diagnostics.Process]::new(); $probeProcess=[Diagnostics.Process]::new(); $actorStarted=$false; $probeStarted=$false
    try {
        $actorProcess.StartInfo.FileName=$actorPath; $actorProcess.StartInfo.Arguments='"' + $directory + '" ' + $names[8] + ' ' + $names[9] + ' "' + $moved + '"'
        if ($case -eq 'unguarded') { $actorProcess.StartInfo.Arguments+=' ' + $names[10] + ' ' + $names[11] }
        $actorProcess.StartInfo.UseShellExecute=$false; $actorProcess.StartInfo.CreateNoWindow=$true; $actorProcess.StartInfo.RedirectStandardOutput=$true; $actorProcess.StartInfo.RedirectStandardError=$true
        if (-not $actorProcess.Start()) { throw 'Actor did not start' }; $actorStarted=$true
        if (-not $events[8].WaitOne(5000)) { throw 'Actor preopen not observed' }
        $mode=if ($case -eq 'guarded') { 'parent-sharewrite' } else { 'unprotected-posix' }
        $probeProcess.StartInfo.FileName=$probePath
        $probeProcess.StartInfo.Arguments='"' + $directory + '" ' + (($names | Select-Object -First 6) -join ' ') + ' "' + $wrapperPath + '" "' + $inspectorPath + '" ' + ($names[6..7] -join ' ') + ' commit existing ' + $mode
        $probeProcess.StartInfo.UseShellExecute=$false; $probeProcess.StartInfo.CreateNoWindow=$true; $probeProcess.StartInfo.RedirectStandardOutput=$true; $probeProcess.StartInfo.RedirectStandardError=$true
        if (-not $probeProcess.Start()) { throw 'Probe did not start' }; $probeStarted=$true
        if (-not $events[4].WaitOne(10000)) { throw 'Inspection barrier not reached' }; $events[5].Set() | Out-Null
        if ($case -eq 'guarded') {
            if ($events[0].WaitOne(3000) -or -not $probeProcess.WaitForExit(5000) -or $probeProcess.ExitCode -eq 0) { throw 'Guard did not fail before transaction readiness' }
            $stderr=$probeProcess.StandardError.ReadToEnd(); if ($stderr -notmatch 'directory open failed: 32') { throw "Wrong guard failure: $stderr" }
            $events[9].Set() | Out-Null
        } else {
            if (-not $events[0].WaitOne(5000)) { throw 'Unguarded transaction not ready' }; $events[1].Set() | Out-Null
            if (-not $events[2].WaitOne(5000)) { throw 'Closed-target barrier not reached' }
            $events[9].Set() | Out-Null
        }
        if ($case -eq 'unguarded') {
            if (-not $events[10].WaitOne(5000)) { throw 'Actor did not report first move result' }
            $firstLine=$actorProcess.StandardOutput.ReadLine()
            if ($firstLine -ne 'preopened handle move error=6824' -or -not [IO.Directory]::Exists($directory) -or [IO.Directory]::Exists($moved)) { throw "Unexpected in-transaction move result: $firstLine" }
            $events[3].Set() | Out-Null
            if (-not $events[6].WaitOne(5000)) { throw 'Staged rename not reached' }; $events[7].Set() | Out-Null
            if (-not $probeProcess.WaitForExit(10000) -or $probeProcess.ExitCode -ne 0 -or $probeProcess.StandardOutput.ReadToEnd() -notmatch 'transacted handle rename committed') { throw 'Unguarded transaction did not commit' }
            if ((Get-FileHash -LiteralPath (Join-Path $directory 'destination.bin') -Algorithm SHA256).Hash -ne $fixtureHash -or [IO.File]::Exists((Join-Path $directory 'candidate.bin'))) { throw 'Directory did not receive inspected candidate' }
            $events[11].Set() | Out-Null
            if (-not $actorProcess.WaitForExit(5000) -or $actorProcess.ExitCode -ne 0 -or $actorProcess.StandardOutput.ReadToEnd().Trim() -ne 'preopened handle retry error=0') { throw 'Same-handle retry did not move directory' }
            if ([IO.Directory]::Exists($directory) -or -not [IO.Directory]::Exists($moved) -or (Get-FileHash -LiteralPath (Join-Path $moved 'destination.bin') -Algorithm SHA256).Hash -ne $fixtureHash) { throw 'Same-handle post-commit move outcome differs' }
            $actorOutput=$firstLine + '; same-handle retry error=0'
        } else {
            if (-not $actorProcess.WaitForExit(5000)) { throw 'Preopened-handle actor did not exit' }
            $actorOutput=$actorProcess.StandardOutput.ReadToEnd().Trim(); $actorError=$actorProcess.StandardError.ReadToEnd().Trim()
            if ($actorProcess.ExitCode -ne 0 -or $actorOutput -notmatch 'preopened handle move error=0' -or [IO.Directory]::Exists($directory) -or -not [IO.Directory]::Exists($moved)) { throw "Preopened-handle control did not move: $actorOutput $actorError" }
            if ([IO.File]::ReadAllText((Join-Path $moved 'destination.bin')) -ne 'old' -or (Get-FileHash -LiteralPath (Join-Path $moved 'candidate.bin') -Algorithm SHA256).Hash -ne $fixtureHash) { throw 'Failed guarded probe changed files' }
        }
        Write-Output "${case}: $actorOutput; transaction outcome and post-release directory move checked."
    } finally {
        foreach ($n in @(1,3,5,7,9,11)) { $events[$n].Set() | Out-Null }
        foreach ($item in @(@($actorProcess,$actorStarted),@($probeProcess,$probeStarted))) { if ($item[1] -and -not $item[0].WaitForExit(10000)) { $item[0].Kill(); $item[0].WaitForExit() }; $item[0].Dispose() }
        foreach ($event in $events) { $event.Dispose() }
    }
}
Write-Output "Test-owned artifacts: $root"
