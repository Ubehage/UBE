param([Parameter(Mandatory=$true)][string] $Clang, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$clang = (Resolve-Path -LiteralPath $Clang).Path
$root = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($root) | Out-Null
foreach ($opt in @('0', '2')) {
    $objects = @()
    foreach ($name in @('app', 'library')) {
        $source = Join-Path $PSScriptRoot "initializer-order-$name.ll"
        $object = Join-Path $root "$name-$opt.o"
        & $clang --target=x86_64-w64-windows-gnu "-O$opt" -Wno-override-module -Xclang -llvm-verify-each -c $source -o $object
        if ($LASTEXITCODE -ne 0) { throw "LLVM compile failed: $name O$opt" }
        $objects += $object
    }
    $exe = Join-Path $root "initializer-$opt.exe"
    & $clang --target=x86_64-w64-windows-gnu $objects[0] $objects[1] -o $exe
    if ($LASTEXITCODE -ne 0) { throw 'Link failed' }
    & $exe
    if ($LASTEXITCODE -ne 8) { throw "Normal order returned $LASTEXITCODE" }
    & $exe reverse
    if ($LASTEXITCODE -ne 5) { throw "Reversed declaration order returned $LASTEXITCODE" }
    & $exe root first
    if ($LASTEXITCODE -ne 1) { throw "Root-first order returned $LASTEXITCODE" }
}
Write-Output "Separate hand-authored modules produced 8, 5 and 1 at O0/O2: $root"
