param([Parameter(Mandatory=$true)][string]$ReaderReport,[Parameter(Mandatory=$true)][string]$BindingReport,[string]$InstructionReport='',[switch]$GeneratedTargets,[switch]$ReferencePointers,[switch]$ImportTargets,[switch]$ThreadStorage)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
if($ThreadStorage){$ImportTargets=$true}
if($ImportTargets){$ReferencePointers=$true}
if($ReferencePointers){$GeneratedTargets=$true}
$totalReferences=0;$totalImports=0;$totalThreadIndexes=0;$totalThreadMembers=0
$root=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))){$root=Split-Path $root -Parent;if(-not $root){throw 'Repository root missing'}}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$reader=Get-Content -LiteralPath $ReaderReport -Raw|ConvertFrom-Json;$binding=Get-Content -LiteralPath $BindingReport -Raw|ConvertFrom-Json
if(-not $reader.success -or -not $binding.success -or $reader.acceptedSelection.compiler.sha256 -cne $binding.acceptedSelection.compiler.sha256){throw 'Passing reports from the same bootstrap tools required'}
$run=Join-Path $root ('bootstrap/out/native-fixups/'+[guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($run)
$inputs=@();$checks=@();$commands=@();$success=$false;$failure=$null
foreach($path in @($ReaderReport,$BindingReport,$PSCommandPath,(Join-Path $root 'bootstrap/tools/verification.ps1'))){$inputs+=Get-ArtifactIdentity $path}
function Retain($Id){$actual=Get-ArtifactIdentity $Id.path;if($actual.sha256 -cne $Id.sha256){throw ('Retained input changed: '+$Id.path)};$script:inputs+=@($actual);return $actual.path}
function Run([string]$File,[string[]]$Arguments,[string]$Rejection=''){
 $r=Invoke-BoundedProcess $File $Arguments $run 30;$script:commands+=@($r)
 if($r.timedOut){throw ($r|ConvertTo-Json -Compress)}
 if($Rejection){if($r.exit -ne 1 -or $r.stderr -notmatch $Rejection){throw ('Fixup control was not rejected: '+($r|ConvertTo-Json -Compress))}}
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
function ImageAnchor([byte[]]$Bytes,$Inventory,[string]$Name){
 $key=[BitConverter]::ToString([Text.Encoding]::ASCII.GetBytes($Name));$matches=@($Inventory.rows.Values|Where-Object {$_.name -ceq $key -and $_.section -gt 0 -and $_.storage -in @(2,3)});if($matches.Count -ne 1){throw ('Independent TLS anchor absent/ambiguous: '+$Name)};$match=$matches[0];$section=Section $Bytes $Inventory ($match.section-1)
 if($match.value -ge [Math]::Min($section.size,$section.virtual)){throw 'Independent TLS anchor uninitialized'};$rva=$section.rva+$match.value
 return [pscustomobject]@{symbol=[int]$match.index;section=$section;offset=$match.value;rva=$rva;address=$Inventory.base+$rva;first=$section.first+$match.value}
}
function WriteImageRange($Writer,$Anchor,[int]$Count){
 if($Count -lt 1 -or $Count -gt [Math]::Min($Anchor.section.size,$Anchor.section.virtual)-$Anchor.offset){throw 'Independent TLS range outside initialized section'}
 foreach($n in @(-1,$Anchor.section.index,$Anchor.first,$Count,$Count,0)){$Writer.Write([int]$n)};foreach($n in @($Anchor.offset,$Anchor.rva,$Anchor.address,$Anchor.section.flags)){$Writer.Write([long]$n)}
}
try {
 if($GeneratedTargets -and -not $InstructionReport){throw 'Generated owner checks require the independent instruction report'}
 $inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'target-owners.h')
 foreach($inputIdentity in $reader.inputs){$null=Retain $inputIdentity}
 $null=Retain $reader.acceptedSelection.clang;$unicode=Retain $reader.acceptedSelection.unicodeRuntime
 $driver=Join-Path $PSScriptRoot 'fixup-files.c';$inputs+=Get-ArtifactIdentity $driver;[IO.File]::Copy($driver,(Join-Path $run 'fixup-files.c'))
 foreach($name in @('probe.c','file-output-observed.c')){$ids=@($reader.artifacts|Where-Object {(Split-Path $_.path -Leaf) -ceq $name});if($ids.Count -ne 1){throw 'Retained adapter source missing'};$path=Retain $ids[0];[IO.File]::Copy($path,(Join-Path $run $name))}
 $probePath=Join-Path $run 'probe.c';$probeText=[IO.File]::ReadAllText($probePath);$signature='int main(int argc,char** argv)'
 if(([regex]::Matches($probeText,[regex]::Escape($signature))).Count -ne 1){throw 'Retained probe entry missing'}
 [IO.File]::WriteAllText($probePath,$probeText.Replace($signature,'int retained_object_probe_main(int argc,char** argv)'),[Text.UTF8Encoding]::new($false))
 $probes=@();$ownerProbes=@()
 foreach($stage in 0..1){
  $ids=@($reader.artifacts|Where-Object {(Split-Path $_.path -Leaf) -ceq ('stage'+$stage+'-adapter.ll')});if($ids.Count -ne 1){throw 'Reader LLVM missing'};$ir=Retain $ids[0]
  $exe=Join-Path $run ('stage'+$stage+'-fixups.exe');$null=Run $reader.acceptedSelection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-Wall','-Wextra','-Werror','-I',$root,'-I',$PSScriptRoot,$ir,(Join-Path $run 'fixup-files.c'),$unicode,'-o',$exe);$probes+=$exe
  if($GeneratedTargets){$driver=Join-Path $PSScriptRoot 'target-owner-files.c';if($stage -eq 0){$inputs+=Get-ArtifactIdentity $driver;[IO.File]::Copy($driver,(Join-Path $run 'target-owner-files.c'))};$ownerExe=Join-Path $run ('stage'+$stage+'-owners.exe');$null=Run $reader.acceptedSelection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-Wall','-Wextra','-Werror','-I',$root,'-I',$PSScriptRoot,$ir,(Join-Path $run 'target-owner-files.c'),$unicode,'-o',$ownerExe);$ownerProbes+=$ownerExe}
 }
 $instructionMap=@{}
 if($InstructionReport){
  $instructionReportData=Get-Content -LiteralPath $InstructionReport -Raw|ConvertFrom-Json
  if(-not $instructionReportData.success -or -not $instructionReportData.wholeCode -or $instructionReportData.acceptedSelection.compiler.sha256 -cne $reader.acceptedSelection.compiler.sha256){throw 'Passing complete instruction report from the same bootstrap required'}
  $inputs+=Get-ArtifactIdentity $InstructionReport;foreach($id in $instructionReportData.inputs){$null=Retain $id}
  foreach($command in $instructionReportData.commands){if($command.arguments[0] -ceq '--code-instructions' -and $command.exit -eq 0){$instructionMap[$command.arguments[1]]=$command.arguments[2]}}
  if($instructionMap.Count -ne 112){throw 'Complete independent instruction corpus missing'}
 }
 $pairs=[ordered]@{};foreach($command in $binding.commands){if($command.arguments[0] -ceq '--bound-extents' -and $command.exit -eq 0){$pairs[$command.arguments[1]]=$command.arguments[2]}}
 if($pairs.Count -ne 144){throw 'Expected all 144 generated objects'}
 $ownerFiles=@{};$ownerOracles=@{};$referenceFiles=@{};$referenceOracles=@{};$importFiles=@{};$importOracles=@{};$threadFiles=@{};$threadOracles=@{}
 if($GeneratedTargets){
  $producerGroups=[ordered]@{};$seenProducers=@{}
  foreach($command in $binding.commands){if($command.arguments[0] -cne '--bound-extents' -or $command.exit -ne 0 -or $seenProducers.ContainsKey($command.arguments[1])){continue};$seenProducers[$command.arguments[1]]=$true;$image=$command.arguments[2];if(-not $producerGroups.Contains($image)){$producerGroups[$image]=@()};$producerGroups[$image]+=@([pscustomobject]@{object=$command.arguments[1];frozen=$command.arguments[3]})}
  if($producerGroups.Count -ne 16){throw 'Generated owner image cohort differs'};$imageOrdinal=0
  foreach($image in $producerGroups.Keys){
   $id=@($binding.inputs|Where-Object path -EQ $image);if($id.Count -lt 1){throw 'Image identity missing'};$null=Retain $id[0];$ib=[IO.File]::ReadAllBytes($image);$ii=Inventory $ib $true;$oracle=@{};$frozenNames=@{}
   $stream=[IO.MemoryStream]::new();$writer=[IO.BinaryWriter]::new($stream);$writer.Write([int]$producerGroups[$image].Count)
   foreach($unit in $producerGroups[$image]){
    foreach($path in @($unit.object,$unit.frozen)){$id=@($binding.inputs|Where-Object path -EQ $path);if($id.Count -lt 1){throw 'Producer/frozen identity missing'};$null=Retain $id[0];$nameBytes=[Text.Encoding]::UTF8.GetBytes($path);$writer.Write([int]$nameBytes.Length);$writer.Write($nameBytes)}
    $ob=[IO.File]::ReadAllBytes($unit.object);$oi=Inventory $ob $false;$eb=[IO.File]::ReadAllBytes($unit.frozen);$n=[BitConverter]::ToInt32($eb,0);$names=8+40*$n
    for($j=0;$j -lt $n;++$j){
     $at=8+40*$j;$name=[BitConverter]::ToString($eb,$names+[BitConverter]::ToInt32($eb,$at),[BitConverter]::ToInt32($eb,$at+4));$required=[BitConverter]::ToInt32($eb,$at+24);$count=[BitConverter]::ToInt32($eb,$at+28);if($count -eq 0){$count=1}
     $original=@($oi.rows.Values|Where-Object {$_.name -ceq $name -and $_.section -gt 0 -and $_.storage -in @(2,3)});if($original.Count -eq 0){if($required){throw 'Required producer absent'};continue};if($original.Count -ne 1){throw 'Producer definition ambiguous'}
     $matches=@($ii.rows.Values|Where-Object {$_.name -ceq $name -and $_.section -gt 0 -and $_.storage -in @(2,3)});if($matches.Count -ne 1){throw 'Retained generated definition ambiguous'};$match=$matches[0];$section=Section $ib $ii ($match.section-1)
     if($match.value -gt $section.virtual-$count){throw 'Frozen extent outside image section'};$initialized=[int][Math]::Min($count,[Math]::Max(0,[Math]::Min($section.size,$section.virtual)-$match.value));$first=-1;if($initialized){$first=$section.first+$match.value};$rva=$section.rva+$match.value
     $rangeStream=[IO.MemoryStream]::new();$rangeWriter=[IO.BinaryWriter]::new($rangeStream);$rangeWriter.Write($eb,$at,40);foreach($value in @($match.index,($match.section-1),$first,$count,$initialized,$match.type)){$rangeWriter.Write([int]$value)};foreach($value in @($match.value,$rva,($ii.base+$rva),$section.flags)){$rangeWriter.Write([long]$value)};$rangeWriter.Flush();$rangeBytes=$rangeStream.ToArray();$rangeWriter.Dispose();$rangeStream.Dispose();if($oracle.ContainsKey([int]$match.index)){throw 'Duplicate generated image owner'};$oracle[[int]$match.index]=$rangeBytes;$nameCount=[BitConverter]::ToInt32($eb,$at+4);$nameBytes=[byte[]]::new($nameCount);[Buffer]::BlockCopy($eb,($names+[BitConverter]::ToInt32($eb,$at)),$nameBytes,0,$nameCount);$frozenNames[[int]$match.index]=$nameBytes
    }
   }
   if($ReferencePointers){
    $associations=@{}
    foreach($symbol in $frozenNames.Keys){$cellName=[BitConverter]::ToString([Text.Encoding]::ASCII.GetBytes('.refptr.')+$frozenNames[$symbol]);$matches=@($ii.rows.Values|Where-Object {$_.name -ceq $cellName -and $_.section -gt 0 -and $_.storage -in @(2,3)});if($matches.Count -eq 0){continue};if($matches.Count -ne 1){throw 'Reference-cell oracle name ambiguous'};$cell=$matches[0];$section=Section $ib $ii ($cell.section-1);if($cell.type -ne 0 -or $cell.value -gt [Math]::Min($section.size,$section.virtual)-8 -or ($section.flags -band [long]0xE2000020) -ne [long]0x40000000){throw 'Reference cell is not ordinary resident read-only data'};if([BitConverter]::ToInt64($ib,($section.first+$cell.value)) -ne [BitConverter]::ToInt64($oracle[$symbol],80)){throw 'Independent cell/referent value differs'};$associations[[int]$cell.index]=[pscustomobject]@{referent=[int]$symbol;name=$frozenNames[$symbol]}}
    if($associations.Count -ne 7){throw 'Reference-cell image census differs'}
    $rs=[IO.MemoryStream]::new();$rw=[IO.BinaryWriter]::new($rs);$rw.Write([int]$associations.Count);foreach($symbol in ($associations.Keys|Sort-Object)){$association=$associations[$symbol];$rw.Write([int]$symbol);$rw.Write([int]$association.referent);$rw.Write([int]$association.name.Length);$rw.Write([byte[]]$association.name)};$rw.Flush();$rp=Join-Path $run ('image-'+$imageOrdinal+'-reference-pointers.bin');[IO.File]::WriteAllBytes($rp,$rs.ToArray());$rw.Dispose();$rs.Dispose();$referenceFiles[$image]=$rp;$referenceOracles[$image]=$associations;$inputs+=Get-ArtifactIdentity $rp
   }
   if($ImportTargets){
    # Frozen platform requirements, independent of the candidate's import descriptors.
    $associations=@{};$library=[Text.Encoding]::ASCII.GetBytes('KERNEL32.dll')
    foreach($procedure in @('ExitProcess','Sleep','TerminateProcess','VirtualQuery')){
     $name=[BitConverter]::ToString([Text.Encoding]::ASCII.GetBytes('__imp_'+$procedure));$matches=@($ii.rows.Values|Where-Object {$_.name -ceq $name -and $_.section -gt 0 -and $_.storage -eq 2});if($matches.Count -ne 1){throw 'Frozen imported API anchor absent/ambiguous'};$cell=$matches[0];$section=Section $ib $ii ($cell.section-1)
     if($cell.type -ne 0 -or $cell.value -gt [Math]::Min($section.size,$section.virtual)-8 -or ($section.flags -band [long]0x62000060) -ne [long]0x40000040 -or ($section.rva+$cell.value)%8 -ne 0){throw 'Imported API anchor is not initialized resident aligned data'}
     $associations[[int]$cell.index]=[pscustomobject]@{library=$library;procedure=[Text.Encoding]::ASCII.GetBytes($procedure)}
    }
    $rs=[IO.MemoryStream]::new();$rw=[IO.BinaryWriter]::new($rs);$rw.Write([int]$associations.Count);foreach($symbol in ($associations.Keys|Sort-Object)){$association=$associations[$symbol];$rw.Write([int]$symbol);$rw.Write([int]$association.library.Length);$rw.Write([int]$association.procedure.Length);$rw.Write([byte[]]$association.library);$rw.Write([byte[]]$association.procedure)};$rw.Flush();$rp=Join-Path $run ('image-'+$imageOrdinal+'-import-targets.bin');[IO.File]::WriteAllBytes($rp,$rs.ToArray());$rw.Dispose();$rs.Dispose();$importFiles[$image]=$rp;$importOracles[$image]=$associations;$inputs+=Get-ArtifactIdentity $rp
   }
   if($ThreadStorage){
    # The expected ranges come from frozen producer extents and named CRT anchors,
    # independently of the candidate TLS directory's pointer values.
    $directory=ImageAnchor $ib $ii '_tls_used';$start=ImageAnchor $ib $ii '_tls_start';$end=ImageAnchor $ib $ii '_tls_end';$index=ImageAnchor $ib $ii '_tls_index';$callbacks=ImageAnchor $ib $ii '__xl_c';$callbackNext=ImageAnchor $ib $ii '__xl_d';$callbackEnd=ImageAnchor $ib $ii '__xl_z';$initialize=ImageAnchor $ib $ii '__dyn_tls_init';$destroy=ImageAnchor $ib $ii '__dyn_tls_dtor'
    $members=@{};$templateBytes=0
    foreach($symbol in $oracle.Keys){$range=$oracle[$symbol];if([BitConverter]::ToInt32($range,20) -notin @(12,22)){continue};$members[[int]$symbol]=$true;$offset=[BitConverter]::ToInt64($range,64);$count=[BitConverter]::ToInt32($range,52);if([BitConverter]::ToInt32($range,44) -ne $start.section.index -or [BitConverter]::ToInt64($range,72) -ne $start.rva+$offset){throw 'Frozen TLS definition has a different template origin'};$templateBytes=[Math]::Max($templateBytes,$offset+$count)}
    if($members.Count -ne 2 -or $templateBytes -ne 800 -or $start.offset -ne 0 -or $end.rva -ne $start.rva+$templateBytes){throw 'Frozen TLS template extent differs'}
    if($callbackNext.rva -ne $callbacks.rva+8 -or $callbackEnd.rva -ne $callbacks.rva+16 -or [BitConverter]::ToInt64($ib,$callbacks.first) -ne $initialize.address -or [BitConverter]::ToInt64($ib,$callbackNext.first) -ne $destroy.address -or [BitConverter]::ToInt64($ib,$callbackEnd.first) -ne 0 -or [BitConverter]::ToUInt32($ib,$index.first) -ne 0){throw 'Independent CRT TLS initializer/index bytes differ'}
    $ts=[IO.MemoryStream]::new();$tw=[IO.BinaryWriter]::new($ts);WriteImageRange $tw $directory 40;WriteImageRange $tw $start ([int]$templateBytes);WriteImageRange $tw $index 4;WriteImageRange $tw $callbacks 24;$tw.Write([int]8);$tw.Write([int]1);$tw.Write([int]$index.symbol);$tw.Flush();$tp=Join-Path $run ('image-'+$imageOrdinal+'-thread-storage.bin');[IO.File]::WriteAllBytes($tp,$ts.ToArray());$tw.Dispose();$ts.Dispose();$threadFiles[$image]=$tp;$threadOracles[$image]=[pscustomobject]@{index=[int]$index.symbol;members=$members};$inputs+=Get-ArtifactIdentity $tp
   }
   $writer.Flush();$manifest=Join-Path $run ('image-'+$imageOrdinal+'-producers.bin');[IO.File]::WriteAllBytes($manifest,$stream.ToArray());$writer.Dispose();$stream.Dispose();$files=@()
   foreach($stage in 0..1){
    $owners=Join-Path $run ('image-'+$imageOrdinal+'-stage'+$stage+'-owners.bin');$actual=Run $ownerProbes[$stage] @($image,$manifest,$owners);if($actual -cne ('PASS '+$oracle.Count+' frozen generated owners'+[char]10)){throw 'Generated owner binding count differs'};$bytes=[IO.File]::ReadAllBytes($owners);$count=[BitConverter]::ToInt32($bytes,0);if($count -ne $oracle.Count -or $bytes.Length -ne 4+160*$count){throw 'Generated owner transport differs'};$seen=@{}
    for($i=0;$i -lt $count;++$i){$at=4+160*$i;$symbol=[BitConverter]::ToInt32($bytes,$at+104);if($seen.ContainsKey($symbol) -or -not $oracle.ContainsKey($symbol) -or [BitConverter]::ToInt32($bytes,$at+40) -ne 1){throw 'Generated owner identity differs'};$seen[$symbol]=$true;$wanted=$oracle[$symbol];if([BitConverter]::ToString($bytes,$at,40) -cne [BitConverter]::ToString($wanted,0,40) -or [BitConverter]::ToString($bytes,$at+104,56) -cne [BitConverter]::ToString($wanted,40,56)){throw 'Generated owner range differs from independent oracle'}}
    $files+=$owners;$inputs+=Get-ArtifactIdentity $owners;$checks+=@([pscustomobject]@{assertion='Producer-bound frozen definitions match independent complete image ranges';readerStage=$stage+1;owners=$count;image=$image;passed=$true})
   }
   $ownerFiles[$image]=$files;$ownerOracles[$image]=$oracle;++$imageOrdinal
  }
 }
 $ordinal=0;$totalFields=0;$totalGenerated=0;$nonempty=0
 foreach($path in $pairs.Keys){
  $ids=@($binding.inputs|Where-Object path -EQ $path);$iids=@($binding.inputs|Where-Object path -EQ $pairs[$path]);if($ids.Count -lt 1 -or $iids.Count -lt 1){throw 'Qualified association missing'}
  $object=Retain $ids[0];$image=Retain $iids[0];$ob=[IO.File]::ReadAllBytes($object);$ib=[IO.File]::ReadAllBytes($image);$oi=Inventory $ob $false;$ii=Inventory $ib $true
  $definitions=@{};foreach($symbol in $ii.rows.Values){if($symbol.section -gt 0 -and $symbol.storage -in @(2,3)){if(-not $definitions.ContainsKey($symbol.name)){$definitions[$symbol.name]=@()};$definitions[$symbol.name]+=@($symbol)}}
  $imageSections=@();for($si=0;$si -lt $ii.sectionCount;++$si){$imageSections+=Section $ib $ii $si}
  $instructionRows=@()
  if($InstructionReport -and $instructionMap.ContainsKey($path)){
   $idsForOracle=@($instructionReportData.artifacts|Where-Object path -EQ $instructionMap[$path]);if($idsForOracle.Count -ne 1){throw 'Independent instruction oracle missing'};$instructionOracle=Retain $idsForOracle[0];$data=[IO.File]::ReadAllBytes($instructionOracle);$n=[BitConverter]::ToInt32($data,0)
   if($n -lt 1 -or $data.Length -ne 4+24*$n){throw 'Independent instruction transport differs'}
   for($i=0;$i -lt $n;++$i){$instructionRows+=@([pscustomobject]@{first=[BitConverter]::ToInt32($data,4+24*$i);length=[BitConverter]::ToInt32($data,8+24*$i)})}
  }
  $targets=@{};$rows=@();$signedRows=@();$instructionCursor=0
  for($si=0;$si -lt $oi.sectionCount;++$si){
   $os=Section $ob $oi $si;if(($os.flags -band 0x20000000) -eq 0 -or $os.count -eq 0){continue};if(($os.flags -band 0x01000000) -ne 0){throw 'Unexpected extended count in generated code'}
   # Test-owned placement: every corresponding function anchor must agree on
   # the section base. No linked operand participates in this calculation.
   $bases=@();foreach($symbol in $oi.rows.Values){if($symbol.section -eq $si+1 -and $symbol.type -eq 32 -and $symbol.storage -in @(2,3)){
    $matches=@($definitions[$symbol.name]);if($matches.Count -ne 1 -or $matches[0].type -ne 32){throw 'Independent function anchor missing/ambiguous'};$match=$matches[0];$is=$imageSections[$match.section-1];$bases+=($is.rva+$match.value-$symbol.value)
   }}
   $bases=@($bases|Sort-Object -Unique);if($bases.Count -ne 1){throw 'Code anchors disagree on contribution placement'};$base=[long]$bases[0]
   $sites=@($imageSections|Where-Object {($_.flags -band 0x20000000) -ne 0 -and $base -ge $_.rva -and $base+$os.size -le $_.rva+[Math]::Min($_.size,$_.virtual)})
   if($sites.Count -ne 1){throw 'Code placement is outside a unique initialized image section'};$siteSection=$sites[0]
   for($ri=0;$ri -lt $os.count;++$ri){
    $at=$os.relocations+10*$ri;$offset=[long][BitConverter]::ToUInt32($ob,$at);$target=[int][BitConverter]::ToUInt32($ob,$at+4);$kind=[int][BitConverter]::ToUInt16($ob,$at+8)
    if($kind -notin @(4,11) -or $offset -gt $os.size-4){throw 'Unexpected generated relocation kind/span'}
    if(-not $targets.ContainsKey($target)){
     $symbol=$oi.rows[$target];if(-not $symbol){throw 'Independent target is not primary'}
     if($symbol.aux -eq 0){
      $matches=@($definitions[$symbol.name]);if($matches.Count -ne 1){throw 'Independent image target missing/ambiguous'};$match=$matches[0];$is=$imageSections[$match.section-1]
      if($match.value -ge $is.virtual){throw 'Independent target outside logical section'};$first=-1;$initialized=0
      if($is.first -gt 0 -and $match.value -lt [Math]::Min($is.size,$is.virtual)){$first=$is.first+$match.value;$initialized=1}
      $rva=$is.rva+$match.value;$targets[$target]=[pscustomobject]@{fields=@($match.index,$is.index,$first,1,$initialized,$match.type);wide=@($match.value,$rva,($ii.base+$rva),$is.flags)}
     }else{
      if($symbol.aux -ne 1 -or $symbol.storage -ne 3 -or $symbol.type -ne 0 -or $symbol.value -ne 0 -or $symbol.name -cne '2E-72-64-61-74-61'){throw 'Unexpected anonymous target'}
      $cs=Section $ob $oi ($symbol.section-1);$pattern=[BitConverter]::ToString($ob,$cs.first,$cs.size)
      if($cs.size -ne 31 -or $pattern -cne '6F-75-74-20-6F-66-20-73-74-61-63-6B-20-73-70-61-63-65-00-55-42-45-2E-52-75-6E-74-69-6D-65-00'){throw 'Independent constant bytes differ'}
      $hits=@();foreach($is in $imageSections){if(($is.flags -band [long]0xE2001AE0) -ne [long]0x40000040){continue};$limit=[Math]::Min($is.size,$is.virtual)-$cs.size
       for($n=0;$n -le $limit;++$n){if([BitConverter]::ToString($ib,$is.first+$n,$cs.size) -ceq $pattern){$rva=$is.rva+$n;$hits+=@([pscustomobject]@{fields=@(-1,$is.index,($is.first+$n),$cs.size,$cs.size,0);wide=@([long]$n,$rva,($ii.base+$rva),$is.flags)})}}
      };if($hits.Count -ne 1){throw 'Independent constant placement is not unique'};$targets[$target]=$hits[0]
     }
    }
    if($InstructionReport){
     while($instructionCursor+1 -lt $instructionRows.Count -and $instructionRows[$instructionCursor+1].first -le $os.first+$offset){++$instructionCursor}
     if($instructionRows.Count -eq 0){throw 'Instruction oracle missing for relocated code'};$ins=$instructionRows[$instructionCursor];$field=$os.first+$offset-$ins.first
     if($field -lt 1 -or $field+4 -gt $ins.length){throw 'Relocation field crosses independent instruction'}
     $addend=[long][BitConverter]::ToInt32($ob,$os.first+$offset);$position=$targets[$target].wide[0]+$addend
     if($kind -eq 4){$position=$targets[$target].wide[1]+$addend+$ins.length-$field-4}
     $signedRows+=@([pscustomobject]@{first=$ins.first;length=$ins.length;offset=[long]($ins.first-$os.first);imageFirst=[int]($siteSection.first+$base+$offset-$siteSection.rva-$field);rva=[long]($base+$offset-$field);position=[long]$position;field=$field})
    }
    $rows+=@([pscustomobject]@{si=$si;ri=$ri;kind=$kind;objectFirst=$os.first+$offset;imageFirst=$siteSection.first+$base+$offset-$siteSection.rva;site=$base+$offset;target=$targets[$target]})
   }
  }
  $stream=[IO.MemoryStream]::new();$writer=[IO.BinaryWriter]::new($stream);$writer.Write([int]$rows.Count)
  foreach($row in $rows){foreach($n in @($row.si,$row.ri,$row.imageFirst)){$writer.Write([int]$n)};$writer.Write([long]$row.site);foreach($n in $row.target.fields){$writer.Write([int]$n)};foreach($n in $row.target.wide){$writer.Write([long]$n)}}
  $writer.Flush();$expectedBytes=$stream.ToArray();$writer.Dispose();$stream.Dispose();$expected=Join-Path $run ($ordinal.ToString()+'-expected.bin');[IO.File]::WriteAllBytes($expected,$expectedBytes)
  $signedExpected='';$signedBytes=$null
  if($InstructionReport){
   $stream=[IO.MemoryStream]::new();$writer=[IO.BinaryWriter]::new($stream);$writer.Write([int]$signedRows.Count)
   foreach($row in $signedRows){$writer.Write([int]$row.first);$writer.Write([int]$row.length);$writer.Write([long]$row.offset);$writer.Write([int]$row.imageFirst);$writer.Write([long]$row.rva);$writer.Write([long]$row.position)}
   $writer.Flush();$signedBytes=$stream.ToArray();$writer.Dispose();$stream.Dispose();$signedExpected=Join-Path $run ($ordinal.ToString()+'-targets.bin');[IO.File]::WriteAllBytes($signedExpected,$signedBytes)
  }
  $generated=0;if($GeneratedTargets){foreach($row in $rows){if($ownerOracles[$image].ContainsKey([int]$row.target.fields[0])){++$generated}};$totalGenerated+=$generated}
  $references=0;if($ReferencePointers){foreach($row in $rows){if($referenceOracles[$image].ContainsKey([int]$row.target.fields[0])){++$references}};$totalReferences+=$references}
  $imports=0;if($ImportTargets){foreach($row in $rows){if($importOracles[$image].ContainsKey([int]$row.target.fields[0])){++$imports}};$totalImports+=$imports}
  $threadIndexes=0;$threadMembers=0;if($ThreadStorage){foreach($row in $rows){$symbol=[int]$row.target.fields[0];if($symbol -eq $threadOracles[$image].index){++$threadIndexes};if($threadOracles[$image].members.ContainsKey($symbol)){++$threadMembers}};$totalThreadIndexes+=$threadIndexes;$totalThreadMembers+=$threadMembers}
  $comparisonArguments=@($object,$image,$expected);if($InstructionReport){$comparisonArguments+=@($signedExpected)}
  foreach($stage in 0..1){$stageArguments=$comparisonArguments;if($GeneratedTargets){$stageArguments+=@($ownerFiles[$image][$stage],'0')};if($ReferencePointers){$stageArguments+=@($referenceFiles[$image])};if($ImportTargets){$stageArguments+=@($importFiles[$image])};if($ThreadStorage){$stageArguments+=@($threadFiles[$image])};$actual=Run $probes[$stage] $stageArguments;if($actual -cne ("PASS $($rows.Count) relocated fields"+$(if($InstructionReport){"; $($rows.Count) signed instruction targets"}else{''})+$(if($GeneratedTargets){"; $generated generated owners"}else{''})+$(if($ReferencePointers){"; $references reference pointers"}else{''})+$(if($ImportTargets){"; $imports import targets"}else{''})+$(if($ThreadStorage){"; $threadIndexes TLS indexes; $threadMembers TLS members"}else{''})+[char]10)){throw 'Relocated field output differs'};$checks+=@([pscustomobject]@{assertion='Relocation fields agree with resolved targets and independent site placement';signedInstructionTargets=[bool]$InstructionReport;generatedOwners=$generated;referencePointers=$references;importTargets=$imports;threadIndexes=$threadIndexes;threadMembers=$threadMembers;readerStage=$stage+1;input=$ids[0];image=$iids[0];fields=$rows.Count;passed=$true})}
  if($rows.Count -gt 0){
   ++$nonempty;$rowIndex=0;while($rowIndex -lt $rows.Count -and $rows[$rowIndex].kind -ne 4){++$rowIndex};if($rowIndex -eq $rows.Count){throw 'No relative relocation for site control'};$row=$rows[$rowIndex]
   if($InstructionReport){
    $signed=$signedRows[$rowIndex]
    if([BitConverter]::ToInt32($ib,$signed.imageFirst+$signed.field+1) -eq [BitConverter]::ToInt32($ib,$signed.imageFirst+$signed.field)){throw 'Shifted linked-field control is not discriminating'}
    foreach($mutation in @('image-first','image-rva','instruction-offset','result')){
     $wrong=[byte[]]$signedBytes.Clone();$slot=4+36*$rowIndex;$pattern='instruction target section=\d+ index=\d+ code=1506'
     if($mutation -eq 'image-first'){[BitConverter]::GetBytes([int]($signed.imageFirst+1)).CopyTo($wrong,$slot+16)}
     if($mutation -eq 'image-rva'){[BitConverter]::GetBytes([long]($signed.rva+1)).CopyTo($wrong,$slot+20)}
     if($mutation -eq 'instruction-offset'){[BitConverter]::GetBytes([long]($signed.offset+1)).CopyTo($wrong,$slot+8)}
     if($mutation -eq 'result'){[BitConverter]::GetBytes([long]($signed.position -bxor 1)).CopyTo($wrong,$slot+28);$pattern='instruction target mismatch section=\d+ index=\d+'}
     $wrongTargets=Join-Path $run ($ordinal.ToString()+'-target-'+$mutation+'.bin');[IO.File]::WriteAllBytes($wrongTargets,$wrong)
     foreach($stage in 0..1){$null=Run $probes[$stage] @($object,$image,$expected,$wrongTargets) $pattern;$checks+=@([pscustomobject]@{assertion=('Signed instruction target mutation rejected: '+$mutation);readerStage=$stage+1;passed=$true})}
    }
   }
   if($GeneratedTargets){if($generated -lt 1){throw 'Nonempty code has no generated-target controls'};foreach($defect in 1..4){$code=1506;if($defect -eq 4){$code=1509};foreach($stage in 0..1){$null=Run $probes[$stage] @($object,$image,$expected,$signedExpected,$ownerFiles[$image][$stage],([string]$defect)) ('generated target section=\d+ index=\d+ code='+$code);$checks+=@([pscustomobject]@{assertion=('Generated target owner mutation rejected: '+$defect);readerStage=$stage+1;passed=$true})}}}
   if($ReferencePointers -and $references -gt 0){foreach($defect in 5..8){foreach($stage in 0..1){$null=Run $probes[$stage] @($object,$image,$expected,$signedExpected,$ownerFiles[$image][$stage],([string]$defect),$referenceFiles[$image]) 'reference pointer section=\d+ index=\d+ code=1506';$checks+=@([pscustomobject]@{assertion=('Reference pointer mutation rejected: '+$defect);readerStage=$stage+1;passed=$true})}}}
   if($ImportTargets -and $imports -gt 0){foreach($defect in 9..12){foreach($stage in 0..1){$null=Run $probes[$stage] @($object,$image,$expected,$signedExpected,$ownerFiles[$image][$stage],([string]$defect),$referenceFiles[$image],$importFiles[$image]) 'import target section=\d+ index=\d+ code=1506';$checks+=@([pscustomobject]@{assertion=('Import target mutation rejected: '+$defect);readerStage=$stage+1;passed=$true})}}}
   if($ThreadStorage){foreach($defect in 13..16){$kind='index';$count=$threadIndexes;if($defect -ge 15){$kind='member';$count=$threadMembers};if($count -lt 1){continue};foreach($stage in 0..1){$null=Run $probes[$stage] @($object,$image,$expected,$signedExpected,$ownerFiles[$image][$stage],([string]$defect),$referenceFiles[$image],$importFiles[$image],$threadFiles[$image]) ('thread '+$kind+' section=\d+ index=\d+ code=1506');$checks+=@([pscustomobject]@{assertion=('TLS '+$kind+' mutation rejected: '+$defect);readerStage=$stage+1;passed=$true})}}}
   foreach($mutation in @('linked','addend','site')){
    $op=$object;$ip=$image;$ep=$expected
    if($mutation -eq 'linked'){$wrong=[byte[]]$ib.Clone();$wrong[$row.imageFirst]=[byte]($wrong[$row.imageFirst] -bxor 1);$ip=Join-Path $run ($ordinal.ToString()+'-linked.exe');[IO.File]::WriteAllBytes($ip,$wrong)}
    if($mutation -eq 'addend'){$wrong=[byte[]]$ob.Clone();$wrong[$row.objectFirst]=[byte]($wrong[$row.objectFirst] -bxor 1);$op=Join-Path $run ($ordinal.ToString()+'-addend.o');[IO.File]::WriteAllBytes($op,$wrong)}
    if($mutation -eq 'site'){$wrong=[byte[]]$expectedBytes.Clone();[BitConverter]::GetBytes([long]($row.site+1)).CopyTo($wrong,4+76*$rowIndex+12);$ep=Join-Path $run ($ordinal.ToString()+'-site.bin');[IO.File]::WriteAllBytes($ep,$wrong)}
    foreach($stage in 0..1){$null=Run $probes[$stage] @($op,$ip,$ep) 'relocation value section=\d+ index=\d+ code=1506';$checks+=@([pscustomobject]@{assertion=('Relocation mutation rejected: '+$mutation);readerStage=$stage+1;passed=$true})}
   }
  }
  $totalFields+=$rows.Count;++$ordinal
 }
 if($ThreadStorage -and ($totalThreadIndexes -ne 592 -or $totalThreadMembers -ne 888)){throw 'TLS index/member census differs'}
 if($ImportTargets -and $totalImports -ne 80){throw 'Import target census differs'}
 if($ReferencePointers -and $totalReferences -ne 1880){throw 'Reference pointer census differs'}
 if($GeneratedTargets -and $totalGenerated -ne 3128){throw 'Generated target census differs'}
 if($totalFields -ne 5712 -or $nonempty -ne 112){throw 'Retained relocation census changed'}
 foreach($inputIdentity in $inputs){if((Get-ArtifactIdentity $inputIdentity.path).sha256 -cne $inputIdentity.sha256){throw ('Input changed during verification: '+$inputIdentity.path)}}
 $success=$true
}catch{$failure=$_.Exception.Message}
[pscustomobject]@{success=$success;failure=$failure;acceptedSelection=$reader.acceptedSelection;inputs=$inputs;checks=$checks;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});signedInstructionTargets=[bool]$InstructionReport;generatedTargets=[bool]$GeneratedTargets;generatedReferences=$totalGenerated;referencePointers=[bool]$ReferencePointers;referenceReferences=$totalReferences;importTargets=[bool]$ImportTargets;importReferences=$totalImports;threadStorage=[bool]$ThreadStorage;threadIndexReferences=$totalThreadIndexes;threadMemberReferences=$totalThreadMembers;scope='ThreadStorage additionally compares complete TLS ranges with frozen producer and CRT-symbol geometry, checks exact loader-index reads and initialized TLS members, retaining all earlier target checks. ImportTargets additionally binds aligned eight-byte RIP import cells to the frozen KERNEL32.dll APIs, scanning all import descriptors and lookup/IAT entries with metadata isolation. ReferencePointers additionally checks readonly resident eight-byte cells against frozen referent names and VAs, with exact RIP reads and independent associations. GeneratedTargets additionally checks frozen generated function entries and data extents through producer-bound definitions. Optional instruction report adds signed linked-target correspondence using independent LLVM boundaries. Relocation encoding values with production named/constant target resolution and independent test-owned code placement. No production placement, complete byte coverage, pointer/register propagation or complete loader/CRT callback provenance, complete instruction/control-flow safety, cross-object aliases, stack/debug or publication qualification.'}|ConvertTo-Json -Depth 18|Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Evidence: $run/report.json"
if(-not $success){throw $failure}
