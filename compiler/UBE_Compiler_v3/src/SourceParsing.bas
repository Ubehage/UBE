UBE SOURCE 1 MODULE
Attribute UBE_Name = "SourceParsing"

' Bounded source-set syntax orchestration; no UBECore source/compiler policy.
' Contract: CONCURRENCY-CONSUMER.md. Sources and completed published work are
' immutable. New work is private until one atomic complete-array replacement.
Type SourceSetFailure
    Kind As Long
    SourceId As Long
    UnitFailure As SyntaxFailure
End Type

' Borrows the immutable input reference vector for this call.
Intrinsic Function SourceOwnerCount(ByRef Values() As SourceOwner) As Long
Attribute SourceOwnerCount.UBE_Primitive = "Array.Length"
End Function

' Allocates only reference slots, never copies owned source/token/node payload.
Intrinsic Function TryResizeSourceWorks(ByRef Values() As SourceWork, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeSourceWorks.UBE_Primitive = "Array.TryResize"
End Function

' Replaces the complete vector atomically; failure retains the entire old graph.
Intrinsic Function TryCopySourceWorks(ByRef Destination() As SourceWork, ByRef Source() As SourceWork) As Boolean
Attribute TryCopySourceWorks.UBE_Primitive = "Array.TryCopy"
End Function

' Observes sticky native stop without interpreting another thread's Err.
Function TryContinueSourceWork(ByVal Work As SourceWork) As Boolean
    TryContinueSourceWork = False
    Dim Requested As Boolean = False
    If TryThreadStopRequested(Requested) = False Then
        Work.State = 2
        Work.Failure.Kind = 5
        Exit Function
    End If
    If Requested Then
        Work.State = 3
        Exit Function
    End If
    TryContinueSourceWork = True
End Function

' Actual UBE worker. Existing conditional, scan and token-parse bodies do work;
' retained tokens and cooperative checkpoints require their separate entries.
Sub ProcessSourceWork(ByVal Work As SourceWork)
    Work.Failure.Kind = 5
    If TryCurrentThreadId(Work.WorkerId) = False Then
        Work.State = 2
        Exit Sub
    End If
    If TryContinueSourceWork(Work) = False Then
        Exit Sub
    End If
    Dim Deferred As Boolean = False
    If TrySyntaxConditionalInput(Work.Owner.Document, Deferred, Work.Failure) = False Then
        Work.State = 2
        Exit Sub
    End If
    If Deferred Then
        Work.State = 2
        Exit Sub
    End If
    If TryContinueSourceWork(Work) = False Then
        Exit Sub
    End If
    Dim ScanFailure As ScannerFailure
    ScanFailure.Kind = 5
    If TryScanSource(Work.Owner.Document, 0, Work.MaximumTokens, Work.Tokens, ScanFailure) = False Then
        Work.Failure.Kind = 5
        If ScanFailure.Kind <> 5 Then
            Work.Failure.Kind = 200 + ScanFailure.Kind
        End If
        Work.Failure.FirstByte = ScanFailure.First.ByteOffset
        Work.Failure.LastByte = ScanFailure.Last.ByteOffset
        Work.State = 2
        Exit Sub
    End If
    If TryContinueSourceWork(Work) = False Then
        Exit Sub
    End If
    Work.Failure.Kind = 5
    If TryParseSyntax(Work.Owner.Document, Work.Tokens, 3, Work.Owner.SourceId, Work.MaximumNodes, Work.MaximumPending, Work.MaximumDepth, Work.Syntax, Work.Failure, Work.Metrics) = False Then
        Work.State = 2
        Exit Sub
    End If
    If TryContinueSourceWork(Work) = False Then
        Exit Sub
    End If
    Work.State = 1
End Sub

' Records infrastructure failure before any ordinary source diagnostic; repeated
' infrastructure failures choose the smallest associated canonical source ID.
Sub RecordSourceSetFailure(ByRef Failure As SourceSetFailure, ByVal Kind As Long, ByVal SourceId As Long)
    If Failure.Kind = 0 Or Failure.Kind = 3 Then
        Failure.Kind = Kind
        Failure.SourceId = SourceId
        Dim EmptyUnitFailure As SyntaxFailure
        Failure.UnitFailure = EmptyUnitFailure
    Else
        If Failure.Kind = Kind And SourceId >= 0 Then
            If Failure.SourceId < 0 Or SourceId < Failure.SourceId Then
                Failure.SourceId = SourceId
            End If
        End If
    End If
End Sub

' Linearizes publication admission at the final cooperative request check.
Function TryPublishSourceWorks(ByVal Cancellation As SourceCancellation, ByRef Pending() As SourceWork, ByRef Published() As SourceWork, ByRef Failure As SourceSetFailure) As Boolean
    TryPublishSourceWorks = False
    If Cancellation.Requested Then
        Failure.Kind = 4
        Exit Function
    End If
    Failure.Kind = 5
    If TryCopySourceWorks(Published, Pending) = False Then
        Exit Function
    End If
    Dim EmptyFailure As SourceSetFailure
    Failure = EmptyFailure
    Failure.SourceId = -1
    TryPublishSourceWorks = True
End Function

' One invocation, one budget. A failed or cancelled attempt preserves Published.
' Callers seed Failure.Kind=5/SourceId=-1 for pre-body managed admission failure.
Function TryParseSources(ByRef Inputs() As SourceOwner, ByVal Jobs As Long, ByVal MaximumTokens As Long, ByVal MaximumNodes As Long, ByVal MaximumPending As Long, ByVal MaximumDepth As Long, ByVal Cancellation As SourceCancellation, ByRef Published() As SourceWork, ByRef Failure As SourceSetFailure) As Boolean
    TryParseSources = False
    Dim EmptyFailure As SourceSetFailure
    Failure = EmptyFailure
    Failure.Kind = 1
    Failure.SourceId = -1
    Dim Count As Long = SourceOwnerCount(Inputs)
    If Count < 0 Or Count > 256 Or Jobs < 1 Or Jobs > 4 Then
        Exit Function
    End If
    If MaximumTokens < 0 Or MaximumTokens > 1048576 Or MaximumNodes < 0 Or MaximumNodes > 1048576 Or MaximumPending < 0 Or MaximumPending > 1048576 Or MaximumDepth < 0 Or MaximumDepth > 256 Then
        Exit Function
    End If
    If Cancellation Is Nothing Then
        Exit Function
    End If
    Dim Index As Long = 0
    Dim Owner As SourceOwner
    While Index < Count
        Failure.Kind = 5
        Set Owner = Nothing
        If (Owner Is Nothing) = False Then
            Exit Function
        End If
        Set Owner = Inputs(Index)
        If (Owner Is Inputs(Index)) = False Then
            Exit Function
        End If
        Failure.Kind = 1
        If Owner Is Nothing Then
            Failure.SourceId = Index
            Exit Function
        End If
        If Owner.SourceId <> Index Then
            Failure.SourceId = Index
            Exit Function
        End If
        Index = Index + 1
    Wend
    If Cancellation.Requested Then
        Failure.Kind = 4
        Exit Function
    End If
    Failure.Kind = 5
    Dim Pending() As SourceWork
    If Count = 0 Then
        TryParseSources = TryPublishSourceWorks(Cancellation, Pending, Published, Failure)
        Exit Function
    End If
    If TryResizeSourceWorks(Pending, Count, False) = False Then
        Exit Function
    End If
    Dim Work As SourceWork
    Index = 0
    While Index < Count
        Set Work = Nothing
        If (Work Is Nothing) = False Then
            Exit Function
        End If
        Set Work = New SourceWork
        If Work Is Nothing Then
            Exit Function
        End If
        Set Work.Owner = Inputs(Index)
        If (Work.Owner Is Inputs(Index)) = False Then
            Exit Function
        End If
        Work.Failure.Kind = 5
        Work.MaximumTokens = MaximumTokens
        Work.MaximumNodes = MaximumNodes
        Work.MaximumPending = MaximumPending
        Work.MaximumDepth = MaximumDepth
        Set Pending(Index) = Work
        If (Pending(Index) Is Work) = False Then
            Exit Function
        End If
        Index = Index + 1
    Wend
    Dim Slots As SourceWorkerSlots
    If TryInitializeSourceWorkerSlots(Slots, Jobs, Count) = False Then
        Exit Function
    End If
    Failure = EmptyFailure
    Failure.SourceId = -1
    Dim Finished As Boolean = False
    Dim Slot As Long = -1
    Dim SourceIndex As Long = -1
    Dim Action As Long = 0
    Dim WorkAccepted As Boolean = False
    While Finished = False
        Action = NextSourceWorkerAction(Slots, Cancellation.Requested, True, Slot, SourceIndex)
        If Slots.FirstInfrastructureKind <> 0 Then
            Call RecordSourceSetFailure(Failure, Slots.FirstInfrastructureKind, Slots.FirstInfrastructureSource)
        End If
        If Action = 1 Then
                Set Work = Nothing
                WorkAccepted = Work Is Nothing
                If WorkAccepted Then
                    Set Work = Pending(SourceIndex)
                    WorkAccepted = Work Is Pending(SourceIndex)
                End If
                If WorkAccepted = False Then
                    Call RecordSourceWorkerFailure(Slots, 5, SourceIndex)
                Else
                    Dim Id As LongLong = CallNew ProcessSourceWork(Work)
                    Call CommitSourceWorkerAdmission(Slots, Slot, Id)
                End If
        Else
            If Action = 2 Then
                Set Work = Nothing
                WorkAccepted = Work Is Nothing
                If WorkAccepted Then
                    Set Work = Pending(SourceIndex)
                    WorkAccepted = Work Is Pending(SourceIndex)
                End If
                If WorkAccepted = False Then
                    Call RecordSourceWorkerFailure(Slots, 5, SourceIndex)
                Else
                    If Work.State <> 1 Then
                        If Work.State = 3 Then
                            Call RecordSourceWorkerFailure(Slots, 4, SourceIndex)
                        Else
                            If Work.State = 0 Or Work.Failure.Kind = 5 Then
                                Call RecordSourceWorkerFailure(Slots, 5, SourceIndex)
                            Else
                                If Failure.Kind = 0 Or (Failure.Kind = 3 And SourceIndex < Failure.SourceId) Then
                                    Failure.Kind = 3
                                    Failure.SourceId = SourceIndex
                                    Failure.UnitFailure = Work.Failure
                                End If
                            End If
                        End If
                    End If
                End If
            Else
                If Action = 3 Then
                Finished = True
                End If
            End If
        End If
        If Slots.FirstInfrastructureKind <> 0 Then
            Call RecordSourceSetFailure(Failure, Slots.FirstInfrastructureKind, Slots.FirstInfrastructureSource)
        End If
    Wend
    If Failure.Kind <> 0 Then
        Exit Function
    End If
    Failure.Kind = 5
    Failure.SourceId = -1
    TryParseSources = TryPublishSourceWorks(Cancellation, Pending, Published, Failure)
End Function
