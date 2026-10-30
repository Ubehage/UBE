UBE SOURCE 1 MODULE
Attribute UBE_Name = "UnsupportedFileMain"

Function Main() As Long
    Open "missing.txt" For Input As #1
    Main = 0
End Function
