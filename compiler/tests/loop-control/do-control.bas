Private Function RecursiveExit(ByVal Depth As Long) As Long
    Dim Count As Long
    Do
        If Depth > 0 Then
            Count = RecursiveExit(Depth - 1)
            If Count <> Depth Then RecursiveExit = 100: Exit Function
        End If
        Do
            Exit Loop
        Loop
        RecursiveExit = 101
        Exit Function
    Loop
    RecursiveExit = Count + 1
End Function

Private Function Condition(ByRef Count As Long) As Boolean
    Count = Count + 1
    Condition = True
End Function

Private Sub TerminalLoop(ByRef Count As Long)
    Do
        Count = Count + 1
        Do
            Exit Loop
        Loop
        Count = 100
        Exit Do
    Loop
End Sub

Private Sub RecordFailure()
    Err.Raise 17
End Sub

Public Function Main() As Long
    Dim Count As Long
    Dim Tests As Long
    Dim UntilTests As Long
    Dim AfterBlock As Long
    On Error GoTo UnexpectedFailure
    If True Then
        Do While Condition(Tests)
            Count = Count + 1
            Do
                If True Then Exit Loop
                Count = 100
                Exit Do
            Loop While Condition(Tests)
            Count = 101
            Exit Do
        Loop
        AfterBlock = 1
    End If
    If Count <> 1 Or Tests <> 1 Or AfterBlock <> 1 Then Main = 1: Exit Function
    If RecursiveExit(4) <> 5 Then Main = 2: Exit Function
    Count = 0
    TerminalLoop Count
    If Count <> 1 Then Main = 3: Exit Function
    Count = 0
    Do
        Do
            Exit Do
        Loop
        Count = Count + 1
        If Count = 2 Then Exit Loop
    Loop
    If Count <> 2 Then Main = 4: Exit Function
    Do Until False
        Exit Loop
    Loop
    Do
        Exit Loop
    Loop Until Condition(Tests)
    If Tests <> 1 Then Main = 5: Exit Function
    On Error GoTo 0
    RecordFailure
    On Error GoTo UnexpectedFailure
    Do
        Do
            Exit Loop
        Loop
        Main = 6
        Exit Function
    Loop
    If Err.Number <> 17 Then Main = 7: Exit Function
    ' A following sibling loop must acquire its own outermost continuation.
    Do
        Exit Loop
    Loop
    Count = 8
    If Count <> 8 Then Main = 8: Exit Function
    ' The pretest Until condition runs once; exiting both loops must not retest it.
    Count = 0
    Do Until Not Condition(UntilTests)
        Count = Count + 1
        Do
            Exit Loop
        Loop
        Count = 100
        Exit Do
    Loop
    If Count <> 1 Or UntilTests <> 1 Then Main = 10: Exit Function
    Exit Function
UnexpectedFailure:
    Main = 9
End Function
