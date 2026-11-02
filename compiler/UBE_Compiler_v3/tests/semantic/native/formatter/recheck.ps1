param([Parameter(Mandatory=$true)][string]$BaseRun,[string]$Control='')
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not (Test-Path -LiteralPath (Join-Path $root 'compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE'))){$parent=Split-Path $root -Parent;if(-not $parent -or $parent -ceq $root){throw 'Cannot find repository root'};$root=$parent}
$repo=$root
. (Join-Path $repo 'bootstrap/tools/verification.ps1')
$report=Get-Content -LiteralPath (Join-Path $BaseRun 'report.json') -Raw|ConvertFrom-Json;$selection=$report.selection
$run=Join-Path (Join-Path $repo 'bootstrap/out/semantic-formatter') ('rechecks/'+[Guid]::NewGuid().ToString('N'));$null=New-Item -ItemType Directory $run -Force
foreach($name in @('probe.c','expected.h')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $run $name)}
$ir=Join-Path $BaseRun 'formatter-native.ll';$object=Join-Path $BaseRun 'observer/runtime-observed.o';$exe=Join-Path $run 'formatter.exe'
$args=@('--target=x86_64-w64-windows-gnu','-O2','-I',(Join-Path $repo 'bootstrap/runtime'),'-x','ir',$ir,'-x','c',(Join-Path $run 'probe.c'),'-std=c11','-Wall','-Wextra','-Werror');if($Control){$args+='-D'+$Control};$args+=@('-x','none',$object,$selection.unicodeRuntime.path,'-o',$exe)
$compile=Invoke-BoundedProcess $selection.clang.path $args $repo 120
$actual=$null;if($compile.exit -eq 0){$actual=Invoke-BoundedProcess $exe @() $repo 300}
$success=$compile.exit -eq 0 -and $actual -and $actual.exit -eq 0 -and -not $actual.timedOut -and $actual.stderr -ceq '' -and $actual.stdout -match 'PASS semantic formatter assertions:[0-9]+\n$'
[pscustomobject]@{success=[bool]$success;base=(Get-ArtifactIdentity (Join-Path $BaseRun 'report.json'));ir=(Get-ArtifactIdentity $ir);object=(Get-ArtifactIdentity $object);compile=$compile;actual=$actual;inputs=@((Get-ArtifactIdentity (Join-Path $run 'probe.c')),(Get-ArtifactIdentity (Join-Path $run 'expected.h')),(Get-ArtifactIdentity $PSCommandPath))}|ConvertTo-Json -Depth 15|Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Formatter recheck: $run/report.json";Write-Output ($compile|ConvertTo-Json -Compress);if($actual){Write-Output ($actual|ConvertTo-Json -Compress)}
if(-not $success){throw 'Formatter native recheck failed'}
