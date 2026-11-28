UBE SOURCE 1 MODULE
Attribute UBE_Name = "BinaryFloatMath"
' Exact IEEE constant arithmetic, independent of host floating point.

' Adds one exact significand at a nonnegative bit offset.
Private Sub AddMagnitude(ByRef Digits() As Byte, ByVal Position As Long, ByVal Value As LongLong)
    Dim Sum As Long
    Do While Value <> 0
        Sum = Digits(Position) + Value Mod 2
        Digits(Position) = Sum Mod 2
        Value = Value \ 2 + Sum \ 2
        Position = Position + 1
    Loop
End Sub

Private Sub SubtractMagnitude(ByRef Digits() As Byte, ByVal Position As Long, ByVal Value As LongLong)
    Dim Difference As Long
    Dim Borrow As Long
    Do While Value <> 0 Or Borrow <> 0
        Difference = Digits(Position) - Value Mod 2 - Borrow
        Borrow = 0
        If Difference < 0 Then Difference = Difference + 2: Borrow = 1
        Digits(Position) = Difference
        Value = Value \ 2
        Position = Position + 1
    Loop
End Sub

' At most 60 retained bits leave guard/round bits for either target precision.
Private Function PackDigits(ByRef Digits() As Byte, ByVal Negative As Boolean, ByVal Exponent As Long, ByVal BitWidth As Long, ByRef Result As LongLong) As Boolean
    Dim Index As Long = 2199
    Dim Low As Long
    Dim Significand As LongLong
    Dim Sticky As Boolean
    Do While Index >= 0
        If Digits(Index) <> 0 Then Exit Do
        Index = Index - 1
    Loop
    Low = Index - 59
    If Low < 0 Then Low = 0
    Exponent = Exponent + Low
    Do While Index >= Low
        Significand = Significand * 2 + Digits(Index)
        Index = Index - 1
    Loop
    Do While Index >= 0
        If Digits(Index) <> 0 Then Sticky = True: Exit Do
        Index = Index - 1
    Loop
    PackDigits = BinaryFloatValues.TryPackArithmetic(Negative, Significand, Exponent, Sticky, BitWidth, Result)
End Function

