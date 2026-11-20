UBE SOURCE 1 MODULE
Attribute UBE_Name = "ThreadTextProbe"
' Actual managed worker roots and retained array payloads across descriptor replacement.

Private Intrinsic Function ResizeTexts(ByRef Values() As String, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeTexts.UBE_Primitive = "Array.TryResize"
End Function

' RequestStop is only the release signal; all source waits have finite bounds.
Private Sub WaitForRelease()
    Dim Attempts As Long
    On Error GoTo Failed
    Do While Not ThreadPrimitives.StopRequested()
        Attempts = Attempts + 1
        If Attempts > 100000 Then Err.Raise 5
        Call ThreadPrimitives.Yield()
    Loop
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

Private Sub RetainedWorker(ByRef Value As String, ByRef Before As String, ByRef After As String)
    On Error GoTo Failed
    Call WaitForRelease()
    Before = Value
    Value = Value & " / worker"
    Call Memory.CollectGarbage()
    After = Value
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

Private Function RetainedPayload(ByVal Preserve As Boolean) As Boolean
    Dim Values() As String
    Dim Before As String
    Dim After As String
    Dim Id As LongLong
    On Error GoTo Failed
    If Not ResizeTexts(Values, 1, False) Then Exit Function
    Values(0) = "retained payload"
    Id = CallNew RetainedWorker(Values(0), Before, After)
    If ThreadPrimitives.Wait(Id, 0) <> 0 Then Exit Function
    If Not ResizeTexts(Values, 2, Preserve) Then Exit Function
    If Not Preserve Then Values(0) = "new descriptor"
    Call Memory.CollectGarbage()
    If ThreadPrimitives.RequestStop(Id) <> 1 Then Exit Function
    If ThreadPrimitives.Wait(Id, 5000) <> 1 Then Exit Function
    If Before <> "retained payload" Then Exit Function
    If After <> "retained payload / worker" Then Exit Function
    Call Memory.CollectGarbage()
    If Preserve Then
        If Values(0) <> "retained payload" Then Exit Function
    Else
        If Values(0) <> "new descriptor" Then Exit Function
    End If
    If Values(1) <> "" Then Exit Function
    RetainedPayload = True
    Exit Function
Failed:
    RetainedPayload = False
End Function

Private Sub AllocatingWorker(ByVal Number As Long, ByRef Output As String)
    Dim Index As Long
    Dim Value As String
    Dim Prefix As String
    On Error GoTo Failed
    Call WaitForRelease()
    Prefix = "worker " & Number & ":"
    Do While Index < 40
        Value = Prefix & Index
        Call Memory.CollectGarbage()
        If Text.Length(Value) < 10 Then Err.Raise 5
        Index = Index + 1
        Call ThreadPrimitives.Yield()
    Loop
    Output = Value
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

Private Function ConcurrentWorkers() As Boolean
    Dim First As String
    Dim Second As String
    Dim Third As String
    Dim One As LongLong
    Dim Two As LongLong
    Dim Three As LongLong
    On Error GoTo Failed
    One = CallNew AllocatingWorker(1, First)
    Two = CallNew AllocatingWorker(2, Second)
    Three = CallNew AllocatingWorker(3, Third)
    If ThreadPrimitives.Wait(One, 0) <> 0 Then Exit Function
    If ThreadPrimitives.Wait(Two, 0) <> 0 Then Exit Function
    If ThreadPrimitives.Wait(Three, 0) <> 0 Then Exit Function
    If ThreadPrimitives.RequestStop(One) <> 1 Then Exit Function
    If ThreadPrimitives.RequestStop(Two) <> 1 Then Exit Function
    If ThreadPrimitives.RequestStop(Three) <> 1 Then Exit Function
    If ThreadPrimitives.Wait(One, 10000) <> 1 Then Exit Function
    If ThreadPrimitives.Wait(Two, 10000) <> 1 Then Exit Function
    If ThreadPrimitives.Wait(Three, 10000) <> 1 Then Exit Function
    Call Memory.CollectGarbage()
    ConcurrentWorkers = First = "worker 1:39" And Second = "worker 2:39" And Third = "worker 3:39"
    Exit Function
Failed:
    ConcurrentWorkers = False
End Function

Private Sub NumberWorker(ByRef Value As LongLong, ByRef Output As LongLong)
    On Error GoTo Failed
    Call WaitForRelease()
    Output = Value
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

Private Function ConvertedCapture() As Boolean
    Dim Value As String = "900000007"
    Dim Output As LongLong
    Dim Before As String
    Dim After As String
    Dim Id As LongLong
    Dim CollectionError As Long
    On Error GoTo Failed
    Id = CallNew NumberWorker((Value), Output)
    Call FilePrimitives.SetError(42)
    Call Memory.CollectGarbage()
    CollectionError = Err.Number
    Call ThreadPrimitives.RequestStop(Id)
    If ThreadPrimitives.Wait(Id, 5000) <> 1 Then Exit Function
    If Output <> 900000007^ Or CollectionError <> 42 Then Exit Function
    Id = CallNew RetainedWorker((42), Before, After)
    Call Memory.CollectGarbage()
    Call ThreadPrimitives.RequestStop(Id)
    If ThreadPrimitives.Wait(Id, 5000) <> 1 Then Exit Function
    ConvertedCapture = Before = "42" And After = "42 / worker" And Err.Number = 42
    Exit Function
Failed:
    If Id <> 0 Then Call ThreadPrimitives.RequestStop(Id)
    ConvertedCapture = False
End Function

Public Function Main() As Long
    On Error GoTo Failed
    If Not RetainedPayload(False) Then Main = 1: Exit Function
    If Not RetainedPayload(True) Then Main = 2: Exit Function
    If Not ConcurrentWorkers() Then Main = 3: Exit Function
    If Not ConvertedCapture() Then Main = 4: Exit Function
    Exit Function
Failed:
    Main = 250
End Function
