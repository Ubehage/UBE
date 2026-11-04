param([string]$SelectionPath='',[string]$ToolPath='',[string]$OutputRoot='')
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$repo=$PSScriptRoot;while(-not [IO.File]::Exists((Join-Path $repo 'bootstrap/tools/verification.ps1'))){$parent=Split-Path $repo -Parent;if(-not $parent -or $parent -eq $repo){throw 'Repository root not found'};$repo=$parent}
. (Join-Path $repo 'bootstrap/tools/verification.ps1')
$foundation=Join-Path $repo 'compiler/UBE_Compiler_v3/tests/semantic/native'
. (Join-Path $foundation 'observer.ps1')
. (Join-Path $foundation 'abi.ps1')
. (Join-Path $foundation 'project.ps1')
if($SelectionPath -ceq ''){$SelectionPath=Join-Path $repo 'bootstrap/out/v2/current.json'}
$selection=Get-VerifiedBootstrapSelection $SelectionPath
if($ToolPath -ceq ''){$ToolPath=$selection.compiler.path}
if(-not $OutputRoot){$OutputRoot=Join-Path $repo 'bootstrap/out/semantic-whole'};$run=Join-Path $OutputRoot ([Guid]::NewGuid().ToString('N'));$project=Join-Path $run 'project';$null=New-Item -ItemType Directory -Path $project -Force
$utf8=New-Object Text.UTF8Encoding($false);$inputs=@();$inputChanges=@();$commands=@();$success=$false;$failure=$null;$nativeRecords=@();$observer=$null;$wholeObserver=$null;$mapping=$null
$base=Join-Path $repo 'compiler/UBE_Compiler_v3';$paths=@();$lines=@('UBE-Project 1','Name = "SemanticWholeSourceFixture"','Kind = "Exe"','Startup = "Main"')
foreach($line in [IO.File]::ReadAllLines((Join-Path $base 'UBE_Compiler_v3.UBE'))){if($line -match '^Source = "([^"]+)"$'){$paths+=@(Join-Path $base $Matches[1])}}
$required=@('SemanticChecking.bas','SemanticStatements.bas','SourceWorkerSlots.bas');foreach($name in $required){if(@($paths|Where-Object {(Split-Path $_ -Leaf) -ceq $name}).Count -ne 1){throw "Production compiler manifest must contain exactly one $name"}}
$paths+=@((Join-Path $PSScriptRoot 'Entry.bas'))
$seen=@{};foreach($path in $paths){$name=Split-Path $path -Leaf;if($seen.ContainsKey($name)){throw "Duplicate whole-check source $name"};$seen[$name]=$true;$text=[IO.File]::ReadAllText($path);if($name -ceq 'Main.bas'){$text=[regex]::Replace($text,'(?ms)^Function Main\(\) As Long\r?\n.*?^End Function\r?\n?','')};[IO.File]::WriteAllText((Join-Path $project $name),$text,$utf8);$inputs+=@(Get-ArtifactIdentity $path);$lines+='Source = "'+$name+'"'}
$core=Join-Path $project 'core';$null=New-Item -ItemType Directory -Path $core
$coreLines=@('UBE-Project 1','Name = "UBECore"','Kind = "Library"');$coreManifest=Join-Path $repo 'std-lib/UBECore.UBE'
foreach($line in [IO.File]::ReadAllLines($coreManifest)){if($line -match '^Source = "([^"]+)"$'){$path=Join-Path (Join-Path $repo 'std-lib') $Matches[1];$name=Split-Path $path -Leaf;[IO.File]::Copy($path,(Join-Path $core $name));$inputs+=@(Get-ArtifactIdentity $path);$coreLines+='Source = "'+$name+'"'}}
[IO.File]::WriteAllText((Join-Path $core 'UBECore.UBE'),($coreLines -join "`n")+"`n",$utf8)
$lines+='Reference = "core/UBECore.UBE"';$manifest=Join-Path $project 'Whole.UBE';[IO.File]::WriteAllText($manifest,($lines -join "`n")+"`n",$utf8)
$sources=@(Get-FoundationProjectSources $manifest);$procedures=@{};$types=@{};$classes=@();$ordinal=0
foreach($source in $sources){$text=[IO.File]::ReadAllText($source);if($text -match '^UBE SOURCE 1 CLASS'){$null=$text -match 'Attribute UBE_Name = "([^"]+)"';$classes+=@($Matches[1])};foreach($match in [regex]::Matches($text,'(?m)^(?:(?:Public|Private|Friend) )?(?:Intrinsic )?(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)\b')){$name=$match.Groups[1].Value;if($procedures.ContainsKey($name)){throw "Duplicate whole-check procedure $name"};$procedures[$name]='ube.p'+$ordinal;++$ordinal}}
$ordinal=0;foreach($name in $classes){$types[$name]='%ube.type.'+$ordinal;++$ordinal};foreach($source in $sources){foreach($match in [regex]::Matches([IO.File]::ReadAllText($source),'(?m)^Type ([A-Za-z_][A-Za-z_0-9]*)\b')){$types[$match.Groups[1].Value]='%ube.type.'+$ordinal;++$ordinal}}
$mapping=[pscustomobject]@{procedures=$procedures;types=$types}
$bytes=[IO.File]::ReadAllBytes((Join-Path $foundation 'complete/sources/scalar-context-and-storage/ScalarApp.bas'));[IO.File]::WriteAllText((Join-Path $run 'scalar-source.h'),'static const char scalar_source[]={'+(($bytes+0) -join ',')+'};'+"`n",$utf8)
foreach($file in @('probe.c','scalar-complete.h','EXPECTATIONS.md')){[IO.File]::Copy((Join-Path $PSScriptRoot $file),(Join-Path $run $file))}
$inputs+=@(Get-ArtifactIdentity (Join-Path $base 'UBE_Compiler_v3.UBE'));$inputs+=@($sources|ForEach-Object {Get-ArtifactIdentity $_})+@($coreManifest,$SelectionPath,$ToolPath,$PSCommandPath,(Join-Path $PSScriptRoot 'probe.c'),(Join-Path $PSScriptRoot 'scalar-complete.h'),(Join-Path $foundation 'complete/sources/scalar-context-and-storage/ScalarApp.bas'),(Join-Path $PSScriptRoot 'EXPECTATIONS.md'),(Join-Path $foundation 'observer.ps1'),(Join-Path $foundation 'abi.ps1'),(Join-Path $foundation 'project.ps1')|ForEach-Object {Get-ArtifactIdentity $_})
try{
 $rawPath=Join-Path $run 'whole.ll';$record=Invoke-BoundedProcess $ToolPath @($manifest,$rawPath) $repo 900;$commands+=@($record);if($record.timedOut -or $record.exit -ne 0){throw ($record|ConvertTo-Json -Compress)}
 $raw=[IO.File]::ReadAllText($rawPath);$adapter=New-Object Text.StringBuilder
 $null=Assert-FoundationRecord $raw $mapping 'SemanticFact' 'i32, i32, i32, i32, i64, i32, i32, i32, i32, i32, i32'
 $null=Assert-FoundationRecord $raw $mapping 'BoundNode' 'i32, i32, i32, i32, i64, i32, i32, i32, i32, i32, i32'
 $null=Assert-FoundationRecord $raw $mapping 'SemanticDeclaration' 'i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i64'
 $null=Assert-FoundationRecord $raw $mapping 'SemanticModuleResult' ('ptr, i32, ptr, i32, ptr, i32, i32, '+$types.SemanticMetrics)
 $null=Assert-FoundationRecord $raw $mapping 'SemanticResult' 'ptr, ptr, i32'
 $null=Assert-FoundationRecord $raw $mapping 'SemanticSource' ('ptr, '+$types.SourceEnvelope+', i32, i32, i32, i32, i32, i32, ptr')
 foreach($binding in @(@('statement_make','TryMakeStatementSource','i1','ptr,i32,i32,ptr,ptr'),@('statement_cancel','TryMakeStatementCancellation','i1','ptr'),@('statement_check','TryCheckStatementSource','i1','ptr,i32,ptr,ptr,ptr,ptr'),@('statement_project_make','TryMakeStatementProject','i1','ptr,i32,ptr,ptr,ptr'),@('statement_project_check','TryCheckStatementProject','i1','ptr,i32,ptr,ptr,ptr,ptr'))){Add-FoundationBinding $adapter $raw $mapping $binding[0] $binding[1] $binding[2] $binding[3]}
 $raw=Redirect-FoundationRuntime $raw $adapter @(@('i32','ube_value_assign','ptr, ptr, ptr','whole_assign'),@('i32','ube_value_try_resize','ptr, i32, ptr, i32','whole_resize'),@('i32','ube_value_copy_bytes','ptr, i32, ptr, i32, i32','whole_copybytes'),@('ptr','ube_thread_capture_allocate','i64, i64, ptr','whole_capture_allocate'),@('void','ube_thread_capture_destroy','ptr','whole_capture_destroy'))
 $raw=$raw.Replace('ptr @ube_thread_capture_destroy','ptr @whole_capture_destroy')
 $adapted=Join-Path $run 'whole-native.ll';[IO.File]::WriteAllText($adapted,[regex]::Replace($raw,'(?m)^define i32 @main\(' ,'define i32 @whole_unused_main(')+"`n"+$adapter.ToString(),$utf8)
 $observer=New-FoundationObservedRuntime $repo $run $selection;$commands+=@($observer.commands)
 $preserved=Join-Path $run 'runtime-foundation-preserved.c';[IO.File]::Copy($observer.generated.path,$preserved)
 $observer.generated=Get-ArtifactIdentity $preserved
 $wholeSource=Join-Path $run 'runtime-whole.c'
 $runtime=[IO.File]::ReadAllText($preserved)+"`nint32_t whole_worker_count(void) { if(!ube_thread_enter_lock())return -1; int32_t count=0; for(struct ube_thread_record* p=ube_threads;p;p=p->next)if(p->is_worker)++count; ube_thread_leave_lock(); return count; }`n"
 [IO.File]::WriteAllText($wholeSource,$runtime,$utf8)
 $runtimeObject=Join-Path $run 'runtime-whole.o';$record=Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c11','-Wall','-Wextra','-Werror','-I',(Join-Path $repo 'bootstrap/runtime'),'-include',(Join-Path $repo 'std-lib/tests/managed-storage/copy-probe.h'),'-c',$wholeSource,'-o',$runtimeObject) $repo 120;$commands+=@($record);if($record.timedOut -or $record.exit -ne 0){throw "Whole observer compile: $($record.stderr)"}
 $inputs+=@($observer.source);foreach($relative in @('bootstrap/runtime/value_storage.h','bootstrap/runtime/windows/file_primitives.c','bootstrap/runtime/windows/thread_primitives.c','std-lib/tests/managed-storage/copy-probe.h','std-lib/tests/byte-storage/allocation-probe.h')){$path=Join-Path $repo $relative;$inputs+=Get-ArtifactIdentity $path;$copy=Join-Path (Join-Path $run 'native-inputs') $relative;[void][IO.Directory]::CreateDirectory((Split-Path $copy -Parent));[IO.File]::Copy($path,$copy)}
 $wholeObserver=[pscustomobject]@{source=(Get-ArtifactIdentity $wholeSource);object=(Get-ArtifactIdentity $runtimeObject);difference='Only test-owned locked worker-count getter appended to exact audited foundation observer source.'}
 foreach($variant in @('positive','negative')){
  $exe=Join-Path $run ($variant+'.exe');$arguments=@('--target=x86_64-w64-windows-gnu','-O2','-I',$run,'-I',(Join-Path $repo 'bootstrap/runtime'),'-x','ir',$adapted,'-x','c',(Join-Path $run 'probe.c'),'-std=c11','-Wall','-Wextra','-Werror');if($variant -ceq 'negative'){$arguments+=@('-DNEGATIVE_BODY_EXPECTATION')};$arguments+=@('-x','none',$runtimeObject,$selection.unicodeRuntime.path,'-o',$exe)
  $record=Invoke-BoundedProcess $selection.clang.path $arguments $repo 120;$commands+=@($record);if($record.timedOut -or $record.exit -ne 0){throw "Whole native link: $($record.stderr)"}
  $record=Invoke-BoundedProcess $exe @() $repo 120;$commands+=@($record);$nativeRecords+=@([pscustomobject]@{variant=$variant;native=$record})
  if($variant -ceq 'positive'){if($record.timedOut -or $record.exit -ne 0 -or $record.stderr -cne '' -or $record.stdout -notmatch 'PASS whole semantic checker assertions:[0-9]+\n$'){throw "Whole checker native: $($record|ConvertTo-Json -Compress)"}}else{if($record.timedOut -or $record.exit -ne 1 -or -not $record.stderr.Contains('whole checker assertion')){throw 'Wrong whole-checker expectation was not rejected'}}
 }
 foreach($identity in $inputs){$current=Get-ArtifactIdentity $identity.path;if($current.sha256 -cne $identity.sha256){throw ('Producer input changed during whole gate: '+$identity.path)}}
 $null=Get-VerifiedBootstrapSelection $SelectionPath;$success=$true
}catch{$failure=$_.Exception.Message}
finally{[pscustomobject]@{success=$success;qualified=$false;diagnosticOnly=$true;failure=$failure;selection=$selection;tool=(Get-ArtifactIdentity $ToolPath);mapping=$mapping;inputs=$inputs;inputChanges=$inputChanges;liveDraftInputsUnchanged=($inputChanges.Count -eq 0);observer=$observer;wholeObserver=$wholeObserver;native=$nativeRecords;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -Recurse -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});limits='Focused whole single-source checker diagnostic through one accepted894 source-built stage and immutable copied implementation/Core sources. Exact empty/integer body facts/graphs; independent ScalarApp complete53 catalog/body fact records and21 value nodes, all declaration/signature scalars/original name spans and six builtin type records. If/While/Exit ownership plan, module forward runtime read and cross-jobs complete scalar record equality. Live development input changes are recorded separately; only exact copied snapshots were executed. No wholechecker qualification, multi-source ownership/overlap or exhaustive resource/failure acceptance claim.'}|ConvertTo-Json -Depth 32|Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8;Write-Output "Evidence: $run/report.json"}
if(-not $success){throw $failure}
