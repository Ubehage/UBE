UBE SOURCE 1 MODULE
Attribute UBE_Name = "IrModel"

' RP5 IR is target independent. All relationships are bounded array indexes;
' native pointers, LLVM types, and target layouts never enter these records.

Type IrProgram
    FormatVersion As Long
    EntryFunction As Long
    HasErrors As Long
End Type

Type IrBuildState
    GlobalCount As Long
    GlobalCapacity As Long
    FunctionCount As Long
    FunctionCapacity As Long
    ParameterCount As Long
    ParameterCapacity As Long
    StorageCount As Long
    StorageCapacity As Long
    BlockCount As Long
    BlockCapacity As Long
    InstructionCount As Long
    InstructionCapacity As Long
    OperandCount As Long
    OperandCapacity As Long
    ValueCount As Long
    ValueCapacity As Long
    EdgeCount As Long
    EdgeCapacity As Long
    CleanupCount As Long
    CleanupCapacity As Long
    LocationCount As Long
    LocationCapacity As Long
    FailureSyntaxNode As Long
    FailureStage As Long
    FailureDetail As String
End Type

Type IrLocation
    StableId As Long
    SourceId As Long
    StartByte As Long
    ByteLength As Long
    LineNumber As Long
    ColumnNumber As Long
    SyntaxNode As Long
    Flags As Long
End Type

Type IrGlobal
    StableId As Long
    SymbolIndex As Long
    TypeIndex As Long
    StorageIndex As Long
    InitializerValue As Long
    Flags As Long
    LocationIndex As Long
End Type

Type IrFunction
    StableId As Long
    SymbolIndex As Long
    FunctionName As String
    ResultType As Long
    EntryBlock As Long
    ReturnBlock As Long
    FirstParameter As Long
    ParameterCount As Long
    FirstStorage As Long
    StorageCount As Long
    FirstBlock As Long
    BlockCount As Long
    Flags As Long
    LocationIndex As Long
End Type

Type IrParameter
    StableId As Long
    FunctionIndex As Long
    SymbolIndex As Long
    TypeIndex As Long
    StorageIndex As Long
    Ordinal As Long
    PassingMode As Long
    Flags As Long
    LocationIndex As Long
End Type

Type IrStorage
    StableId As Long
    FunctionIndex As Long
    SymbolIndex As Long
    TypeIndex As Long
    StorageKind As Long
    Flags As Long
    LocationIndex As Long
End Type

Type IrBlock
    StableId As Long
    FunctionIndex As Long
    BlockOrdinal As Long
    FirstInstruction As Long
    InstructionCount As Long
    Flags As Long
    LocationIndex As Long
End Type

Type IrInstruction
    StableId As Long
    FunctionIndex As Long
    BlockIndex As Long
    Opcode As Long
    ResultValue As Long
    ResultType As Long
    FirstOperand As Long
    OperandCount As Long
    PrimaryTarget As Long
    SecondaryTarget As Long
    FailureTarget As Long
    CleanupDepth As Long
    SymbolIndex As Long
    Flags As Long
    ImmediateText As String
    LocationIndex As Long
End Type

Type IrOperand
    StableId As Long
    InstructionIndex As Long
    Ordinal As Long
    OperandKind As Long
    ReferencedIndex As Long
    ImmediateText As String
End Type

Type IrValue
    StableId As Long
    FunctionIndex As Long
    TypeIndex As Long
    DefinitionInstruction As Long
    ValueKind As Long
    Flags As Long
    LocationIndex As Long
End Type

Type IrEdge
    StableId As Long
    FunctionIndex As Long
    FromBlock As Long
    ToBlock As Long
    EdgeKind As Long
    ConditionValue As Long
    CleanupFromDepth As Long
    CleanupToDepth As Long
    LocationIndex As Long
End Type

Type IrCleanup
    StableId As Long
    FunctionIndex As Long
    RegionDepth As Long
    StorageIndex As Long
    CleanupKind As Long
    ActivationInstruction As Long
    DeactivationInstruction As Long
    Flags As Long
    LocationIndex As Long
End Type

