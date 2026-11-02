param([string]$SelectionPath='',[string]$ModulePath='',[string]$OutputRoot='',[switch]$RequireIntegrated)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
. (Join-Path $PSScriptRoot 'abi.ps1')
. (Join-Path $PSScriptRoot 'observer.ps1')
if($SelectionPath -ceq ''){$SelectionPath=Join-Path $root 'bootstrap/out/v2/current.json'}
$selection=Get-VerifiedBootstrapSelection $SelectionPath
if($ModulePath -ceq ''){$ModulePath=Join-Path $PSScriptRoot 'SignedIntegers.bas';if(-not (Test-Path -LiteralPath $ModulePath)){$ModulePath=Join-Path $root 'std-lib/src/portable/SignedIntegers.bas'}}
$ModulePath=[IO.Path]::GetFullPath($ModulePath)
$coreProject=Join-Path $root 'std-lib/UBECore.UBE'
$coreInputs=@(Get-SignedIntegerProjectInputs $coreProject);$integrated=$coreInputs -contains $ModulePath
if($RequireIntegrated -and -not $integrated){throw 'SignedIntegers must be included by the real UBECore manifest'}
if($OutputRoot -ceq ''){$OutputRoot=Join-Path $root 'bootstrap/out/signed-integers'}
$run=Join-Path ([IO.Path]::GetFullPath($OutputRoot)) ([Guid]::NewGuid().ToString('N'));$null=New-Item -ItemType Directory -Path $run -Force
$utf8=New-Object Text.UTF8Encoding($false)
$files=@('Entry.bas','probe.c','observation.h','arithmetic-cases.h','arithmetic-tests.h','decimal-cases.h','abi.ps1','observer.ps1','check.ps1')
foreach($file in $files){[IO.File]::Copy((Join-Path $PSScriptRoot $file),(Join-Path $run $file))}
[IO.File]::Copy($ModulePath,(Join-Path $run 'SignedIntegers.bas'))
$project=Join-Path $run 'Qualification.UBE'
$reference=([Uri]($run+[IO.Path]::DirectorySeparatorChar)).MakeRelativeUri([Uri]([IO.Path]::GetFullPath($coreProject))).ToString()
$moduleSource='';if(-not $integrated){$moduleSource="Source = `"SignedIntegers.bas`"`n"}
[IO.File]::WriteAllText($project,"UBE-Project 1`nName = `"SignedIntegerQualification`"`nKind = `"Exe`"`nStartup = `"Main`"`nSource = `"Entry.bas`"`n"+$moduleSource+"Reference = `"$reference`"`n",$utf8)
$projectInputs=@(Get-SignedIntegerProjectInputs $project)
$pinPaths=@($SelectionPath,$PSCommandPath,(Join-Path $PSScriptRoot 'abi.ps1'),(Join-Path $PSScriptRoot 'observer.ps1'),(Join-Path $root 'bootstrap/tools/verification.ps1'),(Join-Path $root 'std-lib/SIGNED-INTEGER-CONTRACT.md'),(Join-Path $root 'bootstrap/runtime/bootstrap_runtime.c'),(Join-Path $root 'bootstrap/runtime/value_storage.h'),(Join-Path $root 'std-lib/tests/managed-storage/copy-probe.h'),(Join-Path $root 'std-lib/tests/byte-storage/allocation-probe.h'))+$projectInputs+@($files|ForEach-Object {Join-Path $PSScriptRoot $_})
$pinPaths+=@($ModulePath,$selection.manifest.path,(Join-Path $root 'bootstrap/runtime/windows/file_primitives.c'),(Join-Path $root 'bootstrap/runtime/windows/thread_primitives.c'))
$inputs=@($pinPaths|Select-Object -Unique|ForEach-Object {Get-ArtifactIdentity $_})
[IO.File]::Copy((Join-Path $root 'std-lib/SIGNED-INTEGER-CONTRACT.md'),(Join-Path $run 'SIGNED-INTEGER-CONTRACT.md'))
$snapshot=Join-Path $run 'inputs';$null=New-Item -ItemType Directory -Path $snapshot
for($index=0;$index -lt $inputs.Count;++$index){[IO.File]::Copy($inputs[$index].path,(Join-Path $snapshot ($index.ToString('D3')+'-'+[IO.Path]::GetFileName($inputs[$index].path))))}
$stages=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
$records=@();$commands=@();$rawHashes=@();$success=$false;$failure=$null;$observer=$null
try{
 $observer=New-SignedIntegerObservedRuntime $root $run $selection
 for($stage=0;$stage -lt 2;++$stage){
  $stem=Join-Path $run ('stage'+($stage+1));$ir=$stem+'.ll';$adapted=$stem+'-adapted.ll'
  $compile=Invoke-BoundedProcess $stages[$stage] @($project,$ir) $root 180;$commands+=@($compile)
  if($compile.timedOut -or $compile.exit -ne 0){throw "Signed integer draft emission failed: $($compile.stdout)$($compile.stderr)"}
  $rawHashes+=(Get-ArtifactIdentity $ir).sha256
  $adapter=New-SignedIntegerNativeAdapter ([IO.File]::ReadAllText($ir)) $projectInputs
  [IO.File]::WriteAllText($adapted,$adapter.text,$utf8)
  $variants=@(@('positive','',''),@('wrong-value','NEGATIVE_NUMERIC_VALUE','arithmetic'),@('wrong-read-counter','NEGATIVE_NUMERIC_COUNTER','decimal'),@('wrong-operation-counter','NEGATIVE_NUMERIC_OPERATIONS','arithmetic'),@('actual-forbidden-copy','NEGATIVE_NUMERIC_COPY','heap'),@('actual-forbidden-allocation','NEGATIVE_NUMERIC_ALLOCATION','heap'),@('wrong-heap-event','NEGATIVE_NUMERIC_HEAP','heap'))
  foreach($variant in $variants){
   $exe=$stem+'-'+$variant[0]+'.exe';$defines=@('-DNUMERIC_OBSERVED');if($variant[1] -cne ''){$defines+=('-D'+$variant[1])}
   $link=Invoke-BoundedProcess $selection.clang.path (@('--target=x86_64-w64-windows-gnu','-O2','-I',(Join-Path $root 'bootstrap/runtime'),'-I',$run,'-x','ir',$adapted,'-x','c',(Join-Path $run 'probe.c'),'-std=c11','-Wall','-Wextra','-Werror')+$defines+@('-x','none',$observer.object.path,$selection.unicodeRuntime.path,'-o',$exe)) $root 120;$commands+=@($link)
   if($link.timedOut -or $link.exit -ne 0){throw "Signed integer native link failed [$($variant[0])]: $($link.stderr)"}
   $arguments=@();$timeout=120;if($variant[2] -cne ''){$arguments=@('--controls',$variant[2]);$timeout=30}
   $native=Invoke-BoundedProcess $exe $arguments $root $timeout;$commands+=@($native)
   $passed=$false
   if($variant[0] -ceq 'positive'){
    $passed=-not $native.timedOut -and $native.exit -eq 0 -and $native.stderr -ceq '' -and $native.stdout -match 'PASS signed integer native assertions:[0-9]+\n$'
    if(-not $passed){throw "Signed integer native oracle failed: $($native|ConvertTo-Json -Compress)"}
    $events=@($native.stdout -split "`n"|Where-Object {$_ -like '{*'}|ForEach-Object {$_|ConvertFrom-Json})
    if(@($events|Where-Object {$_.PSObject.Properties.Name -contains 'suite' -and $_.suite -ceq 'arithmetic'}).Count -ne 2){throw 'Expected normal and full-registry arithmetic suites'}
    if(@($events|Where-Object {$_.PSObject.Properties.Name -contains 'phase' -and $_.phase -ceq 'decode'}).Count -ne 6){throw 'Expected six actual linear-work observations'}
   }else{
    $passed=-not $native.timedOut -and $native.exit -eq 1 -and $native.stderr.Contains('signed integer assertion')
    if(-not $passed){throw "Signed integer negative control was not rejected: $($variant[0])"}
   }
   $records+=@([pscustomobject]@{stage=$stage+1;variant=$variant[0];passed=$passed;compiler=(Get-ArtifactIdentity $stages[$stage]);raw=(Get-ArtifactIdentity $ir);adapted=(Get-ArtifactIdentity $adapted);executable=(Get-ArtifactIdentity $exe);procedureMapping=$adapter.mapping;native=$native})
  }
 }
 if($rawHashes[0] -cne $rawHashes[1]){throw 'Intact SignedIntegers project LLVM differs between source-built stages'}
 foreach($identity in $inputs){$actual=Get-ArtifactIdentity $identity.path;if($actual.sha256 -cne $identity.sha256 -or $actual.bytes -ne $identity.bytes){throw "Pinned signed integer input changed: $($identity.path)"}}
 $null=Get-VerifiedBootstrapSelection $SelectionPath
 $success=$true
}catch{$failure=$_.Exception.Message}
finally{
 $evidence=[pscustomobject]@{schema=1;success=$success;failure=$failure;draftOnly=(-not $integrated);productionIntegrated=$integrated;source=(Get-ArtifactIdentity $ModulePath);selection=$selection;inputs=$inputs;observer=$observer;rawStageIdentity=($rawHashes.Count -eq 2 -and $rawHashes[0] -ceq $rawHashes[1]);records=$records;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});limits='Exact final minimal UBE module compiled with real direct UBECore Reference; source is root draft until Core manifest promotion, then only Entry.Main is root. Independent native literal answers and negative controls, unchanged input bytes/scalar outputs/observable Err.Number/Description/Source, actual byte/reader/checked-helper/copy/allocation/root/heap counters, zero/exact/+1 actual root capacity and full-registry scalar corpus. UBE thread sharing is qualified separately. No compiler literal grammar, suffix, contextual typing, folding or semantic checker is qualified here.'}
 $evidence|ConvertTo-Json -Depth 32|Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
 Write-Output "Evidence: $run/report.json"
}
if(-not $success){throw $failure}
foreach($record in $records|Where-Object variant -CEQ 'positive'){Write-Output "Stage$($record.stage): $(([regex]::Matches($record.native.stdout,'PASS signed integer native assertions:[0-9]+'))[0].Value)"}
