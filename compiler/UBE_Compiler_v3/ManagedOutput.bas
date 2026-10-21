UBE SOURCE 1 MODULE
Attribute UBE_Name = "ManagedOutput"

Sub WriteManagedDump(ByRef Metadata As ManagedMetadata, ByRef Layouts() As ManagedLayout, ByRef Slots() As ManagedSlot, ByRef Roots() As ManagedRoot, ByRef SafePoints() As ManagedSafePoint, ByRef Barriers() As ManagedBarrier, ByRef Pins() As ManagedPin, ByRef Finalizers() As ManagedFinalizer)
    Print "UBE-MANAGED 1"
    Dim Index As Long = 0
    While Index < Metadata.LayoutCount
        Print "layout|" & LongToString(Layouts(Index).StableId) & "|" & LongToString(Layouts(Index).TypeIndex) & "|" & LongToString(Layouts(Index).FirstSlot) & "|" & LongToString(Layouts(Index).SlotCount) & "|" & LongToString(Layouts(Index).Flags)
        Index = Index + 1
    Wend
    Index = 0
    While Index < Metadata.SlotCount
        Print "slot|" & LongToString(Slots(Index).StableId) & "|" & LongToString(Slots(Index).LayoutIndex) & "|" & LongToString(Slots(Index).FieldSymbol) & "|" & LongToString(Slots(Index).TypeIndex) & "|" & LongToString(Slots(Index).FieldOrdinal) & "|" & LongToString(Slots(Index).SlotKind) & "|" & LongToString(Slots(Index).Flags)
        Index = Index + 1
    Wend
    Index = 0
    While Index < Metadata.RootCount
        Print "root|" & LongToString(Roots(Index).StableId) & "|" & LongToString(Roots(Index).FunctionIndex) & "|" & LongToString(Roots(Index).StorageIndex) & "|" & LongToString(Roots(Index).TypeIndex) & "|" & LongToString(Roots(Index).RootKind) & "|" & LongToString(Roots(Index).Flags)
        Index = Index + 1
    Wend
    Index = 0
    While Index < Metadata.SafePointCount
        Print "safe|" & LongToString(SafePoints(Index).StableId) & "|" & LongToString(SafePoints(Index).FunctionIndex) & "|" & LongToString(SafePoints(Index).BlockIndex) & "|" & LongToString(SafePoints(Index).InstructionIndex) & "|" & LongToString(SafePoints(Index).SafePointKind) & "|" & LongToString(SafePoints(Index).Flags)
        Index = Index + 1
    Wend
    Index = 0
    While Index < Metadata.BarrierCount
        Print "barrier|" & LongToString(Barriers(Index).StableId) & "|" & LongToString(Barriers(Index).FunctionIndex) & "|" & LongToString(Barriers(Index).InstructionIndex) & "|" & LongToString(Barriers(Index).TargetStorage) & "|" & LongToString(Barriers(Index).StoredValue) & "|" & LongToString(Barriers(Index).BarrierKind) & "|" & LongToString(Barriers(Index).Flags)
        Index = Index + 1
    Wend
    Index = 0
    While Index < Metadata.PinCount
        Print "pin|" & LongToString(Pins(Index).StableId) & "|" & LongToString(Pins(Index).FunctionIndex) & "|" & LongToString(Pins(Index).InstructionIndex) & "|" & LongToString(Pins(Index).ValueIndex) & "|" & LongToString(Pins(Index).PinKind) & "|" & LongToString(Pins(Index).Flags)
        Index = Index + 1
    Wend
    Index = 0
    While Index < Metadata.FinalizerCount
        Print "finalizer|" & LongToString(Finalizers(Index).StableId) & "|" & LongToString(Finalizers(Index).TypeIndex) & "|" & LongToString(Finalizers(Index).FunctionIndex) & "|" & LongToString(Finalizers(Index).Flags)
        Index = Index + 1
    Wend
    Print "summary|" & LongToString(Metadata.LayoutCount) & "|" & LongToString(Metadata.SlotCount) & "|" & LongToString(Metadata.RootCount) & "|" & LongToString(Metadata.SafePointCount) & "|" & LongToString(Metadata.BarrierCount) & "|" & LongToString(Metadata.PinCount) & "|" & LongToString(Metadata.FinalizerCount)
End Sub
