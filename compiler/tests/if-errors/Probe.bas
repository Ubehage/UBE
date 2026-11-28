UBE SOURCE 1 MODULE
Attribute UBE_Name = "Entry"

Private Function Condition(ByVal Seed As Long, ByRef Calls As Long) As Boolean
    Calls = Calls + 1
    If Seed = 1 Then Err.Raise 5
    Condition = True
End Function

Private Function Touch(ByRef Calls As Long) As Boolean
    Calls = Calls + 1
    Touch = True
End Function

Private Function Branches(ByVal Seed As Long) As Long
    Dim Calls As Long
    Dim Selected As Long
    Dim Failures As Long
    Call Err.Clear()
    If Condition(Seed, Calls) Then
        Failures = Failures + 1
    Else
        Selected = Selected + 1
    End If
    If Selected <> 1 Then Failures = Failures + 1
    If Err.Number <> 5 Then Failures = Failures + 1
    If Condition(Seed, Calls) Then Failures = Failures + 1 Else Selected = Selected + 1
    If Selected <> 2 Then Failures = Failures + 1
    If Condition(Seed, Calls) Then
        Failures = Failures + 1
    ElseIf Condition(Seed, Calls) Then
        Failures = Failures + 1
    ElseIf Touch(Calls) Then
        Selected = Selected + 1
    Else
        Failures = Failures + 1
    End If
    If Selected <> 3 Then Failures = Failures + 1
    If Calls <> 5 Then Failures = Failures + 1
    If Condition(Seed, Calls) Then
        Failures = Failures + 1
    ElseIf Condition(Seed, Calls) Then
        Failures = Failures + 1
    Else
        If Condition(Seed, Calls) Then
            Failures = Failures + 1
        Else
            Selected = Selected + 1
        End If
    End If
    If Selected <> 4 Then Failures = Failures + 1
    If Calls <> 8 Then Failures = Failures + 1
    If Condition(Seed, Calls) Then Failures = Failures + 1
    If Calls <> 9 Then Failures = Failures + 1
    ' Eager And must abandon the remaining operand after a fresh failure.
    If Condition(Seed, Calls) And Touch(Calls) Then
        Failures = Failures + 1
    Else
        Selected = Selected + 1
    End If
    If Calls <> 10 Then Failures = Failures + 1
    If Selected <> 5 Then Failures = Failures + 1
    ' Stale Err does not make a successful True condition fail.
    If Touch(Calls) Then Selected = Selected + 1 Else Failures = Failures + 1
    If Selected <> 6 Then Failures = Failures + 1
    If Err.Number <> 5 Then Failures = Failures + 1
    On Error Resume Next
    If Condition(Seed, Calls) Then Failures = Failures + 1 Else Selected = Selected + 1
    If Selected <> 7 Then Failures = Failures + 1
    Branches = Failures
End Function

Private Function Arithmetic(ByVal Divisor As Long) As Long
    Dim Selected As Long
    Dim Failures As Long
    If (10 \ Divisor) > 0 Then Failures = Failures + 1 Else Selected = 1
    If Selected <> 1 Then Failures = Failures + 1
    If Err.Number <> 11 Then Failures = Failures + 1
    Arithmetic = Failures
End Function

Private Function Handler(ByVal Seed As Long) As Long
    Dim Calls As Long
    Dim Selected As Long
    Dim Handled As Long
    Dim Failures As Long
    On Error GoTo Failed
    If Condition(Seed, Calls) Then
        Failures = Failures + 1
    Else
        Failures = Failures + 1
    End If
    Failures = Failures + 1
Done:
    If Handled <> 1 Then Failures = Failures + 1
    If Calls <> 2 Then Failures = Failures + 1
    If Selected <> 1 Then Failures = Failures + 1
    If Err.Number <> 5 Then Failures = Failures + 1
    Handler = Failures
    Exit Function
Failed:
    Handled = Handled + 1
    If Handled > 1 Then Handler = 99: Exit Function
    If Condition(Seed, Calls) Then Failures = Failures + 1 Else Selected = 1
    GoTo Done
End Function

Private Function Loops(ByVal Seed As Long) As Long
    Dim Calls As Long
    Dim Bodies As Long
    Dim Failures As Long
    Do Until Condition(Seed, Calls)
        Bodies = Bodies + 1
        Exit Do
    Loop
    If Bodies <> 0 Then Failures = Failures + 1
    Do
        Bodies = Bodies + 1
        If Bodies > 2 Then Exit Do
    Loop Until Condition(Seed, Calls)
    If Bodies <> 1 Then Failures = Failures + 1
    If Calls <> 2 Then Failures = Failures + 1
    Loops = Failures
End Function

Public Function Main() As Long
    Main = Branches(1) + Arithmetic(0) + Handler(1) + Loops(1)
End Function
