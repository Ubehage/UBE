Attribute VB_Name = "Emitter"
Option Explicit

' Proves that a VB6 host can emit IR for a separate native x64 backend.
Private Declare Sub ExitProcess Lib "kernel32" (ByVal ExitCode As Long)

' Writes one fixed IR fixture; reports invalid paths without an error dialog.
Public Sub Main()
    Dim OutputFile As Integer
    Dim IsOpen As Boolean
    On Error GoTo Failed
    If Len(Command$) = 0 Then ExitProcess 2
    OutputFile = FreeFile
    Open Command$ For Output As #OutputFile
    IsOpen = True
    Print #OutputFile, "target triple = ""x86_64-pc-windows-msvc"""
    Print #OutputFile, "define i32 @main() {"
    Print #OutputFile, "entry:"
    Print #OutputFile, "  ret i32 42"
    Print #OutputFile, "}"
    Close #OutputFile
    IsOpen = False
    ExitProcess 0
    Exit Sub
Failed:
    On Error Resume Next
    If IsOpen Then Close #OutputFile
    ExitProcess 3
End Sub
