param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $Wrapper,
      [Parameter(Mandatory=$true)][string] $Inspector, [Parameter(Mandatory=$true)][string] $StructuralProbe,
      [Parameter(Mandatory=$true)][string] $Executable, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$probePath=(Resolve-Path -LiteralPath $Probe).Path; $wrapperPath=(Resolve-Path -LiteralPath $Wrapper).Path
$inspectorPath=(Resolve-Path -LiteralPath $Inspector).Path; $structuralPath=(Resolve-Path -LiteralPath $StructuralProbe).Path
$fixture=(Resolve-Path -LiteralPath $Executable).Path; $fixtureHash=(Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash
$root=Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
foreach ($case in @('ordinary','alias-0','alias-1','alias-2','alias-3','duplicate-2','swapped-2')) {
    $directory=Join-Path $root $case; [IO.Directory]::CreateDirectory($directory) | Out-Null
    $candidate=Join-Path $directory 'candidate.bin'; $destination=Join-Path $directory 'destination.bin'
    [IO.File]::Copy($fixture,$candidate)
    $protected=@(0..3 | ForEach-Object { $p=Join-Path $directory "input-$_.bin"; [IO.File]::WriteAllText($p,"input-$_"); $p })
    if ($case -eq 'ordinary') { [IO.File]::WriteAllText($destination,'old') }
    else {
        $index=if ($case -match '([0-3])$') { [int]$Matches[1] } else { throw 'Missing case index' }
        if ($case -eq 'duplicate-2') {
            $duplicate=Join-Path $directory 'duplicate.bin'; New-Item -ItemType HardLink -Path $duplicate -Target $protected[2] | Out-Null
            New-Item -ItemType HardLink -Path $destination -Target $duplicate | Out-Null
        } else { New-Item -ItemType HardLink -Path $destination -Target $protected[$index] | Out-Null }
    }
    $id=[guid]::NewGuid().ToString('N'); $names=@('ready','release','closed-ready','closed-release','inspect-ready','inspect-release') | ForEach-Object { 'Local\UBE-protected-set-' + $_ + '-' + $id }
    $events=@($names | ForEach-Object { [Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$_) })
    $process=[Diagnostics.Process]::new(); $started=$false
    try {
        $process.StartInfo.FileName=$probePath
        $process.StartInfo.Arguments='"' + $directory + '" ' + ($names -join ' ') + ' "' + $wrapperPath + '" "' + $inspectorPath + '" "' + $structuralPath + '" --protected-set ' + (($protected | ForEach-Object { '"' + $_ + '"' }) -join ' ')
        $process.StartInfo.UseShellExecute=$false; $process.StartInfo.CreateNoWindow=$true; $process.StartInfo.RedirectStandardOutput=$true; $process.StartInfo.RedirectStandardError=$true
        if (-not $process.Start()) { throw 'Probe did not start' }; $started=$true
        if (-not $events[4].WaitOne(10000)) { throw 'Inspection barrier not reached' }
        if ($case -eq 'swapped-2') { $moved=Join-Path $directory 'input-2-moved.bin'; [IO.File]::Move($protected[2],$moved); [IO.File]::WriteAllText($protected[2],'decoy') }
        $events[5].Set() | Out-Null
        if ($case -eq 'ordinary') {
            if (-not $events[0].WaitOne(5000)) { throw 'Transaction was not ready' }; $events[1].Set() | Out-Null
            if (-not $events[2].WaitOne(5000)) { throw 'Precommit barrier not reached' }; $events[3].Set() | Out-Null
        } elseif ($events[0].WaitOne(500)) {
            $events[1].Set() | Out-Null
            if (-not $events[2].WaitOne(5000)) { throw 'Unexpected transaction did not reach precommit' }
            $events[3].Set() | Out-Null
        }
        if (-not $process.WaitForExit(10000)) { throw 'Probe timed out' }
        $stdout=$process.StandardOutput.ReadToEnd(); $stderr=$process.StandardError.ReadToEnd()
        if ($stdout -notmatch 'protected set retained' -or $stdout -notmatch 'structural inspection succeeded' -or $stdout -notmatch 'external inspection succeeded') { throw 'Retained set or inspections not observed' }
        if ($case -eq 'ordinary') {
            if ($process.ExitCode -ne 0 -or (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne $fixtureHash -or [IO.File]::Exists($candidate)) { throw "Ordinary output did not commit: $stderr" }
        } else {
            if ($process.ExitCode -eq 0 -or $stderr -notmatch 'protected identity rejected' -or [IO.File]::ReadAllText($destination) -ne "input-$index" -or (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash -ne $fixtureHash) { throw "Protected alias not preserved: $stdout $stderr" }
        }
        for ($i=0;$i -lt 4;$i++) {
            $expected=if ($case -eq 'swapped-2' -and $i -eq 2) { 'decoy' } else { "input-$i" }
            if ([IO.File]::ReadAllText($protected[$i]) -ne $expected) { throw "Input $i differs" }
        }
        if ($case -eq 'swapped-2' -and [IO.File]::ReadAllText($moved) -ne 'input-2') { throw 'Moved input differs' }
        Write-Output "${case}: exit=$($process.ExitCode); inputs and destination checked."
    } finally {
        foreach ($n in @(1,3,5)) { $events[$n].Set() | Out-Null }
        if ($started -and -not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() }
        $process.Dispose(); foreach ($event in $events) { $event.Dispose() }
    }
}
Write-Output "Test-owned artifacts: $root"
