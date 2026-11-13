UBE SOURCE 1 MODULE
Attribute UBE_Name = "UnicodeScalarProbe"
' Checks scalar codecs independently, then exports every valid scalar for a host byte oracle.

Private Sub SeedError()
    Err.Raise 77
End Sub

Private Function Vector(ByVal Scalar As Long, ByVal SequenceBytes As Long, ByVal A As Byte, ByVal B As Byte, ByVal C As Byte, ByVal D As Byte) As Boolean
    Dim Bytes(0 To 5) As Byte
    Dim Written As Long = 91
    Dim Decoded As Long = -1
    Dim Read As Long = 92
    Bytes(0) = 42
    Bytes(1) = 42
    Bytes(2) = 42
    Bytes(3) = 42
    Bytes(4) = 42
    Bytes(5) = 42
    SeedError
    If Not Utf8.TryEncodeScalar(Scalar, Bytes, 1, Written) Then Exit Function
    If Written <> SequenceBytes Or Err.Number <> 77 Then Exit Function
    If Bytes(0) <> 42 Or Bytes(5) <> 42 Then Exit Function
    If Bytes(1) <> A Then Exit Function
    If SequenceBytes > 1 Then
        If Bytes(2) <> B Then Exit Function
    Else
        If Bytes(2) <> 42 Then Exit Function
    End If
    If SequenceBytes > 2 Then
        If Bytes(3) <> C Then Exit Function
    Else
        If Bytes(3) <> 42 Then Exit Function
    End If
    If SequenceBytes > 3 Then
        If Bytes(4) <> D Then Exit Function
    Else
        If Bytes(4) <> 42 Then Exit Function
    End If
    If Not Utf8.TryDecodeScalar(Bytes, 1, 1 + SequenceBytes, Decoded, Read) Then Exit Function
    Vector = Decoded = Scalar And Read = SequenceBytes And Err.Number = 77
End Function

Private Function InvalidSequence(ByVal A As Byte, ByVal B As Byte, ByVal C As Byte, ByVal D As Byte, ByVal Length As Long) As Boolean
    Dim Bytes(0 To 3) As Byte
    Dim Scalar As Long = 123
    Dim SequenceBytes As Long = 456
    Dim Accepted As Boolean = True
    Bytes(0) = A
    Bytes(1) = B
    Bytes(2) = C
    Bytes(3) = D
    SeedError
    On Error GoTo Failed
    Accepted = Utf8.TryDecodeScalar(Bytes, 0, Length, Scalar, SequenceBytes)
    InvalidSequence = Not Accepted And Scalar = 123 And SequenceBytes = 456 And Err.Number = 77
    Exit Function
Failed:
    InvalidSequence = False
End Function

Private Function RejectedEncode(ByVal Scalar As Long, ByVal Offset As Long) As Boolean
    Dim Bytes(0 To 3) As Byte
    Dim SequenceBytes As Long = 456
    Dim Accepted As Boolean = True
    Bytes(0) = 42
    Bytes(1) = 43
    Bytes(2) = 44
    Bytes(3) = 45
    SeedError
    On Error GoTo Failed
    Accepted = Utf8.TryEncodeScalar(Scalar, Bytes, Offset, SequenceBytes)
    If Accepted Or SequenceBytes <> 456 Or Err.Number <> 77 Then Exit Function
    RejectedEncode = Bytes(0) = 42 And Bytes(1) = 43 And Bytes(2) = 44 And Bytes(3) = 45
    Exit Function
Failed:
    RejectedEncode = False
End Function

Private Function Bounds() As Boolean
    Dim Bytes(0 To 3) As Byte
    Dim Positive(1 To 4) As Byte
    Dim Negative(-1 To 2) As Byte
    Dim EmptyBytes() As Byte
    Dim Scalar As Long = 123
    Dim SequenceBytes As Long = 456
    SeedError
    If Utf8.TryDecodeScalar(Bytes, -1, 4, Scalar, SequenceBytes) Then Exit Function
    If Utf8.TryDecodeScalar(Bytes, 4, 4, Scalar, SequenceBytes) Then Exit Function
    If Utf8.TryDecodeScalar(Bytes, 0, -1, Scalar, SequenceBytes) Then Exit Function
    If Utf8.TryDecodeScalar(Bytes, 0, 5, Scalar, SequenceBytes) Then Exit Function
    If Utf8.TryDecodeScalar(EmptyBytes, 0, 0, Scalar, SequenceBytes) Then Exit Function
    If Utf8.TryEncodeScalar(65, EmptyBytes, 0, SequenceBytes) Then Exit Function
    If Scalar <> 123 Or SequenceBytes <> 456 Or Err.Number <> 77 Then Exit Function
    If Utf8.TryDecodeScalar(Positive, 0, 4, Scalar, SequenceBytes) Then Exit Function
    If Err.Number <> 9 Then Exit Function
    SeedError
    If Utf8.TryDecodeScalar(Negative, 0, 4, Scalar, SequenceBytes) Then Exit Function
    If Err.Number <> 9 Then Exit Function
    SeedError
    If Utf8.TryEncodeScalar(65, Positive, 0, SequenceBytes) Then Exit Function
    If Err.Number <> 9 Or Positive(1) <> 0 Then Exit Function
    SeedError
    If Utf8.TryEncodeScalar(65, Negative, 0, SequenceBytes) Then Exit Function
    Bounds = Err.Number = 9 And Negative(0) = 0 And Scalar = 123 And SequenceBytes = 456
