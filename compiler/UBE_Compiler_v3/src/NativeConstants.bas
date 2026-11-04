UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeConstants"

Private Function NativeResidentConstantCharacteristics(ByVal Flags As LongLong) As Boolean
    NativeResidentConstantCharacteristics = NativeReadOnlyDataCharacteristics(Flags) And (Flags \ 32) Mod 2 = 0 And (Flags \ 128) Mod 2 = 0 And (Flags \ 512) Mod 2 = 0 And (Flags \ 2048) Mod 2 = 0 And (Flags \ 4096) Mod 2 = 0 And (Flags \ 33554432) Mod 2 = 0
End Function

Function TryBindNativeConstantContribution(ByVal SymbolIndex As Long, ByRef ObjectInventory As NativeSymbolInventory, ByRef ObjectBytes() As Byte, ByRef ObjectLayout As NativeObjectLayout, ByRef ImageBytes() As Byte, ByRef ImageLayout As NativeObjectLayout, ByRef Inspection As NativeInspection, ByRef Result As NativeRetainedDefinition, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryBindNativeConstantContribution = False
    Call ResetNativeFailure(Failure)
    If ObjectLayout.Kind <> 1 Or ImageLayout.Kind <> 2 Or ObjectInventory.Status <> 1 Then
        Exit Function
    End If
    If ObjectLayout.Length <> ByteStorageLength(ObjectBytes) Or ObjectInventory.Length <> ObjectLayout.Length Or ObjectInventory.SymbolCapacity <> ObjectLayout.SymbolCount Or ImageLayout.Length <> ByteStorageLength(ImageBytes) Then
        Exit Function
    End If
    Dim Symbol As NativeObjectSymbol
    If TryReadNativeIndexedSymbol(ObjectInventory, SymbolIndex, Inspection, Symbol, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Symbol.StorageClass <> 3 Or Symbol.TypeCode <> 0 Or Symbol.Value <> 0 Or Symbol.SectionNumber < 1 Or Symbol.AuxiliaryCount <> 1 Then
        Exit Function
    End If
    Dim Original As NativeObjectSection
    If TryReadNativeObjectSection(ObjectBytes, Inspection, ObjectLayout, Symbol.SectionNumber - 1, Original, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If NativeResidentConstantCharacteristics(Original.Characteristics) = False Or Original.RawBytes < 1 Or Original.InitializedBytes <> Original.RawBytes Or Original.RelocationCount <> 0 Then
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
    Dim SectionName As NativeObjectName
    If TryReadNativeSectionName(ObjectBytes, Inspection, ObjectLayout, Symbol.SectionNumber - 1, SectionName, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Symbol.Name.Count < 1 Or Symbol.Name.Count <> SectionName.Count Then
        Exit Function
    End If
    Dim Position As Long = 0
    Dim Left As LongLong = 0
    Dim Right As LongLong = 0
    While Position < SectionName.Count
        If TryReadNativeBits(ObjectBytes, Inspection, Symbol.Name.First + Position, 1, Left, Cancellation, Failure) = False Then
            Exit Function
        End If
        If TryReadNativeBits(ObjectBytes, Inspection, SectionName.First + Position, 1, Right, Cancellation, Failure) = False Then
            Exit Function
        End If
        Failure.Code = 1506
        If Left <> Right Then
            Exit Function
        End If
        Position = Position + 1
    Wend
    Dim Auxiliary As Long = Symbol.AuxiliaryFirst
    If TryReadNativeBits(ObjectBytes, Inspection, Auxiliary, 4, Left, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Left <> Original.RawBytes Then
        Exit Function
    End If
    If TryReadNativeBits(ObjectBytes, Inspection, Auxiliary + 4, 4, Left, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Left <> 0 Then
        Exit Function
    End If
    ' Non-COMDAT checksum is not used to substitute for full byte comparison.
    If TryReadNativeBits(ObjectBytes, Inspection, Auxiliary + 8, 4, Left, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(ObjectBytes, Inspection, Auxiliary + 12, 2, Left, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Left <> 0 And Left <> Symbol.SectionNumber Then
        Exit Function
    End If
    If TryReadNativeBits(ObjectBytes, Inspection, Auxiliary + 14, 4, Left, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Left <> 0 Then
        Exit Function
    End If
    Dim Prepared As NativeRetainedDefinition
    Prepared.ObjectRange.SymbolIndex = SymbolIndex
    Prepared.ObjectRange.SectionIndex = Symbol.SectionNumber - 1
    Prepared.ObjectRange.FileFirst = Original.RawFirst
    Prepared.ObjectRange.ByteCount = Original.RawBytes
    Prepared.ObjectRange.InitializedBytes = Original.RawBytes
    Prepared.ObjectRange.Characteristics = Original.Characteristics
    Dim SectionIndex As Long = 0
    While SectionIndex < ImageLayout.SectionCount
        Dim Candidate As NativeObjectSection
        If TryReadNativeObjectSection(ImageBytes, Inspection, ImageLayout, SectionIndex, Candidate, Cancellation, Failure) = False Then
            Exit Function
        End If
        If NativeResidentConstantCharacteristics(Candidate.Characteristics) Then
            Dim Offset As Long = 0
            Dim Remainder As Long = Candidate.VirtualAddress Mod Alignment
            If Remainder <> 0 Then
                Offset = Alignment - Remainder
            End If
            While Offset <= Candidate.InitializedBytes - Original.RawBytes
                Dim Equal As Boolean = False
                If TryCompareNativeByteSpan(ObjectBytes, Original.RawFirst, ImageBytes, Candidate.RawFirst + Offset, Original.RawBytes, Inspection, Equal, Cancellation, Failure) = False Then
                    Exit Function
                End If
                If Equal Then
                    Failure.Code = 1506
                    If Prepared.Present <> 0 Then
                        Exit Function
                    End If
                    If ImageLayout.ImageBase < 0 Or Candidate.VirtualAddress < 0 Or Candidate.VirtualAddress > ImageLayout.ImageBytes Then
                        Exit Function
                    End If
                    If Offset > ImageLayout.ImageBytes - Candidate.VirtualAddress Then
                        Exit Function
                    End If
                    Dim RelativeAddress As LongLong = Candidate.VirtualAddress + Offset
                    If Original.RawBytes > ImageLayout.ImageBytes - RelativeAddress Then
                        Exit Function
                    End If
                    Dim Maximum As LongLong = SemanticLongLongMaximum()
                    If RelativeAddress > Maximum - ImageLayout.ImageBase Then
                        Exit Function
                    End If
                    Dim Address As LongLong = ImageLayout.ImageBase + RelativeAddress
                    If Original.RawBytes > Maximum - Address Then
                        Exit Function
                    End If
                    Prepared.Present = 1
                    Prepared.ImageRange.SymbolIndex = -1
                    Prepared.ImageRange.SectionIndex = SectionIndex
                    Prepared.ImageRange.FileFirst = Candidate.RawFirst + Offset
                    Prepared.ImageRange.ByteCount = Original.RawBytes
                    Prepared.ImageRange.InitializedBytes = Original.RawBytes
                    Prepared.ImageRange.SectionOffset = Offset
                    Prepared.ImageRange.RelativeAddress = RelativeAddress
                    Prepared.ImageRange.Address = Address
                    Prepared.ImageRange.Characteristics = Candidate.Characteristics
                End If
                ' Avoid overflowing the last candidate increment near Long.MaxValue.
                If Alignment > Candidate.InitializedBytes - Original.RawBytes - Offset Then
                    Exit While
                End If
                Offset = Offset + Alignment
            Wend
        End If
        SectionIndex = SectionIndex + 1
    Wend
    Failure.Code = 1506
    If Prepared.Present <> 1 Then
        Exit Function
    End If
    If TryValidateNativeContributionIsolation(ImageBytes, ImageLayout, Prepared.ImageRange, Inspection, Cancellation, Failure) = False Then
        Exit Function
    End If
    Result = Prepared
    Failure.Code = 0
    Failure.Resource = 0
    TryBindNativeConstantContribution = True
End Function
