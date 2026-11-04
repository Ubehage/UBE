UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeWarnings"

' Internal selected warning policy; see ../NATIVE-WARNING-IMPLEMENTATION.md.
' One build owns every array ByRef. Capacity shadows describe charged payload;
' partial failure stays disposable. Only Status 2 exposes warning records.
Type NativeWarningSpan
    FirstByte As Long
    LastByte As Long
End Type
Type NativeInitializationWarning
    Code As Long
    SourceId As Long
    FirstByte As Long
    LastByte As Long
    SmallestModule As Long
End Type
Type NativeWarningGraph
    Matrix() As Long
    Spans() As NativeWarningSpan
    Members() As Long
    Warnings() As NativeInitializationWarning
    Components As GraphComponents
    ModuleCount As Long
    MatrixCapacity As Long
    SpanCapacity As Long
    MemberCapacity As Long
    WarningCapacity As Long
    ComponentCapacity As Long
    Pending As Long
    Count As Long
    Status As Long
End Type
Private Intrinsic Function TryResizeNativeWarningLongs(ByRef Values() As Long, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeNativeWarningLongs.UBE_Primitive = "Array.TryResize"
End Function
Private Intrinsic Function TryResizeNativeWarningSpans(ByRef Values() As NativeWarningSpan, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeNativeWarningSpans.UBE_Primitive = "Array.TryResize"
End Function
Private Intrinsic Function TryResizeNativeWarnings(ByRef Values() As NativeInitializationWarning, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeNativeWarnings.UBE_Primitive = "Array.TryResize"
End Function
Private Sub ReadNativeWarning(ByRef Destination As NativeInitializationWarning, ByRef Original As NativeInitializationWarning)
    Destination = Original
End Sub
Private Sub WriteNativeWarning(ByRef Destination As NativeInitializationWarning, ByRef Original As NativeInitializationWarning)
    Destination = Original
End Sub

Private Function TryReserveNativeWarningPayload(ByVal Bytes As LongLong, ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByRef Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryReserveNativeWarningPayload = False
    Call ResetNativeFailure(Failure)
    If TryContinueNativeOutput(Cancellation, Failure) = False Then
        Exit Function
    End If
    TryReserveNativeWarningPayload = TryChargeNativeResource(Limits, Usage, 1, Bytes, Failure)
End Function

Function TryBeginNativeWarnings(ByRef State As NativeWarningGraph, ByVal ModuleCount As Long, ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByRef Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryBeginNativeWarnings = False
    Call ResetNativeFailure(Failure)
    If State.Status <> 0 Or State.ModuleCount <> 0 Or State.MatrixCapacity <> 0 Or State.SpanCapacity <> 0 Or State.MemberCapacity <> 0 Or State.WarningCapacity <> 0 Or State.ComponentCapacity <> 0 Or State.Pending <> 0 Then
        Exit Function
    End If
    State.Status = 4
    If ModuleCount < 0 Then
        Exit Function
    End If
    Dim Cells As LongLong = ModuleCount
    Cells = Cells * ModuleCount
    If Cells > 2147483647 Then
        Failure.Code = 1502
        Failure.Resource = 1
        Exit Function
    End If
    State.ModuleCount = ModuleCount
    Dim Bytes As LongLong = 0
    Dim Allocated As Boolean = False
    Dim Cleanup As NativeFailure
    Bytes = Cells
    Bytes = Bytes * 4
    Call ResetNativeFailure(Failure)
    If TryReserveNativeWarningPayload(Bytes, Limits, Usage, Cancellation, Failure) = False Then
        Exit Function
    End If
    Allocated = TryResizeNativeWarningLongs(State.Matrix, Cells, False)
    If Allocated = False Then
        Call TryReleaseNativeResource(Usage, 1, Bytes, Cleanup)
        Failure.Code = 1502
        Failure.Resource = 1
        Exit Function
    End If
    State.MatrixCapacity = Cells
    Call ResetNativeFailure(Failure)
    If TryContinueNativeOutput(Cancellation, Failure) = False Then
        Exit Function
    End If
    Bytes = Cells
    Bytes = Bytes * 8
    Call ResetNativeFailure(Failure)
    If TryReserveNativeWarningPayload(Bytes, Limits, Usage, Cancellation, Failure) = False Then
        Exit Function
    End If
    Allocated = TryResizeNativeWarningSpans(State.Spans, Cells, False)
    If Allocated = False Then
        Call TryReleaseNativeResource(Usage, 1, Bytes, Cleanup)
        Failure.Code = 1502
        Failure.Resource = 1
        Exit Function
    End If
    State.SpanCapacity = Cells
    Call ResetNativeFailure(Failure)
    If TryContinueNativeOutput(Cancellation, Failure) = False Then
        Exit Function
    End If
    Bytes = ModuleCount
    Bytes = Bytes * 4
    Call ResetNativeFailure(Failure)
    If TryReserveNativeWarningPayload(Bytes, Limits, Usage, Cancellation, Failure) = False Then
        Exit Function
    End If
    Allocated = TryResizeNativeWarningLongs(State.Members, ModuleCount, False)
    If Allocated = False Then
        Call TryReleaseNativeResource(Usage, 1, Bytes, Cleanup)
        Failure.Code = 1502
        Failure.Resource = 1
        Exit Function
    End If
    State.MemberCapacity = ModuleCount
    Call ResetNativeFailure(Failure)
    If TryContinueNativeOutput(Cancellation, Failure) = False Then
        Exit Function
    End If
    Bytes = ModuleCount
    Bytes = Bytes * 20
    Call ResetNativeFailure(Failure)
    If TryReserveNativeWarningPayload(Bytes, Limits, Usage, Cancellation, Failure) = False Then
        Exit Function
    End If
    Allocated = TryResizeNativeWarnings(State.Warnings, ModuleCount, False)
    If Allocated = False Then
        Call TryReleaseNativeResource(Usage, 1, Bytes, Cleanup)
        Failure.Code = 1502
        Failure.Resource = 1
        Exit Function
    End If
    State.WarningCapacity = ModuleCount
    Call ResetNativeFailure(Failure)
    If TryContinueNativeOutput(Cancellation, Failure) = False Then
        Exit Function
    End If
    State.Count = 0
    State.Status = 1
    Failure.Code = 0
    Failure.Resource = 0
    TryBeginNativeWarnings = True
End Function

Private Function EarlierNativeWarningSpan(ByVal SourceId As Long, ByVal FirstByte As Long, ByVal LastByte As Long, ByVal OtherSource As Long, ByVal OtherFirst As Long, ByVal OtherLast As Long) As Boolean
    EarlierNativeWarningSpan = SourceId < OtherSource
    If SourceId = OtherSource Then
        EarlierNativeWarningSpan = FirstByte < OtherFirst
        If FirstByte = OtherFirst Then
            EarlierNativeWarningSpan = LastByte < OtherLast
        End If
    End If
End Function

Function TryAddNativeWarningDependency(ByRef State As NativeWarningGraph, ByVal FromModule As Long, ByVal ToModule As Long, ByVal SourceId As Long, ByVal FirstByte As Long, ByVal LastByte As Long, ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByRef Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryAddNativeWarningDependency = False
    Call ResetNativeFailure(Failure)
    If State.Status <> 1 Then
        Exit Function
    End If
    State.Status = 4
    If FromModule < 0 Or FromModule >= State.ModuleCount Or ToModule < 0 Or ToModule >= State.ModuleCount Or SourceId < 0 Or SourceId >= State.ModuleCount Or FirstByte < 0 Or LastByte < FirstByte Then
        Exit Function
    End If
    If TryVisitNativeIndex(Limits, Usage, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Cell As Long = FromModule * State.ModuleCount + ToModule
    Dim Existing As Long = State.Matrix(Cell)
    Dim Replace As Boolean = Existing = 0
    If Existing > 0 Then
        Replace = EarlierNativeWarningSpan(SourceId, FirstByte, LastByte, Existing - 1, State.Spans(Cell).FirstByte, State.Spans(Cell).LastByte)
    End If
    If Replace Then
        State.Matrix(Cell) = SourceId + 1
        State.Spans(Cell).FirstByte = FirstByte
        State.Spans(Cell).LastByte = LastByte
    End If
    State.Status = 1
    Failure.Code = 0
    Failure.Resource = 0
    TryAddNativeWarningDependency = True
End Function

' Admit the bounded Core chunk before entry; reconcile its actual work and
' pending counts even on failure. Other pending owners cannot change concurrently.
Private Function TryFindNativeWarningComponents(ByRef State As NativeWarningGraph, ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByRef Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryFindNativeWarningComponents = False
    Call ResetNativeFailure(Failure)
    Dim Bytes As LongLong = State.ModuleCount
    Bytes = Bytes * 20
    If TryReserveNativeWarningPayload(Bytes, Limits, Usage, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim CoreFailure As Long = 5
    If TryBeginGraphComponents(State.Components, State.Matrix, State.ModuleCount, CoreFailure) = False Then
        Dim Cleanup As NativeFailure
        Call TryReleaseNativeResource(Usage, 1, Bytes, Cleanup)
        Failure.Code = 1502
        Failure.Resource = 1
        If CoreFailure = 1 Then
            Failure.Code = 1509
            Failure.Resource = 0
        End If
        Exit Function
    End If
    State.ComponentCapacity = State.ModuleCount
    Dim Complete As Boolean = False
    While Complete = False
        Call ResetNativeFailure(Failure)
        If TryContinueNativeOutput(Cancellation, Failure) = False Then
            Exit Function
        End If
        If TryChargeNativeResource(Limits, Usage, 5, 0, Failure) = False Then
            Exit Function
        End If
        If TryChargeNativeResource(Limits, Usage, 4, 0, Failure) = False Then
            Exit Function
        End If
        If State.Pending < 0 Or State.Pending > Usage.Pending Then
            Call ResetNativeFailure(Failure)
            Exit Function
        End If
        Dim Allowance As LongLong = Limits.MaximumWork - Usage.Work
        If Allowance > 4096 Then
            Allowance = 4096
        End If
        Dim Others As LongLong = Usage.Pending - State.Pending
        Dim Available As LongLong = Limits.MaximumPending - Others
        If Available > 2147483647 Then
            Available = 2147483647
        End If
        Dim Work As Long = 0
        Dim Pending As Long = State.Pending
        Dim Peak As Long = Pending
        CoreFailure = 5
        Dim Accepted As Boolean = TryAdvanceGraphComponents(State.Components, State.Matrix, Allowance, Available, Work, Pending, Peak, Complete, CoreFailure)
        If TryChargeNativeResource(Limits, Usage, 5, Work, Failure) = False Then
            Exit Function
        End If
        Dim Difference As LongLong = Pending
        Difference = Difference - State.Pending
        If Difference > 0 Then
            If TryChargeNativeResource(Limits, Usage, 4, Difference, Failure) = False Then
                Exit Function
            End If
        Else
            If TryReleaseNativeResource(Usage, 4, 0 - Difference, Failure) = False Then
                Exit Function
            End If
        End If
        State.Pending = Pending
        If Others + Peak > Usage.PeakPending Then
            Usage.PeakPending = Others + Peak
        End If
        If Accepted = False Then
            Failure.Code = 1502
            Failure.Resource = 1
            If CoreFailure = 2 Then
                Failure.Resource = 4
            End If
            If CoreFailure = 1 Then
                Failure.Code = 1509
                Failure.Resource = 0
            End If
            Exit Function
        End If
        If Complete = False And Allowance = 0 Then
            Failure.Code = 1502
            Failure.Resource = 5
            Exit Function
        End If
        Call ResetNativeFailure(Failure)
        If TryContinueNativeOutput(Cancellation, Failure) = False Then
            Exit Function
        End If
    Wend
    Failure.Code = 0
    Failure.Resource = 0
    TryFindNativeWarningComponents = True
End Function

Private Function EarlierNativeInitializationWarning(ByRef Left As NativeInitializationWarning, ByRef Right As NativeInitializationWarning) As Boolean
    EarlierNativeInitializationWarning = Left.SourceId < Right.SourceId
    If Left.SourceId = Right.SourceId Then
        EarlierNativeInitializationWarning = Left.FirstByte < Right.FirstByte
        If Left.FirstByte = Right.FirstByte Then
            EarlierNativeInitializationWarning = Left.SmallestModule < Right.SmallestModule
        End If
    End If
End Function

Function TryFinishNativeWarnings(ByRef State As NativeWarningGraph, ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByRef Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryFinishNativeWarnings = False
    Call ResetNativeFailure(Failure)
    If State.Status <> 1 Then
        Exit Function
    End If
    State.Status = 4
    If TryFindNativeWarningComponents(State, Limits, Usage, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim ModuleId As Long = 0
    While ModuleId < State.ModuleCount
        If TryVisitNativeIndex(Limits, Usage, Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim Label As Long = 0
        Dim CoreFailure As Long = 5
        If TryReadGraphComponent(State.Components, ModuleId, Label, CoreFailure) = False Then
            Failure.Code = 1502
            Failure.Resource = 1
            If CoreFailure = 1 Then
                Failure.Code = 1509
                Failure.Resource = 0
            End If
            Exit Function
        End If
        If Label < 1 Or Label > State.ModuleCount Then
            Call ResetNativeFailure(Failure)
            Exit Function
        End If
        State.Members(ModuleId) = Label
        If State.Warnings(Label - 1).Code = 0 Then
            State.Warnings(Label - 1).Code = -1
            State.Warnings(Label - 1).SmallestModule = ModuleId
        End If
        ModuleId = ModuleId + 1
    Wend
    Dim Cell As Long = 0
    While Cell < State.MatrixCapacity
        If TryVisitNativeIndex(Limits, Usage, Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim Witness As Long = State.Matrix(Cell)
        If Witness > 0 Then
            Dim FromModule As Long = Cell \ State.ModuleCount
            Dim ToModule As Long = Cell Mod State.ModuleCount
            Dim Component As Long = State.Members(FromModule)
            If Component = State.Members(ToModule) Then
                Dim Candidate As NativeInitializationWarning
                Call ReadNativeWarning(Candidate, State.Warnings(Component - 1))
                Dim Span As NativeWarningSpan
                Span = State.Spans(Cell)
                Dim Replace As Boolean = Candidate.Code <> 1514
                If Candidate.Code = 1514 Then
                    Replace = EarlierNativeWarningSpan(Witness - 1, Span.FirstByte, Span.LastByte, Candidate.SourceId, Candidate.FirstByte, Candidate.LastByte)
                End If
                If Replace Then
                    Candidate.Code = 1514
                    Candidate.SourceId = Witness - 1
                    Candidate.FirstByte = Span.FirstByte
                    Candidate.LastByte = Span.LastByte
                    Call WriteNativeWarning(State.Warnings(Component - 1), Candidate)
                End If
            End If
        End If
        Cell = Cell + 1
    Wend
    Dim Group As Long = 0
    While Group < State.ModuleCount
        If TryVisitNativeIndex(Limits, Usage, Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim Selected As NativeInitializationWarning
        Call ReadNativeWarning(Selected, State.Warnings(Group))
        If Selected.Code = 1514 Then
            Call WriteNativeWarning(State.Warnings(State.Count), Selected)
            State.Count = State.Count + 1
        End If
        Group = Group + 1
    Wend
    Dim Position As Long = 1
    While Position < State.Count
        If TryVisitNativeIndex(Limits, Usage, Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim Ordered As NativeInitializationWarning
        Call ReadNativeWarning(Ordered, State.Warnings(Position))
        Dim Previous As Long = Position - 1
        Dim Moving As Boolean = True
        While Previous >= 0 And Moving
            If TryVisitNativeIndex(Limits, Usage, Cancellation, Failure) = False Then
                Exit Function
            End If
            Dim Prior As NativeInitializationWarning
            Call ReadNativeWarning(Prior, State.Warnings(Previous))
            If EarlierNativeInitializationWarning(Ordered, Prior) Then
                Call WriteNativeWarning(State.Warnings(Previous + 1), Prior)
                Previous = Previous - 1
            Else
                Moving = False
            End If
        Wend
        Call WriteNativeWarning(State.Warnings(Previous + 1), Ordered)
        Position = Position + 1
    Wend
    State.Status = 2
    Failure.Code = 0
    Failure.Resource = 0
    TryFinishNativeWarnings = True
End Function

Function TryReadNativeInitializationWarning(ByRef State As NativeWarningGraph, ByVal Index As Long, ByRef Result As NativeInitializationWarning, ByRef Failure As NativeFailure) As Boolean
    TryReadNativeInitializationWarning = False
    Call ResetNativeFailure(Failure)
    If State.Status <> 2 Or Index < 0 Or Index >= State.Count Then
        Exit Function
    End If
    Call ReadNativeWarning(Result, State.Warnings(Index))
    Failure.Code = 0
    Failure.Resource = 0
    TryReadNativeInitializationWarning = True
End Function

Function TryDisposeNativeWarnings(ByRef State As NativeWarningGraph, ByRef Usage As NativeUsage, ByRef Failure As NativeFailure) As Boolean
    TryDisposeNativeWarnings = False
    Call ResetNativeFailure(Failure)
    Dim CoreFailure As Long = 5
    If TryDisposeGraphComponents(State.Components, CoreFailure) = False Then
        Exit Function
    End If
    Dim Bytes As LongLong = State.ComponentCapacity
    Bytes = Bytes * 20
    Dim Cleanup As NativeFailure
    Call TryReleaseNativeResource(Usage, 1, Bytes, Cleanup)
    Call TryReleaseNativeResource(Usage, 4, State.Pending, Cleanup)
    State.ComponentCapacity = 0
    State.Pending = 0
    If TryResizeNativeWarningLongs(State.Matrix, 0, False) = False Then
        Exit Function
    End If
    Bytes = State.MatrixCapacity
    Bytes = Bytes * 4
    Call TryReleaseNativeResource(Usage, 1, Bytes, Cleanup)
    State.MatrixCapacity = 0
    If TryResizeNativeWarningSpans(State.Spans, 0, False) = False Then
        Exit Function
    End If
    Bytes = State.SpanCapacity
    Bytes = Bytes * 8
    Call TryReleaseNativeResource(Usage, 1, Bytes, Cleanup)
    State.SpanCapacity = 0
    If TryResizeNativeWarningLongs(State.Members, 0, False) = False Then
        Exit Function
    End If
    Bytes = State.MemberCapacity
    Bytes = Bytes * 4
    Call TryReleaseNativeResource(Usage, 1, Bytes, Cleanup)
    State.MemberCapacity = 0
    If TryResizeNativeWarnings(State.Warnings, 0, False) = False Then
        Exit Function
    End If
    Bytes = State.WarningCapacity
    Bytes = Bytes * 20
    Call TryReleaseNativeResource(Usage, 1, Bytes, Cleanup)
    State.WarningCapacity = 0
    State.ModuleCount = 0
    State.Count = 0
    State.Status = 0
    Failure.Code = 0
    Failure.Resource = 0
    TryDisposeNativeWarnings = True
End Function
