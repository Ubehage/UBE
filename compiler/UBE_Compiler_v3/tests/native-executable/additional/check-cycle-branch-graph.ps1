param([Parameter(Mandatory=$true)][string] $Observer)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$observerPath = (Resolve-Path -LiteralPath $Observer).Path
$directory = Join-Path $PSScriptRoot 'initializer-cycle-branch'
$project = (Resolve-Path -LiteralPath (Join-Path $directory 'InitializerCycleBranch.UBE')).Path
$texts = @('A.bas', 'B.bas', 'C.bas', 'App.bas' | ForEach-Object { [IO.File]::ReadAllText((Join-Path $directory $_)) })

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
    if (-not $actual.setup -or -not $actual.ok -or $actual.modules.Count -ne 4) { return $false }
    $a = @($actual.modules | Where-Object { $_.source -eq 0 })[0]
    $b = @($actual.modules | Where-Object { $_.source -eq 1 })[0]
    $c = @($actual.modules | Where-Object { $_.source -eq 2 })[0]
    $aDeclaration = Node-At $actual 0 103 'x As Long = B.y + 1'
    $bDeclaration = Node-At $actual 1 103 'y As Long = A.x + C.z'
    $cDeclaration = Node-At $actual 2 103 'z As Long = 7'
    $aAdd = Node-At $actual 0 5 'B.y + 1'
    $bAdd = Node-At $actual 1 5 'A.x + C.z'
    $aRead = Node-At $actual 0 3 'B.y + 1'
    $bReadA = Node-At $actual 1 3 'A.x + C.z'
    $bReadC = Node-At $actual 1 3 'C.z'
    return ($a.values[$aDeclaration][6] -eq $aAdd -and $a.values[$aAdd][6] -eq $aRead -and
        $b.values[$bDeclaration][6] -eq $bAdd -and $b.values[$bAdd][6] -eq $bReadA -and
        $b.values[$bReadA][7] -eq $bReadC -and
        $a.values[$aRead][5] -eq $b.values[$bDeclaration][5] -and
        $b.values[$bReadA][5] -eq $a.values[$aDeclaration][5] -and
        $b.values[$bReadC][5] -eq $c.values[$cDeclaration][5] -and
        $a.values[$aDeclaration][5] -ge 0 -and $b.values[$bDeclaration][5] -ge 0 -and
        $c.values[$cDeclaration][5] -ge 0)
}

$previous = $null
foreach ($jobs in @(1, 4)) {
    $output = @(& $observerPath --project $project $jobs 2>&1)
    if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw "Observer failed jobs=$jobs" }
    if ($null -ne $previous -and $previous -cne $output[0]) { throw 'Graph differs across worker counts' }
    $previous = $output[0]
    $actual = $output[0] | ConvertFrom-Json
    if (-not (Check-Graph $actual)) { throw "Dependency graph mismatch jobs=$jobs" }
    foreach ($edge in @(@(0, 'B.y + 1'), @(1, 'A.x + C.z'), @(1, 'C.z'))) {
        $changed = $output[0] | ConvertFrom-Json
        $module = @($changed.modules | Where-Object { $_.source -eq $edge[0] })[0]
        $read = Node-At $changed $edge[0] 3 $edge[1]
        $module.values[$read][5] = -1
        if (Check-Graph $changed) { throw "Changed dependency was accepted: $($edge[1])" }
    }
    Write-Output "cycle branch jobs=$jobs : three targets matched; mutations rejected."
}
