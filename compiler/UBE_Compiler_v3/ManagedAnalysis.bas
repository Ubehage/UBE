UBE SOURCE 1 MODULE
Attribute UBE_Name = "ManagedAnalysis"

Function ManagedTypeIsDirect(ByVal TypeIndex As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long) As Long
    If TypeIndex < 0 Or TypeIndex >= TypeCount Then
        ManagedTypeIsDirect = 0
        Exit Function
    End If
    Dim Kind As Long = Types(TypeIndex).TypeKind
    If Kind = 11 Or Kind = 12 Or Kind = 13 Or Kind = 30 Or Kind = 40 Or Kind = 41 Or (Kind >= 50 And Kind <= 52) Then
        ManagedTypeIsDirect = 1
    Else
        ManagedTypeIsDirect = 0
    End If
End Function

Function BuildManagedTypeFlags(ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef ManagedFlags() As Long) As Long
    If TypeCount <= 0 Then
        BuildManagedTypeFlags = 0
        Exit Function
    End If
    ReDim ManagedFlags(TypeCount - 1)
    Dim TypeIndex As Long = 0
    While TypeIndex < TypeCount
        ManagedFlags(TypeIndex) = ManagedTypeIsDirect(TypeIndex, Types, TypeCount)
        TypeIndex = TypeIndex + 1
    Wend

    ' A self field is a lazy managed edge even when it is the only managed
    ' field in the record. Seed those edges before the transitive fixed point.
    TypeIndex = 0
    While TypeIndex < TypeCount
        If Types(TypeIndex).TypeSymbol >= 0 Then
            Dim SeedSymbol As Long = 0
            While SeedSymbol < SymbolCount
                If Symbols(SeedSymbol).ParentSymbol = Types(TypeIndex).TypeSymbol And Symbols(SeedSymbol).SymbolKind = SemanticSymbolMember() Then
                    If Symbols(SeedSymbol).DeclaredType = TypeIndex Then
                        ManagedFlags(TypeIndex) = 1
                    End If
                End If
                SeedSymbol = SeedSymbol + 1
            Wend
        End If
        TypeIndex = TypeIndex + 1
    Wend

    Dim PassIndex As Long = 0
    While PassIndex < TypeCount
        Dim Changed As Long = 0
        TypeIndex = 0
        While TypeIndex < TypeCount
            If ManagedFlags(TypeIndex) = 0 And Types(TypeIndex).TypeSymbol >= 0 Then
                Dim SymbolIndex As Long = 0
                While SymbolIndex < SymbolCount
                    If Symbols(SymbolIndex).ParentSymbol = Types(TypeIndex).TypeSymbol And Symbols(SymbolIndex).SymbolKind = SemanticSymbolMember() Then
                        Dim FieldType As Long = Symbols(SymbolIndex).DeclaredType
                        If FieldType >= 0 And FieldType < TypeCount Then
                            If ManagedFlags(FieldType) <> 0 Then
                                ManagedFlags(TypeIndex) = 1
                                Changed = 1
                                Exit While
                            End If
                        End If
                    End If
                    SymbolIndex = SymbolIndex + 1
                Wend
            End If
            TypeIndex = TypeIndex + 1
        Wend
        If Changed = 0 Then
            Exit While
        End If
        PassIndex = PassIndex + 1
    Wend
    BuildManagedTypeFlags = 1
End Function

Function ManagedRootKindForStorage(ByVal StorageKind As Long) As Long
    If StorageKind = IrStorageGlobal() Then
        ManagedRootKindForStorage = ManagedRootGlobal()
        Exit Function
    End If
    If StorageKind = IrStorageStatic() Then
        ManagedRootKindForStorage = ManagedRootStatic()
        Exit Function
    End If
    If StorageKind = IrStorageParameter() Then
        ManagedRootKindForStorage = ManagedRootParameter()
        Exit Function
    End If
    If StorageKind = IrStorageResult() Then
        ManagedRootKindForStorage = ManagedRootResult()
        Exit Function
    End If
    If StorageKind = IrStorageTemporary() Then
        ManagedRootKindForStorage = ManagedRootTemporary()
        Exit Function
    End If
    ManagedRootKindForStorage = ManagedRootLocal()
