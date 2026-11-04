UBE SOURCE 1 MODULE
Attribute UBE_Name = "A"
Public x As Long = ForwardValue()
Public Function ForwardValue() As Long
    Dim p As Long = 3
    ForwardValue = B.Touch(p) * 10 + p
End Function
