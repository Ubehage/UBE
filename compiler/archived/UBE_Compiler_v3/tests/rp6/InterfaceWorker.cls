UBE SOURCE 1 CLASS
Attribute UBE_Name = "InterfaceWorker"

Implements IValue

Private StoredValue As Long

Private Sub Class_Initialize()
    StoredValue = 40
End Sub

Public Property Get Value() As Long
    Value = StoredValue
End Property

Public Sub Increment()
    StoredValue = StoredValue + 1
End Sub
