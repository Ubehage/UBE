UBE SOURCE 1 MODULE
Attribute UBE_Name = "WorkerBinding"

Private Intrinsic Function Wait(ByVal Id As LongLong, ByVal Timeout As LongLong) As Long
Attribute Wait.UBE_Primitive = "Thread.Wait"
End Function
Private Intrinsic Function StopRequested() As Boolean
Attribute StopRequested.UBE_Primitive = "Thread.StopRequested"
End Function
Private Intrinsic Function RequestStop(ByVal Id As LongLong) As Long
Attribute RequestStop.UBE_Primitive = "Thread.RequestStop"
End Function
Private Intrinsic Function YieldCore() As Boolean
Attribute YieldCore.UBE_Primitive = "Thread.Yield"
End Function
Private Intrinsic Function ResizeValues(ByRef Values() As Double, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeValues.UBE_Primitive = "Array.TryResize"
End Function
Private Intrinsic Function SetError(ByVal Number As Long) As Boolean
Attribute SetError.UBE_Primitive = "Error.Set"
End Function

Private Sub Worker(ByVal Captured As Double, ByRef Value As Double, ByRef Output As Double, ByRef Narrow As Single, ByRef ErrorNumber As Long)
    Dim Attempts As Long
    On Error GoTo Failed
    Do While Not StopRequested()
        Attempts = Attempts + 1
        If Attempts > 100000 Then Err.Raise 5
        Call YieldCore()
    Loop
    If Err.Number <> 0 Then Err.Raise 5
    Call SetError(33)
    Value = Value + Captured
    Output = Value
    Narrow = Captured
    ErrorNumber = Err.Number
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

Public Function Main() As Long
    Dim Values() As Double
    Dim Captured As Double
    Dim Output As Double
    Dim Narrow As Single
    Dim WorkerError As Long
    Dim Id As LongLong
    On Error GoTo Failed
    If Not ResizeValues(Values, 1, False) Then Main = 1: Exit Function
    Values(0) = 0.5#
    Captured = 1.25#
    Call SetError(57)
    Id = CallNew Worker(Captured, Values(0), Output, Narrow, WorkerError)
    If Wait(Id, 0) <> 0 Then Main = 2: Exit Function
    Captured = 100#
    If Not ResizeValues(Values, 2, True) Then Main = 3: Exit Function
    If RequestStop(Id) <> 1 Then Main = 4: Exit Function
    If Wait(Id, 5000) <> 1 Then Main = 5: Exit Function
    If Output <> 1.75# Or Narrow <> 1.25! Then Main = 6: Exit Function
    If Values(0) <> 0.5# Or Values(1) <> 0# Then Main = 7: Exit Function
    If WorkerError <> 33 Or Err.Number <> 57 Then Main = 8: Exit Function
    Exit Function
Failed:
    Main = 250
End Function
