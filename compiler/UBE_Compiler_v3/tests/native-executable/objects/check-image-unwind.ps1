param([Parameter(Mandatory=$true)][string]$ReaderReport,[Parameter(Mandatory=$true)][string]$RetentionReport)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))){$root=Split-Path $root -Parent;if(-not $root){throw 'Repository root missing'}}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$reader=Get-Content -LiteralPath $ReaderReport -Raw|ConvertFrom-Json;$retention=Get-Content -LiteralPath $RetentionReport -Raw|ConvertFrom-Json
if(-not $reader.success -or -not $retention.success -or $reader.acceptedSelection.compiler.sha256 -cne $retention.acceptedSelection.compiler.sha256){throw 'Passing reader and retention reports from the same bootstrap tools required'}
$run=Join-Path $root ('bootstrap/out/native-image-unwind/'+[guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($run)
$utf8=[Text.UTF8Encoding]::new($false);$inputs=@();$checks=@();$commands=@();$success=$false;$failure=$null
foreach($path in @($ReaderReport,$RetentionReport,$PSCommandPath,(Join-Path $root 'bootstrap/tools/verification.ps1'))){$inputs+=Get-ArtifactIdentity $path}
function Retain($Id){$actual=Get-ArtifactIdentity $Id.path;if($actual.sha256 -cne $Id.sha256){throw ('Retained input changed: '+$Id.path)};$script:inputs+=@($actual);return $actual.path}
function Run([string]$File,[string[]]$Arguments){$r=Invoke-BoundedProcess $File $Arguments $run 30;$script:commands+=@($r);if($r.timedOut -or $r.exit -ne 0 -or $r.stderr -cne ''){throw ($r|ConvertTo-Json -Compress)};return $r.stdout}
try {
 foreach($input in $reader.inputs){$null=Retain $input}
 $probes=@();foreach($stage in 0..1){$id=@($reader.artifacts|Where-Object {(Split-Path $_.path -Leaf) -ceq ('stage'+$stage+'-probe.exe')});if($id.Count -ne 1){throw 'Reader executable missing'};$probes+=Retain $id[0]}
 $readobj=Join-Path (Split-Path $reader.acceptedSelection.clang.path -Parent) 'llvm-readobj.exe';$inputs+=Get-ArtifactIdentity $readobj
 $images=@($retention.artifacts|Where-Object {(Split-Path $_.path -Leaf) -match '^stage[01]-[01]-O[02]-(Full|None)\.exe$'});if($images.Count -ne 16){throw 'Expected sixteen qualified linked images'}
 $total=0;$ordinal=0
 foreach($id in $images){
  $image=Retain $id;$unwindText=Run $readobj @('--unwind',$image);[IO.File]::WriteAllText((Join-Path $run ($ordinal.ToString()+'-unwind.txt')),$unwindText,$utf8)
  $expected='';$count=0
  foreach($block in [regex]::Matches($unwindText,'(?ms)^  RuntimeFunction \{\r?\n(.*?)^  \}')){
   $fields=@();foreach($field in @('StartAddress','EndAddress','UnwindInfoAddress')){$match=[regex]::Match($block.Groups[1].Value,'(?m)^    '+$field+': .*\(0x([0-9A-Fa-f]+)\)\r?$');if(-not $match.Success){throw ('LLVM unwind field missing: '+$field)};$fields+=[Convert]::ToInt64($match.Groups[1].Value,16)}
   if($fields[1] -le $fields[0]){throw 'Invalid independent LLVM extent'}
   $expected+="extent`t"+$fields[0]+"`t"+$fields[1]+"`t"+$fields[2]+"`n";++$count
  }
  if($count -lt 1){throw 'Linked image has no independent runtime-function records'}
  [IO.File]::WriteAllText((Join-Path $run ($ordinal.ToString()+'-expected.tsv')),$expected,$utf8)
  foreach($stage in 0..1){$actual=Run $probes[$stage] @('--image-unwind',$image);if($actual -cne $expected){throw ('Image extent differs from LLVM oracle: '+$image)};$checks+=@([pscustomobject]@{assertion='Production exception-directory code/unwind ranges match independent LLVM image records';readerStage=$stage+1;image=$id;entries=$count;passed=$true})}
  $total+=$count;++$ordinal
 }
 foreach($input in $inputs){if((Get-ArtifactIdentity $input.path).sha256 -cne $input.sha256){throw ('Input changed during verification: '+$input.path)}}
 $success=$true
}catch{$failure=$_.Exception.Message}
[pscustomobject]@{success=$success;failure=$failure;acceptedSelection=$reader.acceptedSelection;inputs=$inputs;checks=$checks;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Image exception-directory ranges from retained linked checked LLVM objects; independent LLVM oracle through both current reader stages. No invented range for absent leaf metadata. Not object/image identity binding, instruction/linked-byte, full unwind/stack, reserve, debug or publication qualification.'}|ConvertTo-Json -Depth 18|Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Evidence: $run/report.json"
if(-not $success){throw $failure}
