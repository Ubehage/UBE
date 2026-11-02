param([Parameter(Mandatory=$true)][string]$Executable,[string]$SelectionPath='')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath($PSScriptRoot)
while(-not (Test-Path -LiteralPath (Join-Path $root 'bootstrap/tools/verification.ps1'))){$parent=Split-Path $root -Parent;if(-not $parent -or $parent -ceq $root){throw 'Repository root missing'};$root=$parent}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$run=Join-Path $root ('bootstrap/out/semantic-cli-process/'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $run -Force
$utf8=New-Object Text.UTF8Encoding($false,$true)
$checks=New-Object 'System.Collections.Generic.List[object]'
$commands=New-Object 'System.Collections.Generic.List[object]'
$recordChecks=$false
$success=$false;$failure=$null;$inputs=@()
function Assert-Fact([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
# Reuse only the existing independent source/witness validation functions. The
# historical785-count gate itself is not executed or weakened by this harness.
$definitionPath=Join-Path $root 'compiler/UBE_Compiler_v3/tools/check-semantic-contract.ps1'
$ast=[Management.Automation.Language.Parser]::ParseFile($definitionPath,[ref]$null,[ref]$null)
$needed=@('Has','Fields','String','Integer','List','Position','Witness')
foreach($node in $ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst]},$true)){
 if($node.Name -cin $needed){Invoke-Expression $node.Extent.Text}
}
try{
 if(-not $SelectionPath){$SelectionPath=Join-Path $root 'bootstrap/out/v2/current.json'}
 $selection=Get-VerifiedBootstrapSelection $SelectionPath
 $casesPath=Join-Path $root 'compiler/UBE_Compiler_v3/tests/semantic/cases.json'
 $messagesPath=Join-Path $root 'compiler/UBE_Compiler_v3/SEMANTIC-DIAGNOSTICS.md'
 $inputs=@($Executable,$PSCommandPath,$definitionPath,$casesPath,$messagesPath)|ForEach-Object {Get-ArtifactIdentity $_}
 $messages=@{}
 foreach($line in [IO.File]::ReadAllLines($messagesPath)){
  if($line -match '^\|\s*([^|]+?)\s*\|\s*UBE([0-9]{4})\s*\|\s*([^|]+)\|$'){$messages[$Matches[1].Trim()]=[pscustomobject]@{code=$Matches[2];text=$Matches[3].Trim()}}
 }
 $cases=([IO.File]::ReadAllText($casesPath)|ConvertFrom-Json).cases
 $selected=@($cases|Where-Object {$_.sources.Count -eq 1 -and $_.expected.outcome -cne 'frontend'})
 if($selected.Count -ne 186){throw 'The186 independent single-source semantic cases must all be exercised'}
 $index=0
 foreach($case in $selected){
  $source=$case.sources[0];$path=Join-Path $run ('input'+$index+'.bas')
  [IO.File]::WriteAllText($path,$source.source,$utf8)
  $sources=New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
  $sources.Add([string]$source.id,$source)
  $expected='';$exit=0;$where=$null
  if($case.expected.outcome -cne 'checked'){
   $exit=1;$d=$case.expected.diagnostic
   $w=@($case.witnesses|Where-Object id -CEQ $d.at)
   if($w.Count -ne 1 -or -not $messages.ContainsKey([string]$d.kind)){throw 'Missing independent diagnostic/message anchor'}
   $where=Witness $w[0] $sources;$message=$messages[[string]$d.kind]
   $expected='error UBE'+$message.code+': '+$message.text+" (next lines: line, column, byte)`n"+$where.first.line+"`n"+$where.first.column+"`n"+$where.first.byte+"`n"
  }
  $before=@(Get-ChildItem -LiteralPath $run -File|Sort-Object FullName|ForEach-Object {Get-ArtifactIdentity $_.FullName})|ConvertTo-Json -Depth 5 -Compress
  $record=Invoke-BoundedProcess $Executable @('--check',$path) $run 30;$commands.Add($record)
  $after=@(Get-ChildItem -LiteralPath $run -File|Sort-Object FullName|ForEach-Object {Get-ArtifactIdentity $_.FullName})|ConvertTo-Json -Depth 5 -Compress
  $passed=-not $record.timedOut -and $record.exit -eq $exit -and $record.stdout -ceq $expected -and $record.stderr -ceq '' -and $before -ceq $after
  $checks.Add([pscustomobject]@{case=$case.id;passed=$passed;expectedExit=$exit;expected=$expected;actual=$record;witness=$where;noArtifacts=($before -ceq $after)})
  if(-not $passed){throw "Process semantic case failed:$($case.id):$($record|ConvertTo-Json -Depth 5 -Compress); expected exit$exit/output$expected"}
  $index++
 }
 $frontend=@($cases|Where-Object {$_.expected.outcome -ceq 'frontend'})
 if($frontend.Count -ne 3){throw 'All3 retained frontend rejections must be exercised'}
 foreach($case in $frontend){
  $source=$case.sources[0];$path=Join-Path $run ('frontend'+$index+'.bas')
  [IO.File]::WriteAllText($path,$source.source,$utf8)
  $sources=New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
  $sources.Add([string]$source.id,$source)
  $d=$case.expected.diagnostic;$w=@($case.witnesses|Where-Object id -CEQ $d.at)
  if($w.Count -ne 1){throw 'Missing frontend anchor'}
  $where=Witness $w[0] $sources
  switch -CaseSensitive ($d.kind){
   'ExpectedExpression'{$expected="error UBE1201: expected expression (next lines: line, column, byte)`n$($where.first.line)`n$($where.first.column)`n$($where.first.byte)`n"}
   'FrontendDeferred'{$expected="error UBE1200: source syntax family is not implemented (next lines: line, column, byte)`n$($where.first.line)`n$($where.first.column)`n$($where.first.byte)`n"}
   'UnknownReservedAttribute'{$expected="source($($where.first.line),$($where.first.column)): error UBE1100: unknown reserved source attribute at byte $($where.first.byte)`n"}
   default{throw 'Undefined frontend prediction'}
  }
  $record=Invoke-BoundedProcess $Executable @('--check',$path) $run 30;$commands.Add($record)
  $passed=-not $record.timedOut -and $record.exit -eq 1 -and $record.stdout -ceq $expected -and $record.stderr -ceq ''
  $checks.Add([pscustomobject]@{case=$case.id;passed=$passed;expectedExit=1;expected=$expected;actual=$record;witness=$where})
  if(-not $passed){throw "Retained frontend case failed:$($case.id)"}
  $index++
 }
 foreach($usage in @(@(),@('--wrong','x.bas'),@('--check','x.bas','--jobs','2'),@('--check','x.UBE','--jobs','0'))){
  $expected="usage: ube --check <source-file>`n"
  if($usage.Count -ge 2 -and $usage[1].EndsWith('.UBE')){$expected="usage: ube --check <project.UBE> [--jobs N] (N: 1..4)`n"}
  $record=Invoke-BoundedProcess $Executable $usage $run 30;$commands.Add($record)
  $passed=-not $record.timedOut -and $record.exit -eq 2 -and $record.stdout -ceq $expected -and $record.stderr -ceq ''
  $checks.Add([pscustomobject]@{case='usage';passed=$passed;arguments=$usage;actual=$record})
  if(-not $passed){throw 'Existing usage transport changed'}
 }
 foreach($identity in $inputs){if((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256){throw 'Process oracle input changed'}}
 $success=$true
}catch{$failure=$_.Exception.Message}
finally{
 [pscustomobject]@{success=$success;failure=$failure;inputs=$inputs;checks=$checks.ToArray();commands=$commands.ToArray();scope='Exact186 single-source semantic CLI outcomes/messages/coordinates/no-artifacts, all3 retained frontend rejections and4 usage cases, one compiled snapshot. No formatter fault/project/two-stage or complete semantic qualification.'}|ConvertTo-Json -Depth 30|Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
 Write-Output ('Evidence: '+(Join-Path $run 'report.json'))
}
if(-not $success){throw $failure}
Write-Output ('PASS CLI process checks:'+ $checks.Count)
