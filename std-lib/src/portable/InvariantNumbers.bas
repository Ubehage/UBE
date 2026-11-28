UBE SOURCE 1 MODULE
Attribute UBE_Name = "InvariantNumbers"
' Parses complete invariant numeric text without floating point or host locale state.

Private Type NumberText
    First As Long
    Last As Long
    Radix As Long
    Negative As Boolean
    Nonzero As Boolean
    LeadingZeros As Long
    IntegerDigits As Long
    Exponent As LongLong
End Type

' Records a recoverable conversion error without raising a language FAIL.
Private Intrinsic Function RecordError(ByVal Number As Long) As Boolean
Attribute RecordError.UBE_Primitive = "Error.Set"
End Function

' Uses the Unicode White_Space property, independent of the target locale.
Private Function WhiteSpace(ByVal Scalar As Long) As Boolean
    If Scalar >= 9 And Scalar <= 13 Then WhiteSpace = True: Exit Function
    If Scalar = 32 Or Scalar = 133 Or Scalar = 160 Or Scalar = 5760 Then WhiteSpace = True: Exit Function
    If Scalar >= 8192 And Scalar <= 8202 Then WhiteSpace = True: Exit Function
    WhiteSpace = Scalar = 8232 Or Scalar = 8233 Or Scalar = 8239 Or Scalar = 8287 Or Scalar = 12288
End Function

' Validates the counted UTF-8 span and removes only surrounding whitespace.
Private Function TrimSpan(ByRef Bytes() As Byte, ByVal Offset As Long, ByVal Count As Long, ByRef First As Long, ByRef Last As Long) As Boolean
    Dim Capacity As Long
    Dim Limit As Long
    Dim Position As Long
    Dim Scalar As Long
    Dim ByteWidth As Long
    Dim Seen As Boolean
    Capacity = BufferPrimitives.ByteStorageLength(Bytes)
    If Offset < 0 Or Count < 0 Or Offset > Capacity Then TrimSpan = RecordError(5): Exit Function
    If Count > Capacity - Offset Then TrimSpan = RecordError(5): Exit Function
    Limit = Offset + Count
    Position = Offset
    Do While Position < Limit
        If Not Utf8.TryDecodeScalar(Bytes, Position, Limit, Scalar, ByteWidth) Then TrimSpan = RecordError(13): Exit Function
        If Not WhiteSpace(Scalar) Then
            If Not Seen Then First = Position
            Seen = True
            Last = Position + ByteWidth
        End If
        Position = Position + ByteWidth
    Loop
    If Not Seen Then TrimSpan = RecordError(13): Exit Function
    TrimSpan = True
End Function

' Classifies one ASCII digit; other scalars cannot occur in invariant numeric syntax.
Private Function Digit(ByVal Code As Long) As Long
    Digit = -1
    If Code >= 48 And Code <= 57 Then Digit = Code - 48: Exit Function
    If Code >= 65 And Code <= 70 Then Digit = Code - 55: Exit Function
    If Code >= 97 And Code <= 102 Then Digit = Code - 87
End Function

