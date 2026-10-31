# Shared offline bootstrap verification helpers. No build runs when dot-sourced.
function Get-ArtifactIdentity([string]$Path) {
    $item = Get-Item -LiteralPath $Path
    [pscustomobject]@{ path = $item.FullName; bytes = $item.Length;
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
}

# Admit an immutable source-built compiler cohort and its unchanged source inputs.
function Get-VerifiedBootstrapSelection([string]$SelectionPath) {
    $selection = Get-Content -LiteralPath $SelectionPath -Raw | ConvertFrom-Json
    foreach ($property in $selection.PSObject.Properties) {
        if ($property.Name -eq 'schema') { continue }
        $actual = Get-ArtifactIdentity $property.Value.path
        if ($actual.sha256 -cne $property.Value.sha256 -or $actual.bytes -ne $property.Value.bytes) {
            throw "Selection identity mismatch: $($property.Name)"
        }
    }
    $manifest = Get-Content -LiteralPath $selection.manifest.path -Raw | ConvertFrom-Json
    if (-not $manifest.success) { throw 'Source-built cohort is unsuccessful' }
    foreach ($identity in $manifest.inputs) {
        if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) {
            throw "Source-built input changed: $($identity.path)"
        }
    }
    $stages = @((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
    foreach ($stage in $stages) {
        $identities = @($manifest.artifacts | Where-Object path -CEQ $stage)
        if ($identities.Count -ne 1 -or (Get-ArtifactIdentity $stage).sha256 -cne $identities[0].sha256) {
            throw "Source-built stage identity mismatch: $stage"
        }
    }
    return $selection
}

function ConvertTo-ProcessArgument([string]$Value) {
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    '"' + [regex]::Replace($escaped, '(\\+)$', '$1$1') + '"'
}

function Invoke-BoundedProcess {
    param([string]$FilePath, [string[]]$Arguments = @(),
        [string]$WorkingDirectory = (Get-Location).Path, [int]$TimeoutSeconds = 30)
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $FilePath
    $info.Arguments = (($Arguments | ForEach-Object { ConvertTo-ProcessArgument $_ }) -join ' ')
    $info.WorkingDirectory = $WorkingDirectory
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    $timer = [Diagnostics.Stopwatch]::StartNew()
    try {
        if (-not $process.Start()) { throw "Could not start $FilePath" }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $peakBytes = 0L
        $timedOut = $false
        while (-not $process.WaitForExit(50)) {
            $process.Refresh()
            if (-not $process.HasExited) { $peakBytes = [Math]::Max($peakBytes, $process.PeakWorkingSet64) }
            if ($timer.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
                $timedOut = $true
                $killInfo = New-Object Diagnostics.ProcessStartInfo
                $killInfo.FileName = Join-Path $env:SystemRoot 'System32/taskkill.exe'
                $killInfo.Arguments = "/PID $($process.Id) /T /F"
                $killInfo.UseShellExecute = $false
                $killInfo.CreateNoWindow = $true
                $killInfo.RedirectStandardOutput = $true
                $killInfo.RedirectStandardError = $true
                $killer = [Diagnostics.Process]::Start($killInfo)
                try { if (-not $killer.WaitForExit(5000)) { $killer.Kill() } }
                finally { $killer.Dispose() }
                if (-not $process.HasExited) { $process.Kill() }
                if (-not $process.WaitForExit(2000)) { throw "Timeout cleanup failed: $FilePath" }
                break
            }
        }
        if (-not $stdoutTask.Wait(5000) -or -not $stderrTask.Wait(5000)) {
            throw "Output pipes did not close: $FilePath"
        }
        $timer.Stop()
        [pscustomobject]@{ file = $FilePath; arguments = @($Arguments);
            exit = $process.ExitCode; timedOut = $timedOut;
            elapsedMs = $timer.ElapsedMilliseconds; sampledPeakWorkingSetBytes = $peakBytes;
            stdout = $stdoutTask.Result.Replace("`r`n", "`n");
            stderr = $stderrTask.Result.Replace("`r`n", "`n") }
    } finally { $process.Dispose() }
}
