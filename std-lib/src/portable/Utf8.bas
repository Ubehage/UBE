UBE SOURCE 1 MODULE
Attribute UBE_Name = "Utf8"
' Validates scalar UTF-8 sequences in zero-based counted byte storage without String allocation.

' Returns byte width and UTF-16 width for one scalar; the two output variables must be distinct.
Public Function TrySequenceWidth(ByRef Bytes() As Byte, ByVal Offset As Long, ByVal Length As Long, ByRef ByteWidth As Long, ByRef Utf16Width As Long) As Boolean
    Dim First As Long
    Dim Second As Long
    Dim NextByte As Long
    Dim Index As Long
    Dim Actual As Long
    Dim Endpoint As Long
    On Error GoTo InvalidSequence
    ByteWidth = 0
    Utf16Width = 0
    Actual = BufferPrimitives.ByteStorageLength(Bytes)
    If Length < 0 Or Length > Actual Then TrySequenceWidth = False: Exit Function
    If Offset < 0 Or Offset >= Length Then TrySequenceWidth = False: Exit Function
    Endpoint = Bytes(0)
    Endpoint = Bytes(Actual - 1)
    First = Bytes(Offset)
    If First < 128 Then ByteWidth = 1: Utf16Width = 1: TrySequenceWidth = True: Exit Function
    If First < 194 Or First > 244 Then TrySequenceWidth = False: Exit Function
    ByteWidth = 2
    If First >= 224 Then ByteWidth = 3
    If First >= 240 Then ByteWidth = 4
    If ByteWidth > Length - Offset Then ByteWidth = 0: TrySequenceWidth = False: Exit Function
    Second = Bytes(Offset + 1)
    If First = 224 And Second < 160 Then GoTo InvalidSequence
    If First = 237 And Second > 159 Then GoTo InvalidSequence
    If First = 240 And Second < 144 Then GoTo InvalidSequence
    If First = 244 And Second > 143 Then GoTo InvalidSequence
    Index = 1
    Do While Index < ByteWidth
        NextByte = Bytes(Offset + Index)
        If NextByte < 128 Or NextByte > 191 Then GoTo InvalidSequence
        Index = Index + 1
    Loop
    Utf16Width = 1
    If ByteWidth = 4 Then Utf16Width = 2
    TrySequenceWidth = True
    Exit Function
InvalidSequence:
    ByteWidth = 0
    Utf16Width = 0
    TrySequenceWidth = False
End Function

' Decodes one validated scalar and publishes distinct outputs only after complete success.
Public Function TryDecodeScalar(ByRef Bytes() As Byte, ByVal Offset As Long, ByVal Length As Long, ByRef Scalar As Long, ByRef ByteWidth As Long) As Boolean
    Dim SequenceBytes As Long
    Dim Utf16Width As Long
    Dim Value As Long
    Dim Index As Long
    On Error GoTo Failed
    If Not TrySequenceWidth(Bytes, Offset, Length, SequenceBytes, Utf16Width) Then Exit Function
    Value = Bytes(Offset)
    If SequenceBytes = 2 Then Value = Value - 192
    If SequenceBytes = 3 Then Value = Value - 224
    If SequenceBytes = 4 Then Value = Value - 240
    Index = 1
    Do While Index < SequenceBytes
        Value = (Value * 64) + (Bytes(Offset + Index) - 128)
        Index = Index + 1
    Loop
    Scalar = Value
    ByteWidth = SequenceBytes
    TryDecodeScalar = True
    Exit Function
Failed:
    TryDecodeScalar = False
End Function

' Encodes one Unicode scalar into a validated span without partial destination publication.
Public Function TryEncodeScalar(ByVal Scalar As Long, ByRef Destination() As Byte, ByVal Offset As Long, ByRef ByteWidth As Long) As Boolean
    Dim Scratch(0 To 3) As Byte
    Dim SequenceBytes As Long
    Dim Value As Long
    Dim Index As Long
    Dim Length As Long
    Dim Endpoint As Long
    On Error GoTo Failed
    If Scalar < 0 Or Scalar > 1114111 Then GoTo InvalidScalar
    If Scalar >= 55296 And Scalar <= 57343 Then GoTo InvalidScalar
    SequenceBytes = 1
    If Scalar >= 128 Then SequenceBytes = 2
    If Scalar >= 2048 Then SequenceBytes = 3
    If Scalar >= 65536 Then SequenceBytes = 4
    Length = BufferPrimitives.ByteStorageLength(Destination)
    If Offset < 0 Or Offset > Length Then GoTo InvalidSpan
    If SequenceBytes > Length - Offset Then GoTo InvalidSpan
    Endpoint = Destination(0)
    Endpoint = Destination(Length - 1)
    Value = Scalar
    Index = SequenceBytes - 1
    Do While Index > 0
        Scratch(Index) = 128 + (Value Mod 64)
        Value = Value \ 64
        Index = Index - 1
    Loop
    If SequenceBytes = 2 Then Value = Value + 192
    If SequenceBytes = 3 Then Value = Value + 224
    If SequenceBytes = 4 Then Value = Value + 240
    Scratch(0) = Value
    If Not BufferPrimitives.CopyByteRange(Scratch, 0, Destination, Offset, SequenceBytes) Then Exit Function
    ByteWidth = SequenceBytes
    TryEncodeScalar = True
    Exit Function
InvalidScalar:
    TryEncodeScalar = False
    Exit Function
InvalidSpan:
    TryEncodeScalar = False
    Exit Function
Failed:
    TryEncodeScalar = False
End Function
