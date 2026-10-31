Function Main() As Long
    Main = 1
    Dim Buffer As ByteBuffer
    Dim Source() As Byte
    ReDim Source(4)
    Source(0) = 10
    Source(1) = 20
    Source(2) = 30
    Source(3) = 40
    Source(4) = 50
    If TryAppendBytes(Buffer, Source, 1, 3) = False Then
        Print "source slice"
        Exit Function
    End If
    If TryAppendBytes(Buffer, Buffer.Storage, 0, 3) = False Then
        Print "self append without growth"
        Exit Function
    End If
    If ByteBufferLength(Buffer) <> 6 Or ByteBufferCapacity(Buffer) <> 8 Then
        Print "self append length"
        Exit Function
    End If
    If TryAppendBytes(Buffer, Buffer.Storage, 1, 5) = False Then
        Print "self append with growth"
        Exit Function
    End If
    Dim Snapshot() As Byte
    If TrySnapshotByteBuffer(Buffer, Snapshot) = False Then
        Print "overlap snapshot"
        Exit Function
    End If
    If ByteStorageLength(Snapshot) <> 11 Or ByteBufferCapacity(Buffer) <> 16 Then
        Print "overlap bounds"
        Exit Function
    End If
    If Snapshot(0) <> 20 Or Snapshot(1) <> 30 Or Snapshot(2) <> 40 Or Snapshot(3) <> 20 Or Snapshot(4) <> 30 Or Snapshot(5) <> 40 Then
        Print "retained prefix"
        Exit Function
    End If
    If Snapshot(6) <> 30 Or Snapshot(7) <> 40 Or Snapshot(8) <> 20 Or Snapshot(9) <> 30 Or Snapshot(10) <> 40 Then
        Print "original overlapping input"
        Exit Function
    End If
    If TryAppendBytes(Buffer, Source, 5, 0) = False Then
        Print "end empty span"
        Exit Function
    End If
    Dim Empty() As Byte
    If TryAppendBytes(Buffer, Empty, 0, 0) = False Then
        Print "default empty span"
        Exit Function
    End If
    If ByteBufferLength(Buffer) <> 11 Then
        Print "empty append length"
        Exit Function
    End If
    Print "PASS byte buffer overlap"
    Main = 0
End Function
