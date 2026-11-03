UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim maximum As LongLong = 9223372036854775807
    Dim one As LongLong = 1
    Dim failed As LongLong = maximum + one
    Dim later As LongLong = failed + 7
    If failed = 0 AndAlso later = 7 Then
        Main = 78
    Else
        Main = 99
    End If
End Function
