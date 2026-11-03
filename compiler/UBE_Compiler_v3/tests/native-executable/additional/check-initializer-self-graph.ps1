param([Parameter(Mandatory = $true)][string] $Observer)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$source = Join-Path $PSScriptRoot 'initializer-self/App.bas'
$text = [IO.File]::ReadAllText($source)
if ([Text.Encoding]::UTF8.GetByteCount($text) -ne $text.Length) { throw 'Fixture must remain ASCII' }
$output = @(& (Resolve-Path -LiteralPath $Observer).Path $source 2>&1)
if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw 'Observer transport failed' }
$actual = $output[0] | ConvertFrom-Json
if (-not $actual.setup -or -not $actual.ok) { throw 'Semantic observation failed' }
function Find-Node($Actual, [int] $kind, [string] $anchor) {
    $start = $text.IndexOf($anchor, [StringComparison]::Ordinal)
    if ($start -lt 0) { throw "Missing anchor $anchor" }
    $matches = @(for ($i = 0; $i -lt $Actual.values.Count; $i++) {
        $node = $Actual.values[$i]; $syntax = $Actual.syntax[$node[1]]
        if ($node[2] -eq $kind -and $syntax[1] -eq $start) { $i }
    })
    if ($matches.Count -ne 1) { throw "Ambiguous node $anchor" }
    return [int]$matches[0]
}
function Check-Relationships($Actual) {
    $procedure = Find-Node $Actual 101 'Function Main() As Long'
    $declaration = Find-Node $Actual 103 'number As Long = number + 5'
    $addition = Find-Node $Actual 5 'number + 5'
    $read = Find-Node $Actual 3 'number + 5'
    $failed = Find-Node $Actual 103 'failed As Long = 42'
    $divisor = Find-Node $Actual 103 'divisor As Long = 0'
    $division = Find-Node $Actual 5 '42 \ divisor'
    $assignment = Find-Node $Actual 104 'failed = failed + 7'
    $laterRead = Find-Node $Actual 3 'failed + 7'
    $laterAddition = Find-Node $Actual 5 'failed + 7'
    $d = $Actual.values[$declaration]; $f = $Actual.values[$failed]; $a = $Actual.values[$assignment]
    $body = [int]$Actual.values[$procedure][6]
    if ($body -lt 0 -or $body -ge $Actual.values.Count -or $Actual.values[$body][2] -ne 102 -or $Actual.values[$body][6] -ne $declaration) { return $false }
    if ($d[7] -ne $divisor -or $Actual.values[$divisor][7] -ne $failed -or $f[7] -ne $assignment) { return $false }
    $divideNode = $Actual.values[$division]
    $addSecond = [int]$Actual.values[$read][7]
    $divideFirst = [int]$divideNode[6]
    if ($addSecond -lt 0 -or $addSecond -ge $Actual.values.Count -or $divideFirst -lt 0 -or $divideFirst -ge $Actual.values.Count) { return $false }
    $divideSecond = [int]$Actual.values[$divideFirst][7]
    $laterSecond = [int]$Actual.values[$laterRead][7]
    if ($divideSecond -lt 0 -or $divideSecond -ge $Actual.values.Count -or $laterSecond -lt 0 -or $laterSecond -ge $Actual.values.Count) { return $false }
    if ($Actual.values[$addSecond][2] -ne 1 -or $Actual.values[$addSecond][4] -ne 5 -or $Actual.values[$addSecond][7] -ne -1 -or
        $Actual.values[$divideFirst][2] -ne 1 -or $Actual.values[$divideFirst][4] -ne 42 -or
        $Actual.values[$divideSecond][2] -ne 3 -or $Actual.values[$divideSecond][5] -ne $Actual.values[$divisor][5] -or $Actual.values[$divideSecond][7] -ne -1 -or
        $Actual.values[$laterSecond][2] -ne 1 -or $Actual.values[$laterSecond][4] -ne 7 -or $Actual.values[$laterSecond][7] -ne -1) { return $false }
    foreach ($pair in @(@($d, $addition, 4), @($f, $division, 4), @($a, $laterAddition, 3))) {
        $owner = $pair[0]; $valueIndex = [int]$pair[1]; $context = [int]$pair[2]
        $factIndex = [int]$owner[10]
        if ($factIndex -lt 0 -or $factIndex -ge $Actual.facts.Count) { return $false }
        $fact = $Actual.facts[$factIndex]
        if ($fact[2] -ne 3 -or $fact[3] -ne 4 -or $fact[5] -ne $owner[5] -or $fact[6] -ne 4 -or
            $fact[7] -ne $context -or $fact[1] -ne $Actual.values[$valueIndex][1]) { return $false }
    }
    return ($d[3] -eq 4 -and $d[5] -ge 0 -and $d[6] -eq $addition -and
        $Actual.values[$addition][3] -eq 4 -and $Actual.values[$addition][8] -eq 2 -and $Actual.values[$addition][10] -eq 12 -and
        $Actual.values[$addition][6] -eq $read -and $Actual.values[$read][5] -eq $d[5] -and
        $f[3] -eq 4 -and $f[5] -ge 0 -and $f[5] -ne $d[5] -and $f[6] -eq $division -and
        $Actual.values[$division][3] -eq 4 -and $Actual.values[$division][8] -eq 2 -and $Actual.values[$division][10] -eq 10 -and
        $a[5] -eq $f[5] -and $a[6] -eq $laterAddition -and
        $Actual.values[$laterAddition][3] -eq 4 -and $Actual.values[$laterAddition][8] -eq 2 -and $Actual.values[$laterAddition][10] -eq 12 -and
        $Actual.values[$laterAddition][6] -eq $laterRead -and $Actual.values[$laterRead][5] -eq $f[5])
}
if (-not (Check-Relationships $actual)) { throw 'Initializer or storage relationships differ' }
$mutated = $actual | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$read = Find-Node $mutated 3 'number + 5'
$mutated.values[$read][5] = -1
if (Check-Relationships $mutated) { throw 'Wrong self-reference target accepted' }
$mutated = $actual | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$assignment = Find-Node $mutated 104 'failed = failed + 7'
$mutated.values[$assignment][5] = -1
if (Check-Relationships $mutated) { throw 'Wrong assignment target accepted' }
$mutated = $actual | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$division = Find-Node $mutated 5 '42 \ divisor'
$mutated.values[$division][10] = 8
if (Check-Relationships $mutated) { throw 'Wrong operator accepted' }
$mutated = $actual | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$declaration = Find-Node $mutated 103 'number As Long = number + 5'
$mutated.facts[$mutated.values[$declaration][10]][5] = -1
if (Check-Relationships $mutated) { throw 'Wrong conversion target accepted' }
$mutated = $actual | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$division = Find-Node $mutated 5 '42 \ divisor'
$mutated.values[$mutated.values[$division][6]][4] = 41
if (Check-Relationships $mutated) { throw 'Wrong dividend accepted' }
$mutated = $actual | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$declaration = Find-Node $mutated 103 'number As Long = number + 5'
$assignment = Find-Node $mutated 104 'failed = failed + 7'
$mutated.values[$declaration][7] = $assignment
if (Check-Relationships $mutated) { throw 'Wrong statement order accepted' }
Write-Output 'Initializer, statement order, operands, conversions and reused-storage graph checks passed; six mutations rejected.'
