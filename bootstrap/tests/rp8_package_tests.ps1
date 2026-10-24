[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$CompilerPath,
    [Parameter(Mandatory)] [string]$OutputDirectory,
    [string]$Target = 'x86_64-w64-windows-gnu'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$rp8 = Join-Path $root 'compiler/UBE_Compiler_v3/tests/rp8'
$tools = Join-Path $root 'compiler/UBE_Compiler_v3/tools'
$utf8 = [Text.UTF8Encoding]::new($false)

if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
    throw "RP8 output directory does not exist: $OutputDirectory"
}

$resourcePath = Join-Path $OutputDirectory 'rp8-package.UBR'
& (Join-Path $tools 'New-UbeResource.ps1') -OutputPath $resourcePath -Entry @(
    "App=$(Join-Path $rp8 'group-app.bas')",
    "Library=$(Join-Path $rp8 'group-library.bas')"
)

$bundlePath = Join-Path $OutputDirectory 'rp8-package.UBL'
$interfaceHash = (Get-FileHash -LiteralPath (Join-Path $rp8 'group-library.bas') -Algorithm SHA256).Hash
& (Join-Path $tools 'New-UbeLibraryBundle.ps1') -OutputPath $bundlePath `
    -Name RP8GroupLibrary -Version 1.0.0-rp8 -Target $Target `
    -ObjectFormat COFF -InterfacePath (Join-Path $rp8 'group-library.bas') `
    -ArtifactPath $CompilerPath

$sourcePath = Join-Path $OutputDirectory 'rp8-package-main.bas'
Copy-Item -LiteralPath (Join-Path $rp8 'group-app.bas') -Destination $sourcePath -Force
$projectPath = Join-Path $OutputDirectory 'rp8-package.UBE'
$project = @(
    'UBE-Project 1'
    'Name = "RP8Package"'
    'Kind = "Exe"'
    'Startup = "Main"'
    'Optimization = "2"'
    'DebugInformation = "Full"'
    'Source = "rp8-package-main.bas"'
    'Resource = "rp8-package.UBR"'
    "LibraryReference = `"rp8-package.UBL|1.0.0-rp8|$interfaceHash`""
    ''
) -join "`n"
[IO.File]::WriteAllText($projectPath, $project, $utf8)

$positive = & $CompilerPath $projectPath $Target 2>&1
$positiveText = $positive -join "`n"
if ($LASTEXITCODE -ne 0 -or $positiveText -notlike 'UBE Compiler v3 RP8: project RP8Package*') {
    throw "RP8 package validation failed: $positive"
}

$resourceLlvmPath = Join-Path $OutputDirectory 'rp8-package-resource.ll'
& $CompilerPath '--emit-llvm' $projectPath $Target $resourceLlvmPath
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $resourceLlvmPath)) {
    throw 'RP8 resource LLVM emission failed'
}
$resourceLlvmText = [IO.File]::ReadAllText($resourceLlvmPath)
$resourceLength = (Get-Item -LiteralPath $resourcePath).Length
if (-not $resourceLlvmText.Contains('@ube.resource.count = constant i32 1') -or
    -not $resourceLlvmText.Contains("@ube.resource.lengths = constant [1 x i64] [i64 $resourceLength]") -or
    -not $resourceLlvmText.Contains("@ube.resource.data = constant [$resourceLength x i8]")) {
    throw 'RP8 resource container was not emitted into deterministic read-only LLVM globals'
}

$corruptPath = Join-Path $OutputDirectory 'rp8-corrupt.UBR'
[IO.File]::WriteAllBytes($corruptPath, [byte[]](1, 2, 3))
$corruptProjectPath = Join-Path $OutputDirectory 'rp8-corrupt.UBE'
[IO.File]::WriteAllText($corruptProjectPath,
    $project.Replace('rp8-package.UBR', 'rp8-corrupt.UBR'), $utf8)
$corrupt = & $CompilerPath $corruptProjectPath $Target 2>&1
$corruptText = $corrupt -join "`n"
if ($LASTEXITCODE -eq 0 -or $corruptText -notlike '*error UBE3045:*resource container*') {
    throw "RP8 corrupt-resource rejection failed: $corrupt"
}

$incompatible = & $CompilerPath $projectPath 'x86_64-unknown-linux-gnu' 2>&1
$incompatibleText = $incompatible -join "`n"
if ($LASTEXITCODE -eq 0 -or $incompatibleText -notlike '*error UBE3048:*compiled-library bundle*') {
    throw "RP8 incompatible-bundle rejection failed: $incompatible"
}

