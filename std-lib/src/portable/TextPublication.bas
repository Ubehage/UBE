UBE SOURCE 1 MODULE
Attribute UBE_Name = "TextPublication"
' Installed support validates a private candidate before the raw publication barrier.
Private Intrinsic Function Commit(ByRef Destination As String, ByVal Candidate As LongLong) As Boolean
Attribute Commit.UBE_Primitive = "Text.Commit"
End Function

Private Intrinsic Function RecordError(ByVal Number As Long) As Boolean
Attribute RecordError.UBE_Primitive = "Error.Set"
End Function

Public Function Publish(ByRef Destination As String, ByVal Candidate As LongLong) As Boolean
    Dim Bytes(0 To 3) As Byte
    Dim ByteCount As LongLong
    Dim ScalarCount As LongLong
    Dim Position As LongLong
    Dim ActualScalars As LongLong
    Dim Available As Long
    Dim Index As Long
    Dim Scalar As Long
    Dim SequenceWidth As Long
    On Error GoTo Failed
    If Not TextPrimitives.TryCandidateInfo(Candidate, ByteCount, ScalarCount) Then Exit Function
    Do While Position < ByteCount
        Available = 4
        If ByteCount - Position < 4 Then Available = ByteCount - Position
        Index = 0
        Do While Index < Available
            If Not TextPrimitives.TryReadCandidateByte(Candidate, Position + Index, Bytes(Index)) Then Exit Function
            Index = Index + 1
        Loop
        If Not Utf8.TryDecodeScalar(Bytes, 0, Available, Scalar, SequenceWidth) Then GoTo InvalidText
        Position = Position + SequenceWidth
        ActualScalars = ActualScalars + 1
    Loop
    If ActualScalars <> ScalarCount Then GoTo InvalidText
    Publish = Commit(Destination, Candidate)
    Exit Function
InvalidText:
    Call RecordError(13)
Failed:
End Function
