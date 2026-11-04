param([Parameter(Mandatory=$true)][string]$ReaderReport,[Parameter(Mandatory=$true)][string]$BindingReport)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))){$root=Split-Path $root -Parent;if(-not $root){throw 'Repository root missing'}}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$reader=Get-Content -LiteralPath $ReaderReport -Raw|ConvertFrom-Json;$binding=Get-Content -LiteralPath $BindingReport -Raw|ConvertFrom-Json
if(-not $reader.success -or -not $binding.success -or $reader.acceptedSelection.compiler.sha256 -cne $binding.acceptedSelection.compiler.sha256){throw 'Passing reports from the same bootstrap tools required'}
$run=Join-Path $root ('bootstrap/out/native-named-relocations/'+[guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($run)
$inputs=@();$checks=@();$commands=@();$success=$false;$failure=$null
foreach($path in @($ReaderReport,$BindingReport,$PSCommandPath,(Join-Path $root 'bootstrap/tools/verification.ps1'))){$inputs+=Get-ArtifactIdentity $path}
function Retain($Id){$actual=Get-ArtifactIdentity $Id.path;if($actual.sha256 -cne $Id.sha256){throw ('Retained input changed: '+$Id.path)};$script:inputs+=@($actual);return $actual.path}
function Run([string]$File,[string[]]$Arguments,[string]$Rejection=''){
 $r=Invoke-BoundedProcess $File $Arguments $run 30;$script:commands+=@($r)
 if($r.timedOut){throw ($r|ConvertTo-Json -Compress)}
 if($Rejection){if($r.exit -ne 1 -or $r.stderr -notmatch $Rejection){throw ('Named target control was not rejected: '+($r|ConvertTo-Json -Compress))}}
 elseif($r.exit -ne 0 -or $r.stderr -cne ''){throw ($r|ConvertTo-Json -Compress)}
 return $r.stdout
}
# Independent SDK file/section/symbol offsets; no production names or locations.
function Inventory([byte[]]$Bytes,[bool]$Image){
 $head=0;if($Image){$head=[int][BitConverter]::ToUInt32($Bytes,60)+4}
 $table=[int][BitConverter]::ToUInt32($Bytes,$head+8);$count=[int][BitConverter]::ToUInt32($Bytes,$head+12);$strings=$table+18*$count;$sections=$head+20+[BitConverter]::ToUInt16($Bytes,$head+16);$sectionCount=[int][BitConverter]::ToUInt16($Bytes,$head+2);$base=[long]0
 if($Image){$base=[BitConverter]::ToInt64($Bytes,$head+44)}
 $rows=@{};$index=0
 while($index -lt $count){$at=$table+18*$index;$first=$at;$length=0
  if([BitConverter]::ToUInt32($Bytes,$at) -eq 0){$first=$strings+[int][BitConverter]::ToUInt32($Bytes,$at+4);while($Bytes[$first+$length] -ne 0){++$length}}
  else{while($length -lt 8 -and $Bytes[$first+$length] -ne 0){++$length}}
  if($length -lt 1){throw 'Oracle encountered empty primary name'}
  $key=[BitConverter]::ToString($Bytes,$first,$length)
  $aux=[int]$Bytes[$at+17]
  $rows[$index]=[pscustomobject]@{index=$index;name=$key;nameFirst=$first;value=[long][BitConverter]::ToUInt32($Bytes,$at+8);section=[int][BitConverter]::ToInt16($Bytes,$at+12);type=[int][BitConverter]::ToUInt16($Bytes,$at+14);storage=[int]$Bytes[$at+16];aux=$aux}
  $index+=1+$aux
 }
 return [pscustomobject]@{rows=$rows;sections=$sections;sectionCount=$sectionCount;base=$base}
}
try {
 foreach($inputIdentity in $reader.inputs){$null=Retain $inputIdentity}
 $probes=@();foreach($stage in 0..1){$id=@($reader.artifacts|Where-Object {(Split-Path $_.path -Leaf) -ceq ('stage'+$stage+'-probe.exe')});if($id.Count -ne 1){throw 'Reader executable missing'};$probes+=Retain $id[0]}
 $pairs=[ordered]@{};foreach($command in $binding.commands){if($command.arguments[0] -ceq '--bound-extents' -and $command.exit -eq 0){$pairs[$command.arguments[1]]=$command.arguments[2]}}
 if($pairs.Count -ne 144){throw 'Expected all 144 generated objects'}
 $ordinal=0;$totalNamed=0;$totalUnsupported=0
 foreach($path in $pairs.Keys){
  $id=@($binding.inputs|Where-Object path -EQ $path);$iid=@($binding.inputs|Where-Object path -EQ $pairs[$path]);if($id.Count -lt 1 -or $iid.Count -lt 1){throw 'Qualified association missing'}
  $object=Retain $id[0];$image=Retain $iid[0];$ob=[IO.File]::ReadAllBytes($object);$ib=[IO.File]::ReadAllBytes($image);$oi=Inventory $ob $false;$ii=Inventory $ib $true
  $rows=@();$named=0;$unsupported=0;$firstImageName=-1
  for($si=0;$si -lt $oi.sectionCount;++$si){$sh=$oi.sections+40*$si;$flags=[long][BitConverter]::ToUInt32($ob,$sh+36);if(($flags -band 0x20000000) -eq 0){continue}
   $relocations=[int][BitConverter]::ToUInt32($ob,$sh+24);$count=[int][BitConverter]::ToUInt16($ob,$sh+32)
   if(($flags -band 0x01000000) -ne 0){throw 'Unexpected extended count in generated code'}
   for($ri=0;$ri -lt $count;++$ri){$at=$relocations+10*$ri;$target=[int][BitConverter]::ToUInt32($ob,$at+4);$kind=[int][BitConverter]::ToUInt16($ob,$at+8);$symbol=$oi.rows[$target];if(-not $symbol -or $kind -notin @(4,11)){throw 'Unexpected generated target/kind'}
    if($symbol.aux -ne 0){
     if($symbol.name -cne '2E-72-64-61-74-61' -or $symbol.storage -ne 3 -or $symbol.type -ne 0 -or $symbol.value -ne 0 -or $symbol.aux -ne 1 -or $kind -ne 4){throw 'Unexpected unsupported target'}
     $rows+=@([pscustomobject]@{si=$si;ri=$ri;accepted=0;fields=@(0,0,0,0,0,0);wide=@([long]0,[long]0,[long]0,[long]0)});++$unsupported;continue
    }
    if($symbol.section -lt 0 -or $symbol.storage -notin @(2,3) -or $symbol.type -notin @(0,32) -or ($symbol.section -eq 0 -and ($symbol.storage -ne 2 -or $symbol.value -ne 0))){throw 'Unexpected generated named symbol'}
    $definitions=@($ii.rows.Values|Where-Object {$_.name -ceq $symbol.name -and $_.section -gt 0 -and $_.storage -in @(2,3)})
    if($definitions.Count -ne 1){throw ('Independent image definition is ambiguous/missing: '+$symbol.name)}
    $match=$definitions[0];if(($symbol.section -gt 0 -or $symbol.type -eq 32) -and $symbol.type -ne $match.type){throw 'Independent type mismatch'}
    $ish=$ii.sections+40*($match.section-1);$virtual=[long][BitConverter]::ToUInt32($ib,$ish+8);$raw=[long][BitConverter]::ToUInt32($ib,$ish+20);$initialized=[Math]::Min([long][BitConverter]::ToUInt32($ib,$ish+16),$virtual);$iflags=[long][BitConverter]::ToUInt32($ib,$ish+36)
    if($match.value -ge $virtual){throw 'Independent target outside logical section'};$first=-1;$init=0
    if($raw -gt 0 -and $match.value -lt $initialized){$first=[int]($raw+$match.value);$init=1}
    $rva=[long][BitConverter]::ToUInt32($ib,$ish+12)+$match.value
    $rows+=@([pscustomobject]@{si=$si;ri=$ri;accepted=1;fields=@($match.index,($match.section-1),$first,1,$init,$match.type);wide=@($match.value,$rva,($ii.base+$rva),$iflags)})
    if($firstImageName -lt 0){$firstImageName=$match.nameFirst};++$named
   }
  }
  $stream=[IO.MemoryStream]::new();$writer=[IO.BinaryWriter]::new($stream);$writer.Write([int]$rows.Count)
  foreach($row in $rows){foreach($n in @($row.si,$row.ri,$row.accepted)+$row.fields){$writer.Write([int]$n)};foreach($n in $row.wide){$writer.Write([long]$n)}}
  $writer.Flush();$expectedBytes=$stream.ToArray();$writer.Dispose();$stream.Dispose();$expected=Join-Path $run ($ordinal.ToString()+'-expected.bin');[IO.File]::WriteAllBytes($expected,$expectedBytes)
  foreach($stage in 0..1){$actual=Run $probes[$stage] @('--named-relocations',$object,$image,$expected);if($actual -cne ("PASS $named named targets; $unsupported unsupported targets"+[char]10)){throw 'Named target comparison output differs'};$checks+=@([pscustomobject]@{assertion='Named target anchors match independent SDK-offset image oracle; anonymous targets explicitly reject';readerStage=$stage+1;input=$id[0];image=$iid[0];named=$named;unsupported=$unsupported;passed=$true})}
  if($named -gt 0){
   $wrong=[byte[]]$expectedBytes.Clone();$rowIndex=0;while($rows[$rowIndex].accepted -eq 0){++$rowIndex};$at=4+68*$rowIndex+12+32;[BitConverter]::GetBytes([long]([BitConverter]::ToInt64($wrong,$at)+1)).CopyTo($wrong,$at);$wrongPath=Join-Path $run ($ordinal.ToString()+'-wrong-rva.bin');[IO.File]::WriteAllBytes($wrongPath,$wrong)
   foreach($stage in 0..1){$null=Run $probes[$stage] @('--named-relocations',$object,$image,$wrongPath) ([regex]::Escape('memcmp(&result,&expected,sizeof expected)==0'));$checks+=@([pscustomobject]@{assertion='Incorrect independent target RVA is rejected';readerStage=$stage+1;passed=$true})}
   $wrong=[byte[]]$ib.Clone();$wrong[$firstImageName]=[byte]($wrong[$firstImageName] -bxor 1);$wrongPath=Join-Path $run ($ordinal.ToString()+'-missing-target.exe');[IO.File]::WriteAllBytes($wrongPath,$wrong)
   foreach($stage in 0..1){$null=Run $probes[$stage] @('--named-relocations',$object,$wrongPath,$expected) 'named relocation section=\d+ index=\d+ code=1506 expected=1';$checks+=@([pscustomobject]@{assertion='Missing linked target definition rejects with 1506';readerStage=$stage+1;passed=$true})}
  }
  $totalNamed+=$named;$totalUnsupported+=$unsupported;++$ordinal
 }
 if($totalNamed -ne 5696 -or $totalUnsupported -ne 16){throw 'Retained relocation diagnostic census changed'}
 foreach($inputIdentity in $inputs){if((Get-ArtifactIdentity $inputIdentity.path).sha256 -cne $inputIdentity.sha256){throw ('Input changed during verification: '+$inputIdentity.path)}}
 $success=$true
}catch{$failure=$_.Exception.Message}
[pscustomobject]@{success=$success;failure=$failure;acceptedSelection=$reader.acceptedSelection;inputs=$inputs;checks=$checks;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Named code-relocation target anchors only. Anonymous section targets explicitly reject. No relocation value evaluation, instruction comparison, pointer-cell/import/TLS semantics, stack/debug validation or publication.'}|ConvertTo-Json -Depth 18|Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Evidence: $run/report.json"
if(-not $success){throw $failure}
