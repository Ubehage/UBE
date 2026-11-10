UBE SOURCE 1 MODULE
Attribute UBE_Name = "HandlerScopeProbe"
' Observes invocation-local handler modes and the independently shared sticky Err record.
Private Trace As Long

' Raises a fresh failure in a child, leaving continuation to its caller.
Private Sub RaiseFive()
    Err.Raise 5
End Sub

' Returns from an active handler without resetting its mode.
Private Function OwnHandler() As Long
    On Error GoTo Caught
    RaiseFive
    OwnHandler = 101
    Exit Function
Caught:
    OwnHandler = 7
End Function

' Resets only this invocation's handler mode and leaves Err untouched.
Private Sub ResetOwnMode()
    On Error GoTo 0
End Sub

' Installs an unused handler and returns without a reset statement.
Private Sub EnableAndReturn()
    On Error GoTo Unexpected
    Exit Sub
Unexpected:
    Trace = 99
End Sub

' Clears the shared error record without changing another invocation's handler state.
Private Sub ClearChild()
    Err.Clear
End Sub

' A callee's enabled and active handler must not replace the caller's handler.
Private Function CheckCalleeHandler() As Long
    Dim Value As Long
    On Error GoTo Caught
    Value = OwnHandler()
    If Value <> 7 Then CheckCalleeHandler = 11: Exit Function
    RaiseFive
    CheckCalleeHandler = 12
    Exit Function
Caught:
    If Err.Number <> 5 Then CheckCalleeHandler = 13: Exit Function
    CheckCalleeHandler = 0
End Function

' A callee's explicit mode reset must not disable the caller's enabled handler.
Private Function CheckCalleeReset() As Long
    On Error GoTo Caught
    ResetOwnMode
    If Err.Number <> 5 Then CheckCalleeReset = 14: Exit Function
    RaiseFive
    CheckCalleeReset = 15
    Exit Function
Caught:
    If Err.Number <> 5 Then CheckCalleeReset = 16: Exit Function
    CheckCalleeReset = 0
End Function

' Every recursive call installs and enters its own handler while its parent handler remains active.
Private Function RecursiveOwn(ByVal Depth As Long) As Long
    Dim Value As Long
    On Error GoTo Caught
    RaiseFive
    RecursiveOwn = 102
    Exit Function
Caught:
    Trace = Trace + 1
    If Depth > 0 Then
        Value = RecursiveOwn(Depth - 1)
        If Value <> Depth - 1 Then RecursiveOwn = 103: Exit Function
    End If
    RecursiveOwn = Depth
End Function

' The recursive base invocation starts in default mode instead of inheriting its parent's handler.
Private Function RecursiveDefault(ByVal Depth As Long) As Long
    Dim Value As Long
    If Depth > 0 Then
        On Error GoTo Caught
        Value = RecursiveDefault(Depth - 1)
        If Value <> Depth - 1 Then RecursiveDefault = 104: Exit Function
        RaiseFive
        RecursiveDefault = 105
        Exit Function
    End If
    RaiseFive
    Trace = Trace + 1
    RecursiveDefault = 0
    Exit Function
Caught:
    If Depth = 0 Then RecursiveDefault = 106: Exit Function
    Trace = Trace + 1
    RecursiveDefault = Depth
End Function

' Checks exact observations using a volatile harness-supplied recursion depth.
Public Function Run(ByVal RuntimeDepth As Long) As Long
    Dim Value As Long
    Value = CheckCalleeHandler()
    If Value <> 0 Then Run = Value: Exit Function
    Value = CheckCalleeReset()
    If Value <> 0 Then Run = Value: Exit Function
    Trace = 0
    Value = RecursiveOwn(RuntimeDepth)
    If Value <> 3 Then Run = 23: Exit Function
    If Trace <> 4 Then Run = 24: Exit Function
    Trace = 0
    Value = RecursiveDefault(RuntimeDepth)
    If Value <> 3 Then Run = 25: Exit Function
    If Trace <> 4 Then Run = 26: Exit Function
    If Err.Number <> 5 Then Run = 27: Exit Function
    Trace = 0
    EnableAndReturn
    RaiseFive
    If Trace <> 0 Then Run = 28: Exit Function
    If Err.Number <> 5 Then Run = 29: Exit Function
    ResetOwnMode
    If Err.Number <> 5 Then Run = 30: Exit Function
    ClearChild
    If Err.Number <> 0 Then Run = 31: Exit Function
    Run = 0
End Function