' Validates every character before conversion; exponent saturation cannot hide a bad suffix.
Private Function Describe(ByRef Bytes() As Byte, ByVal First As Long, ByVal Last As Long, ByRef Description As NumberText) As Boolean
    Dim Position As Long = First
    Dim Code As Long
    Dim Value As Long
    Dim Digits As Long
    Dim PointSeen As Boolean
    Dim ExponentNegative As Boolean
    Dim ExponentLimit As LongLong = Last - First
    ' Covers the full binary64 subnormal range as well as integer conversion.
    ExponentLimit = ExponentLimit + 1200
    Description.Radix = 10
    Code = Bytes(Position)
    If Code = 43 Or Code = 45 Then
        Description.Negative = Code = 45
        Position = Position + 1
    End If
    If Position = Last Then Describe = RecordError(13): Exit Function
    If Bytes(Position) = 38 Then
        Position = Position + 1
        If Position = Last Then Describe = RecordError(13): Exit Function
        Code = Bytes(Position)
        If Code = 72 Or Code = 104 Then Description.Radix = 16
        If Code = 79 Or Code = 111 Then Description.Radix = 8
        If Description.Radix = 10 Then Describe = RecordError(13): Exit Function
        Position = Position + 1
    End If
    Description.First = Position
    Do While Position < Last
        Code = Bytes(Position)
        Value = Digit(Code)
        If Description.Radix = 10 And (Code = 69 Or Code = 101) Then Exit Do
        If Description.Radix = 10 And Code = 46 Then
            If PointSeen Then Describe = RecordError(13): Exit Function
            PointSeen = True
        Else
            If Value < 0 Or Value >= Description.Radix Then Describe = RecordError(13): Exit Function
            Digits = Digits + 1
            If Not PointSeen Then Description.IntegerDigits = Description.IntegerDigits + 1
            If Value <> 0 Then Description.Nonzero = True
            If Not Description.Nonzero Then Description.LeadingZeros = Description.LeadingZeros + 1
        End If
        Position = Position + 1
    Loop
    Description.Last = Position
    If Digits = 0 Then Describe = RecordError(13): Exit Function
    If Position < Last Then
        Position = Position + 1
        If Position = Last Then Describe = RecordError(13): Exit Function
        Code = Bytes(Position)
        If Code = 43 Or Code = 45 Then
            ExponentNegative = Code = 45
            Position = Position + 1
        End If
        If Position = Last Then Describe = RecordError(13): Exit Function
        Do While Position < Last
            Value = Bytes(Position) - 48
            If Value < 0 Or Value > 9 Then Describe = RecordError(13): Exit Function
            If Description.Exponent < ExponentLimit Then
                Description.Exponent = (Description.Exponent * 10) + Value
                If Description.Exponent > ExponentLimit Then Description.Exponent = ExponentLimit
            End If
            Position = Position + 1
        Loop
        If ExponentNegative Then Description.Exponent = -Description.Exponent
    End If
    Describe = True
End Function

' Parses IEEE bit encodings through the same complete invariant scanner.
Public Function TryParseFloating(ByRef Bytes() As Byte, ByVal Offset As Long, ByVal Count As Long, ByVal BitWidth As Long, ByRef Value As LongLong) As Boolean
    Dim First As Long
    Dim Last As Long
    Dim Description As NumberText
    On Error GoTo Failed
    If BitWidth <> 32 And BitWidth <> 64 Then TryParseFloating = RecordError(5): Exit Function
    If Not TrimSpan(Bytes, Offset, Count, First, Last) Then Exit Function
    If Not Describe(Bytes, First, Last, Description) Then Exit Function
    If Description.Radix <> 10 Then TryParseFloating = RecordError(13): Exit Function
    TryParseFloating = BinaryFloat.TryParseDecimal(Bytes, Description.First, Description.Last, Description.LeadingZeros, Description.IntegerDigits, Description.Exponent, Description.Negative, Description.Nonzero, BitWidth, Value)
    Exit Function
Failed:
    TryParseFloating = False
End Function

' Accumulates a magnitude negatively so the full signed LongLong range is representable.
Private Function AppendDigit(ByRef Accumulator As LongLong, ByVal Value As Long, ByVal Radix As Long) As Boolean
    Dim Threshold As LongLong = -9223372036854775808&&
    Threshold = (Threshold + Value) \ Radix
    If Accumulator < Threshold Then AppendDigit = RecordError(6): Exit Function
    Accumulator = (Accumulator * Radix) - Value
    AppendDigit = True
End Function

