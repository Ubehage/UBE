param([Parameter(Mandatory=$true)][string] $Clang, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$clang = (Resolve-Path -LiteralPath $Clang).Path
$root = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($root) | Out-Null
$observer = Join-Path $PSScriptRoot 'initializer-error-observer.c'
$runtime = 'bootstrap/runtime/bootstrap_runtime.c'
foreach ($opt in @('0', '2')) {
    $objects = @()
    foreach ($name in @('app', 'library')) {
        $source = Join-Path $PSScriptRoot "initializer-error-$name.ll"
        $object = Join-Path $root "$name-$opt.o"
        & $clang --target=x86_64-w64-windows-gnu "-O$opt" -Wno-override-module -Xclang -llvm-verify-each -c $source -o $object
        if ($LASTEXITCODE -ne 0) { throw 'LLVM compile failed' }
        $objects += $object
    }
    foreach ($wrong in @($false, $true)) {
        $exe = Join-Path $root "init-$opt-$wrong.exe"
        $definition = if ($wrong) { '-DWRONG_EXPECTATION' } else { '-DRIGHT_EXPECTATION' }
        & $clang --target=x86_64-w64-windows-gnu -std=c17 -O2 -ffunction-sections -fdata-sections -Wall -Wextra -Werror $definition $observer $runtime $objects[0] $objects[1] '-Wl,--gc-sections' -o $exe
        if ($LASTEXITCODE -ne 0) { throw 'Probe link failed' }
        & $exe
        $expected = if ($wrong) { 1 } else { 0 }
        if ($LASTEXITCODE -ne $expected) { throw "Unexpected normal result at O$opt wrong=$wrong" }
        if (-not $wrong) { & $exe root-first; if ($LASTEXITCODE -ne 0) { throw "Root-first control failed at O$opt" } }
    }
}
Write-Output "Initializer error and root-first controls passed at O0/O2: $root"
