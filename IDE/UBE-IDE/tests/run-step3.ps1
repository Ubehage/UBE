[CmdletBinding()]
param(
    [switch]$Launch
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$applicationRoot = Split-Path -Parent $PSScriptRoot
$repositoryRoot = (Resolve-Path (Join-Path $applicationRoot '..\..')).Path
$outputRoot = Join-Path $applicationRoot 'out'
$workRoot = Join-Path $outputRoot 'step3-work'
$compilerPath = Join-Path $repositoryRoot 'compiler\release-previews\ube-v3-rp8-windows-x86_64-x86_64-w64-windows-gnu.exe'
$testProject = Join-Path $applicationRoot 'UBE-IDE-Step3-Tests.UBE'
$applicationProject = Join-Path $applicationRoot 'UBE-IDE.UBE'
$nativeSource = Join-Path $applicationRoot 'platform\windows\ube_ide_win32.c'
$runtimeObject = Join-Path $repositoryRoot 'bootstrap\out\bootstrap_runtime.o'
$unicodeRuntimeObject = Join-Path $repositoryRoot 'bootstrap\out\bootstrap_unicode_runtime.o'
$sourceLocalePath = Join-Path $applicationRoot 'resources\locales\en.ube-locale'
$defaultLayoutPath = Join-Path $applicationRoot 'resources\layouts\default.ube-layout'
$testProgram = Join-Path $outputRoot 'ube-ide-step3-tests.exe'
$applicationProgram = Join-Path $outputRoot 'ube-ide.exe'
$nativeProgram = Join-Path $outputRoot 'ube-ide-win32.exe'
$testLlvm = Join-Path $outputRoot 'ube-ide-step3-tests.ll'
$applicationLlvm = Join-Path $outputRoot 'ube-ide-step3.ll'
$deterministicOne = Join-Path $outputRoot 'ube-ide-step3-deterministic-1.ll'
$deterministicTwo = Join-Path $outputRoot 'ube-ide-step3-deterministic-2.ll'

$clangCommand = Get-Command clang -ErrorAction SilentlyContinue
$clangPath = if ($null -ne $clangCommand) { $clangCommand.Source } else { 'C:\Program Files\LLVM\bin\clang.exe' }
$gccCommand = Get-Command gcc -ErrorAction SilentlyContinue
$gccPath = if ($null -ne $gccCommand) {
    $gccCommand.Source
} else {
    'C:\Users\Ubehage\Documents\WinLibs\mingw64\bin\gcc.exe'
}

foreach ($requiredPath in @(
    $compilerPath, $testProject, $applicationProject, $nativeSource, $runtimeObject,
    $unicodeRuntimeObject, $sourceLocalePath, $defaultLayoutPath, $clangPath, $gccPath
)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required Step 3 build input is missing: $requiredPath"
    }
}

