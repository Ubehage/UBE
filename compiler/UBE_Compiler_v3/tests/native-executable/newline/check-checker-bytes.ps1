param([Parameter(Mandatory=$true)][string] $Compiler)
$ErrorActionPreference = 'Stop'
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$root = Split-Path $PSScriptRoot -Parent
$project = (Resolve-Path -LiteralPath (Join-Path $root 'rejections/divide/RejectDivide.UBE')).Path
$source = (Resolve-Path -LiteralPath (Join-Path $root 'rejections/divide/App.bas')).Path.Replace('\','/')
$logical = '"' + $source + '"' + "`n" + 'error UBE1411: constant integer division by zero (next lines: line, column, byte)' + "`n4`n12`n82`n"
$utf8 = [Text.UTF8Encoding]::new($false, $true)
$expected = [BitConverter]::ToString($utf8.GetBytes($logical.Replace("`n", "`r`n")))
$wrong = [BitConverter]::ToString($utf8.GetBytes($logical))
if ($expected -eq $wrong) { throw 'LF mutation did not change expected bytes' }
foreach ($jobs in @(1,4)) {
    $process = [Diagnostics.Process]::new()
    $process.StartInfo.FileName = $compilerPath
    $process.StartInfo.Arguments = '--check "' + $project + '" --jobs ' + $jobs
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    $stdout = [IO.MemoryStream]::new(); $stderr = [IO.MemoryStream]::new()
    try {
        if (-not $process.Start()) { throw 'Checker did not start' }
        $outTask = $process.StandardOutput.BaseStream.CopyToAsync($stdout)
        $errTask = $process.StandardError.BaseStream.CopyToAsync($stderr)
        if (-not $process.WaitForExit(30000)) { $process.Kill(); $process.WaitForExit(); throw 'Checker timed out' }
        [void]$outTask.GetAwaiter().GetResult(); [void]$errTask.GetAwaiter().GetResult()
        $actual = [BitConverter]::ToString($stdout.ToArray())
        if ($process.ExitCode -ne 1 -or $stderr.Length -ne 0 -or $actual -ne $expected -or $actual -eq $wrong) {
            throw "Raw diagnostic mismatch at jobs $jobs; exit=$($process.ExitCode)"
        }
        Write-Output "jobs=$jobs : raw CRLF bytes matched; LF-only control rejected."
    } finally { $stdout.Dispose(); $stderr.Dispose(); $process.Dispose() }
}
Write-Output "Compiler SHA256: $((Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash)"
