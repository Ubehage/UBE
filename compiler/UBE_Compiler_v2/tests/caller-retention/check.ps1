param([string]$SelectionPath=(Join-Path $PSScriptRoot '../../../../bootstrap/out/v2/current.json'))
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$run=Join-Path $root ('bootstrap/out/caller-retention/'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory $run
$selection=$null;$inputs=@();$commands=@();$checks=@();$emissions=@();$rows=@()
$success=$false;$failure=$null;$utf8=[Text.UTF8Encoding]::new($false)
function Assert-Inputs {
    foreach($pin in $inputs){
        $now=Get-ArtifactIdentity $pin.path
        if($now.sha256 -cne $pin.sha256 -or $now.bytes -ne $pin.bytes){throw ('Caller retention input changed: '+$pin.path)}
    }
}
function Invoke-Checked([string]$File,[string[]]$Values,[int]$Seconds=60) {
    $record=Invoke-BoundedProcess $File $Values $root $Seconds
    $script:commands+=$record
    if($record.timedOut -or $record.exit -ne 0){throw ('Caller retention process failed: '+$record.stdout+$record.stderr)}
    return $record
}
try {
    $selection=Get-VerifiedBootstrapSelection $SelectionPath
    $inputs+=Get-ArtifactIdentity $SelectionPath
    $inputs+=@($selection.manifest,$selection.clang,$selection.unicodeRuntime)
    $stages=@((Join-Path (Split-Path $selection.compiler.path) 'ube-stage1-v2.exe'),$selection.compiler.path)
    $inputs+=@($stages|ForEach-Object {Get-ArtifactIdentity $_})
    $fixtureNames=@('Carrier.cls','CallerRetention.bas','CallerRetention.UBE','proof.c')
    $runtimeNames=@('bootstrap/runtime/bootstrap_runtime.c','bootstrap/runtime/error_support.c','bootstrap/runtime/value_storage.h','bootstrap/runtime/windows/file_primitives.c','bootstrap/runtime/windows/file_output.c','bootstrap/runtime/windows/thread_primitives.c')
    $inputs+=@(Get-ChildItem -LiteralPath $PSScriptRoot -File|ForEach-Object {Get-ArtifactIdentity $_.FullName})
    $inputs+=@($runtimeNames|ForEach-Object {Get-ArtifactIdentity (Join-Path $root $_)})
    foreach($name in $fixtureNames){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $run}
    foreach($name in $runtimeNames){Copy-Item -LiteralPath (Join-Path $root $name) -Destination (Join-Path $run (Split-Path $name -Leaf))}
    Assert-Inputs
    # Observe actual completed mark/sweep under the existing lock. Native watches
    # are not traced roots and must check a container before any interior load.
    $runtime=[IO.File]::ReadAllText((Join-Path $run 'bootstrap_runtime.c'))
    $runtime="static int retention_force;`nstatic unsigned long long retention_collections,retention_requests,retention_failures;`nstatic void retention_after_collection(void);`n"+$runtime
    foreach($signature in @('void* ube_gc_allocate(const struct ube_gc_layout* layout) {','static void* ube_gc_allocate_untraced_pending(size_t size) {')){
        if([regex]::Matches($runtime,[regex]::Escape($signature)).Count -ne 1){throw 'Unique managed allocation boundary required'}
        $runtime=$runtime.Replace($signature,$signature+' if(retention_force){++retention_requests;(void)ube_gc_collect();}')
    }
    $completed='(?m)^(    __atomic_store_n\(&ube_gc_collecting_state,0,__ATOMIC_SEQ_CST\);\r?\n    __atomic_store_n\(&ube_root_registry.collector,0,__ATOMIC_SEQ_CST\);\r?\n)(    ube_gc_leave_lock\(\);\r?\n    return performed;)'
    if([regex]::Matches($runtime,$completed).Count -ne 1){throw 'Unique full collection completion boundary required'}
    $runtime=[regex]::Replace($runtime,$completed,('${1}    ++retention_collections; retention_after_collection();'+"`n"+'${2}'))
    $failed='if (!ube_gc_mark_roots()) {'
    if([regex]::Matches($runtime,[regex]::Escape($failed)).Count -ne 1){throw 'Unique mark failure boundary required'}
    $runtime=$runtime.Replace($failed,$failed+' ++retention_failures;')
    $runtime=$runtime.Replace('#include "windows/file_primitives.c"','#include "file_primitives.c"').Replace('#include "windows/thread_primitives.c"','#include "thread_primitives.c"')
    $runtime=$runtime.Replace('#include "windows/file_output.c"','#include "file_output.c"')
    [IO.File]::WriteAllText((Join-Path $run 'observed_runtime.c'),$runtime,$utf8)
    $procedures=@{};$index=0
    foreach($match in [regex]::Matches([IO.File]::ReadAllText((Join-Path $run 'CallerRetention.bas')),'(?m)^(?:Intrinsic )?(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)')){
        $procedures[$match.Groups[1].Value]='ube.p'+$index;$index++
    }
    $priorHash=''
    for($stage=1;$stage -le 2;++$stage){
        $directory=Join-Path $run ('stage'+$stage);$null=New-Item -ItemType Directory $directory
        $rawPath=Join-Path $directory 'raw.ll'
        $emit=Invoke-Checked $stages[$stage-1] @((Join-Path $run 'CallerRetention.UBE'),$rawPath)
        $raw=[IO.File]::ReadAllText($rawPath);$rawIdentity=Get-ArtifactIdentity $rawPath
        if($priorHash -and $priorHash -cne $rawIdentity.sha256){throw 'Source-built stages disagree on caller retention fixture LLVM'}
        $priorHash=$rawIdentity.sha256
        foreach($layout in @('%ube.type.0 = type { ptr }','%ube.type.1 = type { ptr, i32 }')){
            if([regex]::Matches($raw,'(?m)^'+[regex]::Escape($layout)+'\r?$').Count -ne 1){throw 'Independent fixture payload layout differs'}
        }
        if($raw -match 'call i32 @ube_value_root_enter\(ptr %root.arg.' -or $raw -match 'call i32 @ube_gc_root_leave\(ptr %root.arg.'){
            throw 'Duplicate managed ByRef callee admission or cleanup remains'
        }
        if($raw -notmatch 'call i32 @ube_value_root_enter\(ptr %root.value.' -or $raw -notmatch 'call i32 @ube_value_root_enter\(ptr %root.borrow.'){
            throw 'Required private/borrow-owner fixture roots absent'
        }
        $checks+=[pscustomobject]@{assertion="stage${stage}: exact payload layouts, omitted duplicate ByRef admission/cleanup and retained private/borrow-owner roots";passed=$true}
        $adapted=[regex]::Replace($raw,'(?m)^define i32 @main\(','define i32 @proof_unused_main(')
        foreach($name in @('DirectArray','DirectRecord','ForwardAlias','ReplaceElement','ReplaceClassField')){
            $pattern='(?ms)^define void @'+[regex]::Escape($procedures[$name])+'\([^\r\n]*\) \{.*?^\}'
            $found=[regex]::Matches($adapted,$pattern)
            if($found.Count -ne 1){throw 'Unique watched source procedure required'}
            $body=$found[0].Value;$collect='(?m)^(  %r\d+ = call i32 @ube_gc_collect\(\)\r?$)'
            if([regex]::Matches($body,$collect).Count -ne 1){throw 'Unique explicit post-nested-return collection required'}
            $body=[regex]::Replace($body,$collect,('  call void @proof_before_required_gc()'+"`n"+'${1}'))
            $adapted=$adapted.Substring(0,$found[0].Index)+$body+$adapted.Substring($found[0].Index+$found[0].Length)
        }
        $adapter="`ndeclare void @proof_before_required_gc()`n"
        foreach($binding in @(@('proof_array','DirectArray','ptr %a','ptr %a'),@('proof_record','DirectRecord','ptr %a','ptr %a'),@('proof_alias','ForwardAlias','ptr %a','ptr %a, ptr %a'),@('proof_element','ReplaceElement','ptr %a, ptr %b','ptr %a, ptr %b'),@('proof_field','ReplaceClassField','ptr %a, ptr %b','ptr %a, ptr %b'))){
            $adapter+='define void @'+$binding[0]+'('+$binding[2]+") {`n call void @"+$procedures[$binding[1]]+'('+$binding[3]+")`n ret void`n}`n"
        }
        $adapter+="define ptr @proof_parcel_layout() {`n ret ptr @ube.value.1001`n}`ndefine ptr @proof_carrier_layout() {`n ret ptr @ube.object.0`n}`n"
        $entry=Join-Path $directory 'entry.ll';[IO.File]::WriteAllText($entry,$adapted+$adapter,$utf8)
        $exe=Join-Path $directory 'proof.exe'
        $link=Invoke-Checked $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-I',$run,'-x','ir',$entry,'-x','c',(Join-Path $run 'proof.c'),'-x','none',$selection.unicodeRuntime.path,'-o',$exe)
        $emissions+=[pscustomobject]@{stage=$stage;compiler=(Get-ArtifactIdentity $stages[$stage-1]);raw=$rawIdentity;entry=(Get-ArtifactIdentity $entry);exe=(Get-ArtifactIdentity $exe);emit=$emit;link=$link}
        foreach($case in @(0,1,2,3,4)){foreach($force in @(0,1)){
            $trial=Invoke-Checked $exe @([string]$case,[string]$force,'0') 30
            if($trial.stderr -cne ''){throw 'Unexpected positive observer stderr'}
            $result=$trial.stdout|ConvertFrom-Json
            if(-not $result.cleanup -or $result.requiredPostNestedReturnCollections -ne 1 -or $result.markFailures -ne 0 -or $result.pendingOrPinnedMask){throw 'Lifetime observer invariants failed'}
            $rows+=[pscustomobject]@{stage=$stage;case=$case;forced=[bool]$force;negative=$false;result=$result;process=$trial}
            $checks+=[pscustomobject]@{assertion="stage${stage} case${case} force${force}: exact outputs/Err, actual post-nested GC before new borrow, no pin/publication masking, complete drain";passed=$true}
        }}
        foreach($case in @(0,3,4)){foreach($force in @(0,1)){
            $trial=Invoke-BoundedProcess $exe @([string]$case,[string]$force,'1') $root 30;$commands+=$trial
            $role=if($case -eq 0){'slot'}else{'owner'}
            if($trial.timedOut -or $trial.exit -ne 92 -or $trial.stdout -cne '' -or $trial.stderr -notmatch ('^dead-watch:'+$role+' required:[01]\r?\n$') -or ($case -eq 0 -and $trial.stderr -notmatch 'required:1')){throw 'Independent missing-caller/owner dead-watch control failed'}
            $rows+=[pscustomobject]@{stage=$stage;case=$case;forced=[bool]$force;negative=$true;process=$trial}
            $checks+=[pscustomobject]@{assertion="stage${stage} case${case} force${force}: missing caller location/containing owner rejected before unsafe dereference";passed=$true}
        }}
    }
    $checks+=[pscustomobject]@{assertion='Both source-built stages emit byte-identical raw fixture LLVM';passed=$true}
    Assert-Inputs
    $null=Get-VerifiedBootstrapSelection $SelectionPath
    if($checks.Count -ne 35 -or $rows.Count -ne 32){throw 'Caller retention proof group inventory incomplete'}
    $success=$true
}catch{$failure=$_.Exception.Message}finally{
    $path=Join-Path $run 'report.json'
    [pscustomobject]@{schema='ube-caller-retention-proof-1';success=$success;failure=$failure;acceptedSelection=$selection;inputs=$inputs;checks=$checks;commands=$commands;emissions=$emissions;rows=$rows;artifacts=@(Get-ChildItem $run -Recurse -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Actual source-built synchronous caller-retained private ByRef rule; nested new outputs, exact alias, replaced containing owners, completed ordinary/forced GC, independent contents/errors/drain and unrooted negative controls. No foreign ABI or performance qualification.'}|ConvertTo-Json -Depth 22|Set-Content $path -Encoding UTF8
    Write-Output ('Evidence: '+$path)
}
if(-not $success){throw $failure}
Write-Output 'PASS caller-retained ByRef lifetime: 20 positive executions, 12 missing-root controls, 35 grouped assertions.'
