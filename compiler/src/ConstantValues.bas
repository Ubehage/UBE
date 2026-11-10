UBE SOURCE 1 MODULE
Attribute UBE_Name = "ConstantValues"
' Checks exact typed integer constants without executing invalid arithmetic or changing Err.

' Returns the integer storage width, or zero for a noninteger type code.
Public Function IntegerWidth(ByVal TypeCode As Long) As Long
    If TypeCode = SyntaxTokens.KwByte Then IntegerWidth = 8
    If TypeCode = SyntaxTokens.KwInteger Then IntegerWidth = 16
    If TypeCode = SyntaxTokens.KwLong Then IntegerWidth = 32
    If TypeCode = SyntaxTokens.KwLongLong Then IntegerWidth = 64
End Function

' Promotes Byte operations to Integer and preserves other admitted scalar domains.
Public Function PromotedType(ByVal TypeCode As Long) As Long
    On Error GoTo Failed
    If TypeCode = SyntaxTokens.KwByte Then PromotedType = SyntaxTokens.KwInteger: Exit Function
    If TypeCode = SyntaxTokens.KwBoolean Or IntegerWidth(TypeCode) <> 0 Then PromotedType = TypeCode
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Selects a common operation domain; mixed Boolean/integer domains have no admitted type.
Public Function BinaryType(ByVal LeftType As Long, ByVal RightType As Long) As Long
    Dim A As Long
    Dim B As Long
    On Error GoTo Failed
    If LeftType = SyntaxTokens.KwBoolean And RightType = SyntaxTokens.KwBoolean Then BinaryType = SyntaxTokens.KwBoolean: Exit Function
    A = IntegerWidth(LeftType)
    B = IntegerWidth(RightType)
    If A = 0 Or B = 0 Then Exit Function
    BinaryType = SyntaxTokens.KwInteger
    If A = 32 Or B = 32 Then BinaryType = SyntaxTokens.KwLong
    If A = 64 Or B = 64 Then BinaryType = SyntaxTokens.KwLongLong
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Returns the minimum admitted numeric representation for a known scalar type.
Private Function Minimum(ByVal TypeCode As Long) As LongLong
    If TypeCode = SyntaxTokens.KwBoolean Then Minimum = -1
    If TypeCode = SyntaxTokens.KwInteger Then Minimum = -32768
    If TypeCode = SyntaxTokens.KwLong Then Minimum = -2147483648
    If TypeCode = SyntaxTokens.KwLongLong Then Minimum = -9223372036854775808^
End Function

' Returns the maximum admitted numeric representation for a known scalar type.
Private Function Maximum(ByVal TypeCode As Long) As LongLong
    If TypeCode = SyntaxTokens.KwByte Then Maximum = 255
    If TypeCode = SyntaxTokens.KwInteger Then Maximum = 32767
    If TypeCode = SyntaxTokens.KwLong Then Maximum = 2147483647
    If TypeCode = SyntaxTokens.KwLongLong Then Maximum = 9223372036854775807^
End Function

' Validates the complete source scalar representation before operating on it.
Private Function Fits(ByVal Value As LongLong, ByVal TypeCode As Long) As Boolean
    On Error GoTo Failed
    If TypeCode <> SyntaxTokens.KwBoolean And IntegerWidth(TypeCode) = 0 Then Exit Function
    Fits = Value >= Minimum(TypeCode) And Value <= Maximum(TypeCode)
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Checks a scalar conversion, preserving the output and Err for an ordinary rejected constant.
Public Function TryConvert(ByVal InputValue As LongLong, ByVal SourceType As Long, ByVal DestinationType As Long, ByRef Value As LongLong, ByRef Reason As Long) As Boolean
    Dim Candidate As LongLong
    On Error GoTo Failed
    Reason = 3
    If Not Fits(InputValue, SourceType) Then Exit Function
    If DestinationType <> SyntaxTokens.KwBoolean And IntegerWidth(DestinationType) = 0 Then Exit Function
    Candidate = InputValue
    If DestinationType = SyntaxTokens.KwBoolean Then
        Candidate = 0
        If InputValue <> 0 Then Candidate = -1
    Else
        Reason = 2
        If Not Fits(Candidate, DestinationType) Then Exit Function
    End If
    Value = Candidate
    Reason = 0
    TryConvert = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Decodes decimal magnitude negatively so signed minimum never needs a positive intermediate.
