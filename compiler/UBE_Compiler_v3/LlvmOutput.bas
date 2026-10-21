UBE SOURCE 1 MODULE
Attribute UBE_Name = "LlvmOutput"

Function AppendLlvmChunk(ByRef Chunks() As String, ByRef Count As Long, ByRef Capacity As Long, ByVal Value As String) As Long
    If Count >= LimitIrRecords() Then
        AppendLlvmChunk = 0
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = 256
        If Capacity > 0 Then
            NewCapacity = Capacity * 2
        End If
        If NewCapacity > LimitIrRecords() Then
            NewCapacity = LimitIrRecords()
        End If
        If Capacity = 0 Then
            ReDim Chunks(NewCapacity - 1)
        Else
            ReDim Preserve Chunks(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Chunks(Count) = Value
    Count = Count + 1
    AppendLlvmChunk = 1
End Function

Function LlvmTypeForSemanticType(ByVal TypeIndex As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Abi As TargetAbiDescription) As String
    If TypeIndex < 0 Then
        LlvmTypeForSemanticType = "void"
        Exit Function
    End If
    Dim Classification As AbiTypeClassification
    If ClassifyTargetAbiType(TypeIndex, Types, TypeCount, Abi, Classification) = 0 Then
        LlvmTypeForSemanticType = ""
    Else
        LlvmTypeForSemanticType = Classification.LlvmType
    End If
End Function

Function LlvmZeroValue(ByVal LlvmType As String) As String
    If LlvmType = "ptr" Then
        LlvmZeroValue = "null"
    Else
        If LlvmType = "float" Or LlvmType = "double" Then
            LlvmZeroValue = "0.000000e+00"
        Else
            If StringLength(LlvmType) > 0 And StringByteAt(LlvmType, 0) = 37 Then
                LlvmZeroValue = "zeroinitializer"
            Else
                LlvmZeroValue = "0"
            End If
        End If
    End If
End Function

Function LlvmFunctionName(ByVal FunctionIndex As Long, ByRef Functions() As IrFunction, ByRef Symbols() As SemanticSymbol) As String
    If FunctionIndex < 0 Then
        LlvmFunctionName = ""
        Exit Function
    End If
    Dim SymbolIndex As Long = Functions(FunctionIndex).SymbolIndex
    If SymbolIndex < 0 Then
        LlvmFunctionName = ""
        Exit Function
    End If
    Dim ExternalName As String = LlvmBootstrapIntrinsicName(Functions(FunctionIndex).FunctionName)
    If StringLength(ExternalName) > 0 Then
        LlvmFunctionName = ExternalName
        Exit Function
    End If
    LlvmFunctionName = MangleInternalSymbol(1, Symbols(SymbolIndex).SourceId, SymbolIndex + 1)
End Function

Function LlvmClassLifecycleFunction(ByVal ModuleSymbol As Long, ByVal ProcedureName As String, ByRef Functions() As IrFunction, ByVal FunctionCount As Long, ByRef Symbols() As SemanticSymbol) As Long
    Dim Index As Long = 0
    While Index < FunctionCount
        Dim SymbolIndex As Long = Functions(Index).SymbolIndex
        If SymbolIndex >= 0 Then
            If Symbols(SymbolIndex).ParentSymbol = ModuleSymbol And EqualsFolded(Symbols(SymbolIndex).SymbolName, ProcedureName) <> 0 Then
                LlvmClassLifecycleFunction = Index
                Exit Function
            End If
        End If
        Index = Index + 1
    Wend
    LlvmClassLifecycleFunction = -1
End Function

Function LlvmGlobalStorageForSymbol(ByVal SymbolIndex As Long, ByRef Storages() As IrStorage, ByVal StorageCount As Long) As Long
    Dim Index As Long = 0
    While Index < StorageCount
        If Storages(Index).StorageKind = IrStorageGlobal() And Storages(Index).SymbolIndex = SymbolIndex Then
            LlvmGlobalStorageForSymbol = Index
            Exit Function
        End If
        Index = Index + 1
    Wend
    LlvmGlobalStorageForSymbol = -1
End Function

Function LlvmBootstrapIntrinsicName(ByVal FunctionName As String) As String
    If EqualsFolded(FunctionName, "StringLength") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_string_length"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "StringByteAt") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_string_byte_at"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "StringSlice") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_string_slice_managed"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "StringIndexOf") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_string_index_of"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "StringFromByte") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_string_from_byte_managed"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "LongToString") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_long_to_string_managed"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "CommandArgumentCount") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_command_argument_count"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "CommandArgument") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_command_argument_managed"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "ReadAllText") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_read_all_text_managed"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "WriteAllText") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_write_all_text"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "StringArrayJoin") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_string_array_join_managed"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "CompilerRunTool") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_compiler_run_tool"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "CompilerDeleteFile") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_compiler_delete_file"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "UnicodeIsLetter") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_unicode_is_letter"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "UnicodeSimpleFoldCodePoint") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_unicode_simple_fold_code_point"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "ManagedCollectGarbage") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_gc_collect"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "ManagedVariantEmpty") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_variant_empty"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "ManagedVariantNull") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_variant_null"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "ManagedVariantFromLong") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_variant_from_long"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "ManagedVariantCopy") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_variant_copy"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "ManagedVariantTag") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_variant_tag"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "ManagedVariantGetLong") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_variant_get_long"
        Exit Function
    End If
    LlvmBootstrapIntrinsicName = ""
End Function

Function LlvmBlockLabel(ByVal BlockIndex As Long) As String
    LlvmBlockLabel = "b" & LongToString(BlockIndex)
End Function

Function LlvmValueName(ByVal ValueIndex As Long) As String
    LlvmValueName = "%v" & LongToString(ValueIndex)
End Function

Function LlvmStorageName(ByVal StorageIndex As Long) As String
    LlvmStorageName = "%s" & LongToString(StorageIndex)
End Function

Function LlvmGlobalName(ByVal StorageIndex As Long) As String
    LlvmGlobalName = "@ube_g" & LongToString(StorageIndex)
End Function

Function LlvmOperandAt(ByVal InstructionIndex As Long, ByVal Ordinal As Long, ByRef Instructions() As IrInstruction, ByRef Operands() As IrOperand) As Long
    If Ordinal < 0 Or Ordinal >= Instructions(InstructionIndex).OperandCount Then
        LlvmOperandAt = -1
        Exit Function
    End If
    LlvmOperandAt = Instructions(InstructionIndex).FirstOperand + Ordinal
End Function

Function LlvmValueLastUse(ByVal ValueIndex As Long, ByRef Values() As IrValue, ByRef Instructions() As IrInstruction, ByVal InstructionCount As Long, ByRef Operands() As IrOperand) As Long
    Dim Result As Long = Values(ValueIndex).DefinitionInstruction
    Dim InstructionIndex As Long = 0
    While InstructionIndex < InstructionCount
        Dim Offset As Long = 0
        While Offset < Instructions(InstructionIndex).OperandCount
            Dim OperandIndex As Long = Instructions(InstructionIndex).FirstOperand + Offset
            If Operands(OperandIndex).OperandKind = IrOperandValue() And Operands(OperandIndex).ReferencedIndex = ValueIndex Then
                Result = InstructionIndex
            End If
            Offset = Offset + 1
        Wend
        InstructionIndex = InstructionIndex + 1
    Wend
    LlvmValueLastUse = Result
End Function

Function BuildLlvmValueLastUses(ByRef Values() As IrValue, ByVal ValueCount As Long, ByRef Instructions() As IrInstruction, ByVal InstructionCount As Long, ByRef Operands() As IrOperand, ByRef LastUses() As Long) As Long
    If ValueCount <= 0 Then
        BuildLlvmValueLastUses = 1
        Exit Function
    End If
    ReDim LastUses(ValueCount - 1)
    Dim ValueIndex As Long = 0
    While ValueIndex < ValueCount
        LastUses(ValueIndex) = Values(ValueIndex).DefinitionInstruction
        ValueIndex = ValueIndex + 1
    Wend
    Dim InstructionIndex As Long = 0
    While InstructionIndex < InstructionCount
        Dim Offset As Long = 0
        While Offset < Instructions(InstructionIndex).OperandCount
            Dim OperandIndex As Long = Instructions(InstructionIndex).FirstOperand + Offset
            If Operands(OperandIndex).OperandKind = IrOperandValue() Then
                ValueIndex = Operands(OperandIndex).ReferencedIndex
                If ValueIndex >= 0 And ValueIndex < ValueCount Then
                    LastUses(ValueIndex) = InstructionIndex
                End If
            End If
            Offset = Offset + 1
        Wend
        InstructionIndex = InstructionIndex + 1
    Wend
    BuildLlvmValueLastUses = 1
End Function

Function LlvmStorageAddress(ByVal StorageIndex As Long, ByVal FunctionIndex As Long, ByRef Storages() As IrStorage, ByRef Functions() As IrFunction, ByRef Parameters() As IrParameter) As String
    If Storages(StorageIndex).StorageKind = IrStorageGlobal() Then
        LlvmStorageAddress = LlvmGlobalName(StorageIndex)
        Exit Function
    End If
    If Storages(StorageIndex).StorageKind = IrStorageParameter() Then
        Dim Offset As Long = 0
        While Offset < Functions(FunctionIndex).ParameterCount
            Dim ParameterIndex As Long = Functions(FunctionIndex).FirstParameter + Offset
            If Parameters(ParameterIndex).StorageIndex = StorageIndex Then
                If Parameters(ParameterIndex).PassingMode = IrPassingByRef() Then
                    LlvmStorageAddress = "%p" & LongToString(Offset)
                Else
                    LlvmStorageAddress = LlvmStorageName(StorageIndex)
                End If
                Exit Function
            End If
            Offset = Offset + 1
        Wend
    End If
    LlvmStorageAddress = LlvmStorageName(StorageIndex)
End Function

Function LlvmValueType(ByVal ValueIndex As Long, ByRef Values() As IrValue, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Abi As TargetAbiDescription) As String
    LlvmValueType = LlvmTypeForSemanticType(Values(ValueIndex).TypeIndex, Types, TypeCount, Abi)
End Function

Function LlvmIntegerType(ByVal LlvmType As String) As Long
    If LlvmType = "i1" Or LlvmType = "i8" Or LlvmType = "i16" Or LlvmType = "i32" Or LlvmType = "i64" Then
        LlvmIntegerType = 1
    Else
        LlvmIntegerType = 0
    End If
End Function

Function LlvmIntegerWidth(ByVal LlvmType As String) As String
    If StringLength(LlvmType) > 1 Then
        LlvmIntegerWidth = StringSlice(LlvmType, 1, StringLength(LlvmType) - 1)
    Else
        LlvmIntegerWidth = ""
    End If
End Function

Function LlvmTypeNeedsGcSlot(ByVal TypeIndex As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long) As Long
    If TypeIndex < 0 Or TypeIndex >= TypeCount Then
        LlvmTypeNeedsGcSlot = 0
        Exit Function
    End If
    Dim Kind As Long = Types(TypeIndex).TypeKind
    If Kind = 11 Or Kind = 12 Or Kind = 13 Or Kind = 30 Or Kind = 40 Or Kind = 41 Then
        LlvmTypeNeedsGcSlot = 1
        Exit Function
    End If
    If Kind >= 50 Then
        If Kind <= 52 Then
            LlvmTypeNeedsGcSlot = 1
            Exit Function
        End If
    End If
    LlvmTypeNeedsGcSlot = 0
End Function

Sub AppendLlvmValueSlotPaths(ByVal TypeIndex As Long, ByVal RootStableId As Long, ByVal IndexPath As String, ByVal Depth As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Count As Long, ByRef TextValue As String)
    If TypeIndex < 0 Or TypeIndex >= TypeCount Or Depth > 64 Then
        Exit Sub
    End If
    Dim FieldOrdinal As Long = 0
    Dim Index As Long = 0
    While Index < SymbolCount
        If Symbols(Index).ParentSymbol = Types(TypeIndex).TypeSymbol And Symbols(Index).SymbolKind = SemanticSymbolMember() Then
            Dim FieldType As Long = Symbols(Index).DeclaredType
            If FieldType = TypeIndex Or LlvmTypeNeedsGcSlot(FieldType, Types, TypeCount) <> 0 Then
                If StringLength(TextValue) > 0 Then
                    TextValue = TextValue & ", "
                End If
                TextValue = TextValue & "i64 ptrtoint (ptr getelementptr (%ube.type." & LongToString(RootStableId) & ", ptr null, " & IndexPath & ", i32 " & LongToString(FieldOrdinal) & ") to i64)"
                Count = Count + 1
            Else
                If FieldType >= 0 And FieldType < TypeCount Then
                    If Types(FieldType).TypeKind = 26 Then
                        Call AppendLlvmValueSlotPaths(FieldType, RootStableId, IndexPath & ", i32 " & LongToString(FieldOrdinal), Depth + 1, Types, TypeCount, Symbols, SymbolCount, Count, TextValue)
                    End If
                End If
            End If
            FieldOrdinal = FieldOrdinal + 1
        End If
        Index = Index + 1
    Wend
End Sub

Function LlvmElementSlotCount(ByVal TypeIndex As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long) As Long
    If LlvmTypeNeedsGcSlot(TypeIndex, Types, TypeCount) <> 0 Then
        LlvmElementSlotCount = 1
        Exit Function
    End If
    If TypeIndex < 0 Or TypeIndex >= TypeCount Or Types(TypeIndex).TypeKind <> 26 Then
        LlvmElementSlotCount = 0
        Exit Function
    End If
    Dim Count As Long = 0
    Dim IgnoredText As String = ""
    Call AppendLlvmValueSlotPaths(TypeIndex, Types(TypeIndex).StableId, "i32 0", 0, Types, TypeCount, Symbols, SymbolCount, Count, IgnoredText)
    LlvmElementSlotCount = Count
End Function

Function LlvmSignedMinimum(ByVal LlvmType As String) As String
    If LlvmType = "i8" Then
        LlvmSignedMinimum = "-128"
        Exit Function
    End If
    If LlvmType = "i16" Then
        LlvmSignedMinimum = "-32768"
        Exit Function
    End If
    If LlvmType = "i32" Then
        LlvmSignedMinimum = "-2147483648"
        Exit Function
    End If
    If LlvmType = "i64" Then
        LlvmSignedMinimum = "-9223372036854775808"
        Exit Function
    End If
    LlvmSignedMinimum = ""
End Function

Function LlvmDebugFileCount(ByVal LocationCount As Long) As Long
    If LocationCount > 0 Then
        LlvmDebugFileCount = LocationCount
    Else
        LlvmDebugFileCount = 1
    End If
End Function

Function LlvmDebugFunctionNode(ByVal FunctionIndex As Long, ByVal LocationCount As Long) As Long
    LlvmDebugFunctionNode = 5 + LlvmDebugFileCount(LocationCount) + FunctionIndex
End Function

Function LlvmDebugInstructionScopeNode(ByVal InstructionIndex As Long, ByVal LocationCount As Long, ByVal FunctionCount As Long) As Long
    LlvmDebugInstructionScopeNode = 5 + LlvmDebugFileCount(LocationCount) + FunctionCount + InstructionIndex
End Function

Function LlvmDebugInstructionLocationNode(ByVal InstructionIndex As Long, ByVal LocationCount As Long, ByVal FunctionCount As Long, ByVal InstructionCount As Long) As Long
    LlvmDebugInstructionLocationNode = 5 + LlvmDebugFileCount(LocationCount) + FunctionCount + InstructionCount + InstructionIndex
End Function

Function LlvmDebugFunctionLocationNode(ByVal FunctionIndex As Long, ByVal LocationCount As Long, ByVal FunctionCount As Long, ByVal InstructionCount As Long) As Long
    LlvmDebugFunctionLocationNode = 5 + LlvmDebugFileCount(LocationCount) + FunctionCount + InstructionCount + InstructionCount + FunctionIndex
End Function

Function AttachLlvmDebugLocation(ByVal TextValue As String, ByVal DebugNode As Long) As String
    Dim Result As String = ""
    Dim StartByte As Long = 0
    Dim ByteIndex As Long = 0
    While ByteIndex < StringLength(TextValue)
        If StringByteAt(TextValue, ByteIndex) = 10 Then
            Dim LineLength As Long = ByteIndex - StartByte
            Dim LineText As String = StringSlice(TextValue, StartByte, LineLength)
            If LineLength >= 2 And StringByteAt(LineText, 0) = 32 And StringByteAt(LineText, 1) = 32 Then
                LineText = LineText & ", !dbg !" & LongToString(DebugNode)
            End If
            Result = Result & LineText & StringFromByte(10)
            StartByte = ByteIndex + 1
        End If
        ByteIndex = ByteIndex + 1
    Wend
    If StartByte < StringLength(TextValue) Then
        Result = Result & StringSlice(TextValue, StartByte, StringLength(TextValue) - StartByte)
    End If
    AttachLlvmDebugLocation = Result
End Function

Function LlvmHexByte(ByVal Value As Long) As String
    Dim Digits As String = "0123456789ABCDEF"
    Dim HighValue As Long = 0
    Dim LowValue As Long = Value
    While LowValue >= 16
        LowValue = LowValue - 16
        HighValue = HighValue + 1
    Wend
    LlvmHexByte = StringSlice(Digits, HighValue, 1) & StringSlice(Digits, LowValue, 1)
End Function

Function LlvmStringConstantName(ByVal InstructionIndex As Long) As String
    LlvmStringConstantName = "@.ube.str." & LongToString(InstructionIndex)
End Function

Function EmitLlvmStringConstants(ByRef Abi As TargetAbiDescription, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Instructions() As IrInstruction, ByVal InstructionCount As Long, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long) As Long
    Dim InstructionIndex As Long = 0
    Dim NewLine As String = StringFromByte(10)
    While InstructionIndex < InstructionCount
        If Instructions(InstructionIndex).Opcode = IrOpConstant() Then
            If LlvmTypeForSemanticType(Instructions(InstructionIndex).ResultType, Types, TypeCount, Abi) = "ptr" Then
                Dim TextValue As String = Instructions(InstructionIndex).ImmediateText
                Dim Escaped As String = ""
                Dim ByteIndex As Long = 0
                While ByteIndex < StringLength(TextValue)
                    Escaped = Escaped & "\" & LlvmHexByte(StringByteAt(TextValue, ByteIndex))
                    ByteIndex = ByteIndex + 1
                Wend
                Escaped = Escaped & "\00"
                Dim ByteCount As Long = StringLength(TextValue) + 1
                If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, LlvmStringConstantName(InstructionIndex) & " = private unnamed_addr constant [" & LongToString(ByteCount) & " x i8] c" & StringFromByte(34) & Escaped & StringFromByte(34) & ", align 1" & NewLine) = 0 Then
                    EmitLlvmStringConstants = 0
                    Exit Function
                End If
            End If
        End If
        InstructionIndex = InstructionIndex + 1
    Wend
    If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, NewLine) = 0 Then
        EmitLlvmStringConstants = 0
        Exit Function
    End If
    EmitLlvmStringConstants = 1
End Function

Function LlvmConstantText(ByVal ImmediateText As String, ByVal LlvmType As String) As String
    If LlvmType = "i1" Then
        If EqualsFolded(ImmediateText, "True") <> 0 Then
            LlvmConstantText = "1"
        Else
            If EqualsFolded(ImmediateText, "False") <> 0 Then
                LlvmConstantText = "0"
            Else
                LlvmConstantText = ImmediateText
            End If
        End If
        Exit Function
    End If
    If LlvmType = "ptr" Then
        If EqualsFolded(ImmediateText, "Nothing") <> 0 Or EqualsFolded(ImmediateText, "Null") <> 0 Or StringLength(ImmediateText) = 0 Then
            LlvmConstantText = "null"
        Else
            LlvmConstantText = ""
        End If
        Exit Function
    End If
    LlvmConstantText = ImmediateText
End Function

Function VariantTagForSemanticKind(ByVal TypeKind As Long) As Long
    If TypeKind = 4 Then
        VariantTagForSemanticKind = 2
        Exit Function
    End If
    If TypeKind = 5 Then
        VariantTagForSemanticKind = 3
        Exit Function
    End If
    If TypeKind = 11 Or TypeKind = 40 Then
        VariantTagForSemanticKind = 4
        Exit Function
    End If
    If TypeKind = 12 Or (TypeKind >= 50 And TypeKind <= 52) Then
        VariantTagForSemanticKind = 5
        Exit Function
    End If
    If TypeKind = 1 Then
        VariantTagForSemanticKind = 6
        Exit Function
    End If
    If TypeKind = 2 Then
        VariantTagForSemanticKind = 7
        Exit Function
    End If
    If TypeKind = 3 Then
        VariantTagForSemanticKind = 8
        Exit Function
    End If
    If TypeKind = 6 Then
        VariantTagForSemanticKind = 9
        Exit Function
    End If
    If TypeKind = 7 Then
        VariantTagForSemanticKind = 10
        Exit Function
    End If
    If TypeKind = 8 Then
        VariantTagForSemanticKind = 11
        Exit Function
    End If
    If TypeKind = 10 Then
        VariantTagForSemanticKind = 12
        Exit Function
    End If
    If TypeKind = 15 Then
        VariantTagForSemanticKind = 13
        Exit Function
    End If
    If TypeKind = 16 Then
        VariantTagForSemanticKind = 14
        Exit Function
    End If
    If TypeKind = 26 Then
        VariantTagForSemanticKind = 15
        Exit Function
    End If
    If TypeKind = 41 Then
        VariantTagForSemanticKind = 16
        Exit Function
    End If
    If TypeKind = 9 Then
        VariantTagForSemanticKind = 17
        Exit Function
    End If
    VariantTagForSemanticKind = -1
