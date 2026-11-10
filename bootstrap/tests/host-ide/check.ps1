param([string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube host ide ' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $artifacts
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$ascii = [Text.Encoding]::ASCII
function Write-Source([string]$Name, [string]$Text) {
    [IO.File]::WriteAllText((Join-Path $artifacts $Name), ($Text -replace '\r?\n', "`r`n"), $ascii)
}
function Run-Process([string]$File, [string[]]$Arguments) {
    $p = Start-Process -FilePath $File -ArgumentList (($Arguments | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' ') -WorkingDirectory $artifacts -WindowStyle Hidden -PassThru
    try {
        $handle = $p.Handle
        if (-not $p.WaitForExit(30000)) { $p.Kill(); $null = $p.WaitForExit(5000); throw "Timeout: $File" }
        $p.Refresh()
        if ($null -eq $p.ExitCode) { throw "Missing exit code: $handle" }
        return $p.ExitCode
    } finally { $p.Dispose() }
}
# Compile actual Main and its helpers. Only command input/output are test doubles.
foreach ($f in Get-ChildItem (Join-Path $root 'src') -Filter *.bas) { Copy-Item -LiteralPath $f.FullName -Destination $artifacts }
$main = [IO.File]::ReadAllText((Join-Path $artifacts 'BootstrapMain.bas'))
if ([regex]::Matches($main, '(?m)^    If Not IS_IN_IDE Then NativeExitProcess ExitCode\r?$').Count -ne 1 -or [regex]::Matches($main, '(?m)^    NativeExitProcess ').Count -ne 0) { throw 'Unprotected host termination' }
Write-Source 'BootstrapMain.bas' ($main.Replace('Public Sub Main()', 'Public Sub RunCommand()'))
$hostSource = [IO.File]::ReadAllText((Join-Path $artifacts 'HostFiles.bas'))
$arguments = @'
Public Function ReadArguments(ByRef Arguments() As String, ByRef Count As Long, ByRef Diagnostic As String) As Boolean
    If Probe.CaseName = "unexpected" Then Err.Raise 5
    If Probe.CaseName = "usage" Then Exit Function
    Count = 3
    ReDim Arguments(0 To 2)
    Arguments(0) = "probe"
    Arguments(1) = "--check"
    Arguments(2) = App.Path & "\fixture.UBE"
    If Probe.CaseName = "failed" Then Arguments(2) = App.Path & "\missing.UBE"
    ReadArguments = True
End Function
'@
$output = @'
Public Function WriteOutput(ByVal Text As String, ByVal IsError As Boolean) As Boolean
    Dim FileNumber As Integer
    FileNumber = FreeFile
    Open App.Path & "\output.txt" For Append As #FileNumber
    Print #FileNumber, Text
    Close #FileNumber
    WriteOutput = (Probe.CaseName <> "output")
End Function
'@
$hostSource = [regex]::Replace($hostSource, '(?ms)^Public Function ReadArguments\(.*?^End Function', [System.Text.RegularExpressions.MatchEvaluator]{param($m) $arguments})
$hostSource = [regex]::Replace($hostSource, '(?ms)^Public Function WriteOutput\(.*?^End Function', [System.Text.RegularExpressions.MatchEvaluator]{param($m) $output})
Write-Source 'HostFiles.bas' $hostSource
Write-Source 'Probe.bas' @'
Attribute VB_Name = "Probe"
Option Explicit
Public CaseName As String
Public Sub Main()
    Dim FileNumber As Integer
    FileNumber = FreeFile
    Open App.Path & "\case.txt" For Input As #FileNumber
    Line Input #FileNumber, CaseName
    Close #FileNumber
    BootstrapMain.RunCommand
    FileNumber = FreeFile
    Open App.Path & "\returned.txt" For Output As #FileNumber
    Print #FileNumber, CStr(BootstrapMain.IS_IN_IDE)
    Close #FileNumber
End Sub
'@
$project = [IO.File]::ReadAllText((Join-Path $root 'UBE-Bootstrap.vbp')).Replace('src\', '').Replace('Module=BootstrapMain;', "Module=Probe; Probe.bas`r`nModule=BootstrapMain;")
Write-Source 'Probe.vbp' $project
Write-Source 'fixture.UBE' "UBE-Project 1`r`nName = `"Probe`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nSource = `"Example.bas`"`r`n"
Write-Source 'Example.bas' "UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"Example`"`r`nPublic Sub Main()`r`nEnd Sub`r`n"
$vbp = Join-Path $artifacts 'Probe.vbp'
$log = Join-Path $artifacts 'build.log'
$code = Run-Process $VB6 @('/make', $vbp, '/out', $log, '/outdir', $artifacts)
if ($code -ne 0 -or -not (Test-Path (Join-Path $artifacts 'UBE-Bootstrap.exe'))) { throw "Build failed: $log" }
foreach ($case in @('success','usage','failed','output','unexpected')) {
    Write-Source 'case.txt' ($case + "`r`n")
    $marker = Join-Path $artifacts 'returned.txt'
    if (Test-Path $marker) { Remove-Item -LiteralPath $marker }
    $expected = 1
    if ($case -eq 'success') { $expected = 0 }
    if ($case -eq 'usage') { $expected = 2 }
    $code = Run-Process (Join-Path $artifacts 'UBE-Bootstrap.exe') @('probe')
    if ($code -ne $expected -or (Test-Path $marker)) { throw "EXE $case expected termination $expected; got $code. Evidence: $artifacts" }
    $code = Run-Process $VB6 @('/runexit', $vbp, '/out', (Join-Path $artifacts ($case + '.log')))
    if ($code -ne 0 -or -not (Test-Path $marker)) { throw "IDE $case did not return normally: $code" }
    if ([IO.File]::ReadAllText($marker).Trim() -cne 'True') { throw "IDE $case flag is not True" }
    Copy-Item -LiteralPath $marker -Destination (Join-Path $artifacts ($case + '.returned.txt'))
    Write-Output "PASS: $case EXE exits $expected; IDE returns with IS_IN_IDE=True"
}
# Negative control restores the old unconditional termination in an isolated IDE.
Write-Source 'BootstrapMain.bas' ($main.Replace('Public Sub Main()', 'Public Sub RunCommand()').Replace('If Not IS_IN_IDE Then NativeExitProcess ExitCode', 'NativeExitProcess ExitCode'))
Write-Source 'case.txt' "success`r`n"
Remove-Item -LiteralPath $marker
$code = Run-Process $VB6 @('/runexit', $vbp, '/out', (Join-Path $artifacts 'negative.log'))
if ($code -ne 0 -or (Test-Path $marker)) { throw 'Unconditional-termination negative control did not reproduce lost return' }
Write-Output "PASS: 10 host termination cases and old-behavior negative control. Evidence: $artifacts"
