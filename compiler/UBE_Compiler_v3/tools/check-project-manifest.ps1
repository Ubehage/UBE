param(
    [string]$SelectionPath=(Join-Path $PSScriptRoot '../../../bootstrap/out/v2/current.json'),
    [switch]$DiagnosticOnly
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$run=Join-Path $root ('bootstrap/out/project-manifest/'+[Guid]::NewGuid().ToString('N'))
$project=Join-Path $run 'project'
$null=New-Item -ItemType Directory $project -Force
$fixture=Join-Path $root 'compiler/UBE_Compiler_v3/tests/project-input'
$names=@('SourceInput','SourceFile','ScannerWords','SourceScanner','SourceEnvelope','ProjectManifest')
$paths=@($names | ForEach-Object {Join-Path $root ('compiler/UBE_Compiler_v3/src/'+$_+'.bas')})
$paths+=@((Join-Path $fixture 'manifests.json'),(Join-Path $fixture 'manifest.c'),(Join-Path $fixture 'manifest-entry.bas'),(Join-Path $fixture 'ORACLES.md'),$PSCommandPath,
    (Join-Path $root 'bootstrap/tools/verification.ps1'),(Join-Path $root 'compiler/UBE_Compiler_v3/PROJECT-INPUT-CONTRACT.md'),
    (Join-Path $root 'compiler/UBE_Compiler_v3/PROJECT-DIAGNOSTICS.md'),(Join-Path $root 'std-lib/UBECore.UBE'),
    (Join-Path $root 'bootstrap/runtime/bootstrap_runtime.c'),(Join-Path $root 'bootstrap/runtime/value_storage.h'),
    (Join-Path $root 'bootstrap/runtime/windows/file_primitives.c'),(Join-Path $root 'bootstrap/runtime/windows/thread_primitives.c'),
    (Join-Path $root 'std-lib/tests/managed-storage/copy-probe.h'),(Join-Path $root 'std-lib/tests/byte-storage/allocation-probe.h'))
$inputs=@($paths | ForEach-Object {Get-ArtifactIdentity $_})
$commands=@();$checks=@();$measurements=@();$success=$false;$failure=$null;$selection=$null
function Run-ManifestProcess([string]$Program,[string[]]$Values){
    $record=Invoke-BoundedProcess $Program $Values $root 120
    $script:commands+=$record
    if($record.timedOut -or $record.exit -ne 0 -or $record.stderr -cne ''){throw ($record | ConvertTo-Json -Depth 5)}
    return $record
}
function Expected-Number($Case,[string]$Name,[int]$Default=-1){
    if($null -ne $Case.PSObject.Properties[$Name]){return [int]$Case.$Name};return $Default
}
try{
    if($DiagnosticOnly){$selection=Get-Content $SelectionPath -Raw | ConvertFrom-Json}else{$selection=Get-VerifiedBootstrapSelection $SelectionPath}
    foreach($property in $selection.PSObject.Properties){
        if($property.Name -ne 'schema'){
            if((Get-ArtifactIdentity $property.Value.path).sha256 -cne $property.Value.sha256){throw "Selected artifact changed: $($property.Name)"}
            $inputs+=$property.Value
        }
    }
    $accepted=Get-Content $selection.manifest.path -Raw | ConvertFrom-Json
    if(-not $accepted.success){throw 'Unsuccessful source-built compiler'}
    $stages=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
    foreach($stage in $stages){
        $record=@($accepted.artifacts | Where-Object path -CEQ $stage)
        if($record.Count -ne 1 -or (Get-ArtifactIdentity $stage).sha256 -cne $record[0].sha256){throw 'Stage identity differs'}
        $inputs+=$record[0]
    }
    $ordered=@()
    foreach($name in $names){
        $path=Join-Path $root ('compiler/UBE_Compiler_v3/src/'+$name+'.bas')
        Copy-Item $path (Join-Path $project ($name+'.bas'))
        $ordered+=$path
    }
    Copy-Item (Join-Path $fixture 'manifest-entry.bas') (Join-Path $project 'Entry.bas')
    $ordered+=Join-Path $fixture 'manifest-entry.bas'
    $manifest=Join-Path $project 'ManifestProof.UBE'
    $lines=@('UBE-Project 1','Name = "ManifestProof"','Kind = "Exe"','Startup = "Main"')+@($names | ForEach-Object {'Source = "'+$_+'.bas"'})+@('Source = "Entry.bas"','Reference = "../../../../../std-lib/UBECore.UBE"')
    [IO.File]::WriteAllText($manifest,($lines -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
    $coreManifest=Join-Path $root 'std-lib/UBECore.UBE'
    foreach($match in [regex]::Matches([IO.File]::ReadAllText($coreManifest),'(?m)^Source = "([^"]+)"')){
        $path=[IO.Path]::GetFullPath((Join-Path (Split-Path $coreManifest -Parent) $match.Groups[1].Value))
        $ordered+=$path;$inputs+=Get-ArtifactIdentity $path
    }
    $procedures=@{};$types=@{};$procedureIndex=0;$typeIndex=0
    foreach($path in $ordered){
        $contents=[IO.File]::ReadAllText($path)
        foreach($match in [regex]::Matches($contents,'(?m)^(?:Intrinsic )?(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)\b')){
            $name=$match.Groups[1].Value
            if($procedures.ContainsKey($name)){throw 'Duplicate fixture procedure'}
            $procedures[$name]='ube.p'+$procedureIndex;$procedureIndex++
        }
        foreach($match in [regex]::Matches($contents,'(?m)^Type ([A-Za-z_][A-Za-z_0-9]*)\b')){$types[$match.Groups[1].Value]='%ube.type.'+$typeIndex;$typeIndex++}
    }
    $definition=[IO.File]::ReadAllText((Join-Path $fixture 'manifests.json'),[Text.Encoding]::UTF8) | ConvertFrom-Json
    $header=New-Object Text.StringBuilder
    $rows=New-Object 'System.Collections.Generic.List[string]'
    $caseIndex=0
    foreach($case in $definition.cases){
        $source=[string]$definition.common
        if($null -ne $case.PSObject.Properties['source']){$source=$case.source}
        if($null -ne $case.PSObject.Properties['replace']){$source=$source.Replace($case.replace[0],$case.replace[1])}
        if($null -ne $case.PSObject.Properties['append']){$source+=$case.append}
        if($null -ne $case.PSObject.Properties['repeatSources']){
            for($extra=1;$extra -lt $case.repeatSources;$extra++){$source+="Source = ""src/Repeated.bas""`n"}
        }
        if($null -ne $case.PSObject.Properties['prefix']){$source=$case.prefix+$source}
        if($null -ne $case.PSObject.Properties['crlf']){$source=$source.Replace("`n","`r`n")}
        if($null -ne $case.PSObject.Properties['trimFinalLf']){$source=$source.TrimEnd("`n")}
        $bytes=[Text.Encoding]::UTF8.GetBytes($source)
        if($null -ne $case.PSObject.Properties['prefixHex']){
            $prefix=[byte[]]@(for($offset=0;$offset -lt $case.prefixHex.Length;$offset+=2){[Convert]::ToByte($case.prefixHex.Substring($offset,2),16)})
            $bytes=$prefix+$bytes
        }
        $values=$bytes -join ',';if($bytes.Length -eq 0){$values='0'}
        $null=$header.AppendLine(('static const uint8_t manifest_bytes_'+$caseIndex+'[]={'+$values+'};'))
        $first=-1;$last=-1;$sourceSpan=@(-1,-1,-1,-1);$nameSpan=@(-1,-1)
        if($null -ne $case.PSObject.Properties['span']){$first=$case.span[0];$last=$case.span[1]}
        if($null -ne $case.PSObject.Properties['sourceSpan']){$sourceSpan=$case.sourceSpan}
        if($null -ne $case.PSObject.Properties['nameSpan']){$nameSpan=$case.nameSpan}
        $numbers=@($bytes.Length,$case.code,$first,$last,(Expected-Number $case 'entry'),(Expected-Number $case 'kind'),(Expected-Number $case 'sources'),(Expected-Number $case 'references'),(Expected-Number $case 'optimization'),(Expected-Number $case 'debug'),(Expected-Number $case 'unsupported' 0))
        $rows.Add(('{"'+$case.name+'",manifest_bytes_'+$caseIndex+','+($numbers -join ',')+',{'+($sourceSpan -join ',')+'},{'+($nameSpan -join ',')+'}}'))
        [IO.File]::WriteAllBytes((Join-Path $run ('case'+$caseIndex+'.UBE')),$bytes)
        $caseIndex++
    }
    $null=$header.AppendLine('static const struct manifest_case manifest_cases[]={'+($rows -join ",`n")+'};')
    [IO.File]::WriteAllText((Join-Path $run 'manifest-cases.h'),$header.ToString(),[Text.UTF8Encoding]::new($false))
    $runtimeSource=Join-Path $run 'observed-runtime.c'
    $include=(Join-Path $root 'bootstrap/runtime/bootstrap_runtime.c').Replace('\','/')
    $observer='#define ube_value_array_element manifest_array_element_body'+"`n"+'#include "'+$include+'"'+"`n"+@'
#undef ube_value_array_element
extern void manifest_read_called(void* const*);
void* ube_value_array_element(void* const* source,int32_t index,void** owner,void* fallback,const struct ube_value_layout* type) {
    manifest_read_called(source);
    return manifest_array_element_body(source,index,owner,fallback,type);
}
size_t manifest_test_roots(void) {ube_gc_enter_lock();size_t count=ube_gc_root_count;ube_gc_leave_lock();return count;}
'@
    [IO.File]::WriteAllText($runtimeSource,$observer,[Text.UTF8Encoding]::new($false))
    $observedRuntime=Join-Path $run 'observed-runtime.o'
    $null=Run-ManifestProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-Wall','-Wextra','-Werror','-include',(Join-Path $root 'std-lib/tests/managed-storage/copy-probe.h'),'-c',$runtimeSource,'-o',$observedRuntime)
    $hashes=@()
    for($index=0;$index -lt 2;$index++){
        $stem=Join-Path $run ('stage'+($index+1))
        $null=Run-ManifestProcess $stages[$index] @($manifest,($stem+'.ll'))
        $raw=[IO.File]::ReadAllText($stem+'.ll')
        $parse=$procedures.TryReadProjectManifest;$make=$procedures.TryMakeManifestDocument
        foreach($signature in @(('i1 @'+[regex]::Escape($parse)+'\(ptr [^,]+, ptr [^,]+, ptr [^)]+\)'),('i1 @'+[regex]::Escape($make)+'\(ptr [^,]+, ptr [^,]+, ptr [^)]+\)'))){if([regex]::Matches($raw,'(?m)^define '+$signature+' \{').Count -ne 1){throw 'Unexpected typed entry signature'}}
        $adapted=$raw.Replace('define i32 @main(', 'define i32 @manifest_unused_entry(')
        $adapted+="`n"+@"
define i32 @manifest_make(ptr %bytes, ptr %document, ptr %failure) {
  %ok = call i1 @$make(ptr %bytes, ptr %document, ptr %failure)
  %result = zext i1 %ok to i32
  ret i32 %result
}
define i32 @manifest_parse(ptr %document, ptr %metadata, ptr %failure) {
  %ok = call i1 @$parse(ptr %document, ptr %metadata, ptr %failure)
  %result = zext i1 %ok to i32
  ret i32 %result
}
"@
        $expressions=@()
        foreach($name in @('ProjectManifest','ProjectManifestFailure','ProjectDeclaration','SourceDocument')){$expressions+='ptrtoint (ptr getelementptr ('+$types[$name]+', ptr null, i32 1) to i64)'}
        foreach($field in @(9,11)){$expressions+='ptrtoint (ptr getelementptr ('+$types.ProjectManifest+', ptr null, i32 0, i32 '+$field+') to i64)'}
        $adapted+="`ndefine i64 @manifest_layout(i32 %index) {`n  switch i32 %index, label %invalid [`n"
        for($i=0;$i -lt $expressions.Count;$i++){$adapted+="    i32 $i, label %field$i`n"}
        $adapted+="  ]`ninvalid:`n  ret i64 -1`n"
        for($i=0;$i -lt $expressions.Count;$i++){$adapted+="field${i}:`n  ret i64 "+$expressions[$i]+"`n"}
        $adapted+="}`n"
        [IO.File]::WriteAllText($stem+'-adapted.ll',$adapted,[Text.UTF8Encoding]::new($false))
        $null=Run-ManifestProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-I',$run,($stem+'-adapted.ll'),(Join-Path $fixture 'manifest.c'),'-std=c17','-Wall','-Wextra','-Werror',$selection.runtime.path,$selection.unicodeRuntime.path,'-o',($stem+'.exe'))
        $native=Run-ManifestProcess ($stem+'.exe') @()
        if($native.stdout -notmatch ('^PASS manifest cases:'+$caseIndex+' assertions:[0-9]+\r?\n$')){throw 'Unexpected native case result'}
        $checks+=[pscustomobject]@{assertion="stage $($index+1): exact independent manifest metadata/failure spans, original bytes, Err and cleanup";passed=$true;output=$native.stdout}
        $null=Run-ManifestProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-I',$run,($stem+'-adapted.ll'),(Join-Path $fixture 'manifest.c'),'-std=c17','-Wall','-Wextra','-Werror','-DOBSERVE_MANIFEST',$observedRuntime,$selection.unicodeRuntime.path,'-o',($stem+'-observed.exe'))
        $observed=Run-ManifestProcess ($stem+'-observed.exe') @()
        $lines=@($observed.stdout.TrimEnd("`r","`n").Replace("`r`n","`n").Split("`n"))
        if($lines.Count -ne $caseIndex+1 -or $lines[-1] -notmatch ('^PASS manifest cases:'+$caseIndex+' assertions:[0-9]+$')){throw 'Unexpected observed result'}
        $rows=@($lines[0..($caseIndex-1)] | ForEach-Object {$_ | ConvertFrom-Json})
        foreach($row in $rows){if($row.copiedBytes -ne 0 -or $row.allocationCalls -gt 16 -or $row.peakRequestedAdditionalBytes -gt 32768 -or $row.sourceReads -gt 64*$row.bytes+1024 -or ($row.bytes -gt 0 -and $row.sourceReads -eq 0)){throw 'Native observed budget summary failed'}}
        $measurements+=[pscustomobject]@{stage=$index+1;actual=$rows;processPeakWorkingSetBytes=$observed.sampledPeakWorkingSetBytes}
        $checks+=[pscustomobject]@{assertion="stage $($index+1): observed reads/copies/allocation/peak bounds, actual allocation/root failures, four independent instances, GC and cleanup";passed=$true;output=$lines[-1]}
        $control=Invoke-BoundedProcess ($stem+'-observed.exe') @('wrong-source-watch') $root 30
        $commands+=$control
        if($control.timedOut -or $control.exit -ne 1 -or $control.stderr -notmatch 'source_reads>0'){throw 'Incorrect watched source was not rejected'}
        $checks+=[pscustomobject]@{assertion="stage $($index+1): source-read observer rejects a wrong-array negative control";passed=$true}
        $hashes+=(Get-ArtifactIdentity ($stem+'.ll')).sha256
    }
    if($hashes[0] -cne $hashes[1]){throw 'Raw LLVM differs'}
    $checks+=[pscustomobject]@{assertion='both accepted tools emit byte-identical raw LLVM';passed=$true}
    foreach($input in $inputs){if((Get-ArtifactIdentity $input.path).sha256 -cne $input.sha256){throw "Input changed: $($input.path)"}}
    $success=$true
}catch{$failure=$_.Exception.Message}
[pscustomobject]@{schema='ube-project-manifest-proof-1';success=$success;qualified=($success -and -not $DiagnosticOnly);diagnosticOnly=[bool]$DiagnosticOnly;failure=$failure;acceptedSelection=$selection;inputs=$inputs;checks=$checks;measurements=$measurements;commands=$commands;artifacts=@(Get-ChildItem $run -File -Recurse | ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Manifest structure and borrowed original spans with fixed native observation budgets/faults/independent instances; no project graph, path policy, UBE worker integration, CLI or full project qualification.'} | ConvertTo-Json -Depth 14 | Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output ('Evidence: '+(Join-Path $run 'report.json'))
if(-not $success){throw $failure}
