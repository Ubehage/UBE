Attribute VB_Name = "EscapeCapacityProbe"
Option Explicit
Private Declare Sub ExitProcess Lib "kernel32" (ByVal ExitCode As Long)

' An asynchronous alias at the last retained node must promote its real local owner.
Private Function CheckGraph(ByVal Count As Long) As Boolean
    Dim Parsed As SourceParser.ParsedProject
    Dim Bound As SourceSemantics.BoundProject
    Dim Facts() As NativeEscapes.EscapeFact
    Dim Previous() As NativeEscapes.EscapeFact
    Dim FactCount As Long, Diagnostic As Long, Index As Long
    Parsed.NodeCount = Count
    Bound.NodeCount = Count
    Bound.SymbolCount = 5
    ReDim Parsed.Nodes(1 To Count)
    ReDim Bound.Nodes(1 To Count)
    ReDim Bound.Symbols(1 To 5)
    Bound.Symbols(1).Kind = "module"
    Bound.Symbols(2).Kind = "sub": Bound.Symbols(2).ScopeSymbol = 1
    Bound.Symbols(3).Kind = "variable": Bound.Symbols(3).ScopeSymbol = 2
    Bound.Symbols(3).DeclarationNode = 3
    Bound.Symbols(4).Kind = "sub": Bound.Symbols(4).ScopeSymbol = 1
    Bound.Symbols(4).FirstParameter = 5
    Bound.Symbols(5).Kind = "parameter": Bound.Symbols(5).ScopeSymbol = 4
    Bound.Symbols(5).DeclarationNode = 5
    Parsed.Nodes(Count - 2).Kind = "thread-start"
    Parsed.Nodes(Count - 2).FirstChild = Count - 1
    Parsed.Nodes(Count - 1).NextSibling = Count
    Bound.Nodes(Count - 2).SymbolIndex = 4
    Bound.Nodes(Count).ArgumentMode = "alias"
    Bound.Nodes(Count).SymbolIndex = 3
    If Not NativeEscapes.TryAnalyzeEscapes(Parsed, Bound, Count, 5, Facts, FactCount, Diagnostic) Then Exit Function
    If FactCount <> Count Or Diagnostic <> 0 Then Exit Function
    If Not Facts(2).StorageEscapes Or Not Facts(Count - 1).NeedsOwner Then Exit Function
    If Facts(Count - 1).OwnerKind <> NativeEscapes.SymbolOwner Or Facts(Count - 1).OwnerIdentity <> 3 Then Exit Function
    Previous = Facts
    If NativeEscapes.TryAnalyzeEscapes(Parsed, Bound, Count + 1, 5, Facts, FactCount, Diagnostic) Then Exit Function
    If FactCount <> 0 Or Diagnostic <> 6 Then Exit Function
    ReDim Preserve Parsed.Nodes(1 To Count - 1)
    If NativeEscapes.TryAnalyzeEscapes(Parsed, Bound, Count, 5, Facts, FactCount, Diagnostic) Then Exit Function
    If FactCount <> 0 Or Diagnostic <> 6 Then Exit Function
    ReDim Preserve Parsed.Nodes(1 To Count)
    If NativeEscapes.TryAnalyzeEscapes(Parsed, Bound, Count - 1, 5, Facts, FactCount, Diagnostic) Then Exit Function
    If FactCount <> 0 Or Diagnostic <> 6 Then Exit Function
    ReDim Preserve Bound.Nodes(1 To Count - 1)
    If NativeEscapes.TryAnalyzeEscapes(Parsed, Bound, Count, 5, Facts, FactCount, Diagnostic) Then Exit Function
    If FactCount <> 0 Or Diagnostic <> 6 Then Exit Function
    ReDim Preserve Bound.Nodes(1 To Count)
    Bound.Nodes(Count).ArgumentMode = "alias": Bound.Nodes(Count).SymbolIndex = 3
    ReDim Preserve Bound.Symbols(1 To 4)
    If NativeEscapes.TryAnalyzeEscapes(Parsed, Bound, Count, 5, Facts, FactCount, Diagnostic) Then Exit Function
    If FactCount <> 0 Or Diagnostic <> 6 Then Exit Function
    ReDim Preserve Bound.Symbols(1 To 5)
    Bound.Symbols(5).Kind = "parameter": Bound.Symbols(5).ScopeSymbol = 4: Bound.Symbols(5).DeclarationNode = 5
    If UBound(Facts) <> Count - 1 Or Not Facts(2).StorageEscapes Or Not Facts(Count - 1).NeedsOwner Then Exit Function
    For Index = 0 To Count - 1
        If Facts(Index).OwnerKind <> Previous(Index).OwnerKind Or Facts(Index).OwnerIdentity <> Previous(Index).OwnerIdentity Then Exit Function
        If Facts(Index).StorageEscapes <> Previous(Index).StorageEscapes Or Facts(Index).NeedsOwner <> Previous(Index).NeedsOwner Then Exit Function
    Next Index
    If Not NativeEscapes.TryAnalyzeEscapes(Parsed, Bound, Count, 5, Facts, FactCount, Diagnostic) Then Exit Function
    CheckGraph = FactCount = Count And Diagnostic = 0 And Facts(2).StorageEscapes And Facts(Count - 1).OwnerIdentity = 3
End Function

Public Sub Main()
    On Error GoTo Failed
    If Not CheckGraph(131072) Then GoTo Failed
    If Not CheckGraph(131073) Then GoTo Failed
    If Not CheckGraph(180025) Then GoTo Failed
    If Not HostFiles.WriteOutput("PASS: escape capacity, retained ownership, rejection and retry", False) Then GoTo Failed
    ExitProcess 0
    Exit Sub
Failed:
    Call HostFiles.WriteOutput("FAIL: escape capacity Err=" & CStr(Err.Number), True)
    ExitProcess 1
End Sub
