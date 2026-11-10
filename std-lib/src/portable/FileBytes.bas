UBE SOURCE 1 MODULE
Attribute UBE_Name = "FileBytes"
' Implements bounded file progress and publication policy in ordinary UBE source.

' Reads at most 4096 bytes, closes before publication, and retains failed-close ownership.
Public Function TryReadAllBytes(ByRef PathUtf8() As Byte, ByVal MaximumBytes As Long, ByRef Result() As Byte, ByRef Token As Long, ByRef Failure As Long) As Boolean
    Dim Buffer() As Byte
    Dim Probe(0 To 0) As Byte
    Dim Status As Boolean
    Dim Length As Long
    Dim Offset As Long
    Dim Progress As Long
    Dim CloseFailure As Long
    Dim PrimaryError As Long
    Dim EffectiveMaximum As Long
    EffectiveMaximum = MaximumBytes
    If EffectiveMaximum > 4096 Then EffectiveMaximum = 4096
    Status = FilePrimitives.TryOpen(PathUtf8, EffectiveMaximum, Token, Length, Failure)
    If Status = False Then TryReadAllBytes = False: Exit Function
    Status = BufferPrimitives.TryResizeBytes(Buffer, Length, False)
    If Status = False Then Failure = 8: GoTo Cleanup
ReadNext:
    If Offset = Length Then GoTo ProbeEnd
    Status = FilePrimitives.TryRead(Token, Buffer, Offset, Length + -Offset, Progress, Failure)
    If Status = False Then GoTo Cleanup
    If Progress = 0 Then Failure = 6: Status = FilePrimitives.SetError(57): GoTo Cleanup
    Offset = Offset + Progress
    GoTo ReadNext
ProbeEnd:
    Status = FilePrimitives.TryRead(Token, Probe, 0, 1, Progress, Failure)
    If Status = False Then GoTo Cleanup
    If Progress <> 0 Then Failure = 11: Status = FilePrimitives.SetError(57): GoTo Cleanup
Cleanup:
    PrimaryError = Err.Number
    If Token = 0 Then GoTo AfterClose
    Status = FilePrimitives.TryClose(Token, CloseFailure)
    If Failure <> 0 Then GoTo RestorePrimary
    If Status = False Then Failure = CloseFailure: GoTo Failed
AfterClose:
    If Failure <> 0 Then GoTo Failed
    Status = BufferPrimitives.TryCopyBytes(Result, Buffer)
    If Status = False Then Failure = 8: GoTo Failed
    TryReadAllBytes = True
    Exit Function
RestorePrimary:
    Status = FilePrimitives.SetError(PrimaryError)
Failed:
    TryReadAllBytes = False
    Exit Function
End Function

' Advances only by confirmed writes, rejects zero progress, and flushes the explicit owner.
Public Function TryWriteAllBytes(ByVal Token As Long, ByRef Source() As Byte, ByRef Failure As Long) As Boolean
    Dim Status As Boolean
    Dim Length As Long
    Dim Offset As Long
    Dim Progress As Long
    Length = BufferPrimitives.ByteStorageLength(Source)
    Failure = 0
WriteNext:
    If Offset = Length Then GoTo FlushOutput
    Status = FilePrimitives.TryWrite(Token, Source, Offset, Length + -Offset, Progress, Failure)
    If Status = False Then TryWriteAllBytes = False: Exit Function
    If Progress = 0 Then Failure = 15: TryWriteAllBytes = FilePrimitives.SetError(57): Exit Function
    Offset = Offset + Progress
    GoTo WriteNext
FlushOutput:
    TryWriteAllBytes = FilePrimitives.TryFlush(Token, Failure)
End Function
