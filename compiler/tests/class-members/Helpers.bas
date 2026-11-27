UBE SOURCE 1 MODULE
Attribute UBE_Name = "Helpers"
Option Explicit
Public Held As Gate
Public Evaluations As Long
Public Effects As Long

Public Intrinsic Function CollectGarbage() As Long
Attribute CollectGarbage.UBE_Primitive = "Memory.Collect"
End Function
Public Intrinsic Function RecordError(ByVal Number As Long) As Boolean
Attribute RecordError.UBE_Primitive = "Error.Set"
End Function

Public Sub ClearReference(ByRef Value As Gate)
    Set Value = Nothing
End Sub

Public Sub ClearAndCollect(ByRef Value As Gate)
    On Error GoTo Failed
    Set Value = Nothing
    Call CollectGarbage()
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

Public Function Receiver() As Gate
    Evaluations = Evaluations + 1
    Set Receiver = Held
End Function

Public Function SideEffect() As Long
    Effects = Effects + 1
    SideEffect = 88
End Function

Public Function FailedReceiver() As Gate
    Err.Raise 23
End Function

Public Function ReplaceHeldAndCollect() As Long
    On Error GoTo Failed
    Set Held = New Gate
    Held.Value = 900
    Call CollectGarbage()
    ReplaceHeldAndCollect = 5
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

Public Function RewriteHeld(ByRef Value As Long) As Long
    On Error GoTo Failed
    Set Held = Nothing
    Call CollectGarbage()
    Value = 77
    Call CollectGarbage()
    RewriteHeld = Value
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

Public Sub RewriteRecord(ByRef Value As RecordTypes.Payload)
    On Error GoTo Failed
    Value.Number = 29
    Value.Text = "changed record"
    Call CollectGarbage()
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

Public Sub UnexpectedFailure()
    Err.Raise 51
End Sub
