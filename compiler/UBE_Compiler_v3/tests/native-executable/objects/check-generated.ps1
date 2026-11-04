param([Parameter(Mandatory=$true)][string]$ReaderReport,[Parameter(Mandatory=$true)][string]$FramesReport)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))){$root=Split-Path $root -Parent;if(-not $root){throw 'Repository root missing'}}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$reader=Get-Content -LiteralPath $ReaderReport -Raw|ConvertFrom-Json
$frames=Get-Content -LiteralPath $FramesReport -Raw|ConvertFrom-Json
if(-not $reader.success -or -not $frames.success -or $frames.bindings.Count -ne 16){throw 'Passing reader and complete frame-artifact matrix required'}
if($reader.acceptedSelection.compiler.sha256 -cne $frames.acceptedSelection.compiler.sha256){throw 'Bootstrap selection mismatch'}
$run=Join-Path $root ('bootstrap/out/native-object-inputs/'+[guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($run)
$inputs=@((Get-ArtifactIdentity $ReaderReport),(Get-ArtifactIdentity $FramesReport),(Get-ArtifactIdentity $PSCommandPath),(Get-ArtifactIdentity (Join-Path $root 'bootstrap/tools/verification.ps1')))
$commands=@();$checks=@();$success=$false;$failure=$null
function Retain($Identity){
 $actual=Get-ArtifactIdentity $Identity.path
 if($actual.sha256 -cne $Identity.sha256 -or $actual.bytes -ne $Identity.bytes){throw ('Input identity changed: '+$Identity.path)}
 $script:inputs+=@($actual);return $actual.path
}
function Run([string]$File,[string]$Path){
 $r=Invoke-BoundedProcess $File @($Path) $run 30;$script:commands+=@($r)
 if($r.timedOut -or $r.exit -ne 0 -or $r.stderr -cne ''){throw ($r|ConvertTo-Json -Compress)};return $r.stdout
}
try {
 # Current reader source and its instrumented executables must still match.
 # Frame artifacts are retained historical outputs; this does not requalify
 # their generating sources or the current complete compiler manifest.
 foreach($input in $reader.inputs){$null=Retain $input}
 $oracle=@($reader.artifacts|Where-Object {(Split-Path $_.path -Leaf) -ceq 'oracle.exe'});if($oracle.Count -ne 1){throw 'Unique independent oracle missing'};$oracle=Retain $oracle[0]
 $probes=@();foreach($stage in 0..1){$probe=@($reader.artifacts|Where-Object {(Split-Path $_.path -Leaf) -ceq ('stage'+$stage+'-probe.exe')});if($probe.Count -ne 1){throw 'Unique reader executable missing'};$probes+=Retain $probe[0]}
 foreach($binding in $frames.bindings){
  if($binding.objects.Count -ne 5){throw 'Complete module/entry/platform object inventory required'}
  foreach($artifact in @($binding.objects)+@($binding.table,$binding.image)){
   $path=Retain $artifact;$expected=Run $oracle $path
   for($stage=0;$stage -lt 2;++$stage){$actual=Run $probes[$stage] $path;if($actual -cne $expected){throw ('Generated artifact reader differs from SDK oracle: '+$path)}
    $checks+=@([pscustomobject]@{assertion='Production reader agrees on generated UBE artifact';readerStage=$stage+1;generatorStage=$binding.stage;reference=$binding.reference;optimization=$binding.optimization;debug=$binding.debug;artifact=$artifact;passed=$true})
   }
  }
 }
 foreach($input in $inputs){if((Get-ArtifactIdentity $input.path).sha256 -cne $input.sha256){throw ('Input changed during verification: '+$input.path)}}
 $success=$true
}catch{$failure=$_.Exception.Message}
[pscustomobject]@{success=$success;failure=$failure;acceptedSelection=$reader.acceptedSelection;inputs=$inputs;checks=$checks;commands=$commands;scope='Current production binary readers over retained generated module/entry/platform/frame objects and bound images: exact SDK header/section/name/symbol comparisons and relocation count/digest comparisons. Historical generator artifacts only; not current whole-compiler, complete binding, instruction/stack/debug or publication qualification.'}|ConvertTo-Json -Depth 18|Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Evidence: $run/report.json"
if(-not $success){throw $failure}
