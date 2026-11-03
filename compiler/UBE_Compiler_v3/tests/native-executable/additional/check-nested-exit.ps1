param([Parameter(Mandatory = $true)][string] $Observer)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$source = Join-Path $PSScriptRoot 'nested-exit/App.bas'
$text = [IO.File]::ReadAllText($source)
if ([Text.Encoding]::UTF8.GetByteCount($text) -ne $text.Length) { throw 'Fixture must remain ASCII for byte offsets' }
$output = @(& (Resolve-Path -LiteralPath $Observer).Path $source 2>&1)
if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw 'Observer transport failed' }
$actual = $output[0] | ConvertFrom-Json
if (-not $actual.setup -or -not $actual.ok) { throw 'Semantic observation failed' }
function Find-Syntax($Actual, [int] $Kind, [string] $Anchor) {
    $start = $text.IndexOf($Anchor, [StringComparison]::Ordinal)
    if ($start -lt 0 -or $text.IndexOf($Anchor, $start + 1, [StringComparison]::Ordinal) -ge 0) { throw "Ambiguous anchor $Anchor" }
    $matches = @(for ($i = 0; $i -lt $Actual.syntax.Count; $i++) {
        if ($Actual.syntax[$i][0] -eq $Kind -and $Actual.syntax[$i][1] -eq $start) { $i }
    })
    if ($matches.Count -ne 1) { throw "Missing syntax for $Anchor" }
    return [int]$matches[0]
}
function Node-Index($Actual, [int] $Syntax, [int] $Kind) {
    $matches = @(for ($i = 0; $i -lt $Actual.values.Count; $i++) {
        if ($Actual.values[$i][1] -eq $Syntax -and $Actual.values[$i][2] -eq $Kind) { $i }
    })
    if ($matches.Count -ne 1) { throw 'Missing or duplicate bound node' }
    return [int]$matches[0]
}
$outer = Node-Index $actual (Find-Syntax $actual 71 'While outer < 3') 107
$inner = Node-Index $actual (Find-Syntax $actual 71 'While inner < 5') 107
$exit = Node-Index $actual (Find-Syntax $actual 59 'Exit While') 108
function Check-Exit($Actual) { return ($inner -ne $outer -and $Actual.values[$exit][5] -eq $inner -and $Actual.values[$exit][9] -eq 3) }
if (-not (Check-Exit $actual)) { throw 'Exit While does not target the inner loop' }
$mutated = $actual | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$mutated.values[$exit][5] = $outer
if (Check-Exit $mutated) { throw 'Wrong-target control accepted' }
Write-Output 'Passed nested exit target check and wrong-target control.'
