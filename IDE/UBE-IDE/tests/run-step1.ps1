[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$applicationRoot = Split-Path -Parent $PSScriptRoot
$repositoryRoot = (Resolve-Path (Join-Path $applicationRoot '..\..')).Path
$outputRoot = Join-Path $applicationRoot 'out'
$workRoot = Join-Path $outputRoot 'step1-work'
$compilerPath = Join-Path $repositoryRoot 'compiler\release-previews\ube-v3-rp7-windows-x86_64-x86_64-w64-windows-gnu.exe'
$projectPath = Join-Path $applicationRoot 'UBE-IDE-Step1.UBE'
$runtimeObject = Join-Path $repositoryRoot 'bootstrap\out\bootstrap_runtime.o'
$unicodeRuntimeObject = Join-Path $repositoryRoot 'bootstrap\out\bootstrap_unicode_runtime.o'
$programPath = Join-Path $outputRoot 'ube-ide-step1.exe'
$llvmPath = Join-Path $outputRoot 'ube-ide-step1.ll'
$deterministicLlvmOne = Join-Path $outputRoot 'ube-ide-step1-deterministic-1.ll'
$deterministicLlvmTwo = Join-Path $outputRoot 'ube-ide-step1-deterministic-2.ll'
$sourceLocalePath = Join-Path $applicationRoot 'resources\locales\en.ube-locale'

$clangCommand = Get-Command clang -ErrorAction SilentlyContinue
$clangPath = if ($null -ne $clangCommand) {
    $clangCommand.Source
} else {
    'C:\Program Files\LLVM\bin\clang.exe'
}

foreach ($requiredPath in @($compilerPath, $projectPath, $runtimeObject, $unicodeRuntimeObject, $clangPath, $sourceLocalePath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required Step 1 build input is missing: $requiredPath"
    }
}

$clangVersionLines = @(& $clangPath '--version')
$clangVersionStatus = $LASTEXITCODE
$clangVersion = if ($clangVersionLines.Count -gt 0) { $clangVersionLines[0].ToString() } else { '' }
if ($clangVersionStatus -ne 0 -or $clangVersion -notmatch '^clang version 23(?:\.|$)') {
    throw "UBE IDE Step 1 requires the verified Clang 23 toolchain; found: $clangVersion"
}

New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
New-Item -ItemType Directory -Path $workRoot -Force | Out-Null

$diagnosticCodes = Get-ChildItem -LiteralPath (Join-Path $applicationRoot 'src') -Filter '*.bas' |
    Select-String -Pattern '"IDE[0-9]{4}"' -AllMatches |
    ForEach-Object { $_.Matches.Value.Trim('"') } |
    Sort-Object -Unique
$localeDiagnosticKeys = Get-Content -LiteralPath $sourceLocalePath |
    Where-Object { $_ -match '^Diagnostic\.(IDE[0-9]{4})\s*=' } |
    ForEach-Object { $Matches[1] } |
    Sort-Object -Unique
$missingDiagnosticKeys = @($diagnosticCodes | Where-Object { $_ -notin $localeDiagnosticKeys })
if ($missingDiagnosticKeys.Count -ne 0) {
    throw "Source locale is missing diagnostic keys: $($missingDiagnosticKeys -join ', ')"
}

foreach ($generatedPath in @(
    $programPath,
    $llvmPath,
    $deterministicLlvmOne,
    $deterministicLlvmTwo,
    (Join-Path $workRoot 'Main.bas'),
    (Join-Path $workRoot 'Main.bas.ube-recovery')
)) {
    if (Test-Path -LiteralPath $generatedPath) {
        Remove-Item -LiteralPath $generatedPath -Force
    }
}

& $compilerPath '--build-native' $projectPath 'x86_64-w64-windows-gnu' $clangPath $runtimeObject $unicodeRuntimeObject $programPath $llvmPath
if ($LASTEXITCODE -ne 0) {
    throw "Compiler v3 failed to build the UBE IDE Step 1 verification program (exit $LASTEXITCODE)."
}

& $compilerPath '--emit-llvm' $projectPath 'x86_64-w64-windows-gnu' $deterministicLlvmOne
if ($LASTEXITCODE -ne 0) {
    throw 'Compiler v3 failed the first deterministic LLVM emission.'
}
& $compilerPath '--emit-llvm' $projectPath 'x86_64-w64-windows-gnu' $deterministicLlvmTwo
if ($LASTEXITCODE -ne 0) {
    throw 'Compiler v3 failed the second deterministic LLVM emission.'
}
$firstLlvmHash = (Get-FileHash -LiteralPath $deterministicLlvmOne -Algorithm SHA256).Hash
$secondLlvmHash = (Get-FileHash -LiteralPath $deterministicLlvmTwo -Algorithm SHA256).Hash
if ($firstLlvmHash -ne $secondLlvmHash) {
    throw 'Repeated Step 1 LLVM emission was not byte-identical.'
}
Write-Output "Step 1 deterministic LLVM SHA-256: $firstLlvmHash"

$verificationOutput = @(& $programPath $workRoot $sourceLocalePath)
$verificationStatus = $LASTEXITCODE
$verificationOutput | ForEach-Object { Write-Output $_ }
if ($verificationStatus -ne 0) {
    throw "UBE IDE Step 1 verification failed (exit $verificationStatus)."
}
if ($verificationOutput.Count -eq 0 -or $verificationOutput[-1] -ne 'STEP1 PASS') {
    throw 'UBE IDE Step 1 verification did not emit its completion marker.'
}

Write-Output 'UBE IDE Step 1 build and headless verification passed.'
