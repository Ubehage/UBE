UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Private Function Sum(ByVal n As Long) As Long
    If n = 0 Then
        Exit Function
    End If
    Sum = n + Sum(n - 1)
End Function
Function Main() As Long
    Main = Sum(5)
End Function
