UBE SOURCE 1 MODULE
Attribute UBE_Name = "ByteTextProbe"
' Observes exact formatter output and failure publication independently of its implementation.

' Compares the runtime value against independently supplied expected ASCII bytes.
Public Function CheckInteger(ByVal Value As LongLong, ByRef Expected() As Byte) As Long
    Dim Buffer(0 To 23) As Byte
    Dim Used As Long = 1
    Dim Index As Long
    Dim Length As Long
    Dim Status As Boolean
    Buffer(0) = 33
    Buffer(23) = 77
    Status = FilePrimitives.SetError(71)
    Status = ByteText.TryAppendInteger(Buffer, Used, Value)
    If Status = False Then CheckInteger = 1: Exit Function
    Length = BufferPrimitives.ByteStorageLength(Expected)
    If Used <> Length + 1 Then CheckInteger = 2: Exit Function
    If Buffer(0) <> 33 Or Buffer(23) <> 77 Then CheckInteger = 3: Exit Function
    If Err.Number <> 71 Then CheckInteger = 4: Exit Function
    Do While Index < Length
        If Buffer(Index + 1) <> Expected(Index) Then CheckInteger = 5: Exit Function
        Index = Index + 1
    Loop
End Function

' Checks capacity, invalid used counts, shifted bounds and exact-fill publication.
Public Function CheckBounds(ByVal Seed As Long) As Long
    Dim Buffer(0 To 1) As Byte
    Dim Shifted(-1 To 0) As Byte
    Dim EmptyBuffer() As Byte
    Dim Used As Long = 1
    Dim Status As Boolean
    Buffer(0) = 65
    Buffer(1) = 66
    Status = ByteText.TryAppendInteger(Buffer, Used, 123)
    If Status Or Used <> 1 Or Buffer(0) <> 65 Or Buffer(1) <> 66 Or Err.Number <> 9 Then CheckBounds = 1: Exit Function
    Used = -1
    Status = ByteText.TryAppendInteger(Buffer, Used, Seed)
    If Status Or Used <> -1 Or Err.Number <> 5 Then CheckBounds = 2: Exit Function
    Used = 3
    Status = ByteText.TryAppendInteger(Buffer, Used, Seed)
    If Status Or Used <> 3 Or Err.Number <> 9 Then CheckBounds = 3: Exit Function
    Used = 0
    Status = ByteText.TryAppendInteger(Shifted, Used, Seed)
    If Status Or Used <> 0 Or Err.Number <> 9 Then CheckBounds = 4: Exit Function
    Status = ByteText.TryAppendInteger(EmptyBuffer, Used, Seed)
    If Status Or Used <> 0 Or Err.Number <> 9 Then CheckBounds = 5: Exit Function
    Status = ByteText.TryAppendInteger(Buffer, Used, 12)
    If Status = False Or Used <> 2 Or Buffer(0) <> 49 Or Buffer(1) <> 50 Then CheckBounds = 6: Exit Function
End Function

' Exercises range policy with real owners while the harness injects short, zero and failed target writes.
Public Function CheckRange(ByRef Path() As Byte, ByVal Mode As Long) As Long
    Dim Buffer() As Byte
    Dim Token As Long
    Dim Failure As Long
    Dim CloseFailure As Long
    Dim Status As Boolean
    Dim Expected As Boolean = True
    Dim Start As Long = 1
    Dim Count As Long = 3
    Dim Index As Long
    If BufferPrimitives.TryResizeBytes(Buffer, 65540, False) = False Then CheckRange = 1: Exit Function
    Do While Index < 65540
        Buffer(Index) = 7
        Index = Index + 1
    Loop
    If FilePrimitives.TryCreateNew(Path, Token, Failure) = False Then CheckRange = 2: Exit Function
    Status = FilePrimitives.SetError(71)
    If Mode = 0 Then Count = 65537
    If Mode = 1 Then Count = 17
    If Mode = 2 Or Mode = 3 Or Mode = 4 Then Expected = False
    If Mode = 4 Then Start = 65539: Count = 2
    If Mode = 5 Then Start = 65540: Count = 0
    If Mode = 6 Then
        Status = FileBytes.TryWriteAllBytes(Token, Buffer, Failure)
    Else
        Status = FileBytes.TryWriteByteRange(Token, Buffer, Start, Count, Failure)
    End If
    If Status <> Expected Then CheckRange = 3: GoTo Cleanup
    If Expected Then
        If Failure <> 0 Or Err.Number <> 71 Then CheckRange = 4: GoTo Cleanup
    ElseIf Mode = 4 Then
        If Failure <> 1 Or Err.Number <> 5 Then CheckRange = 5: GoTo Cleanup
    Else
        If Failure <> 15 Or Err.Number <> 57 Then CheckRange = 6: GoTo Cleanup
    End If
Cleanup:
    Status = FilePrimitives.TryClose(Token, CloseFailure)
    If Status = False Or Token <> 0 Then CheckRange = 7
End Function
