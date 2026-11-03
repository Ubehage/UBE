param([Parameter(Mandatory=$true)][string] $Observer)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$directory = Join-Path $PSScriptRoot 'reference-initializer-error'
$project = Join-Path $directory 'ReferenceInitializerError.UBE'
$texts = @([IO.File]::ReadAllText((Join-Path $directory 'App.bas')), [IO.File]::ReadAllText((Join-Path $directory 'LibraryState.bas')))
foreach ($text in $texts) { if ([Text.Encoding]::UTF8.GetByteCount($text) -ne $text.Length) { throw 'Fixture must remain ASCII' } }
function Node-At($Actual, [int] $source, [int] $kind, [string] $anchor) {
    $start = $texts[$source].IndexOf($anchor, [StringComparison]::Ordinal)
    if ($start -lt 0) { throw "Missing anchor: $anchor" }
    $module = @($Actual.modules | Where-Object { $_.source -eq $source })
    if ($module.Count -ne 1) { throw "Missing or duplicate module: $source" }
    $ids = @(for ($i = 0; $i -lt $module[0].values.Count; $i++) {
        $node = $module[0].values[$i]; $syntax = $Actual.sourceSyntax[$source][$node[1]]
        if ($node[2] -eq $kind -and $syntax[1] -eq $start) { $i }
    })
    if ($ids.Count -ne 1) { throw "Ambiguous node: $anchor" }
    return [int]$ids[0]
}
function Check-Graph($Actual) {
    if (-not $Actual.setup -or -not $Actual.ok -or $Actual.modules.Count -ne 2) { return $false }
    $app = @($Actual.modules | Where-Object { $_.source -eq 0 })[0]
    $lib = @($Actual.modules | Where-Object { $_.source -eq 1 })[0]
    $divisor = Node-At $Actual 1 103 'divisor As Long = 0'
    $failed = Node-At $Actual 1 103 'failed As Long = 42'
    $later = Node-At $Actual 1 103 'later As Long = failed + 7'
    $division = Node-At $Actual 1 5 '42 \ divisor'
    $failedRead = Node-At $Actual 1 3 'failed + 7'
    $addition = Node-At $Actual 1 5 'failed + 7'
    $appResult = Node-At $Actual 0 103 'result As Long = LibraryState.later + 1'
    $appRead = Node-At $Actual 0 3 'LibraryState.later + 1'
    $appAdd = Node-At $Actual 0 5 'LibraryState.later + 1'
    $d = $lib.values[$divisor]; $f = $lib.values[$failed]; $l = $lib.values[$later]
    $divide = $lib.values[$division]; $numerator = [int]$divide[6]
    if ($numerator -lt 0 -or $numerator -ge $lib.values.Count) { return $false }
    $denominator = [int]$lib.values[$numerator][7]
    if ($denominator -lt 0 -or $denominator -ge $lib.values.Count) { return $false }
    return ($lib.values[$lib.root][6] -eq $divisor -and $d[7] -eq $failed -and $f[7] -eq $later -and
        $f[6] -eq $division -and $divide[10] -eq 10 -and $divide[8] -eq 2 -and
        $lib.values[$numerator][2] -eq 1 -and $lib.values[$numerator][4] -eq 42 -and
        $lib.values[$denominator][2] -eq 3 -and $lib.values[$denominator][5] -eq $d[5] -and
        $l[6] -eq $addition -and $lib.values[$addition][6] -eq $failedRead -and $lib.values[$failedRead][5] -eq $f[5] -and
        $app.values[$appResult][6] -eq $appAdd -and $app.values[$appAdd][6] -eq $appRead -and $app.values[$appRead][5] -eq $l[5])
}
$firstOutput = $null
foreach ($jobs in @(1, 4)) {
    $output = @(& (Resolve-Path -LiteralPath $Observer).Path --project ([IO.Path]::GetFullPath($project)) $jobs 2>&1)
    if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw "Observer transport failed at jobs $jobs" }
    if ($null -ne $firstOutput -and $firstOutput -cne $output[0]) { throw 'Graph differs across worker counts' }
    $firstOutput = $output[0]
    $actual = $output[0] | ConvertFrom-Json
    if (-not (Check-Graph $actual)) { throw "Project graph mismatch at jobs $jobs" }
    foreach ($kind in @('operator', 'order', 'reference')) {
        $mutated = $actual | ConvertTo-Json -Depth 30 | ConvertFrom-Json
        $lib = @($mutated.modules | Where-Object { $_.source -eq 1 })[0]
        $app = @($mutated.modules | Where-Object { $_.source -eq 0 })[0]
        if ($kind -eq 'operator') { $node = Node-At $mutated 1 5 '42 \ divisor'; $lib.values[$node][10] = 8 }
        elseif ($kind -eq 'order') { $node = Node-At $mutated 1 103 'failed As Long = 42'; $lib.values[$node][7] = -1 }
        else { $node = Node-At $mutated 0 3 'LibraryState.later + 1'; $app.values[$node][5] = -1 }
        if (Check-Graph $mutated) { throw "Wrong $kind mutation accepted" }
    }
}
Write-Output 'Reference-error project graph passed at jobs 1/4; operator, order and cross-project mutations rejected.'
