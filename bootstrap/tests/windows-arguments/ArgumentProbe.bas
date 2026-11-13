UBE SOURCE 1 MODULE
Attribute UBE_Name = "ArgumentProbe"
' Observes exact Windows argument bytes, preservation and failure status independently.

' Compares quoted bytes before writing the observed result for the native Windows parser oracle.
Public Function CheckCase(ByRef Source() As Byte, ByVal Start As Long, ByVal Count As Long, ByRef Expected() As Byte, ByRef Path() As Byte, ByVal AliasInput As Boolean) As Long
    Dim Buffer(0 To 95) As Byte
    Dim Used As Long = 1
    Dim Index As Long
    Dim Length As Long
    Dim Status As Boolean
    Dim Token As Long
    Dim Failure As Long
    Buffer(0) = 33
    Buffer(95) = 77
    If AliasInput Then
        Do While Index < BufferPrimitives.ByteStorageLength(Source)
            Buffer(Index + 1) = Source(Index)
            Index = Index + 1
        Loop
    End If
    Status = FilePrimitives.SetError(71)
    If AliasInput Then
        Status = WindowsArguments.TryAppendQuotedArgument(Buffer, Start + 1, Count, Buffer, Used)
    Else
        Status = WindowsArguments.TryAppendQuotedArgument(Source, Start, Count, Buffer, Used)
    End If
    If Not Status Then CheckCase = 1: Exit Function
    Length = BufferPrimitives.ByteStorageLength(Expected)
    If Used <> Length + 1 Then CheckCase = 2: Exit Function
    If Buffer(0) <> 33 Or Buffer(95) <> 77 Then CheckCase = 3: Exit Function
    If Err.Number <> 71 Then CheckCase = 4: Exit Function
    Index = 0
    Do While Index < Length
        If Buffer(Index + 1) <> Expected(Index) Then CheckCase = 5: Exit Function
        Index = Index + 1
    Loop
    If Not FilePrimitives.TryCreateNew(Path, Token, Failure) Then CheckCase = 6: Exit Function
    If Not FileBytes.TryWriteByteRange(Token, Buffer, 1, Length, Failure) Then CheckCase = 7
    If Not FilePrimitives.TryClose(Token, Failure) Then CheckCase = 8
End Function

' Checks an independently parsed argument and its atomic found/value publication.
Public Function CheckRead(ByRef CommandLine() As Byte, ByVal Requested As Long, ByRef Expected() As Byte, ByVal ExpectedFound As Boolean, ByVal AliasInput As Boolean) As Long
    Dim Buffer() As Byte
    Dim Found As Boolean = True
    Dim Status As Boolean
    Dim Index As Long
    Dim Length As Long
    If AliasInput Then
        If Not BufferPrimitives.TryCopyBytes(Buffer, CommandLine) Then CheckRead = 1: Exit Function
    Else
        If Not BufferPrimitives.TryResizeBytes(Buffer, 2, False) Then CheckRead = 2: Exit Function
        Buffer(0) = 65
        Buffer(1) = 66
    End If
    Status = FilePrimitives.SetError(71)
    If AliasInput Then
        Status = WindowsArguments.TryReadArgument(Buffer, Requested, Buffer, Found)
    Else
        Status = WindowsArguments.TryReadArgument(CommandLine, Requested, Buffer, Found)
    End If
    If Not Status Or Found <> ExpectedFound Or Err.Number <> 71 Then CheckRead = 3: Exit Function
    If Not Found Then
        If BufferPrimitives.ByteStorageLength(Buffer) <> 2 Then CheckRead = 4: Exit Function
        If Buffer(0) <> 65 Or Buffer(1) <> 66 Then CheckRead = 5: Exit Function
        Exit Function
    End If
    Length = BufferPrimitives.ByteStorageLength(Expected)
    If BufferPrimitives.ByteStorageLength(Buffer) <> Length Then CheckRead = 6: Exit Function
    Do While Index < Length
        If Buffer(Index) <> Expected(Index) Then CheckRead = 7: Exit Function
        Index = Index + 1
    Loop
End Function

' Uses inline initial storage so injected allocation failures begin inside the parser.
Public Function CheckReadFailure(ByRef CommandLine() As Byte, ByVal Requested As Long, ByVal ExpectedError As Long) As Long
    Dim Buffer(0 To 1) As Byte
    Dim Found As Boolean = True
    Dim Status As Boolean
    Buffer(0) = 65
    Buffer(1) = 66
    Status = FilePrimitives.SetError(71)
    Status = WindowsArguments.TryReadArgument(CommandLine, Requested, Buffer, Found)
    If Status Or Not Found Or Err.Number <> ExpectedError Then CheckReadFailure = 1: Exit Function
    If BufferPrimitives.ByteStorageLength(Buffer) <> 2 Then CheckReadFailure = 2: Exit Function
    If Buffer(0) <> 65 Or Buffer(1) <> 66 Then CheckReadFailure = 3: Exit Function
End Function

' Requires failed appends to retain every destination cell and the previous used count.
Public Function CheckFailure(ByVal Mode As Long) As Long
    Dim Source(0 To 1) As Byte
    Dim Buffer(0 To 5) As Byte
    Dim Start As Long
    Dim Count As Long = 2
    Dim Used As Long = 1
    Dim OriginalUsed As Long
    Dim ExpectedError As Long = 9
    Dim Index As Long
    Dim Status As Boolean
    Source(0) = 65
    Source(1) = 66
    Do While Index < 6
        Buffer(Index) = 90
        Index = Index + 1
    Loop
    If Mode = 0 Then Start = -1: ExpectedError = 5
    If Mode = 1 Then Count = -1: ExpectedError = 5
    If Mode = 2 Then Used = -1: ExpectedError = 5
    If Mode = 3 Then Start = 3
    If Mode = 4 Then Start = 1
    If Mode = 5 Then Used = 7
    If Mode = 6 Then Source(1) = 0: ExpectedError = 5
    If Mode = 7 Then Used = 3
    If Mode = 8 Then Source(0) = 92: Source(1) = 92
    If Mode = 9 Then ExpectedError = 7
    OriginalUsed = Used
    Status = FilePrimitives.SetError(71)
    Status = WindowsArguments.TryAppendQuotedArgument(Source, Start, Count, Buffer, Used)
    If Status Or Used <> OriginalUsed Or Err.Number <> ExpectedError Then CheckFailure = 1: Exit Function
    Index = 0
    Do While Index < 6
        If Buffer(Index) <> 90 Then CheckFailure = 2: Exit Function
        Index = Index + 1
    Loop
End Function
