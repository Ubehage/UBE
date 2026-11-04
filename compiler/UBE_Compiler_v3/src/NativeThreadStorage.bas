UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeThreadStorage"

Type NativeThreadStorage
    DirectoryRange As NativeDefinitionRange
    TemplateRange As NativeDefinitionRange
    IndexRange As NativeDefinitionRange
    CallbacksRange As NativeDefinitionRange
    Alignment As Long
    Status As Long
End Type

Private Function ValidNativeThreadStorage(ByRef State As NativeThreadStorage) As Boolean
    ValidNativeThreadStorage = False
    If State.Status <> 1 Or State.Alignment < 8 Or State.Alignment > 8192 Then
        Exit Function
    End If
    If ValidNativeRelocationTarget(State.DirectoryRange) = False Or ValidNativeRelocationTarget(State.TemplateRange) = False Or ValidNativeRelocationTarget(State.IndexRange) = False Or ValidNativeRelocationTarget(State.CallbacksRange) = False Then
        Exit Function
    End If
    If State.DirectoryRange.ByteCount <> 40 Or State.IndexRange.ByteCount <> 4 Or State.CallbacksRange.ByteCount Mod 8 <> 0 Then
        Exit Function
    End If
    If State.DirectoryRange.InitializedBytes <> 40 Or State.IndexRange.InitializedBytes <> 4 Or State.CallbacksRange.InitializedBytes <> State.CallbacksRange.ByteCount Or State.TemplateRange.InitializedBytes <> State.TemplateRange.ByteCount Then
        Exit Function
    End If
    ValidNativeThreadStorage = True
End Function

