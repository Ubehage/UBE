[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$out = Join-Path $root 'bootstrap\out\v4-task1'
$support = Join-Path $root 'compiler\UBE_Compiler_v4\support'
$compiler = Join-Path $root 'bootstrap\out\ube-v3-production-stage1.exe'
$clang = 'C:\Program Files\LLVM\bin\clang.exe'
$runtime = Join-Path $root 'bootstrap\out\bootstrap_runtime.o'
$unicodeRuntime = Join-Path $root 'bootstrap\out\bootstrap_unicode_runtime.o'
$target = 'x86_64-w64-windows-gnu'

foreach ($required in @($compiler, $clang, $runtime, $unicodeRuntime)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Task 1 prerequisite is missing: $required"
    }
}
[IO.Directory]::CreateDirectory($out) | Out-Null

function Build-Native([string]$ProjectName, [string]$OutputName) {
    $project = Join-Path $support $ProjectName
    $executable = Join-Path $out $OutputName
    $llvm = "$executable.ll"
    & $compiler '--build-native' $project $target $clang $runtime $unicodeRuntime $executable $llvm
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $executable -PathType Leaf)) {
        throw "v3 failed to build Task 1 fixture $ProjectName"
    }
    return $executable
}

$libraryLlvm = Join-Path $out 'UBECompilerSupport.ll'
$libraryRepeatLlvm = Join-Path $out 'UBECompilerSupport-repeat.ll'
& $compiler '--emit-llvm' (Join-Path $support 'UBECompilerSupport.UBE') $target $libraryLlvm
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $libraryLlvm -PathType Leaf)) {
    throw 'v3 failed to compile the independent UBECompilerSupport project'
}
& $compiler '--emit-llvm' (Join-Path $support 'UBECompilerSupport.UBE') $target $libraryRepeatLlvm
if ($LASTEXITCODE -ne 0 -or (Get-FileHash $libraryLlvm -Algorithm SHA256).Hash -cne (Get-FileHash $libraryRepeatLlvm -Algorithm SHA256).Hash) {
    throw 'UBECompilerSupport output was not deterministic across repeated builds'
}
$coreLlvm = Join-Path $out 'UBECore.ll'
& $compiler '--emit-llvm' (Join-Path $root 'source-library\UBECore.UBE') $target $coreLlvm
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $coreLlvm -PathType Leaf)) {
    throw 'v3 failed to compile the independent preserved UBECore project'
}

$api = Build-Native 'SupportApiTest.UBE' 'support-api-test.exe'
$apiOutput = (& $api) -join "`n"
$expectedApi = "1`nUBE`n0`n1`nsrc/main.bas`n0`n1`nUBEphase=shell`n`n0`n66`n-1`n1`nomp`n0`nA`n`n5`n1203`n`n1`n0`n97"
if ($LASTEXITCODE -ne 0 -or $apiOutput -cne $expectedApi) {
    throw "support API fixture failed:`n$apiOutput"
}

$thread = Build-Native 'ThreadSafetyTest.UBE' 'thread-safety-test.exe'
$threadOutput = (& $thread) -join "`n"
if ($LASTEXITCODE -ne 0 -or $threadOutput -cne "1`nsrc/one.bas`n1`nsrc/two.bas") {
    throw "support thread-safety fixture failed:`n$threadOutput"
}

$io = Build-Native 'IoProcessTest.UBE' 'io-process-test.exe'
$input = Join-Path $out 'required-input.txt'
$published = Join-Path $out 'published-output.txt'
[IO.File]::WriteAllText($input, 'task1-input', [Text.UTF8Encoding]::new($false))
$ioOutput = (& $io $input $published "$env:SystemRoot\System32\where.exe") -join "`n"
if ($LASTEXITCODE -ne 0 -or ($ioOutput -split "`n")[-1] -cne 'io-process-cleanup-passed') {
    throw "support I/O/process fixture failed:`n$ioOutput"
}
if (Test-Path -LiteralPath $published) {
    throw 'support I/O/process fixture left a published artifact after cleanup'
}

$hashes = [ordered]@{}
foreach ($path in @($libraryLlvm, $coreLlvm, $api, $thread, $io)) {
    $hashes[[IO.Path]::GetFileName($path)] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
$record = [ordered]@{
    format = 'UBE-v4-task1-evidence-1'
    status = 'passed'
    packages = @('UBECompilerSupport@0.2.0-v4t4', 'UBECore@0.1.0-rp8')
    compiler_support_intrinsic_count = 15
    ubecore_intrinsic_count = 54
    target = $target
    hashes = $hashes
}
$recordPath = Join-Path $out 'task1-evidence.json'
[IO.File]::WriteAllText($recordPath, ($record | ConvertTo-Json -Depth 4) + "`n", [Text.UTF8Encoding]::new($false))
Write-Host "Task 1 support gate passed: $recordPath"
