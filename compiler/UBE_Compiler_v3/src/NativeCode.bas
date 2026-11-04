UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeCode"

Private Function NativeResidentCodeCharacteristics(ByVal Flags As LongLong) As Boolean
    NativeResidentCodeCharacteristics = NativeReadableCodeCharacteristics(Flags) And (Flags \ 64) Mod 2 = 0 And (Flags \ 128) Mod 2 = 0 And (Flags \ 512) Mod 2 = 0 And (Flags \ 2048) Mod 2 = 0 And (Flags \ 4096) Mod 2 = 0 And (Flags \ 33554432) Mod 2 = 0
End Function

Private Function TryCompareNativeCodeSpan(ByRef ObjectBytes() As Byte, ByVal ObjectFirst As Long, ByRef ImageBytes() As Byte, ByVal ImageFirst As Long, ByVal Count As Long, ByRef Inspection As NativeInspection, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryCompareNativeCodeSpan = False
    Dim Equal As Boolean = False
    If TryCompareNativeByteSpan(ObjectBytes, ObjectFirst, ImageBytes, ImageFirst, Count, Inspection, Equal, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Equal = False Then
        Exit Function
    End If
    Failure.Code = 0
    Failure.Resource = 0
    TryCompareNativeCodeSpan = True
End Function

Function TryValidateNativeCodeContribution(ByRef Anchor As NativeRetainedDefinition, ByRef ObjectInventory As NativeSymbolInventory, ByRef ObjectBytes() As Byte, ByRef ObjectLayout As NativeObjectLayout, ByRef ImageInventory As NativeSymbolInventory, ByRef ImageBytes() As Byte, ByRef ImageLayout As NativeObjectLayout, ByRef Inspection As NativeInspection, ByRef Result As NativeRetainedDefinition, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryValidateNativeCodeContribution = False
    Call ResetNativeFailure(Failure)
    If Anchor.Present <> 1 Or Anchor.ObjectRange.TypeCode <> 32 Or Anchor.ImageRange.TypeCode <> 32 Or Anchor.ObjectRange.ByteCount <> 1 Or Anchor.ImageRange.ByteCount <> 1 Or Anchor.ObjectRange.InitializedBytes <> 1 Or Anchor.ImageRange.InitializedBytes <> 1 Then
        Exit Function
    End If
    If ObjectLayout.Kind <> 1 Or ImageLayout.Kind <> 2 Or ObjectLayout.Length <> ByteStorageLength(ObjectBytes) Or ImageLayout.Length <> ByteStorageLength(ImageBytes) Or ObjectInventory.Status <> 1 Or ImageInventory.Status <> 1 Then
        Exit Function
    End If
    If ObjectInventory.Length <> ObjectLayout.Length Or ObjectInventory.SymbolCapacity <> ObjectLayout.SymbolCount Or ImageInventory.Length <> ImageLayout.Length Or ImageInventory.SymbolCapacity <> ImageLayout.SymbolCount Then
        Exit Function
    End If
    If Anchor.ObjectRange.SymbolIndex < 0 Or Anchor.ObjectRange.SymbolIndex >= ObjectLayout.SymbolCount Or Anchor.ImageRange.SymbolIndex < 0 Or Anchor.ImageRange.SymbolIndex >= ImageLayout.SymbolCount Or Anchor.ObjectRange.SectionOffset < 0 Or Anchor.ImageRange.SectionOffset < Anchor.ObjectRange.SectionOffset Then
        Exit Function
    End If
    Dim Original As NativeObjectSection
    Dim Linked As NativeObjectSection
    If TryReadNativeObjectSection(ObjectBytes, Inspection, ObjectLayout, Anchor.ObjectRange.SectionIndex, Original, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeObjectSection(ImageBytes, Inspection, ImageLayout, Anchor.ImageRange.SectionIndex, Linked, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If NativeResidentCodeCharacteristics(Original.Characteristics) = False Or NativeResidentCodeCharacteristics(Linked.Characteristics) = False Or Original.RawBytes < 1 Or Original.InitializedBytes <> Original.RawBytes Then
        Exit Function
    End If
    If Anchor.ObjectRange.SectionOffset >= Original.RawBytes Or Anchor.ImageRange.SectionOffset >= Linked.InitializedBytes Then
        Exit Function
    End If
    If Anchor.ObjectRange.FileFirst <> Original.RawFirst + Anchor.ObjectRange.SectionOffset Or Anchor.ImageRange.FileFirst <> Linked.RawFirst + Anchor.ImageRange.SectionOffset Or Anchor.ObjectRange.RelativeAddress <> 0 Or Anchor.ObjectRange.Address <> 0 Or Anchor.ObjectRange.Characteristics <> Original.Characteristics Or Anchor.ImageRange.Characteristics <> Linked.Characteristics Then
        Exit Function
    End If
    Dim Offset As LongLong = Anchor.ImageRange.SectionOffset - Anchor.ObjectRange.SectionOffset
    If Original.RawBytes > Linked.InitializedBytes - Offset Then
        Exit Function
    End If
    If ImageLayout.ImageBase < 0 Or Linked.VirtualAddress < 0 Or Linked.VirtualAddress > ImageLayout.ImageBytes Then
        Exit Function
    End If
    If Offset > ImageLayout.ImageBytes - Linked.VirtualAddress Then
        Exit Function
    End If
    Dim RelativeAddress As LongLong = Linked.VirtualAddress + Offset
    If Original.RawBytes > ImageLayout.ImageBytes - RelativeAddress Or RelativeAddress > SemanticLongLongMaximum() - ImageLayout.ImageBase Then
        Exit Function
    End If
    Dim Address As LongLong = ImageLayout.ImageBase + RelativeAddress
    If Original.RawBytes > SemanticLongLongMaximum() - Address Then
        Exit Function
    End If
    If Anchor.ImageRange.RelativeAddress <> RelativeAddress + Anchor.ObjectRange.SectionOffset Or Anchor.ImageRange.Address <> Address + Anchor.ObjectRange.SectionOffset Then
        Exit Function
    End If
    Dim AlignmentCode As Long = (Original.Characteristics \ 1048576) Mod 16
    If AlignmentCode < 1 Or AlignmentCode > 14 Then
        Exit Function
    End If
    Dim Alignment As Long = 1
    While AlignmentCode > 1
        Alignment = Alignment * 2
        AlignmentCode = AlignmentCode - 1
    Wend
    If RelativeAddress Mod Alignment <> 0 Then
        Exit Function
    End If
    Dim Prepared As NativeRetainedDefinition
    Prepared.Present = 1
    Prepared.ObjectRange.SymbolIndex = -1
    Prepared.ObjectRange.SectionIndex = Anchor.ObjectRange.SectionIndex
    Prepared.ObjectRange.FileFirst = Original.RawFirst
    Prepared.ObjectRange.ByteCount = Original.RawBytes
    Prepared.ObjectRange.InitializedBytes = Original.RawBytes
    Prepared.ObjectRange.TypeCode = 32
    Prepared.ObjectRange.Characteristics = Original.Characteristics
    Prepared.ImageRange.SymbolIndex = -1
    Prepared.ImageRange.SectionIndex = Anchor.ImageRange.SectionIndex
    Prepared.ImageRange.FileFirst = Linked.RawFirst + Offset
    Prepared.ImageRange.ByteCount = Original.RawBytes
    Prepared.ImageRange.InitializedBytes = Original.RawBytes
    Prepared.ImageRange.TypeCode = 32
    Prepared.ImageRange.SectionOffset = Offset
    Prepared.ImageRange.RelativeAddress = RelativeAddress
    Prepared.ImageRange.Address = Address
    Prepared.ImageRange.Characteristics = Linked.Characteristics
    If TryValidateNativeContributionIsolation(ObjectBytes, ObjectLayout, Prepared.ObjectRange, Inspection, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryValidateNativeContributionIsolation(ImageBytes, ImageLayout, Prepared.ImageRange, Inspection, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Position As Long = 0
    Dim Index As Long = 0
    While Index < Original.RelocationCount
        Dim Relocation As NativeObjectRelocation
        If TryReadNativeObjectRelocation(ObjectBytes, Inspection, ObjectLayout, Original, Index, Relocation, Cancellation, Failure) = False Then
            Exit Function
        End If
        If Relocation.Kind <> 0 Then
            Failure.Code = 1506
            If Relocation.Offset < Position Then
                Exit Function
            End If
            If TryCompareNativeCodeSpan(ObjectBytes, Original.RawFirst + Position, ImageBytes, Prepared.ImageRange.FileFirst + Position, Relocation.Offset - Position, Inspection, Cancellation, Failure) = False Then
                Exit Function
            End If
            Dim Target As NativeDefinitionRange
            Dim Symbol As NativeObjectSymbol
            If TryReadNativeIndexedSymbol(ObjectInventory, Relocation.TargetIndex, Inspection, Symbol, Cancellation, Failure) = False Then
                Exit Function
            End If
            If Symbol.AuxiliaryCount > 0 Then
                Dim Constant As NativeRetainedDefinition
                If TryBindNativeConstantContribution(Relocation.TargetIndex, ObjectInventory, ObjectBytes, ObjectLayout, ImageBytes, ImageLayout, Inspection, Constant, Cancellation, Failure) = False Then
                    Exit Function
                End If
                Target = Constant.ImageRange
            Else
                If TryResolveNativeNamedRelocation(Relocation, ObjectInventory, ObjectBytes, ObjectLayout, ImageInventory, ImageBytes, ImageLayout, Inspection, Target, Cancellation, Failure) = False Then
                    Exit Function
                End If
            End If
            If TryValidateNativeRelocationValue(Relocation, Target, RelativeAddress + Relocation.Offset, ObjectBytes, Original.RawFirst + Relocation.Offset, ImageBytes, Prepared.ImageRange.FileFirst + Relocation.Offset, Inspection, Cancellation, Failure) = False Then
                Exit Function
            End If
            Position = Relocation.Offset + Relocation.Width
        End If
        Index = Index + 1
    Wend
    If TryCompareNativeCodeSpan(ObjectBytes, Original.RawFirst + Position, ImageBytes, Prepared.ImageRange.FileFirst + Position, Original.RawBytes - Position, Inspection, Cancellation, Failure) = False Then
        Exit Function
    End If
    Result = Prepared
    Failure.Code = 0
    Failure.Resource = 0
    TryValidateNativeCodeContribution = True
End Function

Private Intrinsic Function NativeCodeMapLength(ByRef Values() As NativeRetainedDefinition) As Long
Attribute NativeCodeMapLength.UBE_Primitive = "Array.Length"
End Function

Function ValidNativeCodeContribution(ByRef Value As NativeRetainedDefinition) As Boolean
    ValidNativeCodeContribution = False
    If Value.Present <> 1 Or Value.ObjectRange.SymbolIndex <> -1 Or Value.ImageRange.SymbolIndex <> -1 Or Value.ObjectRange.TypeCode <> 32 Or Value.ImageRange.TypeCode <> 32 Then
        Exit Function
    End If
    If Value.ObjectRange.SectionIndex < 0 Or Value.ObjectRange.SectionIndex > 95 Or Value.ImageRange.SectionIndex < 0 Or Value.ImageRange.SectionIndex > 95 Then
        Exit Function
    End If
    Dim Count As Long = Value.ObjectRange.ByteCount
    If Count < 1 Or Value.ObjectRange.InitializedBytes <> Count Or Value.ImageRange.ByteCount <> Count Or Value.ImageRange.InitializedBytes <> Count Or Value.ObjectRange.FileFirst < 0 Or Value.ImageRange.FileFirst < 0 Then
        Exit Function
    End If
    If Count > 2147483647 - Value.ObjectRange.FileFirst Or Count > 2147483647 - Value.ImageRange.FileFirst Then
        Exit Function
    End If
    If Value.ObjectRange.SectionOffset <> 0 Or Value.ObjectRange.RelativeAddress <> 0 Or Value.ObjectRange.Address <> 0 Then
        Exit Function
    End If
    Dim Maximum As LongLong = 65536
    Maximum = Maximum * 65536 - 1
    If Value.ImageRange.SectionOffset < 0 Or Value.ImageRange.RelativeAddress < Value.ImageRange.SectionOffset Or Value.ImageRange.RelativeAddress > Maximum Or Value.ImageRange.Address < Value.ImageRange.RelativeAddress Then
        Exit Function
    End If
    If Count > Maximum - Value.ImageRange.RelativeAddress Or Count > SemanticLongLongMaximum() - Value.ImageRange.Address Then
        Exit Function
    End If
    If Value.ObjectRange.Characteristics < 0 Or Value.ObjectRange.Characteristics > Maximum Or Value.ImageRange.Characteristics < 0 Or Value.ImageRange.Characteristics > Maximum Then
        Exit Function
    End If
    If NativeResidentCodeCharacteristics(Value.ObjectRange.Characteristics) = False Or NativeResidentCodeCharacteristics(Value.ImageRange.Characteristics) = False Then
        Exit Function
    End If
    ValidNativeCodeContribution = True
End Function

Function TryValidateNativeCodeAnchor(ByRef Anchor As NativeRetainedDefinition, ByRef Contribution As NativeRetainedDefinition, ByRef Inspection As NativeInspection, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryValidateNativeCodeAnchor = False
    Call ResetNativeFailure(Failure)
    If ValidNativeCodeContribution(Contribution) = False Or Anchor.Present <> 1 Or Anchor.ObjectRange.SymbolIndex < 0 Or Anchor.ImageRange.SymbolIndex < 0 Or Anchor.ObjectRange.TypeCode <> 32 Or Anchor.ImageRange.TypeCode <> 32 Or Anchor.ObjectRange.ByteCount <> 1 Or Anchor.ImageRange.ByteCount <> 1 Or Anchor.ObjectRange.InitializedBytes <> 1 Or Anchor.ImageRange.InitializedBytes <> 1 Then
        Exit Function
    End If
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    Dim Offset As LongLong = Anchor.ObjectRange.SectionOffset
    If Offset < 0 Or Offset >= Contribution.ObjectRange.ByteCount Then
        Exit Function
    End If
    If Anchor.ObjectRange.SectionIndex <> Contribution.ObjectRange.SectionIndex Or Anchor.ImageRange.SectionIndex <> Contribution.ImageRange.SectionIndex Or Anchor.ObjectRange.Characteristics <> Contribution.ObjectRange.Characteristics Or Anchor.ImageRange.Characteristics <> Contribution.ImageRange.Characteristics Then
        Exit Function
    End If
    If Anchor.ObjectRange.FileFirst <> Contribution.ObjectRange.FileFirst + Offset Or Anchor.ObjectRange.RelativeAddress <> 0 Or Anchor.ObjectRange.Address <> 0 Then
        Exit Function
    End If
    If Anchor.ImageRange.FileFirst <> Contribution.ImageRange.FileFirst + Offset Or Anchor.ImageRange.SectionOffset <> Contribution.ImageRange.SectionOffset + Offset Or Anchor.ImageRange.RelativeAddress <> Contribution.ImageRange.RelativeAddress + Offset Or Anchor.ImageRange.Address <> Contribution.ImageRange.Address + Offset Then
        Exit Function
    End If
    Failure.Code = 0
    Failure.Resource = 0
    TryValidateNativeCodeAnchor = True
End Function

Function TryValidateNativeCodeCoverage(ByRef Bytes() As Byte, ByRef Layout As NativeObjectLayout, ByRef Contributions() As NativeRetainedDefinition, ByRef Inspection As NativeInspection, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryValidateNativeCodeCoverage = False
    Call ResetNativeFailure(Failure)
    If Layout.Kind <> 1 Or Layout.Length <> ByteStorageLength(Bytes) Or Layout.SectionCount < 1 Or Layout.SectionCount > 96 Or NativeCodeMapLength(Contributions) <> Layout.SectionCount Then
        Exit Function
    End If
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Index As Long = 0
    While Index < Layout.SectionCount
        Dim Section As NativeObjectSection
        If TryReadNativeObjectSection(Bytes, Inspection, Layout, Index, Section, Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim Mapped As NativeRetainedDefinition
        Mapped = Contributions(Index)
        Failure.Code = 1506
        If (Section.Characteristics \ 536870912) Mod 2 <> 0 And Section.RawBytes > 0 Then
            If Mapped.Present <> 1 Then
                Exit Function
            End If
            Call ResetNativeFailure(Failure)
            If ValidNativeCodeContribution(Mapped) = False Then
                Exit Function
            End If
            Failure.Code = 1506
            If Mapped.ObjectRange.SectionIndex <> Index Or Mapped.ObjectRange.FileFirst <> Section.RawFirst Or Mapped.ObjectRange.ByteCount <> Section.RawBytes Or Mapped.ObjectRange.InitializedBytes <> Section.InitializedBytes Or Mapped.ObjectRange.Characteristics <> Section.Characteristics Then
                Exit Function
            End If
        Else
            If Mapped.Present <> 0 Then
                Exit Function
            End If
        End If
        Index = Index + 1
    Wend
    Failure.Code = 0
    Failure.Resource = 0
    TryValidateNativeCodeCoverage = True
End Function
