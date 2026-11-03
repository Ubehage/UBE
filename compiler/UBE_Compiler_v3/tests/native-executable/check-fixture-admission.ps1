param([string]$Compiler = (Join-Path $PSScriptRoot '../../../../bootstrap/out/v3/ube.exe'))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$fixtures = @(
    'alias/Alias.UBE', 'empty/Empty.UBE', 'fold/Fold.UBE',
    'signed/Signed.UBE', 'native/NativeApp.UBE', 'order/Order.UBE',
    'neutral/Neutral.UBE', 'eager/Eager.UBE', 'optional/Optional.UBE',
    'overflow/Overflow.UBE', 'conditions/Conditions.UBE',
    'conversion/Conversion.UBE', 'recursion/Recursion.UBE', 'negative/Negative.UBE',
    'native-widths/NativeWidths.UBE', 'bitwise/Bitwise.UBE',
    'comparisons/Comparisons.UBE', 'booleans/Booleans.UBE', 'startup/Startup.UBE'
)
function IsExpectedResult([int]$ExitCode, [string]$Stdout, [string]$Stderr) {
    return $ExitCode -eq 0 -and $Stdout.Length -eq 0 -and $Stderr.Length -eq 0
}
if (IsExpectedResult 1 '' '') { throw 'Nonzero-exit control was not rejected.' }
if (IsExpectedResult 0 'unexpected' '') { throw 'Output control was not rejected.' }
if (IsExpectedResult 0 '' 'unexpected') { throw 'Error-output control was not rejected.' }
$count = 0
foreach ($fixture in $fixtures) {
    $path = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "fixtures/$fixture")).Path
    foreach ($jobs in @(1, 4)) {
        $info = New-Object System.Diagnostics.ProcessStartInfo
        $info.FileName = $compilerPath
        $info.Arguments = '--check "' + $path + '" --jobs ' + $jobs
        $info.UseShellExecute = $false
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $info
        try {
            if (-not $process.Start()) { throw 'Could not start checker.' }
            $stdoutTask = $process.StandardOutput.ReadToEndAsync()
            $stderrTask = $process.StandardError.ReadToEndAsync()
            if (-not $process.WaitForExit(30000)) {
                $process.Kill()
                $process.WaitForExit()
                throw "Checker timed out: $fixture jobs=$jobs"
            }
            $stdout = $stdoutTask.GetAwaiter().GetResult()
            $stderr = $stderrTask.GetAwaiter().GetResult()
            if (-not (IsExpectedResult $process.ExitCode $stdout $stderr)) {
                throw "Checker rejected $fixture jobs=$jobs exit=$($process.ExitCode) stdout=$stdout stderr=$stderr"
            }
            $count++
        } finally { $process.Dispose() }
    }
}
$hash = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
Write-Output "Fixture admission: $count checks passed; three comparator controls passed."
Write-Output "Checker SHA256: $hash"
Write-Output 'This checks frontend admission only; native behavior is not tested.'
