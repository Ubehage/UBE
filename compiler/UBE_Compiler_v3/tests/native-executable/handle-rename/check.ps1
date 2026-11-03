param([Parameter(Mandatory = $true)][string] $Probe, [Parameter(Mandatory = $true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$root = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($root) | Out-Null
$directory = Join-Path $root ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$candidate = Join-Path $directory 'candidate.bin'
$destination = Join-Path $directory 'destination.bin'
function Write-Text([string] $Path, [string] $Value) { [IO.File]::WriteAllText($Path, $Value) }
function Assert-Text([string] $Path, [string] $Value) { if (-not [IO.File]::Exists($Path) -or [IO.File]::ReadAllText($Path) -cne $Value) { throw "Wrong bytes: $Path" } }
Write-Text $candidate 'new'
Write-Text $destination 'old'
& $probePath $directory absolute | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Existing rename failed' }
Assert-Text $destination 'new'
if ([IO.File]::Exists($candidate)) { throw 'Candidate remains after rename' }
[IO.File]::Delete($destination)
Write-Text $candidate 'created'
& $probePath $directory absolute | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Absent rename failed' }
Assert-Text $destination 'created'
Write-Text $candidate 'locked-new'
Write-Text $destination 'locked-old'
$lock = [IO.File]::Open($destination, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
try {
    $ErrorActionPreference = 'Continue'
    $ignored = @(& $probePath $directory absolute 2>&1)
    $result = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
} finally { $ErrorActionPreference = 'Stop'; $lock.Dispose() }
if ($result -eq 0) { throw 'Locked destination unexpectedly replaced' }
Assert-Text $destination 'locked-old'
Assert-Text $candidate 'locked-new'
$ErrorActionPreference = 'Continue'
$relative = @(& $probePath $directory relative 2>&1 | ForEach-Object { "$_" })
$result = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($result -eq 0) { throw 'Relative-root observation unexpectedly succeeded; review host behavior' }
if (($relative -join "`n") -cnotmatch 'rename failed: 87') { throw "Unexpected relative-root failure: $relative" }
Assert-Text $destination 'locked-old'
Assert-Text $candidate 'locked-new'
& $probePath $directory native-relative | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Native relative-root rename failed' }
Assert-Text $destination 'locked-new'
if ([IO.File]::Exists($candidate)) { throw 'Native rename left candidate' }
[IO.File]::Delete($destination)
Write-Text $candidate 'native-created'
& $probePath $directory native-relative | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Native absent rename failed' }
Assert-Text $destination 'native-created'
Write-Text $candidate 'native-locked-new'
Write-Text $destination 'native-locked-old'
$lock = [IO.File]::Open($destination, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
try {
    $ErrorActionPreference = 'Continue'
    $ignored = @(& $probePath $directory native-relative 2>&1)
    $result = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
} finally { $ErrorActionPreference = 'Stop'; $lock.Dispose() }
if ($result -eq 0) { throw 'Native locked destination unexpectedly replaced' }
Assert-Text $destination 'native-locked-old'
Assert-Text $candidate 'native-locked-new'
$lock = [IO.File]::Open($destination, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
try {
    $actorDenied = $false
    try { [IO.File]::Move($destination, (Join-Path $directory 'blocked-swap.bin')) }
    catch [IO.IOException] { $actorDenied = $true }
    if (-not $actorDenied) { throw 'Destination unexpectedly moved under no-delete-share handle' }
    $ErrorActionPreference = 'Continue'
    $ignored = @(& $probePath $directory native-relative 2>&1)
    $result = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($result -eq 0) { throw 'Native replacement unexpectedly bypassed no-delete-share handle' }
} finally { $ErrorActionPreference = 'Stop'; $lock.Dispose() }
Assert-Text $destination 'native-locked-old'
Assert-Text $candidate 'native-locked-new'
Write-Output 'No-delete-share handle blocked both destination swap and native replacement.'
$posixControl = Join-Path $directory 'posix-control'
[IO.Directory]::CreateDirectory($posixControl) | Out-Null
Write-Text (Join-Path $posixControl 'candidate.bin') 'posix-new'
Write-Text (Join-Path $posixControl 'destination.bin') 'posix-old'
& $probePath $posixControl native-posix | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Extended rename unlocked control failed' }
Assert-Text (Join-Path $posixControl 'destination.bin') 'posix-new'
$lock = [IO.File]::Open($destination, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
try {
    $ErrorActionPreference = 'Continue'
    $posix = @(& $probePath $directory native-posix 2>&1 | ForEach-Object { "$_" })
    $posixResult = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
} finally { $ErrorActionPreference = 'Stop'; $lock.Dispose() }
if ($posixResult -eq 0) { throw 'Extended rename succeeded under lock; review this new outcome' }
Assert-Text $destination 'native-locked-old'
Assert-Text $candidate 'native-locked-new'
Write-Output "Extended rename under no-delete-share handle failed: $($posix -join ' ')"
$active = Join-Path $directory 'active'
$moved = Join-Path $directory 'moved'
[IO.Directory]::CreateDirectory($active) | Out-Null
Write-Text (Join-Path $active 'candidate.bin') 'anchored-new'
Write-Text (Join-Path $active 'destination.bin') 'anchored-old'
[IO.Directory]::Move($active, $moved)
[IO.Directory]::Move($moved, $active)
$id = [guid]::NewGuid().ToString('N')
$readyName = 'Local\UBE-rename-ready-' + $id
$releaseName = 'Local\UBE-rename-release-' + $id
$ready = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $readyName)
$release = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $releaseName)
$process = [Diagnostics.Process]::new()
try {
    $process.StartInfo.FileName = $probePath
    $process.StartInfo.Arguments = '"' + $active + '" native-relative ' + $readyName + ' ' + $releaseName
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    if (-not $process.Start()) { throw 'Race process did not start' }
    if (-not $ready.WaitOne(10000)) { throw 'Race readiness not observed' }
    $swapped = $false
    try { [IO.Directory]::Move($active, $moved); $swapped = $true }
    catch [IO.IOException] { Write-Output 'Directory move denied while probe handles are open.' }
    if ($swapped) {
        [IO.Directory]::CreateDirectory($active) | Out-Null
        Write-Text (Join-Path $active 'destination.bin') 'replacement-directory'
    }
    $release.Set() | Out-Null
    if (-not $process.WaitForExit(10000)) { throw 'Race process timed out' }
    if ($process.ExitCode -ne 0) { throw "Race rename failed: $($process.ExitCode)" }
    if ($swapped) {
        Assert-Text (Join-Path $active 'destination.bin') 'replacement-directory'
        Assert-Text (Join-Path $moved 'destination.bin') 'anchored-new'
    } else { Assert-Text (Join-Path $active 'destination.bin') 'anchored-new' }
} finally {
    $release.Set() | Out-Null
    if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
    $process.Dispose(); $ready.Dispose(); $release.Dispose()
}
$target = Join-Path $directory 'target-race'
[IO.Directory]::CreateDirectory($target) | Out-Null
Write-Text (Join-Path $target 'candidate.bin') 'race-new'
Write-Text (Join-Path $target 'destination.bin') 'checked-old'
$id = [guid]::NewGuid().ToString('N')
$readyName = 'Local\UBE-target-ready-' + $id
$releaseName = 'Local\UBE-target-release-' + $id
$ready = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $readyName)
$release = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $releaseName)
$process = [Diagnostics.Process]::new()
try {
    $process.StartInfo.FileName = $probePath
    $process.StartInfo.Arguments = '"' + $target + '" native-relative ' + $readyName + ' ' + $releaseName
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    if (-not $process.Start()) { throw 'Target-race process did not start' }
    if (-not $ready.WaitOne(10000)) { throw 'Target-race readiness not observed' }
    [IO.File]::Move((Join-Path $target 'destination.bin'), (Join-Path $target 'prior.bin'))
    Write-Text (Join-Path $target 'destination.bin') 'interloper'
    $release.Set() | Out-Null
    if (-not $process.WaitForExit(10000)) { throw 'Target-race process timed out' }
    if ($process.ExitCode -ne 0) { throw "Target-race rename failed: $($process.ExitCode)" }
    Assert-Text (Join-Path $target 'prior.bin') 'checked-old'
    Assert-Text (Join-Path $target 'destination.bin') 'race-new'
    Write-Output 'Target replacement after check was overwritten by native-relative rename.'
} finally {
    $release.Set() | Out-Null
    if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
    $process.Dispose(); $ready.Dispose(); $release.Dispose()
}
$target = Join-Path $directory 'hardlink-race'
[IO.Directory]::CreateDirectory($target) | Out-Null
Write-Text (Join-Path $target 'candidate.bin') 'race-new'
Write-Text (Join-Path $target 'destination.bin') 'checked-old'
Write-Text (Join-Path $target 'protected.bin') 'protected-input'
$id = [guid]::NewGuid().ToString('N')
$readyName = 'Local\UBE-link-ready-' + $id
$releaseName = 'Local\UBE-link-release-' + $id
$ready = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $readyName)
$release = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $releaseName)
$process = [Diagnostics.Process]::new()
try {
    $process.StartInfo.FileName = $probePath
    $process.StartInfo.Arguments = '"' + $target + '" native-relative ' + $readyName + ' ' + $releaseName
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    if (-not $process.Start()) { throw 'Hardlink-race process did not start' }
    if (-not $ready.WaitOne(10000)) { throw 'Hardlink-race readiness not observed' }
    [IO.File]::Move((Join-Path $target 'destination.bin'), (Join-Path $target 'prior.bin'))
    New-Item -ItemType HardLink -Path (Join-Path $target 'destination.bin') -Target (Join-Path $target 'protected.bin') | Out-Null
    $release.Set() | Out-Null
    if (-not $process.WaitForExit(10000)) { throw 'Hardlink-race process timed out' }
    if ($process.ExitCode -ne 0) { throw "Hardlink-race rename failed: $($process.ExitCode)" }
    Assert-Text (Join-Path $target 'prior.bin') 'checked-old'
    Assert-Text (Join-Path $target 'protected.bin') 'protected-input'
    Assert-Text (Join-Path $target 'destination.bin') 'race-new'
    Write-Output 'Hardlink substitution was replaced; protected peer bytes stayed intact.'
} finally {
    $release.Set() | Out-Null
    if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
    $process.Dispose(); $ready.Dispose(); $release.Dispose()
}
Write-Output "Passed absolute and native-relative rename checks; Win32 relative-root rename returned 87: $directory"