Private Function DecimalValue(ByRef Source() As Byte, ByVal Start As Long, ByVal Finish As Long, ByVal Negated As Boolean, ByRef Value As LongLong, ByRef Reason As Long) As Boolean
    Dim Accumulator As LongLong
    Dim Twice As LongLong
    Dim Eight As LongLong
    Dim Digit As LongLong
    Dim LastDigit As LongLong = 7
    Dim Cursor As Long
    On Error GoTo Failed
    Reason = 1
    If Start >= Finish Then Exit Function
    Cursor = Start
    Do While Cursor < Finish
        Digit = Source(Cursor)
        If Digit < 48 Or Digit > 57 Then Exit Function
        Cursor = Cursor + 1
    Loop
    If Negated Then LastDigit = 8
    Do While Start < Finish
        Digit = Source(Start)
        Digit = Digit - 48
        Reason = 2
        If Accumulator < -922337203685477580^ Then Exit Function
        If Accumulator = -922337203685477580^ Then
            If Digit > LastDigit Then Exit Function
        End If
        Twice = Accumulator + Accumulator
        Eight = Twice + Twice
        Eight = Eight + Eight
        Accumulator = Eight + Twice
        Accumulator = Accumulator - Digit
        Reason = 1
        Start = Start + 1
    Loop
    If Not Negated Then Accumulator = -Accumulator
    Value = Accumulator
    Reason = 0
    DecimalValue = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Parses one retained literal using authoritative suffixes and a widening destination context.
Public Function TryLiteral(ByRef Source() As Byte, ByRef Token As SourceScanner.SourceToken, ByVal ExpectedType As Long, ByVal Negated As Boolean, ByRef Value As LongLong, ByRef TypeCode As Long, ByRef Reason As Long) As Boolean
    Dim Size As Long
    Dim Finish As Long
    Dim Suffix As Long
    Dim Selected As Long
    Dim Candidate As LongLong
    Dim Probe As Long
    On Error GoTo Failed
    Reason = 3
    Size = BufferPrimitives.ByteStorageLength(Source)
    If Size > 0 Then Probe = Source(0): Probe = Source(Size - 1)
    If Token.ByteStart < 0 Or Token.ByteLength <= 0 Then Exit Function
    If Token.ByteStart > Size Then Exit Function
    If Token.ByteLength > Size - Token.ByteStart Then Exit Function
    Reason = 1
    If Token.Kind <> SourceScanner.NumberToken Then Exit Function
    Finish = Token.ByteStart + Token.ByteLength
    Suffix = Source(Finish - 1)
    If Suffix = 37 Then Selected = SyntaxTokens.KwInteger
    If Suffix = 38 Then Selected = SyntaxTokens.KwLong
    If Suffix = 94 Then Selected = SyntaxTokens.KwLongLong
    If Selected <> 0 Then Finish = Finish - 1
    If Not DecimalValue(Source, Token.ByteStart, Finish, Negated, Candidate, Reason) Then Exit Function
    If Selected = 0 Then
        Selected = ExpectedType
        If IntegerWidth(Selected) = 0 Then Selected = SyntaxTokens.KwLong
        If Selected = SyntaxTokens.KwByte Then
            If Not Fits(Candidate, Selected) Then Selected = SyntaxTokens.KwInteger
        End If
        If Selected = SyntaxTokens.KwInteger Then
            If Not Fits(Candidate, Selected) Then Selected = SyntaxTokens.KwLong
        End If
        If Selected = SyntaxTokens.KwLong Then
            If Not Fits(Candidate, Selected) Then Selected = SyntaxTokens.KwLongLong
        End If
    End If
    Reason = 2
    If Not Fits(Candidate, Selected) Then Exit Function
    Value = Candidate
    TypeCode = Selected
    Reason = 0
    TryLiteral = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Checks unary operations in their promoted type, including signed-minimum negation.
