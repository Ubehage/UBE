UBE SOURCE 1 MODULE
Attribute UBE_Name = "BinaryFloatPower"
' Correct rounding from directed fixed-point intervals; no host floating point.

' Ordinary bound runtime role: convert record-only failure into language FAIL.
Public Function Evaluate(ByVal BaseBits As LongLong, ByVal PowerBits As LongLong) As LongLong
    Dim Result As LongLong
    On Error GoTo Failed
    If Not TryPower(BaseBits, PowerBits, Result) Then Err.Raise Err.Number
    Evaluate = Result
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

Private Sub Clear(ByRef A() As Byte, ByVal Count As Long)
    Dim I As Long
    On Error GoTo Failed
    If Not BufferPrimitives.TryResizeBytes(A, Count, False) Then Err.Raise Err.Number
    Do While I < Count
        A(I) = 0
        I = I + 1
    Loop
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

Private Sub Copy(ByRef A() As Byte, ByRef B() As Byte, ByVal Count As Long)
    On Error GoTo Failed
    Call Clear(B, Count)
    If Not BufferPrimitives.CopyByteRange(A, 0, B, 0, Count) Then Err.Raise Err.Number
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

Private Function Compare(ByRef A() As Byte, ByRef B() As Byte, ByVal Count As Long) As Long
    Dim I As Long = Count - 1
    Do While I >= 0
        If A(I) < B(I) Then Compare = -1: Exit Function
        If A(I) > B(I) Then Compare = 1: Exit Function
        I = I - 1
    Loop
End Function

Private Sub Increment(ByRef A() As Byte, ByVal Count As Long)
    Dim I As Long
    Do While I < Count
        If A(I) < 255 Then A(I) = A(I) + 1: Exit Sub
        A(I) = 0
        I = I + 1
    Loop
    Err.Raise 6
End Sub

Private Sub Add(ByRef A() As Byte, ByRef B() As Byte, ByVal Count As Long)
    Dim I As Long
    Dim Carry As Long
    Do While I < Count
        Carry = A(I) + B(I) + Carry
        A(I) = Carry Mod 256
        Carry = Carry \ 256
        I = I + 1
    Loop
    If Carry <> 0 Then Err.Raise 6
End Sub

Private Sub Subtract(ByRef A() As Byte, ByRef B() As Byte, ByVal Count As Long)
    Dim I As Long
    Dim Borrow As Long
    Dim Value As Long
    Do While I < Count
        Value = A(I) - B(I) - Borrow
        Borrow = 0
        If Value < 0 Then Value = Value + 256: Borrow = 1
        A(I) = Value
        I = I + 1
    Loop
    If Borrow <> 0 Then Err.Raise 6
End Sub

Private Sub MultiplySmall(ByRef A() As Byte, ByVal Value As LongLong, ByVal Count As Long, ByRef Result() As Byte)
    Dim I As Long
    Dim Carry As LongLong
    On Error GoTo Failed
    Call Clear(Result, Count)
    Do While I < Count
        Carry = A(I) * Value + Carry
        Result(I) = Carry Mod 256
        Carry = Carry \ 256
        I = I + 1
    Loop
    If Carry <> 0 Then Err.Raise 6
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

Private Sub DivideSmall(ByRef A() As Byte, ByVal Divisor As Long, ByVal Count As Long, ByVal Upward As Boolean, ByRef Result() As Byte)
    Dim I As Long = Count - 1
    Dim Remainder As LongLong
    On Error GoTo Failed
    Call Clear(Result, Count)
    Do While I >= 0
        Remainder = Remainder * 256 + A(I)
        Result(I) = Remainder \ Divisor
        Remainder = Remainder Mod Divisor
        I = I - 1
    Loop
    If Upward And Remainder <> 0 Then Call Increment(Result, Count)
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

