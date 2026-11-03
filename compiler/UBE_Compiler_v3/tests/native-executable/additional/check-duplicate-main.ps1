param([Parameter(Mandatory = $true)][string] $Compiler, [switch] $WrongExpected)
$ErrorActionPreference = 'Stop'
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$manifest = Join-Path $PSScriptRoot 'duplicate-main/DuplicateMain.UBE'
$other = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'duplicate-main/Other.bas')).Replace('\', '/')
$expected = @(('"' + $other + '"'), 'error UBE1422: executable requires one parameterless Sub Main or Function Main As Long (next lines: line, column, byte)', '3', '12', '60')
if ($WrongExpected) { $expected[2] = '4' }
foreach ($jobs in @(1, 4)) {
    $output = @(& $compilerPath --check $manifest --jobs $jobs 2>&1 | ForEach-Object { "$_" })
    if ($LASTEXITCODE -ne 1 -or ($output -join "`n") -cne ($expected -join "`n")) { throw "Duplicate Main diagnostic differs at jobs $jobs" }
}
Write-Output 'Passed duplicate Main diagnostic checks at jobs 1 and 4.'
