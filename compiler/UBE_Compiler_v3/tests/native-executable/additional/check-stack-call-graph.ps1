param([Parameter(Mandatory=$true)][string] $Observer)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$source = Join-Path $PSScriptRoot 'stack-call-effects/App.bas'
$text = [IO.File]::ReadAllText($source)
if ([Text.Encoding]::UTF8.GetByteCount($text) -ne $text.Length) { throw 'Fixture must remain ASCII' }
$output = @(& (Resolve-Path -LiteralPath $Observer).Path $source 2>&1)
if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw 'Observer transport failed' }
$actual = $output[0] | ConvertFrom-Json
if (-not $actual.setup -or -not $actual.ok) { throw 'Semantic observation failed' }
function Find-Declaration($graph, [string] $anchor) {
    $start = $text.IndexOf($anchor, [StringComparison]::Ordinal)
    $found = @(for ($i=0; $i -lt $graph.declarations.Count; $i++) {
        $d=$graph.declarations[$i]
        if ($d[2] -ge 0 -and $graph.syntax[$d[2]][1] -eq $start) { $i }
    })
    if ($start -lt 0 -or $found.Count -ne 1) { throw "Ambiguous declaration $anchor" }
    return [int]$found[0]
}
function Find-Call($graph, [string] $expression) {
    $start = $text.LastIndexOf($expression, [StringComparison]::Ordinal)
    $found = @(for ($i=0; $i -lt $graph.values.Count; $i++) {
        $n=$graph.values[$i]; $s=$graph.syntax[$n[1]]
        if ($n[2] -eq 6 -and $s[1] -eq $start -and $s[2] -eq $start+$expression.Length) { $i }
    })
    if ($start -lt 0 -or $found.Count -ne 1) { throw "Ambiguous call $expression" }
    return [int]$found[0]
}
function Check-Graph($graph) {
    $outer = Find-Call $graph 'Work(Argument())'; $inner = Find-Call $graph 'Argument()'
    $work = Find-Declaration $graph 'Private Function Work('
    $argument = Find-Declaration $graph 'Private Function Argument('
    $node = $graph.values[$outer]; $child = $graph.values[$inner]
    if ($node[5] -ne $work -or $child[5] -ne $argument -or $node[6] -ne $inner -or
        $node[8] -ne 1 -or $child[7] -ne -1 -or $child[8] -ne 0) { return $false }
    $factIndex = [int]$node[10]
    if ($factIndex -lt 0 -or $factIndex -ge $graph.facts.Count) { return $false }
    $fact = $graph.facts[$factIndex]
    $arguments = @($graph.facts | Where-Object { $_[2] -eq 6 -and $_[6] -eq $factIndex })
    if ($fact[2] -ne 5 -or $fact[5] -ne $work -or $fact[7] -ne 1 -or $arguments.Count -ne 1) { return $false }
    return $arguments[0][5] -eq $graph.declarations[$work][7] -and
        $arguments[0][7] -eq $child[1] -and $arguments[0][9] -eq 0 -and $arguments[0][10] -eq 0
}
if (-not (Check-Graph $actual)) { throw 'Nested call graph differs' }
foreach ($mutation in @('outer-target','inner-target','child','parameter')) {
    $changed = $actual | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $outer = Find-Call $changed 'Work(Argument())'; $inner = Find-Call $changed 'Argument()'
    if ($mutation -eq 'outer-target') { $changed.values[$outer][5] = $changed.values[$inner][5] }
    if ($mutation -eq 'inner-target') { $changed.values[$inner][5] = $changed.values[$outer][5] }
    if ($mutation -eq 'child') { $changed.values[$outer][6] = -1 }
    if ($mutation -eq 'parameter') { (@($changed.facts | Where-Object { $_[2] -eq 6 -and $_[6] -eq $changed.values[$outer][10] })[0])[5] = -1 }
    if (Check-Graph $changed) { throw "Accepted $mutation mutation" }
}
Write-Output 'Nested call targets, child and parameter matched; four controls rejected.'
