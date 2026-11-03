param([Parameter(Mandatory=$true)][string] $Observer)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$observerPath = (Resolve-Path -LiteralPath $Observer).Path
foreach ($case in @('initializer-early-access','initializer-cycle')) {
    $directory = Join-Path $PSScriptRoot $case
    $manifest = if ($case -eq 'initializer-cycle') { 'InitializerCycle.UBE' } else { 'InitializerEarlyAccess.UBE' }
    $project = (Resolve-Path -LiteralPath (Join-Path $directory $manifest)).Path
    $texts = @([IO.File]::ReadAllText((Join-Path $directory 'A.bas')), [IO.File]::ReadAllText((Join-Path $directory 'B.bas')), [IO.File]::ReadAllText((Join-Path $directory 'App.bas')))
    function Node-At($actual, [int] $source, [int] $kind, [string] $anchor) {
        $start = $texts[$source].IndexOf($anchor, [StringComparison]::Ordinal)
        if ($start -lt 0) { throw "Missing source anchor: $anchor" }
        $modules = @($actual.modules | Where-Object { $_.source -eq $source })
        if ($modules.Count -ne 1) { throw "Missing module $source" }
        $ids = @(for ($i = 0; $i -lt $modules[0].values.Count; $i++) {
            $node = $modules[0].values[$i]
            $syntax = $actual.sourceSyntax[$source][$node[1]]
            if ($node[2] -eq $kind -and $syntax[1] -eq $start) { $i }
        })
        if ($ids.Count -ne 1) { throw "Ambiguous node: $anchor kind=$kind" }
        return [int]$ids[0]
    }
    function Check-Graph($actual) {
        if (-not $actual.setup -or -not $actual.ok -or $actual.modules.Count -ne 3) { return $false }
        $a = @($actual.modules | Where-Object { $_.source -eq 0 })[0]
        $b = @($actual.modules | Where-Object { $_.source -eq 1 })[0]
        $aDeclaration = Node-At $actual 0 103 'x As Long = B.y + 1'
        $aAdd = Node-At $actual 0 5 'B.y + 1'
        $aRead = Node-At $actual 0 3 'B.y + 1'
        $bAnchor = if ($case -eq 'initializer-cycle') { 'y As Long = A.x + 1' } else { 'y As Long = InitializeValue()' }
        $bDeclaration = Node-At $actual 1 103 $bAnchor
        if ($a.values[$aDeclaration][6] -ne $aAdd -or $a.values[$aAdd][6] -ne $aRead -or
            $a.values[$aRead][5] -ne $b.values[$bDeclaration][5] -or $b.values[$bDeclaration][5] -lt 0) { return $false }
        if ($case -eq 'initializer-cycle') {
            $bAdd = Node-At $actual 1 5 'A.x + 1'
            $bRead = Node-At $actual 1 3 'A.x + 1'
            if ($b.values[$bDeclaration][6] -ne $bAdd -or $b.values[$bAdd][6] -ne $bRead -or
                $b.values[$bRead][5] -ne $a.values[$aDeclaration][5] -or $a.values[$aDeclaration][5] -lt 0) { return $false }
        }
        return $true
    }
    $previous = $null
    foreach ($jobs in @(1,4)) {
        $output = @(& $observerPath --project $project $jobs 2>&1)
        if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw "Observer failed for $case jobs=$jobs" }
        if ($null -ne $previous -and $previous -cne $output[0]) { throw "Graph differs across worker counts: $case" }
        $previous = $output[0]
        $actual = $output[0] | ConvertFrom-Json
        if (-not (Check-Graph $actual)) { throw "Dependency graph mismatch: $case jobs=$jobs" }
        foreach ($source in @(if ($case -eq 'initializer-cycle') { 0; 1 } else { 0 })) {
            $changed = $output[0] | ConvertFrom-Json
            $module = @($changed.modules | Where-Object { $_.source -eq $source })[0]
            $read = if ($source -eq 0) { Node-At $changed 0 3 'B.y + 1' } else { Node-At $changed 1 3 'A.x + 1' }
            $module.values[$read][5] = -1
            if (Check-Graph $changed) { throw "Changed dependency was accepted: $case source=$source" }
        }
        Write-Output "$case jobs=$jobs : cross-module declaration targets matched; mutations rejected."
    }
}
