UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeImports"

Private Function TryReadNativeImportName(ByRef Bytes() As Byte, ByRef Layout As NativeObjectLayout, ByVal Address As LongLong, ByRef Inspection As NativeInspection, ByRef Result As NativeObjectName, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryReadNativeImportName = False
    Dim Section As NativeObjectSection
    Dim SectionIndex As Long = -1
    If TryLocateNativeImageSpan(Bytes, Layout, Address, 1, Inspection, Section, SectionIndex, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If NativeInitializedImageDataCharacteristics(Section.Characteristics) = False Then
        Exit Function
    End If
    Dim Offset As LongLong = Address - Section.VirtualAddress
    Dim Limit As Long = Section.InitializedBytes - Offset
    Dim Prepared As NativeObjectName
    Prepared.First = Section.RawFirst + Offset
    Dim Found As Boolean = False
    While Prepared.Count < Limit And Found = False
        Dim Value As LongLong = 0
        If TryReadNativeBits(Bytes, Inspection, Prepared.First + Prepared.Count, 1, Value, Cancellation, Failure) = False Then
            Exit Function
        End If
        Failure.Code = 1506
        If Value = 0 Then
            Found = True
        Else
            If Value > 127 Then
                Exit Function
            End If
            Prepared.Count = Prepared.Count + 1
        End If
    Wend
    Failure.Code = 1506
    If Found = False Or Prepared.Count = 0 Then
        Exit Function
    End If
    Dim Range As NativeDefinitionRange
    If TryLocateNativeImageRange(Bytes, Layout, Address, Prepared.Count + 1, Inspection, Range, Cancellation, Failure) = False Then
        Exit Function
    End If
    Result = Prepared
    Failure.Code = 0
    TryReadNativeImportName = True
End Function

Private Function TryCompareNativeImportName(ByRef Bytes() As Byte, ByRef Actual As NativeObjectName, ByRef Names() As Byte, ByRef Expected As NativeObjectName, ByVal Fold As Boolean, ByRef Inspection As NativeInspection, ByRef Equal As Boolean, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryCompareNativeImportName = False
    Dim Prepared As Boolean = Actual.Count = Expected.Count
    If Prepared Then
        If Fold = False Then
            If TryCompareNativeByteSpan(Bytes, Actual.First, Names, Expected.First, Actual.Count, Inspection, Prepared, Cancellation, Failure) = False Then
                Exit Function
            End If
        Else
            Dim Index As Long = 0
            While Index < Actual.Count And Prepared
                Dim LeftValue As LongLong = 0
                Dim RightValue As LongLong = 0
                If TryReadNativeBits(Bytes, Inspection, Actual.First + Index, 1, LeftValue, Cancellation, Failure) = False Then
                    Exit Function
                End If
                If TryReadNativeBits(Names, Inspection, Expected.First + Index, 1, RightValue, Cancellation, Failure) = False Then
                    Exit Function
                End If
                Prepared = SimpleFoldUnicode(LeftValue) = SimpleFoldUnicode(RightValue)
                Index = Index + 1
            Wend
        End If
    End If
    Equal = Prepared
    Failure.Code = 0
    TryCompareNativeImportName = True
End Function

Function TryBindNativeImportTarget(ByRef Instruction As NativeInstruction, ByRef Target As NativeDefinitionRange, ByVal Position As LongLong, ByRef Names() As Byte, ByRef LibraryName As NativeObjectName, ByRef ProcedureName As NativeObjectName, ByRef Bytes() As Byte, ByRef Layout As NativeObjectLayout, ByRef Inspection As NativeInspection, ByRef Result As NativeDefinitionRange, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryBindNativeImportTarget = False
    Call ResetNativeFailure(Failure)
    If Layout.Kind <> 2 Or Layout.Length <> ByteStorageLength(Bytes) Or ValidNativeRelocationTarget(Target) = False Or Target.SymbolIndex < 0 Or Target.ByteCount <> 1 Then
        Exit Function
    End If
    Dim NameBytes As Long = ByteStorageLength(Names)
    If LibraryName.First < 0 Or LibraryName.Count < 1 Or LibraryName.First > NameBytes Or ProcedureName.First < 0 Or ProcedureName.Count < 1 Or ProcedureName.First > NameBytes Then
        Exit Function
    End If
    If LibraryName.Count > NameBytes - LibraryName.First Or ProcedureName.Count > NameBytes - ProcedureName.First Then
        Exit Function
    End If
    If Instruction.ByteCount < 1 Or Instruction.ByteCount > 15 Or Position < 0 Then
        Exit Function
    End If
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Position <> Target.RelativeAddress Or Position Mod 8 <> 0 Or Instruction.MemoryBytes <> 8 Or Instruction.MemoryWrite <> 0 Or Instruction.MemoryBase <> -2 Or Instruction.MemoryIndex <> -1 Or Instruction.Segment <> 0 Then
        Exit Function
    End If
    If Instruction.Flow <> 0 And Instruction.Flow <> 5 And Instruction.Flow <> 6 Then
        Exit Function
    End If
    Dim Address As LongLong = 0
    Dim Size As LongLong = 0
    If TryReadNativeImageDirectory(Bytes, Layout, 11, Inspection, Address, Size, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Address <> 0 Or Size <> 0 Then
        Exit Function
    End If
    If TryReadNativeImageDirectory(Bytes, Layout, 13, Inspection, Address, Size, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Address <> 0 Or Size <> 0 Then
        Exit Function
    End If
    If TryReadNativeImageDirectory(Bytes, Layout, 12, Inspection, Address, Size, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Address = 0 Or Address Mod 8 <> 0 Or Size < 8 Or Size > 2147483647 Or Size Mod 8 <> 0 Then
        Exit Function
    End If
    Dim IAT As NativeDefinitionRange
    If TryLocateNativeImageRange(Bytes, Layout, Address, Size, Inspection, IAT, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If NativeInitializedImageDataCharacteristics(IAT.Characteristics) = False Or Position < Address Or Position - Address > Size - 8 Then
        Exit Function
    End If
    If TryValidateNativeContributionIsolation(Bytes, Layout, IAT, Inspection, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Prepared As NativeDefinitionRange
    If TryLocateNativeImageRange(Bytes, Layout, Position, 8, Inspection, Prepared, Cancellation, Failure) = False Then
        Exit Function
    End If
    Prepared.SymbolIndex = Target.SymbolIndex
    Failure.Code = 1506
    If NativeDefinitionAnchorMatches(Target, Prepared) = False Then
        Exit Function
    End If
    If TryReadNativeImageDirectory(Bytes, Layout, 1, Inspection, Address, Size, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Address = 0 Or Size < 20 Or Size > 2147483647 Or Size Mod 20 <> 0 Then
        Exit Function
    End If
    Dim Directory As NativeDefinitionRange
    If TryLocateNativeImageRange(Bytes, Layout, Address, Size, Inspection, Directory, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If NativeInitializedImageDataCharacteristics(Directory.Characteristics) = False Or NativeImageRangeOverlaps(Address, Size, IAT) Then
        Exit Function
    End If
    Dim Cursor As Long = 0
    Dim Ended As Boolean = False
    Dim Found As Boolean = False
    While Cursor < Directory.ByteCount
        Dim Lookup As LongLong = 0
        Dim Stamp As LongLong = 0
        Dim Forwarders As LongLong = 0
        Dim DLL As LongLong = 0
        Dim Thunk As LongLong = 0
        Dim First As Long = Directory.FileFirst + Cursor
        If TryReadNativeBits(Bytes, Inspection, First, 4, Lookup, Cancellation, Failure) = False Then
            Exit Function
        End If
        If TryReadNativeBits(Bytes, Inspection, First + 4, 4, Stamp, Cancellation, Failure) = False Then
            Exit Function
        End If
        If TryReadNativeBits(Bytes, Inspection, First + 8, 4, Forwarders, Cancellation, Failure) = False Then
            Exit Function
        End If
        If TryReadNativeBits(Bytes, Inspection, First + 12, 4, DLL, Cancellation, Failure) = False Then
            Exit Function
        End If
        If TryReadNativeBits(Bytes, Inspection, First + 16, 4, Thunk, Cancellation, Failure) = False Then
            Exit Function
        End If
        Failure.Code = 1506
        If Lookup = 0 And Stamp = 0 And Forwarders = 0 And DLL = 0 And Thunk = 0 Then
            Ended = True
        Else
            If Ended Or Lookup = 0 Or Lookup Mod 8 <> 0 Or Stamp <> 0 Or Forwarders <> 0 Or DLL = 0 Or Thunk Mod 8 <> 0 Or Thunk < IAT.RelativeAddress Then
                Exit Function
            End If
            If Thunk - IAT.RelativeAddress > IAT.ByteCount - 8 Then
                Exit Function
            End If
            Dim ActualLibrary As NativeObjectName
            If TryReadNativeImportName(Bytes, Layout, DLL, Inspection, ActualLibrary, Cancellation, Failure) = False Then
                Exit Function
            End If
            Failure.Code = 1506
            If NativeImageRangeOverlaps(DLL, ActualLibrary.Count + 1, IAT) Then
                Exit Function
            End If
            Dim LibraryMatches As Boolean = False
            If TryCompareNativeImportName(Bytes, ActualLibrary, Names, LibraryName, True, Inspection, LibraryMatches, Cancellation, Failure) = False Then
                Exit Function
            End If
            Dim Section As NativeObjectSection
            Dim SectionIndex As Long = -1
            If TryLocateNativeImageSpan(Bytes, Layout, Lookup, 8, Inspection, Section, SectionIndex, Cancellation, Failure) = False Then
                Exit Function
            End If
            Failure.Code = 1506
            If NativeInitializedImageDataCharacteristics(Section.Characteristics) = False Then
                Exit Function
            End If
            Dim LookupOffset As LongLong = Lookup - Section.VirtualAddress
            Dim Entries As Long = (Section.InitializedBytes - LookupOffset) \ 8
            Dim IATEntries As Long = (IAT.ByteCount - (Thunk - IAT.RelativeAddress)) \ 8
            If Entries > IATEntries Then
                Entries = IATEntries
            End If
            Dim Index As Long = 0
            Dim Terminated As Boolean = False
            While Index < Entries And Terminated = False
                Dim Value As LongLong = 0
                Dim Linked As LongLong = 0
                If TryReadNativeBits(Bytes, Inspection, Section.RawFirst + LookupOffset + Index * 8, 8, Value, Cancellation, Failure) = False Then
                    Exit Function
                End If
                If TryReadNativeBits(Bytes, Inspection, IAT.FileFirst + Thunk - IAT.RelativeAddress + Index * 8, 8, Linked, Cancellation, Failure) = False Then
                    Exit Function
                End If
                Failure.Code = 1506
                If Linked <> Value Or Value < 0 Or Value > 2147483647 Then
                    Exit Function
                End If
                If Value = 0 Then
                    Terminated = True
                Else
                    If Value Mod 2 <> 0 Then
                        Exit Function
                    End If
                    Dim Hint As NativeDefinitionRange
                    If TryLocateNativeImageRange(Bytes, Layout, Value, 2, Inspection, Hint, Cancellation, Failure) = False Then
                        Exit Function
                    End If
                    Dim ActualProcedure As NativeObjectName
                    If TryReadNativeImportName(Bytes, Layout, Value + 2, Inspection, ActualProcedure, Cancellation, Failure) = False Then
                        Exit Function
                    End If
                    Failure.Code = 1506
                    Dim HintBytes As LongLong = ActualProcedure.Count
                    HintBytes = HintBytes + 3
                    If NativeImageRangeOverlaps(Value, HintBytes, IAT) Then
                        Exit Function
                    End If
                    If Thunk + Index * 8 = Position Then
                        If Found Or LibraryMatches = False Then
                            Exit Function
                        End If
                        Dim ProcedureMatches As Boolean = False
                        If TryCompareNativeImportName(Bytes, ActualProcedure, Names, ProcedureName, False, Inspection, ProcedureMatches, Cancellation, Failure) = False Then
                            Exit Function
                        End If
                        Failure.Code = 1506
                        If ProcedureMatches = False Then
                            Exit Function
                        End If
                        Found = True
                    End If
                End If
                Index = Index + 1
            Wend
            Failure.Code = 1506
            If Terminated = False Or NativeImageRangeOverlaps(Lookup, Index * 8, IAT) Then
                Exit Function
            End If
            Dim CompleteLookup As NativeDefinitionRange
            If TryLocateNativeImageRange(Bytes, Layout, Lookup, Index * 8, Inspection, CompleteLookup, Cancellation, Failure) = False Then
                Exit Function
            End If
        End If
        Cursor = Cursor + 20
    Wend
    Failure.Code = 1506
    If Found = False Or Ended = False Then
        Exit Function
    End If
    Result = Prepared
    Failure.Code = 0
    Failure.Resource = 0
    TryBindNativeImportTarget = True
End Function
