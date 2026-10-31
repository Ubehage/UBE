Function Main() As Long
    Dim Path() As Byte
    Dim Failure As Long = 0
    If TryCommandArgument(0, Path, Failure) = False Then
        Main = 1
        Exit Function
    End If
    Dim Token As Long = 0
    Dim Length As Long = 0
    If TryOpenByteFile(Path, 257, Token, Length, Failure) = False Then
        Main = 2
        Exit Function
    End If
    Dim Bytes() As Byte
    If TryResizeByteStorage(Bytes, 257, False) = False Then
        Call TryCloseByteFile(Token, Failure)
        Main = 3
        Exit Function
    End If
    Dim Got As Long = 0
    Dim Success As Boolean = TryReadByteFile(Token, Bytes, 0, 257, Got, Failure)
    Dim Closed As Boolean = TryCloseByteFile(Token, Failure)
    If Success = False Or Closed = False Or Got <> 257 Or Length <> 257 Or Token <> 0 Then
        Main = 4
        Exit Function
    End If
    Dim Index As Long = 0
    While Index < 256
        If Bytes(Index) <> Index Then
            Main = 5
            Exit Function
        End If
        Index = Index + 1
    Wend
    If Bytes(256) <> 0 Then
        Main = 6
        Exit Function
    End If
    Print "file primitives"
    Main = 0
End Function
