' Adopted native-value mechanism test. Not a production UBECore module.
Type Octet As Byte
End Type

Intrinsic Function PackOctet(ByVal Storage As Byte) As Octet
Attribute PackOctet.UBE_Primitive = "Value.Pack"
End Function

Intrinsic Function UnpackOctet(ByVal Value As Octet) As Byte
Attribute UnpackOctet.UBE_Primitive = "Value.Unpack"
End Function

Sub ChangeCopy(ByVal Value As Octet)
    Value = PackOctet(50)
End Sub

Sub ChangeStorage(ByRef Value As Octet)
    Value = PackOctet(128)
End Sub

Function ReturnCopy(ByVal Value As Octet) As Octet
    ReturnCopy = Value
End Function

Function TrySetValue(ByVal InputValue As Long, ByRef Destination As Octet) As Boolean
    If InputValue < 0 Or InputValue > 255 Then
        TrySetValue = False
        Exit Function
    End If
    Destination = PackOctet(InputValue)
    TrySetValue = True
End Function
