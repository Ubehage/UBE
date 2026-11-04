param([Parameter(Mandatory=$true)][string]$ReaderReport,[Parameter(Mandatory=$true)][string]$RetentionReport)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))){$root=Split-Path $root -Parent;if(-not $root){throw 'Repository root missing'}}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$reader=Get-Content -LiteralPath $ReaderReport -Raw|ConvertFrom-Json
$retention=Get-Content -LiteralPath $RetentionReport -Raw|ConvertFrom-Json
if(-not $reader.success -or -not $retention.success -or $reader.acceptedSelection.compiler.sha256 -cne $retention.acceptedSelection.compiler.sha256){throw 'Passing reader/retention reports from matching tools required'}
$run=Join-Path $root ('bootstrap/out/native-image-relocations/'+[guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($run)
$inputs=@();$checks=@();$commands=@();$success=$false;$failure=$null;$utf8=[Text.UTF8Encoding]::new($false)
foreach($p in @($ReaderReport,$RetentionReport,$PSCommandPath,(Join-Path $PSScriptRoot 'image-relocation-matrix.c'),(Join-Path $root 'bootstrap/tools/verification.ps1'))){$inputs+=Get-ArtifactIdentity $p}
function Retain($Id){$actual=Get-ArtifactIdentity $Id.path;if($actual.sha256 -cne $Id.sha256){throw ('Retained input changed: '+$Id.path)};$script:inputs+=@($actual);return $actual.path}
function Run([string]$File,[string[]]$Arguments,[int]$Timeout=180){$r=Invoke-BoundedProcess $File $Arguments $run $Timeout;$script:commands+=@($r);if($r.timedOut -or $r.exit -ne 0 -or $r.stderr -cne ''){throw ($r|ConvertTo-Json -Compress)};return $r.stdout}
function U16([byte[]]$b,[int]$at){return [BitConverter]::ToUInt16($b,$at)}
function U32([byte[]]$b,[int]$at){return [long][BitConverter]::ToUInt32($b,$at)}
function FileOffset([long]$rva,[int]$length){
 $found=@($script:sections|Where-Object {$rva -ge $_.rva -and $rva+$length -le $_.rva+[Math]::Min($_.virtual,$_.raw)})
 if($found.Count -ne 1){throw 'Independent image mapping is not unique'}
 return [int]($found[0].file+$rva-$found[0].rva)
}
function Symbol([string]$name){if($name -ceq '__ImageBase'){return [long]0};if(-not $script:symbols.ContainsKey($name)){throw ('Required oracle symbol missing: '+$name)};$v=@($script:symbols[$name]|Select-Object -Unique);if($v.Count -ne 1){throw ('Ambiguous oracle symbol: '+$name)};return [long]$v[0]}
function Pair([long]$field,[long]$target,[string]$role){$script:pairs+=@([pscustomobject]@{field=$field;target=$target;role=$role})}
try {
 foreach($id in $reader.inputs){$null=Retain $id}
 $readerDir=Split-Path ([IO.Path]::GetFullPath($ReaderReport)) -Parent
 foreach($name in @('probe.c','file-output-observed.c')){
  $id=@($reader.artifacts|Where-Object {(Split-Path $_.path -Leaf) -ceq $name});if($id.Count -ne 1){throw 'Reader bridge missing'}
  $source=Retain $id[0];$dest=$name
  if($name -ceq 'probe.c'){
   $dest='reader-probe.c';$text=[IO.File]::ReadAllText($source)
   if(([regex]::Matches($text,'(?m)^int main\(')).Count -ne 1){throw 'Reader main bridge changed'}
   [IO.File]::WriteAllText((Join-Path $run $dest),[regex]::Replace($text,'(?m)^int main\(','int binary_reader_main('),$utf8)
  }else{[IO.File]::Copy($source,(Join-Path $run $dest))}
 }
 # Only the unnamed constructor uses a frozen address observation. All other
 # expected fields and values come from independent named anchors below.
 $diagnosticPath=Join-Path $root 'bootstrap/out/native-image-pointer-diagnostic.json'
 $inputs+=Get-ArtifactIdentity $diagnosticPath;$diagnostic=Get-Content -LiteralPath $diagnosticPath -Raw|ConvertFrom-Json
 if(-not $diagnostic.success){throw 'Frozen constructor observation missing'}
 foreach($id in $diagnostic.inputs){$null=Retain $id}
 $executables=@()
 foreach($stage in 0..1){
  $id=@($reader.artifacts|Where-Object {(Split-Path $_.path -Leaf) -ceq ('stage'+$stage+'-adapter.ll')});if($id.Count -ne 1){throw 'Reader adapter missing'};$adapter=Retain $id[0]
  $exe=Join-Path $run ('stage'+$stage+'-matrix.exe');$executables+=$exe
  $null=Run $reader.acceptedSelection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-Wall','-Wextra','-Werror','-I',$run,'-I',$root,'-I',$PSScriptRoot,$adapter,(Join-Path $PSScriptRoot 'image-relocation-matrix.c'),$reader.acceptedSelection.unicodeRuntime.path,'-o',$exe)
  $literal=Run $exe @('--image-relocations') 60
  if($literal -cne "PASS image relocations 1198 bytes/311 events`n"){throw 'Literal exact-cost oracle differs'}
  $checks+=@([pscustomobject]@{assertion='Literal relocation suite and independently frozen 1198-byte/311-event cost';readerStage=$stage+1;passed=$true;output=$literal})
 }
 $images=@($retention.artifacts|Where-Object {(Split-Path $_.path -Leaf) -match '^stage[01]-[01]-O[02]-(Full|None)\.exe$'});if($images.Count -ne 16){throw 'Expected sixteen retained images'}
 $ordinal=0
 foreach($id in $images){
  $image=Retain $id;$b=[IO.File]::ReadAllBytes($image);$pe=U32 $b 60;$sectionTable=$pe+24+(U16 $b ($pe+20));$sections=@()
  for($i=0;$i -lt (U16 $b ($pe+6));++$i){$at=$sectionTable+40*$i;$sections+=@([pscustomobject]@{rva=(U32 $b ($at+12));virtual=(U32 $b ($at+8));file=(U32 $b ($at+20));raw=(U32 $b ($at+16))})}
  $symbols=@{};$sym=U32 $b ($pe+12);$count=U32 $b ($pe+16);$strings=$sym+18*$count
  for($i=0;$i -lt $count;){
   $at=$sym+18*$i;$section=U16 $b ($at+12)
   if((U32 $b $at) -eq 0){$first=$strings+(U32 $b ($at+4));$end=$first;while($b[$end] -ne 0){++$end};$name=[Text.Encoding]::UTF8.GetString($b,$first,$end-$first)}else{$end=0;while($end -lt 8 -and $b[$at+$end] -ne 0){++$end};$name=[Text.Encoding]::UTF8.GetString($b,$at,$end)}
   if($section -gt 0 -and $section -le $sections.Count){$value=$sections[$section-1].rva+(U32 $b ($at+8));if(-not $symbols.ContainsKey($name)){$symbols[$name]=@()};$symbols[$name]+=$value}
   $i+=1+$b[$at+17]
  }
  $pairs=@()
  foreach($name in @($symbols.Keys|Where-Object {$_ -clike '.refptr.*'})){Pair (Symbol $name) (Symbol $name.Substring(8)) 'reference cell'}
  # __ImageBase is an absolute COFF symbol, deliberately not ordinary storage.
  # Its reference is handled explicitly when resolving symbols above/below.
  for($i=0;$i -lt 3;++$i){Pair ((Symbol 'ube.module.initializers')+8*$i) (Symbol ('ube.module.init'+$i)) 'generated initializer'}
  $tls=Symbol '_tls_used';$offset=0
  foreach($name in @('_tls_start','_tls_end','_tls_index','__xl_c')){Pair ($tls+$offset) (Symbol $name) 'TLS directory';$offset+=8}
  Pair (Symbol '__xl_c') (Symbol '__dyn_tls_init') 'TLS callback'
  Pair (Symbol '__xl_d') (Symbol '__dyn_tls_dtor') 'TLS callback'
  Pair (Symbol '__dyn_tls_init_callback') (Symbol '__dyn_tls_init') 'CRT dynamic initializer'
  Pair (Symbol 'p.0') ((Symbol '__DTOR_LIST__')+8) 'CRT destructor cursor'
  foreach($names in @(@('__imp___p___initenv','__p___initenv'),@('__imp__amsg_exit','_amsg_exit'),@('__imp___getmainargs','__getmainargs'),@('__imp___initenv','local__initenv'))){Pair (Symbol $names[0]) (Symbol $names[1]) 'CRT local adapter'}
  $frozen=@($diagnostic.observations|Where-Object {$_.image -ceq $image});if($frozen.Count -ne 1){throw 'Frozen image observation missing'}
  $ctor=@($frozen[0].rows|Where-Object {$_.role -ceq 'CRT constructor entry'});if($ctor.Count -ne 1){throw 'Frozen unnamed constructor missing'}
  Pair ((Symbol '__CTOR_LIST__')+8) $ctor[0].targetRVA 'CRT constructor observation'
  $pairs=@($pairs|Sort-Object field);if($pairs.Count -ne 49 -or @($pairs.field|Select-Object -Unique).Count -ne 49){throw 'Independent pointer census mismatch'}
  # Decode entry locations solely to target mutation sites, never to derive
  # the expected pointer set or its target values.
  $sites=@{};$reloc=U32 $b ($pe+176);$size=U32 $b ($pe+180);$pos=FileOffset $reloc $size;$end=$pos+$size
  while($pos -lt $end){$page=U32 $b $pos;$block=U32 $b ($pos+4);if($block -lt 8 -or $pos+$block -gt $end){throw 'Frozen relocation bounds'};for($at=$pos+8;$at -lt $pos+$block;$at+=2){$entry=U16 $b $at;if(($entry -shr 12) -eq 10){$field=$page+($entry -band 4095);if($sites.ContainsKey($field)){throw 'Frozen duplicate relocation'};$sites[$field]=$at}};$pos+=$block}
  $lines=@('49');foreach($pair in $pairs){if(-not $sites.ContainsKey($pair.field)){throw 'Expected field has no mutation site'};$lines+=('{0} {1} {2} {3}' -f $pair.field,$pair.target,(FileOffset $pair.field 8),$sites[$pair.field])}
  $oracle=Join-Path $run ($ordinal.ToString()+'-expected.txt');[IO.File]::WriteAllLines($oracle,$lines,$utf8)
  $pairs|ConvertTo-Json -Depth 5|Set-Content (Join-Path $run ($ordinal.ToString()+'-roles.json')) -Encoding UTF8
  foreach($stage in 0..1){$output=Run $executables[$stage] @($image,$oracle) 60;if($output -notmatch '^PASS image pointer associations 49; rejected 147; bytes [1-9][0-9]*; events [1-9][0-9]*\n$'){throw ('Unexpected association result: '+$output)};$checks+=@([pscustomobject]@{assertion='Complete independent pointer associations and per-field omitted/redirected/value controls';readerStage=$stage+1;image=$id;fields=49;rejected=147;passed=$true;output=$output})}
  ++$ordinal
 }
 foreach($id in $inputs){if((Get-ArtifactIdentity $id.path).sha256 -cne $id.sha256){throw ('Input changed during verification: '+$id.path)}}
 $success=$true
}catch{$failure=$_.Exception.Message}
[pscustomobject]@{success=$success;failure=$failure;acceptedSelection=$reader.acceptedSelection;inputs=$inputs;checks=$checks;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Exact base-relocation membership and preferred-base pointer associations through both readers. Named-anchor expectations plus explicit frozen unnamed CRT constructor observation; controlled numeric rebasing, not Windows loader execution or CRT function/control-flow proof.'}|ConvertTo-Json -Depth 18|Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Evidence: $run/report.json"
if(-not $success){throw $failure}
