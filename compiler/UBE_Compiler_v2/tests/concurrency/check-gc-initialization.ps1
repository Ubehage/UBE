param([switch]$ExpectFatal,[string]$SelectionPath='')

# Reproduce the exact fatal before case and retain the controlled after assertion.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$selection=Get-Content -LiteralPath (Join-Path $root 'bootstrap/out/v2/current.json') -Raw | ConvertFrom-Json
$acceptedSelection=$null
if($SelectionPath -ne ''){$selection=Get-VerifiedBootstrapSelection $SelectionPath;$acceptedSelection=$selection}
$run=Join-Path $root ('bootstrap/out/gc-initialization/'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$probe=Join-Path $PSScriptRoot 'gc_initialization_probe.c'
$exe=Join-Path $run 'probe.exe'
$link=Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2',$probe,$selection.unicodeRuntime.path,'-o',$exe) $root 60
if($link.timedOut -or $link.exit -ne 0){throw ('Probe link: '+$link.stderr)}
$native=Invoke-BoundedProcess $exe @() $root 10
if($ExpectFatal){$success=(-not $native.timedOut -and $native.exit -eq 70 -and $native.stderr -match 'could not initialize collector lock')}
else{$success=(-not $native.timedOut -and $native.exit -eq 0 -and $native.stdout.Replace("`r",'') -ceq "PASS managed initialization without callback event; source admission fails cleanly`n" -and $native.stderr -ceq '')}
$inputs=@($probe,(Join-Path $root 'runtime/bootstrap_runtime.c'),(Join-Path $root 'runtime/value_storage.h'),(Join-Path $root 'std-lib/src/win-lib/thread_primitives.c'),(Join-Path $root 'std-lib/src/win-lib/file_primitives.c') | ForEach-Object {Get-ArtifactIdentity $_})
if($null -ne $acceptedSelection){$null=Get-VerifiedBootstrapSelection $SelectionPath}
$checks=@();if($success){$checks=@([pscustomobject]@{passed=$true;assertion='denied callback event leaves managed initialization available and source admission controlled'})}
$report=[pscustomobject]@{success=$success;acceptedSelection=$acceptedSelection;checks=$checks;reproducedFatal=[bool]$ExpectFatal;qualifiedConcurrency=$false;inputs=$inputs;link=$link;native=$native;exe=(Get-ArtifactIdentity $exe)}
$path=Join-Path $run 'report.json';$report | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $path -Encoding UTF8
Write-Output ('Evidence: '+$path)
if(-not $success){throw ('Initialization regression: '+($native | ConvertTo-Json -Compress))}
Write-Output ('PASS initialization regression; reproduced fatal='+[bool]$ExpectFatal)
