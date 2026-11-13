# Qualifies shared runtime storage with real native threads; this is not source CallNew acceptance.
param(
 [Parameter(Mandatory=$true)][string]$BootstrapExe,
 [string]$Clang='C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$enc=New-Object Text.UTF8Encoding($false,$true)
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube shared storage '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $artifacts
$script:process=0;$script:assertions=0
# Stops on an independently specified failed observation.
function Require([bool]$Condition,[string]$Message){$script:assertions++;if(-not $Condition){throw $Message}}
# Writes exact UTF-8 test inputs and retained native evidence.
function Write-Text([string]$Path,[string]$Text){[IO.File]::WriteAllText($Path,$Text,$enc)}
# Encodes literal Windows argv without invoking a command shell.
function Quote([string]$Value){if($Value -notmatch '[\s"]'){return $Value};$s=[regex]::Replace($Value,'(\\*)"','$1$1\"');$s=[regex]::Replace($s,'(\\+)$','$1$1');return '"'+$s+'"'}
# Bounds a hidden child and captures exact output with a retained process handle.
function Run([string]$File,[string[]]$Arguments,[int]$Deadline=60000){
 $script:process++;$prefix=Join-Path $artifacts ('process-'+$script:process)
 $options=@{FilePath=$File;WorkingDirectory=$artifacts;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=(($Arguments|ForEach-Object{Quote $_}) -join ' ')}
 $p=Start-Process @options
 try{$handle=$p.Handle;if(-not $p.WaitForExit($Deadline)){$p.Kill();$null=$p.WaitForExit(5000);throw "Native deadline exceeded: $prefix"};$p.Refresh();Require ($null -ne $p.ExitCode) "No retained exit code: $handle";return [pscustomobject]@{ExitCode=$p.ExitCode;Stdout=[IO.File]::ReadAllText($prefix+'.stdout',$enc);Stderr=[IO.File]::ReadAllText($prefix+'.stderr',$enc);Evidence=$prefix}}finally{$p.Dispose()}
}
Write-Output "Evidence: $artifacts"
$sources=@('std-lib/src/portable/FilePrimitives.bas','bootstrap/tests/shared-storage/Probe.bas')
$manifest=Join-Path $artifacts 'project.UBE';$lines=@('UBE-Project 1','Name = "SharedStorage"','Kind = "Library"','Optimization = "0"')
foreach($source in $sources){$leaf=[IO.Path]::GetFileName($source);Copy-Item -LiteralPath (Join-Path $root $source) -Destination (Join-Path $artifacts $leaf);$lines+='Source = "'+$leaf+'"'}
Write-Text $manifest (($lines -join "`r`n")+"`r`n")
$base=Join-Path $artifacts 'source.ll';$emission=Run $BootstrapExe @('--emit-llvm',$manifest,$base);Require ($emission.ExitCode -eq 0) "Source emission failed: $($emission.Evidence)"
$binding=Run $BootstrapExe @('--dump-bound',$manifest);Require ($binding.ExitCode -eq 0) 'Binding failed'
$ids=@{};foreach($line in ($binding.Stdout -split '\r?\n')){if($line.StartsWith('SYMBOL ')){$fields=$line.Substring(7).Split('|');if($fields[1] -eq 'function' -and $fields[2] -in @('Prepare','Work','Value')){$ids[$fields[2]]=$fields[0]}}}
foreach($name in @('Prepare','Work','Value')){Require $ids.ContainsKey($name) "Missing source function $name"}
$ir=[IO.File]::ReadAllText($base,$enc)
# Fault wrappers affect only this test image and count every successful allocation/release atomically.
$ir=$ir.Replace('define ptr @ube.target.allocate(','define ptr @ube.target.allocate.real(').Replace('define i1 @ube.target.release(','define i1 @ube.target.release.real(')
$support=@'
@test.fail = global i64 0, align 8
@test.failures = global i64 0, align 8
@test.live = global i64 0, align 8
@test.ready = global i64 0, align 8
@test.go = global i64 0, align 8
@test.contended = global i64 0, align 8
@test.hold = global i64 0, align 8
@test.claimed = global i64 0, align 8
define ptr @ube.target.allocate(i64 %bytes) {
entry:
 %fail = load atomic i64, ptr @test.fail acquire, align 8
 %fault = icmp ne i64 %fail, 0
 br i1 %fault, label %failed, label %allocate
failed:
 %old.failed = atomicrmw add ptr @test.failures, i64 1 monotonic
 ret ptr null
allocate:
 %block = call ptr @ube.target.allocate.real(i64 %bytes)
 %ok = icmp ne ptr %block, null
 br i1 %ok, label %count, label %done
count:
 %old = atomicrmw add ptr @test.live, i64 1 monotonic
 br label %done
done:
 ret ptr %block
}
define i1 @ube.target.release(ptr %block) {
entry:
 %ok = call i1 @ube.target.release.real(ptr %block)
 br i1 %ok, label %count, label %done
count:
 %old = atomicrmw sub ptr @test.live, i64 1 monotonic
 br label %done
done:
 ret i1 %ok
}
%test.task = type { %ube.thread, i64, i64, i64 }
@test.first = global %ube.context zeroinitializer, align 8
@test.second = global %ube.context zeroinitializer, align 8
@test.a = global %test.task zeroinitializer, align 8
@test.b = global %test.task zeroinitializer, align 8
define i32 @test.worker(ptr %task) {
entry:
 %mode.ptr = getelementptr %test.task, ptr %task, i32 0, i32 1
 %expected.ptr = getelementptr %test.task, ptr %task, i32 0, i32 2
 %result.ptr = getelementptr %test.task, ptr %task, i32 0, i32 3
 %mode = load i64, ptr %mode.ptr
 %expected = load i64, ptr %expected.ptr
 %previous = atomicrmw add ptr @test.ready, i64 1 release
 br label %wait
wait:
 %go = load atomic i64, ptr @test.go acquire, align 8
 %ready = icmp ne i64 %go, 0
 br i1 %ready, label %run, label %wait
run:
 %pair = call {i1,i64} @ube.proc.WORK(ptr %task,i64 %mode,i64 %expected)
 %fresh = extractvalue {i1,i64} %pair,0
 %value = extractvalue {i1,i64} %pair,1
 %result = select i1 %fresh,i64 %value,i64 98
 store atomic i64 %result,ptr %result.ptr release,align 8
 ret i32 0
}
define i1 @test.run(i64 %fault, i1 %separate, i64 %expected.result) {
entry:
 %first.program = call ptr @ube.thread.program(ptr @test.first)
 %other.root = select i1 %separate,ptr @test.second,ptr @test.first
 %second.program = call ptr @ube.thread.program(ptr %other.root)
 call void @ube.thread.init(ptr @test.a,ptr %first.program,ptr null)
 call void @ube.thread.init(ptr @test.b,ptr %second.program,ptr null)
 %a.mode = getelementptr %test.task,ptr @test.a,i32 0,i32 1
 %a.expected = getelementptr %test.task,ptr @test.a,i32 0,i32 2
 %a.result = getelementptr %test.task,ptr @test.a,i32 0,i32 3
 %b.mode = getelementptr %test.task,ptr @test.b,i32 0,i32 1
 %b.expected = getelementptr %test.task,ptr @test.b,i32 0,i32 2
 %b.result = getelementptr %test.task,ptr @test.b,i32 0,i32 3
 %expected = select i1 %separate,i64 99,i64 42
 store i64 0,ptr %a.mode
 store i64 42,ptr %a.expected
 store i64 97,ptr %a.result
 store i64 1,ptr %b.mode
 store i64 %expected,ptr %b.expected
 store i64 97,ptr %b.result
 store atomic i64 0,ptr @test.ready release,align 8
 store atomic i64 0,ptr @test.go release,align 8
 store atomic i64 0,ptr @test.contended release,align 8
 store atomic i64 0,ptr @test.claimed release,align 8
 %shared = xor i1 %separate,true
 %hold = zext i1 %shared to i64
 store atomic i64 %hold,ptr @test.hold release,align 8
 store atomic i64 %fault,ptr @test.fail release,align 8
 %ha = call ptr @CreateThread(ptr null,i64 8388608,ptr @test.worker,ptr @test.a,i32 65536,ptr null)
 %hb = call ptr @CreateThread(ptr null,i64 8388608,ptr @test.worker,ptr @test.b,i32 65536,ptr null)
 %a.ok = icmp ne ptr %ha,null
 %b.ok = icmp ne ptr %hb,null
 %both = and i1 %a.ok,%b.ok
 br i1 %both,label %ready,label %failed
ready:
 %count = load atomic i64,ptr @test.ready acquire,align 8
 %started = icmp eq i64 %count,2
 br i1 %started,label %go,label %ready
go:
 store atomic i64 1,ptr @test.go release,align 8
 %wa = call i32 @WaitForSingleObject(ptr %ha,i32 15000)
 %wb = call i32 @WaitForSingleObject(ptr %hb,i32 15000)
 %ca = call i32 @CloseHandle(ptr %ha)
 %cb = call i32 @CloseHandle(ptr %hb)
 store atomic i64 0,ptr @test.fail release,align 8
 store atomic i64 0,ptr @test.hold release,align 8
 %av = load atomic i64,ptr %a.result acquire,align 8
 %bv = load atomic i64,ptr %b.result acquire,align 8
 %ag = icmp eq i64 %av,%expected.result
 %bg = icmp eq i64 %bv,%expected.result
 %wg = or i32 %wa,%wb
 %joined = icmp eq i32 %wg,0
 %ac = icmp ne i32 %ca,0
 %bc = icmp ne i32 %cb,0
 %closed = and i1 %ac,%bc
 %values = and i1 %ag,%bg
 %children = and i1 %joined,%closed
 %complete = and i1 %values,%children
 ret i1 %complete
failed:
 store atomic i64 1,ptr @test.go release,align 8
 ret i1 false
}
@test.box = global ptr null
define i32 @test.box.worker(ptr %ctx) {
entry:
 %box = load ptr,ptr @test.box
 call void @ube.box.drop(ptr %ctx,ptr %box,i1 true)
 ret i32 0
}
define i1 @test.box.owners(i1 %caller.last) {
entry:
 %worker = alloca %ube.thread,align 8
 %program = call ptr @ube.thread.program(ptr @test.first)
 call void @ube.thread.init(ptr %worker,ptr %program,ptr null)
 %box = call ptr @ube.memory.new(ptr @test.first,i64 4,i64 1)
 %allocated = icmp ne ptr %box,null
 br i1 %allocated,label %prepare,label %failed
prepare:
 %array = getelementptr %ube.block,ptr %box,i64 1
 %resized = call i1 @ube.array.tryresize(ptr @test.first,ptr %array,i64 2,i64 0,i64 1)
 %snapshot = call {i64,i64,ptr,ptr} @ube.array.snapshot(ptr @test.first,ptr %array)
 %data = extractvalue {i64,i64,ptr,ptr} %snapshot,2
 %pin = extractvalue {i64,i64,ptr,ptr} %snapshot,3
 store atomic i64 543,ptr %data monotonic,align 8
 call void @ube.block.retain(ptr %box)
 store ptr %box,ptr @test.box
 br i1 %caller.last,label %start,label %caller.first
caller.first:
 call void @ube.box.drop(ptr @test.first,ptr %box,i1 true)
 br label %start
start:
 %handle = call ptr @CreateThread(ptr null,i64 8388608,ptr @test.box.worker,ptr %worker,i32 65536,ptr null)
 %wait = call i32 @WaitForSingleObject(ptr %handle,i32 15000)
 %closed = call i32 @CloseHandle(ptr %handle)
 br i1 %caller.last,label %caller.drop,label %collect
caller.drop:
 call void @ube.box.drop(ptr @test.first,ptr %box,i1 true)
 br label %collect
collect:
 %collected = call i1 @ube.memory.collect(ptr @test.first)
 %value = load atomic i64,ptr %data monotonic,align 8
 %preserved = icmp eq i64 %value,543
 %refs.ptr = getelementptr %ube.block,ptr %pin,i32 0,i32 1
 %refs = load atomic i64,ptr %refs.ptr acquire,align 8
 %one = icmp eq i64 %refs,1
 call void @ube.block.drop(ptr @test.first, ptr %pin)
 %released = call i1 @ube.memory.collect(ptr @test.first)
 %joined = icmp eq i32 %wait,0
 %close.ok = icmp ne i32 %closed,0
 %a = and i1 %preserved,%one
 %b = and i1 %joined,%close.ok
 %ok = and i1 %a,%b
 ret i1 %ok
failed:
 ret i1 false
}
define i32 @main() {
entry:
 call void @ube.context.init(ptr @test.first)
 call void @ube.context.init(ptr @test.second)
 %last.worker = call i1 @test.box.owners(i1 false)
 %last.caller = call i1 @test.box.owners(i1 true)
 %box.owners = and i1 %last.worker,%last.caller
 %ia = call i1 @ube.project.init(ptr @test.first)
 %ib = call i1 @ube.project.init(ptr @test.second)
 %pa = call {i1,i64} @ube.proc.PREPARE(ptr @test.first,i64 42)
 %pb = call {i1,i64} @ube.proc.PREPARE(ptr @test.second,i64 99)
 store i64 77,ptr @test.first
 store i64 88,ptr @test.second
 %normal = call i1 @test.run(i64 0,i1 false,i64 0)
 %contended = load atomic i64,ptr @test.contended acquire,align 8
 %overlap = icmp ugt i64 %contended,0
 %fault = call i1 @test.run(i64 1,i1 false,i64 7)
 %failures = load atomic i64,ptr @test.failures acquire,align 8
 %injected = icmp eq i64 %failures,4
 %recovery = call i1 @test.run(i64 0,i1 true,i64 0)
 %va = call {i1,i64} @ube.proc.VALUE(ptr @test.first)
 %vb = call {i1,i64} @ube.proc.VALUE(ptr @test.second)
 %a = extractvalue {i1,i64} %va,1
 %b = extractvalue {i1,i64} %vb,1
 %ag = icmp eq i64 %a,EXPECTED
 %bg = icmp eq i64 %b,99
 %ea = load i64,ptr @test.first
 %eb = load i64,ptr @test.second
 %eag = icmp eq i64 %ea,77
 %ebg = icmp eq i64 %eb,88
 %da = call i1 @ube.context.dispose(ptr @test.first)
 %db = call i1 @ube.context.dispose(ptr @test.second)
 %live = load atomic i64,ptr @test.live acquire,align 8
 %zero = icmp eq i64 %live,0
 %s0 = and i1 %normal,%overlap
 %s1 = and i1 %fault,%injected
 %s2 = and i1 %recovery,%ag
 %s3 = and i1 %bg,%eag
 %s4 = and i1 %ebg,%da
 %s5 = and i1 %db,%zero
 %s6 = and i1 %s0,%s1
 %s7 = and i1 %s2,%s3
 %s8 = and i1 %s4,%s5
 %s9 = and i1 %s6,%s7
 %all = and i1 %s9,%s8
 %with.box = and i1 %all,%box.owners
 %exit = select i1 %with.box,i32 0,i32 99
 ret i32 %exit
}
'@
$support=$support.Replace('@ube.proc.WORK','@ube.proc.'+$ids.Work).Replace('@ube.proc.PREPARE','@ube.proc.'+$ids.Prepare).Replace('@ube.proc.VALUE','@ube.proc.'+$ids.Value)
# Delay one acquired metadata lock until the second native worker contends on that exact lock.
$lock=[regex]::Match($ir,'(?ms)^define internal void @ube.program.storage.lock\([^\r\n]*\r?\n.*?^}')
Require $lock.Success 'Missing unique production storage lock'
$observed=$lock.Value.Replace('br i1 %won, label %done, label %attempt',"br i1 %won, label %done, label %contended`r`ncontended:`r`n  %collision = atomicrmw add ptr @test.contended, i64 1 monotonic`r`n  br label %attempt")
$observed=$observed.Replace("done:`r`n  ret void",@'
done:
  %hold = load atomic i64,ptr @test.hold acquire,align 8
  %enabled = icmp ne i64 %hold,0
  br i1 %enabled,label %claim,label %finish
claim:
  %prior = atomicrmw xchg ptr @test.claimed,i64 1 acq_rel
  %first = icmp eq i64 %prior,0
  br i1 %first,label %observe,label %finish
observe:
  %collisions = load atomic i64,ptr @test.contended acquire,align 8
  %seen = icmp ne i64 %collisions,0
  br i1 %seen,label %finish,label %observe
finish:
  ret void
'@)
$ir=$ir.Replace($lock.Value,$observed)
$definition=Join-Path $artifacts 'kernel32.def';$library=Join-Path $artifacts 'kernel32.lib'
Write-Text $definition ([IO.File]::ReadAllText((Join-Path $root 'compiler/llvm/kernel32.def'),$enc))
$dlltool=Join-Path ([IO.Path]::GetDirectoryName($Clang)) 'llvm-dlltool.exe';$lib=Run $dlltool @('-m','i386:x86-64','-d',$definition,'-l',$library);Require ($lib.ExitCode -eq 0) 'Test import archive failed'
foreach($level in @('O0','O2')){foreach($expected in @(42,43)){
 $input=Join-Path $artifacts ($level+'-'+$expected+'.ll');$exe=Join-Path $artifacts ($level+'-'+$expected+'.exe')
 Write-Text $input ($ir+"`r`n"+$support.Replace('EXPECTED',[string]$expected))
 $build=Run $Clang @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-'+$level),$input,$library,'-o',$exe,'-Wl,/entry:main,/subsystem:console,/stack:8388608')
 Require ($build.ExitCode -eq 0) "Native build failed: $($build.Evidence)"
 $run=Run $exe @();$wanted=0;if($expected -eq 43){$wanted=99}
 Require ($run.ExitCode -eq $wanted -and $run.Stdout -eq '' -and $run.Stderr -eq '') "Shared storage $level observation failed: $($run.Evidence), exit $($run.ExitCode)"
 Write-Output "PASS $level expected${expected}: real shared-lock contention, retained arrays, isolated Err/programs, four injected failures, recovery and zero live allocations"
}}
Write-Output "PASS $script:assertions shared-storage harness assertions; evidence: $artifacts"
