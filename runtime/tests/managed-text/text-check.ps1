# Runs actual managed String source; no model or replacement storage is admitted.
param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe',[switch]$Simple,[switch]$Conditions,[switch]$Threads)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$encoding=New-Object Text.UTF8Encoding($false,$true)
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube managed text '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
Write-Output "Evidence: $evidence"
$script:sequence=0
function Quote-Argument([string]$Value) {
 if($Value.Length -gt 0 -and $Value -notmatch '[\s"]'){return $Value}
 $escaped=[regex]::Replace($Value,'(\\*)"','$1$1\"')
 $escaped=[regex]::Replace($escaped,'(\\+)$','$1$1')
 return '"'+$escaped+'"'
}
function Run([string]$File,[string[]]$Arguments,[int]$Expected=0,[switch]$Build) {
 $script:sequence++
 $prefix=Join-Path $evidence ('process-'+$script:sequence)
 $options=@{FilePath=$File;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=(($Arguments|ForEach-Object {Quote-Argument $_}) -join ' ')}
 $process=Start-Process @options
 try {
  $handle=$process.Handle
  if(-not $process.WaitForExit(60000)){$process.Kill();$null=$process.WaitForExit(5000);throw "Deadline: $prefix"}
  $process.Refresh()
  $errors=[IO.File]::ReadAllText($prefix+'.stderr')
  $output=[IO.File]::ReadAllText($prefix+'.stdout')
  if($null -eq $process.ExitCode -or $process.ExitCode -ne $Expected -or $errors.Length){throw "Exit $($process.ExitCode), expected $Expected; $output $errors; evidence $prefix"}
  if($Build -and $output -notmatch '(?m)^BUILD OK\r?$'){throw "Missing build success: $prefix"}
 }finally{$process.Dispose()}
}
$modules=@('Text','TextPrimitives','Utf8','BufferPrimitives','ByteText','InvariantNumbers','FilePrimitives','ThreadPrimitives','Memory')
foreach($name in $modules){Copy-Item -LiteralPath (Join-Path $repo "std-lib/src/portable/$name.bas") -Destination $evidence}
$probe=Join-Path $evidence 'TextProbe.bas'
$probeName='TextProbe.bas'
if($Simple){$probeName='SimpleString.bas'}
if($Conditions){$probeName='StringConditions.bas'}
if($Threads){$probeName='ThreadTextProbe.bas'}
if(([int]$Simple.IsPresent+[int]$Conditions.IsPresent+[int]$Threads.IsPresent) -gt 1){throw 'Choose one diagnostic client'}
$original=[IO.File]::ReadAllText((Join-Path $PSScriptRoot $probeName),$encoding)
foreach($level in @('0','2')) {
 $manifest=Join-Path $evidence ('Project'+$level+'.UBE')
 $text="UBE-Project 1`r`nName = `"ManagedTextTest`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nOptimization = `"$level`"`r`n"
 foreach($name in ($modules+@('TextProbe'))){$text+="Source = `"$name.bas`"`r`n"}
 [IO.File]::WriteAllText($manifest,$text,$encoding)
 foreach($negative in @($false,$true)) {
  $source=$original
  if($negative){
   if($Threads){$source=$original.Replace('If After <> "retained payload / worker"','If After <> "incorrect payload / worker"')}
   elseif($Conditions){$source=$original.Replace('Value = Echo("False")','Value = Echo("True")')}
   elseif($Simple){$source=$original.Replace('If Value <> "Hi"','If Value <> "Ho"')}
   else{$source=$original.Replace('Text.Length(Value) <> 4','Text.Length(Value) <> 5')}
   if($source -ceq $original){throw 'Missing negative control marker'}
  }
  [IO.File]::WriteAllText($probe,$source,$encoding)
  $exe=Join-Path $evidence "Probe-$level-$negative.exe"
  Run $CompilerExe @('--build',$manifest,$exe,'--clang',$Clang) -Build
  $expected=0;if($negative){$expected=1}
  Run $exe @() $expected
 }
 if($Threads){Write-Output "PASS native String O$level retained array payload, simultaneous collectors and changed retained-value control"}
 elseif($Conditions){Write-Output "PASS native String O$level If/Do Boolean conversion, failure and changed-condition control"}
 elseif($Simple){Write-Output "PASS native String O$level literal/ByVal/result/comparison and changed-value control"}
 else{Write-Output "PASS native String O$level Unicode/value/conversion/failure/collection cases and changed scalar-count control"}
}
