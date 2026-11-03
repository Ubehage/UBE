UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim value As NativeBytes.Octet
    If NativeBytes.ReadByte(value) = 0 Then
        Main = 75
    Else
        Main = 99
    End If
End Function
