UBE SOURCE 1 CLASS
Attribute UBE_Name = "Worker"

Private Value As Long

Private Sub Class_Initialize()
    Value = 10
End Sub

Private Sub Class_Terminate()
    Print 900
End Sub

Public Property Get Current() As Long
    Current = Value
End Property

Public Property Let Current(ByVal NewValue As Long)
    Value = NewValue
End Property

Public Sub Increment()
    Value = Value + 1
End Sub
