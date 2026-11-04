param([Parameter(Mandatory=$true)][string]$ReaderReport,[Parameter(Mandatory=$true)][string]$GraphReport,[Parameter(Mandatory=$true)][string]$RetentionReport)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))){$root=Split-Path $root -Parent;if(-not $root){throw 'Repository root missing'}}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$reader=Get-Content -LiteralPath $ReaderReport -Raw|ConvertFrom-Json;$graph=Get-Content -LiteralPath $GraphReport -Raw|ConvertFrom-Json;$retention=Get-Content -LiteralPath $RetentionReport -Raw|ConvertFrom-Json
if(-not $reader.success -or -not $graph.success -or -not $retention.success -or $reader.acceptedSelection.compiler.sha256 -cne $graph.acceptedSelection.compiler.sha256 -or $reader.acceptedSelection.compiler.sha256 -cne $retention.acceptedSelection.compiler.sha256){throw 'Passing reports from the same bootstrap tools required'}
$run=Join-Path $root ('bootstrap/out/native-extent-bindings/'+[guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($run)
$utf8=[Text.UTF8Encoding]::new($false);$inputs=@();$checks=@();$commands=@();$success=$false;$failure=$null
foreach($path in @($ReaderReport,$GraphReport,$RetentionReport,$PSCommandPath,(Join-Path $root 'bootstrap/tools/verification.ps1'))){$inputs+=Get-ArtifactIdentity $path}
function Retain($Id){$actual=Get-ArtifactIdentity $Id.path;if($actual.sha256 -cne $Id.sha256){throw ('Retained input changed: '+$Id.path)};$script:inputs+=@($actual);return $actual.path}
function Artifact($Report,[string]$Path){$id=@($Report.artifacts|Where-Object path -EQ $Path);if($id.Count -ne 1){throw ('Missing retained artifact: '+$Path)};return Retain $id[0]}
function Run([string]$File,[string[]]$Arguments,[bool]$Rejected=$false){
 $r=Invoke-BoundedProcess $File $Arguments $run 60;$script:commands+=@($r);if($r.timedOut){throw ($r|ConvertTo-Json -Compress)}
 if($Rejected){if($r.exit -ne 1 -or $r.stderr -notmatch 'extent binding row=[0-9]+ code=1506 resource=0'){throw ('Extent mutation was not rejected at binding: '+($r|ConvertTo-Json -Compress))}}
 elseif($r.exit -ne 0 -or $r.stderr -cne ''){throw ($r|ConvertTo-Json -Compress)}
 return $r.stdout
}
function Read-Symbols([string]$Text,[string]$OnlyName=''){
 $symbols=@{}
 foreach($block in [regex]::Matches($Text,'(?ms)^  Symbol \{\r?\n(.*?)^  \}')){
  $name=[regex]::Match($block.Groups[1].Value,'(?m)^    Name: (.+)\r?$');$value=[regex]::Match($block.Groups[1].Value,'(?m)^    Value: ([0-9]+)\r?$');$section=[regex]::Match($block.Groups[1].Value,'(?m)^    Section: .*\(([0-9]+)\)\r?$')
  if($name.Success -and $value.Success -and $section.Success -and [int]$section.Groups[1].Value -gt 0){$key=$name.Groups[1].Value.TrimEnd([char]13);if($OnlyName -and $key -cne $OnlyName){continue};if($symbols.ContainsKey($key)){throw 'LLVM symbol oracle is ambiguous'};$symbols[$key]=[pscustomobject]@{section=[int]$section.Groups[1].Value-1;offset=[long]$value.Groups[1].Value}}
 }
 return $symbols
}
function Resolve-Expression([string]$Expression,$Symbols){
 $m=[regex]::Match($Expression,'^(.*?)(?: \+0x([0-9A-Fa-f]+))?$');if(-not $m.Success -or -not $Symbols.ContainsKey($m.Groups[1].Value)){throw ('Unknown LLVM unwind expression: '+$Expression)}
 $symbol=$Symbols[$m.Groups[1].Value];$addend=[long]0;if($m.Groups[2].Success){$addend=[Convert]::ToInt64($m.Groups[2].Value,16)}
 return [pscustomobject]@{section=$symbol.section;offset=$symbol.offset+$addend}
}
function Read-ObjectOracle([string]$Path,[string]$Stem){
 $text=Run $script:readobj @('--symbols','--unwind',$Path);[IO.File]::WriteAllText((Join-Path $run ($Stem+'-oracle.txt')),$text,$utf8);$symbols=Read-Symbols $text;$ranges=@{};$index=0
 foreach($block in [regex]::Matches($text,'(?ms)^  RuntimeFunction \{\r?\n(.*?)^  \}')){
  $fields=@();foreach($field in @('StartAddress','EndAddress')){$m=[regex]::Match($block.Groups[1].Value,'(?m)^    '+$field+': (.+) \(0x[0-9A-Fa-f]+\)\r?$');if(-not $m.Success){throw ('LLVM field missing: '+$field)};$fields+=Resolve-Expression $m.Groups[1].Value $symbols}
  if($fields[0].section -ne $fields[1].section -or $fields[1].offset -le $fields[0].offset){throw 'Invalid independent object range'}
  $key=$fields[0].section.ToString()+':'+$fields[0].offset;if($ranges.ContainsKey($key)){throw 'Duplicate independent object range'};$ranges[$key]=[pscustomobject]@{count=$fields[1].offset-$fields[0].offset;index=$index};++$index
 }
 return [pscustomobject]@{symbols=$symbols;ranges=$ranges}
}
try {
 foreach($input in $reader.inputs){$null=Retain $input}
 $probes=@();foreach($stage in 0..1){$id=@($reader.artifacts|Where-Object {(Split-Path $_.path -Leaf) -ceq ('stage'+$stage+'-probe.exe')});if($id.Count -ne 1){throw 'Reader executable missing'};$probes+=Retain $id[0]}
 $readobj=Join-Path (Split-Path $reader.acceptedSelection.clang.path -Parent) 'llvm-readobj.exe';$inputs+=Get-ArtifactIdentity $readobj
 $graphRoot=Split-Path ([IO.Path]::GetFullPath($GraphReport)) -Parent;$retentionRoot=Split-Path ([IO.Path]::GetFullPath($RetentionReport)) -Parent
 foreach($generator in 0..1){foreach($reference in 0..1){
  $directory=Join-Path $graphRoot ('stage'+$generator);$table=Artifact $graph (Join-Path $directory ('expected-definitions-'+$reference+'.tsv'));$rows=@(Import-Csv -LiteralPath $table -Delimiter "`t");if($rows.Count -ne 54){throw 'Complete frozen table missing'}
  $main=@($rows|Where-Object {[int]$_.family -eq 1 -and [int]$_.required -eq 1});if($main.Count -ne 1){throw 'Expected Main missing'}
  foreach($optimization in @('O0','O2')){foreach($debug in @('Full','None')){
   $stem='stage'+$generator+'-'+$reference+'-'+$optimization+'-'+$debug;$image=Artifact $retention (Join-Path $retentionRoot ($stem+'.exe'));$mainUnit=$null
   foreach($kind in 0..6){$sources=@(-1);if($kind -eq 0){$sources=0..2};foreach($source in $sources){
    $unitStem=$stem+'-'+$kind+'-'+$source;$object=Artifact $graph (Join-Path $directory ('expected-'+$reference+'-'+$kind+'-'+$source+'-'+$optimization+'-'+$debug+'.o'));$expected=Artifact $retention (Join-Path $retentionRoot ($unitStem+'.bin'));$oracle=Read-ObjectOracle $object $unitStem
    $selected=@($rows|Where-Object {[int]$_.unit -eq $kind -and [int]$_.source -eq $source -and [int]$_.bytes -eq 0});$output='';$bound=0;$noUnwind=0;$eliminated=0
    foreach($row in $selected){$value='eliminated';if($oracle.symbols.ContainsKey($row.name)){$symbol=$oracle.symbols[$row.name];$key=$symbol.section.ToString()+':'+$symbol.offset;if($oracle.ranges.ContainsKey($key)){$value=$oracle.ranges[$key].count;++$bound}else{$value='no-unwind';++$noUnwind}}else{if([int]$row.required -eq 1){throw 'Required object definition missing from oracle'};++$eliminated};$output+=$row.name+"`t"+$value+"`n"}
    foreach($readerStage in 0..1){$actual=Run $probes[$readerStage] @('--bound-extents',$object,$image,$expected);if($actual -cne $output){throw ('Bound extents differ from frozen rows/LLVM oracle: '+$unitStem)};$checks+=@([pscustomobject]@{assertion='Retained declared object/image extents match frozen definitions and independent LLVM lengths';readerStage=$readerStage+1;generatorStage=$generator+1;reference=$reference;optimization=$optimization;debug=$debug;unit=$kind;source=$source;bound=$bound;noUnwind=$noUnwind;eliminated=$eliminated;passed=$true})}
    if($kind -eq 0 -and $source -eq [int]$main[0].source){$mainUnit=[pscustomobject]@{object=$object;expected=$expected;oracle=$oracle}}
   }}
   if(-not $mainUnit){throw 'Main unit missing'}
   $symbols=Read-Symbols (Run $readobj @('--symbols',$image)) $main[0].name;if($symbols.Count -ne 1){throw 'Unique Main image symbol missing'};$symbol=$symbols[$main[0].name];$bytes=[IO.File]::ReadAllBytes($image);$pe=[BitConverter]::ToInt32($bytes,60);$sections=$pe+24+[BitConverter]::ToUInt16($bytes,$pe+20);$sectionCount=[BitConverter]::ToUInt16($bytes,$pe+6);$rva=[BitConverter]::ToUInt32($bytes,$sections+40*$symbol.section+12)+$symbol.offset
   $tableRva=[BitConverter]::ToUInt32($bytes,$pe+160);$tableSize=[BitConverter]::ToUInt32($bytes,$pe+164);$tableFirst=-1
   for($s=0;$s -lt $sectionCount;++$s){$at=$sections+40*$s;$va=[BitConverter]::ToUInt32($bytes,$at+12);$size=[BitConverter]::ToUInt32($bytes,$at+8);if($tableRva -ge $va -and $tableRva+$tableSize -le $va+$size){if($tableFirst -ne -1){throw 'Ambiguous independent directory locator'};$tableFirst=[BitConverter]::ToUInt32($bytes,$at+20)+$tableRva-$va}}
   if($tableFirst -lt 0 -or $tableSize%12 -ne 0){throw 'Independent image directory missing'};$records=@();for($at=$tableFirst;$at -lt $tableFirst+$tableSize;$at+=12){if([BitConverter]::ToUInt32($bytes,$at) -eq $rva){$records+=$at}};if($records.Count -ne 1){throw 'Independent Main image record missing'};$record=$records[0]
   $objectSymbol=$mainUnit.oracle.symbols[$main[0].name];$objectKey=$objectSymbol.section.ToString()+':'+$objectSymbol.offset;if(-not $mainUnit.oracle.ranges.ContainsKey($objectKey)){throw 'Main object range missing'};$objectRecord=$mainUnit.oracle.ranges[$objectKey].index
   foreach($control in @('shifted-start','shortened-end','missing-range','resized-object')){
    $candidateObject=$mainUnit.object;$candidateImage=$image
    if($control -eq 'resized-object'){$wrong=[IO.File]::ReadAllBytes($mainUnit.object);$sectionCount=[BitConverter]::ToUInt16($wrong,2);$positions=@();for($s=0;$s -lt $sectionCount;++$s){$at=20+40*$s;if([Text.Encoding]::ASCII.GetString($wrong,$at,8).TrimEnd([char]0) -ceq '.pdata'){$positions+=[BitConverter]::ToUInt32($wrong,$at+20)}};if($positions.Count -ne 1){throw 'Independent object table missing'};$at=$positions[0]+12*$objectRecord+4;[Array]::Copy([BitConverter]::GetBytes([uint32]([BitConverter]::ToUInt32($wrong,$at)+1)),0,$wrong,$at,4);$candidateObject=Join-Path $run ($stem+'-'+$control+'.o');[IO.File]::WriteAllBytes($candidateObject,$wrong)}
    else{$wrong=[byte[]]$bytes.Clone();if($control -eq 'shifted-start'){[Array]::Copy([BitConverter]::GetBytes([uint32]($rva+1)),0,$wrong,$record,4)};if($control -eq 'shortened-end'){[Array]::Copy([BitConverter]::GetBytes([uint32]([BitConverter]::ToUInt32($wrong,$record+4)-1)),0,$wrong,$record+4,4)};if($control -eq 'missing-range'){[Array]::Copy($wrong,$record+12,$wrong,$record,$tableFirst+$tableSize-$record-12);[Array]::Clear($wrong,$tableFirst+$tableSize-12,12);[Array]::Copy([BitConverter]::GetBytes([uint32]($tableSize-12)),0,$wrong,$pe+164,4)};$candidateImage=Join-Path $run ($stem+'-'+$control+'.exe');[IO.File]::WriteAllBytes($candidateImage,$wrong)}
    foreach($readerStage in 0..1){$null=Run $probes[$readerStage] @('--bound-extents',$candidateObject,$candidateImage,$mainUnit.expected) $true;$checks+=@([pscustomobject]@{assertion=('Range binding rejects '+$control);readerStage=$readerStage+1;generatorStage=$generator+1;reference=$reference;optimization=$optimization;debug=$debug;passed=$true})}
   }
  }}
 }}
 foreach($input in $inputs){if((Get-ArtifactIdentity $input.path).sha256 -cne $input.sha256){throw ('Input changed during verification: '+$input.path)}}
 $success=$true
}catch{$failure=$_.Exception.Message}
[pscustomobject]@{success=$success;failure=$failure;acceptedSelection=$reader.acceptedSelection;inputs=$inputs;checks=$checks;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Current production declared extent correspondence over frozen expected definitions and retained graph/link artifacts. Explicit no-unwind and eliminated cases do not invent leaf bounds. Not instruction/fixup equality, full unwind/stack/debug validation, integrated build ownership or publication.'}|ConvertTo-Json -Depth 18|Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Evidence: $run/report.json"
if(-not $success){throw $failure}
