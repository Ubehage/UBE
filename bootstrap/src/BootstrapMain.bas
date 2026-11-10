Attribute VB_Name = "BootstrapMain"
Option Explicit

' Loads, parses and checks an ordered project with caller-owned compiler state.
Private Declare Sub ExitProcess Lib "kernel32" (ByVal ExitCode As Long)

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
    On Error GoTo Unexpected
    If Not ReadArguments(Arguments, ArgumentCount, Diagnostic) Then GoTo Usage
    If ArgumentCount <> 3 Then GoTo Usage
    Mode = Arguments(1)
    If Mode <> "--check" And Mode <> "--parse" And Mode <> "--dump-ast" And Mode <> "--analyze" And Mode <> "--dump-bound" Then GoTo Usage
    If Not LoadProject(Arguments(2), Project, Diagnostic) Then GoTo Failed
    If Mode <> "--check" Then
        If Not ParseProject(Project, Parsed, Diagnostic) Then GoTo Failed
    End If
    If Mode = "--analyze" Or Mode = "--dump-bound" Then
        If Not BindProject(Project, Parsed, Bound, Diagnostic) Then GoTo Failed
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
    If Mode = "--check" Then
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
    ExitProcess 2
    Exit Sub
OutputFailed:
    Diagnostic = "UBE: E_IO: cannot write command output"
Failed:
    Call WriteOutput(Diagnostic, True)
    ExitProcess 1
    Exit Sub
Unexpected:
    On Error Resume Next
    Call WriteOutput("UBE: E_INTERNAL: unable to complete project check", True)
    ExitProcess 1
End Sub
