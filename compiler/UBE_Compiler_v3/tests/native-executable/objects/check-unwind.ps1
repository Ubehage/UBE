param([Parameter(Mandatory=$true)][string]$ReaderReport,[Parameter(Mandatory=$true)][string]$GraphReport)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))){$root=Split-Path $root -Parent;if(-not $root){throw 'Repository root missing'}}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$reader=Get-Content -LiteralPath $ReaderReport -Raw|ConvertFrom-Json;$graph=Get-Content -LiteralPath $GraphReport -Raw|ConvertFrom-Json
if(-not $reader.success -or -not $graph.success -or $reader.acceptedSelection.compiler.sha256 -cne $graph.acceptedSelection.compiler.sha256){throw 'Passing reader and graph reports from the same bootstrap tools required'}
$run=Join-Path $root ('bootstrap/out/native-unwind/'+[guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($run)
$utf8=[Text.UTF8Encoding]::new($false);$inputs=@();$checks=@();$commands=@();$success=$false;$failure=$null
foreach($path in @($ReaderReport,$GraphReport,$PSCommandPath,(Join-Path $root 'bootstrap/tools/verification.ps1'))){$inputs+=Get-ArtifactIdentity $path}
function Retain($Id){$actual=Get-ArtifactIdentity $Id.path;if($actual.sha256 -cne $Id.sha256){throw ('Retained input changed: '+$Id.path)};$script:inputs+=@($actual);return $actual.path}
function Run([string]$File,[string[]]$Arguments){$r=Invoke-BoundedProcess $File $Arguments $run 30;$script:commands+=@($r);if($r.timedOut -or $r.exit -ne 0 -or $r.stderr -cne ''){throw ($r|ConvertTo-Json -Compress)};return $r.stdout}
function Resolve-Expression([string]$Expression,$Symbols){
 $m=[regex]::Match($Expression,'^(.*?)(?: \+0x([0-9A-Fa-f]+))?$');if(-not $m.Success -or -not $Symbols.ContainsKey($m.Groups[1].Value)){throw ('Unknown LLVM unwind expression: '+$Expression)}
 $symbol=$Symbols[$m.Groups[1].Value];$addend=[long]0;if($m.Groups[2].Success){$addend=[Convert]::ToInt64($m.Groups[2].Value,16)}
 return [pscustomobject]@{section=$symbol.section;offset=$symbol.offset+$addend}
}
try {
 foreach($input in $reader.inputs){$null=Retain $input}
 $probes=@();foreach($stage in 0..1){$id=@($reader.artifacts|Where-Object {(Split-Path $_.path -Leaf) -ceq ('stage'+$stage+'-probe.exe')});if($id.Count -ne 1){throw 'Reader executable missing'};$probes+=Retain $id[0]}
 $readobj=Join-Path (Split-Path $reader.acceptedSelection.clang.path -Parent) 'llvm-readobj.exe';$inputs+=Get-ArtifactIdentity $readobj
 $objects=@($graph.artifacts|Where-Object {(Split-Path $_.path -Leaf) -match '^expected-[01]-[0-6]--?[0-2]-O[02]-(Full|None)\.o$'})
 if($objects.Count -ne 144){throw 'Complete checked object matrix missing'}
 $ordinal=0;$total=0
 foreach($id in $objects){$object=Retain $id;$symbolsText=Run $readobj @('--symbols',$object);$unwindText=Run $readobj @('--unwind',$object)
  [IO.File]::WriteAllText((Join-Path $run ($ordinal.ToString()+'-symbols.txt')),$symbolsText,$utf8);[IO.File]::WriteAllText((Join-Path $run ($ordinal.ToString()+'-unwind.txt')),$unwindText,$utf8)
  $symbols=@{}
  foreach($block in [regex]::Matches($symbolsText,'(?ms)^  Symbol \{\r?\n(.*?)^  \}')){
   $name=[regex]::Match($block.Groups[1].Value,'(?m)^    Name: (.+)\r?$');$value=[regex]::Match($block.Groups[1].Value,'(?m)^    Value: ([0-9]+)\r?$');$section=[regex]::Match($block.Groups[1].Value,'(?m)^    Section: .*\(([0-9]+)\)\r?$')
   if($name.Success -and $value.Success -and $section.Success){$key=$name.Groups[1].Value.TrimEnd([char]13);if($symbols.ContainsKey($key)){throw 'LLVM symbol oracle is ambiguous'};$symbols[$key]=[pscustomobject]@{section=[int]$section.Groups[1].Value-1;offset=[long]$value.Groups[1].Value}}
  }
  $expected='';$count=0
  foreach($block in [regex]::Matches($unwindText,'(?ms)^  RuntimeFunction \{\r?\n(.*?)^  \}')){
   $fields=@();foreach($field in @('StartAddress','EndAddress','UnwindInfoAddress')){$match=[regex]::Match($block.Groups[1].Value,'(?m)^    '+$field+': (.+) \(0x[0-9A-Fa-f]+\)\r?$');if(-not $match.Success){throw ('LLVM unwind field missing: '+$field)};$fields+=Resolve-Expression $match.Groups[1].Value $symbols}
   if($fields[0].section -ne $fields[1].section -or $fields[1].offset -le $fields[0].offset){throw 'Invalid independent LLVM extent'}
   $expected+="extent`t"+$fields[0].section+"`t"+$fields[0].offset+"`t"+($fields[1].offset-$fields[0].offset)+"`t"+$fields[2].section+"`t"+$fields[2].offset+"`n";++$count
  }
  [IO.File]::WriteAllText((Join-Path $run ($ordinal.ToString()+'-expected.tsv')),$expected,$utf8)
  foreach($stage in 0..1){$actual=Run $probes[$stage] @('--unwind',$object);if($actual -cne $expected){throw ('Declared extent differs from LLVM oracle: '+$object)};$checks+=@([pscustomobject]@{assertion='Production declared code/unwind ranges match independent LLVM symbol and runtime-function records';readerStage=$stage+1;object=$id;entries=$count;passed=$true})}
  $total+=$count;++$ordinal
 }
 if($total -lt 1){throw 'No non-leaf extents were exercised'}
 foreach($input in $inputs){if((Get-ArtifactIdentity $input.path).sha256 -cne $input.sha256){throw ('Input changed during verification: '+$input.path)}}
 $success=$true
}catch{$failure=$_.Exception.Message}
[pscustomobject]@{success=$success;failure=$failure;acceptedSelection=$reader.acceptedSelection;inputs=$inputs;checks=$checks;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Object-side declared runtime-function extents from retained checked LLVM objects; independent LLVM oracle through both current reader stages. No invented range for absent leaf metadata. Not instruction/linked-byte, full unwind/stack, reserve, debug or publication qualification.'}|ConvertTo-Json -Depth 18|Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Evidence: $run/report.json"
if(-not $success){throw $failure}
