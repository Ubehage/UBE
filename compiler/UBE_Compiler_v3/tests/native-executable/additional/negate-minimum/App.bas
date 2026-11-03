UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim minimum As Long = -2147483648
    Dim failed As Long = -minimum
    Dim later As Long = failed + 7
    If failed = 0 AndAlso later = 7 Then
        Main = 84
    Else
        Main = 99
    End If
End Function