' The returned fixed-point product discards exactly FractionBytes low bytes.
Private Sub Multiply(ByRef A() As Byte, ByRef B() As Byte, ByVal FractionBytes As Long, ByVal Count As Long, ByVal Upward As Boolean, ByRef Result() As Byte)
    Dim Product() As Byte
    Dim I As Long
    Dim J As Long
    Dim Carry As LongLong
    Dim Sticky As Boolean
    Dim Value As LongLong
    On Error GoTo Failed
    Call Clear(Product, Count * 2)
    Call Clear(Result, Count)
    Do While I < Count
        J = 0
        Carry = 0
        Do While J < Count
            Value = A(I)
            Value = Value * B(J)
            Carry = Product(I + J) + Value + Carry
            Product(I + J) = Carry Mod 256
            Carry = Carry \ 256
            J = J + 1
        Loop
        Product(I + Count) = Carry
        I = I + 1
    Loop
    I = 0
    Do While I < FractionBytes
        If Product(I) <> 0 Then Sticky = True
        I = I + 1
    Loop
    I = 0
    Do While I < Count
        Result(I) = Product(I + FractionBytes)
        I = I + 1
    Loop
    I = Count + FractionBytes
    Do While I < Count * 2
        If Product(I) <> 0 Then Err.Raise 6
        I = I + 1
    Loop
    If Upward And Sticky Then Call Increment(Result, Count)
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

Private Sub Shift(ByRef A() As Byte, ByVal Exponent As Long, ByVal Count As Long, ByVal Upward As Boolean)
    Dim I As Long
    Dim Carry As Long
    Dim Value As Long
    Dim Sticky As Boolean
    Do While Exponent > 0
        I = 0: Carry = 0
        Do While I < Count
            Value = A(I) * 2 + Carry
            A(I) = Value Mod 256
            Carry = Value \ 256
            I = I + 1
        Loop
        If Carry <> 0 Then Err.Raise 6
        Exponent = Exponent - 1
    Loop
    Do While Exponent < 0
        I = Count - 1: Carry = 0
        Do While I >= 0
            Value = Carry * 256 + A(I)
            A(I) = Value \ 2
            Carry = Value Mod 2
            I = I - 1
        Loop
        If Carry <> 0 Then Sticky = True
        Exponent = Exponent + 1
    Loop
    If Upward And Sticky Then Call Increment(A, Count)
End Sub

' Numerator/Denominator is <=1/3; remainder arithmetic fits signed LongLong.
Private Sub Ratio(ByVal Numerator As LongLong, ByVal Denominator As LongLong, ByVal FractionBytes As Long, ByVal Count As Long, ByVal Upward As Boolean, ByRef Result() As Byte)
    Dim I As Long = FractionBytes - 1
    Dim J As Long
    Dim Digit As Long
    On Error GoTo Failed
    Call Clear(Result, Count)
    Do While I >= 0
        J = 0: Digit = 0
        Do While J < 8
            Numerator = Numerator * 2
            Digit = Digit * 2
            If Numerator >= Denominator Then Numerator = Numerator - Denominator: Digit = Digit + 1
            J = J + 1
        Loop
        Result(I) = Digit
        I = I - 1
    Loop
    If Upward And Numerator <> 0 Then Call Increment(Result, Count)
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

' ln((d+n)/(d-n)) = 2 * sum(t^(2j+1)/(2j+1)).
' With t<=1/3, ceil(P/3) terms leave tail below 9^-N <= 2^-P.
Private Sub LogRatio(ByVal Numerator As LongLong, ByVal Denominator As LongLong, ByVal FractionBytes As Long, ByVal Count As Long, ByVal Upward As Boolean, ByRef Result() As Byte)
    Dim Term() As Byte
    Dim Square() As Byte
    Dim NextTerm() As Byte
    Dim Part() As Byte
    Dim I As Long
    Dim Precision As Long = FractionBytes * 8
    Dim Terms As Long = (Precision + 2) \ 3
    On Error GoTo Failed
    Call Clear(Result, Count)
    If Numerator = 0 Then Exit Sub
    Call Ratio(Numerator, Denominator, FractionBytes, Count, Upward, Term)
    Call Multiply(Term, Term, FractionBytes, Count, Upward, Square)
    Do While I < Terms
        Call DivideSmall(Term, I * 2 + 1, Count, Upward, Part)
        Call Add(Result, Part, Count)
        Call Multiply(Term, Square, FractionBytes, Count, Upward, NextTerm)
        Call Copy(NextTerm, Term, Count)
        I = I + 1
    Loop
    Call Shift(Result, 1, Count, False)
    If Upward Then Call Increment(Result, Count)
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

