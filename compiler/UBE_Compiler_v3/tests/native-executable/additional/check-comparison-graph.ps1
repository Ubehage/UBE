param([Parameter(Mandatory=$true)][string] $Observer)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$source = Join-Path $PSScriptRoot 'comparison-boundaries/App.bas'
$text = [IO.File]::ReadAllText($source)
if ([Text.Encoding]::UTF8.GetByteCount($text) -ne $text.Length) { throw 'Fixture must remain ASCII' }
$output = @(& (Resolve-Path -LiteralPath $Observer).Path $source 2>&1)
if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw 'Observer transport failed' }
$actual = $output[0] | ConvertFrom-Json
if (-not $actual.setup -or -not $actual.ok) { throw 'Semantic observation failed' }
function Find-Comparison($graph) {
    $expression = 'wideBit = wideZero'
    $start = $text.IndexOf($expression, [StringComparison]::Ordinal)
    if ($start -lt 0) { throw 'Missing expression' }
    $matches = @(for ($i = 0; $i -lt $graph.values.Count; $i++) {
        $node = $graph.values[$i]; $span = $graph.syntax[$node[1]]
        if ($node[2] -eq 5 -and $span[1] -eq $start -and $span[2] -eq $start + $expression.Length) { $i }
    })
    if ($matches.Count -ne 1) { throw 'Comparison node is ambiguous' }
    return [int]$matches[0]
}
function Check-Comparison($graph) {
    $node = $graph.values[(Find-Comparison $graph)]
    $leftIndex = [int]$node[6]
    if ($node[3] -ne 1 -or $node[8] -ne 2 -or $node[10] -ne 15 -or $leftIndex -lt 0 -or $leftIndex -ge $graph.values.Count) { return $false }
    $left = $graph.values[$leftIndex]; $rightIndex = [int]$left[7]
    if ($rightIndex -lt 0 -or $rightIndex -ge $graph.values.Count) { return $false }
    $right = $graph.values[$rightIndex]
    $leftSpan = $graph.syntax[$left[1]]; $rightSpan = $graph.syntax[$right[1]]
    $targets = @{}
    foreach ($name in @('wideBit', 'wideZero')) {
        $start = $text.IndexOf($name + ' As ', [StringComparison]::Ordinal)
        $declarations = @($graph.values | Where-Object { $_[2] -eq 103 -and $graph.syntax[$_[1]][1] -eq $start })
        if ($start -lt 0 -or $declarations.Count -ne 1) { return $false }
        $targets[$name] = $declarations[0][5]
    }
    return $left[2] -eq 3 -and $left[3] -eq 5 -and $left[5] -ge 0 -and
        $right[2] -eq 3 -and $right[3] -eq 5 -and $right[5] -ge 0 -and
        $left[5] -eq $targets.wideBit -and $right[5] -eq $targets.wideZero -and
        $left[5] -ne $right[5] -and $right[7] -eq -1 -and
        $text.Substring($leftSpan[1], $leftSpan[2] - $leftSpan[1]) -eq 'wideBit' -and
        $text.Substring($rightSpan[1], $rightSpan[2] - $rightSpan[1]) -eq 'wideZero'
}
if (-not (Check-Comparison $actual)) { throw 'Incorrect LongLong equality graph' }
foreach ($mutation in @('operator', 'type', 'identity', 'swap-identities')) {
    $changed = $actual | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $node = $changed.values[(Find-Comparison $changed)]; $left = $changed.values[$node[6]]; $right = $changed.values[$left[7]]
    if ($mutation -eq 'operator') { $node[10] = 13 }
    if ($mutation -eq 'type') { $right[3] = 4 }
    if ($mutation -eq 'identity') { $right[5] = $left[5] }
    if ($mutation -eq 'swap-identities') { $old = $left[5]; $left[5] = $right[5]; $right[5] = $old }
    if (Check-Comparison $changed) { throw "Accepted $mutation mutation" }
}
function Check-Initializer($graph, [string] $name, [int] $type, [long] $expected) {
    $start = $text.IndexOf($name + ' As ', [StringComparison]::Ordinal)
    $matches = @(for ($i = 0; $i -lt $graph.values.Count; $i++) {
        $node = $graph.values[$i]
        if ($node[2] -eq 103 -and $graph.syntax[$node[1]][1] -eq $start) { $i }
    })
    if ($start -lt 0 -or $matches.Count -ne 1) { return $false }
    $declaration = $graph.values[$matches[0]]; $index = [int]$declaration[6]
    if ($declaration[3] -ne $type -or $index -lt 0 -or $index -ge $graph.values.Count) { return $false }
    $value = $graph.values[$index]
    return $value[2] -eq 1 -and $value[3] -eq $type -and $value[4] -eq $expected
}
$initializers = @(
    @('minimum', 4, [long]::Parse('-2147483648')),
    @('maximum', 4, [long]::Parse('2147483647')),
    @('wideMinimum', 5, [long]::MinValue),
    @('wideMaximum', 5, [long]::MaxValue),
    @('wideBit', 5, [long]::Parse('4294967296'))
)
foreach ($case in $initializers) {
    if (-not (Check-Initializer $actual $case[0] $case[1] $case[2])) { throw "Wrong initializer for $($case[0])" }
    if (Check-Initializer $actual $case[0] 1 $case[2]) { throw 'Wrong-type control accepted' }
    if (Check-Initializer $actual $case[0] $case[1] 0) { throw 'Wrong-value control accepted' }
}
Write-Output 'Passed LongLong equality, five initializer graphs and 14 controls.'
