UBE SOURCE 1 MODULE
Attribute UBE_Name = "FileBytes"
' Implements bounded file progress and publication policy in ordinary UBE source.

' Reads an exact bounded size and probes EOF into private caller scratch; never closes the owner.
Private Function TryReadBuffer(ByVal Token As Long, ByVal Length As Long, ByRef Buffer() As Byte, ByRef Failure As Long) As Boolean
    Dim Probe(0 To 0) As Byte
    Dim Status As Boolean
    Dim Offset As Long
    Dim Progress As Long
    Dim Request As Long
    On Error GoTo RuntimeFailure
    Failure = 0
    If Length < 0 Or Length > 1048576 Then
        Failure = 1
        TryReadBuffer = FilePrimitives.SetError(5)
        Exit Function
    End If
    Status = BufferPrimitives.TryResizeBytes(Buffer, Length, False)
    If Status = False Then Failure = 8: Exit Function
ReadNext:
    If Offset = Length Then GoTo ProbeEnd
    Request = Length - Offset
    If Request > 65536 Then Request = 65536
    Status = FilePrimitives.TryRead(Token, Buffer, Offset, Request, Progress, Failure)
    If Status = False Then Exit Function
    If Progress <= 0 Or Progress > Request Then Failure = 6: TryReadBuffer = FilePrimitives.SetError(57): Exit Function
    Offset = Offset + Progress
    GoTo ReadNext
ProbeEnd:
    Status = FilePrimitives.TryRead(Token, Probe, 0, 1, Progress, Failure)
    If Status = False Then Exit Function
    If Progress <> 0 Then Failure = 11: TryReadBuffer = FilePrimitives.SetError(57): Exit Function
    TryReadBuffer = True
    Exit Function
RuntimeFailure:
    Failure = 1
    Exit Function
End Function

' Reads from an already-open owner and atomically publishes bytes; the caller retains the owner and its position.
Public Function TryReadOpenBytes(ByVal Token As Long, ByVal Length As Long, ByRef Result() As Byte, ByRef Failure As Long) As Boolean
    Dim Buffer() As Byte
    On Error GoTo RuntimeFailure
    If TryReadBuffer(Token, Length, Buffer, Failure) = False Then Exit Function
    If BufferPrimitives.TryCopyBytes(Result, Buffer) = False Then Failure = 8: Exit Function
    TryReadOpenBytes = True
    Exit Function
RuntimeFailure:
    Failure = 1
    Exit Function
End Function

' Attempts one explicit close while preserving any primary failure and retaining unsuccessful ownership.
Public Function TryClosePreservingError(ByRef Token As Long, ByRef Failure As Long) As Boolean
    Dim PrimaryError As Long
    Dim CloseFailure As Long
    Dim Status As Boolean
    PrimaryError = Err.Number
    Status = FilePrimitives.TryClose(Token, CloseFailure)
    If Failure <> 0 Then
        TryClosePreservingError = Status
        Status = FilePrimitives.SetError(PrimaryError)
        Exit Function
    End If
    If Status = False Then Failure = CloseFailure
    TryClosePreservingError = Status
End Function

' Reads at most one MiB through bounded transfers, closes before publication, and retains failed-close ownership.
Public Function TryReadAllBytes(ByRef PathUtf8() As Byte, ByVal MaximumBytes As Long, ByRef Result() As Byte, ByRef Token As Long, ByRef Failure As Long) As Boolean
    Dim Buffer() As Byte
    Dim Status As Boolean
    Dim Length As Long
    Dim EffectiveMaximum As Long
    EffectiveMaximum = MaximumBytes
    If EffectiveMaximum > 1048576 Then EffectiveMaximum = 1048576
    Status = FilePrimitives.TryOpen(PathUtf8, EffectiveMaximum, Token, Length, Failure)
    If Status = False Then TryReadAllBytes = False: Exit Function
    Status = TryReadBuffer(Token, Length, Buffer, Failure)
    If Token <> 0 Then
        Status = TryClosePreservingError(Token, Failure)
        If Status = False Then GoTo Failed
    End If
    If Failure <> 0 Then GoTo Failed
    Status = BufferPrimitives.TryCopyBytes(Result, Buffer)
    If Status = False Then Failure = 8: GoTo Failed
    TryReadAllBytes = True
    Exit Function
Failed:
    TryReadAllBytes = False
    Exit Function
End Function

' Writes a validated logical span through bounded requests without flushing or releasing its owner.
Public Function TryWriteByteRange(ByVal Token As Long, ByRef Source() As Byte, ByVal Start As Long, ByVal Count As Long, ByRef Failure As Long) As Boolean
    Dim Status As Boolean
    Dim Length As Long
    Dim Offset As Long
    Dim Progress As Long
    Dim Request As Long
    On Error GoTo RuntimeFailure
    Length = BufferPrimitives.ByteStorageLength(Source)
    Failure = 0
    If Start < 0 Or Count < 0 Or Start > Length Then GoTo InvalidRequest
    If Count > Length - Start Then GoTo InvalidRequest
    If Count = 0 Then
        TryWriteByteRange = FilePrimitives.TryWrite(Token, Source, Start, 0, Progress, Failure)
        Exit Function
    End If
WriteNext:
    If Offset = Count Then TryWriteByteRange = True: Exit Function
    Request = Count - Offset
    If Request > 65536 Then Request = 65536
    Status = FilePrimitives.TryWrite(Token, Source, Start + Offset, Request, Progress, Failure)
    If Status = False Then TryWriteByteRange = False: Exit Function
    If Progress <= 0 Or Progress > Request Then Failure = 15: TryWriteByteRange = FilePrimitives.SetError(57): Exit Function
    Offset = Offset + Progress
    GoTo WriteNext
InvalidRequest:
    Failure = 1
    TryWriteByteRange = FilePrimitives.SetError(5)
    Exit Function
RuntimeFailure:
    Failure = 1
    TryWriteByteRange = False
End Function

' Writes the complete counted array and flushes only after every byte succeeds.
Public Function TryWriteAllBytes(ByVal Token As Long, ByRef Source() As Byte, ByRef Failure As Long) As Boolean
    Dim Length As Long
    On Error GoTo RuntimeFailure
    Length = BufferPrimitives.ByteStorageLength(Source)
    If TryWriteByteRange(Token, Source, 0, Length, Failure) = False Then TryWriteAllBytes = False: Exit Function
    TryWriteAllBytes = FilePrimitives.TryFlush(Token, Failure)
    Exit Function
RuntimeFailure:
    Failure = 1
    TryWriteAllBytes = False
End Function
