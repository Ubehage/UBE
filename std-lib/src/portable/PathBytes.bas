UBE SOURCE 1 MODULE
Attribute UBE_Name = "PathBytes"

' Counted-byte paths; contract: ../../PATH-BYTES-PROPOSAL.md.
' Host observation only: returns independent strict UTF-8 directory bytes and
' never changes the process directory. Capture once per request. Failure leaves
' Published unchanged; success sets Failure=0 and preserves earlier Err. Callers
' seed Failure=8 before managed entry. No reference is retained after this call.
Intrinsic Function TryCurrentDirectoryBytes(ByRef Published() As Byte, ByRef Failure As Long) As Boolean
Attribute TryCurrentDirectoryBytes.UBE_Primitive = "Process.TryCurrentDirectory"
End Function

' The following BytePath helpers are reserved implementation procedures. The
' bounded bootstrap does not yet support Private procedure declarations.
Intrinsic Function TryResizeBytePathStarts(ByRef Values() As Long, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeBytePathStarts.UBE_Primitive = "Array.TryResize"
End Function

Function IsBytePathSeparator(ByVal Value As Long) As Boolean
    IsBytePathSeparator = Value = 47 Or Value = 92
End Function

Function RejectBytePath(ByVal Reason As Long, ByRef Failure As Long) As Boolean
    RejectBytePath = False
    Failure = Reason
    Dim ErrorNumber As Long = 5
    If Reason = 4 Then
        ErrorNumber = 6
    End If
    If Reason = 8 Then
        ErrorNumber = 7
    End If
    Call RecordErrorNumber(ErrorNumber)
End Function

' Validates a zero-based private buffer's logical prefix, without copying it.
Function TryValidateBytePath(ByRef Bytes() As Byte, ByVal Count As Long, ByRef Failure As Long) As Boolean
    TryValidateBytePath = False
    If Count < 1 Then
        Call RejectBytePath(2, Failure)
        Exit Function
    End If
    If Count > 131068 Then
        Call RejectBytePath(4, Failure)
        Exit Function
    End If
    Dim Decoder As Utf8Decoder
    Dim Index As Long = 0
    Dim Units As Long = 0
    While Index < Count
        Dim Scalar As Long = 0
        Dim Complete As Boolean = False
        If FeedUtf8Byte(Decoder, Bytes(Index), Scalar, Complete) = False Then
            Call RejectBytePath(2, Failure)
            Exit Function
        End If
        If Complete Then
            If Scalar = 0 Then
                Call RejectBytePath(2, Failure)
                Exit Function
            End If
            Units = Units + 1
            If Scalar > 65535 Then
                Units = Units + 1
            End If
            If Units > 32767 Then
                Call RejectBytePath(4, Failure)
                Exit Function
            End If
        End If
        Index = Index + 1
    Wend
    If FinishUtf8Decoder(Decoder) = False Then
        Call RejectBytePath(2, Failure)
        Exit Function
    End If
    Failure = 0
    TryValidateBytePath = True
End Function

' Snapshot payload offsets rather than language indices: any input lower bound.
Function TrySnapshotBytePath(ByRef InputBytes() As Byte, ByRef Snapshot() As Byte, ByRef Count As Long, ByRef Failure As Long) As Boolean
    TrySnapshotBytePath = False
    Count = ByteStorageLength(InputBytes)
    If Count < 1 Then
        Call RejectBytePath(2, Failure)
        Exit Function
    End If
    If Count > 131068 Then
        Call RejectBytePath(4, Failure)
        Exit Function
    End If
    If TryResizeByteStorage(Snapshot, Count, False) = False Then
        Call RejectBytePath(8, Failure)
        Exit Function
    End If
    If TryCopyByteRange(InputBytes, 0, Snapshot, 0, Count) = False Then
        Call RejectBytePath(8, Failure)
        Exit Function
    End If
    Failure = 8
    TrySnapshotBytePath = TryValidateBytePath(Snapshot, Count, Failure)
End Function

' Kind: ordinary=0, exact dot=1, exact parent=2. Bounds are private/checked.
Function TryClassifyBytePathComponent(ByRef Bytes() As Byte, ByVal Start As Long, ByVal Count As Long, ByRef Kind As Long, ByRef Failure As Long) As Boolean
    TryClassifyBytePathComponent = False
    Kind = 0
    If Count = 1 Then
        If Bytes(Start) = 46 Then
            Kind = 1
        End If
    End If
    If Count = 2 Then
        If Bytes(Start) = 46 And Bytes(Start + 1) = 46 Then
            Kind = 2
        End If
    End If
    If Kind <> 0 Then
        Failure = 0
        TryClassifyBytePathComponent = True
        Exit Function
    End If
    Dim Index As Long = Start
    While Index < Start + Count
        Dim Value As Long = Bytes(Index)
        If Value < 32 Or Value = 34 Or Value = 42 Or Value = 60 Or Value = 62 Or Value = 63 Or Value = 124 Then
            Call RejectBytePath(2, Failure)
            Exit Function
        End If
        If Value = 58 Then
            Call RejectBytePath(14, Failure)
            Exit Function
        End If
        Index = Index + 1
    Wend
    If Bytes(Start + Count - 1) = 46 Or Bytes(Start + Count - 1) = 32 Then
        Call RejectBytePath(14, Failure)
        Exit Function
    End If
    Failure = 0
    TryClassifyBytePathComponent = True
End Function

' RootKind: relative=0, drive=1, UNC=2. RootEnd excludes UNC tail slash.
Function TryReadBytePathRoot(ByRef Bytes() As Byte, ByVal Count As Long, ByRef RootKind As Long, ByRef RootEnd As Long, ByRef Failure As Long) As Boolean
    TryReadBytePathRoot = False
    RootKind = 0
    RootEnd = 0
    If Count >= 2 Then
        If Bytes(1) = 58 Then
            Dim Letter As Long = Bytes(0)
            If (Letter < 65 Or Letter > 90) And (Letter < 97 Or Letter > 122) Then
                Call RejectBytePath(2, Failure)
                Exit Function
            End If
            If Count < 3 Then
                Call RejectBytePath(14, Failure)
                Exit Function
            End If
            If IsBytePathSeparator(Bytes(2)) = False Then
                Call RejectBytePath(14, Failure)
                Exit Function
            End If
            RootKind = 1
            RootEnd = 3
            Failure = 0
            TryReadBytePathRoot = True
            Exit Function
        End If
    End If
    If IsBytePathSeparator(Bytes(0)) = False Then
        Failure = 0
        TryReadBytePathRoot = True
        Exit Function
    End If
    If Count < 2 Then
        Call RejectBytePath(14, Failure)
        Exit Function
    End If
    If IsBytePathSeparator(Bytes(1)) = False Then
        Call RejectBytePath(14, Failure)
        Exit Function
    End If
    Dim Index As Long = 2
    Dim ServerStart As Long = Index
    While Index < Count
        If IsBytePathSeparator(Bytes(Index)) Then
            Exit While
        End If
        Index = Index + 1
    Wend
    Dim ServerCount As Long = Index - ServerStart
    If ServerCount = 1 Then
        If Bytes(ServerStart) = 46 Or Bytes(ServerStart) = 63 Then
            Call RejectBytePath(14, Failure)
            Exit Function
        End If
    End If
    If ServerCount = 0 Or Index = Count Then
        Call RejectBytePath(2, Failure)
        Exit Function
    End If
    Dim ComponentKind As Long = 0
    Failure = 8
    If TryClassifyBytePathComponent(Bytes, ServerStart, ServerCount, ComponentKind, Failure) = False Then
        Exit Function
    End If
    If ComponentKind <> 0 Then
        Call RejectBytePath(2, Failure)
        Exit Function
    End If
    Index = Index + 1
    Dim ShareStart As Long = Index
    While Index < Count
        If IsBytePathSeparator(Bytes(Index)) Then
            Exit While
        End If
        Index = Index + 1
    Wend
    If Index = ShareStart Then
        Call RejectBytePath(2, Failure)
        Exit Function
    End If
    Failure = 8
    If TryClassifyBytePathComponent(Bytes, ShareStart, Index - ShareStart, ComponentKind, Failure) = False Then
        Exit Function
    End If
    If ComponentKind <> 0 Then
        Call RejectBytePath(2, Failure)
        Exit Function
    End If
    RootKind = 2
    RootEnd = Index
    Failure = 0
    TryReadBytePathRoot = True
End Function

' One bounded workspace and component stack; popping never copies a prefix.
Function TryBuildNormalizedBytePath(ByRef Bytes() As Byte, ByVal Count As Long, ByVal RootKind As Long, ByVal RootEnd As Long, ByRef Scratch() As Byte, ByRef Used As Long, ByRef Parents As Long, ByRef Failure As Long) As Boolean
    TryBuildNormalizedBytePath = False
    Used = 0
    Parents = 0
    If TryResizeByteStorage(Scratch, Count + 2, False) = False Then
        Call RejectBytePath(8, Failure)
        Exit Function
    End If
    Dim Starts() As Long
    Dim StackCapacity As Long = Count \ 2 + 1
    If TryResizeBytePathStarts(Starts, StackCapacity, False) = False Then
        Call RejectBytePath(8, Failure)
        Exit Function
    End If
    Dim Index As Long = 0
    While Index < RootEnd
        Dim Value As Byte = Bytes(Index)
        If IsBytePathSeparator(Value) Then
            Value = 47
        End If
        Scratch(Used) = Value
        Used = Used + 1
        Index = Index + 1
    Wend
    If RootKind = 2 Then
        Scratch(Used) = 47
        Used = Used + 1
    End If
    Dim Depth As Long = 0
    While Index < Count
        If IsBytePathSeparator(Bytes(Index)) Then
            Index = Index + 1
        Else
            Dim Start As Long = Index
            While Index < Count
                If IsBytePathSeparator(Bytes(Index)) Then
                    Exit While
                End If
                Index = Index + 1
            Wend
            Dim ComponentCount As Long = Index - Start
            Dim ComponentKind As Long = 0
            Failure = 8
            If TryClassifyBytePathComponent(Bytes, Start, ComponentCount, ComponentKind, Failure) = False Then
                Exit Function
            End If
            Dim AppendComponent As Boolean = ComponentKind = 0
            If ComponentKind = 2 Then
                If Depth > Parents Then
                    Depth = Depth - 1
                    Used = Starts(Depth)
                Else
                    If RootKind = 0 Then
                        AppendComponent = True
                        Parents = Parents + 1
                    End If
                End If
            End If
            If AppendComponent Then
                If Depth >= StackCapacity Then
                    Call RejectBytePath(4, Failure)
                    Exit Function
                End If
                Starts(Depth) = Used
                Depth = Depth + 1
                If Used > 0 Then
                    If Scratch(Used - 1) <> 47 Then
                        Scratch(Used) = 47
                        Used = Used + 1
                    End If
                End If
                If ComponentCount > Count + 2 - Used Then
                    Call RejectBytePath(4, Failure)
                    Exit Function
                End If
                If TryCopyByteRange(Bytes, Start, Scratch, Used, ComponentCount) = False Then
                    Call RejectBytePath(8, Failure)
                    Exit Function
                End If
                Used = Used + ComponentCount
            End If
        End If
    Wend
    If Used = 0 Then
        Scratch(0) = 46
        Used = 1
    End If
    Failure = 0
    TryBuildNormalizedBytePath = True
End Function

Function TryPublishBytePath(ByRef Scratch() As Byte, ByVal Used As Long, ByRef Published() As Byte, ByRef Failure As Long) As Boolean
    TryPublishBytePath = False
    Failure = 8
    If TryValidateBytePath(Scratch, Used, Failure) = False Then
        Exit Function
    End If
    Dim Prepared() As Byte
    If TryResizeByteStorage(Prepared, Used, False) = False Then
        Call RejectBytePath(8, Failure)
        Exit Function
    End If
    If TryCopyByteRange(Scratch, 0, Prepared, 0, Used) = False Then
        Call RejectBytePath(8, Failure)
        Exit Function
    End If
    If TryCopyByteStorage(Published, Prepared) = False Then
        Call RejectBytePath(8, Failure)
        Exit Function
    End If
    Failure = 0
    TryPublishBytePath = True
End Function

' Independent normalized relative result; retains no references. Caller owns
' mutable arrays, seeds Failure=8/LeadingParents=0; failure keeps Published.
' All component spelling is retained, including Unicode bytes. Success keeps Err.
Function TryNormalizeRelativePathBytes(ByRef Path() As Byte, ByRef Published() As Byte, ByRef LeadingParents As Long, ByRef Failure As Long) As Boolean
    TryNormalizeRelativePathBytes = False
    LeadingParents = 0
    Failure = 8
    Dim Snapshot() As Byte
    Dim Count As Long = 0
    If TrySnapshotBytePath(Path, Snapshot, Count, Failure) = False Then
        Exit Function
    End If
    If IsBytePathSeparator(Snapshot(0)) Then
        Call RejectBytePath(2, Failure)
        Exit Function
    End If
    If Count >= 2 Then
        If Snapshot(1) = 58 Then
            Call RejectBytePath(2, Failure)
            Exit Function
        End If
    End If
    Dim Scratch() As Byte
    Dim Used As Long = 0
    Dim Parents As Long = 0
    Failure = 8
    If TryBuildNormalizedBytePath(Snapshot, Count, 0, 0, Scratch, Used, Parents, Failure) = False Then
        Exit Function
    End If
    Failure = 8
    If TryPublishBytePath(Scratch, Used, Published, Failure) = False Then
        Exit Function
    End If
    LeadingParents = Parents
    Failure = 0
    TryNormalizeRelativePathBytes = True
End Function

' Resolves against a captured absolute base, without consulting the host. Inputs
' may be shared immutably. Complete independent publication preserves old output
' on failure; no mutable state/references survive the call. Success keeps Err.
Function TryResolvePathBytes(ByRef BaseDirectory() As Byte, ByRef Path() As Byte, ByRef Published() As Byte, ByRef Failure As Long) As Boolean
    TryResolvePathBytes = False
    Failure = 8
    Dim BaseBytes() As Byte
    Dim BaseCount As Long = 0
    If TrySnapshotBytePath(BaseDirectory, BaseBytes, BaseCount, Failure) = False Then
        Exit Function
    End If
    Dim BaseKind As Long = 0
    Dim BaseEnd As Long = 0
    Failure = 8
    If TryReadBytePathRoot(BaseBytes, BaseCount, BaseKind, BaseEnd, Failure) = False Then
        Exit Function
    End If
    If BaseKind = 0 Then
        Call RejectBytePath(2, Failure)
        Exit Function
    End If
    Dim BaseScratch() As Byte
    Dim BaseUsed As Long = 0
    Dim Parents As Long = 0
    Failure = 8
    If TryBuildNormalizedBytePath(BaseBytes, BaseCount, BaseKind, BaseEnd, BaseScratch, BaseUsed, Parents, Failure) = False Then
        Exit Function
    End If
    Dim PathBytes() As Byte
    Dim PathCount As Long = 0
    Failure = 8
    If TrySnapshotBytePath(Path, PathBytes, PathCount, Failure) = False Then
        Exit Function
    End If
    Dim PathKind As Long = 0
    Dim PathEnd As Long = 0
    Failure = 8
    If TryReadBytePathRoot(PathBytes, PathCount, PathKind, PathEnd, Failure) = False Then
        Exit Function
    End If
    Dim Scratch() As Byte
    Dim Used As Long = 0
    If PathKind <> 0 Then
        Failure = 8
        If TryBuildNormalizedBytePath(PathBytes, PathCount, PathKind, PathEnd, Scratch, Used, Parents, Failure) = False Then
            Exit Function
        End If
    Else
        Dim Combined As ByteBuffer
        If TryReserveByteBuffer(Combined, BaseUsed + PathCount + 1) = False Then
            Call RejectBytePath(8, Failure)
            Exit Function
        End If
        If TryAppendBytes(Combined, BaseScratch, 0, BaseUsed) = False Then
            Call RejectBytePath(8, Failure)
            Exit Function
        End If
        If TryAppendByte(Combined, 47) = False Then
            Call RejectBytePath(8, Failure)
            Exit Function
        End If
        If TryAppendBytes(Combined, PathBytes, 0, PathCount) = False Then
            Call RejectBytePath(8, Failure)
            Exit Function
        End If
        Failure = 8
        If TryBuildNormalizedBytePath(Combined.Storage, Combined.Count, BaseKind, BaseEnd, Scratch, Used, Parents, Failure) = False Then
            Exit Function
        End If
    End If
    Failure = 8
    TryResolvePathBytes = TryPublishBytePath(Scratch, Used, Published, Failure)
End Function