$wrongVersionPath = Join-Path $OutputDirectory 'rp8-wrong-version.UBE'
[IO.File]::WriteAllText($wrongVersionPath,
    $project.Replace('|1.0.0-rp8|', '|1.0.1-rp8|'), $utf8)
$wrongVersion = & $CompilerPath $wrongVersionPath $Target 2>&1
$wrongVersionText = $wrongVersion -join "`n"
if ($LASTEXITCODE -eq 0 -or $wrongVersionText -notlike '*error UBE3048:*compiled-library bundle*') {
    throw "RP8 incompatible bundle-version rejection failed: $wrongVersion"
}

$wrongInterfacePath = Join-Path $OutputDirectory 'rp8-wrong-interface.UBE'
$wrongInterface = '0' * 64
[IO.File]::WriteAllText($wrongInterfacePath,
    $project.Replace($interfaceHash, $wrongInterface), $utf8)
$wrongInterfaceResult = & $CompilerPath $wrongInterfacePath $Target 2>&1
$wrongInterfaceText = $wrongInterfaceResult -join "`n"
if ($LASTEXITCODE -eq 0 -or $wrongInterfaceText -notlike '*error UBE3048:*compiled-library bundle*') {
    throw "RP8 incompatible bundle-interface rejection failed: $wrongInterfaceResult"
}

# Regression: a structurally valid container must not satisfy a consumer by
# merely claiming the required interface hash in its manifest. The hash must
# also be the directory hash of the actual Interface entry.
$forgedInterfacePath = Join-Path $OutputDirectory 'rp8-forged-interface.bas'
[IO.File]::WriteAllText($forgedInterfacePath,
    ([IO.File]::ReadAllText((Join-Path $rp8 'group-library.bas')) + "`n' forged interface`n"), $utf8)
$forgedMetadataPath = Join-Path $OutputDirectory 'rp8-forged-manifest.txt'
$artifactHash = (Get-FileHash -LiteralPath $CompilerPath -Algorithm SHA256).Hash
$forgedMetadata = @(
    'Format=UBE-LibraryBundle-Metadata-1'
    'Name=RP8GroupLibrary'
    'Version=1.0.0-rp8'
    'Language=1.0'
    'IntrinsicABI=ube-intrinsic-abi-1'
    "Target=$Target"
    'ObjectFormat=COFF'
    'PointerBits=64'
    "InterfaceSHA256=$interfaceHash"
    "ArtifactSHA256=$artifactHash"
    ''
) -join "`n"
[IO.File]::WriteAllText($forgedMetadataPath, $forgedMetadata, $utf8)
$forgedBundlePath = Join-Path $OutputDirectory 'rp8-forged.UBL'
& (Join-Path $tools 'New-UbeResource.ps1') -OutputPath $forgedBundlePath `
    -ContainerKind LibraryBundle -Entry @(
        "Artifact=$CompilerPath",
        "Interface=$forgedInterfacePath",
        "Manifest=$forgedMetadataPath"
    )
$forgedProjectPath = Join-Path $OutputDirectory 'rp8-forged.UBE'
[IO.File]::WriteAllText($forgedProjectPath,
    $project.Replace('rp8-package.UBL', 'rp8-forged.UBL'), $utf8)
$forgedResult = & $CompilerPath $forgedProjectPath $Target 2>&1
$forgedText = $forgedResult -join "`n"
if ($LASTEXITCODE -eq 0 -or $forgedText -notlike '*error UBE3048:*compiled-library bundle*') {
    throw "RP8 forged bundle-interface rejection failed: $forgedResult"
}

$group = & $CompilerPath (Join-Path $rp8 'group.UBG') $Target 2>&1
$groupText = $group -join "`n"
if ($LASTEXITCODE -ne 0 -or $groupText -notlike '*project group RP8 Group, 2 project(s)*') {
    throw "RP8 project-group validation failed: $group"
}

$duplicate = & $CompilerPath (Join-Path $rp8 'group-duplicate.UBG') $Target 2>&1
$duplicateText = $duplicate -join "`n"
if ($LASTEXITCODE -eq 0 -or $duplicateText -notlike '*error UBE3041:*duplicate Project*') {
    throw "RP8 duplicate group-project rejection failed: $duplicate"
}

$invalidOptimization = & $CompilerPath (Join-Path $rp8 'invalid-optimization.UBE') $Target 2>&1
$invalidOptimizationText = $invalidOptimization -join "`n"
if ($LASTEXITCODE -eq 0 -or $invalidOptimizationText -notlike '*error UBE3029:*Optimization*') {
    throw "RP8 invalid optimization rejection failed: $invalidOptimization"
}

Write-Output 'RP8 package tests passed'
$global:LASTEXITCODE = 0
