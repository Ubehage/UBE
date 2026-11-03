UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeBytes"
Public Type Octet As Byte
End Type
Public Intrinsic Function CreateByte(ByVal bits As Byte) As Octet
Attribute CreateByte.UBE_Primitive = "Value.Pack"
End Function
Public Intrinsic Function ReadByte(ByVal boxed As Octet) As Byte
Attribute ReadByte.UBE_Primitive = "Value.Unpack"
End Function
