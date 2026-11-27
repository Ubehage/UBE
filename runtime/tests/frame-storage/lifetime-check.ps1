param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$encoding=New-Object Text.UTF8Encoding($false,$true)
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube frame lifetime '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $artifacts
Write-Output "Evidence: $artifacts"
$script:sequence=0
function Run([string]$File,[string[]]$Arguments,[int]$Expected=0){
 $script:sequence++;$prefix=Join-Path $artifacts ('process-'+$script:sequence)
 $options=@{FilePath=$File;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=(($Arguments|ForEach-Object{'"'+$_+'"'}) -join ' ')}
 $p=Start-Process @options
 try{
  $handle=$p.Handle
  if(-not $p.WaitForExit(120000)){$p.Kill();$null=$p.WaitForExit(5000);throw "Deadline: $prefix"}
  $p.Refresh();$errors=[IO.File]::ReadAllText($prefix+'.stderr')
  if($p.ExitCode -ne $Expected -or $errors.Length){throw "Exit $($p.ExitCode), expected $Expected; $errors; $prefix"}
 }finally{$p.Dispose()}
}
$source=Join-Path $artifacts 'Lifetime.bas'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Lifetime.bas') -Destination $source
$project=Join-Path $artifacts 'Probe.UBE'
[IO.File]::WriteAllText($project,"UBE-Project 1`r`nName = `"FrameLifetime`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nSource = `"Lifetime.bas`"`r`n",$encoding)
$ir=Join-Path $artifacts 'source.ll'
Run $CompilerExe @('--emit-llvm',$project,$ir)
$original=[IO.File]::ReadAllText($ir,$encoding)
$procedures=[regex]::Matches($original,'(?ms)^define \{ i1, i64 \} @ube\.proc\.[^\r\n]+\{\r?\n.*?^\}')
$targets=@($procedures|Where-Object {$_.Value -match '\b747474\b'})
if($targets.Count -ne 1){throw 'Expected exactly one distinctive Target procedure'}
$target=$targets[0].Value
$allocation='call ptr @ube.memory.new.locked(ptr %ctx, i64 '
if(([regex]::Matches($target,[regex]::Escape($allocation))).Count -ne 1){throw 'Expected one target frame allocation'}
$modifiedTarget=$target.Replace($allocation,'call ptr @test.frame.fail.once(ptr %ctx, i64 ')
$instrumented=$original.Replace($target,$modifiedTarget)
$instrumented=$instrumented.Replace('%frame.owner = call ptr @ube.memory.new.locked(', '%frame.owner = call ptr @test.frame.allocate(')
$instrumented=$instrumented.Replace('call void @ube.block.drop(ptr %ctx, ptr %frame.owner)','call void @test.frame.drop(ptr %ctx, ptr %frame.owner)')
$initialized='  %initialized = call i1 @ube.project.init(ptr @ube.entry.context)'
if(([regex]::Matches($instrumented,[regex]::Escape($initialized))).Count -ne 1){throw 'Expected one project initialization'}
$instrumented=$instrumented.Replace($initialized,$initialized+"`r`n  call void @test.frame.begin(ptr @ube.entry.context)")
$tail='  ret i32 %final.status'
if(([regex]::Matches($instrumented,[regex]::Escape($tail))).Count -ne 1){throw 'Expected one native status publication'}
$shutdown='  call void @ube.thread.root.complete(ptr @ube.entry.context, i1 %fresh.success)'
if(([regex]::Matches($instrumented,[regex]::Escape($shutdown))).Count -ne 1){throw 'Expected one root completion'}
$instrumented=$instrumented.Replace($shutdown,"  %frame.check = call i1 @test.frame.check(ptr @ube.entry.context)`r`n"+$shutdown)
$instrumented=$instrumented.Replace($tail,"  %checked.status = select i1 %frame.check, i32 %final.status, i32 91`r`n  ret i32 %checked.status")
$helpers=@'
@test.frame.live = internal global i64 0, align 8
@test.frame.failed = internal global i1 false, align 1
@test.frame.root = internal global ptr null, align 8
define void @test.frame.begin(ptr %ctx) {
entry:
  %root.ptr = getelementptr %ube.thread, ptr %ctx, i32 0, i32 4
  %root = load ptr, ptr %root.ptr
  store ptr %root, ptr @test.frame.root
  ret void
}
define ptr @test.frame.allocate(ptr %ctx, i64 %cells, i64 %stride) {
entry:
  %block = call ptr @ube.memory.new.locked(ptr %ctx, i64 %cells, i64 %stride)
  %ok = icmp ne ptr %block, null
  br i1 %ok, label %count, label %done
count:
  %old = atomicrmw add ptr @test.frame.live, i64 1 monotonic
  br label %done
done:
  ret ptr %block
}
define ptr @test.frame.fail.once(ptr %ctx, i64 %cells, i64 %stride) {
entry:
  %failed = load i1, ptr @test.frame.failed
  store i1 true, ptr @test.frame.failed
  br i1 %failed, label %retry, label %fail
fail:
  ret ptr null
retry:
  %block = call ptr @test.frame.allocate(ptr %ctx, i64 %cells, i64 %stride)
  ret ptr %block
}
define void @test.frame.drop(ptr %ctx, ptr %block) {
entry:
  %exists = icmp ne ptr %block, null
  br i1 %exists, label %drop, label %done
drop:
  %old = atomicrmw sub ptr @test.frame.live, i64 1 monotonic
  call void @ube.block.drop(ptr %ctx, ptr %block)
  br label %done
done:
  ret void
}
define i1 @test.frame.check(ptr %ctx) {
entry:
  %live = load atomic i64, ptr @test.frame.live monotonic, align 8
  %empty = icmp eq i64 %live, 0
  %depth.ptr = getelementptr %ube.thread, ptr %ctx, i32 0, i32 1
  %depth = load atomic i64, ptr %depth.ptr monotonic, align 8
  %depth.empty = icmp eq i64 %depth, 0
  %root.ptr = getelementptr %ube.thread, ptr %ctx, i32 0, i32 4
  %root = load ptr, ptr %root.ptr
  %root.expected = load ptr, ptr @test.frame.root
  %root.empty = icmp eq ptr %root, %root.expected
  %first = and i1 %empty, %depth.empty
  %all = and i1 %first, %root.empty
  ret i1 %all
}
'@
$instrumented+="`r`n"+$helpers
$library=Join-Path $artifacts 'kernel32.lib'
Run (Join-Path (Split-Path $Clang) 'llvm-dlltool.exe') @('-m','i386:x86-64','-d',(Join-Path (Split-Path $CompilerExe) 'llvm/kernel32.def'),'-l',$library)
foreach($level in @('0','2')){
 foreach($variant in @('positive','negative')){
  $text=$instrumented;$expected=0
  if($variant -eq 'negative'){$text=$text.Replace('%empty = icmp eq i64 %live, 0','%empty = icmp eq i64 %live, 1');$expected=91}
  $path=Join-Path $artifacts ($variant+$level+'.ll');$exe=Join-Path $artifacts ($variant+$level+'.exe')
  [IO.File]::WriteAllText($path,$text,$encoding)
  Run $Clang @('--target=x86_64-pc-windows-msvc','-Wno-override-module','-fuse-ld=lld','-nostdlib',('-O'+$level),$path,$library,'-o',$exe,'-Wl,/entry:main,/subsystem:console,/stack:8388608')
  Run $exe @() $expected
  Write-Output "PASS $variant O${level}: allocation failure/retry, retained String root, depth failure/recovery, balanced frames/roots/depth"
 }
}
