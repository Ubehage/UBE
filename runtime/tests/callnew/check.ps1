param([string]$BootstrapExe='', [string]$VB6='C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf8=New-Object Text.UTF8Encoding($false,$true)
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube native workers '+[guid]::NewGuid())
$null=New-Item -ItemType Directory $artifacts
Write-Output "Artifacts retained: $artifacts"
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Workers.bas') -Destination (Join-Path $artifacts 'Workers.bas')
foreach($name in @('CaptureProbe.bas','Capacity.bas','Acceptance.bas')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $artifacts $name)}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../../../std-lib/src/portable/ThreadPrimitives.bas') -Destination (Join-Path $artifacts 'ThreadPrimitives.bas')
function Invoke-Checked([string]$File,[string[]]$Arguments,[string]$Name,[int]$Expected=0){
    $quoted=($Arguments|ForEach-Object{if($_ -match '[\s"]'){'"'+$_+'"'}else{$_}}) -join ' '
    $out=Join-Path $artifacts ($Name+'.stdout');$err=Join-Path $artifacts ($Name+'.stderr')
    $start=@{FilePath=$File;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=$out;RedirectStandardError=$err}
    if($Arguments.Count -gt 0){$start.ArgumentList=$quoted}
    $process=Start-Process @start
    try{$handle=$process.Handle;if(-not $process.WaitForExit(30000)){$process.Kill();throw "$Name timed out"};$process.Refresh();$code=$process.ExitCode}finally{$process.Dispose()}
    $errors=[IO.File]::ReadAllText($err,$utf8)
    if($code -ne $Expected -or $errors.Length -ne 0){throw "$Name failed exit $code, expected $Expected`: $errors"}
}
if(-not $BootstrapExe){
    $project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../bootstrap/UBE-Bootstrap.vbp'))
    $log=Join-Path $artifacts 'vb6-build.log'
    Invoke-Checked $VB6 @('/make',$project,'/out',$log,'/outdir',$artifacts) 'host-build'
    if(Test-Path -LiteralPath $log){Get-Content -LiteralPath $log}
    $BootstrapExe=Join-Path $artifacts 'UBE-Bootstrap.exe'
    if(-not(Test-Path -LiteralPath $BootstrapExe)){throw 'Host build did not publish its executable'}
}
foreach($level in 0,2){
    $manifest=Join-Path $artifacts ('workers'+$level+'.UBE')
    [IO.File]::WriteAllText($manifest,"UBE-Project 1`r`nName = `"WorkerAcceptance`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nOptimization = `"$level`"`r`nSource = `"Workers.bas`"`r`nSource = `"CaptureProbe.bas`"`r`nSource = `"Capacity.bas`"`r`nSource = `"Acceptance.bas`"`r`nSource = `"ThreadPrimitives.bas`"`r`n",$utf8)
    $exe=Join-Path $artifacts ('workers'+$level+'.exe')
    Invoke-Checked $BootstrapExe @('--build',$manifest,$exe) ('build'+$level)
    Invoke-Checked $exe @() ('run'+$level)
    Write-Output "PASS: native worker ownership and fresh failure assertions O$level"
    $workerPath=Join-Path $artifacts 'Workers.bas';$original=[IO.File]::ReadAllText($workerPath,$utf8)
    $changed=$original.Replace('Observed <> 41','Observed <> 42')
    if($changed -ceq $original){throw 'Missing source ownership negative-control observation'}
    [IO.File]::WriteAllText($workerPath,$changed,$utf8)
    $negative=Join-Path $artifacts ('workers-negative'+$level+'.exe')
    Invoke-Checked $BootstrapExe @('--build',$manifest,$negative) ('build-negative'+$level)
    Invoke-Checked $negative @() ('run-negative'+$level) 1
    [IO.File]::WriteAllText($workerPath,$original,$utf8)
    Write-Output "PASS: changed caller-return scalar observation rejected O$level"
}
& (Join-Path $PSScriptRoot 'fault-check.ps1') -BootstrapExe $BootstrapExe
