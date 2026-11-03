param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $Reader, [Parameter(Mandatory=$true)][string] $OutputDirectory, [switch] $ExpectMissing, [switch] $RequireNoOpenErrors)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$probePath=(Resolve-Path -LiteralPath $Probe).Path; $readerPath=(Resolve-Path -LiteralPath $Reader).Path
$root=Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
foreach ($round in 1..5) {
    $directory=Join-Path $root ([string]$round); [IO.Directory]::CreateDirectory($directory) | Out-Null
    $destination=Join-Path $directory 'destination.bin'
    [IO.File]::WriteAllText($destination,'old'); [IO.File]::WriteAllText((Join-Path $directory 'candidate.bin'),'candidate'); [IO.File]::WriteAllText((Join-Path $directory 'protected.bin'),'protected')
    $id=[guid]::NewGuid().ToString('N')
    $names=@('ready','release','closed-ready','closed-release','saw-old','saw-new','stop') | ForEach-Object { 'Local\UBE-tx-visible-' + $_ + '-' + $id }
    $events=@($names | ForEach-Object { [Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$_) })
    $writer=[Diagnostics.Process]::new(); $readerProcess=[Diagnostics.Process]::new(); $readerStarted=$false; $writerStarted=$false
    try {
        $writer.StartInfo.FileName=$probePath; $writer.StartInfo.Arguments='"' + $directory + '" ' + (($names | Select-Object -First 4) -join ' ')
        $writer.StartInfo.UseShellExecute=$false; $writer.StartInfo.CreateNoWindow=$true; $writer.StartInfo.RedirectStandardOutput=$true; $writer.StartInfo.RedirectStandardError=$true
        if (-not $writer.Start()) { throw 'Writer did not start' }; $writerStarted=$true
        if (-not $events[0].WaitOne(5000)) { throw 'Transaction guard was not established' }
        $events[1].Set() | Out-Null
        if (-not $events[2].WaitOne(5000)) { throw 'Closed-target barrier not reached' }
        $readerProcess.StartInfo.FileName=$readerPath; $readerProcess.StartInfo.Arguments='"' + $destination + '" ' + ($names[4..6] -join ' ')
        $readerProcess.StartInfo.UseShellExecute=$false; $readerProcess.StartInfo.CreateNoWindow=$true; $readerProcess.StartInfo.RedirectStandardOutput=$true; $readerProcess.StartInfo.RedirectStandardError=$true
        if (-not $readerProcess.Start()) { throw 'Reader did not start' }; $readerStarted=$true
        if (-not $events[4].WaitOne(5000)) { throw 'Reader did not observe old bytes before commit' }
        $events[3].Set() | Out-Null
        if (-not $writer.WaitForExit(10000) -or $writer.ExitCode -ne 0) { throw "Transaction failed: $($writer.StandardError.ReadToEnd())" }
        if (-not $events[5].WaitOne(5000)) { throw 'Reader did not observe new bytes after commit' }
        $events[6].Set() | Out-Null
        if (-not $readerProcess.WaitForExit(5000) -or $readerProcess.ExitCode -ne 0) { throw 'Reader failed' }
        $observation=$readerProcess.StandardOutput.ReadToEnd().Trim()
        if ($observation -notmatch '^old=[1-9][0-9]* new=[1-9][0-9]* missing=[0-9]+ sharing=[0-9]+ other=0 invalid=0$') { throw "Bad reader observations: $observation" }
        if ($ExpectMissing -and $observation -notmatch 'missing=[1-9][0-9]*') { throw "Non-atomic control failed to expose missing path: $observation" }
        if ($RequireNoOpenErrors -and $observation -notmatch 'missing=0 sharing=0 other=0 invalid=0$') { throw "Reader open or content failure: $observation" }
        if ([IO.File]::ReadAllText($destination) -ne 'candidate') { throw 'Committed destination differs' }
        Write-Output "Round ${round}: $observation"
    } finally {
        $events[1].Set() | Out-Null; $events[3].Set() | Out-Null; $events[6].Set() | Out-Null
        foreach ($item in @(@($writer,$writerStarted),@($readerProcess,$readerStarted))) {
            if ($item[1] -and -not $item[0].WaitForExit(10000)) { $item[0].Kill(); $item[0].WaitForExit() }
            $item[0].Dispose()
        }
        foreach ($event in $events) { $event.Dispose() }
    }
}
Write-Output "Test-owned artifacts: $root"
