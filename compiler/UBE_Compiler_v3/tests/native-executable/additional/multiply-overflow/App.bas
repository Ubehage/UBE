UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim tooLarge As Long = 46341
    Dim withinRange As Long = 46340
    Dim failed As Long = tooLarge * tooLarge
    Dim valid As Long = withinRange * withinRange
    If failed = 0 AndAlso valid = 2147395600 Then
        Main = 81
    Else
        Main = 99
    End If
End Function
