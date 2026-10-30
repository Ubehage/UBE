UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Sub Main()
    Error 123
    Print Err.Number
    Call Err.Clear()
    Print Err.Number
End Sub