End Function

Function BuildManagedMetadata(ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Functions() As IrFunction, ByVal FunctionCount As Long, ByRef Storages() As IrStorage, ByVal StorageCount As Long, ByRef Blocks() As IrBlock, ByVal BlockCount As Long, ByRef Instructions() As IrInstruction, ByVal InstructionCount As Long, ByRef Operands() As IrOperand, ByVal OperandCount As Long, ByRef Values() As IrValue, ByVal ValueCount As Long, ByRef Edges() As IrEdge, ByVal EdgeCount As Long, ByRef Metadata As ManagedMetadata, ByRef Layouts() As ManagedLayout, ByRef Slots() As ManagedSlot, ByRef Roots() As ManagedRoot, ByRef SafePoints() As ManagedSafePoint, ByRef Barriers() As ManagedBarrier, ByRef Pins() As ManagedPin, ByRef Finalizers() As ManagedFinalizer) As Long
    Metadata.FormatVersion = 1
    Metadata.LayoutCount = 0
    Metadata.SlotCount = 0
    Metadata.RootCount = 0
    Metadata.SafePointCount = 0
    Metadata.BarrierCount = 0
    Metadata.PinCount = 0
    Metadata.FinalizerCount = 0
    Metadata.HasErrors = 0
    Dim LayoutCapacity As Long = 0
    Dim SlotCapacity As Long = 0
    Dim RootCapacity As Long = 0
    Dim SafePointCapacity As Long = 0
    Dim BarrierCapacity As Long = 0
    Dim PinCapacity As Long = 0
    Dim FinalizerCapacity As Long = 0
    Dim ManagedFlags() As Long
    If BuildManagedTypeFlags(Types, TypeCount, Symbols, SymbolCount, ManagedFlags) = 0 Then
        Metadata.HasErrors = 1
        BuildManagedMetadata = 0
        Exit Function
    End If

    Dim TypeIndex As Long = 0
    While TypeIndex < TypeCount
        If ManagedFlags(TypeIndex) <> 0 Then
            Dim LayoutIndex As Long = AppendManagedLayout(Layouts, Metadata.LayoutCount, LayoutCapacity, TypeIndex, Metadata.SlotCount, 0)
            If LayoutIndex < 0 Then
                Metadata.HasErrors = 1
                BuildManagedMetadata = 0
                Exit Function
            End If
            Dim FieldOrdinal As Long = 0
            Dim SymbolIndex As Long = 0
            While SymbolIndex < SymbolCount
                If Symbols(SymbolIndex).ParentSymbol = Types(TypeIndex).TypeSymbol And Symbols(SymbolIndex).SymbolKind = SemanticSymbolMember() Then
                    Dim FieldType As Long = Symbols(SymbolIndex).DeclaredType
                    If FieldType >= 0 And FieldType < TypeCount Then
                        If ManagedFlags(FieldType) <> 0 Then
                            Dim SlotKind As Long = ManagedSlotReference()
                            If FieldType = TypeIndex Then
                                SlotKind = ManagedSlotRecursiveValue()
                            Else
                                If Types(FieldType).TypeKind = 13 Then
                                    SlotKind = ManagedSlotVariantPayload()
                                End If
                            End If
                            If AppendManagedSlot(Slots, Metadata.SlotCount, SlotCapacity, LayoutIndex, SymbolIndex, FieldType, FieldOrdinal, SlotKind, 0) < 0 Then
                                Metadata.HasErrors = 1
                                BuildManagedMetadata = 0
                                Exit Function
                            End If
                            Layouts(LayoutIndex).SlotCount = Layouts(LayoutIndex).SlotCount + 1
                        End If
                    End If
                    FieldOrdinal = FieldOrdinal + 1
                End If
                SymbolIndex = SymbolIndex + 1
            Wend
        End If
        TypeIndex = TypeIndex + 1
    Wend

    ' Object finalizers are part of the target-independent metadata too.  The
    ' LLVM object layout consumes the same class/function relationship later;
    ' recording it here lets verification reject stale or malformed pairs.
    TypeIndex = 0
    While TypeIndex < TypeCount
        If Types(TypeIndex).TypeKind >= 50 And Types(TypeIndex).TypeKind <= 52 Then
            Dim FinalizerFunction As Long = 0
            While FinalizerFunction < FunctionCount
                Dim FinalizerSymbol As Long = Functions(FinalizerFunction).SymbolIndex
                If FinalizerSymbol >= 0 Then
                    If Symbols(FinalizerSymbol).ParentSymbol = Types(TypeIndex).TypeSymbol Then
                        If EqualsFolded(Symbols(FinalizerSymbol).SymbolName, "Class_Terminate") <> 0 Then
                            If AppendManagedFinalizer(Finalizers, Metadata.FinalizerCount, FinalizerCapacity, TypeIndex, FinalizerFunction, 0) < 0 Then
                                Metadata.HasErrors = 1
                                BuildManagedMetadata = 0
                                Exit Function
                            End If
                        End If
                    End If
                End If
                FinalizerFunction = FinalizerFunction + 1
            Wend
        End If
        TypeIndex = TypeIndex + 1
    Wend

    Dim StorageIndex As Long = 0
    While StorageIndex < StorageCount
        Dim StorageType As Long = Storages(StorageIndex).TypeIndex
        If StorageType >= 0 And StorageType < TypeCount Then
            If ManagedFlags(StorageType) <> 0 Then
                Dim RootKind As Long = ManagedRootKindForStorage(Storages(StorageIndex).StorageKind)
                If AppendManagedRoot(Roots, Metadata.RootCount, RootCapacity, Storages(StorageIndex).FunctionIndex, StorageIndex, StorageType, RootKind, 0) < 0 Then
                    Metadata.HasErrors = 1
                    BuildManagedMetadata = 0
                    Exit Function
                End If
            End If
        End If
        StorageIndex = StorageIndex + 1
    Wend

    ' SSA results are live across later safe points even when they have not
    ' yet been assigned to source-visible storage. Encode their spill identity
    ' as -(value + 1); storage indexes remain nonnegative.
    Dim ValueIndex As Long = 0
    While ValueIndex < ValueCount
        Dim ValueType As Long = Values(ValueIndex).TypeIndex
        If ValueType >= 0 And ValueType < TypeCount Then
            Dim ValueKind As Long = Types(ValueType).TypeKind
            If ValueKind = 11 Or ValueKind = 12 Or ValueKind = 13 Or ValueKind = 30 Or ValueKind = 41 Or (ValueKind >= 50 And ValueKind <= 52) Then
                If AppendManagedRoot(Roots, Metadata.RootCount, RootCapacity, Values(ValueIndex).FunctionIndex, -ValueIndex - 1, ValueType, ManagedRootTemporary(), 0) < 0 Then
                    Metadata.HasErrors = 1
                    BuildManagedMetadata = 0
                    Exit Function
                End If
            End If
        End If
        ValueIndex = ValueIndex + 1
    Wend

    Dim InstructionIndex As Long = 0
    While InstructionIndex < InstructionCount
        Dim Opcode As Long = Instructions(InstructionIndex).Opcode
        Dim SafePointKind As Long = 0
        If Opcode = IrOpArrayResize() Or Opcode = IrOpConcatenate() Then
            SafePointKind = ManagedSafePointAllocation()
        Else
            If Opcode = IrOpCall() Then
                SafePointKind = ManagedSafePointCall()
            End If
        End If
        If SafePointKind <> 0 Then
            If AppendManagedSafePoint(SafePoints, Metadata.SafePointCount, SafePointCapacity, Instructions(InstructionIndex).FunctionIndex, Instructions(InstructionIndex).BlockIndex, InstructionIndex, SafePointKind, 0) < 0 Then
                Metadata.HasErrors = 1
                BuildManagedMetadata = 0
                Exit Function
            End If
        End If
        If Opcode = IrOpStore() And Instructions(InstructionIndex).OperandCount = 2 Then
            Dim FirstOperand As Long = Instructions(InstructionIndex).FirstOperand
            Dim SecondOperand As Long = FirstOperand + 1
            If FirstOperand >= 0 And SecondOperand < OperandCount Then
                If Operands(SecondOperand).OperandKind = IrOperandValue() Then
                    Dim StoredValue As Long = Operands(SecondOperand).ReferencedIndex
                    If StoredValue >= 0 And StoredValue < ValueCount Then
                        Dim StoredType As Long = Values(StoredValue).TypeIndex
                        If StoredType >= 0 And StoredType < TypeCount Then
                            If ManagedFlags(StoredType) <> 0 Then
                                Dim TargetStorage As Long = -1
                                If Operands(FirstOperand).OperandKind = IrOperandStorage() Then
                                    TargetStorage = Operands(FirstOperand).ReferencedIndex
                                End If
                                If AppendManagedBarrier(Barriers, Metadata.BarrierCount, BarrierCapacity, Instructions(InstructionIndex).FunctionIndex, InstructionIndex, TargetStorage, StoredValue, ManagedBarrierReferenceStore(), 0) < 0 Then
                                    Metadata.HasErrors = 1
                                    BuildManagedMetadata = 0
                                    Exit Function
                                End If
                            End If
                        End If
                    End If
                End If
            End If
        End If
        InstructionIndex = InstructionIndex + 1
    Wend

    Dim EdgeIndex As Long = 0
    While EdgeIndex < EdgeCount
        If Edges(EdgeIndex).ToBlock <= Edges(EdgeIndex).FromBlock Then
            Dim FromBlock As Long = Edges(EdgeIndex).FromBlock
            If FromBlock >= 0 And FromBlock < BlockCount Then
                Dim BackedgeInstruction As Long = Blocks(FromBlock).FirstInstruction + Blocks(FromBlock).InstructionCount - 1
                If BackedgeInstruction >= 0 And BackedgeInstruction < InstructionCount Then
                    If AppendManagedSafePoint(SafePoints, Metadata.SafePointCount, SafePointCapacity, Edges(EdgeIndex).FunctionIndex, FromBlock, BackedgeInstruction, ManagedSafePointLoopBackedge(), 0) < 0 Then
                        Metadata.HasErrors = 1
                        BuildManagedMetadata = 0
                        Exit Function
                    End If
                End If
            End If
        End If
        EdgeIndex = EdgeIndex + 1
    Wend
    BuildManagedMetadata = 1
