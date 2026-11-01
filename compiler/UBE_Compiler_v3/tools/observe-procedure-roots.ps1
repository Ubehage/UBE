param(
 [Parameter(Mandatory=$true)][string]$ProcedureRootReport,
 [ValidateSet('collections','functions')][string]$Observation='collections'
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$prior=Get-Content -LiteralPath $ProcedureRootReport -Raw | ConvertFrom-Json
if(-not $prior.success -or $prior.schema -cne 'ube-procedure-root-comparison-1'){throw 'Successful procedure-root experiment required'}
foreach($pin in @($prior.inputs)+@($prior.artifacts)){
 $now=Get-ArtifactIdentity $pin.path
 if($now.sha256 -cne $pin.sha256 -or $now.bytes -ne $pin.bytes){throw ('Experimental input changed: '+$pin.path)}
}
$originalDriver=@($prior.link.arguments | Where-Object {$_ -like '*driver.c'})
if($originalDriver.Count -ne 1){throw 'Unique driver path required'}
$originalRuntime=Join-Path (Split-Path $originalDriver[0] -Parent) 'observed_runtime.c'
$run=Join-Path $root ('bootstrap/out/procedure-root-observation/'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $run -Force
$runtime=[IO.File]::ReadAllText($originalRuntime)
$driver=[IO.File]::ReadAllText($originalDriver[0])
$reset='double c0 = cpu_seconds(), t0 = now_seconds();'
$finish='cpu += cpu_seconds() - c0;'
foreach($marker in @($reset,$finish)){if([regex]::Matches($driver,[regex]::Escape($marker)).Count -ne 1){throw 'Unique work observation boundary required'}}
if($Observation -ceq 'collections'){
 $runtime="static unsigned long long probe_collections, probe_collection_requests, probe_collection_failures;`n"+$runtime
 foreach($signature in @('void* ube_gc_allocate(const struct ube_gc_layout* layout) {','static void* ube_gc_allocate_untraced_pending(size_t size) {')){
  if([regex]::Matches($runtime,[regex]::Escape($signature)).Count -ne 1){throw 'Managed allocation observation ABI differs'}
  $runtime=$runtime.Replace($signature,$signature+' __atomic_add_fetch(&probe_collection_requests, 1ull, __ATOMIC_RELAXED); (void)ube_gc_collect();')
 }
 # CollectGarbage's 0/1 return describes whether anything was reclaimed, not
 # whether an empty trace succeeded. Observe completed and failed mark passes.
 $completed='(?m)^(    __atomic_store_n\(&ube_gc_collecting_state,0,__ATOMIC_SEQ_CST\);\r?\n    __atomic_store_n\(&ube_root_registry.collector,0,__ATOMIC_SEQ_CST\);\r?\n)(    ube_gc_leave_lock\(\);\r?\n    return performed;)'
 if([regex]::Matches($runtime,$completed).Count -ne 1){throw 'Unique full collection completion boundary required'}
 $runtime=[regex]::Replace($runtime,$completed,('${1}    ++probe_collections;' + "`n" + '${2}'))
 $failed='if (!ube_gc_mark_roots()) {'
 if([regex]::Matches($runtime,[regex]::Escape($failed)).Count -ne 1){throw 'Unique mark-failure boundary required'}
 $runtime=$runtime.Replace($failed,$failed+' ++probe_collection_failures;')
 $driver=$driver.Replace($reset,'probe_collections = probe_collection_requests = probe_collection_failures = 0; '+$reset)
 $driver=$driver.Replace($finish,$finish+' printf("{\"collections\":%llu,\"collectionRequests\":%llu,\"collectionFailures\":%llu}\n", probe_collections, probe_collection_requests, probe_collection_failures);')
}else{
 $prefix=@'
struct probe_function { const char *name; unsigned long long count; };
static struct probe_function probe_functions[64];
static int probe_function_count, probe_function_overflow;
static void probe_gc_enter(const char *name);
'@
 $runtime=$runtime.Replace('ube_gc_enter_lock();','probe_gc_enter(__func__);')
 $runtime=$prefix+"`n"+$runtime+@'

static void probe_gc_enter(const char *name) {
    ube_gc_enter_lock();
    int i;
    for (i = 0; i < probe_function_count; ++i)
        if (strcmp(probe_functions[i].name, name) == 0) break;
    if (i == probe_function_count) {
        if (i == 64) { probe_function_overflow = 1; return; }
        probe_functions[i].name = name;
        ++probe_function_count;
    }
    ++probe_functions[i].count;
}
'@
 $driver=$driver.Replace($reset,'for(int p = 0; p < probe_function_count; ++p) probe_functions[p].count = 0; '+$reset)
 $print=@'
 printf("{\"functions\":{");
 for(int p = 0; p < probe_function_count; ++p) printf("%s\"%s\":%llu", p ? "," : "", probe_functions[p].name, probe_functions[p].count);
 printf("},\"overflow\":%d}\n", probe_function_overflow);
'@
 # Here-strings above contain C source, not a PowerShell/JSON escaped string.
 $print=$print.Replace('\\','\').Replace('\"','\"')
 $driver=$driver.Replace($finish,$finish+$print)
}
$runtimePath=Join-Path $run 'observed_runtime.c';$driverPath=Join-Path $run 'driver.c'
$utf8=[Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText($runtimePath,$runtime,$utf8);[IO.File]::WriteAllText($driverPath,$driver,$utf8)
$pins=@($prior.inputs)+@($prior.artifacts)+@((Get-ArtifactIdentity $ProcedureRootReport),(Get-ArtifactIdentity $PSCommandPath),(Get-ArtifactIdentity $runtimePath),(Get-ArtifactIdentity $driverPath))
$inputDirectory=Split-Path $originalDriver[0] -Parent
$exe=Join-Path $run 'diagnostic.exe';$link=$null;$rows=@();$success=$false;$failure=$null
try{
 $originalExe=@($prior.artifacts | Where-Object {$_.path -like '*diagnostic.exe'})
 if($originalExe.Count -ne 1){throw 'Unique original executable required'}
 $arguments=@($prior.link.arguments | ForEach-Object {if($_ -ceq $originalDriver[0]){$driverPath}elseif($_ -ceq $originalExe[0].path){$exe}else{$_}})
 if($arguments[-1] -cne $exe){throw 'Exact native link substitution failed'}
 $link=Invoke-BoundedProcess $prior.link.file $arguments $root 180
 if($link.timedOut -or $link.exit -ne 0){throw ('Observation link failed: '+$link.stdout+$link.stderr)}
 foreach($jobs in @(1,2,4)){
  $trial=Invoke-BoundedProcess $exe @((Join-Path $inputDirectory 'focused.inputs'),(Join-Path $inputDirectory 'focused.expected'),([string]$jobs),'1','0') $root 600
  Write-Output $trial.stdout
  if($trial.timedOut -or $trial.exit -ne 0){throw ('Observed UBE work failed: '+$trial.stderr)}
  $parsed=@($trial.stdout -split "`n" | Where-Object {$_} | ForEach-Object {$_ | ConvertFrom-Json})
  if($parsed.Count -ne 3){throw 'Expected observation, cost and result rows'}
  $observationRow=$parsed[0];$cost=$parsed[1];$result=$parsed[2]
  if($cost.enters -ne $cost.leaves -or $cost.enters -le 0 -or -not $result.completeResults -or -not $result.cleanup){throw 'Root balance/complete result/cleanup assertion failed'}
  if($Observation -ceq 'collections'){
   if($observationRow.collections -lt 1 -or $observationRow.collections -ne $observationRow.collectionRequests -or $observationRow.collectionFailures -ne 0){throw 'Requested managed collections did not all complete successfully'}
  }else{
   $sum=0L;foreach($property in $observationRow.functions.PSObject.Properties){$sum+=[long]$property.Value}
   if($observationRow.overflow -ne 0 -or $sum -ne $cost.locks){throw 'Collector callsite counts do not sum to observed locks'}
  }
  $rows+=[pscustomobject]@{jobs=$jobs;observation=$observationRow;cost=$cost;result=$result;process=$trial}
 }
 foreach($pin in $pins){$now=Get-ArtifactIdentity $pin.path;if($now.sha256 -cne $pin.sha256 -or $now.bytes -ne $pin.bytes){throw 'Observation input changed'}}
 $success=$true
}catch{$failure=$_.Exception.Message;throw}finally{
 $report=Join-Path $run 'report.json'
 [pscustomobject]@{schema='ube-procedure-root-observation-1';success=$success;observation=$Observation;productionQualified=$false;performanceAccepted=$false;failure=$failure;inputs=$pins;link=$link;rows=$rows;artifacts=@(Get-ChildItem -LiteralPath $run -File | Where-Object Name -NE 'report.json' | ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Focused actual UBE procedure-root experiment, forced managed collections or observed GC callsites. Instrumented diagnostic only.'} | ConvertTo-Json -Depth 22 | Set-Content -LiteralPath $report -Encoding UTF8
 Write-Output ('Evidence: '+$report)
}
