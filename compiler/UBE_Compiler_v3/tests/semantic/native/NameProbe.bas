UBE SOURCE 1 MODULE
Attribute UBE_Name = "NameProbe"

Type NameProbeSpan
    FirstByte As Long
    LastByte As Long
    SuffixFirst As Long
    Bracketed As Long
End Type
Type NameProbeKey
    FirstByte As Long
    ByteCount As Long
    SourceFirst As Long
    SourceLast As Long
    SuffixFirst As Long
    Value As Long
End Type
Type NameProbeResult
    Bytes() As Byte
    Keys() As NameProbeKey
    Count As Long
    ByteCount As Long
    SourceId As Long
End Type
Type NameProbeWork
    Scalars As Long
    Encoded As Long
    Escapes As Long
    Names As Long
    Writes As Long
End Type
Intrinsic Function NameProbeSpanLength(ByRef Values() As NameProbeSpan) As Long
Attribute NameProbeSpanLength.UBE_Primitive = "Array.Length"
End Function
Intrinsic Function TryResizeNameProbeKeys(ByRef Values() As NameProbeKey, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeNameProbeKeys.UBE_Primitive = "Array.TryResize"
End Function
Intrinsic Function TryResizeNameProbeResults(ByRef Values() As NameProbeResult, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeNameProbeResults.UBE_Primitive = "Array.TryResize"
End Function
Intrinsic Function TryCopyNameProbeResults(ByRef Destination() As NameProbeResult, ByRef Original() As NameProbeResult) As Boolean
Attribute TryCopyNameProbeResults.UBE_Primitive = "Array.TryCopy"
End Function

' Generic scalar encoding candidate; no allocation/retention/Err change.
' False preserves all outputs. Caller keeps outputs distinct.
Function TryEncodeNameProbeScalar(ByVal Scalar As Long, ByRef B0 As Byte, ByRef B1 As Byte, ByRef B2 As Byte, ByRef B3 As Byte, ByRef ScalarWidth As Long) As Boolean
    TryEncodeNameProbeScalar = TryEncodeUtf8Scalar(Scalar, B0, B1, B2, B3, ScalarWidth)
End Function

' Compiler name policy candidate. Buffer is private unpublished construction;
' failed append can leave private partial bytes, never a public partial result.
Function TryAppendCanonicalProbeName(ByRef Bytes() As Byte, ByVal FirstByte As Long, ByVal LastByte As Long, ByVal SuffixFirst As Long, ByVal Bracketed As Boolean, ByVal MaximumBytes As Long, ByRef Buffer As ByteBuffer, ByRef CanonicalFirst As Long, ByRef CanonicalCount As Long, ByRef Failure As Long, ByRef Work As NameProbeWork) As Boolean
    TryAppendCanonicalProbeName = False
    Failure = 5
    If FirstByte < 0 Or LastByte <= FirstByte Or MaximumBytes < 0 Or MaximumBytes > 1048576 Then
        Failure = 1
        Exit Function
    End If
    If LastByte > ByteStorageLength(Bytes) Or SuffixFirst < -1 Then
        Failure = 1
        Exit Function
    End If
    Dim EndByte As Long = LastByte
    If SuffixFirst >= 0 Then
        If SuffixFirst <> LastByte - 1 Or SuffixFirst <= FirstByte Then
            Failure = 1
            Exit Function
        End If
        EndByte = SuffixFirst
    End If
    Dim AtByte As Long = FirstByte
    If Bracketed Then
        If EndByte - FirstByte < 3 Then
            Failure = 1
            Exit Function
        End If
        If Bytes(FirstByte) <> 91 Or Bytes(EndByte - 1) <> 93 Then
            Failure = 1
            Exit Function
        End If
        AtByte = AtByte + 1
        EndByte = EndByte - 1
    End If
    Dim Start As Long = Buffer.Count
    While AtByte < EndByte
        Dim Scalar As Long = 0
        Dim ScalarWidth As Long = 0
        If TryReadSourceScalar(Bytes, AtByte, Scalar, ScalarWidth) = False Then
            Exit Function
        End If
        If ScalarWidth > EndByte - AtByte Then
            Failure = 1
            Exit Function
        End If
        If Bracketed And Scalar = 93 Then
            If AtByte + 1 >= EndByte Then
                Failure = 1
                Exit Function
            End If
            If Bytes(AtByte + 1) <> 93 Then
                Failure = 1
                Exit Function
            End If
            ScalarWidth = 2
            Work.Escapes = Work.Escapes + 1
        End If
        Work.Scalars = Work.Scalars + 1
        Dim B0 As Byte = 0
        Dim B1 As Byte = 0
        Dim B2 As Byte = 0
        Dim B3 As Byte = 0
        Dim EncodedWidth As Long = 0
        If TryEncodeNameProbeScalar(SimpleFoldUnicode(Scalar), B0, B1, B2, B3, EncodedWidth) = False Then
            Failure = 1
            Exit Function
        End If
        If Buffer.Count > MaximumBytes - EncodedWidth Then
            Failure = 2
            Exit Function
        End If
        If TryAppendByte(Buffer, B0) = False Then
            Exit Function
        End If
        Work.Writes = Work.Writes + 1
        If EncodedWidth >= 2 Then
            If TryAppendByte(Buffer, B1) = False Then
                Exit Function
            End If
            Work.Writes = Work.Writes + 1
        End If
        If EncodedWidth >= 3 Then
            If TryAppendByte(Buffer, B2) = False Then
                Exit Function
            End If
            Work.Writes = Work.Writes + 1
        End If
        If EncodedWidth = 4 Then
            If TryAppendByte(Buffer, B3) = False Then
                Exit Function
            End If
            Work.Writes = Work.Writes + 1
        End If
        Work.Encoded = Work.Encoded + EncodedWidth
        AtByte = AtByte + ScalarWidth
    Wend
    CanonicalFirst = Start
    CanonicalCount = Buffer.Count - Start
    Work.Names = Work.Names + 1
    Failure = 0
    TryAppendCanonicalProbeName = True
End Function

Function TryBuildCanonicalProbeNames(ByRef Bytes() As Byte, ByRef Spans() As NameProbeSpan, ByVal Count As Long, ByVal MaximumBytes As Long, ByVal SourceId As Long, ByRef Result() As NameProbeResult, ByRef Failure As Long, ByRef Work As NameProbeWork) As Boolean
    TryBuildCanonicalProbeNames = False
    Failure = 5
    If Count < 0 Or Count > 16384 Or MaximumBytes < 0 Or MaximumBytes > 1048576 Or SourceId < 0 Then
        Failure = 1
        Exit Function
    End If
    If Count > NameProbeSpanLength(Spans) Then
        Failure = 1
        Exit Function
    End If
    Dim Pending() As NameProbeResult
    If TryResizeNameProbeResults(Pending, 1, False) = False Then
        Exit Function
    End If
    If TryResizeNameProbeKeys(Pending(0).Keys, Count, False) = False Then
        Exit Function
    End If
    Dim Buffer As ByteBuffer
    Dim Index As Long = 0
    While Index < Count
        Dim First As Long = 0
        Dim Length As Long = 0
        Failure = 5
        If Spans(Index).Bracketed < 0 Or Spans(Index).Bracketed > 1 Then
            Failure = 1
            Exit Function
        End If
        If TryAppendCanonicalProbeName(Bytes, Spans(Index).FirstByte, Spans(Index).LastByte, Spans(Index).SuffixFirst, Spans(Index).Bracketed <> 0, MaximumBytes, Buffer, First, Length, Failure, Work) = False Then
            Exit Function
        End If
        Failure = 5
        Pending(0).Keys(Index).FirstByte = First
        Pending(0).Keys(Index).ByteCount = Length
        Pending(0).Keys(Index).SourceFirst = Spans(Index).FirstByte
        Pending(0).Keys(Index).SourceLast = Spans(Index).LastByte
        Pending(0).Keys(Index).SuffixFirst = Spans(Index).SuffixFirst
        Pending(0).Keys(Index).Value = Index
        Index = Index + 1
    Wend
    Failure = 5
    If TryResizeByteStorage(Pending(0).Bytes, Buffer.Count, False) = False Then
        Exit Function
    End If
    If TryCopyByteRange(Buffer.Storage, 0, Pending(0).Bytes, 0, Buffer.Count) = False Then
        Exit Function
    End If
    Pending(0).Count = Count
    Pending(0).ByteCount = Buffer.Count
    Pending(0).SourceId = SourceId
    If TryCopyNameProbeResults(Result, Pending) = False Then
        Exit Function
    End If
    Failure = 0
    TryBuildCanonicalProbeNames = True
End Function
