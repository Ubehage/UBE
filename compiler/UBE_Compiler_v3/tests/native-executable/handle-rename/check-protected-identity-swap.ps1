param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $Wrapper,
      [Parameter(Mandatory=$true)][string] $Inspector, [Parameter(Mandatory=$true)][string] $StructuralProbe,
      [Parameter(Mandatory=$true)][string] $Executable, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$probePath=(Resolve-Path -LiteralPath $Probe).Path; $wrapperPath=(Resolve-Path -LiteralPath $Wrapper).Path
$inspectorPath=(Resolve-Path -LiteralPath $Inspector).Path; $structuralPath=(Resolve-Path -LiteralPath $StructuralProbe).Path
$fixture=(Resolve-Path -LiteralPath $Executable).Path; $fixtureHash=(Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash
$root=Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
foreach ($case in @('late-path','retained-handle')) {
    $directory=Join-Path $root $case; [IO.Directory]::CreateDirectory($directory) | Out-Null
    $candidate=Join-Path $directory 'candidate.bin'; $destination=Join-Path $directory 'destination.bin'
    $protected=Join-Path $directory 'protected.bin'; $moved=Join-Path $directory 'protected-moved.bin'
    [IO.File]::Copy($fixture,$candidate); [IO.File]::WriteAllText($protected,'protected')
    New-Item -ItemType HardLink -Path $destination -Target $protected | Out-Null
    $id=[guid]::NewGuid().ToString('N'); $names=@('ready','release','closed-ready','closed-release','inspect-ready','inspect-release') | ForEach-Object { 'Local\UBE-protected-swap-' + $_ + '-' + $id }
    $events=@($names | ForEach-Object { [Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$_) })
    $process=[Diagnostics.Process]::new(); $started=$false
    try {
        $option=if ($case -eq 'retained-handle') { '--protected=' } else { '--protected-late=' }
        $process.StartInfo.FileName=$probePath
        $process.StartInfo.Arguments='"' + $directory + '" ' + ($names -join ' ') + ' "' + $wrapperPath + '" "' + $inspectorPath + '" "' + $structuralPath + '" "' + $option + $protected + '"'
        $process.StartInfo.UseShellExecute=$false; $process.StartInfo.CreateNoWindow=$true
        $process.StartInfo.RedirectStandardOutput=$true; $process.StartInfo.RedirectStandardError=$true
        if (-not $process.Start()) { throw 'Probe did not start' }; $started=$true
        if (-not $events[4].WaitOne(10000)) { throw 'Inspection barrier not reached' }
        [IO.File]::Move($protected,$moved); [IO.File]::WriteAllText($protected,'decoy')
        $events[5].Set() | Out-Null
        if ($case -eq 'late-path') {
            if (-not $events[0].WaitOne(5000)) { throw 'Late-path transaction not ready' }; $events[1].Set() | Out-Null
            if (-not $events[2].WaitOne(5000)) { throw 'Late-path precommit not reached' }; $events[3].Set() | Out-Null
        }
        if (-not $process.WaitForExit(10000)) { throw 'Probe timed out' }
        $stdout=$process.StandardOutput.ReadToEnd(); $stderr=$process.StandardError.ReadToEnd()
        if ($stdout -notmatch 'structural inspection succeeded' -or $stdout -notmatch 'external inspection succeeded') { throw "Inspection evidence missing: $stdout $stderr" }
        if ($case -eq 'late-path') {
            if ($process.ExitCode -ne 0 -or (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne $fixtureHash -or [IO.File]::Exists($candidate)) { throw "Late-path adverse control failed: $stdout $stderr" }
        } else {
            if ($process.ExitCode -eq 0 -or $stdout -notmatch 'protected identity retained' -or $stderr -notmatch 'protected identity rejected' -or
                [IO.File]::ReadAllText($destination) -ne 'protected' -or (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash -ne $fixtureHash) { throw "Retained identity failed: $stdout $stderr" }
        }
        if ([IO.File]::ReadAllText($moved) -ne 'protected' -or [IO.File]::ReadAllText($protected) -ne 'decoy') { throw 'Actor substitution outcome differs' }
        Write-Output "${case}: exit=$($process.ExitCode); actor substitution and resulting files checked."
    } finally {
        foreach ($n in @(1,3,5)) { $events[$n].Set() | Out-Null }
        if ($started -and -not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() }
        $process.Dispose(); foreach ($event in $events) { $event.Dispose() }
    }
}
Write-Output "Test-owned artifacts: $root"
