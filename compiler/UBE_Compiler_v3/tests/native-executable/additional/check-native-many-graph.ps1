param([Parameter(Mandatory=$true)][string] $Observer)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$directory = Join-Path $PSScriptRoot 'native-many-arguments'
$project = (Resolve-Path -LiteralPath (Join-Path $directory 'NativeManyArguments.UBE')).Path
$text = [IO.File]::ReadAllText((Join-Path $directory 'App.bas'))
$expression = 'Weighted(a, b, c, d, e)'
$start = $text.LastIndexOf($expression, [StringComparison]::Ordinal)
if ($start -lt 0 -or [Text.Encoding]::UTF8.GetByteCount($text) -ne $text.Length) { throw 'Fixture anchor or ASCII assumption failed' }
function Check-Graph($g) {
    if (-not $g.setup -or -not $g.ok) { return $false }
    $modules = @($g.modules | Where-Object { $_.source -eq 0 })
    if ($modules.Count -ne 1) { return $false }
    $m = $modules[0]
    $calls = @(for ($i=0; $i -lt $m.values.Count; $i++) {
        $n = $m.values[$i]; $s = $g.sourceSyntax[0][$n[1]]
        if ($n[2] -eq 6 -and $s[1] -eq $start -and $s[2] -eq $start + $expression.Length) { $i }
    })
    if ($calls.Count -ne 1) { return $false }
    $call = $m.values[$calls[0]]
    $declarations = @(for ($i=0; $i -lt $g.declarations.Count; $i++) {
        $d = $g.declarations[$i]
        if ($d[1] -eq 0 -and $d[2] -ge 0 -and $g.sourceSyntax[0][$d[2]][1] -eq $text.IndexOf('Private Function Weighted(', [StringComparison]::Ordinal)) { $i }
    })
    if ($declarations.Count -ne 1 -or $call[5] -ne $declarations[0] -or $call[8] -ne 5) { return $false }
    $factIndex = [int]$call[10]
    if ($factIndex -lt 0 -or $factIndex -ge $m.facts.Count) { return $false }
    $fact = $m.facts[$factIndex]
    $args = @($m.facts | Where-Object { $_[2] -eq 6 -and $_[6] -eq $factIndex })
    if ($fact[2] -ne 5 -or $fact[5] -ne $declarations[0] -or $fact[7] -ne 5 -or $args.Count -ne 5) { return $false }
    $child = [int]$call[6]
    for ($i=0; $i -lt 5; $i++) {
        if ($child -lt 0 -or $child -ge $m.values.Count) { return $false }
        $node = $m.values[$child]; $syntax = $g.sourceSyntax[0][$node[1]]
        $expectedStart = $start + 9 + 3 * $i
        if ($syntax[1] -ne $expectedStart -or $syntax[2] -ne $expectedStart + 1 -or
            $args[$i][7] -ne $node[1] -or $args[$i][9] -ne $i -or $args[$i][10] -ne $i -or
            $args[$i][5] -ne $g.declarations[$declarations[0]][7] + $i) { return $false }
        $child = [int]$node[7]
    }
    return $child -eq -1
}
$previous = $null
foreach ($jobs in @(1,4)) {
    $output = @(& (Resolve-Path -LiteralPath $Observer).Path --project $project $jobs 2>&1)
    if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw "Observer failed jobs=$jobs" }
    if ($null -ne $previous -and $previous -cne $output[0]) { throw 'Graph differs across worker counts' }
    $previous = $output[0]
    $actual = $output[0] | ConvertFrom-Json
    if (-not (Check-Graph $actual)) { throw "Five-argument graph mismatch jobs=$jobs" }
    $m = @($actual.modules | Where-Object { $_.source -eq 0 })[0]
    $call = @($m.values | Where-Object { $_[2] -eq 6 -and $_[8] -eq 5 })[0]
    $args = @($m.facts | Where-Object { $_[2] -eq 6 -and $_[6] -eq $call[10] })
    foreach ($i in 0..4) {
        $old = $args[$i][5]; $args[$i][5] = -1
        if (Check-Graph $actual) { throw "Argument mutation accepted: $i" }
        $args[$i][5] = $old
    }
    Write-Output "jobs=$jobs : five arguments and parameter associations matched; five mutations rejected."
}
