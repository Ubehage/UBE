param([Parameter(Mandatory = $true)][string] $Observer)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$source = Join-Path $PSScriptRoot 'multiply-overflow/App.bas'
$text = [IO.File]::ReadAllText($source)
if ([Text.Encoding]::UTF8.GetByteCount($text) -ne $text.Length) { throw 'Fixture must remain ASCII' }
$output = @(& (Resolve-Path -LiteralPath $Observer).Path $source 2>&1)
if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw 'Observer transport failed' }
$actual = $output[0] | ConvertFrom-Json
if (-not $actual.setup -or -not $actual.ok) { throw 'Semantic observation failed' }
function Check-Multiply($Actual, [string] $name) {
    $expression = "$name * $name"
    $start = $text.IndexOf($expression, [StringComparison]::Ordinal)
    if ($start -lt 0) { return $false }
    $matches = @(for ($i = 0; $i -lt $Actual.values.Count; $i++) {
        $node = $Actual.values[$i]; $syntax = $Actual.syntax[$node[1]]
        if ($node[2] -eq 5 -and $node[3] -eq 4 -and $node[10] -eq 8 -and
            $syntax[1] -eq $start -and $syntax[2] -eq $start + $expression.Length) { $i }
    })
    if ($matches.Count -ne 1) { return $false }
    $node = $Actual.values[$matches[0]]
    if ($node[8] -ne 2) { return $false }
    $first = [int]$node[6]
    if ($first -lt 0 -or $first -ge $Actual.values.Count) { return $false }
    $second = [int]$Actual.values[$first][7]
    if ($second -lt 0 -or $second -ge $Actual.values.Count) { return $false }
    $expectedStarts = @($start, ($start + 3 + $name.Length))
    $children = @($first, $second)
    for ($i = 0; $i -lt 2; $i++) {
        $child = $Actual.values[$children[$i]]; $syntax = $Actual.syntax[$child[1]]
        if ($child[2] -ne 3 -or $child[3] -ne 4 -or $syntax[1] -ne $expectedStarts[$i] -or
            $syntax[2] -ne $expectedStarts[$i] + $name.Length) { return $false }
    }
    return $Actual.values[$second][7] -eq -1
}
foreach ($name in @('tooLarge', 'withinRange')) {
    if (-not (Check-Multiply $actual $name)) { throw "Incorrect multiplication graph for $name" }
}
$mutated = $actual | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$start = $text.IndexOf('tooLarge * tooLarge', [StringComparison]::Ordinal)
$node = @($mutated.values | Where-Object { $_[2] -eq 5 -and $mutated.syntax[$_[1]][1] -eq $start })[0]
$node[10] = 9
if (Check-Multiply $mutated 'tooLarge') { throw 'Wrong-operator control accepted' }
Write-Output 'Passed two dynamic multiplication graph checks and wrong-operator control.'
