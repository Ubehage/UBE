UBE SOURCE 1 MODULE
Attribute UBE_Name = "BinaryFloatValues"
' Integer-only IEEE representation helpers shared by compiler and library algorithms.

Private Intrinsic Function RecordError(ByVal Number As Long) As Boolean
Attribute RecordError.UBE_Primitive = "Error.Set"
End Function

' Packs an exact finite dyadic, with checked range and one nearest/even rounding.
Public Function TryPack(ByVal Negative As Boolean, ByVal Significand As LongLong, ByVal Exponent As Long, ByVal BitWidth As Long, ByRef Bits As LongLong) As Boolean
    TryPack = PackFinite(Negative, Significand, Exponent, False, BitWidth, False, Bits)
End Function

' Sticky represents a nonzero tail below the supplied significand's low bit.
' With a tail, supply at least precision+2 significant bits to avoid double rounding.
Public Function TryPackArithmetic(ByVal Negative As Boolean, ByVal Significand As LongLong, ByVal Exponent As Long, ByVal Sticky As Boolean, ByVal BitWidth As Long, ByRef Bits As LongLong) As Boolean
    TryPackArithmetic = PackFinite(Negative, Significand, Exponent, Sticky, BitWidth, True, Bits)
End Function

Private Function PackFinite(ByVal Negative As Boolean, ByVal Significand As LongLong, ByVal Exponent As Long, ByVal Sticky As Boolean, ByVal BitWidth As Long, ByVal Arithmetic As Boolean, ByRef Bits As LongLong) As Boolean
    Dim Unit As LongLong
    Dim MinimumExponent As Long
    Dim MaximumExponent As Long
    Dim Bias As Long
    Dim FractionWidth As Long
    Dim Guard As Long
    Dim Candidate As LongLong
    Dim Overflowed As Boolean
    On Error GoTo Failed
    If Significand < 0 Then PackFinite = RecordError(5): Exit Function
    If BitWidth = 32 Then
        Unit = 8388608^
        MinimumExponent = -149
        MaximumExponent = 104
        Bias = 127
        FractionWidth = 23
    ElseIf BitWidth = 64 Then
        Unit = 4503599627370496^
        MinimumExponent = -1074
        MaximumExponent = 971
        Bias = 1023
        FractionWidth = 52
    Else
        PackFinite = RecordError(5): Exit Function
    End If
    If Significand <> 0 Then
        Do While Significand >= Unit * 2 Or Exponent < MinimumExponent
            If Guard <> 0 Then Sticky = True
            Guard = Significand Mod 2
            Significand = Significand \ 2
            Exponent = Exponent + 1
            If Significand = 0 And Exponent < MinimumExponent Then
                If Guard <> 0 Then Sticky = True
                Guard = 0
                Exponent = MinimumExponent
            End If
        Loop
        Do While Significand < Unit And Exponent > MinimumExponent
            Significand = Significand * 2
            Exponent = Exponent - 1
        Loop
        If Not Arithmetic Then
            If Exponent > MaximumExponent Then PackFinite = RecordError(6): Exit Function
            If Exponent = MaximumExponent And Significand = Unit * 2 - 1 Then
                If Guard <> 0 Or Sticky Then PackFinite = RecordError(6): Exit Function
            End If
        End If
        If Guard <> 0 Then
            If Sticky Or Significand Mod 2 <> 0 Then Significand = Significand + 1
        End If
        If Significand = Unit * 2 Then
            Significand = Significand \ 2
            Exponent = Exponent + 1
        End If
        Overflowed = Exponent > MaximumExponent
        If Overflowed Then
            PackFinite = RecordError(6): Exit Function
        Else
            Candidate = Significand
            If Significand >= Unit Then Candidate = (Exponent + Bias + FractionWidth) * Unit + Significand - Unit
        End If
    End If
    If Negative Then
        If BitWidth = 32 Then Candidate = Candidate Or 2147483648^
        If BitWidth = 64 Then Candidate = Candidate Or -9223372036854775808^
    End If
    Bits = Candidate
    PackFinite = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

Public Function TryFromInteger(ByVal Value As LongLong, ByVal BitWidth As Long, ByRef Bits As LongLong) As Boolean
    Dim Magnitude As LongLong
    Dim Exponent As Long
    On Error GoTo Failed
    If Value = -9223372036854775808^ Then
        Magnitude = 4611686018427387904^
        Exponent = 1
    Else
        Magnitude = Value
        If Value < 0 Then Magnitude = -Value
    End If
    TryFromInteger = TryPack(Value < 0, Magnitude, Exponent, BitWidth, Bits)
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

