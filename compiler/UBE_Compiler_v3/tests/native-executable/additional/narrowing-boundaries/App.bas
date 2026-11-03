UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Private Function IToByte(ByVal value As Integer) As Byte
    IToByte = value
End Function
Private Function LToByte(ByVal value As Long) As Byte
    LToByte = value
End Function
Private Function LLToByte(ByVal value As LongLong) As Byte
    LLToByte = value
End Function
Private Function LToInteger(ByVal value As Long) As Integer
    LToInteger = value
End Function
Private Function LLToInteger(ByVal value As LongLong) As Integer
    LLToInteger = value
End Function
Private Function LLToLong(ByVal value As LongLong) As Long
    LLToLong = value
End Function
Function Main() As Long
    Main = 90
    If IToByte(0) <> 0 Then Main = 99
    If IToByte(255) <> 255 Then Main = 99
    If IToByte(-1) <> 0 Then Main = 99
    If IToByte(256) <> 0 Then Main = 99
    If LToByte(0) <> 0 Then Main = 99
    If LToByte(255) <> 255 Then Main = 99
    If LToByte(-1) <> 0 Then Main = 99
    If LToByte(256) <> 0 Then Main = 99
    If LLToByte(0) <> 0 Then Main = 99
    If LLToByte(255) <> 255 Then Main = 99
    If LLToByte(-1) <> 0 Then Main = 99
    If LLToByte(256) <> 0 Then Main = 99
    If LToInteger(-32768) <> -32768 Then Main = 99
    If LToInteger(32767) <> 32767 Then Main = 99
    If LToInteger(-32769) <> 0 Then Main = 99
    If LToInteger(32768) <> 0 Then Main = 99
    If LLToInteger(-32768) <> -32768 Then Main = 99
    If LLToInteger(32767) <> 32767 Then Main = 99
    If LLToInteger(-32769) <> 0 Then Main = 99
    If LLToInteger(32768) <> 0 Then Main = 99
    If LLToLong(-2147483648) <> -2147483648 Then Main = 99
    If LLToLong(2147483647) <> 2147483647 Then Main = 99
    If LLToLong(-2147483649) <> 0 Then Main = 99
    If LLToLong(2147483648) <> 0 Then Main = 99
End Function
