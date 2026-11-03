UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim a As Byte = 200
    Dim b As Byte = 100
    Dim sum As Integer = a + b
    Dim neg As Integer = -a
    Dim numerator As Long = 17
    Dim divisor As Long = -5
    Dim quotient As Long = numerator \ divisor
    Dim remainder As Long = numerator Mod divisor
    If sum = 300 AndAlso neg = -200 AndAlso quotient = -3 AndAlso remainder = 2 Then
        Main = 67
    Else
        Main = 99
    End If
End Function
