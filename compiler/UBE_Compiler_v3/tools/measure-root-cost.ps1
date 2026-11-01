param([Parameter(Mandatory=$true)][string]$BaselineReport)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$baseline=Get-Content -LiteralPath $BaselineReport -Raw | ConvertFrom-Json
if(-not $baseline.success -or -not $baseline.frozenBaseline){throw 'A complete frozen pre-optimization baseline is required'}
$selection=$baseline.selection
$selectionPath=Join-Path (Split-Path (Split-Path $selection.manifest.path -Parent) -Parent) 'current.json'
$null=Get-VerifiedBootstrapSelection $selectionPath
# Admit actual frozen build/runtime inputs; never silently reuse changed sources.
foreach($pin in $baseline.inputs){$now=Get-ArtifactIdentity $pin.path;if($now.sha256 -cne $pin.sha256 -or $now.bytes -ne $pin.bytes){throw ('Frozen baseline source changed: '+$pin.path)}}
$build=$baseline.builds[-1]
foreach($pin in @($selection.clang,$selection.unicodeRuntime,$build.raw,$build.entry,$build.exe)){
 $now=Get-ArtifactIdentity $pin.path;if($now.sha256 -cne $pin.sha256 -or $now.bytes -ne $pin.bytes){throw 'Frozen build/tool changed'}
}
$run=Join-Path $root ('bootstrap/out/root-cost/'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $run -Force
$utf8=[Text.UTF8Encoding]::new($false)
$runtimePath=Join-Path $root 'bootstrap/runtime/bootstrap_runtime.c'
$runtime=[IO.File]::ReadAllText($runtimePath)
$declarations=@'
static unsigned long long probe_locks, probe_stripe_locks, probe_enters, probe_leaves, probe_visits, probe_peak;
static void probe_root_admitted(unsigned long long count) {
    __atomic_fetch_add(&probe_enters,1,__ATOMIC_RELAXED);
    unsigned long long previous=__atomic_load_n(&probe_peak,__ATOMIC_RELAXED);
    while(previous<count&&!__atomic_compare_exchange_n(&probe_peak,&previous,count,0,__ATOMIC_RELAXED,__ATOMIC_RELAXED)){}
}
'@
$declarations+="`n"
$runtime=$declarations+$runtime
$lock='EnterCriticalSection(&ube_gc_lock);'
if([regex]::Matches($runtime,[regex]::Escape($lock)).Count -ne 1){throw 'Collector lock observation ABI differs'}
$runtime=$runtime.Replace($lock,$lock+' __atomic_fetch_add(&probe_locks,1,__ATOMIC_RELAXED);')
$stripe='EnterCriticalSection\(&ube_root_registry\.stripes\[(?:index|stripe)\]\.section\);'
if([regex]::Matches($runtime,$stripe).Count -ne 4){throw 'Registry stripe observation ABI differs'}
$runtime=[regex]::Replace($runtime,$stripe,'{${0} __atomic_fetch_add(&probe_stripe_locks,1,__ATOMIC_RELAXED);}')
$enter='(?m)^(\s*if\(__atomic_compare_exchange_n\(&ube_root_registry\.state,&current,current\+1,0,\r?\n\s*__ATOMIC_SEQ_CST,__ATOMIC_SEQ_CST\)\))return 1;'
if([regex]::Matches($runtime,$enter).Count -ne 1){throw 'Root admission observation ABI differs'}
$runtime=[regex]::Replace($runtime,$enter,'${1}{probe_root_admitted((current+1)&UBE_ROOT_COUNT_MASK);return 1;}')
$leave='int32_t ube_gc_root_leave(void*root_storage) {'
if([regex]::Matches($runtime,[regex]::Escape($leave)).Count -ne 1){throw 'Root leave observation ABI differs'}
$runtime=$runtime.Replace($leave,$leave+' __atomic_fetch_add(&probe_leaves,1,__ATOMIC_RELAXED);')
$pattern='(?ms)^static int32_t ube_root_registry_leave_locked\(void\* storage,size_t bucket\) \{.*?^\}'
$found=[regex]::Matches($runtime,$pattern)
if($found.Count -ne 1){throw 'Root leave observation ABI differs'}
$body=$found[0].Value
if([regex]::Matches($body,[regex]::Escape('while(*link!=NULL) {')).Count -ne 1){throw 'Root traversal observation ABI differs'}
$body=$body.Replace('while(*link!=NULL) {','while(*link!=NULL) { __atomic_fetch_add(&probe_visits,1,__ATOMIC_RELAXED);')
$runtime=$runtime.Substring(0,$found[0].Index)+$body+$runtime.Substring($found[0].Index+$found[0].Length)
$runtime=$runtime.Replace('#include "windows/file_primitives.c"','#include "file_primitives.c"').Replace('#include "windows/thread_primitives.c"','#include "thread_primitives.c"')
$observed=Join-Path $run 'observed_runtime.c';[IO.File]::WriteAllText($observed,$runtime,$utf8)
$driverPath=Join-Path $root 'compiler/UBE_Compiler_v3/tests/concurrency/performance.c'
$driver=[IO.File]::ReadAllText($driverPath).Replace('#include "bootstrap_runtime.c"','#include "observed_runtime.c"')
$marker='double c0 = cpu_seconds(), t0 = now_seconds();'
if([regex]::Matches($driver,[regex]::Escape($marker)).Count -ne 1){throw 'Measurement boundary ABI differs'}
$driver=$driver.Replace($marker,'probe_locks = probe_stripe_locks = probe_enters = probe_leaves = probe_visits = 0; probe_peak = ube_gc_root_count; '+$marker)
$marker='cpu += cpu_seconds() - c0;'
$driver=$driver.Replace($marker,$marker+' printf("{\"diagnostic\":\"roots\",\"jobs\":%d,\"locks\":%llu,\"stripeLocks\":%llu,\"enters\":%llu,\"leaves\":%llu,\"linksExamined\":%llu,\"peakRoots\":%llu}\n", jobs, probe_locks, probe_stripe_locks, probe_enters, probe_leaves, probe_visits, probe_peak);')
$adapted=Join-Path $run 'driver.c';[IO.File]::WriteAllText($adapted,$driver,$utf8)
$input=Join-Path $run 'focused.inputs';$writer=[IO.BinaryWriter]::new([IO.File]::Create($input))
try{
 $writer.Write([int]4)
 $source=[IO.File]::ReadAllText((Join-Path $root 'compiler/UBE_Compiler_v3/src/SourceInput.bas'),$utf8)
 for($i=0;$i -lt 4;++$i){$bytes=$utf8.GetBytes(($source -replace 'Attribute UBE_Name = "SourceInput"',('Attribute UBE_Name = "RootInput'+$i+'"')));$writer.Write([int]$bytes.Length);$writer.Write($bytes)}
}finally{$writer.Dispose()}
$pins=@($baseline.inputs)+@((Get-ArtifactIdentity $BaselineReport),(Get-ArtifactIdentity $PSCommandPath),(Get-ArtifactIdentity (Join-Path $root 'compiler/UBE_Compiler_v3/ROOT-COST-PROBE.md')),(Get-ArtifactIdentity $input),(Get-ArtifactIdentity $observed),(Get-ArtifactIdentity $adapted),$build.entry,$build.exe,$selection.clang,$selection.unicodeRuntime)
$success=$false;$failure=$null;$link=$null;$reference=$null;$rows=@();$exe=Join-Path $run 'diagnostic.exe';$expected=Join-Path $run 'focused.expected'
try{
 $flags=@('--target=x86_64-w64-windows-gnu','-O2','-I',$run,'-I',(Join-Path $root 'bootstrap/runtime'),'-I',(Join-Path $root 'bootstrap/runtime/windows'),'-x','ir',$build.entry.path,'-x','c',$adapted,'-x','none',$selection.unicodeRuntime.path,'-o',$exe)
 $link=Invoke-BoundedProcess $selection.clang.path $flags $root 180
 if($link.timedOut -or $link.exit -ne 0){throw ('Diagnostic native link failed: '+$link.stdout+$link.stderr)}
 # The uninstrumented frozen executable creates the reference, not the observer.
 $reference=Invoke-BoundedProcess $build.exe.path @($input,$expected,'1','0','1') $root 600
 if($reference.timedOut -or $reference.exit -ne 0){throw 'Frozen native serial reference failed'}
 foreach($jobs in @(1,2,4)){
  $trial=Invoke-BoundedProcess $exe @($input,$expected,([string]$jobs),'1','0') $root 600
  Write-Output $trial.stdout
  if($trial.timedOut -or $trial.exit -ne 0 -or $trial.stdout -notmatch '"completeResults":true'){throw ('Root-cost diagnostic failed: '+$trial.stderr)}
  $parsed=@($trial.stdout -split "`n" | Where-Object {$_} | ForEach-Object {$_ | ConvertFrom-Json})
  if($parsed.Count -ne 2){throw 'Expected one cost row and one complete-result row'}
  $cost=$parsed[0];$result=$parsed[1]
  if($cost.jobs -ne $jobs -or $cost.enters -le 0 -or $cost.enters -ne $cost.leaves -or $cost.linksExamined -lt $cost.leaves -or ($cost.locks+$cost.stripeLocks) -lt ($cost.enters+$cost.leaves) -or $cost.peakRoots -gt (3+256+$jobs*(128+4096+1))){throw 'Executed root-count/balance/bound assertions failed'}
  if(-not $result.completeResults -or -not $result.cleanup -or $result.jobs -ne $jobs){throw 'Complete-result/cleanup assertion failed'}
  $rows+=[pscustomobject]@{jobs=$jobs;cost=$cost;result=$result;process=$trial}
 }
 foreach($pin in $pins){$now=Get-ArtifactIdentity $pin.path;if($now.sha256 -cne $pin.sha256 -or $now.bytes -ne $pin.bytes){throw ('Diagnostic input changed: '+$pin.path)}}
 $success=$true
}catch{$failure=$_.Exception.Message;throw}finally{
 $report=Join-Path $run 'report.json'
 [pscustomobject]@{schema='ube-root-cost-1';success=$success;performanceAccepted=$false;failure=$failure;inputs=$pins;link=$link;reference=$reference;rows=$rows;artifacts=@(Get-ChildItem -LiteralPath $run -File | Where-Object Name -NE 'report.json' | ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Instrumented executed root/collector cost of actual UBE workers; diagnostic timing only.'} | ConvertTo-Json -Depth 18 | Set-Content -LiteralPath $report -Encoding UTF8
 Write-Output ('Evidence: '+$report)
}
