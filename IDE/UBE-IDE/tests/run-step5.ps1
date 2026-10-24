[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$applicationRoot = Split-Path -Parent $PSScriptRoot
$repositoryRoot = (Resolve-Path (Join-Path $applicationRoot '..\..')).Path
$outputRoot = Join-Path $applicationRoot 'out'
$workRoot = Join-Path $outputRoot 'step5-work'
$compilerPath = Join-Path $repositoryRoot 'compiler\release-previews\ube-v3-rp8-windows-x86_64-x86_64-w64-windows-gnu.exe'
$testProject = Join-Path $applicationRoot 'UBE-IDE-Step5-Tests.UBE'
$serviceProject = Join-Path $applicationRoot 'UBE-IDE-Language-Service.UBE'
$runtimeObject = Join-Path $repositoryRoot 'bootstrap\out\bootstrap_runtime.o'
$unicodeRuntimeObject = Join-Path $repositoryRoot 'bootstrap\out\bootstrap_unicode_runtime.o'
$sourceLocalePath = Join-Path $applicationRoot 'resources\locales\en.ube-locale'
$libraryPath = Join-Path $repositoryRoot 'source-library\src\portable\Strings.bas'
$testProgram = Join-Path $outputRoot 'ube-ide-step5-tests.exe'
$serviceProgram = Join-Path $outputRoot 'ube-ide-language-service.exe'
$testLlvm = Join-Path $outputRoot 'ube-ide-step5-tests.ll'
$serviceLlvm = Join-Path $outputRoot 'ube-ide-language-service.ll'
$deterministicOne = Join-Path $outputRoot 'ube-ide-step5-service-deterministic-1.ll'
$deterministicTwo = Join-Path $outputRoot 'ube-ide-step5-service-deterministic-2.ll'

$clangCommand = Get-Command clang -ErrorAction SilentlyContinue
$clangPath = if ($null -ne $clangCommand) { $clangCommand.Source } else { 'C:\Program Files\LLVM\bin\clang.exe' }

foreach ($requiredPath in @(
    $compilerPath, $testProject, $serviceProject, $runtimeObject,
    $unicodeRuntimeObject, $sourceLocalePath, $libraryPath, $clangPath
)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required Step 5 build input is missing: $requiredPath"
    }
}

$clangVersion = @(& $clangPath '--version')[0].ToString()
if ($LASTEXITCODE -ne 0 -or $clangVersion -notmatch '^clang version 23(?:\.|$)') {
    throw "UBE IDE Step 5 requires the verified Clang 23 toolchain; found: $clangVersion"
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

& $compilerPath '--build-native' $serviceProject 'x86_64-w64-windows-gnu' $clangPath $runtimeObject $unicodeRuntimeObject $serviceProgram $serviceLlvm
if ($LASTEXITCODE -ne 0) { throw "Compiler v3 RP8 failed to build the Step 5 language service (exit $LASTEXITCODE)." }
& $compilerPath '--build-native' $testProject 'x86_64-w64-windows-gnu' $clangPath $runtimeObject $unicodeRuntimeObject $testProgram $testLlvm
if ($LASTEXITCODE -ne 0) { throw "Compiler v3 RP8 failed to build the Step 5 integration tests (exit $LASTEXITCODE)." }

& $compilerPath '--emit-llvm' $serviceProject 'x86_64-w64-windows-gnu' $deterministicOne
if ($LASTEXITCODE -ne 0) { throw 'The first deterministic Step 5 service emission failed.' }
& $compilerPath '--emit-llvm' $serviceProject 'x86_64-w64-windows-gnu' $deterministicTwo
if ($LASTEXITCODE -ne 0) { throw 'The second deterministic Step 5 service emission failed.' }
$firstHash = (Get-FileHash -LiteralPath $deterministicOne -Algorithm SHA256).Hash
$secondHash = (Get-FileHash -LiteralPath $deterministicTwo -Algorithm SHA256).Hash
if ($firstHash -ne $secondHash) { throw 'Repeated Step 5 service LLVM emission was not byte-identical.' }
Write-Output "Step 5 deterministic service LLVM SHA-256: $firstHash"

$documentPath = Join-Path $workRoot 'NavigationSample.bas'
$libraryHash = (Get-FileHash -LiteralPath $libraryPath -Algorithm SHA256).Hash
$libraryIdentity = "sha256:$libraryHash"
$output = @(& $testProgram $serviceProgram $workRoot $documentPath $libraryPath $libraryIdentity)
$status = $LASTEXITCODE
$output | ForEach-Object { Write-Output $_ }
if ($status -ne 0 -or $output.Count -eq 0 -or $output[-1] -notmatch '^STEP5 PASS [0-9]+$') {
    throw "UBE Step 5 compiler/navigation verification failed (exit $status)."
}

$requestPath = Join-Path $workRoot 'malformed-request.txt'
$resultPath = Join-Path $workRoot 'malformed-result.txt'
[System.IO.File]::WriteAllText($requestPath, "UBE-IDE-Language-Request 999`n", [System.Text.UTF8Encoding]::new($false))
& $serviceProgram $requestPath $resultPath
if ($LASTEXITCODE -eq 0) { throw 'Malformed language-service request was not rejected.' }
Write-Output 'Malformed language-service request produced a controlled failure.'
Write-Output "Exact UBECore source identity: $libraryIdentity"
Write-Output 'UBE IDE Step 5 out-of-process diagnostics and navigation verification passed.'
