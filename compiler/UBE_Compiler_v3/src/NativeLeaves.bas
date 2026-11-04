UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeLeaves"

' Fresh/disposable private owner; see ../NATIVE-LEAF-IMPLEMENTATION.md.
Type NativeLeaf
    Marks() As Byte
    Pending() As Long
    MarkCapacity As Long
    PendingCapacity As Long
    First As Long
    CodeBytes As Long
    InstructionCount As Long
    Status As Long
End Type
Private Intrinsic Function NativeLeafPendingLength(ByRef Values() As Long) As Long
Attribute NativeLeafPendingLength.UBE_Primitive = "Array.Length"
End Function

Private Function NativeLeafFenceMatchesAnchor(ByRef Anchor As NativeDefinitionRange, ByRef Fence As NativeDefinitionRange) As Boolean
    NativeLeafFenceMatchesAnchor = False
    If Anchor.TypeCode <> 32 Or Anchor.ByteCount <> 1 Or Anchor.InitializedBytes <> 1 Or Anchor.SymbolIndex < 0 Or Anchor.SectionIndex < 0 Or Anchor.FileFirst < 0 Or Anchor.SectionOffset < 0 Then
        Exit Function
    End If
    If Fence.ByteCount < 1 Or Fence.InitializedBytes <> Fence.ByteCount Or Fence.SymbolIndex <> Anchor.SymbolIndex Or Fence.SectionIndex <> Anchor.SectionIndex Or Fence.FileFirst <> Anchor.FileFirst Or Fence.TypeCode <> Anchor.TypeCode Or Fence.SectionOffset <> Anchor.SectionOffset Or Fence.RelativeAddress <> Anchor.RelativeAddress Or Fence.Address <> Anchor.Address Or Fence.Characteristics <> Anchor.Characteristics Then
        Exit Function
    End If
    If NativeReadableCodeCharacteristics(Fence.Characteristics) = False Or Fence.ByteCount > 2147483647 - Fence.FileFirst Then
        Exit Function
    End If
    NativeLeafFenceMatchesAnchor = True
End Function

Private Function ValidNativeLeafForFence(ByRef State As NativeLeaf, ByRef Fence As NativeDefinitionRange) As Boolean
    ValidNativeLeafForFence = False
    If State.Status <> 1 Or State.MarkCapacity < 1 Or State.PendingCapacity <> State.MarkCapacity Or ByteStorageLength(State.Marks) <> State.MarkCapacity Or NativeLeafPendingLength(State.Pending) <> State.PendingCapacity Then
        Exit Function
    End If
    If State.CodeBytes < 1 Or State.CodeBytes > State.MarkCapacity Or State.InstructionCount < 1 Or State.InstructionCount > State.CodeBytes Then
        Exit Function
    End If
    If State.First <> Fence.FileFirst Or State.MarkCapacity <> Fence.ByteCount Then
        Exit Function
    End If
    ValidNativeLeafForFence = True
End Function