$clangVersion = @(& $clangPath '--version')[0].ToString()
if ($LASTEXITCODE -ne 0 -or $clangVersion -notmatch '^clang version 23(?:\.|$)') {
    throw "UBE IDE Step 3 requires the verified Clang 23 toolchain; found: $clangVersion"
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

& $gccPath '-std=c11' '-Wall' '-Wextra' '-Werror' '-municode' $nativeSource '-o' $nativeProgram '-loleacc' '-lole32' '-luuid' '-luser32' '-lgdi32'
if ($LASTEXITCODE -ne 0) {
    throw "The Step 3 Win32 adapter failed to compile (exit $LASTEXITCODE)."
}

& $compilerPath '--build-native' $testProject 'x86_64-w64-windows-gnu' $clangPath $runtimeObject $unicodeRuntimeObject $testProgram $testLlvm
if ($LASTEXITCODE -ne 0) {
    throw "Compiler v3 RP8 failed to build the Step 3 model tests (exit $LASTEXITCODE)."
}
& $compilerPath '--build-native' $applicationProject 'x86_64-w64-windows-gnu' $clangPath $runtimeObject $unicodeRuntimeObject $applicationProgram $applicationLlvm
if ($LASTEXITCODE -ne 0) {
    throw "Compiler v3 RP8 failed to build the Step 3 UBE shell (exit $LASTEXITCODE)."
}

& $compilerPath '--emit-llvm' $applicationProject 'x86_64-w64-windows-gnu' $deterministicOne
if ($LASTEXITCODE -ne 0) { throw 'The first deterministic Step 3 LLVM emission failed.' }
& $compilerPath '--emit-llvm' $applicationProject 'x86_64-w64-windows-gnu' $deterministicTwo
if ($LASTEXITCODE -ne 0) { throw 'The second deterministic Step 3 LLVM emission failed.' }
$firstHash = (Get-FileHash -LiteralPath $deterministicOne -Algorithm SHA256).Hash
$secondHash = (Get-FileHash -LiteralPath $deterministicTwo -Algorithm SHA256).Hash
if ($firstHash -ne $secondHash) { throw 'Repeated Step 3 LLVM emission was not byte-identical.' }
Write-Output "Step 3 deterministic LLVM SHA-256: $firstHash"

$modelWork = Join-Path $workRoot 'model'
New-Item -ItemType Directory -Path $modelWork -Force | Out-Null
$modelOutput = @(& $testProgram $sourceLocalePath $modelWork)
$modelStatus = $LASTEXITCODE
$modelOutput | ForEach-Object { Write-Output $_ }
if ($modelStatus -ne 0 -or $modelOutput.Count -eq 0 -or $modelOutput[-1] -notmatch '^STEP3 MODEL PASS [0-9]+$') {
    throw "UBE Step 3 model verification failed (exit $modelStatus)."
}

$integrationRoot = Join-Path $workRoot 'native-document'
New-Item -ItemType Directory -Path $integrationRoot -Force | Out-Null
$layoutPath = Join-Path $integrationRoot 'layout.ube-layout'
$configPath = Join-Path $integrationRoot 'shell-config.txt'
$layoutResultPath = Join-Path $integrationRoot 'layout-result.ube-layout'
$documentPath = Join-Path $integrationRoot 'RealDocument.bas'
$documentInputPath = Join-Path $integrationRoot 'document-input.txt'
$documentOutputPath = Join-Path $integrationRoot 'document-output.txt'
$documentActionPath = Join-Path $integrationRoot 'document-action.txt'
Copy-Item -LiteralPath $defaultLayoutPath -Destination $layoutPath -Force
[System.IO.File]::WriteAllText(
    $documentPath,
    "UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"RealDocument`"`n",
    [System.Text.UTF8Encoding]::new($false))

$watch = [System.Diagnostics.Stopwatch]::StartNew()
$shellOutput = @(& $applicationProgram $nativeProgram $sourceLocalePath $layoutPath `
    $configPath $layoutResultPath $documentPath $documentInputPath $documentOutputPath `
    $documentActionPath '--verify')
$shellStatus = $LASTEXITCODE
$watch.Stop()
$shellOutput | ForEach-Object { Write-Output $_ }
if ($shellStatus -ne 0 -or $shellOutput -notcontains 'NATIVE SHELL PASS' -or
    $shellOutput -notcontains 'STEP3 DOCUMENT PASS') {
    throw "Native Step 3 document verification failed (exit $shellStatus)."
}
if ($watch.ElapsedMilliseconds -gt 2500) {
    throw 'Native Step 3 document verification exceeded the 2500 ms startup-and-check budget.'
}
$savedDocument = Get-Content -LiteralPath $documentPath -Raw
if ($savedDocument -notmatch "Step 3 native document edit") {
    throw 'The real source document did not receive the verified native edit.'
}
if (Test-Path -LiteralPath "$documentPath.ube-recovery") {
    throw 'Successful native document save left a recovery file behind.'
}
foreach ($sessionPath in @($documentInputPath, $documentOutputPath, $documentActionPath)) {
    if (Test-Path -LiteralPath $sessionPath) {
        throw "Successful native document session left a transient file behind: $sessionPath"
    }
}
Write-Output "Native document shell completed in $($watch.ElapsedMilliseconds) ms."

$invalidConfig = Join-Path $integrationRoot 'invalid-document-config.txt'
$invalidResult = Join-Path $integrationRoot 'invalid-document-result.txt'
[System.IO.File]::WriteAllText($invalidConfig, "UBE-IDE-Shell 999`n", [System.Text.UTF8Encoding]::new($false))
& $nativeProgram '--config' $invalidConfig '--result' $invalidResult `
    '--document-input' $documentPath '--document-output' $documentOutputPath `
    '--document-action' $documentActionPath '--verify'
if ($LASTEXITCODE -eq 0) { throw 'Malformed document-shell configuration was not rejected.' }
Write-Output 'Malformed document-shell configuration produced a controlled failure.'
Write-Output 'UBE IDE Step 3 build and native-document verification passed.'

if ($Launch) {
    $interactiveRoot = Join-Path $outputRoot 'interactive-step3'
    New-Item -ItemType Directory -Path $interactiveRoot -Force | Out-Null
    $interactiveLayout = Join-Path $interactiveRoot 'layout.ube-layout'
    if (-not (Test-Path -LiteralPath $interactiveLayout -PathType Leaf)) {
        Copy-Item -LiteralPath $defaultLayoutPath -Destination $interactiveLayout
    }
    & $applicationProgram $nativeProgram $sourceLocalePath $interactiveLayout `
        (Join-Path $interactiveRoot 'config.txt') (Join-Path $interactiveRoot 'layout-result.txt') `
        $documentPath (Join-Path $interactiveRoot 'document-input.txt') `
        (Join-Path $interactiveRoot 'document-output.txt') `
        (Join-Path $interactiveRoot 'document-action.txt')
    if ($LASTEXITCODE -ne 0) { throw "Interactive UBE IDE document shell exited with $LASTEXITCODE." }
}
