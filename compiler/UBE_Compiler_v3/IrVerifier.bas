UBE SOURCE 1 MODULE
Attribute UBE_Name = "IrVerifier"

Sub AddIrDiagnostic(ByVal Code As String, ByVal Message As String, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long)
    Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Code, "<ir>", 1, 1, Message)
End Sub

Function IrOpcodeIsTerminator(ByVal Opcode As Long) As Long
    If Opcode = IrOpBranch() Or Opcode = IrOpConditionalBranch() Or Opcode = IrOpReturn() Or Opcode = IrOpErrorDispatch() Or Opcode = IrOpResume() Then
        IrOpcodeIsTerminator = 1
    Else
        IrOpcodeIsTerminator = 0
    End If
End Function

Function IrOpcodeMayFail(ByVal Opcode As Long) As Long
    If Opcode = IrOpCheckedAdd() Or Opcode = IrOpCheckedSubtract() Or Opcode = IrOpCheckedMultiply() Or Opcode = IrOpCheckedNegate() Or Opcode = IrOpCheckedDivide() Or Opcode = IrOpCheckedRemainder() Then
        IrOpcodeMayFail = 1
        Exit Function
    End If
    ' RP5 represents checked arithmetic and checked numeric conversion as
    ' recoverable IR error edges. Allocation, strings, arrays, and callees use
    ' the bootstrap substrate's controlled terminal-failure ABI until RP7 adds
    ' the full resumable runtime-error model.
    If Opcode = IrOpConvert() Then
        IrOpcodeMayFail = 1
        Exit Function
    End If
    If Opcode = IrOpCall() Or Opcode = IrOpResume() Or Opcode = IrOpRaiseEvent() Or Opcode = IrOpLoadComponent() Or Opcode = IrOpUnloadComponent() Then
        IrOpcodeMayFail = 1
        Exit Function
    End If
    IrOpcodeMayFail = 0
End Function

Function IrOpcodeIsKnown(ByVal Opcode As Long) As Long
    If Opcode >= IrOpConstant() And Opcode <= IrOpCopyValue() Then
        IrOpcodeIsKnown = 1
        Exit Function
    End If
    If Opcode >= IrOpCheckedAdd() And Opcode <= IrOpConcatenate() Then
        IrOpcodeIsKnown = 1
        Exit Function
    End If
    If Opcode >= IrOpArrayAddress() And Opcode <= IrOpObjectAllocate() Then
        IrOpcodeIsKnown = 1
        Exit Function
    End If
    If Opcode >= IrOpCall() And Opcode <= IrOpUnloadComponent() Then
        IrOpcodeIsKnown = 1
        Exit Function
    End If
    If Opcode >= IrOpErrorTest() And Opcode <= IrOpResume() Then
        IrOpcodeIsKnown = 1
        Exit Function
    End If
    If Opcode >= IrOpCleanupBegin() And Opcode <= IrOpCleanupEnd() Then
        IrOpcodeIsKnown = 1
        Exit Function
    End If
    IrOpcodeIsKnown = 0
End Function

Function IrBlockHasEdge(ByVal FunctionIndex As Long, ByVal FromBlock As Long, ByVal ToBlock As Long, ByRef Edges() As IrEdge, ByVal EdgeCount As Long) As Long
    Dim EdgeIndex As Long = 0
    While EdgeIndex < EdgeCount
        If Edges(EdgeIndex).FunctionIndex = FunctionIndex And Edges(EdgeIndex).FromBlock = FromBlock And Edges(EdgeIndex).ToBlock = ToBlock Then
            IrBlockHasEdge = 1
            Exit Function
        End If
        EdgeIndex = EdgeIndex + 1
    Wend
    IrBlockHasEdge = 0
End Function

Function IrBlockHasKindEdge(ByVal FunctionIndex As Long, ByVal FromBlock As Long, ByVal ToBlock As Long, ByVal EdgeKind As Long, ByRef Edges() As IrEdge, ByVal EdgeCount As Long) As Long
    Dim EdgeIndex As Long = 0
    While EdgeIndex < EdgeCount
        If Edges(EdgeIndex).FunctionIndex = FunctionIndex And Edges(EdgeIndex).FromBlock = FromBlock And Edges(EdgeIndex).ToBlock = ToBlock And Edges(EdgeIndex).EdgeKind = EdgeKind Then
            IrBlockHasKindEdge = 1
            Exit Function
        End If
        EdgeIndex = EdgeIndex + 1
    Wend
    IrBlockHasKindEdge = 0
End Function

Function IrTypeIsManaged(ByVal TypeIndex As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long) As Long
    If TypeIndex < 0 Or TypeIndex >= TypeCount Then
        IrTypeIsManaged = 0
        Exit Function
    End If
    If EqualsFolded(Types(TypeIndex).TypeName, "String") <> 0 Or Types(TypeIndex).TypeKind = 30 Or Types(TypeIndex).TypeKind = 40 Or Types(TypeIndex).TypeKind = 41 Then
        IrTypeIsManaged = 1
    Else
        IrTypeIsManaged = 0
    End If
End Function

