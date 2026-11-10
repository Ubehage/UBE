Attribute VB_Name = "BootstrapMain"
Option Explicit

' Loads, checks and compiles an ordered project with caller-owned compiler state.
Private Declare Sub NativeExitProcess Lib "kernel32" Alias "ExitProcess" (ByVal ExitCode As Long)
Private RunningInIDE As Boolean

' Read-only host equivalent of the planned UBE compiler-supplied constant.
Public Property Get IS_IN_IDE() As Boolean
    IS_IN_IDE = RunningInIDE
End Property

' Debug.Assert evaluates its argument only inside VB6, never in a built EXE.
Private Function DetectIDE() As Boolean
    Debug.Assert MarkIDE(DetectIDE)
End Function

Private Function MarkIDE(ByRef Detected As Boolean) As Boolean
    Detected = True
    MarkIDE = True
End Function

' Returning lets Sub Main finish without terminating the hosting VB6 process.
Private Sub ExitProcess(ByVal ExitCode As Long)
    If Not IS_IN_IDE Then NativeExitProcess ExitCode
End Sub

' Runs the bounded inspection commands without invoking the VB6 interactive error UI.
Public Sub Main()
    Dim Arguments() As String
    Dim ArgumentCount As Long
    Dim Diagnostic As String
    Dim Project As ProjectContext
    Dim Index As Long
    Dim Parsed As ParsedProject
    Dim Bound As BoundProject
    Dim Mode As String
    Dim IRText As String
    Dim ClangPath As String
    Dim NativeMode As Boolean
    On Error GoTo Unexpected
    RunningInIDE = DetectIDE()
    If Not ReadArguments(Arguments, ArgumentCount, Diagnostic) Then GoTo Usage
    If ArgumentCount < 3 Then GoTo Usage
    Mode = Arguments(1)
    NativeMode = (Mode = "--emit-llvm" Or Mode = "--build")
    If NativeMode Then
        If Mode = "--build" And ArgumentCount = 6 Then
            If Arguments(4) <> "--clang" Then GoTo Usage
            ClangPath = Arguments(5)
        ElseIf ArgumentCount <> 4 Then
            GoTo Usage
        End If
    Else
        If ArgumentCount <> 3 Then GoTo Usage
        If Mode <> "--check" And Mode <> "--parse" And Mode <> "--dump-ast" And Mode <> "--analyze" And Mode <> "--dump-bound" Then GoTo Usage
    End If
    If Not LoadProject(Arguments(2), Project, Diagnostic) Then GoTo Failed
    If Mode <> "--check" Then
        If Not ParseProject(Project, Parsed, Diagnostic) Then GoTo Failed
    End If
    If Mode = "--analyze" Or Mode = "--dump-bound" Or NativeMode Then
        If Not BindProject(Project, Parsed, Bound, Diagnostic) Then GoTo Failed
    End If
    If NativeMode Then
        If Not EmitProject(Project, Parsed, Bound, IRText, Diagnostic) Then GoTo Failed
        If Mode = "--emit-llvm" Then
            If Not WriteLLVMOutput(Project, IRText, Arguments(3), Diagnostic) Then GoTo Failed
        Else
            If Not BuildNativeProject(Project, IRText, Arguments(3), ClangPath, Diagnostic) Then GoTo Failed
        End If
    End If
    If Not WriteOutput("PROJECT " & Project.ProjectName, False) Then GoTo OutputFailed
    For Index = 0 To Project.SourceCount - 1
        If Not WriteOutput("MODULE " & Project.Sources(Index).ModuleName, False) Then GoTo OutputFailed
    Next Index
    If Mode = "--dump-ast" Then
        For Index = 1 To Parsed.NodeCount
            If Not WriteOutput(FormatNode(Parsed, Index), False) Then GoTo OutputFailed
        Next Index
    End If
    If Mode = "--dump-bound" Then
        If Not WriteOutput("ENTRY " & CStr(Bound.EntrySymbol), False) Then GoTo OutputFailed
        For Index = 1 To Bound.SymbolCount
            If Not WriteOutput(FormatSymbol(Bound, Index), False) Then GoTo OutputFailed
        Next Index
        For Index = 1 To Bound.NodeCount
            If Not WriteOutput(FormatBinding(Bound, Index), False) Then GoTo OutputFailed
        Next Index
    End If
    If Mode = "--emit-llvm" Then
        If Not WriteOutput("EMIT OK", False) Then GoTo OutputFailed
    ElseIf Mode = "--build" Then
        If Not WriteOutput("BUILD OK", False) Then GoTo OutputFailed
    ElseIf Mode = "--check" Then
        If Not WriteOutput("CHECK OK", False) Then GoTo OutputFailed
    ElseIf Mode = "--analyze" Or Mode = "--dump-bound" Then
        If Not WriteOutput("ANALYZE OK", False) Then GoTo OutputFailed
    Else
        If Not WriteOutput("PARSE OK", False) Then GoTo OutputFailed
    End If
    ExitProcess 0
    Exit Sub
Usage:
    Call WriteOutput("UBE: E_USAGE: usage: UBE-Bootstrap --check|--parse|--dump-ast|--analyze|--dump-bound <project.UBE>", True)
    Call WriteOutput("UBE: E_USAGE: or --emit-llvm <project.UBE> <output.ll> | --build <project.UBE> <output.exe> [--clang <path>]", True)
    ExitProcess 2
    Exit Sub
OutputFailed:
    Diagnostic = "UBE: E_IO: cannot write command output"
Failed:
    Call WriteOutput(Diagnostic, True)
    ExitProcess 1
    Exit Sub
Unexpected:
    ' Resume clears VB6's active handler before diagnostic output can fail again.
    Resume ReportUnexpected
ReportUnexpected:
    On Error Resume Next
    Call WriteOutput("UBE: E_INTERNAL: unable to complete project command", True)
    ExitProcess 1
End Sub
