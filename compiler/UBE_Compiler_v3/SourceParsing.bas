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

' Private bounded active native IDs, owned until confirmed completion.
Intrinsic Function TryResizeSourceThreadIds(ByRef Values() As LongLong, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeSourceThreadIds.UBE_Primitive = "Array.TryResize"
End Function

' Private source association for the same active slots and worker budget.
Intrinsic Function TryResizeSourceIndexes(ByRef Values() As Long, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeSourceIndexes.UBE_Primitive = "Array.TryResize"
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
        Set Owner = Inputs(Index)
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
        Set Work = New SourceWork
        If Work Is Nothing Then
            Exit Function
        End If
        Set Work.Owner = Inputs(Index)
        Work.Failure.Kind = 5
        Work.MaximumTokens = MaximumTokens
        Work.MaximumNodes = MaximumNodes
        Work.MaximumPending = MaximumPending
        Work.MaximumDepth = MaximumDepth
        Set Pending(Index) = Work
        Index = Index + 1
    Wend
    Dim Ids() As LongLong
    Dim SourceIndexes() As Long
    If TryResizeSourceThreadIds(Ids, Jobs, False) = False Or TryResizeSourceIndexes(SourceIndexes, Jobs, False) = False Then
        Exit Function
    End If
    Failure = EmptyFailure
    Failure.SourceId = -1
    Dim NextSource As Long = 0
    Dim Active As Long = 0
    Dim StopAdmission As Boolean = False
    While Active > 0 Or (NextSource < Count And StopAdmission = False)
        If Cancellation.Requested Then
            Call RecordSourceSetFailure(Failure, 4, -1)
            StopAdmission = True
        End If
        While Active < Jobs And NextSource < Count And StopAdmission = False
            If Cancellation.Requested Then
                Call RecordSourceSetFailure(Failure, 4, -1)
                StopAdmission = True
            Else
                Dim Slot As Long = 0
                While Slot < Jobs And Ids(Slot) <> 0
                    Slot = Slot + 1
                Wend
                Set Work = Pending(NextSource)
                Dim Id As LongLong = CallNew ProcessSourceWork(Work)
                If Id = 0 Then
                    Call RecordSourceSetFailure(Failure, 2, NextSource)
                    StopAdmission = True
                Else
                    Ids(Slot) = Id
                    SourceIndexes(Slot) = NextSource
                    NextSource = NextSource + 1
                    Active = Active + 1
                End If
            End If
        Wend
        Index = 0
        While Index < Jobs
            If Ids(Index) <> 0 Then
                If StopAdmission Then
                    Dim Requested As Boolean = False
                    If TryThreadRequestStop(Ids(Index), Requested) = False Then
                        Call RecordSourceSetFailure(Failure, 6, SourceIndexes(Index))
                    End If
                End If
                Dim Completed As Boolean = False
                If TryThreadWait(Ids(Index), 0, Completed) = False Then
                    Call RecordSourceSetFailure(Failure, 6, SourceIndexes(Index))
                    StopAdmission = True
                Else
                    If Completed Then
                        Set Work = Pending(SourceIndexes(Index))
                        If Work.State <> 1 Then
                            If Work.State = 3 Then
                                Call RecordSourceSetFailure(Failure, 4, SourceIndexes(Index))
                                StopAdmission = True
                            Else
                                If Work.State = 0 Or Work.Failure.Kind = 5 Then
                                    Call RecordSourceSetFailure(Failure, 5, SourceIndexes(Index))
                                    StopAdmission = True
                                Else
                                    If Failure.Kind = 0 Or (Failure.Kind = 3 And SourceIndexes(Index) < Failure.SourceId) Then
                                        Failure.Kind = 3
                                        Failure.SourceId = SourceIndexes(Index)
                                        Failure.UnitFailure = Work.Failure
                                    End If
                                End If
                            End If
                        End If
                        Ids(Index) = 0
                        Active = Active - 1
                    End If
                End If
            End If
            Index = Index + 1
        Wend
        If Active > 0 Then
            Call TryThreadYield()
        End If
    Wend
    If Failure.Kind <> 0 Then
        Exit Function
    End If
    Failure.Kind = 5
    Failure.SourceId = -1
    TryParseSources = TryPublishSourceWorks(Cancellation, Pending, Published, Failure)
End Function
