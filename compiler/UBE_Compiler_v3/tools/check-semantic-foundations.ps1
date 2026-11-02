param(
 [string]$SelectionPath='',
 [switch]$RequireIntegrated=$true,
 [ValidateSet('all','arena','sharing')][string]$OnlySuite='all',
 [string]$OutputRoot='',
 [string]$ByteKeysPath='',
 [string]$SignedIntegersPath='',
 [string]$Utf8EncodingPath='',
 [string]$StorageCapacityPath=''
)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$candidate=[IO.DirectoryInfo]$PSScriptRoot;$root=$null
while($candidate){if(Test-Path -LiteralPath (Join-Path $candidate.FullName 'bootstrap/tools/verification.ps1')){$root=$candidate.FullName;break};$candidate=$candidate.Parent}
if(-not $root){throw 'Repository root with bootstrap verification helper not found'}
if(-not $SelectionPath){$SelectionPath=Join-Path $root 'bootstrap/out/v2/current.json'}
$fixture=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../fixtures'));if(-not (Test-Path -LiteralPath $fixture)){$fixture=Join-Path $root 'compiler/UBE_Compiler_v3/tests/semantic/native'}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
. (Join-Path $fixture 'project.ps1')
. (Join-Path $fixture 'observer.ps1')
. (Join-Path $fixture 'abi.ps1')
if(-not $OutputRoot){$OutputRoot=Join-Path $root 'bootstrap/out/semantic-foundations'}
$run=Join-Path $OutputRoot ([Guid]::NewGuid().ToString('N'));$null=New-Item -ItemType Directory -Path $run -Force
$inputs=@();$commands=New-Object 'System.Collections.Generic.List[object]';$checks=New-Object 'System.Collections.Generic.List[object]';$results=New-Object 'System.Collections.Generic.List[object]';$raw=@();$selection=$null;$project=$null;$observer=$null;$success=$false;$failure=$null
function Assert-Fact([bool]$Value,[string]$Message,$Detail=$null){if(-not $Value){throw $Message};$checks.Add([pscustomobject]@{assertion=$Message;detail=$Detail;passed=$true})}
function Invoke-Checked([string]$File,[string[]]$Arguments,[int]$Timeout=120){$record=Invoke-BoundedProcess $File $Arguments $root $Timeout;$commands.Add($record);if($record.timedOut -or $record.exit -ne 0){throw "Foundation process failed: $($record|ConvertTo-Json -Compress)"};return $record}
function Check-Native([string]$Executable,[string[]]$Arguments,[string]$Prefix,[int]$Stage,[string]$Suite,[bool]$Negative=$false){
 $record=Invoke-BoundedProcess $Executable $Arguments $root 300;$commands.Add($record)
 if($Negative){$assertionPrefix=$Prefix;if($Prefix -ceq 'shared UBE'){$assertionPrefix='shared probe'};Assert-Fact (-not $record.timedOut -and $record.exit -eq 1 -and $record.stderr.Contains($assertionPrefix+' assertion')) "Stage$Stage native $Suite corruption is rejected"}
 else{
  $pattern='PASS '+[regex]::Escape($Prefix)+' native assertions:([0-9]+)\n$';$matched=$record.stdout -match $pattern;$nativeCount=0;if($matched){$nativeCount=[long]$Matches[1]}
  Assert-Fact (-not $record.timedOut -and $record.exit -eq 0 -and $record.stderr -ceq '' -and $matched -and $nativeCount -gt 0) "Stage$Stage native $Suite exact status/output/complete assertions pass"
  $rows=@($record.stdout -split "`n"|Where-Object {$_.StartsWith('{')}|ForEach-Object {$_|ConvertFrom-Json})
  switch($Suite){
   'arena'{Assert-Fact ($rows.Count -eq 10 -and @($rows|Where-Object {$_.suite -ceq 'arena-cost'}).Count -eq 6 -and @($rows|Where-Object {$_.suite -ceq 'arena-allocation-faults' -and $_.sites -eq 9 -and $_.passed}).Count -eq 1) "Stage$Stage complete arena cost/failure/budget/trim cohort"}
   'arena-roots'{Assert-Fact ($rows.Count -eq 1 -and $rows[0].suite -ceq 'arena-root-pressure' -and $rows[0].realBacked -and $rows[0].passed -and $rows[0].capacities -eq $rows[0].required+2) "Stage$Stage gap-free real-backed arena root capacities zero through exact-plus-one"}
   'sharing'{
    Assert-Fact ($rows.Count -eq 5 -and @($rows|Where-Object {$_.suite -ceq 'shared-UBE-workers' -and $_.workers -eq 4 -and $_.passed -and $_.captureBytes -eq 32 -and $_.actualCaptureCopied -eq 32 -and $_.sourceCopied -eq 0 -and $_.catalogCopied -eq 0 -and $_.callerRootsRemovedDuringCollection}).Count -eq 3) "Stage$Stage all three actual UBE four-worker ownership/determinism contexts"
    Assert-Fact (@($rows|Where-Object {$_.suite -ceq 'shared-worker-resource-failures' -and $_.workerAllocationSites -eq 7 -and $_.recoveries -eq 7 -and $_.captureAllocationSites -gt 0 -and $_.cancelledWorkerDrained -and $_.classAllocationDenied -and $_.rootAdmissionDenied -and $_.oldCompleteGraphPreserved -and $_.passed}).Count -eq 1) "Stage$Stage actual worker/capture/class/root failures, cancellation and old-publication preservation"
    Assert-Fact (@($rows|Where-Object {$_.suite -ceq 'unowned-borrow-control' -and $_.weakOwnerReclaimed -and $_.weakBytesReclaimed -and $_.missingOwnerRejected -and -not $_.dereferencedFreedStorage -and $_.passed}).Count -eq 1) "Stage$Stage safe unowned-borrow negative control"
   }
  }
 }
 $results.Add([pscustomobject]@{stage=$Stage;suite=$Suite;negative=$Negative;executable=(Get-ArtifactIdentity $Executable);actual=$record})
}
try{
 $selection=Get-VerifiedBootstrapSelection $SelectionPath;$accepted=Get-Content -LiteralPath $selection.manifest.path -Raw|ConvertFrom-Json
 $inputs=@($accepted.inputs)+@((Get-ArtifactIdentity $SelectionPath),(Get-ArtifactIdentity $PSCommandPath))+@($selection.PSObject.Properties|Where-Object Name -NE 'schema'|ForEach-Object Value)
 $inputs+=@(Get-ChildItem -LiteralPath $fixture -File|ForEach-Object {Get-ArtifactIdentity $_.FullName})
 $snapshot=Join-Path $run 'fixture-inputs';$null=New-Item -ItemType Directory -Path $snapshot -Force;foreach($file in Get-ChildItem -LiteralPath $fixture -File){[IO.File]::Copy($file.FullName,(Join-Path $snapshot $file.Name))}
 [IO.File]::Copy($SelectionPath,(Join-Path $run 'accepted-selection.json'));[IO.File]::Copy($selection.manifest.path,(Join-Path $run 'accepted-manifest.json'));[IO.File]::Copy($PSCommandPath,(Join-Path $run 'runner.ps1'))
 $project=New-FoundationProject $root $run $fixture @{ByteKeys=$ByteKeysPath;SignedIntegers=$SignedIntegersPath;Utf8Encoding=$Utf8EncodingPath;StorageCapacity=$StorageCapacityPath} ([bool]$RequireIntegrated);$inputs+=@($project.inputs)
 Assert-Fact (-not $RequireIntegrated -or $project.integrated) 'Required generic algorithms are exact real UBECore Reference inputs' $project.modules
 $observer=New-FoundationObservedRuntime $root $run $selection;foreach($command in $observer.commands){$commands.Add($command)};$inputs+=@($observer.source)
 $nativeInputs=@('bootstrap/runtime/value_storage.h','bootstrap/runtime/windows/file_primitives.c','bootstrap/runtime/windows/thread_primitives.c','std-lib/tests/managed-storage/copy-probe.h','std-lib/tests/byte-storage/allocation-probe.h','bootstrap/tools/verification.ps1')
 foreach($relative in $nativeInputs){$path=Join-Path $root $relative;$inputs+=Get-ArtifactIdentity $path;$copy=Join-Path (Join-Path $run 'native-inputs') $relative;$null=New-Item -ItemType Directory -Path (Split-Path $copy -Parent) -Force;[IO.File]::Copy($path,$copy)}
 $stages=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
 for($stage=1;$stage -le 2;++$stage){
  $rawPath=Join-Path $run ('stage'+$stage+'.ll');$null=Invoke-Checked $stages[$stage-1] @($project.manifest.path,$rawPath) 300;$raw+=Get-ArtifactIdentity $rawPath
  if($OnlySuite -in @('all','arena')){
   $adapted=Join-Path $run ('stage'+$stage+'-arena.ll');$abi=Write-FoundationArenaAbi $rawPath $adapted $project;Assert-Fact ($abi.recordBytes -eq 48 -and $abi.resultBytes -eq 24) "Stage$stage intact scalar arena ABI"
   foreach($control in @('','VALUE','METRIC','HEAP')){
    $defines=@();$suffix='native';if($control){$defines=@('-DNEGATIVE_ARENA_'+$control);$suffix='negative-'+$control.ToLowerInvariant()};$exe=Join-Path $run ('stage'+$stage+'-arena-'+$suffix+'.exe')
    $null=Invoke-Checked $selection.clang.path (@('--target=x86_64-w64-windows-gnu','-O2','-I',(Join-Path $root 'bootstrap/runtime'),'-x','ir',$adapted,'-x','c',(Join-Path $snapshot 'arena.c'),'-std=c11','-Wall','-Wextra','-Werror')+$defines+@('-x','none',$observer.object.path,$selection.unicodeRuntime.path,'-o',$exe))
    Check-Native $exe @() 'arena' $stage $(if($control){'arena-'+$control}else{'arena'}) ([bool]$control)
    if(-not $control){Check-Native $exe @('roots') 'arena' $stage 'arena-roots'}
   }
  }
  if($OnlySuite -in @('all','sharing')){
   $adapted=Join-Path $run ('stage'+$stage+'-sharing.ll');$abi=Write-FoundationSharedAbi $rawPath $adapted $project;Assert-Fact ($abi.keyBytes -eq 16 -and $abi.ownerBytes -eq 80 -and $abi.workBytes -eq 88) "Stage$stage intact final generic sharing ABI"
   foreach($control in @('','VALUE','SOURCE_COPY','METRIC')){
    $defines=@();$suffix='native';if($control){$defines=@('-DNEGATIVE_SHARED_'+$control);$suffix='negative-'+$control.ToLowerInvariant()};$exe=Join-Path $run ('stage'+$stage+'-sharing-'+$suffix+'.exe')
    $null=Invoke-Checked $selection.clang.path (@('--target=x86_64-w64-windows-gnu','-O2','-I',(Join-Path $root 'bootstrap/runtime'),'-x','ir',$adapted,'-x','c',(Join-Path $snapshot 'shared.c'),'-std=c11','-Wall','-Wextra','-Werror')+$defines+@('-x','none',$observer.object.path,$selection.unicodeRuntime.path,'-o',$exe))
    Check-Native $exe @() 'shared UBE' $stage $(if($control){'sharing-'+$control}else{'sharing'}) ([bool]$control)
   }
  }
 }
 Assert-Fact ($raw.Count -eq 2 -and $raw[0].sha256 -ceq $raw[1].sha256 -and $raw[0].bytes -eq $raw[1].bytes) 'Complete intact actual-Core consumer raw LLVM is byte-identical across both accepted stages'
 foreach($identity in $inputs){$actual=Get-ArtifactIdentity $identity.path;if($actual.sha256 -cne $identity.sha256 -or $actual.bytes -ne $identity.bytes){throw "Foundation input changed: $($identity.path)"}}
 Assert-Fact $true 'All exact source/tool/fixture/accepted-cohort inputs remain unchanged after native gates';$success=$true
}catch{$failure=$_.Exception.Message}
finally{
 $qualified=$success -and $project -and $project.integrated -and $OnlySuite -ceq 'all'
 [pscustomobject]@{schema='ube-semantic-foundations-native-1';success=$success;qualifiedFoundations=[bool]$qualified;diagnosticOnly=(-not $qualified);failure=$failure;requireIntegrated=[bool]$RequireIntegrated;onlySuite=$OnlySuite;selection=$selection;acceptedSelection=$selection;sourceBuildCurrent=$success;project=$project;observer=$observer;inputs=$inputs;rawLLVM=$raw;checks=$checks.ToArray();results=$results.ToArray();commands=$commands.ToArray();artifacts=@(Get-ChildItem -LiteralPath $run -File -Recurse|ForEach-Object {Get-ArtifactIdentity $_.FullName});limits='Exact integrated UBECore scalar arena/immutable actual UBE worker component proof only. No semantic checker, compiler SourceOwner/ProjectSyntax integration, general scheduler, backend or speedup claim. Partial/nonintegrated runs are diagnostic only.'}|ConvertTo-Json -Depth 40|Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
 Write-Output "Evidence: $run/report.json"
}
if(-not $success){throw $failure};Write-Output "PASS: $($checks.Count) semantic foundation gate assertions; integrated=$($project.integrated) suite=$OnlySuite"
