UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim a As Byte = 255
    Dim b As Byte = 15
    Dim inverted As Integer = Not a
    Dim both As Integer = a And b
    Dim either As Integer = a Or b
    Dim different As Integer = a Xor b
    Dim equivalent As Integer = a Eqv b
    Dim implied As Integer = a Imp b
    If inverted = -256 AndAlso both = 15 AndAlso either = 255 AndAlso different = 240 AndAlso equivalent = -241 AndAlso implied = -241 Then
        Main = 80
    Else
        Main = 99
    End If
End Function
