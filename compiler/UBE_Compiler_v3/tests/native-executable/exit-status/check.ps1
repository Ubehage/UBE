param(
    [Parameter(Mandatory = $true)][string] $Clang,
    [Parameter(Mandatory = $true)][string] $OutputDirectory
)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'probe.c'
[IO.Directory]::CreateDirectory([IO.Path]::GetFullPath($OutputDirectory)) | Out-Null
$executable = [IO.Path]::GetFullPath((Join-Path $OutputDirectory 'status-probe.exe'))
$output = @(& $Clang --target=x86_64-w64-windows-gnu -O2 $source -o $executable 2>&1)
if ($LASTEXITCODE -ne 0) { throw "Probe compilation failed: $($output -join ' ')" }
foreach ($case in @(@('min', [uint32]2147483648), @('max', [uint32]2147483647))) {
    $process = [Diagnostics.Process]::new()
    try {
        $process.StartInfo.FileName = $executable
        $process.StartInfo.Arguments = $case[0]
        $process.StartInfo.UseShellExecute = $false
        if (-not $process.Start()) { throw 'Process did not start' }
        if (-not $process.WaitForExit(10000)) { $process.Kill(); throw 'Process timed out' }
        $bits = [BitConverter]::ToUInt32([BitConverter]::GetBytes([int]$process.ExitCode), 0)
        if ($bits -ne $case[1]) { throw "Wrong $($case[0]) status: $bits" }
        if ($bits -eq ($case[1] -bxor 1)) { throw 'Wrong-bit control accepted' }
    } finally { $process.Dispose() }
}
Write-Output 'Passed two full-width status observations and two wrong-bit controls.'
