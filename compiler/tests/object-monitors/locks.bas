UBE SOURCE 1 MODULE
Attribute UBE_Name = "LockProbe"
Option Explicit

Private Entered(0 To 8) As Long
Private Observed(0 To 8) As Long
Private Phase As Long
Private Evaluations As Long

Private Intrinsic Function WaitThread(ByVal Id As LongLong, ByVal Timeout As LongLong) As Long
Attribute WaitThread.UBE_Primitive = "Thread.Wait"
End Function
Private Intrinsic Function YieldThread() As Boolean
Attribute YieldThread.UBE_Primitive = "Thread.Yield"
End Function
Private Intrinsic Function CollectGarbage() As Long
Attribute CollectGarbage.UBE_Primitive = "Memory.Collect"
End Function
Private Intrinsic Function RecordError(ByVal Number As Long) As Boolean
Attribute RecordError.UBE_Primitive = "Error.Set"
End Function

Private Sub Take(ByVal Target As Gate, ByVal Index As Long)
    On Error GoTo Unexpected
    Entered(Index) = 1
    SyncLock Target
        Observed(Index) = Phase
    End SyncLock
    Exit Sub
Unexpected:
    Err.Raise Err.Number
End Sub

Private Function WaitEntered(ByVal Index As Long) As Boolean
    Dim Attempt As Long
    On Error GoTo Unexpected
    For Attempt = 1 To 10000
        If Entered(Index) = 1 Then WaitEntered = True: Exit Function
        Call YieldThread()
    Next Attempt
    Exit Function
Unexpected:
    Err.Raise Err.Number
End Function

Private Function Target(ByVal Value As Gate) As Gate
    On Error GoTo Unexpected
    Evaluations = Evaluations + 1
    Set Target = Value
    Exit Function
Unexpected:
    Err.Raise Err.Number
End Function

Private Function FailedTarget() As Gate
    Evaluations = Evaluations + 1
    Err.Raise 17
End Function

Private Sub Fail()
    Err.Raise 17
End Sub

Private Function MixedExit() As Boolean
    Dim Outer As Gate
    Dim Inner As Gate
    Dim Original As Gate
    Dim OuterWorker As LongLong
    Dim InnerWorker As LongLong
    Dim Values(0 To 1) As Long
    Dim Item As Variant
    Dim Index As Long
    Dim BodyCount As Long
    Dim Ready As Boolean
    Dim Waited As Long
    On Error GoTo Unexpected
    Set Outer = New Gate
    Set Inner = New Gate
    Set Original = Inner
    Phase = 1
    SyncLock Outer
        OuterWorker = CallNew Take(Outer, 0)
        Ready = False
        Ready = WaitEntered(0)
        If Not Ready Then Exit Function
        Do
            For Index = 1 To 2
                While True
                    For Each Item In Values
                        SyncLock Target(Inner)
                            InnerWorker = CallNew Take(Inner, 1)
                            Ready = False
                            Ready = WaitEntered(1)
                            If Not Ready Then Exit Function
                            Set Inner = New Gate
                            Call CollectGarbage()
                            BodyCount = BodyCount + 1
                            If True Then Exit Loop
                        End SyncLock
                    Next Item
                Wend
            Next Index
        Loop
        If BodyCount <> 1 Or Evaluations <> 1 Then Exit Function
        Waited = -1
        Waited = WaitThread(InnerWorker, 5000)
        If Waited <> 1 Then Exit Function
        If Observed(1) <> 1 Then Exit Function
        Waited = -1
        Waited = WaitThread(OuterWorker, 0)
        If Waited <> 0 Then Exit Function
        SyncLock Original
            Call CollectGarbage()
        End SyncLock
        Phase = 2
    End SyncLock
    Waited = -1
    Waited = WaitThread(OuterWorker, 5000)
    If Waited <> 1 Then Exit Function
    If Observed(0) <> 2 Then Exit Function
    MixedExit = True
    Exit Function
Unexpected:
    Err.Raise Err.Number
End Function

