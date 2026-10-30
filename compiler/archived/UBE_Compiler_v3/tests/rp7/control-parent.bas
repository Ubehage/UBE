UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Sub Main()
    Dim ControlValue As New ParentlessControl
    On Error Resume Next
    Load ControlValue
    Print Err.Number
End Sub
