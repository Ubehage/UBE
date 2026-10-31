$ErrorActionPreference = 'Stop'
# Expected-failure executables write diagnostics to stderr. PowerShell 7 can
# otherwise promote that native stderr to a terminating ErrorRecord before the
# test can inspect the process exit code.
$PSNativeCommandUseErrorActionPreference = $false

function Invoke-ExpectedNativeFailure {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @()
    )

    $savedErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $capturedOutput = & $FilePath @Arguments 2>&1
        $capturedExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $savedErrorActionPreference
    }
    return [pscustomobject]@{
        ExitCode = $capturedExitCode
        Output = (($capturedOutput | ForEach-Object { $_.ToString() }) -join "`n")
    }
}
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $PSScriptRoot 'out'
$expectedOut = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'out'))
if ([System.IO.Path]::GetFullPath($out) -ne $expectedOut) {
    throw 'Refusing to clean an unexpected bootstrap output directory'
}
if (Test-Path -LiteralPath $out) {
    Remove-Item -LiteralPath $out -Recurse -Force
}
New-Item -ItemType Directory -Path $out | Out-Null

$common = @('-std=c++17', '-Wall', '-Wextra', '-Wpedantic', '-Werror', '-I', (Join-Path $PSScriptRoot 'include'))
$sources = @((Join-Path $PSScriptRoot 'src/lexer.cpp'), (Join-Path $PSScriptRoot 'src/unicode.cpp'))
$parserSources = @($sources + (Join-Path $PSScriptRoot 'src/parser.cpp'))
$compilerSources = @($parserSources + (Join-Path $PSScriptRoot 'src/semantic.cpp'), (Join-Path $PSScriptRoot 'src/codegen.cpp'))
& g++ @common @compilerSources (Join-Path $PSScriptRoot 'src/main.cpp') '-o' (Join-Path $out 'ubec.exe')
if ($LASTEXITCODE -ne 0) { throw 'Compiler build failed' }
& g++ @common @sources (Join-Path $PSScriptRoot 'tests/lexer_tests.cpp') '-o' (Join-Path $out 'lexer_tests.exe')
if ($LASTEXITCODE -ne 0) { throw 'Test build failed' }
& (Join-Path $out 'lexer_tests.exe')
if ($LASTEXITCODE -ne 0) { throw 'Lexer tests failed' }

& g++ @common @parserSources (Join-Path $PSScriptRoot 'tests/parser_tests.cpp') '-o' (Join-Path $out 'parser_tests.exe')
if ($LASTEXITCODE -ne 0) { throw 'Parser test build failed' }
& (Join-Path $out 'parser_tests.exe')
if ($LASTEXITCODE -ne 0) { throw 'Parser tests failed' }

& g++ @common @compilerSources (Join-Path $PSScriptRoot 'tests/semantic_tests.cpp') '-o' (Join-Path $out 'semantic_tests.exe')
if ($LASTEXITCODE -ne 0) { throw 'Semantic test build failed' }
& (Join-Path $out 'semantic_tests.exe')
if ($LASTEXITCODE -ne 0) { throw 'Semantic tests failed' }

& g++ @common @compilerSources (Join-Path $PSScriptRoot 'tests/codegen_tests.cpp') '-o' (Join-Path $out 'codegen_tests.exe')
if ($LASTEXITCODE -ne 0) { throw 'Codegen test build failed' }
& (Join-Path $out 'codegen_tests.exe')
if ($LASTEXITCODE -ne 0) { throw 'Codegen tests failed' }

& gcc '-std=c17' '-Wall' '-Wextra' '-Wpedantic' '-Werror' '-c' `
    (Join-Path $root 'runtime/bootstrap_runtime.c') '-o' (Join-Path $out 'bootstrap_runtime.o')
if ($LASTEXITCODE -ne 0) { throw 'Bootstrap runtime build failed' }
$errorStateProbe = Join-Path $out 'error-state-probe.exe'
& gcc '-std=c17' '-Wall' '-Wextra' '-Wpedantic' '-Werror' `
    (Join-Path $PSScriptRoot 'tests/error_state_probe.c') (Join-Path $out 'bootstrap_runtime.o') `
    '-o' $errorStateProbe
if ($LASTEXITCODE -ne 0) { throw 'Thread-local error-state probe build failed' }
$errorStateOutput = & $errorStateProbe
if ($LASTEXITCODE -ne 0 -or $errorStateOutput -ne 'error state probe passed') {
    throw 'Thread-local error-state probe failed'
}
$threadLifecycleProbe = Join-Path $out 'thread-lifecycle-probe.exe'
& gcc '-std=c17' '-Wall' '-Wextra' '-Wpedantic' '-Werror' `
    (Join-Path $PSScriptRoot 'tests/thread_lifecycle_probe.c') (Join-Path $out 'bootstrap_runtime.o') `
    '-o' $threadLifecycleProbe
if ($LASTEXITCODE -ne 0) { throw 'Thread lifecycle probe build failed' }
$threadLifecycleOutput = & $threadLifecycleProbe
if ($LASTEXITCODE -ne 0 -or $threadLifecycleOutput -ne 'thread lifecycle probe passed') {
    throw 'Thread lifecycle probe failed'
}
$monitorProbe = Join-Path $out 'monitor-probe.exe'
& gcc '-std=c17' '-Wall' '-Wextra' '-Wpedantic' '-Werror' `
    (Join-Path $PSScriptRoot 'tests/monitor_probe.c') (Join-Path $out 'bootstrap_runtime.o') `
    '-o' $monitorProbe
if ($LASTEXITCODE -ne 0) { throw 'Object monitor probe build failed' }
$monitorOutput = & $monitorProbe
if ($LASTEXITCODE -ne 0 -or $monitorOutput -ne 'monitor probe passed') {
    throw 'Object monitor probe failed'
}
$atomicProbe = Join-Path $out 'atomic-probe.exe'
& gcc '-std=c17' '-Wall' '-Wextra' '-Wpedantic' '-Werror' `
    (Join-Path $PSScriptRoot 'tests/atomic_probe.c') (Join-Path $out 'bootstrap_runtime.o') `
    '-o' $atomicProbe
if ($LASTEXITCODE -ne 0) { throw 'Atomic operation probe build failed' }
$atomicOutput = & $atomicProbe
if ($LASTEXITCODE -ne 0 -or $atomicOutput -ne 'atomic probe passed') {
    throw 'Atomic operation probe failed'
}
$threadEventProbe = Join-Path $out 'thread-event-probe.exe'
& gcc '-std=c17' '-Wall' '-Wextra' '-Wpedantic' '-Werror' `
    (Join-Path $PSScriptRoot 'tests/thread_event_probe.c') (Join-Path $out 'bootstrap_runtime.o') `
    '-o' $threadEventProbe
if ($LASTEXITCODE -ne 0) { throw 'Thread-event probe build failed' }
$threadEventOutput = & $threadEventProbe
if ($LASTEXITCODE -ne 0 -or $threadEventOutput -ne 'thread event probe passed') {
    throw 'Thread-event probe failed'
}
$semaphoreProbe = Join-Path $out 'semaphore-probe.exe'
& gcc '-std=c17' '-Wall' '-Wextra' '-Wpedantic' '-Werror' `
    (Join-Path $PSScriptRoot 'tests/semaphore_probe.c') (Join-Path $out 'bootstrap_runtime.o') `
    '-o' $semaphoreProbe
if ($LASTEXITCODE -ne 0) { throw 'Semaphore probe build failed' }
$semaphoreOutput = & $semaphoreProbe
if ($LASTEXITCODE -ne 0 -or $semaphoreOutput -ne 'semaphore probe passed') {
    throw 'Semaphore probe failed'
}
$messageQueueProbe = Join-Path $out 'message-queue-probe.exe'
& gcc '-std=c17' '-Wall' '-Wextra' '-Wpedantic' '-Werror' `
    (Join-Path $PSScriptRoot 'tests/message_queue_probe.c') (Join-Path $out 'bootstrap_runtime.o') `
    '-o' $messageQueueProbe
if ($LASTEXITCODE -ne 0) { throw 'Message-queue probe build failed' }
$messageQueueOutput = & $messageQueueProbe
if ($LASTEXITCODE -ne 0 -or $messageQueueOutput -ne 'message queue probe passed') {
    throw 'Message-queue probe failed'
}
$componentProbe = Join-Path $out 'component-probe.exe'
& gcc '-std=c17' '-Wall' '-Wextra' '-Wpedantic' '-Werror' `
    (Join-Path $PSScriptRoot 'tests/component_probe.c') (Join-Path $out 'bootstrap_runtime.o') `
    '-o' $componentProbe
if ($LASTEXITCODE -ne 0) { throw 'Component lifetime probe build failed' }
$componentOutput = & $componentProbe
if ($LASTEXITCODE -ne 0 -or $componentOutput -ne 'component probe passed') {
    throw 'Component lifetime probe failed'
}
$gcProbe = Join-Path $out 'gc-probe.exe'
& gcc '-std=c17' '-Wall' '-Wextra' '-Wpedantic' '-Werror' `
    (Join-Path $PSScriptRoot 'tests/gc_probe.c') (Join-Path $out 'bootstrap_runtime.o') `
    '-o' $gcProbe
if ($LASTEXITCODE -ne 0) { throw 'Managed tracing probe build failed' }
$gcProbeOutput = & $gcProbe
if ($LASTEXITCODE -ne 0 -or $gcProbeOutput -ne 'gc probe passed') {
    throw 'Managed tracing probe failed'
}
$gcFatal = Invoke-ExpectedNativeFailure -FilePath $gcProbe -Arguments @('--trace-fatal')
if ($gcFatal.ExitCode -ne 70 -or $gcFatal.Output -notlike '*insufficient bookkeeping memory while tracing*') {
    throw 'Managed tracing controlled-fatal probe failed'
}
$gcConcurrencyProbe = Join-Path $out 'gc-concurrency-probe.exe'
& gcc '-std=c17' '-Wall' '-Wextra' '-Wpedantic' '-Werror' `
    (Join-Path $PSScriptRoot 'tests/gc_concurrency_probe.c') (Join-Path $out 'bootstrap_runtime.o') `
    '-o' $gcConcurrencyProbe
if ($LASTEXITCODE -ne 0) { throw 'Managed tracing concurrency probe build failed' }
$gcConcurrencyOutput = & $gcConcurrencyProbe
if ($LASTEXITCODE -ne 0 -or $gcConcurrencyOutput -ne 'GC concurrency probe passed') {
    throw 'Managed tracing concurrency probe failed'
}
& g++ @common '-c' (Join-Path $root 'runtime/bootstrap_unicode_runtime.cpp') `
    '-o' (Join-Path $out 'bootstrap_unicode_runtime.o')
if ($LASTEXITCODE -ne 0) { throw 'Bootstrap Unicode runtime build failed' }

$subProgram = Join-Path $out 'sub_main.exe'
& (Join-Path $out 'ubec.exe') '--compile' `
    (Join-Path $PSScriptRoot 'tests/fixtures/sub_main.bas') '-o' $subProgram
if ($LASTEXITCODE -ne 0) { throw 'Sub Main native compilation failed' }
$subOutput = & $subProgram
if ($LASTEXITCODE -ne 0) { throw 'Sub Main did not return exit code zero' }
if ($subOutput -ne 'sub-main') { throw 'Sub Main produced unexpected output' }

$functionProgram = Join-Path $out 'exit_code.exe'
& (Join-Path $out 'ubec.exe') '--compile' `
    (Join-Path $PSScriptRoot 'tests/fixtures/exit_code.bas') '-o' $functionProgram
if ($LASTEXITCODE -ne 0) { throw 'Function Main native compilation failed' }
$functionOutput = & $functionProgram
if ($LASTEXITCODE -ne 7) { throw 'Function Main did not return its Long result as the exit code' }
if ($functionOutput -ne 'function-main') { throw 'Function Main produced unexpected output' }

$controlProgram = Join-Path $out 'control_flow.exe'
& (Join-Path $out 'ubec.exe') '--compile' `
    (Join-Path $PSScriptRoot 'tests/fixtures/control_flow.bas') '-o' $controlProgram
if ($LASTEXITCODE -ne 0) { throw 'Control-flow native compilation failed' }
$controlOutput = & $controlProgram
if ($LASTEXITCODE -ne 0) { throw 'Control-flow program returned a nonzero exit code' }
if (($controlOutput -join ',') -ne '0,middle,2') { throw 'Control-flow program produced unexpected output' }

$procedureProgram = Join-Path $out 'procedures.exe'
& (Join-Path $out 'ubec.exe') '--compile' `
    (Join-Path $PSScriptRoot 'tests/fixtures/procedures.bas') '-o' $procedureProgram
if ($LASTEXITCODE -ne 0) { throw 'Procedure-call native compilation failed' }
$procedureOutput = & $procedureProgram
if ($LASTEXITCODE -ne 0) { throw 'Procedure-call program returned a nonzero exit code' }
if ($procedureOutput -ne '42') { throw 'Procedure-call program produced unexpected output' }

$byrefProgram = Join-Path $out 'byref.exe'
& (Join-Path $out 'ubec.exe') '--compile' `
    (Join-Path $PSScriptRoot 'tests/fixtures/byref.bas') '-o' $byrefProgram
if ($LASTEXITCODE -ne 0) { throw 'ByRef native compilation failed' }
$byrefOutput = & $byrefProgram
if ($LASTEXITCODE -ne 0) { throw 'ByRef program returned a nonzero exit code' }
if (($byrefOutput -join ',') -ne '44,updated') { throw 'ByRef program produced unexpected output' }

$arrayProgram = Join-Path $out 'arrays.exe'
& (Join-Path $out 'ubec.exe') '--compile' `
    (Join-Path $PSScriptRoot 'tests/fixtures/arrays.bas') '-o' $arrayProgram
if ($LASTEXITCODE -ne 0) { throw 'Dynamic-array native compilation failed' }
$arrayOutput = & $arrayProgram
if ($LASTEXITCODE -ne 0) { throw 'Dynamic-array program returned a nonzero exit code' }
if (($arrayOutput -join ',') -ne '60,1,4,dynamic arrays') { throw 'Dynamic-array program produced unexpected output' }

$typeProgram = Join-Path $out 'user_types.exe'
& (Join-Path $out 'ubec.exe') '--compile' `
    (Join-Path $PSScriptRoot 'tests/fixtures/user_types.bas') '-o' $typeProgram
if ($LASTEXITCODE -ne 0) { throw 'User-defined-type native compilation failed' }
$typeOutput = & $typeProgram
if ($LASTEXITCODE -ne 0) { throw 'User-defined-type program returned a nonzero exit code' }
if (($typeOutput -join ',') -ne '7,identifier,11,first,12,second,13,third') { throw 'User-defined-type program produced unexpected output' }

$forProgram = Join-Path $out 'for_loops.exe'
& (Join-Path $out 'ubec.exe') '--compile' `
    (Join-Path $PSScriptRoot 'tests/fixtures/for_loops.bas') '-o' $forProgram
if ($LASTEXITCODE -ne 0) { throw 'For-loop native compilation failed' }
$forOutput = & $forProgram
if ($LASTEXITCODE -ne 0) { throw 'For-loop program returned a nonzero exit code' }
if (($forOutput -join ',') -ne '1,2,3,3,1,2') { throw 'For-loop program produced unexpected output' }

$overflowProgram = Join-Path $out 'integer_overflow.exe'
& (Join-Path $out 'ubec.exe') '--compile' `
    (Join-Path $PSScriptRoot 'tests/fixtures/integer_overflow.bas') '-o' $overflowProgram
if ($LASTEXITCODE -ne 0) { throw 'Integer-overflow native compilation failed' }
$overflowFailure = Invoke-ExpectedNativeFailure -FilePath $overflowProgram
if ($overflowFailure.ExitCode -ne 0 -or $overflowFailure.Output -ne '0') {
    throw 'Integer overflow did not return neutral zero without terminating'
}

$stringProgram = Join-Path $out 'strings.exe'
& (Join-Path $out 'ubec.exe') '--compile' `
    (Join-Path $PSScriptRoot 'tests/fixtures/strings.bas') '-o' $stringProgram
if ($LASTEXITCODE -ne 0) { throw 'String native compilation failed' }
$stringOutput = & $stringProgram
if ($LASTEXITCODE -ne 0) { throw 'String program returned a nonzero exit code' }
if ($stringOutput -ne 'Hello from UBE') { throw 'String program produced unexpected output' }

$intrinsicProgram = Join-Path $out 'intrinsics.exe'
$toolProbe = Join-Path $out 'tool-probe.exe'
& gcc '-std=c17' '-Wall' '-Wextra' '-Wpedantic' '-Werror' `
    (Join-Path $PSScriptRoot 'tests/tool_probe.c') '-o' $toolProbe
if ($LASTEXITCODE -ne 0) { throw 'Tool-process probe build failed' }
& (Join-Path $out 'ubec.exe') '--compile' `
    (Join-Path $PSScriptRoot 'tests/fixtures/intrinsics.bas') '-o' $intrinsicProgram
if ($LASTEXITCODE -ne 0) { throw 'Intrinsic native compilation failed' }
$roundTripPath = Join-Path $out 'intrinsic-round-trip.txt'
$intrinsicOutput = & $intrinsicProgram $roundTripPath $toolProbe
if ($LASTEXITCODE -ne 0) { throw 'Intrinsic program returned a nonzero exit code' }
if (($intrinsicOutput -join ',') -ne '2,3,98,bc,4,line!,-42,joined-text,1,0,229,file-data,33,10,-1,-1,-1,-1') { throw 'Intrinsic program produced unexpected output' }
if ((Get-Content -Raw $roundTripPath) -ne 'file-data') { throw 'Intrinsic file round trip produced unexpected data' }

$stageOneProject = Join-Path $root 'compiler/UBE_Compiler_v1'
$stageOne = Join-Path $out 'ube-stage1.exe'
& (Join-Path $out 'ubec.exe') '--compile' (Join-Path $stageOneProject 'Main.bas') '-o' $stageOne
if ($LASTEXITCODE -ne 0) { throw 'Stage zero failed to compile the UBE-written compiler' }

$clangCommand = Get-Command clang -ErrorAction SilentlyContinue
$clangPath = if ($clangCommand) { $clangCommand.Source } else { 'C:\Program Files\LLVM\bin\clang.exe' }
if (-not (Test-Path $clangPath)) { throw 'LLVM clang was not found for stage-one acceptance tests' }
$clangVersion = ((& $clangPath '--version' | Select-Object -First 1).ToString())
if ($LASTEXITCODE -ne 0 -or $clangVersion -notmatch '^clang version 23(?:\.|$)') {
    throw "UBE Compiler v3 RP5 requires Clang major version 23; found: $clangVersion"
}
$v3Rp5ClangCompileFlags = @('--target=x86_64-w64-windows-gnu', '-O2', '-c')
$v3Rp5ClangLinkFlags = @('--target=x86_64-w64-windows-gnu', '-O2')

