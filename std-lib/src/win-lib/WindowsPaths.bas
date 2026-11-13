UBE SOURCE 1 MODULE
Attribute UBE_Name = "WindowsPaths"
' Applies bounded Windows path policy using ordinary byte algorithms and OS ordinal comparison.

' Obtains normalized physical spelling from an already acquired file or directory owner.
Public Function TryFilePath(ByVal Token As Long, ByRef Result() As Byte, ByRef Failure As Long) As Boolean
    Dim Scratch() As Byte
    Dim Count As Long
    On Error GoTo Failed
    Failure = 8
    If Not BufferPrimitives.TryResizeBytes(Scratch, 4096, False) Then Exit Function
    If Not FilePrimitives.TryFinalPath(Token, Scratch, Count, Failure) Then Exit Function
    If Count < 1 Or Count > 4096 Then Failure = 1: Exit Function
    Failure = 8
    If Not BufferPrimitives.TryResizeBytes(Scratch, Count, True) Then Exit Function
    TryFilePath = TryNormalizePhysical(Scratch, Result, Failure)
    Exit Function
Failed:
    Failure = 1
End Function

' Resolves a caller-supplied path lexically; this alone is not physical containment evidence.
Public Function TryAbsolutePath(ByRef Requested() As Byte, ByRef Result() As Byte, ByRef Failure As Long) As Boolean
    Dim Scratch() As Byte
    Dim Count As Long
    On Error GoTo Failed
    Failure = 8
    If Not BufferPrimitives.TryResizeBytes(Scratch, 4096, False) Then Exit Function
    If Not PathPrimitives.TryFullPath(Requested, Scratch, Count, Failure) Then Exit Function
    If Count < 1 Or Count > 4096 Then Failure = 1: Exit Function
    Failure = 8
    If Not BufferPrimitives.TryResizeBytes(Scratch, Count, True) Then Exit Function
    TryAbsolutePath = TryNormalizePhysical(Scratch, Result, Failure)
    Exit Function
Failed:
    Failure = 1
End Function

' Records invalid path policy without replacing caller-owned result arrays or Boolean outputs.
Private Function InvalidPath(ByRef Failure As Long) As Boolean
    Failure = 1
    InvalidPath = FilePrimitives.SetError(5)
End Function

' Validates strict nonempty UTF-8 and the counted file-path size boundary.
Private Function ValidText(ByRef Value() As Byte, ByRef Failure As Long) As Boolean
    Dim Length As Long
    Dim Index As Long
    Dim ByteWidth As Long
    Dim Units As Long
    On Error GoTo Failed
    Length = BufferPrimitives.ByteStorageLength(Value)
    If Length < 1 Or Length > 4096 Then ValidText = InvalidPath(Failure): Exit Function
    Do While Index < Length
        If Value(Index) = 0 Then ValidText = InvalidPath(Failure): Exit Function
        If Not Utf8.TrySequenceWidth(Value, Index, Length, ByteWidth, Units) Then ValidText = InvalidPath(Failure): Exit Function
        Index = Index + ByteWidth
    Loop
    ValidText = True
    Exit Function
Failed:
    Failure = 1
End Function

' Copies a logical prefix through private storage before atomic replacement, including aliased arrays.
Private Function CopyPrefix(ByRef Source() As Byte, ByVal Count As Long, ByRef Result() As Byte, ByRef Failure As Long) As Boolean
    Dim Candidate() As Byte
    On Error GoTo Failed
    If Not BufferPrimitives.TryResizeBytes(Candidate, Count, False) Then Failure = 3: Exit Function
    If Not BufferPrimitives.CopyByteRange(Source, 0, Candidate, 0, Count) Then Failure = 1: Exit Function
    If Not BufferPrimitives.TryCopyBytes(Result, Candidate) Then Failure = 3: Exit Function
    CopyPrefix = True
    Exit Function
Failed:
    Failure = 1
End Function

