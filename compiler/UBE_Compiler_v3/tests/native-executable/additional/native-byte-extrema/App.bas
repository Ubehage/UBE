UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Private Function Echo(ByVal value As NativeBytes.Octet) As NativeBytes.Octet
    Echo = value
End Function
Private Sub Replace(ByRef value As NativeBytes.Octet, ByVal replacement As NativeBytes.Octet)
    value = replacement
End Sub
Function Main() As Long
    Dim original As NativeBytes.Octet = NativeBytes.CreateByte(255)
    Dim copy As NativeBytes.Octet = Echo(original)
    Call Replace(original, NativeBytes.CreateByte(0))
    If NativeBytes.ReadByte(copy) = 255 AndAlso NativeBytes.ReadByte(original) = 0 Then
        Main = 77
    Else
        Main = 99
    End If
End Function
