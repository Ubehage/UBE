UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim minimum As Long = -2147483648
    Dim negativeOne As Long = -1
    Dim positiveOne As Long = 1
    Dim failed As Long = minimum \ negativeOne
    Dim valid As Long = minimum \ positiveOne
    If failed = 0 AndAlso valid = -2147483648 Then
        Main = 82
    Else
        Main = 99
    End If
End Function
