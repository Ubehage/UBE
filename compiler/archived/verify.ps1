[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..')).TrimEnd('\')
$snapshot = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'snapshot.json') -Raw | ConvertFrom-Json
if ($snapshot.format -cne 'ube-compiler-archive-1') { throw 'Unknown compiler archive format.' }
if (Test-Path -LiteralPath (Join-Path $root 'boot')) { throw 'Unexpected boot directory remains.' }
$zipPath = Join-Path $root $snapshot.originals
if ((Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash -cne $snapshot.originals_sha256) {
    throw 'Original archive container hash differs.'
}
$zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
$relocationCount = 0
try {
    if ($zip.Entries.Count -ne $snapshot.file_count) { throw 'Original snapshot file count differs.' }
    foreach ($file in $snapshot.files) {
        $entry = $zip.GetEntry($file.original_path)
        if ($null -eq $entry -or $entry.Length -ne $file.bytes) { throw "Missing/different original: $($file.original_path)" }
        $stream = $entry.Open()
        $memory = [IO.MemoryStream]::new()
        try { $stream.CopyTo($memory); $original = $memory.ToArray() }
        finally { $stream.Dispose(); $memory.Dispose() }
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $originalHash = [BitConverter]::ToString($sha.ComputeHash($original)).Replace('-', '') }
        finally { $sha.Dispose() }
        if ($originalHash -cne $file.original_sha256) { throw "Original file hash differs: $($file.original_path)" }
        $path = [IO.Path]::GetFullPath((Join-Path $root $file.archived_path))
        if (-not $path.StartsWith($PSScriptRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Archived file escapes archive root.' }
        $actualHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        if ($actualHash -cne $file.archived_sha256) { throw "Archived file hash differs: $($file.archived_path)" }
        $changes = @($snapshot.relocation_changes | Where-Object path -EQ $file.archived_path)
        if ($changes.Count -gt 1) { throw 'Duplicate relocation record.' }
        if ($changes.Count -eq 1) {
            if ($file.archived_path -notmatch '^compiler/archived/UBE_Compiler_v[34]/.*\.(ps1|case|json)$') {
                throw 'Unexpected file kind changed during relocation.'
            }
            $expected = [Text.Encoding]::UTF8.GetString($original)
            foreach ($replacement in $changes[0].replacements) {
                if (-not $expected.Contains($replacement.before)) { throw "Relocation text not present in $($file.original_path)" }
                $expected = $expected.Replace($replacement.before, $replacement.after)
            }
            $sha = [Security.Cryptography.SHA256]::Create()
            try { $expectedHash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($expected))).Replace('-', '') }
            finally { $sha.Dispose() }
            if ($expectedHash -cne $actualHash) { throw "Changes exceed recorded relocation: $($file.archived_path)" }
            $relocationCount++
        } elseif ($actualHash -cne $originalHash) {
            throw "Unrecorded archive change: $($file.archived_path)"
        }
    }
} finally { $zip.Dispose() }

$actualFiles = @()
foreach ($directory in @('UBE_Compiler_v3', 'UBE_Compiler_v4', 'release-previews', 'compiler-history')) {
    $actualFiles += @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot $directory) -Recurse -Force -File)
}
if ($actualFiles.Count -ne $snapshot.file_count) { throw 'Archived tree file count differs.' }
foreach ($relative in $snapshot.directories) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relative) -PathType Container)) { throw "Archived directory missing: $relative" }
}

$previewCount = 0
$previewRoot = Join-Path $PSScriptRoot 'release-previews'
foreach ($line in (Get-Content -LiteralPath (Join-Path $previewRoot 'SHA256SUMS.txt'))) {
    if ($line -match '^(?<hash>[A-Fa-f0-9]{64})\s+(?<name>\S+\.exe)$') {
        $expectedHash = $Matches.hash
        $previewPath = Join-Path $previewRoot $Matches.name
        if ((Get-FileHash -LiteralPath $previewPath -Algorithm SHA256).Hash -ine $expectedHash) { throw "Preview ledger mismatch: $previewPath" }
        $previewCount++
    }
}
if ($previewCount -ne @(Get-ChildItem -LiteralPath $previewRoot -File -Filter '*.exe').Count) { throw 'Preview ledger file count differs.' }

