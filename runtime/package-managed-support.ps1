# Copies the reviewed ordinary UBE support closure and emits its installed manifest.
param([Parameter(Mandatory=$true)][string]$Destination)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$encoding = New-Object Text.UTF8Encoding($false, $true)
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$target = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $target) { throw "Support destination already exists: $target" }
$ancestor = [IO.Path]::GetDirectoryName($target)
while ($ancestor) {
    if (Test-Path -LiteralPath $ancestor) {
        $item = Get-Item -LiteralPath $ancestor -Force
        if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "Support destination has a redirected or non-directory ancestor: $ancestor"
        }
    }
    $ancestor = [IO.Path]::GetDirectoryName($ancestor)
}
$records = New-Object Collections.Generic.List[object]
$names = @{}
$entries = [IO.File]::ReadAllLines((Join-Path $PSScriptRoot 'managed-support-sources.txt'), $encoding)
foreach ($entry in $entries) {
    $entry = $entry.Trim()
    if (-not $entry -or $entry.StartsWith('#')) { continue }
    if ($entry -notmatch '^std-lib/src/portable/[A-Za-z_][A-Za-z0-9_]*\.bas$') {
        throw "Invalid managed support source entry: $entry"
    }
    $path = Join-Path $root $entry
    $item = Get-Item -LiteralPath $path -Force
    if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Expected an ordinary support source file: $path"
    }
    if ($names.ContainsKey($item.Name)) { throw "Duplicate managed support filename: $($item.Name)" }
    $names[$item.Name] = $true
    $bytes = [IO.File]::ReadAllBytes($path)
    $null = $encoding.GetString($bytes)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { $hash = [BitConverter]::ToString($hasher.ComputeHash($bytes)).Replace('-', '') } finally { $hasher.Dispose() }
    $records.Add([pscustomobject]@{Name=$item.Name;Bytes=$bytes;SHA256=$hash})
}
if ($records.Count -lt 1 -or $records.Count -gt 128) { throw 'Invalid managed support source count' }
$lines = @('UBE-Project 1', 'Name = "ManagedSupport"', 'Kind = "Library"')
foreach ($record in $records) { $lines += 'Source = "' + $record.Name + '"' }
$manifest = $encoding.GetBytes(($lines -join "`r`n") + "`r`n")
$ledger = $encoding.GetBytes(((@($records | ForEach-Object { $_.SHA256 + '  ' + $_.Name })) -join "`r`n") + "`r`n")
# Preflight completes before creating any output; every write refuses replacement.
$null = [IO.Directory]::CreateDirectory($target)
function Write-NewBytes([string]$Name, [byte[]]$Bytes) {
    $stream = [IO.File]::Open((Join-Path $target $Name), [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($Bytes, 0, $Bytes.Length) } finally { $stream.Dispose() }
}
foreach ($record in $records) { Write-NewBytes $record.Name $record.Bytes }
Write-NewBytes 'Managed.UBE' $manifest
Write-NewBytes 'sources.sha256' $ledger
[pscustomobject]@{Manifest=(Join-Path $target 'Managed.UBE');SourceCount=$records.Count;Ledger=(Join-Path $target 'sources.sha256')}