' Operation 1/2/3/4 means addition/subtraction/multiplication/division.
' Operands already have their language-selected common result width.
Public Function TryBinary(ByVal LeftBits As LongLong, ByVal RightBits As LongLong, ByVal BitWidth As Long, ByVal Operation As Long, ByRef Result As LongLong) As Boolean
    Dim LeftNegative As Boolean
    Dim RightNegative As Boolean
    Dim LeftSignificand As LongLong
    Dim RightSignificand As LongLong
    Dim LeftExponent As Long
    Dim RightExponent As Long
    Dim LeftKind As Long
    Dim RightKind As Long
    Dim Negative As Boolean
    Dim Exponent As Long
    Dim Digits() As Byte
    Dim Candidate As LongLong
    Dim Position As Long
    Dim SwapValue As LongLong
    Dim SwapExponent As Long
    Dim SwapNegative As Boolean
    Dim Quotient As LongLong
    Dim Remainder As LongLong
    Dim Index As Long
    Dim LeftMagnitude As LongLong
    Dim RightMagnitude As LongLong
    On Error GoTo Failed
    If Operation < 1 Or Operation > 4 Then TryBinary = FilePrimitives.SetError(5): Exit Function
    If Not BinaryFloatValues.TryDecode(LeftBits, BitWidth, LeftNegative, LeftSignificand, LeftExponent, LeftKind) Then Exit Function
    If Not BinaryFloatValues.TryDecode(RightBits, BitWidth, RightNegative, RightSignificand, RightExponent, RightKind) Then Exit Function
    If LeftKind <> 0 Or RightKind <> 0 Then TryBinary = FilePrimitives.SetError(6): Exit Function
    If Operation = 2 Then RightNegative = Not RightNegative
    Negative = LeftNegative <> RightNegative
    If Operation <= 2 Then
        LeftMagnitude = LeftBits And 9223372036854775807&&
        RightMagnitude = RightBits And 9223372036854775807&&
        If BitWidth = 32 Then LeftMagnitude = LeftBits And 2147483647&&: RightMagnitude = RightBits And 2147483647&&
        If LeftMagnitude < RightMagnitude Then
            SwapValue = LeftSignificand: LeftSignificand = RightSignificand: RightSignificand = SwapValue
            SwapExponent = LeftExponent: LeftExponent = RightExponent: RightExponent = SwapExponent
            SwapNegative = LeftNegative: LeftNegative = RightNegative: RightNegative = SwapNegative
        End If
        Negative = LeftNegative
        If LeftSignificand = 0 And RightSignificand = 0 Then Negative = LeftNegative And RightNegative
        If LeftMagnitude = RightMagnitude And LeftNegative <> RightNegative Then Negative = False
        Exponent = LeftExponent
        If RightExponent < Exponent Then Exponent = RightExponent
        If Not BufferPrimitives.TryResizeBytes(Digits, 2200, False) Then Exit Function
        Call AddMagnitude(Digits, LeftExponent - Exponent, LeftSignificand)
        If LeftNegative = RightNegative Then
            Call AddMagnitude(Digits, RightExponent - Exponent, RightSignificand)
        Else
            Call SubtractMagnitude(Digits, RightExponent - Exponent, RightSignificand)
        End If
        If Not PackDigits(Digits, Negative, Exponent, BitWidth, Candidate) Then Exit Function
    ElseIf Operation = 3 Then
        Exponent = LeftExponent + RightExponent
        If Not BufferPrimitives.TryResizeBytes(Digits, 2200, False) Then Exit Function
        Do While RightSignificand <> 0
            If RightSignificand Mod 2 <> 0 Then Call AddMagnitude(Digits, Position, LeftSignificand)
            RightSignificand = RightSignificand \ 2
            Position = Position + 1
        Loop
        If Not PackDigits(Digits, Negative, Exponent, BitWidth, Candidate) Then Exit Function
    Else
        If RightSignificand = 0 Then TryBinary = FilePrimitives.SetError(11): Exit Function
        If LeftSignificand = 0 Then
            If Not BinaryFloatValues.TryPackArithmetic(Negative, 0, 0, False, BitWidth, Candidate) Then Exit Function
        Else
            Exponent = LeftExponent - RightExponent
            Remainder = LeftSignificand
            Do While Remainder < RightSignificand
                Remainder = Remainder * 2
                Exponent = Exponent - 1
            Loop
            ' Normalization above may still leave a multi-bit integer quotient.
            Do While Remainder >= RightSignificand * 2
                RightSignificand = RightSignificand * 2
                Exponent = Exponent + 1
            Loop
            Do While Index < 60
                Quotient = Quotient * 2
                If Remainder >= RightSignificand Then Quotient = Quotient + 1: Remainder = Remainder - RightSignificand
                Remainder = Remainder * 2
                Index = Index + 1
            Loop
            If Not BinaryFloatValues.TryPackArithmetic(Negative, Quotient, Exponent - 59, Remainder <> 0, BitWidth, Candidate) Then Exit Function
        End If
    End If
    Result = Candidate
    TryBinary = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Finite comparison returns Order -1, 0, or 1; nonfinite input is rejected.
Public Function TryCompare(ByVal LeftBits As LongLong, ByVal RightBits As LongLong, ByVal BitWidth As Long, ByRef Order As Long, ByRef Unordered As Boolean) As Boolean
    Dim LeftNegative As Boolean
    Dim RightNegative As Boolean
    Dim Significand As LongLong
    Dim Exponent As Long
    Dim LeftKind As Long
    Dim RightKind As Long
    Dim LeftMagnitude As LongLong
    Dim RightMagnitude As LongLong
    Dim Candidate As Long
    On Error GoTo Failed
    If Not BinaryFloatValues.TryDecode(LeftBits, BitWidth, LeftNegative, Significand, Exponent, LeftKind) Then Exit Function
    If Not BinaryFloatValues.TryDecode(RightBits, BitWidth, RightNegative, Significand, Exponent, RightKind) Then Exit Function
    If LeftKind <> 0 Or RightKind <> 0 Then TryCompare = FilePrimitives.SetError(6): Exit Function
    LeftMagnitude = LeftBits And 9223372036854775807&&
    RightMagnitude = RightBits And 9223372036854775807&&
    If BitWidth = 32 Then LeftMagnitude = LeftBits And 2147483647&&: RightMagnitude = RightBits And 2147483647&&
    If LeftMagnitude <> 0 Or RightMagnitude <> 0 Then
        If LeftNegative <> RightNegative Then
            Candidate = 1
            If LeftNegative Then Candidate = -1
        Else
            If LeftMagnitude < RightMagnitude Then Candidate = -1
            If LeftMagnitude > RightMagnitude Then Candidate = 1
            If LeftNegative Then Candidate = -Candidate
        End If
    End If
    Order = Candidate
    Unordered = False
    TryCompare = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function
