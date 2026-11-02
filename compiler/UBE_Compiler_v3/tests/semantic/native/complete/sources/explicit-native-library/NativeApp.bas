UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeApp"
Public Function Main() As Long
    Dim item As NativeBytes.Octet = NativeBytes.CreateByte(7)
    Dim copy As NativeBytes.Octet = item
    Dim raw As Byte = NativeBytes.ReadByte(copy)
    Dim same As Boolean = item = copy
    If same Then
        raw = 9
    End If
    Main = 0
End Function
