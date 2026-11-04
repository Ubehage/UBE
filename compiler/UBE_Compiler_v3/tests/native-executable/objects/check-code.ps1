param([Parameter(Mandatory=$true)][string]$ReaderReport,[Parameter(Mandatory=$true)][string]$BindingReport)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))){$root=Split-Path $root -Parent;if(-not $root){throw 'Repository root missing'}}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$reader=Get-Content -LiteralPath $ReaderReport -Raw|ConvertFrom-Json;$binding=Get-Content -LiteralPath $BindingReport -Raw|ConvertFrom-Json
if(-not $reader.success -or -not $binding.success -or $reader.acceptedSelection.compiler.sha256 -cne $binding.acceptedSelection.compiler.sha256){throw 'Passing reports from the same bootstrap tools required'}
$run=Join-Path $root ('bootstrap/out/native-code/'+[guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($run)
$inputs=@();$checks=@();$commands=@();$success=$false;$failure=$null
foreach($path in @($ReaderReport,$BindingReport,$PSCommandPath,(Join-Path $root 'bootstrap/tools/verification.ps1'))){$inputs+=Get-ArtifactIdentity $path}
function Retain($Id){$actual=Get-ArtifactIdentity $Id.path;if($actual.sha256 -cne $Id.sha256){throw ('Retained input changed: '+$Id.path)};$script:inputs+=@($actual);return $actual.path}
function Run([string]$File,[string[]]$Arguments,[string]$Rejection=''){
 $r=Invoke-BoundedProcess $File $Arguments $run 30;$script:commands+=@($r)
 if($r.timedOut){throw ($r|ConvertTo-Json -Compress)}
 if($Rejection){if($r.exit -ne 1 -or $r.stderr -notmatch $Rejection){throw ('Code control was not rejected: '+($r|ConvertTo-Json -Compress))}}
 elseif($r.exit -ne 0 -or $r.stderr -cne ''){throw ($r|ConvertTo-Json -Compress)}
 return $r.stdout
}
# Independent SDK file/section/symbol offsets; no production-reader outputs.
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
function Section([byte[]]$Bytes,$Inventory,[int]$Index){
 $at=$Inventory.sections+40*$Index
 return [pscustomobject]@{index=$Index;virtual=[long][BitConverter]::ToUInt32($Bytes,$at+8);rva=[long][BitConverter]::ToUInt32($Bytes,$at+12);size=[int][BitConverter]::ToUInt32($Bytes,$at+16);first=[int][BitConverter]::ToUInt32($Bytes,$at+20);relocations=[int][BitConverter]::ToUInt32($Bytes,$at+24);count=[int][BitConverter]::ToUInt16($Bytes,$at+32);flags=[long][BitConverter]::ToUInt32($Bytes,$at+36)}
}
try {
 foreach($inputIdentity in $reader.inputs){$null=Retain $inputIdentity}
 $null=Retain $reader.acceptedSelection.clang;$unicode=Retain $reader.acceptedSelection.unicodeRuntime
 $driver=Join-Path $PSScriptRoot 'code-files.c';$inputs+=Get-ArtifactIdentity $driver;[IO.File]::Copy($driver,(Join-Path $run 'code-files.c'))
 foreach($name in @('probe.c','file-output-observed.c')){$ids=@($reader.artifacts|Where-Object {(Split-Path $_.path -Leaf) -ceq $name});if($ids.Count -ne 1){throw 'Retained adapter source missing'};$path=Retain $ids[0];[IO.File]::Copy($path,(Join-Path $run $name))}
 $probePath=Join-Path $run 'probe.c';$probeText=[IO.File]::ReadAllText($probePath);$signature='int main(int argc,char** argv)'
 if(([regex]::Matches($probeText,[regex]::Escape($signature))).Count -ne 1){throw 'Retained probe entry missing'}
 [IO.File]::WriteAllText($probePath,$probeText.Replace($signature,'int retained_object_probe_main(int argc,char** argv)'),[Text.UTF8Encoding]::new($false))
 $probes=@()
 foreach($stage in 0..1){
  $ids=@($reader.artifacts|Where-Object {(Split-Path $_.path -Leaf) -ceq ('stage'+$stage+'-adapter.ll')});if($ids.Count -ne 1){throw 'Reader LLVM missing'};$ir=Retain $ids[0]
  $exe=Join-Path $run ('stage'+$stage+'-code.exe');$null=Run $reader.acceptedSelection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-Wall','-Wextra','-Werror','-I',$root,'-I',$PSScriptRoot,$ir,(Join-Path $run 'code-files.c'),$unicode,'-o',$exe);$probes+=$exe
 }
 $pairs=[ordered]@{};foreach($command in $binding.commands){if($command.arguments[0] -ceq '--bound-extents' -and $command.exit -eq 0){$pairs[$command.arguments[1]]=@($command.arguments[2],$command.arguments[3])}}
 if($pairs.Count -ne 144){throw 'Expected all 144 generated objects'}
 $ordinal=0;$totalBytes=0;$totalContributions=0;$ownership=[ordered]@{}
 foreach($path in $pairs.Keys){
  $ids=@($binding.inputs|Where-Object path -EQ $path);$iids=@($binding.inputs|Where-Object path -EQ $pairs[$path][0]);$eids=@($binding.inputs|Where-Object path -EQ $pairs[$path][1]);if($ids.Count -lt 1 -or $iids.Count -lt 1 -or $eids.Count -lt 1){throw 'Qualified frozen association missing'}
  $object=Retain $ids[0];$image=Retain $iids[0];$frozen=Retain $eids[0];$ob=[IO.File]::ReadAllBytes($object);$ib=[IO.File]::ReadAllBytes($image);$eb=[IO.File]::ReadAllBytes($frozen);$oi=Inventory $ob $false;$ii=Inventory $ib $true
  $frozenCount=[BitConverter]::ToInt32($eb,0);$names=8+40*$frozenCount;$selected=@{}
  for($n=0;$n -lt $frozenCount;++$n){$at=8+40*$n;if([BitConverter]::ToInt32($eb,$at+28) -ne 0){continue};$name=[BitConverter]::ToString($eb,$names+[BitConverter]::ToInt32($eb,$at),[BitConverter]::ToInt32($eb,$at+4));$selected[$name]=$n}
  $definitions=@{};foreach($symbol in $ii.rows.Values){if($symbol.section -gt 0 -and $symbol.storage -in @(2,3)){if(-not $definitions.ContainsKey($symbol.name)){$definitions[$symbol.name]=@()};$definitions[$symbol.name]+=@($symbol)}}
  $imageSections=@();for($si=0;$si -lt $ii.sectionCount;++$si){$imageSections+=Section $ib $ii $si}
  $rows=@();$contentBytes=0;$control=$null
  for($si=0;$si -lt $oi.sectionCount;++$si){
   $os=Section $ob $oi $si;if(($os.flags -band 0x20000000) -eq 0 -or $os.size -eq 0){continue}
   $anchors=@($oi.rows.Values|Where-Object {$_.section -eq $si+1 -and $_.type -eq 32 -and $_.storage -in @(2,3) -and $selected.ContainsKey($_.name)}|Sort-Object {$selected[$_.name]})
   if($anchors.Count -eq 0){throw 'Nonempty code has no frozen expected anchor'};$bases=@();$firstImageSymbol=-1
   foreach($symbol in $anchors){$matches=@($definitions[$symbol.name]);if($matches.Count -ne 1 -or $matches[0].type -ne 32){throw 'Independent frozen image anchor missing/ambiguous'};$match=$matches[0];$is=$imageSections[$match.section-1];$bases+=($is.rva+$match.value-$symbol.value);if($firstImageSymbol -lt 0){$firstImageSymbol=$match.index}}
   $bases=@($bases|Sort-Object -Unique);if($bases.Count -ne 1){throw 'Independent frozen anchor placements disagree'};$base=[long]$bases[0]
   $sites=@($imageSections|Where-Object {($_.flags -band 0x20000000) -ne 0 -and $base -ge $_.rva -and $base+$os.size -le $_.rva+[Math]::Min($_.size,$_.virtual)})
   if($sites.Count -ne 1){throw 'Independent contribution location is not unique'};$is=$sites[0];$offset=$base-$is.rva;$imageFirst=$is.first+$offset
   $rows+=@([pscustomobject]@{si=$si;objectFields=@(-1,$si,$os.first,$os.size,$os.size,32);objectWide=@([long]0,[long]0,[long]0,$os.flags);imageFields=@(-1,$is.index,$imageFirst,$os.size,$os.size,32);imageWide=@($offset,$base,($ii.base+$base),$is.flags)})
   $contentBytes+=$os.size
   if(-not $control){
    if($os.count -lt 2 -or ($os.flags -band 0x01000000) -ne 0){throw 'Expected at least two ordinary code relocations for controls'}
    $fields=@();for($ri=0;$ri -lt $os.count;++$ri){$at=$os.relocations+10*$ri;$kind=[int][BitConverter]::ToUInt16($ob,$at+8);if($kind -notin @(4,11)){throw 'Unexpected retained code relocation kind'};$fields+=([int][BitConverter]::ToUInt32($ob,$at))}
    $unchanged=0;while(@($fields|Where-Object {$unchanged -ge $_ -and $unchanged -lt $_+4}).Count){++$unchanged};if($unchanged -ge $os.size){throw 'No unchanged byte for control'}
    $head=[int][BitConverter]::ToUInt32($ib,60)+4;$imageSymbolTable=[int][BitConverter]::ToUInt32($ib,$head+8)
    $control=[pscustomobject]@{unchanged=$imageFirst+$unchanged;linked=$imageFirst+$fields[0];addend=$os.first+$fields[0];secondRelocation=$os.relocations+10;overlap=$fields[0]+1;imageSymbol=$imageSymbolTable+18*$firstImageSymbol+8}
   }
  }
  $stream=[IO.MemoryStream]::new();$writer=[IO.BinaryWriter]::new($stream);$writer.Write([int]$rows.Count)
  foreach($row in $rows){$writer.Write([int]$row.si);foreach($n in $row.objectFields){$writer.Write([int]$n)};foreach($n in $row.objectWide){$writer.Write([long]$n)};foreach($n in $row.imageFields){$writer.Write([int]$n)};foreach($n in $row.imageWide){$writer.Write([long]$n)}}
  $writer.Flush();$expectedBytes=$stream.ToArray();$writer.Dispose();$stream.Dispose();$expected=Join-Path $run ($ordinal.ToString()+'-expected.bin');[IO.File]::WriteAllBytes($expected,$expectedBytes)
  $exports=@()
  foreach($stage in 0..1){
   $export=Join-Path $run ($ordinal.ToString()+'-stage'+$stage+'-owned.bin');$exports+=$export
   $actual=Run $probes[$stage] @($object,$image,$frozen,$expected,$export);$m=[regex]::Match($actual,'^PASS (\d+) code contributions; (\d+) content bytes; (\d+) inspection bytes; (\d+) events\n$')
   if(-not $m.Success -or [int]$m.Groups[1].Value -ne $rows.Count -or [long]$m.Groups[2].Value -ne $contentBytes){throw 'Complete code comparison output differs'}
   $checks+=@([pscustomobject]@{assertion='Complete code content and placement match frozen expected anchors and independent section oracle';readerStage=$stage+1;input=$ids[0];image=$iids[0];frozen=$eids[0];contributions=$rows.Count;contentBytes=$contentBytes;inspectionBytes=[long]$m.Groups[3].Value;inspectionEvents=[long]$m.Groups[4].Value;passed=$true})
  }
  if(-not $ownership.Contains($image)){$ownership[$image]=@()};$ownership[$image]+=@([pscustomobject]@{exports=$exports;rows=$rows})
  if($rows.Count){foreach($mutation in @('anchor-mismatch','missing-coverage','spurious-coverage')){foreach($stage in 0..1){$pattern='code coverage code=1506';if($mutation -ceq 'anchor-mismatch'){$pattern='code anchor section=\d+ code=1506'};$null=Run $probes[$stage] @($object,$image,$frozen,$expected,('--'+$mutation)) $pattern;$checks+=@([pscustomobject]@{assertion=('Production code ownership refusal: '+$mutation);readerStage=$stage+1;passed=$true})}}}
  if($control){foreach($mutation in @('unchanged','linked','addend','anchor','overlap')){
   $op=$object;$ip=$image
   if($mutation -in @('addend','overlap')){$wrong=[byte[]]$ob.Clone();if($mutation -eq 'addend'){$wrong[$control.addend]=[byte]($wrong[$control.addend] -bxor 1)}else{[BitConverter]::GetBytes([int]$control.overlap).CopyTo($wrong,$control.secondRelocation)};$op=Join-Path $run ($ordinal.ToString()+'-'+$mutation+'.o');[IO.File]::WriteAllBytes($op,$wrong)}
   else{$wrong=[byte[]]$ib.Clone();if($mutation -eq 'anchor'){[BitConverter]::GetBytes([uint32]([BitConverter]::ToUInt32($wrong,$control.imageSymbol)+16)).CopyTo($wrong,$control.imageSymbol)}else{$at=$control.unchanged;if($mutation -eq 'linked'){$at=$control.linked};$wrong[$at]=[byte]($wrong[$at] -bxor 1)};$ip=Join-Path $run ($ordinal.ToString()+'-'+$mutation+'.exe');[IO.File]::WriteAllBytes($ip,$wrong)}
   foreach($stage in 0..1){$null=Run $probes[$stage] @($op,$ip,$frozen,$expected) 'code contribution section=\d+ code=1506';$checks+=@([pscustomobject]@{assertion=('Code mutation rejected: '+$mutation);readerStage=$stage+1;passed=$true})}
  }}
  $totalBytes+=$contentBytes;$totalContributions+=$rows.Count;++$ordinal
 }
 if($totalBytes -ne 146088 -or $totalContributions -ne 112){throw 'Retained code census changed'}
 if($ownership.Count -ne 16){throw 'Expected all sixteen independent images'};$imageOrdinal=0
 foreach($image in $ownership.Keys){
  $units=$ownership[$image];$order=@();$recordCount=0;foreach($unit in $units){foreach($row in $unit.rows){$order+=@([pscustomobject]@{index=$recordCount;rva=$row.imageWide[1]});++$recordCount}}
  if($recordCount -ne 7){throw 'Expected seven code contributions per image'};$ordered=@($order|Sort-Object rva,index)
  foreach($stage in 0..1){
   $stream=[IO.MemoryStream]::new();$writer=[IO.BinaryWriter]::new($stream);$writer.Write([int]$recordCount);$writer.Write([int]3)
   foreach($unit in $units){$records=[IO.File]::ReadAllBytes($unit.exports[$stage]);if([BitConverter]::ToInt32($records,0) -ne $unit.rows.Count -or $records.Length -ne 4+128*$unit.rows.Count){throw 'Exported contribution transport differs'};$writer.Write($records,4,$records.Length-4)}
   foreach($entry in $ordered){$writer.Write([int]$entry.index)};$writer.Flush();$inputPath=Join-Path $run ('image'+$imageOrdinal+'-stage'+$stage+'-ownership.bin');[IO.File]::WriteAllBytes($inputPath,$stream.ToArray());$writer.Dispose();$stream.Dispose()
   $actual=Run $probes[$stage] @('--ownership',$inputPath,'0');$m=[regex]::Match($actual,'^PASS (\d+) owned code contributions; (\d+) peak bytes; (\d+) events\n$');if(-not $m.Success -or [int]$m.Groups[1].Value -ne $recordCount -or [long]$m.Groups[2].Value -ne 25*$recordCount){throw 'Complete-image ownership comparison differs'}
   $checks+=@([pscustomobject]@{assertion='Complete image code ownership is unique and nonoverlapping, with independent RVA order';readerStage=$stage+1;image=$image;contributions=$recordCount;peakBytes=[long]$m.Groups[2].Value;events=[long]$m.Groups[3].Value;passed=$true})
   foreach($defect in 1..3){$null=Run $probes[$stage] @('--ownership',$inputPath,$defect.ToString()) 'code ownership code=1506';$checks+=@([pscustomobject]@{assertion=('Duplicate owner or overlapping image contribution rejected: '+$defect);readerStage=$stage+1;image=$image;passed=$true})}
  };++$imageOrdinal
 }
 foreach($inputIdentity in $inputs){if((Get-ArtifactIdentity $inputIdentity.path).sha256 -cne $inputIdentity.sha256){throw ('Input changed during verification: '+$inputIdentity.path)}}
 $success=$true
}catch{$failure=$_.Exception.Message}
[pscustomobject]@{success=$success;failure=$failure;acceptedSelection=$reader.acceptedSelection;inputs=$inputs;checks=$checks;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Whole ordinary code contribution placement and complete relocation/unchanged-byte comparison with frozen retained definitions, production anchor consistency/section coverage, and complete retained-image contribution uniqueness/file/RVA nonoverlap with independent RVA order. No instruction/effective-address safety, pointer-cell/import/TLS, unwind/stack/debug or builder/publication qualification.'}|ConvertTo-Json -Depth 18|Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Evidence: $run/report.json"
if(-not $success){throw $failure}
