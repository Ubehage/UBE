param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'stack-error-live.c'
$runtime = 'bootstrap/runtime/bootstrap_runtime.c'
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
foreach ($optimization in @('0','2')) {
    $exe = Join-Path $OutputDirectory "stack-query-failure-$optimization.exe"
    & $Clang --target=x86_64-w64-windows-gnu -std=c17 "-O$optimization" -ffunction-sections -fdata-sections -Wall -Wextra -Werror -DFAILED_STACK_QUERY_CONTROL $source $runtime '-Wl,--gc-sections' -o $exe
    if ($LASTEXITCODE -ne 0) { throw 'Query-failure probe compilation failed' }
    $output = @(& (Resolve-Path -LiteralPath $exe).Path); $status = $LASTEXITCODE
    if ($status -ne 0 -or $output.Count -ne 1 -or $output[0] -ne 'unreliable stack query did not report a recoverable refusal') {
        throw "Query-failure probe failed: O$optimization status=$status $output"
    }
    Write-Output "O$optimization : $($output[0])"
}
