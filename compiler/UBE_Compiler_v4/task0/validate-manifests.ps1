param(
    [string[]]$Path = @((Join-Path $PSScriptRoot 'cases\format\minimal.case'))
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$requiredOrder = @(
    'Id', 'Task', 'Purpose', 'Compiler', 'Mode', 'Host', 'Target',
    'Expected.Exit', 'Expected.Artifact', 'Differential.Level', 'Repeat'
)
$repeated = @(
    'Category', 'Input.Source', 'Input.Project', 'Input.Resource',
    'Input.Library', 'Argument', 'LibrarySlice', 'Expected.Diagnostic',
    'Expected.Note', 'Expected.SideEffect', 'JobCount', 'Schedule', 'Limit',
    'Fault', 'CleanupAssertion'
)
$optional = @(
    'Expected.Stdout', 'Expected.Stderr', 'Expected.NativeResult',
    'Expected.ArtifactPath', 'Differential.Normalizer'
)
$categories = @(
    'Positive', 'Interaction', 'Rejection', 'Boundary', 'Stress', 'Failure',
    'Regression', 'Differential', 'Native', 'Determinism'
)
$notApplicable = @($categories | ForEach-Object { "NotApplicable.$_" })
$allKeys = @($requiredOrder + $repeated + $optional + $notApplicable)
$pathKeys = @('Input.Source', 'Input.Project', 'Input.Resource', 'Input.Library')

function Read-CaseString {
    param([string]$Text, [string]$Location)

    if ($Text.Length -lt 2 -or $Text[0] -ne '"' -or $Text[$Text.Length - 1] -ne '"') {
        throw "$Location`: expected a quoted string"
    }
    if ($Text -match '\\(?!["\\nrt])') {
        throw "$Location`: unsupported string escape"
    }
    try {
        $value = $Text | ConvertFrom-Json
    }
    catch {
        throw "$Location`: malformed quoted string"
    }
    if ($value -isnot [string]) {
        throw "$Location`: expected a string value"
    }
    return $value
}

function Test-CaseManifest {
    param([Parameter(Mandatory = $true)][string]$ManifestPath)

    $resolved = (Resolve-Path -LiteralPath $ManifestPath).Path
    $file = Get-Item -LiteralPath $resolved
    if ($file.Length -gt 1MB) {
        throw "$resolved`: manifest exceeds 1 MiB"
    }
    $lines = @(Get-Content -LiteralPath $resolved)
    if ($lines.Count -eq 0 -or $lines[0] -cne 'UBE-Test-Case 1') {
        throw "$resolved`:1: expected UBE-Test-Case 1"
    }

    $values = [ordered]@{}
    $fieldCount = 0
    $lastRequiredIndex = -1
    for ($lineIndex = 1; $lineIndex -lt $lines.Count; $lineIndex += 1) {
        $lineNumber = $lineIndex + 1
        $line = $lines[$lineIndex]
        if ($line.Length -gt 65536) {
            throw "$resolved`:$lineNumber`: line exceeds 65,536 code units"
        }
        if ($line.Length -eq 0 -or $line.StartsWith('#')) {
            continue
        }
        if ($line -notmatch '^([A-Za-z][A-Za-z0-9.]*) = (.+)$') {
            throw "$resolved`:$lineNumber`: expected Name = Value"
        }
        $name = $Matches[1]
        $raw = $Matches[2]
        if ($allKeys -cnotcontains $name) {
            throw "$resolved`:$lineNumber`: unknown field $name"
        }
        $fieldCount += 1
        if ($fieldCount -gt 4096) {
            throw "$resolved`: manifest exceeds 4,096 fields"
        }

        if ($raw -cmatch '^[0-9]+$') {
            $value = [UInt64]::Parse($raw, [Globalization.CultureInfo]::InvariantCulture)
        }
        else {
            $value = Read-CaseString -Text $raw -Location "$resolved`:$lineNumber"
        }

        if ($repeated -ccontains $name) {
            if (-not $values.Contains($name)) {
                $values[$name] = [Collections.Generic.List[object]]::new()
            }
            $values[$name].Add($value)
        }
        else {
            if ($values.Contains($name)) {
                throw "$resolved`:$lineNumber`: duplicate singleton field $name"
            }
            $values[$name] = $value
        }

        $requiredIndex = [Array]::IndexOf($requiredOrder, $name)
        if ($requiredIndex -ge 0) {
            if ($requiredIndex -le $lastRequiredIndex) {
                throw "$resolved`:$lineNumber`: required field $name is out of order"
            }
            $lastRequiredIndex = $requiredIndex
        }
    }

    foreach ($name in $requiredOrder) {
        if (-not $values.Contains($name)) {
            throw "$resolved`: missing required field $name"
        }
    }
    if ($values['Id'] -cnotmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
        throw "$resolved`: Id must use lowercase ASCII words separated by hyphens"
    }
    if ($values['Task'] -isnot [UInt64] -or $values['Task'] -gt 13) {
        throw "$resolved`: Task must be an integer from 0 through 13"
    }
    if ($values['Expected.Exit'] -isnot [UInt64] -or $values['Expected.Exit'] -gt 255) {
        throw "$resolved`: Expected.Exit must be an integer from 0 through 255"
    }
    if (@('required', 'absent', 'not-applicable') -cnotcontains $values['Expected.Artifact']) {
        throw "$resolved`: invalid Expected.Artifact value"
    }
    $hasArtifactPath = $values.Contains('Expected.ArtifactPath')
    if ($values['Expected.Artifact'] -ceq 'required' -and -not $hasArtifactPath) {
        throw "$resolved`: required artifacts must name Expected.ArtifactPath"
    }
    if ($values['Expected.Artifact'] -ceq 'not-applicable' -and $hasArtifactPath) {
        throw "$resolved`: not-applicable artifacts may not name Expected.ArtifactPath"
    }
    if ($values['Differential.Level'] -isnot [UInt64] -or $values['Differential.Level'] -gt 7) {
        throw "$resolved`: Differential.Level must be an integer from 0 through 7"
    }
    if ($values['Repeat'] -isnot [UInt64] -or $values['Repeat'] -lt 1) {
        throw "$resolved`: Repeat must be at least one"
    }

    $declaredCategories = @()
    if ($values.Contains('Category')) {
        $declaredCategories = @($values['Category'])
    }
    if (@($declaredCategories | Sort-Object -Unique).Count -ne $declaredCategories.Count) {
        throw "$resolved`: duplicate Category value"
    }
    foreach ($category in $categories) {
        $lower = $category.ToLowerInvariant()
        $isDeclared = $declaredCategories -ccontains $lower
        $reasonKey = "NotApplicable.$category"
        $hasReason = $values.Contains($reasonKey)
        if ($isDeclared -eq $hasReason) {
            throw "$resolved`: category $lower must be declared or have one not-applicable reason"
        }
    }
    foreach ($category in $declaredCategories) {
        if (@($categories | ForEach-Object { $_.ToLowerInvariant() }) -cnotcontains $category) {
            throw "$resolved`: invalid Category value $category"
        }
    }

    $caseDirectory = [IO.Path]::GetFullPath((Split-Path -Parent $resolved))
    foreach ($name in $pathKeys) {
        if (-not $values.Contains($name)) {
            continue
        }
        foreach ($relative in $values[$name]) {
            if ([IO.Path]::IsPathRooted($relative) -or $relative.Contains('\')) {
                throw "$resolved`: $name must be a relative path using /"
            }
            $candidate = [IO.Path]::GetFullPath((Join-Path $caseDirectory $relative))
            $prefix = $caseDirectory.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
            if (-not $candidate.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
                throw "$resolved`: $name escapes the case directory"
            }
            if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                throw "$resolved`: $name does not exist: $relative"
            }
        }
    }
    if ($hasArtifactPath) {
        $artifactPath = $values['Expected.ArtifactPath']
        if ([IO.Path]::IsPathRooted($artifactPath) -or $artifactPath.Contains('\') -or
            $artifactPath -match '(^|/)\.\.(/|$)') {
            throw "$resolved`: Expected.ArtifactPath must be a repository-relative path using /"
        }
        $repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $artifactAbsolute = [IO.Path]::GetFullPath((Join-Path $repoRoot $artifactPath))
        $artifactRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot 'bootstrap\out'))
        $artifactPrefix = $artifactRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        if (-not $artifactAbsolute.StartsWith($artifactPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "$resolved`: Expected.ArtifactPath must remain below bootstrap/out"
        }
    }

    [PSCustomObject]@{
        Id = $values['Id']
        Path = $resolved
        Fields = $fieldCount
    }
}

try {
    $seen = @{}
    $results = foreach ($manifest in @($Path | Sort-Object)) {
        $result = Test-CaseManifest -ManifestPath $manifest
        if ($seen.ContainsKey($result.Id)) {
            throw "Duplicate case Id $($result.Id): $($seen[$result.Id]) and $($result.Path)"
        }
        $seen[$result.Id] = $result.Path
        $result
    }
    $results | Sort-Object Id | Format-Table -AutoSize
    exit 0
}
catch {
    [Console]::Error.WriteLine("Task 0 manifest validation failed: $($_.Exception.Message)")
    exit 1
}
