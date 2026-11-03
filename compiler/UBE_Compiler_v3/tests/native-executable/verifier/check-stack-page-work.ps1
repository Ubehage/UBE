param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'stack-page-work.c'
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
foreach ($optimization in @('0','2')) {
    $exe = Join-Path $OutputDirectory "page-work-$optimization.exe"
    & $Clang --target=x86_64-w64-windows-gnu -std=c17 "-O$optimization" -Wall -Wextra -Werror $source -o $exe
    if ($LASTEXITCODE -ne 0) { throw 'Page-work probe compilation failed' }
    $output = @(& (Resolve-Path -LiteralPath $exe).Path); $status = $LASTEXITCODE
    if ($status -ne 0 -or $output.Count -ne 1 -or $output[0] -ne 'page queries=136,528; region queries=16,32; fragmented page=31 region=256') { throw "Page-work comparison failed: $status $output" }
    if ($output[0] -eq 'page queries=136,272; region queries=16,32; fragmented page=31 region=256') { throw 'Wrong-work comparison control unexpectedly passed' }
    Write-Output "O$optimization : $($output[0]); wrong-work expectation rejected."
}
