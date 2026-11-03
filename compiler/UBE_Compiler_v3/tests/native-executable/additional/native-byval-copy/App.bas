UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Private Function ChangeCopy(ByVal value As NativeBytes.Octet) As NativeBytes.Octet
    value = NativeBytes.CreateByte(0)
    ChangeCopy = value
End Function
Function Main() As Long
    Dim original As NativeBytes.Octet = NativeBytes.CreateByte(255)
    Dim changed As NativeBytes.Octet = ChangeCopy(original)
    If NativeBytes.ReadByte(original) = 255 AndAlso NativeBytes.ReadByte(changed) = 0 Then
        Main = 79
    Else
        Main = 99
    End If
End Function