Public Function TryUnary(ByVal Operator As Long, ByVal InputValue As LongLong, ByVal InputType As Long, ByRef Value As LongLong, ByRef TypeCode As Long, ByRef Reason As Long) As Boolean
    Dim Selected As Long
    Dim Candidate As LongLong
    On Error GoTo Failed
    Reason = 3
    If Not Fits(InputValue, InputType) Then Exit Function
    Selected = PromotedType(InputType)
    Reason = 1
    If Operator = SyntaxTokens.KwNot Then
        Candidate = Not InputValue
    ElseIf Operator = SyntaxTokens.SymPlus Or Operator = SyntaxTokens.SymMinus Then
        If Selected = SyntaxTokens.KwBoolean Then Exit Function
        Candidate = InputValue
        If Operator = SyntaxTokens.SymMinus Then
            Reason = 2
            If InputValue = Minimum(Selected) Then Exit Function
            Candidate = -InputValue
        End If
    Else
        Exit Function
    End If
    Value = Candidate
    TypeCode = Selected
    Reason = 0
    TryUnary = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Folds admitted binary operations after checking overflow in the selected operation type.
Public Function TryBinary(ByVal Operator As Long, ByVal LeftValue As LongLong, ByVal LeftType As Long, ByVal RightValue As LongLong, ByVal RightType As Long, ByRef Value As LongLong, ByRef TypeCode As Long, ByRef Reason As Long) As Boolean
    Dim Selected As Long
    Dim Candidate As LongLong
    Dim Low As LongLong
    Dim High As LongLong
    Dim Truth As Boolean
    Dim Comparison As Boolean
    On Error GoTo Failed
    Reason = 3
    If Not Fits(LeftValue, LeftType) Or Not Fits(RightValue, RightType) Then Exit Function
    Reason = 1
    Selected = BinaryType(LeftType, RightType)
    If Selected = 0 Then Exit Function
    If Selected = SyntaxTokens.KwBoolean Then
        If Operator <> SyntaxTokens.KwAnd And Operator <> SyntaxTokens.KwOr And Operator <> SyntaxTokens.SymEqual And Operator <> SyntaxTokens.SymNotEqual Then Exit Function
    End If
    Low = Minimum(Selected)
    High = Maximum(Selected)
    Reason = 2
    If Operator = SyntaxTokens.SymPlus Then
        If RightValue > 0 Then
            If LeftValue > High - RightValue Then Exit Function
        ElseIf RightValue < 0 Then
            If LeftValue < Low - RightValue Then Exit Function
        End If
        Candidate = LeftValue + RightValue
    ElseIf Operator = SyntaxTokens.SymMinus Then
        If RightValue > 0 Then
            If LeftValue < Low + RightValue Then Exit Function
        ElseIf RightValue < 0 Then
            If LeftValue > High + RightValue Then Exit Function
        End If
        Candidate = LeftValue - RightValue
    ElseIf Operator = SyntaxTokens.KwAnd Then
        Candidate = LeftValue And RightValue
    ElseIf Operator = SyntaxTokens.KwOr Then
        Candidate = LeftValue Or RightValue
    Else
        Comparison = True
        If Operator = SyntaxTokens.SymEqual Then
            Truth = LeftValue = RightValue
        ElseIf Operator = SyntaxTokens.SymNotEqual Then
            Truth = LeftValue <> RightValue
        ElseIf Operator = SyntaxTokens.SymLess Then
            Truth = LeftValue < RightValue
        ElseIf Operator = SyntaxTokens.SymGreater Then
            Truth = LeftValue > RightValue
        ElseIf Operator = SyntaxTokens.SymLessEqual Then
            Truth = LeftValue <= RightValue
        ElseIf Operator = SyntaxTokens.SymGreaterEqual Then
            Truth = LeftValue >= RightValue
        Else
            Reason = 1
            Exit Function
        End If
        If Truth Then Candidate = -1
    End If
    If Comparison Then Selected = SyntaxTokens.KwBoolean
    Value = Candidate
    TypeCode = Selected
    Reason = 0
    TryBinary = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function