$stageOneSubIr = Join-Path $out 'stage1-sub.ll'
$stageOneSub = Join-Path $out 'stage1-sub.exe'
& $stageOne (Join-Path $stageOneProject 'tests/showcase_sub.bas') $stageOneSubIr
if ($LASTEXITCODE -ne 0) { throw 'Stage one failed to compile the Sub Main showcase' }
& $clangPath '--target=x86_64-w64-windows-gnu' '-O2' $stageOneSubIr '-o' $stageOneSub
if ($LASTEXITCODE -ne 0) { throw 'LLVM failed to link the stage-one Sub Main showcase' }
$stageOneSubOutput = & $stageOneSub
if ($LASTEXITCODE -ne 0 -or $stageOneSubOutput -ne 'Hello from UBE stage one') {
    throw 'Stage-one Sub Main showcase failed'
}

$stageOneFunctionIr = Join-Path $out 'stage1-function.ll'
$stageOneFunction = Join-Path $out 'stage1-function.exe'
& $stageOne (Join-Path $stageOneProject 'tests/showcase_function.bas') $stageOneFunctionIr
if ($LASTEXITCODE -ne 0) { throw 'Stage one failed to compile the Function Main showcase' }
& $clangPath '--target=x86_64-w64-windows-gnu' '-O2' $stageOneFunctionIr '-o' $stageOneFunction
if ($LASTEXITCODE -ne 0) { throw 'LLVM failed to link the stage-one Function Main showcase' }
$stageOneFunctionOutput = & $stageOneFunction
if ($LASTEXITCODE -ne 9 -or $stageOneFunctionOutput -ne 'Function Main from UBE stage one') {
    throw 'Stage-one Function Main showcase failed'
}

function Test-StageOneFailure {
    param(
        [Parameter(Mandatory = $true)][string]$Fixture,
        [Parameter(Mandatory = $true)][string]$ExpectedDiagnostic
    )

    $fixturePath = Join-Path $stageOneProject "tests/$Fixture"
    $resultPath = Join-Path $out "$Fixture.ll"
    Remove-Item -LiteralPath $resultPath -ErrorAction SilentlyContinue
    $failure = Invoke-ExpectedNativeFailure -FilePath $stageOne -Arguments @($fixturePath, $resultPath)
    if ($failure.ExitCode -ne 1) {
        throw "Stage one returned the wrong exit code for $Fixture"
    }
    if ($failure.Output -notlike "*$ExpectedDiagnostic*") {
        throw "Stage one returned the wrong diagnostic for $Fixture"
    }
    if (Test-Path -LiteralPath $resultPath) {
        throw "Stage one left an output artifact for rejected input $Fixture"
    }
}

Test-StageOneFailure 'missing_print.bas' 'expected a Print string statement'
Test-StageOneFailure 'unterminated_print.bas' 'unterminated Print string'
Test-StageOneFailure 'unsupported_backslash.bas' 'backslashes are not supported yet'
Test-StageOneFailure 'missing_function_result.bas' 'Function Main must assign its exit code'

$stageOneUsage = Invoke-ExpectedNativeFailure -FilePath $stageOne
if ($stageOneUsage.ExitCode -ne 2 -or $stageOneUsage.Output -notlike '*usage: ube-stage1*') {
    throw 'Stage one did not reject an invalid argument count predictably'
}

$missingSource = Join-Path $out 'missing-stage-one-source.bas'
$missingResult = Join-Path $out 'missing-stage-one-source.ll'
Remove-Item -LiteralPath $missingSource, $missingResult -ErrorAction SilentlyContinue
$missingFailure = Invoke-ExpectedNativeFailure -FilePath $stageOne -Arguments @($missingSource, $missingResult)
if ($missingFailure.ExitCode -ne 66 -or $missingFailure.Output -notlike '*cannot open for reading*') {
    throw 'Stage one did not report a missing source file predictably'
}
if (Test-Path -LiteralPath $missingResult) {
    throw 'Stage one left output after a source read failure'
}

$writeFailure = Invoke-ExpectedNativeFailure -FilePath $stageOne -Arguments @(
    (Join-Path $stageOneProject 'tests/showcase_sub.bas'), $out)
if ($writeFailure.ExitCode -ne 73 -or $writeFailure.Output -notlike '*cannot open for writing*') {
    throw 'Stage one did not report an output write failure predictably'
}

$v2Project = Join-Path $root 'compiler/UBE_Compiler_v2'
$v2StageOne = Join-Path $out 'ube-stage1-v2.exe'
& (Join-Path $out 'ubec.exe') '--compile' (Join-Path $v2Project 'Main.bas') '-o' $v2StageOne
if ($LASTEXITCODE -ne 0) { throw 'Stage zero failed to compile UBE Compiler v2' }

$v2SelfSmokeIr = Join-Path $out 'v2-self-smoke.ll'
& $v2StageOne (Join-Path $v2Project 'UBE_Compiler_v2.UBE') $v2SelfSmokeIr
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $v2SelfSmokeIr)) {
    throw 'UBE Compiler v2 failed to compile its own source to stage-two LLVM IR'
}

$v2StageTwo = Join-Path $out 'ube-stage2-v2.exe'
& $clangPath '--target=x86_64-w64-windows-gnu' '-O2' $v2SelfSmokeIr `
    (Join-Path $out 'bootstrap_runtime.o') (Join-Path $out 'bootstrap_unicode_runtime.o') '-o' $v2StageTwo
if ($LASTEXITCODE -ne 0) { throw 'LLVM failed to link UBE Compiler v2 stage two' }

$v2StageThreeIr = Join-Path $out 'v2-stage3.ll'
& $v2StageTwo (Join-Path $v2Project 'UBE_Compiler_v2.UBE') $v2StageThreeIr
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $v2StageThreeIr)) {
    throw 'UBE Compiler v2 stage two failed to recompile its own source'
}
$v2StageTwoIrInfo = Get-Item -LiteralPath $v2SelfSmokeIr
$v2StageThreeIrInfo = Get-Item -LiteralPath $v2StageThreeIr
$v2StageTwoIrHash = (Get-FileHash -LiteralPath $v2SelfSmokeIr -Algorithm SHA256).Hash
$v2StageThreeIrHash = (Get-FileHash -LiteralPath $v2StageThreeIr -Algorithm SHA256).Hash
if ($v2StageTwoIrInfo.Length -ne $v2StageThreeIrInfo.Length -or $v2StageTwoIrHash -ne $v2StageThreeIrHash) {
    throw 'UBE Compiler v2 stage-two and stage-three LLVM IR are not byte-identical'
}

$v2SubIr = Join-Path $out 'v2-sub.ll'
$v2Sub = Join-Path $out 'v2-sub.exe'
& $v2StageOne (Join-Path $v2Project 'tests/showcase_sub.bas') $v2SubIr
if ($LASTEXITCODE -ne 0) { throw 'UBE Compiler v2 failed to compile the Sub Main showcase' }
& $clangPath '--target=x86_64-w64-windows-gnu' '-O2' $v2SubIr `
    (Join-Path $out 'bootstrap_runtime.o') (Join-Path $out 'bootstrap_unicode_runtime.o') '-o' $v2Sub
if ($LASTEXITCODE -ne 0) { throw 'LLVM failed to link the UBE Compiler v2 Sub Main showcase' }
$v2SubOutput = & $v2Sub
if ($LASTEXITCODE -ne 0 -or $v2SubOutput -ne 'Hello "quoted" from UBE Compiler v2\lexer') {
    throw 'UBE Compiler v2 Sub Main showcase failed'
}

$v2FunctionIr = Join-Path $out 'v2-function.ll'
$v2Function = Join-Path $out 'v2-function.exe'
& $v2StageOne (Join-Path $v2Project 'tests/showcase_function.bas') $v2FunctionIr
if ($LASTEXITCODE -ne 0) { throw 'UBE Compiler v2 failed to compile the Function Main showcase' }
& $clangPath '--target=x86_64-w64-windows-gnu' '-O2' $v2FunctionIr `
    (Join-Path $out 'bootstrap_runtime.o') (Join-Path $out 'bootstrap_unicode_runtime.o') '-o' $v2Function
if ($LASTEXITCODE -ne 0) { throw 'LLVM failed to link the UBE Compiler v2 Function Main showcase' }
$v2FunctionOutput = & $v2Function
if ($LASTEXITCODE -ne 12 -or $v2FunctionOutput -ne 'Function Main from UBE Compiler v2') {
    throw 'UBE Compiler v2 Function Main showcase failed'
}

$v2StageTwoSubIr = Join-Path $out 'v2-stage2-sub.ll'
& $v2StageTwo (Join-Path $v2Project 'tests/showcase_sub.bas') $v2StageTwoSubIr
if ($LASTEXITCODE -ne 0) { throw 'UBE Compiler v2 stage two failed the Sub Main showcase' }
if ((Get-FileHash -LiteralPath $v2SubIr -Algorithm SHA256).Hash -ne `
    (Get-FileHash -LiteralPath $v2StageTwoSubIr -Algorithm SHA256).Hash) {
    throw 'UBE Compiler v2 stages one and two emitted different Sub Main LLVM IR'
}
$v2StageTwoFunctionIr = Join-Path $out 'v2-stage2-function.ll'
& $v2StageTwo (Join-Path $v2Project 'tests/showcase_function.bas') $v2StageTwoFunctionIr
if ($LASTEXITCODE -ne 0) { throw 'UBE Compiler v2 stage two failed the Function Main showcase' }
if ((Get-FileHash -LiteralPath $v2FunctionIr -Algorithm SHA256).Hash -ne `
    (Get-FileHash -LiteralPath $v2StageTwoFunctionIr -Algorithm SHA256).Hash) {
    throw 'UBE Compiler v2 stages one and two emitted different Function Main LLVM IR'
}

$v2FeaturesIr = Join-Path $out 'v2-backend-features.ll'
$v2StageTwoFeaturesIr = Join-Path $out 'v2-stage2-backend-features.ll'
$v2Features = Join-Path $out 'v2-backend-features.exe'
& $v2StageOne (Join-Path $v2Project 'tests/backend_features.bas') $v2FeaturesIr
if ($LASTEXITCODE -ne 0) { throw 'UBE Compiler v2 stage one failed the backend feature program' }
& $v2StageTwo (Join-Path $v2Project 'tests/backend_features.bas') $v2StageTwoFeaturesIr
if ($LASTEXITCODE -ne 0) { throw 'UBE Compiler v2 stage two failed the backend feature program' }
if ((Get-FileHash -LiteralPath $v2FeaturesIr -Algorithm SHA256).Hash -ne `
    (Get-FileHash -LiteralPath $v2StageTwoFeaturesIr -Algorithm SHA256).Hash) {
    throw 'UBE Compiler v2 stages one and two emitted different backend feature LLVM IR'
}
& $clangPath '--target=x86_64-w64-windows-gnu' '-O2' $v2FeaturesIr `
    (Join-Path $out 'bootstrap_runtime.o') (Join-Path $out 'bootstrap_unicode_runtime.o') '-o' $v2Features
if ($LASTEXITCODE -ne 0) { throw 'LLVM failed to link the UBE Compiler v2 backend feature program' }
$v2FeaturesOutput = & $v2Features
if ($LASTEXITCODE -ne 8 -or $v2FeaturesOutput -ne 'backend-features') {
    throw 'UBE Compiler v2 backend feature program failed'
}

$v2MultiModuleProject = Join-Path $v2Project 'tests/multi_module.UBE'
$v2MultiModuleIr = Join-Path $out 'v2-multi-module.ll'
$v2StageTwoMultiModuleIr = Join-Path $out 'v2-stage2-multi-module.ll'
$v2MultiModuleExe = Join-Path $out 'v2-multi-module.exe'
& $v2StageOne $v2MultiModuleProject $v2MultiModuleIr
if ($LASTEXITCODE -ne 0) { throw 'UBE Compiler v2 stage one failed the multi-module project' }
& $v2StageTwo $v2MultiModuleProject $v2StageTwoMultiModuleIr
if ($LASTEXITCODE -ne 0) { throw 'UBE Compiler v2 stage two failed the multi-module project' }
if ((Get-FileHash -LiteralPath $v2MultiModuleIr -Algorithm SHA256).Hash -ne `
    (Get-FileHash -LiteralPath $v2StageTwoMultiModuleIr -Algorithm SHA256).Hash) {
    throw 'UBE Compiler v2 stages one and two emitted different multi-module LLVM IR'
}
& $clangPath '--target=x86_64-w64-windows-gnu' '-O2' $v2MultiModuleIr `
    (Join-Path $out 'bootstrap_runtime.o') (Join-Path $out 'bootstrap_unicode_runtime.o') '-o' $v2MultiModuleExe
if ($LASTEXITCODE -ne 0) { throw 'LLVM failed to link the UBE Compiler v2 multi-module program' }
$v2MultiModuleOutput = & $v2MultiModuleExe
if ($LASTEXITCODE -ne 7 -or $v2MultiModuleOutput -ne 'multi-module') {
    throw 'UBE Compiler v2 multi-module program failed'
}

$v3Project = Join-Path $root 'compiler/archived/UBE_Compiler_v3'
$v3Manifest = Join-Path $v3Project 'UBE_Compiler_v3.UBE'
$v3SeedManifest = Join-Path $v3Project 'UBE_Compiler_v3_seed.UBE'
$v3SeedStageOneIr = Join-Path $out 'v3-seed-v2-stage1.ll'
$v3SeedStageTwoIr = Join-Path $out 'v3-seed-v2-stage2.ll'
$v3SeedExecutable = Join-Path $out 'ube-v3-seed.exe'
& $v2StageOne $v3SeedManifest $v3SeedStageOneIr
if ($LASTEXITCODE -ne 0) { throw 'UBE Compiler v2 stage one failed to compile the v3 sequential seed' }
& $v2StageTwo $v3SeedManifest $v3SeedStageTwoIr
if ($LASTEXITCODE -ne 0) { throw 'UBE Compiler v2 stage two failed to compile the v3 sequential seed' }
$v3SeedStageOneIrHash = (Get-FileHash -LiteralPath $v3SeedStageOneIr -Algorithm SHA256).Hash
$v3SeedStageTwoIrHash = (Get-FileHash -LiteralPath $v3SeedStageTwoIr -Algorithm SHA256).Hash
if ((Get-Item -LiteralPath $v3SeedStageOneIr).Length -ne `
        (Get-Item -LiteralPath $v3SeedStageTwoIr).Length -or `
        $v3SeedStageOneIrHash -ne $v3SeedStageTwoIrHash) {
    throw 'UBE Compiler v2 stages one and two emitted different v3 seed LLVM IR'
}
& $clangPath '--target=x86_64-w64-windows-gnu' '-O2' $v3SeedStageOneIr `
    (Join-Path $out 'bootstrap_runtime.o') (Join-Path $out 'bootstrap_unicode_runtime.o') '-o' $v3SeedExecutable
if ($LASTEXITCODE -ne 0) { throw 'LLVM failed to link the UBE Compiler v3 sequential seed' }

$v3Rp1Target = 'x86_64-w64-windows-gnu'
$v3Rp1StageOneIr = Join-Path $out 'v3-production-stage1.ll'
$v3Rp1Executable = Join-Path $out 'ube-v3-production-stage1.exe'
& $v3SeedExecutable '--emit-llvm' $v3Manifest $v3Rp1Target $v3Rp1StageOneIr
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $v3Rp1StageOneIr)) {
    throw 'The sequential seed failed to compile the UBE Compiler v3 production manifest'
}
$v3Rp1StageOneIrHash = (Get-FileHash -LiteralPath $v3Rp1StageOneIr -Algorithm SHA256).Hash
& $clangPath '--target=x86_64-w64-windows-gnu' '-O2' $v3Rp1StageOneIr `
    (Join-Path $out 'bootstrap_runtime.o') (Join-Path $out 'bootstrap_unicode_runtime.o') '-o' $v3Rp1Executable
if ($LASTEXITCODE -ne 0) { throw 'LLVM failed to link UBE Compiler v3 production stage one' }

$v3Rp1Output = & $v3Rp1Executable $v3Manifest $v3Rp1Target
if ($LASTEXITCODE -ne 0 -or $v3Rp1Output -notlike 'UBE Compiler v3 RP8: project UBE_Compiler_v3 (Exe), * source(s), * token(s), * syntax node(s), * symbol(s), host windows-x86_64, target x86_64-w64-windows-gnu') {
    throw 'UBE Compiler v3 RP5 failed to analyze its own project'
}

$v3Rp1Tests = Join-Path $v3Project 'tests'
$v3Rp1FixtureOutput = & $v3Rp1Executable (Join-Path $v3Rp1Tests 'rp1-valid.UBE') $v3Rp1Target
if ($LASTEXITCODE -ne 0 -or $v3Rp1FixtureOutput -notlike 'UBE Compiler v3 RP8: project RP1Fixture (Exe), 2 source(s), * token(s), * syntax node(s), * symbol(s), host windows-x86_64, target x86_64-w64-windows-gnu') {
    throw 'UBE Compiler v3 RP5 failed its inherited multi-module project fixture'
}
$ubeCoreProject = Join-Path $root 'archive/source-library/UBECore.UBE'
$ubeCoreOutput = & $v3Rp1Executable $ubeCoreProject $v3Rp1Target
if ($LASTEXITCODE -ne 0 -or $ubeCoreOutput -notlike 'UBE Compiler v3 RP8: project UBECore (Library), * source(s), * token(s), * syntax node(s), * symbol(s), host windows-x86_64, target x86_64-w64-windows-gnu') {
    throw 'UBE Compiler v3 RP5 failed to validate the UBECore project boundary'
}

$v3Rp2Tests = Join-Path $v3Project 'tests/rp2'
foreach ($positiveProject in @('basic.UBE', 'lexical.UBE', 'legacy.UBE', 'conditional-continuation.UBE')) {
    $positiveOutput = & $v3Rp1Executable '--dump-syntax' (Join-Path $v3Rp2Tests $positiveProject) $v3Rp1Target
    if ($LASTEXITCODE -ne 0 -or $positiveOutput[0] -notlike 'UBE-SYNTAX 1 *') {
        throw "UBE Compiler v3 RP5 failed inherited front-end fixture $positiveProject"
    }
}
$firstTokenDump = & $v3Rp1Executable '--dump-tokens' (Join-Path $v3Rp2Tests 'lexical.UBE') $v3Rp1Target
if ($LASTEXITCODE -ne 0) { throw 'UBE Compiler v3 RP3 failed to dump lexical fixture tokens' }
$secondTokenDump = & $v3Rp1Executable '--dump-tokens' (Join-Path $v3Rp2Tests 'lexical.UBE') $v3Rp1Target
if ($LASTEXITCODE -ne 0 -or (Compare-Object $firstTokenDump $secondTokenDump)) {
    throw 'UBE Compiler v3 RP3 token serialization is not deterministic'
}
$serializedTokens = $firstTokenDump -join "`n"
foreach ($requiredTokenKind in @('|keyword|', '|identifier|', '|bracket-identifier|', '|integer|', '|real|', '|string|', '|date|', '|punctuation|', '|newline|', '|comment|', '|spacing|', '|continuation|', '|eof|')) {
    if ($serializedTokens -notlike "*$requiredTokenKind*") {
        throw "UBE Compiler v3 RP3 token dump omitted $requiredTokenKind"
    }
}

