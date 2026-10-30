UBE SOURCE 1 MODULE
Attribute UBE_Name = "ManagedModel"

' Target-independent precise managed metadata. All relationships are stable
' bounded indexes; target byte offsets and native pointers belong to the ABI
' and LLVM phases, never these records.

Type ManagedMetadata
    FormatVersion As Long
    LayoutCount As Long
    SlotCount As Long
    RootCount As Long
    SafePointCount As Long
    BarrierCount As Long
    PinCount As Long
    FinalizerCount As Long
    HasErrors As Long
End Type

Type ManagedLayout
    StableId As Long
    TypeIndex As Long
    FirstSlot As Long
    SlotCount As Long
    Flags As Long
End Type

Type ManagedSlot
    StableId As Long
    LayoutIndex As Long
    FieldSymbol As Long
    TypeIndex As Long
    FieldOrdinal As Long
    SlotKind As Long
    Flags As Long
End Type

Type ManagedRoot
    StableId As Long
    FunctionIndex As Long
    StorageIndex As Long
    TypeIndex As Long
    RootKind As Long
    Flags As Long
End Type

Type ManagedSafePoint
    StableId As Long
    FunctionIndex As Long
    BlockIndex As Long
    InstructionIndex As Long
    SafePointKind As Long
    Flags As Long
End Type

Type ManagedBarrier
    StableId As Long
    FunctionIndex As Long
    InstructionIndex As Long
    TargetStorage As Long
    StoredValue As Long
    BarrierKind As Long
    Flags As Long
End Type

Type ManagedPin
    StableId As Long
    FunctionIndex As Long
    InstructionIndex As Long
    ValueIndex As Long
    PinKind As Long
    Flags As Long
End Type

Type ManagedFinalizer
    StableId As Long
    TypeIndex As Long
    FunctionIndex As Long
    Flags As Long
End Type

Function ManagedSlotReference() As Long
    ManagedSlotReference = 1
End Function

Function ManagedSlotRecursiveValue() As Long
    ManagedSlotRecursiveValue = 2
End Function

Function ManagedSlotVariantPayload() As Long
    ManagedSlotVariantPayload = 3
End Function

Function ManagedRootGlobal() As Long
    ManagedRootGlobal = 1
End Function

Function ManagedRootStatic() As Long
    ManagedRootStatic = 2
End Function

Function ManagedRootLocal() As Long
    ManagedRootLocal = 3
End Function

Function ManagedRootParameter() As Long
    ManagedRootParameter = 4
End Function

Function ManagedRootResult() As Long
    ManagedRootResult = 5
End Function

Function ManagedRootTemporary() As Long
    ManagedRootTemporary = 6
End Function

Function ManagedSafePointAllocation() As Long
    ManagedSafePointAllocation = 1
End Function

Function ManagedSafePointCall() As Long
    ManagedSafePointCall = 2
End Function

Function ManagedSafePointLoopBackedge() As Long
    ManagedSafePointLoopBackedge = 3
End Function

Function ManagedSafePointCollection() As Long
    ManagedSafePointCollection = 4
End Function

Function ManagedSafePointForeignTransition() As Long
    ManagedSafePointForeignTransition = 5
End Function

Function ManagedBarrierReferenceStore() As Long
    ManagedBarrierReferenceStore = 1
End Function

Function ManagedBarrierRangeCopy() As Long
    ManagedBarrierRangeCopy = 2
End Function

Function NextManagedCapacity(ByVal CurrentCapacity As Long) As Long
    Dim Result As Long = 64
    If CurrentCapacity > 0 Then
        Result = CurrentCapacity * 2
    End If
    If Result > LimitIrRecords() Then
        Result = LimitIrRecords()
    End If
    NextManagedCapacity = Result
End Function

