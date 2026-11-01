param([string]$SelectionPath=(Join-Path $PSScriptRoot '../../../bootstrap/out/v2/current.json'))
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$selection=Get-VerifiedBootstrapSelection $SelectionPath
$run=Join-Path $root ('bootstrap/out/borrowed-lifetimes/'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $run -Force
$fixture=Join-Path $root 'std-lib/tests/managed-storage'
$casesPath=Join-Path $fixture 'cases.json'
$cases=@((Get-Content -LiteralPath $casesPath -Raw | ConvertFrom-Json).positive | ForEach-Object {[pscustomobject]@{name=$_.name;source=(Join-Path $fixture $_.source);stdout=$_.stdout}})
$classPath=Join-Path $root 'compiler/UBE_Compiler_v3/tests/concurrency/BorrowedStorage.cls'
$modulePath=Join-Path $root 'compiler/UBE_Compiler_v3/tests/concurrency/BorrowedLifetime.bas'
$project=Join-Path $run 'BorrowedLifetime.UBE'
$utf8=[Text.UTF8Encoding]::new($false)
Copy-Item -LiteralPath $classPath -Destination $run;Copy-Item -LiteralPath $modulePath -Destination $run
[IO.File]::WriteAllText($project,"UBE-Project 1`nName = ""BorrowedLifetime""`nKind = ""Exe""`nStartup = ""Main""`nSource = ""BorrowedStorage.cls""`nSource = ""BorrowedLifetime.bas""`n",$utf8)
$cases+=[pscustomobject]@{name='class-owner-borrows';source=$project;stdout="65`n88`n7`n72`n2`n9`n"}
$runtimeSource=Join-Path $root 'bootstrap/runtime/bootstrap_runtime.c'
$runtime=[IO.File]::ReadAllText($runtimeSource)
foreach($signature in @('void* ube_gc_allocate(const struct ube_gc_layout* layout) {','static void* ube_gc_allocate_untraced_pending(size_t size) {')){
 if([regex]::Matches($runtime,[regex]::Escape($signature)).Count -ne 1){throw 'Managed-allocation collection ABI differs'}
 $runtime=$runtime.Replace($signature,$signature+' if (lifetime_force) { __atomic_add_fetch(&lifetime_collection_requests, 1ull, __ATOMIC_RELAXED); (void)ube_gc_collect(); }')
}
$runtime="static int lifetime_force;`nstatic unsigned long long lifetime_collections, lifetime_collection_requests, lifetime_collection_failures;`nstatic void lifetime_check_watches(void);`n"+$runtime
$completed='(?m)^(    __atomic_store_n\(&ube_gc_collecting_state,0,__ATOMIC_SEQ_CST\);\r?\n    __atomic_store_n\(&ube_root_registry.collector,0,__ATOMIC_SEQ_CST\);\r?\n)(    ube_gc_leave_lock\(\);\r?\n    return performed;)'
if([regex]::Matches($runtime,$completed).Count -ne 1){throw 'Unique full collection completion boundary required'}
$runtime=[regex]::Replace($runtime,$completed,('${1}    lifetime_check_watches(); ++lifetime_collections;' + "`n" + '${2}'))
$failed='if (!ube_gc_mark_roots()) {'
if([regex]::Matches($runtime,[regex]::Escape($failed)).Count -ne 1){throw 'Unique mark-failure boundary required'}
$runtime=$runtime.Replace($failed,$failed+' ++lifetime_collection_failures;')
$runtime=$runtime.Replace('#include "windows/file_primitives.c"','#include "file_primitives.c"').Replace('#include "windows/thread_primitives.c"','#include "thread_primitives.c"')
$runtime+=@'

void lifetime_enable(int force) { lifetime_force = force; }
unsigned long long lifetime_collection_count(void) { return lifetime_collections; }
unsigned long long lifetime_request_count(void) { return lifetime_collection_requests; }
unsigned long long lifetime_collection_failure_count(void) { return lifetime_collection_failures; }
size_t lifetime_root_count(void) { return ube_gc_root_count; }
struct lifetime_watch { void *address; int role; };
static _Thread_local struct lifetime_watch lifetime_watches[4];
static _Thread_local int lifetime_watch_depth;
static unsigned long long lifetime_watch_checks;
void lifetime_watch(void *address, int role) {
    if (lifetime_watch_depth == 4) { fputs("lifetime: watch capacity exceeded\n", stderr); exit(93); }
    lifetime_watches[lifetime_watch_depth++] = (struct lifetime_watch){address, role};
}
void lifetime_unwatch(void) {
    if (!lifetime_watch_depth) { fputs("lifetime: unmatched watch exit\n", stderr); exit(93); }
    --lifetime_watch_depth;
}
static void lifetime_check_watches(void) {
    /* Called under the collector lock after sweeping. Watches deliberately
       retain no reference and never dereference a potentially dead address. */
    for (int i = 0; i < lifetime_watch_depth; ++i) {
        const struct lifetime_watch *watch = &lifetime_watches[i];
        uintptr_t address = (uintptr_t)watch->address;
        int found = 0;
        for (struct ube_gc_header *h = ube_gc_allocations; h; h = h->next) {
            uintptr_t start = (uintptr_t)h->data;
            if (address < start || address - start >= h->payload_size) continue;
            if (watch->role == 1)
                found = h->element_layout && h->element_layout->size == 1 &&
                        address - start >= sizeof(struct ube_array);
            if (watch->role == 2)
                found = address == start && h->layout && h->payload_size == sizeof(void *) &&
                        h->layout->slot_count == 1 && h->layout->slot_offsets[0] == 0;
            if (found) break;
        }
        ++lifetime_watch_checks;
        if (!found) { fputs("lifetime: unretained managed borrow\n", stderr); exit(92); }
    }
}
unsigned long long lifetime_watch_count(void) { return lifetime_watch_checks; }
int lifetime_watch_remaining(void) { return lifetime_watch_depth; }
void lifetime_watch_negative(void) {
    unsigned char unowned = 0;
    lifetime_watch(&unowned, 1);
    (void)ube_gc_collect();
}
'@
$runtimePath=Join-Path $run 'runtime.c';[IO.File]::WriteAllText($runtimePath,$runtime,$utf8)
$wrapper=@'
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <string.h>
extern int lifetime_entry(int, char **);
extern int32_t ube_gc_collect(void);
extern size_t ube_gc_live_allocation_bytes(void), lifetime_root_count(void);
extern void lifetime_enable(int);
extern unsigned long long lifetime_collection_count(void), lifetime_request_count(void), lifetime_collection_failure_count(void);
extern unsigned long long lifetime_watch_count(void);
extern int lifetime_watch_remaining(void);
extern void lifetime_watch_negative(void);
int main(int argc, char **argv) {
    if (argc == 2 && strcmp(argv[1], "watch-negative") == 0) { lifetime_watch_negative(); return 94; }
    int force = argc == 2 && atoi(argv[1]) == 1;
    lifetime_enable(force);
    int result = lifetime_entry(1, argv);
    if (result != 0) return result;
    (void)ube_gc_collect();
    size_t roots = lifetime_root_count(), bytes = ube_gc_live_allocation_bytes();
    unsigned long long collections = lifetime_collection_count();
    unsigned long long requests = lifetime_request_count();
    unsigned long long failures = lifetime_collection_failure_count();
    unsigned long long watched = lifetime_watch_count();
    fprintf(stderr, "lifetime roots:%llu bytes:%llu collections:%llu requests:%llu collection-failures:%llu watched:%llu remaining:%d\n",
            (unsigned long long)roots, (unsigned long long)bytes, collections, requests, failures, watched, lifetime_watch_remaining());
    return roots || bytes || failures || lifetime_watch_remaining() || collections < requests || (force && requests == 0) ? 91 : 0;
}
'@
$wrapperPath=Join-Path $run 'wrapper.c';[IO.File]::WriteAllText($wrapperPath,$wrapper,$utf8)
$pinPaths=@($cases.source)+@($casesPath,$classPath,$modulePath,$runtimeSource,(Join-Path $root 'bootstrap/runtime/value_storage.h'),(Join-Path $root 'bootstrap/runtime/windows/file_primitives.c'),(Join-Path $root 'bootstrap/runtime/windows/thread_primitives.c'),$runtimePath,$wrapperPath,$PSCommandPath,$SelectionPath)
$pins=@($pinPaths | Sort-Object -Unique | ForEach-Object {Get-ArtifactIdentity $_})
$success=$false;$failure=$null;$build=$null;$emissions=@();$rows=@();$priorHashes=@{};$negative=$null
try{
 $runtimeObject=Join-Path $run 'runtime.o'
 $build=Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-I',(Join-Path $root 'bootstrap/runtime'),'-I',(Join-Path $root 'bootstrap/runtime/windows'),'-c',$runtimePath,'-o',$runtimeObject) $root 60
 if($build.timedOut -or $build.exit -ne 0){throw ('Lifetime runtime compile failed: '+$build.stdout+$build.stderr)}
 $stages=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
 for($stageIndex=0;$stageIndex -lt $stages.Count;++$stageIndex){
  foreach($case in $cases){
   Write-Output ('Lifetime stage '+$stageIndex+' '+$case.name)
   $caseDirectory=Join-Path $run ('stage'+$stageIndex+'/'+$case.name);$null=New-Item -ItemType Directory -Path $caseDirectory -Force
   $rawPath=Join-Path $caseDirectory 'raw.ll'
   $emit=Invoke-BoundedProcess $stages[$stageIndex] @($case.source,$rawPath) $root 60
   if($emit.timedOut -or $emit.exit -ne 0){throw ('Lifetime UBE emission failed: '+$emit.stdout+$emit.stderr)}
   $identity=Get-ArtifactIdentity $rawPath
   if($priorHashes.ContainsKey($case.name) -and $priorHashes[$case.name] -cne $identity.sha256){throw 'Source-built stage lifetime LLVM differs'}
   $priorHashes[$case.name]=$identity.sha256
   $emissions+=[pscustomobject]@{stage=(Get-ArtifactIdentity $stages[$stageIndex]);case=$case.name;raw=$identity;process=$emit}
   $raw=[IO.File]::ReadAllText($rawPath)
   foreach($variant in @('original','caller-retained')){
    $adapted=[regex]::Replace($raw,'(?m)^define i32 @main\(','define i32 @lifetime_entry(')
    $watchedFunctions=@()
    if($case.name -ceq 'borrowed-element'){$watchedFunctions=@([pscustomobject]@{symbol='ube.p1';role=1})}
    if($case.name -ceq 'class-owner-borrows'){$watchedFunctions=@([pscustomobject]@{symbol='ube.p3';role=1},[pscustomobject]@{symbol='ube.p4';role=2})}
    foreach($watch in $watchedFunctions){
     $pattern='(?ms)^define void @'+[regex]::Escape($watch.symbol)+'\(ptr (%arg.\d+),[^\r\n]*\) \{\r?\n.*?^\}'
     $matchesFound=[regex]::Matches($adapted,$pattern)
     if($matchesFound.Count -ne 1){throw 'Unique watched Sub/borrowed parameter required'}
     $function=$matchesFound[0].Value;$address=$matchesFound[0].Groups[1].Value
     $function=[regex]::Replace($function,'(?m)^entry:\r?$','entry:'+"`n  call void @lifetime_watch(ptr $address, i32 "+$watch.role+')')
     if([regex]::Matches($function,'(?m)^  ret void\r?$').Count -ne 1){throw 'Unique watched Sub exit required'}
     $function=[regex]::Replace($function,'(?m)^  ret void\r?$',"  call void @lifetime_unwatch()`n  ret void")
     $adapted=$adapted.Substring(0,$matchesFound[0].Index)+$function+$adapted.Substring($matchesFound[0].Index+$matchesFound[0].Length)
    }
    if($watchedFunctions.Count){$adapted+="`n"+'declare void @lifetime_watch(ptr, i32)'+"`n"+'declare void @lifetime_unwatch()'+"`n"}
    $script:omitted=0
    if($variant -ceq 'caller-retained'){
     $transform=[Text.RegularExpressions.MatchEvaluator]{param($match)
      $body=$match.Value
      foreach($a in [regex]::Matches($body,'(?m)^  (%root.status.arg.(\d+)) = call i32 @ube_value_root_enter\(ptr (%root.arg.\d+), ptr (%arg.\d+), ptr @ube.value.(\d+)\)\r?$')){
       $id=$a.Groups[2].Value;$slot=$a.Groups[3].Value;$address=$a.Groups[4].Value
       if($slot -cne ('%root.arg.'+$id) -or $address -cne ('%arg.'+$id) -or ($body -split "`n")[0] -notmatch ('(?:\(|, )ptr '+[regex]::Escape($address)+'(?:,|\))')){throw 'Exact borrowed parameter/root identity differs'}
       $leave='  call i32 @ube_gc_root_leave(ptr '+$slot+')'
       if([regex]::Matches($body,'(?m)^'+[regex]::Escape($leave)+'\r?$').Count -ne 1){throw 'Unique callee borrowed cleanup required'}
       $body=$body.Replace($a.Value,'  '+$a.Groups[1].Value+' = add i32 0, 1').Replace($leave,'  ; caller retains borrowed storage')
       ++$script:omitted
      }
      return $body
     }
     $adapted=[regex]::Replace($adapted,'(?ms)^define [^\r\n]+\r?\n.*?^\}',$transform)
    }
    $adaptedPath=Join-Path $caseDirectory ($variant+'.ll');[IO.File]::WriteAllText($adaptedPath,$adapted,$utf8)
    $exe=Join-Path $caseDirectory ($variant+'.exe')
    $link=Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-x','ir',$adaptedPath,'-x','c',$wrapperPath,'-x','none',$runtimeObject,$selection.unicodeRuntime.path,'-o',$exe) $root 60
    if($link.timedOut -or $link.exit -ne 0){throw ('Lifetime link failed: '+$link.stdout+$link.stderr)}
    if(-not $negative){
     $negative=Invoke-BoundedProcess $exe @('watch-negative') $root 30
     if($negative.timedOut -or $negative.exit -ne 92 -or $negative.stdout -cne '' -or $negative.stderr -cne "lifetime: unretained managed borrow`n"){throw 'Unowned-address negative control did not reject before dereference'}
    }
    foreach($force in @(0,1)){
     $native=Invoke-BoundedProcess $exe @([string]$force) $root 60
     if($native.timedOut -or $native.exit -ne 0 -or $native.stdout -cne $case.stdout -or $native.stderr -notmatch '^lifetime roots:0 bytes:0 collections:(\d+) requests:(\d+) collection-failures:0 watched:(\d+) remaining:0\n$'){throw ('Lifetime oracle/cleanup failed: '+($native | ConvertTo-Json -Compress -Depth 5))}
     $collectionCount=[long]$Matches[1]
     $requestCount=[long]$Matches[2]
     $watchCount=[long]$Matches[3]
     if($collectionCount -lt $requestCount -or ($force -eq 1 -and $requestCount -eq 0)){throw 'Forced collection did not actually complete'}
     if($watchedFunctions.Count -gt 0 -and $watchCount -eq 0){throw 'Managed owner-liveness assertions did not execute'}
     $rows+=[pscustomobject]@{stage=$stageIndex;case=$case.name;variant=$variant;omittedBorrowedRoots=$omitted;forced=[bool]$force;collections=$collectionCount;requests=$requestCount;collectionFailures=0;managedBorrowChecks=$watchCount;expected=$case.stdout;link=$link;process=$native}
    }
   }
  }
 }
 foreach($pin in $pins){$now=Get-ArtifactIdentity $pin.path;if($now.sha256 -cne $pin.sha256 -or $now.bytes -ne $pin.bytes){throw 'Lifetime input changed during the gate'}}
 $null=Get-VerifiedBootstrapSelection $SelectionPath
 if($rows.Count -ne 56 -or $emissions.Count -ne 14){throw 'Complete seven-case/two-stage/two-variant/two-collection-mode coverage required'}
 $success=$true
}catch{$failure=$_.Exception.Message;throw}finally{
 $report=Join-Path $run 'report.json'
 [pscustomobject]@{schema='ube-borrowed-lifetime-1';success=$success;productionQualified=$false;performanceAccepted=$false;failure=$failure;selection=$selection;inputs=$pins;runtimeBuild=$build;emissions=$emissions;rows=$rows;negativeControl=$negative;artifacts=@(Get-ChildItem -LiteralPath $run -File -Recurse | Where-Object Name -NE 'report.json' | ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Independent managed-value, nested roots, results, replaced array-parent and class-owner ByRef lifetimes through both accepted source-built stages. Experimental omission of callee duplicate roots; exact output, live managed owner assertions, successful trace counts, and zero owned roots/payload, ordinary and allocation-triggered collections.'} | ConvertTo-Json -Depth 18 | Set-Content -LiteralPath $report -Encoding UTF8
 Write-Output ('Evidence: '+$report)
}
