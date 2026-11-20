UBE SOURCE 1 MODULE
Attribute UBE_Name = "ManagedMemory"
' Iterative precise tracing over a stopped program snapshot.

' A first discovery is queued once, bounding workspace by the allocation count.
Private Function Discover(ByVal Handle As LongLong, ByRef Pending() As LongLong, ByRef Used As Long, ByVal Capacity As Long) As Boolean
    Dim Fresh As Boolean
    If Not ManagedPrimitives.TryMark(Handle, Fresh) Then Exit Function
    If Fresh Then
        If Used >= Capacity Then
            Call ManagedPrimitives.RecordError(5)
            Exit Function
        End If
        Pending(Used) = Handle
        Used = Used + 1
    End If
    Discover = True
End Function

' Returns whether storage was released; opportunistic collection preserves Err.
' Every owned snapshot ends, including failed workspace and invalid metadata.
Public Function Collect(ByVal ReportFailure As Boolean) As Long
    Dim Pending() As LongLong
    Dim AllocationCount As Long
    Dim RootCount As Long
    Dim Used As Long
    Dim Position As Long
    Dim Index As Long
    Dim EdgeCount As Long
    Dim EdgeIndex As Long
    Dim Handle As LongLong
    Dim Edge As LongLong
    Dim Marked As Boolean
    Dim Owned As Boolean
    Dim Work As Long
    Dim Failure As Long
    Dim IncomingError As Long
    On Error GoTo Failed
    IncomingError = Err.Number
    Owned = ManagedPrimitives.BeginCollection(Work, Failure)
    If Not Owned Then GoTo Finished
    If Not ManagedPrimitives.TrySnapshotCounts(AllocationCount, RootCount) Then GoTo Failed
    If Not ManagedPrimitives.TryResizeWork(Pending, AllocationCount, False) Then GoTo Failed
    Do While Index < RootCount
        If Not ManagedPrimitives.TryRootAt(Index, Handle) Then GoTo Failed
        If Not Discover(Handle, Pending, Used, AllocationCount) Then GoTo Failed
        Index = Index + 1
    Loop
    Do While Position < Used
        Handle = Pending(Position)
        If Not ManagedPrimitives.TryEdgeCount(Handle, EdgeCount) Then GoTo Failed
        EdgeIndex = 0
        Do While EdgeIndex < EdgeCount
            If Not ManagedPrimitives.TryEdgeAt(Handle, EdgeIndex, Edge) Then GoTo Failed
            If Not Discover(Edge, Pending, Used, AllocationCount) Then GoTo Failed
            EdgeIndex = EdgeIndex + 1
        Loop
        Position = Position + 1
    Loop
    ' Reuse the completed discovery queue for validated sweep candidates.
    ' No managed allocation is released until all snapshot queries succeed.
    Used = 0
    Index = 0
    Do While Index < AllocationCount
        If Not ManagedPrimitives.TryAllocationAt(Index, Handle) Then GoTo Failed
        If Handle <> 0 Then
            If Not ManagedPrimitives.TryMarked(Handle, Marked) Then GoTo Failed
            If Not Marked Then
                Pending(Used) = Handle
                Used = Used + 1
            End If
        End If
        Index = Index + 1
    Loop
    If Not ManagedPrimitives.SealCollection() Then GoTo Failed
    Index = 0
    Do While Index < Used
        If ManagedPrimitives.TryReclaim(Pending(Index)) Then
            Work = 1
        ElseIf Failure = 0 Then
            Failure = Err.Number
        End If
        Index = Index + 1
    Loop
    GoTo Finished
Failed:
    If Failure = 0 Then Failure = Err.Number
Finished:
    If Owned Then
        ' Retire the borrowed queue before releasing its stopped snapshot.
        ' The descriptor must never retain workspace owned by a later round.
        If Not ManagedPrimitives.TryResizeWork(Pending, 0, False) Then
            If Failure = 0 Then Failure = Err.Number
        End If
        Call ManagedPrimitives.EndCollection(Work, Failure)
    End If
    If ReportFailure And Failure <> 0 Then
        Call ManagedPrimitives.RecordError(Failure)
    Else
        Call ManagedPrimitives.RecordError(IncomingError)
    End If
    Collect = Work
End Function
