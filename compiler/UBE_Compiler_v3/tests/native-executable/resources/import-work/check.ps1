param()
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))){$root=Split-Path $root -Parent;if(-not $root){throw 'Repository root missing'}}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$priorPath=Join-Path $root 'bootstrap/out/native-graph/1d61ea91bdbd4e3f9bfb6bc15df92ed0/report.json'
$prior=Get-Content -LiteralPath $priorPath -Raw|ConvertFrom-Json
if(-not $prior.success){throw 'Retained adapter was not qualified'}
$adapter=Join-Path (Split-Path $priorPath -Parent) 'stage1/adapter.ll'
$expected=@($prior.artifacts|Where-Object{$_.path -eq $adapter})
if($expected.Count -ne 1 -or (Get-ArtifactIdentity $adapter).sha256 -cne $expected[0].sha256){throw 'Retained adapter identity mismatch'}
$selection=$prior.acceptedSelection
foreach($identity in @($selection.clang,$selection.unicodeRuntime)){if((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256){throw 'Pinned tool identity mismatch'}}
$run=Join-Path $root ('bootstrap/out/native-import-work/'+[guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($run)
$inputs=@(Get-ChildItem -LiteralPath $PSScriptRoot -File|ForEach-Object{Get-ArtifactIdentity $_.FullName})
$inputs+=@($priorPath,$adapter,(Join-Path $root 'std-lib/tests/file-output/native.c')|ForEach-Object{Get-ArtifactIdentity $_})
$commands=@();$failure=$null
function Run([string]$File,[string[]]$Arguments){$r=Invoke-BoundedProcess $File $Arguments $run 180;$script:commands+=@($r);if($r.timedOut -or $r.exit -ne 0){throw ($r|ConvertTo-Json -Compress)};return $r}
try{
 $exe=Join-Path $run 'probe.exe'
 $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu','-std=c17','-O2','-Wall','-Wextra','-Werror','-I',$root,$adapter,(Join-Path $PSScriptRoot 'probe.c'),$selection.unicodeRuntime.path,'-o',$exe)
 $r=Run $exe @((Join-Path $PSScriptRoot 'ImportWork.UBE'))
 $expectedOutput="PASS import work jobs=1 D=42 own=93 imports=210 minimum=303 bound=126`nPASS import work jobs=4 D=42 own=93 imports=210 minimum=303 bound=126`n"
 if($r.stdout -cne $expectedOutput -or $r.stderr -cne ''){throw 'Import accounting oracle failed'}
 foreach($input in $inputs){if((Get-ArtifactIdentity $input.path).sha256 -cne $input.sha256){throw 'Accounting input changed'}}
}catch{$failure=$_.Exception.Message}
[pscustomobject]@{success=($null -eq $failure);failure=$failure;inputs=$inputs;commands=$commands;artifact=(Get-ArtifactIdentity $exe);scope='Actual retained qualified checker/declaration inventory at jobs 1 and 4; necessary typed-import work counterexample, not implemented module emission or native resource acceptance'}|ConvertTo-Json -Depth 15|Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Evidence: $run/report.json"
if($failure){throw $failure}
