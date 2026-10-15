[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$docsRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$failures = [System.Collections.Generic.List[string]]::new()

function Add-Failure([string] $Message) {
    $script:failures.Add($Message)
}

$htmlFiles = Get-ChildItem -LiteralPath $docsRoot -Recurse -Filter '*.html' -File
$articleIds = [System.Collections.Generic.List[string]]::new()
$articlePaths = [System.Collections.Generic.List[string]]::new()

foreach ($file in $htmlFiles) {
    $content = Get-Content -Raw -LiteralPath $file.FullName
    $relative = $file.FullName.Substring($docsRoot.Length).TrimStart('\')

    if ([regex]::Matches($content, '<main\b', 'IgnoreCase').Count -ne 1) {
        Add-Failure "$relative must contain exactly one main element."
    }
    if ($relative -ne 'index.html' -and [regex]::Matches($content, '<h1\b', 'IgnoreCase').Count -ne 1) {
        Add-Failure "$relative must contain exactly one h1 element."
    }
    if ($relative -ne 'index.html' -and $content -notmatch 'data-article-id="[^"]+"') {
        Add-Failure "$relative is missing a stable article ID."
    }
    elseif ($relative -ne 'index.html') {
        $articleId = [regex]::Match($content, 'data-article-id="([^"]+)"', 'IgnoreCase').Groups[1].Value
        $articleIds.Add($articleId)
        $articlePaths.Add($relative.Replace('\', '/'))
    }
    if ($relative -ne 'index.html' -and $content -notmatch 'class="skip-link"') {
        Add-Failure "$relative is missing a skip link."
    }
    if ($relative -ne 'index.html' -and $content -notmatch 'class="standalone-header"') {
        Add-Failure "$relative is missing the standalone article header."
    }
    if ($relative -ne 'index.html' -and $content -notmatch 'class="breadcrumbs"') {
        Add-Failure "$relative is missing breadcrumbs."
    }
    if ($relative -ne 'index.html' -and $content -notmatch 'class="article-footer"') {
        Add-Failure "$relative is missing the article footer."
    }
    if ($relative -ne 'index.html') {
        $statusMatch = [regex]::Match($content, '<span class="badge status">([^<]+)</span>', 'IgnoreCase')
        $allowedStatuses = @('Implemented', 'Partially implemented', 'Specified', 'Planned', 'Compatibility only', 'Deprecated', 'Unsupported')
        if (-not $statusMatch.Success) {
            Add-Failure "$relative is missing a public status label."
        }
        elseif ($statusMatch.Groups[1].Value -notin $allowedStatuses) {
            Add-Failure "$relative uses an unknown public status: $($statusMatch.Groups[1].Value)."
        }
        foreach ($stalePhrase in @(
            'UBE 1.0 draft',
            'Language definition 0.3',
            'Status verified against language definition 0.3',
            'rules are not yet frozen',
            'complete conversion table, ranges, rounding, and text rules are not yet frozen'
        )) {
            if ($content.IndexOf($stalePhrase, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                Add-Failure "$relative contains stale pre-1.0 wording: $stalePhrase."
            }
        }
    }

    foreach ($match in [regex]::Matches($content, '(?:href|src)="([^"]+)"', 'IgnoreCase')) {
        $target = $match.Groups[1].Value
        if ($target -match '^(?:https?:|//)') {
            Add-Failure "$relative uses external resource $target."
            continue
        }
        if ($target -match '^(?:#|data:|mailto:)') { continue }

        $cleanTarget = ($target -split '[#?]')[0]
        $resolved = [System.IO.Path]::GetFullPath((Join-Path $file.DirectoryName $cleanTarget))
        if (-not $resolved.StartsWith($docsRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            Add-Failure "$relative links outside docs: $target."
        }
        elseif (-not (Test-Path -LiteralPath $resolved)) {
            Add-Failure "$relative has a missing target: $target."
        }
    }
}

foreach ($duplicate in $articleIds | Group-Object | Where-Object Count -gt 1) {
    Add-Failure "Article ID is duplicated: $($duplicate.Name)."
}

$wordRoot = Join-Path $docsRoot 'language\words'
if (Test-Path -LiteralPath $wordRoot) {
    $wordPages = Get-ChildItem -LiteralPath $wordRoot -Recurse -Filter '*.html' -File |
        Where-Object { $_.Name -ne 'index.html' }
    foreach ($file in $wordPages) {
        $content = Get-Content -Raw -LiteralPath $file.FullName
        $relative = $file.FullName.Substring($docsRoot.Length).TrimStart('\')
        foreach ($required in @(
            'badge status', '<h2>Syntax</h2>', '<h2>Example</h2>',
            '<pre><code>', 'class="article-nav"'
        )) {
            if ($content -notlike "*$required*") {
                Add-Failure "$relative is missing required word-page content: $required."
            }
        }
    }

    $grammarPath = Join-Path $docsRoot '..\lang-doc\grammar\ube.ebnf'
    if (Test-Path -LiteralPath $grammarPath) {
        $grammar = Get-Content -Raw -LiteralPath $grammarPath
        $suffixFragments = @('a', 'b', 'c', 'd', 'e', 'f', 'i', 'l', 'r', 's', 'ui', 'ul', 'us')
        $expectedWords = [regex]::Matches($grammar, '"([A-Za-z][A-Za-z ]*)"') |
            ForEach-Object { $_.Groups[1].Value -split ' ' } |
            ForEach-Object { $_.ToLowerInvariant() } |
            Where-Object { $_ -and $_ -notin $suffixFragments } |
            Sort-Object -Unique
        $documentedWords = $wordPages | ForEach-Object {
            $content = Get-Content -Raw -LiteralPath $_.FullName
            $match = [regex]::Match($content, '<h1>([^<]+)</h1>', 'IgnoreCase')
            if ($match.Success) { $match.Groups[1].Value.ToLowerInvariant() }
        }
        foreach ($word in $expectedWords) {
            if ($word -notin $documentedWords) {
                Add-Failure "Grammar word has no A-Z article: $word."
            }
        }
    }
}

$requiredNormativeCoverage = @{
    'language/topics/conditional-compilation.html' = @('#Const', '#If', '#ElseIf', '#End If')
    'language/topics/scalar-values-operators.html' = @('96-bit unsigned coefficient', 'scale from 0 through 28', 'IntPtr', 'UIntPtr')
    'language/topics/event-binding.html' = @('WithEvents', 'Private Sub', 'Set Source = Nothing')
    'language/topics/procedures-parameters.html' = @('name := expression', 'ParamArray Values() As Variant', 'evaluated exactly once')
    'language/topics/data-values.html' = @('String * 0', '65,535-character', 'materializes automatically')
    'language/topics/properties-members.html' = @('one logical property', 'no Shared class-member surface', 'evaluated once')
    'tools/project-manifests.html' = @('Reference =', 'StartupForm', 'direct and non-transitive', 'not yet frozen')
    'migration/index.html' = @('DefBool', 'targeted migration diagnostic')
}
foreach ($coveragePath in $requiredNormativeCoverage.Keys) {
    $coverageFile = Join-Path $docsRoot $coveragePath
    if (-not (Test-Path -LiteralPath $coverageFile -PathType Leaf)) {
        Add-Failure "Required normative coverage article is missing: $coveragePath."
        continue
    }
    $coverageText = Get-Content -Raw -LiteralPath $coverageFile
    foreach ($requiredText in $requiredNormativeCoverage[$coveragePath]) {
        if ($coverageText.IndexOf($requiredText, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
            Add-Failure "$coveragePath is missing frozen-contract coverage: $requiredText."
        }
    }
}

$navigationFiles = @(
    (Join-Path $docsRoot 'assets\js\navigation-data.js'),
    (Join-Path $docsRoot 'assets\js\word-data.js')
)
$existingNavigationFiles = $navigationFiles | Where-Object { Test-Path -LiteralPath $_ }
if ($existingNavigationFiles.Count -gt 0) {
    $navigation = ($existingNavigationFiles | ForEach-Object { Get-Content -Raw -LiteralPath $_ }) -join "`n"
    $catalogPaths = [System.Collections.Generic.List[string]]::new()
    [regex]::Matches($navigation, 'path:\s*"([^"]+)"') |
        ForEach-Object { $catalogPaths.Add($_.Groups[1].Value) }

    $wordDataPath = Join-Path $docsRoot 'assets\js\word-data.js'
    if (Test-Path -LiteralPath $wordDataPath) {
        $wordData = Get-Content -Raw -LiteralPath $wordDataPath
        foreach ($groupMatch in [regex]::Matches(
            $wordData,
            '(?m)^\s*([a-z]):\s*\[([^\]]*)\]'
        )) {
            $letter = $groupMatch.Groups[1].Value
            $catalogPaths.Add("language/words/$letter/index.html")
            foreach ($wordMatch in [regex]::Matches(
                $groupMatch.Groups[2].Value,
                '"([^"]+)"'
            )) {
                $slug = $wordMatch.Groups[1].Value.ToLowerInvariant()
                $catalogPaths.Add("language/words/$letter/$slug.html")
            }
        }
    }
    foreach ($duplicate in $catalogPaths | Group-Object | Where-Object Count -gt 1) {
        Add-Failure "Navigation path is duplicated: $($duplicate.Name)."
    }
    foreach ($path in $catalogPaths) {
        if (-not (Test-Path -LiteralPath (Join-Path $docsRoot $path))) {
            Add-Failure "Navigation target is missing: $path."
        }
    }
    foreach ($articlePath in $articlePaths) {
        if ($articlePath -eq 'about/not-found.html') { continue }
        if ($articlePath -notin $catalogPaths) {
            Add-Failure "Article is not present in navigation: $articlePath."
        }
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "UBE documentation validation passed: $($htmlFiles.Count) HTML files."
