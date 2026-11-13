UBE SOURCE 1 MODULE
Attribute UBE_Name = "OpenFileProbe"
' Observes already-open byte reads without hiding owner lifetime in the reader.

' Checks exact bytes/status and proves the owner remains usable until caller close.
Public Function CheckRead(ByRef Path() As Byte, ByRef Expected() As Byte, ByVal SizeAdjustment As Long, ByVal ExpectedFailure As Long) As Long
    Dim Token As Long
    Dim PreviousToken As Long
    Dim Length As Long
    Dim Failure As Long
    Dim CloseFailure As Long
    Dim Progress As Long
    Dim Index As Long
    Dim Status As Boolean
    Dim Result(0 To 1) As Byte
    Dim Probe(0 To 0) As Byte
    On Error GoTo Failed
    Result(0) = 73
    Result(1) = 74
    If FilePrimitives.TryOpen(Path, 1048576, Token, Length, Failure) = False Then CheckRead = 1: GoTo Cleanup
    PreviousToken = Token
    Status = FilePrimitives.SetError(91)
    Status = FileBytes.TryReadOpenBytes(Token, Length + SizeAdjustment, Result, Failure)
    If Token <> PreviousToken Then CheckRead = 2: GoTo Cleanup
    If Failure <> ExpectedFailure Then CheckRead = 3: GoTo Cleanup
    If ExpectedFailure <> 0 Then
        If Status Then CheckRead = 4: GoTo Cleanup
        If BufferPrimitives.ByteStorageLength(Result) <> 2 Then CheckRead = 5: GoTo Cleanup
        If Result(0) <> 73 Or Result(1) <> 74 Then CheckRead = 6: GoTo Cleanup
        If ExpectedFailure = 8 And Err.Number <> 7 Then CheckRead = 7: GoTo Cleanup
    Else
        If Status = False Or Err.Number <> 91 Then CheckRead = 8: GoTo Cleanup
        If BufferPrimitives.ByteStorageLength(Result) <> BufferPrimitives.ByteStorageLength(Expected) Then CheckRead = 9: GoTo Cleanup
        Do While Index < BufferPrimitives.ByteStorageLength(Expected)
            If Result(Index) <> Expected(Index) Then CheckRead = 10: GoTo Cleanup
            Index = Index + 1
        Loop
    End If
    If FilePrimitives.TryRead(Token, Probe, 0, 0, Progress, Failure) = False Then CheckRead = 11: GoTo Cleanup
    If Progress <> 0 Then CheckRead = 12
Cleanup:
    If FilePrimitives.TryClose(Token, CloseFailure) = False Then CheckRead = 13
    Exit Function
Failed:
    CheckRead = 14
    GoTo Cleanup
End Function

