param([Parameter(Mandatory=$true)][string] $Observer)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$observerPath = (Resolve-Path -LiteralPath $Observer).Path
$cases = @(
    @{ file='remainder-integer-min/App.bas'; type=3 },
    @{ file='remainder-minimum/App.bas'; type=4 },
    @{ file='remainder-longlong-min/App.bas'; type=5 }
)
function Matches-Graph($actual, [string] $text, [int] $type) {
    $expression = 'minimum Mod negativeOne'
    $start = $text.IndexOf($expression, [StringComparison]::Ordinal)
    if ($start -lt 0) { return $false }
    $matches = @(for ($i = 0; $i -lt $actual.values.Count; $i++) {
        $node = $actual.values[$i]; $syntax = $actual.syntax[$node[1]]
        if ($node[2] -eq 5 -and $node[3] -eq $type -and $node[10] -eq 11 -and
            $syntax[1] -eq $start -and $syntax[2] -eq $start + $expression.Length) { $i }
    })
    if ($matches.Count -ne 1) { return $false }
    $node = $actual.values[$matches[0]]
    if ($node[8] -ne 2) { return $false }
    $first = [int]$node[6]
    if ($first -lt 0 -or $first -ge $actual.values.Count) { return $false }
    $second = [int]$actual.values[$first][7]
    if ($second -lt 0 -or $second -ge $actual.values.Count) { return $false }
    $expected = @(@('minimum', $start, 2), @('negativeOne', ($start + 12), 3))
    $ids = @($first, $second)
    for ($i = 0; $i -lt 2; $i++) {
        $child = $actual.values[$ids[$i]]; $syntax = $actual.syntax[$child[1]]
        if ($child[2] -ne 3 -or $child[3] -ne $type -or $child[5] -ne $expected[$i][2] -or
            $syntax[1] -ne $expected[$i][1] -or $syntax[2] -ne $expected[$i][1] + $expected[$i][0].Length) { return $false }
    }
    return $actual.values[$second][7] -eq -1
}
foreach ($case in $cases) {
    $source = Join-Path $PSScriptRoot $case.file
    $text = [IO.File]::ReadAllText($source)
    if ([Text.Encoding]::UTF8.GetByteCount($text) -ne $text.Length) { throw 'Fixture must remain ASCII' }
    $output = @(& $observerPath $source 2>&1)
    if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw "Observer failed: $($case.file)" }
    $actual = $output[0] | ConvertFrom-Json
    if (-not $actual.setup -or -not $actual.ok -or -not (Matches-Graph $actual $text $case.type)) { throw "Wrong graph: $($case.file)" }
    $mutated = $actual | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $start = $text.IndexOf('minimum Mod negativeOne', [StringComparison]::Ordinal)
    $node = @($mutated.values | Where-Object { $_[2] -eq 5 -and $mutated.syntax[$_[1]][1] -eq $start })[0]
    $node[10] = 8
    if (Matches-Graph $mutated $text $case.type) { throw 'Wrong operator accepted' }
    $node[10] = 11; $node[3] = 1
    if (Matches-Graph $mutated $text $case.type) { throw 'Wrong type accepted' }
}
Write-Output 'Passed three remainder graph checks with wrong-operator and wrong-type controls.'
