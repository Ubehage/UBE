param([Parameter(Mandatory=$true)][string]$FrozenInventory)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$tool=Join-Path $root 'compiler/UBE_Compiler_v3/tools/measure-frontend.ps1'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($tool,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Measurement tool AST has errors'}
foreach($definition in $ast.FindAll({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst]},$true)){Invoke-Expression $definition.Extent.Text}
$directory=Join-Path $root ('bootstrap/out/frontend-replay-regression/'+[Guid]::NewGuid().ToString('N'))
$fixture=Join-Path $directory 'baseline';$null=New-Item -ItemType Directory -Path $fixture -Force
$FrozenInventory=[IO.Path]::GetFullPath($FrozenInventory)
$inventory=Get-Content -LiteralPath $FrozenInventory -Raw | ConvertFrom-Json
$original=Get-Content -LiteralPath $inventory.originalBaseline.path -Raw | ConvertFrom-Json
$checks=@()
function Assert-Check([bool]$Condition,[string]$Name){if(-not $Condition){throw $Name};$script:checks+=[pscustomobject]@{assertion=$Name;passed=$true}}
function Reset-Replay{
 $script:frozenPins=[Collections.Generic.List[object]]::new()
 $script:frozenPinMap=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
 $script:corpora=@()
}
function Copy-Identity($Identity,[string]$Destination){
 Copy-Item -LiteralPath $Identity.path -Destination $Destination
 $copy=Get-ArtifactIdentity $Destination
 if($copy.sha256 -cne $Identity.sha256 -or $copy.bytes -ne $Identity.bytes){throw 'Fixture copy mismatch'}
 return $copy
}
function New-NativeControl($Program,$Set,[int]$Repeats,[int]$Create,[double]$Seconds){
 # Synthetic process records test validation only. No executable is started.
 $row=[pscustomobject]@{jobs=1;repeats=$Repeats;sources=$Set.sourceCount;workSeconds=$Seconds;cpuSeconds=$Seconds;setupWarmupSeconds=0.25;outsideWorkSeconds=0.5;totalSeconds=$Seconds+0.5;peakWorkingSetBytes=4096;physicalCores=4;physicalMemoryBytes=8589934592;completeResults=$true;cleanup=$true}
 return [pscustomobject]@{process=[pscustomobject]@{file=$Program.path;arguments=@($Set.inputs.path,$Set.reference.path,'1',[string]$Repeats,[string]$Create);exit=0;timedOut=$false;stderr='';stdout=($row|ConvertTo-Json -Compress)};result=$row}
}
$builds=@()
for($stage=0;$stage -lt 2;++$stage){
 $files=@{}
 foreach($role in @('compiler','raw','entry','exe')){
  $path=Join-Path $fixture ($role+$stage+'.fixture')
  [IO.File]::WriteAllText($path,('synthetic metadata-only '+$role))
  $files[$role]=Get-ArtifactIdentity $path
 }
 $builds+=[pscustomobject]$files
}
$sets=@()
$real=$inventory.real
$sets+=[pscustomobject]@{name='real';inputs=(Copy-Identity $real.inputs (Join-Path $fixture 'real.inputs'));reference=$null;units=$real.units;sourceCount=$real.sourceCount;sourceBytes=$real.sourceBytes;repeats=1;originalSerialMedianSeconds=$null;serialBaselineMedianSeconds=2.0;trials=@();admission=@();referenceCreation=$null}
$referencePath=Join-Path $fixture 'real.expected';[IO.File]::WriteAllText($referencePath,'synthetic reference identity only; not a native result stream')
$sets[0].reference=Get-ArtifactIdentity $referencePath
foreach($corpus in $inventory.retainedOriginalCorpora){
 $name=$corpus.name;if($name -ceq 'real'){$name='original-real'}
 $authority=@($original.corpora|Where-Object name -CEQ $corpus.name)[0]
 $median=Get-FrontendMedian @($authority.trials|ForEach-Object {[double]$_.result.workSeconds})
 $sets+=[pscustomobject]@{name=$name;inputs=(Copy-Identity $corpus.inputs.snapshot (Join-Path $fixture ($name+'.inputs')));reference=(Copy-Identity $corpus.reference.snapshot (Join-Path $fixture ($name+'.expected')));units=$corpus.units;sourceCount=$corpus.sourceCount;sourceBytes=$corpus.sourceBytes;repeats=$corpus.repeats;originalSerialMedianSeconds=$median;serialBaselineMedianSeconds=2.0;trials=@();admission=@();referenceCreation=$null}
}
foreach($set in $sets){
 for($stage=0;$stage -lt 2;++$stage){
  $create=0;if($set.name -ceq 'real' -and $stage -eq 0){$create=1}
  $native=New-NativeControl $builds[$stage].exe $set 0 $create 0
  $set.admission+=[pscustomobject]@{compiler=$builds[$stage].compiler;native=$native}
 }
 for($trial=0;$trial -lt 7;++$trial){
  $native=New-NativeControl $builds[-1].exe $set $set.repeats 0 (1.7+0.1*$trial)
  $set.trials+=[pscustomobject]@{session=0;trial=$trial;jobs=1;process=$native.process;result=$native.result}
 }
 if($set.name -ceq 'real'){$set.referenceCreation=[pscustomobject]@{inputs=$set.inputs;reference=$set.reference;compiler=$builds[0].compiler;program=$builds[0].exe;raw=$builds[0].raw;native=$set.admission[0].native}}
}
$valid=[pscustomobject]@{schema='ube-frontend-baseline-2';success=$true;frozenBaseline=$true;diagnosticOnly=$false;frozenInventory=(Get-ArtifactIdentity $FrozenInventory);builds=$builds;corpora=$sets}
$validJson=$valid|ConvertTo-Json -Depth 30
$baselinePath=Join-Path $fixture 'report.json'
function Save-Case($Value){$Value|ConvertTo-Json -Depth 30|Set-Content -LiteralPath $baselinePath -Encoding UTF8}
Reset-Replay
$run=Join-Path $directory 'decode';$null=New-Item -ItemType Directory -Path $run
Add-FrontendReplayCorpus 'real' $inventory.real.inputs $null $inventory.real.units $inventory.real.sourceCount $inventory.real.sourceBytes 0 $null $null
Assert-Check ($corpora.Count -eq 1 -and $corpora[0].sourceCount -eq $inventory.real.sourceCount -and $corpora[0].sourceBytes -eq $inventory.real.sourceBytes) 'Actual expanded native container decodes/copies without Int64/Byte[] local-name collision'
Reset-Replay;Save-Case $valid
$run=Join-Path $directory 'valid-copy';$null=New-Item -ItemType Directory -Path $run
$replay=Read-FrontendReplay '' $baselinePath
Initialize-FrontendReplay $replay
Assert-Check ($corpora.Count -eq 6 -and $corpora[0].sourceCount -eq $inventory.real.sourceCount) 'Valid synthetic baseline metadata and controls admit exactly all six authoritative corpora'
Assert-Check ($corpora[2].repeats -eq @($inventory.retainedOriginalCorpora|Where-Object name -CEQ 'balanced')[0].repeats) 'Valid replay preserves authoritative balanced repetitions'
function Reject-Case([string]$Name,[scriptblock]$Change,[string]$Reason){
 $case=$validJson|ConvertFrom-Json
 & $Change $case
 Save-Case $case;Reset-Replay
 $rejected=$false;$message=''
 try{$null=Read-FrontendReplay '' $baselinePath}catch{$rejected=$true;$message=$_.Exception.Message}
 Assert-Check ($rejected -and $message -like ('*'+$Reason+'*')) ($Name+' rejects at its intended binding: '+$message)
}
Reject-Case 'Expanded real substituted with historical real' {param($case)
 $old=$case.corpora[1];$real=$case.corpora[0]
 $real.sourceCount=$old.sourceCount;$real.sourceBytes=$old.sourceBytes;$real.units=$old.units
 $real.inputs.sha256=$old.inputs.sha256;$real.inputs.bytes=$old.inputs.bytes
} 'source/input binding'
Reject-Case 'Balanced repetition field doubled' {param($case)$case.corpora[2].repeats*=2} 'reference/repetition binding'
Reject-Case 'Missing corpus role' {param($case)$case.corpora=@($case.corpora[0..4])} 'complete expanded'
Reject-Case 'Reordered corpus roles' {param($case)$swap=$case.corpora[1];$case.corpora[1]=$case.corpora[2];$case.corpora[2]=$swap} 'corpus roles'
Reject-Case 'Expanded source bytes changed' {param($case)$case.corpora[0].sourceBytes++} 'source/input binding'
Reject-Case 'Expanded unit order changed' {param($case)$swap=$case.corpora[0].units[0];$case.corpora[0].units[0]=$case.corpora[0].units[1];$case.corpora[0].units[1]=$swap} 'source order/identity'
Reject-Case 'Expanded unit hash changed' {param($case)$case.corpora[0].units[0].sha256='BAD'} 'source order/identity'
Reject-Case 'Expanded unit label changed' {param($case)$case.corpora[0].units[0].label='other'} 'source order/identity'
Reject-Case 'Original expected hash changed' {param($case)$case.corpora[2].reference.sha256='BAD'} 'reference/repetition binding'
Reject-Case 'Original serial guard inflated' {param($case)$case.corpora[2].originalSerialMedianSeconds*=2} 'Original serial guard changed'
Reject-Case 'Expanded reference creation hash changed' {param($case)$case.corpora[0].referenceCreation.reference.sha256='BAD'} 'creation provenance'
Reject-Case 'Expanded creation input changed' {param($case)$case.corpora[0].referenceCreation.inputs.sha256='BAD'} 'creation provenance'
Reject-Case 'Expanded creation compiler changed' {param($case)$case.corpora[0].referenceCreation.compiler.sha256='BAD'} 'creation provenance'
Reject-Case 'Expanded reference escaped baseline path' {param($case)$case.corpora[0].reference.path=$case.corpora[1].reference.path} 'fixed run paths'
Reject-Case 'Only six serial trials' {param($case)$case.corpora[0].trials=@($case.corpora[0].trials[0..5])} 'seven actual serial controls'
Reject-Case 'Duplicate serial trial index' {param($case)$case.corpora[0].trials[6].trial=0} 'indexes'
Reject-Case 'Fractional serial trial index' {param($case)$case.corpora[0].trials[0].trial=0.5} 'indexes'
Reject-Case 'Nonserial trial job' {param($case)$case.corpora[0].trials[0].jobs=2} 'session/job controls'
Reject-Case 'Trial command repetitions changed' {param($case)$case.corpora[0].trials[0].process.arguments[3]='2'} 'command controls'
Reject-Case 'Trial result detached from stdout' {param($case)$case.corpora[0].trials[0].result.workSeconds=99} 'retained stdout'
Reject-Case 'Trial process failed' {param($case)$case.corpora[0].trials[0].process.exit=1} 'process did not complete'
Reject-Case 'Trial process timed out' {param($case)$case.corpora[0].trials[0].process.timedOut=$true} 'process did not complete'
Reject-Case 'Recomputed median differs from declared guard' {param($case)$case.corpora[0].serialBaselineMedianSeconds=99} 'seven actual controls'
Reject-Case 'Missing second stage admission' {param($case)$case.corpora[0].admission=@($case.corpora[0].admission[0])} 'Both baseline stages'
Save-Case $valid
$report=Join-Path $directory 'report.json'
[pscustomobject]@{schema='ube-frontend-replay-regression-1';success=$true;tool=(Get-ArtifactIdentity $tool);fixtureHelper=(Get-ArtifactIdentity $PSCommandPath);inventory=(Get-ArtifactIdentity $FrozenInventory);syntheticBaseline=(Get-ArtifactIdentity $baselinePath);checks=$checks;scope='Actual AST-extracted validation/copy helpers and real frozen native input containers. Positive process records/reference bytes are deliberately synthetic metadata fixtures; no qualified selection, compiler, native parser, reference creation, pilot or benchmark was executed. No performance acceptance claim.'}|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $report -Encoding UTF8
Write-Output ($checks.Count.ToString()+' focused frontend replay assertions passed.')
Write-Output ('Evidence: '+$report)
