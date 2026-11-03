param([Parameter(Mandatory=$true)][string] $InputFile)
$ErrorActionPreference = 'Stop'
$unicodeData = Join-Path $PSScriptRoot '../../../../std-lib/data/unicode/18.0.0/DerivedGeneralCategory.txt'
$ranges = @(
    foreach ($line in [IO.File]::ReadLines([IO.Path]::GetFullPath($unicodeData))) {
        if ($line -match '^([0-9A-F]+)(?:\.\.([0-9A-F]+))?\s*;\s*Cf\b') {
            $first = [Convert]::ToInt32($Matches[1], 16)
            $last = if ($Matches[2]) { [Convert]::ToInt32($Matches[2], 16) } else { $first }
            ,@($first, $last)
        }
    }
)
if ($ranges.Count -eq 0) { throw 'No Unicode format ranges found' }
$all = [IO.File]::ReadAllBytes([IO.Path]::GetFullPath($InputFile))
$count = [Math]::Min($all.Length, 4096)
$builder = [Text.StringBuilder]::new()
for ($i = 0; $i -lt $count;) {
    $first = [int]$all[$i]
    $length = if ($first -lt 0x80) { 1 } elseif ($first -ge 0xC2 -and $first -le 0xDF) { 2 } elseif ($first -ge 0xE0 -and $first -le 0xEF) { 3 } elseif ($first -ge 0xF0 -and $first -le 0xF4) { 4 } else { 0 }
    $valid = $length -gt 0 -and $i + $length -le $count
    $scalar = if ($length -eq 1) { $first } elseif ($length -eq 2) { $first -band 0x1F } elseif ($length -eq 3) { $first -band 0x0F } else { $first -band 0x07 }
    if ($valid) {
        for ($j = 1; $j -lt $length; $j++) {
            $byte = [int]$all[$i + $j]
            if ($byte -lt 0x80 -or $byte -gt 0xBF) { $valid = $false; break }
            $scalar = ($scalar -shl 6) -bor ($byte -band 0x3F)
        }
        if (($length -eq 2 -and $scalar -lt 0x80) -or ($length -eq 3 -and $scalar -lt 0x800) -or
            ($length -eq 4 -and $scalar -lt 0x10000) -or ($scalar -ge 0xD800 -and $scalar -le 0xDFFF) -or $scalar -gt 0x10FFFF) { $valid = $false }
    }
    if (-not $valid) {
        [void]$builder.Append(('\x{0:X2}' -f $first)); $i++; continue
    }
    $format = $false
    foreach ($range in $ranges) { if ($scalar -ge $range[0] -and $scalar -le $range[1]) { $format = $true; break } }
    if ($scalar -eq 0x5C) { [void]$builder.Append('\\') }
    elseif ($scalar -lt 0x20 -or ($scalar -ge 0x7F -and $scalar -le 0x9F) -or $format -or $scalar -eq 0x2028 -or $scalar -eq 0x2029) {
        [void]$builder.Append(('\u{' + ('{0:X}' -f $scalar) + '}'))
    } else { [void]$builder.Append([char]::ConvertFromUtf32($scalar)) }
    $i += $length
}
@{ text = $builder.ToString(); truncated = $all.Length -gt 4096 } | ConvertTo-Json -Compress
