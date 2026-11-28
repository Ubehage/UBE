UBE SOURCE 1 MODULE
Attribute UBE_Name = "BinaryFloatText"
' Shortest invariant decimal coefficients, checked against exact IEEE intervals.

' Compares Coefficient * 10^DecimalExponent with an exact decimal expansion.
Private Function CompareDecimal(ByVal Coefficient As LongLong, ByVal DecimalExponent As Long, ByRef Digits() As Byte, ByVal DigitCount As Long, ByVal Scale As Long) As Long
    Dim Candidate(0 To 19) As Byte
    Dim Count As Long
    Dim Index As Long
    Dim Other As Long
    Dim Expected As Long
    Do While Coefficient <> 0
        Candidate(Count) = Coefficient Mod 10
        Coefficient = Coefficient \ 10
        Count = Count + 1
    Loop
    If Count + DecimalExponent < DigitCount + Scale Then CompareDecimal = -1: Exit Function
    If Count + DecimalExponent > DigitCount + Scale Then CompareDecimal = 1: Exit Function
    Index = Count - 1
    Other = DigitCount - 1
    Do While Index >= 0 Or Other >= 0
        Expected = 0
        If Other >= 0 Then Expected = Digits(Other)
        Coefficient = 0
        If Index >= 0 Then Coefficient = Candidate(Index)
        If Coefficient < Expected Then CompareDecimal = -1: Exit Function
        If Coefficient > Expected Then CompareDecimal = 1: Exit Function
        Index = Index - 1
        Other = Other - 1
    Loop
End Function

Private Sub Render(ByRef Bytes() As Byte, ByRef Used As Long, ByVal Negative As Boolean, ByVal Coefficient As LongLong, ByVal DecimalExponent As Long)
    Dim Digits(0 To 19) As Byte
    Dim Count As Long
    Dim Index As Long
    Dim ScientificExponent As Long
    Dim ScientificLength As Long
    Dim FixedLength As Long
    Dim Position As Long
    Dim AbsoluteExponent As Long
    On Error GoTo Failed
    Do While Coefficient Mod 10 = 0 And Coefficient <> 0
        Coefficient = Coefficient \ 10
        DecimalExponent = DecimalExponent + 1
    Loop
    If Not ByteText.TryAppendInteger(Digits, Count, Coefficient) Then Err.Raise Err.Number
    ScientificExponent = DecimalExponent + Count - 1
    ScientificLength = Count
    If Count > 1 Then ScientificLength = ScientificLength + 1
    If ScientificExponent <> 0 Then
        ScientificLength = ScientificLength + 2
        AbsoluteExponent = ScientificExponent
        If AbsoluteExponent < 0 Then ScientificLength = ScientificLength + 1: AbsoluteExponent = -AbsoluteExponent
        Do While AbsoluteExponent >= 10
            ScientificLength = ScientificLength + 1
            AbsoluteExponent = AbsoluteExponent \ 10
        Loop
    End If
    Position = Count + DecimalExponent
    FixedLength = Count
    If DecimalExponent >= 0 Then FixedLength = Position
    If DecimalExponent < 0 Then
        FixedLength = Count + 1
        If Position <= 0 Then FixedLength = 2 - DecimalExponent
    End If
    Used = 0
    If Negative Then Bytes(Used) = 45: Used = Used + 1
    If FixedLength <= ScientificLength Then
        If Position <= 0 Then
            Bytes(Used) = 48: Used = Used + 1
            Bytes(Used) = 46: Used = Used + 1
            Do While Position < 0
                Bytes(Used) = 48: Used = Used + 1
                Position = Position + 1
            Loop
        End If
        Do While Index < Count
            If Index = Position And Position > 0 Then Bytes(Used) = 46: Used = Used + 1
            Bytes(Used) = Digits(Index): Used = Used + 1
            Index = Index + 1
        Loop
        Do While Index < Position
            Bytes(Used) = 48: Used = Used + 1
            Index = Index + 1
        Loop
    Else
        Bytes(Used) = Digits(0): Used = Used + 1
        Index = 1
        If Count > 1 Then Bytes(Used) = 46: Used = Used + 1
        Do While Index < Count
            Bytes(Used) = Digits(Index): Used = Used + 1
            Index = Index + 1
        Loop
        If ScientificExponent <> 0 Then
            Bytes(Used) = 69: Used = Used + 1
            If Not ByteText.TryAppendInteger(Bytes, Used, ScientificExponent) Then Err.Raise Err.Number
        End If
    End If
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

