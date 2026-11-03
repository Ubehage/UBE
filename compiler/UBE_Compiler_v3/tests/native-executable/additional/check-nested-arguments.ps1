param([Parameter(Mandatory = $true)][string] $Observer)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$source = Join-Path $PSScriptRoot 'nested-arguments/App.bas'
$text = [IO.File]::ReadAllText($source)
if ([Text.Encoding]::UTF8.GetByteCount($text) -ne $text.Length) { throw 'Fixture must remain ASCII' }
$output = @(& (Resolve-Path -LiteralPath $Observer).Path $source 2>&1)
if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw 'Observer transport failed' }
$actual = $output[0] | ConvertFrom-Json
if (-not $actual.setup -or -not $actual.ok) { throw 'Semantic observation failed' }
function Call-At($Actual, [string] $Expression) {
    $start = $text.IndexOf($Expression, [StringComparison]::Ordinal)
    if ($start -lt 0 -or $text.IndexOf($Expression, $start + 1, [StringComparison]::Ordinal) -ge 0) { throw "Ambiguous expression $Expression" }
    $end = $start + $Expression.Length
    $calls = @(for ($i = 0; $i -lt $Actual.values.Count; $i++) {
        $node = $Actual.values[$i]
        $syntax = $Actual.syntax[$node[1]]
        if ($node[2] -eq 6 -and $syntax[1] -eq $start -and $syntax[2] -eq $end) { $i }
    })
    if ($calls.Count -ne 1) { throw "Missing call $Expression" }
    return [int]$calls[0]
}
$outer = Call-At $actual 'Combine(second:=Combine(second:=Mark(2), first:=Mark(1)), first:=Mark(3))'
$inner = Call-At $actual 'Combine(second:=Mark(2), first:=Mark(1))'
$mark2 = Call-At $actual 'Mark(2)'
$mark1 = Call-At $actual 'Mark(1)'
$mark3 = Call-At $actual 'Mark(3)'
function Check-Call($Actual, [int] $Call, [int] $FirstWritten, [int] $SecondWritten) {
    $node = $Actual.values[$Call]
    $first = [int]$node[6]
    if ($node[8] -ne 2 -or $first -ne $FirstWritten -or $first -lt 0) { return $false }
    if ($Actual.values[$first][7] -ne $SecondWritten -or $Actual.values[$SecondWritten][7] -ne -1) { return $false }
    $callFactIndex = [int]$node[10]
    if ($callFactIndex -lt 0 -or $callFactIndex -ge $Actual.facts.Count) { return $false }
    $callFact = $Actual.facts[$callFactIndex]
    if ($callFact[2] -ne 5 -or $callFact[1] -ne $node[1] -or $callFact[7] -ne 2) { return $false }
    $args = @($Actual.facts | Where-Object { $_[2] -eq 6 -and $_[6] -eq $callFactIndex } | Sort-Object { $_[10] })
    if ($args.Count -ne 2) { return $false }
    return ($args[0][10] -eq 0 -and $args[0][9] -eq 1 -and $args[0][7] -eq $Actual.values[$SecondWritten][1] -and $args[1][10] -eq 1 -and $args[1][9] -eq 0 -and $args[1][7] -eq $Actual.values[$FirstWritten][1])
}
if (-not (Check-Call $actual $outer $inner $mark3) -or -not (Check-Call $actual $inner $mark2 $mark1)) { throw 'Nested written order or parameter association differs' }
$mutated = $actual | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$mutated.values[$outer][6] = $mark3
if (Check-Call $mutated $outer $inner $mark3) { throw 'Wrong child-order control accepted' }
$mutated = $actual | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$argument = @($mutated.facts | Where-Object { $_[2] -eq 6 -and $_[6] -eq $mutated.values[$inner][10] -and $_[10] -eq 0 })[0]
$argument[9] = 0
if (Check-Call $mutated $inner $mark2 $mark1) { throw 'Wrong association control accepted' }
Write-Output 'Passed nested call order and association checks and two controls.'
