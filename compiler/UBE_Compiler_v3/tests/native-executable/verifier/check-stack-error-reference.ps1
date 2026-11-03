param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'stack-error-reference.c'
$runtime = 'bootstrap/runtime/bootstrap_runtime.c'
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
foreach ($optimization in @('0','2')) {
    foreach ($variant in @('good','BAD_ERROR_CONTROL','BAD_ENTRY_CONTROL','BAD_RESULT_CONTROL','BAD_ARGUMENT_CONTROL')) {
        $exe = Join-Path $OutputDirectory ("stack-error-$optimization-$variant.exe")
        $flags = @(if ($variant -ne 'good') { "-D$variant" })
        & $Clang --target=x86_64-w64-windows-gnu -std=c17 "-O$optimization" -ffunction-sections -fdata-sections -Wall -Wextra -Werror @flags $source $runtime '-Wl,--gc-sections' -o $exe
        if ($LASTEXITCODE -ne 0) { throw "Reference compilation failed: $variant" }
        & (Resolve-Path -LiteralPath $exe).Path
        $expected = if ($variant -eq 'good') { 0 } else { 1 }
        if ($LASTEXITCODE -ne $expected) { throw "Unexpected result: O$optimization $variant exit=$LASTEXITCODE" }
    }
}
Write-Output 'Two stack-error references passed and eight wrong-behavior controls were rejected.'