' exp(r) for 0<=r<=1. N=P/2 terms leave tail <3/(N+1)!<2^-P, P>=16.
Private Sub ExpSeries(ByRef Argument() As Byte, ByVal FractionBytes As Long, ByVal Count As Long, ByVal Upward As Boolean, ByRef Result() As Byte)
    Dim Term() As Byte
    Dim Product() As Byte
    Dim NextTerm() As Byte
    Dim I As Long = 1
    Dim Precision As Long = FractionBytes * 8
    Dim Terms As Long = Precision \ 2
    On Error GoTo Failed
    Call Clear(Result, Count): Result(FractionBytes) = 1
    Call Copy(Result, Term, Count)
    Do While I <= Terms
        Call Multiply(Term, Argument, FractionBytes, Count, Upward, Product)
        Call DivideSmall(Product, I, Count, Upward, NextTerm)
        Call Add(Result, NextTerm, Count)
        Call Copy(NextTerm, Term, Count)
        I = I + 1
    Loop
    If Upward Then Call Increment(Result, Count)
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

' Directed quotient 2^(2P)/Argument for Argument in [2^P, 3*2^P].
Private Sub Reciprocal(ByRef Argument() As Byte, ByVal FractionBytes As Long, ByVal Count As Long, ByVal Upward As Boolean, ByRef Result() As Byte)
    Dim Remainder() As Byte
    Dim I As Long = FractionBytes * 16
    Dim Position As Long
    Dim Mask As Long
    Dim J As Long
    Dim Nonzero As Boolean
    On Error GoTo Failed
    Call Clear(Result, Count): Call Clear(Remainder, Count)
    Remainder(0) = 1
    Do While I >= 0
        If Compare(Remainder, Argument, Count) >= 0 Then
            Call Subtract(Remainder, Argument, Count)
            Position = I \ 8
            Mask = 1: J = I Mod 8
            Do While J > 0
                Mask = Mask * 2: J = J - 1
            Loop
            Result(Position) = Result(Position) + Mask
        End If
        I = I - 1
        If I >= 0 Then Call Shift(Remainder, 1, Count, False)
    Loop
    I = 0
    Do While I < Count
        If Remainder(I) <> 0 Then Nonzero = True
        I = I + 1
    Loop
    If Upward And Nonzero Then Call Increment(Result, Count)
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

Private Function Pack(ByRef A() As Byte, ByVal FractionBytes As Long, ByVal Count As Long, ByVal Exponent As Long, ByRef Bits As LongLong) As Boolean
    Dim I As Long = Count - 1
    Dim Mask As Long = 128
    Dim Top As Long
    Dim Position As Long
    Dim Retained As Long
    Dim Significand As LongLong
    Dim Sticky As Boolean
    Do While I >= 0
        If A(I) <> 0 Then Exit Do
        I = I - 1
    Loop
    If I < 0 Then Bits = 0: Pack = True: Exit Function
    Top = I * 8 + 7
    Do While (A(I) And Mask) = 0
        Mask = Mask \ 2: Top = Top - 1
    Loop
    Position = Top
    Do While Position >= 0
        If Retained < 60 Then
            Significand = Significand * 2
            If (A(I) And Mask) <> 0 Then Significand = Significand + 1
            Retained = Retained + 1
        Else
            If (A(I) And Mask) <> 0 Then Sticky = True
        End If
        Position = Position - 1: Mask = Mask \ 2
        If Mask = 0 Then Mask = 128: I = I - 1
    Loop
    Exponent = Exponent - FractionBytes * 8 + Top - Retained + 1
    Pack = BinaryFloatValues.TryPackArithmetic(False, Significand, Exponent, Sticky, 64, Bits)