' Checks absolute drive or UNC spelling and returns the root's minimum preserved byte extent.
Private Function RootExtent(ByRef Path() As Byte, ByRef RootLength As Long, ByRef Failure As Long) As Boolean
    Dim Length As Long
    Dim Index As Long
    Dim Start As Long
    Dim ComponentLength As Long
    Dim Value As Long
    Dim Drive As Boolean
    Length = BufferPrimitives.ByteStorageLength(Path)
    If Length < 3 Then RootExtent = InvalidPath(Failure): Exit Function
    Value = Path(0)
    Drive = (Value >= 65 And Value <= 90) Or (Value >= 97 And Value <= 122)
    Drive = Drive And Path(1) = 58 And Path(2) = 92
    If Drive Then
        RootLength = 3
        Start = 3
    Else
        If Path(0) <> 92 Or Path(1) <> 92 Then RootExtent = InvalidPath(Failure): Exit Function
        Index = 2
        Do While Index < Length
            If Path(Index) = 92 Then Exit Do
            Index = Index + 1
        Loop
        If Index = 2 Or Index = Length Then RootExtent = InvalidPath(Failure): Exit Function
        Start = Index + 1
        Index = Start
        Do While Index < Length
            If Path(Index) = 92 Then Exit Do
            Index = Index + 1
        Loop
        If Index = Start Then RootExtent = InvalidPath(Failure): Exit Function
        RootLength = Index
        Start = 2
    End If
    Index = 0
    Do While Index < Length
        Value = Path(Index)
        If Value < 32 Or Value = 34 Or Value = 42 Or Value = 60 Or Value = 62 Or Value = 63 Or Value = 124 Then RootExtent = InvalidPath(Failure): Exit Function
        If Value = 58 Then
            If Not Drive Or Index <> 1 Then RootExtent = InvalidPath(Failure): Exit Function
        End If
        Index = Index + 1
    Loop
    Index = Start
    Do While Index <= Length
        Value = 92
        If Index < Length Then Value = Path(Index)
        If Value = 92 Then
            ComponentLength = Index - Start
            If ComponentLength = 0 And Index < Length Then RootExtent = InvalidPath(Failure): Exit Function
            If ComponentLength = 1 Then
                If Path(Start) = 46 Then RootExtent = InvalidPath(Failure): Exit Function
            End If
            If ComponentLength = 2 Then
                If Path(Start) = 46 And Path(Start + 1) = 46 Then RootExtent = InvalidPath(Failure): Exit Function
            End If
            Start = Index + 1
        End If
        Index = Index + 1
    Loop
    RootExtent = True
End Function

' Normalizes reviewed final/full-path namespace spellings; it performs no filesystem identity check.
Public Function TryNormalizePhysical(ByRef InputPath() As Byte, ByRef Result() As Byte, ByRef Failure As Long) As Boolean
    Dim Candidate() As Byte
    Dim Length As Long
    Dim Skip As Long
    Dim Prefix As Long
    Dim Index As Long
    Dim Used As Long
    Dim RootLength As Long
    Dim Value As Byte
    On Error GoTo Failed
    Failure = 0
    If Not ValidText(InputPath, Failure) Then Exit Function
    Length = BufferPrimitives.ByteStorageLength(InputPath)
    If Length >= 4 Then
        If InputPath(0) = 92 And InputPath(1) = 92 And InputPath(2) = 63 And InputPath(3) = 92 Then
            Skip = 4
            If Length >= 8 Then
                If (InputPath(4) = 85 Or InputPath(4) = 117) And (InputPath(5) = 78 Or InputPath(5) = 110) And (InputPath(6) = 67 Or InputPath(6) = 99) And InputPath(7) = 92 Then Skip = 8: Prefix = 2
            End If
        End If
    End If
    Used = Length - Skip + Prefix
    If Not BufferPrimitives.TryResizeBytes(Candidate, Used, False) Then Failure = 3: Exit Function
    If Prefix = 2 Then Candidate(0) = 92: Candidate(1) = 92
    Index = Skip
    Do While Index < Length
        Value = InputPath(Index)
        If Value = 47 Then Value = 92
        Candidate(Index - Skip + Prefix) = Value
        Index = Index + 1
    Loop
    If Not RootExtent(Candidate, RootLength, Failure) Then Exit Function
    Do While Used > RootLength
        If Candidate(Used - 1) <> 92 Then Exit Do
        Used = Used - 1
    Loop
    TryNormalizePhysical = CopyPrefix(Candidate, Used, Result, Failure)
    Exit Function
Failed:
    Failure = 1
End Function

' Returns an absolute parent while preserving drive and UNC roots when already at the root.
Public Function TryParent(ByRef Path() As Byte, ByRef Result() As Byte, ByRef Failure As Long) As Boolean
    Dim Normalized() As Byte
    Dim RootLength As Long
    Dim Length As Long
    On Error GoTo Failed
    Failure = 0
    If Not TryNormalizePhysical(Path, Normalized, Failure) Then Exit Function
    If Not RootExtent(Normalized, RootLength, Failure) Then Exit Function
    Length = BufferPrimitives.ByteStorageLength(Normalized)
    Do While Length > RootLength
        Length = Length - 1
        If Normalized(Length) = 92 Then Exit Do
    Loop
    TryParent = CopyPrefix(Normalized, Length, Result, Failure)
    Exit Function
Failed:
    Failure = 1
End Function

' Compares complete normalized names using Windows ordinal Unicode case-insensitive equality.
Public Function TrySamePath(ByRef First() As Byte, ByRef Second() As Byte, ByRef Same As Boolean, ByRef Failure As Long) As Boolean
    Dim LeftPath() As Byte
    Dim RightPath() As Byte
    Dim Ordering As Long
    On Error GoTo Failed
    Failure = 0
    If Not TryNormalizePhysical(First, LeftPath, Failure) Then Exit Function
    If Not TryNormalizePhysical(Second, RightPath, Failure) Then Exit Function
    If Not PathPrimitives.TryCompareOrdinal(LeftPath, RightPath, Ordering, Failure) Then Exit Function
    Same = Ordering = 0
    TrySamePath = True
    Exit Function
Failed:
    Failure = 1
