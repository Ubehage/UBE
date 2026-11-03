param([Parameter(Mandatory=$true)][string] $Clang, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$clang = (Resolve-Path -LiteralPath $Clang).Path
$root = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($root) | Out-Null
$bridge = Join-Path $PSScriptRoot 'runtime-error-bridge.ll'
$driver = Join-Path $PSScriptRoot 'runtime-error-i16-exhaustive.c'
$runtime = 'bootstrap/runtime/bootstrap_runtime.c'
foreach ($opt in @('0', '2')) {
    $object = Join-Path $root "bridge-$opt.o"
    & $clang --target=x86_64-w64-windows-gnu "-O$opt" -Wno-override-module -Xclang -llvm-verify-each -c $bridge -o $object
    if ($LASTEXITCODE -ne 0) { throw 'LLVM bridge compile failed' }
    foreach ($wrong in @($false, $true)) {
        $exe = Join-Path $root "probe-$opt-$wrong.exe"
        $definition = if ($wrong) { '-DWRONG_EXPECTATION' } else { '-DRIGHT_EXPECTATION' }
        & $clang --target=x86_64-w64-windows-gnu -std=c17 -O2 -ffunction-sections -fdata-sections -Wall -Wextra -Werror $definition $driver $runtime $object '-Wl,--gc-sections' -o $exe
        if ($LASTEXITCODE -ne 0) { throw 'Probe link failed' }
        & $exe
        $expected = if ($wrong) { 1 } else { 0 }
        if ($LASTEXITCODE -ne $expected) { throw "Unexpected exit for O$opt wrong=$wrong : $LASTEXITCODE" }
    }
}
Write-Output "i16 exhaustive-dividend probe and wrong-expectation controls passed at O0/O2: $root"
