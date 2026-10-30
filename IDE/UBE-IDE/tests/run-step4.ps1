[CmdletBinding()]
param(
    [switch]$Launch
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$applicationRoot = Split-Path -Parent $PSScriptRoot
$repositoryRoot = (Resolve-Path (Join-Path $applicationRoot '..\..')).Path
$outputRoot = Join-Path $applicationRoot 'out'
$workRoot = Join-Path $outputRoot 'step4-work'
$compilerPath = Join-Path $repositoryRoot 'compiler\archived\release-previews\ube-v3-rp8-windows-x86_64-x86_64-w64-windows-gnu.exe'
$testProject = Join-Path $applicationRoot 'UBE-IDE-Step4-Tests.UBE'
$applicationProject = Join-Path $applicationRoot 'UBE-IDE.UBE'
$nativeSource = Join-Path $applicationRoot 'platform\windows\ube_ide_win32.c'
$runtimeObject = Join-Path $repositoryRoot 'bootstrap\out\bootstrap_runtime.o'
$unicodeRuntimeObject = Join-Path $repositoryRoot 'bootstrap\out\bootstrap_unicode_runtime.o'
$sourceLocalePath = Join-Path $applicationRoot 'resources\locales\en.ube-locale'
$defaultLayoutPath = Join-Path $applicationRoot 'resources\layouts\default.ube-layout'
$testProgram = Join-Path $outputRoot 'ube-ide-step4-tests.exe'
$applicationProgram = Join-Path $outputRoot 'ube-ide-step4.exe'
$nativeProgram = Join-Path $outputRoot 'ube-ide-win32-step4.exe'
$testLlvm = Join-Path $outputRoot 'ube-ide-step4-tests.ll'
$applicationLlvm = Join-Path $outputRoot 'ube-ide-step4.ll'
$deterministicOne = Join-Path $outputRoot 'ube-ide-step4-deterministic-1.ll'
$deterministicTwo = Join-Path $outputRoot 'ube-ide-step4-deterministic-2.ll'

$clangCommand = Get-Command clang -ErrorAction SilentlyContinue
$clangPath = if ($null -ne $clangCommand) { $clangCommand.Source } else { 'C:\Program Files\LLVM\bin\clang.exe' }
$gccCommand = Get-Command gcc -ErrorAction SilentlyContinue
$gccPath = if ($null -ne $gccCommand) { $gccCommand.Source } else { 'C:\Users\Ubehage\Documents\WinLibs\mingw64\bin\gcc.exe' }

foreach ($requiredPath in @(
    $compilerPath, $testProject, $applicationProject, $nativeSource, $runtimeObject,
    $unicodeRuntimeObject, $sourceLocalePath, $defaultLayoutPath, $clangPath, $gccPath
)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required Step 4 build input is missing: $requiredPath"
    }
}

