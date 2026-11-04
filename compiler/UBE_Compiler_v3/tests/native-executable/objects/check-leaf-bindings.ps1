param([Parameter(Mandatory=$true)][string]$ReaderReport,[Parameter(Mandatory=$true)][string]$BindingReport,[Parameter(Mandatory=$true)][string]$LeafReport)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))){$root=Split-Path $root -Parent;if(-not $root){throw 'Repository root missing'}}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$reader=Get-Content -LiteralPath $ReaderReport -Raw|ConvertFrom-Json;$binding=Get-Content -LiteralPath $BindingReport -Raw|ConvertFrom-Json;$leaf=Get-Content -LiteralPath $LeafReport -Raw|ConvertFrom-Json
if(-not $reader.success -or -not $binding.success -or -not $leaf.success -or $reader.acceptedSelection.compiler.sha256 -cne $binding.acceptedSelection.compiler.sha256 -or $reader.acceptedSelection.compiler.sha256 -cne $leaf.acceptedSelection.compiler.sha256){throw 'Passing reports from the same bootstrap tools required'}
$run=Join-Path $root ('bootstrap/out/native-leaf-bindings/'+[guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($run)
$inputs=@();$checks=@();$commands=@();$success=$false;$failure=$null
foreach($path in @($ReaderReport,$BindingReport,$LeafReport,$PSCommandPath,(Join-Path $root 'bootstrap/tools/verification.ps1'))){$inputs+=Get-ArtifactIdentity $path}
function Retain($Id){$actual=Get-ArtifactIdentity $Id.path;if($actual.sha256 -cne $Id.sha256){throw ('Retained input changed: '+$Id.path)};$script:inputs+=@($actual);return $actual.path}
function Run([string]$File,[string[]]$Arguments,[bool]$Rejected=$false){
 $r=Invoke-BoundedProcess $File $Arguments $run 30;$script:commands+=@($r)
 if($r.timedOut){throw ($r|ConvertTo-Json -Compress)}
 if($Rejected){if($r.exit -ne 1 -or $r.stderr -notmatch 'leaf binding row=[0-9]+ code=1506'){throw ('Changed leaf correspondence was not rejected by binder: '+($r|ConvertTo-Json -Compress))}}
 elseif($r.exit -ne 0 -or $r.stderr -cne ''){throw ($r|ConvertTo-Json -Compress)}
 return $r.stdout
}
try {
 foreach($input in $reader.inputs){$null=Retain $input}
 $probes=@();foreach($stage in 0..1){$id=@($reader.artifacts|Where-Object {(Split-Path $_.path -Leaf) -ceq ('stage'+$stage+'-probe.exe')});if($id.Count -ne 1){throw 'Reader executable missing'};$probes+=Retain $id[0]}
 $objects=[ordered]@{};foreach($check in $leaf.checks){if($check.PSObject.Properties.Name -contains 'leaves'){$objects[$check.object.path]=$check}}
 if($objects.Count -ne 32){throw 'Expected thirty-two independently traversed objects'};$ordinal=0
 foreach($objectPath in $objects.Keys){
  $metadata=$objects[$objectPath];$object=Retain $metadata.object
  $leafCommand=@($leaf.commands|Where-Object {$_.exit -eq 0 -and $_.arguments[0] -ceq '--leaves' -and $_.arguments[1] -ceq $objectPath})[0]
  $id=@($leaf.artifacts|Where-Object path -CEQ $leafCommand.arguments[2]);if($id.Count -ne 1){throw 'Independent leaf map missing'};$leafExpected=Retain $id[0]
  $oraclePath=$leafExpected.Replace('-expected.bin','-oracle.txt');$id=@($leaf.artifacts|Where-Object path -CEQ $oraclePath);if($id.Count -ne 1){throw 'Independent leaf disassembly missing'};$oracle=Retain $id[0]
  $boundCommand=@($binding.commands|Where-Object {$_.exit -eq 0 -and $_.arguments[0] -ceq '--bound-extents' -and $_.arguments[1] -ceq $objectPath})[0]
  $id=@($binding.inputs|Where-Object path -CEQ $boundCommand.arguments[2]);if($id.Count -lt 1){throw 'Retained image missing'};$image=Retain $id[0]
  $id=@($binding.artifacts|Where-Object path -CEQ $boundCommand.arguments[3]);if($id.Count -ne 1){$id=@($binding.inputs|Where-Object path -CEQ $boundCommand.arguments[3])};if($id.Count -lt 1){throw 'Frozen definition table missing'};$expected=Retain $id[0]
  $wanted=@{};foreach($entry in $metadata.leaves){$wanted[$entry.name]=[int]$entry.codeBytes}
  foreach($stage in 0..1){$actual=Run $probes[$stage] @('--bound-leaves',$object,$image,$expected,$leafExpected);$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
   foreach($line in ($actual.TrimEnd([char]10) -split '\n')){if($line -notmatch '^([^\t\r\n]+)\t([0-9]+)$' -or -not $wanted.ContainsKey($Matches[1]) -or [int]$Matches[2] -ne $wanted[$Matches[1]] -or -not $seen.Add($Matches[1])){throw 'Bound leaf result disagrees with independent disassembly'}}
   if($seen.Count -ne $wanted.Count){throw 'Missing bound leaf'};$checks+=@([pscustomobject]@{assertion='Retained names, indexed fences, both leaf traversals and complete extent/map binding match independent object disassembly';readerStage=$stage+1;object=$object;image=$image;functions=$metadata.leaves;passed=$true;output=$actual})
  }
  # Independent image name lookup from SDK COFF/PE structure offsets.
  $imageBytes=[IO.File]::ReadAllBytes($image);$head=[int][BitConverter]::ToUInt32($imageBytes,60)+4;$table=[int][BitConverter]::ToUInt32($imageBytes,$head+8);$count=[int][BitConverter]::ToUInt32($imageBytes,$head+12);$strings=$table+18*$count;$sections=$head+20+[BitConverter]::ToUInt16($imageBytes,$head+16);$first=-1;$targetName=$metadata.leaves[0].name
  for($i=0;$i -lt $count;){$at=$table+18*$i;$name='';if([BitConverter]::ToUInt32($imageBytes,$at) -eq 0){$start=$strings+[int][BitConverter]::ToUInt32($imageBytes,$at+4);$end=$start;while($end -lt $imageBytes.Length -and $imageBytes[$end] -ne 0){++$end};$name=[Text.Encoding]::ASCII.GetString($imageBytes,$start,$end-$start)}else{$name=[Text.Encoding]::ASCII.GetString($imageBytes,$at,8).TrimEnd([char]0)}
   $section=[int][BitConverter]::ToInt16($imageBytes,$at+12);$type=[BitConverter]::ToUInt16($imageBytes,$at+14)
   if($name -ceq $targetName -and $section -gt 0 -and $type -eq 32){if($first -ge 0){throw 'Ambiguous independent image anchor'};$sh=$sections+40*($section-1);$first=[int]([BitConverter]::ToUInt32($imageBytes,$sh+20)+[BitConverter]::ToUInt32($imageBytes,$at+8))};$i+=1+[int]$imageBytes[$at+17]
  };if($first -lt 0){throw 'Independent image anchor not found'}
  $map=[IO.File]::ReadAllBytes($leafExpected);if([BitConverter]::ToInt32($map,4) -ne $metadata.leaves[0].first){throw 'Independent first leaf differs'};$extent=[BitConverter]::ToInt32($map,12);$width=1;while($width -lt $extent -and $map[20+$width] -eq 3){++$width}
  $instruction=[regex]::Match([IO.File]::ReadAllText($oracle),'(?m)^\s*[0-9A-Fa-f]+:\s+(?:[0-9A-Fa-f]{2}\s+)+([a-z][a-z0-9]*)\s')
  if($width -lt 2 -or -not $instruction.Success -or $instruction.Groups[1].Value -match '^(j|ret|call|ud2)'){throw 'Selected control requires a multi-byte fallthrough instruction'}
  foreach($control in @('early-return','entry-nops')){$changed=[byte[]]$imageBytes.Clone();if($control -eq 'early-return'){$changed[$first]=0xC3}else{for($i=0;$i -lt $width;++$i){$changed[$first+$i]=0x90}};$wrong=Join-Path $run ($ordinal.ToString()+'-'+$control+'.exe');[IO.File]::WriteAllBytes($wrong,$changed)
   foreach($stage in 0..1){$null=Run $probes[$stage] @('--bound-leaves',$object,$wrong,$expected,$leafExpected) $true;$checks+=@([pscustomobject]@{assertion=('Independently decodable changed image leaf rejects at extent/map binding: '+$control);readerStage=$stage+1;passed=$true})}
  };++$ordinal
 }
 foreach($input in $inputs){if((Get-ArtifactIdentity $input.path).sha256 -cne $input.sha256){throw ('Input changed during verification: '+$input.path)}}
 $success=$true
}catch{$failure=$_.Exception.Message}
[pscustomobject]@{success=$success;failure=$failure;acceptedSelection=$reader.acceptedSelection;inputs=$inputs;checks=$checks;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Complete retained object/image leaf extent and reachable-boundary correspondence through qualified names, indexes, fences and traversals. Does not prove instruction values/targets, relocation equality, stack/debug validation or publication.'}|ConvertTo-Json -Depth 18|Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Evidence: $run/report.json"
if(-not $success){throw $failure}
