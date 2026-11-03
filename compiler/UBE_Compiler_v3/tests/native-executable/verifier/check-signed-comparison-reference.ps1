param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'signed-comparison-reference.c'
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
foreach ($optimization in @('0', '2')) {
    foreach ($mutated in @($false, $true)) {
        $output = Join-Path $OutputDirectory ("signed-comparison-$optimization-$mutated.exe")
        $compilerArgs = @('--target=x86_64-w64-windows-gnu', '-std=c17', "-O$optimization", '-Wall', '-Wextra', '-Werror', '-Wno-tautological-compare')
        if ($mutated) { $compilerArgs += '-DUNSIGNED_ORDER_CONTROL' }
        & $Clang @compilerArgs $source '-o' $output
        if ($LASTEXITCODE -ne 0) { throw 'Reference compilation failed' }
        $observed = @(& (Resolve-Path -LiteralPath $output).Path)
        $status = $LASTEXITCODE
        if ($mutated) { $expectedStatus = 1; $expectedOutput = '12' }
        else { $expectedStatus = 0; $expectedOutput = '24' }
        if ($status -ne $expectedStatus -or $observed.Count -ne 1 -or $observed[0] -ne $expectedOutput) {
            throw "Unexpected reference result: optimization=$optimization mutated=$mutated exit=$status output=$observed"
        }
    }
}
Write-Output 'Passed two signed comparison references and two unsigned-order controls.'
