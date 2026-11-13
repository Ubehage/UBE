param([Parameter(Mandatory=$true)][string]$Directory,[Parameter(Mandatory=$true)][string]$Baseline)
$ErrorActionPreference='Stop'
$Directory=[IO.Path]::GetFullPath($Directory)
$watch=[Diagnostics.Stopwatch]::StartNew()
$process=Start-Process -FilePath (Join-Path $Directory 'profile.exe') -WorkingDirectory $Directory -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $Directory 'run.stdout') -RedirectStandardError (Join-Path $Directory 'run.stderr')
try{
 $handle=$process.Handle
 if(-not $process.WaitForExit(600000)){$process.Kill();$null=$process.WaitForExit(5000);throw 'Instrumented diagnostic exceeded ten-minute deadline'}
 $process.Refresh()
 if($process.ExitCode -ne 0){throw "Instrumented diagnostic failed: $($process.ExitCode)"}
}finally{$process.Dispose()}
$watch.Stop()
$expected=(Get-FileHash -LiteralPath $Baseline -Algorithm SHA256).Hash
$actual=(Get-FileHash -LiteralPath (Join-Path $Directory 'output-2.ll') -Algorithm SHA256).Hash
if($expected -cne $actual){throw 'Instrumented compiler output differs from the frozen baseline'}
Write-Output "PASS exact output hash $actual"
Write-Output "Instrumented diagnostic elapsed $($watch.Elapsed.TotalMilliseconds) ms; not performance acceptance evidence"
& (Join-Path $PSScriptRoot 'read.ps1') -Counts (Join-Path $Directory 'counts.bin')
