UBE SOURCE 1 MODULE
Attribute UBE_Name = "Fault"
Public Before As Long = 3
Public Missing As Long = Fail()
Public Following As Long = 7
' Raises a source error during initialization; execution must continue with a default result.
Private Function Fail() As Long
    Err.Raise 5
    Fail = 99
End Function