End Function

' Writes utf8.bin in bounded chunks; every decoded scalar must equal the independent counter.
Private Function Exhaustive() As Long
    Dim Path(0 To 7) As Byte
    Dim Bytes() As Byte
    Dim Token As Long
    Dim Failure As Long
    Dim Scalar As Long
    Dim Count As Long
    Dim SequenceBytes As Long
    Dim Decoded As Long
    Dim Read As Long
    Dim Status As Long = 91
    On Error GoTo Failed
    Path(0) = 117
    Path(1) = 116
    Path(2) = 102
    Path(3) = 56
    Path(4) = 46
    Path(5) = 98
    Path(6) = 105
    Path(7) = 110
    If Not BufferPrimitives.TryResizeBytes(Bytes, 65536, False) Then GoTo Failed
    If Not FilePrimitives.TryCreateNew(Path, Token, Failure) Then GoTo Failed
    Do While Scalar <= 1114111
        If Scalar = 55296 Then Scalar = 57344
        If Count > 65532 Then
            If Not FileBytes.TryWriteByteRange(Token, Bytes, 0, Count, Failure) Then GoTo Failed
            Count = 0
        End If
        If Not Utf8.TryEncodeScalar(Scalar, Bytes, Count, SequenceBytes) Then GoTo Failed
        If Not Utf8.TryDecodeScalar(Bytes, Count, Count + SequenceBytes, Decoded, Read) Then GoTo Failed
        If Decoded <> Scalar Or Read <> SequenceBytes Then GoTo Failed
        Count = Count + SequenceBytes
        Scalar = Scalar + 1
    Loop
    If Not FileBytes.TryWriteByteRange(Token, Bytes, 0, Count, Failure) Then GoTo Failed
    If Not FilePrimitives.TryFlush(Token, Failure) Then GoTo Failed
    Status = 0
Failed:
    If Token <> 0 Then
        If Not FilePrimitives.TryClose(Token, Failure) Then Status = 92
    End If
    Exhaustive = Status
End Function

Public Function Main() As Long
    If Not Vector(0, 1, 0, 0, 0, 0) Then Main = 1: Exit Function
    If Not Vector(127, 1, 127, 0, 0, 0) Then Main = 2: Exit Function
    If Not Vector(128, 2, 194, 128, 0, 0) Then Main = 3: Exit Function
    If Not Vector(2047, 2, 223, 191, 0, 0) Then Main = 4: Exit Function
    If Not Vector(2048, 3, 224, 160, 128, 0) Then Main = 5: Exit Function
    If Not Vector(55295, 3, 237, 159, 191, 0) Then Main = 6: Exit Function
    If Not Vector(57344, 3, 238, 128, 128, 0) Then Main = 7: Exit Function
    If Not Vector(65535, 3, 239, 191, 191, 0) Then Main = 8: Exit Function
    If Not Vector(65536, 4, 240, 144, 128, 128) Then Main = 9: Exit Function
    If Not Vector(128512, 4, 240, 159, 152, 128) Then Main = 10: Exit Function
    If Not Vector(1114111, 4, 244, 143, 191, 191) Then Main = 11: Exit Function
    If Not InvalidSequence(128, 0, 0, 0, 1) Then Main = 12: Exit Function
    If Not InvalidSequence(192, 128, 0, 0, 2) Then Main = 13: Exit Function
    If Not InvalidSequence(193, 191, 0, 0, 2) Then Main = 14: Exit Function
    If Not InvalidSequence(224, 159, 191, 0, 3) Then Main = 15: Exit Function
    If Not InvalidSequence(237, 160, 128, 0, 3) Then Main = 16: Exit Function
    If Not InvalidSequence(240, 143, 191, 191, 4) Then Main = 17: Exit Function
    If Not InvalidSequence(244, 144, 128, 128, 4) Then Main = 18: Exit Function
    If Not InvalidSequence(245, 128, 128, 128, 4) Then Main = 19: Exit Function
    If Not InvalidSequence(255, 0, 0, 0, 1) Then Main = 20: Exit Function
    If Not InvalidSequence(194, 127, 0, 0, 2) Then Main = 21: Exit Function
    If Not InvalidSequence(224, 160, 255, 0, 3) Then Main = 22: Exit Function
    If Not InvalidSequence(240, 144, 128, 127, 4) Then Main = 23: Exit Function
    If Not InvalidSequence(194, 128, 0, 0, 1) Then Main = 24: Exit Function
    If Not InvalidSequence(224, 160, 128, 0, 2) Then Main = 25: Exit Function
    If Not InvalidSequence(240, 144, 128, 128, 3) Then Main = 26: Exit Function
    If Not RejectedEncode(-1, 0) Then Main = 27: Exit Function
    If Not RejectedEncode(55296, 0) Then Main = 28: Exit Function
    If Not RejectedEncode(57343, 0) Then Main = 29: Exit Function
    If Not RejectedEncode(1114112, 0) Then Main = 30: Exit Function
    If Not RejectedEncode(65, -1) Then Main = 31: Exit Function
    If Not RejectedEncode(65, 4) Then Main = 32: Exit Function
    If Not RejectedEncode(128, 3) Then Main = 33: Exit Function
    If Not RejectedEncode(65536, 1) Then Main = 34: Exit Function
    If Not Bounds() Then Main = 35: Exit Function
    Main = Exhaustive()
End Function