Function TryReadNativeThreadStorage(ByRef Bytes() As Byte, ByRef Layout As NativeObjectLayout, ByRef Inspection As NativeInspection, ByRef Result As NativeThreadStorage, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryReadNativeThreadStorage = False
    Call ResetNativeFailure(Failure)
    If Layout.Kind <> 2 Or Layout.Length <> ByteStorageLength(Bytes) Or Layout.ImageBase < 0 Then
        Exit Function
    End If
    Dim Address As LongLong = 0
    Dim Size As LongLong = 0
    If TryReadNativeImageDirectory(Bytes, Layout, 9, Inspection, Address, Size, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Address = 0 Or Address Mod 8 <> 0 Or Size <> 40 Then
        Exit Function
    End If
    Dim Prepared As NativeThreadStorage
    If TryLocateNativeImageRange(Bytes, Layout, Address, 40, Inspection, Prepared.DirectoryRange, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim WriteFlag As LongLong = 1073741824
    WriteFlag = WriteFlag * 2
    Failure.Code = 1506
    If NativeInitializedImageDataCharacteristics(Prepared.DirectoryRange.Characteristics) = False Or Prepared.DirectoryRange.Characteristics >= WriteFlag Then
        Exit Function
    End If
    If TryValidateNativeContributionIsolation(Bytes, Layout, Prepared.DirectoryRange, Inspection, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim First As Long = Prepared.DirectoryRange.FileFirst
    Dim StartAddress As LongLong = 0
    Dim EndAddress As LongLong = 0
    Dim IndexAddress As LongLong = 0
    Dim CallbacksAddress As LongLong = 0
    Dim ZeroFill As LongLong = 0
    Dim Flags As LongLong = 0
    If TryReadNativeBits(Bytes, Inspection, First, 8, StartAddress, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, First + 8, 8, EndAddress, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, First + 16, 8, IndexAddress, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, First + 24, 8, CallbacksAddress, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, First + 32, 4, ZeroFill, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, First + 36, 4, Flags, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If StartAddress < Layout.ImageBase Or EndAddress <= StartAddress Or IndexAddress < Layout.ImageBase Or CallbacksAddress < Layout.ImageBase Or ZeroFill <> 0 Then
        Exit Function
    End If
    If EndAddress - StartAddress > 2147483647 Or StartAddress Mod 8 <> 0 Or IndexAddress Mod 4 <> 0 Or CallbacksAddress Mod 8 <> 0 Then
        Exit Function
    End If
    If Flags Mod 1048576 <> 0 Then
        Exit Function
    End If
    Dim AlignmentCode As LongLong = Flags \ 1048576
    If AlignmentCode < 4 Or AlignmentCode > 14 Then
        Exit Function
    End If
    Prepared.Alignment = 1
    Dim Bit As Long = 1
    While Bit < AlignmentCode
        Prepared.Alignment = Prepared.Alignment * 2
        Bit = Bit + 1
    Wend
    If TryLocateNativeImageRange(Bytes, Layout, StartAddress - Layout.ImageBase, EndAddress - StartAddress, Inspection, Prepared.TemplateRange, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Prepared.TemplateRange.SectionOffset <> 0 Or NativeInitializedImageDataCharacteristics(Prepared.TemplateRange.Characteristics) = False Or Prepared.TemplateRange.Characteristics < WriteFlag Then
        Exit Function
    End If
    If TryValidateNativeContributionIsolation(Bytes, Layout, Prepared.TemplateRange, Inspection, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryLocateNativeImageRange(Bytes, Layout, IndexAddress - Layout.ImageBase, 4, Inspection, Prepared.IndexRange, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If NativeInitializedImageDataCharacteristics(Prepared.IndexRange.Characteristics) = False Or Prepared.IndexRange.Characteristics < WriteFlag Then
        Exit Function
    End If
    If NativeImageRangeOverlaps(Prepared.IndexRange.RelativeAddress, 4, Prepared.TemplateRange) Or NativeImageRangeOverlaps(Prepared.IndexRange.RelativeAddress, 4, Prepared.DirectoryRange) Or NativeImageRangeOverlaps(Prepared.TemplateRange.RelativeAddress, Prepared.TemplateRange.ByteCount, Prepared.DirectoryRange) Then
        Exit Function
    End If
    If TryValidateNativeContributionIsolation(Bytes, Layout, Prepared.IndexRange, Inspection, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Value As LongLong = 0
    If TryReadNativeBits(Bytes, Inspection, Prepared.IndexRange.FileFirst, 4, Value, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Value <> 0 Then
        Exit Function
    End If
    Dim Section As NativeObjectSection
    Dim SectionIndex As Long = -1
    Address = CallbacksAddress - Layout.ImageBase
    If TryLocateNativeImageSpan(Bytes, Layout, Address, 8, Inspection, Section, SectionIndex, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If NativeInitializedImageDataCharacteristics(Section.Characteristics) = False Then
        Exit Function
    End If
    Dim Offset As LongLong = Address - Section.VirtualAddress
    Dim Entries As Long = (Section.InitializedBytes - Offset) \ 8
    Dim Index As Long = 0
    Dim Terminated As Boolean = False
    While Index < Entries And Terminated = False
        If TryReadNativeBits(Bytes, Inspection, Section.RawFirst + Offset + Index * 8, 8, Value, Cancellation, Failure) = False Then
            Exit Function
        End If
        Failure.Code = 1506
        If Value = 0 Then
            Terminated = True
        Else
            If Value < Layout.ImageBase Then
                Exit Function
            End If
            Dim CodeRange As NativeDefinitionRange
            If TryLocateNativeImageRange(Bytes, Layout, Value - Layout.ImageBase, 1, Inspection, CodeRange, Cancellation, Failure) = False Then
                Exit Function
            End If
            Failure.Code = 1506
            If NativeReadableCodeCharacteristics(CodeRange.Characteristics) = False Or (CodeRange.Characteristics \ 33554432) Mod 2 <> 0 Then
                Exit Function
            End If
            If TryValidateNativeContributionIsolation(Bytes, Layout, CodeRange, Inspection, Cancellation, Failure) = False Then
                Exit Function
            End If
        End If
        Index = Index + 1
    Wend
    Failure.Code = 1506
    If Terminated = False Then
        Exit Function
    End If
    If TryLocateNativeImageRange(Bytes, Layout, Address, Index * 8, Inspection, Prepared.CallbacksRange, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If NativeImageRangeOverlaps(Address, Index * 8, Prepared.DirectoryRange) Or NativeImageRangeOverlaps(Address, Index * 8, Prepared.TemplateRange) Or NativeImageRangeOverlaps(Address, Index * 8, Prepared.IndexRange) Then
        Exit Function
    End If
    If TryValidateNativeContributionIsolation(Bytes, Layout, Prepared.CallbacksRange, Inspection, Cancellation, Failure) = False Then
        Exit Function
    End If
    Prepared.Status = 1
    Result = Prepared
    Failure.Code = 0
    Failure.Resource = 0
    TryReadNativeThreadStorage = True
End Function

Function TryBindNativeThreadIndex(ByRef Instruction As NativeInstruction, ByRef Target As NativeDefinitionRange, ByVal Position As LongLong, ByRef Storage As NativeThreadStorage, ByRef Inspection As NativeInspection, ByRef Result As NativeDefinitionRange, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryBindNativeThreadIndex = False
    Call ResetNativeFailure(Failure)
    If ValidNativeThreadStorage(Storage) = False Or ValidNativeRelocationTarget(Target) = False Or Target.SymbolIndex < 0 Or Target.ByteCount <> 1 Or Position < 0 Or Instruction.ByteCount < 1 Or Instruction.ByteCount > 15 Then
        Exit Function
    End If
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Position <> Storage.IndexRange.RelativeAddress Or Instruction.Flow <> 0 Or Instruction.MemoryBytes <> 4 Or Instruction.MemoryWrite <> 0 Or Instruction.MemoryBase <> -2 Or Instruction.MemoryIndex <> -1 Or Instruction.Segment <> 0 Then
        Exit Function
    End If
    Dim Prepared As NativeDefinitionRange
    Prepared = Storage.IndexRange
    Prepared.SymbolIndex = Target.SymbolIndex
    If NativeDefinitionAnchorMatches(Target, Prepared) = False Then
        Exit Function
    End If
    Result = Prepared
    Failure.Code = 0
    Failure.Resource = 0
    TryBindNativeThreadIndex = True
End Function

Function TryValidateNativeThreadMember(ByRef Expected As NativeExpectedDefinition, ByRef Retained As NativeRetainedDefinition, ByRef Bytes() As Byte, ByRef Layout As NativeObjectLayout, ByRef Storage As NativeThreadStorage, ByRef Inspection As NativeInspection, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryValidateNativeThreadMember = False
    Call ResetNativeFailure(Failure)
    If ValidNativeThreadStorage(Storage) = False Or Layout.Kind <> 2 Or Layout.Length <> ByteStorageLength(Bytes) Or Retained.Present <> 1 Or Expected.StorageBytes < 1 Then
        Exit Function
    End If
    If Expected.Family <> 12 And Expected.Family <> 22 Then
        Exit Function
    End If
    If ValidNativeRelocationTarget(Retained.ImageRange) = False Or Retained.ImageRange.SymbolIndex < 0 Or Retained.ImageRange.ByteCount <> Expected.StorageBytes Then
        Exit Function
    End If
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If ValidNativeRetentionRange(Expected, Retained.ImageRange) = False Or Retained.ImageRange.InitializedBytes <> Expected.StorageBytes Or Storage.TemplateRange.SectionOffset <> 0 Then
        Exit Function
    End If
    Dim Range As NativeDefinitionRange
    Range = Retained.ImageRange
    If Range.SectionIndex <> Storage.TemplateRange.SectionIndex Or Range.Characteristics <> Storage.TemplateRange.Characteristics Or Range.RelativeAddress < Storage.TemplateRange.RelativeAddress Then
        Exit Function
    End If
    Dim Offset As LongLong = Range.RelativeAddress - Storage.TemplateRange.RelativeAddress
    If Offset > Storage.TemplateRange.ByteCount Then
        Exit Function
    End If
    If Range.ByteCount > Storage.TemplateRange.ByteCount - Offset Then
        Exit Function
    End If
    If Range.SectionOffset <> Offset Or Range.FileFirst <> Storage.TemplateRange.FileFirst + Offset Or Range.Address <> Storage.TemplateRange.Address + Offset Then
        Exit Function
    End If
    Dim Cursor As Long = 0
    While Cursor < Range.ByteCount
        Dim Width As Long = 8
        If Range.ByteCount - Cursor < 8 Then
            Width = 1
        End If
        Dim Value As LongLong = 0
        If TryReadNativeBits(Bytes, Inspection, Range.FileFirst + Cursor, Width, Value, Cancellation, Failure) = False Then
            Exit Function
        End If
        Failure.Code = 1506
        If Value <> 0 Then
            Exit Function
        End If
        Cursor = Cursor + Width
    Wend
    Failure.Code = 0
    Failure.Resource = 0
    TryValidateNativeThreadMember = True
End Function
