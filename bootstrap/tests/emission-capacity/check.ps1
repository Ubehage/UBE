# Executes the actual seed AddLine procedure at its byte/line boundaries and reproduces the former cap.
param([string]$VB6='C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$source=[IO.File]::ReadAllText((Join-Path $root 'bootstrap/src/SourceEmitter.bas'))
$procedure=[regex]::Match($source,'(?ms)^Private Sub AddLine\([^\r\n]*\r?\n.*?^End Sub').Value
if(-not $procedure){throw 'Missing production AddLine procedure'}
$limits=[regex]::Matches($source,'(?m)^Public Const MaximumIR(?:Characters|Lines) As Long = [0-9]+').Value -join "`r`n"
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube emission capacity '+[guid]::NewGuid())
$null=New-Item -ItemType Directory $evidence
$body=@'
Attribute VB_Name = "Probe"
Option Explicit
Private Declare Sub ExitProcess Lib "kernel32" (ByVal Code As Long)
Private Type EmissionState
 Lines() As String
 LineCount As Long
 CharacterCount As Long
 Failed As Boolean
 FailureDetail As String
End Type
LIMITS
PROCEDURE
Public Sub Main()
 Dim State As EmissionState
 On Error GoTo Failed
 ReDim State.Lines(0 To 500001)
 State.LineCount = 500000
 State.CharacterCount = 20459812
 AddLine State, "ret i32 0"
 If State.Failed Or State.LineCount <> 500001 Or State.CharacterCount <> 20459823 Then ExitProcess 10
 ReDim State.Lines(0 To MaximumIRLines - 1)
 State.LineCount = MaximumIRLines - 1
 State.CharacterCount = 0
 AddLine State, "last"
 If State.Failed Or State.LineCount <> MaximumIRLines Or State.CharacterCount <> 6 Then ExitProcess 11
 AddLine State, "refused"
 If Not State.Failed Or State.LineCount <> MaximumIRLines Or State.CharacterCount <> 6 Then ExitProcess 12
 If State.Lines(MaximumIRLines - 1) <> "last" Then ExitProcess 13
 State.Failed = False
 ReDim State.Lines(0 To 1)
 State.LineCount = 0
 State.CharacterCount = MaximumIRCharacters - 4
 AddLine State, "ok"
 If State.Failed Or State.CharacterCount <> MaximumIRCharacters Then ExitProcess 14
 AddLine State, ""
 If Not State.Failed Or State.LineCount <> 1 Or State.CharacterCount <> MaximumIRCharacters Then ExitProcess 15
 AddLine State, "ignored after refusal"
 If State.LineCount <> 1 Or State.CharacterCount <> MaximumIRCharacters Then ExitProcess 16
 ExitProcess 0
 Exit Sub
Failed:
 ExitProcess 99
End Sub
'@
$body=$body.Replace('LIMITS',$limits).Replace('PROCEDURE',$procedure)
foreach($case in @(@('current',$body,0),@('former',$body.Replace('MaximumIRLines As Long = 1048576','MaximumIRLines As Long = 500000'),10))){
 $folder=Join-Path $evidence $case[0];$null=New-Item -ItemType Directory $folder
 [IO.File]::WriteAllText((Join-Path $folder 'Probe.bas'),$case[1],[Text.Encoding]::ASCII)
 $manifest="Type=Exe`r`nModule=Probe; Probe.bas`r`nStartup=`"Sub Main`"`r`nName=`"CapacityCheck`"`r`nExeName32=`"Probe.exe`"`r`nCompilationType=0`r`nBoundsCheck=1`r`nOverflowCheck=1`r`n"
 [IO.File]::WriteAllText((Join-Path $folder 'Probe.vbp'),$manifest,[Text.Encoding]::ASCII)
 $p=Start-Process $VB6 -ArgumentList @('/make',('"'+$folder+'\Probe.vbp"'),'/out',('"'+$folder+'\build.log"'),'/outdir',('"'+$folder+'"')) -WindowStyle Hidden -PassThru
 try{$null=$p.Handle;if(-not $p.WaitForExit(30000)){$p.Kill();throw 'Build deadline'};$p.Refresh();if($p.ExitCode -ne 0){throw "Build failed: $folder"}}finally{$p.Dispose()}
 $p=Start-Process (Join-Path $folder 'Probe.exe') -WindowStyle Hidden -PassThru
 try{$null=$p.Handle;if(-not $p.WaitForExit(10000)){$p.Kill();throw 'Probe deadline'};$p.Refresh();if($p.ExitCode -ne $case[2]){throw "Unexpected exit $($p.ExitCode): $folder"}}finally{$p.Dispose()}
}
Write-Output "PASS actual seed AddLine accepts compiler-sized output, enforces exact line/character bounds, preserves state on refusal; former cap negative control exits10. Evidence: $evidence"
