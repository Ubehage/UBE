param([string]$ToolPath='',[string]$SelectionPath='',[string]$OutputRoot='',[string]$Control='')
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not (Test-Path -LiteralPath (Join-Path $root 'compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE'))){$parent=Split-Path $root -Parent;if(-not $parent -or $parent -ceq $root){throw 'Cannot find repository root'};$root=$parent}
$repo=$root
. (Join-Path $repo 'bootstrap/tools/verification.ps1')
$foundation=Join-Path $repo 'compiler/UBE_Compiler_v3/tests/semantic/native'
. (Join-Path $foundation 'abi.ps1');. (Join-Path $foundation 'observer.ps1');. (Join-Path $foundation 'project.ps1')
if(-not $SelectionPath){$SelectionPath=Join-Path $repo 'bootstrap/out/v2/current.json'}
$selection=Get-VerifiedBootstrapSelection $SelectionPath
if(-not $ToolPath){$ToolPath=$selection.compiler.path}
if(-not $OutputRoot){$OutputRoot=Join-Path $repo 'bootstrap/out/semantic-formatter'};$run=Join-Path $OutputRoot ('runs/'+[Guid]::NewGuid().ToString('N'));$project=Join-Path $run 'project';$null=New-Item -ItemType Directory $project -Force
$base=Join-Path $repo 'compiler/UBE_Compiler_v3'
$manifest=Join-Path $project 'Formatter.UBE';$lines=@('UBE-Project 1','Name = "SemanticFormatterFixture"','Kind = "Exe"','Startup = "Main"');$inputs=@((Get-ArtifactIdentity (Join-Path $base 'UBE_Compiler_v3.UBE')));$commands=@();$success=$false;$failure=$null
foreach($line in [IO.File]::ReadAllLines((Join-Path $base 'UBE_Compiler_v3.UBE'))){if($line -match '^Source = "([^"]+)"$'){$origin=Join-Path $base $Matches[1];$name=Split-Path $origin -Leaf;$body=[IO.File]::ReadAllText($origin);if($name -ceq 'Main.bas'){$body=[regex]::Replace($body,'(?ms)^Function Main\(\) As Long\r?\n.*?^End Function\r?\n?','')};[IO.File]::WriteAllText((Join-Path $project $name),$body,(New-Object Text.UTF8Encoding($false)));$inputs+=Get-ArtifactIdentity $origin;$lines+='Source = "'+$name+'"'}}
$catalogFixture=Join-Path (Split-Path $PSScriptRoot -Parent) 'catalog/Entry.bas';Copy-Item -LiteralPath $catalogFixture -Destination (Join-Path $project 'CatalogEntry.bas');$inputs+=Get-ArtifactIdentity $catalogFixture;$lines+='Source = "CatalogEntry.bas"'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Entry.bas') -Destination (Join-Path $project 'FormatterEntry.bas');$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'Entry.bas');$lines+='Source = "FormatterEntry.bas"'
$library=Join-Path $repo 'std-lib/UBECore.UBE';$reference=[Uri]::UnescapeDataString(([Uri]($project.TrimEnd('\')+'\')).MakeRelativeUri([Uri]$library).ToString());$lines+='Reference = "'+$reference+'"';[IO.File]::WriteAllText($manifest,($lines -join "`n")+"`n",(New-Object Text.UTF8Encoding($false)))
$sources=@(Get-FoundationProjectSources $manifest);$procedures=@{};$types=@{};$classes=@();$ordinal=0
foreach($source in $sources){$text=[IO.File]::ReadAllText($source);if($text -match '^UBE SOURCE 1 CLASS'){$null=$text -match 'Attribute UBE_Name = "([^"]+)"';$classes+=$Matches[1]};foreach($m in [regex]::Matches($text,'(?m)^(?:(?:Public|Private|Friend) )?(?:Intrinsic )?(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)\b')){$name=$m.Groups[1].Value;if($procedures.ContainsKey($name)){throw "Duplicate procedure $name"};$procedures[$name]='ube.p'+$ordinal;++$ordinal}}
$ordinal=0;foreach($name in $classes){$types[$name]='%ube.type.'+$ordinal;++$ordinal};foreach($source in $sources){foreach($m in [regex]::Matches([IO.File]::ReadAllText($source),'(?m)^Type ([A-Za-z_][A-Za-z_0-9]*)\b')){$types[$m.Groups[1].Value]='%ube.type.'+$ordinal;++$ordinal}}
foreach($required in @('TryFormatSourceSemanticFailure','TryFormatProjectSemanticFailure','TryFindSemanticSourceToken')){if(-not $procedures.ContainsKey($required)){throw 'Production semantic formatter has not been promoted'}};$mapping=[pscustomobject]@{procedures=$procedures;types=$types};$inputs+=@($sources|ForEach-Object {Get-ArtifactIdentity $_})+@((Get-ArtifactIdentity $PSCommandPath),(Get-ArtifactIdentity (Join-Path $PSScriptRoot 'probe.c')))
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'probe.c') -Destination (Join-Path $run 'probe.c')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'expected.h') -Destination (Join-Path $run 'expected.h');$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'expected.h')
try{
 $rawPath=Join-Path $run 'formatter.ll';$record=Invoke-BoundedProcess $ToolPath @($manifest,$rawPath) $repo 900;$commands+=@($record);if($record.timedOut -or $record.exit -ne 0){throw ($record|ConvertTo-Json -Compress)}
 $raw=[IO.File]::ReadAllText($rawPath);$adapter=New-Object Text.StringBuilder
 $null=Assert-FoundationRecord $raw $mapping 'SemanticFailure' 'i32, i32, i32, i32, i32, i32, i32, i32'
 $null=Assert-FoundationRecord $raw $mapping 'ProjectSyntax' 'ptr, ptr';$null=Assert-FoundationRecord $raw $mapping 'SourceWork' ('ptr, ptr, ptr, '+$types.SyntaxFailure+', '+$types.SyntaxMetrics+', i64, i32, i32, i32, i32, i32')
 foreach($b in @(@('formatter_make','TryMakeFormatterFixture','i1','ptr,ptr,ptr'),@('formatter_source','TryFormatSourceSemanticFailure','i1','ptr,ptr,ptr'),@('formatter_project','TryFormatProjectSemanticFailure','i1','ptr,ptr,ptr,ptr'),@('formatter_print_source','TryPrintSourceSemanticFailure','i1','ptr,ptr'),@('formatter_print_project','TryPrintProjectSemanticFailure','i1','ptr,ptr,ptr'),@('formatter_position','TrySemanticFailurePosition','i1','ptr,i32,ptr'))){Add-FoundationBinding $adapter $raw $mapping $b[0] $b[1] $b[2] $b[3]}
 $fallback=Get-FoundationDefinition $raw $mapping 'PrintCompilerStorageFailure' 'void' 'i32';[void]$adapter.AppendLine("define void @formatter_fallback() {`n call void @$fallback(i32 1428)`n ret void`n}")
 $raw=Redirect-FoundationRuntime $raw $adapter @(@('void','ube_print_string','ptr','formatter_capture_string'),@('void','ube_print_newline','','formatter_capture_newline'))
 $adapted=Join-Path $run 'formatter-native.ll';[IO.File]::WriteAllText($adapted,$raw.Replace('define i32 @main(','define i32 @formatter_unused_main(')+"`n"+$adapter.ToString(),(New-Object Text.UTF8Encoding($false)))
 $observer=New-FoundationObservedRuntime $repo $run $selection;$commands+=@($observer.commands)
 $exe=Join-Path $run 'formatter.exe';$args=@('--target=x86_64-w64-windows-gnu','-O2','-I',(Join-Path $repo 'bootstrap/runtime'),'-x','ir',$adapted,'-x','c',(Join-Path $run 'probe.c'),'-std=c11','-Wall','-Wextra','-Werror');if($Control){$args+='-D'+$Control};$args+=@('-x','none',$observer.object.path,$selection.unicodeRuntime.path,'-o',$exe)
 $record=Invoke-BoundedProcess $selection.clang.path $args $repo 180;$commands+=@($record);if($record.timedOut -or $record.exit -ne 0){throw ($record|ConvertTo-Json -Compress)}
 $record=Invoke-BoundedProcess $exe @() $repo 300;$commands+=@($record);if($record.timedOut -or $record.exit -ne 0 -or $record.stderr -cne '' -or $record.stdout -notmatch 'PASS semantic formatter assertions:[0-9]+\n$'){throw ($record|ConvertTo-Json -Compress)}
 foreach($input in $inputs){if((Get-ArtifactIdentity $input.path).sha256 -cne $input.sha256){throw "Formatter input changed: $($input.path)"}}
 $success=$true
}catch{$failure=$_.Exception.Message}
finally{[pscustomobject]@{success=$success;failure=$failure;selection=$selection;tool=(Get-ArtifactIdentity $ToolPath);productionManifest=(Get-ArtifactIdentity (Join-Path $base 'UBE_Compiler_v3.UBE'));mapping=$mapping;inputs=$inputs;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File -Recurse|ForEach-Object {Get-ArtifactIdentity $_.FullName})}|ConvertTo-Json -Depth 30|Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8;Write-Output "Evidence: $run/report.json"}
if(-not $success){throw $failure}
