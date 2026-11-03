param([Parameter(Mandatory=$true)][string] $Observer, [switch] $Acyclic)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$directory = Join-Path $PSScriptRoot $(if ($Acyclic) { 'initializer-indirect-acyclic' } else { 'initializer-indirect-cycle' })
$manifest = if ($Acyclic) { 'InitializerIndirectAcyclic.UBE' } else { 'InitializerIndirectCycle.UBE' }
$project = (Resolve-Path -LiteralPath (Join-Path $directory $manifest)).Path
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
    $aDecl = Find-Node $graph 0 103 'x As Long = ReadB()'
    $call = Find-Node $graph 0 6 'ReadB()'
    $helper = Find-Declaration $graph 0 'Private Function ReadB()'
    $helperNode = Find-Node $graph 0 101 'Private Function ReadB()'
    $readB = Find-Node $graph 0 3 'B.y + 1'
    $bDecl = Find-Node $graph 1 103 $(if ($Acyclic) { 'y As Long = InitializeValue()' } else { 'y As Long = A.x + 1' })
    $body = [int]$a.values[$helperNode][6]
    if ($body -lt 0 -or $body -ge $a.values.Count) { return $false }
    $assignment = [int]$a.values[$body][6]
    if ($assignment -lt 0 -or $assignment -ge $a.values.Count) { return $false }
    $expression = [int]$a.values[$assignment][6]
    if ($expression -lt 0 -or $expression -ge $a.values.Count) { return $false }
    if (-not ($a.values[$aDecl][6] -eq $call -and $a.values[$call][5] -eq $helper -and
        $a.values[$helperNode][5] -eq $helper -and $a.values[$body][2] -eq 102 -and
        $a.values[$assignment][2] -eq 104 -and $a.values[$expression][6] -eq $readB -and
        $a.values[$readB][5] -eq $b.values[$bDecl][5])) { return $false }
    if ($Acyclic) {
        foreach ($node in $b.values) {
            if ($node[2] -in @(3,6) -and $node[5] -eq $a.values[$aDecl][5]) { return $false }
        }
        return $true
    }
    $readA = Find-Node $graph 1 3 'A.x + 1'
    return $b.values[$readA][5] -eq $a.values[$aDecl][5]
}
$previous = $null
foreach ($jobs in @(1,4)) {
    $output = @(& (Resolve-Path -LiteralPath $Observer).Path --project $project $jobs 2>&1)
    if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw "Observer failed at jobs $jobs" }
    if ($null -ne $previous -and $previous -cne $output[0]) { throw 'Graphs differ across worker counts' }
    $previous = $output[0]; $actual = $output[0] | ConvertFrom-Json
    if (-not (Check-Graph $actual)) { throw 'Indirect initialization graph mismatch' }
    $lastMutation = if ($Acyclic) { 'insert-back-reference' } else { 'read-a' }
    foreach ($mutation in @('helper','helper-body','read-b',$lastMutation)) {
        $changed = $output[0] | ConvertFrom-Json
        $source = if ($mutation -in @('read-a','insert-back-reference')) { 1 } else { 0 }
        $module = @($changed.modules | Where-Object { $_.source -eq $source })[0]
        $node = switch ($mutation) {
            'helper' { Find-Node $changed 0 6 'ReadB()' }
            'helper-body' { Find-Node $changed 0 101 'Private Function ReadB()' }
            'read-b' { Find-Node $changed 0 3 'B.y + 1' }
            'read-a' { Find-Node $changed 1 3 'A.x + 1' }
            'insert-back-reference' { Find-Node $changed 1 6 'InitializeValue()' }
        }
        if ($mutation -eq 'helper-body') { $module.values[$node][6] = -1 }
        elseif ($mutation -eq 'insert-back-reference') {
            $a = @($changed.modules | Where-Object { $_.source -eq 0 })[0]
            $aDecl = Find-Node $changed 0 103 'x As Long = ReadB()'
            $module.values[$node][5] = $a.values[$aDecl][5]
        } else { $module.values[$node][5] = -1 }
        if (Check-Graph $changed) { throw "Mutation accepted: $mutation" }
    }
    Write-Output "acyclic=$Acyclic jobs=$jobs : helper body and cross-module targets matched; four mutations rejected."
}