Public Function TryConvertWidth(ByVal InputBits As LongLong, ByVal SourceWidth As Long, ByVal DestinationWidth As Long, ByRef Bits As LongLong) As Boolean
    Dim Negative As Boolean
    Dim Significand As LongLong
    Dim Exponent As Long
    Dim Kind As Long
    On Error GoTo Failed
    If DestinationWidth <> 32 And DestinationWidth <> 64 Then TryConvertWidth = RecordError(5): Exit Function
    If Not TryDecode(InputBits, SourceWidth, Negative, Significand, Exponent, Kind) Then Exit Function
    If Kind <> 0 Then TryConvertWidth = RecordError(6): Exit Function
    If SourceWidth = DestinationWidth Then Bits = InputBits: TryConvertWidth = True: Exit Function
    TryConvertWidth = TryPack(Negative, Significand, Exponent, DestinationWidth, Bits)
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Decodes finite values as Significand * 2^Exponent, preserving the zero sign.
' Kind is 0 for finite, 1 for infinity, and 2 for NaN.
Public Function TryDecode(ByVal Bits As LongLong, ByVal BitWidth As Long, ByRef Negative As Boolean, ByRef Significand As LongLong, ByRef Exponent As Long, ByRef Kind As Long) As Boolean
    Dim Magnitude As LongLong
    Dim FractionUnit As LongLong
    Dim EncodedExponent As Long
    Dim MaximumExponent As Long
    Dim Bias As Long
    Dim FractionWidth As Long
    Dim CandidateNegative As Boolean
    Dim CandidateSignificand As LongLong
    Dim CandidateExponent As Long
    Dim CandidateKind As Long
    On Error GoTo Failed
    If BitWidth = 32 Then
        If Bits < 0 Or Bits > 4294967295^ Then TryDecode = RecordError(5): Exit Function
        CandidateNegative = Bits >= 2147483648^
        Magnitude = Bits And 2147483647^
        FractionUnit = 8388608^
        MaximumExponent = 255
        Bias = 127
        FractionWidth = 23
    ElseIf BitWidth = 64 Then
        CandidateNegative = Bits < 0
        Magnitude = Bits And 9223372036854775807^
        FractionUnit = 4503599627370496^
        MaximumExponent = 2047
        Bias = 1023
        FractionWidth = 52
    Else
        TryDecode = RecordError(5): Exit Function
    End If
    EncodedExponent = Magnitude \ FractionUnit
    CandidateSignificand = Magnitude Mod FractionUnit
    If EncodedExponent = MaximumExponent Then
        CandidateKind = 1
        If CandidateSignificand <> 0 Then CandidateKind = 2
    Else
        CandidateExponent = 1 - Bias - FractionWidth
        If EncodedExponent <> 0 Then
            CandidateSignificand = CandidateSignificand + FractionUnit
            CandidateExponent = EncodedExponent - Bias - FractionWidth
        End If
    End If
    Negative = CandidateNegative
    Significand = CandidateSignificand
    Exponent = CandidateExponent
    Kind = CandidateKind
    TryDecode = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Converts a finite IEEE value to signed integer, rounding once to nearest/even.
' Rejected conversions preserve Value. Range-specific narrowing belongs to caller.
Public Function TryToInteger(ByVal Bits As LongLong, ByVal BitWidth As Long, ByRef Value As LongLong) As Boolean
    Dim Negative As Boolean
    Dim Significand As LongLong
    Dim Exponent As Long
    Dim Kind As Long
    Dim Guard As Long
    Dim Sticky As Boolean
    Dim Candidate As LongLong
    On Error GoTo Failed
    If Not TryDecode(Bits, BitWidth, Negative, Significand, Exponent, Kind) Then Exit Function
    If Kind <> 0 Then TryToInteger = RecordError(6): Exit Function
    If Significand = 0 Then Value = 0: TryToInteger = True: Exit Function
    Do While Exponent < 0
        If Guard <> 0 Then Sticky = True
        Guard = Significand Mod 2
        Significand = Significand \ 2
        Exponent = Exponent + 1
    Loop
    If Guard <> 0 Then
        If Sticky Or (Significand Mod 2 <> 0) Then Significand = Significand + 1
    End If
    ' Accumulate negatively to include the asymmetric LongLong minimum.
    Candidate = -Significand
    Do While Exponent > 0
        If Candidate < -4611686018427387904^ Then TryToInteger = RecordError(6): Exit Function
        Candidate = Candidate * 2
        Exponent = Exponent - 1
    Loop
    If Not Negative Then
        If Candidate = -9223372036854775808^ Then TryToInteger = RecordError(6): Exit Function
        Candidate = -Candidate
    End If
    Value = Candidate
    TryToInteger = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function
