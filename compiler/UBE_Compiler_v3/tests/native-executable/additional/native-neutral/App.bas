UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim small As NativeNumbers.SmallValue
    Dim wide As NativeNumbers.WideValue
    If NativeNumbers.UnpackSmall(small) = 0 AndAlso NativeNumbers.UnpackWide(wide) = 0 Then
        Main = 74
    Else
        Main = 99
    End If
End Function
