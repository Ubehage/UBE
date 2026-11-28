UBE SOURCE 1 MODULE
Attribute UBE_Name = "BinaryFloat"
' Exact invariant decimal conversion using integer IEEE encodings only.

Public Function TryParse(ByRef Bytes() As Byte, ByVal Start As Long, ByVal Count As Long, ByVal BitWidth As Long, ByRef Bits As LongLong) As Boolean
    TryParse = InvariantNumbers.TryParseFloating(Bytes, Start, Count, BitWidth, Bits)
End Function

' Decodes a nonnegative finite IEEE encoding as Mantissa * 2 ^ Exponent.
Private Sub Decode(ByVal Bits As LongLong, ByVal BitWidth As Long, ByRef Mantissa As LongLong, ByRef Exponent As Long)
    Dim Unit As LongLong = 4503599627370496&&
    Dim Bias As Long = 1075
    Dim Field As Long
    If BitWidth = 32 Then Unit = 8388608: Bias = 150
    Field = Bits \ Unit
    Mantissa = Bits Mod Unit
    If Field = 0 Then
        Exponent = 1 - Bias
    Else
        Mantissa = Mantissa + Unit
        Exponent = Field - Bias
    End If
End Sub

' Expands an IEEE finite value/midpoint into reverse decimal digits and scale.
' Caller owns at least 1100 scratch bytes; this bound covers every binary64 dyadic.
Public Function TryDecimalDigits(ByVal Mantissa As LongLong, ByVal Exponent As Long, ByRef Digits() As Byte, ByRef Used As Long, ByRef Scale As Long) As Boolean
    Dim CandidateUsed As Long
    Dim CandidateScale As Long
    Dim Factor As Long = 2
    Dim Count As Long = Exponent
    Dim Index As Long
    Dim Carry As Long
    Dim Product As Long
    If Mantissa < 0 Or Exponent < -1075 Or Exponent > 1024 Then TryDecimalDigits = FilePrimitives.SetError(5): Exit Function
    If BufferPrimitives.ByteStorageLength(Digits) < 1100 Then TryDecimalDigits = FilePrimitives.SetError(9): Exit Function
    If Mantissa = 0 Then Digits(0) = 0: CandidateUsed = 1
    Do While Mantissa <> 0
        Digits(CandidateUsed) = Mantissa Mod 10
        Mantissa = Mantissa \ 10
        CandidateUsed = CandidateUsed + 1
    Loop
    If Exponent < 0 Then Factor = 5: Count = -Exponent: CandidateScale = Exponent
    Do While Count > 0
        Index = 0
        Carry = 0
        Do While Index < CandidateUsed
            Product = Digits(Index) * Factor + Carry
            Digits(Index) = Product Mod 10
            Carry = Product \ 10
            Index = Index + 1
        Loop
        If Carry <> 0 Then Digits(CandidateUsed) = Carry: CandidateUsed = CandidateUsed + 1
        Count = Count - 1
    Loop
    Used = CandidateUsed
    Scale = CandidateScale
    TryDecimalDigits = True
End Function

' Compares arbitrary-length decimal input with an exact dyadic expansion.
Private Function CompareDyadic(ByRef Bytes() As Byte, ByVal First As Long, ByVal Last As Long, ByVal LeadingZeros As Long, ByVal Places As LongLong, ByVal Mantissa As LongLong, ByVal Exponent As Long, ByRef Digits() As Byte) As Long
    Dim Used As Long
    Dim Scale As Long
    Dim Index As Long
    Dim Position As Long = First
    Dim Skipped As Long
    Dim InputDigit As Long
    Dim Expected As Long
    If Mantissa = 0 Then CompareDyadic = 1: Exit Function
    If Not TryDecimalDigits(Mantissa, Exponent, Digits, Used, Scale) Then Err.Raise Err.Number
    If Places < Used + Scale Then CompareDyadic = -1: Exit Function
    If Places > Used + Scale Then CompareDyadic = 1: Exit Function
    Index = Used - 1
    Do While Position < Last
        If Bytes(Position) <> 46 Then
            If Skipped < LeadingZeros Then
                Skipped = Skipped + 1
            Else
                InputDigit = Bytes(Position) - 48
                Expected = 0
                If Index >= 0 Then Expected = Digits(Index)
                If InputDigit < Expected Then CompareDyadic = -1: Exit Function
                If InputDigit > Expected Then CompareDyadic = 1: Exit Function
                Index = Index - 1
            End If
        End If
        Position = Position + 1
    Loop
    Do While Index >= 0
        If Digits(Index) <> 0 Then CompareDyadic = -1: Exit Function
        Index = Index - 1
    Loop
End Function

' Called only after complete syntax validation by InvariantNumbers.
Public Function TryParseDecimal(ByRef Bytes() As Byte, ByVal First As Long, ByVal Last As Long, ByVal LeadingZeros As Long, ByVal IntegerDigits As Long, ByVal DecimalExponent As LongLong, ByVal Negative As Boolean, ByVal Nonzero As Boolean, ByVal BitWidth As Long, ByRef Bits As LongLong) As Boolean
    Dim Low As LongLong
    Dim High As LongLong = 9218868437227405311&&
    Dim Middle As LongLong
    Dim Mantissa As LongLong
    Dim Exponent As Long
    Dim Order As Long
    Dim Places As LongLong = IntegerDigits
    Dim Result As LongLong
    Dim Digits() As Byte
    On Error GoTo Failed
    If BitWidth <> 32 And BitWidth <> 64 Then TryParseDecimal = FilePrimitives.SetError(5): Exit Function
    If BitWidth = 32 Then High = 2139095039
    Places = Places - LeadingZeros + DecimalExponent
    If Nonzero Then
        If Not BufferPrimitives.TryResizeBytes(Digits, 1100, False) Then Exit Function
        ' Conversions check the mathematical range before nearest/even rounding.
        Call Decode(High, BitWidth, Mantissa, Exponent)
        If CompareDyadic(Bytes, First, Last, LeadingZeros, Places, Mantissa, Exponent, Digits) > 0 Then TryParseDecimal = FilePrimitives.SetError(6): Exit Function
        Do While Low < High
            Middle = Low + (High - Low) \ 2 + 1
            Call Decode(Middle, BitWidth, Mantissa, Exponent)
            Order = CompareDyadic(Bytes, First, Last, LeadingZeros, Places, Mantissa, Exponent, Digits)
            If Order < 0 Then
                High = Middle - 1
            Else
                Low = Middle
            End If
        Loop
        Result = Low
        Call Decode(Low, BitWidth, Mantissa, Exponent)
        ' The upper neighbour is one unit in this binade, also at a binade edge.
        Mantissa = Mantissa * 2 + 1
        Exponent = Exponent - 1
        Order = CompareDyadic(Bytes, First, Last, LeadingZeros, Places, Mantissa, Exponent, Digits)
        If Order > 0 Or (Order = 0 And Low Mod 2 <> 0) Then Result = Result + 1
        If BitWidth = 32 Then
            If Result = 2139095040 Then TryParseDecimal = FilePrimitives.SetError(6): Exit Function
        Else
            If Result = 9218868437227405312&& Then TryParseDecimal = FilePrimitives.SetError(6): Exit Function
        End If
    End If
    If Negative Then
        If BitWidth = 32 Then
            Result = Result + 2147483648&&
        Else
            Result = -9223372036854775808&& + Result
        End If
    End If
    Bits = Result
    TryParseDecimal = True
    Exit Function
Failed:
    TryParseDecimal = False
End Function
