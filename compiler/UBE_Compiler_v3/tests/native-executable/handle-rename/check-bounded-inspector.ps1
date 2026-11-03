param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $Readobj,
      [Parameter(Mandatory=$true)][string] $LateMarker, [Parameter(Mandatory=$true)][string] $Noisy,
      [Parameter(Mandatory=$true)][string] $Executable, [string] $Descendant, [string] $NulMarker,
      [string] $ErrorInspector, [string] $StalledInspector)
$ErrorActionPreference = 'Stop'
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$fixture = (Resolve-Path -LiteralPath $Executable).Path
function Check-Uniform([string] $output, [int] $total) {
    $kept = [Math]::Min($total,4096)
    $expectedCounts = "stdout total=$total kept=$kept; stderr total=$total kept=$kept"
    return ($output.Contains($expectedCounts) -and $output -match 'uniform retained prefix: stdout A=1; stderr B=1' -and
        (($output -match 'report truncated; rejected') -eq ($total -gt 4096)))
}
$cases = @(@('real',$Readobj), @('late',$LateMarker), @('empty',$Noisy,0), @('exact',$Noisy,4096), @('over',$Noisy,4097), @('noisy',$Noisy,131072))
if ($Descendant) { $cases += ,@('descendant',$Descendant) }
if ($NulMarker) { $cases += ,@('nul',$NulMarker) }
if ($ErrorInspector) { $cases += ,@('error',$ErrorInspector) }
if ($StalledInspector) { $cases += ,@('stalled',$StalledInspector) }
foreach ($case in $cases) {
    $tool = (Resolve-Path -LiteralPath $case[1]).Path
    $process = [Diagnostics.Process]::new()
    $process.StartInfo.FileName = $probePath
    $process.StartInfo.Arguments = '"' + $tool + '" "' + $fixture + '"'
    $process.StartInfo.UseShellExecute = $false; $process.StartInfo.CreateNoWindow = $true
    if ($case.Count -eq 3) { $process.StartInfo.EnvironmentVariables['UBE_TEST_STREAM_BYTES'] = [string]$case[2] }
    $process.StartInfo.RedirectStandardOutput = $true; $process.StartInfo.RedirectStandardError = $true
    if (-not $process.Start()) { throw 'Probe did not start' }
    try {
        $out = $process.StandardOutput.ReadToEndAsync(); $err = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(15000)) { $process.Kill(); $process.WaitForExit(); throw 'Probe timed out' }
        $output = $out.Result; $errorOutput = $err.Result
        if ($case[0] -eq 'real' -and ($process.ExitCode -ne 0 -or $output -notmatch 'complete report accepted')) { throw "Real report failed: $output $errorOutput" }
        if ($case[0] -eq 'late' -and ($process.ExitCode -eq 0 -or $output -notmatch 'stdout total=([0-9]+) kept=4096' -or [long]$Matches[1] -le 4096 -or $output -notmatch 'report truncated; rejected')) { throw "Late marker control failed: $output $errorOutput" }
        if ($case[0] -eq 'descendant' -and ($process.ExitCode -eq 0 -or $output -notmatch 'inspector exit code=0' -or $output -notmatch 'remaining job processes stopped' -or $output -notmatch 'both output pipes drained to EOF' -or $output -match 'complete report accepted')) { throw "Descendant control failed: $output $errorOutput" }
        if ($case[0] -eq 'nul' -and ($process.ExitCode -eq 0 -or $output -notmatch 'inspector exit code=0' -or $output -notmatch 'stdout total=131 kept=131' -or $output -notmatch 'report contains NUL; rejected' -or $output -match 'complete report accepted')) { throw "Embedded NUL control failed: $output $errorOutput" }
        if ($case[0] -eq 'error' -and ($process.ExitCode -eq 0 -or $output -notmatch 'inspector exit code=41' -or $output -match 'complete report accepted' -or $output -notmatch 'both output pipes drained to EOF' -or $output -notmatch 'captured positive marker prefix')) { throw "Inspector failure control failed: $output $errorOutput" }
        if ($case[0] -eq 'stalled' -and ($process.ExitCode -eq 0 -or $output -notmatch 'timed out; inspector exit observed' -or $output -match 'complete report accepted' -or $output -notmatch 'both output pipes drained to EOF')) { throw "Inspector timeout control failed: $output $errorOutput" }
        if ($case.Count -eq 3) {
            $total = [int]$case[2]
            if ($process.ExitCode -eq 0 -or -not (Check-Uniform $output $total)) { throw "Drain boundary failed: $output $errorOutput" }
            if (Check-Uniform ($output.Replace('stdout A=1','stdout A=0')) $total) { throw 'Wrong-prefix control accepted' }
            if (Check-Uniform $output ($total + 1)) { throw 'Wrong-count control accepted' }
            $changedFlag = if ($total -gt 4096) { $output.Replace('report truncated; rejected','') } else { $output + ' report truncated; rejected' }
            if (Check-Uniform $changedFlag $total) { throw 'Wrong-truncation control accepted' }
        }
        Write-Output "$($case[0]): $($output.Trim())"
    } finally { $process.Dispose() }
}