End Function

Function ManagedLayoutForType(ByVal TypeIndex As Long, ByRef Metadata As ManagedMetadata, ByRef Layouts() As ManagedLayout) As Long
    Dim Index As Long = 0
    While Index < Metadata.LayoutCount
        If Layouts(Index).TypeIndex = TypeIndex Then
            ManagedLayoutForType = Index
            Exit Function
        End If
        Index = Index + 1
    Wend
    ManagedLayoutForType = -1
End Function

Function VerifyManagedMetadata(ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Functions() As IrFunction, ByVal FunctionCount As Long, ByRef Storages() As IrStorage, ByVal StorageCount As Long, ByRef Blocks() As IrBlock, ByVal BlockCount As Long, ByRef Instructions() As IrInstruction, ByVal InstructionCount As Long, ByRef Operands() As IrOperand, ByVal OperandCount As Long, ByRef Values() As IrValue, ByVal ValueCount As Long, ByRef Metadata As ManagedMetadata, ByRef Layouts() As ManagedLayout, ByRef Slots() As ManagedSlot, ByRef Roots() As ManagedRoot, ByRef SafePoints() As ManagedSafePoint, ByRef Barriers() As ManagedBarrier, ByRef Pins() As ManagedPin, ByRef Finalizers() As ManagedFinalizer, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim Valid As Long = 1
    If Metadata.FormatVersion <> 1 Or Metadata.HasErrors <> 0 Then
        Call AddIrDiagnostic("UBE5200", "managed metadata has an invalid format or failed build state", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        Valid = 0
    End If
    Dim LayoutIndex As Long = 0
    While LayoutIndex < Metadata.LayoutCount
        If Layouts(LayoutIndex).StableId <> LayoutIndex + 1 Or Layouts(LayoutIndex).TypeIndex < 0 Or Layouts(LayoutIndex).TypeIndex >= TypeCount Then
            Call AddIrDiagnostic("UBE5201", "managed layout has an invalid identity or type", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        End If
        If Layouts(LayoutIndex).FirstSlot < 0 Or Layouts(LayoutIndex).SlotCount < 0 Or Layouts(LayoutIndex).FirstSlot + Layouts(LayoutIndex).SlotCount > Metadata.SlotCount Then
            Call AddIrDiagnostic("UBE5201", "managed layout has an invalid slot range", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        End If
        Dim SlotIndex As Long = Layouts(LayoutIndex).FirstSlot
        While SlotIndex < Layouts(LayoutIndex).FirstSlot + Layouts(LayoutIndex).SlotCount
            If Slots(SlotIndex).LayoutIndex <> LayoutIndex Or Slots(SlotIndex).TypeIndex < 0 Or Slots(SlotIndex).TypeIndex >= TypeCount Then
                Call AddIrDiagnostic("UBE5202", "managed slot does not belong to its layout or type", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            End If
            If Slots(SlotIndex).SlotKind < ManagedSlotReference() Or Slots(SlotIndex).SlotKind > ManagedSlotVariantPayload() Then
                Call AddIrDiagnostic("UBE5202", "managed slot kind is invalid", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            End If
            SlotIndex = SlotIndex + 1
        Wend
        LayoutIndex = LayoutIndex + 1
    Wend

    Dim RootIndex As Long = 0
    While RootIndex < Metadata.RootCount
        Dim RootStorage As Long = Roots(RootIndex).StorageIndex
        If Roots(RootIndex).StableId <> RootIndex + 1 Then
            Call AddIrDiagnostic("UBE5203", "managed root has an invalid identity or storage", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        Else
            If RootStorage >= 0 Then
                If RootStorage >= StorageCount Then
                    Call AddIrDiagnostic("UBE5203", "managed root storage is outside the IR", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    Valid = 0
                Else
                    If Roots(RootIndex).TypeIndex <> Storages(RootStorage).TypeIndex Or Roots(RootIndex).FunctionIndex <> Storages(RootStorage).FunctionIndex Then
                        Call AddIrDiagnostic("UBE5203", "managed root type or owner differs from its storage", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        Valid = 0
                    End If
                End If
            Else
                Dim RootValue As Long = -RootStorage - 1
                If Roots(RootIndex).RootKind <> ManagedRootTemporary() Or RootValue < 0 Or RootValue >= ValueCount Then
                    Call AddIrDiagnostic("UBE5203", "managed temporary root has an invalid value", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    Valid = 0
                Else
                    If Roots(RootIndex).TypeIndex <> Values(RootValue).TypeIndex Or Roots(RootIndex).FunctionIndex <> Values(RootValue).FunctionIndex Then
                        Call AddIrDiagnostic("UBE5203", "managed temporary root type or owner differs from its value", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        Valid = 0
                    End If
                End If
            End If
        End If
        RootIndex = RootIndex + 1
    Wend

    Dim SafePointIndex As Long = 0
    While SafePointIndex < Metadata.SafePointCount
        Dim SafeInstruction As Long = SafePoints(SafePointIndex).InstructionIndex
        If SafeInstruction < 0 Or SafeInstruction >= InstructionCount Or SafePoints(SafePointIndex).FunctionIndex < 0 Or SafePoints(SafePointIndex).FunctionIndex >= FunctionCount Or SafePoints(SafePointIndex).BlockIndex < 0 Or SafePoints(SafePointIndex).BlockIndex >= BlockCount Then
            Call AddIrDiagnostic("UBE5204", "managed safe point has an invalid owner or instruction", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        Else
            If Instructions(SafeInstruction).FunctionIndex <> SafePoints(SafePointIndex).FunctionIndex Or Instructions(SafeInstruction).BlockIndex <> SafePoints(SafePointIndex).BlockIndex Then
                Call AddIrDiagnostic("UBE5204", "managed safe point owner differs from its instruction", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            End If
        End If
        SafePointIndex = SafePointIndex + 1
    Wend

    Dim BarrierIndex As Long = 0
    While BarrierIndex < Metadata.BarrierCount
        Dim BarrierInstruction As Long = Barriers(BarrierIndex).InstructionIndex
        If BarrierInstruction < 0 Or BarrierInstruction >= InstructionCount Or Instructions(BarrierInstruction).Opcode <> IrOpStore() Then
            Call AddIrDiagnostic("UBE5205", "managed barrier does not reference a store instruction", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        End If
        If Barriers(BarrierIndex).StoredValue < 0 Or Barriers(BarrierIndex).StoredValue >= ValueCount Then
            Call AddIrDiagnostic("UBE5205", "managed barrier has an invalid stored value", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        End If
        BarrierIndex = BarrierIndex + 1
    Wend

    Dim InstructionIndex As Long = 0
    While InstructionIndex < InstructionCount
        If Instructions(InstructionIndex).Opcode = IrOpStore() Then
            Dim FoundBarrier As Long = 0
            BarrierIndex = 0
            While BarrierIndex < Metadata.BarrierCount
                If Barriers(BarrierIndex).InstructionIndex = InstructionIndex Then
                    FoundBarrier = 1
                    Exit While
                End If
                BarrierIndex = BarrierIndex + 1
            Wend
            If Instructions(InstructionIndex).OperandCount = 2 Then
                Dim ValueOperand As Long = Instructions(InstructionIndex).FirstOperand + 1
                If ValueOperand >= 0 And ValueOperand < OperandCount Then
                    If Operands(ValueOperand).OperandKind = IrOperandValue() Then
                        Dim StoreValue As Long = Operands(ValueOperand).ReferencedIndex
                        If StoreValue >= 0 And StoreValue < ValueCount Then
                            If ManagedLayoutForType(Values(StoreValue).TypeIndex, Metadata, Layouts) >= 0 And FoundBarrier = 0 Then
                                Call AddIrDiagnostic("UBE5205", "managed store has no write-barrier metadata", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                Valid = 0
                            End If
                        End If
                    End If
                End If
            End If
            ' Metadata construction identifies managed stores. A barrier record
            ' may not refer to any other opcode; later lowering adds the native
            ' call at exactly these verified sites.
            If FoundBarrier <> 0 Then
                If Instructions(InstructionIndex).FunctionIndex <> Barriers(BarrierIndex).FunctionIndex Then
                    Call AddIrDiagnostic("UBE5205", "managed barrier owner differs from its store", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    Valid = 0
                End If
            End If
        End If
        InstructionIndex = InstructionIndex + 1
    Wend

    If Metadata.PinCount <> 0 Or Metadata.FinalizerCount <> 0 Then
        Dim PinIndex As Long = 0
        While PinIndex < Metadata.PinCount
            If Pins(PinIndex).ValueIndex < 0 Or Pins(PinIndex).ValueIndex >= ValueCount Then
                Call AddIrDiagnostic("UBE5206", "managed pin has an invalid value", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            End If
            PinIndex = PinIndex + 1
        Wend
        Dim FinalizerIndex As Long = 0
        While FinalizerIndex < Metadata.FinalizerCount
            If Finalizers(FinalizerIndex).TypeIndex < 0 Or Finalizers(FinalizerIndex).TypeIndex >= TypeCount Or Finalizers(FinalizerIndex).FunctionIndex < 0 Or Finalizers(FinalizerIndex).FunctionIndex >= FunctionCount Then
                Call AddIrDiagnostic("UBE5207", "managed finalizer has an invalid type or function", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            End If
            FinalizerIndex = FinalizerIndex + 1
        Wend
    End If
    VerifyManagedMetadata = Valid
End Function
