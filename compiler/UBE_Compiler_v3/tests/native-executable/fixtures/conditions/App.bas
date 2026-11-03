UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim n As Long = 2
    Dim count As Long = 0
    While n
        Dim inner As Long = 2
        While inner
            count = count + 1
            inner = inner - 1
        Wend
        n = n - 1
    Wend
    If count = 3 Then
        Main = 98
    ElseIf count = 4 Then
        Main = 41
    Else
        Main = 99
    End If
End Function