$clangVersion = @(& $clangPath '--version')[0].ToString()
if ($LASTEXITCODE -ne 0 -or $clangVersion -notmatch '^clang version 23(?:\.|$)') {
    throw "UBE IDE Step 4 requires the verified Clang 23 toolchain; found: $clangVersion"
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
if ($LASTEXITCODE -ne 0) { throw "The Step 4 Win32 adapter failed to compile (exit $LASTEXITCODE)." }

& $compilerPath '--build-native' $testProject 'x86_64-w64-windows-gnu' $clangPath $runtimeObject $unicodeRuntimeObject $testProgram $testLlvm
if ($LASTEXITCODE -ne 0) { throw "Compiler v3 RP8 failed to build the Step 4 model tests (exit $LASTEXITCODE)." }
& $compilerPath '--build-native' $applicationProject 'x86_64-w64-windows-gnu' $clangPath $runtimeObject $unicodeRuntimeObject $applicationProgram $applicationLlvm
if ($LASTEXITCODE -ne 0) { throw "Compiler v3 RP8 failed to build the Step 4 application (exit $LASTEXITCODE)." }

& $compilerPath '--emit-llvm' $applicationProject 'x86_64-w64-windows-gnu' $deterministicOne
if ($LASTEXITCODE -ne 0) { throw 'The first deterministic Step 4 LLVM emission failed.' }
& $compilerPath '--emit-llvm' $applicationProject 'x86_64-w64-windows-gnu' $deterministicTwo
if ($LASTEXITCODE -ne 0) { throw 'The second deterministic Step 4 LLVM emission failed.' }
$firstHash = (Get-FileHash -LiteralPath $deterministicOne -Algorithm SHA256).Hash
$secondHash = (Get-FileHash -LiteralPath $deterministicTwo -Algorithm SHA256).Hash
if ($firstHash -ne $secondHash) { throw 'Repeated Step 4 LLVM emission was not byte-identical.' }
Write-Output "Step 4 deterministic LLVM SHA-256: $firstHash"

$modelOutput = @(& $testProgram)
$modelStatus = $LASTEXITCODE
$modelOutput | ForEach-Object { Write-Output $_ }
if ($modelStatus -ne 0 -or $modelOutput.Count -eq 0 -or $modelOutput[-1] -notmatch '^STEP4 MODEL PASS [0-9]+$') {
    throw "UBE Step 4 model verification failed (exit $modelStatus)."
}

$integrationRoot = Join-Path $workRoot 'workspace-cycle'
New-Item -ItemType Directory -Path $integrationRoot -Force | Out-Null
$layoutPath = Join-Path $integrationRoot 'layout.ube-layout'
$configPath = Join-Path $integrationRoot 'shell-config.txt'
$layoutResultPath = Join-Path $integrationRoot 'layout-result.ube-layout'
$documentPath = Join-Path $integrationRoot 'Main.bas'
$secondSourcePath = Join-Path $integrationRoot 'Helpers.bas'
$projectPath = Join-Path $integrationRoot 'Workspace.UBE'
$documentInputPath = Join-Path $integrationRoot 'document-input.txt'
$documentOutputPath = Join-Path $integrationRoot 'document-output.txt'
$documentActionPath = Join-Path $integrationRoot 'document-action.txt'
Copy-Item -LiteralPath $defaultLayoutPath -Destination $layoutPath -Force
$utf8 = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($documentPath, "UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"Main`"`n", $utf8)
[System.IO.File]::WriteAllText($secondSourcePath, "UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"Helpers`"`n", $utf8)
[System.IO.File]::WriteAllText($projectPath, "UBE-Project 1`nName = `"Step4Workspace`"`nKind = `"Exe`"`nStartup = `"Main`"`nSource = `"Main.bas`"`nSource = `"Helpers.bas`"`n", $utf8)
$sourceHashBefore = (Get-FileHash -LiteralPath $documentPath -Algorithm SHA256).Hash

function Invoke-WorkspaceCycle {
    param([Parameter(Mandatory)] [string]$Name)
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $output = @(& $applicationProgram $nativeProgram $sourceLocalePath $layoutPath `
        $configPath $layoutResultPath $documentPath $documentInputPath $documentOutputPath `
        $documentActionPath $projectPath '--verify')
    $status = $LASTEXITCODE
    $watch.Stop()
    $output | ForEach-Object { Write-Output $_ }
    if ($status -ne 0 -or $output -notcontains 'NATIVE SHELL PASS' -or
        $output -notcontains 'STEP4 WORKSPACE PASS') {
        throw "Native Step 4 workspace verification '$Name' failed (exit $status)."
    }
    if ($watch.ElapsedMilliseconds -gt 2500) {
        throw "Native Step 4 workspace verification '$Name' exceeded the 2500 ms budget."
    }
    Write-Output "Native workspace '$Name' completed in $($watch.ElapsedMilliseconds) ms."
}

Invoke-WorkspaceCycle -Name 'customize'
$customLayout = Get-Content -LiteralPath $layoutPath -Raw
if ($customLayout -notmatch 'ProjectExplorer.Mode = "1"' -or
    $customLayout -notmatch 'Properties.Mode = "2"' -or
    $customLayout -notmatch 'Output.Mode = "3"') {
    throw 'The first workspace launch did not persist float, hidden, and auto-hide state.'
}
Invoke-WorkspaceCycle -Name 'restore-and-reset'
$resetLayout = Get-Content -LiteralPath $layoutPath -Raw
if ($resetLayout -match '(ProjectExplorer|Properties|Output)\.Mode = "[123]"') {
    throw 'Reset Layout did not restore all workspace tools to their accepted defaults.'
}
$sourceHashAfter = (Get-FileHash -LiteralPath $documentPath -Algorithm SHA256).Hash
if ($sourceHashAfter -ne $sourceHashBefore) {
    throw 'Workspace customization changed the active source document.'
}
foreach ($sessionPath in @($documentInputPath, $documentOutputPath, $documentActionPath)) {
    if (Test-Path -LiteralPath $sessionPath) {
        throw "Workspace cycle left a transient document file behind: $sessionPath"
    }
}
Write-Output 'UBE IDE Step 4 real-workspace restart verification passed.'

if ($Launch) {
    & $applicationProgram $nativeProgram $sourceLocalePath $layoutPath $configPath `
        $layoutResultPath $documentPath $documentInputPath $documentOutputPath `
        $documentActionPath $projectPath
    if ($LASTEXITCODE -ne 0) { throw "Interactive UBE IDE workspace exited with $LASTEXITCODE." }
}
