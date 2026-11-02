param([string]$ToolPath='',[string]$SelectionPath='',[string]$OutputRoot='',[switch]$RequireAccepted=$true)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not (Test-Path -LiteralPath (Join-Path $root 'compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE'))){$parent=Split-Path $root -Parent;if(-not $parent -or $parent -ceq $root){throw 'Cannot find repository root'};$root=$parent}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$foundation=Join-Path $root 'compiler/UBE_Compiler_v3/tests/semantic/native'
. (Join-Path $foundation 'observer.ps1')
. (Join-Path $foundation 'abi.ps1')
. (Join-Path $foundation 'project.ps1')
if(-not $SelectionPath){$SelectionPath=Join-Path $root 'bootstrap/out/v2/current.json'}
if($RequireAccepted){$selection=Get-VerifiedBootstrapSelection $SelectionPath}else{$selection=Get-Content -LiteralPath $SelectionPath -Raw|ConvertFrom-Json}
if(-not $ToolPath){$ToolPath=$selection.compiler.path}
if(-not $OutputRoot){$OutputRoot=Join-Path $root 'bootstrap/out/semantic-catalog'};$run=Join-Path $OutputRoot ('runs/'+[Guid]::NewGuid().ToString('N'));$project=Join-Path $run 'project';$null=New-Item -ItemType Directory -Path $project -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'probe.c') -Destination (Join-Path $run 'probe.c')
$base=Join-Path $root 'compiler/UBE_Compiler_v3';$lines=@('UBE-Project 1','Name = "SemanticCatalogFixture"','Kind = "Exe"','Startup = "Main"');$inputs=@((Get-ArtifactIdentity (Join-Path $base 'UBE_Compiler_v3.UBE')));$commands=@();$success=$false;$failure=$null
foreach($line in [IO.File]::ReadAllLines((Join-Path $base 'UBE_Compiler_v3.UBE'))){if($line -match '^Source = "([^"]+)"$'){$origin=Join-Path $base $Matches[1];$name=Split-Path $origin -Leaf;$text=[IO.File]::ReadAllText($origin);if($name -ceq 'Main.bas'){$text=[regex]::Replace($text,'(?ms)^Function Main\(\) As Long\r?\n.*?^End Function\r?\n?','')};[IO.File]::WriteAllText((Join-Path $project $name),$text,(New-Object Text.UTF8Encoding($false)));$inputs+=Get-ArtifactIdentity $origin;$lines+='Source = "'+$name+'"'}}

