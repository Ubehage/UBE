param([Parameter(Mandatory=$true)][string] $Observer)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$source = Join-Path $PSScriptRoot 'narrowing-boundaries/App.bas'
$text = [IO.File]::ReadAllText($source)
if ([Text.Encoding]::UTF8.GetByteCount($text) -ne $text.Length) { throw 'Fixture must remain ASCII' }
$output = @(& (Resolve-Path -LiteralPath $Observer).Path $source 2>&1)
if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw 'Observer transport failed' }
$actual = $output[0] | ConvertFrom-Json
if (-not $actual.setup -or -not $actual.ok) { throw 'Semantic observation failed' }
$cases = @(@('IToByte',3,2), @('LToByte',4,2), @('LLToByte',5,2),
           @('LToInteger',4,3), @('LLToInteger',5,3), @('LLToLong',5,4))
function Assignment($a, $case) {
    $anchor = $case[0] + ' = value'; $start = $text.IndexOf($anchor, [StringComparison]::Ordinal)
    if ($start -lt 0) { throw "Missing $anchor" }
    $nodes = @(for ($i=0; $i -lt $a.values.Count; $i++) {
        $n=$a.values[$i]; $s=$a.syntax[$n[1]]
        if ($n[2] -eq 104 -and $s[1] -eq $start) { $i }
    })
    if ($nodes.Count -ne 1) { throw "Ambiguous assignment $anchor" }
    return [int]$nodes[0]
}
function Check-Case($a, $case) {
    $index = Assignment $a $case; $node = $a.values[$index]; $child = [int]$node[6]; $fact = [int]$node[10]
    if ($child -lt 0 -or $child -ge $a.values.Count -or $fact -lt 0 -or $fact -ge $a.facts.Count) { return $false }
    $value = $a.values[$child]; $conversion = $a.facts[$fact]
    return ($node[3] -eq $case[2] -and $node[5] -ge 0 -and $node[8] -eq 1 -and
        $value[2] -eq 3 -and $value[3] -eq $case[1] -and $value[5] -ge 0 -and $value[7] -eq -1 -and
        $conversion[2] -eq 3 -and $conversion[3] -eq $case[2] -and $conversion[5] -eq $node[5] -and
        $conversion[6] -eq $case[1] -and $conversion[7] -eq 5 -and $conversion[1] -eq $value[1])
}
foreach ($case in $cases) {
    if (-not (Check-Case $actual $case)) { throw "Wrong conversion graph: $($case[0])" }
    foreach ($mutation in @('source', 'destination', 'target')) {
        $changed = $actual | ConvertTo-Json -Depth 30 | ConvertFrom-Json
        $node = $changed.values[(Assignment $changed $case)]; $fact = $changed.facts[$node[10]]
        if ($mutation -eq 'source') { $fact[6] = 1 }
        if ($mutation -eq 'destination') { $fact[3] = 1 }
        if ($mutation -eq 'target') { $fact[5] = -1 }
        if (Check-Case $changed $case) { throw "Accepted $mutation mutation for $($case[0])" }
    }
}
Write-Output 'Passed six narrowing conversion graphs and 18 mutation controls.'