End Function

' Exact rational dyadic results cover midpoint cases, so interval retries terminate.
Private Function Exact(ByVal Mantissa As LongLong, ByVal Exponent As Long, ByVal PowerMantissa As LongLong, ByVal PowerExponent As Long, ByVal PowerNegative As Boolean, ByRef Matched As Boolean, ByRef Bits As LongLong) As Boolean
    Dim Divisor As Long = 1
    Dim Q As Long
    Dim Low As LongLong
    Dim High As LongLong
    Dim Middle As LongLong
    Dim Root As LongLong
    Dim Product As LongLong = 1
    Dim I As LongLong
    Dim ResultExponent As Long
    Dim AbsoluteExponent As Long
    On Error GoTo Failed
    Exact = True
    Do While Mantissa Mod 2 = 0
        Mantissa = Mantissa \ 2: Exponent = Exponent + 1
    Loop
    Do While PowerMantissa Mod 2 = 0
        PowerMantissa = PowerMantissa \ 2: PowerExponent = PowerExponent + 1
    Loop
    If PowerExponent < 0 Then
        Q = -PowerExponent
        If Q > 11 Then Exit Function
        I = 0
        Do While I < Q
            Divisor = Divisor * 2: I = I + 1
        Loop
        If Exponent Mod Divisor <> 0 Then Exit Function
        Exponent = Exponent \ Divisor
        I = 0
        Do While I < Q And Mantissa <> 1
            Low = 1: High = 94906265
            Do While Low < High
                Middle = Low + (High - Low) \ 2 + 1
                If Middle * Middle > Mantissa Then High = Middle - 1 Else Low = Middle
            Loop
            Root = Low
            If Root * Root <> Mantissa Then Exit Function
            Mantissa = Root: I = I + 1
        Loop
        PowerExponent = 0
    End If
    If Mantissa = 1 Then
        AbsoluteExponent = Exponent
        If AbsoluteExponent < 0 Then AbsoluteExponent = -AbsoluteExponent
        If AbsoluteExponent = 0 Then Bits = 4607182418800017408^: Matched = True: Exit Function
        ResultExponent = 5000
        If PowerExponent < 13 Then
            Do While PowerExponent > 0 And PowerMantissa <= 5000
                PowerMantissa = PowerMantissa * 2: PowerExponent = PowerExponent - 1
            Loop
            If PowerMantissa <= 5000 \ AbsoluteExponent And PowerExponent = 0 Then ResultExponent = AbsoluteExponent * PowerMantissa
        End If
        If (Exponent < 0) <> PowerNegative Then ResultExponent = -ResultExponent
        If Not BinaryFloatValues.TryPackArithmetic(False, 1, ResultExponent, False, 64, Bits) Then Exact = False: Exit Function
        Matched = True: Exit Function
    End If
    If PowerNegative Or PowerExponent > 5 Then Exit Function
    Do While PowerExponent > 0
        PowerMantissa = PowerMantissa * 2: PowerExponent = PowerExponent - 1
    Loop
    If PowerMantissa > 34 Then Exit Function
    I = 0
    Do While I < PowerMantissa
        If Product > 18014398509481983^ \ Mantissa Then Exit Function
        Product = Product * Mantissa: I = I + 1
    Loop
    ResultExponent = Exponent * PowerMantissa
    If Not BinaryFloatValues.TryPackArithmetic(False, Product, ResultExponent, False, 64, Bits) Then Exact = False: Exit Function
    Matched = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

