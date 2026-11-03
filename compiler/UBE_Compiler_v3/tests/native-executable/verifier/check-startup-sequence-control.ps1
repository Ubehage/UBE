param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'startup-sequence-control.c'
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
foreach ($optimization in @('0','2')) {
    foreach ($reverse in @($false,$true)) {
        $exe = Join-Path $OutputDirectory "startup-sequence-$optimization-$reverse.exe"
        $flags = @(if ($reverse) { '-DREVERSE_INITIALIZERS_CONTROL' })
        & $Clang --target=x86_64-w64-windows-gnu -std=c17 "-O$optimization" -Wall -Wextra -Werror @flags $source -o $exe
        if ($LASTEXITCODE -ne 0) { throw 'Startup observer control compilation failed' }
        $output = @(& (Resolve-Path -LiteralPath $exe).Path); $status = $LASTEXITCODE
        $expectedActual = if ($reverse) { 'EL' } else { 'LE' }
        if ($status -ne 0 -or $output.Count -ne 1 -or $output[0] -ne $expectedActual) { throw "Unexpected event sequence: $status $output" }
        $accepted = $output[0] -ceq 'LE'
        if ($accepted -eq $reverse) { throw 'Sequence comparison failed its control' }
        Write-Output "O$optimization reverse=$reverse sequence=$($output[0]) accepted=$accepted"
    }
}
foreach ($wrong in @('L','E','LEE','LL')) {
    if ($wrong -ceq 'LE') { throw 'Missing, extra or repeated-event control unexpectedly passed' }
}
Write-Output 'Missing, extra and repeated-event comparisons rejected.'