Function TryBindNativeLeafExtent(ByRef Retained As NativeRetainedDefinition, ByRef ObjectFence As NativeDefinitionRange, ByRef ImageFence As NativeDefinitionRange, ByRef ObjectLeaf As NativeLeaf, ByRef ImageLeaf As NativeLeaf, ByRef Inspection As NativeInspection, ByRef Result As NativeRetainedDefinition, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryBindNativeLeafExtent = False
    Call ResetNativeFailure(Failure)
    If Retained.Present <> 1 Or ObjectLeaf.Status <> 1 Or ImageLeaf.Status <> 1 Then
        Exit Function
    End If
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If NativeLeafFenceMatchesAnchor(Retained.ObjectRange, ObjectFence) = False Or NativeLeafFenceMatchesAnchor(Retained.ImageRange, ImageFence) = False Then
        Exit Function
    End If
    Call ResetNativeFailure(Failure)
    If ValidNativeLeafForFence(ObjectLeaf, ObjectFence) = False Or ValidNativeLeafForFence(ImageLeaf, ImageFence) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If ObjectLeaf.CodeBytes <> ImageLeaf.CodeBytes Or ObjectLeaf.InstructionCount <> ImageLeaf.InstructionCount Then
        Exit Function
    End If
    Dim Position As Long = 0
    Dim Instructions As Long = 0
    While Position < ObjectLeaf.CodeBytes
        Dim ObjectMark As LongLong = 0
        Dim ImageMark As LongLong = 0
        If TryReadNativeBits(ObjectLeaf.Marks, Inspection, Position, 1, ObjectMark, Cancellation, Failure) = False Then
            Exit Function
        End If
        If TryReadNativeBits(ImageLeaf.Marks, Inspection, Position, 1, ImageMark, Cancellation, Failure) = False Then
            Exit Function
        End If
        Failure.Code = 1506
        If ObjectMark <> ImageMark Or (ObjectMark <> 0 And ObjectMark <> 2 And ObjectMark <> 3) Then
            Exit Function
        End If
        If Position = 0 And ObjectMark <> 2 Then
            Exit Function
        End If
        If Position = ObjectLeaf.CodeBytes - 1 And ObjectMark = 0 Then
            Exit Function
        End If
        If ObjectMark = 2 Then
            Instructions = Instructions + 1
        End If
        Position = Position + 1
    Wend
    Failure.Code = 1506
    If Instructions <> ObjectLeaf.InstructionCount Then
        Exit Function
    End If
    Dim Prepared As NativeRetainedDefinition
    Prepared = Retained
    Prepared.ObjectRange.ByteCount = ObjectLeaf.CodeBytes
    Prepared.ObjectRange.InitializedBytes = ObjectLeaf.CodeBytes
    Prepared.ImageRange.ByteCount = ImageLeaf.CodeBytes
    Prepared.ImageRange.InitializedBytes = ImageLeaf.CodeBytes
    Result = Prepared
    Failure.Code = 0
    Failure.Resource = 0
    TryBindNativeLeafExtent = True
End Function
Private Intrinsic Function TryResizeNativeLeafPending(ByRef Values() As Long, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeNativeLeafPending.UBE_Primitive = "Array.TryResize"
End Function

Private Function TryScheduleNativeLeaf(ByRef State As NativeLeaf, ByVal Offset As LongLong, ByRef Count As Long, ByRef Inspection As NativeInspection, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryScheduleNativeLeaf = False
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Offset < 0 Or Offset >= State.MarkCapacity Then
        Exit Function
    End If
    Dim Index As Long = Offset
    If State.Marks(Index) = 3 Then
        Exit Function
    End If
    If State.Marks(Index) = 0 Then
        If Count >= State.PendingCapacity Then
            Exit Function
        End If
        State.Pending(Count) = Index
        Count = Count + 1
        State.Marks(Index) = 1
    End If
    Failure.Code = 0
    TryScheduleNativeLeaf = True
End Function

Function TryInspectNativeLeaf(ByRef State As NativeLeaf, ByRef Bytes() As Byte, ByVal First As Long, ByVal Available As Long, ByRef Inspection As NativeInspection, ByRef Storage As NativeInspectionStorage, ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryInspectNativeLeaf = False
    Call ResetNativeFailure(Failure)
    If State.Status <> 0 Or State.MarkCapacity <> 0 Or State.PendingCapacity <> 0 Or State.First <> 0 Or State.CodeBytes <> 0 Or State.InstructionCount <> 0 Then
        Exit Function
    End If
    If ByteStorageLength(State.Marks) <> 0 Or NativeLeafPendingLength(State.Pending) <> 0 Then
        Exit Function
    End If
    If First < 0 Or Available < 1 Or First > ByteStorageLength(Bytes) Then
        Exit Function
    End If
    If Available > ByteStorageLength(Bytes) - First Then
        Exit Function
    End If
    State.Status = 4
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Payload As LongLong = Available
    Dim Cleanup As NativeFailure
    If TryReserveNativeInspectionStorage(Storage, Limits, Usage, Payload, Failure) = False Then
        Exit Function
    End If
    If TryResizeByteStorage(State.Marks, Available, False) = False Then
        Call TryReleaseNativeInspectionStorage(Storage, Usage, Payload, Cleanup)
        Failure.Code = 1502
        Failure.Resource = 7
        Exit Function
    End If
    State.MarkCapacity = Available
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    Payload = Payload * 4
    If TryReserveNativeInspectionStorage(Storage, Limits, Usage, Payload, Failure) = False Then
        Exit Function
    End If
    If TryResizeNativeLeafPending(State.Pending, Available, False) = False Then
        Call TryReleaseNativeInspectionStorage(Storage, Usage, Payload, Cleanup)
        Failure.Code = 1502
        Failure.Resource = 7
        Exit Function
    End If
    State.PendingCapacity = Available
    Dim PendingCount As Long = 0
    If TryScheduleNativeLeaf(State, 0, PendingCount, Inspection, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Extent As Long = 0
    Dim Instructions As Long = 0
    While PendingCount > 0
        If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
            Exit Function
        End If
        PendingCount = PendingCount - 1
        Dim Position As Long = State.Pending(PendingCount)
        Dim Decoded As NativeInstruction
        If TryReadNativeInstruction(Bytes, First + Position, Available - Position, Inspection, Decoded, Cancellation, Failure) = False Then
            Exit Function
        End If
        Failure.Code = 1506
        If Decoded.Flow < 0 Or Decoded.Flow > 3 Or (Decoded.WrittenRegisters \ 8) Mod 32 <> 0 Or Decoded.WrittenRegisters \ 4096 <> 0 Then
            Exit Function
        End If
        Dim NextPosition As Long = Position + Decoded.ByteCount
        Dim Cursor As Long = Position + 1
        While Cursor < NextPosition
            If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
                Exit Function
            End If
            Failure.Code = 1506
            If State.Marks(Cursor) <> 0 Then
                Exit Function
            End If
            State.Marks(Cursor) = 3
            Cursor = Cursor + 1
        Wend
        State.Marks(Position) = 2
        Instructions = Instructions + 1
        If NextPosition > Extent Then
            Extent = NextPosition
        End If
        If Decoded.Flow = 0 Or Decoded.Flow = 2 Then
            If TryScheduleNativeLeaf(State, NextPosition, PendingCount, Inspection, Cancellation, Failure) = False Then
                Exit Function
            End If
        End If
        If Decoded.Flow = 2 Or Decoded.Flow = 3 Then
            Dim Target As LongLong = NextPosition
            Target = Target + Decoded.RelativeOffset
            If TryScheduleNativeLeaf(State, Target, PendingCount, Inspection, Cancellation, Failure) = False Then
                Exit Function
            End If
        End If
    Wend
    State.First = First
    State.CodeBytes = Extent
    State.InstructionCount = Instructions
    State.Status = 1
    Failure.Code = 0
    Failure.Resource = 0
    TryInspectNativeLeaf = True
End Function

Function TryDisposeNativeLeaf(ByRef State As NativeLeaf, ByRef Storage As NativeInspectionStorage, ByRef Usage As NativeUsage, ByRef Failure As NativeFailure) As Boolean
    TryDisposeNativeLeaf = False
    Call ResetNativeFailure(Failure)
    If State.MarkCapacity < 0 Or State.PendingCapacity < 0 Then
        Exit Function
    End If
    If ByteStorageLength(State.Marks) <> State.MarkCapacity Or NativeLeafPendingLength(State.Pending) <> State.PendingCapacity Then
        Exit Function
    End If
    Dim Payload As LongLong = State.PendingCapacity
    Payload = Payload * 4
    If Payload + State.MarkCapacity > Storage.Payload Or Payload + State.MarkCapacity > Usage.Payload Then
        Exit Function
    End If
    State.Status = 4
    If TryResizeNativeLeafPending(State.Pending, 0, False) = False Then
        Exit Function
    End If
    If TryReleaseNativeInspectionStorage(Storage, Usage, Payload, Failure) = False Then
        Exit Function
    End If
    State.PendingCapacity = 0
    Payload = State.MarkCapacity
    If TryResizeByteStorage(State.Marks, 0, False) = False Then
        Exit Function
    End If
    If TryReleaseNativeInspectionStorage(Storage, Usage, Payload, Failure) = False Then
        Exit Function
    End If
    State.MarkCapacity = 0
    State.First = 0
    State.CodeBytes = 0
    State.InstructionCount = 0
    State.Status = 0
    Failure.Code = 0
    Failure.Resource = 0
    TryDisposeNativeLeaf = True
End Function