End Function

Function LlvmOpcodeIsCurrentlyEmittable(ByVal Opcode As Long) As Long
    If Opcode = IrOpConstant() Or Opcode = IrOpDefaultValue() Or Opcode = IrOpLoad() Or Opcode = IrOpStore() Or Opcode = IrOpAddress() Or Opcode = IrOpArrayAddress() Or Opcode = IrOpFieldAddress() Or Opcode = IrOpConvert() Or Opcode = IrOpObjectAllocate() Then
        LlvmOpcodeIsCurrentlyEmittable = 1
        Exit Function
    End If
    If Opcode = IrOpCheckedAdd() Or Opcode = IrOpCheckedSubtract() Or Opcode = IrOpCheckedMultiply() Or Opcode = IrOpCheckedNegate() Or Opcode = IrOpCheckedDivide() Or Opcode = IrOpCheckedRemainder() Then
        LlvmOpcodeIsCurrentlyEmittable = 1
        Exit Function
    End If
    If Opcode = IrOpCompare() Or Opcode = IrOpBoolean() Or Opcode = IrOpConcatenate() Or Opcode = IrOpCall() Or Opcode = IrOpArrayResize() Or Opcode = IrOpPrint() Or Opcode = IrOpBranch() Or Opcode = IrOpConditionalBranch() Or Opcode = IrOpReturn() Then
        LlvmOpcodeIsCurrentlyEmittable = 1
    Else
        LlvmOpcodeIsCurrentlyEmittable = 0
    End If
End Function

