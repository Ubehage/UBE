param([string]$SelectionPath='')
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$repo=[IO.Path]::GetFullPath($PSScriptRoot)
while(-not (Test-Path -LiteralPath (Join-Path $repo 'bootstrap/tools/verification.ps1'))){$parent=Split-Path $repo -Parent;if(-not $parent -or $parent -ceq $repo){throw 'Repository root missing'};$repo=$parent}
. (Join-Path $repo 'bootstrap/tools/verification.ps1')
if(-not $SelectionPath){$SelectionPath=Join-Path $repo 'bootstrap/out/v2/current.json'}
$selection=Get-VerifiedBootstrapSelection $SelectionPath
$fixture=Join-Path $repo 'compiler/UBE_Compiler_v3/tests/semantic/native/cli'
$manifest=Join-Path $repo 'compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE'
$run=Join-Path $repo ('bootstrap/out/semantic-cli/'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $run -Force
$powershell=(Get-Process -Id $PID).Path
$utf8=New-Object Text.UTF8Encoding($false,$true)
$commands=New-Object 'System.Collections.Generic.List[object]'
$proofs=New-Object 'System.Collections.Generic.List[object]'
$checks=New-Object 'System.Collections.Generic.List[object]'
$programs=New-Object 'System.Collections.Generic.List[object]'
$inputs=@();$success=$false;$failure=$null
function Manifest-Inputs([string]$Path){
 $Path
 foreach($line in [IO.File]::ReadAllLines($Path)){
  if($line -match '^Source = "([^"]+)"$'){[IO.Path]::GetFullPath((Join-Path (Split-Path $Path -Parent) $Matches[1]))}
  if($line -match '^Reference = "([^"]+)"$'){Manifest-Inputs ([IO.Path]::GetFullPath((Join-Path (Split-Path $Path -Parent) $Matches[1])))}
 }
}
function Invoke-Recorded([string]$File,[string[]]$Arguments,[int]$Timeout){
 $r=Invoke-BoundedProcess $File $Arguments $repo $Timeout;$commands.Add($r)
 if($r.timedOut -or $r.exit -ne 0){throw "Semantic CLI command failed:$($r|ConvertTo-Json -Depth 8 -Compress)"}
 return $r
}
try{
 $paths=@(Manifest-Inputs $manifest)+@($PSCommandPath,(Join-Path $repo 'compiler/UBE_Compiler_v3/tests/semantic/cases.json'),(Join-Path $repo 'compiler/UBE_Compiler_v3/SEMANTIC-DIAGNOSTICS.md'),(Join-Path $repo 'compiler/UBE_Compiler_v3/tools/check-semantic-contract.ps1'),(Join-Path $repo 'compiler/UBE_Compiler_v3/tests/semantic/native/observer.ps1'),(Join-Path $repo 'std-lib/tests/managed-storage/copy-probe.h'))+@(Get-ChildItem -LiteralPath $fixture -File|ForEach-Object FullName)
 $inputs=@($paths|Sort-Object -Unique|ForEach-Object {Get-ArtifactIdentity $_})
 $tools=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
 $raws=@()
 for($i=0;$i -lt 2;$i++){
  $stage=$i+1;$directory=Join-Path $run ('stage'+$stage);$null=New-Item -ItemType Directory -Path $directory
  $raw=Join-Path $directory 'compiler.ll';$exe=Join-Path $directory 'ube.exe'
  $null=Invoke-Recorded $tools[$i] @($manifest,$raw) 900
  $null=Invoke-Recorded $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2',$raw,$selection.runtime.path,$selection.unicodeRuntime.path,'-o',$exe) 300
  $raws+=Get-ArtifactIdentity $raw;$programs.Add((Get-ArtifactIdentity $exe))
  foreach($gate in @('check-process.ps1','check-project-process.ps1','check-faults.ps1')){
   $arguments=@('-NoProfile','-File',(Join-Path $fixture $gate),'-Executable',$exe)
   if($gate -ceq 'check-faults.ps1'){$arguments=@('-NoProfile','-File',(Join-Path $fixture $gate),'-RawPath',$raw)}
   $arguments+=@('-SelectionPath',$SelectionPath)
   $r=Invoke-Recorded $powershell $arguments 900
   $matches=[regex]::Matches($r.stdout,'(?m)^Evidence: (.+?)\r?$')
   if($matches.Count -ne 1){throw 'Each maintained semantic CLI gate must report one evidence path'}
   $path=$matches[0].Groups[1].Value;$proof=[IO.File]::ReadAllText($path,$utf8)|ConvertFrom-Json
   if(-not $proof.success -or $proof.checks.Count -eq 0 -or @($proof.checks|Where-Object {-not $_.passed}).Count -gt 0){throw 'Child semantic CLI proof failed/incomplete'}
   $proofs.Add([pscustomobject]@{stage=$stage;gate=$gate;report=(Get-ArtifactIdentity $path);checks=$proof.checks.Count})
   $checks.Add([pscustomobject]@{assertion="Stage$stage $gate complete independent child checks passed";passed=$true;count=$proof.checks.Count;report=(Get-ArtifactIdentity $path)})
  }
 }
 if($raws[0].sha256 -cne $raws[1].sha256 -or $raws[0].bytes -ne $raws[1].bytes){throw 'Source-built stages must emit identical CLI LLVM'}
 $checks.Add([pscustomobject]@{assertion='Both source-built stages emit byte-identical production CLI LLVM';passed=$true})
 foreach($input in $inputs){$now=Get-ArtifactIdentity $input.path;if($now.sha256 -cne $input.sha256 -or $now.bytes -ne $input.bytes){throw "Semantic CLI input changed:$($input.path)"}}
 foreach($artifact in @($raws)+@($programs.ToArray())+@($proofs.ToArray()|ForEach-Object report)){
  $now=Get-ArtifactIdentity $artifact.path
  if($now.sha256 -cne $artifact.sha256 -or $now.bytes -ne $artifact.bytes){throw 'Semantic CLI generated artifact/proof changed'}
 }
 $null=Get-VerifiedBootstrapSelection $SelectionPath
 $checks.Add([pscustomobject]@{assertion='Complete production, fixture, source-built tool and generated artifact identities remain pinned';passed=$true})
 $success=$true
}catch{$failure=$_.Exception.Message}
finally{
 [pscustomobject]@{schema='ube-semantic-cli-1';success=$success;qualified=$success;sourceBuildCurrent=$success;acceptedSelection=$selection;inputs=$inputs;productionExecutables=$programs.ToArray();proofs=$proofs.ToArray();checks=$checks.ToArray();commands=$commands.ToArray();failure=$failure;scope='Both exact source-built CLI stages: all186 single-source semantic cases,3 retained frontend rejections,4 usage cases; all16 actual projects at jobs1/2/4; actual Main/dispatch allocation/root/file-retention failures and complete process resource cleanup. Independent complete semantic graph and native worker-overlap qualification remain separate maintained gates.'}|ConvertTo-Json -Depth 24|Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
 Write-Output ('Evidence: '+(Join-Path $run 'report.json'))
}
if(-not $success){throw $failure}
Write-Output 'PASS semantic CLI: both source-built stages and six maintained child proofs.'
