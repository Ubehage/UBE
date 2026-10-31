Sub ChangeIndependentCopy(ByVal Buffer As ByteBuffer)
    Dim Cleared As Boolean = ClearByteBuffer(Buffer)
    Dim Appended As Boolean = TryAppendByte(Buffer, 77)
End Sub

Function Main() As Long
    Main = 1
    Dim Buffer As ByteBuffer
    If ByteBufferLength(Buffer) <> 0 Or ByteBufferCapacity(Buffer) <> 0 Then
        Print "zero state"
        Exit Function
    End If
    If TryReserveByteBuffer(Buffer, 0) = False Then
        Print "zero reserve"
        Exit Function
    End If
    Dim Index As Long = 0
    While Index < 256
        If TryAppendByte(Buffer, Index) = False Then
            Print "append byte"
            Exit Function
        End If
        If Index = 0 Or Index = 7 Then
            If ByteBufferCapacity(Buffer) <> 8 Then
                Print "capacity eight"
                Exit Function
            End If
        End If
        If Index = 8 Or Index = 15 Then
            If ByteBufferCapacity(Buffer) <> 16 Then
                Print "capacity sixteen"
                Exit Function
            End If
        End If
        If Index = 16 Then
            If ByteBufferCapacity(Buffer) <> 32 Then
                Print "capacity thirty-two"
                Exit Function
            End If
        End If
        Index = Index + 1
    Wend
    If ByteBufferLength(Buffer) <> 256 Or ByteBufferCapacity(Buffer) <> 256 Then
        Print "full byte domain"
        Exit Function
    End If
    Dim Snapshot() As Byte
    If TrySnapshotByteBuffer(Buffer, Snapshot) = False Then
        Print "snapshot"
        Exit Function
    End If
    If ByteStorageLength(Snapshot) <> 256 Then
        Print "snapshot length"
        Exit Function
    End If
    Index = 0
    While Index < 256
        If Snapshot(Index) <> Index Then
            Print "snapshot bytes"
            Exit Function
        End If
        Index = Index + 1
    Wend
    Dim Independent As ByteBuffer
    Independent = Buffer
    Call ChangeIndependentCopy(Buffer)
    If ByteBufferLength(Buffer) <> 256 Or Buffer.Storage(0) <> 0 Then
        Print "ByVal ownership"
        Exit Function
    End If
    If ClearByteBuffer(Independent) = False Then
        Print "clear independent"
        Exit Function
    End If
    If TryAppendByte(Independent, 88) = False Then
        Print "reuse independent"
        Exit Function
    End If
    If ClearByteBuffer(Buffer) = False Or ByteBufferCapacity(Buffer) <> 256 Then
        Print "clear capacity"
        Exit Function
    End If
    If TryAppendByte(Buffer, 99) = False Then
        Print "reuse buffer"
        Exit Function
    End If
    If Snapshot(0) <> 0 Or Snapshot(77) <> 77 Or Snapshot(255) <> 255 Then
        Print "snapshot ownership"
        Exit Function
    End If
    Dim OriginalBytes() As Byte
    Dim IndependentBytes() As Byte
    If TrySnapshotByteBuffer(Buffer, OriginalBytes) = False Or TrySnapshotByteBuffer(Independent, IndependentBytes) = False Then
        Print "copy snapshots"
        Exit Function
    End If
    If ByteStorageLength(OriginalBytes) <> 1 Or OriginalBytes(0) <> 99 Or IndependentBytes(0) <> 88 Then
        Print "record ownership"
        Exit Function
    End If
    If ClearByteBuffer(Buffer) = False Or TrySnapshotByteBuffer(Buffer, OriginalBytes) = False Then
        Print "empty snapshot"
        Exit Function
    End If
    If ByteStorageLength(OriginalBytes) <> 0 Then
        Print "empty exact length"
        Exit Function
    End If
    Print "PASS byte buffer basics"
    Main = 0
End Function
