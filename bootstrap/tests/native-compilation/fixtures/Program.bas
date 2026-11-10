UBE SOURCE 1 MODULE
Attribute UBE_Name = "Program"
' Exercises native scalar statements and cross-module initialization/failure behavior.
Public EarlyValue As Long = Helpers.MarkInitial()
' Tests native cross-module state, argument ordering, aliases and checked failures.
Public Function Main() As Long
    Dim Value As Long
    Dim Flag As Boolean = True
    Dim Limit As Long = 2147483647
    Dim LocalFailure As Long = Helpers.Fail()
    Dim AfterLocal As Long = 2
    If EarlyValue <> 9 Then Main = 1: Exit Function
    If Helpers.InitialValue <> 9 Then Main = 2: Exit Function
    Helpers.InitialValue = 11
    Value = Helpers.ReadInitial()
    If Value <> 11 Then Main = 14: Exit Function
    If LocalFailure <> 0 Then Main = 15: Exit Function
    If AfterLocal <> 2 Then Main = 16: Exit Function
    If Helpers.FailedValue <> 0 Then Main = 17: Exit Function
    Value = Helpers.LeftOperand() + Helpers.RightOperand()
    If Value <> 30 Then Main = 3: Exit Function
    If Helpers.Trace <> 2 Then Main = 4: Exit Function
    Value = 1
    Helpers.AliasPair Value, Value
    If Value <> 3 Then Main = 5: Exit Function
    Helpers.Touch (Value)
    If Value <> 3 Then Main = 6: Exit Function
    Helpers.Touch (Flag)
    If Flag <> True Then Main = 7: Exit Function
    Value = Flag
    If Value <> -1 Then Main = 8: Exit Function
    Flag = 2
    If Flag <> True Then Main = 9: Exit Function
    Value = 77
    Err.Clear
    Value = Limit + 1
    If Value <> 77 Then Main = 10: Exit Function
    If Err.Number <> 6 Then Main = 11: Exit Function
    Value = Helpers.SuccessfulZero()
    If Value <> 0 Then Main = 12: Exit Function
    If Err.Number <> 6 Then Main = 13: Exit Function
    Value = Helpers.Increment(Limit)
    If Value <> 0 Then Main = 18: Exit Function
    If Err.Number <> 6 Then Main = 19: Exit Function
    Helpers.Record Helpers.Fail(), Helpers.Later()
    If Helpers.LaterCalls <> 0 Then Main = 20: Exit Function
    If Helpers.RecordCalls <> 0 Then Main = 21: Exit Function
    Value = Helpers.CheckModes()
    If Value <> 0 Then Main = 22: Exit Function
    Value = Helpers.CheckActiveClear()
    If Value <> 0 Then Main = 23: Exit Function
    Err.Clear
    Value = Helpers.Recurse()
    If Err.Number <> 28 Then Main = 24: Exit Function
    Value = Helpers.CheckRedeclaration()
    If Value <> 0 Then Main = 25: Exit Function
    Value = Helpers.CheckTempLoop()
    If Value <> 0 Then Main = 26: Exit Function
    Value = 77
    Err.Clear
    Value = Limit + 2147483648
    If Value <> 77 Then Main = 27: Exit Function
    If Err.Number <> 6 Then Main = 28: Exit Function
    Main = 0
End Function
