param([Parameter(Mandatory=$true)][string] $Observer,
      [Parameter(Mandatory=$true)][string] $FixtureDirectory)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$observerPath = (Resolve-Path -LiteralPath $Observer).Path
$fixtureRoot = (Resolve-Path -LiteralPath $FixtureDirectory).Path
function Check-Graph($graph, [int] $size, [bool] $cycle) {
    if (-not $graph.setup -or -not $graph.ok -or $graph.modules.Count -ne $size + 1) { return $false }
    $modules = @{}
    foreach ($module in $graph.modules) {
        if ($modules.ContainsKey([int]$module.source)) { return $false }
        $modules[[int]$module.source] = $module
    }
    $declarations = @()
    for ($i = 0; $i -lt $size; $i++) {
        if (-not $modules.ContainsKey($i)) { return $false }
        $module = $modules[$i]
        $root = [int]$module.root
        if ($root -lt 0 -or $root -ge $module.values.Count) { return $false }
        $decl = [int]$module.values[$root][6]
        if ($decl -lt 0 -or $decl -ge $module.values.Count -or $module.values[$decl][2] -ne 103) { return $false }
        $declarations += $decl
    }
    for ($i = 0; $i -lt $size; $i++) {
        $module = $modules[$i]; $decl = $declarations[$i]
        $initializer = [int]$module.values[$decl][6]
        if ($initializer -lt 0 -or $initializer -ge $module.values.Count) { return $false }
        if ($i -eq $size - 1 -and -not $cycle) {
            if ($module.values[$initializer][2] -ne 1 -or $module.values[$initializer][4] -ne 1) { return $false }
        } else {
            if ($module.values[$initializer][2] -ne 5) { return $false }
            $read = [int]$module.values[$initializer][6]
            if ($read -lt 0 -or $read -ge $module.values.Count -or $module.values[$read][2] -ne 3) { return $false }
            $next = if ($i -eq $size - 1) { 0 } else { $i + 1 }
            $anchor = 'M{0:D3}.value + 1' -f $next
            $start = $texts[$i].IndexOf($anchor, [StringComparison]::Ordinal)
            $syntax = [int]$module.values[$read][1]
            if ($start -lt 0 -or $syntax -lt 0 -or $syntax -ge $graph.sourceSyntax[$i].Count -or
                $graph.sourceSyntax[$i][$syntax][1] -ne $start) { return $false }
            if ($module.values[$read][5] -ne $modules[$next].values[$declarations[$next]][5]) { return $false }
        }
    }
    return $true
}
foreach ($size in @(32,64,128)) {
    foreach ($cycle in @($false,$true)) {
        $project = Join-Path $fixtureRoot "modules-$size-$cycle/Scale.UBE"
        $directory = Split-Path $project -Parent
        $lines = @([IO.File]::ReadAllLines($project) | Where-Object { $_.StartsWith('Source = ', [StringComparison]::Ordinal) })
        if ($lines.Count -ne $size + 1 -or $lines[$size] -cne 'Source = "App.bas"') { throw 'Unexpected fixture source list' }
        $texts = @()
        for ($i = 0; $i -lt $size; $i++) {
            $name = 'M{0:D3}' -f $i
            if ($lines[$i] -cne "Source = `"$name.bas`"") { throw 'Fixture source order differs' }
            $next = if ($i -lt $size - 1) { 'M{0:D3}.value + 1' -f ($i + 1) } elseif ($cycle) { 'M000.value + 1' } else { '1' }
            $expected = "UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"$name`"`nPublic value As Long = $next`n"
            $text = [IO.File]::ReadAllText((Join-Path $directory "$name.bas"))
            if ($text -cne $expected) { throw "Fixture source differs: $name" }
            $texts += $text
        }
        $previous = $null
        foreach ($jobs in @(1,4)) {
            $output = @(& $observerPath --project $project $jobs 2>&1)
            if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw "Observer failed: size=$size cycle=$cycle jobs=$jobs" }
            if ($null -ne $previous -and $previous -cne $output[0]) { throw 'Graph differs across worker counts' }
            $previous = $output[0]; $graph = $output[0] | ConvertFrom-Json
            if (-not (Check-Graph $graph $size $cycle)) { throw "Graph mismatch: size=$size cycle=$cycle jobs=$jobs" }
            foreach ($mutation in @('first-target','tail','source-anchor')) {
                $changed = $output[0] | ConvertFrom-Json
                $source = if ($mutation -eq 'tail') { $size - 1 } else { 0 }
                $module = @($changed.modules | Where-Object { $_.source -eq $source })[0]
                $decl = [int]$module.values[$module.root][6]
                $expression = [int]$module.values[$decl][6]
                if ($mutation -eq 'tail' -and -not $cycle) {
                    $module.values[$expression][4] = 0
                } else {
                    $read = [int]$module.values[$expression][6]
                    if ($mutation -eq 'source-anchor') {
                        $syntax = [int]$module.values[$read][1]
                        $changed.sourceSyntax[$source][$syntax][1]++
                    } else { $module.values[$read][5] = -1 }
                }
                if (Check-Graph $changed $size $cycle) { throw "Mutation accepted: $mutation" }
            }
            Write-Output "size=$size cycle=$cycle jobs=$jobs : all dependency targets matched; three mutations rejected."
        }
    }
}
