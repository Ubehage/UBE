UBE SOURCE 1 MODULE
Attribute UBE_Name = "StandardStreams"
' Completes counted standard-stream writes through bounded progress operations.

' Writes a validated byte span to stdout or stderr, refusing stalled or impossible progress.
Public Function TryWriteBytes(ByVal Stream As Long, ByRef Source() As Byte, ByVal Start As Long, ByVal Count As Long, ByRef Failure As Long) As Boolean
    Dim Length As Long
    Dim Offset As Long
    Dim Request As Long
    Dim Written As Long
    On Error GoTo Failed
    Failure = 0
    Length = BufferPrimitives.ByteStorageLength(Source)
    If Stream <> 1 And Stream <> 2 Then GoTo InvalidRequest
    If Start < 0 Or Count < 0 Or Start > Length Then GoTo InvalidRequest
    If Count > Length - Start Then GoTo InvalidRequest
    If Count = 0 Then
        TryWriteBytes = SystemPrimitives.TryWriteStandard(Stream, Source, Start, 0, Written, Failure)
        Exit Function
    End If
    Do While Offset < Count
        Request = Count - Offset
        If Request > 65536 Then Request = 65536
        If Not SystemPrimitives.TryWriteStandard(Stream, Source, Start + Offset, Request, Written, Failure) Then Exit Function
        If Written <= 0 Or Written > Request Then
            Failure = 15
            TryWriteBytes = FilePrimitives.SetError(57)
            Exit Function
        End If
        Offset = Offset + Written
    Loop
    TryWriteBytes = True
    Exit Function
InvalidRequest:
    Failure = 1
    TryWriteBytes = FilePrimitives.SetError(5)
    Exit Function
Failed:
    Failure = 1
    TryWriteBytes = False
End Function
