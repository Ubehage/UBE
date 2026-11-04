param([Parameter(Mandatory=$true)][string]$ReaderReport,[Parameter(Mandatory=$true)][string]$FramesReport)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))){$root=Split-Path $root -Parent;if(-not $root){throw 'Repository root missing'}}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$reader=Get-Content -LiteralPath $ReaderReport -Raw|ConvertFrom-Json
$frames=Get-Content -LiteralPath $FramesReport -Raw|ConvertFrom-Json
if(-not $reader.success -or -not $frames.success -or $frames.bindings.Count -ne 16){throw 'Passing reader and complete frame matrix required'}
if($reader.acceptedSelection.compiler.sha256 -cne $frames.acceptedSelection.compiler.sha256){throw 'Bootstrap selection mismatch'}
$run=Join-Path $root ('bootstrap/out/native-data-bindings/'+[guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($run)
$inputs=@((Get-ArtifactIdentity $ReaderReport),(Get-ArtifactIdentity $FramesReport),(Get-ArtifactIdentity $PSCommandPath),(Get-ArtifactIdentity (Join-Path $root 'bootstrap/tools/verification.ps1')))
$commands=@();$checks=@();$success=$false;$failure=$null
function Retain($Identity){$actual=Get-ArtifactIdentity $Identity.path;if($actual.sha256 -cne $Identity.sha256 -or $actual.bytes -ne $Identity.bytes){throw ('Input identity changed: '+$Identity.path)};$script:inputs+=@($actual);return $actual.path}
function Run([string]$File,[string[]]$Arguments,[bool]$Rejected){
 $r=Invoke-BoundedProcess $File $Arguments $run 30;$script:commands+=@($r)
 if($r.timedOut){throw ($r|ConvertTo-Json -Compress)}
 if($Rejected){if($r.exit -ne 1 -or $r.stderr -notmatch 'validate_integer_data'){throw ('Corrupt integer metadata was not rejected by the validator: '+($r|ConvertTo-Json -Compress))}}
 elseif($r.exit -ne 0 -or $r.stderr -cne ''){throw ($r|ConvertTo-Json -Compress)}
 return $r.stdout
}
function Write-Expected([string]$Name,[long[]]$Values){$path=Join-Path $run $Name;$stream=[IO.MemoryStream]::new();$writer=[IO.BinaryWriter]::new($stream);foreach($value in $Values){$writer.Write($value)};$writer.Flush();[IO.File]::WriteAllBytes($path,$stream.ToArray());$writer.Dispose();$stream.Dispose();return $path}
try {
 foreach($input in $reader.inputs){$null=Retain $input}
 $probes=@();foreach($stage in 0..1){$probe=@($reader.artifacts|Where-Object {(Split-Path $_.path -Leaf) -ceq ('stage'+$stage+'-probe.exe')});if($probe.Count -ne 1){throw 'Unique reader executable missing'};$probes+=Retain $probe[0]}
 $reserve=Write-Expected 'reserve.bin' @(256);$index=0
 foreach($binding in $frames.bindings){
  if($binding.footprints.Count -ne 18 -or $binding.names.Count -ne 18){throw 'Complete expected frame inventory required'}
  $expected=Write-Expected ('frames-'+$index+'.bin') $binding.footprints;++$index
  foreach($artifact in @($binding.table,$binding.image)){
   $path=Retain $artifact
   foreach($data in @(@('ube.stack.frames',$expected,18),@('ube.stack.reserve',$reserve,1))){for($stage=0;$stage -lt 2;++$stage){
    $actual=Run $probes[$stage] @('--integers',$path,$data[0],$data[1]) $false
    if($actual -cne ('PASS bound integer data '+$data[2]+" values"+[char]10)){throw 'Integer binding output mismatch'}
    $checks+=@([pscustomobject]@{assertion='Production UBE immutable data matches independently derived expected footprint/reserve values';readerStage=$stage+1;generatorStage=$binding.stage;reference=$binding.reference;optimization=$binding.optimization;debug=$binding.debug;name=$data[0];artifact=$artifact;passed=$true})
   }}
  }
  foreach($leaf in @('understated.o','understated.exe')){
   $path=Join-Path (Split-Path $binding.table.path -Parent) $leaf;$artifact=@($frames.artifacts|Where-Object path -EQ $path);if($artifact.Count -ne 1){throw 'Retained understatement control missing'};$path=Retain $artifact[0]
   for($stage=0;$stage -lt 2;++$stage){$null=Run $probes[$stage] @('--integers',$path,'ube.stack.frames',$expected) $true
    $checks+=@([pscustomobject]@{assertion='Production UBE data validator rejects understated frame before execution';readerStage=$stage+1;generatorStage=$binding.stage;reference=$binding.reference;optimization=$binding.optimization;debug=$binding.debug;artifact=$artifact[0];passed=$true})
   }
  }
 }
 foreach($input in $inputs){if((Get-ArtifactIdentity $input.path).sha256 -cne $input.sha256){throw ('Input changed during verification: '+$input.path)}}
 $success=$true
}catch{$failure=$_.Exception.Message}
[pscustomobject]@{success=$success;failure=$failure;acceptedSelection=$reader.acceptedSelection;inputs=$inputs;checks=$checks;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Production UBE definition range and immutable integer-data binding against retained independently derived frame tables and controlled reserve 256, both object and linked image, with understatement rejection. Not a current whole-generator build, complete expected-identity inventory, instruction/fixup retention, reserve derivation, stack/debug safety or publication qualification.'}|ConvertTo-Json -Depth 18|Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Evidence: $run/report.json"
if(-not $success){throw $failure}
