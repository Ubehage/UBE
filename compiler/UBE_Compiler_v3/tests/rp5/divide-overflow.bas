UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Function Main() As Long
    Dim Minimum As Long = -2147483647 - 1
    Main = Minimum \ -1
    Print "unreachable"
End Function
