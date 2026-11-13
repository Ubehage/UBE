UBE SOURCE 1 MODULE
Attribute UBE_Name = "Entry"
' Checks initializer FAIL propagation, sticky Err, recovery and successful execution afterward.
Public Function Main() As Long
    On Error GoTo Failed
    If Fault.Before <> 3 Or Fault.Missing <> 0 Or Fault.Following <> 7 Then Main = 1: Exit Function
    If Err.Number <> 5 Then Main = 2: Exit Function
    Err.Clear
    If Err.Number <> 0 Then Main = 3: Exit Function
    Main = 42
    Exit Function
Failed:
    Main = 80 + Err.Number
End Function