Function IrTypesExactlyMatch(ByVal LeftType As Long, ByVal RightType As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long) As Long
    If LeftType = RightType Then
        IrTypesExactlyMatch = 1
        Exit Function
    End If
    If LeftType < 0 Or LeftType >= TypeCount Or RightType < 0 Or RightType >= TypeCount Then
        IrTypesExactlyMatch = 0
        Exit Function
    End If
    If Types(LeftType).TypeKind <> Types(RightType).TypeKind Or Types(LeftType).ArrayRank <> Types(RightType).ArrayRank Or Types(LeftType).FixedLength <> Types(RightType).FixedLength Then
        IrTypesExactlyMatch = 0
        Exit Function
    End If
    If Types(LeftType).TypeKind = 41 Then
        IrTypesExactlyMatch = IrTypesExactlyMatch(Types(LeftType).ElementType, Types(RightType).ElementType, Types, TypeCount)
        Exit Function
    End If
    If Types(LeftType).TypeSymbol >= 0 Or Types(RightType).TypeSymbol >= 0 Then
        If Types(LeftType).TypeSymbol = Types(RightType).TypeSymbol Then
            IrTypesExactlyMatch = 1
        Else
            IrTypesExactlyMatch = 0
        End If
        Exit Function
    End If
    If EqualsFolded(Types(LeftType).TypeName, Types(RightType).TypeName) <> 0 Then
        IrTypesExactlyMatch = 1
    Else
        IrTypesExactlyMatch = 0
    End If
End Function

