# Independent observation of classic VB6's header order; UBE failure rules remain normative.
param([string]$VB6='C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE')
$ErrorActionPreference='Stop'
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube vb6 loop order '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$source=@'
Attribute VB_Name = "Probe"
Option Explicit
Private Declare Sub ExitProcess Lib "kernel32" (ByVal Code As Long)
Private Function Observe(ByRef Trace As Long, ByVal Part As Long, ByVal Counter As Long) As Long
    Trace = Trace * 100 + Part * 10 + Counter
    Observe = 1
End Function
Public Sub Main()
    Dim Counter As Long
    Dim Trace As Long
    Counter = 9
    For Counter = Observe(Trace, 1, Counter) To Observe(Trace, 2, Counter) Step Observe(Trace, 3, Counter)
        Exit For
    Next Counter
    If Counter <> 1 Then ExitProcess 99
    ExitProcess Trace
End Sub
'@
$manifest=@'
Type=Exe
Module=Probe; Probe.bas
Startup="Sub Main"
Name="LoopOrder"
ExeName32="Probe.exe"
CompilationType=0
BoundsCheck=1
OverflowCheck=1
'@
[IO.File]::WriteAllText((Join-Path $evidence 'Probe.bas'),$source,[Text.Encoding]::ASCII)
$project=Join-Path $evidence 'Probe.vbp'
[IO.File]::WriteAllText($project,$manifest,[Text.Encoding]::ASCII)
$log=Join-Path $evidence 'build.log'
$p=Start-Process -FilePath $VB6 -ArgumentList @('/make',('"'+$project+'"'),'/out',('"'+$log+'"'),'/outdir',('"'+$evidence+'"')) -WindowStyle Hidden -PassThru
try {
 $null=$p.Handle
 if(-not $p.WaitForExit(30000)){$p.Kill();throw 'VB6 build deadline'}
 $p.Refresh()
 if($p.ExitCode -ne 0){throw "VB6 build failed: $evidence"}
}finally{$p.Dispose()}
$exe=Join-Path $evidence 'Probe.exe'
if(-not [IO.File]::Exists($exe)){throw "Missing VB6 executable: $evidence"}
$p=Start-Process -FilePath $exe -WindowStyle Hidden -PassThru
try {
 $null=$p.Handle
 if(-not $p.WaitForExit(10000)){$p.Kill();throw 'VB6 execution deadline'}
 $p.Refresh()
 $code=$p.ExitCode
 [IO.File]::WriteAllText((Join-Path $evidence 'exit.txt'),[string]$code)
 if($code -ne 293919){throw "Header order differs: $code; evidence: $evidence"}
 Write-Output "PASS VB6 end/step/start order, old counter observed by all three, assigned before body; exit=$code; evidence: $evidence"
}finally{$p.Dispose()}
