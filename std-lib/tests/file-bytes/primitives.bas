Function Main() As Long
    Dim Path() As Byte
    Dim Failure As Long = 0
    If TryCommandArgument(0, Path, Failure) = False Then
        Main = 1
        Exit Function
    End If
    Dim Directory() As Byte
    Failure = 8
    If TryCurrentDirectoryBytes(Directory, Failure) = False Then
        Main = 7
        Exit Function
    End If
    If Failure <> 0 Or ByteStorageLength(Directory) < 3 Then
        Main = 7
        Exit Function
    End If
    Dim Token As Long = 0
    Dim Length As Long = 0
    If TryOpenByteFile(Path, 257, Token, Length, Failure) = False Then
        Main = 2
        Exit Function
    End If
    Dim Identity() As Byte
    Dim RepeatedIdentity() As Byte
    Failure = 8
    If TryReadByteFileIdentity(Token, Identity, Failure) = False Then
        Call TryCloseByteFile(Token, Failure)
        Main = 8
        Exit Function
    End If
    If ByteStorageLength(Identity) <> 16 Or Failure <> 0 Then
        Call TryCloseByteFile(Token, Failure)
        Main = 8
        Exit Function
    End If
    Failure = 8
    If TryReadByteFileIdentity(Token, RepeatedIdentity, Failure) = False Then
        Call TryCloseByteFile(Token, Failure)
        Main = 8
        Exit Function
    End If
    Dim IdentityIndex As Long = 0
    While IdentityIndex < 16
        If Identity(IdentityIndex) <> RepeatedIdentity(IdentityIndex) Then
            Call TryCloseByteFile(Token, Failure)
            Main = 8
            Exit Function
        End If
        IdentityIndex = IdentityIndex + 1
    Wend
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
