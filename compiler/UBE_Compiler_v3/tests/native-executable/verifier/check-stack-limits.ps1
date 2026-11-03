param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'stack-limits.c'
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
foreach ($mutated in @($false, $true)) {
    $exe = Join-Path $OutputDirectory ("stack-limits-$mutated.exe")
    $flags = @(if ($mutated) { '-DWRONG_BOUNDS_CONTROL' })
    & $Clang --target=x86_64-w64-windows-gnu -std=c17 -O2 -Wall -Wextra -Werror @flags $source -o $exe
    if ($LASTEXITCODE -ne 0) { throw 'Stack-limits probe compilation failed' }
    $output = @(& (Resolve-Path -LiteralPath $exe).Path)
    $status = $LASTEXITCODE
    if ($mutated) {
        if ($status -ne 1 -or $output.Count -ne 0) { throw 'Wrong-bounds control was not rejected' }
    } elseif ($status -ne 0 -or $output.Count -ne 6 -or $output[0] -ne 'main and worker local addresses lie within their reported bounds' -or $output[1] -notin @('main lower-bound page reserved','main lower-bound page guarded','main lower-bound page committed','main lower-bound page other') -or $output[2] -notmatch '^main regions reserved=\d+ committed=\d+ guarded=\d+ other=\d+$' -or $output[3] -notin @('worker lower bound unchanged','worker lower bound changed') -or $output[4] -notin @('worker lower-bound page reserved','worker lower-bound page guarded','worker lower-bound page committed','worker lower-bound page other') -or $output[5] -notmatch '^worker regions reserved=\d+ committed=\d+ guarded=\d+ other=\d+$') {
        throw "Unexpected stack bounds result: exit=$status output=$output"
    } else {
        Write-Output $output[1]
        Write-Output $output[2]
        Write-Output $output[3]
        Write-Output $output[4]
        Write-Output $output[5]
    }
}
Write-Output 'Main and worker bounds observed; wrong-bounds control rejected.'
