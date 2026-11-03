param([Parameter(Mandatory=$true)][string] $Probe,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$probePath = (Resolve-Path -LiteralPath $Probe).Path
. (Join-Path $PSScriptRoot '../verifier/preservation-snapshot.ps1')
$root = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
foreach ($mode in @('native-relative','native-posix')) {
  foreach ($junction in @($false,$true)) {
    foreach ($guarded in @($false,$true)) {
        $directory = Join-Path $root "$mode-$junction-$guarded"
        [IO.Directory]::CreateDirectory($directory) | Out-Null
        $candidate = Join-Path $directory 'candidate.bin'
        $original = Join-Path $directory 'destination.bin'
        [IO.File]::WriteAllText($candidate, 'candidate')
        [IO.File]::WriteAllText($original, 'source')
        Set-Content -LiteralPath $original -Stream 'ube-preservation-test' -Value 'source stream' -NoNewline
        $before = Snapshot $original
        $selected = $directory
        if ($junction) {
            $selected = Join-Path $root "link-$mode-$guarded"
            New-Item -ItemType Junction -Path $selected -Target $directory | Out-Null
        }
        $held = $null
        try {
            if ($guarded) { $held = [IO.File]::Open($original, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite) }
            $process = [Diagnostics.Process]::new()
            $process.StartInfo.FileName = $probePath
            $process.StartInfo.Arguments = '"' + $selected + '" ' + $mode
            $process.StartInfo.UseShellExecute = $false; $process.StartInfo.CreateNoWindow = $true
            $process.StartInfo.RedirectStandardOutput = $true; $process.StartInfo.RedirectStandardError = $true
            $started = $false
            try {
                $started = $process.Start()
                if (-not $started) { throw 'Rename probe failed to start' }
                $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
                if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit(); throw 'Rename probe timed out' }
                $status = $process.ExitCode; $null = $stdout.Result; $errorText = $stderr.Result
            } finally {
                if ($started -and -not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
                $process.Dispose()
            }
            if ($guarded) {
                $after = Snapshot $original
                if ($status -ne 1 -or $errorText -notmatch 'rename failed: (5|32)\b' -or -not (Same $before $after) -or [IO.File]::ReadAllText($candidate) -ne 'candidate') { throw "Guarded original changed or unexpected failure: $mode $junction $errorText" }
            } else {
                if ($status -ne 0 -or [IO.File]::ReadAllText($original) -ne 'candidate' -or [IO.File]::Exists($candidate)) { throw "Unguarded control did not replace the source name: $mode $junction $errorText" }
            }
            Write-Output "$mode junction=$junction guarded=$guarded status=$status error=$($errorText.Trim())"
        } finally { if ($held) { $held.Dispose() } }
    }
  }
}