function Test-V3Rp1Failure {
    param(
        [string[]]$Arguments = @(),
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$ExpectedDiagnostic,
        [int]$ExpectedExitCode = 1
    )

    $failure = Invoke-ExpectedNativeFailure -FilePath $v3Rp1Executable -Arguments $Arguments
    if ($failure.ExitCode -ne $ExpectedExitCode) {
        throw "UBE Compiler v3 RP3 returned the wrong exit code for $Name"
    }
    if (-not $failure.Output.Contains($ExpectedDiagnostic)) {
        throw "UBE Compiler v3 RP3 returned the wrong diagnostic for $Name`: $($failure.Output)"
    }
}

Test-V3Rp1Failure -Name 'usage' -ExpectedExitCode 2 `
    -ExpectedDiagnostic 'usage: ube-v3-rp8 [--jobs N] [--dump-tokens|--dump-syntax|--dump-semantics|--dump-ir|--dump-managed] <project.UBE> <target-triple> [output.ll]'
Test-V3Rp1Failure -Name 'unsupported-target' -Arguments @($v3Manifest, 'unknown-target') `
    -ExpectedDiagnostic 'error UBE3200: unsupported RP8 target: unknown-target'
$v3Rp5MissingOutputDirectory = Join-Path $out 'missing-output-directory'
$v3Rp5UnwritableOutput = Join-Path $v3Rp5MissingOutputDirectory 'output.ll'
Test-V3Rp1Failure -Name 'atomic-output-write-failure' `
    -Arguments @('--emit-llvm', $v3Manifest, $v3Rp1Target, $v3Rp5UnwritableOutput) `
    -ExpectedDiagnostic 'error UBE5109: cannot atomically write generated LLVM output'
