param([Parameter(Mandatory=$true)][string] $Observer)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$directory = Join-Path $PSScriptRoot 'reference-init-order'
$project = Join-Path $directory 'ReferenceInitOrder.UBE'
$texts = @([IO.File]::ReadAllText((Join-Path $directory 'App.bas')), [IO.File]::ReadAllText((Join-Path $directory 'LibraryState.bas')))
foreach ($text in $texts) { if ([Text.Encoding]::UTF8.GetByteCount($text) -ne $text.Length) { throw 'Fixture must remain ASCII' } }
function Node-At($Actual, [int] $source, [int] $kind, [string] $anchor) {
    $start = $texts[$source].IndexOf($anchor, [StringComparison]::Ordinal)
    if ($start -lt 0) { throw "Missing source anchor: $anchor" }
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
    $library = @($Actual.modules | Where-Object { $_.source -eq 1 })[0]
    $first = Node-At $Actual 1 103 'first As Long = 3'
    $second = Node-At $Actual 1 103 'second As Long = first + 4'
    $libraryRead = Node-At $Actual 1 3 'first + 4'
    $libraryAdd = Node-At $Actual 1 5 'first + 4'
    $appResult = Node-At $Actual 0 103 'result As Long = LibraryState.second + 1'
    $appRead = Node-At $Actual 0 3 'LibraryState.second + 1'
    $appAdd = Node-At $Actual 0 5 'LibraryState.second + 1'
    $a = $library.values[$first]; $b = $library.values[$second]; $result = $app.values[$appResult]
    $initial = [int]$a[6]
    $libraryOther = [int]$library.values[$libraryRead][7]
    $appOther = [int]$app.values[$appRead][7]
    if ($initial -lt 0 -or $initial -ge $library.values.Count -or $libraryOther -lt 0 -or $libraryOther -ge $library.values.Count -or $appOther -lt 0 -or $appOther -ge $app.values.Count) { return $false }
    foreach ($pair in @(@($library, $a), @($library, $b), @($app, $result))) {
        $module = $pair[0]; $owner = $pair[1]; $factIndex = [int]$owner[10]
        if ($factIndex -lt 0 -or $factIndex -ge $module.facts.Count) { return $false }
        $fact = $module.facts[$factIndex]
        if ($fact[2] -ne 3 -or $fact[3] -ne 4 -or $fact[5] -ne $owner[5] -or $fact[6] -ne 4 -or $fact[7] -ne 4 -or $fact[1] -ne $module.values[$owner[6]][1]) { return $false }
    }
    return ($library.values[$library.root][6] -eq $first -and $a[7] -eq $second -and
        $app.values[$app.root][6] -eq $appResult -and
        $a[3] -eq 4 -and $b[3] -eq 4 -and $a[5] -ge 0 -and $b[5] -ge 0 -and $a[5] -ne $b[5] -and
        $library.values[$initial][2] -eq 1 -and $library.values[$initial][4] -eq 3 -and
        $b[6] -eq $libraryAdd -and $library.values[$libraryAdd][6] -eq $libraryRead -and $library.values[$libraryAdd][8] -eq 2 -and $library.values[$libraryAdd][10] -eq 12 -and $library.values[$libraryRead][5] -eq $a[5] -and
        $library.values[$libraryOther][2] -eq 1 -and $library.values[$libraryOther][4] -eq 4 -and $library.values[$libraryOther][7] -eq -1 -and
        $result[6] -eq $appAdd -and $app.values[$appAdd][6] -eq $appRead -and $app.values[$appAdd][8] -eq 2 -and $app.values[$appAdd][10] -eq 12 -and $app.values[$appRead][5] -eq $b[5] -and
        $app.values[$appOther][2] -eq 1 -and $app.values[$appOther][4] -eq 1 -and $app.values[$appOther][7] -eq -1)
}
$firstOutput = $null
foreach ($jobs in @(1, 4)) {
    $output = @(& (Resolve-Path -LiteralPath $Observer).Path --project ([IO.Path]::GetFullPath($project)) $jobs 2>&1)
    if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw "Observer transport failed at jobs $jobs" }
    if ($null -ne $firstOutput -and $firstOutput -cne $output[0]) { throw 'Graph differs across worker counts' }
    $firstOutput = $output[0]
    $actual = $output[0] | ConvertFrom-Json
    if (-not (Check-Graph $actual)) { throw "Project graph mismatch at jobs $jobs" }
    $mutated = $actual | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $app = @($mutated.modules | Where-Object { $_.source -eq 0 })[0]
    $read = Node-At $mutated 0 3 'LibraryState.second + 1'
    $app.values[$read][5] = -1
    if (Check-Graph $mutated) { throw 'Wrong cross-project target accepted' }
    $mutated = $actual | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $library = @($mutated.modules | Where-Object { $_.source -eq 1 })[0]
    $first = Node-At $mutated 1 103 'first As Long = 3'
    $library.values[$first][7] = -1
    if (Check-Graph $mutated) { throw 'Wrong library declaration order accepted' }
    $mutated = $actual | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $app = @($mutated.modules | Where-Object { $_.source -eq 0 })[0]
    $result = Node-At $mutated 0 103 'result As Long = LibraryState.second + 1'
    $app.facts[$app.values[$result][10]][5] = -1
    if (Check-Graph $mutated) { throw 'Wrong executable initializer conversion target accepted' }
    $mutated = $actual | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $library = @($mutated.modules | Where-Object { $_.source -eq 1 })[0]
    $read = Node-At $mutated 1 3 'first + 4'
    $library.values[$library.values[$read][7]][4] = 5
    if (Check-Graph $mutated) { throw 'Wrong library initializer operand accepted' }
}
Write-Output 'Actual project graph and jobs 1/4 comparison passed; four relationship and operand mutations rejected.'
