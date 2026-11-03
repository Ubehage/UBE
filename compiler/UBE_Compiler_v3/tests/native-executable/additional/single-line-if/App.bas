UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim total As Long = 0
    Dim yes As Boolean = True
    Dim no As Boolean = False
    If yes Then total = total + 1 Else total = total + 10
    If no Then total = total + 20 Else total = total + 2
    If no Then total = total + 40
    If yes Then total = total + 4
    Main = total
End Function
