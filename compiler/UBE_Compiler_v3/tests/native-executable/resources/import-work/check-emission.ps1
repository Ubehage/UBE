param([Parameter(Mandatory=$true)][string]$ReportPath)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))){$root=Split-Path $root -Parent;if(-not $root){throw 'Repository root missing'}}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$ReportPath=[IO.Path]::GetFullPath($ReportPath)
$prior=Get-Content -LiteralPath $ReportPath -Raw|ConvertFrom-Json
if(-not $prior.success){throw 'Retained adapter was not qualified'}
$selection=$prior.acceptedSelection
foreach($identity in @($selection.clang,$selection.unicodeRuntime)){if((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256){throw 'Pinned tool identity mismatch'}}
$run=Join-Path $root ('bootstrap/out/native-import-emission/'+[guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($run)
$inputs=@(Get-ChildItem -LiteralPath $PSScriptRoot -File|ForEach-Object{Get-ArtifactIdentity $_.FullName})
$inputs+=@($ReportPath,(Join-Path $root 'std-lib/tests/file-output/native.c'),(Join-Path $root 'bootstrap/runtime/error_support.c')|ForEach-Object{Get-ArtifactIdentity $_})
$commands=@();$checks=@();$failure=$null
function Run([string]$File,[string[]]$Arguments,[string]$Directory){$r=Invoke-BoundedProcess $File $Arguments $Directory 180;$script:commands+=@($r);if($r.timedOut -or $r.exit -ne 0){throw ($r|ConvertTo-Json -Compress)};return $r}
try {
 foreach($stage in 0..1) {
  $adapter=Join-Path (Split-Path $ReportPath -Parent) ('stage'+$stage+'/adapter.ll')
  $expected=@($prior.artifacts|Where-Object{$_.path -eq $adapter})
  if($expected.Count -ne 1 -or (Get-ArtifactIdentity $adapter).sha256 -cne $expected[0].sha256){throw 'Retained adapter identity mismatch'}
  $inputs+=Get-ArtifactIdentity $adapter
  $directory=Join-Path $run ('stage'+$stage);$null=[IO.Directory]::CreateDirectory($directory)
  $exe=Join-Path $directory 'probe.exe'
  $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu','-std=c17','-O2','-Wall','-Wextra','-Werror','-I',$root,$adapter,(Join-Path $PSScriptRoot 'emission.c'),$selection.unicodeRuntime.path,'-o',$exe) $directory
  $r=Run $exe @((Join-Path $PSScriptRoot 'ImportWork.UBE')) $directory
  if($r.stderr -cne '' -or $r.stdout -notmatch '^PASS actual import work jobs=1 D=42 own=126 imports=210 total=([0-9]+) boundary=-1/0/1\nPASS actual import work jobs=4 D=42 own=126 imports=210 total=\1 boundary=-1/0/1\n$'){throw 'Actual import work oracle failed'}
  $checks+=@([pscustomobject]@{stage=$stage+1;assertion='Exact whole-lowering work, approved own/import bound, -1/0/+1 cap boundary, immutable jobs output and cleanup';passed=$true;output=$r.stdout})
  foreach($optimization in @('O0','O2')) {
   $objects=@()
   foreach($source in 0..10) {
    $input=Join-Path $directory ('import-module-'+$source+'.ll');$object=Join-Path $directory ('import-module-'+$source+'-'+$optimization+'.o')
    $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu',('-'+$optimization),'-c',$input,'-o',$object) $directory;$objects+=$object
   }
   $native=Join-Path $directory ('native-'+$optimization+'.exe')
   $null=Run $selection.clang.path (@('--target=x86_64-w64-windows-gnu',('-'+$optimization),'-std=c17','-Wall','-Wextra','-Werror','-I',$root,'-I',$directory)+$objects+@((Join-Path $PSScriptRoot 'observer.c'),'-o',$native)) $directory
   $r=Run $native @() $directory
   if($r.stdout -cne '' -or $r.stderr -cne ''){throw 'Typed-import native result failed'}
   $checks+=@([pscustomobject]@{stage=$stage+1;assertion='Eleven separately compiled modules; shared twenty-formal signature; Main result 21 and exact Err/revision preservation';optimization=$optimization;passed=$true})
  }
 }
 foreach($input in $inputs){if((Get-ArtifactIdentity $input.path).sha256 -cne $input.sha256){throw 'Accounting input changed'}}
}catch{$failure=$_.Exception.Message}
$artifacts=@(Get-ChildItem -LiteralPath $run -Recurse -File|ForEach-Object{Get-ArtifactIdentity $_.FullName})
[pscustomobject]@{success=($null -eq $failure);failure=$failure;acceptedSelection=$selection;inputs=$inputs;commands=$commands;checks=$checks;artifacts=$artifacts;scope='Actual typed module emission and exact work accounting; independent native calls with controlled completed-initialization/frame metadata, not native builder/process-entry or real platform-stack qualification'}|ConvertTo-Json -Depth 15|Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Evidence: $run/report.json"
if($failure){throw $failure}
