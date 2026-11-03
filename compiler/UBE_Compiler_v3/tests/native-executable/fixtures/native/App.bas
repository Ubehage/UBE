UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim item As NativeBytes.Octet = NativeBytes.CreateByte(7)
    Dim copy As NativeBytes.Octet = item
    item = NativeBytes.CreateByte(9)
    If item <> copy Then
        Main = NativeBytes.ReadByte(copy)
    Else
        Main = 99
    End If
End Function
