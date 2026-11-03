param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'stack-guard-aware.c'
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
foreach ($optimization in @('0','2')) {
    foreach ($commitThread in @($false,$true)) {
        foreach ($mutated in @($false,$true)) {
            $exe = Join-Path $OutputDirectory "committed-walk-$optimization-$commitThread-$mutated.exe"
            $flags = @('-DCOMMITTED_STACK_CONTROL','-DCOMMITTED_PAGE_WALK')
            if ($commitThread) { $flags += '-DTHREAD_COMMIT_CONTROL' }
            if ($mutated) { $flags += '-DIGNORE_FRAME_CONTROL' }
            & $Clang --target=x86_64-w64-windows-gnu -std=c17 "-O$optimization" -fstack-usage -Wall -Wextra -Werror @flags $source -Xlinker --stack -Xlinker 262144,262144 -o $exe
            if ($LASTEXITCODE -ne 0) { throw 'Committed-page probe compilation failed' }
            $output = @(& (Resolve-Path -LiteralPath $exe).Path); $status = $LASTEXITCODE
            if ($mutated) {
                if ($status -ne 1 -or $output.Count -ne 0) { throw 'Missing-frame arithmetic control was not rejected' }
                Write-Output "O$optimization commit=$commitThread : missing-frame control rejected"
            } else {
                if ($status -ne 0 -or $output.Count -ne 2 -or $output[0] -notmatch '^committed pages walked=(\d+)$' -or [int]$Matches[1] -lt 2 -or
                    $output[1] -notmatch '^frame-aware test refused a larger frame and unwound (\d+) smaller frames$' -or [int]$Matches[1] -lt 2) {
                    throw "Committed-page probe failed: $status $output"
                }
                Write-Output "O$optimization commit=$commitThread : $($output -join '; ')"
            }
        }
    }
}
