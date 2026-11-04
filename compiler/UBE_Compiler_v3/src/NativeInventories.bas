UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeInventories"

' One fresh/disposable owner; see ../NATIVE-INVENTORY-IMPLEMENTATION.md.
' Capacity fields describe actual owned arrays, including partial failure.
Type NativeSymbolInventory
    Symbols() As NativeObjectSymbol
    Keys() As ByteKey
    Order() As Long
    SymbolCapacity As Long
    KeyCapacity As Long
    OrderCapacity As Long
    PrimaryCount As Long
    Length As Long
    Status As Long
End Type
Private Intrinsic Function NativeInventorySymbolLength(ByRef Values() As NativeObjectSymbol) As Long
Attribute NativeInventorySymbolLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function NativeInventoryKeyLength(ByRef Values() As ByteKey) As Long
Attribute NativeInventoryKeyLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function NativeInventoryOrderLength(ByRef Values() As Long) As Long
Attribute NativeInventoryOrderLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function TryResizeNativeInventorySymbols(ByRef Values() As NativeObjectSymbol, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeNativeInventorySymbols.UBE_Primitive = "Array.TryResize"
End Function
Private Intrinsic Function TryResizeNativeInventoryKeys(ByRef Values() As ByteKey, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeNativeInventoryKeys.UBE_Primitive = "Array.TryResize"
End Function
Private Intrinsic Function TryResizeNativeInventoryOrder(ByRef Values() As Long, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeNativeInventoryOrder.UBE_Primitive = "Array.TryResize"
End Function

Sub ReadNativeKeyBudget(ByRef Result As ByteKeyBudget, ByRef Inspection As NativeInspection)
    Result.MaximumBytes = Inspection.MaximumBytes
    Result.MaximumEvents = Inspection.MaximumEvents
    Result.Bytes = Inspection.Bytes
    Result.Events = Inspection.Events
End Sub
Sub FinishNativeKeyBudget(ByRef Inspection As NativeInspection, ByRef Budget As ByteKeyBudget, ByVal Code As Long, ByRef Failure As NativeFailure)
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
End Sub

Private Function ValidNativeSymbolInventory(ByRef State As NativeSymbolInventory) As Boolean
    ValidNativeSymbolInventory = False
    If State.Status <> 1 Or State.SymbolCapacity < 0 Or State.KeyCapacity <> State.SymbolCapacity Or State.PrimaryCount < 0 Or State.PrimaryCount > State.KeyCapacity Or State.OrderCapacity <> State.PrimaryCount Or State.Length < 0 Then
        Exit Function
    End If
    If NativeInventorySymbolLength(State.Symbols) <> State.SymbolCapacity Or NativeInventoryKeyLength(State.Keys) <> State.KeyCapacity Or NativeInventoryOrderLength(State.Order) <> State.OrderCapacity Then
        Exit Function
    End If
    ValidNativeSymbolInventory = True
End Function

Function TryPrepareNativeSymbolInventory(ByRef State As NativeSymbolInventory, ByRef Bytes() As Byte, ByRef Layout As NativeObjectLayout, ByRef Inspection As NativeInspection, ByRef Storage As NativeInspectionStorage, ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryPrepareNativeSymbolInventory = False
    Call ResetNativeFailure(Failure)
    If State.Status <> 0 Or State.SymbolCapacity <> 0 Or State.KeyCapacity <> 0 Or State.OrderCapacity <> 0 Or State.PrimaryCount <> 0 Then
        Exit Function
    End If
    If NativeInventorySymbolLength(State.Symbols) <> 0 Or NativeInventoryKeyLength(State.Keys) <> 0 Or NativeInventoryOrderLength(State.Order) <> 0 Then
        Exit Function
    End If
    If Layout.Length <> ByteStorageLength(Bytes) Or Layout.SymbolCount < 0 Or Layout.SymbolTable < 0 Or Layout.SymbolTable > Layout.Length Then
        Exit Function
    End If
    If Layout.SymbolCount > (Layout.Length - Layout.SymbolTable) \ 18 Then
        Exit Function
    End If
    State.Status = 4
    State.Length = Layout.Length
    Call ResetNativeFailure(Failure)
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Count As Long = Layout.SymbolCount
    Dim Payload As LongLong = Count
    Payload = Payload * 40
    If TryReserveNativeInspectionStorage(Storage, Limits, Usage, Payload, Failure) = False Then
        Exit Function
    End If
    Dim Cleanup As NativeFailure
    If TryResizeNativeInventorySymbols(State.Symbols, Count, False) = False Then
        Call TryReleaseNativeInspectionStorage(Storage, Usage, Payload, Cleanup)
        Failure.Code = 1502
        Failure.Resource = 7
        Exit Function
    End If
    State.SymbolCapacity = Count
    Call ResetNativeFailure(Failure)
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    Payload = Count
    Payload = Payload * 16
    If TryReserveNativeInspectionStorage(Storage, Limits, Usage, Payload, Failure) = False Then
        Exit Function
    End If
    If TryResizeNativeInventoryKeys(State.Keys, Count, False) = False Then
        Call TryReleaseNativeInspectionStorage(Storage, Usage, Payload, Cleanup)
        Failure.Code = 1502
        Failure.Resource = 7
        Exit Function
    End If
    State.KeyCapacity = Count
    Dim Index As Long = 0
    While Index < Count
        Call ResetNativeFailure(Failure)
        If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim Symbol As NativeObjectSymbol
        Call ResetNativeFailure(Failure)
        If TryReadNativeObjectSymbol(Bytes, Inspection, Layout, Index, Symbol, Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim Key As ByteKey
        Key.Partition = 0
        Key.FirstByte = Symbol.Name.First
        Key.ByteCount = Symbol.Name.Count
        Key.Value = Index
        State.Symbols(Index) = Symbol
        State.Keys(State.PrimaryCount) = Key
        State.PrimaryCount = State.PrimaryCount + 1
        Index = Symbol.NextIndex
    Wend
    Call ResetNativeFailure(Failure)
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Temporary As LongLong = State.PrimaryCount
    Temporary = Temporary * 8
    If TryReserveNativeInspectionStorage(Storage, Limits, Usage, Temporary, Failure) = False Then
        Exit Function
    End If
    Dim Budget As ByteKeyBudget
    Call ReadNativeKeyBudget(Budget, Inspection)
    Dim Code As Long = 5
    Dim Ordered As Boolean = False
    Dim NeverCancelled As Boolean = False
    If Cancellation Is Nothing Then
        Ordered = TryOrderByteKeysBudgeted(Bytes, State.Keys, State.PrimaryCount, State.KeyCapacity, State.Order, Code, Budget, NeverCancelled)
    Else
        Ordered = TryOrderByteKeysBudgeted(Bytes, State.Keys, State.PrimaryCount, State.KeyCapacity, State.Order, Code, Budget, Cancellation.Requested)
    End If
    Call FinishNativeKeyBudget(Inspection, Budget, Code, Failure)
    If Ordered Then
        State.OrderCapacity = State.PrimaryCount
        Temporary = Temporary \ 2
    End If
    If TryReleaseNativeInspectionStorage(Storage, Usage, Temporary, Cleanup) = False Then
        Failure = Cleanup
        Exit Function
    End If
    If Ordered = False Then
        Exit Function
    End If
    State.Status = 1
    Failure.Code = 0
    Failure.Resource = 0
    TryPrepareNativeSymbolInventory = True
End Function

Function TryDisposeNativeSymbolInventory(ByRef State As NativeSymbolInventory, ByRef Storage As NativeInspectionStorage, ByRef Usage As NativeUsage, ByRef Failure As NativeFailure) As Boolean
    TryDisposeNativeSymbolInventory = False
    Call ResetNativeFailure(Failure)
    If State.SymbolCapacity < 0 Or State.KeyCapacity < 0 Or State.OrderCapacity < 0 Then
        Exit Function
    End If
    If NativeInventorySymbolLength(State.Symbols) <> State.SymbolCapacity Or NativeInventoryKeyLength(State.Keys) <> State.KeyCapacity Or NativeInventoryOrderLength(State.Order) <> State.OrderCapacity Then
        Exit Function
    End If
    Dim Payload As LongLong = State.SymbolCapacity
    Payload = Payload * 40
    Dim KeyBytes As LongLong = State.KeyCapacity
    Payload = Payload + KeyBytes * 16
    Dim OrderBytes As LongLong = State.OrderCapacity
    Payload = Payload + OrderBytes * 4
    If Payload > Storage.Payload Or Payload > Usage.Payload Then
        Exit Function
    End If
    State.Status = 4
    Call ResetNativeFailure(Failure)
    If TryResizeNativeInventoryOrder(State.Order, 0, False) = False Then
        Exit Function
    End If
    If TryReleaseNativeInspectionStorage(Storage, Usage, OrderBytes * 4, Failure) = False Then
        Exit Function
    End If
    State.OrderCapacity = 0
    Call ResetNativeFailure(Failure)
    If TryResizeNativeInventoryKeys(State.Keys, 0, False) = False Then
        Exit Function
    End If
    If TryReleaseNativeInspectionStorage(Storage, Usage, KeyBytes * 16, Failure) = False Then
        Exit Function
    End If
    State.KeyCapacity = 0
    Payload = State.SymbolCapacity
    Call ResetNativeFailure(Failure)
    If TryResizeNativeInventorySymbols(State.Symbols, 0, False) = False Then
        Exit Function
    End If
    If TryReleaseNativeInspectionStorage(Storage, Usage, Payload * 40, Failure) = False Then
        Exit Function
    End If
    State.SymbolCapacity = 0
    State.PrimaryCount = 0
    State.Length = 0
    State.Status = 0
    Failure.Code = 0
    Failure.Resource = 0
    TryDisposeNativeSymbolInventory = True
End Function

Function TryReadNativeIndexedSymbol(ByRef State As NativeSymbolInventory, ByVal Index As Long, ByRef Inspection As NativeInspection, ByRef Result As NativeObjectSymbol, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryReadNativeIndexedSymbol = False
    Call ResetNativeFailure(Failure)
    If ValidNativeSymbolInventory(State) = False Then
        Exit Function
    End If
    Call ResetNativeFailure(Failure)
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Index < 0 Or Index >= State.SymbolCapacity Then
        Exit Function
    End If
    If State.Symbols(Index).NextIndex <= Index Or State.Symbols(Index).NextIndex > State.SymbolCapacity Then
        Exit Function
    End If
    Result = State.Symbols(Index)
    Failure.Code = 0
    TryReadNativeIndexedSymbol = True
End Function

Function TryFindNativeSymbolRange(ByRef State As NativeSymbolInventory, ByRef Bytes() As Byte, ByRef QueryBytes() As Byte, ByRef Name As NativeObjectName, ByRef Inspection As NativeInspection, ByRef First As Long, ByRef Count As Long, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryFindNativeSymbolRange = False
    Call ResetNativeFailure(Failure)
    If ValidNativeSymbolInventory(State) = False Or State.Length <> ByteStorageLength(Bytes) Then
        Exit Function
    End If
    Dim Budget As ByteKeyBudget
    Call ReadNativeKeyBudget(Budget, Inspection)
    Dim Code As Long = 5
    Dim Found As Boolean = False
    Dim NeverCancelled As Boolean = False
    If Cancellation Is Nothing Then
        Found = TryFindByteKeyRangeBudgeted(Bytes, QueryBytes, State.Keys, State.Order, 0, Name.First, Name.Count, First, Count, Code, Budget, NeverCancelled)
    Else
        Found = TryFindByteKeyRangeBudgeted(Bytes, QueryBytes, State.Keys, State.Order, 0, Name.First, Name.Count, First, Count, Code, Budget, Cancellation.Requested)
    End If
    Call FinishNativeKeyBudget(Inspection, Budget, Code, Failure)
    TryFindNativeSymbolRange = Found
End Function

Function TrySelectNativeDefinition(ByRef State As NativeSymbolInventory, ByRef Bytes() As Byte, ByRef QueryBytes() As Byte, ByRef Name As NativeObjectName, ByRef Inspection As NativeInspection, ByRef Result As NativeObjectSymbol, ByRef SymbolIndex As Long, ByRef Found As Boolean, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TrySelectNativeDefinition = False
    Dim First As Long = 0
    Dim Count As Long = 0
    Call ResetNativeFailure(Failure)
    If TryFindNativeSymbolRange(State, Bytes, QueryBytes, Name, Inspection, First, Count, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Prepared As NativeObjectSymbol
    Dim Selected As Long = -1
    Dim Position As Long = First
    While Position - First < Count
        Call ResetNativeFailure(Failure)
        If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim KeyIndex As Long = State.Order(Position)
        Call ResetNativeFailure(Failure)
        If KeyIndex < 0 Or KeyIndex >= State.PrimaryCount Then
            Exit Function
        End If
        Dim Index As Long = State.Keys(KeyIndex).Value
        Dim Symbol As NativeObjectSymbol
        Call ResetNativeFailure(Failure)
        If TryReadNativeIndexedSymbol(State, Index, Inspection, Symbol, Cancellation, Failure) = False Then
            Exit Function
        End If
        If Symbol.SectionNumber > 0 And (Symbol.StorageClass = 2 Or Symbol.StorageClass = 3) Then
            Failure.Code = 1506
            If Selected >= 0 Then
                Exit Function
            End If
            Selected = Index
            Prepared = Symbol
        End If
        Position = Position + 1
    Wend
    Found = Selected >= 0
    Result = Prepared
    SymbolIndex = Selected
    Failure.Code = 0
    TrySelectNativeDefinition = True
End Function

Function TryFindNativeDefinition(ByRef State As NativeSymbolInventory, ByRef Bytes() As Byte, ByRef QueryBytes() As Byte, ByRef Name As NativeObjectName, ByRef Inspection As NativeInspection, ByRef Result As NativeObjectSymbol, ByRef SymbolIndex As Long, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryFindNativeDefinition = False
    Dim Prepared As NativeObjectSymbol
    Dim Index As Long = -1
    Dim Found As Boolean = False
    If TrySelectNativeDefinition(State, Bytes, QueryBytes, Name, Inspection, Prepared, Index, Found, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Found = False Then
        Exit Function
    End If
    Result = Prepared
    SymbolIndex = Index
    Failure.Code = 0
    TryFindNativeDefinition = True
End Function

Function TryValidateNativeRelocationTargets(ByRef State As NativeSymbolInventory, ByRef Bytes() As Byte, ByRef Layout As NativeObjectLayout, ByRef Inspection As NativeInspection, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryValidateNativeRelocationTargets = False
    Call ResetNativeFailure(Failure)
    If ValidNativeSymbolInventory(State) = False Or State.SymbolCapacity <> Layout.SymbolCount Or State.Length <> Layout.Length Or Layout.Kind <> 1 Then
        Exit Function
    End If
    Dim SectionIndex As Long = 0
    While SectionIndex < Layout.SectionCount
        Dim Section As NativeObjectSection
        Call ResetNativeFailure(Failure)
        If TryReadNativeObjectSection(Bytes, Inspection, Layout, SectionIndex, Section, Cancellation, Failure) = False Then
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
                Dim Symbol As NativeObjectSymbol
                Call ResetNativeFailure(Failure)
                If TryReadNativeIndexedSymbol(State, Relocation.TargetIndex, Inspection, Symbol, Cancellation, Failure) = False Then
                    Exit Function
                End If
            End If
            Index = Index + 1
        Wend
        SectionIndex = SectionIndex + 1
    Wend
    Failure.Code = 0
    Failure.Resource = 0
    TryValidateNativeRelocationTargets = True
End Function