Private Function Refine(ByVal Mantissa As LongLong, ByVal Exponent As Long, ByVal PowerMantissa As LongLong, ByVal PowerExponent As Long, ByVal PowerNegative As Boolean, ByVal FractionBytes As Long, ByRef Matched As Boolean, ByRef Bits As LongLong) As Boolean
    Dim Count As Long = FractionBytes + 16
    Dim LnLow() As Byte
    Dim LnHigh() As Byte
    Dim TwoLow() As Byte
    Dim TwoHigh() As Byte
    Dim Low() As Byte
    Dim High() As Byte
    Dim Temporary() As Byte
    Dim Unit() As Byte
    Dim ZLow() As Byte
    Dim ZHigh() As Byte
    Dim ResultLow() As Byte
    Dim ResultHigh() As Byte
    Dim K As Long
    Dim N As Long
    Dim Negative As Boolean
    Dim LowBits As LongLong
    Dim HighBits As LongLong
    Dim PriorError As Long
    On Error GoTo Failed
    Do While Mantissa < 4503599627370496^
        Mantissa = Mantissa * 2: Exponent = Exponent - 1
    Loop
    K = Exponent + 52
    Call LogRatio(Mantissa - 4503599627370496^, Mantissa + 4503599627370496^, FractionBytes, Count, False, LnLow)
    Call LogRatio(Mantissa - 4503599627370496^, Mantissa + 4503599627370496^, FractionBytes, Count, True, LnHigh)
    Call LogRatio(1, 3, FractionBytes, Count, False, TwoLow)
    Call LogRatio(1, 3, FractionBytes, Count, True, TwoHigh)
    Negative = K < 0
    If K >= 0 Then
        Call MultiplySmall(TwoLow, K, Count, Low): Call Add(Low, LnLow, Count)
        Call MultiplySmall(TwoHigh, K, Count, High): Call Add(High, LnHigh, Count)
    Else
        Call MultiplySmall(TwoLow, -K, Count, Low)
        If Compare(Low, LnHigh, Count) < 0 Then Refine = True: Exit Function
        Call Subtract(Low, LnHigh, Count)
        Call MultiplySmall(TwoHigh, -K, Count, High): Call Subtract(High, LnLow, Count)
    End If
    Call MultiplySmall(Low, PowerMantissa, Count, ZLow): Call Shift(ZLow, PowerExponent, Count, False)
    Call MultiplySmall(High, PowerMantissa, Count, ZHigh): Call Shift(ZHigh, PowerExponent, Count, True)
    Negative = Negative <> PowerNegative
    Call Clear(Unit, Count): Unit(FractionBytes + 1) = 8
    If Compare(ZLow, Unit, Count) >= 0 Then
        If Not Negative Then Refine = FilePrimitives.SetError(6): Exit Function
        Bits = 0
        Matched = True: Refine = True: Exit Function
    End If
    Call Copy(ZLow, Low, Count)
    Do While Compare(Low, TwoHigh, Count) >= 0
        Call Subtract(Low, TwoHigh, Count): N = N + 1
    Loop
    Call MultiplySmall(TwoLow, N, Count, Temporary)
    Call Copy(ZHigh, High, Count): Call Subtract(High, Temporary, Count)
    Call Clear(Unit, Count): Unit(FractionBytes) = 1
    If Compare(High, Unit, Count) > 0 Then Refine = True: Exit Function
    Call ExpSeries(Low, FractionBytes, Count, False, ResultLow)
    Call ExpSeries(High, FractionBytes, Count, True, ResultHigh)
    If Negative Then
        Call Reciprocal(ResultHigh, FractionBytes, Count, False, Low)
        Call Reciprocal(ResultLow, FractionBytes, Count, True, High)
        N = -N
    Else
        Call Copy(ResultLow, Low, Count): Call Copy(ResultHigh, High, Count)
    End If
    If Not Pack(Low, FractionBytes, Count, N, LowBits) Then Exit Function
    PriorError = Err.Number
    If Not Pack(High, FractionBytes, Count, N, HighBits) Then
        If Err.Number = 6 Then Call FilePrimitives.SetError(PriorError): Refine = True
        Exit Function
    End If
    Matched = LowBits = HighBits
    If Matched Then Bits = LowBits
    Refine = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Positive finite base and finite nonzero exponent; special/domain dispatch is separate.
