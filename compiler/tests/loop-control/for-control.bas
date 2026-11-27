Private Type CounterPair
    Value As Long
End Type

Private Function Mark(ByRef Trace As Long, ByVal Part As Long, ByVal Value As Long) As Long
    Trace = Trace * 10 + Part
    Mark = Value
End Function

Private Function FailHeader(ByRef Trace As Long) As Long
    Trace = Trace * 10 + 4
    Err.Raise 5
End Function

Private Function NestedCall(ByVal Depth As Long) As Long
    Dim Index As Long
    Dim Value As Long
    On Error GoTo UnexpectedFailure
    For Index = 1 To 2
        If Depth > 0 Then Value = NestedCall(Depth - 1)
        Do
            Exit Loop
        Loop
        NestedCall = 100
        Exit Function
    Next Index
    NestedCall = Value + Index
    Exit Function
UnexpectedFailure:
    NestedCall = 99
End Function

Public Function Main() As Long
    Dim Index As Long
    Dim Inner As Long
    Dim Count As Long
    Dim Limit As Long = 3
    Dim Stride As Long = 1
    Dim Trace As Long
    Dim Small As Byte
    Dim First As CounterPair
    Dim Second As CounterPair
    On Error GoTo UnexpectedFailure
    For Index = Mark(Trace, 1, 1) To Mark(Trace, 2, Limit) Step Mark(Trace, 3, Stride)
        Count = Count + 1
        Limit = 0
        Stride = -1
    Next Index
    If Count <> 3 Or Trace <> 123 Or Index <> 4 Then Main = 1: Exit Function
    Count = 0
    For Index = 3 To 1 Step -1
        Count = Count + Index
    Next
    If Count <> 6 Or Index <> 0 Then Main = 2: Exit Function
    For Index = 4 To 3
        Main = 3
        Exit Function
    Next Index
    If Index <> 4 Then Main = 4: Exit Function
    For Index = 1 To 2 Step 0
        Exit Loop
    Next Index
    If Index <> 1 Then Main = 5: Exit Function
    Count = 0
    For Index = 1 To 3
        For Inner = 1 To 3
            While True
                Do
                    Count = Count + 1
                    Exit Loop
                Loop
            Wend
        Next Inner
        Count = 100
        Exit For
    Next Index
    If Count <> 1 Or Index <> 1 Or Inner <> 1 Then Main = 6: Exit Function
    Do
        For Index = 1 To 3
            Exit Loop
        Next
        Main = 7
        Exit Function
    Loop
    If Index <> 1 Then Main = 8: Exit Function
    Count = 0
    For Index = 1 To 2
        For Inner = 1 To 3
            While True
                Exit For
            Wend
        Next
        Count = Count + Inner
    Next
    If Count <> 2 Or Index <> 3 Then Main = 9: Exit Function
    If NestedCall(4) <> 5 Then Main = 10: Exit Function
    On Error GoTo 0
    Err.Clear
    Count = 0
    For Index = 2147483647 To 2147483647
        Count = Count + 1
    Next
    If Count <> 1 Or Index <> 2147483647 Or Err.Number <> 6 Then Main = 11: Exit Function
    Err.Clear
    For Small = 254 To 255
        Count = Count + 1
    Next
    If Small <> 255 Or Count <> 3 Or Err.Number <> 6 Then Main = 12: Exit Function
    Index = 77
    Trace = 0
    For Index = FailHeader(Trace) To Mark(Trace, 2, 3) Step Mark(Trace, 3, 1)
        Main = 13
        Exit Function
    Next
    If Index <> 77 Or Trace <> 4 Or Err.Number <> 5 Then Main = 14: Exit Function
    Trace = 0
    For Index = Mark(Trace, 1, 1) To FailHeader(Trace) Step Mark(Trace, 3, 1)
        Main = 15
        Exit Function
    Next
    If Index <> 77 Or Trace <> 14 Or Err.Number <> 5 Then Main = 16: Exit Function
    Count = 0
    For First.Value = 1 To 2
        For Second.Value = 1 To 2
            Count = Count + 1
        Next Second.Value,First.Value
    If Count <> 4 Or First.Value <> 3 Or Second.Value <> 3 Then Main = 17: Exit Function
    ' A source jump into a loop body must not use undefined SSA header values.
    GoTo InsideBody
    For Index = 1 To 2
InsideBody:
        Exit Loop
    Next
    If Index <> 77 Then Main = 18: Exit Function
    Exit Function
UnexpectedFailure:
    Main = 99
End Function
