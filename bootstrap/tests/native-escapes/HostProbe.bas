Attribute VB_Name = "EscapeHostProbe"
Option Explicit
Private Declare Sub ExitProcess Lib "kernel32" (ByVal ExitCode As Long)

' Exercises the host analyzer against the same runtime source fixture as the UBE gate.
Public Sub Main()
    Dim Arguments() As String, Count As Long, Text As String
    Dim Project As ProjectLoader.ProjectContext
    Dim Parsed As SourceParser.ParsedProject
    Dim Bound As SourceSemantics.BoundProject
    Dim Facts() As NativeEscapes.EscapeFact
    Dim FactCount As Long, Diagnostic As Long, Index As Long, Seen(1 To 4) As Long
    Dim Expected As Boolean, Actual As Boolean, Before As Long
    On Error GoTo Failed
    If Not HostFiles.ReadArguments(Arguments, Count, Text) Then GoTo Failed
    If Count <> 2 Then GoTo Failed
    If Not ProjectLoader.LoadProject(Arguments(1), Project, Text) Then GoTo Failed
    If Not SourceParser.ParseProject(Project, Parsed, Text) Then GoTo Failed
    If Not SourceSemantics.BindProject(Project, Parsed, Bound, Text) Then GoTo Failed
    If Not NativeEscapes.TryAnalyzeEscapes(Parsed, Bound, Parsed.NodeCount, Bound.SymbolCount, Facts, FactCount, Diagnostic) Then GoTo Failed
    If FactCount <> Parsed.NodeCount Or Diagnostic <> 0 Then GoTo Failed
    For Index = 1 To Bound.SymbolCount
        If Bound.Symbols(Index).Origin = "source" And (Bound.Symbols(Index).Kind = "variable" Or Bound.Symbols(Index).Kind = "parameter") Then
            Expected = InStr(1, "|Forwarded|Forward|Left|Right|Copy|CopyArray|Number|Elements|ForwardArray|Local|Record|Values|PayloadOnly|ThroughRelay|", "|" & Bound.Symbols(Index).Name & "|", vbTextCompare) <> 0
            Actual = Facts(Bound.Symbols(Index).DeclarationNode - 1).StorageEscapes
            If Actual <> Expected Then Text = "Unexpected owner for " & Bound.Symbols(Index).Name: GoTo Failed
        End If
    Next Index
    For Index = 0 To FactCount - 1
        If Facts(Index).NeedsOwner Then Seen(Facts(Index).OwnerKind) = Seen(Facts(Index).OwnerKind) + 1
        Before = Before + Facts(Index).OwnerKind + Facts(Index).OwnerIdentity
    Next Index
    If Seen(1) < 1 Or Seen(2) < 1 Or Seen(3) < 3 Or Seen(4) < 1 Then GoTo Failed
    If NativeEscapes.TryAnalyzeEscapes(Parsed, Bound, 131073, Bound.SymbolCount, Facts, FactCount, Diagnostic) Then GoTo Failed
    If FactCount <> 0 Or Diagnostic <> 6 Then GoTo Failed
    For Index = 0 To UBound(Facts)
        Before = Before - Facts(Index).OwnerKind - Facts(Index).OwnerIdentity
    Next Index
    If Before <> 0 Then GoTo Failed
    If Not NativeEscapes.TryAnalyzeEscapes(Parsed, Bound, Parsed.NodeCount, Bound.SymbolCount, Facts, FactCount, Diagnostic) Then GoTo Failed
    If Not HostFiles.WriteOutput("PASS: host escape ownership, bounded rejection and retry", False) Then GoTo Failed
    ExitProcess 0
    Exit Sub
Failed:
    Call HostFiles.WriteOutput("FAIL: host escape probe " & Text & " Err=" & CStr(Err.Number), True)
    ExitProcess 1
End Sub
