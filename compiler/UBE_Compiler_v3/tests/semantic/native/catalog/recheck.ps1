param([Parameter(Mandatory=$true)][string]$BaseRun,[string]$Control='',[ValidateSet('probe','cases','cost','cancellation','ownership','roots','options','admission','primitive-faults','bindings')][string]$SourceName='probe')
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not (Test-Path -LiteralPath (Join-Path $root 'compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE'))){$parent=Split-Path $root -Parent;if(-not $parent -or $parent -ceq $root){throw 'Cannot find repository root'};$root=$parent}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
. (Join-Path $root 'compiler/UBE_Compiler_v3/tests/semantic/native/abi.ps1')
$base=Get-Content -LiteralPath (Join-Path $BaseRun 'report.json') -Raw|ConvertFrom-Json
$selection=$base.selection
$run=Join-Path (Join-Path $root 'bootstrap/out/semantic-catalog') ('rechecks/'+[Guid]::NewGuid().ToString('N'));$null=New-Item -ItemType Directory -Path $run -Force
$probe=Join-Path $run ($SourceName+'.c');foreach($name in @('probe.c',($SourceName+'.c'),'cases.h','ownership.h')){if(Test-Path -LiteralPath (Join-Path $PSScriptRoot $name)){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $run $name) -Force}}
$originalIr=Join-Path $BaseRun 'catalog-native.ll';$raw=[IO.File]::ReadAllText($originalIr);$adapter=New-Object Text.StringBuilder
if($raw -notmatch 'declare i32 @catalog_assign\('){$raw=Redirect-FoundationRuntime $raw $adapter @(@('i32','ube_value_assign','ptr, ptr, ptr','catalog_assign'),@('i32','ube_value_try_resize','ptr, i32, ptr, i32','catalog_resize'),@('i32','ube_value_copy_bytes','ptr, i32, ptr, i32, i32','catalog_copybytes'))}
if($SourceName -ceq 'cost'){. (Join-Path $PSScriptRoot 'abi-extra.ps1');$procedures=@{};foreach($property in $base.mapping.procedures.PSObject.Properties){$procedures[$property.Name]=$property.Value};$raw=Add-CatalogObservationBindings $raw ([pscustomobject]@{procedures=$procedures})}
if($SourceName -ceq 'cancellation'){$procedures=@{};foreach($property in $base.mapping.procedures.PSObject.Properties){$procedures[$property.Name]=$property.Value};$symbol=Get-FoundationDefinition $raw ([pscustomobject]@{procedures=$procedures}) 'TryContinueSemanticPreparation' 'i1' 'ptr,ptr';$raw=$raw.Replace('define i1 @'+$symbol+'(','define i1 @catalog_checkpoint_body(');[void]$adapter.AppendLine("declare void @catalog_poll()`ndefine i1 @$symbol(ptr %cancel, ptr %failure) {`n call void @catalog_poll()`n %ok = call i1 @catalog_checkpoint_body(ptr %cancel, ptr %failure)`n ret i1 %ok`n}")}
$ir=Join-Path $run 'observed.ll';[IO.File]::WriteAllText($ir,$raw+"`n"+$adapter.ToString(),(New-Object Text.UTF8Encoding($false)))
$object=Join-Path $BaseRun 'observer/runtime-observed.o';$exe=Join-Path $run 'catalog.exe';$args=@('--target=x86_64-w64-windows-gnu','-O2','-I',(Join-Path $root 'bootstrap/runtime'),'-x','ir',$ir,'-x','c',$probe,'-std=c11','-Wall','-Wextra','-Werror');if($Control){$args+='-D'+$Control};$args+=@('-x','none',$object,$selection.unicodeRuntime.path,'-o',$exe)
$compile=Invoke-BoundedProcess $selection.clang.path $args $root 180
$actual=$null;if(-not $compile.timedOut -and $compile.exit -eq 0){$actual=Invoke-BoundedProcess $exe @() $root 300}
[pscustomobject]@{diagnosticOnly=$true;base=(Get-ArtifactIdentity (Join-Path $BaseRun 'report.json'));source=(Get-ArtifactIdentity $probe);ir=(Get-ArtifactIdentity $ir);object=(Get-ArtifactIdentity $object);compile=$compile;actual=$actual}|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Diagnostic recheck: $run/report.json";Write-Output ($compile|ConvertTo-Json -Compress);if($actual){Write-Output ($actual|ConvertTo-Json -Compress)}
