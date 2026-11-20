UBE SOURCE 1 MODULE
Attribute UBE_Name = "ManagedPrimitives"
' Test-only deterministic snapshot adapter, not a native runtime implementation.
Public Live(0 To 127) As Boolean
Private Marks(0 To 127) As Boolean
Public NextEdge(0 To 127) As LongLong
Public Root As LongLong
Public Mode As Long
Public EndCount As Long
Public Releases As Long
Public Sealed As Boolean
Private Owned As Boolean
Private WorkspaceCount As Long

Public Intrinsic Function RecordError(ByVal Number As Long) As Boolean
Attribute RecordError.UBE_Primitive = "Error.Set"
End Function
Private Intrinsic Function Resize(ByRef Values() As LongLong, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute Resize.UBE_Primitive = "Array.TryResize"
End Function

Public Sub Reset()
    Dim I As Long
    Do While I < 128
        Live(I) = False
        Marks(I) = False
        NextEdge(I) = 0
        I = I + 1
    Loop
    Root = 0
    Mode = 0
    EndCount = 0
    Releases = 0
    Sealed = False
    Owned = False
    WorkspaceCount = 0
End Sub
Public Function BeginCollection(ByRef Work As Long, ByRef Failure As Long) As Boolean
    Work = 0
    Failure = 0
    If Mode = 4 Then Work = 1: Failure = 7: Exit Function
    Owned = True
    BeginCollection = True
End Function
Public Function EndCollection(ByVal Work As Long, ByVal Failure As Long) As Boolean
    Dim I As Long
    If Not Owned Then EndCount = -100: Exit Function
    If WorkspaceCount <> 0 Then EndCount = -101: Exit Function
    Do While I < 128
        Marks(I) = False
        I = I + 1
    Loop
    Owned = False
    EndCount = EndCount + 1
    EndCollection = True
End Function
Public Function TrySnapshotCounts(ByRef Allocations As Long, ByRef Roots As Long) As Boolean
    Allocations = 128
    Roots = 2
    TrySnapshotCounts = True
End Function
Public Function TryResizeWork(ByRef Values() As LongLong, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
    If Not Owned Then TryResizeWork = RecordError(5): Exit Function
    If Mode = 1 And Count <> 0 Then TryResizeWork = RecordError(7): Exit Function
    If Not Resize(Values, Count, Preserve) Then Exit Function
    WorkspaceCount = Count
    TryResizeWork = True
End Function
Public Function TryRootAt(ByVal Index As Long, ByRef Handle As LongLong) As Boolean
    Handle = Root
    TryRootAt = True
End Function
Public Function TryAllocationAt(ByVal Index As Long, ByRef Handle As LongLong) As Boolean
    If Mode = 5 And Index = 127 Then TryAllocationAt = RecordError(5): Exit Function
    Handle = 0
    If Live(Index) Then Handle = Index + 1
    TryAllocationAt = True
End Function
Public Function TryMark(ByVal Handle As LongLong, ByRef Fresh As Boolean) As Boolean
    Fresh = False
    If Handle = 0 Then TryMark = True: Exit Function
    If Handle < 1 Or Handle > 128 Then TryMark = RecordError(5): Exit Function
    If Not Live(Handle - 1) Then TryMark = RecordError(5): Exit Function
    Fresh = Not Marks(Handle - 1)
    Marks(Handle - 1) = True
    TryMark = True
End Function
Public Function TryMarked(ByVal Handle As LongLong, ByRef Marked As Boolean) As Boolean
    Marked = Marks(Handle - 1)
    TryMarked = True
End Function
Public Function TryEdgeCount(ByVal Handle As LongLong, ByRef Count As Long) As Boolean
    Count = 1
    TryEdgeCount = True
End Function
Public Function TryEdgeAt(ByVal Handle As LongLong, ByVal Index As Long, ByRef Edge As LongLong) As Boolean
    If Mode = 2 Then TryEdgeAt = RecordError(7): Exit Function
    Edge = NextEdge(Handle - 1)
    TryEdgeAt = True
End Function
Public Function SealCollection() As Boolean
    Sealed = True
    SealCollection = True
End Function
Public Function TryReclaim(ByVal Handle As LongLong) As Boolean
    If Not Sealed Or Marks(Handle - 1) Then TryReclaim = RecordError(5): Exit Function
    If Mode = 3 And Handle = 1 Then TryReclaim = RecordError(57): Exit Function
    Live(Handle - 1) = False
    Releases = Releases + 1
    TryReclaim = True
End Function
