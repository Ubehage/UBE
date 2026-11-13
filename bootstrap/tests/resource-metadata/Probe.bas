UBE SOURCE 1 MODULE
Attribute UBE_Name = "MetadataProbe"
' Observes metadata on existing owners, directory admission and process-local system values.
Public Function Main() As Long
    Dim NameA(0 To 4) As Byte
    Dim NameB(0 To 4) As Byte
    Dim NameC(0 To 4) As Byte
    Dim Dot(0 To 0) As Byte
    Dim Value(0 To 0) As Byte
    Dim IdentityA(5 To 16) As Byte
    Dim IdentityB(9 To 20) As Byte
    Dim Path() As Byte
    Dim TokenA As Long
    Dim TokenB As Long
    Dim TokenC As Long
    Dim DirectoryToken As Long
    Dim Length As Long
    Dim Count As Long
    Dim Failure As Long
    Dim Index As Long
    Dim FirstTick As LongLong
    Dim SecondTick As LongLong
    Dim Status As Boolean
    On Error GoTo Failed
    NameA(0) = 97: NameA(1) = 46: NameA(2) = 98: NameA(3) = 105: NameA(4) = 110
    NameB = NameA: NameB(0) = 98
    NameC = NameA: NameC(0) = 99
    Dot(0) = 46
    If Not BufferPrimitives.TryResizeBytes(Path, 4096, False) Then Main = 1: Exit Function
    Status = FilePrimitives.SetError(678)
    If Not SystemPrimitives.TryMonotonicMilliseconds(FirstTick, Failure) Then Main = 2: Exit Function
    If Not SystemPrimitives.TryMonotonicMilliseconds(SecondTick, Failure) Then Main = 3: Exit Function
    If FirstTick < 0 Or SecondTick < FirstTick Or Failure <> 0 Or Err.Number <> 678 Then Main = 4: Exit Function
    If Not FilePrimitives.TryOpenDirectory(Dot, DirectoryToken, Failure) Then Main = 5: GoTo Cleanup
    If Not FilePrimitives.TryFinalPath(DirectoryToken, Path, Count, Failure) Then Main = 6: GoTo Cleanup
    If Count < 5 Or Path(0) <> 92 Then Main = 7: GoTo Cleanup
    If Not FilePrimitives.TryIdentity(DirectoryToken, IdentityB, Failure) Then Main = 8: GoTo Cleanup
    Length = 81
    If FilePrimitives.TryLength(DirectoryToken, Length, Failure) Then Main = 9: GoTo Cleanup
    If Length <> 81 Or Failure <> 9 Then Main = 10: GoTo Cleanup
    If FilePrimitives.TryRead(DirectoryToken, Value, 0, 1, Count, Failure) Then Main = 11: GoTo Cleanup
    If Failure <> 9 Then Main = 12: GoTo Cleanup
    If Not FilePrimitives.TryClose(DirectoryToken, Failure) Then Main = 13: GoTo Cleanup
    If Not FilePrimitives.TryOpen(NameA, 10, TokenA, Length, Failure) Then Main = 14: GoTo Cleanup
    If Not FilePrimitives.TryOpen(NameB, 10, TokenB, Length, Failure) Then Main = 15: GoTo Cleanup
    If Not FilePrimitives.TryIdentity(TokenA, IdentityA, Failure) Then Main = 16: GoTo Cleanup
    If Not FilePrimitives.TryIdentity(TokenB, IdentityB, Failure) Then Main = 17: GoTo Cleanup
    Do While Index < 12
        If IdentityA(Index + 5) <> IdentityB(Index + 9) Then Main = 18: GoTo Cleanup
        Index = Index + 1
    Loop
    If Not FilePrimitives.TryLength(TokenA, Length, Failure) Then Main = 19: GoTo Cleanup
    If Length <> 1 Then Main = 20: GoTo Cleanup
    If Not FilePrimitives.TryRead(TokenA, Value, 0, 1, Count, Failure) Then Main = 21: GoTo Cleanup
    If Count <> 1 Or Value(0) <> 42 Then Main = 22: GoTo Cleanup
    If Not FilePrimitives.TryCreateNew(NameC, TokenC, Failure) Then Main = 23: GoTo Cleanup
    If Not FilePrimitives.TryLength(TokenC, Length, Failure) Then Main = 24: GoTo Cleanup
    If Length <> 0 Then Main = 25: GoTo Cleanup
    If Not FilePrimitives.TryIdentity(TokenC, IdentityB, Failure) Then Main = 26: GoTo Cleanup
    If Not FilePrimitives.TryWrite(TokenC, Value, 0, 1, Count, Failure) Then Main = 27: GoTo Cleanup
    If Not FilePrimitives.TryLength(TokenC, Length, Failure) Then Main = 28: GoTo Cleanup
    If Length <> 1 Then Main = 29: GoTo Cleanup
    Status = FilePrimitives.SetError(345)
    If Not SystemPrimitives.TryExecutablePath(Path, Count, Failure) Then Main = 30: GoTo Cleanup
    If Count < 1 Or Count > 4096 Or Failure <> 0 Or Err.Number <> 345 Then Main = 31: GoTo Cleanup
    If Not StandardStreams.TryWriteBytes(1, Path, 0, Count, Failure) Then Main = 32: GoTo Cleanup
Cleanup:
    If Not FilePrimitives.TryClose(TokenA, Failure) Then Main = 40
    If Not FilePrimitives.TryClose(TokenB, Failure) Then Main = 41
    If Not FilePrimitives.TryClose(TokenC, Failure) Then Main = 42
    If Not FilePrimitives.TryClose(DirectoryToken, Failure) Then Main = 43
    Exit Function
Failed:
    Main = 90
    GoTo Cleanup
End Function
