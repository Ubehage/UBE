param([Parameter(Mandatory=$true)][string]$ReaderReport,[Parameter(Mandatory=$true)][string]$NamedReport)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))){$root=Split-Path $root -Parent;if(-not $root){throw 'Repository root missing'}}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$reader=Get-Content -LiteralPath $ReaderReport -Raw|ConvertFrom-Json;$named=Get-Content -LiteralPath $NamedReport -Raw|ConvertFrom-Json
if(-not $reader.success -or -not $named.success -or $reader.acceptedSelection.compiler.sha256 -cne $named.acceptedSelection.compiler.sha256){throw 'Passing reports from the same bootstrap tools required'}
$run=Join-Path $root ('bootstrap/out/native-constant-bindings/'+[guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($run)
$inputs=@();$checks=@();$commands=@();$success=$false;$failure=$null
foreach($path in @($ReaderReport,$NamedReport,$PSCommandPath,(Join-Path $root 'bootstrap/tools/verification.ps1'))){$inputs+=Get-ArtifactIdentity $path}
function Retain($Id){$actual=Get-ArtifactIdentity $Id.path;if($actual.sha256 -cne $Id.sha256){throw ('Retained input changed: '+$Id.path)};$script:inputs+=@($actual);return $actual.path}
function Run([string]$File,[string[]]$Arguments,[string]$Rejection=''){
 $r=Invoke-BoundedProcess $File $Arguments $run 30;$script:commands+=@($r)
 if($r.timedOut){throw ($r|ConvertTo-Json -Compress)}
 if($Rejection){if($r.exit -ne 1 -or $r.stderr -notmatch $Rejection){throw ('Constant binding control was not rejected: '+($r|ConvertTo-Json -Compress))}}
 elseif($r.exit -ne 0 -or $r.stderr -cne ''){throw ($r|ConvertTo-Json -Compress)}
 return $r.stdout
}
try {
 foreach($inputIdentity in $reader.inputs){$null=Retain $inputIdentity}
 $probes=@();foreach($stage in 0..1){$id=@($reader.artifacts|Where-Object {(Split-Path $_.path -Leaf) -ceq ('stage'+$stage+'-probe.exe')});if($id.Count -ne 1){throw 'Reader executable missing'};$probes+=Retain $id[0]}
 $pairs=[ordered]@{};foreach($command in $named.commands){if($command.arguments[0] -ceq '--named-relocations' -and $command.exit -eq 0){$m=[regex]::Match($command.stdout,'^PASS \d+ named targets; ([1-9]\d*) unsupported targets');if($m.Success){if($m.Groups[1].Value -cne '2'){throw 'Unexpected anonymous-reference count'};$pairs[$command.arguments[1]]=$command.arguments[2]}}}
 if($pairs.Count -ne 8){throw 'Expected all eight anonymous-support objects'}
 $ordinal=0
 foreach($path in $pairs.Keys){
  $id=@($named.inputs|Where-Object path -EQ $path);$iid=@($named.inputs|Where-Object path -EQ $pairs[$path]);if($id.Count -lt 1 -or $iid.Count -lt 1){throw 'Qualified object/image association missing'}
  $object=Retain $id[0];$image=Retain $iid[0];$ob=[IO.File]::ReadAllBytes($object);$ib=[IO.File]::ReadAllBytes($image)
  # Independent SDK offsets and full byte sequences, not production chunk reads.
  $symbols=[int][BitConverter]::ToUInt32($ob,8);$symbolCount=[int][BitConverter]::ToUInt32($ob,12);$objectSections=[int][BitConverter]::ToUInt16($ob,2);$objectTable=20+[int][BitConverter]::ToUInt16($ob,16);$targets=@{}
  for($si=0;$si -lt $objectSections;++$si){$sh=$objectTable+40*$si;$flags=[long][BitConverter]::ToUInt32($ob,$sh+36);if(($flags -band 0x20000000) -eq 0){continue};$count=[int][BitConverter]::ToUInt16($ob,$sh+32);$first=[int][BitConverter]::ToUInt32($ob,$sh+24)
   for($ri=0;$ri -lt $count;++$ri){$target=[int][BitConverter]::ToUInt32($ob,$first+10*$ri+4);$at=$symbols+18*$target;if($ob[$at+17] -eq 1 -and $ob[$at+16] -eq 3){$targets[$target]=$true}}
  }
  if($targets.Count -ne 1){throw 'Independent section target selection differs'};$target=[int]@($targets.Keys)[0];$at=$symbols+18*$target;$section=[int][BitConverter]::ToInt16($ob,$at+12)-1;$sh=$objectTable+40*$section
  if($target -ge $symbolCount -or $section -lt 0 -or $section -ge $objectSections -or [BitConverter]::ToUInt32($ob,$at+8) -ne 0 -or [BitConverter]::ToUInt16($ob,$at+14) -ne 0){throw 'Unexpected section symbol'}
  $length=[int][BitConverter]::ToUInt32($ob,$sh+16);$first=[int][BitConverter]::ToUInt32($ob,$sh+20);$flags=[long][BitConverter]::ToUInt32($ob,$sh+36);$pattern=[BitConverter]::ToString($ob,$first,$length)
  if($length -ne 31 -or $pattern -cne '6F-75-74-20-6F-66-20-73-74-61-63-6B-20-73-70-61-63-65-00-55-42-45-2E-52-75-6E-74-69-6D-65-00'){throw 'Independent error constant bytes differ'}
  $head=[int][BitConverter]::ToUInt32($ib,60)+4;$imageSections=[int][BitConverter]::ToUInt16($ib,$head+2);$table=$head+20+[int][BitConverter]::ToUInt16($ib,$head+16);$base=[BitConverter]::ToInt64($ib,$head+44);$hits=@()
  for($si=0;$si -lt $imageSections;++$si){$ish=$table+40*$si;$iflags=[long][BitConverter]::ToUInt32($ib,$ish+36);if(($iflags -band [long]0xE2001AE0) -ne [long]0x40000040){continue}
   $raw=[int][BitConverter]::ToUInt32($ib,$ish+20);$initialized=[Math]::Min([int][BitConverter]::ToUInt32($ib,$ish+16),[int][BitConverter]::ToUInt32($ib,$ish+8));$rva=[long][BitConverter]::ToUInt32($ib,$ish+12)
   for($offset=0;$offset -le $initialized-$length;++$offset){if([BitConverter]::ToString($ib,$raw+$offset,$length) -ceq $pattern){$hits+=@([pscustomobject]@{section=$si;header=$ish;raw=$raw;first=$raw+$offset;offset=$offset;rva=$rva+$offset;flags=$iflags})}}
  }
  if($hits.Count -ne 1){throw 'Independent constant placement is not unique'};$hit=$hits[0]
  $stream=[IO.MemoryStream]::new();$writer=[IO.BinaryWriter]::new($stream);$writer.Write([int]1);$writer.Write([int]$target)
  foreach($n in @($target,$section,$first,$length,$length,0)){$writer.Write([int]$n)};foreach($n in @([long]0,[long]0,[long]0,$flags)){$writer.Write([long]$n)}
  foreach($n in @(-1,$hit.section,$hit.first,$length,$length,0)){$writer.Write([int]$n)};foreach($n in @($hit.offset,$hit.rva,($base+$hit.rva),$hit.flags)){$writer.Write([long]$n)}
  $writer.Flush();$expectedBytes=$stream.ToArray();$writer.Dispose();$stream.Dispose();$expected=Join-Path $run ($ordinal.ToString()+'-expected.bin');[IO.File]::WriteAllBytes($expected,$expectedBytes)
  foreach($stage in 0..1){$actual=Run $probes[$stage] @('--constant-binding',$object,$image,$expected);if($actual -cne ('PASS 1 constant contributions; 2 code references'+[char]10)){throw 'Constant binding output differs'};$checks+=@([pscustomobject]@{assertion='Complete anonymous constant span and two referenced targets match independent byte-occurrence oracle';readerStage=$stage+1;input=$id[0];image=$iid[0];bytes=$length;passed=$true})}
  foreach($mutation in @('value','duplicate','permission','auxiliary','expected')){
   $objectPath=$object;$imagePath=$image;$expectedPath=$expected;$rejection='constant binding row=0 code=1506'
   if($mutation -eq 'auxiliary'){$wrong=[byte[]]$ob.Clone();[BitConverter]::GetBytes([int]($length-1)).CopyTo($wrong,$symbols+18*($target+1));$objectPath=Join-Path $run ($ordinal.ToString()+'-auxiliary.o');[IO.File]::WriteAllBytes($objectPath,$wrong)}
   elseif($mutation -eq 'expected'){$wrong=[byte[]]$expectedBytes.Clone();[BitConverter]::GetBytes([long]($hit.rva+1)).CopyTo($wrong,96);$expectedPath=Join-Path $run ($ordinal.ToString()+'-wrong-rva.bin');[IO.File]::WriteAllBytes($expectedPath,$wrong);$rejection=[regex]::Escape('memcmp(&result.image,&expected_image,56)==0')}
   else{
    $wrong=[byte[]]$ib.Clone()
    if($mutation -eq 'value'){$wrong[$hit.first+$length-1]=[byte]($wrong[$hit.first+$length-1] -bxor 1)}
    if($mutation -eq 'permission'){[BitConverter]::GetBytes([uint32]($hit.flags -bor [long]2147483648)).CopyTo($wrong,$hit.header+36)}
    if($mutation -eq 'duplicate'){if($hit.offset -lt $length){throw 'No independent duplicate placement'};[Array]::Copy($ib,$hit.first,$wrong,$hit.raw,$length)}
    $imagePath=Join-Path $run ($ordinal.ToString()+'-'+$mutation+'.exe');[IO.File]::WriteAllBytes($imagePath,$wrong)
   }
   foreach($stage in 0..1){$null=Run $probes[$stage] @('--constant-binding',$objectPath,$imagePath,$expectedPath) $rejection;$checks+=@([pscustomobject]@{assertion=('Anonymous constant mutation rejected: '+$mutation);readerStage=$stage+1;passed=$true})}
  }
  ++$ordinal
 }
 foreach($inputIdentity in $inputs){if((Get-ArtifactIdentity $inputIdentity.path).sha256 -cne $inputIdentity.sha256){throw ('Input changed during verification: '+$inputIdentity.path)}}
 $success=$true
}catch{$failure=$_.Exception.Message}
[pscustomobject]@{success=$success;failure=$failure;acceptedSelection=$reader.acceptedSelection;inputs=$inputs;checks=$checks;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Unique complete read-only anonymous constant contributions and reference associations. No relocation arithmetic, instruction bytes, cross-object alias policy, pointer-cell/import/TLS, stack/debug or publication qualification.'}|ConvertTo-Json -Depth 18|Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Evidence: $run/report.json"
if(-not $success){throw $failure}
