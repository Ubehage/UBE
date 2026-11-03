UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim x As Long = -17
    Dim q As Long = x \ 5
    Dim r As Long = x Mod 5
    If q = -3 AndAlso r = -2 Then
        Main = 23
    Else
        Main = 99
    End If
End Function
