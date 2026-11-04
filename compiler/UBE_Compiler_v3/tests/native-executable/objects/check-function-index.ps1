param([Parameter(Mandatory=$true)][string]$ReaderReport,[Parameter(Mandatory=$true)][string]$BindingReport)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))){$root=Split-Path $root -Parent;if(-not $root){throw 'Repository root missing'}}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$reader=Get-Content -LiteralPath $ReaderReport -Raw|ConvertFrom-Json;$binding=Get-Content -LiteralPath $BindingReport -Raw|ConvertFrom-Json
if(-not $reader.success -or -not $binding.success -or $reader.acceptedSelection.compiler.sha256 -cne $binding.acceptedSelection.compiler.sha256){throw 'Passing reports from the same bootstrap tools required'}
$run=Join-Path $root ('bootstrap/out/native-function-index/'+[guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($run)
$inputs=@();$checks=@();$commands=@();$success=$false;$failure=$null
foreach($path in @($ReaderReport,$BindingReport,$PSCommandPath,(Join-Path $root 'bootstrap/tools/verification.ps1'))){$inputs+=Get-ArtifactIdentity $path}
function Retain($Id){$actual=Get-ArtifactIdentity $Id.path;if($actual.sha256 -cne $Id.sha256){throw ('Retained input changed: '+$Id.path)};$script:inputs+=@($actual);return $actual.path}
function Run([string]$File,[string[]]$Arguments,[string]$Rejection=''){
 $r=Invoke-BoundedProcess $File $Arguments $run 30;$script:commands+=@($r)
 if($r.timedOut){throw ($r|ConvertTo-Json -Compress)}
 if($Rejection){if($r.exit -ne 1 -or $r.stderr -notmatch $Rejection){throw ('Function fence control was not rejected: '+($r|ConvertTo-Json -Compress))}}
 elseif($r.exit -ne 0 -or $r.stderr -cne ''){throw ($r|ConvertTo-Json -Compress)}
 return $r.stdout
}
try {
 foreach($input in $reader.inputs){$null=Retain $input}
 $probes=@();foreach($stage in 0..1){$id=@($reader.artifacts|Where-Object {(Split-Path $_.path -Leaf) -ceq ('stage'+$stage+'-probe.exe')});if($id.Count -ne 1){throw 'Reader executable missing'};$probes+=Retain $id[0]}
 $files=[ordered]@{};foreach($command in $binding.commands){if($command.arguments[0] -ceq '--bound-extents' -and $command.exit -eq 0){$files[$command.arguments[1]]=$true;$files[$command.arguments[2]]=$true}}
 if($files.Count -ne 160){throw 'Expected 144 objects and sixteen images'};$ordinal=0
 foreach($path in $files.Keys){
  $id=@($binding.inputs|Where-Object path -EQ $path);if($id.Count -lt 1){throw 'Qualified input identity missing'};$file=Retain $id[0];$bytes=[IO.File]::ReadAllBytes($file)
  # Independent SDK COFF/PE offsets. The oracle exhaustively scans candidates
  # per function; it does not reuse production sorting or binary search.
  $kind=1;$head=0;if([BitConverter]::ToUInt16($bytes,0) -eq 0x5A4D){$kind=2;$head=[int][BitConverter]::ToUInt32($bytes,60)+4}
  $sections=[int][BitConverter]::ToUInt16($bytes,$head+2);$table=[int][BitConverter]::ToUInt32($bytes,$head+8);$count=[int][BitConverter]::ToUInt32($bytes,$head+12);$sectionTable=$head+20+[BitConverter]::ToUInt16($bytes,$head+16);$imageBase=[long]0
  if($kind -eq 2){$imageBase=[BitConverter]::ToInt64($bytes,$head+44)}
  $rows=@();$i=0
  while($i -lt $count){$at=$table+18*$i;$section=[int][BitConverter]::ToInt16($bytes,$at+12);$type=[int][BitConverter]::ToUInt16($bytes,$at+14);$class=[int]$bytes[$at+16]
   if($section -gt 0 -and $type -eq 32 -and $class -in @(2,3)){
    if($section -gt $sections){throw 'Independent function section invalid'};$sh=$sectionTable+40*($section-1);$value=[long][BitConverter]::ToUInt32($bytes,$at+8);$raw=[int][BitConverter]::ToUInt32($bytes,$sh+20);$initialized=[long][BitConverter]::ToUInt32($bytes,$sh+16);$rva=[long]0;$address=[long]0
    if($kind -eq 2){$initialized=[Math]::Min($initialized,[long][BitConverter]::ToUInt32($bytes,$sh+8));$rva=[long][BitConverter]::ToUInt32($bytes,$sh+12)+$value;$address=$imageBase+$rva}
    $flags=[long][BitConverter]::ToUInt32($bytes,$sh+36)
    if($value -ge $initialized -or ($flags -band 0x60000020) -ne 0x60000020 -or ($flags -band [long]2147483648) -ne 0){throw 'Independent function anchor is not initialized readable code'}
    $rows+=@([pscustomobject]@{symbol=$i;section=$section-1;first=[int]($raw+$value);offset=$value;rva=$rva;address=$address;flags=$flags;end=$initialized})
   };$i+=1+[int]$bytes[$at+17]
  }
  $stream=[IO.MemoryStream]::new();$writer=[IO.BinaryWriter]::new($stream);$writer.Write([int]$rows.Count)
  foreach($row in $rows){$end=$row.end;foreach($other in $rows){if($other.section -eq $row.section -and $other.offset -gt $row.offset -and $other.offset -lt $end){$end=$other.offset}};$length=[int]($end-$row.offset)
   foreach($value in @($row.symbol,$row.section,$row.first,$length,$length,32)){$writer.Write([int]$value)}
   foreach($value in @($row.offset,$row.rva,$row.address,$row.flags)){$writer.Write([long]$value)}
  };$writer.Flush();$expectedBytes=$stream.ToArray();$writer.Dispose();$stream.Dispose();$expected=Join-Path $run ($ordinal.ToString()+'-expected.bin');[IO.File]::WriteAllBytes($expected,$expectedBytes)
  foreach($stage in 0..1){$actual=Run $probes[$stage] @('--function-index',$file,$expected);if($actual -cne ('PASS '+$rows.Count+' independently bounded function fences'+[char]10)){throw 'Function fence comparison output differs'};$checks+=@([pscustomobject]@{assertion='Production function fences match independent exhaustive SDK-offset oracle';readerStage=$stage+1;input=$id[0];kind=$kind;functions=$rows.Count;passed=$true})}
  if($rows.Count -gt 0){
   $wrong=[byte[]]$expectedBytes.Clone();[BitConverter]::GetBytes([int]($rows[0].first+1)).CopyTo($wrong,12);$wrongPath=Join-Path $run ($ordinal.ToString()+'-shifted.bin');[IO.File]::WriteAllBytes($wrongPath,$wrong)
   foreach($stage in 0..1){$null=Run $probes[$stage] @('--function-index',$file,$wrongPath) 'function fence failure index=0 code=1506';$checks+=@([pscustomobject]@{assertion='Shifted retained function anchor rejects with 1506';readerStage=$stage+1;passed=$true})}
   $wrong=[byte[]]$expectedBytes.Clone();[BitConverter]::GetBytes([int]([BitConverter]::ToInt32($wrong,16)+1)).CopyTo($wrong,16);$wrongPath=Join-Path $run ($ordinal.ToString()+'-length.bin');[IO.File]::WriteAllBytes($wrongPath,$wrong)
   foreach($stage in 0..1){$null=Run $probes[$stage] @('--function-index',$file,$wrongPath) ([regex]::Escape('ok && memcmp(&result,&expected,sizeof expected)==0'));$checks+=@([pscustomobject]@{assertion='Incorrect independent function fence length is rejected';readerStage=$stage+1;passed=$true})}
  };++$ordinal
 }
 foreach($input in $inputs){if((Get-ArtifactIdentity $input.path).sha256 -cne $input.sha256){throw ('Input changed during verification: '+$input.path)}}
 $success=$true
}catch{$failure=$_.Exception.Message}
[pscustomobject]@{success=$success;failure=$failure;acceptedSelection=$reader.acceptedSelection;inputs=$inputs;checks=$checks;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Conservative function fences from immutable prepared symbol inventories, including unordered image symbols and aliases. Does not establish complete leaf extents, relocation identity, stack/debug validation or publication.'}|ConvertTo-Json -Depth 18|Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Evidence: $run/report.json"
if(-not $success){throw $failure}
