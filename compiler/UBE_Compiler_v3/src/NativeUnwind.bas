UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeUnwind"

Type NativeFunctionExtent
    CodeSection As Long
    CodeFirst As Long
    CodeBytes As Long
    UnwindSection As Long
    UnwindFirst As Long
    CodeOffset As LongLong
    UnwindOffset As LongLong
End Type

Type NativeImageFunctionTable
    FileFirst As Long
    Count As Long
    Length As Long
    Status As Long
End Type

Function TryPrepareNativeImageFunctionTable(ByRef Bytes() As Byte, ByRef Layout As NativeObjectLayout, ByRef Inspection As NativeInspection, ByRef Result As NativeImageFunctionTable, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryPrepareNativeImageFunctionTable = False
    Dim Prepared As NativeImageFunctionTable
    If TryReadNativeImageFunctionTable(Bytes, Layout, Inspection, Prepared, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Index As Long = 0
    While Index < Prepared.Count
        Dim Extent As NativeFunctionExtent
        If TryReadNativeImageFunctionExtent(Bytes, Layout, Prepared, Index, Inspection, Extent, Cancellation, Failure) = False Then
            Exit Function
        End If
        Index = Index + 1
    Wend
    Prepared.Status = 1
    Result = Prepared
    Failure.Code = 0
    TryPrepareNativeImageFunctionTable = True
End Function

Function TryBindNativeFunctionExtent(ByRef Retained As NativeRetainedDefinition, ByRef ObjectExtent As NativeFunctionExtent, ByRef ImageBytes() As Byte, ByRef ImageLayout As NativeObjectLayout, ByRef Table As NativeImageFunctionTable, ByRef Inspection As NativeInspection, ByRef Result As NativeFunctionExtent, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryBindNativeFunctionExtent = False
    Call ResetNativeFailure(Failure)
    If Retained.Present <> 1 Or Retained.ObjectRange.TypeCode <> 32 Or Retained.ImageRange.TypeCode <> 32 Or Retained.ObjectRange.ByteCount <> 1 Or Retained.ImageRange.ByteCount <> 1 Or Retained.ObjectRange.InitializedBytes <> 1 Or Retained.ImageRange.InitializedBytes <> 1 Then
        Exit Function
    End If
    If ObjectExtent.CodeBytes < 1 Or ImageLayout.Kind <> 2 Or ImageLayout.Length <> ByteStorageLength(ImageBytes) Or Table.Status <> 1 Or Table.Length <> ImageLayout.Length Or Table.Count < 0 Or Table.FileFirst < 0 Or Table.FileFirst > ImageLayout.Length Then
        Exit Function
    End If
    If Table.Count > (ImageLayout.Length - Table.FileFirst) \ 12 Then
        Exit Function
    End If
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If ObjectExtent.CodeSection <> Retained.ObjectRange.SectionIndex Or ObjectExtent.CodeFirst <> Retained.ObjectRange.FileFirst Or ObjectExtent.CodeOffset <> Retained.ObjectRange.SectionOffset Then
        Exit Function
    End If
    Dim Low As Long = 0
    Dim High As Long = Table.Count
    While Low < High
        Dim Middle As Long = Low + (High - Low) \ 2
        Dim Address As LongLong = 0
        If TryReadNativeBits(ImageBytes, Inspection, Table.FileFirst + Middle * 12, 4, Address, Cancellation, Failure) = False Then
            Exit Function
        End If
        If Address < Retained.ImageRange.RelativeAddress Then
            Low = Middle + 1
        Else
            If Address > Retained.ImageRange.RelativeAddress Then
                High = Middle
            Else
                Dim Prepared As NativeFunctionExtent
                If TryReadNativeImageFunctionExtent(ImageBytes, ImageLayout, Table, Middle, Inspection, Prepared, Cancellation, Failure) = False Then
                    Exit Function
                End If
                Failure.Code = 1506
                If Prepared.CodeSection <> Retained.ImageRange.SectionIndex Or Prepared.CodeFirst <> Retained.ImageRange.FileFirst Or Prepared.CodeOffset <> Retained.ImageRange.SectionOffset Or Prepared.CodeBytes <> ObjectExtent.CodeBytes Then
                    Exit Function
                End If
                Result = Prepared
                Failure.Code = 0
                TryBindNativeFunctionExtent = True
                Exit Function
            End If
        End If
    Wend
    Failure.Code = 1506
End Function

Function TryReadNativeImageFunctionTable(ByRef Bytes() As Byte, ByRef Layout As NativeObjectLayout, ByRef Inspection As NativeInspection, ByRef Result As NativeImageFunctionTable, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryReadNativeImageFunctionTable = False
    Dim Address As LongLong = 0
    Dim Size As LongLong = 0
    If TryReadNativeImageDirectory(Bytes, Layout, 3, Inspection, Address, Size, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Prepared As NativeImageFunctionTable
    Prepared.Length = Layout.Length
    Failure.Code = 1506
    If Address = 0 Or Size = 0 Then
        If Address <> 0 Or Size <> 0 Then
            Exit Function
        End If
    Else
        If Address Mod 4 <> 0 Or Size Mod 12 <> 0 Then
            Exit Function
        End If
        Dim Section As NativeObjectSection
        Dim SectionIndex As Long = -1
        If TryLocateNativeImageSpan(Bytes, Layout, Address, Size, Inspection, Section, SectionIndex, Cancellation, Failure) = False Then
            Exit Function
        End If
        Failure.Code = 1506
        If NativeReadOnlyDataCharacteristics(Section.Characteristics) = False Then
            Exit Function
        End If
        Prepared.FileFirst = Section.RawFirst + Address - Section.VirtualAddress
        Prepared.Count = Size \ 12
    End If
    Result = Prepared
    Failure.Code = 0
    TryReadNativeImageFunctionTable = True
End Function

Function TryReadNativeImageFunctionExtent(ByRef Bytes() As Byte, ByRef Layout As NativeObjectLayout, ByRef Table As NativeImageFunctionTable, ByVal Index As Long, ByRef Inspection As NativeInspection, ByRef Result As NativeFunctionExtent, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryReadNativeImageFunctionExtent = False
    Call ResetNativeFailure(Failure)
    If Layout.Kind <> 2 Or Layout.Length <> ByteStorageLength(Bytes) Or Table.Length <> Layout.Length Or Index < 0 Or Index >= Table.Count Or Table.FileFirst < 0 Or Table.FileFirst > Layout.Length Then
        Exit Function
    End If
    If Table.Count > (Layout.Length - Table.FileFirst) \ 12 Then
        Exit Function
    End If
    Dim First As LongLong = 0
    Dim Last As LongLong = 0
    Dim Unwind As LongLong = 0
    Dim Record As Long = Table.FileFirst + Index * 12
    If TryReadNativeBits(Bytes, Inspection, Record, 4, First, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, Record + 4, 4, Last, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, Record + 8, 4, Unwind, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If First >= Last Or Unwind Mod 4 <> 0 Then
        Exit Function
    End If
    If Index > 0 Then
        Dim PriorFirst As LongLong = 0
        Dim PriorLast As LongLong = 0
        If TryReadNativeBits(Bytes, Inspection, Record - 12, 4, PriorFirst, Cancellation, Failure) = False Then
            Exit Function
        End If
        If TryReadNativeBits(Bytes, Inspection, Record - 8, 4, PriorLast, Cancellation, Failure) = False Then
            Exit Function
        End If
        Failure.Code = 1506
        If PriorFirst >= PriorLast Or PriorLast > First Then
            Exit Function
        End If
    End If
    Dim CodeSection As NativeObjectSection
    Dim UnwindSection As NativeObjectSection
    Dim Prepared As NativeFunctionExtent
    If TryLocateNativeImageSpan(Bytes, Layout, First, Last - First, Inspection, CodeSection, Prepared.CodeSection, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryLocateNativeImageSpan(Bytes, Layout, Unwind, 4, Inspection, UnwindSection, Prepared.UnwindSection, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If NativeReadableCodeCharacteristics(CodeSection.Characteristics) = False Or NativeReadOnlyDataCharacteristics(UnwindSection.Characteristics) = False Then
        Exit Function
    End If
    Prepared.CodeOffset = First - CodeSection.VirtualAddress
    Prepared.CodeFirst = CodeSection.RawFirst + Prepared.CodeOffset
    Prepared.CodeBytes = Last - First
    Prepared.UnwindOffset = Unwind - UnwindSection.VirtualAddress
    Prepared.UnwindFirst = UnwindSection.RawFirst + Prepared.UnwindOffset
    Result = Prepared
    Failure.Code = 0
    TryReadNativeImageFunctionExtent = True
End Function

Private Function TryReadNativeFunctionAddress(ByRef Bytes() As Byte, ByRef Layout As NativeObjectLayout, ByRef Inventory As NativeSymbolInventory, ByRef Table As NativeObjectSection, ByVal Field As Long, ByRef Inspection As NativeInspection, ByRef Section As NativeObjectSection, ByRef SectionIndex As Long, ByRef Offset As LongLong, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryReadNativeFunctionAddress = False
    Dim Relocation As NativeObjectRelocation
    If TryReadNativeObjectRelocation(Bytes, Inspection, Layout, Table, Field, Relocation, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Relocation.Kind <> 3 Or Relocation.Offset <> Field * 4 Then
        Exit Function
    End If
    Dim Symbol As NativeObjectSymbol
    If TryReadNativeIndexedSymbol(Inventory, Relocation.TargetIndex, Inspection, Symbol, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Symbol.SectionNumber < 1 Or (Symbol.StorageClass <> 2 And Symbol.StorageClass <> 3) Then
        Exit Function
    End If
    Dim Target As NativeObjectSection
    If TryReadNativeObjectSection(Bytes, Inspection, Layout, Symbol.SectionNumber - 1, Target, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Addend As LongLong = 0
    If TryReadNativeBits(Bytes, Inspection, Table.RawFirst + Field * 4, 4, Addend, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Symbol.Value < 0 Or Symbol.Value > Target.InitializedBytes Then
        Exit Function
    End If
    If Addend > Target.InitializedBytes - Symbol.Value Then
        Exit Function
    End If
    Section = Target
    SectionIndex = Symbol.SectionNumber - 1
    Offset = Symbol.Value + Addend
    Failure.Code = 0
    TryReadNativeFunctionAddress = True
End Function

Function TryReadNativeFunctionExtent(ByRef Bytes() As Byte, ByRef Layout As NativeObjectLayout, ByRef Inventory As NativeSymbolInventory, ByRef Table As NativeObjectSection, ByVal Index As Long, ByRef Inspection As NativeInspection, ByRef Result As NativeFunctionExtent, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryReadNativeFunctionExtent = False
    Call ResetNativeFailure(Failure)
    If Layout.Kind <> 1 Or Layout.Length <> ByteStorageLength(Bytes) Or Inventory.Status <> 1 Or Inventory.Length <> Layout.Length Or Inventory.SymbolCapacity <> Layout.SymbolCount Or Index < 0 Then
        Exit Function
    End If
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Table.RawBytes < 12 Or Table.RawBytes Mod 12 <> 0 Or Table.InitializedBytes <> Table.RawBytes Or Table.RawFirst < 0 Or Table.RawFirst > Layout.Length Then
        Exit Function
    End If
    If Table.RawBytes > Layout.Length - Table.RawFirst Or Table.RelocationCount <> Table.RawBytes \ 4 Or NativeReadOnlyDataCharacteristics(Table.Characteristics) = False Then
        Exit Function
    End If
    Call ResetNativeFailure(Failure)
    If Index >= Table.RawBytes \ 12 Then
        Exit Function
    End If
    Dim FirstSection As NativeObjectSection
    Dim LastSection As NativeObjectSection
    Dim UnwindSection As NativeObjectSection
    Dim FirstIndex As Long = -1
    Dim LastIndex As Long = -1
    Dim UnwindIndex As Long = -1
    Dim First As LongLong = 0
    Dim Last As LongLong = 0
    Dim Unwind As LongLong = 0
    If TryReadNativeFunctionAddress(Bytes, Layout, Inventory, Table, Index * 3, Inspection, FirstSection, FirstIndex, First, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeFunctionAddress(Bytes, Layout, Inventory, Table, Index * 3 + 1, Inspection, LastSection, LastIndex, Last, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeFunctionAddress(Bytes, Layout, Inventory, Table, Index * 3 + 2, Inspection, UnwindSection, UnwindIndex, Unwind, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If FirstIndex <> LastIndex Or First >= Last Or NativeReadableCodeCharacteristics(FirstSection.Characteristics) = False Then
        Exit Function
    End If
    If NativeReadOnlyDataCharacteristics(UnwindSection.Characteristics) = False Or Unwind Mod 4 <> 0 Then
        Exit Function
    End If
    If UnwindSection.InitializedBytes - Unwind < 4 Then
        Exit Function
    End If
    Dim Prepared As NativeFunctionExtent
    Prepared.CodeSection = FirstIndex
    Prepared.CodeFirst = FirstSection.RawFirst + First
    Prepared.CodeBytes = Last - First
    Prepared.UnwindSection = UnwindIndex
    Prepared.UnwindFirst = UnwindSection.RawFirst + Unwind
    Prepared.CodeOffset = First
    Prepared.UnwindOffset = Unwind
    Result = Prepared
    Failure.Code = 0
    Failure.Resource = 0
    TryReadNativeFunctionExtent = True
End Function
