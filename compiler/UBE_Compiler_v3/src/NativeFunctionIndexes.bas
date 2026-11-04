UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeFunctionIndexes"

' Private owned index over one immutable symbol inventory and layout.
Type NativeFunctionIndex
    Keys() As ByteKey
    Addresses() As Byte
    Order() As Long
    KeyCapacity As Long
    AddressCapacity As Long
    OrderCapacity As Long
    Count As Long
    SymbolCount As Long
    Length As Long
    Kind As Long
    Status As Long
End Type
Private Intrinsic Function NativeFunctionKeyLength(ByRef Values() As ByteKey) As Long
Attribute NativeFunctionKeyLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function NativeFunctionOrderLength(ByRef Values() As Long) As Long
Attribute NativeFunctionOrderLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function TryResizeNativeFunctionKeys(ByRef Values() As ByteKey, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeNativeFunctionKeys.UBE_Primitive = "Array.TryResize"
End Function
Private Intrinsic Function TryResizeNativeFunctionOrder(ByRef Values() As Long, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeNativeFunctionOrder.UBE_Primitive = "Array.TryResize"
End Function

Private Function TryReleaseNativeFunctionKeys(ByRef State As NativeFunctionIndex, ByRef Storage As NativeInspectionStorage, ByRef Usage As NativeUsage, ByRef Failure As NativeFailure) As Boolean
    TryReleaseNativeFunctionKeys = False
    If TryResizeNativeFunctionKeys(State.Keys, 0, False) = False Then
        Exit Function
    End If
    Dim Payload As LongLong = State.KeyCapacity
    If TryReleaseNativeInspectionStorage(Storage, Usage, Payload * 16, Failure) = False Then
        Exit Function
    End If
    State.KeyCapacity = 0
    If TryResizeByteStorage(State.Addresses, 0, False) = False Then
        Exit Function
    End If
    Payload = State.AddressCapacity
    If TryReleaseNativeInspectionStorage(Storage, Usage, Payload, Failure) = False Then
        Exit Function
    End If
    State.AddressCapacity = 0
    TryReleaseNativeFunctionKeys = True
End Function

Function TryPrepareNativeFunctionIndex(ByRef State As NativeFunctionIndex, ByRef Inventory As NativeSymbolInventory, ByRef Layout As NativeObjectLayout, ByRef Inspection As NativeInspection, ByRef Storage As NativeInspectionStorage, ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryPrepareNativeFunctionIndex = False
    Call ResetNativeFailure(Failure)
    If State.Status <> 0 Or State.KeyCapacity <> 0 Or State.AddressCapacity <> 0 Or State.OrderCapacity <> 0 Or State.Count <> 0 Or State.SymbolCount <> 0 Or State.Length <> 0 Or State.Kind <> 0 Then
        Exit Function
    End If
    If NativeFunctionKeyLength(State.Keys) <> 0 Or ByteStorageLength(State.Addresses) <> 0 Or NativeFunctionOrderLength(State.Order) <> 0 Then
        Exit Function
    End If
    If (Layout.Kind <> 1 And Layout.Kind <> 2) Or Layout.Length < 0 Or Layout.SymbolCount < 0 Or Inventory.Status <> 1 Or Inventory.Length <> Layout.Length Or Inventory.SymbolCapacity <> Layout.SymbolCount Or Inventory.PrimaryCount < 0 Or Inventory.PrimaryCount > Inventory.SymbolCapacity Or Inventory.PrimaryCount > 536870911 Then
        Exit Function
    End If
    State.Status = 4
    State.SymbolCount = Layout.SymbolCount
    State.Length = Layout.Length
    State.Kind = Layout.Kind
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Payload As LongLong = Inventory.PrimaryCount
    Payload = Payload * 16
    Dim Cleanup As NativeFailure
    If TryReserveNativeInspectionStorage(Storage, Limits, Usage, Payload, Failure) = False Then
        Exit Function
    End If
    If TryResizeNativeFunctionKeys(State.Keys, Inventory.PrimaryCount, False) = False Then
        Call TryReleaseNativeInspectionStorage(Storage, Usage, Payload, Cleanup)
        Failure.Code = 1502
        Failure.Resource = 7
        Exit Function
    End If
    State.KeyCapacity = Inventory.PrimaryCount
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    Payload = Inventory.PrimaryCount
    Payload = Payload * 4
    If TryReserveNativeInspectionStorage(Storage, Limits, Usage, Payload, Failure) = False Then
        Exit Function
    End If
    If TryResizeByteStorage(State.Addresses, Inventory.PrimaryCount * 4, False) = False Then
        Call TryReleaseNativeInspectionStorage(Storage, Usage, Payload, Cleanup)
        Failure.Code = 1502
        Failure.Resource = 7
        Exit Function
    End If
    State.AddressCapacity = Inventory.PrimaryCount * 4
    Dim RawIndex As Long = 0
    Dim PrimaryCount As Long = 0
    While RawIndex < Inventory.SymbolCapacity
        Dim Symbol As NativeObjectSymbol
        If TryReadNativeIndexedSymbol(Inventory, RawIndex, Inspection, Symbol, Cancellation, Failure) = False Then
            Exit Function
        End If
        Call ResetNativeFailure(Failure)
        If PrimaryCount >= Inventory.PrimaryCount Then
            Exit Function
        End If
        PrimaryCount = PrimaryCount + 1
        If Symbol.TypeCode = 32 And Symbol.SectionNumber > 0 And (Symbol.StorageClass = 2 Or Symbol.StorageClass = 3) Then
            If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
                Exit Function
            End If
            Dim Value As LongLong = Symbol.Value
            Failure.Code = 1506
            Dim Maximum As LongLong = 65536
            Maximum = Maximum * 65536 - 1
            If Value < 0 Or Value > Maximum Or Symbol.SectionNumber > Layout.SectionCount Then
                Exit Function
            End If
            Dim Key As ByteKey
            Key.Partition = Symbol.SectionNumber
            Key.FirstByte = State.Count * 4
            Key.ByteCount = 4
            Key.Value = RawIndex
            State.Keys(State.Count) = Key
            State.Addresses(Key.FirstByte) = Value \ 16777216
            State.Addresses(Key.FirstByte + 1) = (Value \ 65536) Mod 256
            State.Addresses(Key.FirstByte + 2) = (Value \ 256) Mod 256
            State.Addresses(Key.FirstByte + 3) = Value Mod 256
            State.Count = State.Count + 1
        End If
        RawIndex = Symbol.NextIndex
    Wend
    Call ResetNativeFailure(Failure)
    If PrimaryCount <> Inventory.PrimaryCount Then
        Exit Function
    End If
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    Payload = State.Count
    Payload = Payload * 8
    If TryReserveNativeInspectionStorage(Storage, Limits, Usage, Payload, Failure) = False Then
        Exit Function
    End If
    Dim Budget As ByteKeyBudget
    Budget.MaximumBytes = Inspection.MaximumBytes
    Budget.MaximumEvents = Inspection.MaximumEvents
    Budget.Bytes = Inspection.Bytes
    Budget.Events = Inspection.Events
    Dim Code As Long = 5
    Dim Ordered As Boolean = False
    Dim NeverCancelled As Boolean = False
    If Cancellation Is Nothing Then
        Ordered = TryOrderByteKeysBudgeted(State.Addresses, State.Keys, State.Count, State.KeyCapacity, State.Order, Code, Budget, NeverCancelled)
    Else
        Ordered = TryOrderByteKeysBudgeted(State.Addresses, State.Keys, State.Count, State.KeyCapacity, State.Order, Code, Budget, Cancellation.Requested)
    End If
    Inspection.Bytes = Budget.Bytes
    Inspection.Events = Budget.Events
    Call ResetNativeFailure(Failure)
    If Code = 0 Then
        Failure.Code = 0
    End If
    If Code = 2 Or Code = 5 Then
        Failure.Code = 1502
        Failure.Resource = 7
    End If
    If Code = 3 Then
        Failure.Code = 1507
    End If
    If Ordered Then
        State.OrderCapacity = State.Count
        Payload = Payload \ 2
    End If
    If TryReleaseNativeInspectionStorage(Storage, Usage, Payload, Cleanup) = False Then
        Failure = Cleanup
        Exit Function
    End If
    If Ordered = False Then
        Exit Function
    End If
    Dim Position As Long = 0
    While Position < State.Count
        If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
            Exit Function
        End If
        State.Order(Position) = State.Keys(State.Order(Position)).Value
        Position = Position + 1
    Wend
    If TryReleaseNativeFunctionKeys(State, Storage, Usage, Failure) = False Then
        Exit Function
    End If
    State.Status = 1
    Failure.Code = 0
    Failure.Resource = 0
    TryPrepareNativeFunctionIndex = True
End Function

Function TryDisposeNativeFunctionIndex(ByRef State As NativeFunctionIndex, ByRef Storage As NativeInspectionStorage, ByRef Usage As NativeUsage, ByRef Failure As NativeFailure) As Boolean
    TryDisposeNativeFunctionIndex = False
    Call ResetNativeFailure(Failure)
    If State.KeyCapacity < 0 Or State.AddressCapacity < 0 Or State.OrderCapacity < 0 Then
        Exit Function
    End If
    If NativeFunctionKeyLength(State.Keys) <> State.KeyCapacity Or ByteStorageLength(State.Addresses) <> State.AddressCapacity Or NativeFunctionOrderLength(State.Order) <> State.OrderCapacity Then
        Exit Function
    End If
    Dim Payload As LongLong = State.KeyCapacity
    Payload = Payload * 16 + State.AddressCapacity
    Dim Ordered As LongLong = State.OrderCapacity
    Payload = Payload + Ordered * 4
    If Payload > Storage.Payload Or Payload > Usage.Payload Then
        Exit Function
    End If
    State.Status = 4
    If TryReleaseNativeFunctionKeys(State, Storage, Usage, Failure) = False Then
        Exit Function
    End If
    If TryResizeNativeFunctionOrder(State.Order, 0, False) = False Then
        Exit Function
    End If
    If TryReleaseNativeInspectionStorage(Storage, Usage, Ordered * 4, Failure) = False Then
        Exit Function
    End If
    State.OrderCapacity = 0
    State.Count = 0
    State.SymbolCount = 0
    State.Length = 0
    State.Kind = 0
    State.Status = 0
    Failure.Code = 0
    Failure.Resource = 0
    TryDisposeNativeFunctionIndex = True
End Function

Function TryReadNativeFunctionFence(ByRef State As NativeFunctionIndex, ByRef Inventory As NativeSymbolInventory, ByRef Bytes() As Byte, ByRef Layout As NativeObjectLayout, ByRef Anchor As NativeDefinitionRange, ByRef Inspection As NativeInspection, ByRef Result As NativeDefinitionRange, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryReadNativeFunctionFence = False
    Call ResetNativeFailure(Failure)
    If State.Status <> 1 Or State.KeyCapacity <> 0 Or State.AddressCapacity <> 0 Or State.Count < 0 Or State.Count <> State.OrderCapacity Or NativeFunctionOrderLength(State.Order) <> State.OrderCapacity Or State.SymbolCount <> Inventory.SymbolCapacity Or State.Length <> Inventory.Length Or State.Length <> Layout.Length Or State.Length <> ByteStorageLength(Bytes) Or State.Kind <> Layout.Kind Or Layout.SymbolCount <> State.SymbolCount Then
        Exit Function
    End If
    If Anchor.TypeCode <> 32 Or Anchor.ByteCount <> 1 Or Anchor.InitializedBytes <> 1 Then
        Exit Function
    End If
    Dim Symbol As NativeObjectSymbol
    If TryReadNativeIndexedSymbol(Inventory, Anchor.SymbolIndex, Inspection, Symbol, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Symbol.TypeCode <> 32 Or Symbol.SectionNumber < 1 Or (Symbol.StorageClass <> 2 And Symbol.StorageClass <> 3) Or Symbol.SectionNumber - 1 <> Anchor.SectionIndex Or Symbol.Value <> Anchor.SectionOffset Then
        Exit Function
    End If
    Dim Section As NativeObjectSection
    If TryReadNativeObjectSection(Bytes, Inspection, Layout, Anchor.SectionIndex, Section, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If NativeReadableCodeCharacteristics(Section.Characteristics) = False Or Anchor.Characteristics <> Section.Characteristics Or Symbol.Value < 0 Or Symbol.Value >= Section.InitializedBytes Then
        Exit Function
    End If
    If Anchor.FileFirst <> Section.RawFirst + Symbol.Value Then
        Exit Function
    End If
    Dim Relative As LongLong = 0
    Dim Address As LongLong = 0
    If Layout.Kind = 2 Then
        Relative = Section.VirtualAddress + Symbol.Value
        Address = Layout.ImageBase + Relative
    End If
    If Anchor.RelativeAddress <> Relative Or Anchor.Address <> Address Then
        Exit Function
    End If
    Dim Low As Long = 0
    Dim High As Long = State.Count
    While Low < High
        Dim Middle As Long = Low + (High - Low) \ 2
        If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim Candidate As NativeObjectSymbol
        If TryReadNativeIndexedSymbol(Inventory, State.Order(Middle), Inspection, Candidate, Cancellation, Failure) = False Then
            Exit Function
        End If
        If Candidate.SectionNumber < Symbol.SectionNumber Or (Candidate.SectionNumber = Symbol.SectionNumber And Candidate.Value <= Symbol.Value) Then
            Low = Middle + 1
        Else
            High = Middle
        End If
    Wend
    Dim Last As LongLong = Section.InitializedBytes
    If Low < State.Count Then
        If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim NextSymbol As NativeObjectSymbol
        If TryReadNativeIndexedSymbol(Inventory, State.Order(Low), Inspection, NextSymbol, Cancellation, Failure) = False Then
            Exit Function
        End If
        If NextSymbol.SectionNumber = Symbol.SectionNumber Then
            Last = NextSymbol.Value
        End If
    End If
    Failure.Code = 1506
    If Last <= Symbol.Value Or Last > Section.InitializedBytes Then
        Exit Function
    End If
    Dim Prepared As NativeDefinitionRange
    Prepared = Anchor
    Prepared.ByteCount = Last - Symbol.Value
    Prepared.InitializedBytes = Prepared.ByteCount
    Result = Prepared
    Failure.Code = 0
    Failure.Resource = 0
    TryReadNativeFunctionFence = True
End Function
