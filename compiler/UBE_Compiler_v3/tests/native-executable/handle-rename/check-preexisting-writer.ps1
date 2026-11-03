param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$candidate = Join-Path $directory 'candidate.bin'; $destination = Join-Path $directory 'destination.bin'
[IO.File]::WriteAllText($candidate, 'candidate'); [IO.File]::WriteAllText($destination, 'old')
function Invoke-Probe {
    $process = [Diagnostics.Process]::new()
    $process.StartInfo.FileName = $probePath
    $process.StartInfo.Arguments = '"' + $directory + '" native-reopen-posix'
    $process.StartInfo.UseShellExecute = $false; $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardError = $true; $process.StartInfo.RedirectStandardOutput = $true
    if (-not $process.Start()) { throw 'Probe did not start' }
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(5000)) { $process.Kill(); $process.WaitForExit(); throw 'Probe timed out' }
        return @{ status = $process.ExitCode; stdout = $stdout.Result; stderr = $stderr.Result }
    } finally { $process.Dispose() }
}
$writer = [IO.File]::Open($candidate, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite,
    ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
try {
    $blocked = Invoke-Probe
    if ($blocked.status -ne 5 -or $blocked.stderr -notmatch 'candidate open failed: 32' -or
        [IO.File]::ReadAllText($destination) -ne 'old') { throw 'Guard did not fail closed while writer was open' }
    $writer.Position = 0; $replacement = [Text.Encoding]::ASCII.GetBytes('altered!!')
    $writer.Write($replacement, 0, $replacement.Length); $writer.Flush()
} finally { $writer.Dispose() }
if ([IO.File]::ReadAllText($candidate) -ne 'altered!!') { throw 'Existing writer did not modify candidate' }
[IO.File]::WriteAllText($candidate, 'candidate')
$control = Invoke-Probe
if ($control.status -ne 0 -or [IO.File]::ReadAllText($destination) -ne 'candidate' -or [IO.File]::Exists($candidate)) { throw 'Post-release publication control failed' }
Write-Output "Pre-existing writer blocked guard; its write succeeded; guard and rename succeeded after release: $directory"
