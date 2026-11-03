param(
    [Parameter(Mandatory = $true)][string] $Clang,
    [Parameter(Mandatory = $true)][string] $Objdump,
    [Parameter(Mandatory = $true)][string] $OutputDirectory
)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'probe.c'
[IO.Directory]::CreateDirectory([IO.Path]::GetFullPath($OutputDirectory)) | Out-Null
$debug = Join-Path $OutputDirectory 'debug.o'
$plain = Join-Path $OutputDirectory 'plain.o'
$debugExe = Join-Path $OutputDirectory 'debug.exe'
$plainExe = Join-Path $OutputDirectory 'plain.exe'
foreach ($item in @(@($debug, '-g'), @($plain, '-g0'))) {
    $output = @(& $Clang --target=x86_64-w64-windows-gnu -O2 -gdwarf-4 $item[1] -c $source -o $item[0] 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Clang failed: $($output -join ' ')" }
}
foreach ($item in @(@($debugExe, '-g'), @($plainExe, '-g0'))) {
    $output = @(& $Clang --target=x86_64-w64-windows-gnu -O2 -gdwarf-4 $item[1] $source -o $item[0] 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Clang link failed: $($output -join ' ')" }
}
function Read-Info([string] $Path) {
    $output = @(& $Objdump --dwarf=info,decodedline $Path 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Objdump failed: $($output -join ' ')" }
    return ($output -join "`n")
}
function Matches-Probe([string] $Info, [string] $Procedure) {
    $units = @([regex]::Split($Info, '(?m)^\s*Compilation Unit @ offset ') | Where-Object { $_ -match 'DW_AT_name\s*:.*debug-reader[\\/]probe\.c' })
    if ($units.Count -ne 1) { return $false }
    $unit = $units[0]
    return ($Info -match 'file format pei?-x86-64' -and $unit -match 'DW_TAG_formal_parameter' -and $unit -match 'DW_TAG_variable' -and $unit -match ('DW_AT_name\s*:.*\b' + [regex]::Escape($Procedure) + '\b') -and $unit -match 'DW_AT_name\s*:.*\bvalue\b' -and $unit -match 'DW_AT_name\s*:.*\bfactor\b' -and $Info -match '(?m)^probe\.c\s+3\s')
}
$info = Read-Info $debug
if (-not (Matches-Probe $info 'double_value')) { throw 'Expected debug records missing' }
if (Matches-Probe $info 'wrong_procedure') { throw 'Wrong procedure control accepted' }
if (Matches-Probe (Read-Info $plain) 'double_value') { throw 'No-debug control accepted' }
$linkedInfo = Read-Info $debugExe
if (-not (Matches-Probe $linkedInfo 'double_value')) { throw 'Expected linked debug records missing' }
if (Matches-Probe $linkedInfo 'wrong_procedure') { throw 'Wrong linked procedure control accepted' }
if (Matches-Probe (Read-Info $plainExe) 'double_value') { throw 'No-debug linked control accepted' }
$unrelatedSource = Join-Path $PSScriptRoot 'unrelated.c'
$unrelatedObject = Join-Path $OutputDirectory 'unrelated.o'
$mixedExe = Join-Path $OutputDirectory 'unrelated-debug.exe'
$output = @(& $Clang --target=x86_64-w64-windows-gnu -O2 -gdwarf-4 -g -c $unrelatedSource -o $unrelatedObject 2>&1)
if ($LASTEXITCODE -ne 0) { throw "Unrelated object build failed: $($output -join ' ')" }
$output = @(& $Clang --target=x86_64-w64-windows-gnu $plain $unrelatedObject -o $mixedExe 2>&1)
if ($LASTEXITCODE -ne 0) { throw "Mixed link failed: $($output -join ' ')" }
$mixedInfo = Read-Info $mixedExe
if ($mixedInfo -notmatch 'DW_AT_name\s*:.*debug-reader[\\/]unrelated\.c' -or $mixedInfo -notmatch 'unrelated_debug_function') { throw 'Unrelated debug records are missing' }
if (Matches-Probe $mixedInfo 'double_value') { throw 'Unrelated debug records were accepted as fixture records' }
function Read-Exit([string] $Path) {
    $process = [Diagnostics.Process]::new()
    $process.StartInfo.FileName = (Resolve-Path -LiteralPath $Path).Path
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    if (-not $process.Start()) { throw 'Probe executable did not start' }
    try {
        if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit(); throw 'Probe executable timed out' }
        return $process.ExitCode
    } finally { $process.Dispose() }
}
$debugExit = Read-Exit $debugExe
$plainExit = Read-Exit $plainExe
function Matches-Exit([int] $Actual, [int] $Expected) { return $Actual -eq $Expected }
if (-not (Matches-Exit $debugExit 8) -or -not (Matches-Exit $plainExit 8)) { throw "Unexpected debug/plain results: $debugExit / $plainExit" }
if ((Matches-Exit $debugExit 7) -or (Matches-Exit $plainExit 7)) { throw 'Wrong-result control accepted' }
$behavior = Join-Path $PSScriptRoot 'behavior.c'
$behaviorDebug = Join-Path $OutputDirectory 'behavior-debug.exe'
$behaviorPlain = Join-Path $OutputDirectory 'behavior-plain.exe'
foreach ($item in @(@($behaviorDebug, '-g'), @($behaviorPlain, '-g0'))) {
    $output = @(& $Clang --target=x86_64-w64-windows-gnu -O2 -gdwarf-4 $item[1] $behavior -o $item[0] 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Behavior build failed: $($output -join ' ')" }
}
$behaviorDebugInfo = Read-Info $behaviorDebug
$behaviorPlainInfo = Read-Info $behaviorPlain
if ($behaviorDebugInfo -notmatch 'DW_AT_name\s*:.*debug-reader[\\/]behavior\.c' -or $behaviorDebugInfo -notmatch 'DW_AT_name\s*:.*double_observed') { throw 'Behavior debug records missing' }
if ($behaviorPlainInfo -match 'DW_AT_name\s*:.*debug-reader[\\/]behavior\.c') { throw 'No-debug behavior control retained fixture debug records' }
foreach ($path in @($behaviorDebug, $behaviorPlain)) {
    $status = Read-Exit $path
    if (-not (Matches-Exit $status 8) -or (Matches-Exit $status 99)) { throw "Behavior result or wrong-result control failed: $status" }
}
$badBehavior = Join-Path $OutputDirectory 'behavior-wrong-calls.exe'
$output = @(& $Clang --target=x86_64-w64-windows-gnu -O2 -g -DMUTATE_CALLS $behavior -o $badBehavior 2>&1)
if ($LASTEXITCODE -ne 0) { throw "Mutated behavior build failed: $($output -join ' ')" }
if (-not (Matches-Exit (Read-Exit $badBehavior) 99)) { throw 'Wrong-side-effect mutation was not detected' }
Write-Output 'Debug-reader, optimized debug/plain result and volatile side-effect checks passed.'
