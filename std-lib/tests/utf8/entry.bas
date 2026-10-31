' Test-only calls exercise ordinary UBE record assignment and ByVal copying.
Sub CopyDecoder(ByRef Destination As Utf8Decoder, ByRef Source As Utf8Decoder)
    Destination = Source
End Sub

Sub DisturbDecoder(ByVal Value As Utf8Decoder)
    Call ResetUtf8Decoder(Value)
End Sub

Sub CorruptDecoder(ByRef Value As Utf8Decoder, ByVal Which As Long)
    Call ResetUtf8Decoder(Value)
    If Which = 0 Then
        Value.Remaining = -1
    End If
    If Which = 1 Then
        Value.Remaining = 4
    End If
    If Which = 2 Then
        Value.Accumulator = -1
    End If
    If Which = 3 Then
        Value.Accumulator = 2147483647
    End If
    If Which = 4 Then
        Value.Remaining = 1
        Value.MinimumScalar = -1
    End If
End Sub

Function Main() As Long
    Main = 0
End Function