' Converts an already validated decimal to its exact nearest integer, ties to even.
Private Function RoundedDecimal(ByRef Bytes() As Byte, ByRef Description As NumberText, ByRef Result As LongLong) As Boolean
    Dim IntegerPlaces As LongLong = Description.IntegerDigits
    Dim Position As Long = Description.First
    Dim Ordinal As Long
    Dim Value As Long
    Dim RoundDigit As Long
    Dim Sticky As Boolean
    Dim Magnitude As LongLong
    IntegerPlaces = IntegerPlaces - Description.LeadingZeros + Description.Exponent
    If Not Description.Nonzero Or IntegerPlaces < 0 Then Result = 0: RoundedDecimal = True: Exit Function
    If IntegerPlaces > 19 Then RoundedDecimal = RecordError(6): Exit Function
    Do While Position < Description.Last
        If Bytes(Position) <> 46 Then
            Value = Bytes(Position) - 48
            Ordinal = Ordinal + 1
            If Ordinal > Description.LeadingZeros Then
                If Ordinal - Description.LeadingZeros <= IntegerPlaces Then
                    If Not AppendDigit(Magnitude, Value, 10) Then Exit Function
                ElseIf Ordinal - Description.LeadingZeros = IntegerPlaces + 1 Then
                    RoundDigit = Value
                ElseIf Value <> 0 Then
                    Sticky = True
                End If
            End If
        End If
        Position = Position + 1
    Loop
    Ordinal = Ordinal - Description.LeadingZeros
    Do While Ordinal < IntegerPlaces
        If Not AppendDigit(Magnitude, 0, 10) Then Exit Function
        Ordinal = Ordinal + 1
    Loop
    If RoundDigit > 5 Or (RoundDigit = 5 And (Sticky Or Magnitude Mod 2 <> 0)) Then
        If Magnitude = -9223372036854775808&& Then RoundedDecimal = RecordError(6): Exit Function
        Magnitude = Magnitude - 1
    End If
    Result = Magnitude
    RoundedDecimal = True
End Function

' Parses one complete numeric value and publishes only after rounding and destination range checks.
Public Function TryParseInteger(ByRef Bytes() As Byte, ByVal Offset As Long, ByVal Count As Long, ByVal Minimum As LongLong, ByVal Maximum As LongLong, ByRef Value As LongLong) As Boolean
    Dim First As Long
    Dim Last As Long
    Dim Description As NumberText
    Dim Result As LongLong
    Dim Position As Long
    On Error GoTo Failed
    If Minimum > Maximum Then TryParseInteger = RecordError(5): Exit Function
    If Not TrimSpan(Bytes, Offset, Count, First, Last) Then Exit Function
    If Not Describe(Bytes, First, Last, Description) Then Exit Function
    If Description.Radix = 10 Then
        If Not RoundedDecimal(Bytes, Description, Result) Then Exit Function
    Else
        Position = Description.First
        Do While Position < Description.Last
            If Not AppendDigit(Result, Digit(Bytes(Position)), Description.Radix) Then Exit Function
            Position = Position + 1
        Loop
    End If
    If Not Description.Negative Then
        If Result = -9223372036854775808&& Then TryParseInteger = RecordError(6): Exit Function
        Result = -Result
    End If
    If Result < Minimum Or Result > Maximum Then TryParseInteger = RecordError(6): Exit Function
    Value = Result
    TryParseInteger = True
    Exit Function
Failed:
    TryParseInteger = False
End Function

' Folds ASCII only: the accepted Boolean words have no locale-sensitive letters.
Private Function LowerAscii(ByVal Code As Long) As Long
    LowerAscii = Code
    If Code >= 65 And Code <= 90 Then LowerAscii = Code + 32
End Function

' Numeric Boolean conversion tests exact mathematical zero, without integer rounding or overflow.
Public Function TryParseBoolean(ByRef Bytes() As Byte, ByVal Offset As Long, ByVal Count As Long, ByRef Value As Boolean) As Boolean
    Dim First As Long
    Dim Last As Long
    Dim Description As NumberText
    On Error GoTo Failed
    If Not TrimSpan(Bytes, Offset, Count, First, Last) Then Exit Function
    If Last - First = 4 Then
        If LowerAscii(Bytes(First)) = 116 And LowerAscii(Bytes(First + 1)) = 114 And LowerAscii(Bytes(First + 2)) = 117 And LowerAscii(Bytes(First + 3)) = 101 Then
            Value = True: TryParseBoolean = True: Exit Function
        End If
    End If
    If Last - First = 5 Then
        If LowerAscii(Bytes(First)) = 102 And LowerAscii(Bytes(First + 1)) = 97 And LowerAscii(Bytes(First + 2)) = 108 And LowerAscii(Bytes(First + 3)) = 115 And LowerAscii(Bytes(First + 4)) = 101 Then
            Value = False: TryParseBoolean = True: Exit Function
        End If
    End If
    If Not Describe(Bytes, First, Last, Description) Then Exit Function
    Value = Description.Nonzero
    TryParseBoolean = True
    Exit Function
Failed:
    TryParseBoolean = False
End Function
