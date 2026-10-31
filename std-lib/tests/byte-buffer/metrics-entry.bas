' Ordinary UBE local scopes exercise early-return and normal cleanup.
Function MetricsScopedBuffer(ByVal Marker As Byte, ByVal Cancel As Boolean) As Boolean
    MetricsScopedBuffer = False
    Dim LocalBuffer As ByteBuffer
    Dim LocalOutput() As Byte
    If TryAppendByte(LocalBuffer, Marker) = False Then
        Exit Function
    End If
    If Cancel Then
        Exit Function
    End If
    If TrySnapshotByteBuffer(LocalBuffer, LocalOutput) = False Then
        Exit Function
    End If
    MetricsScopedBuffer = True
End Function

Function Main() As Long
    Main = 0
End Function
