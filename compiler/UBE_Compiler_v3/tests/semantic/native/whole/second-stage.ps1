param([Parameter(Mandatory=$true)][string]$RunPath,[int]$TimeoutSeconds=900,[string]$SelectionPath='')
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$repo=$PSScriptRoot;while(-not [IO.File]::Exists((Join-Path $repo 'bootstrap/tools/verification.ps1'))){$parent=Split-Path $repo -Parent;if(-not $parent -or $parent -eq $repo){throw 'Repository root not found'};$repo=$parent}
. (Join-Path $repo 'bootstrap/tools/verification.ps1')
. (Join-Path $repo 'compiler/UBE_Compiler_v3/tests/semantic/native/abi.ps1')
$previous=[IO.File]::ReadAllText((Join-Path $RunPath 'report.json'))|ConvertFrom-Json
if(-not $SelectionPath){$SelectionPath=Join-Path $repo 'bootstrap/out/v2/current.json'};$selection=Get-VerifiedBootstrapSelection $SelectionPath
if(-not $previous.success -or $previous.selection.manifest.sha256 -cne $selection.manifest.sha256){throw 'Successful first-stage functional snapshot with same accepted tools required'}
$stage1=Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'
$run=Join-Path $RunPath ('stage1-'+[Guid]::NewGuid().ToString('N'));$null=New-Item -ItemType Directory -Path $run
$project=Join-Path $RunPath 'project/Whole.UBE';$rawPath=Join-Path $run 'whole.ll';$commands=@();$records=@();$success=$false;$failure=$null;$utf8=New-Object Text.UTF8Encoding($false)
$procedures=@{};$types=@{};foreach($property in $previous.mapping.procedures.PSObject.Properties){$procedures[$property.Name]=$property.Value};foreach($property in $previous.mapping.types.PSObject.Properties){$types[$property.Name]=$property.Value};$mapping=[pscustomobject]@{procedures=$procedures;types=$types}
$c=Join-Path $run 'probe.c';[IO.File]::Copy((Join-Path $RunPath 'probe.c'),$c)
if(Test-Path -LiteralPath (Join-Path $RunPath 'scalar-complete.h')){[IO.File]::Copy((Join-Path $RunPath 'scalar-complete.h'),(Join-Path $run 'scalar-complete.h'))}
$firstC=@($previous.inputs|Where-Object path -CEQ (Join-Path $PSScriptRoot 'probe.c'));if($firstC.Count -ne 1 -or (Get-ArtifactIdentity $c).sha256 -cne $firstC[0].sha256){throw 'Native expected answer source changed between stages'}
try{
 $record=Invoke-BoundedProcess $stage1 @($project,$rawPath) $repo $TimeoutSeconds;$commands+=@($record);if($record.timedOut -or $record.exit -ne 0){throw "Other source-built stage emission: $($record.stdout)$($record.stderr)"}
 if((Get-ArtifactIdentity $rawPath).sha256 -cne (Get-ArtifactIdentity (Join-Path $RunPath 'whole.ll')).sha256){throw 'Source-built stages emitted different intact whole-checker LLVM'}
 $raw=[IO.File]::ReadAllText($rawPath);$adapter=New-Object Text.StringBuilder
 foreach($binding in @(@('statement_make','TryMakeStatementSource','i1','ptr,i32,i32,ptr,ptr'),@('statement_cancel','TryMakeStatementCancellation','i1','ptr'),@('statement_check','TryCheckStatementSource','i1','ptr,i32,ptr,ptr,ptr,ptr'))){Add-FoundationBinding $adapter $raw $mapping $binding[0] $binding[1] $binding[2] $binding[3]}
 if($mapping.procedures.ContainsKey('TryMakeStatementProject')){foreach($binding in @(@('statement_project_make','TryMakeStatementProject','i1','ptr,i32,ptr,ptr,ptr'),@('statement_project_check','TryCheckStatementProject','i1','ptr,i32,ptr,ptr,ptr,ptr'))){Add-FoundationBinding $adapter $raw $mapping $binding[0] $binding[1] $binding[2] $binding[3]}}
 $raw=Redirect-FoundationRuntime $raw $adapter @(@('i32','ube_value_assign','ptr, ptr, ptr','whole_assign'),@('i32','ube_value_try_resize','ptr, i32, ptr, i32','whole_resize'),@('i32','ube_value_copy_bytes','ptr, i32, ptr, i32, i32','whole_copybytes'),@('ptr','ube_thread_capture_allocate','i64, i64, ptr','whole_capture_allocate'),@('void','ube_thread_capture_destroy','ptr','whole_capture_destroy'))
 $adapted=Join-Path $run 'whole-native.ll';[IO.File]::WriteAllText($adapted,[regex]::Replace($raw.Replace('ptr @ube_thread_capture_destroy','ptr @whole_capture_destroy'),'(?m)^define i32 @main\(','define i32 @whole_unused_main(')+"`n"+$adapter.ToString(),$utf8)
 foreach($variant in @('positive','negative')){
  $exe=Join-Path $run ($variant+'.exe');$arguments=@('--target=x86_64-w64-windows-gnu','-O2','-I',$RunPath,'-I',(Join-Path $repo 'bootstrap/runtime'),'-x','ir',$adapted,'-x','c',$c,'-std=c11','-Wall','-Wextra','-Werror');if($variant -ceq 'negative'){$arguments+=@('-DNEGATIVE_BODY_EXPECTATION')};$arguments+=@('-x','none',(Join-Path $RunPath 'runtime-whole.o'),$selection.unicodeRuntime.path,'-o',$exe)
  $record=Invoke-BoundedProcess $selection.clang.path $arguments $repo 120;$commands+=@($record);if($record.timedOut -or $record.exit -ne 0){throw $record.stderr}
  $record=Invoke-BoundedProcess $exe @() $repo 120;$commands+=@($record);$records+=@([pscustomobject]@{variant=$variant;native=$record})
  if($variant -ceq 'positive'){if($record.timedOut -or $record.exit -ne 0 -or $record.stderr -cne '' -or $record.stdout -notmatch 'PASS whole semantic checker assertions:[0-9]+\n$'){throw "Other-stage native assertions: $($record|ConvertTo-Json -Compress)"}}else{if($record.timedOut -or $record.exit -ne 1 -or -not $record.stderr.Contains('whole checker assertion')){throw 'Other-stage wrong expected answer was not rejected'}}
 }
 $success=$true
}catch{$failure=$_.Exception.Message}
finally{[pscustomobject]@{success=$success;qualified=$false;diagnosticOnly=$true;failure=$failure;firstStageReport=(Get-ArtifactIdentity (Join-Path $RunPath 'report.json'));selection=$selection;compiler=(Get-ArtifactIdentity $stage1);rawStageIdentity=($success);native=$records;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -Recurse -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});limits='Both accepted source-built tools execute the same preserved exact whole-source draft snapshot and independent native expected-answer source. Finite functional diagnostic only; full logical comparator and broad resource/concurrency/failure gates remain.'}|ConvertTo-Json -Depth 24|Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8;Write-Output "Evidence: $run/report.json"}
if(-not $success){throw $failure}
