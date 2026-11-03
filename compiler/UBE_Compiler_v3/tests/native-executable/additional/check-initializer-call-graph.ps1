param([Parameter(Mandatory=$true)][string] $Observer)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$directory = Join-Path $PSScriptRoot 'initializer-early-call'
$project = (Resolve-Path -LiteralPath (Join-Path $directory 'InitializerEarlyCall.UBE')).Path
$texts = @([IO.File]::ReadAllText((Join-Path $directory 'A.bas')), [IO.File]::ReadAllText((Join-Path $directory 'B.bas')))
function Find-Node($graph, [int] $source, [int] $kind, [string] $anchor) {
    $start = $texts[$source].IndexOf($anchor, [StringComparison]::Ordinal)
    $module = @($graph.modules | Where-Object { $_.source -eq $source })[0]
    $found = @(for ($i=0; $i -lt $module.values.Count; $i++) {
        $n = $module.values[$i]
        if ($n[2] -eq $kind -and $graph.sourceSyntax[$source][$n[1]][1] -eq $start) { $i }
    })
    if ($start -lt 0 -or $found.Count -ne 1) { throw "Ambiguous node: $anchor" }
    return [int]$found[0]
}
function Find-Declaration($graph, [int] $source, [string] $anchor) {
    $start = $texts[$source].IndexOf($anchor, [StringComparison]::Ordinal)
    $found = @(for ($i=0; $i -lt $graph.declarations.Count; $i++) {
        $d = $graph.declarations[$i]
        if ($d[1] -eq $source -and $d[2] -ge 0 -and $graph.sourceSyntax[$source][$d[2]][1] -eq $start) { $i }
    })
    if ($start -lt 0 -or $found.Count -ne 1) { throw "Ambiguous declaration: $anchor" }
    return [int]$found[0]
}
function Check-Graph($graph) {
    if (-not $graph.setup -or -not $graph.ok -or $graph.modules.Count -ne 3) { return $false }
    $a = @($graph.modules | Where-Object { $_.source -eq 0 })[0]
    $b = @($graph.modules | Where-Object { $_.source -eq 1 })[0]
    $aDecl = Find-Node $graph 0 103 'x As Long = B.GetValue()'
    $call = Find-Node $graph 0 6 'B.GetValue()'
    $getValue = Find-Declaration $graph 1 'Public Function GetValue()'
    $getNode = Find-Node $graph 1 101 'Public Function GetValue()'
    $yDecl = Find-Node $graph 1 103 'y As Long = InitializeValue()'
    $setY = Find-Node $graph 1 104 'y = 9'
    $countDecl = Find-Node $graph 1 103 'count As Long = 0'
    $countSet = Find-Node $graph 1 104 'count = count + 1'
    $initCall = Find-Node $graph 1 6 'InitializeValue()'
    $initFunction = Find-Declaration $graph 1 'Private Function InitializeValue()'
    $body = [int]$b.values[$getNode][6]
    if ($body -lt 0 -or $body -ge $b.values.Count) { return $false }
    $value = [int]$b.values[$setY][6]
    if ($value -lt 0 -or $value -ge $b.values.Count) { return $false }
    return $a.values[$aDecl][6] -eq $call -and $a.values[$call][5] -eq $getValue -and
        $b.values[$getNode][5] -eq $getValue -and $b.values[$body][6] -eq $setY -and
        $b.values[$setY][5] -eq $b.values[$yDecl][5] -and $b.values[$value][4] -eq 9 -and
        $b.values[$countSet][5] -eq $b.values[$countDecl][5] -and
        $b.values[$yDecl][6] -eq $initCall -and $b.values[$initCall][5] -eq $initFunction
}
$previous = $null
foreach ($jobs in @(1,4)) {
    $output = @(& (Resolve-Path -LiteralPath $Observer).Path --project $project $jobs 2>&1)
    if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw "Observer failed at jobs $jobs" }
    if ($null -ne $previous -and $previous -cne $output[0]) { throw 'Graphs differ across worker counts' }
    $previous = $output[0]; $actual = $output[0] | ConvertFrom-Json
    if (-not (Check-Graph $actual)) { throw 'Early-call graph mismatch' }
    foreach ($mutation in @('call-target','body','assignment-target','initializer-target')) {
        $changed = $output[0] | ConvertFrom-Json
        $source = if ($mutation -eq 'call-target') { 0 } else { 1 }
        $module = @($changed.modules | Where-Object { $_.source -eq $source })[0]
        $node = switch ($mutation) {
            'call-target' { Find-Node $changed 0 6 'B.GetValue()' }
            'body' { Find-Node $changed 1 101 'Public Function GetValue()' }
            'assignment-target' { Find-Node $changed 1 104 'y = 9' }
            'initializer-target' { Find-Node $changed 1 6 'InitializeValue()' }
        }
        if ($mutation -eq 'body') { $module.values[$node][6] = -1 } else { $module.values[$node][5] = -1 }
        if (Check-Graph $changed) { throw "Mutation accepted: $mutation" }
    }
    Write-Output "jobs=$jobs : early procedure call and initialization links matched; four mutations rejected."
}