if ((Test-Path -LiteralPath $v3Rp5UnwritableOutput) -or `
        (Test-Path -LiteralPath $v3Rp5MissingOutputDirectory)) {
    throw 'RP5 atomic output failure left a final or temporary artifact'
}
Test-V3Rp1Failure -Name 'duplicate-source' `
    -Arguments @((Join-Path $v3Rp1Tests 'duplicate-source.UBE'), $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE3013: duplicate Source after path normalization'
Test-V3Rp1Failure -Name 'path-escape' `
    -Arguments @((Join-Path $v3Rp1Tests 'path-escape.UBE'), $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE3012: Source must be a safe relative'
Test-V3Rp1Failure -Name 'unknown-key' `
    -Arguments @((Join-Path $v3Rp1Tests 'unknown-key.UBE'), $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE3019: unsupported project key: Mystery'
Test-V3Rp1Failure -Name 'library-startup' `
    -Arguments @((Join-Path $v3Rp1Tests 'library-startup.UBE'), $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE3022: library projects cannot declare Startup or StartupForm'
$v3Rp8Tests = Join-Path $v3Project 'tests/rp8'
Test-V3Rp1Failure -Name 'rp8-address-of-unsupported' `
    -Arguments @((Join-Path $v3Rp8Tests 'unsupported-address-of.UBE'), $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE4050: AddressOf native callback thunks are reserved'
Test-V3Rp1Failure -Name 'rp8-force-inline-unsupported' `
    -Arguments @((Join-Path $v3Rp8Tests 'unsupported-force-inline.UBE'), $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE4052: ForceInline is reserved'
Test-V3Rp1Failure -Name 'rp8-legacy-file-unsupported' `
    -Arguments @((Join-Path $v3Rp8Tests 'unsupported-file.UBE'), $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE4054: legacy file statements are reserved'
Test-V3Rp1Failure -Name 'rp8-host-clock-unsupported' `
    -Arguments @((Join-Path $v3Rp8Tests 'unsupported-host-clock.UBE'), $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE4055: legacy host-clock assignment is not portable'
Test-V3Rp1Failure -Name 'rp8-variable-hook-unsupported' `
    -Arguments @((Join-Path $v3Rp8Tests 'unsupported-variable-hook.UBE'), $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE4051: variable Get/Set hooks are reserved'
Test-V3Rp1Failure -Name 'rp8-foreign-declare-unsupported' `
    -Arguments @((Join-Path $v3Rp8Tests 'unsupported-declare.UBE'), $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE4053: foreign Declare imports are reserved'
Test-V3Rp1Failure -Name 'rp8-assembly-unsafe' `
    -Arguments @((Join-Path $v3Rp8Tests 'unsupported-asm.UBE'), $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE4030: unsafe source requires an explicitly enabled unsafe build context'
Test-V3Rp1Failure -Name 'rp8-bytecode-unsafe' `
    -Arguments @((Join-Path $v3Rp8Tests 'unsupported-bytecode.UBE'), $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE4030: unsafe source requires an explicitly enabled unsafe build context'
Test-V3Rp1Failure -Name 'rp8-classic-graphics-unsupported' `
    -Arguments @((Join-Path $v3Rp8Tests 'unsupported-graphics.UBE'), $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE4056: classic graphics statements are reserved'
& (Join-Path $PSScriptRoot 'tests/rp8_package_tests.ps1') `
    -CompilerPath $v3Rp1Executable -OutputDirectory $out -Target $v3Rp1Target
$v3Rp8ResourceLlvm = Join-Path $out 'rp8-package-resource.ll'
$v3Rp8ResourceObject = Join-Path $out 'rp8-package-resource.o'
& $clangPath '--target=x86_64-w64-windows-gnu' '-c' $v3Rp8ResourceLlvm '-o' $v3Rp8ResourceObject
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $v3Rp8ResourceObject)) {
    throw 'LLVM rejected the RP8 embedded-resource globals'
}
$resourceProbe = Join-Path $out 'resource-probe.exe'
& gcc '-std=c17' '-Wall' '-Wextra' '-Wpedantic' '-Werror' `
    (Join-Path $PSScriptRoot 'tests/resource_probe.c') (Join-Path $out 'bootstrap_runtime.o') `
    '-o' $resourceProbe
if ($LASTEXITCODE -ne 0) { throw 'RP8 resource probe build failed' }
$resourceProbeOutput = & $resourceProbe (Join-Path $out 'rp8-package.UBR') (Join-Path $out 'rp8-corrupt.UBR')
if ($LASTEXITCODE -ne 0 -or $resourceProbeOutput -ne 'resource probe passed') {
    throw 'RP8 resource probe failed'
}
$libraryBundleProbe = Join-Path $out 'library-bundle-probe.exe'
& gcc '-std=c17' '-Wall' '-Wextra' '-Wpedantic' '-Werror' `
    (Join-Path $PSScriptRoot 'tests/library_bundle_probe.c') (Join-Path $out 'bootstrap_runtime.o') `
    '-o' $libraryBundleProbe
if ($LASTEXITCODE -ne 0) { throw 'RP8 library-bundle probe build failed' }
$rp8InterfaceHash = (Get-FileHash -LiteralPath (Join-Path $v3Rp8Tests 'group-library.bas') -Algorithm SHA256).Hash
$libraryBundleProbeOutput = & $libraryBundleProbe (Join-Path $out 'rp8-package.UBL') $rp8InterfaceHash
if ($LASTEXITCODE -ne 0 -or $libraryBundleProbeOutput -ne 'library bundle probe passed') {
    throw 'RP8 library-bundle probe failed'
}
Test-V3Rp1Failure -Name 'missing-source' -ExpectedExitCode 66 `
    -Arguments @((Join-Path $v3Rp1Tests 'missing-source.UBE'), $v3Rp1Target) `
    -ExpectedDiagnostic 'UBE runtime: cannot open for reading:'
Test-V3Rp1Failure -Name 'source-kind-mismatch' `
    -Arguments @((Join-Path $v3Rp2Tests 'kind-mismatch.UBE'), $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE3303: source header kind does not match its file extension'
Test-V3Rp1Failure -Name 'missing-source-header' `
    -Arguments @((Join-Path $v3Rp2Tests 'missing-header.UBE'), $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE3300: source must begin with a native UBE header or recognized VB6 header'
Test-V3Rp1Failure -Name 'lexical-recovery' `
    -Arguments @((Join-Path $v3Rp2Tests 'malformed.UBE'), $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE3405: unterminated string literal'
Test-V3Rp1Failure -Name 'unmatched-conditional' `
    -Arguments @((Join-Path $v3Rp2Tests 'conditional-bad.UBE'), $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE3507: #Else has no matching open #If'

$v3Rp2FuzzSource = Join-Path $out 'v3-rp2-fuzz.bas'
$v3Rp2FuzzProject = Join-Path $out 'v3-rp2-fuzz.UBE'
$fuzzProjectText = "UBE-Project 1`nName = `"Fuzz`"`nKind = `"Library`"`nSource = `"v3-rp2-fuzz.bas`"`n"
[System.IO.File]::WriteAllText($v3Rp2FuzzProject, $fuzzProjectText, [System.Text.UTF8Encoding]::new($false))

$conditionalDepthText = [System.Text.StringBuilder]::new("UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"Fuzz`"`n")
for ($depthIndex = 0; $depthIndex -le 256; $depthIndex++) {
    [void]$conditionalDepthText.AppendLine('#If True Then')
}
for ($depthIndex = 0; $depthIndex -le 256; $depthIndex++) {
    [void]$conditionalDepthText.AppendLine('#End If')
}
[System.IO.File]::WriteAllText($v3Rp2FuzzSource, $conditionalDepthText.ToString(), [System.Text.UTF8Encoding]::new($false))
Test-V3Rp1Failure -Name 'conditional-depth-limit' -Arguments @($v3Rp2FuzzProject, $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE3503: conditional compilation nesting limit exceeded'

$conditionalConstantText = [System.Text.StringBuilder]::new("UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"Fuzz`"`n")
for ($constantIndex = 0; $constantIndex -le 4096; $constantIndex++) {
    [void]$conditionalConstantText.AppendLine("#Const C$constantIndex = True")
}
[System.IO.File]::WriteAllText($v3Rp2FuzzSource, $conditionalConstantText.ToString(), [System.Text.UTF8Encoding]::new($false))
Test-V3Rp1Failure -Name 'conditional-constant-limit' -Arguments @($v3Rp2FuzzProject, $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE3502: invalid #Const value or conditional constant limit exceeded'

$tokenLimitText = "UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"Fuzz`"`n" + (':' * 300001)
[System.IO.File]::WriteAllText($v3Rp2FuzzSource, $tokenLimitText, [System.Text.UTF8Encoding]::new($false))
Test-V3Rp1Failure -Name 'token-limit' -Arguments @($v3Rp2FuzzProject, $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE3400: token limit exceeded'

$random = [System.Random]::new(3302)
for ($case = 0; $case -lt 32; $case++) {
    $payloadLength = $random.Next(0, 513)
    $payload = [System.Text.StringBuilder]::new()
    for ($byteIndex = 0; $byteIndex -lt $payloadLength; $byteIndex++) {
        [void]$payload.Append([char]$random.Next(1, 128))
    }
    $fuzzText = "UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"Fuzz`"`n" + $payload.ToString()
    [System.IO.File]::WriteAllText($v3Rp2FuzzSource, $fuzzText, [System.Text.UTF8Encoding]::new($false))
    $fuzzResult = Invoke-ExpectedNativeFailure -FilePath $v3Rp1Executable -Arguments @($v3Rp2FuzzProject, $v3Rp1Target)
    if ($fuzzResult.ExitCode -ne 0 -and $fuzzResult.ExitCode -ne 1) {
        throw "UBE Compiler v3 RP3 crashed or returned an uncontrolled status for deterministic fuzz case $case`: $($fuzzResult.Output)"
    }
}

$v3Rp2BomText = "UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"Bom`"`r`nDim finalIdentifier As Long"
$v3Rp2BomBytes = [System.Text.UTF8Encoding]::new($true).GetBytes($v3Rp2BomText)
[System.IO.File]::WriteAllBytes($v3Rp2FuzzSource, $v3Rp2BomBytes)
$bomOutput = & $v3Rp1Executable $v3Rp2FuzzProject $v3Rp1Target
if ($LASTEXITCODE -ne 0 -or $bomOutput -notlike 'UBE Compiler v3 RP8:*') {
    throw 'UBE Compiler v3 RP5 failed BOM, CRLF, or final synthetic newline coverage'
}

$v3Rp3Tests = Join-Path $v3Project 'tests/rp3'
foreach ($positiveProject in @('comprehensive.UBE', 'legacy-designer.UBE')) {
    $positiveOutput = & $v3Rp1Executable '--dump-syntax' (Join-Path $v3Rp3Tests $positiveProject) $v3Rp1Target
    if ($LASTEXITCODE -ne 0 -or $positiveOutput[0] -notlike 'UBE-SYNTAX 1 *') {
        throw "UBE Compiler v3 RP5 failed parser fixture $positiveProject"
    }
}

$firstSyntaxDump = & $v3Rp1Executable '--dump-syntax' (Join-Path $v3Rp3Tests 'comprehensive.UBE') $v3Rp1Target
if ($LASTEXITCODE -ne 0) { throw 'UBE Compiler v3 RP3 failed to dump comprehensive syntax' }
$secondSyntaxDump = & $v3Rp1Executable '--dump-syntax' (Join-Path $v3Rp3Tests 'comprehensive.UBE') $v3Rp1Target
if ($LASTEXITCODE -ne 0 -or (Compare-Object $firstSyntaxDump $secondSyntaxDump -SyncWindow 0)) {
    throw 'UBE Compiler v3 RP3 syntax serialization is not deterministic'
}
if ($firstSyntaxDump[0] -notlike 'UBE-SYNTAX 1 *') {
    throw 'UBE Compiler v3 RP3 syntax dump omitted its format and grammar identity'
}

$grammarRules = Select-String -LiteralPath (Join-Path $root 'lang-doc/grammar/ube.ebnf') `
    -Pattern '^([a-z][a-z0-9-]*)\s*=' | ForEach-Object { $_.Matches[0].Groups[1].Value }
$seenGrammarRules = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($coverageProject in @($v3Manifest, (Join-Path $v3Rp3Tests 'comprehensive.UBE'), (Join-Path $v3Rp3Tests 'legacy-designer.UBE'), (Join-Path $v3Rp2Tests 'lexical.UBE'))) {
    & $v3Rp1Executable '--dump-syntax' $coverageProject $v3Rp1Target | ForEach-Object {
        if ($_ -match '^\d+\|-?\d+\|([^|]+)\|') { [void]$seenGrammarRules.Add($Matches[1]) }
    }
    if ($LASTEXITCODE -ne 0) { throw "UBE Compiler v3 RP3 failed grammar coverage project $coverageProject" }
}
$scannerOwnedRules = @('sign', 'integer-suffix', 'real-suffix', 'identifier-start', 'identifier-part', 'hex-digits', 'octal-digits', 'decimal-digit', 'octal-digit', 'hex-digit')
$missingGrammarRules = @($grammarRules | Where-Object { -not $seenGrammarRules.Contains($_) -and $_ -notin $scannerOwnedRules })
if ($missingGrammarRules.Count -ne 0) {
    throw "UBE Compiler v3 RP3 did not exercise grammar productions: $($missingGrammarRules -join ', ')"
}

$recoveryFailure = Invoke-ExpectedNativeFailure -FilePath $v3Rp1Executable -Arguments @((Join-Path $v3Rp3Tests 'recovery.UBE'), $v3Rp1Target)
$recoveryDiagnosticCount = ([regex]::Matches(($recoveryFailure.Output -join "`n"), 'error UBE3700:')).Count
if ($recoveryFailure.ExitCode -ne 1 -or $recoveryDiagnosticCount -lt 2 -or $recoveryDiagnosticCount -gt 16) {
    throw "UBE Compiler v3 RP3 did not produce bounded multi-error recovery: $($recoveryFailure.Output)"
}

$v3Rp3DepthSource = Join-Path $out 'v3-rp3-depth.bas'
$v3Rp3DepthProject = Join-Path $out 'v3-rp3-depth.UBE'
$v3Rp3ValidDepthSource = Join-Path $out 'v3-rp3-valid-depth.bas'
$v3Rp3ValidDepthProject = Join-Path $out 'v3-rp3-valid-depth.UBE'
$validDepthText = "UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"ValidDepth`"`nDim Value As Long = " + ('(' * 10) + '0' + (')' * 10) + "`n"
[System.IO.File]::WriteAllText($v3Rp3ValidDepthSource, $validDepthText, [System.Text.UTF8Encoding]::new($false))
$validDepthProjectText = "UBE-Project 1`nName = `"ValidDepth`"`nKind = `"Library`"`nSource = `"v3-rp3-valid-depth.bas`"`n"
[System.IO.File]::WriteAllText($v3Rp3ValidDepthProject, $validDepthProjectText, [System.Text.UTF8Encoding]::new($false))
$validDepthOutput = & $v3Rp1Executable $v3Rp3ValidDepthProject $v3Rp1Target
if ($LASTEXITCODE -ne 0 -or $validDepthOutput -notlike 'UBE Compiler v3 RP8: project ValidDepth (Library), 1 source(s), *') {
    throw 'UBE Compiler v3 rejected the valid parser-depth boundary fixture'
}
$depthText = "UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"Depth`"`nDim Value As Long = " + ('(' * 800) + '0' + (')' * 800) + "`n"
[System.IO.File]::WriteAllText($v3Rp3DepthSource, $depthText, [System.Text.UTF8Encoding]::new($false))
$depthProjectText = "UBE-Project 1`nName = `"Depth`"`nKind = `"Library`"`nSource = `"v3-rp3-depth.bas`"`n"
[System.IO.File]::WriteAllText($v3Rp3DepthProject, $depthProjectText, [System.Text.UTF8Encoding]::new($false))
Test-V3Rp1Failure -Name 'syntax-depth-limit' -Arguments @($v3Rp3DepthProject, $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE3701: syntax nesting or node limit exceeded'

$v3Rp4Tests = Join-Path $v3Project 'tests/rp4'
$v3Rp4Output = & $v3Rp1Executable (Join-Path $v3Rp4Tests 'valid.UBE') $v3Rp1Target
if ($LASTEXITCODE -ne 0 -or $v3Rp4Output -notlike 'UBE Compiler v3 RP8: project RP4Valid (Exe), 2 source(s), * symbol(s), host windows-x86_64, target x86_64-w64-windows-gnu') {
    throw 'UBE Compiler v3 RP5 failed its inherited typed multi-module semantic fixture'
}
$firstSemanticDump = & $v3Rp1Executable '--dump-semantics' (Join-Path $v3Rp4Tests 'valid.UBE') $v3Rp1Target
if ($LASTEXITCODE -ne 0) { throw 'UBE Compiler v3 RP5 failed to serialize inherited semantics' }
$secondSemanticDump = & $v3Rp1Executable '--dump-semantics' (Join-Path $v3Rp4Tests 'valid.UBE') $v3Rp1Target
if ($LASTEXITCODE -ne 0 -or (Compare-Object $firstSemanticDump $secondSemanticDump -SyncWindow 0)) {
    throw 'UBE Compiler v3 RP5 inherited semantic serialization is not deterministic'
}
if (($firstSemanticDump -join "`n") -notlike '*expressions=*/*') {
    throw 'UBE Compiler v3 RP5 did not type every accepted inherited expression'
}
Test-V3Rp1Failure -Name 'semantic-duplicate' -Arguments @((Join-Path $v3Rp4Tests 'duplicate.UBE'), $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE4001: duplicate declaration after case folding: value'
Test-V3Rp1Failure -Name 'semantic-entry' -Arguments @((Join-Path $v3Rp4Tests 'missing-main.UBE'), $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE4002: executable project requires exactly one module-level Main'
Test-V3Rp1Failure -Name 'semantic-type' -Arguments @((Join-Path $v3Rp4Tests 'unknown-type.UBE'), $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE4011: unknown type: MissingType'
Test-V3Rp1Failure -Name 'semantic-exit' -Arguments @((Join-Path $v3Rp4Tests 'bad-exit.UBE'), $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE4024: Exit does not name an enclosing construct'
Test-V3Rp1Failure -Name 'semantic-callnew' -Arguments @((Join-Path $v3Rp4Tests 'bad-callnew.UBE'), $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE4026: CallNew target must resolve to a known Sub: Missing'

$v3Rp5Tests = Join-Path $v3Project 'tests/rp5'
$v3Rp5StraightLineProject = Join-Path $v3Rp5Tests 'straight-line.UBE'
$v3Rp5FirstIr = & $v3Rp1Executable '--dump-ir' $v3Rp5StraightLineProject $v3Rp1Target
if ($LASTEXITCODE -ne 0 -or $v3Rp5FirstIr[0] -notlike 'UBE-IR 1*') {
    throw 'UBE Compiler v3 RP5 failed to lower and verify the straight-line IR fixture'
}
$v3Rp5SecondIr = & $v3Rp1Executable '--dump-ir' $v3Rp5StraightLineProject $v3Rp1Target
if ($LASTEXITCODE -ne 0 -or (Compare-Object $v3Rp5FirstIr $v3Rp5SecondIr -SyncWindow 0)) {
    throw 'UBE Compiler v3 RP5 typed IR serialization is not deterministic'
}
$v3Rp5FirstLlvm = Join-Path $out 'v3-rp5-straight-line-1.ll'
$v3Rp5SecondLlvm = Join-Path $out 'v3-rp5-straight-line-2.ll'
& $v3Rp1Executable '--emit-llvm' $v3Rp5StraightLineProject $v3Rp1Target $v3Rp5FirstLlvm
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $v3Rp5FirstLlvm)) {
    throw 'UBE Compiler v3 RP5 failed to emit LLVM for the straight-line fixture'
}
& $v3Rp1Executable '--emit-llvm' $v3Rp5StraightLineProject $v3Rp1Target $v3Rp5SecondLlvm
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $v3Rp5SecondLlvm)) {
    throw 'UBE Compiler v3 RP5 failed to repeat LLVM emission for the straight-line fixture'
}
if ((Get-FileHash -LiteralPath $v3Rp5FirstLlvm -Algorithm SHA256).Hash -ne `
    (Get-FileHash -LiteralPath $v3Rp5SecondLlvm -Algorithm SHA256).Hash) {
    throw 'UBE Compiler v3 RP5 LLVM emission is not deterministic'
}
$v3Phase2JobsOneLlvm = Join-Path $out 'v3-phase2-jobs-one.ll'
& $v3Rp1Executable '--jobs' '1' '--emit-llvm' $v3Rp5StraightLineProject `
    $v3Rp1Target $v3Phase2JobsOneLlvm
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $v3Phase2JobsOneLlvm)) {
    throw 'UBE Compiler v3 Beta 1 Phase 2 failed explicit --jobs 1 emission'
}
if ((Get-FileHash -LiteralPath $v3Rp5FirstLlvm -Algorithm SHA256).Hash -ne `
    (Get-FileHash -LiteralPath $v3Phase2JobsOneLlvm -Algorithm SHA256).Hash) {
    throw 'Explicit --jobs 1 changed emitted LLVM'
}
Test-V3Rp1Failure -Name 'phase3-invalid-job-count' -ExpectedExitCode 2 `
    -Arguments @('--jobs', '0', $v3Rp5StraightLineProject, $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE5300: --jobs requires a positive decimal Long value'
$v3Phase2Faults = [ordered]@{
    'worker-creation' = 'error UBE5301: compiler worker registration failed'
    'task-publication' = 'error UBE5302: compiler task publication failed'
    'result-allocation' = 'error UBE5303: compiler worker result allocation failed'
    'cancellation' = 'error UBE5304: compiler task cancelled'
    'merge' = 'error UBE5305: compiler result merge failed'
}
foreach ($faultSite in $v3Phase2Faults.Keys) {
    $faultOutput = Join-Path $out "v3-phase2-fault-$faultSite.ll"
    Test-V3Rp1Failure -Name "phase2-$faultSite" `
        -Arguments @('--executor-fault', $faultSite, '--jobs', '1', '--emit-llvm', `
            $v3Rp5StraightLineProject, $v3Rp1Target, $faultOutput) `
        -ExpectedDiagnostic $v3Phase2Faults[$faultSite]
    if (Test-Path -LiteralPath $faultOutput) {
        throw "Compiler executor fault $faultSite left a false-success output"
    }
}
$v3Phase3Project = Join-Path $v3Rp4Tests 'valid.UBE'
$v3Phase3JobsOneLlvm = Join-Path $out 'v3-phase3-jobs-one.ll'
$v3Phase3JobsTwoLlvm = Join-Path $out 'v3-phase3-jobs-two.ll'
$v3Phase3JobsEightLlvm = Join-Path $out 'v3-phase3-jobs-eight.ll'
foreach ($phase3Emission in @(
        @{ Jobs = '1'; Path = $v3Phase3JobsOneLlvm },
        @{ Jobs = '2'; Path = $v3Phase3JobsTwoLlvm },
        @{ Jobs = '8'; Path = $v3Phase3JobsEightLlvm })) {
    & $v3Rp1Executable '--jobs' $phase3Emission.Jobs '--emit-llvm' `
        $v3Phase3Project $v3Rp1Target $phase3Emission.Path
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $phase3Emission.Path)) {
        throw "UBE Compiler v3 Beta 1 Phase 3 failed --jobs $($phase3Emission.Jobs) emission"
    }
}
$v3Phase3ReferenceHash = (Get-FileHash -LiteralPath $v3Phase3JobsOneLlvm -Algorithm SHA256).Hash
foreach ($phase3ParallelPath in @($v3Phase3JobsTwoLlvm, $v3Phase3JobsEightLlvm)) {
    if ((Get-FileHash -LiteralPath $phase3ParallelPath -Algorithm SHA256).Hash -ne $v3Phase3ReferenceHash) {
        throw 'Parallel source frontend changed emitted LLVM'
    }
}
$v3Phase3DiagnosticProject = Join-Path $v3Rp4Tests 'duplicate.UBE'
$v3Phase3JobsOneDiagnostics = @(& $v3Rp1Executable '--jobs' '1' $v3Phase3DiagnosticProject $v3Rp1Target 2>&1 | ForEach-Object { $_.ToString() })
$v3Phase3JobsOneExit = $LASTEXITCODE
$v3Phase3JobsTwoDiagnostics = @(& $v3Rp1Executable '--jobs' '2' $v3Phase3DiagnosticProject $v3Rp1Target 2>&1 | ForEach-Object { $_.ToString() })
$v3Phase3JobsTwoExit = $LASTEXITCODE
if ($v3Phase3JobsOneExit -ne $v3Phase3JobsTwoExit -or
        (Compare-Object $v3Phase3JobsOneDiagnostics $v3Phase3JobsTwoDiagnostics -SyncWindow 0)) {
    throw 'Parallel source frontend changed diagnostic order or exit status'
}
$v3Phase3Faults = [ordered]@{
    'frontend-worker-creation' = 'error UBE5310: parallel frontend worker creation failed'
    'frontend-worker-wait' = 'error UBE5311: parallel frontend worker drain failed'
    'frontend-merge' = 'error UBE5312: parallel frontend deterministic merge failed'
}
foreach ($faultSite in $v3Phase3Faults.Keys) {
    $faultOutput = Join-Path $out "v3-phase3-fault-$faultSite.ll"
    Test-V3Rp1Failure -Name "phase3-$faultSite" `
        -Arguments @('--executor-fault', $faultSite, '--jobs', '2', '--emit-llvm', `
            $v3Phase3Project, $v3Rp1Target, $faultOutput) `
        -ExpectedDiagnostic $v3Phase3Faults[$faultSite]
    if (Test-Path -LiteralPath $faultOutput) {
        throw "Parallel frontend fault $faultSite left a false-success output"
    }
}
$v3Phase3TransferSource = Join-Path $out 'v3-phase3-transfer.bas'
$v3Phase3TransferProject = Join-Path $out 'v3-phase3-transfer.UBE'
$v3Phase3TransferText = [System.Text.StringBuilder]::new()
[void]$v3Phase3TransferText.Append("UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"Phase3Transfer`"`n")
for ($transferIndex = 0; $transferIndex -lt 15000; $transferIndex++) {
    [void]$v3Phase3TransferText.Append("Dim Value$transferIndex As Long = $transferIndex`n")
}
[System.IO.File]::WriteAllText($v3Phase3TransferSource, $v3Phase3TransferText.ToString(), [System.Text.UTF8Encoding]::new($false))
$v3Phase3TransferProjectText = "UBE-Project 1`nName = `"Phase3Transfer`"`nKind = `"Library`"`nSource = `"v3-phase3-transfer.bas`"`n"
[System.IO.File]::WriteAllText($v3Phase3TransferProject, $v3Phase3TransferProjectText, [System.Text.UTF8Encoding]::new($false))
& $v3Rp1Executable '--jobs' '1' '--dump-tokens' $v3Phase3TransferProject $v3Rp1Target | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw 'Parallel frontend managed-token transfer regression failed'
}

$v3Phase4Project = Join-Path $v3Rp4Tests 'parallel-semantics.UBE'
$v3Phase4DefaultLlvm = Join-Path $out 'v3-phase4-default.ll'
$v3Phase4JobsOneLlvm = Join-Path $out 'v3-phase4-jobs-one.ll'
$v3Phase4JobsTwoLlvm = Join-Path $out 'v3-phase4-jobs-two.ll'
$v3Phase4JobsEightLlvm = Join-Path $out 'v3-phase4-jobs-eight.ll'
& $v3Rp1Executable '--emit-llvm' $v3Phase4Project $v3Rp1Target $v3Phase4DefaultLlvm
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $v3Phase4DefaultLlvm)) {
    throw 'UBE Compiler v3 Beta 1 Phase 4 failed its default sequential emission'
}
foreach ($phase4Emission in @(
        @{ Jobs = '1'; Path = $v3Phase4JobsOneLlvm },
        @{ Jobs = '2'; Path = $v3Phase4JobsTwoLlvm },
        @{ Jobs = '8'; Path = $v3Phase4JobsEightLlvm })) {
    & $v3Rp1Executable '--jobs' $phase4Emission.Jobs '--emit-llvm' `
        $v3Phase4Project $v3Rp1Target $phase4Emission.Path
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $phase4Emission.Path)) {
        throw "UBE Compiler v3 Beta 1 Phase 4 failed --jobs $($phase4Emission.Jobs) emission"
    }
}
$v3Phase4ReferenceHash = (Get-FileHash -LiteralPath $v3Phase4DefaultLlvm -Algorithm SHA256).Hash
foreach ($phase4Path in @($v3Phase4JobsOneLlvm, $v3Phase4JobsTwoLlvm, $v3Phase4JobsEightLlvm)) {
    if ((Get-FileHash -LiteralPath $phase4Path -Algorithm SHA256).Hash -ne $v3Phase4ReferenceHash) {
        throw 'Parallel procedure-body semantics changed emitted LLVM'
    }
}
$v3Phase4CoreJobsOneLlvm = Join-Path $out 'v3-phase4-ubecore-jobs-one.ll'
$v3Phase4CoreJobsEightLlvm = Join-Path $out 'v3-phase4-ubecore-jobs-eight.ll'
& $v3Rp1Executable '--jobs' '1' '--emit-llvm' $ubeCoreProject $v3Rp1Target $v3Phase4CoreJobsOneLlvm
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $v3Phase4CoreJobsOneLlvm)) {
    throw 'UBE Compiler v3 Beta 1 Phase 4 failed the sequential UBECore regression'
}
& $v3Rp1Executable '--jobs' '8' '--emit-llvm' $ubeCoreProject $v3Rp1Target $v3Phase4CoreJobsEightLlvm
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $v3Phase4CoreJobsEightLlvm)) {
    throw 'UBE Compiler v3 Beta 1 Phase 4 crashed or failed the eight-worker UBECore regression'
}
if ((Get-FileHash -LiteralPath $v3Phase4CoreJobsOneLlvm -Algorithm SHA256).Hash -ne `
        (Get-FileHash -LiteralPath $v3Phase4CoreJobsEightLlvm -Algorithm SHA256).Hash) {
    throw 'Parallel procedure-body semantics changed UBECore LLVM'
}
$v3Phase4ReferenceSemantics = @(& $v3Rp1Executable '--jobs' '1' '--dump-semantics' `
    $v3Phase4Project $v3Rp1Target)
if ($LASTEXITCODE -ne 0) {
    throw 'UBE Compiler v3 Beta 1 Phase 4 failed sequential semantic serialization'
}
foreach ($phase4Jobs in @('2', '8')) {
    $phase4Semantics = @(& $v3Rp1Executable '--jobs' $phase4Jobs '--dump-semantics' `
        $v3Phase4Project $v3Rp1Target)
    if ($LASTEXITCODE -ne 0 -or `
            (Compare-Object $v3Phase4ReferenceSemantics $phase4Semantics -SyncWindow 0)) {
        throw "Parallel procedure-body semantics changed semantic serialization for --jobs $phase4Jobs"
    }
}
for ($phase4Repetition = 0; $phase4Repetition -lt 3; $phase4Repetition++) {
    $phase4RepeatPath = Join-Path $out "v3-phase4-repeat-$phase4Repetition.ll"
    & $v3Rp1Executable '--jobs' '8' '--emit-llvm' `
        $v3Phase4Project $v3Rp1Target $phase4RepeatPath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $phase4RepeatPath) -or `
            (Get-FileHash -LiteralPath $phase4RepeatPath -Algorithm SHA256).Hash -ne $v3Phase4ReferenceHash) {
        throw 'Parallel procedure-body semantics failed its reproducibility stress gate'
    }
}
$v3Phase4Faults = [ordered]@{
    'semantic-worker-creation' = 'error UBE5320: parallel semantic worker creation failed'
    'semantic-worker-wait' = 'error UBE5321: parallel semantic worker drain failed'
    'semantic-merge' = 'error UBE5322: parallel semantic deterministic merge failed'
    'semantic-transfer' = 'error UBE5323: parallel semantic worker received an incomplete frozen snapshot'
}
foreach ($faultSite in $v3Phase4Faults.Keys) {
    $faultOutput = Join-Path $out "v3-phase4-fault-$faultSite.ll"
    Test-V3Rp1Failure -Name "phase4-$faultSite" `
        -Arguments @('--executor-fault', $faultSite, '--jobs', '8', '--emit-llvm', `
            $v3Phase4Project, $v3Rp1Target, $faultOutput) `
        -ExpectedDiagnostic $v3Phase4Faults[$faultSite]
    if (Test-Path -LiteralPath $faultOutput) {
        throw "Parallel semantic fault $faultSite left a false-success output"
    }
    & $v3Rp1Executable '--jobs' '8' '--emit-llvm' `
        $v3Phase4Project $v3Rp1Target $faultOutput
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $faultOutput) -or `
            (Get-FileHash -LiteralPath $faultOutput -Algorithm SHA256).Hash -ne $v3Phase4ReferenceHash) {
        throw "Parallel semantic cleanup failed after injected fault $faultSite"
    }
}
$v3Phase4ProfileLlvm = Join-Path $out 'v3-phase4-profile.ll'
$v3Phase4ProfilePath = Join-Path $out 'v3-phase4-profile.txt'
& $v3Rp1Executable '--jobs' '8' '--profile' $v3Phase4Project $v3Rp1Target `
    $v3Phase4ProfileLlvm $v3Phase4ProfilePath
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $v3Phase4ProfileLlvm) -or `
        -not (Test-Path -LiteralPath $v3Phase4ProfilePath)) {
    throw 'UBE Compiler v3 Beta 1 Phase 4 failed to produce its bounded-fallback performance profile'
}
$v3Phase4ProfileText = Get-Content -LiteralPath $v3Phase4ProfilePath
foreach ($requiredProfileLine in @('execution=sequential', 'requested_jobs=8', 'effective_jobs=1')) {
    if ($v3Phase4ProfileText -notcontains $requiredProfileLine) {
        throw "Bounded semantic fallback performance profile omitted $requiredProfileLine"
    }
}
$v3Phase4ProfileValues = [ordered]@{}
foreach ($profileLine in $v3Phase4ProfileText) {
    $profileSeparator = $profileLine.IndexOf('=')
    if ($profileSeparator -gt 0) {
        $profileName = $profileLine.Substring(0, $profileSeparator)
        $profileValue = $profileLine.Substring($profileSeparator + 1)
        $v3Phase4ProfileValues[$profileName] = $profileValue
    }
}

$v3Phase0ProfileLlvm = Join-Path $out 'v3-phase0-profile.ll'
$v3Phase0ProfilePath = Join-Path $out 'v3-phase0-profile.txt'
& $v3Rp1Executable '--profile' $v3Rp5StraightLineProject $v3Rp1Target `
    $v3Phase0ProfileLlvm $v3Phase0ProfilePath
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $v3Phase0ProfileLlvm) -or `
        -not (Test-Path -LiteralPath $v3Phase0ProfilePath)) {
    throw 'UBE Compiler v3 Beta 1 failed to produce its sequential performance profile'
}
if ((Get-FileHash -LiteralPath $v3Rp5FirstLlvm -Algorithm SHA256).Hash -ne `
    (Get-FileHash -LiteralPath $v3Phase0ProfileLlvm -Algorithm SHA256).Hash) {
    throw 'Compiler profiling changed emitted LLVM'
}
$v3Phase0ProfileText = Get-Content -LiteralPath $v3Phase0ProfilePath
foreach ($requiredProfileLine in @(
        'UBE-COMPILER-PROFILE 1',
        'execution=sequential',
        'requested_jobs=1',
        'effective_jobs=1')) {
    if ($v3Phase0ProfileText -notcontains $requiredProfileLine) {
        throw "Compiler performance profile omitted $requiredProfileLine"
    }
}
foreach ($requiredProfileField in @(
        'total_wall_ms=', 'total_cpu_ms=', 'peak_working_set_kib=',
        'phase_front_end_ms=', 'phase_parse_ms=', 'phase_semantics_ms=',
        'phase_ir_lower_ms=', 'phase_ir_verify_ms=', 'phase_llvm_ms=',
        'token_count=', 'syntax_node_count=', 'semantic_symbol_count=',
        'semantic_expression_count=', 'ir_instruction_count=',
        'ir_verify_edge_probe_count=', 'llvm_instruction_visit_count=',
        'generated_bytes=')) {
    if (-not ($v3Phase0ProfileText | Where-Object { $_.StartsWith($requiredProfileField, [StringComparison]::Ordinal) })) {
        throw "Compiler performance profile omitted $requiredProfileField"
    }
}
$v3Phase0ProfileValues = [ordered]@{}
foreach ($profileLine in $v3Phase0ProfileText) {
    $profileSeparator = $profileLine.IndexOf('=')
    if ($profileSeparator -gt 0) {
        $profileName = $profileLine.Substring(0, $profileSeparator)
        $profileValue = $profileLine.Substring($profileSeparator + 1)
        $v3Phase0ProfileValues[$profileName] = $profileValue
    }
}
$v3Phase0PhaseTimings = [ordered]@{
    front_end_ms = [long]$v3Phase0ProfileValues['phase_front_end_ms']
    parse_ms = [long]$v3Phase0ProfileValues['phase_parse_ms']
    semantics_ms = [long]$v3Phase0ProfileValues['phase_semantics_ms']
    ir_lower_ms = [long]$v3Phase0ProfileValues['phase_ir_lower_ms']
    ir_verify_ms = [long]$v3Phase0ProfileValues['phase_ir_verify_ms']
    llvm_ms = [long]$v3Phase0ProfileValues['phase_llvm_ms']
}
if ([long]$v3Phase0ProfileValues['llvm_instruction_visit_count'] -le 0 -or `
        [long]$v3Phase0ProfileValues['llvm_instruction_visit_count'] -gt `
        [long]$v3Phase0ProfileValues['ir_instruction_count']) {
    throw 'LLVM function emission revisited instructions outside canonical function ranges'
}
$v3Phase5ControlProfileLlvm = Join-Path $out 'v3-phase5-control-profile.ll'
$v3Phase5ControlProfilePath = Join-Path $out 'v3-phase5-control-profile.txt'
& $v3Rp1Executable '--profile' (Join-Path $v3Rp5Tests 'control-flow.UBE') $v3Rp1Target `
    $v3Phase5ControlProfileLlvm $v3Phase5ControlProfilePath
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $v3Phase5ControlProfileLlvm) -or `
        -not (Test-Path -LiteralPath $v3Phase5ControlProfilePath)) {
    throw 'UBE Compiler v3 Beta 1 Phase 5 failed its indexed control-flow profile'
}
$v3Phase5ControlProfileValues = [ordered]@{}
foreach ($profileLine in (Get-Content -LiteralPath $v3Phase5ControlProfilePath)) {
    $profileSeparator = $profileLine.IndexOf('=')
    if ($profileSeparator -gt 0) {
        $v3Phase5ControlProfileValues[$profileLine.Substring(0, $profileSeparator)] = `
            $profileLine.Substring($profileSeparator + 1)
    }
}
$v3Phase5ControlEdges = [long]$v3Phase5ControlProfileValues['ir_edge_count']
$v3Phase5ControlEdgeProbes = [long]$v3Phase5ControlProfileValues['ir_verify_edge_probe_count']
if ($v3Phase5ControlEdges -le 0 -or $v3Phase5ControlEdgeProbes -le 0 -or `
        $v3Phase5ControlEdgeProbes -gt $v3Phase5ControlEdges * 16) {
    throw 'IR verification did not retain a bounded source-block edge lookup'
}
if ([long]$v3Phase5ControlProfileValues['llvm_instruction_visit_count'] -gt `
        [long]$v3Phase5ControlProfileValues['ir_instruction_count']) {
    throw 'Control-flow LLVM emission revisited instructions outside canonical function ranges'
}
$v3Phase3ProfileLlvm = Join-Path $out 'v3-phase3-profile.ll'
$v3Phase3ProfilePath = Join-Path $out 'v3-phase3-profile.txt'
& $v3Rp1Executable '--jobs' '2' '--profile' $v3Phase3Project $v3Rp1Target `
    $v3Phase3ProfileLlvm $v3Phase3ProfilePath
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $v3Phase3ProfileLlvm) -or `
        -not (Test-Path -LiteralPath $v3Phase3ProfilePath)) {
    throw 'UBE Compiler v3 Beta 1 Phase 3 failed to produce its parallel performance profile'
}
if ((Get-FileHash -LiteralPath $v3Phase3ProfileLlvm -Algorithm SHA256).Hash -ne $v3Phase3ReferenceHash) {
    throw 'Parallel compiler profiling changed emitted LLVM'
}
$v3Phase3ProfileText = Get-Content -LiteralPath $v3Phase3ProfilePath
foreach ($requiredProfileLine in @(
        'UBE-COMPILER-PROFILE 1',
        'execution=sequential',
        'requested_jobs=2',
        'effective_jobs=1')) {
    if ($v3Phase3ProfileText -notcontains $requiredProfileLine) {
        throw "Bounded frontend fallback performance profile omitted $requiredProfileLine"
    }
}
$v3Phase0MissingProfileDirectory = Join-Path $out 'missing-profile-directory'
$v3Phase0FailedLlvm = Join-Path $out 'v3-phase0-failed-profile.ll'
Test-V3Rp1Failure -Name 'performance-profile-write-failure' `
    -Arguments @('--profile', $v3Rp5StraightLineProject, $v3Rp1Target, $v3Phase0FailedLlvm, (Join-Path $v3Phase0MissingProfileDirectory 'profile.txt')) `
    -ExpectedDiagnostic 'error UBE5115: cannot atomically write compiler performance profile'
if ((Test-Path -LiteralPath $v3Phase0FailedLlvm) -or `
        (Test-Path -LiteralPath $v3Phase0MissingProfileDirectory)) {
    throw 'Performance-profile write failure left a false-success artifact'
}
$v3Rp8LinuxLlvm = Join-Path $out 'v3-rp8-linux-x86_64.ll'
$v3Rp8LinuxObject = Join-Path $out 'v3-rp8-linux-x86_64.o'
& $v3Rp1Executable '--emit-llvm' $v3Rp5StraightLineProject `
    'x86_64-unknown-linux-gnu' $v3Rp8LinuxLlvm
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $v3Rp8LinuxLlvm)) {
    throw 'UBE Compiler v3 RP8 failed to emit Linux x86-64 LLVM'
}
& $clangPath '--target=x86_64-unknown-linux-gnu' '-c' $v3Rp8LinuxLlvm `
    '-o' $v3Rp8LinuxObject
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $v3Rp8LinuxObject)) {
    throw 'LLVM failed to produce the RP8 Linux x86-64 ELF object'
}
$v3Rp8DebugHashes = [ordered]@{}
foreach ($debugMode in @('none', 'line', 'full')) {
    $debugProject = Join-Path $v3Rp8Tests "debug-$debugMode.UBE"
    $debugLlvm = Join-Path $out "v3-rp8-debug-$debugMode.ll"
    $debugObject = Join-Path $out "v3-rp8-debug-$debugMode.o"
    & $v3Rp1Executable '--emit-llvm' $debugProject $v3Rp1Target $debugLlvm
    if ($LASTEXITCODE -ne 0) { throw "RP8 $debugMode debugger-metadata emission failed" }
    $debugText = Get-Content -LiteralPath $debugLlvm -Raw
    if ($debugMode -eq 'none' -and $debugText -match '!DICompileUnit|!DILocation|!DILocalVariable|llvm\.dbg\.declare') {
        throw 'RP8 DebugInformation=None retained debugger metadata'
    }
    if ($debugMode -eq 'line' -and
        ($debugText -notmatch '!DICompileUnit' -or $debugText -notmatch '!DILocation' -or
         $debugText -notmatch 'emissionKind: LineTablesOnly' -or
         $debugText -match '!DILocalVariable|llvm\.dbg\.declare')) {
        throw 'RP8 DebugInformation=Line metadata is incomplete or contains variable records'
    }
    if ($debugMode -eq 'full' -and
        ($debugText -notmatch '!DICompileUnit' -or $debugText -notmatch '!DISubprogram' -or
         $debugText -notmatch '!DILocation' -or $debugText -notmatch '!DILocalVariable' -or
         $debugText -notmatch 'llvm\.dbg\.declare')) {
        throw 'RP8 DebugInformation=Full metadata is incomplete'
    }
    & $clangPath '--target=x86_64-w64-windows-gnu' '-c' $debugLlvm '-o' $debugObject
    if ($LASTEXITCODE -ne 0) { throw "LLVM rejected RP8 $debugMode debugger metadata" }
    $v3Rp8DebugHashes[$debugMode] = [ordered]@{
        llvm = (Get-FileHash -LiteralPath $debugLlvm -Algorithm SHA256).Hash
        object = (Get-FileHash -LiteralPath $debugObject -Algorithm SHA256).Hash
    }
}
$v3Rp8OptimizationHashes = [ordered]@{}
foreach ($optimizationMode in @('zero', 'size', 'three')) {
    $optimizationProject = Join-Path $v3Rp8Tests "optimization-$optimizationMode.UBE"
    $optimizationExecutable = Join-Path $out "v3-rp8-optimization-$optimizationMode.exe"
    $optimizationIntermediate = Join-Path $out "v3-rp8-optimization-$optimizationMode.ll"
    & $v3Rp1Executable '--build-native' $optimizationProject $v3Rp1Target $clangPath `
        (Join-Path $out 'bootstrap_runtime.o') (Join-Path $out 'bootstrap_unicode_runtime.o') `
        $optimizationExecutable $optimizationIntermediate
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $optimizationExecutable) -or
        (Test-Path -LiteralPath $optimizationIntermediate)) {
        throw "RP8 Optimization=$optimizationMode native build failed or retained its intermediate"
    }
    & $optimizationExecutable
    if ($LASTEXITCODE -ne 0) {
        throw "RP8 Optimization=$optimizationMode changed observable program behavior"
    }
    $v3Rp8OptimizationHashes[$optimizationMode] =
        (Get-FileHash -LiteralPath $optimizationExecutable -Algorithm SHA256).Hash
}
$v3Rp5StraightLineExecutable = Join-Path $out 'v3-rp5-straight-line.exe'
& $clangPath '--target=x86_64-w64-windows-gnu' '-O2' $v3Rp5FirstLlvm `
    (Join-Path $out 'bootstrap_runtime.o') (Join-Path $out 'bootstrap_unicode_runtime.o') `
    '-o' $v3Rp5StraightLineExecutable
if ($LASTEXITCODE -ne 0) {
    throw 'LLVM failed to link the UBE Compiler v3 RP5 straight-line fixture'
}
& $v3Rp5StraightLineExecutable
if ($LASTEXITCODE -ne 0) {
    throw 'UBE Compiler v3 RP5 straight-line native fixture returned a nonzero exit code'
}

# RP5 is the first v3 preview with a permanent self-build gate.  Keep every
# generated stage under bootstrap/out: only the final, fully verified preview
# is copied to compiler/archived/release-previews when the milestone is completed.
$v3Rp5SelfStageTwoIr = Join-Path $out 'v3-rp5-self-stage2.ll'
$v3Rp5SelfStageTwoObject = Join-Path $out 'v3-rp5-self-stage2.o'
$v3Rp5SelfStageTwoExecutable = Join-Path $out 'v3-rp5-self-stage2.exe'
$v3Rp5SelfStageThreeIr = Join-Path $out 'v3-rp5-self-stage3.ll'
$v3Rp5SelfStageThreeObject = Join-Path $out 'v3-rp5-self-stage3.o'
$v3Rp5CanonicalObjectInput = Join-Path $out 'v3-rp5-self-canonical.ll'

& $v3Rp1Executable '--emit-llvm' $v3Manifest $v3Rp1Target $v3Rp5SelfStageTwoIr
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $v3Rp5SelfStageTwoIr)) {
    throw 'The seed-built UBE Compiler v3 production stage one failed to emit stage-two LLVM IR'
}
Copy-Item -LiteralPath $v3Rp5SelfStageTwoIr -Destination $v3Rp5CanonicalObjectInput -Force
& $clangPath '--target=x86_64-w64-windows-gnu' '-O2' '-c' $v3Rp5CanonicalObjectInput `
    '-o' $v3Rp5SelfStageTwoObject
if ($LASTEXITCODE -ne 0) { throw 'LLVM failed to compile v3 RP5 self-build stage-two IR' }
& $clangPath '--target=x86_64-w64-windows-gnu' '-O2' $v3Rp5SelfStageTwoIr `
    (Join-Path $out 'bootstrap_runtime.o') (Join-Path $out 'bootstrap_unicode_runtime.o') `
    '-o' $v3Rp5SelfStageTwoExecutable
if ($LASTEXITCODE -ne 0) { throw 'LLVM failed to link v3 RP5 self-build stage two' }

& $v3Rp5SelfStageTwoExecutable '--emit-llvm' $v3Manifest $v3Rp1Target $v3Rp5SelfStageThreeIr
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $v3Rp5SelfStageThreeIr)) {
    throw 'The self-built UBE Compiler v3 RP5 failed to repeat its own build'
}
Copy-Item -LiteralPath $v3Rp5SelfStageThreeIr -Destination $v3Rp5CanonicalObjectInput -Force
& $clangPath '--target=x86_64-w64-windows-gnu' '-O2' '-c' $v3Rp5CanonicalObjectInput `
    '-o' $v3Rp5SelfStageThreeObject
if ($LASTEXITCODE -ne 0) { throw 'LLVM failed to compile v3 RP5 self-build stage-three IR' }

$v3Rp5SelfStageTwoIrHash = (Get-FileHash -LiteralPath $v3Rp5SelfStageTwoIr -Algorithm SHA256).Hash
$v3Rp5SelfStageThreeIrHash = (Get-FileHash -LiteralPath $v3Rp5SelfStageThreeIr -Algorithm SHA256).Hash
if ((Get-Item -LiteralPath $v3Rp1StageOneIr).Length -ne `
        (Get-Item -LiteralPath $v3Rp5SelfStageTwoIr).Length -or `
        $v3Rp1StageOneIrHash -ne $v3Rp5SelfStageTwoIrHash) {
    throw 'Seed-built production stage-one LLVM differs from production stage two'
}
if ((Get-Item -LiteralPath $v3Rp5SelfStageTwoIr).Length -ne `
        (Get-Item -LiteralPath $v3Rp5SelfStageThreeIr).Length -or `
        $v3Rp5SelfStageTwoIrHash -ne $v3Rp5SelfStageThreeIrHash) {
    throw 'UBE Compiler v3 RP5 self-build LLVM IR is not byte-identical at the fixed point'
}
$v3Rp5SelfStageTwoObjectHash = (Get-FileHash -LiteralPath $v3Rp5SelfStageTwoObject -Algorithm SHA256).Hash
$v3Rp5SelfStageThreeObjectHash = (Get-FileHash -LiteralPath $v3Rp5SelfStageThreeObject -Algorithm SHA256).Hash
function Get-NormalizedCoffSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 8) { throw "COFF object is too short to normalize: $Path" }
    # COFF bytes 4..7 are the producer timestamp. LLVM 21 does not expose a
    # switch to make that field reproducible, so the fixed-point policy zeros
    # exactly this documented nondeterministic field before comparison.
    $bytes[4] = 0
    $bytes[5] = 0
    $bytes[6] = 0
    $bytes[7] = 0
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '')
    }
    finally {
        $sha.Dispose()
    }
}
$v3Rp5SelfStageTwoNormalizedObjectHash = Get-NormalizedCoffSha256 -Path $v3Rp5SelfStageTwoObject
$v3Rp5SelfStageThreeNormalizedObjectHash = Get-NormalizedCoffSha256 -Path $v3Rp5SelfStageThreeObject
if ((Get-Item -LiteralPath $v3Rp5SelfStageTwoObject).Length -ne `
        (Get-Item -LiteralPath $v3Rp5SelfStageThreeObject).Length -or `
        $v3Rp5SelfStageTwoNormalizedObjectHash -ne $v3Rp5SelfStageThreeNormalizedObjectHash) {
    throw 'UBE Compiler v3 RP5 self-build object output differs after documented COFF timestamp normalization'
}

function Test-V3Rp5NativeFixture {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Project,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$ExpectedOutput,
        [Parameter(Mandatory = $true)][int]$ExpectedExitCode
    )

    $v2BuiltIr = Join-Path $out "v3-rp5-fixture-$Name-seed-built.ll"
    $selfBuiltIr = Join-Path $out "v3-rp5-fixture-$Name-self-built.ll"
    $v2BuiltExecutable = Join-Path $out "v3-rp5-fixture-$Name-seed-built.exe"
    $selfBuiltExecutable = Join-Path $out "v3-rp5-fixture-$Name-self-built.exe"

    & $v3Rp1Executable '--emit-llvm' $Project $v3Rp1Target $v2BuiltIr
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $v2BuiltIr)) {
        throw "The seed-built UBE Compiler v3 failed to emit LLVM for fixture $Name"
    }
    & $v3Rp5SelfStageTwoExecutable '--emit-llvm' $Project $v3Rp1Target $selfBuiltIr
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $selfBuiltIr)) {
        throw "The self-built UBE Compiler v3 RP5 failed to emit LLVM for fixture $Name"
    }

    $v2BuiltIrHash = (Get-FileHash -LiteralPath $v2BuiltIr -Algorithm SHA256).Hash
    $selfBuiltIrHash = (Get-FileHash -LiteralPath $selfBuiltIr -Algorithm SHA256).Hash
    if ((Get-Item -LiteralPath $v2BuiltIr).Length -ne (Get-Item -LiteralPath $selfBuiltIr).Length -or `
            $v2BuiltIrHash -ne $selfBuiltIrHash) {
        throw "UBE Compiler v3 fixture LLVM differs between seed-built and self-built production compilers: $Name"
    }

    & $clangPath @v3Rp5ClangLinkFlags $v2BuiltIr `
        (Join-Path $out 'bootstrap_runtime.o') (Join-Path $out 'bootstrap_unicode_runtime.o') `
        '-o' $v2BuiltExecutable
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $v2BuiltExecutable)) {
        throw "LLVM failed to link the seed-built Compiler v3 fixture: $Name"
    }
    & $clangPath @v3Rp5ClangLinkFlags $selfBuiltIr `
        (Join-Path $out 'bootstrap_runtime.o') (Join-Path $out 'bootstrap_unicode_runtime.o') `
        '-o' $selfBuiltExecutable
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $selfBuiltExecutable)) {
        throw "LLVM failed to link the self-built RP5 fixture: $Name"
    }

    $v2BuiltRun = Invoke-ExpectedNativeFailure -FilePath $v2BuiltExecutable
    $selfBuiltRun = Invoke-ExpectedNativeFailure -FilePath $selfBuiltExecutable
    if ($v2BuiltRun.ExitCode -ne $selfBuiltRun.ExitCode -or $v2BuiltRun.Output -cne $selfBuiltRun.Output) {
        throw "RP5 native fixture behavior differs between compiler stages: $Name"
    }
    if ($v2BuiltRun.ExitCode -ne $ExpectedExitCode -or $v2BuiltRun.Output -cne $ExpectedOutput) {
        throw "RP5 native fixture produced an unexpected result: $Name (exit $($v2BuiltRun.ExitCode), output '$($v2BuiltRun.Output)')"
    }

    return [pscustomobject]@{
        name = $Name
        project = $Project.Substring($root.Length + 1).Replace('\', '/')
        llvm_sha256 = $v2BuiltIrHash
        expected_exit_code = $ExpectedExitCode
        expected_output = $ExpectedOutput
    }
}

