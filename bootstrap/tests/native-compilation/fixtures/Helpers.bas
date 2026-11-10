UBE SOURCE 1 MODULE
Attribute UBE_Name = "Helpers"
' Supplies observable scalar calls, initialization and reusable failure checks.
Public FailedValue As Long = Problem.RaiseNow()
Public InitialValue As Long = 7
Public Trace As Long
Public LaterCalls As Long
Public RecordCalls As Long
' Forces on-access initialization before this module's normal schedule position.
Public Function MarkInitial() As Long
    InitialValue = InitialValue + 2
    MarkInitial = InitialValue
End Function
' Reads initialized storage without resetting it on another module access.
Public Function ReadInitial() As Long
    ReadInitial = InitialValue
End Function
' Records the first operand's evaluation.
Public Function LeftOperand() As Long
    Trace = 1
    LeftOperand = 10
End Function
' Requires the first operand to have executed already.
Public Function RightOperand() As Long
    If Trace <> 1 Then Err.Raise 5
    Trace = 2
    RightOperand = 20
End Function
' Observes two exact aliases to the same caller storage.
Public Sub AliasPair(ByRef First As Long, ByRef Second As Long)
    First = First + 1
    Second = First + 1
End Sub
' Writes through either direct storage or an explicitly grouped temporary.
Public Sub Touch(ByRef Value As Long)
    Value = Value + 1
End Sub
' Performs checked runtime arithmetic on a caller-supplied value.
Public Function Increment(ByVal Value As Long) As Long
    Increment = Value + 1
End Function
' Returns neutral success while preserving an earlier visible error record.
Public Function SuccessfulZero() As Long
    SuccessfulZero = 0
End Function
' Reports explicit failure to test caller initialization and argument edges.
Public Function Fail() As Long
    Err.Raise 5
End Function
' Must not run after a preceding argument reports failure.
Public Function Later() As Long
    LaterCalls = LaterCalls + 1
    Later = 1
End Function
' Must not begin if argument preparation failed.
Public Sub Record(ByVal First As Long, ByVal Second As Long)
    RecordCalls = RecordCalls + 1
End Sub
' Explicit Resume Next and GoTo 0 restore ordinary continuation behavior.
Public Function CheckModes() As Long
    On Error GoTo Unexpected
    On Error Resume Next
    Fail
    On Error GoTo Unexpected
    On Error GoTo 0
    Fail
    CheckModes = 0
    Exit Function
Unexpected:
    CheckModes = 1
End Function
' Clearing Err while handling a failure does not reactivate that handler.
Public Function CheckActiveClear() As Long
    Dim Entries As Long
    CheckActiveClear = 1
    On Error GoTo Failed
    Fail
    Exit Function
Failed:
    Entries = Entries + 1
    If Entries > 1 Then Exit Function
    Err.Clear
    Fail
    If Entries = 1 And Err.Number = 5 Then CheckActiveClear = 0
End Function
' Exhausts the bounded source-call depth and then unwinds through normal returns.
Public Function Recurse() As Long
    Recurse = Recurse()
End Function
' Reentering a declaration establishes neutral storage on every execution.
Public Function CheckRedeclaration() As Long
    Dim Passes As Long
Again:
    Dim Value As Long
    If Value <> 0 Then CheckRedeclaration = 1: Exit Function
    Value = 9
    Passes = Passes + 1
    If Passes < 2 Then GoTo Again
    CheckRedeclaration = 0
End Function
' A grouped ByRef temporary remains isolated while its call statement repeats.
Public Function CheckTempLoop() As Long
    Dim Passes As Long
    Dim Value As Long = 7
Again:
    Touch (Value)
    Passes = Passes + 1
    If Passes < 1000 Then GoTo Again
    If Value = 7 Then CheckTempLoop = 0 Else CheckTempLoop = 1
End Function
