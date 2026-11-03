$ErrorActionPreference = 'Stop'
function Match-Anchor($position, [int] $line, [int] $column, [int] $byte) {
    return $position.Line -eq $line -and $position.Column -eq $column -and $position.Byte -eq $byte
}
foreach ($case in @(@{ Name='initializer-cycle'; Line=3; Column=20 },
                     @{ Name='initializer-indirect-cycle'; Line=5; Column=13 })) {
    $path = Join-Path $PSScriptRoot ($case.Name + '/A.bas')
    $bytes = [IO.File]::ReadAllBytes($path)
    $text = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
    if ([Text.Encoding]::UTF8.GetByteCount($text) -ne $text.Length) { throw 'Fixture is not ASCII' }
    $start = $text.IndexOf('B.y', [StringComparison]::Ordinal)
    if ($start -lt 0 -or $text.IndexOf('B.y', $start + 1, [StringComparison]::Ordinal) -ge 0) { throw 'Expected exactly one B.y anchor' }
    $prefix = $text.Substring(0, $start)
    $position = @{
        Line = [regex]::Matches($prefix, "`n").Count + 1
        Column = $start - $prefix.LastIndexOf("`n", [StringComparison]::Ordinal)
        Byte = [Text.Encoding]::UTF8.GetByteCount($prefix)
    }
    if (-not (Match-Anchor $position $case.Line $case.Column $start) -or
        (Match-Anchor $position ($case.Line + 1) $case.Column $start) -or
        (Match-Anchor $position $case.Line ($case.Column + 1) $start) -or
        (Match-Anchor $position $case.Line $case.Column ($start + 1))) { throw "Anchor or comparator mismatch: $($case.Name)" }
    Write-Output "$($case.Name) : line=$($position.Line) column=$($position.Column) byte=$($position.Byte); altered positions rejected."
}
