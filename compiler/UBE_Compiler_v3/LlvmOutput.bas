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
        LlvmBootstrapIntrinsicName = "ube_string_slice"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "StringIndexOf") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_string_index_of"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "StringFromByte") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_string_from_byte"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "LongToString") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_long_to_string"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "CommandArgumentCount") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_command_argument_count"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "CommandArgument") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_command_argument"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "ReadAllText") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_read_all_text"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "WriteAllText") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_write_all_text"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "StringArrayJoin") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_string_array_join"
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

Function LlvmOpcodeIsCurrentlyEmittable(ByVal Opcode As Long) As Long
    If Opcode = IrOpConstant() Or Opcode = IrOpDefaultValue() Or Opcode = IrOpLoad() Or Opcode = IrOpStore() Or Opcode = IrOpAddress() Or Opcode = IrOpArrayAddress() Or Opcode = IrOpFieldAddress() Or Opcode = IrOpConvert() Then
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
        If ReturnClass.ReturnKind <> AbiReturnDirect() Then
            Call AddIrDiagnostic("UBE5101", "indirect aggregate function results are not implemented by the RP5 LLVM writer", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            ValidateLlvmFunctionAbi = 0
            Exit Function
        End If
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
                If SymbolIndex < Types(TypeIndex).TypeSymbol Then
                    SymbolIndex = Types(TypeIndex).TypeSymbol
                End If
                If SymbolIndex > Types(TypeIndex).TypeSymbol And Symbols(SymbolIndex).ParentSymbol <> Types(TypeIndex).TypeSymbol Then
                    Exit While
                End If
                If SymbolIndex > Types(TypeIndex).TypeSymbol And Symbols(SymbolIndex).SymbolKind = SemanticSymbolMember() Then
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

Function BuildLlvmFieldAddressLine(ByVal InstructionIndex As Long, ByVal FunctionIndex As Long, ByVal FirstOperand As Long, ByVal ResultName As String, ByVal ResultType As String, ByRef Abi As TargetAbiDescription, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Functions() As IrFunction, ByRef Parameters() As IrParameter, ByRef Storages() As IrStorage, ByRef Instructions() As IrInstruction, ByRef Operands() As IrOperand, ByVal NewLine As String, ByRef LineText As String, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim FieldTypeOperand As Long = LlvmOperandAt(InstructionIndex, 1, Instructions, Operands)
    Dim FieldOrdinalOperand As Long = LlvmOperandAt(InstructionIndex, 2, Instructions, Operands)
    If FirstOperand < 0 Or FieldTypeOperand < 0 Or FieldOrdinalOperand < 0 Or Operands(FieldTypeOperand).OperandKind <> IrOperandType() Or Operands(FieldOrdinalOperand).OperandKind <> IrOperandInteger() Then
        Call AddIrDiagnostic("UBE5108", "field-address IR instruction has invalid operands or result type", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        BuildLlvmFieldAddressLine = 0
        Exit Function
    End If
    Dim AggregateType As String = LlvmTypeForSemanticType(Operands(FieldTypeOperand).ReferencedIndex, Types, TypeCount, Abi)
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
    LineText = "  " & ResultName & " = getelementptr inbounds " & AggregateType & ", ptr " & FieldBaseAddress & ", i32 0, i32 " & LongToString(Operands(FieldOrdinalOperand).ReferencedIndex) & NewLine
    BuildLlvmFieldAddressLine = 1
End Function

Function EmitIrInstructionToLlvm(ByVal InstructionIndex As Long, ByVal DebugNode As Long, ByRef Abi As TargetAbiDescription, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByRef Functions() As IrFunction, ByRef Parameters() As IrParameter, ByRef Storages() As IrStorage, ByRef Instructions() As IrInstruction, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByRef Cleanups() As IrCleanup, ByVal CleanupCount As Long, ByVal ReturnType As String, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
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
        If BuildLlvmFieldAddressLine(InstructionIndex, FunctionIndex, FirstOperand, ResultName, ResultType, Abi, Types, TypeCount, Functions, Parameters, Storages, Instructions, Operands, NewLine, LineText, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
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
        Dim OldArrayName As String = "%arrayold" & LongToString(InstructionIndex)
        Dim NewArrayName As String = "%arraynew" & LongToString(InstructionIndex)
        LineText = "  " & OldArrayName & " = load ptr, ptr " & ArrayStorageAddress & NewLine
        LineText = LineText & "  " & NewArrayName & " = call ptr @ube_array_redim(ptr " & OldArrayName & ", i32 " & LlvmValueName(Operands(LowerOperand).ReferencedIndex) & ", i32 " & LlvmValueName(Operands(UpperOperand).ReferencedIndex) & ", i64 " & ElementSizeText & ", i1 " & LongToString(Operands(PreserveOperand).ReferencedIndex) & ")" & NewLine
        LineText = LineText & "  store ptr " & NewArrayName & ", ptr " & ArrayStorageAddress & NewLine
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
        LineText = "  " & ResultName & " = call ptr @ube_string_concat(ptr " & LlvmValueName(ConcatLeft) & ", ptr " & LlvmValueName(ConcatRight) & ")" & NewLine
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
                If PrintedType = "i32" Then
                    LineText = "  call void @ube_print_i32(i32 " & LlvmValueName(PrintedValue) & ")" & NewLine
                Else
                    If PrintedType = "double" Then
                        LineText = "  call void @ube_print_f64(double " & LlvmValueName(PrintedValue) & ")" & NewLine
                    Else
                        Call AddIrDiagnostic("UBE5108", "print instruction has an unsupported LLVM value type", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        EmitIrInstructionToLlvm = 0
                        Exit Function
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
            LineText = "  " & ResultName & " = load " & ResultType & ", ptr " & LoadAddress & NewLine
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
                    If LlvmIntegerType(ConvertSourceType) = 0 Or LlvmIntegerType(ResultType) = 0 Then
                        Call AddIrDiagnostic("UBE5108", "RP5 conversion instruction " & LongToString(InstructionIndex) & " from " & ConvertSourceType & " to " & ResultType & " currently requires integer types", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        EmitIrInstructionToLlvm = 0
                        Exit Function
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
                    If Operands(FirstOperand).OperandKind = IrOperandStorage() Then
                        StoreAddress = LlvmStorageAddress(Operands(FirstOperand).ReferencedIndex, FunctionIndex, Storages, Functions, Parameters)
                    Else
                        If Operands(FirstOperand).OperandKind = IrOperandValue() Then
                            StoreAddress = LlvmValueName(Operands(FirstOperand).ReferencedIndex)
                        End If
                    End If
                    If StringLength(StoreAddress) = 0 Then
                        Call AddIrDiagnostic("UBE5108", "store IR instruction requires a storage or address value", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        EmitIrInstructionToLlvm = 0
                        Exit Function
                    End If
                    LineText = "  store " & StoredType & " " & LlvmValueName(StoredValue) & ", ptr " & StoreAddress & NewLine
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
                                    Dim CallText As String = "  "
                                    If CalledType <> "void" Then
                                        CallText = CallText & ResultName & " = "
                                    End If
                                    CallText = CallText & "call " & CalledType & " @" & LlvmFunctionName(CalledFunction, Functions, Symbols) & "("
                                    Dim ArgumentOrdinal As Long = 1
                                    While ArgumentOrdinal < Instructions(InstructionIndex).OperandCount
                                        If ArgumentOrdinal > 1 Then
                                            CallText = CallText & ", "
                                        End If
                                        Dim ArgumentOperand As Long = LlvmOperandAt(InstructionIndex, ArgumentOrdinal, Instructions, Operands)
                                        Dim CalledParameter As Long = Functions(CalledFunction).FirstParameter + ArgumentOrdinal - 1
                                        If CalledParameter >= Functions(CalledFunction).FirstParameter + Functions(CalledFunction).ParameterCount Then
                                            Call AddIrDiagnostic("UBE5108", "call IR instruction " & LongToString(InstructionIndex) & " has too many arguments for function " & LongToString(CalledFunction), Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                            EmitIrInstructionToLlvm = 0
                                            Exit Function
                                        End If
                                        If Parameters(CalledParameter).PassingMode = IrPassingByRef() Then
                                            If Operands(ArgumentOperand).OperandKind = IrOperandStorage() Then
                                                CallText = CallText & "ptr " & LlvmStorageAddress(Operands(ArgumentOperand).ReferencedIndex, FunctionIndex, Storages, Functions, Parameters)
                                            Else
                                                If Operands(ArgumentOperand).OperandKind = IrOperandValue() Then
                                                    CallText = CallText & "ptr " & LlvmValueName(Operands(ArgumentOperand).ReferencedIndex)
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
                                            CallText = CallText & LlvmValueType(ArgumentValue, Values, Types, TypeCount, Abi) & " " & LlvmValueName(ArgumentValue)
                                        End If
                                        ArgumentOrdinal = ArgumentOrdinal + 1
                                    Wend
                                    If ArgumentOrdinal - 1 <> Functions(CalledFunction).ParameterCount Then
                                        Call AddIrDiagnostic("UBE5108", "call IR instruction " & LongToString(InstructionIndex) & " has " & LongToString(ArgumentOrdinal - 1) & " argument(s); function " & LongToString(CalledFunction) & " requires " & LongToString(Functions(CalledFunction).ParameterCount), Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                        EmitIrInstructionToLlvm = 0
                                        Exit Function
                                    End If
                                    LineText = CallText & ")" & NewLine
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

Function EmitVerifiedIrToLlvm(ByRef Target As TargetDescription, ByRef Abi As TargetAbiDescription, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Program As IrProgram, ByRef Globals() As IrGlobal, ByVal GlobalCount As Long, ByRef Functions() As IrFunction, ByVal FunctionCount As Long, ByRef Parameters() As IrParameter, ByVal ParameterCount As Long, ByRef Storages() As IrStorage, ByVal StorageCount As Long, ByRef Blocks() As IrBlock, ByRef Instructions() As IrInstruction, ByVal InstructionCount As Long, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByRef Cleanups() As IrCleanup, ByVal CleanupCount As Long, ByRef Locations() As IrLocation, ByVal LocationCount As Long, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim NewLine As String = StringFromByte(10)
    Dim Quote As String = StringFromByte(34)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "; generated by UBE Compiler v3 RP5" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "target datalayout = " & Quote & Abi.DataLayout & Quote & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "target triple = " & Quote & Abi.Triple & Quote & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_runtime_set_args(i32, ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_print_i32(i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_print_i64(i64)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_print_f64(double)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_print_string(ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_print_newline()" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_string_concat(ptr, ptr)" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_string_compare(ptr, ptr)" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_array_element(ptr, i32)" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_array_redim(ptr, i32, i32, i64, i1)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_array_release(ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_string_length(ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_string_byte_at(ptr, i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_string_slice(ptr, i32, i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_string_index_of(ptr, ptr, i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_string_from_byte(i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_long_to_string(i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_command_argument_count()" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_command_argument(i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_read_all_text(ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_write_all_text(ptr, ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_string_array_join(ptr, i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_compiler_run_tool(ptr, ptr, i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_compiler_delete_file(ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_unicode_is_letter(i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_unicode_simple_fold_code_point(i32)" & NewLine & NewLine)
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
                                End If
                            End If
                            StorageOffset = StorageOffset + 1
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
                    End If
                End If
                Dim InstructionDebugNode As Long = LlvmDebugInstructionLocationNode(InstructionIndex, LocationCount, FunctionCount, InstructionCount)
                If EmitIrInstructionToLlvm(InstructionIndex, InstructionDebugNode, Abi, Types, TypeCount, Symbols, Functions, Parameters, Storages, Instructions, Operands, Values, Cleanups, CleanupCount, ReturnType, Chunks, ChunkCount, ChunkCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
                    EmitVerifiedIrToLlvm = 0
                    Exit Function
                End If
            End If
            InstructionIndex = InstructionIndex + 1
        Wend
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "}" & NewLine & NewLine)
        FunctionIndex = FunctionIndex + 1
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
        If EntryType = "void" Then
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  call void @" & EntryName & "()" & NewLine)
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  ret i32 0" & NewLine)
        Else
            If EntryType <> "i32" Then
                Call AddIrDiagnostic("UBE5107", "program entry function must return Long or have no result", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                EmitVerifiedIrToLlvm = 0
                Exit Function
            End If
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  %result = call " & EntryType & " @" & EntryName & "()" & NewLine)
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  ret i32 %result" & NewLine)
        End If
        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "}" & NewLine)
    End If
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, NewLine & "!llvm.dbg.cu = !{!0}" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "!llvm.module.flags = !{!1, !2}" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "!0 = distinct !DICompileUnit(language: DW_LANG_C, file: !5, producer: " & Quote & "UBE Compiler v3 RP5" & Quote & ", isOptimized: false, runtimeVersion: 0, emissionKind: LineTablesOnly)" & NewLine)
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
