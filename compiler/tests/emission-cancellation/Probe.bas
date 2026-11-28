UBE SOURCE 1 MODULE
Attribute UBE_Name = "EmissionCancellationProbe"

' Stop arrives after real work; the next bounded batch must stop within one procedure.
Private Sub CheckWorker(ByVal PriorFailure As Boolean, ByRef Outcome As Long)
    Dim State As NativeEmission.EmissionState
    Dim Index As Long
    Dim Requested As Long
    On Error GoTo Failed
    Outcome = 1
    State.CurrentNode = 17
    If Not NativeEmission.Charge(State) Then Exit Sub
    If State.Work <> 1 Then Exit Sub
    If PriorFailure Then
        State.Text.Failed = True
        State.FailureCode = 7
        State.FailureReason = 3
        State.ErrorNode = 11
    End If
    Requested = ThreadPrimitives.RequestStop(ThreadPrimitives.CurrentId())
    If Requested <> 1 Then Exit Sub
    Do While Index < 256
        If Not NativeEmission.Charge(State) Then
            If PriorFailure Then
                If State.FailureCode <> 7 Or State.FailureReason <> 3 Or State.ErrorNode <> 11 Then Exit Sub
                If State.Work <> 1 Then Exit Sub
            Else
                If State.FailureCode <> 104 Or State.FailureReason <> 0 Then Exit Sub
                If Not State.Text.Failed Or State.ErrorNode <> 17 Then Exit Sub
                If State.Work > 256 Then Exit Sub
            End If
            Outcome = 0
            Exit Sub
        End If
        Index = Index + 1
    Loop
    Exit Sub
Failed:
    Outcome = 99
End Sub

Public Function Main() As Long
    Dim Worker As LongLong
    Dim Outcome As Long
    Dim State As NativeEmission.EmissionState
    On Error GoTo Failed
    Main = 1
    Worker = CallNew CheckWorker(False, Outcome)
    If Worker = 0 Then Exit Function
    If ThreadPrimitives.Wait(Worker, 10000) <> 1 Then Exit Function
    If Outcome <> 0 Then Main = 2: Exit Function
    Worker = CallNew CheckWorker(True, Outcome)
    If Worker = 0 Then Exit Function
    If ThreadPrimitives.Wait(Worker, 10000) <> 1 Then Exit Function
    If Outcome <> 0 Then Main = 3: Exit Function
    If ThreadPrimitives.StopRequested() Then Main = 4: Exit Function
    If Not NativeEmission.Charge(State) Or State.Work <> 1 Then Main = 5: Exit Function
    State.Work = NativeEmission.MaximumWork
    If NativeEmission.Charge(State) Then Main = 6: Exit Function
    If State.FailureCode <> 6 Or State.FailureReason <> 56 Then Main = 7: Exit Function
    Main = 0
    Exit Function
Failed:
    Main = 99
End Function
