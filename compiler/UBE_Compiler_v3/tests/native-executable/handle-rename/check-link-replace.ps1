param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$root = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
foreach ($locked in @($false, $true)) {
    $directory = Join-Path $root ([string]$locked)
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    $candidate = Join-Path $directory 'candidate.bin'; $destination = Join-Path $directory 'destination.bin'
    [IO.File]::WriteAllText($candidate, 'candidate'); [IO.File]::WriteAllText($destination, 'old')
    $held = $null
    try {
        if ($locked) {
            $held = [IO.File]::Open($destination, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
            $blocked = $false
            try { [IO.File]::Move($destination, (Join-Path $directory 'moved.bin')) } catch [IO.IOException] { $blocked = $true }
            if (-not $blocked) { throw 'Destination move was not blocked by the guard' }
        }
        $process = [Diagnostics.Process]::new()
        $process.StartInfo.FileName = $probePath; $process.StartInfo.Arguments = '"' + $directory + '" native-link'
        $process.StartInfo.UseShellExecute = $false; $process.StartInfo.CreateNoWindow = $true
        $process.StartInfo.RedirectStandardOutput = $true; $process.StartInfo.RedirectStandardError = $true
        if (-not $process.Start()) { throw 'Probe did not start' }
        if (-not $process.WaitForExit(10000)) { $process.Kill(); throw 'Probe timed out' }
        $out = $process.StandardOutput.ReadToEnd(); $err = $process.StandardError.ReadToEnd(); $status = $process.ExitCode
        $process.Dispose()
        if (-not $locked -and $status -ne 0) { throw "Unlocked control failed: $err" }
        if ([IO.File]::ReadAllText($candidate) -ne 'candidate') { throw 'Candidate changed' }
        if ($status -eq 0) {
            if ([IO.File]::ReadAllText($destination) -ne 'candidate') { throw 'Destination does not link candidate' }
            if ($locked) {
                $buffer = New-Object byte[] 3; if ($held.Read($buffer, 0, 3) -ne 3 -or [Text.Encoding]::ASCII.GetString($buffer) -ne 'old') { throw 'Held old file changed' }
                Write-Output 'Hard-link replacement succeeded while guarded destination handle remained open.'
            } else {
                [IO.File]::WriteAllText($candidate, 'linked')
                if ([IO.File]::ReadAllText($destination) -ne 'linked') { throw 'Destination does not share candidate file contents' }
                Write-Output 'Unlocked hard-link replacement succeeded and shares candidate contents.'
            }
        } else {
            if (-not $locked -or $status -ne 1 -or [IO.File]::ReadAllText($destination) -ne 'old') { throw "Unexpected failure: $status $err" }
            Write-Output "Hard-link replacement failed while guarded destination remained: $($err.Trim())"
        }
    } finally { if ($held) { $held.Dispose() } }
}
