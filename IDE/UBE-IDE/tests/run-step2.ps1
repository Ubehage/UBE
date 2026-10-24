[CmdletBinding()]
param(
    [switch]$Launch
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$applicationRoot = Split-Path -Parent $PSScriptRoot
$repositoryRoot = (Resolve-Path (Join-Path $applicationRoot '..\..')).Path
$outputRoot = Join-Path $applicationRoot 'out'
$workRoot = Join-Path $outputRoot 'step2-work'
$compilerPath = Join-Path $repositoryRoot 'compiler\release-previews\ube-v3-rp7-windows-x86_64-x86_64-w64-windows-gnu.exe'
$testProject = Join-Path $applicationRoot 'UBE-IDE-Step2-Tests.UBE'
$applicationProject = Join-Path $applicationRoot 'UBE-IDE.UBE'
$nativeSource = Join-Path $applicationRoot 'platform\windows\ube_ide_win32.c'
$runtimeObject = Join-Path $repositoryRoot 'bootstrap\out\bootstrap_runtime.o'
$unicodeRuntimeObject = Join-Path $repositoryRoot 'bootstrap\out\bootstrap_unicode_runtime.o'
$sourceLocalePath = Join-Path $applicationRoot 'resources\locales\en.ube-locale'
$defaultLayoutPath = Join-Path $applicationRoot 'resources\layouts\default.ube-layout'
$testProgram = Join-Path $outputRoot 'ube-ide-step2-tests.exe'
$applicationProgram = Join-Path $outputRoot 'ube-ide.exe'
$nativeProgram = Join-Path $outputRoot 'ube-ide-win32.exe'
$testLlvm = Join-Path $outputRoot 'ube-ide-step2-tests.ll'
$applicationLlvm = Join-Path $outputRoot 'ube-ide.ll'
$deterministicOne = Join-Path $outputRoot 'ube-ide-step2-deterministic-1.ll'
$deterministicTwo = Join-Path $outputRoot 'ube-ide-step2-deterministic-2.ll'

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
        throw "Required Step 2 build input is missing: $requiredPath"
    }
}

$clangVersion = @(& $clangPath '--version')[0].ToString()
if ($LASTEXITCODE -ne 0 -or $clangVersion -notmatch '^clang version 23(?:\.|$)') {
    throw "UBE IDE Step 2 requires the verified Clang 23 toolchain; found: $clangVersion"
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
    throw "The Step 2 Win32 adapter failed to compile (exit $LASTEXITCODE)."
}

& $compilerPath '--build-native' $testProject 'x86_64-w64-windows-gnu' $clangPath $runtimeObject $unicodeRuntimeObject $testProgram $testLlvm
if ($LASTEXITCODE -ne 0) {
    throw "Compiler v3 failed to build the Step 2 model tests (exit $LASTEXITCODE)."
}
& $compilerPath '--build-native' $applicationProject 'x86_64-w64-windows-gnu' $clangPath $runtimeObject $unicodeRuntimeObject $applicationProgram $applicationLlvm
if ($LASTEXITCODE -ne 0) {
    throw "Compiler v3 failed to build the Step 2 UBE shell (exit $LASTEXITCODE)."
}

& $compilerPath '--emit-llvm' $applicationProject 'x86_64-w64-windows-gnu' $deterministicOne
if ($LASTEXITCODE -ne 0) { throw 'The first deterministic Step 2 LLVM emission failed.' }
& $compilerPath '--emit-llvm' $applicationProject 'x86_64-w64-windows-gnu' $deterministicTwo
if ($LASTEXITCODE -ne 0) { throw 'The second deterministic Step 2 LLVM emission failed.' }
$firstHash = (Get-FileHash -LiteralPath $deterministicOne -Algorithm SHA256).Hash
$secondHash = (Get-FileHash -LiteralPath $deterministicTwo -Algorithm SHA256).Hash
if ($firstHash -ne $secondHash) { throw 'Repeated Step 2 LLVM emission was not byte-identical.' }
Write-Output "Step 2 deterministic LLVM SHA-256: $firstHash"

$modelOutput = @(& $testProgram $sourceLocalePath)
$modelStatus = $LASTEXITCODE
$modelOutput | ForEach-Object { Write-Output $_ }
if ($modelStatus -ne 0 -or $modelOutput.Count -eq 0 -or $modelOutput[-1] -ne 'STEP2 MODEL PASS') {
    throw "UBE Step 2 model verification failed (exit $modelStatus)."
}