foreach($name in @('Entry.bas','CancellationEntry.bas')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $project $name);$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot $name);$lines+='Source = "'+$name+'"'}
$library=Join-Path $root 'std-lib/UBECore.UBE';$reference=[Uri]::UnescapeDataString(([Uri]($project.TrimEnd('\')+'\')).MakeRelativeUri([Uri]$library).ToString());$lines+='Reference = "'+$reference+'"';$manifest=Join-Path $project 'Catalog.UBE';[IO.File]::WriteAllText($manifest,($lines -join "`n")+"`n",(New-Object Text.UTF8Encoding($false)))
$sources=@(Get-FoundationProjectSources $manifest);$procedures=@{};$types=@{};$classes=@();$ordinal=0
foreach($source in $sources){$text=[IO.File]::ReadAllText($source);if($text -match '^UBE SOURCE 1 CLASS'){$null=$text -match 'Attribute UBE_Name = "([^"]+)"';$classes+=$Matches[1]};foreach($m in [regex]::Matches($text,'(?m)^(?:(?:Public|Private|Friend) )?(?:Intrinsic )?(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)\b')){$name=$m.Groups[1].Value;if($procedures.ContainsKey($name)){throw "Duplicate catalog procedure $name"};$procedures[$name]='ube.p'+$ordinal;++$ordinal}}
$ordinal=0;foreach($name in $classes){$types[$name]='%ube.type.'+$ordinal;++$ordinal};foreach($source in $sources){foreach($m in [regex]::Matches([IO.File]::ReadAllText($source),'(?m)^Type ([A-Za-z_][A-Za-z_0-9]*)\b')){$types[$m.Groups[1].Value]='%ube.type.'+$ordinal;++$ordinal}}
foreach($required in @('TryBuildSemanticDeclarations','TryResolveSemanticType','TryLookupSemanticName','TryContinueSemanticPreparation')){if(-not $procedures.ContainsKey($required)){throw 'Production semantic catalog has not been promoted'}};$mapping=[pscustomobject]@{procedures=$procedures;types=$types};$inputs+=@($sources|ForEach-Object {Get-ArtifactIdentity $_})+@((Get-ArtifactIdentity $library),(Get-ArtifactIdentity (Join-Path $PSScriptRoot 'probe.c')),(Get-ArtifactIdentity $PSCommandPath))
try{
 $rawPath=Join-Path $run 'catalog.ll';$record=Invoke-BoundedProcess $ToolPath @($manifest,$rawPath) $root 900;$commands+=@($record);if($record.timedOut -or $record.exit -ne 0){throw ($record|ConvertTo-Json -Compress)}
 $raw=[IO.File]::ReadAllText($rawPath);$adapter=New-Object Text.StringBuilder
 $null=Assert-FoundationRecord $raw $mapping 'SemanticDeclaration' 'i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i64'
 $null=Assert-FoundationRecord $raw $mapping 'SemanticFact' 'i32, i32, i32, i32, i64, i32, i32, i32, i32, i32, i32'
 $null=Assert-FoundationRecord $raw $mapping 'BoundNode' 'i32, i32, i32, i32, i64, i32, i32, i32, i32, i32, i32'
 $null=Assert-FoundationRecord $raw $mapping 'SemanticType' 'i32, i32, i32, i32, i32, i32, i64, i64'
 $null=Assert-FoundationRecord $raw $mapping 'SemanticName' 'i32, i32, i32, i32, i32, i32'
 $null=Assert-FoundationRecord $raw $mapping 'SemanticCatalog' ('ptr, ptr, i32, i32, '+$types.SemanticLimits+', ptr, i32, ptr, i32, ptr, i32, '+$types.ByteBuffer+', ptr, i32, ptr, ptr, i32, ptr, i32, '+$types.SemanticMetrics)
 foreach($binding in @(@('catalog_make','TryMakeCatalogFixture','i1','ptr,ptr,i32,i32,ptr,ptr'),@('catalog_lookup','TryCatalogFixtureLookup','i1','ptr,i32,i32,i32,i32,ptr,ptr,ptr'),@('catalog_qualified','TryLookupSemanticQualified','i1','ptr,i32,i32,i32,ptr,ptr,ptr'),@('catalog_make_cancellation','TryMakeCatalogCancellation','i1','i32,ptr'),@('catalog_build_cancellable','TryBuildSemanticDeclarations','i1','ptr,ptr,ptr'))){Add-FoundationBinding $adapter $raw $mapping $binding[0] $binding[1] $binding[2] $binding[3]}
 $build=Get-FoundationDefinition $raw $mapping 'TryBuildSemanticDeclarations' 'i1' 'ptr,ptr,ptr';[void]$adapter.AppendLine("define i32 @catalog_build(ptr %catalog, ptr %failure) {`n %ok = call i1 @$build(ptr %catalog, ptr null, ptr %failure)`n %status = zext i1 %ok to i32`n ret i32 %status`n}")
 $raw=Redirect-FoundationRuntime $raw $adapter @(@('i32','ube_value_assign','ptr, ptr, ptr','catalog_assign'),@('i32','ube_value_try_resize','ptr, i32, ptr, i32','catalog_resize'),@('i32','ube_value_copy_bytes','ptr, i32, ptr, i32, i32','catalog_copybytes'))
 $adapted=Join-Path $run 'catalog-native.ll';[IO.File]::WriteAllText($adapted,$raw.Replace('define i32 @main(','define i32 @catalog_unused_main(')+"`n"+$adapter.ToString(),(New-Object Text.UTF8Encoding($false)))
 $observer=New-FoundationObservedRuntime $root $run $selection;$commands+=@($observer.commands)
 $exe=Join-Path $run 'catalog-native.exe';$record=Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-I',(Join-Path $root 'bootstrap/runtime'),'-x','ir',$adapted,'-x','c',(Join-Path $run 'probe.c'),'-std=c11','-Wall','-Wextra','-Werror','-x','none',$observer.object.path,$selection.unicodeRuntime.path,'-o',$exe) $root 120;$commands+=@($record);if($record.timedOut -or $record.exit -ne 0){throw ($record|ConvertTo-Json -Compress)}
 $record=Invoke-BoundedProcess $exe @() $root 300;$commands+=@($record);if($record.timedOut -or $record.exit -ne 0 -or $record.stderr -cne '' -or $record.stdout -notmatch 'PASS catalog native assertions:[0-9]+\n$'){throw ($record|ConvertTo-Json -Compress)}
 foreach($input in $inputs){if((Get-ArtifactIdentity $input.path).sha256 -cne $input.sha256){throw "Catalog input changed: $($input.path)"}}
 $success=$true
}catch{$failure=$_.Exception.Message}
finally{[pscustomobject]@{success=$success;qualifiedCatalog=$false;diagnosticOnly=$true;failure=$failure;acceptedRequired=[bool]$RequireAccepted;selection=$selection;tool=(Get-ArtifactIdentity $ToolPath);manifest=(Get-ArtifactIdentity $manifest);sources=$sources;mapping=$mapping;inputs=$inputs;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File -Recurse|ForEach-Object {Get-ArtifactIdentity $_.FullName});limits='Focused draft catalog only. No complete checker claim; both-stage immutable/failure/copy/native controls remain required.'}|ConvertTo-Json -Depth 30|Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8;Write-Output "Evidence: $run/report.json"}
if(-not $success){throw $failure}
