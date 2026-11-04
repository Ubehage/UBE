UBE SOURCE 1 MODULE
Attribute UBE_Name = "A"
Public x As Long = ForwardValue(3)
Public Function ForwardValue(ByVal p As Long) As Long
    ForwardValue = B.Touch(p) * 10 + p
End Function
