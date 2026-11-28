UBE SOURCE 1 MODULE
Attribute UBE_Name = "TextFormatting"
Public Function Main() As Long
    Dim Bytes(0 To 47) As Byte
    Dim Used As Long
    Dim Parsed As LongLong
    On Error GoTo Failed
    If Not BinaryFloatText.TryAppend(Bytes, Used, 4607182418800017408&&, 64) Then Main = 1: Exit Function
    If Used <> 1 Or Bytes(0) <> 49 Then Main = 2: Exit Function
    Used = 0
    If Not BinaryFloatText.TryAppend(Bytes, Used, -9223372036854775808&&, 64) Then Main = 3: Exit Function
    If Used <> 2 Or Bytes(0) <> 45 Or Bytes(1) <> 48 Then Main = 4: Exit Function
    Used = 0
    If Not BinaryFloatText.TryAppend(Bytes, Used, 4591870180066957722&&, 64) Then Main = 5: Exit Function
    If Used <> 3 Or Bytes(0) <> 48 Or Bytes(1) <> 46 Or Bytes(2) <> 49 Then Main = 6: Exit Function
    Used = 0
    If Not BinaryFloatText.TryAppend(Bytes, Used, 1, 64) Then Main = 7: Exit Function
    If Not BinaryFloat.TryParse(Bytes, 0, Used, 64, Parsed) Then Main = 8: Exit Function
    If Parsed <> 1 Then Main = 9: Exit Function
    Used = 0
    If Not BinaryFloatText.TryAppend(Bytes, Used, 9218868437227405311&&, 64) Then Main = 10: Exit Function
    If Not BinaryFloat.TryParse(Bytes, 0, Used, 64, Parsed) Then Main = 11: Exit Function
    If Parsed <> 9218868437227405311&& Then Main = 12: Exit Function
    Exit Function
Failed:
    Main = 250
End Function
