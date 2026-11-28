UBE SOURCE 1 MODULE
Attribute UBE_Name = "PublicationProbe"
Private WorkerResult As Long

Private Function RejectBytes(ByVal A As Byte, ByVal B As Byte, ByVal C As Byte, ByVal D As Byte, ByVal Count As LongLong, ByVal Scalars As LongLong) As Boolean
    Dim Candidate As LongLong
    Dim Value As String = "prior"
    Dim Bytes As LongLong
    Dim Actual As LongLong
    On Error GoTo Failed
    If Not TextPrimitives.TryCreate(Count, Scalars, Candidate) Then Exit Function
    If Not TextPrimitives.TryWriteByte(Candidate, 0, A) Then Exit Function
    If Count > 1 Then
        If Not TextPrimitives.TryWriteByte(Candidate, 1, B) Then Exit Function
    End If
    If Count > 2 Then
        If Not TextPrimitives.TryWriteByte(Candidate, 2, C) Then Exit Function
    End If
    If Count > 3 Then
        If Not TextPrimitives.TryWriteByte(Candidate, 3, D) Then Exit Function
    End If
    Err.Clear
    If TextPrimitives.TryPublish(Value, Candidate) Then Exit Function
    If Err.Number <> 13 Or Value <> "prior" Then Exit Function
    If Not TextPrimitives.TryCandidateInfo(Candidate, Bytes, Actual) Then Exit Function
    If Bytes <> Count Or Actual <> Scalars Then Exit Function
    If Not TextPrimitives.TryAbandon(Candidate) Then Exit Function
    RejectBytes = True
Failed:
End Function

Private Sub ForeignCandidate(ByVal Candidate As LongLong)
    Dim Value As String = "worker"
    Dim ByteCount As LongLong
    Dim Scalars As LongLong
    Dim Item As Byte
    If TextPrimitives.TryCandidateInfo(Candidate, ByteCount, Scalars) Then Exit Sub
    If Err.Number <> 5 Then Exit Sub
    If TextPrimitives.TryReadCandidateByte(Candidate, 0, Item) Then Exit Sub
    If TextPrimitives.TryWriteByte(Candidate, 0, 65) Then Exit Sub
    If TextPrimitives.TryPublish(Value, Candidate) Then Exit Sub
    If Value <> "worker" Then Exit Sub
    If TextPrimitives.TryAbandon(Candidate) Then Exit Sub
    WorkerResult = 1
End Sub

Public Function Main() As Long
    Dim Candidate As LongLong
    Dim Value As String = "prior"
    Dim Bytes As LongLong
    Dim Scalars As LongLong
    Dim Item As Byte
    Dim Worker As LongLong
    Dim Utf8Bytes(0 To 2) As Byte
    On Error GoTo Failed
    If Not RejectBytes(255, 0, 0, 0, 1, 1) Then Main = 1: Exit Function
    If Not RejectBytes(192, 128, 0, 0, 2, 1) Then Main = 2: Exit Function
    If Not RejectBytes(237, 160, 128, 0, 3, 1) Then Main = 3: Exit Function
    If Not RejectBytes(244, 144, 128, 128, 4, 1) Then Main = 4: Exit Function
    If Not RejectBytes(226, 130, 0, 0, 2, 1) Then Main = 5: Exit Function
    If Not RejectBytes(65, 66, 0, 0, 2, 1) Then Main = 6: Exit Function
    If Not TextPrimitives.TryCreate(1, 1, Candidate) Then Main = 10: Exit Function
    If Not TextPrimitives.TryWriteByte(Candidate, 0, 255) Then Main = 11: Exit Function
    If TextPrimitives.TryPublish(Value, Candidate) Then Main = 12: Exit Function
    If Not TextPrimitives.TryWriteByte(Candidate, 0, 65) Then Main = 13: Exit Function
    Worker = CallNew ForeignCandidate(Candidate)
    If ThreadPrimitives.Wait(Worker, -1) <> 1 Or WorkerResult <> 1 Then Main = 14: Exit Function
    If Not TextPrimitives.TryPublish(Value, Candidate) Then Main = 15: Exit Function
    If Value <> "A" Then Main = 16: Exit Function
    If TextPrimitives.TryPublish(Value, Candidate) Then Main = 17: Exit Function
    If TextPrimitives.TryWriteByte(Candidate, 0, 66) Then Main = 18: Exit Function
    If Value <> "A" Then Main = 19: Exit Function
    If Not TextPrimitives.TryCreate(1, 1, Candidate) Then Main = 20: Exit Function
    If Not TextPrimitives.TryAbandon(Candidate) Then Main = 21: Exit Function
    If TextPrimitives.TryCandidateInfo(Candidate, Bytes, Scalars) Then Main = 22: Exit Function
    If TextPrimitives.TryPublish(Value, Candidate) Then Main = 23: Exit Function
    If Not TextPrimitives.TryCreate(5, 2, Candidate) Then Main = 30: Exit Function
    If Not TextPrimitives.TryWriteByte(Candidate, 4, 0) Then Main = 31: Exit Function
    If Not TextPrimitives.TryWriteByte(Candidate, 3, 128) Then Main = 32: Exit Function
    If Not TextPrimitives.TryWriteByte(Candidate, 2, 152) Then Main = 33: Exit Function
    If Not TextPrimitives.TryWriteByte(Candidate, 1, 159) Then Main = 34: Exit Function
    If Not TextPrimitives.TryWriteByte(Candidate, 0, 240) Then Main = 35: Exit Function
    If Not TextPrimitives.TryPublish(Value, Candidate) Then Main = 36: Exit Function
    If TextPrimitives.ByteLength(Value) <> 5 Or TextPrimitives.ScalarLength(Value) <> 2 Then Main = 37: Exit Function
    If Not TextPrimitives.TryReadByte(Value, 4, Item) Or Item <> 0 Then Main = 38: Exit Function
    Utf8Bytes(0) = 226: Utf8Bytes(1) = 130: Utf8Bytes(2) = 172
    Value = Text.FromUtf8(Utf8Bytes, 0, 3)
    If Text.Length(Value) <> 1 Then Main = 40: Exit Function
    If Not TextPrimitives.TryPublish(Value, 0) Or Value <> "" Then Main = 41: Exit Function
    Exit Function
Failed:
    Main = 99
End Function
