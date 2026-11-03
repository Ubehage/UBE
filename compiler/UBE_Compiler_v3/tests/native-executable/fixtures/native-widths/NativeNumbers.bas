UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeNumbers"
Public Type SmallValue As Integer
End Type
Public Type WideValue As Long
End Type
Public Intrinsic Function PackSmall(ByVal bits As Integer) As SmallValue
Attribute PackSmall.UBE_Primitive = "Value.Pack"
End Function
Public Intrinsic Function UnpackSmall(ByVal item As SmallValue) As Integer
Attribute UnpackSmall.UBE_Primitive = "Value.Unpack"
End Function
Public Intrinsic Function PackWide(ByVal bits As Long) As WideValue
Attribute PackWide.UBE_Primitive = "Value.Pack"
End Function
Public Intrinsic Function UnpackWide(ByVal item As WideValue) As Long
Attribute UnpackWide.UBE_Primitive = "Value.Unpack"
End Function
Public Function EchoSmall(ByVal item As SmallValue) As SmallValue
    EchoSmall = item
End Function
Public Sub ReplaceWide(ByRef item As WideValue, ByVal replacement As WideValue)
    item = replacement
End Sub
