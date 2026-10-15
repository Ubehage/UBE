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
if ($overflowFailure.ExitCode -ne 65) { throw 'Integer overflow did not use the controlled failure path' }

$stringProgram = Join-Path $out 'strings.exe'
& (Join-Path $out 'ubec.exe') '--compile' `
    (Join-Path $PSScriptRoot 'tests/fixtures/strings.bas') '-o' $stringProgram
if ($LASTEXITCODE -ne 0) { throw 'String native compilation failed' }
$stringOutput = & $stringProgram
if ($LASTEXITCODE -ne 0) { throw 'String program returned a nonzero exit code' }
if ($stringOutput -ne 'Hello from UBE') { throw 'String program produced unexpected output' }

$intrinsicProgram = Join-Path $out 'intrinsics.exe'
& (Join-Path $out 'ubec.exe') '--compile' `
    (Join-Path $PSScriptRoot 'tests/fixtures/intrinsics.bas') '-o' $intrinsicProgram
if ($LASTEXITCODE -ne 0) { throw 'Intrinsic native compilation failed' }
$roundTripPath = Join-Path $out 'intrinsic-round-trip.txt'
$intrinsicOutput = & $intrinsicProgram $roundTripPath
if ($LASTEXITCODE -ne 0) { throw 'Intrinsic program returned a nonzero exit code' }
if (($intrinsicOutput -join ',') -ne '1,3,98,bc,4,line!,-42,joined-text,1,0,229,file-data') { throw 'Intrinsic program produced unexpected output' }
if ((Get-Content -Raw $roundTripPath) -ne 'file-data') { throw 'Intrinsic file round trip produced unexpected data' }

$stageOneProject = Join-Path $root 'compiler/UBE_Compiler_v1'
$stageOne = Join-Path $out 'ube-stage1.exe'
& (Join-Path $out 'ubec.exe') '--compile' (Join-Path $stageOneProject 'Main.bas') '-o' $stageOne
if ($LASTEXITCODE -ne 0) { throw 'Stage zero failed to compile the UBE-written compiler' }

$clangCommand = Get-Command clang -ErrorAction SilentlyContinue
$clangPath = if ($clangCommand) { $clangCommand.Source } else { 'C:\Program Files\LLVM\bin\clang.exe' }
if (-not (Test-Path $clangPath)) { throw 'LLVM clang was not found for stage-one acceptance tests' }

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

$v3Project = Join-Path $root 'compiler/UBE_Compiler_v3'
$v3Manifest = Join-Path $v3Project 'UBE_Compiler_v3.UBE'
$v3StageOneIr = Join-Path $out 'v3-scaffold-stage1.ll'
$v3StageTwoIr = Join-Path $out 'v3-scaffold-stage2.ll'
$v3Scaffold = Join-Path $out 'v3-scaffold.exe'
& $v2StageOne $v3Manifest $v3StageOneIr
if ($LASTEXITCODE -ne 0) { throw 'UBE Compiler v2 stage one failed to compile the v3 scaffold' }
& $v2StageTwo $v3Manifest $v3StageTwoIr
if ($LASTEXITCODE -ne 0) { throw 'UBE Compiler v2 stage two failed to compile the v3 scaffold' }
$v3StageOneIrHash = (Get-FileHash -LiteralPath $v3StageOneIr -Algorithm SHA256).Hash
$v3StageTwoIrHash = (Get-FileHash -LiteralPath $v3StageTwoIr -Algorithm SHA256).Hash
if ($v3StageOneIrHash -ne $v3StageTwoIrHash) {
    throw 'UBE Compiler v2 stages one and two emitted different v3 scaffold LLVM IR'
}
& $clangPath '--target=x86_64-w64-windows-gnu' '-O2' $v3StageOneIr `
    (Join-Path $out 'bootstrap_runtime.o') (Join-Path $out 'bootstrap_unicode_runtime.o') '-o' $v3Scaffold
if ($LASTEXITCODE -ne 0) { throw 'LLVM failed to link the UBE Compiler v3 scaffold' }
$v3ScaffoldOutput = & $v3Scaffold
if ($LASTEXITCODE -ne 2 -or $v3ScaffoldOutput -ne 'UBE Compiler v3 scaffold: implementation has not started') {
    throw 'UBE Compiler v3 scaffold failed'
}
$v3ScaffoldManifest = [ordered]@{
    schema = 'ube-v3-scaffold-manifest-1'
    target = 'x86_64-w64-windows-gnu'
    optimization = '-O2'
    compiler_stage1 = (Get-FileHash -LiteralPath $v2StageOne -Algorithm SHA256).Hash
    compiler_stage2 = (Get-FileHash -LiteralPath $v2StageTwo -Algorithm SHA256).Hash
    project = (Get-FileHash -LiteralPath $v3Manifest -Algorithm SHA256).Hash
    source = (Get-FileHash -LiteralPath (Join-Path $v3Project 'Main.bas') -Algorithm SHA256).Hash
    runtime_source = (Get-FileHash -LiteralPath (Join-Path $root 'runtime/bootstrap_runtime.c') -Algorithm SHA256).Hash
    unicode_runtime_source = (Get-FileHash -LiteralPath (Join-Path $root 'runtime/bootstrap_unicode_runtime.cpp') -Algorithm SHA256).Hash
    runtime_object = (Get-FileHash -LiteralPath (Join-Path $out 'bootstrap_runtime.o') -Algorithm SHA256).Hash
    unicode_runtime_object = (Get-FileHash -LiteralPath (Join-Path $out 'bootstrap_unicode_runtime.o') -Algorithm SHA256).Hash
    llvm_ir = $v3StageOneIrHash
    executable = (Get-FileHash -LiteralPath $v3Scaffold -Algorithm SHA256).Hash
    clang = ((& $clangPath '--version' | Select-Object -First 1).ToString())
}
$v3ScaffoldManifest | ConvertTo-Json -Depth 3 | `
    Set-Content -LiteralPath (Join-Path $out 'v3-scaffold-manifest.json') -Encoding UTF8

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
