UBE SOURCE 1 MODULE
Attribute UBE_Name = "Probe"
' Exercises the normative precedence rather than conventional VB operator ordering.
Private Const MixedProduct As Long = 20 * 9 \ 4
Private Const MixedModulus As Long = 20 \ 7 Mod 4
Private Const MinimumRemainder% = -32768% Mod -1%
Private Const PositiveProduct% = 7% * 3%
Private Const LeftNegativeProduct% = -7% * 3%
Private Const RightNegativeProduct% = 7% * -3%
Private Const BothNegativeProduct% = -7% * -3%
Private Const LeftNegativeQuotient% = -7% \ 3%
Private Const RightNegativeQuotient% = 7% \ -3%
Private Const BothNegativeQuotient% = -7% \ -3%
Private Const LeftNegativeRemainder% = -7% Mod 3%
Private Const RightNegativeRemainder% = 7% Mod -3%
Private Const BothNegativeRemainder% = -7% Mod -3%
Private Const IntegerMinimumProduct% = -32768% * 1%
Private Const IntegerBoundaryProduct% = -128% * -255%
Private Const LongMinimumProduct& = -2147483648& * 1&
Private Const LongBoundaryProduct& = -46340& * -46340&
Private Const WideMinimumProduct^ = -9223372036854775808^ * 1^
Private Const WideBoundaryProduct^ = -3037000499^ * -3037000499^
Private Const WideZeroProduct^ = -9223372036854775808^ * 0^
Private Const LongMinimumRemainder& = -2147483648& Mod -1&
Private Const WideMinimumRemainder^ = -9223372036854775808^ Mod -1^
Private Const WideMaximumQuotient^ = 9223372036854775807^ \ 3^
Private Const WideMaximumRemainder^ = 9223372036854775807^ Mod 3^
Private Const WideMinimumQuotient^ = -9223372036854775808^ \ 3^
Private Const WideThirdRemainder^ = -9223372036854775808^ Mod 3^
Private Calls As Long
Private Trace As Long

' Returns one observed operand, recording evaluation order without multiplication.
Private Function Operand(ByVal Value As Long, ByVal Marker As Long) As Long
    Calls = Calls + 1
    If Calls = 1 And Marker <> 1 Then Trace = 999
    Trace = Trace + Marker
    Operand = Value
End Function

' Checks folded sign quadrants and boundary products against independent literal results.
Private Function CheckConstants() As Long
    If PositiveProduct% <> 21 Or LeftNegativeProduct% <> -21 Or RightNegativeProduct% <> -21 Or BothNegativeProduct% <> 21 Then CheckConstants = 1: Exit Function
    If LeftNegativeQuotient% <> -2 Or RightNegativeQuotient% <> -2 Or BothNegativeQuotient% <> 2 Then CheckConstants = 2: Exit Function
    If LeftNegativeRemainder% <> -1 Or RightNegativeRemainder% <> 1 Or BothNegativeRemainder% <> -1 Then CheckConstants = 3: Exit Function
    If IntegerMinimumProduct% <> -32768% Or IntegerBoundaryProduct% <> 32640% Then CheckConstants = 4: Exit Function
    If LongMinimumProduct& <> -2147483648& Or LongBoundaryProduct& <> 2147395600& Then CheckConstants = 5: Exit Function
    If WideMinimumProduct^ <> -9223372036854775808^ Or WideBoundaryProduct^ <> 9223372030926249001^ Then CheckConstants = 6: Exit Function
    If WideZeroProduct^ <> 0 Or LongMinimumRemainder& <> 0 Or WideMinimumRemainder^ <> 0 Then CheckConstants = 7: Exit Function
    If WideMaximumQuotient^ <> 3074457345618258602^ Or WideMaximumRemainder^ <> 1 Then CheckConstants = 8: Exit Function
    If WideMinimumQuotient^ <> -3074457345618258602^ Or WideThirdRemainder^ <> -2 Then CheckConstants = 9: Exit Function
End Function

' Supplies an explicit fresh failure from a callee during operand evaluation.
Private Function BrokenOperand(ByVal Marker As Long) As Long
    Calls = Calls + 1
    If Calls = 1 And Marker <> 1 Then Trace = 999
    Trace = Trace + Marker
    Err.Raise 11
    Trace = 999