function Invoke-ShellVerification {
    param(
        [Parameter(Mandatory)] [string]$LayoutPath,
        [Parameter(Mandatory)] [string]$Name
    )
    $configPath = Join-Path $workRoot "$Name-config.txt"
    $resultPath = Join-Path $workRoot "$Name-result.ube-layout"
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $output = @(& $applicationProgram $nativeProgram $sourceLocalePath $LayoutPath $configPath $resultPath '--verify')
    $status = $LASTEXITCODE
    $watch.Stop()
    $output | ForEach-Object { Write-Output $_ }
    if ($status -ne 0 -or $output -notcontains 'NATIVE SHELL PASS' -or $output -notcontains 'STEP2 SHELL PASS') {
        throw "Native Step 2 shell verification '$Name' failed (exit $status)."
    }
    if ($watch.ElapsedMilliseconds -gt 2000) {
        throw "Native Step 2 shell verification '$Name' exceeded the 2000 ms startup-and-check budget."
    }
    Write-Output "Native shell '$Name' completed in $($watch.ElapsedMilliseconds) ms."
}

$normalLayout = Join-Path $workRoot 'normal.ube-layout'
Copy-Item -LiteralPath $defaultLayoutPath -Destination $normalLayout -Force
Invoke-ShellVerification -LayoutPath $normalLayout -Name 'normal'

$corruptLayout = Join-Path $workRoot 'corrupt.ube-layout'
[System.IO.File]::WriteAllText($corruptLayout, "not a layout`n", [System.Text.UTF8Encoding]::new($false))
Invoke-ShellVerification -LayoutPath $corruptLayout -Name 'corrupt-recovery'
if ((Get-Content -LiteralPath $corruptLayout -TotalCount 1) -ne 'UBE-IDE-Layout 1') {
    throw 'Corrupt layout verification did not publish a repaired default layout.'
}

$offscreenLayout = Join-Path $workRoot 'offscreen.ube-layout'
$offscreenText = (Get-Content -LiteralPath $defaultLayoutPath -Raw).
    Replace('Main.Left = "80"', 'Main.Left = "99999"').
    Replace('Main.Top = "60"', 'Main.Top = "99999"').
    Replace('ProjectExplorer.Mode = "0"', 'ProjectExplorer.Mode = "1"').
    Replace('ProjectExplorer.Left = "880"', 'ProjectExplorer.Left = "99999"').
    Replace('ProjectExplorer.Top = "100"', 'ProjectExplorer.Top = "99999"')
[System.IO.File]::WriteAllText($offscreenLayout, $offscreenText, [System.Text.UTF8Encoding]::new($false))
Invoke-ShellVerification -LayoutPath $offscreenLayout -Name 'offscreen-recovery'
if ((Get-Content -LiteralPath $offscreenLayout -Raw) -match 'Main.Left = "99999"') {
    throw 'Off-screen main-window bounds were not repaired.'
}

$invalidConfig = Join-Path $workRoot 'invalid-shell-config.txt'
$invalidResult = Join-Path $workRoot 'invalid-shell-result.ube-layout'
[System.IO.File]::WriteAllText($invalidConfig, "UBE-IDE-Shell 999`n", [System.Text.UTF8Encoding]::new($false))
& $nativeProgram '--config' $invalidConfig '--result' $invalidResult '--verify'
if ($LASTEXITCODE -eq 0) { throw 'Malformed native-shell configuration was not rejected.' }
Write-Output 'Malformed native-shell configuration produced a controlled failure.'

Write-Output 'UBE IDE Step 2 build and native-shell verification passed.'

if ($Launch) {
    $interactiveLayout = Join-Path $outputRoot 'interactive.ube-layout'
    if (-not (Test-Path -LiteralPath $interactiveLayout -PathType Leaf)) {
        Copy-Item -LiteralPath $defaultLayoutPath -Destination $interactiveLayout
    }
    & $applicationProgram $nativeProgram $sourceLocalePath $interactiveLayout `
        (Join-Path $outputRoot 'interactive-config.txt') `
        (Join-Path $outputRoot 'interactive-result.ube-layout')
    if ($LASTEXITCODE -ne 0) { throw "Interactive UBE IDE shell exited with $LASTEXITCODE." }
}
