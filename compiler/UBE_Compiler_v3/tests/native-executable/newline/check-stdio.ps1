param([string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$exe = Join-Path $PSScriptRoot '../../../../../bootstrap/out/newline-stdio-probe.exe'
& $Clang --target=x86_64-w64-windows-gnu -Wall -Wextra -Werror (Join-Path $PSScriptRoot 'stdio-probe.c') -o $exe
if ($LASTEXITCODE -ne 0) { throw 'Probe compilation failed.' }
function Read-Probe([string]$Arguments) {
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $exe
    $info.Arguments = $Arguments
    $info.UseShellExecute = $false
    $info.RedirectStandardOutput = $true
    $process = [System.Diagnostics.Process]::Start($info)
    try {
        $stream = New-Object System.IO.MemoryStream
        try {
            $copy = $process.StandardOutput.BaseStream.CopyToAsync($stream)
            if (-not $process.WaitForExit(30000)) { $process.Kill(); $process.WaitForExit(); throw 'Probe timed out.' }
            $null = $copy.GetAwaiter().GetResult()
            if ($process.ExitCode -ne 0) { throw "Probe exited $($process.ExitCode)." }
            return [BitConverter]::ToString($stream.ToArray())
        } finally { $stream.Dispose() }
    } finally { $process.Dispose() }
}
$textBytes = Read-Probe ''
$binaryBytes = Read-Probe 'binary'
if ($textBytes -cne '41-0D-0A-42-0D-0A') { throw "Unexpected text bytes: $textBytes" }
if ($binaryBytes -cne '41-0A-42-0A') { throw "Unexpected binary bytes: $binaryBytes" }
Write-Output "stdout text mode: $textBytes; binary mode: $binaryBytes"
