param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$probePath=(Resolve-Path -LiteralPath $Probe).Path
$root=Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
foreach ($case in @('uncontended','path-swap')) {
    $directory=Join-Path $root $case; [IO.Directory]::CreateDirectory($directory) | Out-Null
    $candidate=Join-Path $directory 'candidate.bin'; $moved=Join-Path $directory 'inspected.bin'; $destination=Join-Path $directory 'destination.bin'
    [IO.File]::WriteAllText($candidate,'candidate'); [IO.File]::WriteAllText($destination,'old'); [IO.File]::WriteAllText((Join-Path $directory 'protected.bin'),'protected')
    $id=[guid]::NewGuid().ToString('N'); $names=@('ready','release','closed-ready','closed-release','inspect-ready','inspect-release') | ForEach-Object { 'Local\UBE-tx-inspected-' + $_ + '-' + $id }
    $events=@($names | ForEach-Object { [Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$_) })
    $process=[Diagnostics.Process]::new(); $started=$false
    try {
        $process.StartInfo.FileName=$probePath; $process.StartInfo.Arguments='"' + $directory + '" ' + ($names -join ' ')
        $process.StartInfo.UseShellExecute=$false; $process.StartInfo.CreateNoWindow=$true
        $process.StartInfo.RedirectStandardError=$true; $process.StartInfo.RedirectStandardOutput=$true
        if (-not $process.Start()) { throw 'Probe did not start' }; $started=$true
        if (-not $events[4].WaitOne(5000)) { throw 'Inspection barrier not reached' }
        $writeBlocked=$false
        try {
            $writer=[IO.File]::Open($candidate,[IO.FileMode]::Open,[IO.FileAccess]::Write,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
            $writer.Dispose()
        } catch [IO.IOException] { $writeBlocked=$true }
        if (-not $writeBlocked) { throw 'Inspected candidate allowed a new writer' }
        if ($case -eq 'path-swap') { [IO.File]::Move($candidate,$moved); [IO.File]::WriteAllText($candidate,'substitute') }
        $events[5].Set() | Out-Null
        if ($case -eq 'uncontended') {
            if (-not $events[0].WaitOne(5000)) { throw 'Transaction handoff did not succeed' }
            $events[1].Set() | Out-Null
            if (-not $events[2].WaitOne(5000)) { throw 'Precommit barrier not reached' }
            $events[3].Set() | Out-Null
        }
        if (-not $process.WaitForExit(10000)) { throw 'Probe timed out' }
        $stdout=$process.StandardOutput.ReadToEnd().Trim(); $stderr=$process.StandardError.ReadToEnd().Trim()
        if ($case -eq 'uncontended') {
            if ($process.ExitCode -ne 0 -or $stdout -notmatch 'inspected candidate identity matched' -or [IO.File]::ReadAllText($destination) -ne 'candidate') { throw "Matching handoff failed: $stdout $stderr" }
        } else {
            if ($process.ExitCode -eq 0 -or $stderr -notmatch 'candidate identity mismatch' -or [IO.File]::ReadAllText($destination) -ne 'old' -or
                [IO.File]::ReadAllText($moved) -ne 'candidate' -or [IO.File]::ReadAllText($candidate) -ne 'substitute') { throw "Swapped handoff was not rejected: $stdout $stderr" }
        }
        Write-Output "${case}: exit=$($process.ExitCode) stdout=$stdout stderr=$stderr"
    } finally {
        $events[1].Set() | Out-Null; $events[3].Set() | Out-Null; $events[5].Set() | Out-Null
        if ($started -and -not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() }
        $process.Dispose(); foreach ($event in $events) { $event.Dispose() }
    }
}
Write-Output "Test-owned artifacts: $root"
