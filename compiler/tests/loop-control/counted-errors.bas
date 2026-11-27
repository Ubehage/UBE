Private Function Mark(ByRef Trace As Long, ByVal Position As Long, ByVal Value As Long) As Long
    Trace = Trace * 10 + Position
    Mark = Value
End Function

Private Function HeaderFailure(ByVal Position As Long) As Long
    Dim Counter As Byte = 9
    Dim StartValue As Long = 1
    Dim BoundValue As Long = 3
    Dim StepValue As Long = 1
    Dim Trace As Long
    If Position = 1 Then StartValue = 300
    If Position = 2 Then BoundValue = 300
    If Position = 3 Then StepValue = 300
    Err.Clear
    For Counter = Mark(Trace, 1, StartValue) To Mark(Trace, 2, BoundValue) Step Mark(Trace, 3, StepValue)
        HeaderFailure = 10
        Exit Function
    Next Counter
    If Counter <> 9 Or Err.Number <> 6 Then HeaderFailure = 11: Exit Function
    If Position = 1 And Trace <> 1 Then HeaderFailure = 12: Exit Function
    If Position = 2 And Trace <> 12 Then HeaderFailure = 13: Exit Function
    If Position = 3 And Trace <> 123 Then HeaderFailure = 14: Exit Function
End Function

Private Function HeaderHandler(ByVal BadValue As Long) As Long
    Dim Counter As Byte = 9
    Dim Trace As Long
    On Error GoTo Caught
    For Counter = Mark(Trace, 1, BadValue) To Mark(Trace, 2, 3)
        HeaderHandler = 20
        Exit Function
    Next
    HeaderHandler = 21
    Exit Function
Caught:
    If Counter <> 9 Or Trace <> 1 Or Err.Number <> 6 Then HeaderHandler = 22
End Function

Private Sub RaiseError()
    Err.Raise 17
End Sub

Private Function ActiveHandler(ByVal BadValue As Long) As Long
    Dim Counter As Byte = 9
    Dim Visits As Long
    On Error GoTo Caught
    RaiseError
    ActiveHandler = 30
    Exit Function
Caught:
    Visits = Visits + 1
    If Visits <> 1 Then ActiveHandler = 31: Exit Function
    For Counter = BadValue To 3
        ActiveHandler = 32
        Exit Function
    Next
    If Counter <> 9 Or Err.Number <> 6 Then ActiveHandler = 33: Exit Function
    On Error GoTo 0
    Err.Clear
    For Counter = 1 To 2
    Next
    If Counter <> 3 Or Err.Number <> 0 Then ActiveHandler = 34
End Function

Private Function IncrementHandler() As Long
    Dim Counter As Integer
    Dim BodyCount As Long
    On Error GoTo Caught
    For Counter = 32767 To 32767
        BodyCount = BodyCount + 1
    Next
    IncrementHandler = 40
    Exit Function
Caught:
    If Counter <> 32767 Or BodyCount <> 1 Or Err.Number <> 6 Then IncrementHandler = 41
End Function

Private Function BodyFailure(ByVal Limit As Long) As Long
    Dim Counter As Long
    Dim Outer As Long
    Dim Inner As Byte
    Dim Count As Long
    Dim Value As Long = 9
    For Counter = 1 To 3
        Value = Limit + 1
        Count = Count + 1
    Next
    If Counter <> 4 Or Count <> 3 Or Value <> 9 Or Err.Number <> 6 Then BodyFailure = 50: Exit Function
    Count = 0
    For Outer = 1 To 3
        For Inner = Limit To 2
            BodyFailure = 51
            Exit Function
        Next
        Count = Count + 1
    Next
    If Count <> 3 Or Outer <> 4 Or Inner <> 0 Then BodyFailure = 52
End Function

Private Function SkippedIncrement() As Long
    Dim Counter As Byte
    RaiseError
    On Error GoTo Unexpected
    For Counter = 255 To 255
        While True
            Do
                Exit Loop
            Loop
        Wend
    Next
    If Counter <> 255 Or Err.Number <> 17 Then SkippedIncrement = 60
    Exit Function
Unexpected:
    SkippedIncrement = 61
End Function

Public Function Main() As Long
    On Error GoTo UnexpectedFailure
    If HeaderFailure(1) <> 0 Then Main = 1: Exit Function
    If HeaderFailure(2) <> 0 Then Main = 2: Exit Function
    If HeaderFailure(3) <> 0 Then Main = 3: Exit Function
    If HeaderHandler(300) <> 0 Then Main = 4: Exit Function
    If ActiveHandler(300) <> 0 Then Main = 5: Exit Function
    If IncrementHandler() <> 0 Then Main = 6: Exit Function
    If BodyFailure(2147483647) <> 0 Then Main = 7: Exit Function
    If SkippedIncrement() <> 0 Then Main = 8: Exit Function
    Exit Function
UnexpectedFailure:
    Main = 99
End Function
