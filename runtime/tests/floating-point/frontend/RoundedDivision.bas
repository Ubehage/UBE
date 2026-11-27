UBE SOURCE 1 MODULE
Attribute UBE_Name = "RoundedDivision"

Private Function RuntimeValue(ByVal Value As Double) As Double
    RuntimeValue = Value
End Function

Public Function Main() As Long
    Dim LeftValue As Double
    Dim RightValue As Double
    Dim Result As LongLong
    On Error Resume Next
    If 8# \ 3# Mod 2# <> 8 Then Main = 14: Exit Function
    If (8# \ 3#) Mod 2# <> 0 Then Main = 15: Exit Function
    If 4294967297# \ 1# <> 4294967297^ Then Main = 1: Exit Function
    If 12.5# Mod 5# <> 2 Then Main = 2: Exit Function
    If -13.5# \ 3# <> -4 Then Main = 3: Exit Function
    LeftValue = RuntimeValue(4294967297#)
    RightValue = RuntimeValue(1#)
    Result = LeftValue \ RightValue
    If Result <> 4294967297^ Then Main = 4: Exit Function
    LeftValue = RuntimeValue(-13.5#)
    RightValue = RuntimeValue(3#)
    If LeftValue Mod RightValue <> -2 Then Main = 5: Exit Function
    LeftValue = RuntimeValue(-9223372036854775808#)
    RightValue = RuntimeValue(-1#)
    If LeftValue Mod RightValue <> 0 Then Main = 6: Exit Function
    Result = 42
    Result = LeftValue \ RightValue
    If Result <> 42 Then Main = 8: Exit Function
    If Err.Number <> 6 Then Main = 9: Exit Function
    LeftValue = RuntimeValue(1#)
    RightValue = RuntimeValue(0.5#)
    Result = LeftValue Mod RightValue
    If Result <> 42 Then Main = 12: Exit Function
    If Err.Number <> 11 Then Main = 10: Exit Function
    LeftValue = RuntimeValue(9223372036854775808#)
    RightValue = RuntimeValue(2#)
    Result = LeftValue \ RightValue
    If Result <> 42 Then Main = 13: Exit Function
    If Err.Number <> 6 Then Main = 11: Exit Function
End Function
