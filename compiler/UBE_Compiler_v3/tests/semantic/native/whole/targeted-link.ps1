param([Parameter(Mandatory=$true)][string]$RunPath,[string]$Stage1ReportPath='')
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$repo=$PSScriptRoot;while(-not [IO.File]::Exists((Join-Path $repo 'bootstrap/tools/verification.ps1'))){$parent=Split-Path $repo -Parent;if(-not $parent -or $parent -eq $repo){throw 'Repository root not found'};$repo=$parent};. (Join-Path $repo 'bootstrap/tools/verification.ps1')
$previous=[IO.File]::ReadAllText((Join-Path $RunPath 'report.json'))|ConvertFrom-Json
$originalLLVM=Join-Path $RunPath 'whole-native.ll';$stageEvidence=$null
if($Stage1ReportPath -ne ''){$stage=[IO.File]::ReadAllText($Stage1ReportPath)|ConvertFrom-Json;if(-not $stage.success -or -not $stage.rawStageIdentity -or $stage.firstStageReport.sha256 -cne (Get-ArtifactIdentity (Join-Path $RunPath 'report.json')).sha256){throw 'Matching successful preserved stage1 report required'};$originalLLVM=Join-Path (Split-Path $Stage1ReportPath -Parent) 'whole-native.ll';$stageEvidence=Get-ArtifactIdentity $Stage1ReportPath}
$target=Join-Path $RunPath ('targeted-'+$(if($Stage1ReportPath -ne ''){'stage1-'}else{''})+[Guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($target)
foreach($file in @('targeted-probe.c','probe.c','scalar-complete.h')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $target}
Copy-Item -LiteralPath (Join-Path $RunPath 'scalar-source.h') -Destination $target
$ir=Join-Path $target 'whole-native.ll';[IO.File]::WriteAllText($ir,[IO.File]::ReadAllText($originalLLVM).Replace('ptr @ube_thread_capture_destroy','ptr @whole_capture_destroy'),(New-Object Text.UTF8Encoding($false)))
$exe=Join-Path $target 'targeted.exe'
$link=Invoke-BoundedProcess $previous.selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-I',$target,'-I',(Join-Path $repo 'bootstrap/runtime'),'-x','ir',$ir,'-x','c',(Join-Path $target 'targeted-probe.c'),'-std=c11','-Wall','-Wextra','-Werror','-x','none',(Join-Path $RunPath 'runtime-whole.o'),$previous.selection.unicodeRuntime.path,'-o',$exe) $repo 120
[pscustomobject]@{diagnosticOnly=$true;originalReport=(Get-ArtifactIdentity (Join-Path $RunPath 'report.json'));stage1Report=$stageEvidence;originalLLVM=(Get-ArtifactIdentity $originalLLVM);llvm=(Get-ArtifactIdentity $ir);runtime=(Get-ArtifactIdentity (Join-Path $RunPath 'runtime-whole.o'));source=@('targeted-probe.c','probe.c','scalar-complete.h'|ForEach-Object{Get-ArtifactIdentity (Join-Path $target $_)});link=$link}|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $target 'link.json') -Encoding UTF8
if($link.timedOut -or $link.exit -ne 0){throw $link.stderr}
Write-Output "Targeted executable: $exe"