Function AppendManagedLayout(ByRef Items() As ManagedLayout, ByRef Count As Long, ByRef Capacity As Long, ByVal TypeIndex As Long, ByVal FirstSlot As Long, ByVal Flags As Long) As Long
    If Count >= LimitIrRecords() Then
        AppendManagedLayout = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = NextManagedCapacity(Capacity)
        If Capacity = 0 Then
            ReDim Items(NewCapacity - 1)
        Else
            ReDim Preserve Items(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Dim Result As Long = Count
    Items(Result).StableId = Result + 1
    Items(Result).TypeIndex = TypeIndex
    Items(Result).FirstSlot = FirstSlot
    Items(Result).SlotCount = 0
    Items(Result).Flags = Flags
    Count = Count + 1
    AppendManagedLayout = Result
End Function

Function AppendManagedSlot(ByRef Items() As ManagedSlot, ByRef Count As Long, ByRef Capacity As Long, ByVal LayoutIndex As Long, ByVal FieldSymbol As Long, ByVal TypeIndex As Long, ByVal FieldOrdinal As Long, ByVal SlotKind As Long, ByVal Flags As Long) As Long
    If Count >= LimitIrRecords() Then
        AppendManagedSlot = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = NextManagedCapacity(Capacity)
        If Capacity = 0 Then
            ReDim Items(NewCapacity - 1)
        Else
            ReDim Preserve Items(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Dim Result As Long = Count
    Items(Result).StableId = Result + 1
    Items(Result).LayoutIndex = LayoutIndex
    Items(Result).FieldSymbol = FieldSymbol
    Items(Result).TypeIndex = TypeIndex
    Items(Result).FieldOrdinal = FieldOrdinal
    Items(Result).SlotKind = SlotKind
    Items(Result).Flags = Flags
    Count = Count + 1
    AppendManagedSlot = Result
End Function

Function AppendManagedRoot(ByRef Items() As ManagedRoot, ByRef Count As Long, ByRef Capacity As Long, ByVal FunctionIndex As Long, ByVal StorageIndex As Long, ByVal TypeIndex As Long, ByVal RootKind As Long, ByVal Flags As Long) As Long
    If Count >= LimitIrRecords() Then
        AppendManagedRoot = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = NextManagedCapacity(Capacity)
        If Capacity = 0 Then
            ReDim Items(NewCapacity - 1)
        Else
            ReDim Preserve Items(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Dim Result As Long = Count
    Items(Result).StableId = Result + 1
    Items(Result).FunctionIndex = FunctionIndex
    Items(Result).StorageIndex = StorageIndex
    Items(Result).TypeIndex = TypeIndex
    Items(Result).RootKind = RootKind
    Items(Result).Flags = Flags
    Count = Count + 1
    AppendManagedRoot = Result
End Function

Function AppendManagedSafePoint(ByRef Items() As ManagedSafePoint, ByRef Count As Long, ByRef Capacity As Long, ByVal FunctionIndex As Long, ByVal BlockIndex As Long, ByVal InstructionIndex As Long, ByVal SafePointKind As Long, ByVal Flags As Long) As Long
    If Count >= LimitIrRecords() Then
        AppendManagedSafePoint = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = NextManagedCapacity(Capacity)
        If Capacity = 0 Then
            ReDim Items(NewCapacity - 1)
        Else
            ReDim Preserve Items(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Dim Result As Long = Count
    Items(Result).StableId = Result + 1
    Items(Result).FunctionIndex = FunctionIndex
    Items(Result).BlockIndex = BlockIndex
    Items(Result).InstructionIndex = InstructionIndex
    Items(Result).SafePointKind = SafePointKind
    Items(Result).Flags = Flags
    Count = Count + 1
    AppendManagedSafePoint = Result
End Function

Function AppendManagedBarrier(ByRef Items() As ManagedBarrier, ByRef Count As Long, ByRef Capacity As Long, ByVal FunctionIndex As Long, ByVal InstructionIndex As Long, ByVal TargetStorage As Long, ByVal StoredValue As Long, ByVal BarrierKind As Long, ByVal Flags As Long) As Long
    If Count >= LimitIrRecords() Then
        AppendManagedBarrier = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = NextManagedCapacity(Capacity)
        If Capacity = 0 Then
            ReDim Items(NewCapacity - 1)
        Else
            ReDim Preserve Items(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Dim Result As Long = Count
    Items(Result).StableId = Result + 1
    Items(Result).FunctionIndex = FunctionIndex
    Items(Result).InstructionIndex = InstructionIndex
    Items(Result).TargetStorage = TargetStorage
    Items(Result).StoredValue = StoredValue
    Items(Result).BarrierKind = BarrierKind
    Items(Result).Flags = Flags
    Count = Count + 1
    AppendManagedBarrier = Result
End Function

Function AppendManagedPin(ByRef Items() As ManagedPin, ByRef Count As Long, ByRef Capacity As Long, ByVal FunctionIndex As Long, ByVal InstructionIndex As Long, ByVal ValueIndex As Long, ByVal PinKind As Long, ByVal Flags As Long) As Long
    If Count >= LimitIrRecords() Then
        AppendManagedPin = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = NextManagedCapacity(Capacity)
        If Capacity = 0 Then
            ReDim Items(NewCapacity - 1)
        Else
            ReDim Preserve Items(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Dim Result As Long = Count
    Items(Result).StableId = Result + 1
    Items(Result).FunctionIndex = FunctionIndex
    Items(Result).InstructionIndex = InstructionIndex
    Items(Result).ValueIndex = ValueIndex
    Items(Result).PinKind = PinKind
    Items(Result).Flags = Flags
    Count = Count + 1
    AppendManagedPin = Result
End Function

Function AppendManagedFinalizer(ByRef Items() As ManagedFinalizer, ByRef Count As Long, ByRef Capacity As Long, ByVal TypeIndex As Long, ByVal FunctionIndex As Long, ByVal Flags As Long) As Long
    If Count >= LimitIrRecords() Then
        AppendManagedFinalizer = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = NextManagedCapacity(Capacity)
        If Capacity = 0 Then
            ReDim Items(NewCapacity - 1)
        Else
            ReDim Preserve Items(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Dim Result As Long = Count
    Items(Result).StableId = Result + 1
    Items(Result).TypeIndex = TypeIndex
    Items(Result).FunctionIndex = FunctionIndex
    Items(Result).Flags = Flags
    Count = Count + 1
    AppendManagedFinalizer = Result
End Function
