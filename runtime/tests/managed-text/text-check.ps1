# Runs actual managed String source; no model or replacement storage is admitted.
param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe',[switch]$Simple,[switch]$Conditions,[switch]$Threads,[switch]$AllocationFailure)
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
$modules=@('Text','TextPrimitives','Utf8','BufferPrimitives','ByteText','InvariantNumbers','BinaryFloat','BinaryFloatValues','BinaryFloatText','FilePrimitives','ThreadPrimitives','Memory')
foreach($name in $modules){Copy-Item -LiteralPath (Join-Path $repo "std-lib/src/portable/$name.bas") -Destination $evidence}
$probe=Join-Path $evidence 'TextProbe.bas'
$probeName='TextProbe.bas'
if($Simple){$probeName='SimpleString.bas'}
if($Conditions){$probeName='StringConditions.bas'}
if($Threads){$probeName='ThreadTextProbe.bas'}
if($AllocationFailure){$probeName='AllocationFailure.bas'}
if(([int]$Simple.IsPresent+[int]$Conditions.IsPresent+[int]$Threads.IsPresent+[int]$AllocationFailure.IsPresent) -gt 1){throw 'Choose one diagnostic client'}
$original=[IO.File]::ReadAllText((Join-Path $PSScriptRoot $probeName),$encoding)
foreach($level in @('0','2')) {
 $manifest=Join-Path $evidence ('Project'+$level+'.UBE')
 $text="UBE-Project 1`r`nName = `"ManagedTextTest`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nOptimization = `"$level`"`r`n"
 foreach($name in ($modules+@('TextProbe'))){$text+="Source = `"$name.bas`"`r`n"}
 [IO.File]::WriteAllText($manifest,$text,$encoding)
 foreach($negative in @($false,$true)) {
  $source=$original
  if($negative){
   if($AllocationFailure){$source=$original.Replace('If Value <> "retained" Then','If Value <> "incorrect" Then')}
   elseif($Threads){$source=$original.Replace('If After <> "retained payload / worker"','If After <> "incorrect payload / worker"')}
   elseif($Conditions){$source=$original.Replace('Value = Echo("False")','Value = Echo("True")')}
   elseif($Simple){$source=$original.Replace('If Value <> "Hi"','If Value <> "Ho"')}
   else{$source=$original.Replace('Text.Length(Value) <> 4','Text.Length(Value) <> 5')}
   if($source -ceq $original){throw 'Missing negative control marker'}
  }
  [IO.File]::WriteAllText($probe,$source,$encoding)
  $exe=Join-Path $evidence "Probe-$level-$negative.exe"
  if($AllocationFailure){
   $ir=Join-Path $evidence "Probe-$level-$negative.ll"
   Run $CompilerExe @('--emit-llvm',$manifest,$ir)
   $native=[IO.File]::ReadAllText($ir,$encoding)
   $allocation='define internal ptr @ube.memory.new.locked(ptr %ctx, i64 %count, i64 %stride)'
   $entry='define i32 @main()'
   if(-not $native.Contains($allocation) -or -not $native.Contains($entry)){throw 'Missing fault-injection sites'}
   $native=$native.Replace($allocation,'define internal ptr @test.memory.new.locked(ptr %ctx, i64 %count, i64 %stride)').Replace($entry,'define i32 @test.source.main()')
   $native+=@'

@test.failures = global i64 0
define internal ptr @ube.memory.new.locked(ptr %ctx, i64 %count, i64 %stride) {
entry:
 %error = load atomic i64, ptr %ctx monotonic, align 8
 %armed = icmp eq i64 %error, 1234567
 %text = icmp eq i64 %stride, 128
 %reject = and i1 %armed, %text
 br i1 %reject, label %failure, label %allocate
failure:
 %old = atomicrmw add ptr @test.failures, i64 1 monotonic
 ret ptr null
allocate:
 %block = call ptr @test.memory.new.locked(ptr %ctx, i64 %count, i64 %stride)
 ret ptr %block
}
define i32 @main() {
entry:
 %source = call i32 @test.source.main()
 %attempts = load i64, ptr @test.failures
 %two = icmp eq i64 %attempts, 2
 %result = select i1 %two, i32 %source, i32 99
 ret i32 %result
}
'@
   [IO.File]::WriteAllText($ir,$native,$encoding)
   $lib=Join-Path $evidence 'kernel32.lib'
   Run (Join-Path (Split-Path $Clang) 'llvm-dlltool.exe') @('-m','i386:x86-64','-d',(Join-Path $repo 'compiler/llvm/kernel32.def'),'-l',$lib)
   Run $Clang @('--target=x86_64-pc-windows-msvc','-Wno-override-module','-fuse-ld=lld','-nostdlib',('-O'+$level),$ir,$lib,'-o',$exe,'-Wl,/entry:main,/subsystem:console,/stack:8388608')
  }else{Run $CompilerExe @('--build',$manifest,$exe,'--clang',$Clang) -Build}
  $expected=0;if($negative){$expected=1}
  Run $exe @() $expected
 }
 if($AllocationFailure){Write-Output "PASS native String O$level two allocation failures, preserved destination/roots, recovery and changed-value control"}
 elseif($Threads){Write-Output "PASS native String O$level retained array payload, simultaneous collectors and changed retained-value control"}
 elseif($Conditions){Write-Output "PASS native String O$level If/Do Boolean conversion, failure and changed-condition control"}
 elseif($Simple){Write-Output "PASS native String O$level literal/ByVal/result/comparison and changed-value control"}
 else{Write-Output "PASS native String O$level Unicode/value/conversion/failure/collection cases and changed scalar-count control"}
}
