param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $AncestorGuard,
      [Parameter(Mandatory=$true)][string] $JunctionGuard, [Parameter(Mandatory=$true)][string] $Wrapper,
      [Parameter(Mandatory=$true)][string] $Inspector, [Parameter(Mandatory=$true)][string] $StructuralProbe,
      [Parameter(Mandatory=$true)][string] $Executable, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$probePath=(Resolve-Path -LiteralPath $Probe).Path; $ancestorPath=(Resolve-Path -LiteralPath $AncestorGuard).Path
$junctionPath=(Resolve-Path -LiteralPath $JunctionGuard).Path; $wrapperPath=(Resolve-Path -LiteralPath $Wrapper).Path
$inspectorPath=(Resolve-Path -LiteralPath $Inspector).Path; $structuralPath=(Resolve-Path -LiteralPath $StructuralProbe).Path
$fixture=(Resolve-Path -LiteralPath $Executable).Path; $fixtureHash=(Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash
$root=Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
foreach ($case in @('path-resolved-protected','actual-protected')) {
    $base=Join-Path $root $case; $original=Join-Path $base 'original'; $other=Join-Path $base 'other'; $parent=Join-Path $base 'parent'
    $active=Join-Path $parent 'active'; $prior=Join-Path $base 'prior'
    foreach ($d in @($original,$other,$parent)) { [IO.Directory]::CreateDirectory($d) | Out-Null }
    [IO.File]::Copy($fixture,(Join-Path $original 'candidate.bin')); [IO.File]::Copy($fixture,(Join-Path $other 'candidate.bin'))
    [IO.File]::WriteAllText((Join-Path $original 'destination.bin'),'old'); [IO.File]::WriteAllText((Join-Path $original 'protected.bin'),'protected')
    [IO.File]::WriteAllText((Join-Path $other 'protected.bin'),'decoy')
    New-Item -ItemType HardLink -Path (Join-Path $other 'destination.bin') -Target (Join-Path $original 'protected.bin') | Out-Null
    New-Item -ItemType Junction -Path $active -Target $original | Out-Null
    [IO.Directory]::Move($active,$prior); [IO.Directory]::Move($prior,$active)
    $id=[guid]::NewGuid().ToString('N')
    $names=@('ready','release','closed-ready','closed-release','inspect-ready','inspect-release','ancestor-ready','ancestor-release','junction-ready','junction-release') | ForEach-Object { 'Local\UBE-guard-acquire-' + $_ + '-' + $id }
    $events=@($names | ForEach-Object { [Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$_) })
    $ancestor=[Diagnostics.Process]::new(); $junction=[Diagnostics.Process]::new(); $probeProcess=[Diagnostics.Process]::new()
    $ancestorStarted=$false; $junctionStarted=$false; $probeStarted=$false
    try {
        $ancestor.StartInfo.FileName=$ancestorPath; $ancestor.StartInfo.Arguments='"' + $parent + '" ' + $names[6] + ' ' + $names[7]
        $ancestor.StartInfo.UseShellExecute=$false; $ancestor.StartInfo.CreateNoWindow=$true
        if (-not $ancestor.Start()) { throw 'Ancestor guard did not start' }; $ancestorStarted=$true
        if (-not $events[6].WaitOne(5000)) { throw 'Ancestor guard not ready' }
        [IO.Directory]::Move($active,$prior); New-Item -ItemType Junction -Path $active -Target $other | Out-Null
        if ([IO.File]::ReadAllText((Join-Path $active 'destination.bin')) -ne 'protected') { throw 'Pre-guard junction swap did not expose protected alias' }
        $junction.StartInfo.FileName=$junctionPath; $junction.StartInfo.Arguments='"' + $active + '" ' + $names[8] + ' ' + $names[9]
        $junction.StartInfo.UseShellExecute=$false; $junction.StartInfo.CreateNoWindow=$true
        if (-not $junction.Start()) { throw 'Junction guard did not start' }; $junctionStarted=$true
        if (-not $events[8].WaitOne(5000)) { throw 'Junction guard not ready' }
        $probeProcess.StartInfo.FileName=$probePath
        $probeProcess.StartInfo.Arguments='"' + $active + '" ' + (($names | Select-Object -First 6) -join ' ') + ' "' + $wrapperPath + '" "' + $inspectorPath + '" "' + $structuralPath + '"'
        if ($case -eq 'actual-protected') { $probeProcess.StartInfo.Arguments+=' "--protected=' + (Join-Path $original 'protected.bin') + '"' }
        $probeProcess.StartInfo.UseShellExecute=$false; $probeProcess.StartInfo.CreateNoWindow=$true; $probeProcess.StartInfo.RedirectStandardOutput=$true; $probeProcess.StartInfo.RedirectStandardError=$true
        if (-not $probeProcess.Start()) { throw 'Probe did not start' }; $probeStarted=$true
        if (-not $events[4].WaitOne(10000)) { throw 'Candidate inspection did not finish' }; $events[5].Set() | Out-Null
        if ($case -eq 'path-resolved-protected') {
            if (-not $events[0].WaitOne(5000)) { throw 'Decoy transaction not ready' }; $events[1].Set() | Out-Null
            if (-not $events[2].WaitOne(5000)) { throw 'Decoy precommit not reached' }; $events[3].Set() | Out-Null
        }
        if (-not $probeProcess.WaitForExit(10000)) { throw 'Probe timed out' }
        $stdout=$probeProcess.StandardOutput.ReadToEnd(); $stderr=$probeProcess.StandardError.ReadToEnd()
        if ($stdout -notmatch 'structural inspection succeeded' -or $stdout -notmatch 'external inspection succeeded') { throw 'Inspection observations missing' }
        if ($case -eq 'path-resolved-protected') {
            if ($probeProcess.ExitCode -ne 0 -or (Get-FileHash -LiteralPath (Join-Path $other 'destination.bin') -Algorithm SHA256).Hash -ne $fixtureHash -or [IO.File]::Exists((Join-Path $other 'candidate.bin'))) { throw "Adverse control did not publish: $stdout $stderr" }
        } else {
            if ($probeProcess.ExitCode -eq 0 -or $stderr -notmatch 'protected identity rejected' -or [IO.File]::ReadAllText((Join-Path $other 'destination.bin')) -ne 'protected' -or (Get-FileHash -LiteralPath (Join-Path $other 'candidate.bin') -Algorithm SHA256).Hash -ne $fixtureHash) { throw "Actual protected identity was not preserved: $stdout $stderr" }
        }
        if ([IO.File]::ReadAllText((Join-Path $original 'destination.bin')) -ne 'old' -or [IO.File]::ReadAllText((Join-Path $original 'protected.bin')) -ne 'protected' -or (Get-FileHash -LiteralPath (Join-Path $original 'candidate.bin') -Algorithm SHA256).Hash -ne $fixtureHash) { throw 'Original fixtures changed' }
        Write-Output "${case}: exit=$($probeProcess.ExitCode); original files and candidate checked."
    } finally {
        foreach ($n in @(1,3,5,7,9)) { $events[$n].Set() | Out-Null }
        foreach ($item in @(@($probeProcess,$probeStarted),@($junction,$junctionStarted),@($ancestor,$ancestorStarted))) {
            if ($item[1] -and -not $item[0].WaitForExit(10000)) { $item[0].Kill(); $item[0].WaitForExit() }; $item[0].Dispose()
        }
        foreach ($event in $events) { $event.Dispose() }
    }
}
Write-Output "Test-owned artifacts: $root"
