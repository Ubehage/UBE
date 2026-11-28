# Packages the ordered compiler sources without changing their bytes or claiming a self-build.
param(
    [Parameter(Mandatory=$true)][string]$Destination,
    [string[]]$AdditionalSources = @(),
    [ValidateSet('Library','Exe')][string]$Kind = 'Library',
    [ValidateSet('0','2')][string]$Optimization = '0',
    [ValidatePattern('^[A-Za-z_][A-Za-z0-9_]{0,127}$')][string]$Name = 'Compiler'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$encoding = New-Object Text.UTF8Encoding($false, $true)
$target = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $target) { throw "Package destination already exists: $target" }

# Rejects directory aliases so lexical containment also describes the written paths.
function Assert-PlainAncestors([string]$Path) {
    $parent = [IO.Path]::GetDirectoryName($Path)
    while ($parent) {
        if (Test-Path -LiteralPath $parent) {
            $item = Get-Item -LiteralPath $parent -Force
            if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                throw "Package destination has a non-directory or redirected ancestor: $parent"
            }
        }
        $parent = [IO.Path]::GetDirectoryName($parent)
    }
}

# Creates a file exclusively; an unexpected competing file is never overwritten.
function Write-NewBytes([string]$Path, [byte[]]$Bytes) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($Bytes, 0, $Bytes.Length) } finally { $stream.Dispose() }
}

Assert-PlainAncestors $target
# The checked-in project owns source identity and order; packages only relocate it.
$project = Join-Path $root 'compiler/Compiler.UBE'
$paths = @()
$projectSettings = @('UBE-Project 1','Name = "Compiler"','Kind = "Exe"','Optimization = "2"','Startup = "Main"')
$settingIndex = 0
foreach ($line in [IO.File]::ReadAllLines($project, $encoding)) {
    if ($line -match '^Source = "([^"\r\n]+)"$') {
        if ($settingIndex -ne $projectSettings.Count) { throw 'Compiler project sources must follow settings' }
        $relative = $Matches[1]
        if ([IO.Path]::IsPathRooted($relative)) { throw 'Compiler project source must be relative' }
        $absolute = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetDirectoryName($project)) $relative))
        if (-not $absolute.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Compiler project source escapes repository' }
        $paths += $absolute
    } elseif ($settingIndex -lt $projectSettings.Count -and $line -ceq $projectSettings[$settingIndex]) {
        $settingIndex++
    } elseif ($line.Trim().Length -ne 0 -and -not $line.TrimStart().StartsWith("'")) {
        throw 'Unsupported compiler project entry'
    }
}
if ($settingIndex -ne $projectSettings.Count) { throw 'Compiler project settings are incomplete' }
if ($paths.Count -eq 0) { throw 'Compiler project has no sources' }
foreach ($source in $AdditionalSources) {
    if ([string]::IsNullOrWhiteSpace($source)) { throw 'Additional source path is empty' }
    if ([IO.Path]::IsPathRooted($source)) { $paths += $source }
    else { $paths += Join-Path $root $source }
}

# Preflight every source and generated path before creating any package output.
$records = New-Object Collections.Generic.List[object]
$leaves = @{}
$prefix = $target.TrimEnd([char[]]@('\','/')) + [IO.Path]::DirectorySeparatorChar
foreach ($path in $paths) {
    $absolute = [IO.Path]::GetFullPath($path)
    $item = Get-Item -LiteralPath $absolute -Force
    if ($item.PSIsContainer -or $item.Extension -ine '.bas') { throw "Expected a .bas source file: $absolute" }
    $leaf = $item.Name
    if ($leaf -notmatch '^[A-Za-z_][A-Za-z0-9_.-]*\.bas$') { throw "Unsupported package source filename: $leaf" }
    if ($leaves.ContainsKey($leaf)) { throw "Duplicate package source filename: $leaf" }
    $leaves[$leaf] = $true
    $copy = [IO.Path]::GetFullPath((Join-Path $target $leaf))
    if (-not $copy.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Source escapes package destination: $leaf" }
    $records.Add([pscustomobject]@{ Index=$records.Count; OriginalPath=$absolute; RelativePath=$leaf; SHA256=(Get-FileHash -LiteralPath $absolute -Algorithm SHA256).Hash; Length=$item.Length })
}
$lines = @('UBE-Project 1', ('Name = "' + $Name + '"'), ('Kind = "' + $Kind + '"'), ('Optimization = "' + $Optimization + '"'))
if ($Kind -eq 'Exe') { $lines += 'Startup = "Main"' }
# Current compiler packages request no debug information; capability tests exercise unsupported requests.
$lines += 'DebugInformation = "None"'
foreach ($record in $records) { $lines += 'Source = "' + $record.RelativePath + '"' }
$manifestBytes = $encoding.GetBytes(($lines -join "`r`n") + "`r`n")
$ledger = @($records | ForEach-Object { $_.SHA256 + '  ' + $_.RelativePath })
$null = [IO.Directory]::CreateDirectory($target)
foreach ($record in $records) {
    $copy = Join-Path $target $record.RelativePath
    Write-NewBytes $copy ([IO.File]::ReadAllBytes($record.OriginalPath))
    if ((Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash -cne $record.SHA256) {
        throw "Source changed during packaging; incomplete package retained: $($record.OriginalPath)"
    }
}
Write-NewBytes (Join-Path $target 'sources.sha256') ($encoding.GetBytes(($ledger -join "`r`n") + "`r`n"))
# Every compiled consumer receives the ordinary target library, independent of explicit bootstrap sources.
$library = & (Join-Path $root 'std-lib/tools/package-library.ps1') -Destination (Join-Path $target 'library') -Target 'Windows-x64'
# The manifest is the completion artifact and is written only after all copies match.
$manifest = Join-Path $target 'Compiler.UBE'
Write-NewBytes $manifest $manifestBytes
[pscustomobject]@{ Destination=$target; Manifest=$manifest; ManifestSHA256=(Get-FileHash -LiteralPath $manifest -Algorithm SHA256).Hash; Sources=$records.ToArray(); LibraryManifest=$library.Manifest; LibrarySources=$library.Sources; LibraryManifests=$library.Manifests }
