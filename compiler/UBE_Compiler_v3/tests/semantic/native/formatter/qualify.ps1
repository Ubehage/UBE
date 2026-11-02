param([string]$SelectionPath='',[string]$Stage1Run='',[string]$Stage2Run='')
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not (Test-Path -LiteralPath (Join-Path $root 'compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE'))){$parent=Split-Path $root -Parent;if(-not $parent -or $parent -ceq $root){throw 'Cannot find repository root'};$root=$parent}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
if(-not $SelectionPath){$SelectionPath=Join-Path $root 'bootstrap/out/v2/current.json'}
$selection=Get-VerifiedBootstrapSelection $SelectionPath
$run=Join-Path $root ('bootstrap/out/semantic-formatter/qualification/'+[Guid]::NewGuid().ToString('N'));$null=New-Item -ItemType Directory $run -Force
$checks=New-Object 'System.Collections.Generic.List[object]';$commands=New-Object 'System.Collections.Generic.List[object]';$evidence=@();$inputs=@();$success=$false;$failure=$null
function Require([bool]$Condition,[string]$Meaning){if(-not $Condition){throw $Meaning};$checks.Add([pscustomobject]@{assertion=$Meaning;passed=$true})}
function Execute([string]$Script,[string[]]$Arguments,[int]$Seconds){$record=Invoke-BoundedProcess 'powershell.exe' (@('-NoProfile','-File',$Script)+$Arguments) $root $Seconds;$commands.Add($record);return $record}
try{
 foreach($file in Get-ChildItem -LiteralPath $PSScriptRoot -File){$inputs+=Get-ArtifactIdentity $file.FullName}
 $inputs+=Get-ArtifactIdentity (Join-Path $root 'compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE')
 $tools=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path);$bases=@($Stage1Run,$Stage2Run);$raw=$null
 for($stage=0;$stage -lt 2;++$stage){
  if(-not $bases[$stage]){$record=Execute (Join-Path $PSScriptRoot 'check.ps1') @('-SelectionPath',$SelectionPath,'-ToolPath',$tools[$stage]) 1200;Require (-not $record.timedOut -and $record.exit -eq 0) "Stage$($stage+1) exact production formatter gate passes";Require ($record.stdout -match '(?m)^Evidence: (.+)/report.json\r?$') 'Formatter report path emitted';$bases[$stage]=$Matches[1].Trim()}
  $path=Join-Path $bases[$stage] 'report.json';$base=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
  Require ([bool]$base.success -and $base.tool.sha256 -ceq (Get-ArtifactIdentity $tools[$stage]).sha256) 'Exact accepted stage used'
  Require ($base.selection.compiler.sha256 -ceq $selection.compiler.sha256 -and $base.selection.manifest.sha256 -ceq $selection.manifest.sha256) 'Accepted selection/compiler manifest basis retained'
  foreach($identity in $base.inputs){Require ((Get-ArtifactIdentity $identity.path).sha256 -ceq $identity.sha256) 'Formatter compiled input unchanged'}
  $actual=$base.commands[-1];Require ($actual.exit -eq 0 -and -not $actual.timedOut -and $actual.stderr -ceq '' -and $actual.stdout -match 'PASS semantic formatter assertions:[0-9]+\n$') 'All independent native formatter assertions pass'
  $rows=@($actual.stdout -split "`n"|Where-Object {$_.StartsWith('{')}|ForEach-Object {$_|ConvertFrom-Json});Require ($rows.Count -eq 11) 'All fixed message/coordinate/domain/fault/root suites executed';foreach($row in $rows){Require ([bool]$row.passed) 'Native formatter suite passed'}
  $identity=Get-ArtifactIdentity (Join-Path $bases[$stage] 'formatter.ll');if($raw){Require ($raw.sha256 -ceq $identity.sha256) 'Both production-stage raw LLVM results are identical'}else{$raw=$identity}
  $controls=@();foreach($control in @('FORMATTER_WRONG_TEXT','FORMATTER_PARTIAL_FALLBACK','FORMATTER_CHANGED_FAILURE')){$record=Execute (Join-Path $PSScriptRoot 'recheck.ps1') @('-BaseRun',$bases[$stage],'-Control',$control) 300;Require (-not $record.timedOut -and $record.stdout -match '(?m)^Formatter recheck: (.+report.json)\r?$') 'Corruption evidence emitted';$controlPath=$Matches[1].Trim();$proof=Get-Content -LiteralPath $controlPath -Raw|ConvertFrom-Json;Require ($proof.compile.exit -eq 0 -and $proof.compile.stderr -ceq '' -and $proof.actual.exit -eq 1 -and -not $proof.actual.timedOut -and $proof.actual.stderr.Contains('formatter assertion')) 'Actual text/partial-fallback/structured-Failure corruption rejected';$controls+=Get-ArtifactIdentity $controlPath}
  $evidence+=[pscustomobject]@{stage=$stage+1;report=(Get-ArtifactIdentity $path);rawLLVM=$identity;controls=$controls}
 }
 foreach($identity in $inputs){Require ((Get-ArtifactIdentity $identity.path).sha256 -ceq $identity.sha256) 'Final formatter gate input unchanged'}
 $null=Get-VerifiedBootstrapSelection $SelectionPath;$success=$true
}catch{$failure=$_.Exception.Message}
finally{[pscustomobject]@{schema='ube-semantic-formatter-native-1';success=$success;qualifiedFormatter=$success;sourceBuildCurrent=$success;acceptedSelection=$selection;failure=$failure;checks=$checks.ToArray();inputs=$inputs;evidence=$evidence;commands=$commands.ToArray();scope='Actual production compiler manifest, retained source/project owner graph and exact formatter. Filesystem discovery and command dispatch have separate process gates.'}|ConvertTo-Json -Depth 25|Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8;Write-Output "Evidence: $run/report.json"}
if(-not $success){throw $failure};Write-Output "PASS: $($checks.Count) exact semantic formatter gate assertions"