Private Function ReentrantExit() As Boolean
    Dim Value As Gate
    Dim Worker As LongLong
    Dim Ready As Boolean
    Dim Waited As Long
    On Error GoTo Unexpected
    Set Value = New Gate
    Phase = 3
    SyncLock Value
        Worker = CallNew Take(Value, 2)
        Ready = False
        Ready = WaitEntered(2)
        If Not Ready Then Exit Function
        Do
            SyncLock Value
                Exit Loop
            End SyncLock
        Loop
        Waited = -1
        Waited = WaitThread(Worker, 0)
        If Waited <> 0 Then Exit Function
        Call RecordError(73)
        Phase = 4
    End SyncLock
    If Err.Number <> 73 Then Exit Function
    Waited = -1
    Waited = WaitThread(Worker, 5000)
    If Waited <> 1 Then Exit Function
    If Observed(2) <> 4 Then Exit Function
    ReentrantExit = True
    Exit Function
Unexpected:
    Err.Raise Err.Number
End Function

Private Sub ReturnLocked(ByVal Value As Gate)
    On Error GoTo Unexpected
    SyncLock Value
        Exit Sub
    End SyncLock
    Exit Sub
Unexpected:
    Err.Raise Err.Number
End Sub

Private Sub JumpLocked(ByVal Value As Gate)
    On Error GoTo Unexpected
    SyncLock Value
        GoTo Finished
    End SyncLock
Finished:
    Exit Sub
Unexpected:
    Err.Raise Err.Number
End Sub

Private Sub NamedExit(ByVal Value As Gate)
    On Error GoTo Unexpected
    Do
        SyncLock Value
            Exit Do
        End SyncLock
    Loop
    While True
        SyncLock Value
            Exit While
        End SyncLock
    Wend
    Dim Index As Long
    For Index = 1 To 2
        SyncLock Value
            Exit For
        End SyncLock
    Next Index
    Exit Sub
Unexpected:
    Err.Raise Err.Number
End Sub

Private Function OutsideHandler(ByVal Value As Gate) As Boolean
    Dim Worker As LongLong
    Dim Waited As Long
    On Error GoTo Caught
    SyncLock Value
        Call Fail()
    End SyncLock
    Exit Function
Caught:
    If Err.Number <> 17 Then Exit Function
    Worker = CallNew Take(Value, 3)
    Waited = -1
    Waited = WaitThread(Worker, 5000)
    If Waited <> 1 Then Exit Function
    OutsideHandler = True
End Function

Private Function InsideHandler(ByVal Value As Gate) As Boolean
    Dim Worker As LongLong
    Dim Ready As Boolean
    Dim Waited As Long
    On Error GoTo Unexpected
    Phase = 5
    SyncLock Value
        Worker = CallNew Take(Value, 4)
        Ready = False
        Ready = WaitEntered(4)
        If Not Ready Then Exit Function
        On Error GoTo Caught
        Call Fail()
        Exit Function
Caught:
        If Err.Number <> 17 Then Exit Function
        On Error GoTo 0
        Waited = -1
        Waited = WaitThread(Worker, 0)
        If Waited <> 0 Then Exit Function
        Call RecordError(74)
        Phase = 6
    End SyncLock
    Waited = -1
    Waited = WaitThread(Worker, 5000)
    If Waited <> 1 Then Exit Function
    If Observed(4) <> 6 Then Exit Function
    InsideHandler = True
    Exit Function
Unexpected:
    Err.Raise Err.Number
End Function

Private Function HeaderFailure(ByVal Value As Gate) As Boolean
    Dim Count As Long
    Dim Before As Long
    Dim Worker As LongLong
    Dim Ready As Boolean
    Dim Waited As Long
    Before = Evaluations
    Phase = 9
    SyncLock Value
        Worker = CallNew Take(Value, 7)
        Ready = False
        Ready = WaitEntered(7)
        If Not Ready Then Exit Function
        SyncLock Nothing
            Count = Count + 100
        End SyncLock
        Count = Count + 1
        SyncLock FailedTarget()
            Count = Count + 100
        End SyncLock
        Count = Count + 1
        If Count <> 2 Or Evaluations <> Before + 1 Then Exit Function
        If Err.Number <> 17 Then Exit Function
        Waited = -1
        Waited = WaitThread(Worker, 0)
        If Waited <> 0 Then Exit Function
        Phase = 10
        Call RecordError(76)
    End SyncLock
    Waited = -1
    Waited = WaitThread(Worker, 5000)
    If Waited <> 1 Then Exit Function
    If Observed(7) <> 10 Or Err.Number <> 76 Then Exit Function
    On Error GoTo Caught
    SyncLock Nothing
        Count = Count + 100
    End SyncLock
    Exit Function
