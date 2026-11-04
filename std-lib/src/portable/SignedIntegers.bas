UBE SOURCE 1 MODULE
Attribute UBE_Name = "SignedIntegers"

' Scalar incremental ASCII output; contract: ../../INTEGER-OUTPUT-CONTRACT.md.
' Reserved state, one caller owner. Neutral state is exhausted. No managed
' references, roots, allocations, payload copies or Err effects.
Type DecimalIntegerEncoder
    Remaining As LongLong
    Divisor As LongLong
    SignPending As Boolean
End Type

Sub BeginDecimalIntegerEncoding(ByVal Value As LongLong, ByRef Encoder As DecimalIntegerEncoder, ByRef ByteCount As Long)
    Dim Remaining As LongLong = Value
    Dim Negative As Boolean = Value < 0
    If Negative = False Then
        Remaining = -Value
    End If
    Dim Divisor As LongLong = 1
    Dim Count As Long = 1
    While Remaining \ Divisor < -9
        Divisor = Divisor * 10
        Count = Count + 1
    Wend
    If Negative Then
        Count = Count + 1
    End If
    Encoder.Remaining = Remaining
    Encoder.Divisor = Divisor
    Encoder.SignPending = Negative
    ByteCount = Count
End Sub

Function TryNextDecimalIntegerByte(ByRef Encoder As DecimalIntegerEncoder, ByRef Value As Byte, ByRef HasByte As Boolean) As Boolean
    TryNextDecimalIntegerByte = False
    If Encoder.Divisor < 0 Or Encoder.Remaining > 0 Then
        Exit Function
    End If
    If Encoder.Divisor = 0 Then
        If Encoder.Remaining <> 0 Or Encoder.SignPending Then
            Exit Function
        End If
        HasByte = False
        TryNextDecimalIntegerByte = True
        Exit Function
    End If
    Dim Digit As LongLong = Encoder.Remaining \ Encoder.Divisor
    If Digit < -9 Or Digit > 0 Then
        Exit Function
    End If
    If Encoder.SignPending Then
        Value = 45
        Encoder.SignPending = False
    Else
        Value = 48 - Digit
        Encoder.Remaining = Encoder.Remaining Mod Encoder.Divisor
        Encoder.Divisor = Encoder.Divisor \ 10
    End If
    HasByte = True
    TryNextDecimalIntegerByte = True
End Function

' Ordinary bounded integer algorithms; contract: ../../SIGNED-INTEGER-CONTRACT.md.
' Bytes are borrowed immutable input for one call. Outputs have one caller owner
' and must be distinct; no input/output alias is permitted. No input reference,
' mutable shared state, array, String or numeric object is retained or copied.
' Logical outcomes preserve Err; actual managed admission failure retains Err 7.
' Callers seed Failure=5 before managed entry. Calls are reentrant/thread-safe.

' One fallible managed read; the decoder seeds fresh Failure=5 before calling.
' This private helper retains nothing and never allocates or changes Err.
' Managed entry may fail before its body; False never comes from stale Err.
' The caller validates the complete span before any read.
' No language literal grammar, suffix, target type or compiler policy is selected.
' The public scalar APIs below require no managed roots and allocate nothing.
Private Function TryReadDecimalIntegerByte(ByRef Bytes() As Byte, ByVal AtByte As Long, ByRef Value As Long) As Boolean
    TryReadDecimalIntegerByte = False
    Value = Bytes(AtByte)
    TryReadDecimalIntegerByte = True
End Function

' ASCII digit span only; sign and inclusive caller range are explicit inputs.
' Output is preserved on failure. Failure: 1 domain, 2 format, 3 range,
' 4 division by zero (arithmetic API), 5 managed admission; 0 success.
' Caller seeds Failure=5 before entry. All logical outcomes preserve Err.
Function TryDecodeDecimalInteger(ByRef Bytes() As Byte, ByVal FirstByte As Long, ByVal ByteCount As Long, ByVal Negative As Boolean, ByVal Minimum As LongLong, ByVal Maximum As LongLong, ByRef Result As LongLong, ByRef Failure As Long) As Boolean
    TryDecodeDecimalInteger = False
    Failure = 1
    If FirstByte < 0 Or ByteCount < 0 Or Minimum > Maximum Then
        Exit Function
    End If
    Dim Length As Long = ByteStorageLength(Bytes)
    If FirstByte > Length Then
        Exit Function
    End If
    If ByteCount > Length - FirstByte Then
        Exit Function
    End If
    Failure = 2
    If ByteCount = 0 Then
        Exit Function
    End If
    Failure = 3
    Dim Limit As LongLong = 0
    If Negative Then
        If Minimum > 0 Then
            Exit Function
        End If
        Limit = Minimum
    Else
        If Maximum < 0 Then
            Exit Function
        End If
        Limit = -Maximum
    End If
    Dim Cutoff As LongLong = Limit \ 10
    Dim Value As LongLong = 0
    Dim AtByte As Long = FirstByte
    Dim LastByte As Long = FirstByte + ByteCount
    While AtByte < LastByte
        Dim Digit As Long = 0
        Failure = 5
        If TryReadDecimalIntegerByte(Bytes, AtByte, Digit) = False Then
            Exit Function
        End If
        Failure = 2
        If Digit < 48 Or Digit > 57 Then
            Exit Function
        End If
        Digit = Digit - 48
        Failure = 3
        If Value < Cutoff Then
            Exit Function
        End If
        Value = Value * 10
        If Value < Limit + Digit Then
            Exit Function
        End If
        Value = Value - Digit
        AtByte = AtByte + 1
    Wend
    If Negative = False Then
        Value = -Value
    End If
    If Value < Minimum Or Value > Maximum Then
        Exit Function
    End If
    Result = Value
    Failure = 0
    TryDecodeDecimalInteger = True
