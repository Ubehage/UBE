param(
    [string]$GrammarPath = (Join-Path $PSScriptRoot '..\grammar\ube.ebnf'),
    [string]$ConditionalGrammarPath = (
        Join-Path $PSScriptRoot '..\grammar\conditional-compilation.ebnf'
    )
)

$ErrorActionPreference = 'Stop'

try {
    $resolved = Resolve-Path -LiteralPath $GrammarPath -ErrorAction Stop
    $grammar = Get-Content -LiteralPath $resolved -Raw -ErrorAction Stop

    $withoutComments = [regex]::Replace($grammar, '\(\*[\s\S]*?\*\)', ' ')
    $withoutStrings = [regex]::Replace($withoutComments, '"(?:[^"]|"")*"', ' ')
    $definitions = @([regex]::Matches(
        $withoutStrings,
        '(?m)^([a-z][a-z0-9-]*)\s*='
    ) | ForEach-Object { $_.Groups[1].Value })

    if ($definitions.Count -eq 0) {
        throw 'No EBNF production definitions were found.'
    }

    $duplicates = @($definitions | Group-Object | Where-Object Count -gt 1)
    if ($duplicates.Count -ne 0) {
        throw "Duplicate productions: $($duplicates.Name -join ', ')."
    }

    $references = @([regex]::Matches(
        $withoutStrings,
        '\b[a-z][a-z0-9-]*\b'
    ) | ForEach-Object { $_.Value } | Sort-Object -Unique)
    $undefined = @($references | Where-Object { $_ -notin $definitions })
    if ($undefined.Count -ne 0) {
        throw "Undefined nonterminals: $($undefined -join ', ')."
    }

    $definedScannerTokens = @(
        'HSPACE', 'NEWLINE', 'EOF', 'LETTER', 'LINE_CHAR', 'COMMENT_TEXT',
        'STRING_TEXT', 'DATE_TEXT', 'REAL_TEXT', 'BRACKET_IDENTIFIER_TEXT',
        'KEYWORD'
    )
    $scannerReferences = @([regex]::Matches(
        $withoutStrings,
        '\b[A-Z][A-Z0-9_]*\b'
    ) | ForEach-Object { $_.Value } | Sort-Object -Unique)
    $unknownScannerTokens = @($scannerReferences | Where-Object {
        $_ -notin $definedScannerTokens
    })
    if ($unknownScannerTokens.Count -ne 0) {
        throw "Undefined scanner tokens: $($unknownScannerTokens -join ', ')."
    }

    # Every production must contribute to a complete program. This catches
    # stale rules that remain syntactically well formed but can never be used.
    $productionMatches = [regex]::Matches(
        $withoutStrings,
        '(?ms)^([a-z][a-z0-9-]*)\s*=\s*(.*?);'
    )
    $edges = @{}
    foreach ($match in $productionMatches) {
        $name = $match.Groups[1].Value
        $body = $match.Groups[2].Value
        $edges[$name] = @([regex]::Matches(
            $body,
            '\b[a-z][a-z0-9-]*\b'
        ) | ForEach-Object { $_.Value } | Where-Object {
            $_ -in $definitions
        } | Sort-Object -Unique)
    }

    $reachable = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal
    )
    $pending = [System.Collections.Generic.Queue[string]]::new()
    $pending.Enqueue('program')
    while ($pending.Count -ne 0) {
        $name = $pending.Dequeue()
        if (-not $reachable.Add($name)) {
            continue
        }
        foreach ($target in $edges[$name]) {
            if (-not $reachable.Contains($target)) {
                $pending.Enqueue($target)
            }
        }
    }

    $unreachable = @($definitions | Where-Object {
        -not $reachable.Contains($_)
    })
    if ($unreachable.Count -ne 0) {
        throw "Unreachable productions: $($unreachable -join ', ')."
    }

    foreach ($pair in @(@('(', ')'), @('[', ']'), @('{', '}'))) {
        $open = ([regex]::Matches($withoutStrings, [regex]::Escape($pair[0]))).Count
        $close = ([regex]::Matches($withoutStrings, [regex]::Escape($pair[1]))).Count
        if ($open -ne $close) {
            throw "Unbalanced $($pair[0]) $($pair[1]) delimiters: $open and $close."
        }
    }

    $requiredProductions = @(
        'native-source-header', 'designer-property-block',
        'interface-declaration', 'event-variable-declaration',
        'property-get-header', 'property-let-header', 'property-set-header',
        'sub-function-modifiers', 'property-modifiers',
        'named-argument', 'me-expression',
        'call-new-expression', 'call-new-statement', 'sync-lock-statement',
        'array-specifier'
    )
    $missingProductions = @($requiredProductions | Where-Object {
        $_ -notin $definitions
    })
    if ($missingProductions.Count -ne 0) {
        throw "Missing UBE 1.0 productions: $($missingProductions -join ', ')."
    }

    $requiredLiterals = @(
        'UBE', 'SOURCE', 'UBE_Name', 'Export', 'Interface', 'WithEvents', 'Me',
        'CallNew', 'SyncLock', 'AndAlso', 'OrElse', 'IsNot'
    )
    $missingLiterals = @($requiredLiterals | Where-Object {
        $grammar -notmatch ('"' + [regex]::Escape($_) + '"')
    })
    if ($missingLiterals.Count -ne 0) {
        throw "Missing UBE 1.0 grammar literals: $($missingLiterals -join ', ')."
    }

    # Conditional compilation is a preprocessing grammar. It deliberately
    # imports lexical productions from the core grammar and has its own root,
    # so validate its local graph separately rather than pretending it is part
    # of `program`.
    $conditionalResolved = Resolve-Path -LiteralPath $ConditionalGrammarPath `
        -ErrorAction Stop
    $conditionalGrammar = Get-Content -LiteralPath $conditionalResolved -Raw `
        -ErrorAction Stop
    $conditionalWithoutComments = [regex]::Replace(
        $conditionalGrammar,
        '\(\*[\s\S]*?\*\)',
        ' '
    )
    $conditionalWithoutStrings = [regex]::Replace(
        $conditionalWithoutComments,
        '"(?:[^"]|"")*"',
        ' '
    )
    $conditionalDefinitions = @([regex]::Matches(
        $conditionalWithoutStrings,
        '(?m)^([a-z][a-z0-9-]*)\s*='
    ) | ForEach-Object { $_.Groups[1].Value })

    if ($conditionalDefinitions.Count -eq 0) {
        throw 'No conditional-compilation EBNF productions were found.'
    }

    $conditionalDuplicates = @(
        $conditionalDefinitions | Group-Object | Where-Object Count -gt 1
    )
    if ($conditionalDuplicates.Count -ne 0) {
        throw "Duplicate conditional-compilation productions: $($conditionalDuplicates.Name -join ', ')."
    }

    $conditionalReferences = @([regex]::Matches(
        $conditionalWithoutStrings,
        '\b[a-z][a-z0-9-]*\b'
    ) | ForEach-Object { $_.Value } | Sort-Object -Unique)
    $conditionalUndefined = @($conditionalReferences | Where-Object {
        $_ -notin $conditionalDefinitions -and $_ -notin $definitions
    })
    if ($conditionalUndefined.Count -ne 0) {
        throw "Undefined conditional-compilation nonterminals: $($conditionalUndefined -join ', ')."
    }

    $conditionalScannerReferences = @([regex]::Matches(
        $conditionalWithoutStrings,
        '\b[A-Z][A-Z0-9_]*\b'
    ) | ForEach-Object { $_.Value } | Sort-Object -Unique)
    $conditionalUnknownScannerTokens = @(
        $conditionalScannerReferences | Where-Object {
            $_ -notin $definedScannerTokens
        }
    )
    if ($conditionalUnknownScannerTokens.Count -ne 0) {
        throw "Undefined conditional-compilation scanner tokens: $($conditionalUnknownScannerTokens -join ', ')."
    }

    $conditionalProductionMatches = [regex]::Matches(
        $conditionalWithoutStrings,
        '(?ms)^([a-z][a-z0-9-]*)\s*=\s*(.*?);'
    )
    $conditionalEdges = @{}
    foreach ($match in $conditionalProductionMatches) {
        $name = $match.Groups[1].Value
        $body = $match.Groups[2].Value
        $conditionalEdges[$name] = @([regex]::Matches(
            $body,
            '\b[a-z][a-z0-9-]*\b'
        ) | ForEach-Object { $_.Value } | Where-Object {
            $_ -in $conditionalDefinitions
        } | Sort-Object -Unique)
    }

    $conditionalReachable = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal
    )
    $conditionalPending = [System.Collections.Generic.Queue[string]]::new()
    $conditionalPending.Enqueue('conditional-directive')
    while ($conditionalPending.Count -ne 0) {
        $name = $conditionalPending.Dequeue()
        if (-not $conditionalReachable.Add($name)) {
            continue
        }
        foreach ($target in $conditionalEdges[$name]) {
            if (-not $conditionalReachable.Contains($target)) {
                $conditionalPending.Enqueue($target)
            }
        }
    }

    $conditionalUnreachable = @($conditionalDefinitions | Where-Object {
        -not $conditionalReachable.Contains($_)
    })
    if ($conditionalUnreachable.Count -ne 0) {
        throw "Unreachable conditional-compilation productions: $($conditionalUnreachable -join ', ')."
    }

    foreach ($pair in @(@('(', ')'), @('[', ']'), @('{', '}'))) {
        $open = ([regex]::Matches(
            $conditionalWithoutStrings,
            [regex]::Escape($pair[0])
        )).Count
        $close = ([regex]::Matches(
            $conditionalWithoutStrings,
            [regex]::Escape($pair[1])
        )).Count
        if ($open -ne $close) {
            throw "Unbalanced conditional-compilation $($pair[0]) $($pair[1]) delimiters: $open and $close."
        }
    }

    $requiredConditionalProductions = @(
        'conditional-directive', 'const-directive', 'if-directive',
        'elseif-directive', 'else-directive', 'end-if-directive',
        'conditional-expression'
    )
    $missingConditionalProductions = @(
        $requiredConditionalProductions | Where-Object {
            $_ -notin $conditionalDefinitions
        }
    )
    if ($missingConditionalProductions.Count -ne 0) {
        throw "Missing conditional-compilation productions: $($missingConditionalProductions -join ', ')."
    }

    $requiredConditionalLiterals = @(
        '#Const', '#If', '#ElseIf', '#Else', '#End', 'Then'
    )
    $missingConditionalLiterals = @(
        $requiredConditionalLiterals | Where-Object {
            $conditionalGrammar -notmatch ('"' + [regex]::Escape($_) + '"')
        }
    )
    if ($missingConditionalLiterals.Count -ne 0) {
        throw "Missing conditional-compilation literals: $($missingConditionalLiterals -join ', ')."
    }

    Write-Output (
        "UBE grammar validation passed: $($definitions.Count) core productions; " +
        "$($conditionalDefinitions.Count) conditional-compilation productions."
    )
    exit 0
}
catch {
    Write-Error "UBE grammar validation failed: $($_.Exception.Message)"
    exit 1
}
