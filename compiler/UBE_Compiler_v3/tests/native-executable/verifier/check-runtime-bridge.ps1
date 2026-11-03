param([Parameter(Mandatory=$true)][string] $Clang, [Parameter(Mandatory=$true)][string] $OutputDirectory, [string] $Objdump)
$ErrorActionPreference = 'Stop'
$clang = (Resolve-Path -LiteralPath $Clang).Path
$root = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($root) | Out-Null
$source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'runtime-error-bridge.ll'))
$badFiles = @{}
foreach ($width in @('16', '32', '64')) {
    $pattern = "(?ms)^define i$width @probe_remainder_i$width\b.*?^special:\r?$"
    $matches = [regex]::Matches($source, $pattern)
    if ($matches.Count -ne 1) { throw "Could not locate unique i$width special branch" }
    $bad = [regex]::Replace($source, $pattern, [Text.RegularExpressions.MatchEvaluator]{ param($m) $m.Value + "`n  call void @ube_err_set(i32 11, ptr null, ptr null)" })
    if ($bad -ceq $source) { throw "i$width wrong-error mutation did not apply" }
    $badFiles["special$width"] = Join-Path $root "bad-special-$width.ll"
    [IO.File]::WriteAllText($badFiles["special$width"], $bad)
    $failurePattern = "(?ms)^define i$width @probe_remainder_i$width\b.*?^failure:\r?`n  call void @ube_err_set\(i32 11, ptr null, ptr null\)"
    if ([regex]::Matches($source, $failurePattern).Count -ne 1) { throw "Could not locate unique i$width failure branch" }
    $badFailure = [regex]::Replace($source, $failurePattern, [Text.RegularExpressions.MatchEvaluator]{ param($m) $m.Value.Replace('i32 11', 'i32 12') })
    if ($badFailure -ceq $source) { throw "i$width wrong-number mutation did not apply" }
    $badFiles["zero$width"] = Join-Path $root "bad-zero-$width.ll"
    [IO.File]::WriteAllText($badFiles["zero$width"], $badFailure)
    $signedOperation = "srem i$width %left, %right"
    $badSign = $source.Replace($signedOperation, "urem i$width %left, %right")
    if ($badSign -ceq $source) { throw "i$width signedness mutation did not apply" }
    $badFiles["sign$width"] = Join-Path $root "bad-sign-$width.ll"
    [IO.File]::WriteAllText($badFiles["sign$width"], $badSign)
}
$driver = Join-Path $PSScriptRoot 'runtime-error-observer.c'
$runtime = 'bootstrap/runtime/bootstrap_runtime.c'
foreach ($opt in @('0', '2')) {
    foreach ($variant in @('good', 'special16', 'special32', 'special64', 'zero16', 'zero32', 'zero64', 'sign16', 'sign32', 'sign64')) {
        $inputFile = if ($variant -eq 'good') { Join-Path $PSScriptRoot 'runtime-error-bridge.ll' } else { $badFiles[$variant] }
        $object = Join-Path $root "bridge-$opt-$variant.o"
        & $clang --target=x86_64-w64-windows-gnu "-O$opt" -Wno-override-module -Xclang -llvm-verify-each -c $inputFile -o $object
        if ($LASTEXITCODE -ne 0) { throw 'LLVM bridge compile failed' }
        $exe = Join-Path $root "bridge-$opt-$variant.exe"
        & $clang --target=x86_64-w64-windows-gnu -std=c17 -O2 -ffunction-sections -fdata-sections -Wall -Wextra -Werror -DUBE_LLVM_REMAINDER $driver $runtime $object '-Wl,--gc-sections' -o $exe
        if ($LASTEXITCODE -ne 0) { throw 'Bridge link failed' }
        $expected = if ($variant -eq 'good') { 0 } else { 1 }
        foreach ($order in @('forward', 'reverse', 'overlap')) {
            if ($order -eq 'forward') { & $exe } else { & $exe $order }
            if ($LASTEXITCODE -ne $expected) { throw "Unexpected exit for O$opt variant=$variant order=$order : $LASTEXITCODE" }
        }
    }
}
if ($Objdump) {
    $objdumpPath = (Resolve-Path -LiteralPath $Objdump).Path
    $bridgeObject = Join-Path $root 'bridge-2-good.o'
    $debugOutputs = @{}
    foreach ($mode in @('debug', 'plain')) {
        $exe = Join-Path $root "runtime-$mode.exe"
        $debugFlag = if ($mode -eq 'debug') { '-g' } else { '-g0' }
        & $clang --target=x86_64-w64-windows-gnu -std=c17 -O2 -gdwarf-4 $debugFlag -ffunction-sections -fdata-sections -Wall -Wextra -Werror -DUBE_LLVM_REMAINDER $driver $runtime $bridgeObject '-Wl,--gc-sections' -o $exe
        if ($LASTEXITCODE -ne 0) { throw "Debug comparison build failed: $mode" }
        foreach ($order in @('forward', 'reverse', 'overlap')) {
            if ($order -eq 'forward') { & $exe } else { & $exe $order }
            if ($LASTEXITCODE -ne 0) { throw "Debug comparison failed: $mode $order" }
        }
        $info = @(& $objdump --dwarf=info $exe 2>&1) -join "`n"
        if ($LASTEXITCODE -ne 0) { throw "Debug info inspection failed: $mode" }
        $debugOutputs[$mode] = $info -match 'DW_AT_name\s*:.*runtime-error-observer\.c'
    }
    if (-not $debugOutputs['debug'] -or $debugOutputs['plain']) { throw 'Debug metadata control did not distinguish the fixture' }
    Write-Output 'Optimized debug and no-debug runtime observer passed all three orders; fixture metadata distinguished.'
}
Write-Output "LLVM bridges and nine mutation controls passed at O0/O2 in both thread orders and overlap: $root"
