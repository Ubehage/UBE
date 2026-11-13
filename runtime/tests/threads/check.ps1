# Exercises the production native lifecycle asset and injected target failures.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$utf8=New-Object Text.UTF8Encoding($false,$true)
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube native threads '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $artifacts
Write-Output "Evidence: $artifacts"
$script:sequence=0
# Runs only direct native tools with bounded waiting and retained diagnostics.
function Run([string]$File,[string[]]$Arguments){
 $script:sequence++;$prefix=Join-Path $artifacts ('process-'+$script:sequence)
 $quoted=@($Arguments|ForEach-Object{'"'+$_.Replace('"','\"')+'"'}) -join ' '
 $start=@{FilePath=$File;WorkingDirectory=$artifacts;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$start.ArgumentList=$quoted}
 $p=Start-Process @start
 try{$handle=$p.Handle;if(-not $p.WaitForExit(60000)){$p.Kill();throw "Deadline: $prefix"};$p.Refresh();return [pscustomobject]@{Code=$p.ExitCode;Evidence=$prefix;Error=[IO.File]::ReadAllText($prefix+'.stderr')}}finally{$p.Dispose()}
}
$templates=[IO.File]::ReadAllText((Join-Path $root 'compiler/llvm/templates.json'),$utf8)|ConvertFrom-Json
$prefix=($templates|Where-Object{$_.name -eq 'ContextPrefix'}).text
$prefix=$prefix.Replace('{0}','1').Replace('{1}','1').Replace('{2}','6848').Replace('{3}','856')
$prefix=$prefix.Substring(0,$prefix.IndexOf('define i1 @ube.context.dispose'))
$runtime=[IO.File]::ReadAllText((Join-Path $root 'compiler/llvm/windows-runtime.ll'),$utf8)
$threads=''
$probe=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'lifecycle.ll'),$utf8)
$definition=[IO.File]::ReadAllText((Join-Path $root 'compiler/llvm/kernel32.def'),$utf8)
$def=Join-Path $artifacts 'kernel32.def';$lib=Join-Path $artifacts 'kernel32.lib'
[IO.File]::WriteAllText($def,$definition,$utf8)
$llvm='C:\Program Files\LLVM\bin'
$result=Run (Join-Path $llvm 'llvm-dlltool.exe') @('-m','i386:x86-64','-d',$def,'-l',$lib)
if($result.Code -ne 0){throw "Import failure: $($result.Evidence)"}
foreach($level in @('0','2')){
 $ir=Join-Path $artifacts ('threads-O'+$level+'.ll');$exe=Join-Path $artifacts ('threads-O'+$level+'.exe')
 [IO.File]::WriteAllText($ir,($prefix+$runtime+"`r`n"+$threads+"`r`n"+$probe),$utf8)
 $built=Run (Join-Path $llvm 'clang.exe') @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-O'+$level),$ir,$lib,'-o',$exe,'-Wl,/entry:main,/subsystem:console,/stack:8388608')
 if($built.Code -ne 0){throw "Compile failure: $($built.Evidence)`n$($built.Error)"}
 foreach($iteration in 1..10){$ran=Run $exe @();if($ran.Code -ne 42){throw "Probe exit $($ran.Code): $($ran.Evidence)"}}
 Write-Output "PASS O${level}: ten overlap, wait/FAIL, cancellation isolation and complete-owner-cleanup probes"
}
$faultProbe=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'startup-failure.ll'),$utf8)
$createWrapper=@'
define ptr @ube.target.thread.start(ptr %procedure, ptr %argument) {
entry:
 %flag = load atomic i64, ptr @fault.trigger seq_cst, align 8
 %fail = icmp ne i64 %flag, 0
 br i1 %fail, label %failed, label %real
failed:
 %count = atomicrmw add ptr @fault.hits, i64 1 seq_cst
 ret ptr null
real:
 %handle = call ptr @ube.target.thread.start.real(ptr %procedure, ptr %argument)
 ret ptr %handle
}
'@
$allocateWrapper=@'
define ptr @ube.target.allocate(i64 %bytes) {
entry:
 %flag = load atomic i64, ptr @fault.trigger seq_cst, align 8
 %fail = icmp ne i64 %flag, 0
 br i1 %fail, label %failed, label %real
failed:
 %count = atomicrmw add ptr @fault.hits, i64 1 seq_cst
 ret ptr null
real:
 %block = call ptr @ube.target.allocate.real(i64 %bytes)
 ret ptr %block
}
'@
$closeWrapper=@'
@fault.close = global i64 1, align 8
@fault.close.hits = global i64 0, align 8
define i1 @ube.target.thread.close(ptr %handle) {
entry:
 %flag = atomicrmw xchg ptr @fault.close, i64 0 seq_cst
 %fail = icmp ne i64 %flag, 0
 br i1 %fail, label %failed, label %real
failed:
 %count = atomicrmw add ptr @fault.close.hits, i64 1 seq_cst
 ret i1 false
real:
 %closed = call i1 @ube.target.thread.close.real(ptr %handle)
 ret i1 %closed
}
'@
$waitWrapper=@'
@fault.wait = global i64 1, align 8
@fault.wait.hits = global i64 0, align 8
define i32 @ube.target.thread.wait(ptr %handle,i32 %milliseconds) {
entry:
 %flag = atomicrmw xchg ptr @fault.wait,i64 0 seq_cst
 %fail = icmp ne i64 %flag,0
 br i1 %fail,label %failed,label %real
failed:
 %count = atomicrmw add ptr @fault.wait.hits,i64 1 seq_cst
 ret i32 -1
real:
 %status = call i32 @ube.target.thread.wait.real(ptr %handle,i32 %milliseconds)
 ret i32 %status
}
'@
foreach($kind in @('create','allocate','close','wait')){foreach($level in @('0','2')){
 $native=$runtime+"`r`n"+$threads;$wrapper='';$body=$faultProbe
 if($kind -eq 'create'){
  $native=$native.Replace('define ptr @ube.target.thread.start(', 'define ptr @ube.target.thread.start.real(')
  $wrapper=$createWrapper;$body=$body.Replace('EXPECT_ERROR','57').Replace('EXPECT_HITS','1')
 }elseif($kind -eq 'allocate'){
  $native=$native.Replace('define ptr @ube.target.allocate(', 'define ptr @ube.target.allocate.real(')
  $wrapper=$allocateWrapper;$body=$body.Replace('EXPECT_ERROR','7').Replace('EXPECT_HITS','2')
 }elseif($kind -eq 'wait'){
  $native=$native.Replace('define i32 @ube.target.thread.wait(', 'define i32 @ube.target.thread.wait.real(')
  $wrapper=$waitWrapper
  $body=$probe.Replace('%timed.sticky = icmp eq i64 %timed.error, 111','%timed.sticky = icmp eq i64 %timed.error, 57').Replace('%timed.valid = and i1 %timed.ok, %timed.zero',"%timed.failed = xor i1 %timed.ok,true`r`n  %timed.valid = and i1 %timed.failed, %timed.zero")
 }else{
  $native=$native.Replace('define i1 @ube.target.thread.close(', 'define i1 @ube.target.thread.close.real(')
  $wrapper=$closeWrapper;$body=$probe.Replace('  %wait.a.all = and i1 %wait.a.failed, %wait.a.code',@'
  %wait.a.primary = and i1 %wait.a.failed, %wait.a.code
  %fault.hits = load atomic i64, ptr @fault.close.hits seq_cst, align 8
  %fault.reached = icmp eq i64 %fault.hits, 1
  %fault.record = call ptr @ube.thread.record.find(ptr @probe.context, i64 %a.id)
  %fault.handle.ptr = getelementptr %ube.worker, ptr %fault.record, i32 0, i32 2
  %fault.handle = load ptr, ptr %fault.handle.ptr, align 8
  %fault.retained = icmp ne ptr %fault.handle, null
  %fault.correct = and i1 %fault.reached, %fault.retained
  %wait.a.all = and i1 %wait.a.primary, %fault.correct
'@)
 }
 $ir=Join-Path $artifacts ($kind+'-O'+$level+'.ll');$exe=Join-Path $artifacts ($kind+'-O'+$level+'.exe')
 [IO.File]::WriteAllText($ir,($prefix+$native+"`r`n"+$wrapper+"`r`n"+$body),$utf8)
 $built=Run (Join-Path $llvm 'clang.exe') @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-O'+$level),$ir,$lib,'-o',$exe,'-Wl,/entry:main,/subsystem:console,/stack:8388608')
 if($built.Code -ne 0){throw "Fault compile failure: $($built.Evidence)`n$($built.Error)"}
 $ran=Run $exe @();if($ran.Code -ne 42){throw "Fault $kind O$level exit $($ran.Code): $($ran.Evidence)"}
 Write-Output "PASS $kind O$level injected failure, retained ownership and full recovery"
}}
$coordination=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'coordination.ll'),$utf8)
foreach($level in @('0','2')){foreach($negative in @($false,$true)){
 $body=$coordination;if($negative){$body=$body.Replace('%child = icmp eq i64 %mark,73','%child = icmp eq i64 %mark,74')}
 $stem='coordination-O'+$level+'-'+$negative
 $ir=Join-Path $artifacts ($stem+'.ll');$exe=Join-Path $artifacts ($stem+'.exe')
 [IO.File]::WriteAllText($ir,($prefix+$runtime+"`r`n"+$body),$utf8)
 $built=Run (Join-Path $llvm 'clang.exe') @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-O'+$level),$ir,$lib,'-o',$exe,'-Wl,/entry:main,/subsystem:console,/stack:8388608')
 if($built.Code -ne 0){throw "Coordination compile failure: $($built.Evidence)`n$($built.Error)"}
 $ran=Run $exe @();$expected=42;if($negative){$expected=97}
 if($ran.Code -ne $expected){throw "Coordination O$level negative${negative} exit $($ran.Code): $($ran.Evidence)"}
 Write-Output "PASS coordination O${level} negative${negative}: simultaneous waiters, Err0 fresh FAIL, stop-wait wakeup, disposal refusal, nested ignored worker drain and empty heap"
}}
$context=($templates|Where-Object{$_.name -eq 'ContextPrefix'}).text
$context=$context.Replace('{0}','1').Replace('{1}','1').Replace('{2}','6848').Replace('{3}','856')
$context+=($templates|Where-Object{$_.name -eq 'ContextMiddle'}).text
$context+=($templates|Where-Object{$_.name -eq 'ContextSuffix'}).text
$entry=($templates|Where-Object{$_.name -eq 'Entry'}).text.Replace('{0}','17').Replace('@main()','@entry.generated()')
$entryProbe=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'entry.ll'),$utf8)
foreach($level in @('0','2')){foreach($outcome in @('success','failure','zero','wait-retry','wait-regression')){
 $success='false';$number='42';$worker='42';$status='1'
 if($outcome -eq 'success' -or $outcome -eq 'wait-retry' -or $outcome -eq 'wait-regression'){$success='true';$worker='0';$status='23'}
 if($outcome -eq 'zero'){$number='0';$worker='0'}
 $body=$entryProbe.Replace('MAIN_SUCCESS',$success).Replace('MAIN_ERROR',$number).Replace('WORKER_ERROR',$worker).Replace('EXPECTED_STATUS',$status)
 $native=$runtime
 if($outcome -eq 'wait-retry' -or $outcome -eq 'wait-regression'){
  $entryWait=$waitWrapper.Replace(' ret i32 -1'," store atomic i64 1,ptr @fault.wait.release release,align 8`r`n ret i32 -1")
  $native=$native.Replace('define i32 @ube.target.thread.wait(', 'define i32 @ube.target.thread.wait.real(')+"`r`n"+$entryWait
  if($outcome -eq 'wait-regression'){$native=$native.Replace('br i1 %released, label %advance, label %retained','br i1 %released, label %advance, label %failed')}
  $body=$body.Replace(' %id = load i64,ptr %payload,align 8'," call void @entry.await.release()`r`n %id = load i64,ptr %payload,align 8")
  $body=$body.Replace(' %all = and i1 %a,%b'," %base = and i1 %a,%b`r`n %fault.hits = load atomic i64,ptr @fault.wait.hits seq_cst,align 8`r`n %fault.once = icmp eq i64 %fault.hits,1`r`n %all = and i1 %base,%fault.once")
  if($outcome -eq 'wait-regression'){$body=$body.Replace(' ret i32 %exit'," %recovered = call i1 @ube.thread.drain(ptr @ube.entry.context)`r`n %released = call i1 @ube.context.dispose(ptr @ube.entry.context)`r`n ret i32 %exit")}
  $body+=@'

@fault.wait.release = global i64 0,align 8
define void @entry.await.release() {
entry:
 br label %poll
poll:
 %flag = load atomic i64,ptr @fault.wait.release acquire,align 8
 %ready = icmp ne i64 %flag,0
 br i1 %ready,label %done,label %pause
pause:
 call void @Sleep(i32 1)
 br label %poll
done:
 call void @Sleep(i32 50)
 ret void
}
'@
 }
 $stem='entry-'+$outcome+'-O'+$level;$ir=Join-Path $artifacts ($stem+'.ll');$exe=Join-Path $artifacts ($stem+'.exe')
 [IO.File]::WriteAllText($ir,($context+$native+"`r`n"+$entry+$body),$utf8)
 $built=Run (Join-Path $llvm 'clang.exe') @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-O'+$level),$ir,$lib,'-o',$exe,'-Wl,/entry:main,/subsystem:console,/stack:8388608')
 if($built.Code -ne 0){throw "Entry compile failure: $($built.Evidence)`n$($built.Error)"}
 $expected=42;if($outcome -eq 'wait-regression'){$expected=99}
 $ran=Run $exe @();if($ran.Code -ne $expected){throw "Entry $outcome O$level exit $($ran.Code): $($ran.Evidence)"}
 if($outcome -eq 'wait-regression'){
  Write-Output "PASS generated entry old-drain negative O${level}: early return rejected before test-only recovery joins and disposes workers"
 }else{
  Write-Output "PASS generated entry $outcome O${level}: ignored worker observes root outcome before drain, disposal empties heap and preserves root Err"
 }
}}
Write-Output 'Production native lifecycle boundary; source CallNew and compiler concurrency require their separate acceptance gates.'
