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
