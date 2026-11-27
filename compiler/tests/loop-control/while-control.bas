Private Function TestCondition(ByRef Calls As Long) As Boolean
    Calls = Calls + 1
    TestCondition = True
End Function

Private Function FailedCondition(ByRef Calls As Long) As Boolean
    Calls = Calls + 1
    Err.Raise 31
End Function

Private Function HandledFailure() As Long
    Dim Calls As Long
    On Error GoTo Caught
    While FailedCondition(Calls)
        HandledFailure = 10
        Exit Function
    Wend
    HandledFailure = 11
    Exit Function
Caught:
    If Calls <> 1 Or Err.Number <> 31 Then HandledFailure = 12
End Function

Public Function Main() As Long
    Dim Count As Long
    Dim Calls As Long
    On Error GoTo UnexpectedFailure
    While TestCondition(Calls)
        Do
            Count = Count + 1
            Exit Loop
        Loop
        Count = 100
        Exit While
    Wend
    If Count <> 1 Or Calls <> 1 Then Main = 1: Exit Function
    Do
        While TestCondition(Calls)
            Exit Loop
        Wend
        Main = 2
        Exit Function
    Loop
    If Calls <> 2 Then Main = 3: Exit Function
    ' Named exits pass through intervening loops of the other kind.
    Do
        While True
            Exit Do
        Wend
        Main = 4
        Exit Function
    Loop
    While True
        Do
            Exit While
        Loop
        Main = 5
        Exit Function
    Wend
    While False
        Main = 6
        Exit Function
    Wend
    Count = 0
    While Count < 3
        Count = Count + 1
    Wend
    If Count <> 3 Then Main = 7: Exit Function
    ' Exit While leaves the nearest While, even through an intervening Do.
    Count = 0
    While Count < 2
        While True
            Do
                Exit While
            Loop
            Main = 11
            Exit Function
        Wend
        Count = Count + 1
    Wend
    If Count <> 2 Then Main = 12: Exit Function
    On Error GoTo 0
    While FailedCondition(Calls)
        Main = 8
        Exit Function
    Wend
    If Calls <> 3 Or Err.Number <> 31 Then Main = 9: Exit Function
    On Error GoTo UnexpectedFailure
    If HandledFailure() <> 0 Then Main = 10: Exit Function
    Exit Function
UnexpectedFailure:
    Main = 99
End Function
