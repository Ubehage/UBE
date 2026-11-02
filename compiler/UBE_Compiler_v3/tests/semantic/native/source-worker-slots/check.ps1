param(
 [string]$SelectionPath='',
 [switch]$DiagnosticOnly,
 [string]$DiagnosticRawPath='',
 [ValidateSet('','boundaries','faults','fixtures')][string]$DiagnosticSuite=''
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not (Test-Path -LiteralPath (Join-Path $root 'compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE'))){$parent=Split-Path $root -Parent;if(-not $parent -or $parent -ceq $root){throw 'Repository root missing'};$root=$parent}
$fixture=Join-Path $PSScriptRoot 'fixture'
$sourceRoot=$root
if($DiagnosticRawPath -or $DiagnosticSuite){$DiagnosticOnly=$true}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
if(-not $SelectionPath){$SelectionPath=Join-Path $root 'bootstrap/out/v2/current.json'}
$selection=Get-VerifiedBootstrapSelection $SelectionPath
$run=Join-Path $root ('bootstrap/out/source-worker-slots-maintained/'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$projectDir=Join-Path $run 'project'
New-Item -ItemType Directory -Path $projectDir | Out-Null
$productionNames=@('SourceOwner.cls','SourceWork.cls','SourceCancellation.cls','SourceWorkerSlots.bas','SourceParsing.bas','SourceInput.bas','SourceFile.bas','ScannerWords.bas','SourceScanner.bas','SourceEnvelope.bas','SyntaxTree.bas','SyntaxExpressions.bas','SyntaxGrammar.bas','SourceSyntax.bas')
$compilerManifest=Join-Path $root 'compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE';$productionDirectory=Split-Path $compilerManifest -Parent
$declaredSources=@();$declaredReferences=@()
foreach($line in [IO.File]::ReadAllLines($compilerManifest)){if($line -match '^Source = "([^"]+)"$'){$declaredSources+=[IO.Path]::GetFullPath((Join-Path $productionDirectory $Matches[1]))};if($line -match '^Reference = "([^"]+)"$'){$declaredReferences+=[IO.Path]::GetFullPath((Join-Path $productionDirectory $Matches[1]))}}
foreach($name in $productionNames){$origin=[IO.Path]::GetFullPath((Join-Path $sourceRoot ('compiler/UBE_Compiler_v3/src/'+$name)));if(@($declaredSources|Where-Object {[string]::Equals($_,$origin,[StringComparison]::OrdinalIgnoreCase)}).Count -ne 1){throw "Required promoted production source missing/duplicated:$name"};Copy-Item -LiteralPath $origin -Destination (Join-Path $projectDir $name)}
$coreManifest=[IO.Path]::GetFullPath((Join-Path $root 'std-lib/UBECore.UBE'));if(@($declaredReferences|Where-Object {[string]::Equals($_,$coreManifest,[StringComparison]::OrdinalIgnoreCase)}).Count -ne 1){throw 'Production compiler real Core reference differs'}
foreach($name in @('SharedSyntaxWork.cls','SourceContextWork.cls','Entry.bas','ContextEntry.bas')){Copy-Item -LiteralPath (Join-Path $fixture $name) -Destination (Join-Path $projectDir $name)}
$orderedNames=@('SourceOwner.cls','SourceWork.cls','SourceCancellation.cls','SharedSyntaxWork.cls','SourceContextWork.cls','SourceWorkerSlots.bas','SourceParsing.bas')+@($productionNames | Where-Object {$_ -notin @('SourceOwner.cls','SourceWork.cls','SourceCancellation.cls','SourceWorkerSlots.bas','SourceParsing.bas')})+@('Entry.bas','ContextEntry.bas')
$project=Join-Path $projectDir 'SourceParsingConsumer.UBE'
$projectLines=@('UBE-Project 1','Name = "SourceParsingConsumer"','Kind = "Exe"','Startup = "Main"',('Reference = "'+(([Uri]($projectDir+[IO.Path]::DirectorySeparatorChar)).MakeRelativeUri([Uri](Join-Path $sourceRoot 'std-lib/UBECore.UBE')).ToString())+'"'))+@($orderedNames | ForEach-Object {'Source = "'+$_+'"'})
[IO.File]::WriteAllText($project,($projectLines -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
$sources=@()
foreach($line in Get-Content -LiteralPath $project){if($line -match '^Source = "([^"]+)"'){$sources+=Join-Path $projectDir $Matches[1]}}
foreach($line in Get-Content -LiteralPath (Join-Path $sourceRoot 'std-lib/UBECore.UBE')){if($line -match '^Source = "([^"]+)"'){$sources+=Join-Path (Join-Path $sourceRoot 'std-lib') $Matches[1]}}
$procedures=@{};$classes=@();$types=@{};$procedureIndex=0
foreach($source in $sources){
 $text=[IO.File]::ReadAllText($source)
 if($text -match '^UBE SOURCE 1 CLASS'){$null=$text -match 'Attribute UBE_Name = "([^"]+)"';$classes+=$Matches[1]}
 foreach($m in [regex]::Matches($text,'(?m)^(?:(?:Public|Private|Friend) )?(?:Intrinsic )?(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)\b')){$name=$m.Groups[1].Value;if($procedures.ContainsKey($name)){throw "Duplicate ABI procedure $name"};$procedures[$name]='ube.p'+$procedureIndex;++$procedureIndex}
}
$typeIndex=0;foreach($name in $classes){$types[$name]='%ube.type.'+$typeIndex;++$typeIndex}
foreach($source in $sources){foreach($m in [regex]::Matches([IO.File]::ReadAllText($source),'(?m)^Type ([A-Za-z_][A-Za-z_0-9]*)\b')){$types[$m.Groups[1].Value]='%ube.type.'+$typeIndex;++$typeIndex}}
$corpusSources=@()
Copy-Item -LiteralPath (Join-Path $fixture 'corpus.h') -Destination (Join-Path $run 'corpus.h')
$runtime=[IO.File]::ReadAllText((Join-Path $sourceRoot 'bootstrap/runtime/bootstrap_runtime.c'))
$mutations=@([regex]::Matches($runtime,'(?m)^\s*ube_gc_live_bytes\s*(?:\+\+|--|<<=|>>=|[+*/%&|^-]=|=(?!=))[^;\r\n]*;')|ForEach-Object {$_.Value.Trim()});$expected=@('ube_gc_live_bytes += layout->size;','ube_gc_live_bytes += size;','ube_gc_live_bytes -= item->payload_size;','ube_gc_live_bytes -= item->payload_size;','ube_gc_live_bytes = 0;')
if((($mutations|Sort-Object)-join "`n") -cne (($expected|Sort-Object)-join "`n") -or [regex]::Matches($runtime,'(?:\+\+|--)\s*ube_gc_live_bytes|(?<!&)&(?!&)\s*ube_gc_live_bytes').Count){throw 'GC live-byte mutation inventory changed'}
if([regex]::Matches($runtime,'__atomic_(?:compare_exchange_n|fetch_sub|store_n)\(&ube_root_registry\.state,').Count -ne 3){throw 'Root-counter mutation inventory changed'}
$admission='(?m)^(\s*if\(__atomic_compare_exchange_n\(&ube_root_registry\.state,&current,current\+1,0,\r?\n\s*__ATOMIC_SEQ_CST,__ATOMIC_SEQ_CST\)\))return 1;'
if([regex]::Matches($runtime,$admission).Count -ne 1){throw 'Root admission observation ABI differs'}
# Observe the exact successful reservation value while its owner holds a stripe.
# This callback is atomic-only: it must never acquire the heap lock or allocate.
$runtime=[regex]::Replace($runtime,$admission,'${1}{observe_root_count((size_t)((current+1)&UBE_ROOT_COUNT_MASK));return 1;}')
foreach($increment in @('ube_gc_live_bytes += layout->size;','ube_gc_live_bytes += size;')){if([regex]::Matches($runtime,[regex]::Escape($increment)).Count -ne 1){throw 'Payload observation ABI differs'};$runtime=$runtime.Replace($increment,$increment+' observe_payload_count(ube_gc_live_bytes);')}
foreach($binding in @(@('EnterCriticalSection(&ube_gc_lock);','observe_lock_before(); EnterCriticalSection(&ube_gc_lock); observe_lock_after();'),@('LeaveCriticalSection(&ube_gc_lock);','observe_lock_release(); LeaveCriticalSection(&ube_gc_lock);'))){if([regex]::Matches($runtime,[regex]::Escape($binding[0])).Count -ne 1){throw 'Collector synchronization observation ABI differs'};$runtime=$runtime.Replace($binding[0],$binding[1])}
[IO.File]::WriteAllText((Join-Path $run 'observed_runtime.c'),$runtime,[Text.UTF8Encoding]::new($false))
$pinPaths=@($sources)+@($corpusSources | ForEach-Object {Join-Path $sourceRoot $_})+@($project,$PSCommandPath,$SelectionPath,(Join-Path $sourceRoot 'bootstrap/runtime/bootstrap_runtime.c'),(Join-Path $sourceRoot 'bootstrap/runtime/value_storage.h'),(Join-Path $sourceRoot 'compiler/UBE_Compiler_v3/CONCURRENCY-CONSUMER.md'),(Join-Path $sourceRoot 'compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE'))+@(Get-ChildItem -LiteralPath $fixture -File | ForEach-Object FullName)
$pinPaths+=@(Join-Path $sourceRoot 'compiler/UBE_Compiler_v3/CONCURRENCY-CONTRACT.md')
$pinPaths+=@((Join-Path $PSScriptRoot 'slot-proof.h'))
$pinPaths+=@($productionNames|ForEach-Object {Join-Path $root ('compiler/UBE_Compiler_v3/src/'+$_)})
$pinPaths+=@((Join-Path $PSScriptRoot 'EXPECTATIONS.md'))
$pinPaths+=@($coreManifest,$selection.manifest.path)
$pins=@($pinPaths | Sort-Object -Unique | ForEach-Object {Get-ArtifactIdentity $_})
$qualified=$false;$success=$false;$failure=$null;$commands=@();$path=Join-Path $run 'report.json';$checks=[Collections.Generic.List[object]]::new()
$reports=@();$priorHash=''
$stages=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
if($DiagnosticRawPath){$stages=@($stages[0])}
try {
foreach($stage in $stages){
 $stageDir=Join-Path $run ('stage'+$reports.Count);New-Item -ItemType Directory -Path $stageDir | Out-Null
 $rawPath=Join-Path $stageDir 'raw.ll';$adaptedPath=Join-Path $stageDir 'observed.ll';$exe=Join-Path $stageDir 'proof.exe'
 if($DiagnosticRawPath){Copy-Item -LiteralPath $DiagnosticRawPath -Destination $rawPath;$emit=[pscustomobject]@{timedOut=$false;exit=0;stdout='Unqualified development raw reuse';stderr=''}}else{$emit=Invoke-BoundedProcess $stage @($project,$rawPath) $root 900}
 $commands+=,$emit
 if($emit.timedOut -or $emit.exit -ne 0){throw ('UBE emission: '+$emit.stdout+$emit.stderr)}
 $hash=(Get-ArtifactIdentity $rawPath).sha256;if($priorHash -and $hash -cne $priorHash){throw 'Source-built stages emitted different consumer LLVM'};if($priorHash){$checks.Add([pscustomobject]@{assertion='Both accepted stages emitted identical source-worker consumer LLVM';passed=$true})};$priorHash=$hash
 $raw=[IO.File]::ReadAllText($rawPath);$adapter=[Text.StringBuilder]::new()
 $expectedLayouts=@{
  SourceWorkerSlots='i64, i64, i64, i64, i32, i32, i32, i32, i32, i32, i32, i32, i1, i32, i32, i32';
  SourceOwner=($types.SourceDocument+', i32');
  SourceWork=('ptr, ptr, ptr, '+$types.SyntaxFailure+', '+$types.SyntaxMetrics+', i64, i32, i32, i32, i32, i32');
  SourceCancellation='i1';
  SharedSyntaxWork=('ptr, ptr, '+$types.SyntaxFailure+', '+$types.SyntaxMetrics+', i64, i32');
  SourceContextWork=('ptr, ptr, ptr, '+$types.SourceSetFailure+', i64, i32')
  SourcePosition='i32, i32, i32, i32';SourceDocument='ptr, i32, i32, i32';
  SourceToken=('i32, '+$types.SourcePosition+', '+$types.SourcePosition);
  SyntaxNode='i32, i32, i32, i32, i32, i32';SyntaxResult='ptr, i32, i32, i32';
  SyntaxFailure='i32, i32, i32';SyntaxMetrics='i32, i32, i32, i32, i32';
  SourceSetFailure=('i32, i32, '+$types.SyntaxFailure)
 }
 foreach($name in $expectedLayouts.Keys){$line=$types[$name]+' = type { '+$expectedLayouts[$name]+' }';if([regex]::Matches($raw,'(?m)^'+[regex]::Escape($line)+'\r?$').Count -ne 1){throw "Independent payload field ABI differs: $name"}}
 function Definition([string]$Name,[string]$Return,[string]$Arguments){
  $symbol=$procedures[$Name];$found=[regex]::Matches($raw,'(?m)^define '+$Return+' @'+[regex]::Escape($symbol)+'\(([^\r\n]*)\) \{\r?$')
  if($found.Count -ne 1){throw "Absent exact ABI $Name"}
  $actual=@($found[0].Groups[1].Value -split ', '|ForEach-Object {($_ -split ' ')[0]}) -join ','
  if($actual -cne $Arguments){throw "ABI mismatch $Name expected $Arguments actual $actual"};return $symbol
 }
 foreach($helper in @(@('TryInitializeSourceWorkerSlots','i1','ptr,i32,i32'),@('SourceWorkerIdAt','i64','ptr,i32'),@('SourceWorkerIndexAt','i32','ptr,i32'),@('SetSourceWorkerSlot','void','ptr,i32,i64,i32'),@('RecordSourceWorkerFailure','void','ptr,i32,i32'),@('CommitSourceWorkerAdmission','void','ptr,i32,i64'),@('NextSourceWorkerAction','i32','ptr,i1,i1,ptr,ptr'))){
  $symbol=Definition $helper[0] $helper[1] $helper[2]
  $helperBody=[regex]::Match($raw,'(?ms)^define '+$helper[1]+' @'+[regex]::Escape($symbol)+'\([^\r\n]*\) \{.*?^\}').Value
  if($helperBody -match 'call [^\r\n]*@(?:ube_value_|ube_gc_|ube_array_|malloc\b|calloc\b|realloc\b)'){throw "Source worker helper acquired managed state: $($helper[0])"}
  $checks.Add([pscustomobject]@{assertion="Rootless scalar source-worker helper:$($helper[0]) through $stage";passed=$true})
 }
 $slotBindings=@(@('proof_slots_init','TryInitializeSourceWorkerSlots','i1','ptr,i32,i32'),@('proof_slots_commit','CommitSourceWorkerAdmission','void','ptr,i32,i64'),@('proof_slots_failure','RecordSourceWorkerFailure','void','ptr,i32,i32'),@('proof_slots_id','SourceWorkerIdAt','i64','ptr,i32'))
 foreach($binding in $slotBindings){
  $symbol=Definition $binding[1] $binding[2] $binding[3];$parts=$binding[3] -split ',';$arguments=@();$calls=@()
  for($i=0;$i -lt $parts.Count;++$i){$arguments+=($parts[$i]+' %a'+$i);$calls+=($parts[$i]+' %a'+$i)}
  $return=$binding[2];if($return -ceq 'i1'){$return='i32'}
  [void]$adapter.AppendLine('define '+$return+' @'+$binding[0]+'('+($arguments -join ', ')+') {')
  $call='call '+$binding[2]+' @'+$symbol+'('+($calls -join ', ')+')'
  if($return -ceq 'void'){[void]$adapter.AppendLine(' '+$call+"`n ret void")}else{[void]$adapter.AppendLine(' %result = '+$call);if($binding[2] -ceq 'i1'){[void]$adapter.AppendLine(" %status = zext i1 %result to i32`n ret i32 %status")}else{[void]$adapter.AppendLine(' ret '+$return+' %result')}}
  [void]$adapter.AppendLine('}')
 }
 $slotAction=Definition 'NextSourceWorkerAction' 'i32' 'ptr,i1,i1,ptr,ptr'
 [void]$adapter.AppendLine('define i32 @proof_slots_next(ptr %state, i32 %cancel, i32 %allow, ptr %slot, ptr %source) {'+"`n %c = trunc i32 %cancel to i1`n %a = trunc i32 %allow to i1`n %result = call i32 @"+$slotAction+"(ptr %state, i1 %c, i1 %a, ptr %slot, ptr %source)`n ret i32 %result`n}")
 [void]$adapter.AppendLine('define i64 @proof_slots_size() {'+"`n ret i64 ptrtoint (ptr getelementptr ("+$types.SourceWorkerSlots+", ptr null, i32 1) to i64)`n}")
 $bindings=@(@('proof_make','TryMakeSourceOwner','i1','ptr,i32,ptr'),@('proof_sources','TryParseSources','i1','ptr,i32,i32,i32,i32,i32,ptr,ptr,ptr'),@('proof_new_cancel','MakeSourceCancellation','void','ptr'),@('proof_make_shared','MakeSharedSyntaxWork','void','ptr,ptr'),@('proof_start_shared','StartSharedSyntax','i64','ptr'),@('proof_make_context','MakeSourceContext','void','ptr,ptr'),@('proof_start_context','StartSourceContext','i64','ptr'))
 foreach($b in $bindings){$symbol=Definition $b[1] $b[2] $b[3];$args=@();$calls=@();$parts=$b[3] -split ',';for($i=0;$i -lt $parts.Count;++$i){$args+=$parts[$i]+' %a'+$i;$calls+=$parts[$i]+' %a'+$i};$return=$b[2];if($return -ceq 'i1'){$return='i32'};[void]$adapter.AppendLine('define '+$return+' @'+$b[0]+'('+($args -join ', ')+') {');$call='call '+$b[2]+' @'+$symbol+'('+($calls -join ', ')+')';if($b[2] -ceq 'void'){[void]$adapter.AppendLine(' '+$call+"`n ret void")}elseif($b[2] -ceq 'i1'){[void]$adapter.AppendLine(' %ok = '+$call+"`n %status = zext i1 %ok to i32`n ret i32 %status")}else{[void]$adapter.AppendLine(' %result = '+$call+"`n ret "+$return+' %result')};[void]$adapter.AppendLine('}')}
 $adapted=[regex]::Replace($raw,'(?m)^define i32 @main\(','define i32 @proof_unused_main(')
 $slotMatch=[regex]::Match($adapted,'(?ms)^define i32 @'+[regex]::Escape($slotAction)+'\([^\r\n]*\) \{.*?^\}');$slotBody=$slotMatch.Value
 foreach($redirect in @(@('ube_thread_try_wait','i64, i64, ptr','observed_slot_wait'),@('ube_thread_try_request_stop','i64, ptr','observed_slot_stop'),@('ube_thread_try_yield','','observed_slot_yield'))){
  if([regex]::Matches($slotBody,'call i32 @'+$redirect[0]+'\(').Count -ne 1){throw 'Expected one bounded slot native wait/stop/yield site'}
  $slotBody=$slotBody.Replace('call i32 @'+$redirect[0]+'(','call i32 @'+$redirect[2]+'(')
  [void]$adapter.AppendLine('declare i32 @'+$redirect[2]+'('+$redirect[1]+')')
 }
 $adapted=$adapted.Substring(0,$slotMatch.Index)+$slotBody+$adapted.Substring($slotMatch.Index+$slotMatch.Length)
 $workSymbol=Definition 'ProcessSourceWork' 'void' 'ptr,ptr'
 $pattern='(?ms)^define void @'+[regex]::Escape($workSymbol)+'\(([^\r\n]*)\) \{.*?^\}'
 $m=[regex]::Match($adapted,$pattern);$body=$m.Value
 if([regex]::Matches($body,'call i32 @ube_value_root_enter\(').Count -lt 1 -or [regex]::Matches($body,'call i32 @ube_value_root_enter\(').Count -gt 128){throw 'Worker wrapper exceeds predefined root bound'}
 $coordinator=Definition 'TryParseSources' 'i1' 'ptr,i32,i32,i32,i32,i32,ptr,ptr,ptr'
 $coordinatorBody=[regex]::Match($raw,'(?ms)^define i1 @'+[regex]::Escape($coordinator)+'\([^\r\n]*\) \{.*?^\}').Value
 if([regex]::Matches($coordinatorBody,'call i32 @ube_value_root_enter\(').Count -lt 1 -or [regex]::Matches($coordinatorBody,'call i32 @ube_value_root_enter\(').Count -gt 256){throw 'Coordinator exceeds predefined root bound'}
 if($body -notmatch '(?m)^thread.body:\r?$'){throw 'Missing checked worker admission label'}
 $workArgument=($m.Groups[1].Value -split ', ')[0] -replace '^ptr ',''
 $body=[regex]::Replace($body,'(?m)^thread.body:\r?$','thread.body:'+"`n call void @observe_work_enter(ptr $workArgument)")
 $body=[regex]::Replace($body,'(?m)^proc.exit:\r?$','proc.exit:'+"`n call void @observe_work_exit(ptr $workArgument)")
 $adapted=$adapted.Substring(0,$m.Index)+$body+$adapted.Substring($m.Index+$m.Length)
 $contextSymbol=Definition 'ProcessSourceContext' 'void' 'ptr,ptr'
 $contextMatch=[regex]::Match($adapted,'(?ms)^define void @'+[regex]::Escape($contextSymbol)+'\(([^\r\n]*)\) \{.*?^\}')
 $contextArgument=($contextMatch.Groups[1].Value -split ', ')[0] -replace '^ptr ',''
 $contextBody=[regex]::Replace($contextMatch.Value,'(?m)^thread.body:\r?$','thread.body:'+"`n call void @observe_context_enter(ptr $contextArgument)")
 $adapted=$adapted.Substring(0,$contextMatch.Index)+$contextBody+$adapted.Substring($contextMatch.Index+$contextMatch.Length)
 [void]$adapter.AppendLine('declare void @observe_context_enter(ptr)')
 [void]$adapter.AppendLine("declare void @observe_work_enter(ptr)`ndeclare void @observe_work_exit(ptr)`ndeclare void @observe_publication(ptr)`ndeclare void @observe_publication_end()")
 $pub=Definition 'TryPublishSourceWorks' 'i1' 'ptr,ptr,ptr,ptr'
 $adapted=[regex]::Replace($adapted,'(?m)^define i1 @'+[regex]::Escape($pub)+'\(','define i1 @proof_publish_body(')
 [void]$adapter.AppendLine('define i1 @'+$pub+"(ptr %a0, ptr %a1, ptr %a2, ptr %a3) {`n call void @observe_publication(ptr %a0)`n %ok = call i1 @proof_publish_body(ptr %a0, ptr %a1, ptr %a2, ptr %a3)`n call void @observe_publication_end()`n ret i1 %ok`n}")
 foreach($b in @(@('i32','ube_value_try_resize','ptr, i32, ptr, i32','observed_resize'),@('i32','ube_value_assign','ptr, ptr, ptr','observed_assign'),@('ptr','ube_value_array_element','ptr, i32, ptr, ptr, ptr','observed_element'))){$adapted=$adapted.Replace('call '+$b[0]+' @'+$b[1]+'(','call '+$b[0]+' @'+$b[3]+'(');[void]$adapter.AppendLine('declare '+$b[0]+' @'+$b[3]+'('+$b[2]+')')}
 $adapted=$adapted.Replace('call i64 @ube_thread_start_checked(','call i64 @observed_start(');[void]$adapter.AppendLine('declare i64 @observed_start(ptr, ptr, ptr)')
 [void]$adapter.AppendLine("define ptr @proof_layout(i32 %role) {`n switch i32 %role, label %invalid [")
 for($i=0;$i -le 5;++$i){[void]$adapter.AppendLine(" i32 $i, label %l$i")};[void]$adapter.AppendLine("]`ninvalid:`n ret ptr null")
 for($i=0;$i -le 5;++$i){$id=20000+$i;if($i -eq 4){$id=7};if($i -eq 5){$id=20004};if($raw -notmatch [regex]::Escape('@ube.value.'+$id+' = private constant')){throw 'Missing actual layout'};[void]$adapter.AppendLine("l${i}:`n ret ptr @ube.value.$id")};[void]$adapter.AppendLine('}')
 [void]$adapter.AppendLine("define i64 @proof_payload_size(i32 %role) {`n switch i32 %role, label %bad [")
 for($i=0;$i -lt 5;++$i){[void]$adapter.AppendLine(" i32 $i, label %p$i")};[void]$adapter.AppendLine("]`nbad:`n ret i64 -1")
 for($i=0;$i -lt 5;++$i){[void]$adapter.AppendLine("p${i}:`n ret i64 ptrtoint (ptr getelementptr ("+$types[$classes[$i]]+", ptr null, i32 1) to i64)")};[void]$adapter.AppendLine('}')
 [void]$adapter.AppendLine("define ptr @proof_object_layout(i32 %role) {`n switch i32 %role, label %invalid [")
 for($i=0;$i -lt 5;++$i){[void]$adapter.AppendLine(" i32 $i, label %o$i")};[void]$adapter.AppendLine("]`ninvalid:`n ret ptr null")
 for($i=0;$i -lt 5;++$i){if($raw -notmatch [regex]::Escape('@ube.object.'+$i+' = private constant %ube.gc.layout')){throw 'Missing actual class payload metadata'};[void]$adapter.AppendLine("o${i}:`n ret ptr @ube.object.$i")};[void]$adapter.AppendLine('}')
 [IO.File]::WriteAllText($adaptedPath,$adapted+"`n"+$adapter.ToString(),[Text.UTF8Encoding]::new($false))
 $link=Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-I',$run,'-I',$PSScriptRoot,'-I',(Join-Path $sourceRoot 'bootstrap/runtime'),'-x','ir',$adaptedPath,'-x','c',(Join-Path $fixture 'proof.c'),'-x','none',$selection.unicodeRuntime.path,'-o',$exe) $root 180
 $commands+=,$link
 if($link.timedOut -or $link.exit -ne 0){throw ('Native link: '+$link.stdout+$link.stderr)}
 $nativeArguments=@();if($DiagnosticSuite){$nativeArguments+=('--'+$DiagnosticSuite)}
 $native=Invoke-BoundedProcess $exe $nativeArguments $root 600
 $commands+=,$native
 $reports+=[pscustomobject]@{compiler=(Get-ArtifactIdentity $stage);raw=(Get-ArtifactIdentity $rawPath);exe=(Get-ArtifactIdentity $exe);emit=$emit;link=$link;native=$native}
 Write-Output $native.stdout;Write-Output $native.stderr
 if($native.timedOut -or $native.exit -ne 0 -or $native.stderr -cne '' -or $native.stdout -notmatch '"assertions":4255,"passed":true' -or $native.stdout -notmatch 'PASS actual UBE source-set proof'){throw 'Actual complete4255 source-worker assertions failed'}
$checks.Add([pscustomobject]@{assertion="All4255 intact UBE source-worker/controller native assertions through $stage";passed=$true})
$rows=@($native.stdout -split "`n"|Where-Object {$_.StartsWith('{')}|ForEach-Object {$_|ConvertFrom-Json})
$sourceRows=@($rows|Where-Object suite -CEQ 'sources');if($sourceRows.Count -ne 6){throw 'Complete repeated jobs1/2/4 required'}
foreach($row in $sourceRows){if($row.units -ne 33 -or $row.sourceCopies -ne 0 -or $row.captureBytes -ne 264 -or $row.peakActive -ne $row.jobs -or ($row.jobs -gt 1 -and $row.operationSwitches -le 0)){throw 'Actual source overlap/capture/ownership budgets differ'}}
$slotRows=@($rows|Where-Object suite -CEQ 'rootless-worker-slots');if($slotRows.Count -ne 1 -or -not $slotRows[0].passed -or $slotRows[0].bytes -ne 80 -or $slotRows[0].rootlessHelpers -ne 7 -or -not $slotRows[0].fullRootRegistry -or -not $slotRows[0].allocatorDenied -or -not $slotRows[0].failedWaitRetained -or -not $slotRows[0].failedStopRetained){throw 'Full registry/rootless control/drain proof missing'}
$checks.Add([pscustomobject]@{assertion="Repeated jobs1/2/4 actual overlap/capture/no-source-copy plus full-registry allocator-denied controller/drain controls through $stage";passed=$true})
}
foreach($pin in $pins){$now=Get-ArtifactIdentity $pin.path;if($pin.sha256 -cne $now.sha256 -or $pin.bytes -ne $now.bytes){throw "Concurrency proof input changed: $($pin.path)"}}
$null=Get-VerifiedBootstrapSelection $SelectionPath
$success=$true;$qualified=-not $DiagnosticOnly -and $reports.Count -eq 2
}catch{$failure=$_.Exception.Message;throw}finally{
 $generated=@(Get-ChildItem -LiteralPath $run -File -Recurse | Where-Object Name -NE 'report.json' | ForEach-Object {Get-ArtifactIdentity $_.FullName})
 [pscustomobject]@{schema='ube-source-worker-slots-native-1';success=$success;qualified=$qualified;draftOnly=$false;productionIntegrated=$qualified;sourceBuildCurrent=$qualified;diagnosticOnly=[bool]$DiagnosticOnly;diagnosticSuite=$DiagnosticSuite;failure=$failure;acceptedSelection=$selection;checks=$checks.ToArray();inputs=$pins;corpusSources=@($corpusSources|ForEach-Object {Get-ArtifactIdentity (Join-Path $sourceRoot $_)});reports=$reports;commands=$commands;artifacts=$generated;scope='Actual promoted production controller/source parser and real Core through both accepted source-built stages. Frozen33-case independent corpus preserves4255 assertions; scanner/parser/workers are intact UBE. No semantic-worker or production speedup claim.'} | ConvertTo-Json -Depth 18 | Set-Content -LiteralPath $path -Encoding UTF8
 Write-Output ('Evidence: '+$path)
}
if($qualified){Write-Output '2 source-built stage concurrency proof groups passed.'}else{Write-Output 'Diagnostic only; compiler concurrency remains unqualified by this report.'}