Function LimitIrRecords() As Long
    LimitIrRecords = 1000000
End Function

Function IrStorageGlobal() As Long
    IrStorageGlobal = 1
End Function

Function IrStorageParameter() As Long
    IrStorageParameter = 2
End Function

Function IrStorageLocal() As Long
    IrStorageLocal = 3
End Function

Function IrStorageStatic() As Long
    IrStorageStatic = 4
End Function

Function IrStorageTemporary() As Long
    IrStorageTemporary = 5
End Function

Function IrStorageResult() As Long
    IrStorageResult = 6
End Function

Function IrStorageErrorState() As Long
    IrStorageErrorState = 7
End Function

Function IrPassingByVal() As Long
    IrPassingByVal = 1
End Function

Function IrPassingByRef() As Long
    IrPassingByRef = 2
End Function

Function IrOperandValue() As Long
    IrOperandValue = 1
End Function

Function IrOperandStorage() As Long
    IrOperandStorage = 2
End Function

Function IrOperandBlock() As Long
    IrOperandBlock = 3
End Function

Function IrOperandFunction() As Long
    IrOperandFunction = 4
End Function

Function IrOperandType() As Long
    IrOperandType = 5
End Function

Function IrOperandInteger() As Long
    IrOperandInteger = 6
End Function

Function IrOperandText() As Long
    IrOperandText = 7
End Function

Function IrValueInstruction() As Long
    IrValueInstruction = 1
End Function

Function IrValueParameter() As Long
    IrValueParameter = 2
End Function

Function IrValueConstant() As Long
    IrValueConstant = 3
End Function

Function IrEdgeFallthrough() As Long
    IrEdgeFallthrough = 1
End Function

Function IrEdgeTrue() As Long
    IrEdgeTrue = 2
End Function

Function IrEdgeFalse() As Long
    IrEdgeFalse = 3
End Function

Function IrEdgeError() As Long
    IrEdgeError = 4
End Function

Function IrEdgeResume() As Long
    IrEdgeResume = 5
End Function

Function IrCleanupManagedValue() As Long
    IrCleanupManagedValue = 1
End Function

Function IrCleanupArrayStorage() As Long
    IrCleanupArrayStorage = 2
End Function

Function IrOpConstant() As Long
    IrOpConstant = 1
End Function

Function IrOpDefaultValue() As Long
    IrOpDefaultValue = 2
End Function

Function IrOpLoad() As Long
    IrOpLoad = 3
End Function

Function IrOpStore() As Long
    IrOpStore = 4
End Function

Function IrOpAddress() As Long
    IrOpAddress = 5
End Function

Function IrOpConvert() As Long
    IrOpConvert = 6
End Function

Function IrOpCopyValue() As Long
    IrOpCopyValue = 7
End Function

Function IrOpCheckedAdd() As Long
    IrOpCheckedAdd = 10
End Function

Function IrOpCheckedSubtract() As Long
    IrOpCheckedSubtract = 11
End Function

Function IrOpCheckedMultiply() As Long
    IrOpCheckedMultiply = 12
End Function

Function IrOpCheckedNegate() As Long
    IrOpCheckedNegate = 13
End Function

Function IrOpCheckedDivide() As Long
    IrOpCheckedDivide = 14
End Function

Function IrOpCheckedRemainder() As Long
    IrOpCheckedRemainder = 15
End Function

Function IrOpCompare() As Long
    IrOpCompare = 16
End Function

Function IrOpBoolean() As Long
    IrOpBoolean = 17
End Function

Function IrOpConcatenate() As Long
    IrOpConcatenate = 18
End Function

Function IrOpArrayAddress() As Long
    IrOpArrayAddress = 19
End Function

Function IrOpArrayLoad() As Long
    IrOpArrayLoad = 20
End Function

Function IrOpArrayStore() As Long
    IrOpArrayStore = 21
End Function

Function IrOpArrayResize() As Long
    IrOpArrayResize = 22
End Function

Function IrOpArrayLowerBound() As Long
    IrOpArrayLowerBound = 23
End Function

