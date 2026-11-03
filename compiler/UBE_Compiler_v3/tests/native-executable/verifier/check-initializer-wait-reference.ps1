param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'initializer-wait-reference.c'
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
foreach ($optimization in @('0','2')) {
    $exe = Join-Path $OutputDirectory "initializer-wait-$optimization.exe"
    & $Clang --target=x86_64-w64-windows-gnu -std=c17 "-O$optimization" -Wall -Wextra -Werror $source -o $exe
    if ($LASTEXITCODE -ne 0) { throw 'Wait reference compilation failed' }
    foreach ($mode in @('early','wait','recursive-control','stall-control')) {
        $process = [Diagnostics.Process]::new()
        $process.StartInfo.FileName = (Resolve-Path -LiteralPath $exe).Path
        $process.StartInfo.Arguments = $mode
        $process.StartInfo.UseShellExecute = $false; $process.StartInfo.CreateNoWindow = $true
        $process.StartInfo.RedirectStandardOutput = $true; $process.StartInfo.RedirectStandardError = $true
        $started = $false
        try {
            $started = $process.Start()
            if (-not $started) { throw 'Reference process did not start' }
            $stderr = $process.StandardError.ReadToEndAsync()
            $events = @()
            $wantedCount = if ($mode -eq 'early') { 5 } else { 3 }
            for ($i = 0; $i -lt $wantedCount; $i++) {
                $line = $process.StandardOutput.ReadLineAsync()
                if (-not $line.Wait(5000) -or $null -eq $line.Result) { throw "Event deadline or EOF: $mode" }
                $events += $line.Result
            }
            if ($mode -eq 'early') {
                if (-not $process.WaitForExit(5000) -or $process.ExitCode -ne 0 -or ($events -join ',') -cne 'A-enter,B-enter,B-complete,A-complete,main=81' -or $stderr.Result -ne '') { throw 'Early access reference differed' }
                Write-Output "O$optimization early: completed with result 81."
            } else {
                $accepted = ($events -join ',') -ceq 'A-enter,B-enter,wait:A'
                if ($accepted -ne ($mode -eq 'wait')) { throw "Wait comparator did not distinguish $mode" }
                $extra = $process.StandardOutput.ReadLineAsync()
                if ($extra.Wait(250) -or $process.WaitForExit(0)) { throw "Unexpected output or exit after barrier: $mode" }
                $process.Kill()
                if (-not $process.WaitForExit(5000) -or $null -ne $extra.Result -or $stderr.Result -ne '') { throw "Reference cleanup or streams failed: $mode" }
                Write-Output "O$optimization $mode : sequence-accepted=$accepted; child stopped and exit observed."
            }
        } finally {
            if ($started -and -not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
            $process.Dispose()
        }
    }
}
