UBE SOURCE 1 MODULE
Attribute UBE_Name = "OperatorPrecedence"

Private Function RuntimeValue(ByVal Value As Long) As Long
    RuntimeValue = Value
End Function

Public Function Main() As Long
    Dim LeftValue As Long
    Dim MiddleValue As Long
    Dim RightValue As Long
    If 8 \ 3 Mod 2 <> 0 Then Main = 1: Exit Function
    LeftValue = RuntimeValue(8)
    MiddleValue = RuntimeValue(3)
    RightValue = RuntimeValue(2)
    If LeftValue \ MiddleValue Mod RightValue <> 0 Then Main = 2: Exit Function
    If 8 * 3 \ 2 <> 12 Then Main = 3: Exit Function
    MiddleValue = RuntimeValue(5)
    RightValue = RuntimeValue(3)
    If LeftValue * MiddleValue Mod RightValue <> 1 Then Main = 4: Exit Function
    If LeftValue * MiddleValue \ RightValue <> 13 Then Main = 5: Exit Function
    If LeftValue \ MiddleValue * RightValue <> 0 Then Main = 6: Exit Function
    If LeftValue \ MiddleValue Mod RightValue <> 1 Then Main = 7: Exit Function
    If LeftValue / MiddleValue \ RightValue <> 0 Then Main = 8: Exit Function
    If LeftValue \ MiddleValue / RightValue <> 4 Then Main = 9: Exit Function
    If LeftValue + MiddleValue Mod RightValue <> 10 Then Main = 10: Exit Function
    If LeftValue - MiddleValue Mod RightValue <> 6 Then Main = 11: Exit Function
    If LeftValue / 2 * 2 <> 8 Then Main = 12: Exit Function
End Function
