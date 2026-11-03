param([Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$source = Join-Path $directory 'source.bas'
$moved = Join-Path $directory 'moved.bas'
[IO.File]::WriteAllText($source, 'first source bytes')
$writer = [IO.File]::Open($source, [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
try {
    $denied = $false
    try { $unexpected = [IO.File]::Open($source, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read); $unexpected.Dispose() }
    catch [IO.IOException] { $denied = $true }
    if (-not $denied) { throw 'Guard admitted a pre-existing writer' }
} finally { $writer.Dispose() }
$guard = [IO.File]::Open($source, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
try {
    $reader = [IO.File]::Open($source, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
    try {
        $buffer = [byte[]]::new(128)
        $count = $reader.Read($buffer, 0, $buffer.Length)
        if ([Text.Encoding]::UTF8.GetString($buffer, 0, $count) -cne 'first source bytes') { throw 'Reader received incorrect bytes' }
    } finally { $reader.Dispose() }
    $writeDenied = $false
    try { $unexpected = [IO.File]::Open($source, [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete); $unexpected.Dispose() }
    catch [IO.IOException] { $writeDenied = $true }
    if (-not $writeDenied) { throw 'Guard allowed a new writer' }
    $moveDenied = $false
    try { [IO.File]::Move($source, $moved) } catch [IO.IOException] { $moveDenied = $true }
    if (-not $moveDenied) { throw 'Guard allowed moving the original name' }
    if ([IO.File]::ReadAllText($source) -cne 'first source bytes') { throw 'Source changed' }
} finally { $guard.Dispose() }
$after = [IO.File]::Open($source, [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
$after.Dispose()
[IO.File]::Move($source, $moved)
if ([IO.File]::ReadAllText($moved) -cne 'first source bytes') { throw 'Release control failed' }
Write-Output 'Pre-existing writer rejected; compatible reader succeeded; write and move blocked until guard release.'

$originalDirectory = Join-Path $directory 'original'
$replacementDirectory = Join-Path $directory 'replacement'
[IO.Directory]::CreateDirectory($originalDirectory) | Out-Null
[IO.Directory]::CreateDirectory($replacementDirectory) | Out-Null
[IO.File]::WriteAllText((Join-Path $originalDirectory 'source.bas'), 'original')
[IO.File]::WriteAllText((Join-Path $replacementDirectory 'source.bas'), 'replacement')
$junction = Join-Path $directory 'selected'
$oldJunction = Join-Path $directory 'old-selected'
New-Item -ItemType Junction -Path $junction -Target $originalDirectory | Out-Null
$selectedSource = Join-Path $junction 'source.bas'
$guard = [IO.File]::Open($selectedSource, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
try {
    [IO.Directory]::Move($junction, $oldJunction)
    New-Item -ItemType Junction -Path $junction -Target $replacementDirectory | Out-Null
    $reader = [IO.File]::Open($selectedSource, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
    try {
        $buffer = [byte[]]::new(64)
        $count = $reader.Read($buffer, 0, $buffer.Length)
        if ([Text.Encoding]::UTF8.GetString($buffer, 0, $count) -cne 'replacement') { throw 'Path substitution control did not reach replacement' }
    } finally { $reader.Dispose() }
    $guardBuffer = [byte[]]::new(64)
    $guardCount = $guard.Read($guardBuffer, 0, $guardBuffer.Length)
    if ([Text.Encoding]::UTF8.GetString($guardBuffer, 0, $guardCount) -cne 'original') { throw 'Guard no longer refers to original' }
} finally { $guard.Dispose() }
Write-Output 'Adverse control: a swapped parent junction redirected the separately opened reader while the original file guard remained held.'
