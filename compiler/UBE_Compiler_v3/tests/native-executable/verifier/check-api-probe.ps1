param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $Library)
$ErrorActionPreference = 'Stop'
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$libraryPath = (Resolve-Path -LiteralPath $Library).Path
$cases = @(
    @('valid.ll', 0, 'valid module'),
    @('invalid-dominance.ll', 1, 'invalid module'),
    @('invalid-syntax.ll', 2, 'parse failure'),
    @('nonexistent.ll', 3, 'input failure')
)
function Matches-Expected($status, $output, $case) {
    return $status -eq $case[1] -and $output.Count -eq 1 -and $output[0] -eq $case[2]
}
foreach ($case in $cases) {
    $output = @(& $probePath $libraryPath (Join-Path $PSScriptRoot $case[0]) 2>&1)
    $status = $LASTEXITCODE
    if (-not (Matches-Expected $status $output $case)) {
        throw "Wrong disposition for $($case[0]): exit $LASTEXITCODE, output $output"
    }
    $wrongStatus = @($case[0], ($case[1] + 10), $case[2])
    $wrongOutput = @($case[0], $case[1], 'wrong disposition')
    if ((Matches-Expected $status $output $wrongStatus) -or (Matches-Expected $status $output $wrongOutput)) {
        throw "Negative comparator control accepted for $($case[0])"
    }
}
Write-Output 'Passed four API verifier disposition checks and eight comparator controls.'
