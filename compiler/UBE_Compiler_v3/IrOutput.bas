UBE SOURCE 1 MODULE
Attribute UBE_Name = "IrOutput"

' Records are emitted in array order. Text is UTF-8 byte hex so separators,
' line endings, locale, and arbitrary literal contents cannot alter framing.

Sub WriteIrDump(ByRef Program As IrProgram, ByRef Globals() As IrGlobal, ByVal GlobalCount As Long, ByRef Functions() As IrFunction, ByVal FunctionCount As Long, ByRef Parameters() As IrParameter, ByVal ParameterCount As Long, ByRef Storages() As IrStorage, ByVal StorageCount As Long, ByRef Blocks() As IrBlock, ByVal BlockCount As Long, ByRef Instructions() As IrInstruction, ByVal InstructionCount As Long, ByRef Operands() As IrOperand, ByVal OperandCount As Long, ByRef Values() As IrValue, ByVal ValueCount As Long, ByRef Edges() As IrEdge, ByVal EdgeCount As Long, ByRef Cleanups() As IrCleanup, ByVal CleanupCount As Long, ByRef Locations() As IrLocation, ByVal LocationCount As Long)
    Print "UBE-IR 1|language=1.0|semantic=1|target=independent"
    Print "summary|entry=" & LongToString(Program.EntryFunction) & "|globals=" & LongToString(GlobalCount) & "|functions=" & LongToString(FunctionCount) & "|parameters=" & LongToString(ParameterCount) & "|storages=" & LongToString(StorageCount) & "|blocks=" & LongToString(BlockCount) & "|instructions=" & LongToString(InstructionCount) & "|operands=" & LongToString(OperandCount) & "|values=" & LongToString(ValueCount) & "|edges=" & LongToString(EdgeCount) & "|cleanups=" & LongToString(CleanupCount) & "|locations=" & LongToString(LocationCount)
    Dim Index As Long = 0
    While Index < GlobalCount
        Print "global|" & LongToString(Globals(Index).StableId) & "|symbol=" & LongToString(Globals(Index).SymbolIndex) & "|type=" & LongToString(Globals(Index).TypeIndex) & "|storage=" & LongToString(Globals(Index).StorageIndex) & "|init=" & LongToString(Globals(Index).InitializerValue) & "|flags=" & LongToString(Globals(Index).Flags) & "|loc=" & LongToString(Globals(Index).LocationIndex)
        Index = Index + 1
    Wend
    Index = 0
    While Index < FunctionCount
        Print "function|" & LongToString(Functions(Index).StableId) & "|symbol=" & LongToString(Functions(Index).SymbolIndex) & "|name=" & HexEncode(Functions(Index).FunctionName) & "|result=" & LongToString(Functions(Index).ResultType) & "|entry=" & LongToString(Functions(Index).EntryBlock) & "|return=" & LongToString(Functions(Index).ReturnBlock) & "|parameters=" & LongToString(Functions(Index).FirstParameter) & ":" & LongToString(Functions(Index).ParameterCount) & "|storages=" & LongToString(Functions(Index).FirstStorage) & ":" & LongToString(Functions(Index).StorageCount) & "|blocks=" & LongToString(Functions(Index).FirstBlock) & ":" & LongToString(Functions(Index).BlockCount) & "|flags=" & LongToString(Functions(Index).Flags) & "|loc=" & LongToString(Functions(Index).LocationIndex)
        Index = Index + 1
    Wend
    Index = 0
    While Index < ParameterCount
        Print "parameter|" & LongToString(Parameters(Index).StableId) & "|function=" & LongToString(Parameters(Index).FunctionIndex) & "|symbol=" & LongToString(Parameters(Index).SymbolIndex) & "|type=" & LongToString(Parameters(Index).TypeIndex) & "|storage=" & LongToString(Parameters(Index).StorageIndex) & "|ordinal=" & LongToString(Parameters(Index).Ordinal) & "|mode=" & LongToString(Parameters(Index).PassingMode) & "|flags=" & LongToString(Parameters(Index).Flags) & "|loc=" & LongToString(Parameters(Index).LocationIndex)
        Index = Index + 1
    Wend
    Index = 0
    While Index < StorageCount
        Print "storage|" & LongToString(Storages(Index).StableId) & "|function=" & LongToString(Storages(Index).FunctionIndex) & "|symbol=" & LongToString(Storages(Index).SymbolIndex) & "|type=" & LongToString(Storages(Index).TypeIndex) & "|kind=" & LongToString(Storages(Index).StorageKind) & "|flags=" & LongToString(Storages(Index).Flags) & "|loc=" & LongToString(Storages(Index).LocationIndex)
        Index = Index + 1
    Wend
    Index = 0
    While Index < BlockCount
        Print "block|" & LongToString(Blocks(Index).StableId) & "|function=" & LongToString(Blocks(Index).FunctionIndex) & "|ordinal=" & LongToString(Blocks(Index).BlockOrdinal) & "|instructions=" & LongToString(Blocks(Index).FirstInstruction) & ":" & LongToString(Blocks(Index).InstructionCount) & "|flags=" & LongToString(Blocks(Index).Flags) & "|loc=" & LongToString(Blocks(Index).LocationIndex)
        Index = Index + 1
    Wend
    Index = 0
    While Index < InstructionCount
        Print "instruction|" & LongToString(Instructions(Index).StableId) & "|function=" & LongToString(Instructions(Index).FunctionIndex) & "|block=" & LongToString(Instructions(Index).BlockIndex) & "|op=" & LongToString(Instructions(Index).Opcode) & "|result=" & LongToString(Instructions(Index).ResultValue) & ":" & LongToString(Instructions(Index).ResultType) & "|operands=" & LongToString(Instructions(Index).FirstOperand) & ":" & LongToString(Instructions(Index).OperandCount) & "|targets=" & LongToString(Instructions(Index).PrimaryTarget) & ":" & LongToString(Instructions(Index).SecondaryTarget) & ":" & LongToString(Instructions(Index).FailureTarget) & "|cleanup=" & LongToString(Instructions(Index).CleanupDepth) & "|symbol=" & LongToString(Instructions(Index).SymbolIndex) & "|flags=" & LongToString(Instructions(Index).Flags) & "|immediate=" & HexEncode(Instructions(Index).ImmediateText) & "|loc=" & LongToString(Instructions(Index).LocationIndex)
        Index = Index + 1
    Wend
    Index = 0
    While Index < OperandCount
        Print "operand|" & LongToString(Operands(Index).StableId) & "|instruction=" & LongToString(Operands(Index).InstructionIndex) & "|ordinal=" & LongToString(Operands(Index).Ordinal) & "|kind=" & LongToString(Operands(Index).OperandKind) & "|reference=" & LongToString(Operands(Index).ReferencedIndex) & "|immediate=" & HexEncode(Operands(Index).ImmediateText)
        Index = Index + 1
    Wend
    Index = 0
    While Index < ValueCount
        Print "value|" & LongToString(Values(Index).StableId) & "|function=" & LongToString(Values(Index).FunctionIndex) & "|type=" & LongToString(Values(Index).TypeIndex) & "|definition=" & LongToString(Values(Index).DefinitionInstruction) & "|kind=" & LongToString(Values(Index).ValueKind) & "|flags=" & LongToString(Values(Index).Flags) & "|loc=" & LongToString(Values(Index).LocationIndex)
        Index = Index + 1
    Wend
    Index = 0
    While Index < EdgeCount
        Print "edge|" & LongToString(Edges(Index).StableId) & "|function=" & LongToString(Edges(Index).FunctionIndex) & "|from=" & LongToString(Edges(Index).FromBlock) & "|to=" & LongToString(Edges(Index).ToBlock) & "|kind=" & LongToString(Edges(Index).EdgeKind) & "|condition=" & LongToString(Edges(Index).ConditionValue) & "|cleanup=" & LongToString(Edges(Index).CleanupFromDepth) & ":" & LongToString(Edges(Index).CleanupToDepth) & "|loc=" & LongToString(Edges(Index).LocationIndex)
        Index = Index + 1
    Wend
    Index = 0
    While Index < CleanupCount
        Print "cleanup|" & LongToString(Cleanups(Index).StableId) & "|function=" & LongToString(Cleanups(Index).FunctionIndex) & "|depth=" & LongToString(Cleanups(Index).RegionDepth) & "|storage=" & LongToString(Cleanups(Index).StorageIndex) & "|kind=" & LongToString(Cleanups(Index).CleanupKind) & "|active=" & LongToString(Cleanups(Index).ActivationInstruction) & ":" & LongToString(Cleanups(Index).DeactivationInstruction) & "|flags=" & LongToString(Cleanups(Index).Flags) & "|loc=" & LongToString(Cleanups(Index).LocationIndex)
        Index = Index + 1
    Wend
    Index = 0
    While Index < LocationCount
        Print "location|" & LongToString(Locations(Index).StableId) & "|source=" & LongToString(Locations(Index).SourceId) & "|range=" & LongToString(Locations(Index).StartByte) & ":" & LongToString(Locations(Index).ByteLength) & "|line=" & LongToString(Locations(Index).LineNumber) & ":" & LongToString(Locations(Index).ColumnNumber) & "|syntax=" & LongToString(Locations(Index).SyntaxNode) & "|flags=" & LongToString(Locations(Index).Flags)
        Index = Index + 1
    Wend
End Sub
