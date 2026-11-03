param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$clang = (Resolve-Path -LiteralPath $Clang).Path
$valid = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'valid.ll')).Path
$invalid = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'invalid-dominance.ll')).Path
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$path = Join-Path $directory 'module.ll'; $moved = Join-Path $directory 'moved.ll'
[IO.File]::Copy($valid, $path)
[IO.File]::Move($path, $moved); [IO.File]::Move($moved, $path)
$writer = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite)
try {
    $guardDenied = $false
    try { $premature = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read); $premature.Dispose() } catch [IO.IOException] { $guardDenied = $true }
    if (-not $guardDenied) { throw 'Guard was acquired despite a pre-existing writer' }
} finally { $writer.Dispose() }
$guard = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
try {
    $writeBlocked = $false; $moveBlocked = $false
    try { $writer = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite); $writer.Dispose() } catch [IO.IOException] { $writeBlocked = $true }
    try { [IO.File]::Move($path, $moved) } catch [IO.IOException] { $moveBlocked = $true }
    if (-not $writeBlocked -or -not $moveBlocked -or -not [IO.File]::Exists($path)) { throw 'Guard did not block the controlled mutation' }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $heldHash = ([BitConverter]::ToString($sha.ComputeHash($guard))).Replace('-','') } finally { $sha.Dispose() }
    if ($heldHash -ne (Get-FileHash -LiteralPath $valid).Hash) { throw 'Held input differs from valid fixture' }
    $objects = @()
    foreach ($index in @(1,2)) {
        $output = Join-Path $directory "guarded-$index.o"
        & $clang --target=x86_64-w64-windows-gnu -O2 -Wno-override-module -Xclang -llvm-verify-each -c -x ir $path -o $output
        if ($LASTEXITCODE -ne 0 -or -not [IO.File]::Exists($output)) { throw 'Clang rejected guarded valid module' }
        $objects += (Get-FileHash -LiteralPath $output).Hash
    }
    if ((Get-FileHash -LiteralPath $path).Hash -ne $heldHash) { throw 'Guarded input changed' }
} finally { $guard.Dispose() }
[IO.File]::Move($path, $moved)
[IO.File]::Copy($invalid, $path)
$invalidObject = Join-Path $directory 'invalid.o'
$errorPath = Join-Path $directory 'invalid-error.txt'
$process = [Diagnostics.Process]::new()
$process.StartInfo.FileName = $clang
$process.StartInfo.Arguments = '--target=x86_64-w64-windows-gnu -O2 -Wno-override-module -Xclang -llvm-verify-each -c -x ir "' + $path + '" -o "' + $invalidObject + '"'
$process.StartInfo.UseShellExecute = $false; $process.StartInfo.CreateNoWindow = $true
$process.StartInfo.RedirectStandardOutput = $true; $process.StartInfo.RedirectStandardError = $true
try {
    if (-not $process.Start()) { throw 'Invalid-module control did not start' }
    $out = $process.StandardOutput.ReadToEndAsync(); $err = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit(); throw 'Invalid-module control timed out' }
    $diagnostic = $err.Result; [IO.File]::WriteAllText($errorPath, $diagnostic)
    if ($process.ExitCode -eq 0 -or $diagnostic -notmatch 'Instruction does not dominate all uses' -or [IO.File]::Exists($invalidObject)) { throw 'Invalid substituted module was not rejected' }
    $null = $out.Result
} finally { $process.Dispose() }
Write-Output "Pre-existing writer blocked guard; guard blocked writes and file-name moves; guarded IR compiled twice (object hashes equal=$($objects[0] -eq $objects[1])). After release, substituted invalid IR was rejected."
