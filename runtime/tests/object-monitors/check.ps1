# Exercises production object allocation and monitor primitives with bounded coordinated workers.
param([string]$ProgramIR='')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$utf8=New-Object Text.UTF8Encoding($false,$true)
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube object monitors '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $artifacts
Write-Output "Evidence: $artifacts"
$script:sequence=0
function Run([string]$File,[string[]]$Arguments){
 $script:sequence++;$prefix=Join-Path $artifacts ('process-'+$script:sequence)
 $quoted=@($Arguments|ForEach-Object{'"'+$_.Replace('"','\"')+'"'}) -join ' '
 $start=@{FilePath=$File;WorkingDirectory=$artifacts;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$start.ArgumentList=$quoted}
 $p=Start-Process @start
 try{$handle=$p.Handle;if(-not $p.WaitForExit(30000)){$p.Kill();throw "Deadline: $prefix"};$p.Refresh();if($null -eq $p.ExitCode){throw "Missing process exit code: $prefix"};return [pscustomobject]@{Code=$p.ExitCode;Evidence=$prefix;Error=[IO.File]::ReadAllText($prefix+'.stderr')}}finally{$p.Dispose()}
}
$templates=[IO.File]::ReadAllText((Join-Path $root 'compiler/llvm/templates.json'),$utf8)|ConvertFrom-Json
$prefix=($templates|Where-Object{$_.name -eq 'ContextPrefix'}).text
$prefix=$prefix.Replace('{0}','1').Replace('{1}','1').Replace('{2}','6904').Replace('{3}','863')
$prefix=$prefix.Substring(0,$prefix.IndexOf('define i1 @ube.context.dispose'))
$runtime=[IO.File]::ReadAllText((Join-Path $root 'compiler/llvm/windows-runtime.ll'),$utf8)
$probe=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'monitor-probe.ll'),$utf8)
$entry='main'
if($ProgramIR -ne ''){
 $program=[IO.File]::ReadAllText($ProgramIR,$utf8)
 $first=$program.IndexOf('%ube.block = type')
 $last=$program.IndexOf('define internal void @ube.managed.temps.clear',$first)
 if($first -lt 0 -or $last -lt $first -or -not $runtime.StartsWith('%ube.block = type')){throw 'Missing exact runtime boundaries'}
 $runtime=$program.Substring(0,$first)+$runtime+$program.Substring($last)
 $prefix=''
 $entry='monitorgcmain'
 function ReplaceOnce([string]$Text,[string]$Before,[string]$After){
  if([regex]::Matches($Text,[regex]::Escape($Before)).Count -ne 1){throw "Ambiguous collector probe substitution: $Before"}
  return $Text.Replace($Before,$After)
 }
 $probe=ReplaceOnce $probe 'define i32 @main()' 'define i32 @monitorgcmain()'
 $probe=ReplaceOnce $probe '%installed = call i1 @ube.managed.install(ptr @monitor.ctx, ptr @monitor.collector)' '%installed = call i1 @ube.project.init(ptr @monitor.ctx)'
 $probe=ReplaceOnce $probe 'ptr null, i64 8, ptr null, ptr %candidate)' 'ptr @monitor.fields.layout, i64 16, ptr @monitor.cleanup, ptr %candidate)'
 $probe=ReplaceOnce $probe '  store atomic i64 777, ptr @monitor.ctx monotonic, align 8' @'
  %text.created = call i1 @ube.text.create(ptr @monitor.ctx, i64 1, i64 1, ptr %candidate)
  br i1 %text.created, label %text.initialize, label %failed
text.initialize:
  %text.identity = load i64, ptr %candidate, align 8
  %text.written = call i1 @ube.text.write(ptr @monitor.ctx, i64 %text.identity, i64 0, i64 65)
  %object.fields = call ptr @ube.object.address(ptr @monitor.ctx, i64 %identity, ptr @monitor.descriptor)
  %text.field = getelementptr i64, ptr %object.fields, i64 1
  %text.published = call i1 @ube.text.publish(ptr @monitor.ctx, ptr %text.field, i64 %text.identity)
  %text.ready = and i1 %text.written, %text.published
  br i1 %text.ready, label %acquire.object, label %failed
acquire.object:
  store atomic i64 777, ptr @monitor.ctx monotonic, align 8
'@
 $probe=ReplaceOnce $probe 'br i1 %snapshot.ok, label %inner.release, label %failed' @'
br i1 %snapshot.ok, label %collect.waiting, label %failed
collect.waiting:
  %collection = call {i1,i64} @ube.managed.collect(ptr @monitor.ctx, i64 -1)
  %collection.ok = extractvalue {i1,i64} %collection, 0
  %alive.fields = call ptr @ube.object.address(ptr @monitor.ctx, i64 %identity, ptr @monitor.descriptor)
  %alive = icmp ne ptr %alive.fields, null
  %early.cleanups = load i64, ptr @monitor.cleanups, align 8
  %not.cleaned = icmp eq i64 %early.cleanups, 0
  %text.length.result = call {i1,i64} @ube.text.length(ptr @monitor.ctx, ptr %text.field, i1 false)
  %text.length.ok = extractvalue {i1,i64} %text.length.result, 0
  %text.length = extractvalue {i1,i64} %text.length.result, 1
  %text.retained = icmp eq i64 %text.length, 1
  %text.edge.ok = and i1 %text.length.ok, %text.retained
  %survived = and i1 %collection.ok, %alive
  %object.safe = and i1 %survived, %not.cleaned
  %retained.object = and i1 %object.safe, %text.edge.ok
  br i1 %retained.object, label %inner.release, label %failed
'@
 $probe=ReplaceOnce $probe "done:`n  ret i32 42" @'
done:
  call void @ube.managed.store(ptr @monitor.ctx, ptr @monitor.slot, i64 0)
  %reclaimed = call {i1,i64} @ube.managed.collect(ptr @monitor.ctx, i64 -1)
  %reclaim.ok = extractvalue {i1,i64} %reclaimed, 0
  %state = call ptr @ube.managed.state(ptr @monitor.ctx)
  %remaining.record = call ptr @ube.managed.find(ptr %state, i64 %identity)
  %gone = icmp eq ptr %remaining.record, null
  %remaining.text = call ptr @ube.managed.find(ptr %state, i64 %text.identity)
  %text.gone = icmp eq ptr %remaining.text, null
  %cleanups = load i64, ptr @monitor.cleanups, align 8
  %once = icmp eq i64 %cleanups, 1
  %collected.correctly = and i1 %reclaim.ok, %gone
  %cleanup.correctly = and i1 %collected.correctly, %once
  %finished.correctly = and i1 %cleanup.correctly, %text.gone
  br i1 %finished.correctly, label %gc.done, label %failed
gc.done:
  ret i32 42
'@
 $probe+=@'

@monitor.cleanups = global i64 0
@monitor.field.offset = constant i64 1
@monitor.fields.layout = constant %ube.managed.layout {i64 2,i64 1,ptr @monitor.field.offset,i64 0,ptr null,i64 0,ptr null}
define void @monitor.cleanup(ptr %ctx, ptr %payload) {
entry:
  %previous = atomicrmw add ptr @monitor.cleanups, i64 1 seq_cst
  ret void
}
'@
 Write-Output 'Using actual UBE collector: retained object while waiting, then reclaimed after final root removal'
}
$definition=[IO.File]::ReadAllText((Join-Path $root 'compiler/llvm/kernel32.def'),$utf8)
$def=Join-Path $artifacts 'kernel32.def';$lib=Join-Path $artifacts 'kernel32.lib'
[IO.File]::WriteAllText($def,$definition,$utf8)
$llvm='C:\Program Files\LLVM\bin'
$result=Run (Join-Path $llvm 'llvm-dlltool.exe') @('-m','i386:x86-64','-d',$def,'-l',$lib)
if($result.Code -ne 0){throw "Import failure: $($result.Evidence)"}
foreach($level in @('0','2')){
 $ir=Join-Path $artifacts ('monitors-O'+$level+'.ll');$exe=Join-Path $artifacts ('monitors-O'+$level+'.exe')
 [IO.File]::WriteAllText($ir,($prefix+$runtime+"`r`n"+$probe),$utf8)
 $built=Run (Join-Path $llvm 'clang.exe') @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-O'+$level),$ir,$lib,'-o',$exe,("-Wl,/entry:"+$entry+',/subsystem:console,/stack:8388608'))
 if($built.Code -ne 0){throw "Compile failure: $($built.Evidence)`n$($built.Error)"}
 foreach($iteration in 1..3){$ran=Run $exe @();if($ran.Code -ne 42 -or $ran.Error.Length -ne 0){throw "Monitor assertion exit $($ran.Code): $($ran.Evidence)"}}
 Write-Output "PASS O${level}: three Nothing/overflow-output/reentrancy/collector-rendezvous/visibility/Err-preservation probes"
}

# Negative control: a broken release drops the entire reentrant depth on inner exit.
# The same assertions must reject this mutant, independent of worker scheduling.
$original='  %next = sub i64 %depth, 1'
if([regex]::Matches($runtime,[regex]::Escape($original)).Count -ne 1){throw 'Ambiguous monitor mutation site'}
$mutant=$runtime.Replace($original,'  %next = add i64 0, 0')
$ir=Join-Path $artifacts 'monitors-broken-reentrancy.ll'
$exe=Join-Path $artifacts 'monitors-broken-reentrancy.exe'
[IO.File]::WriteAllText($ir,($prefix+$mutant+"`r`n"+$probe),$utf8)
$built=Run (Join-Path $llvm 'clang.exe') @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib','-O2',$ir,$lib,'-o',$exe,("-Wl,/entry:"+$entry+',/subsystem:console,/stack:8388608'))
if($built.Code -ne 0){throw "Negative-control compile failure: $($built.Evidence)`n$($built.Error)"}
$ran=Run $exe @()
if($ran.Code -ne 1 -or $ran.Error.Length -ne 0){throw "Broken reentrancy escaped assertion oracle: $($ran.Evidence)"}
Write-Output 'PASS negative control: premature reentrant release rejected with assertion exit 1'
