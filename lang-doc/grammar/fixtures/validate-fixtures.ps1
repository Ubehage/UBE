param(
    [string]$IndexPath = (Join-Path $PSScriptRoot 'expectations.csv')
)

$ErrorActionPreference = 'Stop'

try {
    $resolvedIndex = Resolve-Path -LiteralPath $IndexPath -ErrorAction Stop
    $fixtureRoot = Split-Path -Parent $resolvedIndex
    $rows = @(Import-Csv -LiteralPath $resolvedIndex -ErrorAction Stop)

    if ($rows.Count -eq 0) {
        throw 'The fixture index is empty.'
    }

    $allowedCategories = @('positive', 'negative', 'ambiguity', 'recovery')
    $allowedGrammarResults = @('accept', 'reject')
    $allowedLaterResults = @('accept', 'reject', 'n/a')
    $indexed = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    foreach ($row in $rows) {
        $relative = [string]$row.file
        if ([string]::IsNullOrWhiteSpace($relative)) {
            throw 'A fixture index row has no file name.'
        }
        if ([System.IO.Path]::IsPathRooted($relative) -or $relative.Contains('..')) {
            throw "Unsafe fixture path in index: $relative"
        }
        if (-not $indexed.Add($relative.Replace('\', '/'))) {
            throw "Duplicate fixture index entry: $relative"
        }
        if ($row.category -notin $allowedCategories) {
            throw "Unknown fixture category '$($row.category)' for $relative."
        }
        if ($row.grammar_expected -notin $allowedGrammarResults) {
            throw "Unknown grammar result '$($row.grammar_expected)' for $relative."
        }
        if ($row.later_expected -notin $allowedLaterResults) {
            throw "Unknown later-phase result '$($row.later_expected)' for $relative."
        }
        if (-not $relative.Replace('\', '/').StartsWith("$($row.category)/")) {
            throw "Fixture $relative is not inside its category directory."
        }

        $path = Join-Path $fixtureRoot $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Indexed fixture does not exist: $relative"
        }
        $source = Get-Content -LiteralPath $path -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($source)) {
            throw "Fixture is empty: $relative"
        }

        if ($row.category -ne 'negative' -or $relative -ne 'negative/headerless.bas') {
            $hasNativeHeader = $source -match '(?im)^UBE[ \t]+SOURCE[ \t]+[0-9]+[ \t]+(MODULE|CLASS|FORM|CONTROL)[ \t]*$'
            $hasLegacyHeader = $source -match '(?im)^(VERSION|Object[ \t]*=|Reference[ \t]*=|Attribute[ \t]+VB_Name[ \t]*=)'
            if (-not $hasNativeHeader -and -not $hasLegacyHeader) {
                throw "Fixture has no recognizable complete-source header: $relative"
            }
        }

        if ($row.category -in @('negative', 'recovery') -and
            $source -notmatch 'INTENTIONAL-ERROR:') {
            throw "Rejected fixture has no INTENTIONAL-ERROR marker: $relative"
        }
        if ($row.category -eq 'ambiguity' -and
            $source -notmatch 'SEMANTIC-ERROR:') {
            throw "Ambiguity fixture has no SEMANTIC-ERROR marker: $relative"
        }
    }

    $fixtureRootFull = [System.IO.Path]::GetFullPath([string]$fixtureRoot).TrimEnd(
        [char[]]@('\', '/')
    )
    $sourceFiles = @(Get-ChildItem -LiteralPath $fixtureRoot -File -Recurse |
        Where-Object Extension -in @('.bas', '.cls', '.frm', '.ctl') |
        ForEach-Object {
            $fileFull = [System.IO.Path]::GetFullPath($_.FullName)
            $fileFull.Substring($fixtureRootFull.Length).TrimStart(
                [char[]]@('\', '/')
            ).Replace('\', '/')
        })
    $unindexed = @($sourceFiles | Where-Object { -not $indexed.Contains($_) })
    if ($unindexed.Count -ne 0) {
        throw "Unindexed fixtures: $($unindexed -join ', ')"
    }

    foreach ($category in $allowedCategories) {
        if (@($rows | Where-Object category -eq $category).Count -eq 0) {
            throw "Fixture category is empty: $category"
        }
    }

    $grammarValidator = Join-Path $fixtureRoot '..\..\tools\validate-grammar.ps1'
    & $grammarValidator
    if ($LASTEXITCODE -ne 0) {
        throw 'The normative grammar validator failed.'
    }

    Write-Output "UBE fixture validation passed: $($rows.Count) indexed fixtures in $($allowedCategories.Count) categories."
    exit 0
}
catch {
    Write-Error "UBE fixture validation failed: $($_.Exception.Message)"
    exit 1
}
