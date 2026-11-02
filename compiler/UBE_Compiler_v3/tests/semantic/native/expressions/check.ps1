param([string]$SelectionPath='',[int[]]$Stages=@(1,2),[string]$ImplementationDirectory='')
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))){$parent=Split-Path $root -Parent;if(-not $parent -or $parent -eq $root){throw 'Repository root not found'};$root=$parent}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
. (Join-Path $root 'compiler/UBE_Compiler_v3/tests/semantic/native/abi.ps1')
. (Join-Path $root 'compiler/UBE_Compiler_v3/tests/semantic/native/project.ps1')
if(-not $SelectionPath){$SelectionPath=Join-Path $root 'bootstrap/out/v2/current.json'}
$run=Join-Path $root ('bootstrap/out/semantic-expressions/'+[Guid]::NewGuid().ToString('N'));$project=Join-Path $run 'project';$null=New-Item -ItemType Directory -Path $project -Force
$utf8=New-Object Text.UTF8Encoding($false);$selection=$null;$inputs=@();$commands=@();$records=@();$success=$false;$failure=$null;$mapping=$null
try {
 $selection=Get-VerifiedBootstrapSelection $SelectionPath
 $inputs+=Get-ArtifactIdentity $SelectionPath
 foreach($property in $selection.PSObject.Properties){if($property.Name -cne 'schema'){$inputs+=$property.Value}}
 $lines=@('UBE-Project 1','Name = "SemanticExpressionFixture"','Kind = "Exe"','Startup = "Main"')
 $base=Join-Path $root 'compiler/UBE_Compiler_v3'
 foreach($line in [IO.File]::ReadAllLines((Join-Path $base 'UBE_Compiler_v3.UBE'))){if($line -match '^Source = "([^"]+)"$'){
  $origin=Join-Path $base $Matches[1];$name=Split-Path $origin -Leaf;$text=[IO.File]::ReadAllText($origin)
  if($ImplementationDirectory -and $name -like 'Semantic*'){continue}
  if($ImplementationDirectory -and $name -in @('SourceDiagnostics.bas','ProjectDisplay.bas','ProjectDiagnostics.bas','CommandDispatch.bas','Main.bas')){continue}
  if($name -ceq 'Main.bas'){$text=[regex]::Replace($text,'(?ms)^Function Main\(\) As Long\r?\n.*?^End Function\r?\n?','')}
  [IO.File]::WriteAllText((Join-Path $project $name),$text,$utf8);$inputs+=Get-ArtifactIdentity $origin;$lines+='Source = "'+$name+'"'
 }}
 $draft=$ImplementationDirectory
 if($ImplementationDirectory){
 foreach($directory in @('model','catalog','expressions','constants','calls')){
  foreach($origin in @(Get-ChildItem -LiteralPath (Join-Path $draft $directory) -File|Where-Object {$_.Name -like 'Semantic*' -and $_.Extension -in @('.bas','.cls')}|Sort-Object Name)){
   [IO.File]::Copy($origin.FullName,(Join-Path $project $origin.Name));$inputs+=Get-ArtifactIdentity $origin.FullName;$lines+='Source = "'+$origin.Name+'"'
  }
 }
 }
 $origin=Join-Path $PSScriptRoot 'CatalogHelpers.bas';$text=[regex]::Replace([IO.File]::ReadAllText($origin),'(?ms)^Function Main\(\) As Long\r?\n.*?^End Function\r?\n?','');[IO.File]::WriteAllText((Join-Path $project 'CatalogHelpers.bas'),$text,$utf8);$inputs+=Get-ArtifactIdentity $origin;$lines+='Source = "CatalogHelpers.bas"'
 foreach($name in @('Entry.bas','probe.c')){$origin=Join-Path $PSScriptRoot $name;[IO.File]::Copy($origin,(Join-Path $project $name));$inputs+=Get-ArtifactIdentity $origin};$lines+='Source = "Entry.bas"'
 $library=Join-Path $root 'std-lib/UBECore.UBE';$reference=[Uri]::UnescapeDataString(([Uri]($project.TrimEnd('\')+'\')).MakeRelativeUri([Uri]$library).ToString());$lines+='Reference = "'+$reference+'"'
 $manifest=Join-Path $project 'Expression.UBE';[IO.File]::WriteAllText($manifest,($lines -join "`n")+"`n",$utf8)
 $sources=@(Get-FoundationProjectSources $manifest);$procedures=@{};$types=@{};$classes=@();$ordinal=0
 foreach($source in $sources){$text=[IO.File]::ReadAllText($source);if($text -match '^UBE SOURCE 1 CLASS'){$null=$text -match 'Attribute UBE_Name = "([^"]+)"';$classes+=$Matches[1]};foreach($m in [regex]::Matches($text,'(?m)^(?:(?:Public|Private|Friend) )?(?:Intrinsic )?(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)\b')){$name=$m.Groups[1].Value;if($procedures.ContainsKey($name)){throw "Duplicate expression procedure $name"};$procedures[$name]='ube.p'+$ordinal;++$ordinal}}
 $ordinal=0;foreach($name in $classes){$types[$name]='%ube.type.'+$ordinal;++$ordinal};foreach($source in $sources){foreach($m in [regex]::Matches([IO.File]::ReadAllText($source),'(?m)^Type ([A-Za-z_][A-Za-z_0-9]*)\b')){$types[$m.Groups[1].Value]='%ube.type.'+$ordinal;++$ordinal}}
 $mapping=[pscustomobject]@{procedures=$procedures;types=$types};$inputs+=@($sources|ForEach-Object{Get-ArtifactIdentity $_})+@((Get-ArtifactIdentity $library),(Get-ArtifactIdentity $PSCommandPath),(Get-ArtifactIdentity (Join-Path $root 'compiler/UBE_Compiler_v3/tests/semantic/native/abi.ps1')),(Get-ArtifactIdentity (Join-Path $root 'compiler/UBE_Compiler_v3/tests/semantic/native/project.ps1')))
 foreach($stage in $Stages){
  if($stage -notin @(1,2)){throw 'Invalid diagnostic stage selection'}
  $tool=$selection.compiler.path;if($stage -eq 1){$tool=Join-Path (Split-Path $tool -Parent) 'ube-stage1-v2.exe'};$inputs+=Get-ArtifactIdentity $tool
  $stem=Join-Path $run ('stage'+$stage);$rawPath=$stem+'.ll';$emitSeconds=if($ImplementationDirectory){600}else{900};$record=Invoke-BoundedProcess $tool @($manifest,$rawPath) $root $emitSeconds;$commands+=@($record);if($record.timedOut -or $record.exit -ne 0){throw ($record|ConvertTo-Json -Compress)}
  $raw=[IO.File]::ReadAllText($rawPath);$adapter=New-Object Text.StringBuilder
  $null=Assert-FoundationRecord $raw $mapping 'SemanticExpressionInfo' 'i32, i32, i32, i32, i64, i32, i32, i32, i32, i32, i32'
  $null=Assert-FoundationRecord $raw $mapping 'SemanticFact' 'i32, i32, i32, i32, i64, i32, i32, i32, i32, i32, i32'
  $null=Assert-FoundationRecord $raw $mapping 'BoundNode' 'i32, i32, i32, i32, i64, i32, i32, i32, i32, i32, i32'
  $null=Assert-FoundationRecord $raw $mapping 'SemanticDeclaration' 'i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i64'
  $null=Assert-FoundationRecord $raw $mapping 'SemanticModuleWork' ('ptr, ptr, ptr, '+$types.SemanticLimits+', i32, i32, ptr, i32, ptr, i32, i32, i32, '+$types.SemanticFailure+', '+$types.SemanticFailure+', '+$types.SemanticMetrics+', ptr, i64, i32')
  Add-FoundationBinding $adapter $raw $mapping 'expression_check' 'TryCheckExpressionFixture' 'i1' 'ptr,i32,i32,i32,i32,i32,i1,ptr,ptr,ptr'
  Add-FoundationBinding $adapter $raw $mapping 'expression_syntax' 'TryReadSemanticSyntax' 'i1' 'ptr,i32,ptr'
  Add-FoundationBinding $adapter $raw $mapping 'expression_pair' 'TryCheckExpressionFixturePair' 'i1' 'ptr,ptr,i32,i32,i32,i32,i32,i1,ptr,ptr,ptr'
  Add-FoundationBinding $adapter $raw $mapping 'expression_origin' 'TryReadExpressionFixtureOrigin' 'i1' 'ptr,i32,i32,ptr'
  Add-FoundationBinding $adapter $raw $mapping 'expression_declaration' 'TryReadSemanticDeclaration' 'i1' 'ptr,i32,ptr'
  $adapted=$stem+'-native.ll';[IO.File]::WriteAllText($adapted,$raw.Replace('define i32 @main(','define i32 @expression_unused_main(')+"`n"+$adapter.ToString(),$utf8)
  foreach($control in @('','EXPECTED','MISSING_FACT')){
   $suffix='native';$defines=@();if($control){$suffix='negative-'+$control.ToLowerInvariant();$defines=@('-DEXPRESSION_'+$control+'_CONTROL')}
   $exe=$stem+'-'+$suffix+'.exe';$record=Invoke-BoundedProcess $selection.clang.path (@('--target=x86_64-w64-windows-gnu','-O2','-I',(Join-Path $root 'bootstrap/runtime'),'-x','ir',$adapted,'-x','c',(Join-Path $project 'probe.c'),'-std=c11','-Wall','-Wextra','-Werror')+$defines+@('-x','none',$selection.runtime.path,$selection.unicodeRuntime.path,'-o',$exe)) $root 150;$commands+=@($record);if($record.timedOut -or $record.exit -ne 0){throw ($record|ConvertTo-Json -Compress)}
   $record=Invoke-BoundedProcess $exe @() $root 300;$commands+=@($record);$records+=@([pscustomobject]@{stage=$stage;control=$control;raw=(Get-ArtifactIdentity $rawPath);native=$record})
   if($control){if($record.timedOut -or $record.exit -ne 1 -or -not $record.stderr.Contains('expression assertion')){throw 'Independent expression corruption control not rejected'}}else{if($record.timedOut -or $record.exit -ne 0 -or $record.stderr -cne '' -or $record.stdout -notmatch 'PASS expression native cases:37 seeds:2 assertions:[0-9]+\n$'){throw ($record|ConvertTo-Json -Compress)}}
  }
 }
 $positive=@($records|Where-Object control -CEQ '');if($positive.Count -eq 2){if($positive[0].raw.sha256 -cne $positive[1].raw.sha256 -or $positive[0].native.stdout -cne $positive[1].native.stdout){throw 'Source-built stages differ'}}
 $success=$true
}catch{$failure=$_.Exception.Message}
finally{[pscustomobject]@{success=$success;failure=$failure;diagnosticOnly=([bool]$ImplementationDirectory -or (($Stages|Sort-Object)-join ',') -cne '1,2');qualified=($success -and -not $ImplementationDirectory -and (($Stages|Sort-Object)-join ',') -ceq '1,2');schema='ube-semantic-expressions-evidence-1';acceptedSelection=$selection;acceptedToolSelection=$selection;checks=@([pscustomobject]@{assertion='Exact independent expression/call/constant cases and corruption controls through the selected stages';passed=$success});inputs=$inputs;mapping=$mapping;commands=$commands;records=$records;artifacts=@(Get-ChildItem -LiteralPath $run -File -Recurse|ForEach-Object{Get-ArtifactIdentity $_.FullName});limits='Actual production expression/call/constant/catalog bodies by default; optional explicitly selected draft override with actual maintained Core and parser; independent functional examples only. This does not qualify full checker/coordinator, all205 cases, budgets/faults/copies/concurrency or production adoption. Test fixture copies source only during admission. Both stages required for stage equality claim.'}|ConvertTo-Json -Depth 30|Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8;Write-Output "Evidence: $run/report.json"}
if(-not $success){throw $failure}
