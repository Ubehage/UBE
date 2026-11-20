# Links native fault assertions to the actual compiler-emitted ordinary UBE collector.
param([Parameter(Mandatory=$true)][string]$ProgramIR,[switch]$Rendezvous,[switch]$Graph)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube managed faults '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
Write-Output "Evidence: $evidence"
$utf8=New-Object Text.UTF8Encoding($false,$true)
$program=[IO.File]::ReadAllText($ProgramIR,$utf8)
$runtime=[IO.File]::ReadAllText((Join-Path $repo 'compiler/llvm/windows-runtime.ll'),$utf8)
if(-not $program.Contains($runtime)){throw 'Program must contain current canonical runtime exactly'}
if($program -notmatch 'call i1 @ube.managed.install\(ptr %ctx, ptr @ube.proc.\d+\)'){throw 'Missing compiler-bound ordinary UBE collector'}
$probeName='fault-probe.ll';$entry='faultmain'
if($Rendezvous){$probeName='rendezvous-probe.ll';$entry='rendezvousmain'}
if($Graph){$probeName='graph-probe.ll';$entry='graphmain'}
if($Graph -and $Rendezvous){throw 'Choose one assertion suite'}
$probe=[IO.File]::ReadAllText((Join-Path $PSScriptRoot $probeName),$utf8)
$script:sequence=0
function Run([string]$File,[string[]]$Arguments,[int]$Expected=0) {
 $script:sequence++;$prefix=Join-Path $evidence ('process-'+$script:sequence)
 $quoted=($Arguments|ForEach-Object{'"'+$_+'"'}) -join ' '
 $p=Start-Process -FilePath $File -ArgumentList $quoted -WindowStyle Hidden -PassThru -RedirectStandardOutput ($prefix+'.stdout') -RedirectStandardError ($prefix+'.stderr')
 try{$handle=$p.Handle;if(-not $p.WaitForExit(60000)){$p.Kill();throw "Deadline $prefix"};$p.Refresh();if($p.ExitCode -ne $Expected){throw "Expected $Expected, got $($p.ExitCode): $prefix"}}finally{$p.Dispose()}
}
$lib=Join-Path $evidence 'kernel32.lib'
Run 'C:\Program Files\LLVM\bin\llvm-dlltool.exe' @('-m','i386:x86-64','-d',(Join-Path $repo 'compiler/llvm/kernel32.def'),'-l',$lib)
if($Graph){$text=$program}
elseif($Rendezvous){
 $text=$program.Replace('define i1 @ube.managed.begin(ptr %ctx, ptr %prior.work, ptr %prior.error)', 'define i1 @rendezvous.managed.begin(ptr %ctx, ptr %prior.work, ptr %prior.error)')
 $marker='  %more.joiners = add i64 %joiners, 1'
 if(-not $text.Contains($marker)){throw 'Missing join instrumentation point'}
 $text=$text.Replace($marker,"  %join.count = atomicrmw add ptr @rendezvous.joined, i64 1 seq_cst`r`n"+$marker)
}else{
$text=$program.Replace('define ptr @ube.target.allocate(i64 %bytes)', 'define ptr @fault.target.allocate(i64 %bytes)')
$text=$text.Replace('define i1 @ube.target.release(ptr %block)', 'define i1 @fault.target.release(ptr %block)')
$text=$text.Replace('define i1 @ube.managed.edge.count(ptr %ctx, i64 %identity, ptr %output)', 'define i1 @fault.managed.edge.count(ptr %ctx, i64 %identity, ptr %output)')
$text=$text.Replace('define i1 @ube.managed.workspace(ptr %ctx, ptr %array, i64 %count, i64 %preserve)', 'define i1 @fault.managed.workspace(ptr %ctx, ptr %array, i64 %count, i64 %preserve)')
$marker='  %result = call {i1,i64} %procedure(ptr %ctx, i64 %report)'
if(-not $text.Contains($marker)){throw 'Missing collector invocation instrumentation point'}
$text=$text.Replace($marker,"  %fault.count = atomicrmw add ptr @fault.collect.calls, i64 1 seq_cst`r`n"+$marker)
}
foreach($level in @('O0','O2')) {
 foreach($negative in @($false,$true)) {
  $assertions=$probe
  if($negative){
   if($Graph){$assertions=$assertions.Replace('%all.released = icmp eq i64 %cycle.released, 3000','%all.released = icmp eq i64 %cycle.released, 3001')}
   elseif($Rendezvous){$assertions=$assertions.Replace('%joined = icmp eq i64 %joins, 1','%joined = icmp eq i64 %joins, 2')}
   else{$assertions=$assertions.Replace('%two = icmp eq i64 %allocations, 2','%two = icmp eq i64 %allocations, 3')}
  }
  $stem=Join-Path $evidence ($level+'-negative'+$negative)
  [IO.File]::WriteAllText(($stem+'.ll'),$text+$assertions,$utf8)
  Run 'C:\Program Files\LLVM\bin\clang.exe' @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-'+$level),($stem+'.ll'),$lib,'-o',($stem+'.exe'),('-Wl,/entry:'+$entry+',/subsystem:console,/stack:8388608'))
  $expected=0;if($negative){$expected=1}
  Run ($stem+'.exe') @('fault-probe') $expected
  if($Graph){Write-Output "PASS $level actual UBE collector 3000-record cycle, integer nonroot and empty disposal negative=$negative"}
  elseif($Rendezvous){Write-Output "PASS $level actual UBE collector joined round, capsule-only root, per-thread Err and empty disposal negative=$negative"}
  else{Write-Output "PASS $level actual UBE collector allocation retry, workspace abort/recovery, startup refusal and empty disposal negative=$negative"}
 }
}
