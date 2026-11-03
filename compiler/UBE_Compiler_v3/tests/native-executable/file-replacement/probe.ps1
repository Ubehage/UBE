param([Parameter(Mandatory = $true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($root) | Out-Null
$base = Join-Path $root ([guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $base | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Put([string]$Path, [string]$Value) { [IO.File]::WriteAllText($Path, $Value, $utf8) }
function RequireText([string]$Path, [string]$Expected) {
    if (-not [IO.File]::Exists($Path) -or [IO.File]::ReadAllText($Path, $utf8) -cne $Expected) { throw "Unexpected contents: $Path" }
}
$old = Join-Path $base 'existing.bin'
$candidate = Join-Path $base 'candidate.bin'
Put $old 'old-sentinel'
Put $candidate 'new-candidate'
[IO.File]::Replace($candidate, $old, [NullString]::Value)
RequireText $old 'new-candidate'
if ([IO.File]::Exists($candidate)) { throw 'Replace left the source path.' }
Write-Output 'existing replacement: new bytes, candidate removed'
$absent = Join-Path $base 'absent.bin'
$candidate = Join-Path $base 'candidate2.bin'
Put $candidate 'created-candidate'
[IO.File]::Move($candidate, $absent)
RequireText $absent 'created-candidate'
if ([IO.File]::Exists($candidate)) { throw 'Move left the source path.' }
Write-Output 'absent destination: new bytes, candidate removed'
$locked = Join-Path $base 'locked.bin'
$candidate = Join-Path $base 'candidate3.bin'
Put $locked 'locked-old'
Put $candidate 'locked-new'
$handle = [IO.File]::Open($locked, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
$rejected = $false
try { try { [IO.File]::Replace($candidate, $locked, [NullString]::Value) } catch { $rejected = $true } }
finally { $handle.Dispose() }
if (-not $rejected) { throw 'Expected sharing denial was not observed.' }
RequireText $locked 'locked-old'
RequireText $candidate 'locked-new'
Write-Output 'locked destination: replacement rejected; both byte sequences preserved'
$protected = Join-Path $base 'protected.bin'
$race = Join-Path $base 'race.bin'
$candidate = Join-Path $base 'candidate4.bin'
Put $protected 'protected-original'
Put $race 'checked-old'
Put $candidate 'race-new'
# Simulate another actor changing the destination after a path-only check.
[IO.File]::Delete($race)
New-Item -ItemType HardLink -Path $race -Target $protected | Out-Null
[IO.File]::Replace($candidate, $race, [NullString]::Value)
RequireText $race 'race-new'
RequireText $protected 'protected-original'
Write-Output 'hardlink swap after initial check: unchecked replace proceeded; protected peer bytes unchanged'
Write-Output "fixtures: $base"
