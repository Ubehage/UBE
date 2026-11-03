UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim small As NativeNumbers.SmallValue = NativeNumbers.PackSmall(-12345)
    Dim copy As NativeNumbers.SmallValue = NativeNumbers.EchoSmall(small)
    Dim wide As NativeNumbers.WideValue = NativeNumbers.PackWide(-123456789)
    Dim old As NativeNumbers.WideValue = wide
    Call NativeNumbers.ReplaceWide(wide, NativeNumbers.PackWide(123456789))
    If NativeNumbers.UnpackSmall(copy) = -12345 AndAlso NativeNumbers.UnpackWide(old) = -123456789 AndAlso NativeNumbers.UnpackWide(wide) = 123456789 Then
        Main = 47
    Else
        Main = 99
    End If
End Function
