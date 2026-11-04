UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeTraversal"

' Private lowering cursor over the immutable checked graph, not another IR.
' The caller retains the same Values owner and logical Count through a walk.
' Values and Cancellation are borrowed read-only; only Frames is owned here.
' A frame is six Longs (24 payload bytes). Growth charges old+new capacities.
' Events are enter=1, followed child edge=2, exit=3, end=0, in written order.
' Each occurrence is visited, including repeated child edges; no recursion or
' declaration/name lookup occurs. One cursor can serve both planned traversals.
' Status: 0 unused, 1 active, 2 complete, 4 failed. Cleanup is retryable and
' never checks cancellation. A caller seeds Failure before managed admission.
Type NativeTraversalFrame
    Node As Long
    NextChild As Long
    Remaining As Long
    Ordinal As Long
    Entered As Long
    ParentOrdinal As Long
End Type
Type NativeTraversal
    Frames() As NativeTraversalFrame
    Capacity As Long
    Count As Long
    Status As Long
    PendingChild As Long
    PendingOrdinal As Long
End Type
Type NativeTraversalEvent
    Kind As Long
    Node As Long
    Parent As Long
    Ordinal As Long
    Depth As Long
End Type
Private Intrinsic Function NativeGraphLength(ByRef Values() As BoundNode) As Long
Attribute NativeGraphLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function TryResizeNativeFrames(ByRef Values() As NativeTraversalFrame, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeNativeFrames.UBE_Primitive = "Array.TryResize"
End Function
Private Sub ReadNativeFrame(ByRef Destination As NativeTraversalFrame, ByRef Original As NativeTraversalFrame)
    Destination = Original
End Sub
Private Sub WriteNativeFrame(ByRef Destination As NativeTraversalFrame, ByRef Original As NativeTraversalFrame)
    Destination = Original
End Sub

' Reserve live entries/depth before allocation. Failed admission retains peaks
' but rolls back live charges. After a successful resize the new owner remains
' accounted even if the following cancellation check fails.
Private Function TryPushNativeNode(ByRef State As NativeTraversal, ByRef Values() As BoundNode, ByVal ValueCount As Long, ByVal NodeId As Long, ByVal Ordinal As Long, ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByRef Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryPushNativeNode = False
    Call ResetNativeFailure(Failure)
    If NodeId < 0 Or NodeId >= ValueCount Or State.Count < 0 Or State.Count >= 2147483647 Then
        Exit Function
    End If
    Dim Frame As NativeTraversalFrame
    Frame.Node = NodeId
    Frame.NextChild = Values(NodeId).FirstChild
    Frame.Remaining = Values(NodeId).ChildCount
    Frame.ParentOrdinal = Ordinal
    If Frame.Remaining < 0 Then
        Exit Function
    End If
    If TryChargeNativeResource(Limits, Usage, 4, 1, Failure) = False Then
        Exit Function
    End If
    Dim Cleanup As NativeFailure
    If TryChargeNativeResource(Limits, Usage, 6, 1, Failure) = False Then
        Call TryReleaseNativeResource(Usage, 4, 1, Cleanup)
        Exit Function
    End If
    Dim Healthy As Boolean = True
    If State.Count = State.Capacity Then
        Dim Capacity As Long = State.Capacity
        Healthy = TryGetStorageCapacity(State.Capacity, State.Count + 1, 2147483647, Capacity)
        If Healthy = False Then
            Failure.Code = 1502
            Failure.Resource = 1
        Else
            Dim Bytes As LongLong = Capacity
            Bytes = Bytes * 24
            Healthy = TryChargeNativeResource(Limits, Usage, 1, Bytes, Failure)
            If Healthy Then
                Call ResetNativeFailure(Failure)
                Healthy = TryContinueNativeOutput(Cancellation, Failure)
                If Healthy Then
                    Call ResetNativeFailure(Failure)
                    Healthy = TryResizeNativeFrames(State.Frames, Capacity, True)
                    If Healthy = False Then
                        Failure.Code = 1502
                        Failure.Resource = 1
                    End If
                End If
                If Healthy Then
                    Dim OldBytes As LongLong = State.Capacity
                    OldBytes = OldBytes * 24
                    Call TryReleaseNativeResource(Usage, 1, OldBytes, Cleanup)
                    State.Capacity = Capacity
                    Call ResetNativeFailure(Failure)
                    Healthy = TryContinueNativeOutput(Cancellation, Failure)
                Else
                    Call TryReleaseNativeResource(Usage, 1, Bytes, Cleanup)
                End If
            End If
        End If
    End If
    If Healthy = False Then
        Call TryReleaseNativeResource(Usage, 4, 1, Cleanup)
        Call TryReleaseNativeResource(Usage, 6, 1, Cleanup)
        Exit Function
    End If
    Call ResetNativeFailure(Failure)
    Call WriteNativeFrame(State.Frames(State.Count), Frame)
    State.Count = State.Count + 1
    Failure.Code = 0
    Failure.Resource = 0
    TryPushNativeNode = True
End Function

Function TryBeginNativeTraversal(ByRef State As NativeTraversal, ByRef Values() As BoundNode, ByVal ValueCount As Long, ByVal Root As Long, ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByRef Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryBeginNativeTraversal = False
    Call ResetNativeFailure(Failure)
    If (State.Status <> 0 And State.Status <> 2) Or State.Count <> 0 Then
        Exit Function
    End If
    State.Status = 4
    If ValueCount < 1 Or ValueCount > NativeGraphLength(Values) Then
        Exit Function
    End If
    Call ResetNativeFailure(Failure)
    If TryContinueNativeOutput(Cancellation, Failure) = False Then
        Exit Function
    End If
    Call ResetNativeFailure(Failure)
    If TryPushNativeNode(State, Values, ValueCount, Root, -1, Limits, Usage, Cancellation, Failure) = False Then
        Exit Function
    End If
    State.PendingChild = -1
    State.PendingOrdinal = -1
    State.Status = 1
    Failure.Code = 0
    TryBeginNativeTraversal = True
End Function

' A successful end returns a neutral event repeatedly. Any failure preserves
' the caller's previous event. Already returned prefix events stay private to
' this lowering operation; callers must discard output after a failed walk.
Function TryNextNativeTraversal(ByRef State As NativeTraversal, ByRef Values() As BoundNode, ByVal ValueCount As Long, ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByRef Cancellation As SourceCancellation, ByRef Event As NativeTraversalEvent, ByRef Failure As NativeFailure) As Boolean
    TryNextNativeTraversal = False
    Call ResetNativeFailure(Failure)
    Dim Prepared As NativeTraversalEvent
    If State.Status = 2 Then
        Event = Prepared
        Failure.Code = 0
        TryNextNativeTraversal = True
        Exit Function
    End If
    If State.Status <> 1 Or State.Count <= 0 Or State.Count > State.Capacity Then
        Exit Function
    End If
    State.Status = 4
    If State.PendingChild >= 0 Then
        Call ResetNativeFailure(Failure)
        If TryPushNativeNode(State, Values, ValueCount, State.PendingChild, State.PendingOrdinal, Limits, Usage, Cancellation, Failure) = False Then
            Exit Function
        End If
        State.PendingChild = -1
        Call ResetNativeFailure(Failure)
    End If
    If Usage.Work Mod 4096 = 0 Then
        Call ResetNativeFailure(Failure)
        If TryContinueNativeOutput(Cancellation, Failure) = False Then
            Exit Function
        End If
        Call ResetNativeFailure(Failure)
    End If
    Dim Frame As NativeTraversalFrame
    Call ReadNativeFrame(Frame, State.Frames(State.Count - 1))
    Prepared.Node = Frame.Node
    Prepared.Parent = -1
    Prepared.Ordinal = Frame.ParentOrdinal
    Prepared.Depth = State.Count
    If State.Count > 1 Then
        Prepared.Parent = State.Frames(State.Count - 2).Node
    End If
    If Frame.Entered = 0 Then
        Prepared.Kind = 1
        Frame.Entered = 1
    Else
        If Frame.Remaining > 0 Then
            Dim Child As Long = Frame.NextChild
            If Child < 0 Or Child >= ValueCount Then
                Exit Function
            End If
            Prepared.Kind = 2
            Prepared.Node = Child
            Prepared.Parent = Frame.Node
            Prepared.Ordinal = Frame.Ordinal
            State.PendingChild = Child
            State.PendingOrdinal = Frame.Ordinal
            Frame.NextChild = Values(Child).NextSibling
            Frame.Remaining = Frame.Remaining - 1
            Frame.Ordinal = Frame.Ordinal + 1
        Else
            If Frame.NextChild <> -1 Then
                Exit Function
            End If
            Prepared.Kind = 3
        End If
    End If
    If TryChargeNativeResource(Limits, Usage, 5, 1, Failure) = False Then
        Exit Function
    End If
    If Prepared.Kind = 3 Then
        Dim Cleanup As NativeFailure
        Call TryReleaseNativeResource(Usage, 4, 1, Cleanup)
        Call TryReleaseNativeResource(Usage, 6, 1, Cleanup)
        State.Count = State.Count - 1
    Else
        Call WriteNativeFrame(State.Frames(State.Count - 1), Frame)
    End If
    State.Status = 1
    If State.Count = 0 Then
        State.Status = 4
        Call ResetNativeFailure(Failure)
        If TryContinueNativeOutput(Cancellation, Failure) = False Then
            Exit Function
        End If
        State.Status = 2
    End If
    Event = Prepared
    Failure.Code = 0
    Failure.Resource = 0
    TryNextNativeTraversal = True
End Function

' After an edge event, defer that child's subtree to a separate consumer.
' The edge is already charged; no child frame or enter/exit has been created.
' The caller must account for the deferred subtree when it is actually visited.
Function TrySkipNativeTraversalChild(ByRef State As NativeTraversal) As Boolean
    TrySkipNativeTraversalChild = False
    If State.Status <> 1 Or State.Count < 1 Or State.Count > State.Capacity Or State.PendingChild < 0 Or State.PendingOrdinal < 0 Then
        Exit Function
    End If
    State.PendingChild = -1
    State.PendingOrdinal = -1
    TrySkipNativeTraversalChild = True
End Function

Function TryDisposeNativeTraversal(ByRef State As NativeTraversal, ByRef Usage As NativeUsage, ByRef Failure As NativeFailure) As Boolean
    TryDisposeNativeTraversal = False
    Call ResetNativeFailure(Failure)
    If State.Count < 0 Or State.Capacity < State.Count Then
        Exit Function
    End If
    If TryResizeNativeFrames(State.Frames, 0, False) = False Then
        Exit Function
    End If
    Dim Bytes As LongLong = State.Capacity
    Bytes = Bytes * 24
    Dim Cleanup As NativeFailure
    Call TryReleaseNativeResource(Usage, 1, Bytes, Cleanup)
    Call TryReleaseNativeResource(Usage, 4, State.Count, Cleanup)
    Call TryReleaseNativeResource(Usage, 6, State.Count, Cleanup)
    State.Capacity = 0
    State.Count = 0
    State.Status = 0
    State.PendingChild = -1
    State.PendingOrdinal = -1
    Failure.Code = 0
    Failure.Resource = 0
    TryDisposeNativeTraversal = True
End Function
