UBE SOURCE 1 MODULE
Attribute UBE_Name = "OperatorPrecedence"

Private Function RuntimeValue(ByVal Value As Long) As Long
    RuntimeValue = Value
End Function

Public Function Main() As Long
    Dim LeftValue As Long
    Dim MiddleValue As Long
    Dim RightValue As Long
    If 8 \ 3 Mod 2 <> 8 Then Main = 1: Exit Function
    LeftValue = RuntimeValue(8)
    MiddleValue = RuntimeValue(3)
    RightValue = RuntimeValue(2)
    If LeftValue \ MiddleValue Mod RightValue <> 8 Then Main = 2: Exit Function
    If 8 * 3 \ 2 <> 8 Then Main = 3: Exit Function
End Function
