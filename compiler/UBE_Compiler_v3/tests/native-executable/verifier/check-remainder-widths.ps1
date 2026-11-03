param([Parameter(Mandatory=$true)][string] $Clang, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$clangPath = (Resolve-Path -LiteralPath $Clang).Path
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$original = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'remainder-widths.ll'))
$mutated = $original.Replace('%c = icmp eq i32 %preserved, 73', '%c = icmp eq i32 %preserved, 74')
if ($mutated -ceq $original) { throw 'Negative control did not change the expected value' }
$negative = Join-Path $directory 'wrong-expectation.ll'
[IO.File]::WriteAllText($negative, $mutated)
$mainOffset = $original.IndexOf('define i32 @main()', [StringComparison]::Ordinal)
if ($mainOffset -lt 0) { throw 'LLVM probe entry not found' }
$functions = Join-Path $directory 'remainder-functions.ll'
[IO.File]::WriteAllText($functions, $original.Substring(0, $mainOffset))
$driver = Join-Path $PSScriptRoot 'remainder-widths-driver.c'
foreach ($optimization in @('0', '2')) {
    foreach ($wrong in @($false, $true)) {
        $inputFile = if ($wrong) { $negative } else { Join-Path $PSScriptRoot 'remainder-widths.ll' }
        $exe = Join-Path $directory "remainder-$optimization-$wrong.exe"
        & $clangPath --target=x86_64-w64-windows-gnu "-O$optimization" -Wno-override-module -Xclang -llvm-verify-each $inputFile -o $exe
        if ($LASTEXITCODE -ne 0) { throw 'Compilation failed' }
        & $exe
        $expected = if ($wrong) { 1 } else { 0 }
        if ($LASTEXITCODE -ne $expected) { throw "Unexpected exit for O$optimization wrong=$wrong : $LASTEXITCODE" }
    }
    foreach ($wrong in @($false, $true)) {
        $exe = Join-Path $directory "runtime-$optimization-$wrong.exe"
        $definition = if ($wrong) { '-DWRONG_EXPECTATION' } else { '-DRIGHT_EXPECTATION' }
        & $clangPath --target=x86_64-w64-windows-gnu "-O$optimization" -Wno-override-module -Xclang -llvm-verify-each $definition $functions $driver -o $exe
        if ($LASTEXITCODE -ne 0) { throw 'Runtime driver compilation failed' }
        & $exe
        $expected = if ($wrong) { 7 } else { 0 }
        if ($LASTEXITCODE -ne $expected) { throw "Unexpected runtime exit for O$optimization wrong=$wrong : $LASTEXITCODE" }
    }
}
Write-Output 'Constant and runtime i16/i64 probes passed at O0 and O2; wrong-Err controls failed as expected.'
