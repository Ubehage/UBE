UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeStorageOwnership"

Private Intrinsic Function NativeRetainedDefinitionsLength(ByRef Values() As NativeRetainedDefinition) As Long
Attribute NativeRetainedDefinitionsLength.UBE_Primitive = "Array.Length"
End Function

' Revalidate the complete logical extent, including any loader-zeroed suffix.
Private Function TryValidateNativeStorageGeometry(ByRef Bytes() As Byte, ByRef Layout As NativeObjectLayout, ByRef Range As NativeDefinitionRange, ByRef Inspection As NativeInspection, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryValidateNativeStorageGeometry = False
    Failure.Code = 1506
    If Range.SymbolIndex < 0 Or Range.SectionIndex < 0 Or Range.SectionIndex >= Layout.SectionCount Or Range.ByteCount < 1 Or Range.SectionOffset < 0 Then
        Exit Function
    End If
    Dim Section As NativeObjectSection
    If TryReadNativeObjectSection(Bytes, Inspection, Layout, Range.SectionIndex, Section, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Range.Characteristics <> Section.Characteristics Or Range.SectionOffset > Section.VirtualBytes Then
        Exit Function
    End If
    If Range.ByteCount > Section.VirtualBytes - Range.SectionOffset Then
        Exit Function
    End If
    Dim Initialized As LongLong = 0
    Dim FileFirst As LongLong = -1
    If Range.SectionOffset < Section.InitializedBytes Then
        Initialized = Section.InitializedBytes - Range.SectionOffset
        If Initialized > Range.ByteCount Then
            Initialized = Range.ByteCount
        End If
        FileFirst = Section.RawFirst + Range.SectionOffset
    End If
    Dim Address As LongLong = Section.VirtualAddress + Range.SectionOffset
    If Range.FileFirst <> FileFirst Or Range.InitializedBytes <> Initialized Or Range.RelativeAddress <> Address Then
        Exit Function
    End If
    If Address > SemanticLongLongMaximum() - Layout.ImageBase Then
        Exit Function
    End If
    If Range.Address <> Layout.ImageBase + Address Then
        Exit Function
    End If
    If Range.ByteCount > SemanticLongLongMaximum() - Range.Address Then
        Exit Function
    End If
    TryValidateNativeStorageGeometry = TryValidateNativeStorageIsolation(Bytes, Layout, Range, Inspection, Cancellation, Failure)
End Function

' Retained aligns with the complete frozen table; Order lists its present storage.
' Protected is a complete caller-qualified RVA/count view, not candidate inference.
Function TryValidateNativeStorageOwnership(ByRef Bytes() As Byte, ByRef Layout As NativeObjectLayout, ByRef Expected As NativeExpectedDefinitions, ByRef Retained() As NativeRetainedDefinition, ByRef Order() As Long, ByRef Protected() As LongLong, ByRef Inspection As NativeInspection, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryValidateNativeStorageOwnership = False
    Call ResetNativeFailure(Failure)
    If Layout.Kind <> 2 Or Layout.Length <> ByteStorageLength(Bytes) Or Layout.ImageBase < 0 Or Layout.ImageBytes < 1 Or Layout.SectionCount < 1 Or Layout.SectionCount > 96 Then
        Exit Function
    End If
    If Expected.Status <> 1 Or Expected.Count < 0 Or Expected.Capacity < Expected.Count Or Expected.SourceCount < 1 Or Expected.NameLength < 0 Or Expected.NameCapacity < Expected.NameLength Then
        Exit Function
    End If
    If NativeExpectedRowsLength(Expected.Rows) <> Expected.Capacity Or ByteStorageLength(Expected.Names) <> Expected.NameCapacity Or NativeRetainedDefinitionsLength(Retained) <> Expected.Count Then
        Exit Function
    End If
    Dim Index As Long = 0
    Dim StorageCount As Long = 0
    While Index < Expected.Count
        If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
            Exit Function
        End If
        Call ResetNativeFailure(Failure)
        Dim Row As NativeExpectedDefinition
        Row = Expected.Rows(Index)
        If Row.Family < 1 Or Row.Family > 23 Or Row.UnitKind < 0 Or Row.UnitKind > 6 Or Row.SourceId < -1 Or Row.SourceId >= Expected.SourceCount Or Row.RequireObject < 0 Or Row.RequireObject > 1 Or Row.StorageBytes < 0 Then
            Exit Function
        End If
        If Row.Name.First < 0 Or Row.Name.Count < 1 Or Row.Name.First > Expected.NameLength Then
            Exit Function
        End If
        If Row.Name.Count > Expected.NameLength - Row.Name.First Then
            Exit Function
        End If
        If NativeExpectedHasStorage(Row) <> (Row.StorageBytes > 0) Or Retained(Index).Present < 0 Or Retained(Index).Present > 1 Then
            Exit Function
        End If
        Failure.Code = 1506
        If Retained(Index).Present = 0 Then
            If Row.RequireObject <> 0 Then
                Exit Function
            End If
        Else
            If NativeExpectedHasStorage(Row) Then
                StorageCount = StorageCount + 1
            End If
        End If
        Index = Index + 1
    Wend
    Call ResetNativeFailure(Failure)
    If NativeInventoryOrderLength(Order) <> StorageCount Then
        Exit Function
    End If
    Dim ProtectedCount As Long = NativeExpectedIntegerLength(Protected)
    If ProtectedCount Mod 2 <> 0 Then
        Exit Function
    End If
    Dim Previous As LongLong = -1
    Index = 0
    While Index < ProtectedCount
        If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
            Exit Function
        End If
        Call ResetNativeFailure(Failure)
        Dim First As LongLong = Protected(Index)
        Dim Count As LongLong = Protected(Index + 1)
        If First < 0 Or First < Previous Or First > Layout.ImageBytes Or Count < 1 Then
            Exit Function
        End If
        If Count > Layout.ImageBytes - First Then
            Exit Function
        End If
        Previous = First
        Index = Index + 2
    Wend
    Dim ThreadStorage As NativeThreadStorage
    If TryReadNativeThreadStorage(Bytes, Layout, Inspection, ThreadStorage, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim ProtectedIndex As Long = 0
    Dim PreviousEnd As LongLong = 0
    Index = 0
    While Index < StorageCount
        If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
            Exit Function
        End If
        Call ResetNativeFailure(Failure)
        Dim Owner As Long = Order(Index)
        If Owner < 0 Or Owner >= Expected.Count Then
            Exit Function
        End If
        Row = Expected.Rows(Owner)
        If NativeExpectedHasStorage(Row) = False Or Retained(Owner).Present <> 1 Then
            Exit Function
        End If
        Dim Range As NativeDefinitionRange
        Range = Retained(Owner).ImageRange
        Failure.Code = 1506
        If Range.ByteCount <> Row.StorageBytes Or Range.RelativeAddress < PreviousEnd Or ValidNativeRetentionRange(Row, Range) = False Then
            Exit Function
        End If
        If TryValidateNativeStorageGeometry(Bytes, Layout, Range, Inspection, Cancellation, Failure) = False Then
            Exit Function
        End If
        PreviousEnd = Range.RelativeAddress + Range.ByteCount
        If Row.Family = 12 Or Row.Family = 22 Then
            If TryValidateNativeThreadMember(Row, Retained(Owner), Bytes, Layout, ThreadStorage, Inspection, Cancellation, Failure) = False Then
                Exit Function
            End If
        Else
            Failure.Code = 1506
            If NativeImageRangeOverlaps(Range.RelativeAddress, Range.ByteCount, ThreadStorage.TemplateRange) Then
                Exit Function
            End If
        End If
        Failure.Code = 1506
        If NativeImageRangeOverlaps(Range.RelativeAddress, Range.ByteCount, ThreadStorage.DirectoryRange) Or NativeImageRangeOverlaps(Range.RelativeAddress, Range.ByteCount, ThreadStorage.IndexRange) Or NativeImageRangeOverlaps(Range.RelativeAddress, Range.ByteCount, ThreadStorage.CallbacksRange) Then
            Exit Function
        End If
        While ProtectedIndex < ProtectedCount
            If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
                Exit Function
            End If
            First = Protected(ProtectedIndex)
            If First >= PreviousEnd Then
                Exit While
            End If
            Failure.Code = 1506
            If First + Protected(ProtectedIndex + 1) > Range.RelativeAddress Then
                Exit Function
            End If
            ProtectedIndex = ProtectedIndex + 2
        Wend
        Index = Index + 1
    Wend
    Failure.Code = 0
    Failure.Resource = 0
    TryValidateNativeStorageOwnership = True
End Function
