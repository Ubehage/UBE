UBE SOURCE 1 MODULE
Attribute UBE_Name = "PowerBinding"
Private Function RuntimeValue(ByVal Value As Double) As Double
    RuntimeValue = Value
End Function
Public Function Main() As Long
    Dim BaseValue As Double
    Dim PowerValue As Double
    Dim Result As Double
    On Error Resume Next
    If 2# ^ 3# ^ 2# <> 64# Then Main = 1: Exit Function
    If -2# ^ 2# <> -4# Then Main = 2: Exit Function
    If (-2#) ^ 2# <> 4# Then Main = 3: Exit Function
    If 9# ^ 0.5# <> 3# Then Main = 4: Exit Function
    BaseValue = RuntimeValue(2#)
    PowerValue = RuntimeValue(0.5#)
    Result = BaseValue ^ PowerValue
    If Result <> 1.4142135623730951# Then Main = 5: Exit Function
    PowerValue = RuntimeValue(-3#)
    If BaseValue ^ PowerValue <> 0.125# Then Main = 6: Exit Function
    BaseValue = RuntimeValue(-2#)
    If BaseValue ^ PowerValue <> -0.125# Then Main = 7: Exit Function
    Result = 42#
    PowerValue = RuntimeValue(0.5#)
    Result = BaseValue ^ PowerValue
    If Result <> 42# Or Err.Number <> 5 Then Main = 8: Exit Function
    BaseValue = RuntimeValue(0#)
    PowerValue = RuntimeValue(-1#)
    Result = BaseValue ^ PowerValue
    If Result <> 42# Or Err.Number <> 5 Then Main = 9: Exit Function
    BaseValue = RuntimeValue(2#)
    PowerValue = RuntimeValue(1024#)
    Result = BaseValue ^ PowerValue
    If Result <> 42# Or Err.Number <> 6 Then Main = 10: Exit Function
    PowerValue = RuntimeValue(3#)
    Result = BaseValue ^ PowerValue
    If Result <> 8# Or Err.Number <> 6 Then Main = 11: Exit Function
    If BaseValue ^ PowerValue ^ 2# <> 64# Then Main = 12: Exit Function
    If BaseValue ^ -PowerValue ^ 2# <> 0.015625# Then Main = 13: Exit Function
    If 2# ^ -3# ^ 2# <> 0.015625# Then Main = 14: Exit Function
    If -BaseValue ^ 2# <> -4# Then Main = 15: Exit Function
    If BaseValue ^ +PowerValue ^ 2# <> 64# Then Main = 16: Exit Function
End Function
