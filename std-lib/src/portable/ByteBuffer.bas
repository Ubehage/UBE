UBE SOURCE 1 MODULE
Attribute UBE_Name = "ByteBuffer"

' Ordinary owned byte storage; contract: ../../BYTE-BUFFER-CONTRACT.md.
' Zero is empty. Fields are reserved implementation state; mutable instances
' have one owner. Assignment/ByVal/result boundaries copy storage independently.
Type ByteBuffer
    Storage() As Byte
    Count As Long
End Type

Intrinsic Function ByteStorageLength(ByRef Values() As Byte) As Long
Attribute ByteStorageLength.UBE_Primitive = "Array.Length"
End Function

Intrinsic Function TryResizeByteStorage(ByRef Values() As Byte, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeByteStorage.UBE_Primitive = "Array.TryResize"
End Function

Intrinsic Function TryCopyByteStorage(ByRef Destination() As Byte, ByRef Source() As Byte) As Boolean
Attribute TryCopyByteStorage.UBE_Primitive = "Array.TryCopy"
End Function

Intrinsic Function TryCopyByteRange(ByRef Source() As Byte, ByVal SourceStart As Long, ByRef Destination() As Byte, ByVal DestinationStart As Long, ByVal Count As Long) As Boolean
Attribute TryCopyByteRange.UBE_Primitive = "Memory.CopyBytes"
End Function

' Returns allocated byte capacity, or -1 for an invalid logical Count.
' Borrows Buffer only for this call; allocates nothing and preserves Err.
Function ByteBufferCapacity(ByRef Buffer As ByteBuffer) As Long
    ByteBufferCapacity = -1
    Dim Capacity As Long = ByteStorageLength(Buffer.Storage)
    If Buffer.Count < 0 Or Buffer.Count > Capacity Then
        Exit Function
    End If
    ByteBufferCapacity = Capacity
End Function

' Returns logical byte length, or -1 for invalid state; no allocation/Err change.
Function ByteBufferLength(ByRef Buffer As ByteBuffer) As Long
    ByteBufferLength = -1
    If ByteBufferCapacity(Buffer) < 0 Then
        Exit Function
    End If
    ByteBufferLength = Buffer.Count
End Function

' Ensures at least MinimumCapacity bytes without changing logical contents.
' Domain rejection preserves Err/state; allocation failure sets Err 7 and
' preserves contents, Count and capacity. Success preserves prior Err.
Function TryReserveByteBuffer(ByRef Buffer As ByteBuffer, ByVal MinimumCapacity As Long) As Boolean
    TryReserveByteBuffer = False
    Dim Capacity As Long = ByteBufferCapacity(Buffer)
    If Capacity < 0 Or MinimumCapacity < 0 Then
        Exit Function
    End If
    If MinimumCapacity <= Capacity Then
        TryReserveByteBuffer = True
        Exit Function
    End If
    Dim NewCapacity As Long = Capacity
    If NewCapacity < 8 Then
        NewCapacity = 8
    End If
    While NewCapacity < MinimumCapacity
        If NewCapacity > 1073741823 Then
            NewCapacity = MinimumCapacity
        Else
            NewCapacity = NewCapacity * 2
        End If
    Wend
    TryReserveByteBuffer = TryResizeByteStorage(Buffer.Storage, NewCapacity, True)
End Function

' Appends one byte with geometric growth. Retains no input references.
' Rejection/failure preserves the entire old Buffer; success preserves Err.
Function TryAppendByte(ByRef Buffer As ByteBuffer, ByVal Value As Byte) As Boolean
    TryAppendByte = False
    If ByteBufferCapacity(Buffer) < 0 Or Buffer.Count = 2147483647 Then
        Exit Function
    End If
    Dim NewCount As Long = Buffer.Count + 1
    If TryReserveByteBuffer(Buffer, NewCount) = False Then
        Exit Function
    End If
    Buffer.Storage(Buffer.Count) = Value
    Buffer.Count = NewCount
    TryAppendByte = True
End Function

' Appends the original Source range, including an overlapping Buffer.Storage
' range. SourceStart is an offset from Source's first stored byte, independent
' of its language lower bound; validates every bound before reserving.
' CopyBytes is allocation-free and alias-safe for the validated ranges.
Function TryAppendBytes(ByRef Buffer As ByteBuffer, ByRef Source() As Byte, ByVal SourceStart As Long, ByVal ByteCount As Long) As Boolean
    TryAppendBytes = False
    Dim Capacity As Long = ByteBufferCapacity(Buffer)
    Dim SourceLength As Long = ByteStorageLength(Source)
    If Capacity < 0 Or SourceStart < 0 Or ByteCount < 0 Then
        Exit Function
    End If
    If SourceStart > SourceLength Then
        Exit Function
    End If
    If ByteCount > SourceLength - SourceStart Then
        Exit Function
    End If
    If ByteCount > 2147483647 - Buffer.Count Then
        Exit Function
    End If
    Dim NewCount As Long = Buffer.Count + ByteCount
    If TryReserveByteBuffer(Buffer, NewCount) = False Then
        Exit Function
    End If
    If TryCopyByteRange(Source, SourceStart, Buffer.Storage, Buffer.Count, ByteCount) = False Then
        Exit Function
    End If
    Buffer.Count = NewCount
    TryAppendBytes = True
End Function

' Clears logical contents while retaining capacity. Does not allocate, erase
' retained bytes, change Err or repair malformed state; False rejects that state.
Function ClearByteBuffer(ByRef Buffer As ByteBuffer) As Boolean
    ClearByteBuffer = False
    If ByteBufferCapacity(Buffer) < 0 Then
        Exit Function
    End If
    Buffer.Count = 0
    ClearByteBuffer = True
End Function

' Produces exactly Count independently owned bytes. Result must not alias
' Buffer.Storage. On rejection or allocation failure Result and Buffer retain
' their old values; allocation failure sets Err 7. Success preserves prior Err.
Function TrySnapshotByteBuffer(ByRef Buffer As ByteBuffer, ByRef Result() As Byte) As Boolean
    TrySnapshotByteBuffer = False
    If ByteBufferCapacity(Buffer) < 0 Then
        Exit Function
    End If
    Dim Prepared() As Byte
    If TryResizeByteStorage(Prepared, Buffer.Count, False) = False Then
        Exit Function
    End If
    If TryCopyByteRange(Buffer.Storage, 0, Prepared, 0, Buffer.Count) = False Then
        Exit Function
    End If
    TrySnapshotByteBuffer = TryCopyByteStorage(Result, Prepared)
End Function

' Strictly validates logical UTF-8 bytes and returns the Unicode scalar count.
' Output is zero on any rejection and must not alias Buffer fields. Borrows
' Buffer for this call, retains nothing, allocates nothing and preserves Err.
Function TryCountUtf8Scalars(ByRef Buffer As ByteBuffer, ByRef ScalarCount As Long) As Boolean
    TryCountUtf8Scalars = False
    ScalarCount = 0
    If ByteBufferCapacity(Buffer) < 0 Then
        Exit Function
    End If
    Dim Decoder As Utf8Decoder
    Dim Index As Long = 0
    Dim Count As Long = 0
    While Index < Buffer.Count
        Dim Scalar As Long = 0
        Dim Complete As Boolean = False
        If FeedUtf8Byte(Decoder, Buffer.Storage(Index), Scalar, Complete) = False Then
            Exit Function
        End If
        If Complete Then
            Count = Count + 1
        End If
        Index = Index + 1
    Wend
    If FinishUtf8Decoder(Decoder) = False Then
        Exit Function
    End If
    ScalarCount = Count
    TryCountUtf8Scalars = True
End Function