$v3Rp5NativeFixtureResults = @(
    Test-V3Rp5NativeFixture -Name 'straight-line' -Project (Join-Path $v3Rp5Tests 'straight-line.UBE') -ExpectedOutput '41' -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'calls' -Project (Join-Path $v3Rp5Tests 'calls.UBE') -ExpectedOutput '42' -ExpectedExitCode 83
    Test-V3Rp5NativeFixture -Name 'control-flow' -Project (Join-Path $v3Rp5Tests 'control-flow.UBE') -ExpectedOutput '0' -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'custom-type-members' -Project (Join-Path $v3Rp5Tests 'custom-type-members.UBE') -ExpectedOutput '42' -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'array-elements' -Project (Join-Path $v3Rp5Tests 'array-elements.UBE') -ExpectedOutput "42`nUBE" -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'array-member' -Project (Join-Path $v3Rp5Tests 'array-member.UBE') -ExpectedOutput "42`n42" -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'byref-indexed' -Project (Join-Path $v3Rp5Tests 'byref-indexed.UBE') -ExpectedOutput "42`nindexed" -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'default-initialization' -Project (Join-Path $v3Rp5Tests 'default-initialization.UBE') -ExpectedOutput 'defaults-ok' -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'divide-overflow' -Project (Join-Path $v3Rp5Tests 'divide-overflow.UBE') -ExpectedOutput "0`n11" -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'array-bounds' -Project (Join-Path $v3Rp5Tests 'array-bounds.UBE') -ExpectedOutput 'UBE runtime: array index out of range: 1' -ExpectedExitCode 65
)

