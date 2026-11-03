param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'stack-guard-probe.c'
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
foreach ($optimization in @('0','2')) {
  foreach ($frameBytes in @(8192, 16384, 32768)) {
    foreach ($refuse in @($false,$true)) {
        $exe = Join-Path $OutputDirectory ("stack-guard-$optimization-$frameBytes-$refuse.exe")
        $flags = @("-DTEST_FRAME_BYTES=$frameBytes")
        if ($refuse) { $flags += '-DALWAYS_REFUSE_CONTROL' }
        & $Clang --target=x86_64-w64-windows-gnu -std=c17 "-O$optimization" -Wall -Wextra -Werror @flags $source -o $exe
        if ($LASTEXITCODE -ne 0) { throw 'Stack guard probe compilation failed' }
        $output = @(& (Resolve-Path -LiteralPath $exe).Path)
        if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw 'Stack guard probe failed' }
        if ($refuse -and $output[0] -ne 'always-refuse control rejected before recursion') { throw 'Unexpected refusal control' }
        if (-not $refuse -and $output[0] -notmatch '^guard refused after ([2-9]|[1-5][0-9]|6[0-3]) frames; all unwound; larger frame unsafe$') { throw 'Guard did not reach and unwind bounded recursion or expose the large-frame counterexample' }
        Write-Output "O$optimization frame=$frameBytes : $($output[0])"
    }
  }
  foreach ($refuse in @($false,$true)) {
    $mixed = Join-Path $PSScriptRoot 'stack-guard-mixed.c'
    $exe = Join-Path $OutputDirectory ("stack-guard-mixed-$optimization-$refuse.exe")
    $flags = @(if ($refuse) { '-DALWAYS_REFUSE_CONTROL' })
    & $Clang --target=x86_64-w64-windows-gnu -std=c17 "-O$optimization" -Wall -Wextra -Werror @flags $mixed -o $exe
    if ($LASTEXITCODE -ne 0) { throw 'Mixed stack guard probe compilation failed' }
    $output = @(& (Resolve-Path -LiteralPath $exe).Path)
    if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw 'Mixed stack guard probe failed' }
    if ($refuse -and $output[0] -ne 'mixed always-refuse control rejected before recursion') { throw 'Unexpected mixed refusal control' }
    if (-not $refuse -and $output[0] -notmatch '^mixed guard refused after [1-9][0-9]* small and [1-9][0-9]* large frames; all unwound$') { throw 'Mixed guard did not unwind' }
    Write-Output "O$optimization : $($output[0])"
  }
}
