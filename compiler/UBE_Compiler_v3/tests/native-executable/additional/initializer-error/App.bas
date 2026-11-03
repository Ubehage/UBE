UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Private divisor As Long = 0
Private failed As Long = 42 \ divisor
Private later As Long = failed + 7
Function Main() As Long
    If failed = 0 AndAlso later = 7 Then
        Main = 67
    Else
        Main = 99
    End If
End Function
