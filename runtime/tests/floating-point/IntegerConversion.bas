UBE SOURCE 1 MODULE
Attribute UBE_Name = "IntegerConversion"

Public Function Main() As Long
    Dim Value As LongLong
    On Error GoTo Failed
    If Not BinaryFloatValues.TryToInteger(4602678819172646912^, 64, Value) Then Main = 1: Exit Function
    If Value <> 0 Then Main = 2: Exit Function
    If Not BinaryFloatValues.TryToInteger(4609434218613702656^, 64, Value) Then Main = 3: Exit Function
    If Value <> 2 Then Main = 4: Exit Function
    If Not BinaryFloatValues.TryToInteger(4612811918334230528^, 64, Value) Then Main = 5: Exit Function
    If Value <> 2 Then Main = 6: Exit Function
    If Not BinaryFloatValues.TryToInteger(-4612811918334230528^, 64, Value) Then Main = 7: Exit Function
    If Value <> -2 Then Main = 8: Exit Function
    If Not BinaryFloatValues.TryToInteger(-4332462841530417152^, 64, Value) Then Main = 9: Exit Function
    If Value <> -9223372036854775808^ Then Main = 10: Exit Function
    Value = 42
    If BinaryFloatValues.TryToInteger(4890909195324358656^, 64, Value) Then Main = 11: Exit Function
    If Value <> 42 Or Err.Number <> 6 Then Main = 12: Exit Function
    If BinaryFloatValues.TryToInteger(9218868437227405312^, 64, Value) Then Main = 13: Exit Function
    If Value <> 42 Or Err.Number <> 6 Then Main = 14: Exit Function
    If Not BinaryFloatValues.TryToInteger(1, 64, Value) Then Main = 15: Exit Function
    If Value <> 0 Or Err.Number <> 6 Then Main = 16: Exit Function
    If Not BinaryFloatValues.TryFromInteger(16777217^, 32, Value) Then Main = 17: Exit Function
    If Value <> 1266679808^ Then Main = 18: Exit Function
    If Not BinaryFloatValues.TryFromInteger(16777219^, 32, Value) Then Main = 19: Exit Function
    If Value <> 1266679810^ Then Main = 20: Exit Function
    If Not BinaryFloatValues.TryFromInteger(-9223372036854775808^, 64, Value) Then Main = 21: Exit Function
    If Value <> -4332462841530417152^ Then Main = 22: Exit Function
    If Not BinaryFloatValues.TryConvertWidth(1, 32, 64, Value) Then Main = 23: Exit Function
    If Value <> 3936146074321813504^ Then Main = 24: Exit Function
    If Not BinaryFloatValues.TryConvertWidth(Value, 64, 32, Value) Then Main = 25: Exit Function
    If Value <> 1 Then Main = 26: Exit Function
    If Not BinaryFloatValues.TryConvertWidth(-9223372036854775808^, 64, 32, Value) Then Main = 27: Exit Function
    If Value <> 2147483648^ Then Main = 28: Exit Function
    Value = 42
    If BinaryFloatValues.TryConvertWidth(9218868437227405312^, 64, 32, Value) Then Main = 29: Exit Function
    If Value <> 42 Or Err.Number <> 6 Then Main = 30: Exit Function
    Value = 42
    If BinaryFloatValues.TryConvertWidth(9218868437227405311^, 64, 32, Value) Then Main = 31: Exit Function
    If Value <> 42 Or Err.Number <> 6 Then Main = 32: Exit Function
    If BinaryFloatValues.TryPackArithmetic(False, 16777215^, 105, False, 32, Value) Then Main = 33: Exit Function
    If Value <> 42 Or Err.Number <> 6 Then Main = 34: Exit Function
    If Not BinaryFloatValues.TryPackArithmetic(False, 33554429^, 103, False, 32, Value) Then Main = 35: Exit Function
    If Value <> 2139095038^ Then Main = 36: Exit Function
    If Not BinaryFloatValues.TryPackArithmetic(False, 67108858^, 102, True, 32, Value) Then Main = 37: Exit Function
    If Value <> 2139095039^ Then Main = 38: Exit Function
    If Not BinaryFloatValues.TryPackArithmetic(True, 1, -150, False, 32, Value) Then Main = 39: Exit Function
    If Value <> 2147483648^ Then Main = 40: Exit Function
    If Not BinaryFloatValues.TryPackArithmetic(False, 4, -152, True, 32, Value) Then Main = 41: Exit Function
    If Value <> 1 Then Main = 42: Exit Function
    Value = 42
    If BinaryFloatValues.TryConvertWidth(9221120237041090560^, 64, 64, Value) Then Main = 43: Exit Function
    If Value <> 42 Or Err.Number <> 6 Then Main = 44: Exit Function
    If BinaryFloatValues.TryConvertWidth(2139095040^, 32, 64, Value) Then Main = 45: Exit Function
    If Value <> 42 Or Err.Number <> 6 Then Main = 46: Exit Function
    Exit Function
Failed:
    Main = 250
End Function