End Function

' Mutates a later operand to check that an earlier scalar read was already captured.
Private Function ChangeOperand(ByRef Value As Long) As Long
    Value = 99
    ChangeOperand = 3
End Function

' Confirms signed quotient/remainder signs, left associativity and mixed precedence.
Private Function CheckPrecedence(ByVal Seed As Long) As Long
    Dim A As Long = 20 + Seed
    Dim B As Long = 9
    Dim C As Long = 4
    If A * B \ C <> 40 Then CheckPrecedence = 1: Exit Function
    B = 7
    If A \ B Mod C <> 6 Then CheckPrecedence = 2: Exit Function
    If A Mod B * C <> 24 Then CheckPrecedence = 3: Exit Function
    A = 19
    B = 6
    If A Mod B Mod C <> 1 Then CheckPrecedence = 4: Exit Function
    A = 100
    If A \ B \ C <> 4 Then CheckPrecedence = 5: Exit Function
    A = 7
    B = 3
    If -A Mod B <> -1 Then CheckPrecedence = 6: Exit Function
    If -A \ B <> -2 Then CheckPrecedence = 7: Exit Function
    If A \ -B <> -2 Then CheckPrecedence = 8: Exit Function
    If A Mod -B <> 1 Then CheckPrecedence = 9: Exit Function
    If -A Mod -B <> -1 Then CheckPrecedence = 10: Exit Function
    If -A \ -B <> 2 Then CheckPrecedence = 11: Exit Function
    If MixedProduct <> 40 Or MixedModulus <> 6 Or MinimumRemainder% <> 0 Then CheckPrecedence = 12: Exit Function
    If 2 + 3 * 8 \ 3 Mod 2 <> 26 Then CheckPrecedence = 13: Exit Function
End Function

' Byte arithmetic promotes to Integer before the destination conversion.
Private Function CheckByte(ByVal Seed As Long) As Long
    Dim A As Byte = 255 + Seed
    Dim B As Byte = 2
    Dim Z As Byte = Seed
    Dim I As Integer
    Dim L As Long = 77
    Dim Target As Byte = 19
    I = A * B
    If I <> 510 Then CheckByte = 1: Exit Function
    I = A \ B
    If I <> 127 Then CheckByte = 2: Exit Function
    I = A Mod B
    If I <> 1 Then CheckByte = 3: Exit Function
    B = 255
    Err.Clear
    L = A * B
    If L <> 77 Or Err.Number <> 6 Then CheckByte = 4: Exit Function
    L = 255
    L = A * L
    If L <> 65025 Or Err.Number <> 6 Then CheckByte = 5: Exit Function
    B = 2
    Target = A * B
    If Target <> 19 Or Err.Number <> 6 Then CheckByte = 6: Exit Function
    L = 77
    Err.Clear
    L = A \ Z
    If L <> 77 Or Err.Number <> 11 Then CheckByte = 7: Exit Function
    Err.Clear
    L = A Mod Z
    If L <> 77 Or Err.Number <> 11 Then CheckByte = 8: Exit Function
End Function

' Checks Integer-width intermediate overflow before wider assignment and grouped division.
Private Function CheckInteger(ByVal Seed As Long) As Long
    Dim A As Integer = 32767 + Seed
    Dim B As Integer = 2
    Dim Z As Integer = Seed
    Dim N As Integer = -1
    Dim R As Long = 77
    Err.Clear
    R = A * B
    If R <> 77 Or Err.Number <> 6 Then CheckInteger = 1: Exit Function
    R = A * B \ B
    If R <> 32767 Or Err.Number <> 6 Then CheckInteger = 2: Exit Function
    R = 77
    Err.Clear
    R = (A * B) \ B
    If R <> 77 Or Err.Number <> 6 Then CheckInteger = 3: Exit Function
    A = -32768%
    R = A Mod N
    If R <> 0 Or Err.Number <> 6 Then CheckInteger = 4: Exit Function
    R = 77
    Err.Clear
    R = A \ N
    If R <> 77 Or Err.Number <> 6 Then CheckInteger = 5: Exit Function
    Err.Clear
    R = A * N
    If R <> 77 Or Err.Number <> 6 Then CheckInteger = 6: Exit Function
    Err.Clear
    R = A \ Z
    If R <> 77 Or Err.Number <> 11 Then CheckInteger = 7: Exit Function
    Err.Clear
    R = A Mod Z
    If R <> 77 Or Err.Number <> 11 Then CheckInteger = 8: Exit Function
    A = -7
    B = 3
    R = A \ B
    If R <> -2 Or Err.Number <> 11 Then CheckInteger = 9: Exit Function
    R = A Mod B
    If R <> -1 Or Err.Number <> 11 Then CheckInteger = 10: Exit Function
