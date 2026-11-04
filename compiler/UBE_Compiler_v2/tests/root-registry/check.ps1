param([string]$SelectionPath=(Join-Path $PSScriptRoot '../../../../bootstrap/out/v2/current.json'))
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$candidate=Join-Path $root 'bootstrap/runtime/bootstrap_runtime.c'
$contract=Join-Path $PSScriptRoot 'CONTRACT.md'
$driver=Join-Path $PSScriptRoot 'probe.c'
$legacy=Join-Path $PSScriptRoot 'legacy-proof.c'
$selection=Get-VerifiedBootstrapSelection $SelectionPath
$names=@('bootstrap/runtime/error_support.c','bootstrap/runtime/value_storage.h','bootstrap/runtime/windows/file_primitives.c','bootstrap/runtime/windows/file_output.c','bootstrap/runtime/windows/thread_primitives.c')
$pins=@($candidate,$contract,$driver,$legacy,$PSCommandPath,$SelectionPath)|ForEach-Object {Get-ArtifactIdentity $_}
$pins+=@($selection.compiler,$selection.manifest,$selection.clang,$selection.unicodeRuntime)
$pins+=@($names|ForEach-Object {Get-ArtifactIdentity (Join-Path $root $_)})
$run=Join-Path $root ('bootstrap/out/root-registry/'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory $run
$script:commands=@();$rows=@();$checks=@();$success=$false;$failure=$null
$utf8=[Text.UTF8Encoding]::new($false)
function Replace-One([string]$Text,[string]$From,[string]$To){
 if([regex]::Matches($Text,[regex]::Escape($From)).Count -ne 1){throw ('Unique instrumentation marker mismatch: '+$From)}
 return $Text.Replace($From,$To)
}
function Assert-Pins{
 foreach($pin in $pins){if((Get-ArtifactIdentity $pin.path).sha256 -cne $pin.sha256){throw ('Input changed '+$pin.path)}}
}
function Execute([string]$File,[string[]]$Values,[int]$Expected=0,[int]$Seconds=90){
 $p=Invoke-BoundedProcess $File $Values $root $Seconds;$script:commands+=$p
 if($p.timedOut -or $p.exit -ne $Expected){throw ('Proof process exit/timeout '+$p.stdout+$p.stderr)}
 if($Expected -eq 0 -and ($p.stderr -cne '' -or $p.stdout -notmatch 'PASS root synchronization .+ assertions:[1-9][0-9]*')){throw ('Proof assertion output missing '+$p.stdout+$p.stderr)}
 if($Expected -ne 0 -and ($p.stdout -cne '' -or $p.stderr -notmatch ('^SAFE-GUARD '+$Expected+' '))){throw ('Expected safe detector did not fire '+$p.stdout+$p.stderr)}
 return $p
}
try {
 Assert-Pins
$text=[IO.File]::ReadAllText($candidate).Replace("`r`n","`n")
$text=Replace-One $text '#include "windows/file_primitives.c"' '#include "file_primitives.c"'
$text=Replace-One $text '#include "windows/thread_primitives.c"' '#include "thread_primitives.c"'
$text=Replace-One $text '#include "windows/file_output.c"' '#include "file_output.c"'
$unobserved=$text
$text=Replace-One $text 'uint64_t current=__atomic_load_n(&ube_root_registry.state,__ATOMIC_SEQ_CST);' 'uint64_t current=__atomic_load_n(&ube_root_registry.state,__ATOMIC_SEQ_CST);proof_reserve_loaded(current);'
$text=Replace-One $text 'if((current&UBE_ROOT_CLOSED)||(current&UBE_ROOT_COUNT_MASK)>=UBE_GC_MAX_ROOTS)return 0;' 'if((current&UBE_ROOT_CLOSED)||(current&UBE_ROOT_COUNT_MASK)>=UBE_GC_MAX_ROOTS){proof_reserve_rejected(current);return 0;}'
$cas=@'
        if(__atomic_compare_exchange_n(&ube_root_registry.state,&current,current+1,0,
                __ATOMIC_SEQ_CST,__ATOMIC_SEQ_CST))return 1;
'@
$text=Replace-One $text $cas ($cas+'        proof_reserve_retry(current);')
$text=Replace-One $text 'if(!ube_root_registry_reserve())return 0;' 'if(!ube_root_registry_reserve())return 0;proof_point(RESERVED);'
$text=$text.Replace('ube_root_registry_freeze();','ube_root_registry_freeze();proof_frozen();')
$text=Replace-One $text @'
static int ube_gc_mark_registered_roots(struct ube_gc_header***work,size_t*count,size_t*capacity) {
    ube_root_registry_freeze();proof_frozen();
'@ @'
static int ube_gc_mark_registered_roots(struct ube_gc_header***work,size_t*count,size_t*capacity) {
    ube_root_registry_freeze();proof_frozen();proof_point(SNAPSHOT);
'@
$text=Replace-One $text 'ube_root_registry_unfreeze();return 1;' 'ube_root_registry_unfreeze();proof_point(AFTER_SNAPSHOT);return 1;'
$text=Replace-One $text 'if(ube_root_registry_foreign_collection()){ube_root_registry_wait_for_collector();continue;}' 'if(ube_root_registry_foreign_collection()){ube_root_registry_wait_for_collector();continue;}proof_point(BEFORE_STRIPE);'
$recheck=@'
        if(ube_root_registry_foreign_collection()) {
            LeaveCriticalSection(&ube_root_registry.stripes[stripe].section);
            ube_root_registry_wait_for_collector();continue;
        }
'@
$text=Replace-One $text $recheck ($recheck+"        proof_before_admit(root_storage);proof_point(IN_STRIPE);`n")
$text=Replace-One $text @'
    else LeaveCriticalSection(&ube_root_registry.stripes[stripe].section);
    return result;
'@ @'
    else LeaveCriticalSection(&ube_root_registry.stripes[stripe].section);
    proof_leave_return(root_storage,result);return result;
'@
$original=$text
$variants=@(
 [pscustomobject]@{name='normal';define=$null;case=$null;exit=0},
 [pscustomobject]@{name='missing-freeze';define='missing-freeze';case='freeze';exit=91},
 [pscustomobject]@{name='missing-gate';define='missing-gate';case='gate';exit=92},
 [pscustomobject]@{name='missing-recheck';define='missing-recheck';case='recheck';exit=92},
 [pscustomobject]@{name='held-stripe-wait';define='held-stripe-wait';case='recheck';exit=90},
 [pscustomobject]@{name='early-leave';define='early-leave';case='lifetime';exit=93},
 [pscustomobject]@{name='alias-missing-freeze';define='alias-missing-freeze';case='aliases';exit=91},
 [pscustomobject]@{name='shutdown-missing-freeze';define='shutdown-missing-freeze';case='shutdown';exit=91},
 [pscustomobject]@{name='noncas-reserve';define='noncas-reserve';case='capacity-shared-load';exit=95}
)
 foreach($variant in $variants){
  $directory=Join-Path $run $variant.name;$null=New-Item -ItemType Directory $directory
  $text=$original
  switch($variant.define){
   'missing-freeze' {$text=Replace-One $text 'ube_root_registry_freeze();proof_frozen();proof_point(SNAPSHOT);' 'proof_frozen();proof_point(SNAPSHOT);'}
   'missing-gate' {$text=Replace-One $text 'return ube_gc_collecting&&' 'return 0 && ube_gc_collecting&&'}
   'missing-recheck' {$text=Replace-One $text $recheck ''}
   'held-stripe-wait' {$changed=$recheck.Replace('LeaveCriticalSection(&ube_root_registry.stripes[stripe].section);','/* safe mutant: omitted release; heap guard must terminate before acquisition */');$text=Replace-One $text $recheck $changed}
   'early-leave' {$text=Replace-One $text 'int32_t result=ube_root_registry_leave_locked(root_storage,bucket);' 'int32_t result=1;'}
   'alias-missing-freeze' {$text=Replace-One $text ("ube_root_registry_freeze();proof_frozen();`n    for (struct ube_default_form_slot* item") ("proof_frozen();`n    for (struct ube_default_form_slot* item")}
   'shutdown-missing-freeze' {$text=Replace-One $text ("ube_root_registry_freeze();proof_frozen();`n    memset(ube_root_registry.heads") ("proof_frozen();`n    memset(ube_root_registry.heads")}
   'noncas-reserve' {$text=Replace-One $text ($cas+'        proof_reserve_retry(current);') '__atomic_store_n(&ube_root_registry.state,current+1,__ATOMIC_SEQ_CST);return 1;'}
  }
  [IO.File]::WriteAllText((Join-Path $directory 'bootstrap_runtime.c'),$text,$utf8)
  $old=[IO.File]::ReadAllText($legacy)
  $old=Replace-One $old '#include "bootstrap_runtime.c"' '/* runtime included once by independent driver */'
  [IO.File]::WriteAllText((Join-Path $directory 'legacy-proof.c'),$old,$utf8)
  Copy-Item $driver (Join-Path $directory 'probe.c')
  foreach($name in $names){Copy-Item (Join-Path $root $name) (Join-Path $directory (Split-Path $name -Leaf))}
  $exe=Join-Path $directory 'probe.exe'
  if($true){
   $p=Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-I',$directory,(Join-Path $directory 'probe.c'),$selection.unicodeRuntime.path,'-o',$exe) $root 90
   $script:commands+=$p
   if($p.timedOut -or $p.exit -ne 0 -or $p.stderr -cne ''){throw ('Proof compilation failed '+$p.stdout+$p.stderr)}
   if($variant.name -ceq 'normal'){
    foreach($case in @('freeze','gate','recheck','inflight','lifetime','capture','capacity','capacity-shared-load','close','close-reserved','owner','aliases','shutdown','fallback-capacity')){
     $p=Execute $exe @($case);$rows+=[pscustomobject]@{variant=$variant.name;case=$case;process=$p};Write-Output ($variant.name+' '+$case+' passed')
    }
    foreach($position in 0..63){
     $p=Execute $exe @('fallback',[string]$position);$rows+=[pscustomobject]@{variant=$variant.name;case='fallback';position=$position;process=$p}
    }
    Write-Output 'All64 fresh-process fallback positions passed'
   }else {
    $p=Execute $exe @($variant.case) $variant.exit
    $rows+=[pscustomobject]@{variant=$variant.name;case=$variant.case;expectedSafeExit=$variant.exit;process=$p};Write-Output ($variant.name+' safe detector passed')
   }
  }
 }
 Assert-Pins
 if($rows.Count -ne 86){throw 'Deterministic registry matrix inventory incomplete'}
 foreach($row in $rows){$checks+=[pscustomobject]@{assertion=($row.variant+' '+$row.case+$(if($row.PSObject.Properties.Name -contains 'position'){' '+$row.position}else{''}));passed=$true}}
 # Independent uninstrumented legacy proof retains all original assertions.
 $directory=Join-Path $run 'legacy';$null=New-Item -ItemType Directory $directory
 [IO.File]::WriteAllText((Join-Path $directory 'bootstrap_runtime.c'),$unobserved,$utf8)
 Copy-Item $legacy (Join-Path $directory 'legacy-proof.c')
 foreach($name in $names){Copy-Item (Join-Path $root $name) (Join-Path $directory (Split-Path $name -Leaf))}
 $exe=Join-Path $directory 'legacy-proof.exe'
 $p=Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-I',$directory,(Join-Path $directory 'legacy-proof.c'),$selection.unicodeRuntime.path,'-o',$exe) $root 90
 $script:commands+=$p
 if($p.timedOut -or $p.exit -ne 0 -or $p.stderr -cne ''){throw ('Legacy proof compilation failed '+$p.stdout+$p.stderr)}
 $p=Invoke-BoundedProcess $exe @() $root 90;$script:commands+=$p
 if($p.timedOut -or $p.exit -ne 0 -or $p.stderr -cne '' -or $p.stdout -cnotmatch '(?m)^PASS root storage bucket synthetic assertions:2106814\r?$'){throw ('Legacy registry assertion inventory failed '+$p.stdout+$p.stderr)}
 $checks+=[pscustomobject]@{assertion='Legacy registry membership, real capacity, lifetime, error, alias, capture, duplicate-precondition and shutdown: 2106814 assertions';passed=$true;process=$p}
 Assert-Pins
 $null=Get-VerifiedBootstrapSelection $SelectionPath
 if($checks.Count -ne 87){throw 'Registry proof group inventory incomplete'}
 $success=$true
}catch{$failure=$_.Exception.Message}finally{
 $path=Join-Path $run 'report.json'
 [pscustomobject]@{schema='ube-root-registry-proof-1';success=$success;failure=$failure;acceptedSelection=$selection;inputs=$pins;checks=$checks;rows=$rows;commands=$script:commands;artifacts=@(Get-ChildItem $run -Recurse -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Current verified source/tool cohort; 86 deterministic protocol/fallback/safe-mutant checks and independent 2106814-assertion actual-capacity legacy proof. Observers and mutants occur only in private test runtime copies; no performance claim.'}|ConvertTo-Json -Depth 22|Set-Content $path -Encoding UTF8
 Write-Output ('Evidence: '+$path)
}

if(-not $success){throw $failure}
Write-Output 'PASS root registry: 87 checks, including 2106814 legacy assertions.'
