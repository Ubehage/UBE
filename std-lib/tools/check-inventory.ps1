[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$libraryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $libraryRoot '..'))
$checklist = Get-Content -LiteralPath (Join-Path $libraryRoot 'inventory/reference-checklist.json') -Raw | ConvertFrom-Json
if ($checklist.format -cne 'ube-library-inventory-checklist-1') { throw 'Unknown inventory checklist format.' }
$documents = @('INVENTORY.md', 'inventory/vb6-runtime.md', 'inventory/ube-contract.md',
    'inventory/vb6-components.md', 'inventory/compiler-foundation.md')
$names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$runtimeNames = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$tableCounts = [ordered]@{}
$localLinks = 0

function Check-LocalLink([string]$DocumentPath, [string]$Target) {
    if ($Target -match '^(https?://|mailto:|#)') { return }
    $relative = ($Target -split '#', 2)[0].Trim('<', '>')
    if ($relative -eq '') { return }
    $resolved = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $DocumentPath) $relative))
    if (-not (Test-Path -LiteralPath $resolved)) { throw "Missing local inventory link: $DocumentPath -> $Target" }
    $script:localLinks++
}

foreach ($relative in $documents) {
    $path = Join-Path $libraryRoot $relative
    $contents = Get-Content -LiteralPath $path -Raw
    $lines = @(Get-Content -LiteralPath $path)
    $expectedCells = 0
    $rows = 0
    $keys = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $definitions = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($line in $lines) {
        if ($line -match '\s+$') { throw "Trailing whitespace in ${relative}: $line" }
        if ($line -match '^\[(?<key>[^\]]+)\]:\s*(?<target>\S+)') {
            [void]$definitions.Add($Matches.key)
            Check-LocalLink $path $Matches.target
        }
        if ($line -match '^\|\s*(Identifier|Capability)\s*\|') {
            $expectedCells = @($line.Trim().Trim('|') -split '(?<!\\)\|').Count
            continue
        }
        if ($line -notmatch '^\|') { $expectedCells = 0; continue }
        if ($expectedCells -eq 0 -or $line -match '^\|[\s:|-]+$') { continue }
        $cells = @($line.Trim().Trim('|') -split '(?<!\\)\|' | ForEach-Object { $_.Trim() })
        if ($cells.Count -ne $expectedCells -or @($cells | Where-Object { $_ -eq '' }).Count -ne 0) {
            throw "Malformed inventory table row in ${relative}: $line"
        }
        $key = $cells[0] + ' / ' + $cells[1]
        if (-not $keys.Add($key)) { throw "Duplicate identifier/kind in ${relative}: $key" }
        foreach ($match in [regex]::Matches($cells[0], '`([^`]+)`')) {
            $name = ($match.Groups[1].Value -split '\(', 2)[0].Trim()
            [void]$names.Add($name)
            if ($relative -eq 'inventory/vb6-runtime.md') { [void]$runtimeNames.Add($name) }
        }
        $rows++
    }
    foreach ($match in [regex]::Matches($contents, '\[[^\]\r\n]+\]\((?<target>[^)\r\n]+)\)')) {
        Check-LocalLink $path $match.Groups['target'].Value
    }
    foreach ($match in [regex]::Matches($contents, '\[[^\]\r\n]+\]\[(?<key>[^\]\r\n]+)\]')) {
        if (-not $definitions.Contains($match.Groups['key'].Value)) { throw "Undefined reference link in ${relative}: $($match.Value)" }
    }
    foreach ($match in [regex]::Matches($contents, '\[(?<key>[SU][0-9]+)\](?![:(\[])')) {
        if (-not $definitions.Contains($match.Groups['key'].Value)) { throw "Undefined source key in ${relative}: $($match.Value)" }
    }
    $tableCounts[$relative] = $rows
}

foreach ($name in $checklist.runtime_names) {
    if (-not $runtimeNames.Contains($name)) { throw "Missing runtime reference name: $name" }
}
foreach ($group in @('vba7_and_type_names', 'ube_api_names', 'component_names')) {
    foreach ($name in $checklist.$group) {
        if (-not $names.Contains($name)) { throw "Missing $group reference name: $name" }
    }
}
$hooks = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($relative in @('compiler/archived/UBE_Compiler_v3/BootstrapIntrinsics.bas',
    'archive/source-library/src/portable/RuntimeIntrinsics.bas',
    'compiler/archived/UBE_Compiler_v4/support/src/SupportIntrinsics.bas')) {
    $contents = Get-Content -LiteralPath (Join-Path $repositoryRoot $relative) -Raw
    foreach ($match in [regex]::Matches($contents, '(?im)^\s*(?:Public\s+|Private\s+)?Intrinsic\s+(?:Function|Sub)\s+(?<name>[A-Za-z][A-Za-z0-9_]*)')) {
        [void]$hooks.Add($match.Groups['name'].Value)
    }
}
foreach ($hook in $hooks) {
    if (-not $names.Contains($hook)) { throw "Missing historical intrinsic: $hook" }
}
$result = [ordered]@{
    result = 'passed'
    documents = $documents.Count
    inventory_rows = $tableCounts
    runtime_reference_names = $checklist.runtime_names.Count
    historical_intrinsic_names = $hooks.Count
    local_link_targets_checked = $localLinks
    scope = 'Named coverage, table structure, duplicate keys, link targets/references, and whitespace only; no implementation or complete UI/member parity claim.'
}
$result | ConvertTo-Json -Depth 4
