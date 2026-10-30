UBE SOURCE 1 MODULE
Attribute UBE_Name = "IrTypeRelations"

Function IrTypesAreIdentityCompatible(ByVal LeftType As Long, ByVal RightType As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long) As Long
    If LeftType < 0 Or LeftType >= TypeCount Or RightType < 0 Or RightType >= TypeCount Then
        IrTypesAreIdentityCompatible = 0
        Exit Function
    End If
    Dim LeftKind As Long = Types(LeftType).TypeKind
    Dim RightKind As Long = Types(RightType).TypeKind
    Dim LeftIdentity As Long = 0
    Dim RightIdentity As Long = 0
    If LeftKind = 12 Or LeftKind = 19 Or LeftKind = 30 Or (LeftKind >= 50 And LeftKind <= 52) Then
        LeftIdentity = 1
    End If
    If RightKind = 12 Or RightKind = 19 Or RightKind = 30 Or (RightKind >= 50 And RightKind <= 52) Then
        RightIdentity = 1
    End If
    IrTypesAreIdentityCompatible = LeftIdentity And RightIdentity
End Function

Function LowerAsNewVariableInitializerToIr(ByVal VariableSymbol As Long, ByVal FunctionIndex As Long, ByVal BlockIndex As Long, ByVal FailureBlock As Long, ByVal LocationIndex As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Storages() As IrStorage, ByRef Instructions() As IrInstruction, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByRef Build As IrBuildState) As Long
    Dim NewVariableType As Long = Symbols(VariableSymbol).DeclaredType
    If NewVariableType < 0 Or NewVariableType >= TypeCount Then
        LowerAsNewVariableInitializerToIr = 0
        Exit Function
    End If
    Dim NewModuleSymbol As Long = Types(NewVariableType).TypeSymbol
    If NewModuleSymbol < 0 Or NewModuleSymbol >= SymbolCount Then
        LowerAsNewVariableInitializerToIr = 0
        Exit Function
    End If
    Dim NewInstruction As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, IrOpObjectAllocate(), NewVariableType, FailureBlock, NewModuleSymbol, 0, "", LocationIndex, Instructions, Values, Build)
    Dim NewVariableStorage As Long = FindIrStorageForSymbol(VariableSymbol, FunctionIndex, Storages, Build.StorageCount)
    Dim NewStoreInstruction As Long = AppendIrInstruction(Instructions, Build.InstructionCount, Build.InstructionCapacity, FunctionIndex, BlockIndex, IrOpStore(), -1, -1, -1, -1, -1, 0, VariableSymbol, 0, "", LocationIndex)
    If NewInstruction < 0 Or NewVariableStorage < 0 Or NewStoreInstruction < 0 Then
        LowerAsNewVariableInitializerToIr = 0
        Exit Function
    End If
    If AppendIrInstructionOperand(NewStoreInstruction, IrOperandStorage(), NewVariableStorage, "", Instructions, Operands, Build) = 0 Or AppendIrInstructionOperand(NewStoreInstruction, IrOperandValue(), Instructions(NewInstruction).ResultValue, "", Instructions, Operands, Build) = 0 Then
        LowerAsNewVariableInitializerToIr = 0
        Exit Function
    End If
    LowerAsNewVariableInitializerToIr = 1
End Function
