UBE SOURCE 1 MODULE
Attribute UBE_Name = "FiniteFailures"

Private Intrinsic Function SetError(ByVal Number As Long) As Boolean
Attribute SetError.UBE_Primitive = "Error.Set"
End Function

Private Function Echo(ByVal Value As Double) As Double
    Echo = Value
End Function

Private Function Touch(ByRef Calls As Long) As Double
    Calls = Calls + 1
    Touch = 1.0
End Function

Public Function Main() As Long
    Dim LeftValue As Double
    Dim RightValue As Double
    Dim Kept As Double = 42.0
    Dim Narrow As Single = 42.0!
    Dim Calls As Long
    On Error Resume Next
    LeftValue = Echo(1.0)
    RightValue = Echo(-0.0)
    Call SetError(57)
    Kept = (LeftValue / RightValue) + Touch(Calls)
    If Kept <> 42.0 Or Calls <> 0 Then Main = 1: Exit Function
    If Err.Number <> 11 Then Main = 2: Exit Function
    LeftValue = Echo(0.0)
    Kept = LeftValue / RightValue
    If Kept <> 42.0 Then Main = 3: Exit Function
    If Err.Number <> 11 Then Main = 4: Exit Function
    LeftValue = Echo(1.7976931348623157E308)
    RightValue = Echo(2.0)
    Kept = LeftValue * RightValue
    If Kept <> 42.0 Then Main = 5: Exit Function
    If Err.Number <> 6 Then Main = 6: Exit Function
    Narrow = LeftValue
    If Narrow <> 42.0! Then Main = 7: Exit Function
    If Err.Number <> 6 Then Main = 8: Exit Function
    Kept = Echo(1.0) + Echo(2.0)
    If Kept <> 3.0 Then Main = 9: Exit Function
    If Err.Number <> 6 Then Main = 10: Exit Function
End Function
