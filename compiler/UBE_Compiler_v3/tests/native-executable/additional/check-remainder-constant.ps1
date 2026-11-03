param([Parameter(Mandatory=$true)][string] $Observer)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'remainder-constant/App.bas'
$text = [IO.File]::ReadAllText($source)
if ([Text.Encoding]::UTF8.GetByteCount($text) -ne $text.Length) { throw 'Fixture must remain ASCII' }
$output = @(& (Resolve-Path -LiteralPath $Observer).Path $source 2>&1)
if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw 'Observer transport failed' }
$actual = $output[0] | ConvertFrom-Json
if (-not $actual.setup -or -not $actual.ok) { throw 'Semantic observation failed' }
$expression = '-2147483648 Mod -1'
$start = $text.IndexOf($expression, [StringComparison]::Ordinal)
function Check-Result($observed, $expected) {
    $found = @($observed.values | Where-Object {
        $syntax = $observed.syntax[$_[1]]
        $_[2] -eq 1 -and $_[3] -eq 4 -and $_[4] -eq $expected -and
        $syntax[1] -eq $start -and $syntax[2] -eq $start + $expression.Length
    })
    return $found.Count -eq 1
}
if ($start -lt 0 -or -not (Check-Result $actual 0)) { throw 'Expected folded Long zero not found' }
if (Check-Result $actual 1) { throw 'Wrong folded value accepted' }
Write-Output 'Observed folded Long zero and rejected wrong-value control.'