# Exercise the compiler-owned, bounded toolchain handoff in addition to the
# harness-owned Clang invocations above. Both compiler stages must build and
# run the same fixture, while a missing tool must leave no false-success file.
$v3Rp5NativeModeV2Executable = Join-Path $out 'v3-rp5-build-native-seed-built.exe'
$v3Rp5NativeModeV2Ir = Join-Path $out 'v3-rp5-build-native-seed-built.ll'
& $v3Rp1Executable '--build-native' $v3Rp5StraightLineProject $v3Rp1Target $clangPath `
    (Join-Path $out 'bootstrap_runtime.o') (Join-Path $out 'bootstrap_unicode_runtime.o') `
    $v3Rp5NativeModeV2Executable $v3Rp5NativeModeV2Ir
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $v3Rp5NativeModeV2Executable) -or `
        (Test-Path -LiteralPath $v3Rp5NativeModeV2Ir)) {
    throw 'The seed-built Compiler v3 failed its bounded native-build toolchain handoff'
}
$v3Rp5NativeModeV2Run = Invoke-ExpectedNativeFailure -FilePath $v3Rp5NativeModeV2Executable
if ($v3Rp5NativeModeV2Run.ExitCode -ne 0 -or $v3Rp5NativeModeV2Run.Output -cne '41') {
    throw 'The seed-built Compiler v3 native-build result behaved unexpectedly'
}

$v3Rp5NativeModeSelfExecutable = Join-Path $out 'v3-rp5-build-native-self-built.exe'
$v3Rp5NativeModeSelfIr = Join-Path $out 'v3-rp5-build-native-self-built.ll'
& $v3Rp5SelfStageTwoExecutable '--build-native' $v3Rp5StraightLineProject $v3Rp1Target $clangPath `
    (Join-Path $out 'bootstrap_runtime.o') (Join-Path $out 'bootstrap_unicode_runtime.o') `
    $v3Rp5NativeModeSelfExecutable $v3Rp5NativeModeSelfIr
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $v3Rp5NativeModeSelfExecutable) -or `
        (Test-Path -LiteralPath $v3Rp5NativeModeSelfIr)) {
    throw 'The self-built RP5 compiler failed its bounded native-build toolchain handoff'
}
$v3Rp5NativeModeSelfRun = Invoke-ExpectedNativeFailure -FilePath $v3Rp5NativeModeSelfExecutable
if ($v3Rp5NativeModeSelfRun.ExitCode -ne 0 -or $v3Rp5NativeModeSelfRun.Output -cne '41') {
    throw 'The RP5 compiler stages disagreed through the bounded native-build toolchain handoff'
}

$v3Rp5MissingToolExecutable = Join-Path $out 'v3-rp5-missing-tool.exe'
$v3Rp5MissingToolIr = Join-Path $out 'v3-rp5-missing-tool.ll'
$v3Rp5MissingTool = Join-Path $out 'missing-clang.exe'
$v3Rp5MissingToolFailure = Invoke-ExpectedNativeFailure -FilePath $v3Rp1Executable -Arguments @(
    '--build-native', $v3Rp5StraightLineProject, $v3Rp1Target, $v3Rp5MissingTool,
    (Join-Path $out 'bootstrap_runtime.o'), (Join-Path $out 'bootstrap_unicode_runtime.o'),
    $v3Rp5MissingToolExecutable, $v3Rp5MissingToolIr)
if ($v3Rp5MissingToolFailure.ExitCode -eq 0 -or `
        (Test-Path -LiteralPath $v3Rp5MissingToolExecutable) -or `
        (Test-Path -LiteralPath $v3Rp5MissingToolIr)) {
    throw 'RP5 missing-tool failure returned success or left a false-success artifact'
}

# UBECore is the exact RP5 source-library project slice. Reproduce it with
# both v3 stages, compare IR, and compile each result through the frozen ABI.
$v3Rp5CoreV2Ir = Join-Path $out 'v3-rp5-ubecore-seed-built.ll'
$v3Rp5CoreSelfIr = Join-Path $out 'v3-rp5-ubecore-self-built.ll'
$v3Rp5CoreCanonicalIr = Join-Path $out 'v3-rp5-ubecore-canonical.ll'
$v3Rp5CoreV2Object = Join-Path $out 'v3-rp5-ubecore-seed-built.o'
$v3Rp5CoreSelfObject = Join-Path $out 'v3-rp5-ubecore-self-built.o'
& $v3Rp1Executable '--emit-llvm' $ubeCoreProject $v3Rp1Target $v3Rp5CoreV2Ir
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $v3Rp5CoreV2Ir)) {
    throw 'The seed-built Compiler v3 failed to emit the exact UBECore slice'
}
& $v3Rp5SelfStageTwoExecutable '--emit-llvm' $ubeCoreProject $v3Rp1Target $v3Rp5CoreSelfIr
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $v3Rp5CoreSelfIr)) {
    throw 'The self-built RP5 compiler failed to emit the exact UBECore slice'
}
$v3Rp5CoreV2IrHash = (Get-FileHash -LiteralPath $v3Rp5CoreV2Ir -Algorithm SHA256).Hash
$v3Rp5CoreSelfIrHash = (Get-FileHash -LiteralPath $v3Rp5CoreSelfIr -Algorithm SHA256).Hash
if ((Get-Item -LiteralPath $v3Rp5CoreV2Ir).Length -ne (Get-Item -LiteralPath $v3Rp5CoreSelfIr).Length -or `
        $v3Rp5CoreV2IrHash -ne $v3Rp5CoreSelfIrHash) {
    throw 'UBECore LLVM differs between seed-built and self-built production compilers'
}
Copy-Item -LiteralPath $v3Rp5CoreV2Ir -Destination $v3Rp5CoreCanonicalIr -Force
& $clangPath @v3Rp5ClangCompileFlags $v3Rp5CoreCanonicalIr '-o' $v3Rp5CoreV2Object
if ($LASTEXITCODE -ne 0) { throw 'LLVM failed to compile the seed-built UBECore IR' }
Copy-Item -LiteralPath $v3Rp5CoreSelfIr -Destination $v3Rp5CoreCanonicalIr -Force
& $clangPath @v3Rp5ClangCompileFlags $v3Rp5CoreCanonicalIr '-o' $v3Rp5CoreSelfObject
if ($LASTEXITCODE -ne 0) { throw 'LLVM failed to compile the self-built UBECore IR' }
$v3Rp5CoreV2ObjectHash = (Get-FileHash -LiteralPath $v3Rp5CoreV2Object -Algorithm SHA256).Hash
$v3Rp5CoreSelfObjectHash = (Get-FileHash -LiteralPath $v3Rp5CoreSelfObject -Algorithm SHA256).Hash
$v3Rp5CoreV2NormalizedObjectHash = Get-NormalizedCoffSha256 -Path $v3Rp5CoreV2Object
$v3Rp5CoreSelfNormalizedObjectHash = Get-NormalizedCoffSha256 -Path $v3Rp5CoreSelfObject
if ((Get-Item -LiteralPath $v3Rp5CoreV2Object).Length -ne (Get-Item -LiteralPath $v3Rp5CoreSelfObject).Length -or `
        $v3Rp5CoreV2NormalizedObjectHash -ne $v3Rp5CoreSelfNormalizedObjectHash) {
    throw 'UBECore object output differs after documented COFF timestamp normalization'
}

function Assert-V3Rp5CompilerParity {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string[]]$Arguments = @()
    )

    $v2BuiltResult = Invoke-ExpectedNativeFailure -FilePath $v3Rp1Executable -Arguments $Arguments
    $selfBuiltResult = Invoke-ExpectedNativeFailure -FilePath $v3Rp5SelfStageTwoExecutable -Arguments $Arguments
    if ($v2BuiltResult.ExitCode -ne $selfBuiltResult.ExitCode -or `
            $v2BuiltResult.Output -cne $selfBuiltResult.Output) {
        throw "Seed-built and self-built UBE Compiler v3 production compilers disagreed for $Name"
    }
}

$v3Rp5ParityCases = @(
    [pscustomobject]@{ Name = 'own-project'; Arguments = @($v3Manifest, $v3Rp1Target) },
    [pscustomobject]@{ Name = 'multi-module'; Arguments = @((Join-Path $v3Rp1Tests 'rp1-valid.UBE'), $v3Rp1Target) },
    [pscustomobject]@{ Name = 'source-library-slice'; Arguments = @($ubeCoreProject, $v3Rp1Target) },
    [pscustomobject]@{ Name = 'lexical-tokens'; Arguments = @('--dump-tokens', (Join-Path $v3Rp2Tests 'lexical.UBE'), $v3Rp1Target) },
    [pscustomobject]@{ Name = 'comprehensive-syntax'; Arguments = @('--dump-syntax', (Join-Path $v3Rp3Tests 'comprehensive.UBE'), $v3Rp1Target) },
    [pscustomobject]@{ Name = 'typed-semantics'; Arguments = @('--dump-semantics', (Join-Path $v3Rp4Tests 'valid.UBE'), $v3Rp1Target) },
    [pscustomobject]@{ Name = 'typed-ir'; Arguments = @('--dump-ir', $v3Rp5StraightLineProject, $v3Rp1Target) },
    [pscustomobject]@{ Name = 'usage-failure'; Arguments = @() },
    [pscustomobject]@{ Name = 'target-failure'; Arguments = @($v3Manifest, 'unknown-target') },
    [pscustomobject]@{ Name = 'manifest-failure'; Arguments = @((Join-Path $v3Rp1Tests 'unknown-key.UBE'), $v3Rp1Target) },
    [pscustomobject]@{ Name = 'missing-source-failure'; Arguments = @((Join-Path $v3Rp1Tests 'missing-source.UBE'), $v3Rp1Target) },
    [pscustomobject]@{ Name = 'lexer-failure'; Arguments = @((Join-Path $v3Rp2Tests 'malformed.UBE'), $v3Rp1Target) },
    [pscustomobject]@{ Name = 'preprocessor-failure'; Arguments = @((Join-Path $v3Rp2Tests 'conditional-bad.UBE'), $v3Rp1Target) },
    [pscustomobject]@{ Name = 'parser-recovery'; Arguments = @((Join-Path $v3Rp3Tests 'recovery.UBE'), $v3Rp1Target) },
    [pscustomobject]@{ Name = 'semantic-name-failure'; Arguments = @((Join-Path $v3Rp4Tests 'duplicate.UBE'), $v3Rp1Target) },
    [pscustomobject]@{ Name = 'semantic-type-failure'; Arguments = @((Join-Path $v3Rp4Tests 'unknown-type.UBE'), $v3Rp1Target) },
    [pscustomobject]@{ Name = 'semantic-control-flow-failure'; Arguments = @((Join-Path $v3Rp4Tests 'bad-exit.UBE'), $v3Rp1Target) },
    [pscustomobject]@{ Name = 'semantic-callnew-failure'; Arguments = @((Join-Path $v3Rp4Tests 'bad-callnew.UBE'), $v3Rp1Target) }
)
foreach ($v3Rp5ParityCase in $v3Rp5ParityCases) {
    Assert-V3Rp5CompilerParity -Name $v3Rp5ParityCase.Name -Arguments $v3Rp5ParityCase.Arguments
}

$v3Rp5SelfStraightLineLlvm = Join-Path $out 'v3-rp5-self-straight-line.ll'
& $v3Rp5SelfStageTwoExecutable '--emit-llvm' $v3Rp5StraightLineProject $v3Rp1Target $v3Rp5SelfStraightLineLlvm
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $v3Rp5SelfStraightLineLlvm)) {
    throw 'The self-built UBE Compiler v3 RP5 failed to emit the native corpus fixture'
}
if ((Get-FileHash -LiteralPath $v3Rp5FirstLlvm -Algorithm SHA256).Hash -ne `
        (Get-FileHash -LiteralPath $v3Rp5SelfStraightLineLlvm -Algorithm SHA256).Hash) {
    throw 'Seed-built and self-built UBE Compiler v3 native fixture IR differs'
}
$v3Rp5ReleaseCandidate = Join-Path $out 'ube-v3-rp5-windows-x86_64-x86_64-w64-windows-gnu.exe'

# RP6 managed values, object identity/lifecycle, project references, and
# deterministic module initialization must behave identically through both
# compiler stages. Test-V3Rp5NativeFixture is intentionally reused so the
# comparison policy remains exactly the permanent RP5 policy.
$v3Rp6Tests = Join-Path $v3Project 'tests/rp6'
$v3Rp6NativeFixtureResults = @(
    Test-V3Rp5NativeFixture -Name 'rp6-managed-values' -Project (Join-Path $v3Rp6Tests 'managed-values.UBE') -ExpectedOutput "2`n3`n4`n5`n[abcde]`n[xy   ]`n42`n-1`n5000000000`n12.5`nvariant text`n0`n70`n80`n90`n91" -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'rp6-object-dispatch' -Project (Join-Path $v3Rp6Tests 'object-dispatch.UBE') -ExpectedOutput "21`n11`n21`n900`n900`n1" -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'rp6-object-lifecycle' -Project (Join-Path $v3Rp6Tests 'object-lifecycle.UBE') -ExpectedOutput "1`n99`n1`n1`n99" -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'rp6-interface-dispatch' -Project (Join-Path $v3Rp6Tests 'interface-dispatch.UBE') -ExpectedOutput "41`n82" -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'rp6-module-lifecycle' -Project (Join-Path $v3Rp6Tests 'module-lifecycle.UBE') -ExpectedOutput "10`n20`n30`n40`n50`n60`n70" -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'rp6-reference-app' -Project (Join-Path $v3Rp6Tests 'reference-app.UBE') -ExpectedOutput '42' -ExpectedExitCode 0
)

function Test-V3Rp6Failure {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Project,
        [Parameter(Mandatory = $true)][string]$ExpectedDiagnostic
    )
    $outputPath = Join-Path $out "v3-rp6-rejected-$Name.ll"
    Remove-Item -LiteralPath $outputPath -ErrorAction SilentlyContinue
    $arguments = @('--emit-llvm', $Project, $v3Rp1Target, $outputPath)
    $bootstrapFailure = Invoke-ExpectedNativeFailure -FilePath $v3Rp1Executable -Arguments $arguments
    if (Test-Path -LiteralPath $outputPath) {
        throw "The seed-built Compiler v3 left output for rejected fixture $Name"
    }
    $selfFailure = Invoke-ExpectedNativeFailure -FilePath $v3Rp5SelfStageTwoExecutable -Arguments $arguments
    if (Test-Path -LiteralPath $outputPath) {
        throw "The self-built RP6 compiler left output for rejected fixture $Name"
    }
    if ($bootstrapFailure.ExitCode -eq 0 -or $bootstrapFailure.ExitCode -ne $selfFailure.ExitCode -or `
            $bootstrapFailure.Output -cne $selfFailure.Output -or `
            $bootstrapFailure.Output -notlike "*$ExpectedDiagnostic*") {
        throw "RP6 compiler stages disagreed or returned the wrong diagnostic for $Name"
    }
}

Test-V3Rp6Failure -Name 'interface-signature' `
    -Project (Join-Path $v3Rp6Tests 'interface-signature-invalid.UBE') `
    -ExpectedDiagnostic 'error UBE4040: class does not provide the required Interface member: Transform'
Test-V3Rp6Failure -Name 'private-reference' `
    -Project (Join-Path $v3Rp6Tests 'reference-private.UBE') `
    -ExpectedDiagnostic 'error UBE4043: declaration is not public in a direct project Reference: HiddenReferencedValue'
Test-V3Rp6Failure -Name 'transitive-reference' `
    -Project (Join-Path $v3Rp6Tests 'reference-transitive.UBE') `
    -ExpectedDiagnostic 'error UBE4043: declaration is not public in a direct project Reference: TransitiveReferencedValue'
Test-V3Rp6Failure -Name 'reference-cycle' `
    -Project (Join-Path $v3Rp6Tests 'reference-cycle-a.UBE') `
    -ExpectedDiagnostic 'cyclic project Reference'

