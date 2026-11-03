param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $Wrapper,
      [Parameter(Mandatory=$true)][string] $Inspector, [Parameter(Mandatory=$true)][string] $Executable,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$probePath=(Resolve-Path -LiteralPath $Probe).Path; $wrapperPath=(Resolve-Path -LiteralPath $Wrapper).Path
$inspectorPath=(Resolve-Path -LiteralPath $Inspector).Path; $fixture=(Resolve-Path -LiteralPath $Executable).Path
$fixtureHash=(Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash
$root=Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
$counts=@{ old=0; new=0; terminated=0; completed=0 }
foreach ($delay in @(0,0,0,1,1,1,5,5,5,20,20,20)) {
    $directory=Join-Path $root ([guid]::NewGuid().ToString('N')); [IO.Directory]::CreateDirectory($directory) | Out-Null
    $candidate=Join-Path $directory 'candidate.bin'; $destination=Join-Path $directory 'destination.bin'
    [IO.File]::Copy($fixture,$candidate); [IO.File]::WriteAllText($destination,'old'); [IO.File]::WriteAllText((Join-Path $directory 'protected.bin'),'protected')
    $id=[guid]::NewGuid().ToString('N'); $names=@('ready','release','closed-ready','closed-release','inspect-ready','inspect-release','staged-ready','staged-release') | ForEach-Object { 'Local\UBE-tx-race-' + $_ + '-' + $id }
    $events=@($names | ForEach-Object { [Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$_) })
    $process=[Diagnostics.Process]::new(); $started=$false; $terminated=$false
    try {
        $process.StartInfo.FileName=$probePath
        $process.StartInfo.Arguments='"' + $directory + '" ' + (($names | Select-Object -First 6) -join ' ') + ' "' + $wrapperPath + '" "' + $inspectorPath + '" ' + ($names[6..7] -join ' ') + ' commit'
        $process.StartInfo.UseShellExecute=$false; $process.StartInfo.CreateNoWindow=$true
        $process.StartInfo.RedirectStandardError=$true; $process.StartInfo.RedirectStandardOutput=$true
        if (-not $process.Start()) { throw 'Probe did not start' }; $started=$true
        if (-not $events[4].WaitOne(10000)) { throw 'Inspection barrier not reached' }; $events[5].Set() | Out-Null
        if (-not $events[0].WaitOne(5000)) { throw 'Transaction guard not established' }; $events[1].Set() | Out-Null
        if (-not $events[2].WaitOne(5000)) { throw 'Pre-rename barrier not reached' }; $events[3].Set() | Out-Null
        if (-not $events[6].WaitOne(5000)) { throw 'Staged-rename barrier not reached' }; $events[7].Set() | Out-Null
        if (-not $process.WaitForExit($delay)) {
            try { $process.Kill(); $terminated=$true } catch [InvalidOperationException] { }
        }
        if (-not $process.WaitForExit(10000)) { throw 'Probe exit not observed' }
        if ($terminated) { $counts.terminated++ } else { $counts.completed++ }
        $stdout=$process.StandardOutput.ReadToEnd(); $stderr=$process.StandardError.ReadToEnd()
        $reportedCommit=$stdout -match 'transacted handle rename committed'
        if ($stdout -notmatch 'external inspection succeeded' -or $stdout -notmatch 'inspected candidate identity matched') { throw "Inspection evidence missing: $stdout $stderr" }
        $deadline=[Diagnostics.Stopwatch]::StartNew(); $outcome=''
        while ($deadline.ElapsedMilliseconds -lt 5000 -and -not $outcome) {
            try {
                $bytes=[IO.File]::ReadAllBytes($destination)
                if ($bytes.Length -eq 3 -and [Text.Encoding]::ASCII.GetString($bytes) -ceq 'old' -and [IO.File]::Exists($candidate) -and (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash -eq $fixtureHash) { $outcome='old' }
                elseif ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -eq $fixtureHash -and -not [IO.File]::Exists($candidate)) { $outcome='new' }
            } catch [IO.IOException] { }
            if (-not $outcome) { Start-Sleep -Milliseconds 20 }
        }
        if (-not $outcome -or [IO.File]::ReadAllText((Join-Path $directory 'protected.bin')) -ne 'protected') { throw "Neither complete outcome observed after delay $delay" }
        if (-not $terminated -and ($process.ExitCode -ne 0 -or $outcome -ne 'new' -or -not $reportedCommit)) { throw "Nonterminated process did not confirm a committed result: $stdout $stderr" }
        $counts[$outcome]++
        Write-Output "delay=${delay}ms termination-issued=$terminated outcome=$outcome commit-message=$reportedCommit"
    } finally {
        foreach ($n in @(1,3,5,7)) { $events[$n].Set() | Out-Null }
        if ($started -and -not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() }
        $process.Dispose(); foreach ($event in $events) { $event.Dispose() }
    }
}
Write-Output "old=$($counts.old) new=$($counts.new) terminated=$($counts.terminated) completed=$($counts.completed); artifacts=$root"
