param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $FirstLinker,
      [Parameter(Mandatory=$true)][string] $SecondLinker,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$clangPath = (Resolve-Path -LiteralPath $Clang).Path
$linkers = @((Resolve-Path -LiteralPath $FirstLinker).Path, (Resolve-Path -LiteralPath $SecondLinker).Path)
if ((Get-FileHash -LiteralPath $linkers[0]).Hash -eq (Get-FileHash -LiteralPath $linkers[1]).Hash) {
    throw 'Controlled linker binaries must have different identities'
}
$root = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($root) | Out-Null
$source = Join-Path $root 'input.c'
[IO.File]::WriteAllText($source, 'int main(void) { return 0; }')
$driverHash = (Get-FileHash -LiteralPath $clangPath).Hash
for ($i = 0; $i -lt 2; $i++) {
    $output = Join-Path $root "result-$i.exe"
    $log = Join-Path $root "driver-$i.txt"
    $process = [Diagnostics.Process]::new()
    $process.StartInfo.FileName = $clangPath
    $process.StartInfo.Arguments = '--target=x86_64-w64-windows-gnu --ld-path="' + $linkers[$i] + '" "' + $source + '" -o "' + $output + '"'
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    try {
        if (-not $process.Start()) { throw 'Clang did not start' }
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(20000)) { $process.Kill(); $process.WaitForExit(); throw 'Clang timed out' }
        $text = $stdout.Result + $stderr.Result
        [IO.File]::WriteAllText($log, $text)
        $wanted = if ($i -eq 0) { 'independent-linker-one' } else { 'independent-linker-two' }
        $wrong = if ($i -eq 0) { 'independent-linker-two' } else { 'independent-linker-one' }
        if ($process.ExitCode -eq 0 -or $text -notmatch $wanted -or $text -match $wrong -or [IO.File]::Exists($output)) {
            throw "Unexpected child identity or output for case ${i}: $text"
        }
        if ((Get-FileHash -LiteralPath $clangPath).Hash -ne $driverHash) { throw 'Driver identity changed during test' }
        Write-Output "Case ${i}: same driver invoked $wanted, link failed, no executable published."
    } finally { $process.Dispose() }
}
