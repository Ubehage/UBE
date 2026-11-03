param([Parameter(Mandatory=$true)][string] $Observer, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$source = Join-Path $PSScriptRoot 'reference-init-order/LibraryState.bas'
$library = [IO.File]::ReadAllText($source)
if ([Text.Encoding]::UTF8.GetByteCount($library) -ne $library.Length) { throw 'Fixture must remain ASCII' }
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$synthetic = Join-Path $directory 'LibraryState.bas'
[IO.File]::WriteAllText($synthetic, $library + "`nFunction Main() As Long`n    Main = second`nEnd Function`n")
$output = @(& (Resolve-Path -LiteralPath $Observer).Path $synthetic 2>&1)
if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw 'Observer transport failed' }
$actual = $output[0] | ConvertFrom-Json
if (-not $actual.setup -or -not $actual.ok) { throw 'Semantic observation failed' }
function Node-At($Actual, [int] $kind, [string] $anchor) {
    $start = $library.IndexOf($anchor, [StringComparison]::Ordinal)
    if ($start -lt 0) { throw 'Missing source anchor' }
    $ids = @(for ($i = 0; $i -lt $Actual.values.Count; $i++) {
        $node = $Actual.values[$i]; $syntax = $Actual.syntax[$node[1]]
        if ($node[2] -eq $kind -and $syntax[1] -eq $start) { $i }
    })
    if ($ids.Count -ne 1) { throw "Ambiguous node: $anchor" }
    return [int]$ids[0]
}
function Check-Graph($Actual) {
    $first = Node-At $Actual 103 'first As Long = 3'
    $second = Node-At $Actual 103 'second As Long = first + 4'
    $sum = Node-At $Actual 5 'first + 4'
    $read = Node-At $Actual 3 'first + 4'
    $a = $Actual.values[$first]; $b = $Actual.values[$second]; $sumNode = $Actual.values[$sum]
    $initial = [int]$a[6]; $other = [int]$Actual.values[$read][7]
    if ($initial -lt 0 -or $initial -ge $Actual.values.Count -or $other -lt 0 -or $other -ge $Actual.values.Count) { return $false }
    return ($Actual.values[0][6] -eq $first -and $a[7] -eq $second -and $a[3] -eq 4 -and $b[3] -eq 4 -and
        $a[5] -ge 0 -and $b[5] -ge 0 -and $a[5] -ne $b[5] -and $Actual.values[$initial][2] -eq 1 -and $Actual.values[$initial][4] -eq 3 -and
        $b[6] -eq $sum -and $sumNode[3] -eq 4 -and $sumNode[8] -eq 2 -and $sumNode[10] -eq 12 -and $sumNode[6] -eq $read -and
        $Actual.values[$read][5] -eq $a[5] -and $Actual.values[$other][2] -eq 1 -and $Actual.values[$other][4] -eq 4 -and $Actual.values[$other][7] -eq -1)
}
if (-not (Check-Graph $actual)) { throw 'Library declaration graph mismatch' }
$mutation = $actual | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$first = Node-At $mutation 103 'first As Long = 3'; $mutation.values[$first][7] = -1
if (Check-Graph $mutation) { throw 'Wrong declaration order accepted' }
$mutation = $actual | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$read = Node-At $mutation 3 'first + 4'; $mutation.values[$read][5] = -1
if (Check-Graph $mutation) { throw 'Wrong reference target accepted' }
Write-Output "Synthetic single-module graph passed; wrong order and target rejected: $directory"
