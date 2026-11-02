param([string]$SelectionPath=(Join-Path $PSScriptRoot '../../bootstrap/out/v2/current.json'))
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$run=Join-Path $root ('bootstrap/out/signed-integers/'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $run -Force
$path=Join-Path $run 'report.json';$checks=@();$commands=@();$inputs=@();$nestedReports=@();$selection=$null;$success=$false;$failure=$null
try{
 $selection=Get-VerifiedBootstrapSelection $SelectionPath
 $fixture=Join-Path $root 'std-lib/tests/signed-integers';$module=Join-Path $root 'std-lib/src/portable/SignedIntegers.bas'
 $paths=@($PSCommandPath,$SelectionPath,$module,(Join-Path $root 'std-lib/SIGNED-INTEGER-CONTRACT.md'),(Join-Path $root 'std-lib/UBECore.UBE'),(Join-Path $root 'bootstrap/tools/verification.ps1'))+@(Get-ChildItem -LiteralPath $fixture -File|ForEach-Object FullName)
 $inputs=@($paths|ForEach-Object {Get-ArtifactIdentity $_})
 $checks+=@([pscustomobject]@{assertion='both source-built stages and all current source inputs match immutable accepted selection';passed=$true})
 $shell=Join-Path $PSHOME 'powershell.exe';if(-not (Test-Path -LiteralPath $shell)){$shell=(Get-Process -Id $PID).Path}
 $native=Invoke-BoundedProcess $shell @('-NoProfile','-File',(Join-Path $fixture 'check.ps1'),'-SelectionPath',$SelectionPath,'-ModulePath',$module,'-RequireIntegrated','-OutputRoot',(Join-Path $run 'native')) $root 900
 $commands+=@($native)
 $reports=[regex]::Matches($native.stdout,'(?m)^Evidence: (.+)$')
 if($reports.Count -eq 1){$nestedReports+=@(Get-ArtifactIdentity $reports[0].Groups[1].Value.Trim())}
 if($native.timedOut -or $native.exit -ne 0 -or $native.stderr -cne '' -or $reports.Count -ne 1){throw "Signed integer native gate failed: $($native|ConvertTo-Json -Depth 5 -Compress)"}
 $report=[IO.File]::ReadAllText($nestedReports[0].path)|ConvertFrom-Json
 if(-not $report.success -or -not $report.productionIntegrated -or $report.draftOnly -or -not $report.rawStageIdentity -or $report.records.Count -ne 14){throw 'Signed integer integrated gate is incomplete'}
 if($report.selection.compiler.sha256 -cne $selection.compiler.sha256 -or $report.selection.manifest.sha256 -cne $selection.manifest.sha256 -or $report.source.sha256 -cne (Get-ArtifactIdentity $module).sha256){throw 'Signed integer integrated gate used different sources or source-built tools'}
 $checks+=@([pscustomobject]@{assertion='exact production SignedIntegers module is included by actual direct UBECore reference; only Entry.Main is root';passed=$true})
 foreach($record in $report.records){
  if(-not $record.passed){throw 'Signed integer native assertion/control failed'}
  $assertion='source-built stage'+$record.stage+': '+$record.variant
  $checks+=@([pscustomobject]@{assertion=$assertion;passed=$true;stage=$record.stage;variant=$record.variant;native=$record.native})
 }
 $checks+=@([pscustomobject]@{assertion='both source-built stages emit byte-identical intact raw LLVM for integrated SignedIntegers project';passed=$true})
 foreach($identity in $inputs){$actual=Get-ArtifactIdentity $identity.path;if($actual.sha256 -cne $identity.sha256 -or $actual.bytes -ne $identity.bytes){throw "Maintained numeric gate input changed: $($identity.path)"}}
 $null=Get-VerifiedBootstrapSelection $SelectionPath
 $checks+=@([pscustomobject]@{assertion='all maintained module/fixture/header/contract/runner and accepted source/tool identities remain unchanged';passed=$true})
 $success=$true
}catch{$failure=$_.Exception.Message}
finally{
 [pscustomobject]@{schema='ube-signed-integers-1';success=$success;failure=$failure;acceptedSelection=$selection;sourceBuildCurrent=$success;productionIntegrated=$success;inputs=$inputs;checks=$checks;commands=$commands;nestedReports=$nestedReports;artifacts=@(Get-ChildItem -LiteralPath $run -Recurse -File|Where-Object FullName -CNE $path|ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Actual Core-included ordinary UBE numeric module through both accepted source-built stages. Independent native values, bounded executed work, complete observable Err, root/heap/copy/allocation controls and actual capacity denial. UBE worker sharing is qualified separately; no compiler literal or semantic behavior is claimed.'}|ConvertTo-Json -Depth 32|Set-Content -LiteralPath $path -Encoding UTF8
 Write-Output "Evidence: $path"
}
if(-not $success){throw $failure}
Write-Output "PASS signed integers: $($checks.Count) gate assertions"
