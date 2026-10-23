UBE SOURCE 1 MODULE
Attribute UBE_Name = "RP7ComponentDrainMain"

Sub Main()
    Dim Window As New DrainForm
    Load Window
    Call Window.CloseSelf(Window)
    On Error Resume Next
    Call Window.CloseSelf(Window)
    Print Err.Number
End Sub
