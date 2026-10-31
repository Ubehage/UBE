UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeValues"

Type Octet As Byte
End Type

Intrinsic Function PackOctet(ByVal Storage As Byte) As Octet
Attribute PackOctet.UBE_Primitive = "Value.Pack"
End Function

Intrinsic Function UnpackOctet(ByVal Value As Octet) As Byte
Attribute UnpackOctet.UBE_Primitive = "Value.Unpack"
End Function

Sub Main()
    Dim Value As Octet = PackOctet(255)
    Print UnpackOctet(Value)
End Sub
