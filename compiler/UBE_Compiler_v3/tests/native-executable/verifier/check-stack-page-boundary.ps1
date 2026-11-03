param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'stack-page-boundary.c'
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
foreach ($optimization in @('0','2')) {
    foreach ($variant in @('good','page','region')) {
        $exe = Join-Path $OutputDirectory "page-boundary-$optimization-$variant.exe"
        $flags = @(if ($variant -eq 'page') { '-DIGNORE_PAGE_GUARD_CONTROL' } elseif ($variant -eq 'region') { '-DIGNORE_REGION_GUARD_CONTROL' })
        & $Clang --target=x86_64-w64-windows-gnu -std=c17 "-O$optimization" -Wall -Wextra -Werror @flags $source -o $exe
        if ($LASTEXITCODE -ne 0) { throw 'Page-boundary probe compilation failed' }
        $output = @(& (Resolve-Path -LiteralPath $exe).Path); $status = $LASTEXITCODE
        if ($variant -ne 'good') {
            if ($status -ne 1 -or $output.Count -ne 0) { throw 'Guard-page mutation was not rejected' }
        } elseif ($status -ne 0 -or $output.Count -ne 1 -or $output[0] -ne 'guard, no-access, uncommitted, bound and stale-observation controls passed') {
            throw "Page-boundary probe failed: $status $output"
        }
        Write-Output "O$optimization variant=$variant status=$status"
    }
}
