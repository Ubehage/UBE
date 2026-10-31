Function Main() As Long
    Main = 1
    Dim Buffer As ByteBuffer
    Dim Scalars As Long = 99
    If TryCountUtf8Scalars(Buffer, Scalars) = False Or Scalars <> 0 Then
        Print "empty utf8"
        Exit Function
    End If
    If TryAppendByte(Buffer, 255) = False Or ClearByteBuffer(Buffer) = False Then
        Print "retained invalid byte setup"
        Exit Function
    End If
    If TryCountUtf8Scalars(Buffer, Scalars) = False Or Scalars <> 0 Then
        Print "capacity is not logical input"
        Exit Function
    End If
    Dim Input() As Byte
    ReDim Input(10)
    Input(0) = 0
    Input(1) = 65
    Input(2) = 194
    Input(3) = 162
    Input(4) = 226
    Input(5) = 130
    Input(6) = 172
    Input(7) = 240
    Input(8) = 159
    Input(9) = 152
    Input(10) = 128
    If TryAppendBytes(Buffer, Input, 0, 11) = False Or TryCountUtf8Scalars(Buffer, Scalars) = False Or Scalars <> 5 Then
        Print "five scalar utf8"
        Exit Function
    End If
    If ClearByteBuffer(Buffer) = False Or TryAppendByte(Buffer, 194) = False Then
        Print "truncated setup"
        Exit Function
    End If
    Scalars = 99
    If TryCountUtf8Scalars(Buffer, Scalars) Or Scalars <> 0 Then
        Print "truncated accepted"
        Exit Function
    End If
    If TryAppendByte(Buffer, 162) = False Or TryCountUtf8Scalars(Buffer, Scalars) = False Or Scalars <> 1 Then
        Print "validation retains no decoder failure"
        Exit Function
    End If
    If ClearByteBuffer(Buffer) = False Or TryAppendByte(Buffer, 237) = False Or TryAppendByte(Buffer, 160) = False Or TryAppendByte(Buffer, 128) = False Then
        Print "surrogate setup"
        Exit Function
    End If
    Scalars = 99
    If TryCountUtf8Scalars(Buffer, Scalars) Or Scalars <> 0 Then
        Print "surrogate accepted"
        Exit Function
    End If
    Print "PASS byte buffer utf8"
    Main = 0
End Function
