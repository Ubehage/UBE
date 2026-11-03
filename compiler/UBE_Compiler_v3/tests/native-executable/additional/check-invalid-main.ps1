param([Parameter(Mandatory = $true)][string] $Compiler, [switch] $WrongExpected)
$ErrorActionPreference = 'Stop'
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$manifest = Join-Path $PSScriptRoot 'invalid-main/InvalidMain.UBE'
$source = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'invalid-main/App.bas')).Replace('\', '/')
$expected = @(('"' + $source + '"'), 'error UBE1422: executable requires one parameterless Sub Main or Function Main As Long (next lines: line, column, byte)', '3', '17', '63')
if ($WrongExpected) { $expected[3] = '18' }
foreach ($jobs in @(1, 4)) {
    $output = @(& $compilerPath --check $manifest --jobs $jobs 2>&1 | ForEach-Object { "$_" })
    if ($LASTEXITCODE -ne 1 -or ($output -join "`n") -cne ($expected -join "`n")) { throw "Invalid Main diagnostic differs at jobs $jobs" }
}
Write-Output 'Passed invalid Main diagnostic checks at jobs 1 and 4.'
