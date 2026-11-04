UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeObjects"

Function NativeImageRangeOverlaps(ByVal Address As LongLong, ByVal Count As LongLong, ByRef Range As NativeDefinitionRange) As Boolean
    NativeImageRangeOverlaps = Address < Range.RelativeAddress + Range.ByteCount And Range.RelativeAddress < Address + Count
End Function

Function NativeReadableCodeCharacteristics(ByVal Flags As LongLong) As Boolean
    Dim WriteFlag As LongLong = 1073741824
    WriteFlag = WriteFlag * 2
    NativeReadableCodeCharacteristics = (Flags \ 32) Mod 2 = 1 And (Flags \ 536870912) Mod 2 = 1 And (Flags \ 1073741824) Mod 2 = 1 And (Flags \ WriteFlag) Mod 2 = 0
End Function

' Read the shared bounded PE header location and data-directory count.
Function TryReadNativeImageHeader(ByRef Bytes() As Byte, ByRef Layout As NativeObjectLayout, ByRef Inspection As NativeInspection, ByRef Header As LongLong, ByRef Count As LongLong, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryReadNativeImageHeader = False
    Call ResetNativeFailure(Failure)
    If Layout.Kind <> 2 Or Layout.Length <> ByteStorageLength(Bytes) Then
        Exit Function
    End If
    Dim PE As LongLong = 0
    If TryReadNativeBits(Bytes, Inspection, 60, 4, PE, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If PE < 64 Or PE > Layout.SectionTable - 136 Then
        Exit Function
    End If
    Dim Directories As LongLong = 0
    If TryReadNativeBits(Bytes, Inspection, PE + 132, 4, Directories, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Directories > (Layout.SectionTable - PE - 136) \ 8 Then
        Exit Function
    End If
    Header = PE
    Count = Directories
    Failure.Code = 0
    TryReadNativeImageHeader = True
End Function

' Locate an optional image directory without changing the shared read costs.
Function TryReadNativeImageDirectory(ByRef Bytes() As Byte, ByRef Layout As NativeObjectLayout, ByVal Index As Long, ByRef Inspection As NativeInspection, ByRef Address As LongLong, ByRef Size As LongLong, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryReadNativeImageDirectory = False
    Call ResetNativeFailure(Failure)
    If Layout.Kind <> 2 Or Layout.Length <> ByteStorageLength(Bytes) Or Index < 0 Or Index > 15 Then
        Exit Function
    End If
    Dim PE As LongLong = 0
    Dim Directories As LongLong = 0
    If TryReadNativeImageHeader(Bytes, Layout, Inspection, PE, Directories, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim PreparedAddress As LongLong = 0
    Dim PreparedSize As LongLong = 0
    If Index < Directories Then
        If TryReadNativeBits(Bytes, Inspection, PE + 136 + Index * 8, 4, PreparedAddress, Cancellation, Failure) = False Then
            Exit Function
        End If
        If TryReadNativeBits(Bytes, Inspection, PE + 140 + Index * 8, 4, PreparedSize, Cancellation, Failure) = False Then
            Exit Function
        End If
    End If
    Address = PreparedAddress
    Size = PreparedSize
    Failure.Code = 0
    TryReadNativeImageDirectory = True
End Function

Function TryLocateNativeImageRange(ByRef Bytes() As Byte, ByRef Layout As NativeObjectLayout, ByVal Address As LongLong, ByVal Count As Long, ByRef Inspection As NativeInspection, ByRef Result As NativeDefinitionRange, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryLocateNativeImageRange = False
    Call ResetNativeFailure(Failure)
    If Count < 1 Then
        Exit Function
    End If
    Dim Section As NativeObjectSection
    Dim SectionIndex As Long = -1
    If TryLocateNativeImageSpan(Bytes, Layout, Address, Count, Inspection, Section, SectionIndex, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    Dim Maximum As LongLong = SemanticLongLongMaximum()
    If Layout.ImageBase < 0 Or Address > Maximum - Layout.ImageBase Then
        Exit Function
    End If
    If Count > Maximum - Layout.ImageBase - Address Then
        Exit Function
    End If
    Dim Prepared As NativeDefinitionRange
    Prepared.SymbolIndex = -1
    Prepared.SectionIndex = SectionIndex
    Prepared.SectionOffset = Address - Section.VirtualAddress
    Prepared.FileFirst = Section.RawFirst + Prepared.SectionOffset
    Prepared.ByteCount = Count
    Prepared.InitializedBytes = Count
    Prepared.RelativeAddress = Address
    Prepared.Address = Layout.ImageBase + Address
    Prepared.Characteristics = Section.Characteristics
    Result = Prepared
    Failure.Code = 0
    TryLocateNativeImageRange = True
End Function

Function NativeInitializedImageDataCharacteristics(ByVal Flags As LongLong) As Boolean
    NativeInitializedImageDataCharacteristics = False
    Dim WriteFlag As LongLong = 1073741824
    WriteFlag = WriteFlag * 2
    If Flags < 0 Or Flags > WriteFlag * 2 - 1 Then
        Exit Function
    End If
    If (Flags \ 32) Mod 2 <> 0 Or (Flags \ 33554432) Mod 2 <> 0 Then
        Exit Function
    End If
    If Flags >= WriteFlag Then
        Flags = Flags - WriteFlag
    End If
    NativeInitializedImageDataCharacteristics = NativeReadOnlyDataCharacteristics(Flags)
End Function

Function NativeReadOnlyDataCharacteristics(ByVal Flags As LongLong) As Boolean
    Dim WriteFlag As LongLong = 1073741824
    WriteFlag = WriteFlag * 2
    NativeReadOnlyDataCharacteristics = (Flags \ 64) Mod 2 = 1 And (Flags \ 536870912) Mod 2 = 0 And (Flags \ 1073741824) Mod 2 = 1 And (Flags \ WriteFlag) Mod 2 = 0
End Function

' Reserved scalar descriptors over one caller-owned immutable byte snapshot.
' Kind 1 is ordinary AMD64 COFF, kind 2 is the selected PE32+ console image.
Type NativeObjectLayout
    Kind As Long
    Length As Long
    SectionTable As Long
    SectionCount As Long
    SymbolTable As Long
    SymbolCount As Long
    StringTable As Long
    StringBytes As Long
    HeaderBytes As Long
    FileAlignment As Long
    SectionAlignment As LongLong
    ImageBase As LongLong
    ImageBytes As LongLong
End Type

Type NativeObjectSection
    NameBits As LongLong
    VirtualBytes As LongLong
    VirtualAddress As LongLong
    RawFirst As Long
    RawBytes As Long
    InitializedBytes As Long
    RelocationTable As Long
    RelocationCount As Long
    Characteristics As LongLong
End Type

Function TryReadNativeObjectLayout(ByRef Bytes() As Byte, ByRef Inspection As NativeInspection, ByRef Result As NativeObjectLayout, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryReadNativeObjectLayout = False
    Call ResetNativeFailure(Failure)
    Dim Prepared As NativeObjectLayout
    Prepared.Length = ByteStorageLength(Bytes)
    Dim Magic As LongLong = 0
    If TryReadNativeBits(Bytes, Inspection, 0, 2, Magic, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    Dim Coff As Long = 0
    Prepared.Kind = 1
    If Magic = 23117 Then
        Prepared.Kind = 2
        Dim PEOffset As LongLong = 0
        If TryReadNativeBits(Bytes, Inspection, 60, 4, PEOffset, Cancellation, Failure) = False Then
            Exit Function
        End If
        Failure.Code = 1506
        If PEOffset < 64 Or PEOffset > Prepared.Length - 24 Then
            Exit Function
        End If
        Dim Signature As LongLong = 0
        If TryReadNativeBits(Bytes, Inspection, PEOffset, 4, Signature, Cancellation, Failure) = False Then
            Exit Function
        End If
        Failure.Code = 1506
        If Signature <> 17744 Then
            Exit Function
        End If
        Coff = PEOffset + 4
        If TryReadNativeBits(Bytes, Inspection, Coff, 2, Magic, Cancellation, Failure) = False Then
            Exit Function
        End If
    End If
    Failure.Code = 1506
    If Magic <> 34404 Or Coff > Prepared.Length - 20 Then
        Exit Function
    End If
    Dim Sections As LongLong = 0
    Dim Symbols As LongLong = 0
    Dim SymbolCount As LongLong = 0
    Dim OptionalBytes As LongLong = 0
    Dim Characteristics As LongLong = 0
    If TryReadNativeBits(Bytes, Inspection, Coff + 2, 2, Sections, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, Coff + 8, 4, Symbols, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, Coff + 12, 4, SymbolCount, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, Coff + 16, 2, OptionalBytes, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, Coff + 18, 2, Characteristics, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Sections < 1 Or OptionalBytes > Prepared.Length - Coff - 20 Then
        Exit Function
    End If
    Dim Table As Long = Coff + 20 + OptionalBytes
    Dim TableBytes As LongLong = Sections * 40
    If TableBytes > Prepared.Length - Table Then
        Exit Function
    End If
    Prepared.SectionTable = Table
    Prepared.SectionCount = Sections
    Prepared.HeaderBytes = Table + TableBytes
    If Prepared.Kind = 1 Then
        If OptionalBytes <> 0 Then
            Exit Function
        End If
    Else
        If OptionalBytes < 112 Or Sections > 96 Or ((Characteristics \ 2) Mod 2) = 0 Or ((Characteristics \ 8192) Mod 2) <> 0 Then
            Exit Function
        End If
        Dim OptionalStart As Long = Coff + 20
        If TryReadNativeBits(Bytes, Inspection, OptionalStart, 2, Magic, Cancellation, Failure) = False Then
            Exit Function
        End If
        Failure.Code = 1506
        If Magic <> 523 Then
            Exit Function
        End If
        Dim ImageBase As LongLong = 0
        Dim SectionAlignment As LongLong = 0
        Dim FileAlignment As LongLong = 0
        Dim ImageBytes As LongLong = 0
        Dim HeaderBytes As LongLong = 0
        Dim Subsystem As LongLong = 0
        Dim Directories As LongLong = 0
        If TryReadNativeBits(Bytes, Inspection, OptionalStart + 24, 8, ImageBase, Cancellation, Failure) = False Then
            Exit Function
        End If
        If TryReadNativeBits(Bytes, Inspection, OptionalStart + 32, 4, SectionAlignment, Cancellation, Failure) = False Then
            Exit Function
        End If
        If TryReadNativeBits(Bytes, Inspection, OptionalStart + 36, 4, FileAlignment, Cancellation, Failure) = False Then
            Exit Function
        End If
        If TryReadNativeBits(Bytes, Inspection, OptionalStart + 56, 4, ImageBytes, Cancellation, Failure) = False Then
            Exit Function
        End If
        If TryReadNativeBits(Bytes, Inspection, OptionalStart + 60, 4, HeaderBytes, Cancellation, Failure) = False Then
            Exit Function
        End If
        If TryReadNativeBits(Bytes, Inspection, OptionalStart + 68, 2, Subsystem, Cancellation, Failure) = False Then
            Exit Function
        End If
        If TryReadNativeBits(Bytes, Inspection, OptionalStart + 108, 4, Directories, Cancellation, Failure) = False Then
            Exit Function
        End If
        Failure.Code = 1506
        If ImageBase < 0 Or ImageBase Mod 65536 <> 0 Or Subsystem <> 3 Or Directories > (OptionalBytes - 112) \ 8 Then
            Exit Function
        End If
        If FileAlignment < 1 Or FileAlignment > 65536 Or SectionAlignment < FileAlignment Then
            Exit Function
        End If
        Dim Alignment As LongLong = 1
        Dim FileAligned As Boolean = False
        While Alignment < SectionAlignment
            If Alignment = FileAlignment Then
                FileAligned = True
            End If
            Alignment = Alignment * 2
        Wend
        If Alignment = FileAlignment Then
            FileAligned = True
        End If
        If Alignment <> SectionAlignment Or FileAligned = False Then
            Exit Function
        End If
        If SectionAlignment < 4096 Then
            If FileAlignment <> SectionAlignment Then
                Exit Function
            End If
        Else
            If FileAlignment < 512 Then
                Exit Function
            End If
        End If
        If HeaderBytes < Prepared.HeaderBytes Or HeaderBytes > Prepared.Length Or HeaderBytes Mod FileAlignment <> 0 Then
            Exit Function
        End If
        If ImageBytes < HeaderBytes Or ImageBytes Mod SectionAlignment <> 0 Or ImageBase > SemanticLongLongMaximum() - ImageBytes Then
            Exit Function
        End If
        Prepared.HeaderBytes = HeaderBytes
        Prepared.FileAlignment = FileAlignment
        Prepared.SectionAlignment = SectionAlignment
        Prepared.ImageBase = ImageBase
        Prepared.ImageBytes = ImageBytes
    End If
    Failure.Code = 1506
    If Symbols = 0 Then
        If SymbolCount <> 0 Then
            Exit Function
        End If
    Else
        If Symbols < Prepared.HeaderBytes Or Symbols > Prepared.Length - 4 Then
            Exit Function
        End If
        Dim SymbolBytes As LongLong = SymbolCount * 18
        If SymbolBytes > Prepared.Length - Symbols - 4 Then
            Exit Function
        End If
        Dim Strings As Long = Symbols + SymbolBytes
        Dim StringBytes As LongLong = 0
        If TryReadNativeBits(Bytes, Inspection, Strings, 4, StringBytes, Cancellation, Failure) = False Then
            Exit Function
        End If
        Failure.Code = 1506
        If StringBytes < 4 Or StringBytes > Prepared.Length - Strings Then
            Exit Function
        End If
        Prepared.SymbolTable = Symbols
        Prepared.SymbolCount = SymbolCount
        Prepared.StringTable = Strings
        Prepared.StringBytes = StringBytes
    End If
    Call ResetNativeFailure(Failure)
    Result = Prepared
    Failure.Code = 0
    TryReadNativeObjectLayout = True
End Function

Function TryReadNativeObjectSection(ByRef Bytes() As Byte, ByRef Inspection As NativeInspection, ByRef Layout As NativeObjectLayout, ByVal Index As Long, ByRef Result As NativeObjectSection, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryReadNativeObjectSection = False
    Call ResetNativeFailure(Failure)
    If Layout.Kind < 1 Or Layout.Kind > 2 Or Layout.Length <> ByteStorageLength(Bytes) Or Layout.SectionTable < 0 Or Layout.HeaderBytes < 0 Or Index < 0 Or Index >= Layout.SectionCount Then
        Exit Function
    End If
    Dim WideFirst As LongLong = Index
    WideFirst = WideFirst * 40 + Layout.SectionTable
    If WideFirst > Layout.Length - 40 Then
        Exit Function
    End If
    Dim First As Long = WideFirst
    Dim Prepared As NativeObjectSection
    Dim RawBytes As LongLong = 0
    Dim RawFirst As LongLong = 0
    Dim Relocations As LongLong = 0
    Dim RelocationCount As LongLong = 0
    Dim LineTable As LongLong = 0
    Dim LineCount As LongLong = 0
    If TryReadNativeBits(Bytes, Inspection, First, 8, Prepared.NameBits, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, First + 8, 4, Prepared.VirtualBytes, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, First + 12, 4, Prepared.VirtualAddress, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, First + 16, 4, RawBytes, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, First + 20, 4, RawFirst, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, First + 24, 4, Relocations, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, First + 28, 4, LineTable, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, First + 32, 2, RelocationCount, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, First + 34, 2, LineCount, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, First + 36, 4, Prepared.Characteristics, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If LineTable <> 0 Or LineCount <> 0 Then
        Exit Function
    End If
    If RawBytes > 2147483647 Or RawFirst > Layout.Length Then
        Exit Function
    End If
    Prepared.RawBytes = RawBytes
    Prepared.RawFirst = RawFirst
    If RawFirst <> 0 Then
        If RawFirst < Layout.HeaderBytes Or RawBytes > Layout.Length - RawFirst Then
            Exit Function
        End If
        Prepared.InitializedBytes = RawBytes
    Else
        If RawBytes > 0 And ((Prepared.Characteristics \ 128) Mod 2) = 0 Then
            Exit Function
        End If
    End If
    If Layout.Kind = 2 Then
        Call ResetNativeFailure(Failure)
        If Layout.FileAlignment < 1 Or Layout.SectionAlignment < 1 Or Layout.ImageBytes < 0 Then
            Exit Function
        End If
        Failure.Code = 1506
        If RawBytes Mod Layout.FileAlignment <> 0 Or RawFirst Mod Layout.FileAlignment <> 0 Or Prepared.VirtualAddress Mod Layout.SectionAlignment <> 0 Then
            Exit Function
        End If
        If Prepared.VirtualAddress < Layout.HeaderBytes Or Prepared.VirtualAddress > Layout.ImageBytes Then
            Exit Function
        End If
        If Prepared.VirtualBytes > Layout.ImageBytes - Prepared.VirtualAddress Or Relocations <> 0 Or RelocationCount <> 0 Or ((Prepared.Characteristics \ 16777216) Mod 2) <> 0 Then
            Exit Function
        End If
        If Prepared.VirtualBytes < Prepared.InitializedBytes Then
            Prepared.InitializedBytes = Prepared.VirtualBytes
        End If
    Else
        If ((Prepared.Characteristics \ 16777216) Mod 2) <> 0 Then
            If RelocationCount <> 65535 Or Relocations < Layout.HeaderBytes Or Relocations > Layout.Length - 10 Then
                Exit Function
            End If
            Dim TotalRecords As LongLong = 0
            Dim ReservedSymbol As LongLong = 0
            Dim ReservedType As LongLong = 0
            If TryReadNativeBits(Bytes, Inspection, Relocations, 4, TotalRecords, Cancellation, Failure) = False Then
                Exit Function
            End If
            If TryReadNativeBits(Bytes, Inspection, Relocations + 4, 4, ReservedSymbol, Cancellation, Failure) = False Then
                Exit Function
            End If
            If TryReadNativeBits(Bytes, Inspection, Relocations + 8, 2, ReservedType, Cancellation, Failure) = False Then
                Exit Function
            End If
            Failure.Code = 1506
            If TotalRecords < 65536 Or ReservedSymbol <> 0 Or ReservedType <> 0 Then
                Exit Function
            End If
            If TotalRecords > (Layout.Length - Relocations) \ 10 Then
                Exit Function
            End If
            Relocations = Relocations + 10
            RelocationCount = TotalRecords - 1
        End If
        If RelocationCount > 0 Then
            If Relocations < Layout.HeaderBytes Or Relocations > Layout.Length Then
                Exit Function
            End If
            If RelocationCount > (Layout.Length - Relocations) \ 10 Then
                Exit Function
            End If
            Prepared.RelocationTable = Relocations
            Prepared.RelocationCount = RelocationCount
        Else
            If Relocations <> 0 Then
                Exit Function
            End If
        End If
    End If
    Call ResetNativeFailure(Failure)
    Result = Prepared
    Failure.Code = 0
    TryReadNativeObjectSection = True
End Function

Function TryLocateNativeImageSpan(ByRef Bytes() As Byte, ByRef Layout As NativeObjectLayout, ByVal Address As LongLong, ByVal Count As LongLong, ByRef Inspection As NativeInspection, ByRef Section As NativeObjectSection, ByRef SectionIndex As Long, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryLocateNativeImageSpan = False
    Call ResetNativeFailure(Failure)
    If Layout.Kind <> 2 Or Layout.Length <> ByteStorageLength(Bytes) Or Layout.SectionCount < 1 Or Layout.SectionCount > 96 Then
        Exit Function
    End If
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Address < 0 Or Count < 1 Or Address > Layout.ImageBytes Then
        Exit Function
    End If
    If Count > Layout.ImageBytes - Address Then
        Exit Function
    End If
    Dim Selected As NativeObjectSection
    Dim SelectedIndex As Long = -1
    Dim Index As Long = 0
    While Index < Layout.SectionCount
        Dim Current As NativeObjectSection
        If TryReadNativeObjectSection(Bytes, Inspection, Layout, Index, Current, Cancellation, Failure) = False Then
            Exit Function
        End If
        Failure.Code = 1506
        If Current.VirtualBytes > 0 And Address < Current.VirtualAddress + Current.VirtualBytes And Current.VirtualAddress < Address + Count Then
            If SelectedIndex >= 0 Or Address < Current.VirtualAddress Then
                Exit Function
            End If
            Dim Offset As LongLong = Address - Current.VirtualAddress
            If Offset > Current.InitializedBytes Then
                Exit Function
            End If
            If Count > Current.InitializedBytes - Offset Then
                Exit Function
            End If
            Selected = Current
            SelectedIndex = Index
        End If
        Index = Index + 1
    Wend
    If SelectedIndex < 0 Then
        Exit Function
    End If
    Section = Selected
    SectionIndex = SelectedIndex
    Failure.Code = 0
    TryLocateNativeImageSpan = True
End Function
