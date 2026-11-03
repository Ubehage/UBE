param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'stack-fatal-probe.c'
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$backpressureSource = Join-Path $PSScriptRoot 'stack-fatal-backpressure.c'
$backpressure = Join-Path $OutputDirectory 'stack-fatal-backpressure.exe'
& $Clang --target=x86_64-w64-windows-gnu -std=c17 -O2 -Wall -Wextra -Werror -municode $backpressureSource -o $backpressure
if ($LASTEXITCODE -ne 0) { throw 'Backpressure probe compilation failed' }
foreach ($optimization in @('0','2')) {
    $exe = Join-Path $OutputDirectory ("stack-fatal-$optimization.exe")
    & $Clang --target=x86_64-w64-windows-gnu -std=c17 "-O$optimization" -Wall -Wextra -Werror $source -o $exe
    if ($LASTEXITCODE -ne 0) { throw 'Fatal-path probe compilation failed' }
    foreach ($mode in @('fatal','closed','ordinary','threaded','prestarted')) {
        $process = [Diagnostics.Process]::new()
        $process.StartInfo.FileName = (Resolve-Path -LiteralPath $exe).Path
        $process.StartInfo.Arguments = $mode
        $process.StartInfo.UseShellExecute = $false; $process.StartInfo.CreateNoWindow = $true
        $process.StartInfo.RedirectStandardOutput = $true; $process.StartInfo.RedirectStandardError = $true
        if (-not $process.Start()) { throw 'Fatal-path probe did not start' }
        try {
            $out = $process.StandardOutput.ReadToEndAsync(); $err = $process.StandardError.ReadToEndAsync()
            if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit(); throw 'Fatal-path probe timed out' }
            if ($process.ExitCode -ne 1 -or $out.Result -ne '') { throw "Unexpected status or stdout: O$optimization $mode" }
            $expected = if ($mode -in @('fatal','threaded','prestarted')) { "error: insufficient execution stack`r`n" } else { '' }
            if ($err.Result -cne $expected) { throw "Unexpected stderr: O$optimization $mode" }
        } finally { $process.Dispose() }
    }
    $result = @(& (Resolve-Path -LiteralPath $backpressure).Path (Resolve-Path -LiteralPath $exe).Path)
    if ($LASTEXITCODE -ne 0 -or $result.Count -ne 1 -or $result[0] -ne 'full stderr blocked fatal write until pipe was drained') { throw "Backpressure observation failed: O$optimization $result" }
    $nonblocking = @(& (Resolve-Path -LiteralPath $backpressure).Path (Resolve-Path -LiteralPath $exe).Path 'nowait')
    if ($LASTEXITCODE -ne 0 -or $nonblocking.Count -ne 1 -or ($nonblocking[0] -notin @('nowait exited; parent pipe mode unchanged','nowait exited; parent pipe mode changed') -and $nonblocking[0] -notmatch '^nowait setup failed with error [0-9]+$')) { throw "Nonblocking observation failed: O$optimization $nonblocking" }
    Write-Output "O$optimization : $($nonblocking[0])"
    $empty = @(& (Resolve-Path -LiteralPath $backpressure).Path (Resolve-Path -LiteralPath $exe).Path 'nowait-empty')
    if ($LASTEXITCODE -ne 0 -or $empty.Count -ne 1 -or ($empty[0] -notin @('nowait exited; parent pipe mode unchanged','nowait exited; parent pipe mode changed') -and $empty[0] -notmatch '^nowait setup failed with error [0-9]+$')) { throw "Empty-pipe observation failed: O$optimization $empty" }
    Write-Output "O$optimization empty pipe : $($empty[0])"
    $threaded = @(& (Resolve-Path -LiteralPath $backpressure).Path (Resolve-Path -LiteralPath $exe).Path 'threaded')
    if ($LASTEXITCODE -ne 0 -or $threaded.Count -ne 1 -or $threaded[0] -ne 'threaded fatal exited while pipe remained full; parent mode unchanged') { throw "Threaded backpressure observation failed: O$optimization $threaded" }
    Write-Output "O$optimization : $($threaded[0])"
    $prestarted = @(& (Resolve-Path -LiteralPath $backpressure).Path (Resolve-Path -LiteralPath $exe).Path 'prestarted')
    if ($LASTEXITCODE -ne 0 -or $prestarted.Count -ne 1 -or $prestarted[0] -ne 'prestarted writer exited while pipe remained full; parent mode unchanged') { throw "Prestarted backpressure observation failed: O$optimization $prestarted" }
    Write-Output "O$optimization : $($prestarted[0])"
    $cancelled = @(& (Resolve-Path -LiteralPath $backpressure).Path (Resolve-Path -LiteralPath $exe).Path 'cancel')
    if ($LASTEXITCODE -ne 0 -or $cancelled.Count -ne 1 -or $cancelled[0] -ne 'cancelled write and exited while pipe remained full; parent mode unchanged') { throw "Cancelled-write observation failed: O$optimization $cancelled" }
    Write-Output "O$optimization : $($cancelled[0])"
}
Write-Output 'Fatal, closed-stderr, ordinary-status and backpressure observations passed at O0 and O2.'
