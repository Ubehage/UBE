param([Parameter(Mandatory=$true)][string]$Executable,[string]$SelectionPath='')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath($PSScriptRoot)
while(-not (Test-Path -LiteralPath (Join-Path $root 'bootstrap/tools/verification.ps1'))){$parent=Split-Path $root -Parent;if(-not $parent -or $parent -ceq $root){throw 'Repository root missing'};$root=$parent}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$run=Join-Path $root ('bootstrap/out/semantic-cli-project-process/'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $run -Force
$utf8=New-Object Text.UTF8Encoding($false,$true)
$checks=New-Object 'System.Collections.Generic.List[object]'
$commands=New-Object 'System.Collections.Generic.List[object]'
$recordChecks=$false
$success=$false;$failure=$null;$inputs=@()
function Assert-Fact([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
$definitionPath=Join-Path $root 'compiler/UBE_Compiler_v3/tools/check-semantic-contract.ps1'
$ast=[Management.Automation.Language.Parser]::ParseFile($definitionPath,[ref]$null,[ref]$null)
$needed=@('Has','Fields','String','Integer','List','Position','Witness')
foreach($node in $ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst]},$true)){
 if($node.Name -cin $needed){Invoke-Expression $node.Extent.Text}
}
function Quote-ProjectPath([string]$Path){
 $builder=New-Object Text.StringBuilder
 [void]$builder.Append('"')
 foreach($ch in $Path.ToCharArray()){
  $n=[int]$ch
  if($n -lt 32 -or $n -eq 127){[void]$builder.Append(('\x{0:X2}' -f $n))}
  else{if($n -eq 34 -or $n -eq 92){[void]$builder.Append('\')};[void]$builder.Append($ch)}
 }
 [void]$builder.Append('"')
 return $builder.ToString()
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
 $selected=@($cases|Where-Object {$_.sources.Count -gt 1})
 if($selected.Count -ne 16){throw 'All16 independent multi-source semantic cases must be exercised'}
 foreach($case in $selected){
  $directory=Join-Path $run $case.id
  $null=New-Item -ItemType Directory -Path $directory
  $sources=New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
  $paths=@{}
  $rootLines=@('UBE-Project 1','Name = "SemanticProjectFixture"','Kind = "Exe"','Startup = "Main"')
  $libraryLines=@('UBE-Project 1','Name = "UBECore"','Kind = "Library"')
  $reference=$false
  foreach($source in $case.sources){
   $name=$source.id+'.bas';$path=Join-Path $directory $name
   [IO.File]::WriteAllText($path,$source.source,$utf8)
   $sources.Add([string]$source.id,$source);$paths[[string]$source.id]=$path.Replace('\','/')
   if($source.package -ceq 'app'){$rootLines+='Source = "'+$name+'"'}
   else{$reference=$true;$libraryLines+='Source = "'+$name+'"'}
  }
  if($reference){$rootLines+='Reference = "UBECore.UBE"';[IO.File]::WriteAllText((Join-Path $directory 'UBECore.UBE'),($libraryLines -join "`n")+"`n",$utf8)}
  $project=Join-Path $directory 'App.UBE'
  [IO.File]::WriteAllText($project,($rootLines -join "`n")+"`n",$utf8)
  $expected='';$exit=0;$where=$null
  if($case.expected.outcome -cne 'checked'){
   $exit=1;$d=$case.expected.diagnostic
   $w=@($case.witnesses|Where-Object id -CEQ $d.at)
   if($w.Count -ne 1 -or -not $messages.ContainsKey([string]$d.kind)){throw 'Missing independent diagnostic/message anchor'}
   $where=Witness $w[0] $sources;$message=$messages[[string]$d.kind]
   $expected=(Quote-ProjectPath $paths[[string]$w[0].source])+"`n"+'error UBE'+$message.code+': '+$message.text+" (next lines: line, column, byte)`n"+$where.first.line+"`n"+$where.first.column+"`n"+$where.first.byte+"`n"
  }
  foreach($jobs in @(1,2,4)){
   $before=@(Get-ChildItem -LiteralPath $directory -Recurse -File|Sort-Object FullName|ForEach-Object {Get-ArtifactIdentity $_.FullName})|ConvertTo-Json -Depth 5 -Compress
   $record=Invoke-BoundedProcess $Executable @('--check',$project,'--jobs',[string]$jobs) $directory 60
   $commands.Add($record)
   $after=@(Get-ChildItem -LiteralPath $directory -Recurse -File|Sort-Object FullName|ForEach-Object {Get-ArtifactIdentity $_.FullName})|ConvertTo-Json -Depth 5 -Compress
   $noArtifacts=$before -ceq $after
   $passed=-not $record.timedOut -and $record.exit -eq $exit -and $record.stdout -ceq $expected -and $record.stderr -ceq '' -and $noArtifacts
   $checks.Add([pscustomobject]@{case=$case.id;jobs=$jobs;passed=$passed;expectedExit=$exit;expected=$expected;actual=$record;witness=$where;noArtifacts=$noArtifacts})
   if(-not $passed){throw "Project CLI failed:$($case.id), jobs$jobs :$($record|ConvertTo-Json -Depth 5 -Compress); expected exit$exit/output$expected"}
  }
 }
 foreach($identity in $inputs){if((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256){throw 'Project process oracle input changed'}}
 $success=$true
}catch{$failure=$_.Exception.Message}
finally{
 [pscustomobject]@{success=$success;failure=$failure;inputs=$inputs;checks=$checks.ToArray();commands=$commands.ToArray();scope='All16 independent multi-source CLI cases at jobs1/2/4: exact outcomes, messages, owning paths, coordinates and no artifacts. One compiled snapshot; native overlap and fault qualification are separate.'}|ConvertTo-Json -Depth 30|Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
 Write-Output ('Evidence: '+(Join-Path $run 'report.json'))
}
if(-not $success){throw $failure}
Write-Output ('PASS project CLI process checks:'+ $checks.Count)
