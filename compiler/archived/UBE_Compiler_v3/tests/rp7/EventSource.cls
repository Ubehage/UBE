UBE SOURCE 1 CLASS
Attribute UBE_Name = "EventSource"

Public Event Progress(ByVal Value As Long)

Public Sub Emit(ByVal Value As Long)
    RaiseEvent Progress(Value)
End Sub
