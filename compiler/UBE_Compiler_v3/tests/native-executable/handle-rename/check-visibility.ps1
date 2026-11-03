param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $OutputDirectory, [ValidateSet('move', 'native', 'posix', 'replace', 'no-reader', 'release-first', 'non-atomic')][string] $Mode = 'move')
$ErrorActionPreference = 'Stop'
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
for ($i = 0; $i -lt 10; $i++) {
    $process = [Diagnostics.Process]::new()
    $process.StartInfo.FileName = $probePath
    $process.StartInfo.Arguments = '"' + $directory + '" ' + $Mode
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    if (-not $process.Start()) { throw 'Probe did not start' }
    try {
        if (-not $process.WaitForExit(30000)) { $process.Kill(); $process.WaitForExit(); throw 'Probe timed out' }
        $output = $process.StandardOutput.ReadToEnd().Trim()
        $errorOutput = $process.StandardError.ReadToEnd().Trim()
        if ($Mode -eq 'no-reader') {
            if ($output -notmatch '^complete reads: 0; A: 0; B: 0; replacements: [0-9]+$') { throw "Unexpected no-reader observation: $output" }
        } elseif ($output -notmatch '^complete reads: [1-9][0-9]*; A: [0-9]+; B: [0-9]+; replacements: [0-9]+$') { throw "No complete reader observation: $output" }
        if ($Mode -eq 'posix' -and ($process.ExitCode -ne 0 -or $output -notmatch 'A: [1-9][0-9]*; B: [1-9][0-9]*; replacements: 200$')) { throw "Both patterns and all replacements were not observed: $output $errorOutput" }
        if ($Mode -eq 'non-atomic' -and ($process.ExitCode -ne 1 -or $errorOutput -notmatch '^reader open failed: (2|5)$')) { throw "Negative control did not observe an open failure: $output $errorOutput" }
        if ($process.ExitCode -eq 0) { Write-Output "Run $i : $output" }
        elseif ($process.ExitCode -eq 1 -and $errorOutput -match '^replacement failed: (5|32)$') { Write-Output "Run $i : $output; $errorOutput" }
        elseif ($process.ExitCode -eq 1 -and (($Mode -eq 'replace' -and $errorOutput -match '^reader open failed: 2$') -or ($Mode -eq 'non-atomic' -and $errorOutput -match '^reader open failed: (2|5)$'))) { Write-Output "Run $i : $output; $errorOutput" }
        else { throw "Probe failed: $($process.ExitCode) $output $errorOutput" }
    } finally { $process.Dispose() }
}
