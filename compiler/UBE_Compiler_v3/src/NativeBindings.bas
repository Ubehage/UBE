UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeBindings"

' Scalar locations into the same immutable snapshot as the supplied inventory.
Type NativeDefinitionRange
    SymbolIndex As Long
    SectionIndex As Long
    FileFirst As Long
    ByteCount As Long
    InitializedBytes As Long
    TypeCode As Long
    SectionOffset As LongLong
    RelativeAddress As LongLong
    Address As LongLong
    Characteristics As LongLong
End Type
Type NativeRetainedDefinition
    Present As Long
    ObjectRange As NativeDefinitionRange
    ImageRange As NativeDefinitionRange
End Type
' Return the length of borrowed scalar expectations for binary association.
Intrinsic Function NativeExpectedIntegerLength(ByRef Values() As LongLong) As Long
Attribute NativeExpectedIntegerLength.UBE_Primitive = "Array.Length"
End Function

Function TryValidateNativeContributionIsolation(ByRef Bytes() As Byte, ByRef Layout As NativeObjectLayout, ByRef Range As NativeDefinitionRange, ByRef Inspection As NativeInspection, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryValidateNativeContributionIsolation = False
    Call ResetNativeFailure(Failure)
    If Range.InitializedBytes <> Range.ByteCount Then
        Exit Function
    End If
    TryValidateNativeContributionIsolation = TryValidateNativeStorageIsolation(Bytes, Layout, Range, Inspection, Cancellation, Failure)
End Function

' The logical virtual extent can include a suffix with no file storage.
Function TryValidateNativeStorageIsolation(ByRef Bytes() As Byte, ByRef Layout As NativeObjectLayout, ByRef Range As NativeDefinitionRange, ByRef Inspection As NativeInspection, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryValidateNativeStorageIsolation = False
    Call ResetNativeFailure(Failure)
    If Layout.Kind < 1 Or Layout.Kind > 2 Or Layout.Length <> ByteStorageLength(Bytes) Or Layout.SectionCount < 1 Or Layout.SectionCount > 96 Or Range.SectionIndex < 0 Or Range.SectionIndex >= Layout.SectionCount Then
        Exit Function
    End If
    If Range.ByteCount < 1 Or Range.InitializedBytes < 0 Or Range.InitializedBytes > Range.ByteCount Then
        Exit Function
    End If
    If Range.InitializedBytes = 0 Then
        If Range.FileFirst <> -1 Then
            Exit Function
        End If
    Else
        If Range.FileFirst < Layout.HeaderBytes Or Range.FileFirst < 0 Or Range.FileFirst > Layout.Length Then
            Exit Function
        End If
        If Range.InitializedBytes > Layout.Length - Range.FileFirst Then
            Exit Function
        End If
    End If
    If Layout.HeaderBytes < 0 Or Layout.HeaderBytes > Layout.Length Or Layout.SymbolTable < 0 Then
        Exit Function
    End If
    If Layout.SymbolTable > 0 Then
        If Layout.SymbolTable > Layout.Length Or Layout.StringTable < Layout.SymbolTable Or Layout.StringTable > Layout.Length Or Layout.StringBytes < 0 Then
            Exit Function
        End If
        If Layout.StringBytes > Layout.Length - Layout.StringTable Then
            Exit Function
        End If
    End If
    If Layout.Kind = 2 Then
        If Range.RelativeAddress < 0 Or Range.RelativeAddress > Layout.ImageBytes Then
            Exit Function
        End If
        If Range.ByteCount > Layout.ImageBytes - Range.RelativeAddress Then
            Exit Function
        End If
    End If
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Layout.SymbolTable > 0 And Range.InitializedBytes > 0 Then
        If Layout.SymbolTable < Range.FileFirst + Range.InitializedBytes And Range.FileFirst < Layout.StringTable + Layout.StringBytes Then
            Exit Function
        End If
    End If
    Dim Index As Long = 0
    While Index < Layout.SectionCount
        If Index <> Range.SectionIndex Or Layout.Kind = 1 Then
            Dim Other As NativeObjectSection
            If TryReadNativeObjectSection(Bytes, Inspection, Layout, Index, Other, Cancellation, Failure) = False Then
                Exit Function
            End If
            Failure.Code = 1506
            If Index <> Range.SectionIndex Then
                If Other.InitializedBytes > 0 And Range.InitializedBytes > 0 Then
                    If Other.RawFirst < Range.FileFirst + Range.InitializedBytes And Range.FileFirst < Other.RawFirst + Other.InitializedBytes Then
                        Exit Function
                    End If
                End If
                If Layout.Kind = 2 And Other.VirtualBytes > 0 Then
                    If Other.VirtualAddress < Range.RelativeAddress + Range.ByteCount And Range.RelativeAddress < Other.VirtualAddress + Other.VirtualBytes Then
                        Exit Function
                    End If
                End If
            End If
            If Layout.Kind = 1 And Other.RelocationCount > 0 And Range.InitializedBytes > 0 Then
                If Other.RelocationTable < Range.FileFirst + Range.InitializedBytes And Range.FileFirst < Other.RelocationTable + Other.RelocationCount * 10 Then
                    Exit Function
                End If
                ' The extended-count sentinel precedes the effective records.
                If (Other.Characteristics \ 16777216) Mod 2 <> 0 Then
                    If Other.RelocationTable - 10 < Range.FileFirst + Range.InitializedBytes And Range.FileFirst < Other.RelocationTable Then
                        Exit Function
                    End If
                End If
            End If
        End If
        Index = Index + 1
    Wend
    Failure.Code = 0
    Failure.Resource = 0
    TryValidateNativeStorageIsolation = True
End Function

Function NativeExpectedHasStorage(ByRef Expected As NativeExpectedDefinition) As Boolean
    NativeExpectedHasStorage = Expected.Family = 2 Or Expected.Family = 9 Or Expected.Family = 10 Or Expected.Family = 11 Or Expected.Family = 12 Or Expected.Family = 16 Or Expected.Family = 17 Or Expected.Family = 22
End Function

Function ValidNativeRetentionRange(ByRef Expected As NativeExpectedDefinition, ByRef Range As NativeDefinitionRange) As Boolean
    ValidNativeRetentionRange = False
    Dim Flags As LongLong = Range.Characteristics
    If (Flags \ 1073741824) Mod 2 <> 1 Then
        Exit Function
    End If
    Dim Executable As Boolean = (Flags \ 536870912) Mod 2 = 1
    Dim WriteFlag As LongLong = 1073741824
    WriteFlag = WriteFlag * 2
    Dim Writable As Boolean = (Flags \ WriteFlag) Mod 2 = 1
    Dim Code As Boolean = (Flags \ 32) Mod 2 = 1
    If Expected.StorageBytes = 0 Then
        If Range.TypeCode <> 32 Or Range.InitializedBytes <> 1 Or NativeReadableCodeCharacteristics(Flags) = False Then
            Exit Function
        End If
    Else
        If Range.TypeCode <> 0 Or Executable Or Code Or (Flags \ 33554432) Mod 2 <> 0 Then
            Exit Function
        End If
        If (Flags \ 64) Mod 2 = 0 And (Flags \ 128) Mod 2 = 0 Then
            Exit Function
        End If
        Dim Mutable As Boolean = Expected.Family = 2 Or Expected.Family = 9 Or Expected.Family = 10 Or Expected.Family = 12 Or Expected.Family = 22
        If Writable <> Mutable Then
            Exit Function
        End If
        If Mutable = False Then
            If (Flags \ 64) Mod 2 <> 1 Or Range.InitializedBytes <> Expected.StorageBytes Then
                Exit Function
            End If
        End If
    End If
    ValidNativeRetentionRange = True
End Function

Function TryBindNativeDefinition(ByRef Expected As NativeExpectedDefinition, ByRef Names() As Byte, ByRef ObjectInventory As NativeSymbolInventory, ByRef ObjectBytes() As Byte, ByRef ObjectLayout As NativeObjectLayout, ByRef ImageInventory As NativeSymbolInventory, ByRef ImageBytes() As Byte, ByRef ImageLayout As NativeObjectLayout, ByRef Inspection As NativeInspection, ByRef Result As NativeRetainedDefinition, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryBindNativeDefinition = False
    Call ResetNativeFailure(Failure)
    If Expected.Family < 1 Or Expected.Family > 23 Or Expected.UnitKind < 0 Or Expected.UnitKind > 6 Or Expected.RequireObject < 0 Or Expected.RequireObject > 1 Or Expected.StorageBytes < 0 Or ObjectLayout.Kind <> 1 Or ImageLayout.Kind <> 2 Or ObjectInventory.Status <> 1 Or ImageInventory.Status <> 1 Then
        Exit Function
    End If
    If Expected.Name.First < 0 Or Expected.Name.Count < 1 Or Expected.Name.First > ByteStorageLength(Names) Then
        Exit Function
    End If
    If Expected.Name.Count > ByteStorageLength(Names) - Expected.Name.First Then
        Exit Function
    End If
    If ObjectLayout.Length <> ByteStorageLength(ObjectBytes) Or ObjectInventory.Length <> ObjectLayout.Length Or ObjectInventory.SymbolCapacity <> ObjectLayout.SymbolCount Or ImageLayout.Length <> ByteStorageLength(ImageBytes) Or ImageInventory.Length <> ImageLayout.Length Or ImageInventory.SymbolCapacity <> ImageLayout.SymbolCount Then
        Exit Function
    End If
    Dim Data As Boolean = NativeExpectedHasStorage(Expected)
    If Data <> (Expected.StorageBytes > 0) Then
        Exit Function
    End If
    Dim Symbol As NativeObjectSymbol
    Dim Index As Long = -1
    Dim Found As Boolean = False
    If TrySelectNativeDefinition(ObjectInventory, ObjectBytes, Names, Expected.Name, Inspection, Symbol, Index, Found, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Prepared As NativeRetainedDefinition
    If Found = False Then
        Failure.Code = 1506
        If Expected.RequireObject <> 0 Then
            Exit Function
        End If
    Else
        Dim Count As Long = Expected.StorageBytes
        If Count = 0 Then
            Count = 1
        End If
        If TryLocateNativeDefinition(ObjectInventory, ObjectBytes, ObjectLayout, Names, Expected.Name, Count, Inspection, Prepared.ObjectRange, Cancellation, Failure) = False Then
            Exit Function
        End If
        Failure.Code = 1506
        If ValidNativeRetentionRange(Expected, Prepared.ObjectRange) = False Then
            Exit Function
        End If
        If TryLocateNativeDefinition(ImageInventory, ImageBytes, ImageLayout, Names, Expected.Name, Count, Inspection, Prepared.ImageRange, Cancellation, Failure) = False Then
            Exit Function
        End If
        Failure.Code = 1506
        If ValidNativeRetentionRange(Expected, Prepared.ImageRange) = False Then
            Exit Function
        End If
        Prepared.Present = 1
    End If
    Result = Prepared
    Failure.Code = 0
    Failure.Resource = 0
    TryBindNativeDefinition = True
End Function

Function TryLocateNativeDefinition(ByRef Inventory As NativeSymbolInventory, ByRef Bytes() As Byte, ByRef Layout As NativeObjectLayout, ByRef QueryBytes() As Byte, ByRef Name As NativeObjectName, ByVal ByteCount As Long, ByRef Inspection As NativeInspection, ByRef Result As NativeDefinitionRange, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryLocateNativeDefinition = False
    Call ResetNativeFailure(Failure)
    If ByteCount < 1 Or Layout.Length <> ByteStorageLength(Bytes) Or Inventory.Length <> Layout.Length Or Inventory.SymbolCapacity <> Layout.SymbolCount Then
        Exit Function
    End If
    If Layout.Kind <> 1 And Layout.Kind <> 2 Then
        Exit Function
    End If
    Dim Symbol As NativeObjectSymbol
    Dim SymbolIndex As Long = -1
    If TryFindNativeDefinition(Inventory, Bytes, QueryBytes, Name, Inspection, Symbol, SymbolIndex, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Section As NativeObjectSection
    Call ResetNativeFailure(Failure)
    If TryReadNativeObjectSection(Bytes, Inspection, Layout, Symbol.SectionNumber - 1, Section, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim LogicalBytes As LongLong = Section.RawBytes
    If Layout.Kind = 2 Then
        LogicalBytes = Section.VirtualBytes
    End If
    Failure.Code = 1506
    If Symbol.Value < 0 Or Symbol.Value > LogicalBytes Then
        Exit Function
    End If
    If ByteCount > LogicalBytes - Symbol.Value Then
        Exit Function
    End If
    Dim Prepared As NativeDefinitionRange
    Prepared.SymbolIndex = SymbolIndex
    Prepared.SectionIndex = Symbol.SectionNumber - 1
    Prepared.FileFirst = -1
    Prepared.ByteCount = ByteCount
    Prepared.TypeCode = Symbol.TypeCode
    Prepared.SectionOffset = Symbol.Value
    Prepared.Characteristics = Section.Characteristics
    If Symbol.Value < Section.InitializedBytes Then
        Dim Initialized As LongLong = Section.InitializedBytes - Symbol.Value
        If Initialized > ByteCount Then
            Initialized = ByteCount
        End If
        If Section.RawFirst < 0 Or Section.RawFirst > Layout.Length Then
            Exit Function
        End If
        If Symbol.Value > Layout.Length - Section.RawFirst Then
            Exit Function
        End If
        Prepared.FileFirst = Section.RawFirst + Symbol.Value
        If Initialized > Layout.Length - Prepared.FileFirst Then
            Exit Function
        End If
        Prepared.InitializedBytes = Initialized
    End If
    If Layout.Kind = 2 Then
        If Layout.ImageBase < 0 Or Section.VirtualAddress < 0 Or Section.VirtualAddress > Layout.ImageBytes Then
            Exit Function
        End If
        If Symbol.Value > Layout.ImageBytes - Section.VirtualAddress Then
            Exit Function
        End If
        Prepared.RelativeAddress = Section.VirtualAddress + Symbol.Value
        If ByteCount > Layout.ImageBytes - Prepared.RelativeAddress Then
            Exit Function
        End If
        Dim Maximum As LongLong = SemanticLongLongMaximum()
        If Prepared.RelativeAddress > Maximum - Layout.ImageBase Then
            Exit Function
        End If
        Prepared.Address = Layout.ImageBase + Prepared.RelativeAddress
        If ByteCount > Maximum - Prepared.Address Then
            Exit Function
        End If
    End If
    Result = Prepared
    Failure.Code = 0
    Failure.Resource = 0
    TryLocateNativeDefinition = True
End Function

Function TryValidateNativeIntegerData(ByRef Inventory As NativeSymbolInventory, ByRef Bytes() As Byte, ByRef Layout As NativeObjectLayout, ByRef QueryBytes() As Byte, ByRef Name As NativeObjectName, ByRef Expected() As LongLong, ByRef Inspection As NativeInspection, ByRef Result As NativeDefinitionRange, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryValidateNativeIntegerData = False
    Call ResetNativeFailure(Failure)
    Dim Count As Long = NativeExpectedIntegerLength(Expected)
    If Count < 1 Or Count > 268435455 Then
        Exit Function
    End If
    Dim Prepared As NativeDefinitionRange
    If TryLocateNativeDefinition(Inventory, Bytes, Layout, QueryBytes, Name, Count * 8, Inspection, Prepared, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Prepared.InitializedBytes <> Prepared.ByteCount Or Prepared.FileFirst < 0 Or Prepared.TypeCode <> 0 Then
        Exit Function
    End If
    If NativeReadOnlyDataCharacteristics(Prepared.Characteristics) = False Then
        Exit Function
    End If
    Dim Section As NativeObjectSection
    Call ResetNativeFailure(Failure)
    If TryReadNativeObjectSection(Bytes, Inspection, Layout, Prepared.SectionIndex, Section, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Index As Long = 0
    While Index < Section.RelocationCount
        Dim Relocation As NativeObjectRelocation
        Call ResetNativeFailure(Failure)
        If TryReadNativeObjectRelocation(Bytes, Inspection, Layout, Section, Index, Relocation, Cancellation, Failure) = False Then
            Exit Function
        End If
        If Relocation.Kind <> 0 Then
            Failure.Code = 1506
            If Relocation.Offset < Prepared.SectionOffset + Prepared.ByteCount And Prepared.SectionOffset < Relocation.Offset + Relocation.Width Then
                Exit Function
            End If
        End If
        Index = Index + 1
    Wend
    Index = 0
    While Index < Count
        Dim Value As LongLong = 0
        Call ResetNativeFailure(Failure)
        If TryReadNativeBits(Bytes, Inspection, Prepared.FileFirst + Index * 8, 8, Value, Cancellation, Failure) = False Then
            Exit Function
        End If
        Failure.Code = 1506
        If Value <> Expected(Index) Then
            Exit Function
        End If
        Index = Index + 1
    Wend
    Result = Prepared
    Failure.Code = 0
    Failure.Resource = 0
    TryValidateNativeIntegerData = True
End Function

Function NativeDefinitionAnchorMatches(ByRef Anchor As NativeDefinitionRange, ByRef Range As NativeDefinitionRange) As Boolean
    NativeDefinitionAnchorMatches = False
    Dim Initialized As Long = 0
    If Range.InitializedBytes > 0 Then
        Initialized = 1
    End If
    If Anchor.SymbolIndex <> Range.SymbolIndex Or Anchor.SectionIndex <> Range.SectionIndex Or Anchor.FileFirst <> Range.FileFirst Or Anchor.InitializedBytes <> Initialized Or Anchor.TypeCode <> Range.TypeCode Then
        Exit Function
    End If
    If Anchor.SectionOffset <> Range.SectionOffset Or Anchor.RelativeAddress <> Range.RelativeAddress Or Anchor.Address <> Range.Address Or Anchor.Characteristics <> Range.Characteristics Then
        Exit Function
    End If
    NativeDefinitionAnchorMatches = True
End Function

' Match a qualified named target to its frozen generated owner and access extent.
Function TryValidateNativeGeneratedTarget(ByRef Instruction As NativeInstruction, ByRef Relocation As NativeObjectRelocation, ByRef Target As NativeDefinitionRange, ByVal Position As LongLong, ByRef Expected As NativeExpectedDefinition, ByRef Retained As NativeRetainedDefinition, ByRef Inspection As NativeInspection, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryValidateNativeGeneratedTarget = False
    Call ResetNativeFailure(Failure)
    If Expected.Family < 1 Or Expected.Family > 23 Or Expected.UnitKind < 0 Or Expected.UnitKind > 6 Or Expected.RequireObject < 0 Or Expected.RequireObject > 1 Or Expected.StorageBytes < 0 Or Expected.Name.First < 0 Or Expected.Name.Count < 1 Then
        Exit Function
    End If
    Dim Data As Boolean = NativeExpectedHasStorage(Expected)
    If Data <> (Expected.StorageBytes > 0) Or Retained.Present <> 1 Then
        Exit Function
    End If
    If ValidNativeRelocationTarget(Target) = False Or ValidNativeRelocationTarget(Retained.ImageRange) = False Then
        Exit Function
    End If
    Dim Count As Long = Expected.StorageBytes
    If Count = 0 Then
        Count = 1
    End If
    If Retained.ImageRange.ByteCount <> Count Or Retained.ImageRange.SymbolIndex < 0 Or Target.SymbolIndex < 0 Or Target.ByteCount <> 1 Then
        Exit Function
    End If
    Dim Maximum As LongLong = 65536
    Maximum = Maximum * 65536 - 1
    If Position < 0 Or Position > Maximum Or Retained.ImageRange.Characteristics < 0 Or Retained.ImageRange.Characteristics > Maximum Then
        Exit Function
    End If
    If Retained.ImageRange.InitializedBytes = 0 Then
        If Retained.ImageRange.FileFirst <> -1 Then
            Exit Function
        End If
    Else
        If Retained.ImageRange.FileFirst < 0 Or Retained.ImageRange.InitializedBytes > 2147483647 - Retained.ImageRange.FileFirst Then
            Exit Function
        End If
    End If
    If Instruction.ByteCount < 1 Or Instruction.ByteCount > 15 Or Instruction.Flow < 0 Or Instruction.Flow > 7 Or Instruction.MemoryWrite < 0 Or Instruction.MemoryWrite > 1 Then
        Exit Function
    End If
    If Instruction.MemoryBytes <> 0 And Instruction.MemoryBytes <> 1 And Instruction.MemoryBytes <> 2 And Instruction.MemoryBytes <> 4 And Instruction.MemoryBytes <> 8 Then
        Exit Function
    End If
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If ValidNativeRetentionRange(Expected, Retained.ImageRange) = False Then
        Exit Function
    End If
    If NativeDefinitionAnchorMatches(Target, Retained.ImageRange) = False Then
        Exit Function
    End If
    Dim Relative As Boolean = Relocation.Kind >= 4 And Relocation.Kind <= 9
    If Relocation.Width <> 4 Then
        Exit Function
    End If
    If Relative Then
        If Relocation.RelativeEnd <> Relocation.Kind Then
            Exit Function
        End If
    Else
        If Relocation.Kind <> 11 Or Relocation.RelativeEnd <> 0 Then
            Exit Function
        End If
    End If
    If Data = False Then
        If Relative = False Or Instruction.Flow < 2 Or Instruction.Flow > 4 Or Instruction.MemoryBytes <> 0 Or Instruction.MemoryWrite <> 0 Or Instruction.MemoryBase <> -1 Or Instruction.MemoryIndex <> -1 Or Instruction.Segment <> 0 Then
            Exit Function
        End If
        If Position <> Retained.ImageRange.RelativeAddress Then
            Exit Function
        End If
    Else
        If Instruction.Flow <> 0 And Instruction.Flow <> 5 And Instruction.Flow <> 6 Then
            Exit Function
        End If
        If Instruction.MemoryIndex <> -1 Or Instruction.Segment <> 0 Then
            Exit Function
        End If
        Dim ThreadStorage As Boolean = Expected.Family = 12 Or Expected.Family = 22
        Dim First As LongLong = Retained.ImageRange.RelativeAddress
        If ThreadStorage Then
            If Relocation.Kind <> 11 Or Instruction.MemoryBase < 0 Or Instruction.MemoryBase > 15 Then
                Exit Function
            End If
            First = Retained.ImageRange.SectionOffset
        Else
            If Relative = False Or Instruction.MemoryBase <> -2 Then
                Exit Function
            End If
        End If
        Dim Width As Long = Instruction.MemoryBytes
        If Width = 0 Then
            If Instruction.Flow <> 0 Or Instruction.MemoryWrite <> 0 Then
                Exit Function
            End If
            Width = 1
        End If
        If Instruction.Flow = 5 Or Instruction.Flow = 6 Then
            If Width <> 8 Or Instruction.MemoryWrite <> 0 Then
                Exit Function
            End If
        End If
        If Instruction.MemoryWrite <> 0 Then
            Dim WriteFlag As LongLong = 1073741824
            WriteFlag = WriteFlag * 2
            If (Retained.ImageRange.Characteristics \ WriteFlag) Mod 2 <> 1 Then
                Exit Function
            End If
        End If
        If Position < First Then
            Exit Function
        End If
        Dim Offset As LongLong = Position - First
        If Offset > Count Then
            Exit Function
        End If
        If Width > Count - Offset Then
            Exit Function
        End If
    End If
    Failure.Code = 0
    Failure.Resource = 0
    TryValidateNativeGeneratedTarget = True
End Function

Function TryBindNativeReferencePointer(ByRef Instruction As NativeInstruction, ByRef Target As NativeDefinitionRange, ByVal Position As LongLong, ByRef Expected As NativeExpectedDefinition, ByRef Retained As NativeRetainedDefinition, ByRef Names() As Byte, ByRef Inventory As NativeSymbolInventory, ByRef Bytes() As Byte, ByRef Layout As NativeObjectLayout, ByRef Inspection As NativeInspection, ByRef Result As NativeDefinitionRange, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryBindNativeReferencePointer = False
    Call ResetNativeFailure(Failure)
    If Expected.Family < 1 Or Expected.Family > 23 Or Expected.UnitKind < 0 Or Expected.UnitKind > 6 Or Expected.RequireObject < 0 Or Expected.RequireObject > 1 Or Expected.StorageBytes < 1 Or Retained.Present <> 1 Then
        Exit Function
    End If
    If NativeExpectedHasStorage(Expected) = False Or ValidNativeRelocationTarget(Retained.ImageRange) = False Or ValidNativeRelocationTarget(Target) = False Then
        Exit Function
    End If
    If Retained.ImageRange.ByteCount <> Expected.StorageBytes Or Retained.ImageRange.SymbolIndex < 0 Or Target.SymbolIndex < 0 Or Target.ByteCount <> 1 Then
        Exit Function
    End If
    If Expected.Name.First < 0 Or Expected.Name.Count < 1 Or Expected.Name.Count > 2147483639 Or Expected.Name.First > ByteStorageLength(Names) Then
        Exit Function
    End If
    If Expected.Name.Count > ByteStorageLength(Names) - Expected.Name.First Then
        Exit Function
    End If
    If Layout.Kind <> 2 Or Layout.Length <> ByteStorageLength(Bytes) Or Inventory.Status <> 1 Or Inventory.Length <> Layout.Length Or Inventory.SymbolCapacity <> Layout.SymbolCount Then
        Exit Function
    End If
    If Instruction.ByteCount < 1 Or Instruction.ByteCount > 15 Or Position < 0 Then
        Exit Function
    End If
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Expected.Family = 12 Or Expected.Family = 22 Or ValidNativeRetentionRange(Expected, Retained.ImageRange) = False Then
        Exit Function
    End If
    If Instruction.Flow <> 0 Or Instruction.MemoryBytes <> 8 Or Instruction.MemoryWrite <> 0 Or Instruction.MemoryBase <> -2 Or Instruction.MemoryIndex <> -1 Or Instruction.Segment <> 0 Or Position <> Target.RelativeAddress Then
        Exit Function
    End If
    Dim Symbol As NativeObjectSymbol
    If TryReadNativeIndexedSymbol(Inventory, Target.SymbolIndex, Inspection, Symbol, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Symbol.Name.Count <> Expected.Name.Count + 8 Then
        Exit Function
    End If
    Dim Prefix As LongLong = 779252848
    Prefix = Prefix * 65536 * 65536 + 1717924398
    Dim Value As LongLong = 0
    If TryReadNativeBits(Bytes, Inspection, Symbol.Name.First, 8, Value, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Value <> Prefix Then
        Exit Function
    End If
    Dim Equal As Boolean = False
    If TryCompareNativeByteSpan(Bytes, Symbol.Name.First + 8, Names, Expected.Name.First, Expected.Name.Count, Inspection, Equal, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Equal = False Then
        Exit Function
    End If
    Dim Prepared As NativeDefinitionRange
    If TryLocateNativeDefinition(Inventory, Bytes, Layout, Bytes, Symbol.Name, 8, Inspection, Prepared, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If NativeDefinitionAnchorMatches(Target, Prepared) = False Or Prepared.InitializedBytes <> 8 Or Prepared.TypeCode <> 0 Or NativeReadOnlyDataCharacteristics(Prepared.Characteristics) = False Then
        Exit Function
    End If
    If (Prepared.Characteristics \ 32) Mod 2 <> 0 Or (Prepared.Characteristics \ 33554432) Mod 2 <> 0 Then
        Exit Function
    End If
    If TryValidateNativeContributionIsolation(Bytes, Layout, Prepared, Inspection, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, Prepared.FileFirst, 8, Value, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Value <> Retained.ImageRange.Address Then
        Exit Function
    End If
    Result = Prepared
    Failure.Code = 0
    Failure.Resource = 0
    TryBindNativeReferencePointer = True
End Function
