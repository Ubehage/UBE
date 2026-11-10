# Exercises the actual Main recovery tail with a second error during reporting.
param([string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube host error recovery ' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $artifacts
$ascii = [Text.Encoding]::ASCII

# Bounds each compiler/probe process and retains its exit status.
function Run-Process([string]$File, [string[]]$Arguments, [string]$Directory) {
    $start = @{ FilePath=$File; WorkingDirectory=$Directory; WindowStyle='Hidden'; PassThru=$true }
    if ($Arguments.Count) { $start.ArgumentList = (($Arguments | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' ') }
    $process = Start-Process @start
    try {
        $handle = $process.Handle
        if (-not $process.WaitForExit(30000)) {
            $process.Kill()
            $null = $process.WaitForExit(5000)
            throw "Process timeout: $File"
        }
        $process.Refresh()
        if ($null -eq $process.ExitCode) { throw "Missing exit status for $handle" }
        return $process.ExitCode
    } finally { $process.Dispose() }
}

$source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '../../src/BootstrapMain.bas'))
$match = [regex]::Match($source, '(?ms)^Unexpected:\r?\n.*?^End Sub')
if (-not $match.Success) { throw 'Main recovery tail not found' }
$tail = $match.Value
$helpers = [regex]::Match($source, '(?ms)^Private RunningInIDE As Boolean\r?\n.*?(?=^'' Runs the bounded inspection)').Value
if (-not $helpers) { throw 'Host IDE detection/shutdown helpers not found' }
$oldTail = [regex]::Replace($tail, "(?m)^    ' Resume clears[^\r\n]*\r?\n", '')
$oldTail = $oldTail.Replace("    Resume ReportUnexpected`r`nReportUnexpected:`r`n", '').Replace("    Resume ReportUnexpected`nReportUnexpected:`n", '')
if ($oldTail -ceq $tail) { throw 'Recovery negative control did not remove Resume' }

foreach ($legacy in @($true, $false)) {
    foreach ($reportFails in @($false, $true)) {
        $directory = Join-Path $artifacts ("legacy-$legacy-reportFails-$reportFails")
        $null = New-Item -ItemType Directory -Path $directory
        $handler = $tail
        if ($legacy) { $handler = $oldTail }
        $report = '    WriteOutput = True'
        if ($reportFails) { $report = '    Err.Raise 5' }
        # The caller catches escaped errors so the old failure cannot display a VB6 dialog.
        $probe = @"
Attribute VB_Name = "RecoveryProbe"
Option Explicit
Private Declare Sub NativeExitProcess Lib "kernel32" Alias "ExitProcess" (ByVal Code As Long)
$helpers
Public Sub Main()
    On Error GoTo Escaped
    RunProbe
    ExitProcess 78
    Exit Sub
Escaped:
    ExitProcess 77
End Sub
Private Sub RunProbe()
    On Error GoTo Unexpected
    Err.Raise 6
    ExitProcess 79
    Exit Sub
$handler
Private Function WriteOutput(ByVal Message As String, ByVal IsError As Boolean) As Boolean
$report
End Function
"@
        $project = @'
Type=Exe
Module=RecoveryProbe; RecoveryProbe.bas
Startup="Sub Main"
Name="HostRecoveryTest"
ExeName32="RecoveryProbe.exe"
CompilationType=0
OptimizationType=0
BoundsCheck=1
OverflowCheck=1
ThreadPerObject=0
MaxNumberOfThreads=1
'@
        [IO.File]::WriteAllText((Join-Path $directory 'RecoveryProbe.bas'), ($probe -replace '\r?\n', "`r`n") + "`r`n", $ascii)
        $vbp = Join-Path $directory 'RecoveryProbe.vbp'
        [IO.File]::WriteAllText($vbp, ($project -replace '\r?\n', "`r`n") + "`r`n", $ascii)
        $log = Join-Path $directory 'build.log'
        $code = Run-Process $VB6 @('/make', $vbp, '/out', $log, '/outdir', $directory) $directory
        $exe = Join-Path $directory 'RecoveryProbe.exe'
        if ($code -ne 0 -or -not (Test-Path -LiteralPath $exe)) { throw "Probe build failed: $log" }
        $code = Run-Process $exe @() $directory
        $expected = 1
        if ($legacy -and $reportFails) { $expected = 77 }
        if ($code -ne $expected) { throw "Expected exit $expected, got $code in $directory" }
        Write-Output "PASS: legacy=$legacy reportingFailure=$reportFails exit=$code"
    }
}
Write-Output "PASS: 4 host recovery cases. Evidence: $artifacts"
