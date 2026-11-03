param([Parameter(Mandatory=$true)][string] $Clang, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$clangPath = (Resolve-Path -LiteralPath $Clang).Path
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$driver = Join-Path $PSScriptRoot 'narrowing-reference.c'
foreach ($optimization in @('0','2')) {
    foreach ($mode in @('correct','WRONG_ERROR','WRONG_VALUE','WRONG_PRESERVATION')) {
        $exe = Join-Path $directory "narrow-$optimization-$mode.exe"
        $definitions = @(if ($mode -ne 'correct') { "-D$mode" })
        & $clangPath --target=x86_64-w64-windows-gnu -std=c17 "-O$optimization" -ffunction-sections -fdata-sections -Wall -Wextra -Werror @definitions $driver bootstrap/runtime/bootstrap_runtime.c '-Wl,--gc-sections' -o $exe
        if ($LASTEXITCODE -ne 0) { throw "Compilation failed for $optimization $mode" }
        & $exe
        $expected = if ($mode -eq 'correct') { 0 } else { 1 }
        if ($LASTEXITCODE -ne $expected) { throw "Unexpected exit $LASTEXITCODE for $optimization $mode" }
    }
}
Write-Output "Narrowing reference and three negative controls passed at O0 and O2: $directory"
