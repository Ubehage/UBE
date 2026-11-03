UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim minimum As NativeNumbers.SmallValue = NativeNumbers.PackSmall(-32768)
    Dim smallCopy As NativeNumbers.SmallValue = NativeNumbers.EchoSmall(minimum)
    Dim maximum As NativeNumbers.WideValue = NativeNumbers.PackWide(2147483647)
    Dim old As NativeNumbers.WideValue = maximum
    Call NativeNumbers.ReplaceWide(maximum, NativeNumbers.PackWide(-2147483648))
    If NativeNumbers.UnpackSmall(smallCopy) = -32768 AndAlso NativeNumbers.UnpackWide(old) = 2147483647 AndAlso NativeNumbers.UnpackWide(maximum) = -2147483648 Then
        Main = 73
    Else
        Main = 99
    End If
End Function
