Function Main() As Long
    Main = 1
    Dim Buffer As ByteBuffer
    Dim Empty() As Byte
    Dim Result() As Byte
    ReDim Result(0)
    Result(0) = 91
    If TryAppendByte(Buffer, 65) = False Then
        Print "initial append"
        Exit Function
    End If
    If TryReserveByteBuffer(Buffer, -1) Then
        Print "negative minimum accepted"
        Exit Function
    End If
    If TryAppendBytes(Buffer, Empty, -1, 0) Or TryAppendBytes(Buffer, Empty, 0, -1) Or TryAppendBytes(Buffer, Empty, 1, 0) Or TryAppendBytes(Buffer, Empty, 0, 1) Then
        Print "invalid span accepted"
        Exit Function
    End If
    If ByteBufferLength(Buffer) <> 1 Or ByteBufferCapacity(Buffer) <> 8 Then
        Print "invalid request changed buffer"
        Exit Function
    End If
    Buffer.Count = -1
    If ByteBufferLength(Buffer) <> -1 Or ByteBufferCapacity(Buffer) <> -1 Then
        Print "negative state query"
        Exit Function
    End If
    If TryReserveByteBuffer(Buffer, 0) Or TryAppendByte(Buffer, 66) Or TryAppendBytes(Buffer, Empty, 0, 0) Or ClearByteBuffer(Buffer) Or TrySnapshotByteBuffer(Buffer, Result) Then
        Print "negative state accepted"
        Exit Function
    End If
    Dim Scalars As Long = 99
    If TryCountUtf8Scalars(Buffer, Scalars) Or Scalars <> 0 Then
        Print "negative state validation"
        Exit Function
    End If
    If Buffer.Count <> -1 Or ByteStorageLength(Result) <> 1 Or Result(0) <> 91 Then
        Print "negative rejection changed state"
        Exit Function
    End If
    Buffer.Count = 9
    If ByteBufferLength(Buffer) <> -1 Or TryReserveByteBuffer(Buffer, 16) Or ClearByteBuffer(Buffer) Or TrySnapshotByteBuffer(Buffer, Result) Then
        Print "oversized state accepted"
        Exit Function
    End If
    If Buffer.Count <> 9 Or ByteStorageLength(Buffer.Storage) <> 8 Or Buffer.Storage(0) <> 65 Or Result(0) <> 91 Then
        Print "oversized rejection changed state"
        Exit Function
    End If
    Print "PASS byte buffer rejections"
    Main = 0
End Function
