UBE SOURCE 1 MODULE
Attribute UBE_Name = "FailureFlowOracle"

' Source-level acceptance oracle compiled and executed by the native-compilation gate.
Private AfterRaise As Long
Private OperandCalls As Long
Private Cleaned As Long
Private CleanupAfter As Long

' Returns zero successfully without clearing a previous error.
Private Function SuccessfulZero() As Long
    SuccessfulZero = 0
End Function

' Raises only for a value supplied at runtime by the external test harness.
Private Function ReadValue(ByVal FailureInput As Long) As Long
    If FailureInput <> 0 Then Err.Raise 5
    AfterRaise = 1
    ReadValue = 100
End Function

' Makes evaluation of a following expression operand observable.
Private Function FollowingOperand() As Long
    OperandCalls = OperandCalls + 1
    FollowingOperand = 10
End Function

' Models explicit user cleanup before raising with bounded observable markers.
Private Sub CleanupThenRaise(ByVal FailureInput As Long)
    If FailureInput <> 0 Then
        Cleaned = 1
        Err.Raise 5
    End If
    CleanupAfter = 1
End Sub

' Writes through ByRef before reporting failure; the write must survive.
Private Sub WriteThenRaise(ByVal FailureInput As Long, ByRef Value As Long)
    Value = 17
    If FailureInput <> 0 Then Err.Raise 5
End Sub

' Checks successful zero after a preceding statement left Err 5.
Public Function CheckSuccessZero(ByVal FailureInput As Long) As Long
    Dim Value As Long
    Err.Clear
    Value = ReadValue(FailureInput)
    Value = 77
    Value = SuccessfulZero()
    CheckSuccessZero = 1
    If Value = 0 And Err.Number = 5 Then CheckSuccessZero = 0
End Function

' Checks immediate procedure exit and failure-result nonpublication.
Public Function CheckRaiseExit(ByVal FailureInput As Long) As Long
    Dim Value As Long
    Err.Clear
    AfterRaise = 0
    Value = 88
    Value = ReadValue(FailureInput)
    CheckRaiseExit = 2
    If Value = 88 And Err.Number = 5 And AfterRaise = 0 Then CheckRaiseExit = 0
End Function

' Checks default statement skipping, assignment preservation and operand ordering.
Public Function CheckDefaultContinuation(ByVal FailureInput As Long) As Long
    Dim Value As Long
    Err.Clear
    OperandCalls = 0
    Value = 25
    Value = ReadValue(FailureInput) + FollowingOperand()
    CheckDefaultContinuation = 4
    If Value = 25 And OperandCalls = 0 And Err.Number = 5 Then CheckDefaultContinuation = 0
End Function

' Checks transfer to the enabled caller handler rather than normal continuation.
Public Function CheckCallerHandler(ByVal FailureInput As Long) As Long
    Dim Value As Long
    Err.Clear
    Value = 99
    On Error GoTo Failed
    Value = ReadValue(FailureInput)
    CheckCallerHandler = 8
    Exit Function
Failed:
    CheckCallerHandler = 8
    If Value = 99 And Err.Number = 5 Then CheckCallerHandler = 0
End Function

' Checks a failing call in an active handler without unbounded reentry.
Public Function CheckActiveHandler(ByVal FailureInput As Long) As Long
    Dim Entries As Long
    Dim Value As Long
    Err.Clear
    Entries = 0
    Value = 25
    On Error GoTo Failed
    Value = ReadValue(FailureInput)
    CheckActiveHandler = 16
    Exit Function
Failed:
    Entries = Entries + 1
    If Entries > 1 Then
        CheckActiveHandler = 16
        Exit Function
    End If
    Value = ReadValue(FailureInput)
    CheckActiveHandler = 16
    If Entries = 1 And Value = 25 And Err.Number = 5 Then CheckActiveHandler = 0
End Function

' Checks explicit cleanup before Raise and nonexecution of following cleanup.
Public Function CheckCleanupOrder(ByVal FailureInput As Long) As Long
    Err.Clear
    Cleaned = 0
    CleanupAfter = 0
    CleanupThenRaise FailureInput
    CheckCleanupOrder = 32
    If Cleaned = 1 And CleanupAfter = 0 And Err.Number = 5 Then CheckCleanupOrder = 0
End Function

' Checks preservation of a completed ByRef side effect.
Public Function CheckByRefPreservation(ByVal FailureInput As Long) As Long
    Dim Value As Long
    Err.Clear
    Value = 1
    WriteThenRaise FailureInput, Value
    CheckByRefPreservation = 64
    If Value = 17 And Err.Number = 5 Then CheckByRefPreservation = 0
End Function

' Checks two failed assignments even when their recorded error numbers are equal.
Public Function CheckRepeatedError(ByVal FailureInput As Long) As Long
    Dim FirstValue As Long
    Dim SecondValue As Long
    Dim FirstError As Long
    Err.Clear
    FirstValue = 10
    SecondValue = 20
    FirstValue = ReadValue(FailureInput)
    FirstError = Err.Number
    SecondValue = ReadValue(FailureInput)
    CheckRepeatedError = 128
    If FirstValue = 10 And SecondValue = 20 And FirstError = 5 And Err.Number = 5 Then CheckRepeatedError = 0
End Function