Public Function TryFinite(ByVal BaseBits As LongLong, ByVal PowerBits As LongLong, ByRef Bits As LongLong) As Boolean
    Dim Negative As Boolean
    Dim Mantissa As LongLong
    Dim Exponent As Long
    Dim Kind As Long
    Dim PowerNegative As Boolean
    Dim PowerMantissa As LongLong
    Dim PowerExponent As Long
    Dim PowerKind As Long
    Dim Matched As Boolean
    Dim Candidate As LongLong
    Dim FractionBytes As Long = 8
    On Error GoTo Failed
    If Not BinaryFloatValues.TryDecode(BaseBits, 64, Negative, Mantissa, Exponent, Kind) Then Exit Function
    If Not BinaryFloatValues.TryDecode(PowerBits, 64, PowerNegative, PowerMantissa, PowerExponent, PowerKind) Then Exit Function
    If Negative Or Kind <> 0 Or Mantissa = 0 Or PowerKind <> 0 Or PowerMantissa = 0 Then TryFinite = FilePrimitives.SetError(5): Exit Function
    If BaseBits = 4607182418800017408^ Then Bits = BaseBits: TryFinite = True: Exit Function
    If PowerExponent >= 12 Then
        If (BaseBits < 4607182418800017408^) <> PowerNegative Then Bits = 0: TryFinite = True: Exit Function
        TryFinite = FilePrimitives.SetError(6): Exit Function
    End If
    If Not Exact(Mantissa, Exponent, PowerMantissa, PowerExponent, PowerNegative, Matched, Candidate) Then Exit Function
    Do While Not Matched
        If Not Refine(Mantissa, Exponent, PowerMantissa, PowerExponent, PowerNegative, FractionBytes, Matched, Candidate) Then Exit Function
        If Not Matched Then
            If FractionBytes > 67108864 Then TryFinite = FilePrimitives.SetError(7): Exit Function
            FractionBytes = FractionBytes * 2
        End If
    Loop
    Bits = Candidate
    TryFinite = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Finite-only language power, including integral negative-base and signed-zero cases.
Public Function TryPower(ByVal BaseBits As LongLong, ByVal PowerBits As LongLong, ByRef Bits As LongLong) As Boolean
    Dim Negative As Boolean
    Dim Mantissa As LongLong
    Dim Exponent As Long
    Dim Kind As Long
    Dim PowerNegative As Boolean
    Dim PowerMantissa As LongLong
    Dim PowerExponent As Long
    Dim PowerKind As Long
    Dim Integral As Boolean = True
    Dim Odd As Boolean
    Dim Candidate As LongLong
    On Error GoTo Failed
    If Not BinaryFloatValues.TryDecode(BaseBits, 64, Negative, Mantissa, Exponent, Kind) Then Exit Function
    If Not BinaryFloatValues.TryDecode(PowerBits, 64, PowerNegative, PowerMantissa, PowerExponent, PowerKind) Then Exit Function
    If Kind <> 0 Or PowerKind <> 0 Then TryPower = FilePrimitives.SetError(6): Exit Function
    If PowerMantissa = 0 Then Bits = 4607182418800017408^: TryPower = True: Exit Function
    Do While PowerExponent < 0
        If PowerMantissa Mod 2 <> 0 Then Integral = False: Exit Do
        PowerMantissa = PowerMantissa \ 2: PowerExponent = PowerExponent + 1
    Loop
    If Integral And PowerExponent = 0 Then Odd = PowerMantissa Mod 2 <> 0
    If Mantissa = 0 Then
        If PowerNegative Then TryPower = FilePrimitives.SetError(5): Exit Function
        If Negative And Odd Then Candidate = -9223372036854775808^
        Bits = Candidate: TryPower = True: Exit Function
    End If
    If Negative And Not Integral Then TryPower = FilePrimitives.SetError(5): Exit Function
    If Not TryFinite(BaseBits And 9223372036854775807^, PowerBits, Candidate) Then Exit Function
    If Negative And Odd Then Candidate = Candidate Or -9223372036854775808^
    Bits = Candidate
    TryPower = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function
