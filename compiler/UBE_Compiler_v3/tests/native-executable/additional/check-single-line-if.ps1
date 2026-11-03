param([Parameter(Mandatory = $true)][string] $Observer)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$source = Join-Path $PSScriptRoot 'single-line-if/App.bas'
$text = [IO.File]::ReadAllText($source)
if ([Text.Encoding]::UTF8.GetByteCount($text) -ne $text.Length) { throw 'Fixture must remain ASCII' }
$output = @(& (Resolve-Path -LiteralPath $Observer).Path $source 2>&1)
if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw 'Observer transport failed' }
$actual = $output[0] | ConvertFrom-Json
if (-not $actual.setup -or -not $actual.ok) { throw 'Semantic observation failed' }
$cases = @(
    @('If yes Then total = total + 1 Else total = total + 10', 'yes', 'total = total + 1', 'total = total + 10'),
    @('If no Then total = total + 20 Else total = total + 2', 'no', 'total = total + 20', 'total = total + 2'),
    @('If no Then total = total + 40', 'no', 'total = total + 40'),
    @('If yes Then total = total + 4', 'yes', 'total = total + 4')
)
function Check-Case($Actual, $Case) {
    $start = $text.IndexOf($Case[0], [StringComparison]::Ordinal)
    if ($start -lt 0) { return $false }
    $matches = @(for ($i = 0; $i -lt $Actual.values.Count; $i++) {
        $node = $Actual.values[$i]; $syntax = $Actual.syntax[$node[1]]
        if ($node[2] -eq 106 -and $syntax[1] -eq $start -and $syntax[2] -eq $start + $Case[0].Length) { $i }
    })
    if ($matches.Count -ne 1) { return $false }
    $parent = $Actual.values[$matches[0]]
    if ($parent[8] -ne $Case.Count - 1) { return $false }
    $child = [int]$parent[6]
    $search = $start
    for ($n = 1; $n -lt $Case.Count; $n++) {
        if ($child -lt 0 -or $child -ge $Actual.values.Count) { return $false }
        $expectedStart = $text.IndexOf($Case[$n], $search, [StringComparison]::Ordinal)
        $record = $Actual.values[$child]; $syntax = $Actual.syntax[$record[1]]
        $expectedKind = if ($n -eq 1) { 3 } else { 102 }
        if ($record[2] -ne $expectedKind -or $syntax[1] -ne $expectedStart -or $syntax[2] -ne $expectedStart + $Case[$n].Length) { return $false }
        $search = $expectedStart + $Case[$n].Length
        $child = [int]$record[7]
    }
    return $child -eq -1
}
foreach ($case in $cases) { if (-not (Check-Case $actual $case)) { throw "Wrong If graph: $($case[0])" } }
$mutated = $actual | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$parent = @($mutated.values | Where-Object { $_[2] -eq 106 -and $mutated.syntax[$_[1]][1] -eq $text.IndexOf($cases[0][0], [StringComparison]::Ordinal) })[0]
$condition = [int]$parent[6]
$then = [int]$mutated.values[$condition][7]
$mutated.values[$condition][7] = $mutated.values[$then][7]
if (Check-Case $mutated $cases[0]) { throw 'Omitted-branch control accepted' }
Write-Output 'Passed four single-line If graph checks and omitted-branch control.'
