# Exercises the real request API and cancellation diagnostic without reserving or publishing output.
param(
 [Parameter(Mandatory=$true)][string]$CompilerExe,
 [string]$Clang='C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$utf8=New-Object Text.UTF8Encoding($false,$true)
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube request cancellation '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$script:serial=0
Write-Output "Evidence: $evidence"
function Require([bool]$Value,[string]$Message){if(-not $Value){throw $Message}}
function Write-Text([string]$Path,[string]$Value){[IO.File]::WriteAllText($Path,$Value,$utf8)}
function Quote([string]$Value){'"'+[regex]::Replace([regex]::Replace($Value,'(\\*)"','$1$1\"'),'(\\+)$','$1$1')+'"'}
function Run([string]$File,[string[]]$Arguments,[int]$Deadline=180000){
 $script:serial++;$prefix=Join-Path $evidence ('process-'+$script:serial)
 $options=@{FilePath=$File;WorkingDirectory=$evidence;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=($Arguments|ForEach-Object{Quote $_}) -join ' '}
 $p=Start-Process @options
 try{$null=$p.Handle;if(-not $p.WaitForExit($Deadline)){$p.Kill();$null=$p.WaitForExit(5000);throw "Deadline: $prefix"};$p.Refresh();return [pscustomobject]@{Exit=$p.ExitCode;Out=[IO.File]::ReadAllText($prefix+'.stdout',$utf8);Error=[IO.File]::ReadAllText($prefix+'.stderr',$utf8)}}finally{$p.Dispose()}
}
foreach($optimization in @('0','2')){
 $package=& (Join-Path $root 'bootstrap/tools/self-host-sources.ps1') -Destination (Join-Path $evidence ('o'+$optimization)) -Kind Exe -Optimization $optimization -AdditionalSources (Join-Path $PSScriptRoot 'Probe.bas')
 $lines=[IO.File]::ReadAllLines($package.Manifest,$utf8) | Where-Object {$_ -cne 'Source = "CompilerCommand.bas"'}
 Write-Text $package.Manifest (($lines -join "`r`n")+"`r`n")
 $probe=Join-Path $package.Destination 'probe.exe'
 $built=Run $CompilerExe @('--build',$package.Manifest,$probe,'--clang',$Clang)
 Require ($built.Exit -eq 0 -and $built.Out -match '(?m)^BUILD OK\r?$' -and $built.Error -ceq '') ('Probe build failed: '+$built.Error)
 $missing=Join-Path $package.Destination 'missing.UBE'
 $output=Join-Path $package.Destination 'retained.ll'
 Write-Text $output 'PRESERVE'
 $r=Run $probe @($missing,$output) 20000
 $expected="UBE: E_CANCELLED: compilation stopped (operation/code/reason 0/104/0) $output`r`n"
 Require ($r.Exit -eq 0 -and $r.Out -ceq '' -and $r.Error -ceq $expected) ('Request cancellation O'+$optimization+' failed: exit '+$r.Exit+' '+$r.Error)
 Require ([IO.File]::ReadAllText($output,$utf8) -ceq 'PRESERVE') 'Cancellation/failure changed existing output'
 Require (@(Get-ChildItem -LiteralPath $package.Destination -Directory -Force -Filter '.ube-*').Count -eq 0) 'Request leaked a private stage'
 Write-Output "PASS O$optimization : exact cancelled diagnostic, reset metadata, no cancelled-request owners, preserved output, unrelated request classified normally"
}
Write-Output "PASS request cancellation; evidence: $evidence"