Public Function TryAppend(ByRef Destination() As Byte, ByRef Used As Long, ByVal Bits As LongLong, ByVal BitWidth As Long) As Boolean
    Dim Negative As Boolean
    Dim Mantissa As LongLong
    Dim Exponent As Long
    Dim Kind As Long
    Dim Digits() As Byte
    Dim LowerDigits() As Byte
    Dim UpperDigits() As Byte
    Dim Scratch(0 To 47) As Byte
    Dim DigitCount As Long
    Dim Scale As Long
    Dim Count As Long
    Dim Precision As Long
    Dim Limit As Long = 17
    Dim Index As Long
    Dim Coefficient As LongLong
    Dim Rounded As LongLong
    Dim Candidate As LongLong
    Dim DecimalExponent As Long
    Dim RoundUp As Boolean
    Dim Tail As Boolean
    Dim Attempt As Long
    Dim Accepted As Boolean
    Dim Capacity As Long
    Dim LowerCount As Long
    Dim UpperCount As Long
    Dim LowerScale As Long
    Dim UpperScale As Long
    Dim Unit As LongLong = 4503599627370496&&
    Dim MinimumExponent As Long = -1074
    Dim MaximumExponent As Long = 971
    Dim LowerMantissa As LongLong
    Dim LowerExponent As Long
    Dim LowerClosed As Boolean
    Dim UpperClosed As Boolean
    Dim Order As Long
    Dim Endpoint As Byte
    On Error GoTo Failed
    Capacity = BufferPrimitives.ByteStorageLength(Destination)
    If Used < 0 Then TryAppend = FilePrimitives.SetError(5): Exit Function
    If Used > Capacity Then TryAppend = FilePrimitives.SetError(9): Exit Function
    If Capacity > 0 Then Endpoint = Destination(0): Endpoint = Destination(Capacity - 1)
    If Not BinaryFloatValues.TryDecode(Bits, BitWidth, Negative, Mantissa, Exponent, Kind) Then Exit Function
    If Kind <> 0 Then TryAppend = FilePrimitives.SetError(6): Exit Function
    If Mantissa = 0 Then
        If Negative Then Scratch(0) = 45: Count = 1
        Scratch(Count) = 48: Count = Count + 1
    Else
        If Not BufferPrimitives.TryResizeBytes(Digits, 1100, False) Then Exit Function
        If Not BinaryFloat.TryDecimalDigits(Mantissa, Exponent, Digits, DigitCount, Scale) Then Exit Function
        If Not BufferPrimitives.TryResizeBytes(LowerDigits, 1100, False) Then Exit Function
        If Not BufferPrimitives.TryResizeBytes(UpperDigits, 1100, False) Then Exit Function
        If BitWidth = 32 Then Limit = 9: Unit = 8388608: MinimumExponent = -149: MaximumExponent = 104
        LowerMantissa = Mantissa * 2 - 1
        LowerExponent = Exponent - 1
        If Mantissa = Unit And Exponent > MinimumExponent Then LowerMantissa = Mantissa * 4 - 1: LowerExponent = Exponent - 2
        If Not BinaryFloat.TryDecimalDigits(LowerMantissa, LowerExponent, LowerDigits, LowerCount, LowerScale) Then Exit Function
        LowerClosed = Mantissa Mod 2 = 0
        UpperClosed = LowerClosed
        If Exponent = MaximumExponent And Mantissa = Unit * 2 - 1 Then
            ' Checked text conversion rejects every mathematical value above maxfinite.
            If Not BinaryFloat.TryDecimalDigits(Mantissa, Exponent, UpperDigits, UpperCount, UpperScale) Then Exit Function
            UpperClosed = True
        Else
            If Not BinaryFloat.TryDecimalDigits(Mantissa * 2 + 1, Exponent - 1, UpperDigits, UpperCount, UpperScale) Then Exit Function
        End If
        Precision = 1
        Do While Precision <= Limit And Not Accepted
            Index = DigitCount - Precision
            Coefficient = Coefficient * 10
            If Index >= 0 Then Coefficient = Coefficient + Digits(Index)
            DecimalExponent = DigitCount + Scale - Precision
            Rounded = Coefficient
            RoundUp = False
            If Index > 0 Then
                Tail = False
                Attempt = Index - 2
                Do While Attempt >= 0
                    If Digits(Attempt) <> 0 Then Tail = True
                    Attempt = Attempt - 1
                Loop
                If Digits(Index - 1) > 5 Then RoundUp = True
                If Digits(Index - 1) = 5 Then RoundUp = Tail Or Coefficient Mod 2 <> 0
            End If
            If RoundUp Then Rounded = Rounded + 1
            Attempt = 0
            Do While Attempt < 2 And Not Accepted
                Candidate = Rounded
                If Attempt = 1 Then
                    Candidate = Coefficient + 1
                    If RoundUp Then Candidate = Coefficient
                End If
                Order = CompareDecimal(Candidate, DecimalExponent, LowerDigits, LowerCount, LowerScale)
                Accepted = Order > 0 Or (Order = 0 And LowerClosed)
                If Accepted Then
                    Order = CompareDecimal(Candidate, DecimalExponent, UpperDigits, UpperCount, UpperScale)
                    Accepted = Order < 0 Or (Order = 0 And UpperClosed)
                End If
                If Accepted Then Call Render(Scratch, Count, Negative, Candidate, DecimalExponent)
                Attempt = Attempt + 1
            Loop
            Precision = Precision + 1
        Loop
        If Not Accepted Then TryAppend = FilePrimitives.SetError(13): Exit Function
    End If
    If Count > Capacity - Used Then TryAppend = FilePrimitives.SetError(9): Exit Function
    If Not BufferPrimitives.CopyByteRange(Scratch, 0, Destination, Used, Count) Then Exit Function
    Used = Used + Count
    TryAppend = True
    Exit Function
Failed:
    TryAppend = False
End Function
