UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Private Function Down(ByVal n As Long) As Long
    If n = 0 Then
        Down = 7
    Else
        Down = Down(n - 1)
    End If
End Function
Function Main() As Long
    Main = Down(12)
End Function
