UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim maximum As Long = 2147483647
    Dim failed As Long = maximum + 1
    Dim later As Long = failed + 7
    If failed = 0 AndAlso later = 7 Then
        Main = 37
    Else
        Main = 99
    End If
End Function
