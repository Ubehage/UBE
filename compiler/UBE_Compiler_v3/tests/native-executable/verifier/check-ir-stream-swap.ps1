param([Parameter(Mandatory=$true)][string] $Clang, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$clangPath = (Resolve-Path -LiteralPath $Clang).Path
$valid = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'valid.ll')).Path
$invalid = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'invalid-dominance.ll')).Path
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$candidate = Join-Path $directory 'module.ll'; $moved = Join-Path $directory 'moved.ll'
[IO.File]::Copy($valid, $candidate)
$expectedHash = (Get-FileHash -LiteralPath $valid -Algorithm SHA256).Hash
$guard = [IO.File]::Open($candidate, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::Read -bor [IO.FileShare]::Delete))
function Run-Clang([IO.Stream] $inputStream, [string] $name) {
    $outputFile = Join-Path $directory "$name.o"
    $process = [Diagnostics.Process]::new()
    $process.StartInfo.FileName = $clangPath
    $process.StartInfo.Arguments = '--target=x86_64-w64-windows-gnu -O2 -Wno-override-module -Xclang -llvm-verify-each -c -x ir - -o "' + $outputFile + '"'
    $process.StartInfo.UseShellExecute = $false; $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardInput = $true; $process.StartInfo.RedirectStandardOutput = $true; $process.StartInfo.RedirectStandardError = $true
    if (-not $process.Start()) { throw 'Clang did not start' }
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
        $copy = $inputStream.CopyToAsync($process.StandardInput.BaseStream)
        if (-not $copy.Wait(10000)) { $process.Kill(); $process.WaitForExit(); throw 'Input streaming timed out' }
        $process.StandardInput.Close()
        if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit(); throw 'Clang timed out' }
        return @{ status=$process.ExitCode; stderr=$stderr.Result; stdout=$stdout.Result; output=$outputFile }
    } finally {
        if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
        $process.Dispose()
    }
}
try {
    [IO.File]::Move($candidate, $moved); [IO.File]::Copy($invalid, $candidate)
    $blocked = $false
    try {
        $writer = [IO.File]::Open($moved, [IO.FileMode]::Open, [IO.FileAccess]::Write, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $writer.Dispose()
    } catch [IO.IOException] { $blocked = $true }
    if (-not $blocked) { throw 'Guard did not block a new writer' }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = ([BitConverter]::ToString($sha.ComputeHash($guard))).Replace('-','') } finally { $sha.Dispose() }
    if ($hash -ne $expectedHash) { throw 'Held input does not match the independent fixture hash' }
    $runs = @()
    foreach ($name in @('verify-compile-1','verify-compile-2')) {
        $guard.Position = 0
        $result = Run-Clang $guard $name
        if ($result.status -ne 0 -or -not [IO.File]::Exists($result.output) -or $guard.Position -ne $guard.Length) { throw "Held input failed: $($result.stderr)" }
        $runs += ,$result
    }
    $substitute = [IO.File]::OpenRead($candidate)
    try { $bad = Run-Clang $substitute 'substitute' } finally { $substitute.Dispose() }
    if ($bad.status -eq 0 -or $bad.stderr -notmatch 'Instruction does not dominate all uses' -or [IO.File]::Exists($bad.output)) { throw 'Substituted invalid module was not rejected' }
    $hash1 = (Get-FileHash -LiteralPath $runs[0].output -Algorithm SHA256).Hash
    $hash2 = (Get-FileHash -LiteralPath $runs[1].output -Algorithm SHA256).Hash
    Write-Output "Held fixture $hash compiled twice after path swap; object hashes equal=$($hash1 -eq $hash2). Substituted invalid IR was rejected."
    Write-Output "Test-owned artifacts: $directory"
} finally { $guard.Dispose() }