Caught:
    If Err.Number = 91 And Count = 2 Then HeaderFailure = True
End Function

Private Sub RecursiveLocks(ByVal Value As Gate, ByVal Depth As Long)
    On Error GoTo Unexpected
    SyncLock Value
        If Depth > 0 Then RecursiveLocks Value, Depth - 1
        Do
            SyncLock Value
                Exit Loop
            End SyncLock
        Loop
    End SyncLock
    Exit Sub
Unexpected:
    Err.Raise Err.Number
End Sub

Private Sub RaiseLocked(ByVal Value As Gate)
    On Error GoTo WrongHandler
    SyncLock Value
        Err.Raise 17
    End SyncLock
    Exit Sub
WrongHandler:
    Call RecordError(99)
End Sub

Private Function DirectRaiseExit() As Boolean
    Dim Value As Gate
    Dim Worker As LongLong
    Dim Waited As Long
    On Error GoTo Caught
    Set Value = New Gate
    RaiseLocked Value
    Exit Function
Caught:
    If Err.Number <> 17 Then Exit Function
    Worker = CallNew Take(Value, 8)
    Waited = -1
    Waited = WaitThread(Worker, 5000)
    If Waited <> 1 Then Exit Function
    DirectRaiseExit = True
End Function

Public Function Main() As Long
    Dim Value As Gate
    Dim Worker As LongLong
    Dim Passed As Boolean
    Dim Ready As Boolean
    Dim Waited As Long
    On Error GoTo Unexpected
    Passed = False
    Passed = MixedExit()
    If Not Passed Then Main = 1: Exit Function
    Passed = False
    Passed = ReentrantExit()
    If Not Passed Then Main = 2: Exit Function
    Set Value = New Gate
    ReturnLocked Value
    JumpLocked Value
    NamedExit Value
    Worker = CallNew Take(Value, 5)
    Waited = -1
    Waited = WaitThread(Worker, 5000)
    If Waited <> 1 Then Main = 3: Exit Function
    Passed = False
    Passed = OutsideHandler(Value)
    If Not Passed Then Main = 4: Exit Function
    Passed = False
    Passed = InsideHandler(Value)
    If Not Passed Then Main = 5: Exit Function
    Passed = False
    Passed = HeaderFailure(Value)
    If Not Passed Then Main = 6: Exit Function
    Call CollectGarbage()
    SyncLock Value
        Call RecordError(79)
    End SyncLock
    If Err.Number <> 79 Then Main = 7: Exit Function
    Dim RecursiveValue As Gate
    Dim Reached As Long
    Set RecursiveValue = New Gate
    Phase = 7
    Do
        SyncLock RecursiveValue
            Worker = CallNew Take(RecursiveValue, 6)
            Ready = False
            Ready = WaitEntered(6)
            If Not Ready Then Main = 8: Exit Function
            RecursiveLocks RecursiveValue, 2
            Reached = Reached + 1
            Waited = -1
            Waited = WaitThread(Worker, 0)
            If Waited <> 0 Then Main = 9: Exit Function
            Phase = 8
            Call RecordError(75)
        End SyncLock
        Exit Do
    Loop
    If Reached <> 1 Then Main = 10: Exit Function
    Waited = -1
    Waited = WaitThread(Worker, 5000)
    If Waited <> 1 Then Main = 11: Exit Function
    If Observed(6) <> 8 Or Err.Number <> 75 Then Main = 12: Exit Function
    Passed = False
    Passed = DirectRaiseExit()
    If Not Passed Then Main = 13: Exit Function
    Exit Function
Unexpected:
    Main = 90
End Function