Function IrOpArrayUpperBound() As Long
    IrOpArrayUpperBound = 24
End Function

Function IrOpFieldAddress() As Long
    IrOpFieldAddress = 25
End Function

Function IrOpPrint() As Long
    IrOpPrint = 26
End Function

Function IrOpCall() As Long
    IrOpCall = 30
End Function

Function IrOpBranch() As Long
    IrOpBranch = 31
End Function

Function IrOpConditionalBranch() As Long
    IrOpConditionalBranch = 32
End Function

Function IrOpReturn() As Long
    IrOpReturn = 33
End Function

Function IrOpErrorTest() As Long
    IrOpErrorTest = 40
End Function

Function IrOpErrorSet() As Long
    IrOpErrorSet = 41
End Function

Function IrOpErrorClear() As Long
    IrOpErrorClear = 42
End Function

Function IrOpCleanupBegin() As Long
    IrOpCleanupBegin = 50
End Function

Function IrOpCleanupEnd() As Long
    IrOpCleanupEnd = 51
End Function

Function NextIrCapacity(ByVal CurrentCapacity As Long) As Long
    Dim Result As Long = 64
    If CurrentCapacity > 0 Then
        Result = CurrentCapacity * 2
    End If
    If Result > LimitIrRecords() Then
        Result = LimitIrRecords()
    End If
    NextIrCapacity = Result
End Function

