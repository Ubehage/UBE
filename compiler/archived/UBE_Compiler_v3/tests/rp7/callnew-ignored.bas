UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Sub Main()
    Dim Ignored As LongLong
    Ignored = CallNew Worker()
End Sub

Sub Worker()
    Print 77
End Sub
