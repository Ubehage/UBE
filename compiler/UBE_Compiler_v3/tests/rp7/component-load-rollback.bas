UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Sub Main()
    Dim Window As New FailingLoadForm
    On Error Resume Next
    Load Window
    Print Err.Number <> 0
    Err.Clear
    Load Window
    Print Err.Number
    Unload Window
End Sub