Function VerifyProgramIr(ByRef Program As IrProgram, ByRef Globals() As IrGlobal, ByVal GlobalCount As Long, ByRef Functions() As IrFunction, ByVal FunctionCount As Long, ByRef Parameters() As IrParameter, ByVal ParameterCount As Long, ByRef Storages() As IrStorage, ByVal StorageCount As Long, ByRef Blocks() As IrBlock, ByVal BlockCount As Long, ByRef Instructions() As IrInstruction, ByVal InstructionCount As Long, ByRef Operands() As IrOperand, ByVal OperandCount As Long, ByRef Values() As IrValue, ByVal ValueCount As Long, ByRef Edges() As IrEdge, ByVal EdgeCount As Long, ByRef Cleanups() As IrCleanup, ByVal CleanupCount As Long, ByRef Locations() As IrLocation, ByVal LocationCount As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim Valid As Long = 1
    If Program.FormatVersion <> 1 Then
        Call AddIrDiagnostic("UBE5000", "unsupported or missing IR format version", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        Valid = 0
    End If
    If Program.EntryFunction < -1 Or Program.EntryFunction >= FunctionCount Then
        Call AddIrDiagnostic("UBE5001", "IR entry function index is outside function storage", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        Valid = 0
    End If

    Dim Index As Long = 0
    While Index < LocationCount
        If Locations(Index).StableId <> Index + 1 Or Locations(Index).SourceId < 0 Or Locations(Index).StartByte < 0 Or Locations(Index).ByteLength < 0 Or Locations(Index).LineNumber < 1 Or Locations(Index).ColumnNumber < 1 Then
            Call AddIrDiagnostic("UBE5001", "IR location record is invalid", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        End If
        Index = Index + 1
    Wend

    Index = 0
    While Index < GlobalCount
        If Globals(Index).StableId <> Index + 1 Or Globals(Index).TypeIndex < 0 Or Globals(Index).TypeIndex >= TypeCount Or Globals(Index).StorageIndex < 0 Or Globals(Index).StorageIndex >= StorageCount Or Globals(Index).LocationIndex < 0 Or Globals(Index).LocationIndex >= LocationCount Then
            Call AddIrDiagnostic("UBE5001", "IR global record contains an invalid index", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        End If
        Index = Index + 1
    Wend

    Index = 0
    While Index < FunctionCount
        If Functions(Index).StableId <> Index + 1 Or Functions(Index).LocationIndex < 0 Or Functions(Index).LocationIndex >= LocationCount Then
            Call AddIrDiagnostic("UBE5001", "IR function identity or location is invalid", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        End If
        If Functions(Index).FirstParameter < 0 Or Functions(Index).ParameterCount < 0 Or Functions(Index).FirstParameter + Functions(Index).ParameterCount > ParameterCount Then
            Call AddIrDiagnostic("UBE5002", "IR function parameter range is invalid", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        End If
        If Functions(Index).FirstStorage < 0 Or Functions(Index).StorageCount < 0 Or Functions(Index).FirstStorage + Functions(Index).StorageCount > StorageCount Then
            Call AddIrDiagnostic("UBE5002", "IR function storage range is invalid", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        End If
        If Functions(Index).FirstBlock < 0 Or Functions(Index).BlockCount <= 0 Or Functions(Index).FirstBlock + Functions(Index).BlockCount > BlockCount Then
            Call AddIrDiagnostic("UBE5002", "IR function block range is invalid", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        Else
            If Functions(Index).EntryBlock < Functions(Index).FirstBlock Or Functions(Index).EntryBlock >= Functions(Index).FirstBlock + Functions(Index).BlockCount Or Functions(Index).ReturnBlock < Functions(Index).FirstBlock Or Functions(Index).ReturnBlock >= Functions(Index).FirstBlock + Functions(Index).BlockCount Then
                Call AddIrDiagnostic("UBE5003", "IR function entry or return block is outside its function", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            End If
        End If
        Index = Index + 1
    Wend

    Index = 0
    While Index < ParameterCount
        If Parameters(Index).StableId <> Index + 1 Or Parameters(Index).FunctionIndex < 0 Or Parameters(Index).FunctionIndex >= FunctionCount Or Parameters(Index).StorageIndex < 0 Or Parameters(Index).StorageIndex >= StorageCount Or Parameters(Index).TypeIndex < 0 Or Parameters(Index).TypeIndex >= TypeCount Then
            Call AddIrDiagnostic("UBE5001", "IR parameter record contains an invalid index", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        Else
            If Storages(Parameters(Index).StorageIndex).FunctionIndex <> Parameters(Index).FunctionIndex Or Storages(Parameters(Index).StorageIndex).StorageKind <> IrStorageParameter() Then
                Call AddIrDiagnostic("UBE5007", "IR parameter storage has the wrong owner or kind", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            End If
        End If
        If Parameters(Index).PassingMode <> IrPassingByVal() And Parameters(Index).PassingMode <> IrPassingByRef() Then
            Call AddIrDiagnostic("UBE5007", "IR parameter passing mode is invalid", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        End If
        Index = Index + 1
    Wend

    Index = 0
    While Index < StorageCount
        If Storages(Index).StableId <> Index + 1 Or Storages(Index).TypeIndex < 0 Or Storages(Index).TypeIndex >= TypeCount Or Storages(Index).LocationIndex < 0 Or Storages(Index).LocationIndex >= LocationCount Then
            Call AddIrDiagnostic("UBE5001", "IR storage record contains an invalid index", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        End If
        If Storages(Index).FunctionIndex < -1 Or Storages(Index).FunctionIndex >= FunctionCount Then
            Call AddIrDiagnostic("UBE5002", "IR storage owner is invalid", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        End If
        Index = Index + 1
    Wend

    Index = 0
    While Index < BlockCount
        If Blocks(Index).StableId <> Index + 1 Or Blocks(Index).FunctionIndex < 0 Or Blocks(Index).FunctionIndex >= FunctionCount Or Blocks(Index).LocationIndex < 0 Or Blocks(Index).LocationIndex >= LocationCount Then
            Call AddIrDiagnostic("UBE5001", "IR block identity, owner, or location is invalid", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        End If
        If Blocks(Index).FirstInstruction < 0 Or Blocks(Index).InstructionCount <= 0 Or Blocks(Index).FirstInstruction + Blocks(Index).InstructionCount > InstructionCount Then
            Call AddIrDiagnostic("UBE5003", "IR block instruction range is empty or invalid", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        Else
            Dim LastInstruction As Long = Blocks(Index).FirstInstruction + Blocks(Index).InstructionCount - 1
            If IrOpcodeIsTerminator(Instructions(LastInstruction).Opcode) = 0 Then
                Call AddIrDiagnostic("UBE5003", "IR block does not end in a terminator", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            End If
        End If
        Index = Index + 1
    Wend

    Index = 0
    While Index < InstructionCount
        If Instructions(Index).StableId <> Index + 1 Or Instructions(Index).FunctionIndex < 0 Or Instructions(Index).FunctionIndex >= FunctionCount Or Instructions(Index).BlockIndex < 0 Or Instructions(Index).BlockIndex >= BlockCount Or Instructions(Index).LocationIndex < 0 Or Instructions(Index).LocationIndex >= LocationCount Then
            Call AddIrDiagnostic("UBE5001", "IR instruction contains an invalid identity or index", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        Else
            If Blocks(Instructions(Index).BlockIndex).FunctionIndex <> Instructions(Index).FunctionIndex Then
                Call AddIrDiagnostic("UBE5002", "IR instruction and block have different owners", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            End If
        End If
        If IrOpcodeIsKnown(Instructions(Index).Opcode) = 0 Then
            Call AddIrDiagnostic("UBE5003", "IR instruction has an unknown opcode", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        End If
        If Instructions(Index).BlockIndex >= 0 And Instructions(Index).BlockIndex < BlockCount Then
            If Index < Blocks(Instructions(Index).BlockIndex).FirstInstruction Or Index >= Blocks(Instructions(Index).BlockIndex).FirstInstruction + Blocks(Instructions(Index).BlockIndex).InstructionCount Then
                Call AddIrDiagnostic("UBE5003", "IR instruction is outside its owning block range", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            End If
        End If
        Dim OperandRangeInvalid As Long = 0
        If Instructions(Index).OperandCount < 0 Then
            OperandRangeInvalid = 1
        Else
            If Instructions(Index).OperandCount = 0 Then
                If Instructions(Index).FirstOperand <> -1 Then
                    OperandRangeInvalid = 1
                End If
            Else
                If Instructions(Index).FirstOperand < 0 Or Instructions(Index).FirstOperand + Instructions(Index).OperandCount > OperandCount Then
                    OperandRangeInvalid = 1
                End If
            End If
        End If
        If OperandRangeInvalid <> 0 Then
            Call AddIrDiagnostic("UBE5001", "IR instruction operand range is invalid", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        End If
        If Instructions(Index).ResultValue >= 0 Then
            If Instructions(Index).ResultValue >= ValueCount Or Instructions(Index).ResultType < 0 Or Instructions(Index).ResultType >= TypeCount Then
                Call AddIrDiagnostic("UBE5005", "IR instruction result value or type is invalid", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            Else
                If Values(Instructions(Index).ResultValue).DefinitionInstruction <> Index Or Values(Instructions(Index).ResultValue).FunctionIndex <> Instructions(Index).FunctionIndex Or Values(Instructions(Index).ResultValue).TypeIndex <> Instructions(Index).ResultType Then
                    Call AddIrDiagnostic("UBE5006", "IR instruction result and value definition disagree", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    Valid = 0
                End If
            End If
        End If
        If IrOpcodeMayFail(Instructions(Index).Opcode) <> 0 Then
            If Instructions(Index).FailureTarget < 0 Or Instructions(Index).FailureTarget >= BlockCount Then
                Call AddIrDiagnostic("UBE5008", "fallible IR instruction has no valid failure target", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            Else
                If Blocks(Instructions(Index).FailureTarget).FunctionIndex <> Instructions(Index).FunctionIndex Then
                    Call AddIrDiagnostic("UBE5008", "fallible IR instruction crosses a function boundary", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    Valid = 0
                Else
                    If IrBlockHasKindEdge(Instructions(Index).FunctionIndex, Instructions(Index).BlockIndex, Instructions(Index).FailureTarget, IrEdgeError(), Edges, EdgeCount) = 0 Then
                        Call AddIrDiagnostic("UBE5008", "fallible IR instruction has no matching error edge", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        Valid = 0
                    End If
                End If
            End If
        Else
            If Instructions(Index).FailureTarget >= 0 Then
                Call AddIrDiagnostic("UBE5008", "non-failing IR instruction has a failure target", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            End If
        End If
        If Instructions(Index).CleanupDepth < 0 Then
            Call AddIrDiagnostic("UBE5009", "IR instruction cleanup depth is negative", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        End If
        If OperandRangeInvalid = 0 Then
            If Instructions(Index).Opcode = IrOpArrayAddress() Then
                If Instructions(Index).OperandCount <> 3 Or Instructions(Index).ResultValue < 0 Then
                    Call AddIrDiagnostic("UBE5006", "array-address instruction requires a result and three operands", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    Valid = 0
                Else
                    Dim ArrayBaseOperand As Long = Instructions(Index).FirstOperand
                    If Operands(ArrayBaseOperand).OperandKind <> IrOperandStorage() Or Operands(ArrayBaseOperand + 1).OperandKind <> IrOperandValue() Or Operands(ArrayBaseOperand + 2).OperandKind <> IrOperandType() Then
                        Call AddIrDiagnostic("UBE5006", "array-address instruction operand kinds are invalid", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        Valid = 0
                    End If
                End If
            End If
            If Instructions(Index).Opcode = IrOpFieldAddress() Then
                If Instructions(Index).OperandCount <> 3 Or Instructions(Index).ResultValue < 0 Then
                    Call AddIrDiagnostic("UBE5006", "field-address instruction requires a result and three operands", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    Valid = 0
                Else
                    Dim FieldBaseOperand As Long = Instructions(Index).FirstOperand
                    Dim FieldBaseKind As Long = Operands(FieldBaseOperand).OperandKind
                    If (FieldBaseKind <> IrOperandStorage() And FieldBaseKind <> IrOperandValue()) Or Operands(FieldBaseOperand + 1).OperandKind <> IrOperandType() Or Operands(FieldBaseOperand + 2).OperandKind <> IrOperandInteger() Then
                        Call AddIrDiagnostic("UBE5006", "field-address instruction operand kinds are invalid", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        Valid = 0
                    End If
                End If
            End If
            If Instructions(Index).Opcode = IrOpLoad() Then
                If Instructions(Index).OperandCount <> 1 Or Instructions(Index).ResultValue < 0 Then
                    Call AddIrDiagnostic("UBE5006", "load instruction requires one address operand and a result", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    Valid = 0
                Else
                    Dim LoadOperandKind As Long = Operands(Instructions(Index).FirstOperand).OperandKind
                    If LoadOperandKind <> IrOperandStorage() And LoadOperandKind <> IrOperandValue() Then
                        Call AddIrDiagnostic("UBE5006", "load instruction address is neither storage nor an address value", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        Valid = 0
                    End If
                End If
            End If
            If Instructions(Index).Opcode = IrOpStore() Then
                If Instructions(Index).OperandCount <> 2 Then
                    Call AddIrDiagnostic("UBE5006", "store instruction requires address and value operands", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    Valid = 0
                Else
                    Dim StoreOperandKind As Long = Operands(Instructions(Index).FirstOperand).OperandKind
                    If (StoreOperandKind <> IrOperandStorage() And StoreOperandKind <> IrOperandValue()) Or Operands(Instructions(Index).FirstOperand + 1).OperandKind <> IrOperandValue() Then
                        Call AddIrDiagnostic("UBE5006", "store instruction operand kinds are invalid", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        Valid = 0
                    End If
                End If
            End If
            If Instructions(Index).Opcode = IrOpRaiseEvent() Then
                If Instructions(Index).OperandCount < 1 Or Operands(Instructions(Index).FirstOperand).OperandKind <> IrOperandInteger() Then
                    Call AddIrDiagnostic("UBE5006", "RaiseEvent instruction requires an Event symbol operand", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    Valid = 0
                End If
                If Instructions(Index).ResultValue >= 0 Then
                    Call AddIrDiagnostic("UBE5006", "RaiseEvent instruction cannot produce a value", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    Valid = 0
                End If
            End If
            If Instructions(Index).Opcode = IrOpLoadComponent() Or Instructions(Index).Opcode = IrOpUnloadComponent() Then
                If Instructions(Index).OperandCount <> 2 Or Operands(Instructions(Index).FirstOperand).OperandKind <> IrOperandStorage() Or Operands(Instructions(Index).FirstOperand + 1).OperandKind <> IrOperandInteger() Then
                    Call AddIrDiagnostic("UBE5006", "component lifecycle instruction requires storage and component-kind operands", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    Valid = 0
                End If
                If Instructions(Index).ResultValue >= 0 Then
                    Call AddIrDiagnostic("UBE5006", "component lifecycle instruction cannot produce a value", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    Valid = 0
                End If
            End If
            If Instructions(Index).Opcode = IrOpMonitorEnter() Or Instructions(Index).Opcode = IrOpMonitorExit() Then
                If Instructions(Index).OperandCount <> 1 Or Operands(Instructions(Index).FirstOperand).OperandKind <> IrOperandStorage() Then
                    Call AddIrDiagnostic("UBE5006", "monitor instruction requires one object storage operand", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    Valid = 0
                End If
                If Instructions(Index).Opcode = IrOpMonitorEnter() Then
                    If Instructions(Index).ResultValue < 0 Or EqualsFolded(Types(Instructions(Index).ResultType).TypeName, "Boolean") = 0 Then
                        Call AddIrDiagnostic("UBE5006", "monitor-enter instruction must produce Boolean", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        Valid = 0
                    End If
                Else
                    If Instructions(Index).ResultValue >= 0 Then
                        Call AddIrDiagnostic("UBE5006", "monitor-exit instruction cannot produce a value", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        Valid = 0
                    End If
                End If
            End If
            If Instructions(Index).Opcode = IrOpCall() Or Instructions(Index).Opcode = IrOpCallNew() Then
                If Instructions(Index).OperandCount < 1 Or Operands(Instructions(Index).FirstOperand).OperandKind <> IrOperandFunction() Then
                    Call AddIrDiagnostic("UBE5006", "call instruction requires a function operand", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    Valid = 0
                Else
                    Dim CalledFunction As Long = Operands(Instructions(Index).FirstOperand).ReferencedIndex
                    If CalledFunction < 0 Or CalledFunction >= FunctionCount Then
                        Call AddIrDiagnostic("UBE5006", "call instruction references an invalid function", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        Valid = 0
                    Else
                        Dim CallFirstArgument As Long = 1
                        If Instructions(Index).Opcode = IrOpCallNew() Then
                            If Instructions(Index).ResultValue < 0 Or EqualsFolded(Types(Instructions(Index).ResultType).TypeName, "LongLong") = 0 Then
                                Call AddIrDiagnostic("UBE5006", "CallNew must produce a LongLong thread identifier", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                Valid = 0
                            End If
                            If Functions(CalledFunction).ResultType >= 0 Then
                                Call AddIrDiagnostic("UBE5006", "CallNew target must be a Sub", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                Valid = 0
                            End If
                        End If
                        If Instructions(Index).Flags And 256 Then
                            CallFirstArgument = 2
                            If Instructions(Index).OperandCount < 2 Then
                                Call AddIrDiagnostic("UBE5006", "instance call requires an object receiver", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                Valid = 0
                            Else
                                Dim ReceiverOperandKind As Long = Operands(Instructions(Index).FirstOperand + 1).OperandKind
                                If ReceiverOperandKind <> IrOperandStorage() And ReceiverOperandKind <> IrOperandValue() Then
                                    Call AddIrDiagnostic("UBE5006", "instance call receiver must be a value or storage", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                    Valid = 0
                                End If
                            End If
                        End If
                        If Instructions(Index).OperandCount - CallFirstArgument <> Functions(CalledFunction).ParameterCount Then
                            Call AddIrDiagnostic("UBE5006", "call argument count does not match the called function", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                            Valid = 0
                        Else
                            Dim CallArgumentOffset As Long = 0
                            While CallArgumentOffset < Functions(CalledFunction).ParameterCount
                                Dim CalledParameter As Long = Functions(CalledFunction).FirstParameter + CallArgumentOffset
                                Dim CallOperand As Long = Instructions(Index).FirstOperand + CallArgumentOffset + CallFirstArgument
                                Dim CallArgumentType As Long = -1
                                If Instructions(Index).Opcode = IrOpCallNew() And Parameters(CalledParameter).PassingMode <> IrPassingByVal() Then
                                    Call AddIrDiagnostic("UBE5007", "CallNew parameters must be ByVal", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                    Valid = 0
                                End If
                                If Parameters(CalledParameter).PassingMode = IrPassingByRef() Then
                                    If Operands(CallOperand).OperandKind = IrOperandStorage() Then
                                        If Operands(CallOperand).ReferencedIndex >= 0 And Operands(CallOperand).ReferencedIndex < StorageCount Then
                                            CallArgumentType = Storages(Operands(CallOperand).ReferencedIndex).TypeIndex
                                        End If
                                    Else
                                        If Operands(CallOperand).OperandKind = IrOperandValue() Then
                                            Dim AddressValue As Long = Operands(CallOperand).ReferencedIndex
                                            If AddressValue >= 0 And AddressValue < ValueCount Then
                                                Dim AddressDefinition As Long = Values(AddressValue).DefinitionInstruction
                                                If AddressDefinition >= 0 And AddressDefinition < InstructionCount Then
                                                    If Instructions(AddressDefinition).Opcode = IrOpAddress() Or Instructions(AddressDefinition).Opcode = IrOpArrayAddress() Or Instructions(AddressDefinition).Opcode = IrOpFieldAddress() Then
                                                        CallArgumentType = Values(AddressValue).TypeIndex
                                                    End If
                                                End If
                                            End If
                                        End If
                                    End If
                                    If CallArgumentType < 0 Then
                                        Call AddIrDiagnostic("UBE5007", "ByRef call argument is not an addressable identity", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                        Valid = 0
                                    End If
                                Else
                                    If Operands(CallOperand).OperandKind = IrOperandValue() Then
                                        If Operands(CallOperand).ReferencedIndex >= 0 And Operands(CallOperand).ReferencedIndex < ValueCount Then
                                            CallArgumentType = Values(Operands(CallOperand).ReferencedIndex).TypeIndex
                                        End If
                                    End If
                                    If CallArgumentType < 0 Then
                                        Call AddIrDiagnostic("UBE5006", "ByVal call argument is not a value", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                        Valid = 0
                                    End If
                                End If
                                If CallArgumentType >= 0 And IrTypesExactlyMatch(CallArgumentType, Parameters(CalledParameter).TypeIndex, Types, TypeCount) = 0 Then
                                    Call AddIrDiagnostic("UBE5007", "call argument type " & Types(CallArgumentType).TypeName & " (" & LongToString(CallArgumentType) & ") does not exactly match parameter type " & Types(Parameters(CalledParameter).TypeIndex).TypeName & " (" & LongToString(Parameters(CalledParameter).TypeIndex) & ") for " & Functions(CalledFunction).FunctionName, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                    Valid = 0
                                End If
                                CallArgumentOffset = CallArgumentOffset + 1
                            Wend
                        End If
                        If Instructions(Index).Opcode <> IrOpCallNew() Then
                            If Functions(CalledFunction).ResultType < 0 Then
                                If Instructions(Index).ResultValue >= 0 Then
                                    Call AddIrDiagnostic("UBE5006", "Sub call unexpectedly produces a result value", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                    Valid = 0
                                End If
                            Else
                                If Instructions(Index).ResultValue < 0 Or Instructions(Index).ResultType <> Functions(CalledFunction).ResultType Then
                                    Call AddIrDiagnostic("UBE5006", "Function call result does not match the called function", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                    Valid = 0
                                End If
                            End If
                        End If
                    End If
                End If
            End If
        End If
        If Instructions(Index).PrimaryTarget >= 0 Then
            If Instructions(Index).PrimaryTarget >= BlockCount Or Blocks(Instructions(Index).PrimaryTarget).FunctionIndex <> Instructions(Index).FunctionIndex Then
                Call AddIrDiagnostic("UBE5004", "IR primary target crosses a function boundary", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            Else
                If IrBlockHasEdge(Instructions(Index).FunctionIndex, Instructions(Index).BlockIndex, Instructions(Index).PrimaryTarget, Edges, EdgeCount) = 0 Then
                    Call AddIrDiagnostic("UBE5004", "IR target has no matching control-flow edge", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    Valid = 0
                End If
            End If
        End If
        If Instructions(Index).SecondaryTarget >= 0 Then
            If Instructions(Index).SecondaryTarget >= BlockCount Or Blocks(Instructions(Index).SecondaryTarget).FunctionIndex <> Instructions(Index).FunctionIndex Then
                Call AddIrDiagnostic("UBE5004", "IR secondary target crosses a function boundary", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            Else
                If IrBlockHasEdge(Instructions(Index).FunctionIndex, Instructions(Index).BlockIndex, Instructions(Index).SecondaryTarget, Edges, EdgeCount) = 0 Then
                    Call AddIrDiagnostic("UBE5004", "IR secondary target has no matching control-flow edge", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    Valid = 0
                End If
            End If
        End If
        Index = Index + 1
    Wend

    Index = 0
    While Index < OperandCount
        If Operands(Index).StableId <> Index + 1 Or Operands(Index).InstructionIndex < 0 Or Operands(Index).InstructionIndex >= InstructionCount Or Operands(Index).Ordinal < 0 Then
            Call AddIrDiagnostic("UBE5001", "IR operand identity or owner is invalid", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        End If
        If Operands(Index).InstructionIndex >= 0 And Operands(Index).InstructionIndex < InstructionCount Then
            Dim OwnerInstruction As Long = Operands(Index).InstructionIndex
            If Instructions(OwnerInstruction).FirstOperand < 0 Or Index < Instructions(OwnerInstruction).FirstOperand Or Index >= Instructions(OwnerInstruction).FirstOperand + Instructions(OwnerInstruction).OperandCount Or Operands(Index).Ordinal <> Index - Instructions(OwnerInstruction).FirstOperand Then
                Call AddIrDiagnostic("UBE5006", "IR operand is outside its owning instruction range or ordinal", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            End If
        End If
        If Operands(Index).OperandKind = IrOperandValue() Then
            If Operands(Index).ReferencedIndex < 0 Or Operands(Index).ReferencedIndex >= ValueCount Then
                Call AddIrDiagnostic("UBE5006", "IR operand references an invalid value", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            Else
                If Operands(Index).InstructionIndex >= 0 And Operands(Index).InstructionIndex < InstructionCount Then
                    If Values(Operands(Index).ReferencedIndex).FunctionIndex <> Instructions(Operands(Index).InstructionIndex).FunctionIndex Then
                        Call AddIrDiagnostic("UBE5006", "IR value operand crosses a function boundary", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        Valid = 0
                    Else
                        Dim ValueDefinition As Long = Values(Operands(Index).ReferencedIndex).DefinitionInstruction
                        If ValueDefinition < 0 Or ValueDefinition >= Operands(Index).InstructionIndex Then
                            Call AddIrDiagnostic("UBE5006", "IR value is used before its definition", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                            Valid = 0
                        Else
                            If Instructions(ValueDefinition).BlockIndex <> Instructions(Operands(Index).InstructionIndex).BlockIndex Then
                                Call AddIrDiagnostic("UBE5006", "IR value crosses a block without an explicit merge", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                Valid = 0
                            End If
                        End If
                    End If
                End If
            End If
        End If
        If Operands(Index).OperandKind = IrOperandStorage() Then
            If Operands(Index).ReferencedIndex < 0 Or Operands(Index).ReferencedIndex >= StorageCount Then
                Call AddIrDiagnostic("UBE5007", "IR operand references invalid storage", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            Else
                If Operands(Index).InstructionIndex >= 0 And Operands(Index).InstructionIndex < InstructionCount Then
                    Dim StorageOwner As Long = Storages(Operands(Index).ReferencedIndex).FunctionIndex
                    If StorageOwner >= 0 And StorageOwner <> Instructions(Operands(Index).InstructionIndex).FunctionIndex Then
                        Call AddIrDiagnostic("UBE5007", "IR storage operand crosses a function boundary", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        Valid = 0
                    End If
                End If
            End If
        End If
        If Operands(Index).OperandKind = IrOperandFunction() Then
            If Operands(Index).ReferencedIndex < 0 Or Operands(Index).ReferencedIndex >= FunctionCount Then
                Call AddIrDiagnostic("UBE5006", "IR operand references an invalid function", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            End If
        End If
        If Operands(Index).OperandKind = IrOperandBlock() Then
            If Operands(Index).ReferencedIndex < 0 Or Operands(Index).ReferencedIndex >= BlockCount Then
                Call AddIrDiagnostic("UBE5004", "IR operand references an invalid block", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            Else
                If Operands(Index).InstructionIndex >= 0 And Operands(Index).InstructionIndex < InstructionCount Then
                    If Blocks(Operands(Index).ReferencedIndex).FunctionIndex <> Instructions(Operands(Index).InstructionIndex).FunctionIndex Then
                        Call AddIrDiagnostic("UBE5004", "IR block operand crosses a function boundary", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        Valid = 0
                    End If
                End If
            End If
        End If
        If Operands(Index).OperandKind = IrOperandType() Then
            If Operands(Index).ReferencedIndex < 0 Or Operands(Index).ReferencedIndex >= TypeCount Then
                Call AddIrDiagnostic("UBE5006", "IR operand references an invalid semantic type", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            End If
        End If
        If Operands(Index).OperandKind = IrOperandInteger() Then
            If Operands(Index).ReferencedIndex < 0 Then
                Call AddIrDiagnostic("UBE5006", "IR integer operand is negative where an index is required", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            End If
        End If
        If Operands(Index).OperandKind < IrOperandValue() Or Operands(Index).OperandKind > IrOperandText() Then
            Call AddIrDiagnostic("UBE5006", "IR operand kind is unknown", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        End If
        Index = Index + 1
    Wend

    Index = 0
    While Index < ValueCount
        If Values(Index).StableId <> Index + 1 Or Values(Index).FunctionIndex < 0 Or Values(Index).FunctionIndex >= FunctionCount Or Values(Index).TypeIndex < 0 Or Values(Index).TypeIndex >= TypeCount Or Values(Index).LocationIndex < 0 Or Values(Index).LocationIndex >= LocationCount Then
            Call AddIrDiagnostic("UBE5005", "IR value identity, owner, type, or location is invalid", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        End If
        If Values(Index).ValueKind = IrValueInstruction() Then
            If Values(Index).DefinitionInstruction < 0 Or Values(Index).DefinitionInstruction >= InstructionCount Then
                Call AddIrDiagnostic("UBE5006", "IR value has no valid defining instruction", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            Else
                If Instructions(Values(Index).DefinitionInstruction).FunctionIndex <> Values(Index).FunctionIndex Then
                    Call AddIrDiagnostic("UBE5006", "IR value definition crosses a function boundary", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    Valid = 0
                End If
            End If
        End If
        Index = Index + 1
    Wend

    Index = 0
    While Index < EdgeCount
        If Edges(Index).StableId <> Index + 1 Or Edges(Index).FunctionIndex < 0 Or Edges(Index).FunctionIndex >= FunctionCount Or Edges(Index).FromBlock < 0 Or Edges(Index).FromBlock >= BlockCount Or Edges(Index).ToBlock < 0 Or Edges(Index).ToBlock >= BlockCount Then
            Call AddIrDiagnostic("UBE5004", "IR edge identity, owner, or target is invalid", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        Else
            If Blocks(Edges(Index).FromBlock).FunctionIndex <> Edges(Index).FunctionIndex Or Blocks(Edges(Index).ToBlock).FunctionIndex <> Edges(Index).FunctionIndex Then
                Call AddIrDiagnostic("UBE5004", "IR edge crosses a function boundary", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            End If
        End If
        If Edges(Index).CleanupFromDepth < Edges(Index).CleanupToDepth Or Edges(Index).CleanupToDepth < 0 Then
            Call AddIrDiagnostic("UBE5009", "IR edge has an invalid cleanup-depth transition", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        End If
        If Edges(Index).EdgeKind < IrEdgeFallthrough() Or Edges(Index).EdgeKind > IrEdgeResume() Then
            Call AddIrDiagnostic("UBE5004", "IR edge kind is unknown", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        End If
        If Edges(Index).EdgeKind = IrEdgeTrue() Or Edges(Index).EdgeKind = IrEdgeFalse() Then
            If Edges(Index).ConditionValue < 0 Or Edges(Index).ConditionValue >= ValueCount Then
                Call AddIrDiagnostic("UBE5004", "conditional IR edge has no valid condition value", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            Else
                If Values(Edges(Index).ConditionValue).FunctionIndex <> Edges(Index).FunctionIndex Then
                    Call AddIrDiagnostic("UBE5004", "conditional IR edge condition crosses a function boundary", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    Valid = 0
                End If
            End If
        Else
            If Edges(Index).ConditionValue >= 0 Then
                Call AddIrDiagnostic("UBE5004", "unconditional IR edge unexpectedly has a condition value", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            End If
        End If
        Index = Index + 1
    Wend

    Index = 0
    While Index < CleanupCount
        If Cleanups(Index).StableId <> Index + 1 Or Cleanups(Index).FunctionIndex < 0 Or Cleanups(Index).FunctionIndex >= FunctionCount Or Cleanups(Index).StorageIndex < 0 Or Cleanups(Index).StorageIndex >= StorageCount Or Cleanups(Index).RegionDepth < 0 Then
            Call AddIrDiagnostic("UBE5009", "IR cleanup record is invalid", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Valid = 0
        Else
            If Storages(Cleanups(Index).StorageIndex).FunctionIndex <> Cleanups(Index).FunctionIndex Then
                Call AddIrDiagnostic("UBE5009", "IR cleanup storage crosses a function boundary", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            End If
            If Cleanups(Index).CleanupKind <> IrCleanupManagedValue() And Cleanups(Index).CleanupKind <> IrCleanupArrayStorage() Then
                Call AddIrDiagnostic("UBE5009", "IR cleanup kind is unknown", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            Else
                Dim CleanupStorageType As Long = Storages(Cleanups(Index).StorageIndex).TypeIndex
                If Cleanups(Index).CleanupKind = IrCleanupManagedValue() Then
                    If IrTypeIsManaged(CleanupStorageType, Types, TypeCount) = 0 Then
                        Call AddIrDiagnostic("UBE5009", "managed-value cleanup names unmanaged storage", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        Valid = 0
                    End If
                Else
                    If CleanupStorageType < 0 Or CleanupStorageType >= TypeCount Then
                        Call AddIrDiagnostic("UBE5009", "array cleanup storage type is invalid", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        Valid = 0
                    Else
                        If Types(CleanupStorageType).TypeKind <> 41 Then
                            Call AddIrDiagnostic("UBE5009", "array cleanup names non-array storage", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                            Valid = 0
                        End If
                    End If
                End If
            End If
            If Cleanups(Index).ActivationInstruction < 0 Or Cleanups(Index).ActivationInstruction >= InstructionCount Then
                Call AddIrDiagnostic("UBE5009", "IR cleanup activation instruction is invalid", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Valid = 0
            Else
                If Instructions(Cleanups(Index).ActivationInstruction).FunctionIndex <> Cleanups(Index).FunctionIndex Then
                    Call AddIrDiagnostic("UBE5009", "IR cleanup activation crosses a function boundary", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    Valid = 0
                End If
            End If
            If Cleanups(Index).DeactivationInstruction >= 0 Then
                If Cleanups(Index).DeactivationInstruction >= InstructionCount Or Cleanups(Index).DeactivationInstruction < Cleanups(Index).ActivationInstruction Then
                    Call AddIrDiagnostic("UBE5009", "IR cleanup deactivation instruction is invalid or precedes activation", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    Valid = 0
                Else
                    If Instructions(Cleanups(Index).DeactivationInstruction).FunctionIndex <> Cleanups(Index).FunctionIndex Then
                        Call AddIrDiagnostic("UBE5009", "IR cleanup deactivation crosses a function boundary", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        Valid = 0
                    End If
                End If
            End If
        End If
        Index = Index + 1
    Wend

    If Valid = 0 Then
        Program.HasErrors = 1
    End If
    VerifyProgramIr = Valid
End Function