$librarySnapshot = Get-Content -LiteralPath (Join-Path $root 'archive/source-library.snapshot.json') -Raw | ConvertFrom-Json
$libraryRoot = Join-Path $root $librarySnapshot.archive_path
if (@(Get-ChildItem -LiteralPath $libraryRoot -Recurse -Force -File).Count -ne $librarySnapshot.file_count) { throw 'Library archive count differs.' }
foreach ($file in $librarySnapshot.files) {
    $path = Join-Path $libraryRoot $file.path
    if ((Get-Item -LiteralPath $path).Length -ne $file.bytes -or
        (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $file.sha256) { throw "Library archive differs: $($file.path)" }
}

$manifestPaths = @('compiler/archived/UBE_Compiler_v3/UBE_Compiler_v3.UBE',
    'compiler/archived/UBE_Compiler_v3/UBE_Compiler_v3_seed.UBE',
    'compiler/archived/UBE_Compiler_v4/UBE_Compiler_v4.UBE',
    'compiler/archived/UBE_Compiler_v4/support/UBECompilerSupport.UBE',
    'archive/source-library/UBECore.UBE', 'std-lib/UBECore.UBE')
$sourceCount = 0
foreach ($relative in $manifestPaths) {
    $manifest = Join-Path $root $relative
    foreach ($line in (Get-Content -LiteralPath $manifest)) {
        if ($line -match '^(Source|Reference)\s*=\s*"(?<path>[^"]+)"\s*$') {
            $directory = Split-Path -Parent $manifest
            $target = [IO.Path]::GetFullPath((Join-Path $directory $Matches.path))
            if (-not $target.StartsWith($directory + '\', [StringComparison]::OrdinalIgnoreCase) -or
                -not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "Manifest input missing/escaping: $manifest -> $line" }
            $sourceCount++
        }
    }
}
$dependency = Join-Path $PSScriptRoot 'UBE_Compiler_v4/TASK1_DEPENDENCIES.json'
$dependencyText = Get-Content -LiteralPath $dependency -Raw
[void]($dependencyText | ConvertFrom-Json)
if ($dependencyText -notmatch '"manifest":\s*"(?<path>\.\./\.\./\.\./archive/source-library/UBECore\.UBE)"' -or
    -not (Test-Path -LiteralPath (Join-Path (Split-Path $dependency -Parent) $Matches.path))) { throw 'Archived dependency path differs.' }

$externalScripts = @('bootstrap/build.ps1', 'bootstrap/tools/measure-v3-performance.ps1',
    'bootstrap/tests/rp8_package_tests.ps1', 'std-lib/tools/check-inventory.ps1',
    'samples/01-hello-ube/tests/smoke.ps1')
$externalScripts += @(1..7 | ForEach-Object { "IDE/UBE-IDE/tests/run-step$_.ps1" })
$scripts = @($actualFiles | Where-Object Extension -EQ '.ps1') +
    @($externalScripts | ForEach-Object { Get-Item -LiteralPath (Join-Path $root $_) })
foreach ($script in $scripts) {
    $tokens = $null; $parseErrors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -ne 0) { throw "Script syntax error: $($script.FullName): $($parseErrors[0].Message)" }
    $contents = Get-Content -LiteralPath $script.FullName -Raw
    if ($contents -match '[''"]compiler[/\\](UBE_Compiler_v[34]|release-previews)([/\\]|[''"])') { throw "Stale historical script path: $($script.FullName)" }
    foreach ($match in [regex]::Matches($contents, 'Join-Path \$(PSScriptRoot|taskRoot|v4Root) ''(?<path>\.\.(?:\\\.\.)+)''')) {
        $base = $script.DirectoryName
        if ($match.Groups[1].Value -eq 'v4Root') { $base = Split-Path -Parent $base }
        if ([IO.Path]::GetFullPath((Join-Path $base $match.Groups['path'].Value)).TrimEnd('\') -ine $root) {
            throw "Incorrect repository-root depth in $($script.FullName)"
        }
    }
}
$fresh = Join-Path $root 'compiler/UBE_Compiler_v3'
if (@(Get-ChildItem -LiteralPath $fresh -Recurse -File | Where-Object Extension -IN @('.bas', '.cls', '.UBE')).Count -ne 0) {
    throw 'Unexpected fresh production scaffold before its prerequisite proof.'
}
foreach ($name in @('README.md', 'AGENTS.md', 'DESIGN.md', 'Roadmap.md', 'Progress.md')) {
    if (-not (Test-Path -LiteralPath (Join-Path $fresh $name) -PathType Leaf)) { throw "Fresh compiler document missing: $name" }
}

[ordered]@{
    result = 'passed'
    original_and_archived_files = $snapshot.file_count
    relocation_only_files = $relocationCount
    immutable_source_and_other_files = $snapshot.file_count - $relocationCount
    preview_hashes = $previewCount
    previous_library_files = $librarySnapshot.file_count
    manifests = $manifestPaths.Count
    resolved_manifest_inputs = $sourceCount
    powershell_scripts = $scripts.Count
    new_compiler_implementation = 'none; design and workplans only'
    compiler_or_runtime_gates_run = $false
} | ConvertTo-Json