# RP7 error recovery, threads, synchronization, events, and component lifetime
# must reproduce through both the seed-built and self-built production compilers.
$v3Rp7Tests = Join-Path $v3Project 'tests/rp7'
$v3Rp7NativeFixtureResults = @(
    Test-V3Rp5NativeFixture -Name 'rp7-byref-worker' -Project (Join-Path $v3Rp7Tests 'byref-worker.UBE') -ExpectedOutput "1`n41`n6`n6" -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'rp7-conditional-redim-worker' -Project (Join-Path $v3Rp7Tests 'conditional-redim-worker.UBE') -ExpectedOutput "1`n42" -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'rp7-callnew-ignored' -Project (Join-Path $v3Rp7Tests 'callnew-ignored.UBE') -ExpectedOutput '77' -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'rp7-callnew' -Project (Join-Path $v3Rp7Tests 'callnew.UBE') -ExpectedOutput "-1`n1`n42" -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'rp7-callnew-capture' -Project (Join-Path $v3Rp7Tests 'callnew-capture.UBE') -ExpectedOutput "12`n1`n30`n1`n31" -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'rp7-error-state' -Project (Join-Path $v3Rp7Tests 'error-state.UBE') -ExpectedOutput "123`n0" -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'rp7-neutral-errors' -Project (Join-Path $v3Rp7Tests 'neutral-errors.UBE') -ExpectedOutput "0`n11`n0`n13`n0" -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'rp7-on-error' -Project (Join-Path $v3Rp7Tests 'on-error.UBE') -ExpectedOutput "0`n11`n11`n22`n0`n5`n44`n123`n55`n1`n2`n0`n33" -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'rp7-synclock-error' -Project (Join-Path $v3Rp7Tests 'synclock-error.UBE') -ExpectedOutput "5`n44`n1`n6" -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'rp7-synclock' -Project (Join-Path $v3Rp7Tests 'synclock.UBE') -ExpectedOutput "1`n1`n3" -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'rp7-events' -Project (Join-Path $v3Rp7Tests 'events.UBE') -ExpectedOutput "1`n101`n102" -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'rp7-events-mutation' -Project (Join-Path $v3Rp7Tests 'events-mutation.UBE') -ExpectedOutput "1`n2`n202`n3`n4`n204`n203" -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'rp7-events-class' -Project (Join-Path $v3Rp7Tests 'events-class.UBE') -ExpectedOutput "5`n12" -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'rp7-events-cross-thread' -Project (Join-Path $v3Rp7Tests 'events-cross-thread.UBE') -ExpectedOutput "9`n1`n9`n-1" -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'rp7-events-handler-error' -Project (Join-Path $v3Rp7Tests 'events-handler-error.UBE') -ExpectedOutput '222' -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'rp7-component-lifecycle' -Project (Join-Path $v3Rp7Tests 'component-lifecycle.UBE') -ExpectedOutput "10`n20`n-1`n20`n-1" -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'rp7-component-load-rollback' -Project (Join-Path $v3Rp7Tests 'component-load-rollback.UBE') -ExpectedOutput "-1`n0" -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'rp7-component-drain' -Project (Join-Path $v3Rp7Tests 'component-drain.UBE') -ExpectedOutput "10`n30`n20`n40`n91" -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'rp7-control-parent' -Project (Join-Path $v3Rp7Tests 'control-parent.UBE') -ExpectedOutput '91' -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'rp7-startup-form' -Project (Join-Path $v3Rp7Tests 'startup-form.UBE') -ExpectedOutput "10`n30`n20`n10`n20" -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'rp7-object-identity' -Project (Join-Path $v3Rp7Tests 'object-identity.UBE') -ExpectedOutput "-1`n-1" -ExpectedExitCode 0
    Test-V3Rp5NativeFixture -Name 'rp7-ubecore-coordination' -Project (Join-Path $root 'archive/source-library/AtomicTest.UBE') -ExpectedOutput "1`n5`n5`n8`n1`n4000000009`n1`n-1`n1`n1`n2008`n0`n1`n1`n0`n1`n0`n1`n1`n1`n1`n1`n1`n42`n0" -ExpectedExitCode 0
)
$v3Rp8NativeFixtureResults = @(
    Test-V3Rp5NativeFixture -Name 'rp8-ubecore-public-api' `
        -Project (Join-Path $root 'archive/source-library/CoreApiTest.UBE') `
        -ExpectedOutput "-1`n-1`n1`n1`n1`n42`n3`n1`n-123`n456`n1`n1" -ExpectedExitCode 0
)
Test-V3Rp6Failure -Name 'rp7-event-handler-signature' `
    -Project (Join-Path $v3Rp7Tests 'events-invalid-handler.UBE') `
    -ExpectedDiagnostic 'error UBE4047: WithEvents handler must be a Private Sub with the exact Event signature: Source_Progress'

$v3Rp6ManagedDumpV2 = Invoke-ExpectedNativeFailure -FilePath $v3Rp1Executable `
    -Arguments @('--dump-managed', (Join-Path $v3Rp6Tests 'managed-layout.UBE'), $v3Rp1Target)
$v3Rp6ManagedDumpSelf = Invoke-ExpectedNativeFailure -FilePath $v3Rp5SelfStageTwoExecutable `
    -Arguments @('--dump-managed', (Join-Path $v3Rp6Tests 'managed-layout.UBE'), $v3Rp1Target)
if ($v3Rp6ManagedDumpV2.ExitCode -ne 0 -or $v3Rp6ManagedDumpV2.Output -cne $v3Rp6ManagedDumpSelf.Output -or `
        $v3Rp6ManagedDumpV2.Output -notlike 'UBE-MANAGED 1*') {
    throw 'RP6 managed metadata dump is unsuccessful or nondeterministic'
}
$v3Rp6ManagedHashProvider = [Security.Cryptography.SHA256]::Create()
try {
    $v3Rp6ManagedHashBytes = $v3Rp6ManagedHashProvider.ComputeHash(
        [Text.Encoding]::UTF8.GetBytes($v3Rp6ManagedDumpV2.Output))
    $v3Rp6ManagedDumpHash = -join ($v3Rp6ManagedHashBytes | ForEach-Object { $_.ToString('X2') })
}
finally {
    $v3Rp6ManagedHashProvider.Dispose()
}

$v3Rp6ForeignProject = Join-Path $v3Rp6Tests 'foreign-library.UBE'
$v3Rp6ForeignBootstrapIr = Join-Path $out 'v3-rp6-foreign-seed-built.ll'
$v3Rp6ForeignSelfIr = Join-Path $out 'v3-rp6-foreign-self-built.ll'
& $v3Rp1Executable '--emit-llvm' $v3Rp6ForeignProject $v3Rp1Target $v3Rp6ForeignBootstrapIr
if ($LASTEXITCODE -ne 0) { throw 'The seed-built Compiler v3 failed to emit the foreign library' }
& $v3Rp5SelfStageTwoExecutable '--emit-llvm' $v3Rp6ForeignProject $v3Rp1Target $v3Rp6ForeignSelfIr
if ($LASTEXITCODE -ne 0) { throw 'The self-built RP6 compiler failed to emit the foreign library' }
if ((Get-FileHash -LiteralPath $v3Rp6ForeignBootstrapIr -Algorithm SHA256).Hash -ne `
        (Get-FileHash -LiteralPath $v3Rp6ForeignSelfIr -Algorithm SHA256).Hash -or `
        (Get-FileHash -LiteralPath ($v3Rp6ForeignBootstrapIr + '.h') -Algorithm SHA256).Hash -ne `
        (Get-FileHash -LiteralPath ($v3Rp6ForeignSelfIr + '.h') -Algorithm SHA256).Hash) {
    throw 'RP6 foreign-library IR or generated declarations differ between compiler stages'
}
$v3Rp6ForeignDll = Join-Path $out 'v3-rp6-foreign-library.dll'
& $clangPath '--target=x86_64-w64-windows-gnu' '-O2' '-shared' $v3Rp6ForeignBootstrapIr `
    (Join-Path $out 'bootstrap_runtime.o') (Join-Path $out 'bootstrap_unicode_runtime.o') `
    '-o' $v3Rp6ForeignDll
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $v3Rp6ForeignDll)) {
    throw 'LLVM failed to link the RP6 foreign library'
}
Copy-Item -LiteralPath ($v3Rp6ForeignBootstrapIr + '.h') `
    -Destination (Join-Path $out 'foreign-library.h') -Force
& gcc '-std=c17' '-Wall' '-Wextra' '-Wpedantic' '-Werror' '-fsyntax-only' `
    '-I' $out (Join-Path $PSScriptRoot 'tests/foreign_abi_header_probe.c')
