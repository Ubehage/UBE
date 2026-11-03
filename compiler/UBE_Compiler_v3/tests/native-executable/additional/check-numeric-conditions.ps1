param([Parameter(Mandatory = $true)][string] $Observer)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$source = Join-Path $PSScriptRoot '../fixtures/conditions/App.bas'
$observerPath = (Resolve-Path -LiteralPath $Observer).Path
$output = @(& $observerPath $source 2>&1)
if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw 'Observer transport failed' }
$observation = $output[0] | ConvertFrom-Json
if (-not $observation.setup -or -not $observation.ok) { throw 'Semantic observation failed' }
$bytes = [IO.File]::ReadAllBytes($source)
function Check-Condition($Actual, [string] $Text) {
    $anchor = [Text.Encoding]::UTF8.GetBytes('While ' + $Text)
    $positions = @(for ($i = 0; $i -le $bytes.Length - $anchor.Length; $i++) {
        $match = $true
        for ($j = 0; $j -lt $anchor.Length; $j++) { if ($bytes[$i + $j] -ne $anchor[$j]) { $match = $false; break } }
        if ($match) { $i }
    })
    if ($positions.Count -ne 1) { return $false }
    $start = $positions[0]
    $conditions = @(for ($i = 0; $i -lt $Actual.syntax.Count; $i++) {
        $s = $Actual.syntax[$i]
        if ($s[0] -eq 71 -and $s[1] -eq $start) { $i }
    })
    if ($conditions.Count -ne 1) { return $false }
    $condition = $conditions[0]
    $operand = [int]$Actual.syntax[$condition][3]
    $nodes = @($Actual.values | Where-Object { $_[1] -eq $condition -and $_[2] -eq 107 })
    $facts = @($Actual.facts | Where-Object { $_[1] -eq $operand -and $_[2] -eq 3 -and $_[5] -eq $condition -and $_[7] -eq 7 })
    if ($nodes.Count -ne 1 -or $facts.Count -ne 1) { return $false }
    $child = [int]$nodes[0][6]
    if ($child -lt 0 -or $child -ge $Actual.values.Count) { return $false }
    return ($Actual.values[$child][1] -eq $operand -and $Actual.values[$child][2] -eq 3 -and $Actual.values[$child][3] -eq 4 -and $facts[0][3] -eq 1 -and $facts[0][6] -eq 4 -and ($facts[0][8] -band 1) -eq 1)
}
foreach ($name in @('n', 'inner')) {
    if (-not (Check-Condition $observation $name)) { throw "Wrong numeric condition: $name" }
    $mutated = $observation | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $start = [Text.Encoding]::UTF8.GetString($bytes).IndexOf('While ' + $name, [StringComparison]::Ordinal)
    $target = @(for ($i = 0; $i -lt $mutated.syntax.Count; $i++) { if ($mutated.syntax[$i][0] -eq 71 -and $mutated.syntax[$i][1] -eq $start) { $i } })[0]
    $fact = @($mutated.facts | Where-Object { $_[2] -eq 3 -and $_[5] -eq $target -and $_[7] -eq 7 })[0]
    $fact[6] = 1
    if (Check-Condition $mutated $name) { throw "Wrong-source-type control accepted: $name" }
}
Write-Output 'Passed two numeric condition checks and two wrong-type controls.'
