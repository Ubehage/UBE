param([Parameter(Mandatory = $true)][string] $Observer)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$source = Join-Path $PSScriptRoot '../fixtures/conditions/App.bas'
$text = [IO.File]::ReadAllText($source)
if ([Text.Encoding]::UTF8.GetByteCount($text) -ne $text.Length) { throw 'Fixture must remain ASCII' }
$output = @(& (Resolve-Path -LiteralPath $Observer).Path $source 2>&1)
if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw 'Observer transport failed' }
$actual = $output[0] | ConvertFrom-Json
if (-not $actual.setup -or -not $actual.ok) { throw 'Semantic observation failed' }
function Find-Node($a, [int] $kind, [string] $anchor) {
    $start = $text.IndexOf($anchor, [StringComparison]::Ordinal)
    if ($start -lt 0) { throw "Missing source anchor $anchor" }
    $found = @(for ($i = 0; $i -lt $a.values.Count; $i++) {
        $n = $a.values[$i]; $s = $a.syntax[$n[1]]
        if ($n[2] -eq $kind -and $s[1] -eq $start) { $i }
    })
    if ($found.Count -ne 1) { throw "Expected one node for $anchor" }
    return [int]$found[0]
}
function Check-Graph($a) {
    $outer = Find-Node $a 106 'If count = 3 Then'
    $firstCondition = Find-Node $a 5 'count = 3'
    $firstBranch = Find-Node $a 102 'Main = 98'
    $elseIf = Find-Node $a 106 'ElseIf count = 4 Then'
    $secondCondition = Find-Node $a 5 'count = 4'
    $secondBranch = Find-Node $a 102 'Main = 41'
    $elseBranch = Find-Node $a 102 'Main = 99'
    $v = $a.values
    if ($v[$outer][8] -ne 4 -or $v[$outer][6] -ne $firstCondition -or
        $v[$firstCondition][7] -ne $firstBranch -or $v[$firstBranch][7] -ne $elseIf -or
        $v[$elseIf][7] -ne $elseBranch -or $v[$elseBranch][7] -ne -1 -or
        $v[$elseIf][8] -ne 2 -or $v[$elseIf][6] -ne $secondCondition -or
        $v[$secondCondition][7] -ne $secondBranch -or $v[$secondBranch][7] -ne -1) { return $false }
    foreach ($pair in @(@($firstCondition, 3), @($secondCondition, 4))) {
        $condition = $v[$pair[0]]; $left = [int]$condition[6]
        if ($condition[3] -ne 1 -or $condition[8] -ne 2 -or $condition[10] -ne 15 -or $left -lt 0) { return $false }
        $right = [int]$v[$left][7]
        if ($right -lt 0 -or $v[$left][2] -ne 3 -or $v[$right][2] -ne 1 -or
            $v[$right][4] -ne $pair[1] -or $v[$right][7] -ne -1) { return $false }
    }
    return $v[[int]$v[$firstCondition][6]][5] -eq $v[[int]$v[$secondCondition][6]][5]
}
if (-not (Check-Graph $actual)) { throw 'Wrong If/ElseIf graph' }
foreach ($mutation in @('order', 'condition', 'branch', 'operator')) {
    $changed = $actual | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $first = Find-Node $changed 102 'Main = 98'
    $nested = Find-Node $changed 106 'ElseIf count = 4 Then'
    $cond = Find-Node $changed 5 'count = 4'
    if ($mutation -eq 'order') { $changed.values[$first][7] = $changed.values[$nested][7] }
    if ($mutation -eq 'condition') { $changed.values[$nested][6] = Find-Node $changed 5 'count = 3' }
    if ($mutation -eq 'branch') { $changed.values[$cond][7] = Find-Node $changed 102 'Main = 99' }
    if ($mutation -eq 'operator') { $changed.values[$cond][10] = 13 }
    if (Check-Graph $changed) { throw "Accepted $mutation mutation" }
}
Write-Output 'Passed If/ElseIf graph and four independent mutation controls.'