if ($LASTEXITCODE -ne 0) { throw 'RP6 generated foreign ABI declarations failed strict C17 validation' }
$v3Rp6ForeignProbe = Join-Path $out 'foreign-abi-probe.exe'
& gcc '-std=c17' '-Wall' '-Wextra' '-Wpedantic' '-Werror' `
    (Join-Path $PSScriptRoot 'tests/foreign_abi_probe.c') '-o' $v3Rp6ForeignProbe
if ($LASTEXITCODE -ne 0) { throw 'RP6 foreign ABI probe failed to build' }
$v3Rp6ForeignProbeOutput = & $v3Rp6ForeignProbe $v3Rp6ForeignDll
if ($LASTEXITCODE -ne 0 -or $v3Rp6ForeignProbeOutput -ne 'foreign ABI probe passed') {
    throw 'RP6 foreign ABI probe failed'
}

$v3Rp8ReleaseCandidate = Join-Path $out 'ube-v3-rp8-windows-x86_64-x86_64-w64-windows-gnu.exe'

$v3Rp1ManySources = Join-Path $out 'v3-rp1-too-many-sources.UBE'
$manySourcesText = [System.Text.StringBuilder]::new()
[void]$manySourcesText.AppendLine('UBE-Project 1')
[void]$manySourcesText.AppendLine('Name = "TooManySources"')
[void]$manySourcesText.AppendLine('Kind = "Exe"')
[void]$manySourcesText.AppendLine('Startup = "Main"')
for ($sourceIndex = 0; $sourceIndex -le 1024; $sourceIndex++) {
    [void]$manySourcesText.AppendLine(('Source = "Module{0}.bas"' -f $sourceIndex))
}
[System.IO.File]::WriteAllText($v3Rp1ManySources, $manySourcesText.ToString(), [System.Text.UTF8Encoding]::new($false))
Test-V3Rp1Failure -Name 'source-limit' -Arguments @($v3Rp1ManySources, $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE3014: project exceeds the 1024-source limit'

$v3Rp1LargeManifest = Join-Path $out 'v3-rp1-oversized.UBE'
[System.IO.File]::WriteAllText($v3Rp1LargeManifest, ('x' * 1048577), [System.Text.UTF8Encoding]::new($false))
Test-V3Rp1Failure -Name 'manifest-limit' -Arguments @($v3Rp1LargeManifest, $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE3001: project manifest exceeds the 1048576-byte limit'

$v3Rp1InvalidSource = Join-Path $out 'v3-rp1-invalid-utf8.bas'
[System.IO.File]::WriteAllBytes($v3Rp1InvalidSource, [byte[]](0xC3, 0x28))
$v3Rp1InvalidSourceProject = Join-Path $out 'v3-rp1-invalid-utf8.UBE'
$invalidSourceProjectText = "UBE-Project 1`nName = `"InvalidUtf8`"`nKind = `"Exe`"`nStartup = `"Main`"`nSource = `"v3-rp1-invalid-utf8.bas`"`n"
[System.IO.File]::WriteAllText($v3Rp1InvalidSourceProject, $invalidSourceProjectText, [System.Text.UTF8Encoding]::new($false))
Test-V3Rp1Failure -Name 'invalid-source-utf8' -Arguments @($v3Rp1InvalidSourceProject, $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE3102: source is not valid UTF-8'

$v3Rp1OversizedSource = Join-Path $out 'v3-rp1-oversized-source.bas'
[System.IO.File]::WriteAllText($v3Rp1OversizedSource, [string]::new([char]'a', 16777217), [System.Text.UTF8Encoding]::new($false))
$v3Rp1OversizedSourceProject = Join-Path $out 'v3-rp1-oversized-source.UBE'
$oversizedSourceProjectText = "UBE-Project 1`nName = `"OversizedSource`"`nKind = `"Exe`"`nStartup = `"Main`"`nSource = `"v3-rp1-oversized-source.bas`"`n"
[System.IO.File]::WriteAllText($v3Rp1OversizedSourceProject, $oversizedSourceProjectText, [System.Text.UTF8Encoding]::new($false))
Test-V3Rp1Failure -Name 'source-size-limit' -Arguments @($v3Rp1OversizedSourceProject, $v3Rp1Target) `
    -ExpectedDiagnostic 'error UBE3101: source exceeds the 16777216-byte limit'

function Get-V3ManifestSourceHashes {
    param([Parameter(Mandatory = $true)][string]$ManifestPath)

    $hashes = [ordered]@{}
    foreach ($manifestLine in (Get-Content -LiteralPath $ManifestPath)) {
        if ($manifestLine -match '^Source = "([^"]+)"$') {
            $sourceName = $Matches[1]
            if ($hashes.Contains($sourceName)) {
                throw "Duplicate source in compiler manifest ${ManifestPath}: $sourceName"
            }
            $sourcePath = Join-Path $v3Project $sourceName
            if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
                throw "Compiler manifest source does not exist: $sourcePath"
            }
            $hashes[$sourceName] = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
        }
    }
    if ($hashes.Count -eq 0) {
        throw "Compiler manifest contains no sources: $ManifestPath"
    }
    Write-Output -NoEnumerate $hashes
}
$v3SourceHashes = Get-V3ManifestSourceHashes -ManifestPath $v3Manifest
$v3SeedSourceHashes = Get-V3ManifestSourceHashes -ManifestPath $v3SeedManifest
$v3Rp1BuildManifest = [ordered]@{
    schema = 'ube-v3-beta1-build-manifest-1'
    preview = 'RP8'
    development_milestone = 'Beta 1 multithreading Phase 4'
    compiler_generation = 3
    language = '1.0'
    project_format = 'UBE-Project 1'
    core_package = 'UBECore'
    core_library_version = '0.1.0-rp8'
    intrinsic_abi = 'ube-intrinsic-abi-1'
    source_library_slice = @(
        'src/portable/CoreIdentity.bas',
        'src/portable/RuntimeIntrinsics.bas',
        'src/portable/Conversions.bas',
        'src/portable/Strings.bas',
        'src/portable/Memory.bas',
        'src/portable/Variants.bas',
        'src/portable/Errors.bas',
        'src/portable/Threads.bas',
        'src/portable/AtomicBoolean.cls',
        'src/portable/AtomicLong.cls',
        'src/portable/AtomicLongLong.cls',
        'src/portable/AtomicObject.cls',
        'src/portable/ThreadEvent.cls',
        'src/portable/Semaphore.cls',
        'src/portable/MessageQueue.cls',
        'src/portable/Synchronization.bas'
    )
    target = 'x86_64-w64-windows-gnu'
    optimization = '-O2'
    compiler_stage1 = (Get-FileHash -LiteralPath $v2StageOne -Algorithm SHA256).Hash
    compiler_stage2 = (Get-FileHash -LiteralPath $v2StageTwo -Algorithm SHA256).Hash
    project = (Get-FileHash -LiteralPath $v3Manifest -Algorithm SHA256).Hash
    grammar = (Get-FileHash -LiteralPath (Join-Path $root 'lang-doc/grammar/ube.ebnf') -Algorithm SHA256).Hash
    sources = $v3SourceHashes
    core_library_project = (Get-FileHash -LiteralPath $ubeCoreProject -Algorithm SHA256).Hash
    core_library_identity_source = (Get-FileHash -LiteralPath (Join-Path $root 'archive/source-library/src/portable/CoreIdentity.bas') -Algorithm SHA256).Hash
    runtime_source = (Get-FileHash -LiteralPath (Join-Path $root 'runtime/bootstrap_runtime.c') -Algorithm SHA256).Hash
    unicode_runtime_source = (Get-FileHash -LiteralPath (Join-Path $root 'runtime/bootstrap_unicode_runtime.cpp') -Algorithm SHA256).Hash
    runtime_object = (Get-FileHash -LiteralPath (Join-Path $out 'bootstrap_runtime.o') -Algorithm SHA256).Hash
    unicode_runtime_object = (Get-FileHash -LiteralPath (Join-Path $out 'bootstrap_unicode_runtime.o') -Algorithm SHA256).Hash
    llvm_ir = $v3Rp1StageOneIrHash
    bootstrap_chain = [ordered]@{
        policy = 'stage zero -> preserved v2 -> sequential seed -> production stage one -> production stages two and three'
        seed_identity = 'ube-v3-sequential-seed-1'
        seed_manifest = 'compiler/archived/UBE_Compiler_v3/UBE_Compiler_v3_seed.UBE'
        seed_manifest_sha256 = (Get-FileHash -LiteralPath $v3SeedManifest -Algorithm SHA256).Hash
        seed_sources = $v3SeedSourceHashes
        v2_stage1_seed_ir_sha256 = $v3SeedStageOneIrHash
        v2_stage2_seed_ir_sha256 = $v3SeedStageTwoIrHash
        seed_executable_sha256 = (Get-FileHash -LiteralPath $v3SeedExecutable -Algorithm SHA256).Hash
        production_identity = 'ube-v3-production-rp8'
        production_manifest = 'compiler/archived/UBE_Compiler_v3/UBE_Compiler_v3.UBE'
        production_manifest_sha256 = (Get-FileHash -LiteralPath $v3Manifest -Algorithm SHA256).Hash
        seed_built_production_stage1_ir_sha256 = $v3Rp1StageOneIrHash
        seed_built_production_stage1_executable_sha256 = (Get-FileHash -LiteralPath $v3Rp1Executable -Algorithm SHA256).Hash
    }
    execution = [ordered]@{
        executor_identity = 'ube-v3-bounded-sequential-executor-1'
        execution = $v3Phase0ProfileValues['execution']
        requested_jobs = [int]$v3Phase0ProfileValues['requested_jobs']
        effective_jobs = [int]$v3Phase0ProfileValues['effective_jobs']
        total_wall_ms = [long]$v3Phase0ProfileValues['total_wall_ms']
        total_cpu_ms = [long]$v3Phase0ProfileValues['total_cpu_ms']
        peak_working_set_kib = [long]$v3Phase0ProfileValues['peak_working_set_kib']
        phase_timings = $v3Phase0PhaseTimings
    }
    parallel_semantics = [ordered]@{
        policy = 'worker fault paths retained; normal activation performance-gated to coordinator analysis; byte-identical LLVM for jobs 1, 2, and 8'
        tested_jobs = @(1, 2, 8)
        llvm_sha256 = $v3Phase4ReferenceHash
        requested_jobs = [int]$v3Phase4ProfileValues['requested_jobs']
        effective_jobs = [int]$v3Phase4ProfileValues['effective_jobs']
        execution = $v3Phase4ProfileValues['execution']
        fault_codes = @('UBE5320', 'UBE5321', 'UBE5322', 'UBE5323')
    }
    self_build_comparison = [ordered]@{
        policy = 'byte-identical LLVM IR; equal-length COFF objects with identical SHA-256 after zeroing only the 4-byte COFF producer timestamp'
        stage2_ir_sha256 = $v3Rp5SelfStageTwoIrHash
        stage3_ir_sha256 = $v3Rp5SelfStageThreeIrHash
        stage2_object_sha256 = $v3Rp5SelfStageTwoObjectHash
        stage3_object_sha256 = $v3Rp5SelfStageThreeObjectHash
        stage2_normalized_object_sha256 = $v3Rp5SelfStageTwoNormalizedObjectHash
        stage3_normalized_object_sha256 = $v3Rp5SelfStageThreeNormalizedObjectHash
        corpus_policy = 'identical exit code and ordinal output text for the recorded inherited, RP6, and RP7 parity corpora plus RP8 project/package closure gates'
        corpus_case_count = $v3Rp5ParityCases.Count + $v3Rp6NativeFixtureResults.Count + $v3Rp7NativeFixtureResults.Count + $v3Rp8NativeFixtureResults.Count + 5
    }
    source_library_comparison = [ordered]@{
        project = 'archive/source-library/UBECore.UBE'
        seed_built_ir_sha256 = $v3Rp5CoreV2IrHash
        self_built_ir_sha256 = $v3Rp5CoreSelfIrHash
        seed_built_object_sha256 = $v3Rp5CoreV2ObjectHash
        self_built_object_sha256 = $v3Rp5CoreSelfObjectHash
        seed_built_normalized_object_sha256 = $v3Rp5CoreV2NormalizedObjectHash
        self_built_normalized_object_sha256 = $v3Rp5CoreSelfNormalizedObjectHash
    }
    native_profile_fixtures = @($v3Rp5NativeFixtureResults + $v3Rp6NativeFixtureResults + $v3Rp7NativeFixtureResults + $v3Rp8NativeFixtureResults)
    managed_metadata_sha256 = $v3Rp6ManagedDumpHash
    foreign_library_ir = (Get-FileHash -LiteralPath $v3Rp6ForeignBootstrapIr -Algorithm SHA256).Hash
    foreign_library = (Get-FileHash -LiteralPath $v3Rp6ForeignDll -Algorithm SHA256).Hash
    resource_container = (Get-FileHash -LiteralPath (Join-Path $out 'rp8-package.UBR') -Algorithm SHA256).Hash
    resource_llvm = (Get-FileHash -LiteralPath $v3Rp8ResourceLlvm -Algorithm SHA256).Hash
    resource_object = (Get-FileHash -LiteralPath $v3Rp8ResourceObject -Algorithm SHA256).Hash
    library_bundle = (Get-FileHash -LiteralPath (Join-Path $out 'rp8-package.UBL') -Algorithm SHA256).Hash
    linux_x86_64_llvm = (Get-FileHash -LiteralPath $v3Rp8LinuxLlvm -Algorithm SHA256).Hash
    linux_x86_64_object = (Get-FileHash -LiteralPath $v3Rp8LinuxObject -Algorithm SHA256).Hash
    debugger_metadata = $v3Rp8DebugHashes
    optimization_artifacts = $v3Rp8OptimizationHashes
    clang_compile_flags = $v3Rp5ClangCompileFlags
    clang_link_flags = $v3Rp5ClangLinkFlags
    straight_line_ir = (Get-FileHash -LiteralPath $v3Rp5FirstLlvm -Algorithm SHA256).Hash
    straight_line_executable = (Get-FileHash -LiteralPath $v3Rp5StraightLineExecutable -Algorithm SHA256).Hash
    executable = (Get-FileHash -LiteralPath $v3Rp1Executable -Algorithm SHA256).Hash
    self_built_executable = (Get-FileHash -LiteralPath $v3Rp5SelfStageTwoExecutable -Algorithm SHA256).Hash
    release_candidate = (Get-FileHash -LiteralPath $v3Rp5SelfStageTwoExecutable -Algorithm SHA256).Hash
    clang = ((& $clangPath '--version' | Select-Object -First 1).ToString())
}
$v3Rp1BuildManifest | ConvertTo-Json -Depth 5 | `
    Set-Content -LiteralPath (Join-Path $out 'v3-beta1-build-manifest.json') -Encoding UTF8

function Test-V2Failure {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$ExpectedDiagnostic,
        [int]$ExpectedExitCode = 1
    )

    $resultPath = Join-Path $out "$Name.ll"
    Remove-Item -LiteralPath $resultPath -ErrorAction SilentlyContinue
    $failure = Invoke-ExpectedNativeFailure -FilePath $v2StageOne -Arguments @($SourcePath, $resultPath)
    if ($failure.ExitCode -ne $ExpectedExitCode) {
        throw "UBE Compiler v2 returned the wrong exit code for $Name"
    }
    if ($failure.Output -notlike "*$ExpectedDiagnostic*") {
        throw "UBE Compiler v2 returned the wrong diagnostic for $Name`: $($failure.Output)"
    }
    if (Test-Path -LiteralPath $resultPath) {
        throw "UBE Compiler v2 left an output artifact for rejected input $Name"
    }
    if (Test-Path -LiteralPath $v2StageTwo) {
        $stageTwoResultPath = Join-Path $out "$Name-stage2.ll"
        Remove-Item -LiteralPath $stageTwoResultPath -ErrorAction SilentlyContinue
        $stageTwoFailure = Invoke-ExpectedNativeFailure -FilePath $v2StageTwo `
            -Arguments @($SourcePath, $stageTwoResultPath)
        if ($stageTwoFailure.ExitCode -ne $failure.ExitCode -or $stageTwoFailure.Output -ne $failure.Output) {
            throw "UBE Compiler v2 stages one and two disagreed for rejected input $Name"
        }
        if (Test-Path -LiteralPath $stageTwoResultPath) {
            throw "UBE Compiler v2 stage two left an output artifact for rejected input $Name"
        }
    }
}

Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/unterminated_string.bas') `
    -Name 'v2-unterminated-string' -ExpectedDiagnostic '(2,11): error UBE1004: unterminated string literal'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/duplicate_main.bas') `
    -Name 'v2-duplicate-main' -ExpectedDiagnostic 'error UBE2100: duplicate procedure name: Main'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/missing_function_result.bas') `
    -Name 'v2-missing-function-result' -ExpectedDiagnostic 'error UBE2003: Function must assign its result before returning'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/invalid_print_expression.bas') `
    -Name 'v2-invalid-print-expression' -ExpectedDiagnostic 'error UBE2220: expected expression'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/duplicate_unicode_procedure.bas') `
    -Name 'v2-duplicate-unicode-procedure' -ExpectedDiagnostic 'error UBE2100: duplicate procedure name'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/unterminated_procedure.bas') `
    -Name 'v2-unterminated-procedure' -ExpectedDiagnostic '(1,1): error UBE2101: unterminated procedure declaration'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/duplicate_unicode_type.bas') `
    -Name 'v2-duplicate-unicode-type' -ExpectedDiagnostic 'error UBE2110: duplicate Type name'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/unterminated_type.bas') `
    -Name 'v2-unterminated-type' -ExpectedDiagnostic '(1,1): error UBE2111: unterminated Type declaration'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/duplicate_unicode_field.bas') `
    -Name 'v2-duplicate-unicode-field' -ExpectedDiagnostic 'error UBE2114: duplicate field name'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/missing_field_type.bas') `
    -Name 'v2-missing-field-type' -ExpectedDiagnostic 'error UBE2116: Type field requires an explicit As type'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/duplicate_unicode_parameter.bas') `
    -Name 'v2-duplicate-unicode-parameter' -ExpectedDiagnostic 'error UBE2121: duplicate parameter name'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/missing_parameter_type.bas') `
    -Name 'v2-missing-parameter-type' -ExpectedDiagnostic 'error UBE2123: parameter requires an explicit As type'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/missing_function_type.bas') `
    -Name 'v2-missing-function-type' -ExpectedDiagnostic 'error UBE2127: Function requires an explicit result type'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/main_with_parameter.bas') `
    -Name 'v2-main-with-parameter' -ExpectedDiagnostic 'error UBE3003: Main must not have parameters'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/main_wrong_result.bas') `
    -Name 'v2-main-wrong-result' -ExpectedDiagnostic 'error UBE3004: Function Main must return Long'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/intrinsic_main.bas') `
    -Name 'v2-intrinsic-main' -ExpectedDiagnostic 'error UBE3002: Main cannot be Intrinsic'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/missing_main.bas') `
    -Name 'v2-missing-main' -ExpectedDiagnostic 'error UBE3000: executable requires Sub Main() or Function Main() As Long'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/local_duplicates_parameter.bas') `
    -Name 'v2-local-duplicates-parameter' -ExpectedDiagnostic 'error UBE2201: local name duplicates a parameter'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/duplicate_unicode_local.bas') `
    -Name 'v2-duplicate-unicode-local' -ExpectedDiagnostic 'error UBE2202: duplicate local name'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/missing_local_type.bas') `
    -Name 'v2-missing-local-type' -ExpectedDiagnostic 'error UBE2204: local variable requires an explicit As type'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/missing_initializer.bas') `
    -Name 'v2-missing-initializer' -ExpectedDiagnostic 'error UBE2206: local initializer requires an expression'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/missing_call_target.bas') `
    -Name 'v2-missing-call-target' -ExpectedDiagnostic 'error UBE2210: expected procedure name after Call'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/missing_assignment_value.bas') `
    -Name 'v2-missing-assignment-value' -ExpectedDiagnostic 'error UBE2211: assignment requires a value'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/undeclared_assignment.bas') `
    -Name 'v2-undeclared-assignment' -ExpectedDiagnostic 'error UBE3100: assignment target is not declared: Missing'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/unknown_call.bas') `
    -Name 'v2-unknown-call' -ExpectedDiagnostic 'error UBE3101: procedure is not declared: Missing'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/incomplete_binary_expression.bas') `
    -Name 'v2-incomplete-binary-expression' -ExpectedDiagnostic 'error UBE2220: expected expression'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/incomplete_call_argument.bas') `
    -Name 'v2-incomplete-call-argument' -ExpectedDiagnostic 'error UBE2220: expected expression'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/unknown_initializer_name.bas') `
    -Name 'v2-unknown-initializer-name' -ExpectedDiagnostic 'error UBE3102: name is not declared: Missing'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/wrong_argument_count.bas') `
    -Name 'v2-wrong-argument-count' -ExpectedDiagnostic 'error UBE3103: argument count does not match callable'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/incompatible_initializer_type.bas') `
    -Name 'v2-incompatible-initializer-type' -ExpectedDiagnostic 'error UBE3201: local initializer type is not assignable'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/incompatible_operator_types.bas') `
    -Name 'v2-incompatible-operator-types' -ExpectedDiagnostic 'error UBE3200: expression has incompatible or unresolved types'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/call_scalar.bas') `
    -Name 'v2-call-scalar' -ExpectedDiagnostic 'error UBE3209: expression is not callable or indexable'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/invalid_unary_string.bas') `
    -Name 'v2-invalid-unary-string' -ExpectedDiagnostic 'error UBE3200: expression has incompatible or unresolved types'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/invalid_string_and.bas') `
    -Name 'v2-invalid-string-and' -ExpectedDiagnostic 'error UBE3200: expression has incompatible or unresolved types'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/byref_literal.bas') `
    -Name 'v2-byref-literal' -ExpectedDiagnostic 'error UBE3202: ByRef argument must be an addressable variable'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/incompatible_assignment.bas') `
    -Name 'v2-incompatible-assignment' -ExpectedDiagnostic 'error UBE3208: assigned value has an incompatible type'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/invalid_array_index.bas') `
    -Name 'v2-invalid-array-index' -ExpectedDiagnostic 'error UBE3205: array index must be Long'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/if_missing_then.bas') `
    -Name 'v2-if-missing-then' -ExpectedDiagnostic 'error UBE2230: block If requires a condition followed by Then'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/orphan_else.bas') `
    -Name 'v2-orphan-else' -ExpectedDiagnostic 'error UBE2232: Else has no matching block If'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/duplicate_else.bas') `
    -Name 'v2-duplicate-else' -ExpectedDiagnostic 'error UBE2233: block If has more than one Else'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/mismatched_wend.bas') `
    -Name 'v2-mismatched-wend' -ExpectedDiagnostic 'error UBE2234: Wend does not match the open structured statement'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/unterminated_while.bas') `
    -Name 'v2-unterminated-while' -ExpectedDiagnostic 'error UBE2235: unterminated structured statement'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/invalid_if_condition.bas') `
    -Name 'v2-invalid-if-condition' -ExpectedDiagnostic 'error UBE3210: structured statement condition must be Boolean or integral'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/unsupported_paramarray.bas') `
    -Name 'v2-unsupported-paramarray' -ExpectedDiagnostic 'error UBE2128: ParamArray is not supported by this compiler generation'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/unsupported_for.bas') `
    -Name 'v2-unsupported-for' -ExpectedDiagnostic 'error UBE2238: structured statement is reserved for UBE Compiler v3: For'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/bare_exit.bas') `
    -Name 'v2-bare-exit' -ExpectedDiagnostic 'error UBE2216: Exit requires Sub, Function, or While'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/wrong_exit_kind.bas') `
    -Name 'v2-wrong-exit-kind' -ExpectedDiagnostic 'error UBE2219: Exit Function is only valid inside a Function'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/orphan_exit_while.bas') `
    -Name 'v2-orphan-exit-while' -ExpectedDiagnostic 'error UBE2226: Exit While requires an enclosing While block'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/redim_scalar.bas') `
    -Name 'v2-redim-scalar' -ExpectedDiagnostic 'error UBE3211: ReDim target must be a dynamic array'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/redim_string_bound.bas') `
    -Name 'v2-redim-string-bound' -ExpectedDiagnostic 'error UBE3212: ReDim upper bound must be Long'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/unknown_unused_type.bas') `
    -Name 'v2-unknown-unused-type' -ExpectedDiagnostic 'error UBE3214: unknown local type: MissingType'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/path_escape.UBE') `
    -Name 'v2-project-path-escape' -ExpectedDiagnostic 'error UBE5009: project Source path is empty, absolute, or escapes the project directory'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/multi_error.UBE') `
    -Name 'v2-project-multi-module-diagnostic' -ExpectedDiagnostic 'modules/multi_error_support.bas(2,10): error UBE3101: procedure is not declared: Missing'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/duplicate_normalized_source.UBE') `
    -Name 'v2-project-duplicate-normalized-source' -ExpectedDiagnostic 'error UBE5010: duplicate project Source after path normalization'
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/missing_second_source.UBE') `
    -Name 'v2-project-missing-second-source' -ExpectedDiagnostic 'UBE runtime: cannot open for reading:' -ExpectedExitCode 66
Test-V2Failure -SourcePath (Join-Path $v2Project 'tests/unknown_key.UBE') `
    -Name 'v2-project-unknown-key' -ExpectedDiagnostic 'error UBE5007: unsupported project key: Mystery'

$v2NulSource = Join-Path $out 'v2-nul-source.bas'
[IO.File]::WriteAllBytes($v2NulSource, [byte[]](83, 117, 98, 32, 77, 97, 105, 110, 40, 41, 10, 0))
Test-V2Failure -SourcePath $v2NulSource -Name 'v2-nul-source' `
    -ExpectedDiagnostic 'UBE runtime: text file contains an embedded NUL byte' -ExpectedExitCode 66

$v2LoneCrSource = Join-Path $out 'v2-lone-cr-source.bas'
[IO.File]::WriteAllBytes($v2LoneCrSource, [byte[]](83, 117, 98, 32, 77, 97, 105, 110, 40, 41, 13, 69))
Test-V2Failure -SourcePath $v2LoneCrSource -Name 'v2-lone-cr-source' `
    -ExpectedDiagnostic '(1,11): error UBE1002: lone carriage return is not a valid line ending'

$v2InvalidUtf8Source = Join-Path $out 'v2-invalid-utf8-source.bas'
[IO.File]::WriteAllBytes($v2InvalidUtf8Source, [byte[]](83, 117, 98, 32, 77, 97, 105, 110, 40, 41, 10, 192, 175))
Test-V2Failure -SourcePath $v2InvalidUtf8Source -Name 'v2-invalid-utf8-source' `
    -ExpectedDiagnostic '(2,1): error UBE1005: source is not valid UTF-8'

& (Join-Path $out 'ubec.exe') '--check' (Join-Path $PSScriptRoot 'tests/fixtures/basic.bas')
if ($LASTEXITCODE -ne 0) { throw 'Compiler check smoke test failed' }

$v2BootstrapManifestPath = Join-Path $out 'v2-bootstrap-manifest.json'
$v2BootstrapManifest = [ordered]@{
    schema = 'ube-bootstrap-manifest-1'
    generation = 'UBE_Compiler_v2'
    target = 'x86_64-w64-windows-gnu'
    optimization = '-O2'
    comparison = [ordered]@{
        policy = 'byte-identical LLVM IR, verified by equal byte length and SHA-256'
        stage2_ir_sha256 = $v2StageTwoIrHash
        stage3_ir_sha256 = $v2StageThreeIrHash
    }
    tools = [ordered]@{
        clang = ((& $clangPath '--version' | Select-Object -First 1).ToString())
        gcc = ((& g++ '--version' | Select-Object -First 1).ToString())
        powershell = $PSVersionTable.PSVersion.ToString()
        os = [Environment]::OSVersion.VersionString
    }
    inputs = [ordered]@{
        project = (Get-FileHash -LiteralPath (Join-Path $v2Project 'UBE_Compiler_v2.UBE') -Algorithm SHA256).Hash
        source = (Get-FileHash -LiteralPath (Join-Path $v2Project 'Main.bas') -Algorithm SHA256).Hash
        runtime_source = (Get-FileHash -LiteralPath (Join-Path $root 'runtime/bootstrap_runtime.c') -Algorithm SHA256).Hash
        unicode_runtime_source = (Get-FileHash -LiteralPath (Join-Path $root 'runtime/bootstrap_unicode_runtime.cpp') -Algorithm SHA256).Hash
    }
    artifacts = [ordered]@{
        stage0 = (Get-FileHash -LiteralPath (Join-Path $out 'ubec.exe') -Algorithm SHA256).Hash
        runtime_object = (Get-FileHash -LiteralPath (Join-Path $out 'bootstrap_runtime.o') -Algorithm SHA256).Hash
        unicode_runtime_object = (Get-FileHash -LiteralPath (Join-Path $out 'bootstrap_unicode_runtime.o') -Algorithm SHA256).Hash
        stage1 = (Get-FileHash -LiteralPath $v2StageOne -Algorithm SHA256).Hash
        stage2_ir = $v2StageTwoIrHash
        stage2 = (Get-FileHash -LiteralPath $v2StageTwo -Algorithm SHA256).Hash
        stage3_ir = $v2StageThreeIrHash
    }
}
$v2BootstrapManifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $v2BootstrapManifestPath -Encoding UTF8

# Materialize the named RP8 release candidate only after every inherited and
# preview-specific gate above has passed.  The completion workflow can then
# copy this exact file and hash into compiler/archived/release-previews.
Copy-Item -LiteralPath $v3Rp5SelfStageTwoExecutable -Destination $v3Rp8ReleaseCandidate
$global:LASTEXITCODE = 0
