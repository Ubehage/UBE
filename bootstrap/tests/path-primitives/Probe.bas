UBE SOURCE 1 MODULE
Attribute UBE_Name = "PathProbe"
' Exercises path spelling, UTF-8, output preservation and the existing file owner.
Public Function Main() As Long
    Dim Relative(3 To 15) As Byte
    Dim Upper(2 To 3) As Byte
    Dim Lower(7 To 8) As Byte
    Dim Bad(4 To 4) As Byte
    Dim Tiny(9 To 9) As Byte
    Dim EmptyBuffer() As Byte
    Dim Full() As Byte
    Dim Physical() As Byte
    Dim Normalized() As Byte
    Dim Count As Long
    Dim PhysicalCount As Long
    Dim Failure As Long
    Dim Token As Long
    Dim Length As Long
    Dim Ordering As Long
    Dim ReadCount As Long
    Dim Status As Boolean
    On Error GoTo Failed
    Relative(3) = 46: Relative(4) = 92
    Relative(5) = 99: Relative(6) = 97: Relative(7) = 115: Relative(8) = 101
    Relative(9) = 45: Relative(10) = 195: Relative(11) = 166
    Relative(12) = 46: Relative(13) = 98: Relative(14) = 105: Relative(15) = 110
    Upper(2) = 195: Upper(3) = 134
    Lower(7) = 195: Lower(8) = 166
    Status = FilePrimitives.SetError(345)
    If Not PathPrimitives.TryCompareOrdinal(Upper, Lower, Ordering, Failure) Then Main = 1: Exit Function
    If Ordering <> 0 Or Failure <> 0 Or Err.Number <> 345 Then Main = 2: Exit Function
    If Not PathPrimitives.TryCompareOrdinal(EmptyBuffer, Lower, Ordering, Failure) Then Main = 3: Exit Function
    If Ordering <> -1 Then Main = 4: Exit Function
    If Not PathPrimitives.TryCompareOrdinal(Lower, EmptyBuffer, Ordering, Failure) Then Main = 5: Exit Function
    If Ordering <> 1 Then Main = 6: Exit Function
    If Not PathPrimitives.TryCompareOrdinal(EmptyBuffer, EmptyBuffer, Ordering, Failure) Then Main = 7: Exit Function
    If Ordering <> 0 Then Main = 8: Exit Function
    Bad(4) = 255: Ordering = 81
    If PathPrimitives.TryCompareOrdinal(Bad, Lower, Ordering, Failure) Then Main = 9: Exit Function
    If Ordering <> 81 Or Failure <> 1 Then Main = 10: Exit Function
    Count = 83: Tiny(9) = 77
    If PathPrimitives.TryFullPath(Relative, Tiny, Count, Failure) Then Main = 11: Exit Function
    If Count <> 83 Or Tiny(9) <> 77 Or Failure <> 1 Then Main = 12: Exit Function
    If PathPrimitives.TryFullPath(EmptyBuffer, Tiny, Count, Failure) Then Main = 13: Exit Function
    If Count <> 83 Or Tiny(9) <> 77 Then Main = 14: Exit Function
    If PathPrimitives.TryCompareOrdinal(Upper, Lower, Ordering, Ordering) Then Main = 15: Exit Function
    If Ordering <> 81 Then Main = 16: Exit Function
    If Not BufferPrimitives.TryResizeBytes(Full, 4096, False) Then Main = 17: Exit Function
    If Not BufferPrimitives.TryResizeBytes(Physical, 4096, False) Then Main = 18: Exit Function
    Status = FilePrimitives.SetError(678)
    If Not PathPrimitives.TryFullPath(Relative, Full, Count, Failure) Then Main = 19: Exit Function
    If Count < 1 Or Count > 4096 Or Failure <> 0 Or Err.Number <> 678 Then Main = 20: Exit Function
    If Not BufferPrimitives.TryResizeBytes(Full, Count, True) Then Main = 21: Exit Function
    If Not FilePrimitives.TryOpen(Relative, 10, Token, Length, Failure) Then Main = 22: Exit Function
    If Length <> 1 Then Main = 23: GoTo Cleanup
    If Not FilePrimitives.TryFinalPath(Token, Physical, PhysicalCount, Failure) Then Main = 24: GoTo Cleanup
    If PhysicalCount <> Count + 4 Or Err.Number <> 678 Then Main = 25: GoTo Cleanup
    If Physical(0) <> 92 Or Physical(1) <> 92 Or Physical(2) <> 63 Or Physical(3) <> 92 Then Main = 26: GoTo Cleanup
    If Not BufferPrimitives.TryResizeBytes(Normalized, Count, False) Then Main = 27: GoTo Cleanup
    If Not BufferPrimitives.CopyByteRange(Physical, 4, Normalized, 0, Count) Then Main = 28: GoTo Cleanup
    If Not PathPrimitives.TryCompareOrdinal(Full, Normalized, Ordering, Failure) Then Main = 29: GoTo Cleanup
    If Ordering <> 0 Then Main = 30: GoTo Cleanup
    If Not FilePrimitives.TryRead(Token, Tiny, 0, 1, ReadCount, Failure) Then Main = 31: GoTo Cleanup
    If ReadCount <> 1 Or Tiny(9) <> 42 Then Main = 32: GoTo Cleanup
    If Not StandardStreams.TryWriteBytes(1, Full, 0, Count, Failure) Then Main = 33: GoTo Cleanup
Cleanup:
    If Not FilePrimitives.TryClose(Token, Failure) Then Main = 34
    Exit Function
Failed:
    Main = 90
    GoTo Cleanup
End Function
