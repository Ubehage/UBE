UBE SOURCE 1 MODULE
Attribute UBE_Name = "IntegerProbe"
' Exercises admitted integer widths through runtime inputs and checked failure edges.
Public Const ByteMax As Byte = 255
Public Const IntegerMin% = -32768%
Public Const IntegerMax% = 32767%
Public Const LongMin& = -2147483648&
Public Const LongMax& = 2147483647&
Public Const LongLongMin^ = -9223372036854775808^
Public Const LongLongMax^ = 9223372036854775807^
Public Const ContextWide As LongLong = 2147483647 + 1
Public Const NarrowAfterWide As Integer = 40000 + -10000
Private Calls As Long
' Byte operands promote before addition, and suffixed uses retain declared types.
Public Function CheckArithmetic(ByVal Seed As Long) As Long
    Dim B As Byte = 254 + Seed
    Dim I% = B + B
    Dim L& = I%
    Dim Q^ = ContextWide
    If I% <> 510 Then CheckArithmetic = 1: Exit Function
    If L& <> 510 Then CheckArithmetic = 2: Exit Function
    If Q^ <> 2147483648^ Then CheckArithmetic = 3: Exit Function
    Q^ = -9223372036854775808^
    If Q^ <> LongLongMin^ Then CheckArithmetic = 4: Exit Function
    I% = -B
    If I% <> -255% Then CheckArithmetic = 5: Exit Function
    I% = B And B
    If I% <> 255% Then CheckArithmetic = 6: Exit Function
    Q^ = EchoWide^(Q^)
    If Q^ <> LongLongMin^ Then CheckArithmetic = 7: Exit Function
    CheckArithmetic = 0
End Function
' Returns the widest signed value without narrowing at a call boundary.
Public Function EchoWide^(ByVal Value As LongLong)
    EchoWide^ = Value
End Function
' Checks failure at each selected arithmetic width and final conversion boundary.
Public Function CheckFailures(ByVal Seed As Long) As Long
    Dim B As Byte = 7
    Dim I As Integer = 32766 + Seed
    Dim L As Long = 77
    Dim Q As LongLong = 77
    Dim Flag As Boolean = Seed
    Err.Clear
    L = I + 1%
    If L <> 77 Then CheckFailures = 1: Exit Function
    If Err.Number <> 6 Then CheckFailures = 2: Exit Function
    Err.Clear
    L = 2147483646 + Seed
    Q = L + 1&
    If Q <> 77 Then CheckFailures = 3: Exit Function
    If Err.Number <> 6 Then CheckFailures = 4: Exit Function
    Err.Clear
    Q = 9223372036854775806^ + Seed
    Q = Q + 1^
    If Q <> LongLongMax^ Then CheckFailures = 5: Exit Function
    If Err.Number <> 6 Then CheckFailures = 6: Exit Function
    Err.Clear
    Q = LongLongMin^
    Q = -Q
    If Q <> LongLongMin^ Then CheckFailures = 7: Exit Function
    If Err.Number <> 6 Then CheckFailures = 8: Exit Function
    Err.Clear
    B = Flag
    If B <> 7 Then CheckFailures = 9: Exit Function
    If Err.Number <> 6 Then CheckFailures = 10: Exit Function
    Flag = False
    B = Flag
    If B <> 0 Then CheckFailures = 11: Exit Function
    B = 7
    L = 255 + Seed
    B = L
    If B <> 7 Then CheckFailures = 12: Exit Function
    L = -Seed
    B = L
    If B <> 7 Then CheckFailures = 13: Exit Function
    B = ConversionMatrix.EchoByte(255 + Seed)
    If B <> 7 Then CheckFailures = 17: Exit Function
    B = ConversionMatrix.FromLongLongToByte(255 + Seed)
    If B <> 0 Then CheckFailures = 18: Exit Function
    If Err.Number <> 6 Then CheckFailures = 19: Exit Function
    On Error GoTo Narrowed
    Q = 32767^ + Seed
    I = Q
    CheckFailures = 14
    Exit Function
Narrowed:
    If Err.Number <> 6 Then CheckFailures = 15: Exit Function
    If I <> 32767% Then CheckFailures = 16: Exit Function
    CheckFailures = 0
End Function
' Writes through exact Byte storage and records whether a call was entered.
Public Sub TouchByte(ByRef Value As Byte)
    Calls = Calls + 1
    Value = Value + 1
End Sub
' Writes through exact Integer storage.
Public Sub TouchInteger(ByRef Value As Integer)
    Value = Value + 1%
End Sub
' Writes through exact Long storage.
Public Sub TouchLong(ByRef Value As Long)
    Value = Value + 1&
End Sub
' Writes through exact LongLong storage.
Public Sub TouchWide(ByRef Value As LongLong)
    Value = Value + 1^
End Sub
' Tests exact aliases and grouping conversion, including failed argument preparation.
Public Function CheckByRef(ByVal Seed As Long) As Long
    Dim B As Byte = Seed
    Dim I As Integer = Seed
    Dim L As Long = Seed
    Dim Q As LongLong = Seed
    Calls = 0
    TouchByte B
    TouchInteger I
    TouchLong L
    TouchWide Q
    If B <> 2 Then CheckByRef = 1: Exit Function
    If I <> 2 Then CheckByRef = 2: Exit Function
    If L <> 2 Then CheckByRef = 3: Exit Function
    If Q <> 2 Then CheckByRef = 4: Exit Function
    TouchByte (L)
    If L <> 2 Then CheckByRef = 5: Exit Function
    If Calls <> 2 Then CheckByRef = 6: Exit Function
    L = 255 + Seed
    Err.Clear
    TouchByte (L)
    If Calls <> 2 Then CheckByRef = 7: Exit Function
    If Err.Number <> 6 Then CheckByRef = 8: Exit Function
    CheckByRef = 0
End Function
