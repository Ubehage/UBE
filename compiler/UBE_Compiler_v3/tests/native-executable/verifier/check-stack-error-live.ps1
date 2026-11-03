param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $Readobj,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'stack-error-live.c'
$runtime = 'bootstrap/runtime/bootstrap_runtime.c'
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
foreach ($optimization in @('0','2')) {
  foreach ($debug in @($false,$true)) {
    foreach ($variant in @('good','WRONG_STACK_ERROR_CONTROL','WRONG_STACK_RESULT_CONTROL')) {
        $exe = Join-Path $OutputDirectory ("stack-error-live-$optimization-$debug-$variant.exe")
        $flags = @(if ($variant -ne 'good') { "-D$variant" })
        if ($debug) { $flags += '-g' }
        & $Clang --target=x86_64-w64-windows-gnu -std=c17 "-O$optimization" -ffunction-sections -fdata-sections -Wall -Wextra -Werror @flags $source $runtime '-Wl,--gc-sections' -o $exe
        if ($LASTEXITCODE -ne 0) { throw "Compilation failed: O$optimization $variant" }
        $output = @(& (Resolve-Path -LiteralPath $exe).Path); $status = $LASTEXITCODE
        if ($variant -eq 'good') {
            if ($status -ne 0 -or $output.Count -ne 1 -or $output[0] -ne 'guarded recursion, argument effects and thread-local error passed') { throw "Good run failed: O$optimization status=$status" }
            if ($debug) {
                $sections = (& $Readobj --sections $exe) -join "`n"
                if ($LASTEXITCODE -ne 0 -or $sections -notmatch '(?m)^\s*Name: \.debug_info\s') { throw 'Debug section missing' }
            }
        } elseif ($status -ne 1) { throw "Mutation not detected: O$optimization $variant status=$status" }
    }
  }
}
Write-Output 'Four debug/plain stack-error runs passed; eight wrong-error/result controls rejected.'
