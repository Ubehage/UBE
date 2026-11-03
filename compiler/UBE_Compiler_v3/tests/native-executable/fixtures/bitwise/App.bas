UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim x As Long = 6
    Dim y As Long = 3
    If (Not x) = -7 AndAlso (x And y) = 2 AndAlso (x Or y) = 7 AndAlso (x Xor y) = 5 AndAlso (x Eqv y) = -6 AndAlso (x Imp y) = -5 Then
        Main = 53
    Else
        Main = 99
    End If
End Function