End Function

' Checks Long-width arithmetic and narrowing from a successful wider multiplication.
Private Function CheckLong(ByVal Seed As Long) As Long
    Dim A As Long = 2147483647 + Seed
    Dim B As Long = 2
    Dim Z As Long = Seed
    Dim N As Long = -1
    Dim R As LongLong = 77
    Dim Target As Integer = 19
    Err.Clear
    R = A * B
    If R <> 77 Or Err.Number <> 6 Then CheckLong = 1: Exit Function
    A = -2147483648&
    R = A Mod N
    If R <> 0 Or Err.Number <> 6 Then CheckLong = 2: Exit Function
    R = 77
    Err.Clear
    R = A \ N
    If R <> 77 Or Err.Number <> 6 Then CheckLong = 3: Exit Function
    Err.Clear
    R = A * N
    If R <> 77 Or Err.Number <> 6 Then CheckLong = 4: Exit Function
    Err.Clear
    R = A \ Z
    If R <> 77 Or Err.Number <> 11 Then CheckLong = 5: Exit Function
    Err.Clear
    R = A Mod Z
    If R <> 77 Or Err.Number <> 11 Then CheckLong = 6: Exit Function
    A = 400
    B = 100
    Target = A * B
    If Target <> 19 Or Err.Number <> 6 Then CheckLong = 7: Exit Function
    A = -7
    B = 3
    R = A \ B
    If R <> -2 Or Err.Number <> 6 Then CheckLong = 8: Exit Function
    R = A Mod B
    If R <> -1 Or Err.Number <> 6 Then CheckLong = 9: Exit Function
End Function

' Checks LongLong limits, minimum remainder special case and final Long conversion.
Private Function CheckLongLong(ByVal Seed As Long) As Long
    Dim A As LongLong = 9223372036854775807^ + Seed
    Dim B As LongLong = 2
    Dim Z As LongLong = Seed
    Dim N As LongLong = -1
    Dim R As LongLong = 77
    Dim Target As Long = 19
    Err.Clear
    R = A * B
    If R <> 77 Or Err.Number <> 6 Then CheckLongLong = 1: Exit Function
    A = -9223372036854775808^
    R = A Mod N
    If R <> 0 Or Err.Number <> 6 Then CheckLongLong = 2: Exit Function
    R = 77
    Err.Clear
    R = A \ N
    If R <> 77 Or Err.Number <> 6 Then CheckLongLong = 3: Exit Function
    Err.Clear
    R = A * N
    If R <> 77 Or Err.Number <> 6 Then CheckLongLong = 4: Exit Function
    Err.Clear
    R = A \ Z
    If R <> 77 Or Err.Number <> 11 Then CheckLongLong = 5: Exit Function
    Err.Clear
    R = A Mod Z
    If R <> 77 Or Err.Number <> 11 Then CheckLongLong = 6: Exit Function
    A = 50000
    B = 50000
    Target = A * B
    If Target <> 19 Or Err.Number <> 6 Then CheckLongLong = 7: Exit Function
    A = -7
    B = 3
    R = A \ B
    If R <> -2 Or Err.Number <> 6 Then CheckLongLong = 8: Exit Function
    R = A Mod B
    If R <> -1 Or Err.Number <> 6 Then CheckLongLong = 9: Exit Function
End Function

