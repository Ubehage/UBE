param(
 [string]$SelectionPath=(Join-Path $PSScriptRoot '../../../bootstrap/out/v2/current.json'),
 [switch]$DiagnosticOnly,
 [ValidateSet('all','small-empty','small-source','real','balanced','uneven')][string]$Corpus='all',
 [string]$FrozenInventory,
 [string]$BaselineReport,
 [string[]]$ChangedBuildInputs=@()
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
# Frozen-corpus provenance, replay and complete-session measurement helpers.
function Assert-FrontendIdentity($Identity){
 if(-not $Identity -or -not $Identity.path -or -not $Identity.sha256){throw 'Missing frozen identity'}
 $actual=Get-ArtifactIdentity $Identity.path
 if($actual.bytes -ne $Identity.bytes -or $actual.sha256 -cne $Identity.sha256){throw ('Frozen input/artifact changed: '+$Identity.path)}
 if(-not $script:frozenPinMap.ContainsKey($Identity.path)){$script:frozenPinMap.Add($Identity.path,$Identity);$script:frozenPins.Add($Identity)}
 elseif($script:frozenPinMap[$Identity.path].sha256 -cne $Identity.sha256){throw 'Conflicting frozen identity'}
}
function Get-FrontendMedian([double[]]$Values){
 if($Values.Count -ne 7){throw 'Exactly seven retained values are required'}
 return @($Values | Sort-Object)[3]
}
function Assert-FrontendReplayUnits($Set,$Expected){
 if($Set.sourceCount -ne $Expected.sourceCount -or $Set.sourceBytes -ne $Expected.sourceBytes -or $Set.units.Count -ne $Expected.units.Count -or $Set.inputs.bytes -ne $Expected.inputs.bytes -or $Set.inputs.sha256 -cne $Expected.inputs.sha256){throw ('Frozen replay source/input binding changed: '+$Set.name)}
 for($unitIndex=0;$unitIndex -lt $Expected.units.Count;++$unitIndex){
  $actualUnit=$Set.units[$unitIndex];$expectedUnit=$Expected.units[$unitIndex]
  if($actualUnit.id -ne $unitIndex -or $actualUnit.id -ne $expectedUnit.id -or $actualUnit.label -cne $expectedUnit.label -or $actualUnit.bytes -ne $expectedUnit.bytes -or $actualUnit.sha256 -cne $expectedUnit.sha256){throw ('Frozen replay source order/identity changed: '+$Set.name)}
 }
}
function Assert-FrontendNativeControl($Native,$Program,$Inputs,$Reference,[int]$Sources,[int]$Jobs,[int]$Repeats,[int]$Create){
 $control=$Native.process
 if($control.file -cne $Program.path -or $control.exit -ne 0 -or $control.timedOut -or $control.stderr -cne ''){throw 'Serial native process did not complete successfully'}
 $arguments=@($Inputs.path,$Reference.path,[string]$Jobs,[string]$Repeats,[string]$Create)
 if($control.arguments.Count -ne 5 -or ($control.arguments -join "`n") -cne ($arguments -join "`n")){throw 'Serial native command controls changed'}
 $parsed=$control.stdout | ConvertFrom-Json
 $fields='cleanup,completeResults,cpuSeconds,jobs,outsideWorkSeconds,peakWorkingSetBytes,physicalCores,physicalMemoryBytes,repeats,setupWarmupSeconds,sources,totalSeconds,workSeconds'
 if((@($parsed.PSObject.Properties.Name|Sort-Object) -join ',') -cne $fields -or (@($Native.result.PSObject.Properties.Name|Sort-Object) -join ',') -cne $fields){throw 'Serial native result schema changed'}
 foreach($property in $parsed.PSObject.Properties){if($Native.result.($property.Name) -cne $property.Value){throw 'Stored native result differs from actual retained stdout'}}
 if($parsed.jobs -ne $Jobs -or $parsed.repeats -ne $Repeats -or $parsed.sources -ne $Sources -or $parsed.completeResults -isnot [bool] -or -not $parsed.completeResults -or $parsed.cleanup -isnot [bool] -or -not $parsed.cleanup -or $parsed.physicalCores -lt 4 -or $parsed.physicalMemoryBytes -le 0){throw 'Serial native result controls changed'}
 foreach($field in @('workSeconds','cpuSeconds','setupWarmupSeconds','outsideWorkSeconds','totalSeconds')){
  $value=[double]$parsed.$field
  if([double]::IsNaN($value) -or [double]::IsInfinity($value) -or $value -lt 0){throw 'Invalid serial native timing value'}
 }
 if(($Repeats -gt 0 -and $parsed.workSeconds -le 0) -or ($Repeats -eq 0 -and $parsed.workSeconds -ne 0)){throw 'Serial native work/repetition controls changed'}
 return $parsed
}
function Get-FrontendSerialControlMedian($Set,$Program,[bool]$SessionControls){
 if($Set.trials.Count -ne 7){throw ('Exactly seven actual serial controls are required: '+$Set.name)}
 $seen=@();$samples=@()
 foreach($trial in $Set.trials){
  if(($trial.trial -isnot [int] -and $trial.trial -isnot [long]) -or $trial.trial -lt 0 -or $trial.trial -gt 6 -or $trial.trial -in $seen){throw 'Serial trial indexes must be unique integers 0..6'}
  if($SessionControls -and ($trial.session -ne 0 -or $trial.jobs -ne 1)){throw 'Serial baseline session/job controls changed'}
  $seen+=$trial.trial
  $control=Assert-FrontendNativeControl $trial $Program $Set.inputs $Set.reference $Set.sourceCount 1 $Set.repeats 0
  $samples+=[double]$control.workSeconds
 }
 return Get-FrontendMedian $samples
}
function Assert-FrontendReplayBaseline($Previous,$Inventory,$Original,[string]$ReportPath){
 if(($Previous.corpora.name -join ',') -cne 'real,original-real,balanced,uneven,small-empty,small-source'){throw 'Baseline must retain the six authoritative corpus roles in order'}
 if($Previous.builds.Count -ne 2 -or $Previous.builds[0].raw.sha256 -cne $Previous.builds[1].raw.sha256){throw 'Baseline requires both identical-LLVM source-built stages'}
 foreach($build in $Previous.builds){foreach($identity in @($build.compiler,$build.raw,$build.entry,$build.exe)){Assert-FrontendIdentity $identity}}
 $directory=Split-Path ([IO.Path]::GetFullPath($ReportPath)) -Parent
 foreach($set in $Previous.corpora){
  if($set.inputs.path -cne (Join-Path $directory ($set.name+'.inputs')) -or $set.reference.path -cne (Join-Path $directory ($set.name+'.expected'))){throw 'Baseline corpus/reference must retain its own fixed run paths'}
  if($set.name -ceq 'real'){
   $expected=$Inventory.real
   if($null -ne $set.originalSerialMedianSeconds){throw 'Expanded real cannot replace its guard with a historical corpus'}
  }else{
   $name=$set.name;if($name -ceq 'original-real'){$name='real'}
   $expected=@($Original.corpora|Where-Object name -CEQ $name)
   if($expected.Count -ne 1){throw 'Ambiguous original corpus authority'}
   $expected=$expected[0]
   if($set.reference.sha256 -cne $expected.reference.sha256 -or $set.reference.bytes -ne $expected.reference.bytes -or $set.repeats -ne $expected.repeats){throw ('Original reference/repetition binding changed: '+$set.name)}
   $guard=Get-FrontendSerialControlMedian $expected $Original.builds[-1].exe $false
   if($set.originalSerialMedianSeconds -ne $guard){throw ('Original serial guard changed: '+$set.name)}
  }
  Assert-FrontendReplayUnits $set $expected
  Assert-FrontendIdentity $set.inputs;Assert-FrontendIdentity $set.reference
  if($set.repeats -lt 1 -or $set.repeats -gt 16384){throw 'Invalid frozen repetition count'}
  if($set.admission.Count -ne 2){throw 'Both baseline stages must retain complete admission controls'}
  for($stage=0;$stage -lt 2;++$stage){
   $admission=$set.admission[$stage];$build=$Previous.builds[$stage]
   if($admission.compiler.sha256 -cne $build.compiler.sha256 -or $admission.compiler.bytes -ne $build.compiler.bytes -or $admission.compiler.path -cne $build.compiler.path){throw 'Baseline stage admission identity changed'}
   $create=0;if($set.name -ceq 'real' -and $stage -eq 0){$create=1}
   $null=Assert-FrontendNativeControl $admission.native $build.exe $set.inputs $set.reference $set.sourceCount 1 0 $create
  }
  if($set.name -ceq 'real'){
   $creation=$set.referenceCreation;$first=$Previous.builds[0]
   foreach($pair in @(@($creation.inputs,$set.inputs),@($creation.reference,$set.reference),@($creation.compiler,$first.compiler),@($creation.program,$first.exe),@($creation.raw,$first.raw))){
    if($pair[0].path -cne $pair[1].path -or $pair[0].sha256 -cne $pair[1].sha256 -or $pair[0].bytes -ne $pair[1].bytes){throw 'Expanded reference creation provenance changed'}
   }
   $null=Assert-FrontendNativeControl $creation.native $first.exe $set.inputs $set.reference $set.sourceCount 1 0 1
  }
  $median=Get-FrontendSerialControlMedian $set $Previous.builds[-1].exe $true
  if($median -lt 1 -or $set.serialBaselineMedianSeconds -ne $median){throw ('Serial baseline guard does not match seven actual controls: '+$set.name)}
 }
}
function Read-FrontendReplay([string]$InventoryPath,[string]$ReportPath){
 $previous=$null
 if($ReportPath){
  $ReportPath=[IO.Path]::GetFullPath($ReportPath)
  $previous=Get-Content -LiteralPath $ReportPath -Raw | ConvertFrom-Json
  if($previous.schema -cne 'ube-frontend-baseline-2' -or -not $previous.success -or -not $previous.frozenBaseline -or $previous.diagnosticOnly -or $previous.corpora.Count -ne 6){throw 'Candidate requires a successful complete expanded pre-optimization baseline'}
  Assert-FrontendIdentity $previous.frozenInventory
  $InventoryPath=$previous.frozenInventory.path
  Assert-FrontendIdentity (Get-ArtifactIdentity $ReportPath)
 }
 $InventoryPath=[IO.Path]::GetFullPath($InventoryPath)
 $inventory=Get-Content -LiteralPath $InventoryPath -Raw | ConvertFrom-Json
 if($inventory.schema -cne 'ube-expanded-frontend-input-freeze-1' -or -not $inventory.success -or $inventory.retainedOriginalCorpora.Count -ne 5){throw 'Unsupported expanded frozen-input ledger'}
 Assert-FrontendIdentity (Get-ArtifactIdentity $InventoryPath)
 Assert-FrontendIdentity $inventory.originalBaseline
 $original=Get-Content -LiteralPath $inventory.originalBaseline.path -Raw | ConvertFrom-Json
 if($original.schema -cne 'ube-frontend-baseline-1' -or -not $original.success -or -not $original.frozenBaseline -or $original.corpora.Count -ne 5){throw 'Original complete serial baseline is required'}
 foreach($set in $inventory.retainedOriginalCorpora){
  $expected=@($original.corpora|Where-Object name -CEQ $set.name)
  if($expected.Count -ne 1 -or $set.sourceCount -ne $expected[0].sourceCount -or $set.sourceBytes -ne $expected[0].sourceBytes -or $set.repeats -ne $expected[0].repeats -or $set.inputs.snapshot.sha256 -cne $expected[0].inputs.sha256 -or $set.reference.snapshot.sha256 -cne $expected[0].reference.sha256){throw 'Original corpus/reference/repetition identity changed in replay ledger'}
 }
 if(@($original.corpora|Where-Object {$_.name -eq 'balanced' -and $_.sourceCount -ge 32}).Count -ne 1 -or @($original.corpora|Where-Object {$_.name -eq 'uneven' -and $_.sourceCount -ge 32}).Count -ne 1){throw 'Balanced and uneven guards must retain at least 32 sources'}
 foreach($saved in $inventory.saved){
  Assert-FrontendIdentity $saved.snapshot
  # Qualification can advance current.json, and this measurement tool gains replay
  # support after the freeze. Neither is a change to frozen production work.
  if(-not $previous -and $saved.original.path -notmatch '[\\/]bootstrap[\\/]out[\\/]' -and $saved.original.path -cne $PSCommandPath){Assert-FrontendIdentity $saved.original}
 }
 if($previous){
  Assert-FrontendReplayBaseline $previous $inventory $original $ReportPath
 }
 return [pscustomobject]@{inventory=$inventory;identity=(Get-ArtifactIdentity $InventoryPath);original=$original;previous=$previous;baselineIdentity=$(if($ReportPath){Get-ArtifactIdentity $ReportPath}else{$null})}
}
function Add-FrontendReplayCorpus([string]$Name,$Inputs,$Reference,[object[]]$Units,[int]$Count,[long]$Bytes,[int]$Repeats,$OriginalGuard,$SerialGuard){
 Assert-FrontendIdentity $Inputs
 $inputPath=Join-Path $run ($Name+'.inputs');Copy-Item -LiteralPath $Inputs.path -Destination $inputPath
 $inputCopy=Get-ArtifactIdentity $inputPath
 if($inputCopy.sha256 -cne $Inputs.sha256 -or $inputCopy.bytes -ne $Inputs.bytes){throw 'Frozen native-input copy mismatch'}
 # Independently validate the complete native length-prefixed input container.
 $stream=[IO.File]::OpenRead($inputPath);$reader=[IO.BinaryReader]::new($stream)
 try{
  if($reader.ReadInt32() -ne $Count -or $Units.Count -ne $Count){throw 'Frozen corpus count mismatch'}
  $total=0L
  for($i=0;$i -lt $Count;++$i){
   $length=$reader.ReadInt32();if($length -lt 0 -or $length -ne $Units[$i].bytes -or $Units[$i].id -ne $i){throw 'Frozen corpus length/order mismatch'}
   $payloadBytes=$reader.ReadBytes($length);if($payloadBytes.Length -ne $length){throw 'Truncated frozen source'}
   $sha=[Security.Cryptography.SHA256]::Create()
   try{$hash=([BitConverter]::ToString($sha.ComputeHash($payloadBytes))).Replace('-','')}finally{$sha.Dispose()}
   if($hash -cne $Units[$i].sha256){throw 'Frozen source payload hash mismatch'}
   $total+=$length
  }
  if($total -ne $Bytes -or $stream.Position -ne $stream.Length){throw 'Frozen corpus byte accounting mismatch'}
 }finally{$reader.Dispose();$stream.Dispose()}
 $referenceCopy=$null
 if($Reference){
  Assert-FrontendIdentity $Reference
  $referencePath=Join-Path $run ($Name+'.expected');Copy-Item -LiteralPath $Reference.path -Destination $referencePath
  $referenceCopy=Get-ArtifactIdentity $referencePath
  if($referenceCopy.sha256 -cne $Reference.sha256 -or $referenceCopy.bytes -ne $Reference.bytes){throw 'Frozen reference copy mismatch'}
 }
 $script:corpora+=[pscustomobject]@{name=$Name;inputs=$inputCopy;sourceCount=$Count;sourceBytes=$Bytes;units=$Units;reference=$referenceCopy;referenceCreation=$null;repeats=$Repeats;pilot=@();trials=@();serialBaselineMedianSeconds=$SerialGuard;originalSerialMedianSeconds=$OriginalGuard;admission=@()}
}
function Initialize-FrontendReplay($Replay){
 if($Replay.previous){
  Assert-FrontendReplayBaseline $Replay.previous $Replay.inventory $Replay.original $Replay.baselineIdentity.path
  foreach($set in $Replay.previous.corpora){
   if($set.repeats -lt 1 -or $set.repeats -gt 16384 -or $set.serialBaselineMedianSeconds -le 0){throw 'Missing frozen repetition count/serial baseline'}
   Add-FrontendReplayCorpus $set.name $set.inputs $set.reference $set.units $set.sourceCount $set.sourceBytes $set.repeats $set.originalSerialMedianSeconds $set.serialBaselineMedianSeconds
  }
 }else{
  $real=$Replay.inventory.real
  Add-FrontendReplayCorpus 'real' $real.inputs $null $real.units $real.sourceCount $real.sourceBytes 0 $null $null
  foreach($set in $Replay.inventory.retainedOriginalCorpora){
   $originalSet=@($Replay.original.corpora|Where-Object name -CEQ $set.name)[0]
   if($originalSet.trials.Count -ne 7 -or $set.repeats -lt 1 -or $set.repeats -gt 16384){throw 'Incomplete original serial baseline'}
   foreach($trial in $originalSet.trials){
    if($trial.result.jobs -ne 1 -or $trial.result.repeats -ne $set.repeats -or -not $trial.result.completeResults -or -not $trial.result.cleanup){throw 'Invalid original baseline trial'}
   }
   $name=$set.name;if($name -ceq 'real'){$name='original-real'}
   $median=Get-FrontendMedian @($originalSet.trials | ForEach-Object {[double]$_.result.workSeconds})
   Add-FrontendReplayCorpus $name $set.inputs.snapshot $set.reference.snapshot $set.units $set.sourceCount $set.sourceBytes $set.repeats $median $null
  }
 }
 $names=@($corpora.name | Sort-Object)
 if(($names -join ',') -cne 'balanced,original-real,real,small-empty,small-source,uneven'){throw 'Replay must retain expanded real and all five original corpora'}
}
function Get-FrontendBuildInputs([string[]]$Paths,$Selection){
 $accepted=Get-Content -LiteralPath $Selection.manifest.path -Raw | ConvertFrom-Json
 # Include producer source identities as well as the directly linked consumer.
 $producer=@($accepted.inputs | Where-Object { $_.path -match '[\\/](compiler[\\/]UBE_Compiler_v2|bootstrap[\\/](src|include))[\\/]' -and $_.path -notmatch '[\\/]tests[\\/]' -and $_.path -match '\.(bas|cls|cpp|c|h|hpp)$' } | ForEach-Object path)
 $records=@()
 foreach($path in @($Paths+$producer | Sort-Object -Unique)){
  $full=[IO.Path]::GetFullPath($path)
  if(-not $full.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Build source outside workspace'}
  if($full -match '[\\/]bootstrap[\\/]out[\\/]'){continue}
  $records+=[pscustomobject]@{role=$full.Substring($root.Length+1).Replace('\','/');identity=(Get-ArtifactIdentity $full)}
 }
 return $records
}
function Compare-FrontendBuildInputs($Baseline,[object[]]$Current,[string[]]$Allowed){
 $allowedRoles=@()
 foreach($path in $Allowed){
  if([IO.Path]::IsPathRooted($path)){throw 'Declare changed build inputs with workspace-relative paths'}
  $full=[IO.Path]::GetFullPath((Join-Path $root $path))
  if(-not $full.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Allowed input outside workspace'}
  $role=$full.Substring($root.Length+1).Replace('\','/')
  if($role -match '(^|/)(tests|tools)/|\.ps1$|\.md$|\.UBE$'){throw ('Measurement harness, manifests, scripts and contracts cannot be exempted: '+$role)}
  if($role -in $allowedRoles){throw 'Duplicate changed-build-input declaration'}
  $allowedRoles+=$role
 }
 $before=@($Baseline.buildInputs.role | Sort-Object);$after=@($Current.role | Sort-Object)
 if(($before -join "`n") -cne ($after -join "`n")){throw 'Build input inventory changed; freeze a separate pre-optimization baseline'}
 $changes=@();$used=@()
 foreach($input in $Current){
  $old=@($Baseline.buildInputs | Where-Object role -CEQ $input.role)
  if($old.Count -ne 1){throw 'Ambiguous baseline input role'}
  if($input.identity.sha256 -cne $old[0].identity.sha256 -or $input.identity.bytes -ne $old[0].identity.bytes){
   if($input.role -notin $allowedRoles){throw ('Unexpected baseline/candidate input change: '+$input.role)}
   $used+=$input.role;$changes+=[pscustomobject]@{role=$input.role;baseline=$old[0].identity;candidate=$input.identity}
  }
 }
 foreach($role in $allowedRoles){if($role -notin $used){throw ('Unused changed-build-input declaration: '+$role)}}
 return $changes
}
function Invoke-FrontendNative([string]$Executable,$Set,[string]$Reference,[int]$Jobs,[int]$Repeats,[int]$Create=0){
 $program=Get-ArtifactIdentity $Executable
 Assert-FrontendIdentity $program;Assert-FrontendIdentity $Set.inputs
 if($Create -eq 0){Assert-FrontendIdentity $Set.reference}
 $process=Invoke-BoundedProcess $Executable @($Set.inputs.path,$Reference,[string]$Jobs,[string]$Repeats,[string]$Create) $root 600
 if($process.timedOut -or $process.exit -ne 0 -or $process.stderr -cne ''){throw ('Native frontend operation failed: '+($process|ConvertTo-Json -Depth 5 -Compress))}
 $row=$process.stdout | ConvertFrom-Json
 if($row.jobs -ne $Jobs -or $row.repeats -ne $Repeats -or $row.sources -ne $Set.sourceCount -or -not $row.completeResults -or -not $row.cleanup -or $row.physicalCores -lt 4 -or ($Repeats -gt 0 -and $row.workSeconds -le 0)){throw 'Native frontend result/control mismatch'}
 Assert-FrontendIdentity $program;Assert-FrontendIdentity $Set.inputs
 if($Create -eq 0){Assert-FrontendIdentity $Set.reference}
 return [pscustomobject]@{process=$process;result=$row}
}
function Get-FrontendAffinity{
 $logical=@(Get-ChildItem 'HKLM:/HARDWARE/DESCRIPTION/System/CentralProcessor').Count
 if($logical -lt 4 -or $logical -gt 64){throw 'A single processor group with at least four available physical cores is required'}
 $current=[Diagnostics.Process]::GetCurrentProcess()
 try{$signed=$current.ProcessorAffinity.ToInt64()}finally{$current.Dispose()}
 $mask=[BitConverter]::ToUInt64([BitConverter]::GetBytes($signed),0)
 $expected=[uint64]::MaxValue;if($logical -lt 64){$expected=[uint64][Math]::Pow(2,$logical)-1}
 if($mask -ne $expected){throw 'Measurement process must inherit availability of every host logical processor'}
 return [pscustomobject]@{logicalProcessors=$logical;inheritedProcessorMask=[string]$mask;scope='Native child inherits this process affinity; native result must independently report at least four physical cores'}
}
function Assert-FrontendSessionContext{
 foreach($pin in @($pins)+@($frozenPins)){
  $now=Get-ArtifactIdentity $pin.path
  if($now.sha256 -cne $pin.sha256 -or $now.bytes -ne $pin.bytes){throw ('Session source/input/artifact changed: '+$pin.path)}
 }
 $null=Get-VerifiedBootstrapSelection $SelectionPath
 $currentAffinity=Get-FrontendAffinity
 $powerPlan=(& powercfg /getactivescheme | Out-String).Trim()
 if($powerPlan -cne $hardware.powerPlan -or ($currentAffinity|ConvertTo-Json -Compress) -cne ($affinity|ConvertTo-Json -Compress)){throw 'Session power plan or processor availability changed'}
 return [pscustomobject]@{utc=[DateTime]::UtcNow.ToString('o');powerPlan=$powerPlan;affinity=$currentAffinity;pinsChecked=$pins.Count+$frozenPins.Count}
}
function Invoke-FrontendReplay($Replay,[object[]]$Builds){
 $exe=$Builds[-1].exe.path;$negative=$null
 foreach($set in $corpora){
  Write-Host ('Validate frozen '+$set.name+' ('+$set.sourceCount+' sources)')
  foreach($build in $Builds){
   if(-not $set.reference){
    $reference=Join-Path $run ($set.name+'.expected')
    $row=Invoke-FrontendNative $build.exe.path $set $reference 1 0 1
    $set.reference=Get-ArtifactIdentity $reference
    $set.referenceCreation=[pscustomobject]@{inputs=$set.inputs;reference=$set.reference;compiler=$build.compiler;program=$build.exe;raw=$build.raw;native=$row}
   }else{
    $row=Invoke-FrontendNative $build.exe.path $set $set.reference.path 1 0 0
   }
   $set.admission+=[pscustomobject]@{compiler=$build.compiler;native=$row}
  }
  if(-not $negative){
   $bad=Join-Path $run 'corrupt.expected';$bytes=[IO.File]::ReadAllBytes($set.reference.path);$bytes[0]=$bytes[0] -bxor 1;[IO.File]::WriteAllBytes($bad,$bytes)
   $negative=Invoke-BoundedProcess $exe @($set.inputs.path,$bad,'1','0','0') $root 600
   if($negative.timedOut -or $negative.exit -eq 0 -or $negative.stderr -notmatch 'complete result/reference mismatch'){throw 'Frozen reference corruption negative control did not fail as required'}
  }
  if($set.repeats -eq 0){
   $repeats=1
   do{
    $pilot=Invoke-FrontendNative $exe $set $set.reference.path 1 $repeats
    $set.pilot+=$pilot
    if($pilot.result.workSeconds -ge 1.25){break}
    $repeats*=2;if($repeats -gt 16384){throw 'Expanded real pilot exceeded the repetition bound'}
   }while($true)
   $set.repeats=$repeats
  }
 }
 $sessions=@();$comparisons=@();$accepted=$false
 if(-not $Replay.previous){
  $sessionStart=Assert-FrontendSessionContext
  for($trial=0;$trial -lt 7;++$trial){
   $order=@($corpora);if($trial%2 -eq 1){[array]::Reverse($order)}
   foreach($set in $order){
    Write-Host ('Frozen baseline '+$set.name+' trial '+($trial+1)+'/7')
    $native=Invoke-FrontendNative $exe $set $set.reference.path 1 $set.repeats
    $set.trials+=[pscustomobject]@{session=0;trial=$trial;jobs=1;process=$native.process;result=$native.result}
   }
  }
  foreach($set in $corpora){
   $set.serialBaselineMedianSeconds=Get-FrontendMedian @($set.trials | ForEach-Object {[double]$_.result.workSeconds})
   if($set.serialBaselineMedianSeconds -lt 1){throw 'Expanded baseline median below the fixed one-second floor'}
  }
  $sessionEnd=Assert-FrontendSessionContext
  $sessions+=[pscustomobject]@{session=0;kind='serial baseline';trialCount=7;start=$sessionStart;end=$sessionEnd}
 }else{
  $orders=@(@(1,2,4),@(2,4,1),@(4,1,2))
  for($session=0;$session -lt 2;++$session){
   $sessionStart=Assert-FrontendSessionContext
   for($trial=0;$trial -lt 7;++$trial){
    $order=@($corpora);if($trial%2 -eq 1){[array]::Reverse($order)}
    foreach($set in $order){
     foreach($jobs in $orders[$trial%3]){
      Write-Host ('Candidate session '+($session+1)+' '+$set.name+' trial '+($trial+1)+'/7 jobs '+$jobs)
      $native=Invoke-FrontendNative $exe $set $set.reference.path $jobs $set.repeats
      $set.trials+=[pscustomobject]@{session=$session;trial=$trial;jobs=$jobs;process=$native.process;result=$native.result}
     }
    }
   }
   $summary=@()
   foreach($set in $corpora){
    $medians=@{};$budgets=@()
    foreach($jobs in @(1,2,4)){
     $rows=@($set.trials | Where-Object {$_.session -eq $session -and $_.jobs -eq $jobs})
     $times=@($rows | ForEach-Object {[double]$_.result.workSeconds});$median=Get-FrontendMedian $times;$medians[$jobs]=$median
     $cpu=@($rows | ForEach-Object {[double]$_.result.cpuSeconds})
     $budgets+=[pscustomobject]@{jobs=$jobs;trials=$rows.Count;medianSeconds=$median;minimumSeconds=($times|Measure-Object -Minimum).Minimum;maximumSeconds=($times|Measure-Object -Maximum).Maximum;medianCpuSeconds=(Get-FrontendMedian $cpu);minimumCpuSeconds=($cpu|Measure-Object -Minimum).Minimum;maximumCpuSeconds=($cpu|Measure-Object -Maximum).Maximum;maximumPeakWorkingSetBytes=($rows.result.peakWorkingSetBytes|Measure-Object -Maximum).Maximum}
    }
    $checks=@([pscustomobject]@{name='matching serial baseline';actual=$medians[1];limit=1.05*$set.serialBaselineMedianSeconds;passed=($medians[1] -le 1.05*$set.serialBaselineMedianSeconds)})
    if($null -ne $set.originalSerialMedianSeconds){$checks+=[pscustomobject]@{name='original frozen serial baseline';actual=$medians[1];limit=1.05*$set.originalSerialMedianSeconds;passed=($medians[1] -le 1.05*$set.originalSerialMedianSeconds)}}
    if($set.name -in @('real','balanced')){
     foreach($target in @(@(2,1.5),@(4,2.0))){$speedup=$medians[1]/$medians[[int]$target[0]];$checks+=[pscustomobject]@{name=('speedup at '+$target[0]+' workers');actual=$speedup;minimum=$target[1];passed=($speedup -ge $target[1])}}
    }
    if($set.name -in @('small-empty','small-source')){
     foreach($jobs in @(1,2,4)){$checks+=[pscustomobject]@{name=('small-input guard jobs '+$jobs);actual=$medians[$jobs];limit=1.10*$medians[1];passed=($medians[$jobs] -le 1.10*$medians[1])}}
    }
    $item=[pscustomobject]@{session=$session;corpus=$set.name;budgets=$budgets;checks=$checks;passed=(@($checks|Where-Object {-not $_.passed}).Count -eq 0)}
    $summary+=$item;$comparisons+=$item
   }
   $sessionEnd=Assert-FrontendSessionContext
   $sessions+=[pscustomobject]@{session=$session;trialCount=7;budgetOrders=$orders;alternateCorpusOrder=$true;start=$sessionStart;end=$sessionEnd;corpora=$summary;passed=(@($summary|Where-Object {-not $_.passed}).Count -eq 0)}
  }
  $accepted=$sessions.Count -eq 2 -and @($sessions|Where-Object {-not $_.passed}).Count -eq 0
 }
 return [pscustomobject]@{negative=$negative;sessions=$sessions;comparisons=$comparisons;accepted=$accepted}
}

$frozenPins=[Collections.Generic.List[object]]::new()
$frozenPinMap=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
$replay=$null
if($FrozenInventory -and $BaselineReport){throw 'Choose frozen-inventory baseline or candidate baseline report'}
if(($FrozenInventory -or $BaselineReport) -and ($DiagnosticOnly -or $Corpus -cne 'all')){throw 'Frozen replay requires complete qualified runs; diagnostic/partial modes are unavailable'}
if($ChangedBuildInputs.Count -gt 0 -and -not $BaselineReport){throw 'Changed build inputs are candidate-only provenance declarations'}
if($Corpus -ne 'all'){$DiagnosticOnly=$true}
$selection=Get-VerifiedBootstrapSelection $SelectionPath
if($FrozenInventory -or $BaselineReport){$replay=Read-FrontendReplay $FrozenInventory $BaselineReport}
$run=Join-Path $root ('bootstrap/out/frontend-performance/'+[Guid]::NewGuid().ToString('N'))
$projectDir=Join-Path $run 'project'
$null=New-Item -ItemType Directory -Path $projectDir -Force
$utf8=[Text.UTF8Encoding]::new($false)
$productionNames=@('SourceOwner.cls','SourceWork.cls','SourceCancellation.cls','SourceWorkerSlots.bas','SourceParsing.bas','SourceInput.bas','SourceFile.bas','ScannerWords.bas','SourceScanner.bas','SourceEnvelope.bas','SyntaxTree.bas','SyntaxExpressions.bas','SyntaxGrammar.bas','SourceSyntax.bas')
$sources=@($productionNames | ForEach-Object {Join-Path $root ('compiler/UBE_Compiler_v3/src/'+$_)})
$entry=Join-Path $root 'compiler/UBE_Compiler_v3/tests/concurrency/PerformanceEntry.bas'
$sources+=$entry
foreach($source in $sources){Copy-Item -LiteralPath $source -Destination $projectDir}
$project=Join-Path $projectDir 'FrontendPerformance.UBE'
$lines=@('UBE-Project 1','Name = "FrontendPerformance"','Kind = "Exe"','Startup = "Main"','Reference = "../../../../../std-lib/UBECore.UBE"')
$lines+=@($productionNames+@('PerformanceEntry.bas') | ForEach-Object {'Source = "'+$_+'"'})
[IO.File]::WriteAllText($project,($lines -join "`n")+"`n",$utf8)
foreach($line in Get-Content -LiteralPath (Join-Path $root 'std-lib/UBECore.UBE')){
 if($line -match '^Source = "([^"]+)"'){$sources+=Join-Path (Join-Path $root 'std-lib') $Matches[1]}
}
$realPaths=@();$unsupported=@()
foreach($manifest in @('compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE','std-lib/UBECore.UBE')){
 foreach($line in Get-Content -LiteralPath (Join-Path $root $manifest)){
  if($line -match '^Source = "([^"]+)"'){
   $source=Join-Path (Join-Path $root (Split-Path $manifest -Parent)) $Matches[1]
   if($source -like '*.bas'){$realPaths+=$source}else{$unsupported+=Get-ArtifactIdentity $source}
  }
 }
}
$corpora=@()
function Add-Corpus([string]$Name,[object[]]$Documents,[string[]]$Labels){
 $file=Join-Path $run ($Name+'.inputs')
 $stream=[IO.File]::Create($file);$writer=[IO.BinaryWriter]::new($stream)
 $units=@();$total=0L
 try{
  $writer.Write([int]$Documents.Count)
  for($i=0;$i -lt $Documents.Count;++$i){
   [byte[]]$bytes=$Documents[$i];$writer.Write([int]$bytes.Length);$writer.Write($bytes)
   $sha=[Security.Cryptography.SHA256]::Create()
   try{$hash=([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','')}finally{$sha.Dispose()}
   $units+=[pscustomobject]@{id=$i;label=$Labels[$i];bytes=$bytes.Length;sha256=$hash};$total+=$bytes.Length
  }
 }finally{$writer.Dispose();$stream.Dispose()}
 $script:corpora+=[pscustomobject]@{name=$Name;inputs=(Get-ArtifactIdentity $file);sourceCount=$Documents.Count;sourceBytes=$total;units=$units;reference=$null;repeats=0;pilot=@();trials=@()}
}
if($replay){Initialize-FrontendReplay $replay}else{
$documents=@();foreach($source in $realPaths){$documents+=,[IO.File]::ReadAllBytes($source)}
Add-Corpus 'real' $documents $realPaths
$large=[IO.File]::ReadAllText((Join-Path $root 'compiler/UBE_Compiler_v3/src/SyntaxExpressions.bas'),$utf8)
$small=[IO.File]::ReadAllText((Join-Path $root 'std-lib/src/portable/LibraryIdentity.bas'),$utf8)
$balanced=@();$uneven=@();$balancedLabels=@();$unevenLabels=@()
for($i=0;$i -lt 32;++$i){
 $balanced+=,$utf8.GetBytes(($large -replace 'Attribute UBE_Name = "SyntaxExpressions"',('Attribute UBE_Name = "Balanced'+$i+'"')))
 $balancedLabels+='SyntaxExpressions.bas with UBE_Name Balanced'+$i
 if($i % 2 -eq 0){$template=$large;$original='SyntaxExpressions'}else{$template=$small;$original='LibraryIdentity'}
 $uneven+=,$utf8.GetBytes(($template -replace ('Attribute UBE_Name = "'+$original+'"'),('Attribute UBE_Name = "Uneven'+$i+'"')))
 $unevenLabels+=$original+'.bas with UBE_Name Uneven'+$i
}
Add-Corpus 'balanced' $balanced $balancedLabels
Add-Corpus 'uneven' $uneven $unevenLabels
Add-Corpus 'small-empty' @(,$utf8.GetBytes("UBE SOURCE 1 MODULE`nAttribute UBE_Name = ""Empty""`n")) @('empty native MODULE')
Add-Corpus 'small-source' @(,[IO.File]::ReadAllBytes((Join-Path $root 'compiler/UBE_Compiler_v3/src/SourceInput.bas'))) @('SourceInput.bas')
}
$nativeSource=Join-Path $root 'compiler/UBE_Compiler_v3/tests/concurrency/performance.c'
$contract=Join-Path $root 'compiler/UBE_Compiler_v3/PERFORMANCE-CONTRACT.md'
$pinPaths=@($sources)+$realPaths+@($unsupported.path)+@(Get-ChildItem -LiteralPath $projectDir -File | ForEach-Object FullName)+@($PSCommandPath,$contract,$nativeSource,$SelectionPath,$project,(Join-Path $root 'bootstrap/tools/verification.ps1'),(Join-Path $root 'bootstrap/runtime/bootstrap_runtime.c'),(Join-Path $root 'bootstrap/runtime/value_storage.h'),(Join-Path $root 'bootstrap/runtime/windows/file_primitives.c'),(Join-Path $root 'bootstrap/runtime/windows/thread_primitives.c'),(Join-Path $root 'compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE'),(Join-Path $root 'std-lib/UBECore.UBE'))
$buildInputs=@();$sourceComparison=@();$selectionComparison=@();$affinity=$null
if($replay){
 $buildInputs=@(Get-FrontendBuildInputs $pinPaths $selection)
 $pinPaths+=@($buildInputs.identity.path)+@($frozenPins.path)
 if($replay.previous){
  $sourceComparison=@(Compare-FrontendBuildInputs $replay.previous $buildInputs $ChangedBuildInputs)
  $before=@($replay.previous.selection.PSObject.Properties.Name|Sort-Object);$after=@($selection.PSObject.Properties.Name|Sort-Object)
  if(($before -join ',') -cne ($after -join ',')){throw 'Selected tool role inventory changed'}
  foreach($property in $selection.PSObject.Properties){
   if($property.Name -ceq 'schema'){continue}
   $prior=$replay.previous.selection.($property.Name)
   $same=$property.Value.sha256 -ceq $prior.sha256 -and $property.Value.bytes -eq $prior.bytes
   if($property.Name -in @('clang','unicodeRuntime') -and -not $same){throw ('Frozen code-generation/link tool changed: '+$property.Name)}
   $selectionComparison+=[pscustomobject]@{role=$property.Name;baseline=$prior;candidate=$property.Value;identical=$same;reason=$(if($same){'same artifact'}else{'separately qualified cohort; producer/runtime source differences are pinned and declared separately'})}
  }
 }
}
$pins=@($pinPaths | Sort-Object -Unique | ForEach-Object {Get-ArtifactIdentity $_})
$hardware=[pscustomobject]@{processors=@();os=$null;inventoryFailure=$null;powerPlan=(& powercfg /getactivescheme | Out-String).Trim();logicalProcessors=[Environment]::ProcessorCount}
try{
 $hardware.processors=@(Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors)
 $hardware.os=Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber,TotalVisibleMemorySize
}catch{
 $hardware.inventoryFailure=$_.Exception.Message
 $hardware.processors=@(Get-ItemProperty 'HKLM:/HARDWARE/DESCRIPTION/System/CentralProcessor/0' | Select-Object ProcessorNameString,Identifier)
 $hardware.os=Get-ItemProperty 'HKLM:/SOFTWARE/Microsoft/Windows NT/CurrentVersion' | Select-Object ProductName,DisplayVersion,CurrentBuildNumber,UBR
}
if($replay){
 $affinity=Get-FrontendAffinity
 if($replay.previous){
  foreach($key in @('processors','os','powerPlan','logicalProcessors')){
   if(($hardware.$key|ConvertTo-Json -Depth 6 -Compress) -cne ($replay.previous.hardware.$key|ConvertTo-Json -Depth 6 -Compress)){throw ('Baseline/candidate host context changed: '+$key)}
  }
  if(($affinity|ConvertTo-Json -Compress) -cne ($replay.previous.affinity|ConvertTo-Json -Compress)){throw 'Baseline/candidate processor availability changed'}
 }
}
$procedures=@{};$index=0
foreach($source in $sources){
 foreach($m in [regex]::Matches([IO.File]::ReadAllText($source),'(?m)^(?:(?:Public|Private|Friend) )?(?:Intrinsic )?(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)\b')){
  $name=$m.Groups[1].Value;if($procedures.ContainsKey($name)){throw "Duplicate ABI procedure $name"};$procedures[$name]='ube.p'+$index;++$index
 }
}
$types=@{SourceOwner='%ube.type.0';SourceWork='%ube.type.1';SourceCancellation='%ube.type.2'};$typeIndex=3
foreach($source in $sources){foreach($m in [regex]::Matches([IO.File]::ReadAllText($source),'(?m)^Type ([A-Za-z_][A-Za-z_0-9]*)\b')){$types[$m.Groups[1].Value]='%ube.type.'+$typeIndex;++$typeIndex}}
$success=$false;$frozen=$false;$failure=$null;$builds=@();$negative=$null
$performanceAccepted=$false;$sessions=@();$comparisons=@();$measurement=$null
$report=Join-Path $run 'report.json'
$flags=@('--target=x86_64-w64-windows-gnu','-O2','-I',(Join-Path $root 'bootstrap/runtime'),'-x','ir')
if($replay -and $replay.previous -and ($flags -join "`n") -cne ($replay.previous.buildFlags -join "`n")){throw 'Baseline/candidate target, optimization, language or link flags changed'}
try{
 $prior='';$exe=''
 $stages=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
 foreach($stage in $stages){
  $stageDir=Join-Path $run ('stage'+$builds.Count);$null=New-Item -ItemType Directory -Path $stageDir
  $rawPath=Join-Path $stageDir 'raw.ll';$adaptedPath=Join-Path $stageDir 'entry.ll';$exe=Join-Path $stageDir 'measure.exe'
  $emit=Invoke-BoundedProcess $stage @($project,$rawPath) $root 180
  if($emit.timedOut -or $emit.exit -ne 0){throw ('UBE emission failed: '+$emit.stdout+$emit.stderr)}
  $raw=[IO.File]::ReadAllText($rawPath);$rawIdentity=Get-ArtifactIdentity $rawPath
  if($prior -and $prior -cne $rawIdentity.sha256){throw 'Source-built stages emitted different raw LLVM'};$prior=$rawIdentity.sha256
  $adapter=[Text.StringBuilder]::new()
  foreach($b in @(@('perf_make','TryMakePerformanceOwner','i1','ptr,i32,ptr'),@('perf_sources','TryParseSources','i1','ptr,i32,i32,i32,i32,i32,ptr,ptr,ptr'),@('perf_cancel','MakePerformanceCancellation','void','ptr'))){
   $symbol=$procedures[$b[1]];$found=[regex]::Matches($raw,'(?m)^define '+$b[2]+' @'+[regex]::Escape($symbol)+'\(([^\r\n]*)\) \{\r?$')
   if($found.Count -ne 1){throw ('Missing exact ABI '+$b[1])}
   $actual=@($found[0].Groups[1].Value -split ', ' | ForEach-Object {($_ -split ' ')[0]}) -join ','
   if($actual -cne $b[3]){throw ('Mismatched ABI '+$b[1])}
   $args=@();$calls=@();$parts=$b[3] -split ','
   for($i=0;$i -lt $parts.Count;++$i){$args+=$parts[$i]+' %a'+$i;$calls+=$parts[$i]+' %a'+$i}
   $return=$b[2];if($return -ceq 'i1'){$return='i32'}
   [void]$adapter.AppendLine('define '+$return+' @'+$b[0]+'('+($args -join ', ')+') {')
   $call='call '+$b[2]+' @'+$symbol+'('+($calls -join ', ')+')'
   if($b[2] -ceq 'void'){[void]$adapter.AppendLine(' '+$call+"`n ret void")}else{[void]$adapter.AppendLine(' %ok = '+$call+"`n %status = zext i1 %ok to i32`n ret i32 %status")}
   [void]$adapter.AppendLine('}')
  }
  $layouts=@{SourceOwner=($types.SourceDocument+', i32');SourceWork=('ptr, ptr, ptr, '+$types.SyntaxFailure+', '+$types.SyntaxMetrics+', i64, i32, i32, i32, i32, i32');SourceCancellation='i1';SourcePosition='i32, i32, i32, i32';SourceDocument='ptr, i32, i32, i32';SourceToken=('i32, '+$types.SourcePosition+', '+$types.SourcePosition);SyntaxNode='i32, i32, i32, i32, i32, i32';SyntaxResult='ptr, i32, i32, i32';SyntaxFailure='i32, i32, i32';SyntaxMetrics='i32, i32, i32, i32, i32';SourceSetFailure=('i32, i32, '+$types.SyntaxFailure)}
  foreach($name in $layouts.Keys){
   $line=$types[$name]+' = type { '+$layouts[$name]+' }'
   if([regex]::Matches($raw,'(?m)^'+[regex]::Escape($line)+'\r?$').Count -ne 1){throw ('Payload ABI differs: '+$name)}
  }
  if($raw -match 'observe_|observed_'){throw 'Observer found in raw timed code'}
  [void]$adapter.AppendLine("define ptr @perf_layout(i32 %role) {`n switch i32 %role, label %invalid [`n i32 0, label %owner`n i32 1, label %byte`n ]`ninvalid:`n ret ptr null`nowner:`n ret ptr @ube.value.20000`nbyte:`n ret ptr @ube.value.7`n}")
  $adapted=[regex]::Replace($raw,'(?m)^define i32 @main\(','define i32 @perf_unused_main(')
  [IO.File]::WriteAllText($adaptedPath,$adapted+"`n"+$adapter.ToString(),$utf8)
  $link=Invoke-BoundedProcess $selection.clang.path ($flags+@($adaptedPath,'-x','c',$nativeSource,'-x','none',$selection.unicodeRuntime.path,'-o',$exe)) $root 180
  if($link.timedOut -or $link.exit -ne 0){throw ('Native link failed: '+$link.stdout+$link.stderr)}
  $builds+=[pscustomobject]@{compiler=(Get-ArtifactIdentity $stage);raw=$rawIdentity;entry=(Get-ArtifactIdentity $adaptedPath);exe=(Get-ArtifactIdentity $exe);emit=$emit;link=$link}
 }
 if($replay){
  foreach($build in $builds){foreach($identity in @($build.compiler,$build.raw,$build.entry,$build.exe)){Assert-FrontendIdentity $identity}}
  $selected=@($corpora)
  $measurement=Invoke-FrontendReplay $replay $builds
  $negative=$measurement.negative;$sessions=$measurement.sessions;$comparisons=$measurement.comparisons
 }else{
 $selected=@($corpora | Where-Object {$Corpus -eq 'all' -or $_.name -eq $Corpus})
 foreach($set in $selected){
  Write-Output ('Preparing '+$set.name+' ('+$set.sourceCount+' sources, '+$set.sourceBytes+' bytes)')
  $reference=Join-Path $run ($set.name+'.expected')
  $create=Invoke-BoundedProcess $exe @($set.inputs.path,$reference,'1','0','1') $root 600
  if($create.timedOut -or $create.exit -ne 0){throw ('Reference creation failed: '+$create.stdout+$create.stderr)}
  $set.reference=Get-ArtifactIdentity $reference
  if(-not $negative){
   $bad=Join-Path $run 'corrupt.expected';$bytes=[IO.File]::ReadAllBytes($reference);$bytes[0]=$bytes[0] -bxor 1;[IO.File]::WriteAllBytes($bad,$bytes)
   $negative=Invoke-BoundedProcess $exe @($set.inputs.path,$bad,'1','0','0') $root 600
   if($negative.timedOut -or $negative.exit -eq 0 -or $negative.stderr -notmatch 'complete result/reference mismatch'){throw 'Reference corruption negative control did not fail as expected'}
  }
  $repeats=1
  do{
   $pilot=Invoke-BoundedProcess $exe @($set.inputs.path,$reference,'1',([string]$repeats),'0') $root 600
   if($pilot.timedOut -or $pilot.exit -ne 0){throw ('Pilot failed: '+$pilot.stdout+$pilot.stderr)}
   $row=$pilot.stdout | ConvertFrom-Json;$set.pilot+=[pscustomobject]@{process=$pilot;result=$row}
   if(-not $DiagnosticOnly -and $row.physicalCores -lt 4){throw 'Performance host has fewer than four physical cores'}
   if($row.workSeconds -ge 1.25 -or $DiagnosticOnly){break}
   $repeats*=2
   if($repeats -gt 16384){throw 'Pilot exceeded fixed repetition bound'}
  }while($true)
  $set.repeats=$repeats
 }
 $trialCount=7;if($DiagnosticOnly){$trialCount=1}
 for($trial=0;$trial -lt $trialCount;++$trial){
  $order=@($selected);if($trial % 2 -eq 1){[array]::Reverse($order)}
  foreach($set in $order){
   Write-Output ('Baseline '+$set.name+' trial '+($trial+1)+'/'+$trialCount)
   $native=Invoke-BoundedProcess $exe @($set.inputs.path,$set.reference.path,'1',([string]$set.repeats),'0') $root 600
   if($native.timedOut -or $native.exit -ne 0){throw ('Trial failed: '+$native.stdout+$native.stderr)}
   $set.trials+=[pscustomobject]@{trial=$trial;process=$native;result=($native.stdout | ConvertFrom-Json)}
  }
 }
 }
 foreach($pin in $pins){$now=Get-ArtifactIdentity $pin.path;if($now.sha256 -cne $pin.sha256 -or $now.bytes -ne $pin.bytes){throw ('Pinned input changed: '+$pin.path)}}
 $null=Get-VerifiedBootstrapSelection $SelectionPath
 foreach($set in $selected){
  if((Get-ArtifactIdentity $set.inputs.path).sha256 -cne $set.inputs.sha256 -or (Get-ArtifactIdentity $set.reference.path).sha256 -cne $set.reference.sha256){throw 'Frozen corpus/reference changed'}
  if(-not $DiagnosticOnly -and -not ($replay -and $replay.previous)){$times=@($set.trials.result.workSeconds | Sort-Object);if($times[3] -lt 1){throw 'Baseline median below one second'}}
 }
 if($replay){
  foreach($pin in $frozenPins){$now=Get-ArtifactIdentity $pin.path;if($now.bytes -ne $pin.bytes -or $now.sha256 -cne $pin.sha256){throw ('Replay input/artifact changed: '+$pin.path)}}
  foreach($set in $corpora){
   foreach($row in $set.admission){
    if($row.native.result.physicalCores -ne $corpora[0].admission[0].native.result.physicalCores -or $row.native.result.physicalMemoryBytes -ne $corpora[0].admission[0].native.result.physicalMemoryBytes){throw 'Inconsistent native host inventory'}
   }
   if($replay.previous){
    $priorSet=@($replay.previous.corpora|Where-Object name -CEQ $set.name)[0]
    if($set.admission[0].native.result.physicalCores -ne $priorSet.admission[0].native.result.physicalCores -or $set.admission[0].native.result.physicalMemoryBytes -ne $priorSet.admission[0].native.result.physicalMemoryBytes){throw 'Baseline/candidate native host inventory changed'}
   }
  }
  if($replay.previous){
   $performanceAccepted=$measurement.accepted
   if(-not $performanceAccepted){throw 'Complete candidate sessions retained; performance thresholds did not all pass'}
  }else{$frozen=$selected.Count -eq 6 -and $builds.Count -eq 2}
 }else{$frozen=-not $DiagnosticOnly -and $selected.Count -eq 5 -and $builds.Count -eq 2}
 $success=$true
}catch{$failure=$_.Exception.Message;throw}finally{
 $schema='ube-frontend-baseline-1';$scope='Uninstrumented actual UBE source-set baseline, not final performance or project-input acceptance.'
 if($replay){
  $schema='ube-frontend-baseline-2';$scope='Expanded representative real baseline with unchanged historical corpora and serial guards.'
  if($replay.previous){$schema='ube-frontend-candidate-1';$scope='Two complete uninstrumented candidate sessions with frozen complete-result/resource assertions and all acceptance comparisons.'}
 }
 [pscustomobject]@{schema=$schema;success=$success;frozenBaseline=$frozen;performanceAccepted=$performanceAccepted;diagnosticOnly=[bool]$DiagnosticOnly;failure=$failure;hardware=$hardware;affinity=$affinity;selection=$selection;inputs=$pins;unsupportedSourceKinds=$unsupported;buildFlags=$flags;builds=$builds;corpora=$corpora;negativeControl=$negative;frozenInventory=$(if($replay){$replay.identity}else{$null});baselineReport=$(if($replay){$replay.baselineIdentity}else{$null});originalBaseline=$(if($replay){$replay.inventory.originalBaseline}else{$null});buildInputs=$buildInputs;sourceComparison=$sourceComparison;selectionComparison=$selectionComparison;changedBuildInputs=$ChangedBuildInputs;sessions=$sessions;comparisons=$comparisons;scope=$scope} | ConvertTo-Json -Depth 26 | Set-Content -LiteralPath $report -Encoding UTF8
 Write-Output ('Evidence: '+$report)
}
if($performanceAccepted){Write-Output 'Both complete candidate sessions passed the frozen comparisons and performance thresholds.'}elseif($frozen){Write-Output 'Frozen pre-optimization baseline complete; final performance gate remains unfinished.'}else{Write-Output 'Diagnostic measurement only; no baseline/performance qualification.'}
