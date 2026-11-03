param([Parameter(Mandatory=$true)][string] $Clang, [Parameter(Mandatory=$true)][string] $Objdump, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$clang = (Resolve-Path -LiteralPath $Clang).Path
$objdump = (Resolve-Path -LiteralPath $Objdump).Path
$root = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($root) | Out-Null
$bridge = Join-Path $PSScriptRoot 'runtime-error-debug-bridge.c'
$driver = Join-Path $PSScriptRoot 'runtime-error-observer.c'
$runtime = 'bootstrap/runtime/bootstrap_runtime.c'
function Has-Lines([string] $Info, [int[]] $Expected) {
    foreach ($line in $Expected) {
        if ($Info -notmatch ("(?m)^runtime-error-debug-bridge\.c\s+" + $line + '\s+0x[0-9a-f]+')) { return $false }
    }
    return $true
}
function Has-MappedLines([string] $Lines, [string] $Disassembly, [hashtable] $Expected) {
    $symbols = [regex]::Matches($Disassembly, '(?m)^([0-9a-f]+) <([^>]+)>:\s*$')
    foreach ($name in $Expected.Keys) {
        $index = -1
        for ($i = 0; $i -lt $symbols.Count; $i++) { if ($symbols[$i].Groups[2].Value -ceq $name) { $index = $i; break } }
        if ($index -lt 0 -or $index + 1 -ge $symbols.Count) { return $false }
        $start = [Convert]::ToInt64($symbols[$index].Groups[1].Value, 16)
        $end = [Convert]::ToInt64($symbols[$index + 1].Groups[1].Value, 16)
        if ($end -le $start) { return $false }
        $pattern = '(?m)^runtime-error-debug-bridge\.c\s+' + $Expected[$name] + '\s+0x([0-9a-f]+)'
        $found = $false
        foreach ($row in [regex]::Matches($Lines, $pattern)) {
            $address = [Convert]::ToInt64($row.Groups[1].Value, 16)
            if ($address -ge $start -and $address -lt $end) { $found = $true; break }
        }
        if (-not $found) { return $false }
    }
    return $true
}
foreach ($mode in @('debug', 'plain', 'bad-debug')) {
    $debug = $mode -ne 'plain'
    $bad = $mode -eq 'bad-debug'
    $ir = Join-Path $root "bridge-$mode.ll"
    $flag = if ($debug) { '-g' } else { '-g0' }
    $definition = if ($bad) { '-DMUTATE_SPECIAL' } else { '-DKEEP_SPECIAL' }
    & $clang --target=x86_64-w64-windows-gnu -O2 -gdwarf-4 $flag $definition -S -emit-llvm $bridge -o $ir
    if ($LASTEXITCODE -ne 0) { throw "LLVM emission failed: $mode" }
    $raw = [IO.File]::ReadAllText($ir)
    if ($debug -and ($raw -notmatch '!llvm\.dbg\.cu' -or $raw -notmatch '!DILocation\(' -or $raw -notmatch 'emissionKind: FullDebug')) { throw "Expected debug metadata missing: $mode" }
    if (-not $debug -and ($raw -match '!DILocation\(' -or $raw -notmatch 'emissionKind: NoDebug')) { throw 'No-debug LLVM control has unexpected location metadata' }
    $object = Join-Path $root "bridge-$mode.o"
    & $clang --target=x86_64-w64-windows-gnu -O2 -Wno-override-module -Xclang -llvm-verify-each -c $ir -o $object
    if ($LASTEXITCODE -ne 0) { throw "LLVM verification/compile failed: $mode" }
    $exe = Join-Path $root "bridge-$mode.exe"
    & $clang --target=x86_64-w64-windows-gnu -std=c17 -O2 -g0 -ffunction-sections -fdata-sections -Wall -Wextra -Werror -DUBE_LLVM_REMAINDER $driver $runtime $object '-Wl,--gc-sections' -o $exe
    if ($LASTEXITCODE -ne 0) { throw "Link failed: $mode" }
    $lines = @(& $objdump --dwarf=decodedline $exe 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "Debug reader failed: $mode" }
    if ($debug -and (-not (Has-Lines $lines @(17,18,19)) -or (Has-Lines $lines @(17,999,19)))) { throw "Linked debug-line comparison failed: $mode" }
    if (-not $debug -and (Has-Lines $lines @(17))) { throw 'No-debug linked line control accepted' }
    if ($debug) {
        $disassembly = @(& $objdump -d $exe 2>&1) -join "`n"
        if ($LASTEXITCODE -ne 0) { throw "Linked disassembly failed: $mode" }
        $expectedLines = @{ probe_remainder_i16 = 17; probe_remainder_i32 = 18; probe_remainder_i64 = 19 }
        if (-not (Has-MappedLines $lines $disassembly $expectedLines)) { throw "Function/line mapping failed: $mode" }
        $wrongLines = @{ probe_remainder_i16 = 18; probe_remainder_i32 = 17; probe_remainder_i64 = 19 }
        if (Has-MappedLines $lines $disassembly $wrongLines) { throw 'Wrong function/line mapping accepted' }
    }
    foreach ($order in @('forward', 'reverse', 'overlap')) {
        if ($order -eq 'forward') { & $exe } else { & $exe $order }
        $expected = if ($bad) { 1 } else { 0 }
        if ($LASTEXITCODE -ne $expected) { throw "Unexpected result: $mode $order $LASTEXITCODE" }
    }
}
Write-Output "Optimized debug/plain bridge, linked lines and mutated-debug controls passed: $root"