Function ValidateLlvmFunctionAbi(ByVal FunctionIndex As Long, ByRef Abi As TargetAbiDescription, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Functions() As IrFunction, ByRef Parameters() As IrParameter, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    If Functions(FunctionIndex).ResultType >= 0 Then
        Dim ReturnClass As AbiTypeClassification
        If ClassifyTargetAbiType(Functions(FunctionIndex).ResultType, Types, TypeCount, Abi, ReturnClass) = 0 Then
            Call AddIrDiagnostic("UBE5100", "target ABI cannot classify a function result type", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            ValidateLlvmFunctionAbi = 0
            Exit Function
        End If
        ' Internal UBE calls use LLVM aggregate values for custom-type results.
        ' LLVM performs the target-specific sret classification at the native
        ' boundary, while Public Export wrappers keep aggregates opaque.
    End If
    Dim Offset As Long = 0
    While Offset < Functions(FunctionIndex).ParameterCount
        Dim ParameterIndex As Long = Functions(FunctionIndex).FirstParameter + Offset
        Dim ParameterClass As AbiTypeClassification
        If ClassifyTargetAbiType(Parameters(ParameterIndex).TypeIndex, Types, TypeCount, Abi, ParameterClass) = 0 Then
            Call AddIrDiagnostic("UBE5102", "target ABI cannot classify a function parameter type", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            ValidateLlvmFunctionAbi = 0
            Exit Function
        End If
        Offset = Offset + 1
    Wend
    ValidateLlvmFunctionAbi = 1
End Function

Function EmitLlvmAggregateDefinitions(ByRef Abi As TargetAbiDescription, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim NewLine As String = StringFromByte(10)
    Dim TypeIndex As Long = 0
    While TypeIndex < TypeCount
        If Types(TypeIndex).TypeKind = 26 Then
            Dim Definition As String = "%ube.type." & LongToString(Types(TypeIndex).StableId) & " = type { "
            Dim FieldCount As Long = 0
            Dim SymbolIndex As Long = 0
            While SymbolIndex < SymbolCount
                If Symbols(SymbolIndex).ParentSymbol = Types(TypeIndex).TypeSymbol And Symbols(SymbolIndex).SymbolKind = SemanticSymbolMember() Then
                    If FieldCount > 0 Then
                        Definition = Definition & ", "
                    End If
                    Dim FieldType As String = ""
                    If Symbols(SymbolIndex).DeclaredType = TypeIndex Then
                        FieldType = "ptr"
                    Else
                        FieldType = LlvmTypeForSemanticType(Symbols(SymbolIndex).DeclaredType, Types, TypeCount, Abi)
                    End If
                    If StringLength(FieldType) = 0 Or FieldType = "void" Then
                        Call AddIrDiagnostic("UBE5108", "custom type field has an unsupported LLVM type", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        EmitLlvmAggregateDefinitions = 0
                        Exit Function
                    End If
                    Definition = Definition & FieldType
                    FieldCount = FieldCount + 1
                End If
                SymbolIndex = SymbolIndex + 1
            Wend
            Definition = Definition & " }" & NewLine
            If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, Definition) = 0 Then
                Call AddIrDiagnostic("UBE5103", "LLVM output limit exceeded", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                EmitLlvmAggregateDefinitions = 0
                Exit Function
            End If
        End If
        If Types(TypeIndex).TypeKind >= 50 Then
        If Types(TypeIndex).TypeKind <= 52 Then
            Dim ClassDefinition As String = "%ube.class." & LongToString(Types(TypeIndex).TypeSymbol) & " = type { i64"
            Dim ClassFieldCount As Long = 0
            Dim ClassSymbol As Long = 0
            While ClassSymbol < SymbolCount
                If Symbols(ClassSymbol).ParentSymbol = Types(TypeIndex).TypeSymbol And Symbols(ClassSymbol).SymbolKind = SemanticSymbolVariable() Then
                    ClassDefinition = ClassDefinition & ", "
                    Dim ClassFieldType As String = LlvmTypeForSemanticType(Symbols(ClassSymbol).DeclaredType, Types, TypeCount, Abi)
                    If StringLength(ClassFieldType) = 0 Or ClassFieldType = "void" Then
                        Call AddIrDiagnostic("UBE5108", "class field has an unsupported LLVM type", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        EmitLlvmAggregateDefinitions = 0
                        Exit Function
                    End If
                    ClassDefinition = ClassDefinition & ClassFieldType
                    ClassFieldCount = ClassFieldCount + 1
                End If
                ClassSymbol = ClassSymbol + 1
            Wend
            If ClassFieldCount = 0 Then
                ClassDefinition = ClassDefinition & "i8"
            End If
            ClassDefinition = ClassDefinition & " }" & NewLine
            If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, ClassDefinition) = 0 Then
                Call AddIrDiagnostic("UBE5103", "LLVM class layout output limit exceeded", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                EmitLlvmAggregateDefinitions = 0
                Exit Function
            End If
        End If
        End If
        TypeIndex = TypeIndex + 1
    Wend
    EmitLlvmAggregateDefinitions = 1
End Function

Function BuildLlvmArrayAddressLine(ByVal InstructionIndex As Long, ByVal FunctionIndex As Long, ByVal FirstOperand As Long, ByVal ResultName As String, ByVal ResultType As String, ByRef Abi As TargetAbiDescription, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Functions() As IrFunction, ByRef Parameters() As IrParameter, ByRef Storages() As IrStorage, ByRef Instructions() As IrInstruction, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByVal NewLine As String, ByRef LineText As String, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim ArrayIndexOperand As Long = LlvmOperandAt(InstructionIndex, 1, Instructions, Operands)
    Dim ArrayElementTypeOperand As Long = LlvmOperandAt(InstructionIndex, 2, Instructions, Operands)
    If FirstOperand < 0 Or ArrayIndexOperand < 0 Or ArrayElementTypeOperand < 0 Or Operands(FirstOperand).OperandKind <> IrOperandStorage() Or Operands(ArrayIndexOperand).OperandKind <> IrOperandValue() Or Operands(ArrayElementTypeOperand).OperandKind <> IrOperandType() Then
        Call AddIrDiagnostic("UBE5108", "array-address IR instruction has invalid operands or result type", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        BuildLlvmArrayAddressLine = 0
        Exit Function
    End If
    Dim ArrayIndexValue As Long = Operands(ArrayIndexOperand).ReferencedIndex
    If LlvmValueType(ArrayIndexValue, Values, Types, TypeCount, Abi) <> "i32" Then
        Call AddIrDiagnostic("UBE5108", "array-address index is not a Long value", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        BuildLlvmArrayAddressLine = 0
        Exit Function
    End If
    Dim ArrayBaseName As String = "%array" & LongToString(InstructionIndex)
    LineText = "  " & ArrayBaseName & " = load ptr, ptr " & LlvmStorageAddress(Operands(FirstOperand).ReferencedIndex, FunctionIndex, Storages, Functions, Parameters) & NewLine
    LineText = LineText & "  " & ResultName & " = call ptr @ube_array_element(ptr " & ArrayBaseName & ", i32 " & LlvmValueName(ArrayIndexValue) & ")" & NewLine
    BuildLlvmArrayAddressLine = 1
End Function

Function BuildLlvmFieldAddressLine(ByVal InstructionIndex As Long, ByVal FunctionIndex As Long, ByVal FirstOperand As Long, ByVal ResultName As String, ByVal ResultType As String, ByRef Abi As TargetAbiDescription, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Functions() As IrFunction, ByRef Parameters() As IrParameter, ByRef Storages() As IrStorage, ByRef Instructions() As IrInstruction, ByRef Operands() As IrOperand, ByVal NewLine As String, ByRef LineText As String, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim FieldTypeOperand As Long = LlvmOperandAt(InstructionIndex, 1, Instructions, Operands)
    Dim FieldOrdinalOperand As Long = LlvmOperandAt(InstructionIndex, 2, Instructions, Operands)
    If FirstOperand < 0 Or FieldTypeOperand < 0 Or FieldOrdinalOperand < 0 Or Operands(FieldTypeOperand).OperandKind <> IrOperandType() Or Operands(FieldOrdinalOperand).OperandKind <> IrOperandInteger() Then
        Call AddIrDiagnostic("UBE5108", "field-address IR instruction has invalid operands or result type", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        BuildLlvmFieldAddressLine = 0
        Exit Function
    End If
    Dim FieldBaseType As Long = Operands(FieldTypeOperand).ReferencedIndex
    Dim AggregateType As String = LlvmTypeForSemanticType(FieldBaseType, Types, TypeCount, Abi)
    Dim IsObjectField As Long = 0
    If FieldBaseType >= 0 And FieldBaseType < TypeCount Then
        If Types(FieldBaseType).TypeKind >= 50 Then
            If Types(FieldBaseType).TypeKind <= 52 Then
                IsObjectField = 1
                AggregateType = "%ube.class." & LongToString(Types(FieldBaseType).TypeSymbol)
            End If
        End If
    End If
    If StringLength(AggregateType) = 0 Or StringByteAt(AggregateType, 0) <> 37 Then
        Call AddIrDiagnostic("UBE5108", "field-address base is not an aggregate type", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        BuildLlvmFieldAddressLine = 0
        Exit Function
    End If
    Dim FieldBaseAddress As String = ""
    If Operands(FirstOperand).OperandKind = IrOperandStorage() Then
        FieldBaseAddress = LlvmStorageAddress(Operands(FirstOperand).ReferencedIndex, FunctionIndex, Storages, Functions, Parameters)
    Else
        If Operands(FirstOperand).OperandKind = IrOperandValue() Then
            FieldBaseAddress = LlvmValueName(Operands(FirstOperand).ReferencedIndex)
        End If
    End If
    If StringLength(FieldBaseAddress) = 0 Then
        Call AddIrDiagnostic("UBE5108", "field-address base is neither storage nor an address value", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        BuildLlvmFieldAddressLine = 0
        Exit Function
    End If
    If IsObjectField <> 0 And Operands(FirstOperand).OperandKind = IrOperandStorage() Then
        Dim ObjectBaseName As String = "%objectbase" & LongToString(InstructionIndex)
        Dim FieldBaseStorage As Long = Operands(FirstOperand).ReferencedIndex
        Dim FieldBaseSymbol As Long = Storages(FieldBaseStorage).SymbolIndex
        If FieldBaseSymbol >= 0 And (Symbols(FieldBaseSymbol).Flags And 16) <> 0 Then
            LineText = "  " & ObjectBaseName & " = call ptr @ube_object_lazy_ensure(ptr " & FieldBaseAddress & ", ptr @ube.object.layout." & LongToString(Types(FieldBaseType).TypeSymbol) & ", ptr @ube.object.initialize." & LongToString(Types(FieldBaseType).TypeSymbol) & ")" & NewLine
        Else
            LineText = "  " & ObjectBaseName & " = load ptr, ptr " & FieldBaseAddress & NewLine
        End If
        FieldBaseAddress = ObjectBaseName
    End If
    If IsObjectField = 0 And FieldBaseType >= 0 And FieldBaseType < TypeCount Then
        If Types(FieldBaseType).TypeKind = 26 Then
            Dim SoughtFieldOrdinal As Long = Operands(FieldOrdinalOperand).ReferencedIndex
            Dim CurrentFieldOrdinal As Long = 0
            Dim FieldSymbol As Long = 0
            Dim IsRecursiveField As Long = 0
            While FieldSymbol < SymbolCount
                If Symbols(FieldSymbol).ParentSymbol = Types(FieldBaseType).TypeSymbol And Symbols(FieldSymbol).SymbolKind = SemanticSymbolMember() Then
                    If CurrentFieldOrdinal = SoughtFieldOrdinal And Symbols(FieldSymbol).DeclaredType = FieldBaseType Then
                        IsRecursiveField = 1
                    End If
                    CurrentFieldOrdinal = CurrentFieldOrdinal + 1
                End If
                FieldSymbol = FieldSymbol + 1
            Wend
            If IsRecursiveField <> 0 Then
                Dim RecursiveSlotName As String = "%recursive.slot" & LongToString(InstructionIndex)
                LineText = LineText & "  " & RecursiveSlotName & " = getelementptr inbounds " & AggregateType & ", ptr " & FieldBaseAddress & ", i32 0, i32 " & LongToString(SoughtFieldOrdinal) & NewLine
                LineText = LineText & "  " & ResultName & " = call ptr @ube_recursive_value_ensure(ptr " & RecursiveSlotName & ", ptr @ube.value.layout." & LongToString(Types(FieldBaseType).TypeSymbol) & ")" & NewLine
                BuildLlvmFieldAddressLine = 1
                Exit Function
            End If
        End If
    End If
    Dim EmittedFieldOrdinal As Long = Operands(FieldOrdinalOperand).ReferencedIndex
    If IsObjectField <> 0 Then
        EmittedFieldOrdinal = EmittedFieldOrdinal + 1
    End If
    LineText = LineText & "  " & ResultName & " = getelementptr inbounds " & AggregateType & ", ptr " & FieldBaseAddress & ", i32 0, i32 " & LongToString(EmittedFieldOrdinal) & NewLine
    BuildLlvmFieldAddressLine = 1
End Function

Function BuildInterfaceCallLlvm(ByVal InstructionIndex As Long, ByVal ReceiverType As Long, ByVal ReceiverName As String, ByVal CalledFunction As Long, ByVal CalledType As String, ByVal ResultName As String, ByVal CallArguments As String, ByVal ReceiverBefore As String, ByRef Abi As TargetAbiDescription, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Functions() As IrFunction, ByVal FunctionCount As Long, ByRef Storages() As IrStorage, ByVal StorageCount As Long, ByRef LineText As String, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim NewLine As String = StringFromByte(10)
    Dim InterfaceName As String = Types(ReceiverType).TypeName
    Dim CalledMemberSymbol As Long = Functions(CalledFunction).SymbolIndex
    Dim CalledMemberName As String = Symbols(CalledMemberSymbol).SymbolName
    If Symbols(CalledMemberSymbol).SymbolKind = SemanticSymbolProperty() Then
        If StringLength(Symbols(CalledMemberSymbol).ConstantText) > 0 Then
            CalledMemberName = Symbols(CalledMemberSymbol).ConstantText
        End If
    End If
    Dim InterfaceSwitch As String = ""
    Dim InterfaceCases As String = ""
    Dim InterfacePhi As String = ""
    Dim InterfaceCandidateCount As Long = 0
    Dim InterfaceSymbol As Long = 0
    While InterfaceSymbol < SymbolCount
        Dim InterfaceCandidateName As String = Symbols(InterfaceSymbol).SymbolName
        If Symbols(InterfaceSymbol).SymbolKind = SemanticSymbolProperty() Then
            If StringLength(Symbols(InterfaceSymbol).ConstantText) > 0 Then
                InterfaceCandidateName = Symbols(InterfaceSymbol).ConstantText
            End If
        End If
        If Symbols(InterfaceSymbol).SymbolKind = Symbols(CalledMemberSymbol).SymbolKind And EqualsFolded(InterfaceCandidateName, CalledMemberName) <> 0 Then
            Dim InterfaceModule As Long = Symbols(InterfaceSymbol).ParentSymbol
            If ModuleImplementsInterface(InterfaceModule, InterfaceName, Symbols, SymbolCount) <> 0 Then
                Dim InterfaceFunction As Long = SemanticFunctionIndex(InterfaceSymbol, Functions, FunctionCount)
                If InterfaceFunction >= 0 Then
                    If Functions(InterfaceFunction).ParameterCount = Functions(CalledFunction).ParameterCount And Functions(InterfaceFunction).ResultType = Functions(CalledFunction).ResultType Then
                        Dim InterfaceCaseLabel As String = "call.interface.case" & LongToString(InstructionIndex) & "_" & LongToString(InterfaceCandidateCount)
                        InterfaceSwitch = InterfaceSwitch & " i64 " & LongToString(InterfaceModule) & ", label %" & InterfaceCaseLabel & NewLine
                        InterfaceCases = InterfaceCases & InterfaceCaseLabel & ":" & NewLine
                        Dim InterfaceFieldOrdinal As Long = 0
                        Dim InterfaceFieldSymbol As Long = 0
                        Dim InterfaceAfter As String = ""
                        While InterfaceFieldSymbol < SymbolCount
                            If Symbols(InterfaceFieldSymbol).ParentSymbol = InterfaceModule And Symbols(InterfaceFieldSymbol).SymbolKind = SemanticSymbolVariable() Then
                                Dim InterfaceFieldStorage As Long = LlvmGlobalStorageForSymbol(InterfaceFieldSymbol, Storages, StorageCount)
                                If InterfaceFieldStorage >= 0 Then
                                    Dim InterfaceFieldType As String = LlvmTypeForSemanticType(Symbols(InterfaceFieldSymbol).DeclaredType, Types, TypeCount, Abi)
                                    Dim InterfaceFieldAddress As String = "%call.interface.field.address" & LongToString(InstructionIndex) & "_" & LongToString(InterfaceCandidateCount) & "_" & LongToString(InterfaceFieldOrdinal)
                                    Dim InterfaceFieldValue As String = "%call.interface.field.value" & LongToString(InstructionIndex) & "_" & LongToString(InterfaceCandidateCount) & "_" & LongToString(InterfaceFieldOrdinal)
                                    InterfaceCases = InterfaceCases & "  " & InterfaceFieldAddress & " = getelementptr inbounds %ube.class." & LongToString(InterfaceModule) & ", ptr " & ReceiverName & ", i32 0, i32 " & LongToString(InterfaceFieldOrdinal + 1) & NewLine
                                    InterfaceCases = InterfaceCases & "  " & InterfaceFieldValue & " = load " & InterfaceFieldType & ", ptr " & InterfaceFieldAddress & NewLine
                                    InterfaceCases = InterfaceCases & "  store " & InterfaceFieldType & " " & InterfaceFieldValue & ", ptr " & LlvmGlobalName(InterfaceFieldStorage) & NewLine
                                    Dim InterfaceReturnValue As String = "%call.interface.return.value" & LongToString(InstructionIndex) & "_" & LongToString(InterfaceCandidateCount) & "_" & LongToString(InterfaceFieldOrdinal)
                                    InterfaceAfter = InterfaceAfter & "  " & InterfaceReturnValue & " = load " & InterfaceFieldType & ", ptr " & LlvmGlobalName(InterfaceFieldStorage) & NewLine
                                    InterfaceAfter = InterfaceAfter & "  store " & InterfaceFieldType & " " & InterfaceReturnValue & ", ptr " & InterfaceFieldAddress & NewLine
                                End If
                                InterfaceFieldOrdinal = InterfaceFieldOrdinal + 1
                            End If
                            InterfaceFieldSymbol = InterfaceFieldSymbol + 1
                        Wend
                        Dim InterfaceResult As String = "%call.interface.result" & LongToString(InstructionIndex) & "_" & LongToString(InterfaceCandidateCount)
                        InterfaceCases = InterfaceCases & "  "
                        If CalledType <> "void" Then
                            InterfaceCases = InterfaceCases & InterfaceResult & " = "
                        End If
                        InterfaceCases = InterfaceCases & "call " & CalledType & " @" & LlvmFunctionName(InterfaceFunction, Functions, Symbols) & "(" & CallArguments & ")" & NewLine
                        InterfaceCases = InterfaceCases & InterfaceAfter & "  br label %call.interface.merge" & LongToString(InstructionIndex) & NewLine
                        If CalledType <> "void" Then
                            If StringLength(InterfacePhi) > 0 Then
                                InterfacePhi = InterfacePhi & ", "
                            End If
                            InterfacePhi = InterfacePhi & "[ " & InterfaceResult & ", %" & InterfaceCaseLabel & " ]"
                        End If
                        InterfaceCandidateCount = InterfaceCandidateCount + 1
                    End If
                End If
            End If
        End If
        InterfaceSymbol = InterfaceSymbol + 1
    Wend
    If InterfaceCandidateCount = 0 Then
        Call AddIrDiagnostic("UBE5108", "interface call has no compatible implementation", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        BuildInterfaceCallLlvm = 0
        Exit Function
    End If
    Dim InterfaceTypeValue As String = "%call.interface.type" & LongToString(InstructionIndex)
    Dim InterfaceDefaultLabel As String = "call.interface.default" & LongToString(InstructionIndex)
    LineText = ReceiverBefore
    LineText = LineText & "  " & InterfaceTypeValue & " = call i64 @ube_object_type_id(ptr " & ReceiverName & ")" & NewLine
    LineText = LineText & " switch i64 " & InterfaceTypeValue & ", label %" & InterfaceDefaultLabel & " [" & NewLine & InterfaceSwitch & " ]" & NewLine
    LineText = LineText & InterfaceCases & InterfaceDefaultLabel & ":" & NewLine
    LineText = LineText & "  br label %call.interface.merge" & LongToString(InstructionIndex) & NewLine
    LineText = LineText & "call.interface.merge" & LongToString(InstructionIndex) & ":" & NewLine
    If CalledType <> "void" Then
        LineText = LineText & "  " & ResultName & " = phi " & CalledType & " " & InterfacePhi & ", [ zeroinitializer, %" & InterfaceDefaultLabel & " ]" & NewLine
    End If
    BuildInterfaceCallLlvm = 1
End Function

Function EmitIrInstructionToLlvm(ByVal InstructionIndex As Long, ByVal DebugNode As Long, ByRef Abi As TargetAbiDescription, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Functions() As IrFunction, ByVal FunctionCount As Long, ByRef Parameters() As IrParameter, ByRef Storages() As IrStorage, ByVal StorageCount As Long, ByRef Instructions() As IrInstruction, ByVal InstructionCount As Long, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByRef Cleanups() As IrCleanup, ByVal CleanupCount As Long, ByVal ReturnType As String, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim NewLine As String = StringFromByte(10)
    Dim Opcode As Long = Instructions(InstructionIndex).Opcode
    Dim FunctionIndex As Long = Instructions(InstructionIndex).FunctionIndex
    Dim ResultName As String = LlvmValueName(Instructions(InstructionIndex).ResultValue)
    Dim ResultType As String = LlvmTypeForSemanticType(Instructions(InstructionIndex).ResultType, Types, TypeCount, Abi)
    Dim FirstOperand As Long = LlvmOperandAt(InstructionIndex, 0, Instructions, Operands)
    Dim SecondOperand As Long = LlvmOperandAt(InstructionIndex, 1, Instructions, Operands)
    Dim LineText As String = ""

    If Opcode = IrOpArrayAddress() Then
        If BuildLlvmArrayAddressLine(InstructionIndex, FunctionIndex, FirstOperand, ResultName, ResultType, Abi, Types, TypeCount, Functions, Parameters, Storages, Instructions, Operands, Values, NewLine, LineText, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
            EmitIrInstructionToLlvm = 0
            Exit Function
        End If
        If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation(LineText, DebugNode)) = 0 Then
            Call AddIrDiagnostic("UBE5103", "LLVM output limit exceeded", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitIrInstructionToLlvm = 0
            Exit Function
        End If
        EmitIrInstructionToLlvm = 1
        Exit Function
    End If
    If Opcode = IrOpFieldAddress() Then
        If BuildLlvmFieldAddressLine(InstructionIndex, FunctionIndex, FirstOperand, ResultName, ResultType, Abi, Types, TypeCount, Symbols, SymbolCount, Functions, Parameters, Storages, Instructions, Operands, NewLine, LineText, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
            EmitIrInstructionToLlvm = 0
            Exit Function
        End If
        If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation(LineText, DebugNode)) = 0 Then
            Call AddIrDiagnostic("UBE5103", "LLVM output limit exceeded", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitIrInstructionToLlvm = 0
            Exit Function
        End If
        EmitIrInstructionToLlvm = 1
        Exit Function
    End If
    If Opcode = IrOpArrayResize() Then
        Dim LowerOperand As Long = LlvmOperandAt(InstructionIndex, 1, Instructions, Operands)
        Dim UpperOperand As Long = LlvmOperandAt(InstructionIndex, 2, Instructions, Operands)
        Dim ElementTypeOperand As Long = LlvmOperandAt(InstructionIndex, 3, Instructions, Operands)
        Dim PreserveOperand As Long = LlvmOperandAt(InstructionIndex, 4, Instructions, Operands)
        If FirstOperand < 0 Or LowerOperand < 0 Or UpperOperand < 0 Or ElementTypeOperand < 0 Or PreserveOperand < 0 Then
            Call AddIrDiagnostic("UBE5108", "array-resize instruction requires storage, bounds, element type, and preserve operands", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitIrInstructionToLlvm = 0
            Exit Function
        End If
        If Operands(FirstOperand).OperandKind <> IrOperandStorage() Or Operands(LowerOperand).OperandKind <> IrOperandValue() Or Operands(UpperOperand).OperandKind <> IrOperandValue() Or Operands(ElementTypeOperand).OperandKind <> IrOperandType() Or Operands(PreserveOperand).OperandKind <> IrOperandInteger() Then
            Call AddIrDiagnostic("UBE5108", "array-resize instruction has invalid operand kinds", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitIrInstructionToLlvm = 0
            Exit Function
        End If
        Dim ElementClass As AbiTypeClassification
        If ClassifyTargetAbiType(Operands(ElementTypeOperand).ReferencedIndex, Types, TypeCount, Abi, ElementClass) = 0 Then
            Call AddIrDiagnostic("UBE5108", "array-resize element type has no target ABI classification", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitIrInstructionToLlvm = 0
            Exit Function
        End If
        Dim ElementSizeText As String = ""
        If ElementClass.SizeBytes > 0 Then
            ElementSizeText = LongToString(ElementClass.SizeBytes)
        Else
            If ElementClass.ClassKind = AbiClassAggregate() And StringLength(ElementClass.LlvmType) > 0 Then
                ElementSizeText = "ptrtoint (ptr getelementptr (" & ElementClass.LlvmType & ", ptr null, i32 1) to i64)"
            End If
        End If
        If StringLength(ElementSizeText) = 0 Then
            Call AddIrDiagnostic("UBE5108", "array-resize element type has no target ABI size", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitIrInstructionToLlvm = 0
            Exit Function
        End If
        Dim ArrayStorageAddress As String = LlvmStorageAddress(Operands(FirstOperand).ReferencedIndex, FunctionIndex, Storages, Functions, Parameters)
        Dim NewArrayName As String = "%arraynew" & LongToString(InstructionIndex)
        Dim ArrayElementType As Long = Operands(ElementTypeOperand).ReferencedIndex
        Dim ElementSlotCount As Long = LlvmElementSlotCount(ArrayElementType, Types, TypeCount, Symbols, SymbolCount)
        Dim ElementSlotsPointer As String = "null"
        If ElementSlotCount > 0 And Types(ArrayElementType).TypeKind = 26 Then
            ElementSlotsPointer = "@ube.value.slots." & LongToString(Types(ArrayElementType).TypeSymbol)
        End If
        LineText = "  " & NewArrayName & " = call ptr @ube_array_redim_managed(ptr " & ArrayStorageAddress & ", i32 " & LlvmValueName(Operands(LowerOperand).ReferencedIndex) & ", i32 " & LlvmValueName(Operands(UpperOperand).ReferencedIndex) & ", i64 " & ElementSizeText & ", i1 " & LongToString(Operands(PreserveOperand).ReferencedIndex) & ", i64 " & LongToString(ElementSlotCount) & ", ptr " & ElementSlotsPointer & ")" & NewLine
        If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation(LineText, DebugNode)) = 0 Then
            Call AddIrDiagnostic("UBE5103", "LLVM output limit exceeded", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitIrInstructionToLlvm = 0
            Exit Function
        End If
        EmitIrInstructionToLlvm = 1
        Exit Function
    End If
    If Opcode = IrOpObjectAllocate() Then
        If Instructions(InstructionIndex).ResultValue < 0 Or Instructions(InstructionIndex).SymbolIndex < 0 Then
            Call AddIrDiagnostic("UBE5108", "object allocation has no class identity or result", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitIrInstructionToLlvm = 0
            Exit Function
        End If
        Dim ObjectModule As Long = Instructions(InstructionIndex).SymbolIndex
        Dim ObjectLayoutName As String = "@ube.object.layout." & LongToString(ObjectModule)
        LineText = "  " & ResultName & " = call ptr @ube_gc_allocate_into(ptr " & ObjectLayoutName & ", ptr %gc.temp." & LongToString(Instructions(InstructionIndex).ResultValue) & ")" & NewLine
        Dim ObjectAllocationFailed As String = "%objectallocationisfailed" & LongToString(InstructionIndex)
        Dim ObjectAllocationFailure As String = "objectallocationfailed" & LongToString(InstructionIndex)
        Dim ObjectAllocationContinue As String = "objectallocationok" & LongToString(InstructionIndex)
        Dim ObjectAllocationMerge As String = "objectallocationmerge" & LongToString(InstructionIndex)
        LineText = LineText & "  " & ObjectAllocationFailed & " = icmp eq ptr " & ResultName & ", null" & NewLine
        LineText = LineText & "  br i1 " & ObjectAllocationFailed & ", label %" & ObjectAllocationFailure & ", label %" & ObjectAllocationContinue & NewLine
        LineText = LineText & ObjectAllocationContinue & ":" & NewLine
        LineText = LineText & "  store i64 " & LongToString(ObjectModule) & ", ptr " & ResultName & NewLine
        Dim ObjectFieldOrdinal As Long = 0
        Dim ObjectMember As Long = 0
        While ObjectMember < StorageCount
            If Symbols(Storages(ObjectMember).SymbolIndex).ParentSymbol = ObjectModule And Symbols(Storages(ObjectMember).SymbolIndex).SymbolKind = SemanticSymbolVariable() And Storages(ObjectMember).StorageKind = IrStorageGlobal() Then
                Dim ObjectFieldType As String = LlvmTypeForSemanticType(Storages(ObjectMember).TypeIndex, Types, TypeCount, Abi)
                LineText = LineText & "  store " & ObjectFieldType & " " & LlvmZeroValue(ObjectFieldType) & ", ptr " & LlvmGlobalName(ObjectMember) & NewLine
                ObjectFieldOrdinal = ObjectFieldOrdinal + 1
            End If
            ObjectMember = ObjectMember + 1
        Wend
        Dim InitializeFunction As Long = LlvmClassLifecycleFunction(ObjectModule, "Class_Initialize", Functions, FunctionCount, Symbols)
        If InitializeFunction >= 0 Then
            LineText = LineText & "  call void @" & LlvmFunctionName(InitializeFunction, Functions, Symbols) & "()" & NewLine
        End If
        ObjectFieldOrdinal = 0
        ObjectMember = 0
        While ObjectMember < SymbolCount
            If Symbols(ObjectMember).ParentSymbol = ObjectModule And Symbols(ObjectMember).SymbolKind = SemanticSymbolVariable() Then
                Dim ObjectFieldStorage As Long = LlvmGlobalStorageForSymbol(ObjectMember, Storages, StorageCount)
                If ObjectFieldStorage >= 0 Then
                    ObjectFieldType = LlvmTypeForSemanticType(Symbols(ObjectMember).DeclaredType, Types, TypeCount, Abi)
                    Dim ObjectFieldValue As String = "%objectfield" & LongToString(InstructionIndex) & "_" & LongToString(ObjectFieldOrdinal)
                    Dim ObjectFieldAddress As String = "%objectfieldaddress" & LongToString(InstructionIndex) & "_" & LongToString(ObjectFieldOrdinal)
                    LineText = LineText & "  " & ObjectFieldValue & " = load " & ObjectFieldType & ", ptr " & LlvmGlobalName(ObjectFieldStorage) & NewLine
                    LineText = LineText & "  " & ObjectFieldAddress & " = getelementptr inbounds %ube.class." & LongToString(ObjectModule) & ", ptr " & ResultName & ", i32 0, i32 " & LongToString(ObjectFieldOrdinal + 1) & NewLine
                    LineText = LineText & "  store " & ObjectFieldType & " " & ObjectFieldValue & ", ptr " & ObjectFieldAddress & NewLine
                End If
                ObjectFieldOrdinal = ObjectFieldOrdinal + 1
            End If
            ObjectMember = ObjectMember + 1
        Wend
        LineText = LineText & "  br label %" & ObjectAllocationMerge & NewLine
        LineText = LineText & ObjectAllocationFailure & ":" & NewLine
        LineText = LineText & "  br label %" & ObjectAllocationMerge & NewLine
        LineText = LineText & ObjectAllocationMerge & ":" & NewLine
        If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation(LineText, DebugNode)) = 0 Then
            Call AddIrDiagnostic("UBE5103", "LLVM output limit exceeded", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitIrInstructionToLlvm = 0
            Exit Function
        End If
        EmitIrInstructionToLlvm = 1
        Exit Function
    End If
    If Opcode = IrOpConcatenate() Then
        If FirstOperand < 0 Or SecondOperand < 0 Or Operands(FirstOperand).OperandKind <> IrOperandValue() Or Operands(SecondOperand).OperandKind <> IrOperandValue() Then
            Call AddIrDiagnostic("UBE5108", "concatenation instruction requires two value operands", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitIrInstructionToLlvm = 0
            Exit Function
        End If
        Dim ConcatLeft As Long = Operands(FirstOperand).ReferencedIndex
        Dim ConcatRight As Long = Operands(SecondOperand).ReferencedIndex
        LineText = "  " & ResultName & " = call ptr @ube_string_concat_managed(ptr " & LlvmValueName(ConcatLeft) & ", ptr " & LlvmValueName(ConcatRight) & ")" & NewLine
        If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation(LineText, DebugNode)) = 0 Then
            Call AddIrDiagnostic("UBE5103", "LLVM output limit exceeded", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitIrInstructionToLlvm = 0
            Exit Function
        End If
        EmitIrInstructionToLlvm = 1
        Exit Function
    End If
    If Opcode = IrOpPrint() Then
        If FirstOperand < 0 Or Operands(FirstOperand).OperandKind <> IrOperandValue() Then
            Call AddIrDiagnostic("UBE5108", "print instruction requires a value operand", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitIrInstructionToLlvm = 0
            Exit Function
        End If
        Dim PrintedValue As Long = Operands(FirstOperand).ReferencedIndex
        Dim PrintedType As String = LlvmValueType(PrintedValue, Values, Types, TypeCount, Abi)
        If PrintedType = "ptr" Then
            LineText = "  call void @ube_print_string(ptr " & LlvmValueName(PrintedValue) & ")" & NewLine
        Else
            If PrintedType = "i64" Then
                LineText = "  call void @ube_print_i64(i64 " & LlvmValueName(PrintedValue) & ")" & NewLine
            Else
                If PrintedType = "i1" Or PrintedType = "i8" Or PrintedType = "i16" Then
                    Dim PrintedWideName As String = "%printwide" & LongToString(InstructionIndex)
                    Dim PrintedExtend As String = "sext"
                    If PrintedType = "i8" Then
                        PrintedExtend = "zext"
                    End If
                    LineText = "  " & PrintedWideName & " = " & PrintedExtend & " " & PrintedType & " " & LlvmValueName(PrintedValue) & " to i32" & NewLine
                    LineText = LineText & "  call void @ube_print_i32(i32 " & PrintedWideName & ")" & NewLine
                Else
                If PrintedType = "i32" Then
                    LineText = "  call void @ube_print_i32(i32 " & LlvmValueName(PrintedValue) & ")" & NewLine
                Else
                    If PrintedType = "double" Then
                        LineText = "  call void @ube_print_f64(double " & LlvmValueName(PrintedValue) & ")" & NewLine
                    Else
                        If PrintedType = "float" Then
                            Dim PrintedDoubleName As String = "%printdouble" & LongToString(InstructionIndex)
                            LineText = "  " & PrintedDoubleName & " = fpext float " & LlvmValueName(PrintedValue) & " to double" & NewLine
                            LineText = LineText & "  call void @ube_print_f64(double " & PrintedDoubleName & ")" & NewLine
                        Else
                        Call AddIrDiagnostic("UBE5108", "print instruction has an unsupported LLVM value type", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        EmitIrInstructionToLlvm = 0
                        Exit Function
                        End If
                    End If
                End If
                End If
            End If
        End If
        LineText = LineText & "  call void @ube_print_newline()" & NewLine
        If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation(LineText, DebugNode)) = 0 Then
            Call AddIrDiagnostic("UBE5103", "LLVM output limit exceeded", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitIrInstructionToLlvm = 0
            Exit Function
        End If
        EmitIrInstructionToLlvm = 1
        Exit Function
    End If

    If Opcode = IrOpConstant() Or Opcode = IrOpDefaultValue() Then
        If Instructions(InstructionIndex).ResultValue < 0 Or StringLength(ResultType) = 0 Or ResultType = "void" Then
            Call AddIrDiagnostic("UBE5108", "constant/default IR instruction has no supported result", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitIrInstructionToLlvm = 0
            Exit Function
        End If
        Dim ConstantValue As String = LlvmZeroValue(ResultType)
        If Opcode = IrOpConstant() Then
            ConstantValue = LlvmConstantText(Instructions(InstructionIndex).ImmediateText, ResultType)
        End If
        If Opcode = IrOpConstant() And ResultType = "ptr" Then
            Dim ConstantSemanticType As Long = Instructions(InstructionIndex).ResultType
            If ConstantSemanticType >= 0 And ConstantSemanticType < TypeCount Then
                If Types(ConstantSemanticType).TypeKind = 17 Then
                    LineText = "  " & ResultName & " = call ptr @ube_variant_empty()" & NewLine
                    If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation(LineText, DebugNode)) = 0 Then
                        EmitIrInstructionToLlvm = 0
                        Exit Function
                    End If
                    EmitIrInstructionToLlvm = 1
                    Exit Function
                End If
                If Types(ConstantSemanticType).TypeKind = 18 Then
                    LineText = "  " & ResultName & " = call ptr @ube_variant_null()" & NewLine
                    If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation(LineText, DebugNode)) = 0 Then
                        EmitIrInstructionToLlvm = 0
                        Exit Function
                    End If
                    EmitIrInstructionToLlvm = 1
                    Exit Function
                End If
                If Types(ConstantSemanticType).TypeKind = 19 Or Types(ConstantSemanticType).TypeKind = 12 Or (Types(ConstantSemanticType).TypeKind >= 50 And Types(ConstantSemanticType).TypeKind <= 52) Then
                    LineText = "  " & ResultName & " = select i1 true, ptr null, ptr null" & NewLine
                    If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation(LineText, DebugNode)) = 0 Then
                        EmitIrInstructionToLlvm = 0
                        Exit Function
                    End If
                    EmitIrInstructionToLlvm = 1
                    Exit Function
                End If
            End If
            Dim StringByteCount As Long = StringLength(Instructions(InstructionIndex).ImmediateText) + 1
            LineText = "  " & ResultName & " = getelementptr inbounds [" & LongToString(StringByteCount) & " x i8], ptr " & LlvmStringConstantName(InstructionIndex) & ", i64 0, i64 0" & NewLine
            If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation(LineText, DebugNode)) = 0 Then
                Call AddIrDiagnostic("UBE5103", "LLVM output limit exceeded", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                EmitIrInstructionToLlvm = 0
                Exit Function
            End If
            EmitIrInstructionToLlvm = 1
            Exit Function
        End If
        If StringLength(ConstantValue) = 0 Or (ResultType <> "ptr" And LlvmIntegerType(ResultType) = 0 And ResultType <> "float" And ResultType <> "double" And (StringLength(ResultType) = 0 Or StringByteAt(ResultType, 0) <> 37)) Then
            Call AddIrDiagnostic("UBE5108", "LLVM writer cannot materialize this constant type", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitIrInstructionToLlvm = 0
            Exit Function
        End If
        LineText = "  " & ResultName & " = select i1 true, " & ResultType & " " & ConstantValue & ", " & ResultType & " " & ConstantValue & NewLine
    Else
        If Opcode = IrOpLoad() Then
            If FirstOperand < 0 Or Instructions(InstructionIndex).ResultValue < 0 Then
                Call AddIrDiagnostic("UBE5108", "load IR instruction has invalid operands", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                EmitIrInstructionToLlvm = 0
                Exit Function
            End If
            Dim LoadAddress As String = ""
            If Operands(FirstOperand).OperandKind = IrOperandStorage() Then
                LoadAddress = LlvmStorageAddress(Operands(FirstOperand).ReferencedIndex, FunctionIndex, Storages, Functions, Parameters)
            Else
                If Operands(FirstOperand).OperandKind = IrOperandValue() Then
                    LoadAddress = LlvmValueName(Operands(FirstOperand).ReferencedIndex)
                End If
            End If
            If StringLength(LoadAddress) = 0 Then
                Call AddIrDiagnostic("UBE5108", "load IR instruction requires a storage or address value", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                EmitIrInstructionToLlvm = 0
                Exit Function
            End If
            Dim IsLazyObjectLoad As Long = 0
            If Operands(FirstOperand).OperandKind = IrOperandStorage() Then
                Dim LoadStorage As Long = Operands(FirstOperand).ReferencedIndex
                Dim LoadSymbol As Long = Storages(LoadStorage).SymbolIndex
                If LoadSymbol >= 0 Then
                    If (Symbols(LoadSymbol).Flags And 16) <> 0 Then
                        Dim LoadSemanticType As Long = Storages(LoadStorage).TypeIndex
                        If LoadSemanticType >= 0 And LoadSemanticType < TypeCount Then
                            If Types(LoadSemanticType).TypeKind >= 50 And Types(LoadSemanticType).TypeKind <= 52 Then
                                LineText = "  " & ResultName & " = call ptr @ube_object_lazy_ensure(ptr " & LoadAddress & ", ptr @ube.object.layout." & LongToString(Types(LoadSemanticType).TypeSymbol) & ", ptr @ube.object.initialize." & LongToString(Types(LoadSemanticType).TypeSymbol) & ")" & NewLine
                                IsLazyObjectLoad = 1
                            End If
                        End If
                    End If
                End If
            End If
            If IsLazyObjectLoad = 0 Then
                LineText = "  " & ResultName & " = load " & ResultType & ", ptr " & LoadAddress & NewLine
            End If
        Else
            If Opcode = IrOpAddress() Then
                If FirstOperand < 0 Or Operands(FirstOperand).OperandKind <> IrOperandStorage() Or ResultType <> "ptr" Then
                    Call AddIrDiagnostic("UBE5108", "address IR instruction has invalid operands or result type", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    EmitIrInstructionToLlvm = 0
                    Exit Function
                End If
                Dim AddressText As String = LlvmStorageAddress(Operands(FirstOperand).ReferencedIndex, FunctionIndex, Storages, Functions, Parameters)
                LineText = "  " & ResultName & " = getelementptr i8, ptr " & AddressText & ", i64 0" & NewLine
            Else
                If Opcode = IrOpConvert() Then
                    If FirstOperand < 0 Or Operands(FirstOperand).OperandKind <> IrOperandValue() Or Instructions(InstructionIndex).ResultValue < 0 Then
                        Call AddIrDiagnostic("UBE5108", "conversion IR instruction has invalid operands", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        EmitIrInstructionToLlvm = 0
                        Exit Function
                    End If
                    Dim ConvertValue As Long = Operands(FirstOperand).ReferencedIndex
                    Dim ConvertSourceType As String = LlvmValueType(ConvertValue, Values, Types, TypeCount, Abi)
                    Dim ConvertSourceSemantic As Long = Values(ConvertValue).TypeIndex
                    Dim ConvertTargetSemantic As Long = Instructions(InstructionIndex).ResultType
                    Dim ConvertSourceKind As Long = -1
                    Dim ConvertTargetKind As Long = -1
                    If ConvertSourceSemantic >= 0 And ConvertSourceSemantic < TypeCount Then
                        ConvertSourceKind = Types(ConvertSourceSemantic).TypeKind
                    End If
                    If ConvertTargetSemantic >= 0 And ConvertTargetSemantic < TypeCount Then
                        ConvertTargetKind = Types(ConvertTargetSemantic).TypeKind
                    End If
                    Dim UsedManagedConversion As Long = 0
                    Dim VariantSourceTag As Long = VariantTagForSemanticKind(ConvertSourceKind)
                    If ConvertTargetKind = 13 And LlvmIntegerType(ConvertSourceType) <> 0 And VariantSourceTag >= 0 Then
                        Dim VariantIntegerValue As String = LlvmValueName(ConvertValue)
                        If ConvertSourceType <> "i64" Then
                            VariantIntegerValue = "%variantwide" & LongToString(InstructionIndex)
                            Dim VariantExtendOpcode As String = "sext"
                            If ConvertSourceType = "i8" Then
                                VariantExtendOpcode = "zext"
                            End If
                            LineText = "  " & VariantIntegerValue & " = " & VariantExtendOpcode & " " & ConvertSourceType & " " & LlvmValueName(ConvertValue) & " to i64" & NewLine
                        End If
                        LineText = LineText & "  " & ResultName & " = call ptr @ube_variant_from_integer(i32 " & LongToString(VariantSourceTag) & ", i64 " & VariantIntegerValue & ")" & NewLine
                        UsedManagedConversion = 1
                    End If
                    If ConvertTargetKind = 13 And (ConvertSourceType = "float" Or ConvertSourceType = "double") And VariantSourceTag >= 0 Then
                        Dim VariantFloatingValue As String = LlvmValueName(ConvertValue)
                        If ConvertSourceType = "float" Then
                            VariantFloatingValue = "%variantfloatwide" & LongToString(InstructionIndex)
                            LineText = "  " & VariantFloatingValue & " = fpext float " & LlvmValueName(ConvertValue) & " to double" & NewLine
                        End If
                        LineText = LineText & "  " & ResultName & " = call ptr @ube_variant_from_floating(i32 " & LongToString(VariantSourceTag) & ", double " & VariantFloatingValue & ")" & NewLine
                        UsedManagedConversion = 1
                    End If
                    If ConvertTargetKind = 13 And ConvertSourceKind = 13 Then
                        LineText = "  " & ResultName & " = call ptr @ube_variant_copy(ptr " & LlvmValueName(ConvertValue) & ")" & NewLine
                        UsedManagedConversion = 1
                    End If
                    If ConvertTargetKind = 13 And ConvertSourceType = "ptr" And VariantSourceTag >= 0 And ConvertSourceKind <> 13 Then
                        LineText = "  " & ResultName & " = call ptr @ube_variant_from_reference(i32 " & LongToString(VariantSourceTag) & ", ptr " & LlvmValueName(ConvertValue) & ")" & NewLine
                        UsedManagedConversion = 1
                    End If
                    If ConvertTargetKind = 4 And ConvertSourceKind = 13 Then
                        Dim VariantLongSlot As String = "%variant.long.slot" & LongToString(InstructionIndex)
                        LineText = "  " & VariantLongSlot & " = alloca i32" & NewLine
                        LineText = LineText & "  store i32 0, ptr " & VariantLongSlot & NewLine
                        LineText = LineText & "  call i32 @ube_variant_get_long(ptr " & LlvmValueName(ConvertValue) & ", ptr " & VariantLongSlot & ")" & NewLine
                        LineText = LineText & "  " & ResultName & " = load i32, ptr " & VariantLongSlot & NewLine
                        UsedManagedConversion = 1
                    End If
                    If ConvertTargetKind = 1 And ConvertSourceKind = 13 Then
                        Dim VariantBooleanSlot As String = "%variant.boolean.slot" & LongToString(InstructionIndex)
                        Dim VariantBooleanWide As String = "%variant.boolean.wide" & LongToString(InstructionIndex)
                        LineText = "  " & VariantBooleanSlot & " = alloca i32" & NewLine
                        LineText = LineText & "  store i32 0, ptr " & VariantBooleanSlot & NewLine
                        LineText = LineText & "  call i32 @ube_variant_get_boolean(ptr " & LlvmValueName(ConvertValue) & ", ptr " & VariantBooleanSlot & ")" & NewLine
                        LineText = LineText & "  " & VariantBooleanWide & " = load i32, ptr " & VariantBooleanSlot & NewLine
                        LineText = LineText & "  " & ResultName & " = icmp ne i32 " & VariantBooleanWide & ", 0" & NewLine
                        UsedManagedConversion = 1
                    End If
                    If (ConvertTargetKind = 5 Or ConvertTargetKind = 8 Or ConvertTargetKind = 15 Or ConvertTargetKind = 16) And ConvertSourceKind = 13 Then
                        Dim VariantLongLongSlot As String = "%variant.longlong.slot" & LongToString(InstructionIndex)
                        LineText = "  " & VariantLongLongSlot & " = alloca i64" & NewLine
                        LineText = LineText & "  store i64 0, ptr " & VariantLongLongSlot & NewLine
                        LineText = LineText & "  call i32 @ube_variant_get_longlong(ptr " & LlvmValueName(ConvertValue) & ", ptr " & VariantLongLongSlot & ")" & NewLine
                        LineText = LineText & "  " & ResultName & " = load i64, ptr " & VariantLongLongSlot & NewLine
                        UsedManagedConversion = 1
                    End If
                    If (ConvertTargetKind = 6 Or ConvertTargetKind = 7) And ConvertSourceKind = 13 Then
                        Dim VariantDoubleSlot As String = "%variant.double.slot" & LongToString(InstructionIndex)
                        Dim VariantDoubleValue As String = "%variant.double.value" & LongToString(InstructionIndex)
                        LineText = "  " & VariantDoubleSlot & " = alloca double" & NewLine
                        LineText = LineText & "  store double 0.0, ptr " & VariantDoubleSlot & NewLine
                        LineText = LineText & "  call i32 @ube_variant_get_double(ptr " & LlvmValueName(ConvertValue) & ", ptr " & VariantDoubleSlot & ")" & NewLine
                        LineText = LineText & "  " & VariantDoubleValue & " = load double, ptr " & VariantDoubleSlot & NewLine
                        If ConvertTargetKind = 6 Then
                            LineText = LineText & "  " & ResultName & " = fptrunc double " & VariantDoubleValue & " to float" & NewLine
                        Else
                            LineText = LineText & "  " & ResultName & " = select i1 true, double " & VariantDoubleValue & ", double " & VariantDoubleValue & NewLine
                        End If
                        UsedManagedConversion = 1
                    End If
                    If (ConvertTargetKind = 11 Or ConvertTargetKind = 40 Or ConvertTargetKind = 12 Or ConvertTargetKind = 30 Or ConvertTargetKind = 41 Or (ConvertTargetKind >= 50 And ConvertTargetKind <= 52)) And ConvertSourceKind = 13 Then
                        Dim VariantReferenceSlot As String = "%variant.reference.slot" & LongToString(InstructionIndex)
                        Dim VariantExpectedTag As Long = VariantTagForSemanticKind(ConvertTargetKind)
                        LineText = "  " & VariantReferenceSlot & " = alloca ptr" & NewLine
                        LineText = LineText & "  store ptr null, ptr " & VariantReferenceSlot & NewLine
                        LineText = LineText & "  call i32 @ube_variant_get_reference(ptr " & LlvmValueName(ConvertValue) & ", i32 " & LongToString(VariantExpectedTag) & ", ptr " & VariantReferenceSlot & ")" & NewLine
                        LineText = LineText & "  " & ResultName & " = load ptr, ptr " & VariantReferenceSlot & NewLine
                        UsedManagedConversion = 1
                    End If
                    If ConvertTargetKind = 4 And (ConvertSourceKind = 11 Or ConvertSourceKind = 40) Then
                        Dim StringLongSlot As String = "%string.long.slot" & LongToString(InstructionIndex)
                        LineText = "  " & StringLongSlot & " = alloca i32" & NewLine
                        LineText = LineText & "  store i32 0, ptr " & StringLongSlot & NewLine
                        LineText = LineText & "  call i32 @ube_checked_string_to_long(ptr " & LlvmValueName(ConvertValue) & ", ptr " & StringLongSlot & ")" & NewLine
                        LineText = LineText & "  " & ResultName & " = load i32, ptr " & StringLongSlot & NewLine
                        UsedManagedConversion = 1
                    End If
                    If (ConvertTargetKind = 11 Or ConvertTargetKind = 40) And ConvertSourceType = "i32" Then
                        LineText = "  " & ResultName & " = call ptr @ube_long_to_string_managed(i32 " & LlvmValueName(ConvertValue) & ")" & NewLine
                        UsedManagedConversion = 1
                    End If
                    If UsedManagedConversion = 0 Then
                    If ConvertSourceType = "ptr" And ResultType = "ptr" Then
                        LineText = "  " & ResultName & " = select i1 true, ptr " & LlvmValueName(ConvertValue) & ", ptr " & LlvmValueName(ConvertValue) & NewLine
                    Else
                    If LlvmIntegerType(ConvertSourceType) = 0 Or LlvmIntegerType(ResultType) = 0 Then
                        Call AddIrDiagnostic("UBE5108", "RP5 conversion instruction " & LongToString(InstructionIndex) & " from " & ConvertSourceType & " to " & ResultType & " currently requires integer types", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        EmitIrInstructionToLlvm = 0
                        Exit Function
                    End If
                    End If
                    If ConvertSourceType = ResultType Then
                        LineText = "  " & ResultName & " = select i1 true, " & ResultType & " " & LlvmValueName(ConvertValue) & ", " & ResultType & " " & LlvmValueName(ConvertValue) & NewLine
                    Else
                        If ResultType = "i1" Then
                            LineText = "  " & ResultName & " = icmp ne " & ConvertSourceType & " " & LlvmValueName(ConvertValue) & ", 0" & NewLine
                        Else
                            Dim ConvertIsWidening As Long = 0
                            If ConvertSourceType = "i1" Then
                                ConvertIsWidening = 2
                            Else
                                If ConvertSourceType = "i8" And (ResultType = "i16" Or ResultType = "i32" Or ResultType = "i64") Then
                                    ConvertIsWidening = 1
                                End If
                                If ConvertSourceType = "i16" And (ResultType = "i32" Or ResultType = "i64") Then
                                    ConvertIsWidening = 1
                                End If
                                If ConvertSourceType = "i32" And ResultType = "i64" Then
                                    ConvertIsWidening = 1
                                End If
                            End If
                            If ConvertIsWidening = 2 Then
                                LineText = "  " & ResultName & " = zext " & ConvertSourceType & " " & LlvmValueName(ConvertValue) & " to " & ResultType & NewLine
                            Else
                                If ConvertIsWidening = 1 Then
                                    LineText = "  " & ResultName & " = sext " & ConvertSourceType & " " & LlvmValueName(ConvertValue) & " to " & ResultType & NewLine
                                Else
                                    Dim ConvertWideName As String = "%wide" & LongToString(InstructionIndex)
                                    Dim ConvertFailedName As String = "%convertfail" & LongToString(InstructionIndex)
                                    Dim ConvertContinueLabel As String = "convertok" & LongToString(InstructionIndex)
                                    LineText = "  " & ResultName & " = trunc " & ConvertSourceType & " " & LlvmValueName(ConvertValue) & " to " & ResultType & NewLine
                                    LineText = LineText & "  " & ConvertWideName & " = sext " & ResultType & " " & ResultName & " to " & ConvertSourceType & NewLine
                                    LineText = LineText & "  " & ConvertFailedName & " = icmp ne " & ConvertSourceType & " " & ConvertWideName & ", " & LlvmValueName(ConvertValue) & NewLine
                                    LineText = LineText & "  br i1 " & ConvertFailedName & ", label %" & LlvmBlockLabel(Instructions(InstructionIndex).FailureTarget) & ", label %" & ConvertContinueLabel & NewLine & ConvertContinueLabel & ":" & NewLine
                                End If
                            End If
                        End If
                    End If
                    End If
                Else
                If Opcode = IrOpStore() Then
                    If FirstOperand < 0 Or SecondOperand < 0 Or Operands(SecondOperand).OperandKind <> IrOperandValue() Then
                        Call AddIrDiagnostic("UBE5108", "store IR instruction has invalid operands", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        EmitIrInstructionToLlvm = 0
                        Exit Function
                    End If
                    Dim StoredValue As Long = Operands(SecondOperand).ReferencedIndex
                    Dim StoredType As String = LlvmValueType(StoredValue, Values, Types, TypeCount, Abi)
                    Dim StoreAddress As String = ""
                    Dim StoreTargetType As Long = -1
                    If Operands(FirstOperand).OperandKind = IrOperandStorage() Then
                        StoreAddress = LlvmStorageAddress(Operands(FirstOperand).ReferencedIndex, FunctionIndex, Storages, Functions, Parameters)
                        StoreTargetType = Storages(Operands(FirstOperand).ReferencedIndex).TypeIndex
                    Else
                        If Operands(FirstOperand).OperandKind = IrOperandValue() Then
                            StoreAddress = LlvmValueName(Operands(FirstOperand).ReferencedIndex)
                            StoreTargetType = Values(Operands(FirstOperand).ReferencedIndex).TypeIndex
                        End If
                    End If
                    If StringLength(StoreAddress) = 0 Then
                        Call AddIrDiagnostic("UBE5108", "store IR instruction requires a storage or address value", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        EmitIrInstructionToLlvm = 0
                        Exit Function
                    End If
                    Dim StoredValueText As String = LlvmValueName(StoredValue)
                    Dim UsedCustomValueCopy As Long = 0
                    If StoreTargetType >= 0 And StoreTargetType < TypeCount Then
                        Dim ArrayTypesMatch As Long = IrTypesExactlyMatch(Values(StoredValue).TypeIndex, StoreTargetType, Types, TypeCount)
                        If Types(StoreTargetType).TypeKind = 41 And StoredType = "ptr" And ArrayTypesMatch <> 0 Then
                            Dim ArrayCopyElement As Long = Types(StoreTargetType).ElementType
                            Dim ArrayCopyLayout As String = "null"
                            Dim ArrayCopyRecursiveCount As Long = 0
                            Dim ArrayCopyRecursivePointer As String = "null"
                            If ArrayCopyElement >= 0 And ArrayCopyElement < TypeCount Then
                                If Types(ArrayCopyElement).TypeKind = 26 Then
                                    ArrayCopyLayout = "@ube.value.layout." & LongToString(Types(ArrayCopyElement).TypeSymbol)
                                    Dim ArrayCopySymbol As Long = 0
                                    While ArrayCopySymbol < SymbolCount
                                        If Symbols(ArrayCopySymbol).ParentSymbol = Types(ArrayCopyElement).TypeSymbol And Symbols(ArrayCopySymbol).SymbolKind = SemanticSymbolMember() And Symbols(ArrayCopySymbol).DeclaredType = ArrayCopyElement Then
                                            ArrayCopyRecursiveCount = ArrayCopyRecursiveCount + 1
                                        End If
                                        ArrayCopySymbol = ArrayCopySymbol + 1
                                    Wend
                                    If ArrayCopyRecursiveCount > 0 Then
                                        ArrayCopyRecursivePointer = "@ube.value.recursive.slots." & LongToString(Types(ArrayCopyElement).TypeSymbol)
                                    End If
                                End If
                            End If
                            Dim ArrayCopyName As String = "%arraycopy" & LongToString(InstructionIndex)
                            LineText = "  " & ArrayCopyName & " = call ptr @ube_array_copy_managed(ptr " & StoredValueText & ", ptr " & ArrayCopyLayout & ", i64 " & LongToString(ArrayCopyRecursiveCount) & ", ptr " & ArrayCopyRecursivePointer & ")" & NewLine
                            StoredValueText = ArrayCopyName
                        End If
                        If Types(StoreTargetType).TypeKind = 40 And StoredType = "ptr" Then
                            Dim FixedCopyName As String = "%fixedcopy" & LongToString(InstructionIndex)
                            LineText = "  " & FixedCopyName & " = call ptr @ube_fixed_string_copy_managed(ptr " & StoredValueText & ", i64 " & LongToString(Types(StoreTargetType).FixedLength) & ")" & NewLine
                            StoredValueText = FixedCopyName
                        End If
                    End If
                    If Values(StoredValue).TypeIndex >= 0 Then
                        If EqualsFolded(Types(Values(StoredValue).TypeIndex).TypeName, "Variant") <> 0 Then
                            Dim VariantCopyName As String = "%variantcopy" & LongToString(InstructionIndex)
                            LineText = "  " & VariantCopyName & " = call ptr @ube_variant_copy(ptr " & StoredValueText & ")" & NewLine
                            StoredValueText = VariantCopyName
                        End If
                    End If
                    If StoreTargetType >= 0 And StoreTargetType < TypeCount Then
                        If Types(StoreTargetType).TypeKind = 26 And Values(StoredValue).TypeIndex = StoreTargetType Then
                            Dim CopySourceName As String = "%valuecopy.source" & LongToString(InstructionIndex)
                            Dim CopyRecursiveCount As Long = 0
                            Dim CopySymbol As Long = 0
                            While CopySymbol < SymbolCount
                                If Symbols(CopySymbol).ParentSymbol = Types(StoreTargetType).TypeSymbol And Symbols(CopySymbol).SymbolKind = SemanticSymbolMember() And Symbols(CopySymbol).DeclaredType = StoreTargetType Then
                                    CopyRecursiveCount = CopyRecursiveCount + 1
                                End If
                                CopySymbol = CopySymbol + 1
                            Wend
                            Dim CopyRecursivePointer As String = "null"
                            If CopyRecursiveCount > 0 Then
                                CopyRecursivePointer = "@ube.value.recursive.slots." & LongToString(Types(StoreTargetType).TypeSymbol)
                            End If
                            LineText = LineText & "  " & CopySourceName & " = alloca " & StoredType & NewLine
                            LineText = LineText & "  store " & StoredType & " " & StoredValueText & ", ptr " & CopySourceName & NewLine
                            LineText = LineText & "  call i32 @ube_value_copy_recursive(ptr " & StoreAddress & ", ptr " & CopySourceName & ", ptr @ube.value.layout." & LongToString(Types(StoreTargetType).TypeSymbol) & ", i64 " & LongToString(CopyRecursiveCount) & ", ptr " & CopyRecursivePointer & ")" & NewLine
                            UsedCustomValueCopy = 1
                        End If
                    End If
                    If UsedCustomValueCopy = 0 Then
                        Dim NeedsRuntimeBarrier As Long = LlvmTypeNeedsGcSlot(Values(StoredValue).TypeIndex, Types, TypeCount)
                        If NeedsRuntimeBarrier <> 0 And StoredType = "ptr" Then
                            LineText = LineText & "  call i32 @ube_gc_write_barrier(ptr null, ptr " & StoreAddress & ", ptr " & StoredValueText & ")" & NewLine
                        Else
                            LineText = LineText & "  store " & StoredType & " " & StoredValueText & ", ptr " & StoreAddress & NewLine
                        End If
                    End If
                Else
                    If Opcode = IrOpBranch() Then
                        LineText = "  br label %" & LlvmBlockLabel(Instructions(InstructionIndex).PrimaryTarget) & NewLine
                    Else
                        If Opcode = IrOpConditionalBranch() Then
                            If FirstOperand < 0 Or Operands(FirstOperand).OperandKind <> IrOperandValue() Then
                                Call AddIrDiagnostic("UBE5108", "conditional branch has no condition value", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                EmitIrInstructionToLlvm = 0
                                Exit Function
                            End If
                            LineText = "  br i1 " & LlvmValueName(Operands(FirstOperand).ReferencedIndex) & ", label %" & LlvmBlockLabel(Instructions(InstructionIndex).PrimaryTarget) & ", label %" & LlvmBlockLabel(Instructions(InstructionIndex).SecondaryTarget) & NewLine
                        Else
                            If Opcode = IrOpReturn() Then
                                LineText = "  ret void" & NewLine
                                If ReturnType <> "void" Then
                                    If FirstOperand >= 0 Then
                                        If Operands(FirstOperand).OperandKind = IrOperandValue() Then
                                            LineText = "  ret " & ReturnType & " " & LlvmValueName(Operands(FirstOperand).ReferencedIndex) & NewLine
                                        Else
                                            LineText = "  ret " & ReturnType & " " & LlvmZeroValue(ReturnType) & NewLine
                                        End If
                                    Else
                                        LineText = "  ret " & ReturnType & " " & LlvmZeroValue(ReturnType) & NewLine
                                    End If
                                End If
                                Dim CleanupIndex As Long = 0
                                While CleanupIndex < CleanupCount
                                    If Cleanups(CleanupIndex).FunctionIndex = FunctionIndex And Cleanups(CleanupIndex).CleanupKind = IrCleanupArrayStorage() Then
                                        Dim CleanupStorage As Long = Cleanups(CleanupIndex).StorageIndex
                                        Dim CleanupAddress As String = LlvmStorageAddress(CleanupStorage, FunctionIndex, Storages, Functions, Parameters)
                                        Dim CleanupValueName As String = "%cleanup" & LongToString(InstructionIndex) & "_" & LongToString(CleanupIndex)
                                        LineText = "  " & CleanupValueName & " = load ptr, ptr " & CleanupAddress & NewLine & "  call void @ube_array_release(ptr " & CleanupValueName & ")" & NewLine & "  store ptr null, ptr " & CleanupAddress & NewLine & LineText
                                    End If
                                    CleanupIndex = CleanupIndex + 1
                                Wend
                            Else
                                If Opcode = IrOpCall() Then
                                    If FirstOperand < 0 Or Operands(FirstOperand).OperandKind <> IrOperandFunction() Then
                                        Call AddIrDiagnostic("UBE5108", "call IR instruction has no function operand", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                        EmitIrInstructionToLlvm = 0
                                        Exit Function
                                    End If
                                    Dim CalledFunction As Long = Operands(FirstOperand).ReferencedIndex
                                    Dim CalledType As String = LlvmTypeForSemanticType(Functions(CalledFunction).ResultType, Types, TypeCount, Abi)
                                    Dim HasObjectReceiver As Long = Instructions(InstructionIndex).Flags And 256
                                    Dim ReceiverBefore As String = ""
                                    Dim ReceiverAfter As String = ""
                                    Dim FirstCallArgument As Long = 1
                                    If HasObjectReceiver <> 0 Then
                                        If Instructions(InstructionIndex).OperandCount < 2 Then
                                            Call AddIrDiagnostic("UBE5108", "instance call has no object receiver", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                            EmitIrInstructionToLlvm = 0
                                            Exit Function
                                        End If
                                        Dim ReceiverOperand As Long = LlvmOperandAt(InstructionIndex, 1, Instructions, Operands)
                                        Dim ReceiverName As String = "%call.receiver" & LongToString(InstructionIndex)
                                        Dim ReceiverType As Long = -1
                                        If Operands(ReceiverOperand).OperandKind = IrOperandStorage() Then
                                            Dim ReceiverStorage As Long = Operands(ReceiverOperand).ReferencedIndex
                                            ReceiverType = Storages(ReceiverStorage).TypeIndex
                                            Dim ReceiverAddress As String = LlvmStorageAddress(ReceiverStorage, FunctionIndex, Storages, Functions, Parameters)
                                            Dim ReceiverIsLazy As Long = 0
                                            Dim ReceiverSymbol As Long = Storages(ReceiverStorage).SymbolIndex
                                            If ReceiverSymbol >= 0 Then
                                                If (Symbols(ReceiverSymbol).Flags And 16) <> 0 Then
                                                    If ReceiverType >= 0 And ReceiverType < TypeCount Then
                                                        If Types(ReceiverType).TypeKind >= 50 And Types(ReceiverType).TypeKind <= 52 Then
                                                            Dim ReceiverTypeSymbolIndex As Long = Types(ReceiverType).TypeSymbol
                                                            Dim ReceiverTypeSymbol As String = LongToString(ReceiverTypeSymbolIndex)
                                                            ReceiverBefore = "  " & ReceiverName & " = call ptr @ube_object_lazy_ensure(ptr " & ReceiverAddress
                                                            ReceiverBefore = ReceiverBefore & ", ptr @ube.object.layout." & ReceiverTypeSymbol
                                                            ReceiverBefore = ReceiverBefore & ", ptr @ube.object.initialize." & ReceiverTypeSymbol & ")" & NewLine
                                                            ReceiverIsLazy = 1
                                                        End If
                                                    End If
                                                End If
                                            End If
                                            If ReceiverIsLazy = 0 Then
                                                ReceiverBefore = "  " & ReceiverName & " = load ptr, ptr " & ReceiverAddress & NewLine
                                            End If
                                        Else
                                            If Operands(ReceiverOperand).OperandKind = IrOperandValue() Then
                                                Dim ReceiverValue As Long = Operands(ReceiverOperand).ReferencedIndex
                                                ReceiverType = Values(ReceiverValue).TypeIndex
                                                ReceiverBefore = "  " & ReceiverName & " = select i1 true, ptr " & LlvmValueName(ReceiverValue) & ", ptr " & LlvmValueName(ReceiverValue) & NewLine
                                            Else
                                                Call AddIrDiagnostic("UBE5108", "instance call receiver is not a value or storage", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                                EmitIrInstructionToLlvm = 0
                                                Exit Function
                                            End If
                                        End If
                                        If ReceiverType < 0 Or ReceiverType >= TypeCount Then
                                            Call AddIrDiagnostic("UBE5108", "instance call receiver has no class type", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                            EmitIrInstructionToLlvm = 0
                                            Exit Function
                                        End If
                                        Dim ReceiverModule As Long = Types(ReceiverType).TypeSymbol
                                        Dim InterfaceReceiver As Long = 0
                                        If Types(ReceiverType).TypeKind = 30 Then
                                            InterfaceReceiver = 1
                                            Dim InterfaceTargetSymbol As Long = Functions(CalledFunction).SymbolIndex
                                            If InterfaceTargetSymbol >= 0 Then
                                                ReceiverModule = Symbols(InterfaceTargetSymbol).ParentSymbol
                                            End If
                                        End If
                                        Dim ReceiverFieldOrdinal As Long = 0
                                        Dim ReceiverFieldSymbol As Long = 0
                                        If InterfaceReceiver <> 0 Then
                                            ReceiverFieldSymbol = SymbolCount
                                        End If
                                        While ReceiverFieldSymbol < SymbolCount
                                            If Symbols(ReceiverFieldSymbol).ParentSymbol = ReceiverModule And Symbols(ReceiverFieldSymbol).SymbolKind = SemanticSymbolVariable() Then
                                                    Dim ReceiverFieldStorage As Long = LlvmGlobalStorageForSymbol(ReceiverFieldSymbol, Storages, StorageCount)
                                                    If ReceiverFieldStorage >= 0 Then
                                                        Dim ReceiverFieldType As String = LlvmTypeForSemanticType(Symbols(ReceiverFieldSymbol).DeclaredType, Types, TypeCount, Abi)
                                                        Dim ReceiverFieldAddress As String = "%call.receiver.field.address" & LongToString(InstructionIndex) & "_" & LongToString(ReceiverFieldOrdinal)
                                                        Dim ReceiverFieldValue As String = "%call.receiver.field.value" & LongToString(InstructionIndex) & "_" & LongToString(ReceiverFieldOrdinal)
                                                        ReceiverBefore = ReceiverBefore & "  " & ReceiverFieldAddress & " = getelementptr inbounds %ube.class." & LongToString(ReceiverModule) & ", ptr " & ReceiverName & ", i32 0, i32 " & LongToString(ReceiverFieldOrdinal + 1) & NewLine
                                                        ReceiverBefore = ReceiverBefore & "  " & ReceiverFieldValue & " = load " & ReceiverFieldType & ", ptr " & ReceiverFieldAddress & NewLine
                                                        ReceiverBefore = ReceiverBefore & "  store " & ReceiverFieldType & " " & ReceiverFieldValue & ", ptr " & LlvmGlobalName(ReceiverFieldStorage) & NewLine
                                                        Dim ReceiverReturnValue As String = "%call.receiver.return.value" & LongToString(InstructionIndex) & "_" & LongToString(ReceiverFieldOrdinal)
                                                        ReceiverAfter = ReceiverAfter & "  " & ReceiverReturnValue & " = load " & ReceiverFieldType & ", ptr " & LlvmGlobalName(ReceiverFieldStorage) & NewLine
                                                        ReceiverAfter = ReceiverAfter & "  store " & ReceiverFieldType & " " & ReceiverReturnValue & ", ptr " & ReceiverFieldAddress & NewLine
                                                    End If
                                                ReceiverFieldOrdinal = ReceiverFieldOrdinal + 1
                                            End If
                                            ReceiverFieldSymbol = ReceiverFieldSymbol + 1
                                        Wend
                                        FirstCallArgument = 2
                                    End If
                                    Dim CallPrefix As String = "  "
                                    If CalledType <> "void" Then
                                        CallPrefix = CallPrefix & ResultName & " = "
                                    End If
                                    Dim CallArguments As String = ""
                                    Dim ArgumentOrdinal As Long = FirstCallArgument
                                    While ArgumentOrdinal < Instructions(InstructionIndex).OperandCount
                                        If ArgumentOrdinal > FirstCallArgument Then
                                            CallArguments = CallArguments & ", "
                                        End If
                                        Dim ArgumentOperand As Long = LlvmOperandAt(InstructionIndex, ArgumentOrdinal, Instructions, Operands)
                                        Dim CalledParameter As Long = Functions(CalledFunction).FirstParameter + ArgumentOrdinal - FirstCallArgument
                                        If CalledParameter >= Functions(CalledFunction).FirstParameter + Functions(CalledFunction).ParameterCount Then
                                            Call AddIrDiagnostic("UBE5108", "call IR instruction " & LongToString(InstructionIndex) & " has too many arguments for function " & LongToString(CalledFunction), Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                            EmitIrInstructionToLlvm = 0
                                            Exit Function
                                        End If
                                        If Parameters(CalledParameter).PassingMode = IrPassingByRef() Then
                                            If Operands(ArgumentOperand).OperandKind = IrOperandStorage() Then
                                                CallArguments = CallArguments & "ptr " & LlvmStorageAddress(Operands(ArgumentOperand).ReferencedIndex, FunctionIndex, Storages, Functions, Parameters)
                                            Else
                                                If Operands(ArgumentOperand).OperandKind = IrOperandValue() Then
                                                    CallArguments = CallArguments & "ptr " & LlvmValueName(Operands(ArgumentOperand).ReferencedIndex)
                                                Else
                                                    Call AddIrDiagnostic("UBE5108", "ByRef call argument is not an address", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                                    EmitIrInstructionToLlvm = 0
                                                    Exit Function
                                                End If
                                            End If
                                        Else
                                            If Operands(ArgumentOperand).OperandKind <> IrOperandValue() Then
                                                Call AddIrDiagnostic("UBE5108", "ByVal call argument is not a value", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                                EmitIrInstructionToLlvm = 0
                                                Exit Function
                                            End If
                                            Dim ArgumentValue As Long = Operands(ArgumentOperand).ReferencedIndex
                                            CallArguments = CallArguments & LlvmValueType(ArgumentValue, Values, Types, TypeCount, Abi) & " " & LlvmValueName(ArgumentValue)
                                        End If
                                        ArgumentOrdinal = ArgumentOrdinal + 1
                                    Wend
                                    If ArgumentOrdinal - FirstCallArgument <> Functions(CalledFunction).ParameterCount Then
                                        Call AddIrDiagnostic("UBE5108", "call IR instruction " & LongToString(InstructionIndex) & " has an invalid argument count for function " & LongToString(CalledFunction), Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                        EmitIrInstructionToLlvm = 0
                                        Exit Function
                                    End If
                                    Dim CallText As String = CallPrefix & "call " & CalledType & " @" & LlvmFunctionName(CalledFunction, Functions, Symbols) & "(" & CallArguments & ")" & NewLine
                                    If InterfaceReceiver <> 0 Then
                                        If BuildInterfaceCallLlvm(InstructionIndex, ReceiverType, ReceiverName, CalledFunction, CalledType, ResultName, CallArguments, ReceiverBefore, Abi, Types, TypeCount, Symbols, SymbolCount, Functions, FunctionCount, Storages, StorageCount, LineText, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
                                            EmitIrInstructionToLlvm = 0
                                            Exit Function
                                        End If
                                    Else
                                        LineText = ReceiverBefore & CallText & ReceiverAfter
                                    End If
                                Else
                                    If Opcode = IrOpCompare() Or Opcode = IrOpBoolean() Then
                                        If FirstOperand < 0 Or Operands(FirstOperand).OperandKind <> IrOperandValue() Then
                                            Call AddIrDiagnostic("UBE5108", "comparison/boolean instruction has no value operand", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                            EmitIrInstructionToLlvm = 0
                                            Exit Function
                                        End If
                                        Dim LeftValue As Long = Operands(FirstOperand).ReferencedIndex
                                        Dim LeftType As String = LlvmValueType(LeftValue, Values, Types, TypeCount, Abi)
                                        If Opcode = IrOpBoolean() And EqualsFolded(Instructions(InstructionIndex).ImmediateText, "Not") <> 0 Then
                                            LineText = "  " & ResultName & " = xor " & LeftType & " " & LlvmValueName(LeftValue) & ", -1" & NewLine
                                        Else
                                            If SecondOperand < 0 Or Operands(SecondOperand).OperandKind <> IrOperandValue() Then
                                                Call AddIrDiagnostic("UBE5108", "binary comparison/boolean instruction lacks its right operand", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                                EmitIrInstructionToLlvm = 0
                                                Exit Function
                                            End If
                                            Dim RightValue As Long = Operands(SecondOperand).ReferencedIndex
                                            Dim OperatorText As String = Instructions(InstructionIndex).ImmediateText
                                            Dim LlvmOperator As String = ""
                                            If Opcode = IrOpCompare() Then
                                                If OperatorText = "=" Then
                                                    LlvmOperator = "icmp eq"
                                                End If
                                                If OperatorText = "<>" Then
                                                    LlvmOperator = "icmp ne"
                                                End If
                                                If OperatorText = "<" Then
                                                    LlvmOperator = "icmp slt"
                                                End If
                                                If OperatorText = "<=" Then
                                                    LlvmOperator = "icmp sle"
                                                End If
                                                If OperatorText = ">" Then
                                                    LlvmOperator = "icmp sgt"
                                                End If
                                                If OperatorText = ">=" Then
                                                    LlvmOperator = "icmp sge"
                                                End If
                                            Else
                                                If EqualsFolded(OperatorText, "And") <> 0 Then
                                                    LlvmOperator = "and"
                                                End If
                                                If EqualsFolded(OperatorText, "Or") <> 0 Then
                                                    LlvmOperator = "or"
                                                End If
                                                If EqualsFolded(OperatorText, "Xor") <> 0 Then
                                                    LlvmOperator = "xor"
                                                End If
                                            End If
                                            If Opcode = IrOpCompare() And LeftType = "ptr" And StringLength(LlvmOperator) > 0 Then
                                                LineText = "  %strcmp" & LongToString(InstructionIndex) & " = call i32 @ube_string_compare(ptr " & LlvmValueName(LeftValue) & ", ptr " & LlvmValueName(RightValue) & ")" & NewLine
                                                LineText = LineText & "  " & ResultName & " = " & LlvmOperator & " i32 %strcmp" & LongToString(InstructionIndex) & ", 0" & NewLine
                                            Else
                                            If StringLength(LlvmOperator) = 0 Or LlvmIntegerType(LeftType) = 0 Then
                                                Call AddIrDiagnostic("UBE5108", "comparison/boolean instruction " & LongToString(InstructionIndex) & " operator " & OperatorText & " with type " & LeftType & " is unsupported", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                                EmitIrInstructionToLlvm = 0
                                                Exit Function
                                            End If
                                            LineText = "  " & ResultName & " = " & LlvmOperator & " " & LeftType & " " & LlvmValueName(LeftValue) & ", " & LlvmValueName(RightValue) & NewLine
                                            End If
                                        End If
                                    Else
                                        If Opcode = IrOpCheckedAdd() Or Opcode = IrOpCheckedSubtract() Or Opcode = IrOpCheckedMultiply() Or Opcode = IrOpCheckedNegate() Or Opcode = IrOpCheckedDivide() Or Opcode = IrOpCheckedRemainder() Then
                                            If FirstOperand < 0 Or Operands(FirstOperand).OperandKind <> IrOperandValue() Or LlvmIntegerType(ResultType) = 0 Then
                                                Call AddIrDiagnostic("UBE5108", "checked arithmetic requires integer value operands", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                                EmitIrInstructionToLlvm = 0
                                                Exit Function
                                            End If
                                            Dim ArithmeticLeft As Long = Operands(FirstOperand).ReferencedIndex
                                            Dim ArithmeticRight As Long = -1
                                            If Opcode <> IrOpCheckedNegate() Then
                                                If SecondOperand < 0 Or Operands(SecondOperand).OperandKind <> IrOperandValue() Then
                                                    Call AddIrDiagnostic("UBE5108", "checked binary arithmetic lacks its right operand", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                                    EmitIrInstructionToLlvm = 0
                                                    Exit Function
                                                End If
                                                ArithmeticRight = Operands(SecondOperand).ReferencedIndex
                                            End If
                                            Dim FailureLabel As String = LlvmBlockLabel(Instructions(InstructionIndex).FailureTarget)
                                            Dim ContinueLabel As String = "ok" & LongToString(InstructionIndex)
                                            If Opcode = IrOpCheckedAdd() Or Opcode = IrOpCheckedSubtract() Or Opcode = IrOpCheckedMultiply() Then
                                                Dim IntrinsicName As String = "llvm.sadd.with.overflow.i" & LlvmIntegerWidth(ResultType)
                                                If Opcode = IrOpCheckedSubtract() Then
                                                    IntrinsicName = "llvm.ssub.with.overflow.i" & LlvmIntegerWidth(ResultType)
                                                End If
                                                If Opcode = IrOpCheckedMultiply() Then
                                                    IntrinsicName = "llvm.smul.with.overflow.i" & LlvmIntegerWidth(ResultType)
                                                End If
                                                LineText = "  %pair" & LongToString(InstructionIndex) & " = call { " & ResultType & ", i1 } @" & IntrinsicName & "(" & ResultType & " " & LlvmValueName(ArithmeticLeft) & ", " & ResultType & " " & LlvmValueName(ArithmeticRight) & ")" & NewLine
                                                LineText = LineText & "  " & ResultName & " = extractvalue { " & ResultType & ", i1 } %pair" & LongToString(InstructionIndex) & ", 0" & NewLine
                                                LineText = LineText & "  %overflow" & LongToString(InstructionIndex) & " = extractvalue { " & ResultType & ", i1 } %pair" & LongToString(InstructionIndex) & ", 1" & NewLine
                                                LineText = LineText & "  br i1 %overflow" & LongToString(InstructionIndex) & ", label %" & FailureLabel & ", label %" & ContinueLabel & NewLine & ContinueLabel & ":" & NewLine
                                            Else
                                                If Opcode = IrOpCheckedNegate() Then
                                                    LineText = "  %ismin" & LongToString(InstructionIndex) & " = icmp eq " & ResultType & " " & LlvmValueName(ArithmeticLeft) & ", " & LlvmSignedMinimum(ResultType) & NewLine
                                                    LineText = LineText & "  br i1 %ismin" & LongToString(InstructionIndex) & ", label %" & FailureLabel & ", label %" & ContinueLabel & NewLine & ContinueLabel & ":" & NewLine
                                                    LineText = LineText & "  " & ResultName & " = sub " & ResultType & " 0, " & LlvmValueName(ArithmeticLeft) & NewLine
                                                Else
                                                    LineText = "  %iszero" & LongToString(InstructionIndex) & " = icmp eq " & ResultType & " " & LlvmValueName(ArithmeticRight) & ", 0" & NewLine
                                                    LineText = LineText & "  %isdivmin" & LongToString(InstructionIndex) & " = icmp eq " & ResultType & " " & LlvmValueName(ArithmeticLeft) & ", " & LlvmSignedMinimum(ResultType) & NewLine
                                                    LineText = LineText & "  %isnegone" & LongToString(InstructionIndex) & " = icmp eq " & ResultType & " " & LlvmValueName(ArithmeticRight) & ", -1" & NewLine
                                                    LineText = LineText & "  %isdivoverflow" & LongToString(InstructionIndex) & " = and i1 %isdivmin" & LongToString(InstructionIndex) & ", %isnegone" & LongToString(InstructionIndex) & NewLine
                                                    LineText = LineText & "  %isdivfailure" & LongToString(InstructionIndex) & " = or i1 %iszero" & LongToString(InstructionIndex) & ", %isdivoverflow" & LongToString(InstructionIndex) & NewLine
                                                    LineText = LineText & "  br i1 %isdivfailure" & LongToString(InstructionIndex) & ", label %" & FailureLabel & ", label %" & ContinueLabel & NewLine & ContinueLabel & ":" & NewLine
                                                    Dim DivideOpcode As String = "sdiv"
                                                    If Opcode = IrOpCheckedRemainder() Then
                                                        DivideOpcode = "srem"
                                                    End If
                                                    LineText = LineText & "  " & ResultName & " = " & DivideOpcode & " " & ResultType & " " & LlvmValueName(ArithmeticLeft) & ", " & LlvmValueName(ArithmeticRight) & NewLine
                                                End If
                                            End If
                                        Else
                                            Call AddIrDiagnostic("UBE5104", "verified IR opcode is not implemented by the RP5 LLVM writer", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                            EmitIrInstructionToLlvm = 0
                                            Exit Function
                                        End If
                                    End If
                                End If
                            End If
                        End If
                    End If
                End If
                End If
            End If
        End If
    End If
    If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation(LineText, DebugNode)) = 0 Then
        Call AddIrDiagnostic("UBE5103", "LLVM output limit exceeded", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        EmitIrInstructionToLlvm = 0
        Exit Function
    End If
    EmitIrInstructionToLlvm = 1
End Function

Function EmitVerifiedIrToLlvm(ByRef Target As TargetDescription, ByRef Abi As TargetAbiDescription, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Program As IrProgram, ByRef Globals() As IrGlobal, ByVal GlobalCount As Long, ByRef Functions() As IrFunction, ByVal FunctionCount As Long, ByRef Parameters() As IrParameter, ByVal ParameterCount As Long, ByRef Storages() As IrStorage, ByVal StorageCount As Long, ByRef Blocks() As IrBlock, ByRef Instructions() As IrInstruction, ByVal InstructionCount As Long, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByVal ValueCount As Long, ByRef Cleanups() As IrCleanup, ByVal CleanupCount As Long, ByRef Locations() As IrLocation, ByVal LocationCount As Long, ByRef Managed As ManagedMetadata, ByRef ManagedLayouts() As ManagedLayout, ByRef ManagedSlots() As ManagedSlot, ByRef ManagedRoots() As ManagedRoot, ByRef ManagedSafePoints() As ManagedSafePoint, ByRef ManagedBarriers() As ManagedBarrier, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim ValueLastUses() As Long
    If BuildLlvmValueLastUses(Values, ValueCount, Instructions, InstructionCount, Operands, ValueLastUses) = 0 Then
        Call AddIrDiagnostic("UBE5103", "LLVM value-liveness analysis failed", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        EmitVerifiedIrToLlvm = 0
        Exit Function
    End If
    Dim RootForValue() As Long
    Dim LastUseHeads() As Long
    Dim LastUseNext() As Long
    If ValueCount > 0 Then
        ReDim RootForValue(ValueCount - 1)
        ReDim LastUseNext(ValueCount - 1)
        Dim IndexedValue As Long = 0
        While IndexedValue < ValueCount
            RootForValue(IndexedValue) = -1
            LastUseNext(IndexedValue) = -1
            IndexedValue = IndexedValue + 1
        Wend
    End If
    If InstructionCount > 0 Then
        ReDim LastUseHeads(InstructionCount - 1)
        Dim IndexedInstruction As Long = 0
        While IndexedInstruction < InstructionCount
            LastUseHeads(IndexedInstruction) = -1
            IndexedInstruction = IndexedInstruction + 1
        Wend
    End If
    Dim IndexedRoot As Long = 0
    While IndexedRoot < Managed.RootCount
        If ManagedRoots(IndexedRoot).StorageIndex < 0 Then
            IndexedValue = -ManagedRoots(IndexedRoot).StorageIndex - 1
            If IndexedValue >= 0 And IndexedValue < ValueCount Then
                RootForValue(IndexedValue) = IndexedRoot
                IndexedInstruction = ValueLastUses(IndexedValue)
                If IndexedInstruction >= 0 And IndexedInstruction < InstructionCount Then
                    LastUseNext(IndexedValue) = LastUseHeads(IndexedInstruction)
                    LastUseHeads(IndexedInstruction) = IndexedValue
                End If
            End If
        End If
        IndexedRoot = IndexedRoot + 1
    Wend
    Dim NewLine As String = StringFromByte(10)
    Dim Quote As String = StringFromByte(34)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "; generated by UBE Compiler v3 RP6" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "target datalayout = " & Quote & Abi.DataLayout & Quote & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "target triple = " & Quote & Abi.Triple & Quote & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_runtime_set_args(i32, ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_print_i32(i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_print_i64(i64)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_print_f64(double)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_print_string(ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_print_newline()" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_string_concat_managed(ptr, ptr)" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_string_compare(ptr, ptr)" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_array_element(ptr, i32)" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_array_redim_managed(ptr, i32, i32, i64, i1, i64, ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_array_copy_managed(ptr, ptr, i64, ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_array_release(ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_string_length(ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_string_byte_at(ptr, i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_string_slice_managed(ptr, i32, i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_string_index_of(ptr, ptr, i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_string_from_byte_managed(i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_long_to_string_managed(i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_command_argument_count()" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_command_argument_managed(i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_read_all_text_managed(ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_write_all_text(ptr, ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_string_array_join_managed(ptr, i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_compiler_run_tool(ptr, ptr, i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_compiler_delete_file(ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_unicode_is_letter(i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_unicode_simple_fold_code_point(i32)" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_gc_collect()" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_gc_safe_point()" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_gc_root_enter(ptr, ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_gc_root_enter_layout(ptr, ptr, i64, ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_gc_root_leave(ptr)" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_gc_pin(ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_gc_unpin(ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_gc_write_barrier(ptr, ptr, ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_fixed_string_copy_managed(ptr, i64)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_gc_allocate_into(ptr, ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_gc_publish(ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_object_allocate(ptr)" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_object_lazy_ensure(ptr, ptr, ptr)" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i64 @ube_object_type_id(ptr)" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_recursive_value_ensure(ptr, ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_value_copy_recursive(ptr, ptr, ptr, i64, ptr)" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_library_call_enter()" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_library_call_leave()" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_library_set_diagnostic(ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_library_initialize_once(ptr, ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i64 @ube_object_lease_acquire(ptr)" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_variant_empty()" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_variant_null()" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_variant_from_long(i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_variant_from_longlong(i64)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_variant_from_integer(i32, i64)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_variant_from_floating(i32, double)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_variant_from_reference(i32, ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_variant_copy(ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_variant_tag(ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_variant_get_long(ptr, ptr)" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_variant_get_longlong(ptr, ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_variant_get_boolean(ptr, ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_variant_get_double(ptr, ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_variant_get_reference(ptr, i32, ptr)" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_checked_string_to_long(ptr, ptr)" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare { i8, i1 } @llvm.sadd.with.overflow.i8(i8, i8)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare { i16, i1 } @llvm.sadd.with.overflow.i16(i16, i16)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare { i32, i1 } @llvm.sadd.with.overflow.i32(i32, i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare { i64, i1 } @llvm.sadd.with.overflow.i64(i64, i64)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare { i8, i1 } @llvm.ssub.with.overflow.i8(i8, i8)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare { i16, i1 } @llvm.ssub.with.overflow.i16(i16, i16)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare { i32, i1 } @llvm.ssub.with.overflow.i32(i32, i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare { i64, i1 } @llvm.ssub.with.overflow.i64(i64, i64)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare { i8, i1 } @llvm.smul.with.overflow.i8(i8, i8)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare { i16, i1 } @llvm.smul.with.overflow.i16(i16, i16)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare { i32, i1 } @llvm.smul.with.overflow.i32(i32, i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare { i64, i1 } @llvm.smul.with.overflow.i64(i64, i64)" & NewLine & NewLine)

    If EmitLlvmAggregateDefinitions(Abi, Types, TypeCount, Symbols, SymbolCount, Chunks, ChunkCount, ChunkCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        EmitVerifiedIrToLlvm = 0
        Exit Function
    End If
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, NewLine)
    Dim ValueLayoutType As Long = 0
    While ValueLayoutType < TypeCount
        If Types(ValueLayoutType).TypeKind = 26 Then
            Dim ValueSlotCount As Long = LlvmElementSlotCount(ValueLayoutType, Types, TypeCount, Symbols, SymbolCount)
            Dim ValueSlotsPointer As String = "null"
            If ValueSlotCount > 0 Then
                Dim ValueSlotText As String = ""
                Dim EmittedValueSlotCount As Long = 0
                Call AppendLlvmValueSlotPaths(ValueLayoutType, Types(ValueLayoutType).StableId, "i32 0", 0, Types, TypeCount, Symbols, SymbolCount, EmittedValueSlotCount, ValueSlotText)
                Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@ube.value.slots." & LongToString(Types(ValueLayoutType).TypeSymbol) & " = private constant [" & LongToString(ValueSlotCount) & " x i64] [" & ValueSlotText & "]" & NewLine)
                ValueSlotsPointer = "getelementptr ([" & LongToString(ValueSlotCount) & " x i64], ptr @ube.value.slots." & LongToString(Types(ValueLayoutType).TypeSymbol) & ", i32 0, i32 0)"
            End If
            Dim RecursiveSlotCount As Long = 0
            Dim RecursiveSlotText As String = ""
            Dim RecursiveFieldOrdinal As Long = 0
            Dim RecursiveSymbol As Long = 0
            While RecursiveSymbol < SymbolCount
                If Symbols(RecursiveSymbol).ParentSymbol = Types(ValueLayoutType).TypeSymbol And Symbols(RecursiveSymbol).SymbolKind = SemanticSymbolMember() Then
                    If Symbols(RecursiveSymbol).DeclaredType = ValueLayoutType Then
                        If RecursiveSlotCount > 0 Then
                            RecursiveSlotText = RecursiveSlotText & ", "
                        End If
                        RecursiveSlotText = RecursiveSlotText & "i64 ptrtoint (ptr getelementptr (%ube.type." & LongToString(Types(ValueLayoutType).StableId) & ", ptr null, i32 0, i32 " & LongToString(RecursiveFieldOrdinal) & ") to i64)"
                        RecursiveSlotCount = RecursiveSlotCount + 1
                    End If
                    RecursiveFieldOrdinal = RecursiveFieldOrdinal + 1
                End If
                RecursiveSymbol = RecursiveSymbol + 1
            Wend
            If RecursiveSlotCount > 0 Then
                Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@ube.value.recursive.slots." & LongToString(Types(ValueLayoutType).TypeSymbol) & " = private constant [" & LongToString(RecursiveSlotCount) & " x i64] [" & RecursiveSlotText & "]" & NewLine)
            End If
            Dim ValueLayoutSize As String = "ptrtoint (ptr getelementptr (%ube.type." & LongToString(Types(ValueLayoutType).StableId) & ", ptr null, i32 1) to i64)"
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@ube.value.layout." & LongToString(Types(ValueLayoutType).TypeSymbol) & " = private constant { i64, i64, ptr, ptr } { i64 " & ValueLayoutSize & ", i64 " & LongToString(ValueSlotCount) & ", ptr " & ValueSlotsPointer & ", ptr null }" & NewLine)
        End If
        ValueLayoutType = ValueLayoutType + 1
    Wend
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, NewLine)

    ' These target-independent tables make the verified managed model part of
    ' the native artifact instead of leaving it only in a diagnostic dump.
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@ube.managed.version = private constant i32 " & LongToString(Managed.FormatVersion) & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@ube.managed.counts = private constant [5 x i32] [i32 " & LongToString(Managed.LayoutCount) & ", i32 " & LongToString(Managed.SlotCount) & ", i32 " & LongToString(Managed.RootCount) & ", i32 " & LongToString(Managed.SafePointCount) & ", i32 " & LongToString(Managed.BarrierCount) & "]" & NewLine)
    Dim ManagedIndex As Long = 0
    While ManagedIndex < Managed.LayoutCount
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@ube.managed.layout." & LongToString(ManagedIndex) & " = private constant [5 x i32] [i32 " & LongToString(ManagedLayouts(ManagedIndex).StableId) & ", i32 " & LongToString(ManagedLayouts(ManagedIndex).TypeIndex) & ", i32 " & LongToString(ManagedLayouts(ManagedIndex).FirstSlot) & ", i32 " & LongToString(ManagedLayouts(ManagedIndex).SlotCount) & ", i32 " & LongToString(ManagedLayouts(ManagedIndex).Flags) & "]" & NewLine)
        ManagedIndex = ManagedIndex + 1
    Wend
    ManagedIndex = 0
    While ManagedIndex < Managed.SlotCount
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@ube.managed.slot." & LongToString(ManagedIndex) & " = private constant [7 x i32] [i32 " & LongToString(ManagedSlots(ManagedIndex).StableId) & ", i32 " & LongToString(ManagedSlots(ManagedIndex).LayoutIndex) & ", i32 " & LongToString(ManagedSlots(ManagedIndex).FieldSymbol) & ", i32 " & LongToString(ManagedSlots(ManagedIndex).TypeIndex) & ", i32 " & LongToString(ManagedSlots(ManagedIndex).FieldOrdinal) & ", i32 " & LongToString(ManagedSlots(ManagedIndex).SlotKind) & ", i32 " & LongToString(ManagedSlots(ManagedIndex).Flags) & "]" & NewLine)
        ManagedIndex = ManagedIndex + 1
    Wend
    ManagedIndex = 0
    While ManagedIndex < Managed.RootCount
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@ube.managed.root." & LongToString(ManagedIndex) & " = private constant [6 x i32] [i32 " & LongToString(ManagedRoots(ManagedIndex).StableId) & ", i32 " & LongToString(ManagedRoots(ManagedIndex).FunctionIndex) & ", i32 " & LongToString(ManagedRoots(ManagedIndex).StorageIndex) & ", i32 " & LongToString(ManagedRoots(ManagedIndex).TypeIndex) & ", i32 " & LongToString(ManagedRoots(ManagedIndex).RootKind) & ", i32 " & LongToString(ManagedRoots(ManagedIndex).Flags) & "]" & NewLine)
        If ManagedRoots(ManagedIndex).RootKind = ManagedRootGlobal() Then
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@ube.gc.root.record." & LongToString(ManagedIndex) & " = private global [4 x ptr] zeroinitializer" & NewLine)
        End If
        ManagedIndex = ManagedIndex + 1
    Wend
    ManagedIndex = 0
    While ManagedIndex < Managed.SafePointCount
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@ube.managed.safe." & LongToString(ManagedIndex) & " = private constant [6 x i32] [i32 " & LongToString(ManagedSafePoints(ManagedIndex).StableId) & ", i32 " & LongToString(ManagedSafePoints(ManagedIndex).FunctionIndex) & ", i32 " & LongToString(ManagedSafePoints(ManagedIndex).BlockIndex) & ", i32 " & LongToString(ManagedSafePoints(ManagedIndex).InstructionIndex) & ", i32 " & LongToString(ManagedSafePoints(ManagedIndex).SafePointKind) & ", i32 " & LongToString(ManagedSafePoints(ManagedIndex).Flags) & "]" & NewLine)
        ManagedIndex = ManagedIndex + 1
    Wend
    ManagedIndex = 0
    While ManagedIndex < Managed.BarrierCount
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@ube.managed.barrier." & LongToString(ManagedIndex) & " = private constant [7 x i32] [i32 " & LongToString(ManagedBarriers(ManagedIndex).StableId) & ", i32 " & LongToString(ManagedBarriers(ManagedIndex).FunctionIndex) & ", i32 " & LongToString(ManagedBarriers(ManagedIndex).InstructionIndex) & ", i32 " & LongToString(ManagedBarriers(ManagedIndex).TargetStorage) & ", i32 " & LongToString(ManagedBarriers(ManagedIndex).StoredValue) & ", i32 " & LongToString(ManagedBarriers(ManagedIndex).BarrierKind) & ", i32 " & LongToString(ManagedBarriers(ManagedIndex).Flags) & "]" & NewLine)
        ManagedIndex = ManagedIndex + 1
    Wend
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, NewLine)

    Dim ClassTypeIndex As Long = 0
    While ClassTypeIndex < TypeCount
        If Types(ClassTypeIndex).TypeKind >= 50 Then
        If Types(ClassTypeIndex).TypeKind <= 52 Then
            Dim ClassModule As Long = Types(ClassTypeIndex).TypeSymbol
            Dim TerminateFunction As Long = LlvmClassLifecycleFunction(ClassModule, "Class_Terminate", Functions, FunctionCount, Symbols)
            Dim FinalizerPointer As String = "null"
            If TerminateFunction >= 0 Then
                FinalizerPointer = "@ube.object.finalize." & LongToString(ClassModule)
            End If
            Dim ClassSlotCount As Long = 0
            Dim ClassFieldOrdinal As Long = 0
            Dim ClassMember As Long = 0
            Dim ClassSlotValues As String = ""
            While ClassMember < SymbolCount
                If Symbols(ClassMember).ParentSymbol = ClassModule And Symbols(ClassMember).SymbolKind = SemanticSymbolVariable() Then
                    If LlvmTypeNeedsGcSlot(Symbols(ClassMember).DeclaredType, Types, TypeCount) <> 0 Then
                        If ClassSlotCount > 0 Then
                            ClassSlotValues = ClassSlotValues & ", "
                        End If
                        ClassSlotValues = ClassSlotValues & "i64 ptrtoint (ptr getelementptr (%ube.class." & LongToString(ClassModule) & ", ptr null, i32 0, i32 " & LongToString(ClassFieldOrdinal + 1) & ") to i64)"
                        ClassSlotCount = ClassSlotCount + 1
                    End If
                    ClassFieldOrdinal = ClassFieldOrdinal + 1
                End If
                ClassMember = ClassMember + 1
            Wend
            Dim ClassSlotsPointer As String = "null"
            If ClassSlotCount > 0 Then
                Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@ube.object.slots." & LongToString(ClassModule) & " = private constant [" & LongToString(ClassSlotCount) & " x i64] [" & ClassSlotValues & "]" & NewLine)
                ClassSlotsPointer = "getelementptr ([" & LongToString(ClassSlotCount) & " x i64], ptr @ube.object.slots." & LongToString(ClassModule) & ", i32 0, i32 0)"
            End If
            Dim ClassSize As String = "ptrtoint (ptr getelementptr (%ube.class." & LongToString(ClassModule) & ", ptr null, i32 1) to i64)"
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@ube.object.layout." & LongToString(ClassModule) & " = private constant { i64, i64, ptr, ptr } { i64 " & ClassSize & ", i64 " & LongToString(ClassSlotCount) & ", ptr " & ClassSlotsPointer & ", ptr " & FinalizerPointer & " }" & NewLine)
        End If
        End If
        ClassTypeIndex = ClassTypeIndex + 1
    Wend
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, NewLine)

    Dim ExportCount As Long = 0
    Dim ExportSymbolIndex As Long = 0
    While ExportSymbolIndex < SymbolCount
        If (Symbols(ExportSymbolIndex).Flags And 64) <> 0 Then
            ExportCount = ExportCount + 1
        End If
        ExportSymbolIndex = ExportSymbolIndex + 1
    Wend
    If ExportCount > 0 Or Program.EntryFunction < 0 Then
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@ube_library_abi_major = dllexport constant i32 1" & NewLine)
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@ube_library_abi_minor = dllexport constant i32 0" & NewLine)
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@ube_library_pointer_bits = dllexport constant i32 " & LongToString(Abi.PointerBits) & NewLine)
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@ube_library_endianness = dllexport constant i32 0" & NewLine)
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@ube_library_calling_convention = dllexport constant i32 1" & NewLine)
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@ube_library_target = dllexport constant [23 x i8] c" & Quote & "x86_64-w64-windows-gnu\00" & Quote & NewLine)
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@ube_library_export_count = dllexport constant i32 " & LongToString(ExportCount) & NewLine)
        Dim SignatureValues As String = ""
        Dim SignatureFunctionIndex As Long = 0
        While SignatureFunctionIndex < FunctionCount
            Dim SignatureSymbol As Long = Functions(SignatureFunctionIndex).SymbolIndex
            If SignatureSymbol >= 0 Then
                If (Symbols(SignatureSymbol).Flags And 64) <> 0 Then
                    If StringLength(SignatureValues) > 0 Then
                        SignatureValues = SignatureValues & ", "
                    End If
                    SignatureValues = SignatureValues & "i64 " & LongToString(ForeignAbiSignatureHash(SignatureFunctionIndex, Symbols, Functions, Parameters, Types))
                End If
            End If
            SignatureFunctionIndex = SignatureFunctionIndex + 1
        Wend
        Dim SignatureCount As Long = ExportCount
        If SignatureCount = 0 Then
            SignatureCount = 1
            SignatureValues = "i64 0"
        End If
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@ube_library_export_signature_hashes = dllexport constant [" & LongToString(SignatureCount) & " x i64] [" & SignatureValues & "]" & NewLine)
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@.ube.abi.null.result = private constant [23 x i8] c" & Quote & "result pointer is null\00" & Quote & NewLine)
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@.ube.abi.lease.failure = private constant [27 x i8] c" & Quote & "could not acquire a handle\00" & Quote & NewLine & NewLine)
    End If

    If EmitLlvmStringConstants(Abi, Types, TypeCount, Instructions, InstructionCount, Chunks, ChunkCount, ChunkCapacity) = 0 Then
        Call AddIrDiagnostic("UBE5103", "LLVM string constant output limit exceeded", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        EmitVerifiedIrToLlvm = 0
        Exit Function
    End If

    Dim GlobalIndex As Long = 0
    While GlobalIndex < GlobalCount
        Dim GlobalStorage As Long = Globals(GlobalIndex).StorageIndex
        Dim GlobalType As String = LlvmTypeForSemanticType(Globals(GlobalIndex).TypeIndex, Types, TypeCount, Abi)
        If StringLength(GlobalType) = 0 Or GlobalType = "void" Then
            Call AddIrDiagnostic("UBE5108", "global storage has an unsupported LLVM type", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitVerifiedIrToLlvm = 0
            Exit Function
        End If
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, LlvmGlobalName(GlobalStorage) & " = internal global " & GlobalType & " " & LlvmZeroValue(GlobalType) & NewLine)
        GlobalIndex = GlobalIndex + 1
    Wend
    If GlobalCount > 0 Then
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, NewLine)
    End If

    Dim FunctionIndex As Long = 0
    While FunctionIndex < FunctionCount
        While FunctionIndex < FunctionCount
            If StringLength(LlvmBootstrapIntrinsicName(Functions(FunctionIndex).FunctionName)) = 0 Then
                Exit While
            End If
            FunctionIndex = FunctionIndex + 1
        Wend
        If FunctionIndex >= FunctionCount Then
            Exit While
        End If
        If ValidateLlvmFunctionAbi(FunctionIndex, Abi, Types, TypeCount, Functions, Parameters, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
            EmitVerifiedIrToLlvm = 0
            Exit Function
        End If
        Dim ReturnType As String = LlvmTypeForSemanticType(Functions(FunctionIndex).ResultType, Types, TypeCount, Abi)
        If StringLength(ReturnType) = 0 Then
            Call AddIrDiagnostic("UBE5100", "target ABI cannot classify a function result type", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitVerifiedIrToLlvm = 0
            Exit Function
        End If
        Dim SymbolName As String = LlvmFunctionName(FunctionIndex, Functions, Symbols)
        If StringLength(SymbolName) = 0 Then
            Call AddIrDiagnostic("UBE5105", "IR function has no valid semantic symbol", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitVerifiedIrToLlvm = 0
            Exit Function
        End If
        Dim Header As String = "define internal " & ReturnType & " @" & SymbolName & "("
        Dim ParameterOffset As Long = 0
        While ParameterOffset < Functions(FunctionIndex).ParameterCount
            If ParameterOffset > 0 Then
                Header = Header & ", "
            End If
            Dim ParameterIndex As Long = Functions(FunctionIndex).FirstParameter + ParameterOffset
            Dim ParameterClass As AbiTypeClassification
            Dim ParameterClassified As Long = ClassifyTargetAbiType(Parameters(ParameterIndex).TypeIndex, Types, TypeCount, Abi, ParameterClass)
            Dim ParameterType As String = ParameterClass.LlvmType
            If Parameters(ParameterIndex).PassingMode = IrPassingByRef() Or ParameterClass.PassKind = AbiPassIndirect() Then
                ParameterType = "ptr"
            End If
            Header = Header & ParameterType & " %p" & LongToString(ParameterOffset)
            ParameterOffset = ParameterOffset + 1
        Wend
        Dim FunctionDebugNode As Long = LlvmDebugFunctionNode(FunctionIndex, LocationCount)
        Dim FunctionLocationNode As Long = LlvmDebugFunctionLocationNode(FunctionIndex, LocationCount, FunctionCount, InstructionCount)
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, Header & ") !dbg !" & LongToString(FunctionDebugNode) & " {" & NewLine)
        Dim PreviousBlock As Long = -1
        Dim InstructionIndex As Long = 0
        While InstructionIndex < InstructionCount
            If Instructions(InstructionIndex).FunctionIndex = FunctionIndex Then
                If LlvmOpcodeIsCurrentlyEmittable(Instructions(InstructionIndex).Opcode) = 0 Then
                    Call AddIrDiagnostic("UBE5104", "verified IR opcode is not implemented by the RP5 LLVM writer", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    EmitVerifiedIrToLlvm = 0
                    Exit Function
                End If
                If Instructions(InstructionIndex).BlockIndex <> PreviousBlock Then
                    If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, LlvmBlockLabel(Instructions(InstructionIndex).BlockIndex) & ":" & NewLine) = 0 Then
                        Call AddIrDiagnostic("UBE5103", "LLVM output limit exceeded", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        EmitVerifiedIrToLlvm = 0
                        Exit Function
                    End If
                    PreviousBlock = Instructions(InstructionIndex).BlockIndex
                    If PreviousBlock = Functions(FunctionIndex).EntryBlock Then
                        Dim StorageOffset As Long = 0
                        While StorageOffset < Functions(FunctionIndex).StorageCount
                            Dim StorageIndex As Long = Functions(FunctionIndex).FirstStorage + StorageOffset
                            If Storages(StorageIndex).StorageKind <> IrStorageGlobal() Then
                                Dim NeedsAllocation As Long = 1
                                Dim ParameterOffsetForStorage As Long = 0
                                While ParameterOffsetForStorage < Functions(FunctionIndex).ParameterCount
                                    Dim ParameterForStorage As Long = Functions(FunctionIndex).FirstParameter + ParameterOffsetForStorage
                                    If Parameters(ParameterForStorage).StorageIndex = StorageIndex And Parameters(ParameterForStorage).PassingMode = IrPassingByRef() Then
                                        NeedsAllocation = 0
                                    End If
                                    ParameterOffsetForStorage = ParameterOffsetForStorage + 1
                                Wend
                                If NeedsAllocation <> 0 Then
                                    Dim StorageType As String = LlvmTypeForSemanticType(Storages(StorageIndex).TypeIndex, Types, TypeCount, Abi)
                                    If StringLength(StorageType) = 0 Or StorageType = "void" Then
                                        Call AddIrDiagnostic("UBE5108", "function storage has an unsupported LLVM type", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                        EmitVerifiedIrToLlvm = 0
                                        Exit Function
                                    End If
                                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation("  " & LlvmStorageName(StorageIndex) & " = alloca " & StorageType & NewLine, FunctionLocationNode))
                                    If Storages(StorageIndex).TypeIndex >= 0 And Storages(StorageIndex).TypeIndex < TypeCount Then
                                        If Types(Storages(StorageIndex).TypeIndex).TypeKind = 40 Then
                                            Dim FixedInitName As String = "%fixedinit.s" & LongToString(StorageIndex)
                                            Dim FixedInitWidth As String = LongToString(Types(Storages(StorageIndex).TypeIndex).FixedLength)
                                            Dim FixedInitLine As String = "  " & FixedInitName & " = call ptr @ube_fixed_string_copy_managed(ptr null, i64 " & FixedInitWidth & ")" & NewLine
                                            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation(FixedInitLine, FunctionLocationNode))
                                            FixedInitLine = "  store ptr " & FixedInitName & ", ptr " & LlvmStorageName(StorageIndex) & NewLine
                                            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation(FixedInitLine, FunctionLocationNode))
                                            FixedInitLine = "  call i32 @ube_gc_publish(ptr " & FixedInitName & ")" & NewLine
                                            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation(FixedInitLine, FunctionLocationNode))
                                        End If
                                    End If
                                End If
                            End If
                            StorageOffset = StorageOffset + 1
                        Wend
                        Dim RootOffset As Long = 0
                        While RootOffset < Managed.RootCount
                            If ManagedRoots(RootOffset).FunctionIndex = FunctionIndex And ManagedRoots(RootOffset).RootKind <> ManagedRootGlobal() Then
                                Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation("  %gc.root.record." & LongToString(RootOffset) & " = alloca [4 x ptr]" & NewLine, FunctionLocationNode))
                                If ManagedRoots(RootOffset).StorageIndex < 0 Then
                                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation("  %gc.temp." & LongToString(-ManagedRoots(RootOffset).StorageIndex - 1) & " = alloca ptr" & NewLine, FunctionLocationNode))
                                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation("  store ptr null, ptr %gc.temp." & LongToString(-ManagedRoots(RootOffset).StorageIndex - 1) & NewLine, FunctionLocationNode))
                                End If
                            End If
                            RootOffset = RootOffset + 1
                        Wend
                        ParameterOffsetForStorage = 0
                        While ParameterOffsetForStorage < Functions(FunctionIndex).ParameterCount
                            ParameterForStorage = Functions(FunctionIndex).FirstParameter + ParameterOffsetForStorage
                            If Parameters(ParameterForStorage).PassingMode = IrPassingByVal() Then
                                StorageIndex = Parameters(ParameterForStorage).StorageIndex
                                StorageType = LlvmTypeForSemanticType(Parameters(ParameterForStorage).TypeIndex, Types, TypeCount, Abi)
                                Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation("  store " & StorageType & " %p" & LongToString(ParameterOffsetForStorage) & ", ptr " & LlvmStorageName(StorageIndex) & NewLine, FunctionLocationNode))
                            End If
                            ParameterOffsetForStorage = ParameterOffsetForStorage + 1
                        Wend
                        RootOffset = 0
                        While RootOffset < Managed.RootCount
                            If ManagedRoots(RootOffset).FunctionIndex = FunctionIndex And ManagedRoots(RootOffset).RootKind <> ManagedRootGlobal() Then
                                Dim RootAddress As String = ""
                                If ManagedRoots(RootOffset).StorageIndex < 0 Then
                                    RootAddress = "%gc.temp." & LongToString(-ManagedRoots(RootOffset).StorageIndex - 1)
                                Else
                                    RootAddress = LlvmStorageAddress(ManagedRoots(RootOffset).StorageIndex, FunctionIndex, Storages, Functions, Parameters)
                                End If
                                Dim RootTypeIndex As Long = ManagedRoots(RootOffset).TypeIndex
                                Dim RootSlotCount As Long = LlvmElementSlotCount(RootTypeIndex, Types, TypeCount, Symbols, SymbolCount)
                                If RootTypeIndex >= 0 And RootTypeIndex < TypeCount And Types(RootTypeIndex).TypeKind = 26 And RootSlotCount > 0 Then
                                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation("  call i32 @ube_gc_root_enter_layout(ptr %gc.root.record." & LongToString(RootOffset) & ", ptr " & RootAddress & ", i64 " & LongToString(RootSlotCount) & ", ptr @ube.value.slots." & LongToString(Types(RootTypeIndex).TypeSymbol) & ")" & NewLine, FunctionLocationNode))
                                Else
                                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation("  call i32 @ube_gc_root_enter(ptr %gc.root.record." & LongToString(RootOffset) & ", ptr " & RootAddress & ")" & NewLine, FunctionLocationNode))
                                End If
                            End If
                            RootOffset = RootOffset + 1
                        Wend
                    End If
                End If
                Dim InstructionDebugNode As Long = LlvmDebugInstructionLocationNode(InstructionIndex, LocationCount, FunctionCount, InstructionCount)
                Dim SafeOffset As Long = 0
                While SafeOffset < Managed.SafePointCount
                    If ManagedSafePoints(SafeOffset).InstructionIndex = InstructionIndex Then
                        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation("  call i32 @ube_gc_safe_point()" & NewLine, InstructionDebugNode))
                    End If
                    SafeOffset = SafeOffset + 1
                Wend
                If Instructions(InstructionIndex).Opcode = IrOpReturn() Then
                    RootOffset = Managed.RootCount - 1
                    While RootOffset >= 0
                        If ManagedRoots(RootOffset).FunctionIndex = FunctionIndex And ManagedRoots(RootOffset).RootKind <> ManagedRootGlobal() Then
                            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation("  call i32 @ube_gc_root_leave(ptr %gc.root.record." & LongToString(RootOffset) & ")" & NewLine, InstructionDebugNode))
                        End If
                        RootOffset = RootOffset - 1
                    Wend
                End If
                If EmitIrInstructionToLlvm(InstructionIndex, InstructionDebugNode, Abi, Types, TypeCount, Symbols, SymbolCount, Functions, FunctionCount, Parameters, Storages, StorageCount, Instructions, InstructionCount, Operands, Values, Cleanups, CleanupCount, ReturnType, Chunks, ChunkCount, ChunkCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
                    EmitVerifiedIrToLlvm = 0
                    Exit Function
                End If
                Dim RootValue As Long = Instructions(InstructionIndex).ResultValue
                If RootValue >= 0 And RootValue < ValueCount Then
                    If RootForValue(RootValue) >= 0 Then
                        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation("  store ptr " & LlvmValueName(RootValue) & ", ptr %gc.temp." & LongToString(RootValue) & NewLine, InstructionDebugNode))
                        If LlvmTypeNeedsGcSlot(Values(RootValue).TypeIndex, Types, TypeCount) <> 0 Then
                            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation("  call i32 @ube_gc_publish(ptr " & LlvmValueName(RootValue) & ")" & NewLine, InstructionDebugNode))
                        End If
                    End If
                End If
                If Instructions(InstructionIndex).Opcode <> IrOpReturn() And Instructions(InstructionIndex).Opcode <> IrOpBranch() And Instructions(InstructionIndex).Opcode <> IrOpConditionalBranch() Then
                    RootValue = LastUseHeads(InstructionIndex)
                    While RootValue >= 0
                        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation("  store ptr null, ptr %gc.temp." & LongToString(RootValue) & NewLine, InstructionDebugNode))
                        RootValue = LastUseNext(RootValue)
                    Wend
                End If
            End If
            InstructionIndex = InstructionIndex + 1
        Wend
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "}" & NewLine & NewLine)
        FunctionIndex = FunctionIndex + 1
    Wend

    ClassTypeIndex = 0
    While ClassTypeIndex < TypeCount
        If Types(ClassTypeIndex).TypeKind >= 50 Then
        If Types(ClassTypeIndex).TypeKind <= 52 Then
            ClassModule = Types(ClassTypeIndex).TypeSymbol
            Dim InitializeFunction As Long = LlvmClassLifecycleFunction(ClassModule, "Class_Initialize", Functions, FunctionCount, Symbols)
            TerminateFunction = LlvmClassLifecycleFunction(ClassModule, "Class_Terminate", Functions, FunctionCount, Symbols)
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "define internal void @ube.object.initialize." & LongToString(ClassModule) & "(ptr %object) {" & NewLine)
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "entry:" & NewLine)
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  store i64 " & LongToString(ClassModule) & ", ptr %object" & NewLine)
            Dim InitFieldOrdinal As Long = 0
            Dim InitMember As Long = 0
            While InitMember < SymbolCount
                If Symbols(InitMember).ParentSymbol = ClassModule And Symbols(InitMember).SymbolKind = SemanticSymbolVariable() Then
                    Dim InitStorage As Long = LlvmGlobalStorageForSymbol(InitMember, Storages, StorageCount)
                    If InitStorage >= 0 Then
                        Dim InitFieldType As String = LlvmTypeForSemanticType(Symbols(InitMember).DeclaredType, Types, TypeCount, Abi)
                        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  store " & InitFieldType & " " & LlvmZeroValue(InitFieldType) & ", ptr " & LlvmGlobalName(InitStorage) & NewLine)
                    End If
                    InitFieldOrdinal = InitFieldOrdinal + 1
                End If
                InitMember = InitMember + 1
            Wend
            If InitializeFunction >= 0 Then
                Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  call void @" & LlvmFunctionName(InitializeFunction, Functions, Symbols) & "()" & NewLine)
            End If
            InitFieldOrdinal = 0
            InitMember = 0
            While InitMember < SymbolCount
                If Symbols(InitMember).ParentSymbol = ClassModule And Symbols(InitMember).SymbolKind = SemanticSymbolVariable() Then
                    InitStorage = LlvmGlobalStorageForSymbol(InitMember, Storages, StorageCount)
                    If InitStorage >= 0 Then
                        InitFieldType = LlvmTypeForSemanticType(Symbols(InitMember).DeclaredType, Types, TypeCount, Abi)
                        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  %initvalue" & LongToString(ClassModule) & "_" & LongToString(InitFieldOrdinal) & " = load " & InitFieldType & ", ptr " & LlvmGlobalName(InitStorage) & NewLine)
                        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  %initaddress" & LongToString(ClassModule) & "_" & LongToString(InitFieldOrdinal) & " = getelementptr inbounds %ube.class." & LongToString(ClassModule) & ", ptr %object, i32 0, i32 " & LongToString(InitFieldOrdinal + 1) & NewLine)
                        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  store " & InitFieldType & " %initvalue" & LongToString(ClassModule) & "_" & LongToString(InitFieldOrdinal) & ", ptr %initaddress" & LongToString(ClassModule) & "_" & LongToString(InitFieldOrdinal) & NewLine)
                    End If
                    InitFieldOrdinal = InitFieldOrdinal + 1
                End If
                InitMember = InitMember + 1
            Wend
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  ret void" & NewLine & "}" & NewLine & NewLine)
            If TerminateFunction >= 0 Then
                Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "define internal void @ube.object.finalize." & LongToString(ClassModule) & "(ptr %object) {" & NewLine)
                Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "entry:" & NewLine)
                Dim FinalFieldOrdinal As Long = 0
                Dim FinalMember As Long = 0
                While FinalMember < SymbolCount
                    If Symbols(FinalMember).ParentSymbol = ClassModule And Symbols(FinalMember).SymbolKind = SemanticSymbolVariable() Then
                        Dim FinalStorage As Long = LlvmGlobalStorageForSymbol(FinalMember, Storages, StorageCount)
                        If FinalStorage >= 0 Then
                            Dim FinalFieldType As String = LlvmTypeForSemanticType(Symbols(FinalMember).DeclaredType, Types, TypeCount, Abi)
                            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  %finaladdress" & LongToString(ClassModule) & "_" & LongToString(FinalFieldOrdinal) & " = getelementptr inbounds %ube.class." & LongToString(ClassModule) & ", ptr %object, i32 0, i32 " & LongToString(FinalFieldOrdinal + 1) & NewLine)
                            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  %finalvalue" & LongToString(ClassModule) & "_" & LongToString(FinalFieldOrdinal) & " = load " & FinalFieldType & ", ptr %finaladdress" & LongToString(ClassModule) & "_" & LongToString(FinalFieldOrdinal) & NewLine)
                            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  store " & FinalFieldType & " %finalvalue" & LongToString(ClassModule) & "_" & LongToString(FinalFieldOrdinal) & ", ptr " & LlvmGlobalName(FinalStorage) & NewLine)
                        End If
                        FinalFieldOrdinal = FinalFieldOrdinal + 1
                    End If
                    FinalMember = FinalMember + 1
                Wend
                Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  call void @" & LlvmFunctionName(TerminateFunction, Functions, Symbols) & "()" & NewLine)
                Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  ret void" & NewLine & "}" & NewLine & NewLine)
            End If
        End If
        End If
        ClassTypeIndex = ClassTypeIndex + 1
    Wend

    If ExportCount > 0 Then
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "define internal void @ube.library.initialize() {" & NewLine & "entry:" & NewLine)
        Dim LibraryModuleSymbol As Long = 0
        While LibraryModuleSymbol < SymbolCount
            If Symbols(LibraryModuleSymbol).SymbolKind = SemanticSymbolModule() And Symbols(LibraryModuleSymbol).Flags = 1 Then
                Dim LibraryInitializeFunction As Long = LlvmClassLifecycleFunction(LibraryModuleSymbol, "Module_Initialize", Functions, FunctionCount, Symbols)
                If LibraryInitializeFunction >= 0 Then
                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  call void @" & LlvmFunctionName(LibraryInitializeFunction, Functions, Symbols) & "()" & NewLine)
                End If
            End If
            LibraryModuleSymbol = LibraryModuleSymbol + 1
        Wend
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  ret void" & NewLine & "}" & NewLine & NewLine)
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "define internal void @ube.library.terminate() {" & NewLine & "entry:" & NewLine)
        LibraryModuleSymbol = SymbolCount - 1
        While LibraryModuleSymbol >= 0
            If Symbols(LibraryModuleSymbol).SymbolKind = SemanticSymbolModule() And Symbols(LibraryModuleSymbol).Flags = 1 Then
                Dim LibraryTerminateFunction As Long = LlvmClassLifecycleFunction(LibraryModuleSymbol, "Module_Terminate", Functions, FunctionCount, Symbols)
                If LibraryTerminateFunction >= 0 Then
                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  call void @" & LlvmFunctionName(LibraryTerminateFunction, Functions, Symbols) & "()" & NewLine)
                End If
            End If
            LibraryModuleSymbol = LibraryModuleSymbol - 1
        Wend
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  ret void" & NewLine & "}" & NewLine & NewLine)
    End If

    Dim ExportFunction As Long = 0
    While ExportFunction < FunctionCount
        Dim ExportProcedureSymbol As Long = Functions(ExportFunction).SymbolIndex
        If ExportProcedureSymbol >= 0 Then
        If (Symbols(ExportProcedureSymbol).Flags And 64) <> 0 Then
            Dim ExportResultType As String = LlvmTypeForSemanticType(Functions(ExportFunction).ResultType, Types, TypeCount, Abi)
            Dim ExportHeader As String = "define dllexport i32 @ube_export_" & HexEncode(Symbols(ExportProcedureSymbol).SymbolName) & "("
            Dim ExportParameterOffset As Long = 0
            While ExportParameterOffset < Functions(ExportFunction).ParameterCount
                If ExportParameterOffset > 0 Then
                    ExportHeader = ExportHeader & ", "
                End If
                Dim ExportParameterIndex As Long = Functions(ExportFunction).FirstParameter + ExportParameterOffset
                Dim ExportParameterType As String = LlvmTypeForSemanticType(Parameters(ExportParameterIndex).TypeIndex, Types, TypeCount, Abi)
                If Parameters(ExportParameterIndex).PassingMode = IrPassingByRef() Then
                    ExportParameterType = "ptr"
                End If
                ExportHeader = ExportHeader & ExportParameterType & " %a" & LongToString(ExportParameterOffset)
                ExportParameterOffset = ExportParameterOffset + 1
            Wend
            If ExportResultType <> "void" Then
                If ExportParameterOffset > 0 Then
                    ExportHeader = ExportHeader & ", "
                End If
                ExportHeader = ExportHeader & "ptr %result"
            End If
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, ExportHeader & ") {" & NewLine)
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "entry:" & NewLine)
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  %admitted = call i32 @ube_library_call_enter()" & NewLine)
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  %closed = icmp eq i32 %admitted, 0" & NewLine)
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  br i1 %closed, label %rejected, label %validate" & NewLine)
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "rejected:" & NewLine & "  ret i32 3" & NewLine)
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "validate:" & NewLine)
            If ExportResultType <> "void" Then
                Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  %result.invalid = icmp eq ptr %result, null" & NewLine)
                Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  br i1 %result.invalid, label %invalid, label %invoke" & NewLine)
                Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "invalid:" & NewLine)
                Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  %invalid.message = getelementptr inbounds [23 x i8], ptr @.ube.abi.null.result, i64 0, i64 0" & NewLine)
                Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  call void @ube_library_set_diagnostic(ptr %invalid.message)" & NewLine)
                Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  call void @ube_library_call_leave()" & NewLine & "  ret i32 1" & NewLine)
                Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "invoke:" & NewLine)
            End If
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  %initialized = call i32 @ube_library_initialize_once(ptr @ube.library.initialize, ptr @ube.library.terminate)" & NewLine)
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  %initialization.failed = icmp eq i32 %initialized, 0" & NewLine)
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  br i1 %initialization.failed, label %initialize.failed, label %call.ready" & NewLine)
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "initialize.failed:" & NewLine & "  call void @ube_library_call_leave()" & NewLine & "  ret i32 5" & NewLine)
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "call.ready:" & NewLine)
            Dim ExportCall As String = "  "
            If ExportResultType <> "void" Then
                ExportCall = ExportCall & "%value = "
            End If
            ExportCall = ExportCall & "call " & ExportResultType & " @" & LlvmFunctionName(ExportFunction, Functions, Symbols) & "("
            ExportParameterOffset = 0
            While ExportParameterOffset < Functions(ExportFunction).ParameterCount
                If ExportParameterOffset > 0 Then
                    ExportCall = ExportCall & ", "
                End If
                ExportParameterIndex = Functions(ExportFunction).FirstParameter + ExportParameterOffset
                ExportParameterType = LlvmTypeForSemanticType(Parameters(ExportParameterIndex).TypeIndex, Types, TypeCount, Abi)
                If Parameters(ExportParameterIndex).PassingMode = IrPassingByRef() Then
                    ExportParameterType = "ptr"
                End If
                ExportCall = ExportCall & ExportParameterType & " %a" & LongToString(ExportParameterOffset)
                ExportParameterOffset = ExportParameterOffset + 1
            Wend
            ExportCall = ExportCall & ")" & NewLine
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, ExportCall)
            If ExportResultType <> "void" Then
                Dim ExportResultSemantic As Long = Functions(ExportFunction).ResultType
                Dim ExportResultKind As Long = -1
                If ExportResultSemantic >= 0 And ExportResultSemantic < TypeCount Then
                    ExportResultKind = Types(ExportResultSemantic).TypeKind
                End If
                If ExportResultKind = 12 Or ExportResultKind = 30 Or (ExportResultKind >= 50 And ExportResultKind <= 52) Then
                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  call i32 @ube_gc_pin(ptr %value)" & NewLine)
                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  %handle = call i64 @ube_object_lease_acquire(ptr %value)" & NewLine)
                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  call i32 @ube_gc_unpin(ptr %value)" & NewLine)
                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  %handle.invalid = icmp eq i64 %handle, 0" & NewLine)
                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  br i1 %handle.invalid, label %lease.failed, label %lease.ready" & NewLine)
                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "lease.failed:" & NewLine)
                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  %lease.message = getelementptr inbounds [27 x i8], ptr @.ube.abi.lease.failure, i64 0, i64 0" & NewLine)
                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  call void @ube_library_set_diagnostic(ptr %lease.message)" & NewLine)
                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  call void @ube_library_call_leave()" & NewLine & "  ret i32 4" & NewLine)
                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "lease.ready:" & NewLine)
                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  store i64 %handle, ptr %result" & NewLine)
                Else
                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  store " & ExportResultType & " %value, ptr %result" & NewLine)
                End If
            End If
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  call void @ube_library_call_leave()" & NewLine)
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  ret i32 0" & NewLine & "}" & NewLine & NewLine)
        End If
        End If
        ExportFunction = ExportFunction + 1
    Wend

    If Program.EntryFunction >= 0 Then
        If Functions(Program.EntryFunction).ParameterCount <> 0 Then
            Call AddIrDiagnostic("UBE5106", "program entry function must not have parameters", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitVerifiedIrToLlvm = 0
            Exit Function
        End If
        Dim EntryName As String = LlvmFunctionName(Program.EntryFunction, Functions, Symbols)
        Dim EntryType As String = LlvmTypeForSemanticType(Functions(Program.EntryFunction).ResultType, Types, TypeCount, Abi)
        ' The C-ABI startup wrapper is generated glue, not the user's Main.
        ' Do not attach Main's DISubprogram to both functions; the user body
        ' retains its complete line-table locations.
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "define i32 @main(i32 %argc, ptr %argv) {" & NewLine)
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "entry:" & NewLine)
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  call void @ube_runtime_set_args(i32 %argc, ptr %argv)" & NewLine)
        GlobalIndex = 0
        While GlobalIndex < GlobalCount
            GlobalStorage = Globals(GlobalIndex).StorageIndex
            If Globals(GlobalIndex).TypeIndex >= 0 And Globals(GlobalIndex).TypeIndex < TypeCount Then
                If Types(Globals(GlobalIndex).TypeIndex).TypeKind = 40 Then
                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  %fixedinit.g" & LongToString(GlobalStorage) & " = call ptr @ube_fixed_string_copy_managed(ptr null, i64 " & LongToString(Types(Globals(GlobalIndex).TypeIndex).FixedLength) & ")" & NewLine)
                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  store ptr %fixedinit.g" & LongToString(GlobalStorage) & ", ptr " & LlvmGlobalName(GlobalStorage) & NewLine)
                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  call i32 @ube_gc_publish(ptr %fixedinit.g" & LongToString(GlobalStorage) & ")" & NewLine)
                End If
            End If
            GlobalIndex = GlobalIndex + 1
        Wend
        ManagedIndex = 0
        While ManagedIndex < Managed.RootCount
            If ManagedRoots(ManagedIndex).RootKind = ManagedRootGlobal() Then
                RootTypeIndex = ManagedRoots(ManagedIndex).TypeIndex
                RootSlotCount = LlvmElementSlotCount(RootTypeIndex, Types, TypeCount, Symbols, SymbolCount)
                If RootTypeIndex >= 0 And RootTypeIndex < TypeCount And Types(RootTypeIndex).TypeKind = 26 And RootSlotCount > 0 Then
                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  call i32 @ube_gc_root_enter_layout(ptr @ube.gc.root.record." & LongToString(ManagedIndex) & ", ptr " & LlvmGlobalName(ManagedRoots(ManagedIndex).StorageIndex) & ", i64 " & LongToString(RootSlotCount) & ", ptr @ube.value.slots." & LongToString(Types(RootTypeIndex).TypeSymbol) & ")" & NewLine)
                Else
                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  call i32 @ube_gc_root_enter(ptr @ube.gc.root.record." & LongToString(ManagedIndex) & ", ptr " & LlvmGlobalName(ManagedRoots(ManagedIndex).StorageIndex) & ")" & NewLine)
                End If
            End If
            ManagedIndex = ManagedIndex + 1
        Wend
        Dim ModuleHookSymbol As Long = 0
        While ModuleHookSymbol < SymbolCount
            If Symbols(ModuleHookSymbol).SymbolKind = SemanticSymbolModule() And Symbols(ModuleHookSymbol).Flags = 1 Then
                Dim ModuleInitializeFunction As Long = LlvmClassLifecycleFunction(ModuleHookSymbol, "Module_Initialize", Functions, FunctionCount, Symbols)
                If ModuleInitializeFunction >= 0 Then
                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  call void @" & LlvmFunctionName(ModuleInitializeFunction, Functions, Symbols) & "()" & NewLine)
                End If
            End If
            ModuleHookSymbol = ModuleHookSymbol + 1
        Wend
        If EntryType = "void" Then
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  call void @" & EntryName & "()" & NewLine)
            ModuleHookSymbol = SymbolCount - 1
            While ModuleHookSymbol >= 0
                If Symbols(ModuleHookSymbol).SymbolKind = SemanticSymbolModule() And Symbols(ModuleHookSymbol).Flags = 1 Then
                    Dim ModuleTerminateFunction As Long = LlvmClassLifecycleFunction(ModuleHookSymbol, "Module_Terminate", Functions, FunctionCount, Symbols)
                    If ModuleTerminateFunction >= 0 Then
                        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  call void @" & LlvmFunctionName(ModuleTerminateFunction, Functions, Symbols) & "()" & NewLine)
                    End If
                End If
                ModuleHookSymbol = ModuleHookSymbol - 1
            Wend
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  ret i32 0" & NewLine)
        Else
            If EntryType <> "i32" Then
                Call AddIrDiagnostic("UBE5107", "program entry function must return Long or have no result", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                EmitVerifiedIrToLlvm = 0
                Exit Function
            End If
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  %result = call " & EntryType & " @" & EntryName & "()" & NewLine)
            ModuleHookSymbol = SymbolCount - 1
            While ModuleHookSymbol >= 0
                If Symbols(ModuleHookSymbol).SymbolKind = SemanticSymbolModule() And Symbols(ModuleHookSymbol).Flags = 1 Then
                    ModuleTerminateFunction = LlvmClassLifecycleFunction(ModuleHookSymbol, "Module_Terminate", Functions, FunctionCount, Symbols)
                    If ModuleTerminateFunction >= 0 Then
                        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  call void @" & LlvmFunctionName(ModuleTerminateFunction, Functions, Symbols) & "()" & NewLine)
                    End If
                End If
                ModuleHookSymbol = ModuleHookSymbol - 1
            Wend
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  ret i32 %result" & NewLine)
        End If
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "}" & NewLine)
    End If
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, NewLine & "!llvm.dbg.cu = !{!0}" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "!llvm.module.flags = !{!1, !2}" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "!0 = distinct !DICompileUnit(language: DW_LANG_C, file: !5, producer: " & Quote & "UBE Compiler v3 RP6" & Quote & ", isOptimized: false, runtimeVersion: 0, emissionKind: LineTablesOnly)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "!1 = !{i32 2, !" & Quote & "Dwarf Version" & Quote & ", i32 4}" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "!2 = !{i32 2, !" & Quote & "Debug Info Version" & Quote & ", i32 3}" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "!3 = !DISubroutineType(types: !4)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "!4 = !{}" & NewLine)
    Dim DebugFileCount As Long = LlvmDebugFileCount(LocationCount)
    Dim DebugOffset As Long = 0
    While DebugOffset < DebugFileCount
        Dim DebugSourceId As Long = 0
        If DebugOffset < LocationCount Then
            DebugSourceId = Locations(DebugOffset).SourceId
        End If
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "!" & LongToString(5 + DebugOffset) & " = !DIFile(filename: " & Quote & "ube-source-" & LongToString(DebugSourceId) & ".bas" & Quote & ", directory: " & Quote & "." & Quote & ")" & NewLine)
        DebugOffset = DebugOffset + 1
    Wend
    DebugOffset = 0
    While DebugOffset < FunctionCount
        Dim DebugFunctionLocation As Long = Functions(DebugOffset).LocationIndex
        Dim DebugFunctionFileNode As Long = 5
        Dim DebugFunctionLine As Long = 1
        If DebugFunctionLocation >= 0 And DebugFunctionLocation < LocationCount Then
            DebugFunctionFileNode = 5 + DebugFunctionLocation
            DebugFunctionLine = Locations(DebugFunctionLocation).LineNumber
            If DebugFunctionLine < 1 Then
                DebugFunctionLine = 1
            End If
        End If
        Dim DebugFunctionName As String = Functions(DebugOffset).FunctionName
        Dim DebugLinkageName As String = LlvmFunctionName(DebugOffset, Functions, Symbols)
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "!" & LongToString(LlvmDebugFunctionNode(DebugOffset, LocationCount)) & " = distinct !DISubprogram(name: " & Quote & DebugFunctionName & Quote & ", linkageName: " & Quote & DebugLinkageName & Quote & ", scope: !" & LongToString(DebugFunctionFileNode) & ", file: !" & LongToString(DebugFunctionFileNode) & ", line: " & LongToString(DebugFunctionLine) & ", type: !3, scopeLine: " & LongToString(DebugFunctionLine) & ", spFlags: DISPFlagDefinition, unit: !0)" & NewLine)
        DebugOffset = DebugOffset + 1
    Wend
    DebugOffset = 0
    While DebugOffset < InstructionCount
        Dim DebugInstructionFunction As Long = Instructions(DebugOffset).FunctionIndex
        Dim DebugInstructionLocation As Long = Instructions(DebugOffset).LocationIndex
        Dim DebugInstructionFileNode As Long = 5
        Dim DebugInstructionLine As Long = 1
        Dim DebugInstructionColumn As Long = 1
        If DebugInstructionLocation >= 0 And DebugInstructionLocation < LocationCount Then
            DebugInstructionFileNode = 5 + DebugInstructionLocation
            DebugInstructionLine = Locations(DebugInstructionLocation).LineNumber
            DebugInstructionColumn = Locations(DebugInstructionLocation).ColumnNumber
            If DebugInstructionLine < 1 Then
                DebugInstructionLine = 1
            End If
            If DebugInstructionColumn < 1 Then
                DebugInstructionColumn = 1
            End If
        End If
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "!" & LongToString(LlvmDebugInstructionScopeNode(DebugOffset, LocationCount, FunctionCount)) & " = !DILexicalBlockFile(scope: !" & LongToString(LlvmDebugFunctionNode(DebugInstructionFunction, LocationCount)) & ", file: !" & LongToString(DebugInstructionFileNode) & ", discriminator: 0)" & NewLine)
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "!" & LongToString(LlvmDebugInstructionLocationNode(DebugOffset, LocationCount, FunctionCount, InstructionCount)) & " = !DILocation(line: " & LongToString(DebugInstructionLine) & ", column: " & LongToString(DebugInstructionColumn) & ", scope: !" & LongToString(LlvmDebugInstructionScopeNode(DebugOffset, LocationCount, FunctionCount)) & ")" & NewLine)
        DebugOffset = DebugOffset + 1
    Wend
    DebugOffset = 0
    While DebugOffset < FunctionCount
        DebugFunctionLocation = Functions(DebugOffset).LocationIndex
        DebugFunctionLine = 1
        Dim DebugFunctionColumn As Long = 1
        If DebugFunctionLocation >= 0 And DebugFunctionLocation < LocationCount Then
            DebugFunctionLine = Locations(DebugFunctionLocation).LineNumber
            DebugFunctionColumn = Locations(DebugFunctionLocation).ColumnNumber
            If DebugFunctionLine < 1 Then
                DebugFunctionLine = 1
            End If
            If DebugFunctionColumn < 1 Then
                DebugFunctionColumn = 1
            End If
        End If
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "!" & LongToString(LlvmDebugFunctionLocationNode(DebugOffset, LocationCount, FunctionCount, InstructionCount)) & " = !DILocation(line: " & LongToString(DebugFunctionLine) & ", column: " & LongToString(DebugFunctionColumn) & ", scope: !" & LongToString(LlvmDebugFunctionNode(DebugOffset, LocationCount)) & ")" & NewLine)
        DebugOffset = DebugOffset + 1
    Wend
    EmitVerifiedIrToLlvm = 1
End Function
