param(
 [string]$SelectionPath=(Join-Path $PSScriptRoot '../../../bootstrap/out/v2/current.json'),
 [switch]$DiagnosticOnly,
 [string]$DiagnosticRawPath='',
 [ValidateSet('','boundaries','faults','fixtures')][string]$DiagnosticSuite=''
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$fixture=Join-Path $root 'compiler/UBE_Compiler_v3/tests/concurrency'
if($DiagnosticRawPath -or $DiagnosticSuite){$DiagnosticOnly=$true}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
if($DiagnosticOnly){$selection=Get-Content -LiteralPath $SelectionPath -Raw | ConvertFrom-Json}else{$selection=Get-VerifiedBootstrapSelection $SelectionPath}
$run=Join-Path $root ('bootstrap/out/source-set-proof/'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$projectDir=Join-Path $run 'project'
New-Item -ItemType Directory -Path $projectDir | Out-Null
$productionNames=@('SourceOwner.cls','SourceWork.cls','SourceCancellation.cls','SourceParsing.bas','SourceInput.bas','SourceFile.bas','ScannerWords.bas','SourceScanner.bas','SourceEnvelope.bas','SyntaxTree.bas','SyntaxExpressions.bas','SyntaxGrammar.bas','SourceSyntax.bas')
foreach($name in $productionNames){Copy-Item -LiteralPath (Join-Path $root ('compiler/UBE_Compiler_v3/'+$name)) -Destination (Join-Path $projectDir $name)}
foreach($name in @('SharedSyntaxWork.cls','SourceContextWork.cls','Entry.bas','ContextEntry.bas')){Copy-Item -LiteralPath (Join-Path $fixture $name) -Destination (Join-Path $projectDir $name)}
$orderedNames=@('SourceOwner.cls','SourceWork.cls','SourceCancellation.cls','SharedSyntaxWork.cls','SourceContextWork.cls','SourceParsing.bas')+@($productionNames | Where-Object {$_ -notin @('SourceOwner.cls','SourceWork.cls','SourceCancellation.cls','SourceParsing.bas')})+@('Entry.bas','ContextEntry.bas')
$project=Join-Path $projectDir 'SourceParsingConsumer.UBE'
$projectLines=@('UBE-Project 1','Name = "SourceParsingConsumer"','Kind = "Exe"','Startup = "Main"','Reference = "../../../../../std-lib/UBECore.UBE"')+@($orderedNames | ForEach-Object {'Source = "'+$_+'"'})
[IO.File]::WriteAllText($project,($projectLines -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
$sources=@()
foreach($line in Get-Content -LiteralPath $project){if($line -match '^Source = "([^"]+)"'){$sources+=Join-Path $projectDir $Matches[1]}}
foreach($line in Get-Content -LiteralPath std-lib/UBECore.UBE){if($line -match '^Source = "([^"]+)"'){$sources+=Join-Path (Join-Path $root 'std-lib') $Matches[1]}}
$procedures=@{};$classes=@();$types=@{};$procedureIndex=0
foreach($source in $sources){
 $text=[IO.File]::ReadAllText($source)
 if($text -match '^UBE SOURCE 1 CLASS'){$null=$text -match 'Attribute UBE_Name = "([^"]+)"';$classes+=$Matches[1]}
 foreach($m in [regex]::Matches($text,'(?m)^(?:(?:Public|Private|Friend) )?(?:Intrinsic )?(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)\b')){$name=$m.Groups[1].Value;if($procedures.ContainsKey($name)){throw "Duplicate ABI procedure $name"};$procedures[$name]='ube.p'+$procedureIndex;++$procedureIndex}
}
$typeIndex=0;foreach($name in $classes){$types[$name]='%ube.type.'+$typeIndex;++$typeIndex}
foreach($source in $sources){foreach($m in [regex]::Matches([IO.File]::ReadAllText($source),'(?m)^Type ([A-Za-z_][A-Za-z_0-9]*)\b')){$types[$m.Groups[1].Value]='%ube.type.'+$typeIndex;++$typeIndex}}
$corpus=@()
$corpus+=,[Text.Encoding]::UTF8.GetBytes("UBE SOURCE 1 MODULE`nAttribute UBE_Name = ""Tiny""`n")
$nonAscii=([string][char]0x00E6)+[char]0x4E2D+[char]0x6587+[char]::ConvertFromUtf32(0x1F600)
$corpus+=,([byte[]]@(239,187,191)+[Text.Encoding]::UTF8.GetBytes("UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = ""BomTiny""`r`n' $nonAscii`r`n"))
foreach($size in @(1,8,32,128)){
 $lines=@('UBE SOURCE 1 MODULE','Attribute UBE_Name = "Growing"','Function Sum() As Long',' Dim Value As Long = 0')
 for($i=0;$i -lt $size;++$i){$lines+=' Value = Value + 1'}
 $lines+=@(' Sum = Value','End Function')
 $corpus+=,[Text.Encoding]::UTF8.GetBytes(($lines -join "`n")+"`n")
}
$corpus+=,[Text.Encoding]::UTF8.GetBytes("UBE SOURCE 1 MODULE`nAttribute UBE_Name = ""Nested""`nFunction Nested() As Long`n If True Then`n  Nested = 1`n End If`nEnd Function`n")
$corpusSources=@()
foreach($manifest in @('compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE','std-lib/UBECore.UBE')){
 foreach($line in Get-Content -LiteralPath $manifest){if($line -match '^Source = "([^"]+)"'){$source=Join-Path (Split-Path $manifest -Parent) $Matches[1];if($source -like '*.bas'){$corpusSources+=$source}}}
}
foreach($source in $corpusSources){$corpus+=,[IO.File]::ReadAllBytes($source)}
$corpus+=,[Text.Encoding]::UTF8.GetBytes("UBE SOURCE 1 MODULE`nAttribute UBE_Name = ""Unicode""`n' $nonAscii`nFunction Answer() As Long`n Answer = 42`nEnd Function`n")
$corpus+=,[Text.Encoding]::UTF8.GetBytes("UBE SOURCE 1 MODULE`nAttribute UBE_Name = ""Reject""`nType EmptyRecord`nEnd Type`n")
$corpus+=,[Text.Encoding]::UTF8.GetBytes("UBE SOURCE 1 MODULE`nAttribute UBE_Name = ""Deferred""`nEnum Choice As Long`n First = 1`nEnd Enum`n")
$header=[Text.StringBuilder]::new();[void]$header.AppendLine('struct corpus_case {const unsigned char* data;int bytes;};')
for($i=0;$i -lt $corpus.Count;++$i){[void]$header.AppendLine('static const unsigned char bytes_'+$i+'[] = {'+($corpus[$i] -join ',')+'};')}
[void]$header.AppendLine('static const struct corpus_case corpus[] = {')
for($i=0;$i -lt $corpus.Count;++$i){[void]$header.AppendLine('{bytes_'+$i+','+$corpus[$i].Length+'},')}
[void]$header.AppendLine('};static const int corpus_count='+$corpus.Count+';static const int corpus_depth_case=6;')
[IO.File]::WriteAllText((Join-Path $run 'corpus.h'),$header.ToString(),[Text.UTF8Encoding]::new($false))
$runtime=[IO.File]::ReadAllText((Join-Path $root 'runtime/bootstrap_runtime.c'))
if([regex]::Matches($runtime,[regex]::Escape('ube_gc_root_count += 1;')).Count -ne 2){throw 'Root admission observation ABI differs'}
$runtime=$runtime.Replace('ube_gc_root_count += 1;','ube_gc_root_count += 1; observe_root_count(ube_gc_root_count);')
foreach($increment in @('ube_gc_live_bytes += layout->size;','ube_gc_live_bytes += size;')){if([regex]::Matches($runtime,[regex]::Escape($increment)).Count -ne 1){throw 'Payload observation ABI differs'};$runtime=$runtime.Replace($increment,$increment+' observe_payload_count(ube_gc_live_bytes);')}
foreach($binding in @(@('EnterCriticalSection(&ube_gc_lock);','observe_lock_before(); EnterCriticalSection(&ube_gc_lock); observe_lock_after();'),@('LeaveCriticalSection(&ube_gc_lock);','observe_lock_release(); LeaveCriticalSection(&ube_gc_lock);'))){if([regex]::Matches($runtime,[regex]::Escape($binding[0])).Count -ne 1){throw 'Collector synchronization observation ABI differs'};$runtime=$runtime.Replace($binding[0],$binding[1])}
[IO.File]::WriteAllText((Join-Path $run 'observed_runtime.c'),$runtime,[Text.UTF8Encoding]::new($false))
$pinPaths=@($sources)+@($corpusSources | ForEach-Object {Join-Path $root $_})+@($project,$PSCommandPath,$SelectionPath,(Join-Path $root 'runtime/bootstrap_runtime.c'),(Join-Path $root 'runtime/value_storage.h'),(Join-Path $root 'compiler/UBE_Compiler_v3/CONCURRENCY-CONSUMER.md'),(Join-Path $root 'compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE'))+@(Get-ChildItem -LiteralPath $fixture -File | ForEach-Object FullName)
$pinPaths+=Join-Path $root 'compiler/UBE_Compiler_v3/CONCURRENCY-CONTRACT.md'
$pins=@($pinPaths | Sort-Object -Unique | ForEach-Object {Get-ArtifactIdentity $_})
$qualified=$false;$success=$false;$failure=$null;$commands=@();$path=Join-Path $run 'report.json'
$reports=@();$priorHash=''
$stages=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
if($DiagnosticRawPath){$stages=@($stages[0])}
try {
foreach($stage in $stages){
 $stageDir=Join-Path $run ('stage'+$reports.Count);New-Item -ItemType Directory -Path $stageDir | Out-Null
 $rawPath=Join-Path $stageDir 'raw.ll';$adaptedPath=Join-Path $stageDir 'observed.ll';$exe=Join-Path $stageDir 'proof.exe'
 if($DiagnosticRawPath){Copy-Item -LiteralPath $DiagnosticRawPath -Destination $rawPath;$emit=[pscustomobject]@{timedOut=$false;exit=0;stdout='Unqualified development raw reuse';stderr=''}}else{$emit=Invoke-BoundedProcess $stage @($project,$rawPath) $root 180}
 $commands+=,$emit
 if($emit.timedOut -or $emit.exit -ne 0){throw ('UBE emission: '+$emit.stdout+$emit.stderr)}
 $hash=(Get-ArtifactIdentity $rawPath).sha256;if($priorHash -and $hash -cne $priorHash){throw 'Source-built stages emitted different consumer LLVM'};$priorHash=$hash
 $raw=[IO.File]::ReadAllText($rawPath);$adapter=[Text.StringBuilder]::new()
 $expectedLayouts=@{
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
 $bindings=@(@('proof_make','TryMakeSourceOwner','i1','ptr,i32,ptr'),@('proof_sources','TryParseSources','i1','ptr,i32,i32,i32,i32,i32,ptr,ptr,ptr'),@('proof_new_cancel','MakeSourceCancellation','void','ptr'),@('proof_make_shared','MakeSharedSyntaxWork','void','ptr,ptr'),@('proof_start_shared','StartSharedSyntax','i64','ptr'),@('proof_make_context','MakeSourceContext','void','ptr,ptr'),@('proof_start_context','StartSourceContext','i64','ptr'))
 foreach($b in $bindings){$symbol=Definition $b[1] $b[2] $b[3];$args=@();$calls=@();$parts=$b[3] -split ',';for($i=0;$i -lt $parts.Count;++$i){$args+=$parts[$i]+' %a'+$i;$calls+=$parts[$i]+' %a'+$i};$return=$b[2];if($return -ceq 'i1'){$return='i32'};[void]$adapter.AppendLine('define '+$return+' @'+$b[0]+'('+($args -join ', ')+') {');$call='call '+$b[2]+' @'+$symbol+'('+($calls -join ', ')+')';if($b[2] -ceq 'void'){[void]$adapter.AppendLine(' '+$call+"`n ret void")}elseif($b[2] -ceq 'i1'){[void]$adapter.AppendLine(' %ok = '+$call+"`n %status = zext i1 %ok to i32`n ret i32 %status")}else{[void]$adapter.AppendLine(' %result = '+$call+"`n ret "+$return+' %result')};[void]$adapter.AppendLine('}')}
 $adapted=[regex]::Replace($raw,'(?m)^define i32 @main\(','define i32 @proof_unused_main(')
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
 $link=Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-I',$run,'-I',(Join-Path $root 'runtime'),'-x','ir',$adaptedPath,'-x','c',(Join-Path $fixture 'proof.c'),'-x','none',$selection.unicodeRuntime.path,'-o',$exe) $root 180
 $commands+=,$link
 if($link.timedOut -or $link.exit -ne 0){throw ('Native link: '+$link.stdout+$link.stderr)}
 $nativeArguments=@();if($DiagnosticSuite){$nativeArguments+=('--'+$DiagnosticSuite)}
 $native=Invoke-BoundedProcess $exe $nativeArguments $root 600
 $commands+=,$native
 $reports+=[pscustomobject]@{compiler=(Get-ArtifactIdentity $stage);raw=(Get-ArtifactIdentity $rawPath);exe=(Get-ArtifactIdentity $exe);emit=$emit;link=$link;native=$native}
 Write-Output $native.stdout;Write-Output $native.stderr
 if($native.timedOut -or $native.exit -ne 0 -or $native.stdout -notmatch 'PASS actual UBE source-set proof'){throw 'Actual UBE source-set assertions failed'}
}
foreach($pin in $pins){$now=Get-ArtifactIdentity $pin.path;if($pin.sha256 -cne $now.sha256 -or $pin.bytes -ne $now.bytes){throw "Concurrency proof input changed: $($pin.path)"}}
if(-not $DiagnosticOnly){$null=Get-VerifiedBootstrapSelection $SelectionPath}
$success=$true;$qualified=-not $DiagnosticOnly -and $reports.Count -eq 2
}catch{$failure=$_.Exception.Message;throw}finally{
 $generated=@(Get-ChildItem -LiteralPath $run -File -Recurse | Where-Object Name -NE 'report.json' | ForEach-Object {Get-ArtifactIdentity $_.FullName})
 [pscustomobject]@{schema='ube-source-concurrency-1';success=$success;qualified=$qualified;diagnosticOnly=[bool]$DiagnosticOnly;diagnosticSuite=$DiagnosticSuite;failure=$failure;acceptedSelection=$selection;inputs=$pins;corpusSources=@($corpusSources|ForEach-Object {Get-ArtifactIdentity (Join-Path $root $_)});reports=$reports;commands=$commands;artifacts=$generated;scope='Actual intact UBE coordinator, scanner and parser. Independent native assertions and observations; instrumented timing is not production speedup evidence.'} | ConvertTo-Json -Depth 18 | Set-Content -LiteralPath $path -Encoding UTF8
 Write-Output ('Evidence: '+$path)
}
if($qualified){Write-Output '2 source-built stage concurrency proof groups passed.'}else{Write-Output 'Diagnostic only; compiler concurrency remains unqualified by this report.'}