' Checks eager exact-once evaluation and failure before later operands or assignment commit.
Private Function CheckEvaluation(ByVal Seed As Long) As Long
    Dim R As Long = 77
    Dim Z As Long = Seed
    Dim A As Long = 7
    Calls = 0
    Trace = 0
    R = Operand(7, 1) * Operand(3, 10)
    If R <> 21 Or Calls <> 2 Or Trace <> 11 Then CheckEvaluation = 1: Exit Function
    Calls = 0
    Trace = 0
    R = Operand(7, 1) \ Operand(3, 10)
    If R <> 2 Or Calls <> 2 Or Trace <> 11 Then CheckEvaluation = 2: Exit Function
    Calls = 0
    Trace = 0
    R = Operand(7, 1) Mod Operand(3, 10)
    If R <> 1 Or Calls <> 2 Or Trace <> 11 Then CheckEvaluation = 3: Exit Function
    Calls = 0
    Trace = 0
    R = 77
    Err.Clear
    R = BrokenOperand(1) * Operand(3, 10)
    If R <> 77 Or Calls <> 1 Or Trace <> 1 Or Err.Number <> 11 Then CheckEvaluation = 4: Exit Function
    Calls = 0
    Trace = 0
    Err.Clear
    R = Operand(7, 1) \ BrokenOperand(10)
    If R <> 77 Or Calls <> 2 Or Trace <> 11 Or Err.Number <> 11 Then CheckEvaluation = 5: Exit Function
    Calls = 0
    Trace = 0
    Err.Clear
    R = (Operand(7, 1) \ Z) * Operand(3, 10)
    If R <> 77 Or Calls <> 1 Or Trace <> 1 Or Err.Number <> 11 Then CheckEvaluation = 6: Exit Function
    Calls = 0
    Trace = 0
    Err.Clear
    R = Operand(7, 1) Mod Operand(Z, 10)
    If R <> 77 Or Calls <> 2 Or Trace <> 11 Or Err.Number <> 11 Then CheckEvaluation = 7: Exit Function
    R = Operand(7, 1) * Operand(3, 10)
    If R <> 21 Or Err.Number <> 11 Then CheckEvaluation = 8: Exit Function
    R = A * ChangeOperand(A)
    If R <> 21 Or A <> 99 Then CheckEvaluation = 9: Exit Function
    A = 7
    R = A \ ChangeOperand(A)
    If R <> 2 Or A <> 99 Then CheckEvaluation = 10: Exit Function
    A = 7
    R = A Mod ChangeOperand(A)
    If R <> 1 Or A <> 99 Then CheckEvaluation = 11: Exit Function
End Function

' Distinguishes fresh FAIL routing from a successful result with an unchanged stale Err.
Private Function CheckHandler(ByVal Zero As Long) As Long
    Dim A As LongLong = -9223372036854775808^
    Dim N As LongLong = -1
    Dim R As LongLong = 77
    On Error GoTo Caught
    R = A \ Zero
    CheckHandler = 1
    Exit Function
Caught:
    If R <> 77 Or Err.Number <> 11 Then CheckHandler = 2: Exit Function
    On Error GoTo Wrong
    R = A Mod N
    If R <> 0 Or Err.Number <> 11 Then CheckHandler = 3: Exit Function
    Exit Function
Wrong:
    CheckHandler = 4
End Function

' Reports the first failed independent family as the native exit status.
Public Function Main() As Long
    Dim Code As Long
    Code = CheckPrecedence(0)
    If Code <> 0 Then Main = 10 + Code: Exit Function
    Code = CheckByte(0)
    If Code <> 0 Then Main = 30 + Code: Exit Function
    Code = CheckInteger(0)
    If Code <> 0 Then Main = 50 + Code: Exit Function
    Code = CheckLong(0)
    If Code <> 0 Then Main = 70 + Code: Exit Function
    Code = CheckLongLong(0)
    If Code <> 0 Then Main = 90 + Code: Exit Function
    Code = CheckEvaluation(0)
    If Code <> 0 Then Main = 110 + Code: Exit Function
    Code = CheckHandler(0)
    If Code <> 0 Then Main = 130 + Code: Exit Function
    Code = CheckConstants()
    If Code <> 0 Then Main = 140 + Code: Exit Function
End Function
