UBE SOURCE 1 CLASS
Attribute UBE_Name = "LeasedValue"

Private StoredValue As Long

Private Sub Class_Initialize()
    StoredValue = 42
End Sub

Public Property Get Value() As Long
    Value = StoredValue
End Property
