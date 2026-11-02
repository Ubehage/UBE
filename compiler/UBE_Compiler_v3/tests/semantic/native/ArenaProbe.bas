UBE SOURCE 1 MODULE
Attribute UBE_Name = "ArenaProbe"
Type ArenaProbeRecord
    SourceId As Long
    NodeId As Long
    Kind As Long
    TypeId As Long
    Value As LongLong
    Left As Long
    Right As Long
    Flags As Long
    Scope As Long
    FirstByte As Long
    LastByte As Long
End Type
Type ArenaProbeResult
    Records() As ArenaProbeRecord
    Count As Long
    Root As Long
    Total As LongLong
End Type
Type ArenaProbeWork
    Writes As Long
    Reads As Long
    Transitions As Long
    MaximumPending As Long
    MaximumDepth As Long
End Type
Intrinsic Function ArenaProbeByteLength(ByRef Bytes() As Byte) As Long
Attribute ArenaProbeByteLength.UBE_Primitive = "Array.Length"
End Function
Intrinsic Function ArenaProbeRecordLength(ByRef Values() As ArenaProbeRecord) As Long
Attribute ArenaProbeRecordLength.UBE_Primitive = "Array.Length"
End Function
Intrinsic Function TryResizeArenaProbeRecords(ByRef Values() As ArenaProbeRecord, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeArenaProbeRecords.UBE_Primitive = "Array.TryResize"
End Function
Intrinsic Function TryResizeArenaProbeResults(ByRef Values() As ArenaProbeResult, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeArenaProbeResults.UBE_Primitive = "Array.TryResize"
End Function
Intrinsic Function TryCopyArenaProbeResults(ByRef Destination() As ArenaProbeResult, ByRef Original() As ArenaProbeResult) As Boolean
Attribute TryCopyArenaProbeResults.UBE_Primitive = "Array.TryCopy"
End Function
Intrinsic Function TryResizeArenaProbeStack(ByRef Values() As Long, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeArenaProbeStack.UBE_Primitive = "Array.TryResize"
End Function
Sub WriteArenaProbeRecord(ByRef Destination As ArenaProbeRecord, ByRef Original As ArenaProbeRecord, ByRef Work As ArenaProbeWork)
    Destination = Original
    Work.Writes = Work.Writes + 1
End Sub
Sub ReadArenaProbeRecord(ByRef Destination As ArenaProbeRecord, ByRef Original As ArenaProbeRecord, ByRef Work As ArenaProbeWork)
    Destination = Original
    Work.Reads = Work.Reads + 1
End Sub
Sub ArenaProbeTransition(ByRef Work As ArenaProbeWork)
    Work.Transitions = Work.Transitions + 1
End Sub
Function TryBuildArenaProbe(ByRef Bytes() As Byte, ByVal Count As Long, ByVal MaximumRecords As Long, ByVal MaximumPending As Long, ByVal MaximumDepth As Long, ByRef Result() As ArenaProbeResult, ByRef Failure As Long, ByRef Work As ArenaProbeWork) As Boolean
    TryBuildArenaProbe = False
    Failure = 1
    If Count < 0 Or Count > 1048576 Or MaximumRecords < 0 Or MaximumRecords > 1048576 Or MaximumPending < 0 Or MaximumPending > 1048576 Or MaximumDepth < 0 Or MaximumDepth > 256 Then
        Exit Function
    End If
    If Count > ArenaProbeByteLength(Bytes) \ 2 Then
        Exit Function
    End If
    Failure = 2
    If Count > MaximumRecords Then
        Exit Function
    End If
    If Count > 0 Then
        If MaximumPending = 0 Or MaximumDepth = 0 Then
            Exit Function
        End If
    End If
    Failure = 5
    Dim Pending() As ArenaProbeResult
    If TryResizeArenaProbeResults(Pending, 1, False) = False Then
        Exit Function
    End If
    Dim Index As Long = 0
    Dim Base As LongLong = 2147483647
    While Index < Count
        Dim Capacity As Long = ArenaProbeRecordLength(Pending(0).Records)
        If Index = Capacity Then
            Dim NextCapacity As Long = 0
            If TryGetStorageCapacity(Capacity, Index + 1, MaximumRecords, NextCapacity) = False Then
                Failure = 2
                Exit Function
            End If
            If TryResizeArenaProbeRecords(Pending(0).Records, NextCapacity, True) = False Then
                Exit Function
            End If
        End If
        Dim Record As ArenaProbeRecord
        Record.SourceId = 7
        Record.NodeId = Index
        Record.Kind = 1 + (Index Mod 3)
        Record.TypeId = 5
        Record.Value = Base + Index
        Record.Left = Index - 1
        Record.Right = -1
        Record.Flags = Index Mod 2
        Record.Scope = 2
        Record.FirstByte = Index * 2
        Record.LastByte = Index * 2 + 1
        Call WriteArenaProbeRecord(Pending(0).Records(Index), Record, Work)
        Index = Index + 1
    Wend
    If ArenaProbeRecordLength(Pending(0).Records) <> Count Then
        If TryResizeArenaProbeRecords(Pending(0).Records, Count, True) = False Then
            Exit Function
        End If
    End If
    Pending(0).Count = Count
    Pending(0).Root = Count - 1
    Dim Stack() As Long
    Dim StackCount As Long = 0
    If Count > 0 Then
        If TryResizeArenaProbeStack(Stack, 1, False) = False Then
            Exit Function
        End If
        Stack(0) = Count - 1
        StackCount = 1
        Work.MaximumPending = 1
        Work.MaximumDepth = 1
        Call ArenaProbeTransition(Work)
    End If
    Dim Total As LongLong = 0
    While StackCount > 0
        Dim Node As Long = Stack(0)
        StackCount = 0
        Call ArenaProbeTransition(Work)
        Dim Current As ArenaProbeRecord
        Call ReadArenaProbeRecord(Current, Pending(0).Records(Node), Work)
        Total = Total + Current.Value
        If Current.Left >= 0 Then
            Stack(0) = Current.Left
            StackCount = 1
            Call ArenaProbeTransition(Work)
        End If
    Wend
    Pending(0).Total = Total
    If TryResizeArenaProbeStack(Stack, 0, False) = False Then
        Exit Function
    End If
    If TryCopyArenaProbeResults(Result, Pending) = False Then
        Exit Function
    End If
    Failure = 0
    TryBuildArenaProbe = True
End Function
