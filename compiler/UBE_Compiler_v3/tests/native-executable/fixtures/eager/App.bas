UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Private trace As Long
Private Function Touch() As Boolean
    trace = trace + 1
    Touch = True
End Function
Function Main() As Long
    Dim a As Boolean = False And Touch()
    Dim b As Boolean = True Or Touch()
    If trace = 2 AndAlso a = False AndAlso b = True Then
        Main = 31
    Else
        Main = 98
    End If
End Function