End Function

' Compares whole directory prefixes without assuming case-equivalent Unicode has equal UTF-8 byte lengths.
Public Function TryIsWithin(ByRef Root() As Byte, ByRef Path() As Byte, ByRef Within As Boolean, ByRef Failure As Long) As Boolean
    Dim Directory() As Byte
    Dim Normalized() As Byte
    Dim Prefix() As Byte
    Dim Compared() As Byte
    Dim Length As Long
    Dim Index As Long
    Dim Separators As Long
    Dim Seen As Long
    Dim Ordering As Long
    On Error GoTo Failed
    Failure = 0
    If Not TryNormalizePhysical(Root, Directory, Failure) Then Exit Function
    If Not TryNormalizePhysical(Path, Normalized, Failure) Then Exit Function
    Length = BufferPrimitives.ByteStorageLength(Directory)
    If Directory(Length - 1) <> 92 Then Length = Length + 1
    If Length > 4096 Then TryIsWithin = InvalidPath(Failure): Exit Function
    If Not BufferPrimitives.TryResizeBytes(Prefix, Length, False) Then Failure = 3: Exit Function
    If Not BufferPrimitives.CopyByteRange(Directory, 0, Prefix, 0, BufferPrimitives.ByteStorageLength(Directory)) Then Failure = 1: Exit Function
    Prefix(Length - 1) = 92
    Do While Index < Length
        If Prefix(Index) = 92 Then Separators = Separators + 1
        Index = Index + 1
    Loop
    Index = 0
    Length = BufferPrimitives.ByteStorageLength(Normalized)
    Do While Index < Length
        If Normalized(Index) = 92 Then Seen = Seen + 1
        Index = Index + 1
        If Seen = Separators Then Exit Do
    Loop
    If Seen <> Separators Or Index = Length Then Within = False: TryIsWithin = True: Exit Function
    If Not CopyPrefix(Normalized, Index, Compared, Failure) Then Exit Function
    If Not PathPrimitives.TryCompareOrdinal(Prefix, Compared, Ordering, Failure) Then Exit Function
    Within = Ordering = 0
    TryIsWithin = True
    Exit Function
Failed:
    Failure = 1
End Function

' Resolves a safe relative source spelling, then enforces lexical directory containment on its OS-normalized path.
Public Function TryResolveSource(ByRef Root() As Byte, ByRef Relative() As Byte, ByRef Result() As Byte, ByRef Failure As Long) As Boolean
    Dim Directory() As Byte
    Dim Joined() As Byte
    Dim Full() As Byte
    Dim Exact() As Byte
    Dim Normalized() As Byte
    Dim RootLength As Long
    Dim Length As Long
    Dim Index As Long
    Dim Used As Long
    Dim Value As Byte
    Dim Within As Boolean
    On Error GoTo Failed
    Failure = 0
    If Not TryNormalizePhysical(Root, Directory, Failure) Then Exit Function
    If Not ValidText(Relative, Failure) Then Exit Function
    Length = BufferPrimitives.ByteStorageLength(Relative)
    If Relative(0) = 92 Or Relative(0) = 47 Then TryResolveSource = InvalidPath(Failure): Exit Function
    Do While Index < Length
        Value = Relative(Index)
        If Value < 32 Or Value = 34 Or Value = 42 Or Value = 58 Or Value = 60 Or Value = 62 Or Value = 63 Or Value = 124 Then TryResolveSource = InvalidPath(Failure): Exit Function
        Index = Index + 1
    Loop
    RootLength = BufferPrimitives.ByteStorageLength(Directory)
    If Directory(RootLength - 1) <> 92 Then RootLength = RootLength + 1
    If Length > 4096 - RootLength Then TryResolveSource = InvalidPath(Failure): Exit Function
    If Not BufferPrimitives.TryResizeBytes(Joined, RootLength + Length, False) Then Failure = 3: Exit Function
    If Not BufferPrimitives.CopyByteRange(Directory, 0, Joined, 0, BufferPrimitives.ByteStorageLength(Directory)) Then Failure = 1: Exit Function
    Joined(RootLength - 1) = 92
    Index = 0
    Do While Index < Length
        Value = Relative(Index)
        If Value = 47 Then Value = 92
        Joined(RootLength + Index) = Value
        Index = Index + 1
    Loop
    If Not BufferPrimitives.TryResizeBytes(Full, 4096, False) Then Failure = 3: Exit Function
    If Not PathPrimitives.TryFullPath(Joined, Full, Used, Failure) Then Exit Function
    If Not CopyPrefix(Full, Used, Exact, Failure) Then Exit Function
    If Not TryNormalizePhysical(Exact, Normalized, Failure) Then Exit Function
    If Not TryIsWithin(Directory, Normalized, Within, Failure) Then Exit Function
    If Not Within Then TryResolveSource = InvalidPath(Failure): Exit Function
    If Not BufferPrimitives.TryCopyBytes(Result, Normalized) Then Failure = 3: Exit Function
    TryResolveSource = True
    Exit Function
Failed:
    Failure = 1
End Function
