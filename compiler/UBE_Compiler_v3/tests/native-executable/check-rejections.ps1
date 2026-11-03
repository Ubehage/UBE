param([string]$Compiler = (Join-Path $PSScriptRoot '../../../../bootstrap/out/v3/ube.exe'))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$cases = @(
    @{ Project = 'divide/RejectDivide.UBE'; Source = 'divide/App.bas'; Hash = '8E76F0BC572BEB14391D030B9A48DF357C085E40752397A4CE785696B270755D'; Code = 'UBE1411'; Message = 'constant integer division by zero'; Column = 12; Byte = 82 },
    @{ Project = 'range/RejectRange.UBE'; Source = 'range/App.bas'; Hash = '121FC254E2DA037314F8DE0CF2018C22FD3ED4ABECA843A1D5700CB3FB2E10F5'; Code = 'UBE1410'; Message = 'constant value is outside its selected integer range'; Column = 24; Byte = 94 },
    @{ Project = 'deferred/DeferredText.UBE'; Source = 'deferred/App.bas'; Hash = '8196D354C1F061549271E37D62517DC9F228D223D4244D57A12EB077C7D6FA29'; Code = 'UBE1433'; Message = 'datatype semantics are not implemented'; Column = 20; Byte = 90 }
)
function MatchesExpected([int]$ExitCode, [string]$Stdout, [string]$Stderr, [string]$Expected) {
    return $ExitCode -eq 1 -and $Stdout -ceq $Expected -and $Stderr.Length -eq 0
}
if (MatchesExpected 0 'expected' '' 'expected') { throw 'Exit control failed.' }
if (MatchesExpected 1 'wrong' '' 'expected') { throw 'Message control failed.' }
if (MatchesExpected 1 'expected' 'unexpected' 'expected') { throw 'Stderr control failed.' }
$count = 0
foreach ($case in $cases) {
    $project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "rejections/$($case.Project)")).Path
    $sourcePath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "rejections/$($case.Source)")).Path
    if ((Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash -cne $case.Hash) { throw "Fixture bytes differ: $($case.Source)" }
    $source = $sourcePath.Replace('\', '/')
    $newline = [Environment]::NewLine
    $expected = '"' + $source + '"' + $newline + 'error ' + $case.Code + ': ' + $case.Message + ' (next lines: line, column, byte)' + $newline + '4' + $newline + $case.Column + $newline + $case.Byte + $newline
    foreach ($jobs in @(1, 4)) {
        $info = New-Object System.Diagnostics.ProcessStartInfo
        $info.FileName = $compilerPath
        $info.Arguments = '--check "' + $project + '" --jobs ' + $jobs
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
                throw "Checker timed out: $($case.Project) jobs=$jobs"
            }
            $stdout = $stdoutTask.GetAwaiter().GetResult()
            $stderr = $stderrTask.GetAwaiter().GetResult()
            if (-not (MatchesExpected $process.ExitCode $stdout $stderr $expected)) {
                throw "Unexpected diagnostic: $($case.Project) jobs=$jobs exit=$($process.ExitCode) stdout=$stdout stderr=$stderr"
            }
            $count++
        } finally { $process.Dispose() }
    }
}
$hash = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
Write-Output "Frontend rejection: $count exact comparisons passed; three comparator controls passed."
Write-Output "Checker SHA256: $hash"
Write-Output 'This does not test native build, tool launch or output publication.'
