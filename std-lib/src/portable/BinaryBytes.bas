UBE SOURCE 1 MODULE
Attribute UBE_Name = "BinaryBytes"

' Ordinary portable conversion; contract: ../../BINARY-BYTES-CONTRACT.md.
' The caller retains immutable zero-based Bytes. No payload allocation/copy.
Private Function TryReadBinaryByte(ByRef Bytes() As Byte, ByVal Index As Long, ByRef Value As Long) As Boolean
    TryReadBinaryByte = False
    Value = Bytes(Index)
    TryReadBinaryByte = True
End Function

' Width 1..7 is zero extended; width 8 preserves the full LongLong bit pattern.
' Failure preserves Value and Err. Outputs must not alias the borrowed input.
Function TryReadLittleEndianBits(ByRef Bytes() As Byte, ByVal First As Long, ByVal Width As Long, ByRef Value As LongLong) As Boolean
    TryReadLittleEndianBits = False
    Dim Length As Long = ByteStorageLength(Bytes)
    If First < 0 Or First > Length Or Width < 1 Or Width > 8 Then
        Exit Function
    End If
    If Width > Length - First Then
        Exit Function
    End If
    Dim Index As Long = First + Width - 1
    Dim NextByte As Long = 0
    If TryReadBinaryByte(Bytes, Index, NextByte) = False Then
        Exit Function
    End If
    Dim Prepared As LongLong = NextByte
    If Width = 8 And NextByte >= 128 Then
        Prepared = Prepared - 256
    End If
    While Index > First
        Index = Index - 1
        If TryReadBinaryByte(Bytes, Index, NextByte) = False Then
            Exit Function
        End If
        Prepared = Prepared * 256 + NextByte
    Wend
    Value = Prepared
    TryReadLittleEndianBits = True
End Function
