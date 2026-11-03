param([Parameter(Mandatory=$true)][string] $Clang, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$tool = (Resolve-Path -LiteralPath $Clang).Path
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$path = Join-Path $directory 'candidate.ll'
$fixture = Join-Path $PSScriptRoot '../verifier/valid.ll'
[IO.File]::Copy([IO.Path]::GetFullPath($fixture), $path)
$guard = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::Read -bor [IO.FileShare]::Delete))
function Invoke-Clang([IO.Stream] $inputStream, [string] $outputPath) {
    $process = [Diagnostics.Process]::new()
    $process.StartInfo.FileName = $tool
    $process.StartInfo.Arguments = '--target=x86_64-w64-windows-gnu -O2 -Xclang -llvm-verify-each -x ir -c - -o "' + $outputPath + '"'
    $process.StartInfo.UseShellExecute = $false; $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardInput = $true; $process.StartInfo.RedirectStandardOutput = $true; $process.StartInfo.RedirectStandardError = $true
    if (-not $process.Start()) { throw 'Clang did not start' }
    try {
        $inputStream.CopyTo($process.StandardInput.BaseStream); $process.StandardInput.Close()
        $stdout = $process.StandardOutput.ReadToEnd(); $stderr = $process.StandardError.ReadToEnd()
        if (-not $process.WaitForExit(10000)) { $process.Kill(); throw 'Clang timed out' }
        return @{ status = $process.ExitCode; stdout = $stdout; stderr = $stderr }
    } finally { $process.Dispose() }
}
try {
    $moved = Join-Path $directory 'original.ll'
    [IO.File]::Move($path, $moved)
    [IO.File]::WriteAllText($path, 'not LLVM IR')
    $writerBlocked = $false
    try {
        $writer = [IO.File]::Open($moved, [IO.FileMode]::Open, [IO.FileAccess]::Write, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $writer.Dispose()
    } catch [IO.IOException] { $writerBlocked = $true }
    if (-not $writerBlocked) { throw 'Guarded original allowed a write open' }
    $object = Join-Path $directory 'guarded.o'
    $good = Invoke-Clang $guard $object
    if ($good.status -ne 0 -or -not [IO.File]::Exists($object)) { throw "Guarded input failed: $($good.stderr)" }
    $substitute = [IO.File]::OpenRead($path)
    try { $bad = Invoke-Clang $substitute (Join-Path $directory 'bad.o') } finally { $substitute.Dispose() }
    if ($bad.status -eq 0 -or [IO.File]::Exists((Join-Path $directory 'bad.o'))) { throw 'Invalid substitute was accepted' }
    Write-Output "Clang compiled guarded original over stdin and rejected substituted pathname: $directory"
} finally { $guard.Dispose() }