Function AppendIrLocation(ByRef Items() As IrLocation, ByRef Count As Long, ByRef Capacity As Long, ByVal SourceId As Long, ByVal StartByte As Long, ByVal ByteLength As Long, ByVal LineNumber As Long, ByVal ColumnNumber As Long, ByVal SyntaxNode As Long, ByVal Flags As Long) As Long
    If Count >= LimitIrRecords() Then
        AppendIrLocation = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = NextIrCapacity(Capacity)
        If Capacity = 0 Then
            ReDim Items(NewCapacity - 1)
        Else
            ReDim Preserve Items(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Dim Result As Long = Count
    Items(Result).StableId = Result + 1
    Items(Result).SourceId = SourceId
    Items(Result).StartByte = StartByte
    Items(Result).ByteLength = ByteLength
    Items(Result).LineNumber = LineNumber
    Items(Result).ColumnNumber = ColumnNumber
    Items(Result).SyntaxNode = SyntaxNode
    Items(Result).Flags = Flags
    Count = Count + 1
    AppendIrLocation = Result
End Function

Function AppendIrGlobal(ByRef Items() As IrGlobal, ByRef Count As Long, ByRef Capacity As Long, ByVal SymbolIndex As Long, ByVal TypeIndex As Long, ByVal StorageIndex As Long, ByVal InitializerValue As Long, ByVal Flags As Long, ByVal LocationIndex As Long) As Long
    If Count >= LimitIrRecords() Then
        AppendIrGlobal = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = NextIrCapacity(Capacity)
        If Capacity = 0 Then
            ReDim Items(NewCapacity - 1)
        Else
            ReDim Preserve Items(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Dim Result As Long = Count
    Items(Result).StableId = Result + 1
    Items(Result).SymbolIndex = SymbolIndex
    Items(Result).TypeIndex = TypeIndex
    Items(Result).StorageIndex = StorageIndex
    Items(Result).InitializerValue = InitializerValue
    Items(Result).Flags = Flags
    Items(Result).LocationIndex = LocationIndex
    Count = Count + 1
    AppendIrGlobal = Result
End Function

Function AppendIrFunction(ByRef Items() As IrFunction, ByRef Count As Long, ByRef Capacity As Long, ByVal SymbolIndex As Long, ByVal FunctionName As String, ByVal ResultType As Long, ByVal Flags As Long, ByVal LocationIndex As Long) As Long
    If Count >= LimitIrRecords() Then
        AppendIrFunction = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = NextIrCapacity(Capacity)
        If Capacity = 0 Then
            ReDim Items(NewCapacity - 1)
        Else
            ReDim Preserve Items(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Dim Result As Long = Count
    Items(Result).StableId = Result + 1
    Items(Result).SymbolIndex = SymbolIndex
    Items(Result).FunctionName = FunctionName
    Items(Result).ResultType = ResultType
    Items(Result).EntryBlock = -1
    Items(Result).ReturnBlock = -1
    Items(Result).FirstParameter = -1
    Items(Result).ParameterCount = 0
    Items(Result).FirstStorage = -1
    Items(Result).StorageCount = 0
    Items(Result).FirstBlock = -1
    Items(Result).BlockCount = 0
    Items(Result).Flags = Flags
    Items(Result).LocationIndex = LocationIndex
    Count = Count + 1
    AppendIrFunction = Result
End Function

Function AppendIrParameter(ByRef Items() As IrParameter, ByRef Count As Long, ByRef Capacity As Long, ByVal FunctionIndex As Long, ByVal SymbolIndex As Long, ByVal TypeIndex As Long, ByVal StorageIndex As Long, ByVal Ordinal As Long, ByVal PassingMode As Long, ByVal Flags As Long, ByVal LocationIndex As Long) As Long
    If Count >= LimitIrRecords() Then
        AppendIrParameter = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = NextIrCapacity(Capacity)
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
    Items(Result).SymbolIndex = SymbolIndex
    Items(Result).TypeIndex = TypeIndex
    Items(Result).StorageIndex = StorageIndex
    Items(Result).Ordinal = Ordinal
    Items(Result).PassingMode = PassingMode
    Items(Result).Flags = Flags
    Items(Result).LocationIndex = LocationIndex
    Count = Count + 1
    AppendIrParameter = Result
End Function

Function AppendIrStorage(ByRef Items() As IrStorage, ByRef Count As Long, ByRef Capacity As Long, ByVal FunctionIndex As Long, ByVal SymbolIndex As Long, ByVal TypeIndex As Long, ByVal StorageKind As Long, ByVal Flags As Long, ByVal LocationIndex As Long) As Long
    If Count >= LimitIrRecords() Then
        AppendIrStorage = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = NextIrCapacity(Capacity)
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
    Items(Result).SymbolIndex = SymbolIndex
    Items(Result).TypeIndex = TypeIndex
    Items(Result).StorageKind = StorageKind
    Items(Result).Flags = Flags
    Items(Result).LocationIndex = LocationIndex
    Count = Count + 1
    AppendIrStorage = Result
End Function

Function AppendIrBlock(ByRef Items() As IrBlock, ByRef Count As Long, ByRef Capacity As Long, ByVal FunctionIndex As Long, ByVal BlockOrdinal As Long, ByVal Flags As Long, ByVal LocationIndex As Long) As Long
    If Count >= LimitIrRecords() Then
        AppendIrBlock = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = NextIrCapacity(Capacity)
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
    Items(Result).BlockOrdinal = BlockOrdinal
    Items(Result).FirstInstruction = -1
    Items(Result).InstructionCount = 0
    Items(Result).Flags = Flags
    Items(Result).LocationIndex = LocationIndex
    Count = Count + 1
    AppendIrBlock = Result
End Function

Function AppendIrInstruction(ByRef Items() As IrInstruction, ByRef Count As Long, ByRef Capacity As Long, ByVal FunctionIndex As Long, ByVal BlockIndex As Long, ByVal Opcode As Long, ByVal ResultValue As Long, ByVal ResultType As Long, ByVal PrimaryTarget As Long, ByVal SecondaryTarget As Long, ByVal FailureTarget As Long, ByVal CleanupDepth As Long, ByVal SymbolIndex As Long, ByVal Flags As Long, ByVal ImmediateText As String, ByVal LocationIndex As Long) As Long
    If Count >= LimitIrRecords() Then
        AppendIrInstruction = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = NextIrCapacity(Capacity)
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
    Items(Result).Opcode = Opcode
    Items(Result).ResultValue = ResultValue
    Items(Result).ResultType = ResultType
    Items(Result).FirstOperand = -1
    Items(Result).OperandCount = 0
    Items(Result).PrimaryTarget = PrimaryTarget
    Items(Result).SecondaryTarget = SecondaryTarget
    Items(Result).FailureTarget = FailureTarget
    Items(Result).CleanupDepth = CleanupDepth
    Items(Result).SymbolIndex = SymbolIndex
    Items(Result).Flags = Flags
    Items(Result).ImmediateText = ImmediateText
    Items(Result).LocationIndex = LocationIndex
    Count = Count + 1
    AppendIrInstruction = Result
End Function

Function AppendIrOperand(ByRef Items() As IrOperand, ByRef Count As Long, ByRef Capacity As Long, ByVal InstructionIndex As Long, ByVal Ordinal As Long, ByVal OperandKind As Long, ByVal ReferencedIndex As Long, ByVal ImmediateText As String) As Long
    If Count >= LimitIrRecords() Then
        AppendIrOperand = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = NextIrCapacity(Capacity)
        If Capacity = 0 Then
            ReDim Items(NewCapacity - 1)
        Else
            ReDim Preserve Items(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Dim Result As Long = Count
    Items(Result).StableId = Result + 1
    Items(Result).InstructionIndex = InstructionIndex
    Items(Result).Ordinal = Ordinal
    Items(Result).OperandKind = OperandKind
    Items(Result).ReferencedIndex = ReferencedIndex
    Items(Result).ImmediateText = ImmediateText
    Count = Count + 1
    AppendIrOperand = Result
End Function

Function AppendIrValue(ByRef Items() As IrValue, ByRef Count As Long, ByRef Capacity As Long, ByVal FunctionIndex As Long, ByVal TypeIndex As Long, ByVal DefinitionInstruction As Long, ByVal ValueKind As Long, ByVal Flags As Long, ByVal LocationIndex As Long) As Long
    If Count >= LimitIrRecords() Then
        AppendIrValue = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = NextIrCapacity(Capacity)
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
    Items(Result).TypeIndex = TypeIndex
    Items(Result).DefinitionInstruction = DefinitionInstruction
    Items(Result).ValueKind = ValueKind
    Items(Result).Flags = Flags
    Items(Result).LocationIndex = LocationIndex
    Count = Count + 1
    AppendIrValue = Result
End Function

Function AppendIrEdge(ByRef Items() As IrEdge, ByRef Count As Long, ByRef Capacity As Long, ByVal FunctionIndex As Long, ByVal FromBlock As Long, ByVal ToBlock As Long, ByVal EdgeKind As Long, ByVal ConditionValue As Long, ByVal CleanupFromDepth As Long, ByVal CleanupToDepth As Long, ByVal LocationIndex As Long) As Long
    If Count >= LimitIrRecords() Then
        AppendIrEdge = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = NextIrCapacity(Capacity)
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
    Items(Result).FromBlock = FromBlock
    Items(Result).ToBlock = ToBlock
    Items(Result).EdgeKind = EdgeKind
    Items(Result).ConditionValue = ConditionValue
    Items(Result).CleanupFromDepth = CleanupFromDepth
    Items(Result).CleanupToDepth = CleanupToDepth
    Items(Result).LocationIndex = LocationIndex
    Count = Count + 1
    AppendIrEdge = Result
End Function

Function AppendIrCleanup(ByRef Items() As IrCleanup, ByRef Count As Long, ByRef Capacity As Long, ByVal FunctionIndex As Long, ByVal RegionDepth As Long, ByVal StorageIndex As Long, ByVal CleanupKind As Long, ByVal ActivationInstruction As Long, ByVal DeactivationInstruction As Long, ByVal Flags As Long, ByVal LocationIndex As Long) As Long
    If Count >= LimitIrRecords() Then
        AppendIrCleanup = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = NextIrCapacity(Capacity)
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
    Items(Result).RegionDepth = RegionDepth
    Items(Result).StorageIndex = StorageIndex
    Items(Result).CleanupKind = CleanupKind
    Items(Result).ActivationInstruction = ActivationInstruction
    Items(Result).DeactivationInstruction = DeactivationInstruction
    Items(Result).Flags = Flags
    Items(Result).LocationIndex = LocationIndex
    Count = Count + 1
    AppendIrCleanup = Result
End Function
