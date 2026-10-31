UBE SOURCE 1 MODULE
Attribute UBE_Name = "Utf8"

' Strict incremental UTF-8; contract: ../../BYTE-TEXT-CONTRACT.md.
' Ordinary value state, no retained references, allocations or external resources.
' Zero is ready; fields are reserved implementation state. Copying is independent.
Type Utf8Decoder
    Remaining As Long
    Accumulator As Long
    MinimumScalar As Long
    Failed As Boolean
End Type

' Clears incomplete input and sticky failure. No allocation or Err change.
Sub ResetUtf8Decoder(ByRef Decoder As Utf8Decoder)
    Decoder.Remaining = 0
    Decoder.Accumulator = 0
    Decoder.MinimumScalar = 0
    Decoder.Failed = False
End Sub

' True accepts a byte; Complete distinguishes a produced scalar (including zero).
' Pending/failure outputs are zero/False. Failure sticks until reset.
' Outputs must not alias Decoder fields. Calls retain no arguments and preserve Err.
Function FeedUtf8Byte(ByRef Decoder As Utf8Decoder, ByVal Value As Byte, ByRef Scalar As Long, ByRef Complete As Boolean) As Boolean
    FeedUtf8Byte = False
    Scalar = 0
    Complete = False
    If Decoder.Failed Then
        Exit Function
    End If
    If Decoder.Remaining < 0 Or Decoder.Remaining > 3 Or Decoder.Accumulator < 0 Or Decoder.Accumulator > 17407 Then
        Decoder.Failed = True
        Exit Function
    End If
    If Decoder.Remaining = 0 Then
        If Value < 128 Then
            Scalar = Value
            Complete = True
            FeedUtf8Byte = True
            Exit Function
        End If
        If Value >= 194 And Value <= 223 Then
            Decoder.Remaining = 1
            Decoder.Accumulator = Value - 192
            Decoder.MinimumScalar = 128
            FeedUtf8Byte = True
            Exit Function
        End If
        If Value >= 224 And Value <= 239 Then
            Decoder.Remaining = 2
            Decoder.Accumulator = Value - 224
            Decoder.MinimumScalar = 2048
            FeedUtf8Byte = True
            Exit Function
        End If
        If Value >= 240 And Value <= 244 Then
            Decoder.Remaining = 3
            Decoder.Accumulator = Value - 240
            Decoder.MinimumScalar = 65536
            FeedUtf8Byte = True
            Exit Function
        End If
        Decoder.Failed = True
        Exit Function
    End If
    If Value < 128 Or Value > 191 Then
        Decoder.Failed = True
        Exit Function
    End If
    If Decoder.MinimumScalar <> 128 And Decoder.MinimumScalar <> 2048 And Decoder.MinimumScalar <> 65536 Then
        Decoder.Failed = True
        Exit Function
    End If
    Dim NextScalar As Long = Decoder.Accumulator * 64 + Value - 128
    If Decoder.Remaining = 1 Then
        If NextScalar < Decoder.MinimumScalar Or NextScalar > 1114111 Or (NextScalar >= 55296 And NextScalar <= 57343) Then
            Decoder.Failed = True
            Exit Function
        End If
        Call ResetUtf8Decoder(Decoder)
        Scalar = NextScalar
        Complete = True
    Else
        Decoder.Remaining = Decoder.Remaining - 1
        Decoder.Accumulator = NextScalar
    End If
    FeedUtf8Byte = True
End Function

' True finishes an empty/complete stream. Truncation becomes sticky failure.
' No argument is retained; callers synchronize access to a shared decoder.
Function FinishUtf8Decoder(ByRef Decoder As Utf8Decoder) As Boolean
    FinishUtf8Decoder = False
    If Decoder.Failed Then
        Exit Function
    End If
    If Decoder.Remaining <> 0 Then
        Decoder.Failed = True
        Exit Function
    End If
    FinishUtf8Decoder = True
End Function