End Function

' Zero-anchored inclusive bounds; both operands must already fit them.
' Operations 1 add, 2 subtract, 3 multiply, 4 divide, 5 remainder,
' 6 negate, 7 identity, 8 Not, 9 And, 10 Or, 11 Xor, 12 Eqv, 13 Imp.
' Unary operations ignore Right. Numeric promotion/operator selection belong
' to the caller. This function allocates/retains nothing and preserves Err.
Function TryEvaluateInteger(ByVal Operation As Long, ByVal Left As LongLong, ByVal Right As LongLong, ByVal Minimum As LongLong, ByVal Maximum As LongLong, ByRef Result As LongLong, ByRef Failure As Long) As Boolean
    TryEvaluateInteger = False
    Failure = 1
    If Operation < 1 Or Operation > 13 Or Minimum > 0 Or Maximum < 0 Then
        Exit Function
    End If
    Failure = 3
    If Left < Minimum Or Left > Maximum Then
        Exit Function
    End If
    If Operation < 6 Or Operation > 8 Then
        If Right < Minimum Or Right > Maximum Then
            Exit Function
        End If
    End If
    Dim Value As LongLong = 0
    If Operation = 1 Then
        If Right > 0 Then
            If Left > Maximum - Right Then
                Exit Function
            End If
        Else
            If Right < 0 Then
                If Left < Minimum - Right Then
                    Exit Function
                End If
            End If
        End If
        Value = Left + Right
    End If
    If Operation = 2 Then
        If Right > 0 Then
            If Left < Minimum + Right Then
                Exit Function
            End If
        Else
            If Right < 0 Then
                If Left > Maximum + Right Then
                    Exit Function
                End If
            End If
        End If
        Value = Left - Right
    End If
    If Operation = 3 Then
        If Left > 0 Then
            If Right > 0 Then
                If Left > Maximum \ Right Then
                    Exit Function
                End If
            Else
                If Right < 0 Then
                    If Right < Minimum \ Left Then
                        Exit Function
                    End If
                End If
            End If
        Else
            If Left < 0 Then
                If Right > 0 Then
                    If Left < Minimum \ Right Then
                        Exit Function
                    End If
                Else
                    If Right < 0 Then
                        If Left < Maximum \ Right Then
                            Exit Function
                        End If
                    End If
                End If
            End If
        End If
        Value = Left * Right
    End If
    If Operation = 4 Or Operation = 5 Then
        If Right = 0 Then
            Failure = 4
            Exit Function
        End If
        If Operation = 4 Then
            If Right = -1 Then
                If Left < -Maximum Then
                    Exit Function
                End If
            End If
            Value = Left \ Right
        Else
            If Right = -1 Or Right = 1 Then
                Value = 0
            Else
                Value = Left Mod Right
            End If
        End If
    End If
    If Operation = 6 Then
        If Left < -Maximum Then
            Exit Function
        End If
        Value = -Left
    End If
    If Operation = 7 Then
        Value = Left
    End If
    If Operation = 8 Then
        Value = Not Left
    End If
    If Operation = 9 Then
        Value = Left And Right
    End If
    If Operation = 10 Then
        Value = Left Or Right
    End If
    If Operation = 11 Or Operation = 12 Then
        Value = (Left Or Right) And Not (Left And Right)
        If Operation = 12 Then
            Value = Not Value
        End If
    End If
    If Operation = 13 Then
        Value = (Not Left) Or Right
    End If
    If Value < Minimum Or Value > Maximum Then
        Exit Function
    End If
    Result = Value
    Failure = 0
    TryEvaluateInteger = True
End Function
Function CompareIntegers(ByVal Left As LongLong, ByVal Right As LongLong) As Long
    CompareIntegers = 0
    If Left < Right Then
        CompareIntegers = -1
    End If
    If Left > Right Then
        CompareIntegers = 1
    End If
End Function
