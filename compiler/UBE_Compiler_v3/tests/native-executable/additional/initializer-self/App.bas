UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim number As Long = number + 5
    Dim divisor As Long = 0
    Dim failed As Long = 42 \ divisor
    failed = failed + 7
    If number = 5 AndAlso failed = 7 Then
        Main = 97
    Else
        Main = 99
    End If
End Function
