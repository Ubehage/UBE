UBE SOURCE 1 CLASS
Attribute UBE_Name = "Counter"
Option Explicit On

Private StoredValue As Long

Public Property Get Value() As Long
    Value = StoredValue
End Property

Public Property Let Value(ByVal NewValue As Long)
    StoredValue = NewValue
End Property

Public Default Property Get Item(ByVal Index As Long) As Long
    Item = StoredValue + Index
End Property

