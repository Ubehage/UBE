[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$applicationRoot = Split-Path -Parent $PSScriptRoot
$repositoryRoot = (Resolve-Path (Join-Path $applicationRoot '..\..')).Path
$outputRoot = Join-Path $applicationRoot 'out'
$workRoot = Join-Path $outputRoot 'step6-work'
$compilerPath = Join-Path $repositoryRoot 'compiler\archived\release-previews\ube-v3-rp8-windows-x86_64-x86_64-w64-windows-gnu.exe'
$testProject = Join-Path $applicationRoot 'UBE-IDE-Step6-Tests.UBE'
$runtimeObject = Join-Path $repositoryRoot 'bootstrap\out\bootstrap_runtime.o'
$unicodeRuntimeObject = Join-Path $repositoryRoot 'bootstrap\out\bootstrap_unicode_runtime.o'
$testProgram = Join-Path $outputRoot 'ube-ide-step6-tests.exe'
$testLlvm = Join-Path $outputRoot 'ube-ide-step6-tests.ll'
$deterministicOne = Join-Path $outputRoot 'ube-ide-step6-deterministic-1.ll'
$deterministicTwo = Join-Path $outputRoot 'ube-ide-step6-deterministic-2.ll'
$faultSource = Join-Path $PSScriptRoot 'service-fault-fixture.c'
$faultProgram = Join-Path $outputRoot 'ube-ide-service-fault-fixture.exe'
$nativeSource = Join-Path $applicationRoot 'platform\windows\ube_ide_win32.c'
$nativeProgram = Join-Path $outputRoot 'ube-ide-win32.exe'
$validConfig = Join-Path $PSScriptRoot 'fixtures\step6-shell-config.txt'
$normalResult = Join-Path $workRoot 'normal-result.ube-layout'
$allocationResult = Join-Path $workRoot 'allocation-failure-result.ube-layout'

$clangCommand = Get-Command clang -ErrorAction SilentlyContinue
$clangPath = if ($null -ne $clangCommand) { $clangCommand.Source } else { 'C:\Program Files\LLVM\bin\clang.exe' }
$gccCommand = Get-Command gcc -ErrorAction SilentlyContinue
$gccPath = if ($null -ne $gccCommand) { $gccCommand.Source } else { 'C:\Users\Ubehage\Documents\WinLibs\mingw64\bin\gcc.exe' }

foreach ($requiredPath in @($compilerPath, $testProject, $runtimeObject, $unicodeRuntimeObject, $faultSource, $nativeSource, $validConfig, $clangPath, $gccPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required Step 6 build input is missing: $requiredPath"
    }
}

$clangVersion = @(& $clangPath '--version')[0].ToString()
if ($LASTEXITCODE -ne 0 -or $clangVersion -notmatch '^clang version 23(?:\.|$)') {
    throw "UBE IDE Step 6 requires the verified Clang 23 toolchain; found: $clangVersion"
}

New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
New-Item -ItemType Directory -Path $workRoot -Force | Out-Null

& $compilerPath '--build-native' $testProject 'x86_64-w64-windows-gnu' $clangPath $runtimeObject $unicodeRuntimeObject $testProgram $testLlvm
if ($LASTEXITCODE -ne 0) { throw "Compiler v3 RP8 failed to build the Step 6 risk tests (exit $LASTEXITCODE)." }
& $compilerPath '--emit-llvm' $testProject 'x86_64-w64-windows-gnu' $deterministicOne
if ($LASTEXITCODE -ne 0) { throw 'The first deterministic Step 6 emission failed.' }
& $compilerPath '--emit-llvm' $testProject 'x86_64-w64-windows-gnu' $deterministicTwo
if ($LASTEXITCODE -ne 0) { throw 'The second deterministic Step 6 emission failed.' }
$firstHash = (Get-FileHash -LiteralPath $deterministicOne -Algorithm SHA256).Hash
$secondHash = (Get-FileHash -LiteralPath $deterministicTwo -Algorithm SHA256).Hash
if ($firstHash -ne $secondHash) { throw 'Repeated Step 6 LLVM emission was not byte-identical.' }
Write-Output "Step 6 deterministic LLVM SHA-256: $firstHash"

$modelWatch = [System.Diagnostics.Stopwatch]::StartNew()
$modelOutput = @(& $testProgram)
$modelStatus = $LASTEXITCODE
$modelWatch.Stop()
$modelOutput | ForEach-Object { Write-Output $_ }
if ($modelStatus -ne 0 -or $modelOutput.Count -eq 0 -or $modelOutput[-1] -notmatch '^STEP6 PASS [0-9]+$') {
    throw "UBE Step 6 service-supervisor verification failed (exit $modelStatus)."
}
if ($modelWatch.ElapsedMilliseconds -gt 1000) { throw 'Step 6 model exceeded its 1000 ms responsiveness budget.' }
Write-Output "Service-supervisor checks completed in $($modelWatch.ElapsedMilliseconds) ms."

& $gccPath '-std=c11' '-Wall' '-Wextra' '-Werror' $faultSource '-o' $faultProgram
if ($LASTEXITCODE -ne 0) { throw "Service fault fixture failed to compile (exit $LASTEXITCODE)." }
& $gccPath '-std=c11' '-Wall' '-Wextra' '-Werror' '-municode' $nativeSource '-o' $nativeProgram '-loleacc' '-lole32' '-luuid' '-luser32' '-lgdi32'
if ($LASTEXITCODE -ne 0) { throw "The Step 6 Win32 adapter failed to compile (exit $LASTEXITCODE)." }

$unsavedPath = Join-Path $workRoot 'unsaved-document.bas'
$unsavedText = "UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"Unsaved`"`n' retained across service faults`n"
[System.IO.File]::WriteAllText($unsavedPath, $unsavedText, [System.Text.UTF8Encoding]::new($false))
$unsavedHash = (Get-FileHash -LiteralPath $unsavedPath -Algorithm SHA256).Hash

$crashProcess = Start-Process -FilePath $faultProgram -ArgumentList 'crash' -PassThru -WindowStyle Hidden
$crashProcess.WaitForExit(2000) | Out-Null
if (-not $crashProcess.HasExited -or $crashProcess.ExitCode -eq 0) { throw 'Service crash was not observed as an isolated child-process failure.' }

$hangWatch = [System.Diagnostics.Stopwatch]::StartNew()
$hangProcess = Start-Process -FilePath $faultProgram -ArgumentList 'hang' -PassThru -WindowStyle Hidden
if ($hangProcess.WaitForExit(750)) { throw 'The hang fixture exited before its timeout.' }
Stop-Process -Id $hangProcess.Id -Force
$hangProcess.WaitForExit()
$hangWatch.Stop()
if ($hangWatch.ElapsedMilliseconds -gt 2000) { throw 'Hung service containment exceeded 2000 ms.' }
if ((Get-FileHash -LiteralPath $unsavedPath -Algorithm SHA256).Hash -ne $unsavedHash) {
    throw 'Service crash or hang changed the unsaved-document fixture.'
}
Write-Output "Crash and hang isolation preserved editing state; hang contained in $($hangWatch.ElapsedMilliseconds) ms."

$shellWatch = [System.Diagnostics.Stopwatch]::StartNew()
$shellOutput = @(& $nativeProgram '--config' $validConfig '--result' $normalResult '--verify')
$shellStatus = $LASTEXITCODE
$shellWatch.Stop()
$shellOutput | ForEach-Object { Write-Output $_ }
if ($shellStatus -ne 0 -or $shellOutput -notcontains 'NATIVE SHELL PASS') {
    throw "Keyboard, accessibility, DPI, monitor, and layout verification failed (exit $shellStatus)."
}
if ($shellWatch.ElapsedMilliseconds -gt 2000) { throw 'Native shell exceeded the 2000 ms cold-start budget.' }
Write-Output "Native risk gates completed in $($shellWatch.ElapsedMilliseconds) ms."

[System.IO.File]::WriteAllText($allocationResult, "sentinel`n", [System.Text.UTF8Encoding]::new($false))
$beforeAllocationHash = (Get-FileHash -LiteralPath $allocationResult -Algorithm SHA256).Hash
& $nativeProgram '--config' $validConfig '--result' $allocationResult '--verify' '--verify-allocation-failure'
if ($LASTEXITCODE -eq 0) { throw 'Injected native allocation failure was not rejected.' }
if ((Get-FileHash -LiteralPath $allocationResult -Algorithm SHA256).Hash -ne $beforeAllocationHash) {
    throw 'Injected allocation failure replaced the last good result.'
}
Write-Output 'Injected allocation failure produced a controlled error and preserved the last good file.'
Write-Output 'UBE IDE Step 6 architectural risk gates passed.'
