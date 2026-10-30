UBE SOURCE 1 CLASS
Attribute UBE_Name = "InterfaceOtherWorker"

Implements IValue

Private StoredValue As Long

Private Sub Class_Initialize()
    StoredValue = 80
End Sub

Public Property Get Value() As Long
    Value = StoredValue
End Property

Public Sub Increment()
    StoredValue = StoredValue + 2
End Sub
