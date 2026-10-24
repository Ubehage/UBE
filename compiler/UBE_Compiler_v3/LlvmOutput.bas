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
    If EqualsFolded(FunctionName, "CompilerValidateResource") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_compiler_validate_resource"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "CompilerResourceLlvmEscape") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_compiler_resource_llvm_escape"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "CompilerValidateLibraryBundle") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_compiler_validate_library_bundle"
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
    If EqualsFolded(FunctionName, "RuntimeErrorNumber") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_err_number"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeErrorDescription") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_err_description"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeErrorSource") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_err_source"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeErrorClear") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_err_clear"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeErrorSet") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_err_set"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeCurrentThreadId") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_thread_current_id"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeThreadIsAlive") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_thread_is_alive"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeThreadWait") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_thread_wait"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeThreadRequestStop") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_thread_request_stop"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeThreadStopRequested") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_thread_stop_requested"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeThreadYield") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_thread_yield"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeAtomicLongCreate") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_atomic_i32_create"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeAtomicLongDestroy") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_atomic_i32_destroy"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeAtomicLongLoad") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_atomic_i32_load"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeAtomicLongStore") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_atomic_i32_store"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeAtomicLongExchange") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_atomic_i32_exchange"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeAtomicLongCompareExchange") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_atomic_i32_compare_exchange"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeAtomicLongAdd") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_atomic_i32_add"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeAtomicLongLongCreate") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_atomic_i64_create"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeAtomicLongLongDestroy") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_atomic_i64_destroy"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeAtomicLongLongLoad") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_atomic_i64_load"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeAtomicLongLongStore") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_atomic_i64_store"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeAtomicLongLongExchange") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_atomic_i64_exchange"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeAtomicLongLongCompareExchange") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_atomic_i64_compare_exchange"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeAtomicLongLongAdd") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_atomic_i64_add"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeThreadEventCreate") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_thread_event_create"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeThreadEventDestroy") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_thread_event_destroy"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeThreadEventSet") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_thread_event_set"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeThreadEventReset") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_thread_event_reset"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeThreadEventWait") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_thread_event_wait"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeSemaphoreCreate") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_semaphore_create"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeSemaphoreDestroy") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_semaphore_destroy"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeSemaphoreWait") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_semaphore_wait"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeSemaphoreRelease") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_semaphore_release"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeMessageQueueCreate") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_message_queue_create"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeMessageQueueDestroy") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_message_queue_destroy"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeMessageQueueEnqueue") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_message_queue_enqueue"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeMessageQueueDequeue") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_message_queue_dequeue"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeAtomicObjectCreate") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_atomic_object_create"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeAtomicObjectDestroy") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_atomic_object_destroy"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeAtomicObjectLoad") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_atomic_object_load"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeAtomicObjectStore") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_atomic_object_store"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeAtomicObjectExchange") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_atomic_object_exchange"
        Exit Function
    End If
    If EqualsFolded(FunctionName, "RuntimeAtomicObjectCompareExchange") <> 0 Then
        LlvmBootstrapIntrinsicName = "ube_atomic_object_compare_exchange"
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

Sub AppendLlvmCaptureSlotPaths(ByVal TypeIndex As Long, ByVal RootType As String, ByVal IndexPath As String, ByVal Depth As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Count As Long, ByRef TextValue As String)
    If TypeIndex < 0 Or TypeIndex >= TypeCount Or Depth > 64 Then
        Exit Sub
    End If
    If LlvmTypeNeedsGcSlot(TypeIndex, Types, TypeCount) <> 0 Then
        If StringLength(TextValue) > 0 Then
            TextValue = TextValue & ", "
        End If
        TextValue = TextValue & "i64 ptrtoint (ptr getelementptr (" & RootType & ", ptr null, " & IndexPath & ") to i64)"
        Count = Count + 1
        Exit Sub
    End If
    If Types(TypeIndex).TypeKind <> 26 Then
        Exit Sub
    End If
    Dim FieldOrdinal As Long = 0
    Dim SymbolIndex As Long = 0
    While SymbolIndex < SymbolCount
        If Symbols(SymbolIndex).ParentSymbol = Types(TypeIndex).TypeSymbol And Symbols(SymbolIndex).SymbolKind = SemanticSymbolMember() Then
            Dim FieldType As Long = Symbols(SymbolIndex).DeclaredType
            If FieldType = TypeIndex Then
                If StringLength(TextValue) > 0 Then
                    TextValue = TextValue & ", "
                End If
                TextValue = TextValue & "i64 ptrtoint (ptr getelementptr (" & RootType & ", ptr null, " & IndexPath & ", i32 " & LongToString(FieldOrdinal) & ") to i64)"
                Count = Count + 1
            Else
                Call AppendLlvmCaptureSlotPaths(FieldType, RootType, IndexPath & ", i32 " & LongToString(FieldOrdinal), Depth + 1, Types, TypeCount, Symbols, SymbolCount, Count, TextValue)
            End If
            FieldOrdinal = FieldOrdinal + 1
        End If
        SymbolIndex = SymbolIndex + 1
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

Function LlvmDebugVariableNode(ByVal StorageIndex As Long, ByVal LocationCount As Long, ByVal FunctionCount As Long, ByVal InstructionCount As Long) As Long
    LlvmDebugVariableNode = 5 + LlvmDebugFileCount(LocationCount) + FunctionCount + InstructionCount + InstructionCount + FunctionCount + StorageIndex
End Function

Function LlvmDebugVariableTypeNode(ByVal StorageCount As Long, ByVal LocationCount As Long, ByVal FunctionCount As Long, ByVal InstructionCount As Long) As Long
    LlvmDebugVariableTypeNode = 5 + LlvmDebugFileCount(LocationCount) + FunctionCount + InstructionCount + InstructionCount + FunctionCount + StorageCount
End Function

Function LlvmDebugExpressionNode(ByVal StorageCount As Long, ByVal LocationCount As Long, ByVal FunctionCount As Long, ByVal InstructionCount As Long) As Long
    LlvmDebugExpressionNode = LlvmDebugVariableTypeNode(StorageCount, LocationCount, FunctionCount, InstructionCount) + 1
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
    If Opcode = IrOpCompare() Or Opcode = IrOpBoolean() Or Opcode = IrOpConcatenate() Or Opcode = IrOpCall() Or Opcode = IrOpCallNew() Or Opcode = IrOpRaiseEvent() Or Opcode = IrOpLoadComponent() Or Opcode = IrOpUnloadComponent() Or Opcode = IrOpArrayResize() Or Opcode = IrOpPrint() Or Opcode = IrOpBranch() Or Opcode = IrOpConditionalBranch() Or Opcode = IrOpReturn() Then
        LlvmOpcodeIsCurrentlyEmittable = 1
    Else
        If Opcode = IrOpErrorTest() Or Opcode = IrOpErrorSet() Or Opcode = IrOpErrorClear() Or Opcode = IrOpMonitorEnter() Or Opcode = IrOpMonitorExit() Or Opcode = IrOpErrorDispatch() Or Opcode = IrOpResume() Then
            LlvmOpcodeIsCurrentlyEmittable = 1
        Else
            LlvmOpcodeIsCurrentlyEmittable = 0
        End If
    End If
End Function

Function AppendLlvmResources(ByVal ResourceCount As Long, ByVal ResourceLengths As String, ByVal ResourceData As String, ByVal ResourceBytes As Long, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long) As Long
    If ResourceCount = 0 Then
        AppendLlvmResources = 1
        Exit Function
    End If
    Dim NewLine As String = StringFromByte(10)
    If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@ube.resource.count = constant i32 " & LongToString(ResourceCount) & NewLine) = 0 Then
        AppendLlvmResources = 0
        Exit Function
    End If
    If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@ube.resource.lengths = constant [" & LongToString(ResourceCount) & " x i64] [" & ResourceLengths & "]" & NewLine) = 0 Then
        AppendLlvmResources = 0
        Exit Function
    End If
    If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@ube.resource.data = constant [" & LongToString(ResourceBytes) & " x i8] c" & StringFromByte(34)) = 0 Then
        AppendLlvmResources = 0
        Exit Function
    End If
    Dim ByteIndex As Long = 0
    While ByteIndex < StringLength(ResourceData)
        Dim ChunkLength As Long = StringLength(ResourceData) - ByteIndex
        If ChunkLength > 4095 Then
            ChunkLength = 4095
        End If
        If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, StringSlice(ResourceData, ByteIndex, ChunkLength)) = 0 Then
            AppendLlvmResources = 0
            Exit Function
        End If
        ByteIndex = ByteIndex + ChunkLength
    Wend
    If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, StringFromByte(34) & ", align 1" & NewLine & NewLine) = 0 Then
        AppendLlvmResources = 0
        Exit Function
    End If
    AppendLlvmResources = 1
End Function

Function ReplaceFirstLlvmText(ByVal Value As String, ByVal Sought As String, ByVal Replacement As String) As String
    Dim Found As Long = StringIndexOf(Value, Sought, 0)
    If Found < 0 Then
        ReplaceFirstLlvmText = Value
        Exit Function
    End If
    ReplaceFirstLlvmText = StringSlice(Value, 0, Found) & Replacement & StringSlice(Value, Found + StringLength(Sought), StringLength(Value) - Found - StringLength(Sought))
End Function

' Project debug modes are applied to the final deterministic LLVM text so the
' target-independent IR remains one implementation. None removes all debug
' records and attachments; Line retains source locations but omits variable
' records; Full preserves the complete metadata graph.
Function FilterLlvmDebugInformation(ByVal LlvmText As String, ByVal DebugMode As String) As String
    If EqualsFolded(DebugMode, "Full") <> 0 Then
        FilterLlvmDebugInformation = LlvmText
        Exit Function
    End If
    Dim Result As String = ""
    Dim Cursor As Long = 0
    While Cursor < StringLength(LlvmText)
        Dim LineEnd As Long = StringIndexOf(LlvmText, StringFromByte(10), Cursor)
        If LineEnd < 0 Then
            LineEnd = StringLength(LlvmText)
        End If
        Dim LineText As String = StringSlice(LlvmText, Cursor, LineEnd - Cursor)
        Dim KeepLine As Long = 1
        If StringIndexOf(LineText, "@llvm.dbg.declare", 0) >= 0 Then
            KeepLine = 0
        End If
        If EqualsFolded(DebugMode, "Line") <> 0 Then
            If StringIndexOf(LineText, "!DILocalVariable", 0) >= 0 Or StringIndexOf(LineText, "!DIBasicType", 0) >= 0 Or StringIndexOf(LineText, "!DIExpression()", 0) >= 0 Then
                KeepLine = 0
            End If
            If StringIndexOf(LineText, "emissionKind: FullDebug", 0) >= 0 Then
                LineText = ReplaceFirstLlvmText(LineText, "emissionKind: FullDebug", "emissionKind: LineTablesOnly")
            End If
        Else
            If StringLength(LineText) > 0 Then
                If StringByteAt(LineText, 0) = 33 Then
                    KeepLine = 0
                End If
            End If
            Dim DebugMarker As Long = StringIndexOf(LineText, " !dbg !", 0)
            If DebugMarker >= 0 Then
                Dim PrefixEnd As Long = DebugMarker
                If PrefixEnd > 0 Then
                    If StringByteAt(LineText, PrefixEnd - 1) = 44 Then
                        PrefixEnd = PrefixEnd - 1
                    End If
                End If
                Dim Brace As Long = StringIndexOf(LineText, "{", DebugMarker)
                If Brace >= 0 Then
                    LineText = StringSlice(LineText, 0, PrefixEnd) & " " & StringSlice(LineText, Brace, StringLength(LineText) - Brace)
                Else
                    LineText = StringSlice(LineText, 0, PrefixEnd)
                End If
            End If
        End If
        If KeepLine <> 0 Then
            Result = Result & LineText
            If LineEnd < StringLength(LlvmText) Then
                Result = Result & StringFromByte(10)
            End If
        End If
        Cursor = LineEnd + 1
    Wend
    FilterLlvmDebugInformation = Result
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
                ClassDefinition = ClassDefinition & ", i8"
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

Function EmitRp7ErrorInstructionToLlvm(ByVal InstructionIndex As Long, ByVal DebugNode As Long, ByRef Abi As TargetAbiDescription, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Functions() As IrFunction, ByVal FunctionCount As Long, ByRef Parameters() As IrParameter, ByRef Storages() As IrStorage, ByVal StorageCount As Long, ByRef Instructions() As IrInstruction, ByVal InstructionCount As Long, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByRef Cleanups() As IrCleanup, ByVal CleanupCount As Long, ByVal ReturnType As String, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim NewLine As String = StringFromByte(10)
    Dim Opcode As Long = Instructions(InstructionIndex).Opcode
    Dim FunctionIndex As Long = Instructions(InstructionIndex).FunctionIndex
    Dim ResultName As String = LlvmValueName(Instructions(InstructionIndex).ResultValue)
    Dim ResultType As String = LlvmTypeForSemanticType(Instructions(InstructionIndex).ResultType, Types, TypeCount, Abi)
    Dim FirstOperand As Long = LlvmOperandAt(InstructionIndex, 0, Instructions, Operands)
    Dim SecondOperand As Long = LlvmOperandAt(InstructionIndex, 1, Instructions, Operands)
    Dim LineText As String = ""

    If Opcode = IrOpErrorTest() Then
        If EqualsFolded(Instructions(InstructionIndex).ImmediateText, "Number") <> 0 Then
            LineText = "  " & ResultName & " = call i32 @ube_err_number()" & NewLine
        Else
            If EqualsFolded(Instructions(InstructionIndex).ImmediateText, "Description") <> 0 Then
                LineText = "  " & ResultName & " = call ptr @ube_err_description()" & NewLine
            Else
                If EqualsFolded(Instructions(InstructionIndex).ImmediateText, "Source") <> 0 Then
                    LineText = "  " & ResultName & " = call ptr @ube_err_source()" & NewLine
                Else
                    Call AddIrDiagnostic("UBE5108", "error-test instruction has an unknown Err member", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    EmitRp7ErrorInstructionToLlvm = 0
                    Exit Function
                End If
            End If
        End If
        If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation(LineText, DebugNode)) = 0 Then
            EmitRp7ErrorInstructionToLlvm = 0
            Exit Function
        End If
        EmitRp7ErrorInstructionToLlvm = 1
        Exit Function
    End If
    If Opcode = IrOpErrorClear() Then
        If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation("  call void @ube_err_clear()" & NewLine, DebugNode)) = 0 Then
            EmitRp7ErrorInstructionToLlvm = 0
            Exit Function
        End If
        EmitRp7ErrorInstructionToLlvm = 1
        Exit Function
    End If
    If Opcode = IrOpErrorSet() Then
        If FirstOperand < 0 Or Operands(FirstOperand).OperandKind <> IrOperandValue() Then
            Call AddIrDiagnostic("UBE5108", "error-set instruction requires a Long value", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitRp7ErrorInstructionToLlvm = 0
            Exit Function
        End If
        LineText = "  call void @ube_err_set(i32 " & LlvmValueName(Operands(FirstOperand).ReferencedIndex) & ", ptr null, ptr null)" & NewLine
        If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation(LineText, DebugNode)) = 0 Then
            EmitRp7ErrorInstructionToLlvm = 0
            Exit Function
        End If
        EmitRp7ErrorInstructionToLlvm = 1
        Exit Function
    End If
    If Opcode = IrOpErrorDispatch() Then
        If Instructions(InstructionIndex).OperandCount < 6 Then
            Call AddIrDiagnostic("UBE5108", "error-dispatch instruction lacks procedure state", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitRp7ErrorInstructionToLlvm = 0
            Exit Function
        End If
        Dim DispatchModeOperand As Long = LlvmOperandAt(InstructionIndex, 0, Instructions, Operands)
        Dim DispatchSiteOperand As Long = LlvmOperandAt(InstructionIndex, 1, Instructions, Operands)
        Dim DispatchActiveOperand As Long = LlvmOperandAt(InstructionIndex, 2, Instructions, Operands)
        Dim DispatchSiteIdOperand As Long = LlvmOperandAt(InstructionIndex, 3, Instructions, Operands)
        Dim DispatchModeAddress As String = LlvmStorageAddress(Operands(DispatchModeOperand).ReferencedIndex, FunctionIndex, Storages, Functions, Parameters)
        Dim DispatchSiteAddress As String = LlvmStorageAddress(Operands(DispatchSiteOperand).ReferencedIndex, FunctionIndex, Storages, Functions, Parameters)
        Dim DispatchActiveAddress As String = LlvmStorageAddress(Operands(DispatchActiveOperand).ReferencedIndex, FunctionIndex, Storages, Functions, Parameters)
        Dim DispatchModeName As String = "%error.mode." & LongToString(InstructionIndex)
        Dim DispatchActiveName As String = "%error.active." & LongToString(InstructionIndex)
        Dim DispatchInactiveLabel As String = "error.dispatch.inactive." & LongToString(InstructionIndex)
        Dim DispatchHandlerLabel As String = "error.dispatch.handler." & LongToString(InstructionIndex)
        Dim DispatchNextLabel As String = LlvmBlockLabel(Instructions(InstructionIndex).PrimaryTarget)
        Dim DispatchFailureLabel As String = LlvmBlockLabel(Instructions(InstructionIndex).SecondaryTarget)
        LineText = "  store i32 " & LongToString(Operands(DispatchSiteIdOperand).ReferencedIndex) & ", ptr " & DispatchSiteAddress & NewLine
        LineText = LineText & "  " & DispatchActiveName & " = load i1, ptr " & DispatchActiveAddress & NewLine
        LineText = LineText & "  br i1 " & DispatchActiveName & ", label %" & DispatchFailureLabel & ", label %" & DispatchInactiveLabel & NewLine
        LineText = LineText & DispatchInactiveLabel & ":" & NewLine
        LineText = LineText & "  " & DispatchModeName & " = load i32, ptr " & DispatchModeAddress & NewLine
        Dim DispatchHasHandlerName As String = "%error.has.handler." & LongToString(InstructionIndex)
        LineText = LineText & "  " & DispatchHasHandlerName & " = icmp sgt i32 " & DispatchModeName & ", 0" & NewLine
        LineText = LineText & "  br i1 " & DispatchHasHandlerName & ", label %" & DispatchHandlerLabel & ", label %" & DispatchNextLabel & NewLine
        LineText = LineText & DispatchHandlerLabel & ":" & NewLine
        Dim DispatchMonitorStorage As Long = 0
        While DispatchMonitorStorage < StorageCount
            If Storages(DispatchMonitorStorage).FunctionIndex = FunctionIndex And (Storages(DispatchMonitorStorage).Flags And 4096) <> 0 Then
                Dim DispatchMonitorAddress As String = LlvmStorageAddress(DispatchMonitorStorage, FunctionIndex, Storages, Functions, Parameters)
                Dim DispatchMonitorValue As String = "%error.monitor." & LongToString(InstructionIndex) & "." & LongToString(DispatchMonitorStorage)
                LineText = LineText & "  " & DispatchMonitorValue & " = load ptr, ptr " & DispatchMonitorAddress & NewLine
                LineText = LineText & "  call void @ube_monitor_error_release(ptr " & DispatchMonitorValue & ")" & NewLine
            End If
            DispatchMonitorStorage = DispatchMonitorStorage + 1
        Wend
        LineText = LineText & "  store i1 true, ptr " & DispatchActiveAddress & NewLine
        LineText = LineText & "  switch i32 " & DispatchModeName & ", label %" & DispatchFailureLabel & " ["
        Dim DispatchPair As Long = 6
        While DispatchPair + 1 < Instructions(InstructionIndex).OperandCount
            Dim DispatchCodeOperand As Long = LlvmOperandAt(InstructionIndex, DispatchPair, Instructions, Operands)
            Dim DispatchBlockOperand As Long = LlvmOperandAt(InstructionIndex, DispatchPair + 1, Instructions, Operands)
            LineText = LineText & " i32 " & LongToString(Operands(DispatchCodeOperand).ReferencedIndex) & ", label %" & LlvmBlockLabel(Operands(DispatchBlockOperand).ReferencedIndex)
            DispatchPair = DispatchPair + 2
        Wend
        LineText = LineText & " ]" & NewLine
        If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation(LineText, DebugNode)) = 0 Then
            EmitRp7ErrorInstructionToLlvm = 0
            Exit Function
        End If
        EmitRp7ErrorInstructionToLlvm = 1
        Exit Function
    End If
    If Opcode = IrOpResume() Then
        If Instructions(InstructionIndex).OperandCount < 3 Then
            Call AddIrDiagnostic("UBE5108", "resume instruction lacks procedure state", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitRp7ErrorInstructionToLlvm = 0
            Exit Function
        End If
        Dim ResumeSiteOperand As Long = LlvmOperandAt(InstructionIndex, 1, Instructions, Operands)
        Dim ResumeActiveOperand As Long = LlvmOperandAt(InstructionIndex, 2, Instructions, Operands)
        Dim ResumeSiteAddress As String = LlvmStorageAddress(Operands(ResumeSiteOperand).ReferencedIndex, FunctionIndex, Storages, Functions, Parameters)
        Dim ResumeActiveAddress As String = LlvmStorageAddress(Operands(ResumeActiveOperand).ReferencedIndex, FunctionIndex, Storages, Functions, Parameters)
        Dim ResumeActiveName As String = "%resume.active." & LongToString(InstructionIndex)
        Dim ResumeRouteLabel As String = "resume.route." & LongToString(InstructionIndex)
        LineText = "  " & ResumeActiveName & " = load i1, ptr " & ResumeActiveAddress & NewLine
        LineText = LineText & "  br i1 " & ResumeActiveName & ", label %" & ResumeRouteLabel & ", label %" & LlvmBlockLabel(Instructions(InstructionIndex).FailureTarget) & NewLine
        LineText = LineText & ResumeRouteLabel & ":" & NewLine
        If Instructions(InstructionIndex).Flags <> 2 Then
            Dim ResumeMonitorStorage As Long = 0
            While ResumeMonitorStorage < StorageCount
                If Storages(ResumeMonitorStorage).FunctionIndex = FunctionIndex And (Storages(ResumeMonitorStorage).Flags And 4096) <> 0 Then
                    Dim ResumeMonitorAddress As String = LlvmStorageAddress(ResumeMonitorStorage, FunctionIndex, Storages, Functions, Parameters)
                    Dim ResumeMonitorValue As String = "%resume.monitor." & LongToString(InstructionIndex) & "." & LongToString(ResumeMonitorStorage)
                    LineText = LineText & "  " & ResumeMonitorValue & " = load ptr, ptr " & ResumeMonitorAddress & NewLine
                    LineText = LineText & "  call void @ube_monitor_error_resume(ptr " & ResumeMonitorValue & ")" & NewLine
                End If
                ResumeMonitorStorage = ResumeMonitorStorage + 1
            Wend
        End If
        LineText = LineText & "  call void @ube_err_clear()" & NewLine & "  store i1 false, ptr " & ResumeActiveAddress & NewLine
        If Instructions(InstructionIndex).Flags = 2 Then
            LineText = LineText & "  br label %" & LlvmBlockLabel(Instructions(InstructionIndex).PrimaryTarget) & NewLine
        Else
            Dim ResumeSiteName As String = "%resume.site." & LongToString(InstructionIndex)
            LineText = LineText & "  " & ResumeSiteName & " = load i32, ptr " & ResumeSiteAddress & NewLine
            LineText = LineText & "  switch i32 " & ResumeSiteName & ", label %" & LlvmBlockLabel(Instructions(InstructionIndex).FailureTarget) & " ["
            Dim ResumeDispatchIndex As Long = 0
            While ResumeDispatchIndex < InstructionCount
                If Instructions(ResumeDispatchIndex).FunctionIndex = FunctionIndex And Instructions(ResumeDispatchIndex).Opcode = IrOpErrorDispatch() Then
                    Dim ResumeDispatchSite As Long = LlvmOperandAt(ResumeDispatchIndex, 3, Instructions, Operands)
                    Dim ResumeDispatchTarget As Long = LlvmOperandAt(ResumeDispatchIndex, 4, Instructions, Operands)
                    If Instructions(InstructionIndex).Flags = 1 Then
                        ResumeDispatchTarget = LlvmOperandAt(ResumeDispatchIndex, 5, Instructions, Operands)
                    End If
                    LineText = LineText & " i32 " & LongToString(Operands(ResumeDispatchSite).ReferencedIndex) & ", label %" & LlvmBlockLabel(Operands(ResumeDispatchTarget).ReferencedIndex)
                End If
                ResumeDispatchIndex = ResumeDispatchIndex + 1
            Wend
            LineText = LineText & " ]" & NewLine
        End If
        If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation(LineText, DebugNode)) = 0 Then
            EmitRp7ErrorInstructionToLlvm = 0
            Exit Function
        End If
        EmitRp7ErrorInstructionToLlvm = 1
        Exit Function
    End If
    EmitRp7ErrorInstructionToLlvm = 0
End Function

Function EmitRp7ComponentInstructionToLlvm(ByVal InstructionIndex As Long, ByVal DebugNode As Long, ByRef Abi As TargetAbiDescription, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Functions() As IrFunction, ByVal FunctionCount As Long, ByRef Parameters() As IrParameter, ByRef Storages() As IrStorage, ByVal StorageCount As Long, ByRef Instructions() As IrInstruction, ByVal InstructionCount As Long, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByRef Cleanups() As IrCleanup, ByVal CleanupCount As Long, ByVal ReturnType As String, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim NewLine As String = StringFromByte(10)
    Dim Opcode As Long = Instructions(InstructionIndex).Opcode
    Dim FunctionIndex As Long = Instructions(InstructionIndex).FunctionIndex
    Dim ResultName As String = LlvmValueName(Instructions(InstructionIndex).ResultValue)
    Dim ResultType As String = LlvmTypeForSemanticType(Instructions(InstructionIndex).ResultType, Types, TypeCount, Abi)
    Dim FirstOperand As Long = LlvmOperandAt(InstructionIndex, 0, Instructions, Operands)
    Dim SecondOperand As Long = LlvmOperandAt(InstructionIndex, 1, Instructions, Operands)
    Dim LineText As String = ""

    If Opcode = IrOpLoadComponent() Or Opcode = IrOpUnloadComponent() Then
        If FirstOperand < 0 Or SecondOperand < 0 Or Operands(FirstOperand).OperandKind <> IrOperandStorage() Or Operands(SecondOperand).OperandKind <> IrOperandInteger() Then
            Call AddIrDiagnostic("UBE5108", "component lifecycle instruction has invalid operands", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitRp7ComponentInstructionToLlvm = 0
            Exit Function
        End If
        Dim ComponentStorage As Long = Operands(FirstOperand).ReferencedIndex
        Dim ComponentKind As Long = Operands(SecondOperand).ReferencedIndex
        Dim ComponentAddress As String = LlvmStorageAddress(ComponentStorage, FunctionIndex, Storages, Functions, Parameters)
        Dim ComponentValue As String = "%component.value." & LongToString(InstructionIndex)
        Dim ComponentMergeLabel As String = "component.merge." & LongToString(InstructionIndex)
        Dim ComponentType As Long = Storages(ComponentStorage).TypeIndex
        Dim ComponentModule As Long = -1
        If ComponentType >= 0 And ComponentType < TypeCount Then
            ComponentModule = Types(ComponentType).TypeSymbol
        End If
        If (Storages(ComponentStorage).Flags And 256) <> 0 And Opcode = IrOpLoadComponent() Then
            LineText = "  " & ComponentValue & " = call ptr @ube_default_form_ensure(ptr " & ComponentAddress & ", ptr @ube.object.layout." & LongToString(ComponentModule) & ", ptr @ube.object.initialize." & LongToString(ComponentModule) & ", i32 1)" & NewLine
        Else
            LineText = "  " & ComponentValue & " = load ptr, ptr " & ComponentAddress & NewLine
        End If
        Dim ComponentHookName As String = "Form_Load"
        If ComponentKind = 52 Then
            ComponentHookName = "Control_Load"
        End If
        If Opcode = IrOpUnloadComponent() Then
            If ComponentKind = 51 Then
                ComponentHookName = "Form_Unload"
            Else
                ComponentHookName = "Control_Unload"
            End If
        End If
        Dim ComponentHookFunction As Long = -1
        Dim ComponentHookSymbol As Long = 0
        While ComponentHookSymbol < SymbolCount
            If Symbols(ComponentHookSymbol).ParentSymbol = ComponentModule And Symbols(ComponentHookSymbol).SymbolKind = SemanticSymbolProcedure() And EqualsFolded(Symbols(ComponentHookSymbol).SymbolName, ComponentHookName) <> 0 Then
                ComponentHookFunction = SemanticFunctionIndex(ComponentHookSymbol, Functions, FunctionCount)
                Exit While
            End If
            ComponentHookSymbol = ComponentHookSymbol + 1
        Wend
        Dim ComponentReceiverBefore As String = ""
        Dim ComponentReceiverAfter As String = ""
        Dim ComponentPreviousObject As String = "%component.previous.object." & LongToString(InstructionIndex)
        ComponentReceiverBefore = "  " & ComponentPreviousObject & " = load ptr, ptr @ube.current.object" & NewLine
        ComponentReceiverBefore = ComponentReceiverBefore & "  store ptr " & ComponentValue & ", ptr @ube.current.object" & NewLine
        Dim ComponentFieldOrdinal As Long = 0
        Dim ComponentFieldSymbol As Long = 0
        While ComponentFieldSymbol < SymbolCount
            If Symbols(ComponentFieldSymbol).ParentSymbol = ComponentModule And Symbols(ComponentFieldSymbol).SymbolKind = SemanticSymbolVariable() Then
                Dim ComponentFieldStorage As Long = LlvmGlobalStorageForSymbol(ComponentFieldSymbol, Storages, StorageCount)
                If ComponentFieldStorage >= 0 Then
                    Dim ComponentFieldType As String = LlvmTypeForSemanticType(Symbols(ComponentFieldSymbol).DeclaredType, Types, TypeCount, Abi)
                    Dim ComponentFieldAddress As String = "%component.field.address." & LongToString(InstructionIndex) & "." & LongToString(ComponentFieldOrdinal)
                    Dim ComponentFieldValue As String = "%component.field.value." & LongToString(InstructionIndex) & "." & LongToString(ComponentFieldOrdinal)
                    ComponentReceiverBefore = ComponentReceiverBefore & "  " & ComponentFieldAddress & " = getelementptr inbounds %ube.class." & LongToString(ComponentModule) & ", ptr " & ComponentValue & ", i32 0, i32 " & LongToString(ComponentFieldOrdinal + 1) & NewLine
                    ComponentReceiverBefore = ComponentReceiverBefore & "  " & ComponentFieldValue & " = load " & ComponentFieldType & ", ptr " & ComponentFieldAddress & NewLine
                    ComponentReceiverBefore = ComponentReceiverBefore & "  store " & ComponentFieldType & " " & ComponentFieldValue & ", ptr " & LlvmGlobalName(ComponentFieldStorage) & NewLine
                    Dim ComponentReturnValue As String = "%component.field.return." & LongToString(InstructionIndex) & "." & LongToString(ComponentFieldOrdinal)
                    ComponentReceiverAfter = ComponentReceiverAfter & "  " & ComponentReturnValue & " = load " & ComponentFieldType & ", ptr " & LlvmGlobalName(ComponentFieldStorage) & NewLine
                    ComponentReceiverAfter = ComponentReceiverAfter & "  store " & ComponentFieldType & " " & ComponentReturnValue & ", ptr " & ComponentFieldAddress & NewLine
                End If
                ComponentFieldOrdinal = ComponentFieldOrdinal + 1
            End If
            ComponentFieldSymbol = ComponentFieldSymbol + 1
        Wend
        ComponentReceiverAfter = ComponentReceiverAfter & "  store ptr " & ComponentPreviousObject & ", ptr @ube.current.object" & NewLine
        If Opcode = IrOpLoadComponent() Then
            Dim ComponentLoadStatus As String = "%component.load.status." & LongToString(InstructionIndex)
            Dim ComponentLoadFailed As String = "%component.load.failed." & LongToString(InstructionIndex)
            Dim ComponentLoadFirst As String = "%component.load.first." & LongToString(InstructionIndex)
            Dim ComponentLoadHookLabel As String = "component.load.hook." & LongToString(InstructionIndex)
            Dim ComponentLoadKnownLabel As String = "component.load.known." & LongToString(InstructionIndex)
            LineText = LineText & "  " & ComponentLoadStatus & " = call i32 @ube_component_begin_load(ptr " & ComponentValue & ", i32 " & LongToString(ComponentKind) & ")" & NewLine
            LineText = LineText & "  " & ComponentLoadFailed & " = icmp eq i32 " & ComponentLoadStatus & ", 0" & NewLine
            LineText = LineText & "  br i1 " & ComponentLoadFailed & ", label %" & LlvmBlockLabel(Instructions(InstructionIndex).FailureTarget) & ", label %" & ComponentLoadKnownLabel & NewLine
            LineText = LineText & ComponentLoadKnownLabel & ":" & NewLine
            LineText = LineText & "  " & ComponentLoadFirst & " = icmp eq i32 " & ComponentLoadStatus & ", 1" & NewLine
            LineText = LineText & "  br i1 " & ComponentLoadFirst & ", label %" & ComponentLoadHookLabel & ", label %" & ComponentMergeLabel & NewLine
            LineText = LineText & ComponentLoadHookLabel & ":" & NewLine & ComponentReceiverBefore
            If ComponentHookFunction >= 0 Then
                LineText = LineText & "  call void @" & LlvmFunctionName(ComponentHookFunction, Functions, Symbols) & "()" & NewLine
            End If
            LineText = LineText & ComponentReceiverAfter
            Dim ComponentFinishStatus As String = "%component.finish.status." & LongToString(InstructionIndex)
            Dim ComponentFinishFailed As String = "%component.finish.failed." & LongToString(InstructionIndex)
            LineText = LineText & "  " & ComponentFinishStatus & " = call i32 @ube_component_finish_load(ptr " & ComponentValue & ", i32 1)" & NewLine
            LineText = LineText & "  " & ComponentFinishFailed & " = icmp eq i32 " & ComponentFinishStatus & ", 0" & NewLine
            LineText = LineText & "  br i1 " & ComponentFinishFailed & ", label %" & LlvmBlockLabel(Instructions(InstructionIndex).FailureTarget) & ", label %" & ComponentMergeLabel & NewLine
            LineText = LineText & ComponentMergeLabel & ":" & NewLine
        Else
            Dim ComponentIsNothing As String = "%component.is.nothing." & LongToString(InstructionIndex)
            Dim ComponentUnloadHookLabel As String = "component.unload.hook." & LongToString(InstructionIndex)
            Dim ComponentUnloadAcceptLabel As String = "component.unload.accept." & LongToString(InstructionIndex)
            Dim ComponentCancelAddress As String = "%component.cancel.address." & LongToString(InstructionIndex)
            Dim ComponentCancelValue As String = "%component.cancel.value." & LongToString(InstructionIndex)
            Dim ComponentCancelled As String = "%component.cancelled." & LongToString(InstructionIndex)
            LineText = LineText & "  " & ComponentIsNothing & " = icmp eq ptr " & ComponentValue & ", null" & NewLine
            LineText = LineText & "  br i1 " & ComponentIsNothing & ", label %" & ComponentMergeLabel & ", label %" & ComponentUnloadHookLabel & NewLine
            LineText = LineText & ComponentUnloadHookLabel & ":" & NewLine
            LineText = LineText & "  " & ComponentCancelAddress & " = alloca i16" & NewLine & "  store i16 0, ptr " & ComponentCancelAddress & NewLine
            LineText = LineText & ComponentReceiverBefore
            If ComponentHookFunction >= 0 Then
                LineText = LineText & "  call void @" & LlvmFunctionName(ComponentHookFunction, Functions, Symbols) & "(ptr " & ComponentCancelAddress & ")" & NewLine
            End If
            LineText = LineText & ComponentReceiverAfter
            LineText = LineText & "  " & ComponentCancelValue & " = load i16, ptr " & ComponentCancelAddress & NewLine
            LineText = LineText & "  " & ComponentCancelled & " = icmp ne i16 " & ComponentCancelValue & ", 0" & NewLine
            LineText = LineText & "  br i1 " & ComponentCancelled & ", label %" & ComponentMergeLabel & ", label %" & ComponentUnloadAcceptLabel & NewLine
            LineText = LineText & ComponentUnloadAcceptLabel & ":" & NewLine
            LineText = LineText & "  call i32 @ube_component_accept_unload(ptr " & ComponentValue & ")" & NewLine
            LineText = LineText & "  br label %" & ComponentMergeLabel & NewLine & ComponentMergeLabel & ":" & NewLine
        End If
        If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation(LineText, DebugNode)) = 0 Then
            EmitRp7ComponentInstructionToLlvm = 0
            Exit Function
        End If
        EmitRp7ComponentInstructionToLlvm = 1
        Exit Function
    End If
    EmitRp7ComponentInstructionToLlvm = 0
End Function

Function EmitRp7EventInstructionToLlvm(ByVal InstructionIndex As Long, ByVal DebugNode As Long, ByRef Abi As TargetAbiDescription, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Functions() As IrFunction, ByVal FunctionCount As Long, ByRef Parameters() As IrParameter, ByRef Storages() As IrStorage, ByVal StorageCount As Long, ByRef Instructions() As IrInstruction, ByVal InstructionCount As Long, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByRef Cleanups() As IrCleanup, ByVal CleanupCount As Long, ByVal ReturnType As String, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim NewLine As String = StringFromByte(10)
    Dim Opcode As Long = Instructions(InstructionIndex).Opcode
    Dim FunctionIndex As Long = Instructions(InstructionIndex).FunctionIndex
    Dim ResultName As String = LlvmValueName(Instructions(InstructionIndex).ResultValue)
    Dim ResultType As String = LlvmTypeForSemanticType(Instructions(InstructionIndex).ResultType, Types, TypeCount, Abi)
    Dim FirstOperand As Long = LlvmOperandAt(InstructionIndex, 0, Instructions, Operands)
    Dim SecondOperand As Long = LlvmOperandAt(InstructionIndex, 1, Instructions, Operands)
    Dim LineText As String = ""

    If Opcode = IrOpRaiseEvent() Then
        If FirstOperand < 0 Or Operands(FirstOperand).OperandKind <> IrOperandInteger() Then
            Call AddIrDiagnostic("UBE5108", "RaiseEvent instruction has no Event symbol", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitRp7EventInstructionToLlvm = 0
            Exit Function
        End If
        Dim RaisedEventSymbol As Long = Operands(FirstOperand).ReferencedIndex
        If RaisedEventSymbol < 0 Or RaisedEventSymbol >= SymbolCount Then
            Call AddIrDiagnostic("UBE5108", "RaiseEvent instruction names an invalid Event symbol", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitRp7EventInstructionToLlvm = 0
            Exit Function
        End If
        Dim RegistryArguments As String = "%event.arguments." & LongToString(InstructionIndex)
        Dim RegistrySource As String = "%event.registry.source." & LongToString(InstructionIndex)
        Dim RegistryStatus As String = "%event.registry.status." & LongToString(InstructionIndex)
        Dim RegistryAccepted As String = "%event.registry.accepted." & LongToString(InstructionIndex)
        Dim RegistryContinueLabel As String = "event.registry.continue." & LongToString(InstructionIndex)
        LineText = "  " & RegistryArguments & " = alloca %ube.event.args." & LongToString(RaisedEventSymbol) & NewLine
        Dim RegistryParameter As Long = 0
        Dim RegistryArgumentOrdinal As Long = 1
        Dim RegistryFieldOrdinal As Long = 0
        While RegistryParameter < SymbolCount
            If Symbols(RegistryParameter).ParentSymbol = RaisedEventSymbol And Symbols(RegistryParameter).SymbolKind = SemanticSymbolParameter() Then
                Dim RegistryOperand As Long = LlvmOperandAt(InstructionIndex, RegistryArgumentOrdinal, Instructions, Operands)
                If RegistryOperand < 0 Then
                    Call AddIrDiagnostic("UBE5108", "RaiseEvent instruction has too few arguments", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    EmitRp7EventInstructionToLlvm = 0
                    Exit Function
                End If
                Dim RegistryFieldAddress As String = "%event.argument.address." & LongToString(InstructionIndex) & "." & LongToString(RegistryFieldOrdinal)
                LineText = LineText & "  " & RegistryFieldAddress & " = getelementptr inbounds %ube.event.args." & LongToString(RaisedEventSymbol) & ", ptr " & RegistryArguments & ", i32 0, i32 " & LongToString(RegistryFieldOrdinal) & NewLine
                If (Symbols(RegistryParameter).Flags And 2) <> 0 Then
                    Dim RegistryValue As Long = Operands(RegistryOperand).ReferencedIndex
                    Dim RegistryValueType As String = LlvmValueType(RegistryValue, Values, Types, TypeCount, Abi)
                    LineText = LineText & "  store " & RegistryValueType & " " & LlvmValueName(RegistryValue) & ", ptr " & RegistryFieldAddress & NewLine
                Else
                    If Operands(RegistryOperand).OperandKind = IrOperandStorage() Then
                        LineText = LineText & "  store ptr " & LlvmStorageAddress(Operands(RegistryOperand).ReferencedIndex, FunctionIndex, Storages, Functions, Parameters) & ", ptr " & RegistryFieldAddress & NewLine
                    Else
                        LineText = LineText & "  store ptr " & LlvmValueName(Operands(RegistryOperand).ReferencedIndex) & ", ptr " & RegistryFieldAddress & NewLine
                    End If
                End If
                RegistryArgumentOrdinal = RegistryArgumentOrdinal + 1
                RegistryFieldOrdinal = RegistryFieldOrdinal + 1
            End If
            RegistryParameter = RegistryParameter + 1
        Wend
        LineText = LineText & "  " & RegistrySource & " = load ptr, ptr @ube.current.object" & NewLine
        LineText = LineText & "  " & RegistryStatus & " = call i32 @ube_event_dispatch(ptr " & RegistrySource & ", i64 " & LongToString(RaisedEventSymbol) & ", ptr " & RegistryArguments & ")" & NewLine
        LineText = LineText & "  " & RegistryAccepted & " = icmp ne i32 " & RegistryStatus & ", 0" & NewLine
        LineText = LineText & "  br i1 " & RegistryAccepted & ", label %" & RegistryContinueLabel & ", label %" & LlvmBlockLabel(Instructions(InstructionIndex).FailureTarget) & NewLine
        LineText = LineText & RegistryContinueLabel & ":" & NewLine
        If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation(LineText, DebugNode)) = 0 Then
            EmitRp7EventInstructionToLlvm = 0
            Exit Function
        End If
        EmitRp7EventInstructionToLlvm = 1
        Exit Function
        Dim RaisedEventOwner As Long = Symbols(RaisedEventSymbol).ParentSymbol
        Dim EventAdmissionName As String = "%event.admission." & LongToString(InstructionIndex)
        Dim EventAllowedName As String = "%event.allowed." & LongToString(InstructionIndex)
        Dim EventDispatchLabel As String = "event.dispatch." & LongToString(InstructionIndex)
        Dim EventFinishLabel As String = "event.finish." & LongToString(InstructionIndex)
        LineText = "  " & EventAdmissionName & " = call i32 @ube_event_enter()" & NewLine
        LineText = LineText & "  " & EventAllowedName & " = icmp ne i32 " & EventAdmissionName & ", 0" & NewLine
        LineText = LineText & "  br i1 " & EventAllowedName & ", label %" & EventDispatchLabel & ", label %" & LlvmBlockLabel(Instructions(InstructionIndex).FailureTarget) & NewLine
        LineText = LineText & EventDispatchLabel & ":" & NewLine
        Dim EventSourceName As String = "%event.source." & LongToString(InstructionIndex)
        LineText = LineText & "  " & EventSourceName & " = load ptr, ptr @ube.current.object" & NewLine
        Dim SubscriberCount As Long = 0
        Dim SubscriberSymbol As Long = 0
        While SubscriberSymbol < SymbolCount
            If Symbols(SubscriberSymbol).SymbolKind = SemanticSymbolVariable() And (Symbols(SubscriberSymbol).Flags And 128) <> 0 Then
                Dim SubscriberType As Long = Symbols(SubscriberSymbol).DeclaredType
                If SubscriberType >= 0 And SubscriberType < TypeCount Then
                    If Types(SubscriberType).TypeSymbol = RaisedEventOwner Then
                        Dim SubscriberHandlerName As String = Symbols(SubscriberSymbol).SymbolName & "_" & Symbols(RaisedEventSymbol).SymbolName
                        Dim SubscriberHandler As Long = 0
                        While SubscriberHandler < SymbolCount
                            If Symbols(SubscriberHandler).ParentSymbol = Symbols(SubscriberSymbol).ParentSymbol And Symbols(SubscriberHandler).SymbolKind = SemanticSymbolProcedure() And EqualsFolded(Symbols(SubscriberHandler).SymbolName, SubscriberHandlerName) <> 0 Then
                                Dim SubscriberHandlerFunction As Long = SemanticFunctionIndex(SubscriberHandler, Functions, FunctionCount)
                                Dim SubscriberStorage As Long = LlvmGlobalStorageForSymbol(SubscriberSymbol, Storages, StorageCount)
                                If SubscriberHandlerFunction >= 0 And SubscriberStorage >= 0 Then
                                    LineText = LineText & "  %event.snapshot." & LongToString(InstructionIndex) & "." & LongToString(SubscriberCount) & " = load ptr, ptr " & LlvmGlobalName(SubscriberStorage) & NewLine
                                    SubscriberCount = SubscriberCount + 1
                                End If
                            End If
                            SubscriberHandler = SubscriberHandler + 1
                        Wend
                    End If
                End If
            End If
            SubscriberSymbol = SubscriberSymbol + 1
        Wend
        If SubscriberCount = 0 Then
            LineText = LineText & "  br label %" & EventFinishLabel & NewLine
        Else
            LineText = LineText & "  br label %event.check." & LongToString(InstructionIndex) & ".0" & NewLine
        End If
        Dim SubscriberOrdinal As Long = 0
        SubscriberSymbol = 0
        While SubscriberSymbol < SymbolCount
            If Symbols(SubscriberSymbol).SymbolKind = SemanticSymbolVariable() And (Symbols(SubscriberSymbol).Flags And 128) <> 0 Then
                SubscriberType = Symbols(SubscriberSymbol).DeclaredType
                If SubscriberType >= 0 And SubscriberType < TypeCount Then
                    If Types(SubscriberType).TypeSymbol = RaisedEventOwner Then
                        SubscriberHandlerName = Symbols(SubscriberSymbol).SymbolName & "_" & Symbols(RaisedEventSymbol).SymbolName
                        SubscriberHandler = 0
                        While SubscriberHandler < SymbolCount
                            If Symbols(SubscriberHandler).ParentSymbol = Symbols(SubscriberSymbol).ParentSymbol And Symbols(SubscriberHandler).SymbolKind = SemanticSymbolProcedure() And EqualsFolded(Symbols(SubscriberHandler).SymbolName, SubscriberHandlerName) <> 0 Then
                                SubscriberHandlerFunction = SemanticFunctionIndex(SubscriberHandler, Functions, FunctionCount)
                                SubscriberStorage = LlvmGlobalStorageForSymbol(SubscriberSymbol, Storages, StorageCount)
                                If SubscriberHandlerFunction >= 0 And SubscriberStorage >= 0 Then
                                    Dim EventCheckLabel As String = "event.check." & LongToString(InstructionIndex) & "." & LongToString(SubscriberOrdinal)
                                    Dim EventCallLabel As String = "event.call." & LongToString(InstructionIndex) & "." & LongToString(SubscriberOrdinal)
                                    Dim EventNextLabel As String = EventFinishLabel
                                    If SubscriberOrdinal + 1 < SubscriberCount Then
                                        EventNextLabel = "event.check." & LongToString(InstructionIndex) & "." & LongToString(SubscriberOrdinal + 1)
                                    End If
                                    Dim EventCurrentName As String = "%event.current." & LongToString(InstructionIndex) & "." & LongToString(SubscriberOrdinal)
                                    Dim EventStillName As String = "%event.still." & LongToString(InstructionIndex) & "." & LongToString(SubscriberOrdinal)
                                    Dim EventSourceMatchName As String = "%event.source.match." & LongToString(InstructionIndex) & "." & LongToString(SubscriberOrdinal)
                                    Dim EventConnectedName As String = "%event.connected." & LongToString(InstructionIndex) & "." & LongToString(SubscriberOrdinal)
                                    Dim EventDispatchName As String = "%event.should.call." & LongToString(InstructionIndex) & "." & LongToString(SubscriberOrdinal)
                                    Dim EventSnapshotName As String = "%event.snapshot." & LongToString(InstructionIndex) & "." & LongToString(SubscriberOrdinal)
                                    LineText = LineText & EventCheckLabel & ":" & NewLine
                                    LineText = LineText & "  " & EventCurrentName & " = load ptr, ptr " & LlvmGlobalName(SubscriberStorage) & NewLine
                                    LineText = LineText & "  " & EventStillName & " = icmp eq ptr " & EventCurrentName & ", " & EventSnapshotName & NewLine
                                    LineText = LineText & "  " & EventSourceMatchName & " = icmp eq ptr " & EventSnapshotName & ", " & EventSourceName & NewLine
                                    LineText = LineText & "  " & EventConnectedName & " = icmp ne ptr " & EventSnapshotName & ", null" & NewLine
                                    LineText = LineText & "  " & EventDispatchName & " = and i1 " & EventStillName & ", " & EventSourceMatchName & NewLine
                                    LineText = LineText & "  " & EventDispatchName & ".connected = and i1 " & EventDispatchName & ", " & EventConnectedName & NewLine
                                    LineText = LineText & "  br i1 " & EventDispatchName & ".connected, label %" & EventCallLabel & ", label %" & EventNextLabel & NewLine
                                    LineText = LineText & EventCallLabel & ":" & NewLine
                                    Dim EventCallArguments As String = ""
                                    Dim EventArgumentOffset As Long = 0
                                    While EventArgumentOffset < Functions(SubscriberHandlerFunction).ParameterCount
                                        If EventArgumentOffset > 0 Then
                                            EventCallArguments = EventCallArguments & ", "
                                        End If
                                        Dim EventArgumentOperand As Long = LlvmOperandAt(InstructionIndex, EventArgumentOffset + 1, Instructions, Operands)
                                        Dim EventHandlerParameter As Long = Functions(SubscriberHandlerFunction).FirstParameter + EventArgumentOffset
                                        If Parameters(EventHandlerParameter).PassingMode = IrPassingByRef() Then
                                            If Operands(EventArgumentOperand).OperandKind = IrOperandStorage() Then
                                                EventCallArguments = EventCallArguments & "ptr " & LlvmStorageAddress(Operands(EventArgumentOperand).ReferencedIndex, FunctionIndex, Storages, Functions, Parameters)
                                            Else
                                                EventCallArguments = EventCallArguments & "ptr " & LlvmValueName(Operands(EventArgumentOperand).ReferencedIndex)
                                            End If
                                        Else
                                            Dim EventArgumentValue As Long = Operands(EventArgumentOperand).ReferencedIndex
                                            EventCallArguments = EventCallArguments & LlvmValueType(EventArgumentValue, Values, Types, TypeCount, Abi) & " " & LlvmValueName(EventArgumentValue)
                                        End If
                                        EventArgumentOffset = EventArgumentOffset + 1
                                    Wend
                                    LineText = LineText & "  call void @" & LlvmFunctionName(SubscriberHandlerFunction, Functions, Symbols) & "(" & EventCallArguments & ")" & NewLine
                                    LineText = LineText & "  br label %" & EventNextLabel & NewLine
                                    SubscriberOrdinal = SubscriberOrdinal + 1
                                End If
                            End If
                            SubscriberHandler = SubscriberHandler + 1
                        Wend
                    End If
                End If
            End If
            SubscriberSymbol = SubscriberSymbol + 1
        Wend
        LineText = LineText & EventFinishLabel & ":" & NewLine & "  call void @ube_event_leave()" & NewLine
        If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation(LineText, DebugNode)) = 0 Then
            EmitRp7EventInstructionToLlvm = 0
            Exit Function
        End If
        EmitRp7EventInstructionToLlvm = 1
        Exit Function
    End If
    EmitRp7EventInstructionToLlvm = 0
End Function

Function EmitRp7MonitorInstructionToLlvm(ByVal InstructionIndex As Long, ByVal DebugNode As Long, ByRef Abi As TargetAbiDescription, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Functions() As IrFunction, ByVal FunctionCount As Long, ByRef Parameters() As IrParameter, ByRef Storages() As IrStorage, ByVal StorageCount As Long, ByRef Instructions() As IrInstruction, ByVal InstructionCount As Long, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByRef Cleanups() As IrCleanup, ByVal CleanupCount As Long, ByVal ReturnType As String, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim NewLine As String = StringFromByte(10)
    Dim Opcode As Long = Instructions(InstructionIndex).Opcode
    Dim FunctionIndex As Long = Instructions(InstructionIndex).FunctionIndex
    Dim ResultName As String = LlvmValueName(Instructions(InstructionIndex).ResultValue)
    Dim ResultType As String = LlvmTypeForSemanticType(Instructions(InstructionIndex).ResultType, Types, TypeCount, Abi)
    Dim FirstOperand As Long = LlvmOperandAt(InstructionIndex, 0, Instructions, Operands)
    Dim SecondOperand As Long = LlvmOperandAt(InstructionIndex, 1, Instructions, Operands)
    Dim LineText As String = ""

    If Opcode = IrOpMonitorEnter() Or Opcode = IrOpMonitorExit() Then
        If FirstOperand < 0 Or Operands(FirstOperand).OperandKind <> IrOperandStorage() Then
            Call AddIrDiagnostic("UBE5108", "monitor instruction requires object storage", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitRp7MonitorInstructionToLlvm = 0
            Exit Function
        End If
        Dim MonitorStorage As Long = Operands(FirstOperand).ReferencedIndex
        Dim MonitorAddress As String = LlvmStorageAddress(MonitorStorage, FunctionIndex, Storages, Functions, Parameters)
        Dim MonitorValue As String = "%monitor.object." & LongToString(InstructionIndex)
        LineText = "  " & MonitorValue & " = load ptr, ptr " & MonitorAddress & NewLine
        If Opcode = IrOpMonitorEnter() Then
            Dim MonitorStatus As String = "%monitor.status." & LongToString(InstructionIndex)
            LineText = LineText & "  " & MonitorStatus & " = call i32 @ube_monitor_enter(ptr " & MonitorValue & ")" & NewLine
            LineText = LineText & "  " & ResultName & " = icmp ne i32 " & MonitorStatus & ", 0" & NewLine
        Else
            LineText = LineText & "  call void @ube_monitor_exit(ptr " & MonitorValue & ")" & NewLine
        End If
        If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation(LineText, DebugNode)) = 0 Then
            EmitRp7MonitorInstructionToLlvm = 0
            Exit Function
        End If
        EmitRp7MonitorInstructionToLlvm = 1
        Exit Function
    End If
    EmitRp7MonitorInstructionToLlvm = 0
End Function

Function EmitRp7CallNewInstructionToLlvm(ByVal InstructionIndex As Long, ByVal DebugNode As Long, ByRef Abi As TargetAbiDescription, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Functions() As IrFunction, ByVal FunctionCount As Long, ByRef Parameters() As IrParameter, ByRef Storages() As IrStorage, ByVal StorageCount As Long, ByRef Instructions() As IrInstruction, ByVal InstructionCount As Long, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByRef Cleanups() As IrCleanup, ByVal CleanupCount As Long, ByVal ReturnType As String, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim NewLine As String = StringFromByte(10)
    Dim Opcode As Long = Instructions(InstructionIndex).Opcode
    Dim FunctionIndex As Long = Instructions(InstructionIndex).FunctionIndex
    Dim ResultName As String = LlvmValueName(Instructions(InstructionIndex).ResultValue)
    Dim ResultType As String = LlvmTypeForSemanticType(Instructions(InstructionIndex).ResultType, Types, TypeCount, Abi)
    Dim FirstOperand As Long = LlvmOperandAt(InstructionIndex, 0, Instructions, Operands)
    Dim SecondOperand As Long = LlvmOperandAt(InstructionIndex, 1, Instructions, Operands)
    Dim LineText As String = ""

    If Opcode = IrOpCallNew() Then
        If FirstOperand < 0 Or Operands(FirstOperand).OperandKind <> IrOperandFunction() Then
            Call AddIrDiagnostic("UBE5108", "CallNew instruction has no Sub operand", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitRp7CallNewInstructionToLlvm = 0
            Exit Function
        End If
        Dim CallNewFunction As Long = Operands(FirstOperand).ReferencedIndex
        Dim CallNewCaptureType As String = "%ube.callnew.capture." & LongToString(InstructionIndex)
        Dim CallNewSlotCount As Long = 0
        Dim CallNewSlotText As String = ""
        Dim CallNewParameterOffset As Long = 0
        While CallNewParameterOffset < Functions(CallNewFunction).ParameterCount
            Dim CallNewParameterIndex As Long = Functions(CallNewFunction).FirstParameter + CallNewParameterOffset
            Call AppendLlvmCaptureSlotPaths(Parameters(CallNewParameterIndex).TypeIndex, CallNewCaptureType, "i32 0, i32 " & LongToString(CallNewParameterOffset), 0, Types, TypeCount, Symbols, SymbolCount, CallNewSlotCount, CallNewSlotText)
            CallNewParameterOffset = CallNewParameterOffset + 1
        Wend
        Dim CallNewSlotsPointer As String = "null"
        If CallNewSlotCount > 0 Then
            CallNewSlotsPointer = "getelementptr ([" & LongToString(CallNewSlotCount) & " x i64], ptr @ube.callnew.slots." & LongToString(InstructionIndex) & ", i32 0, i32 0)"
        End If
        Dim CallNewCaptureName As String = "%callnew.capture." & LongToString(InstructionIndex)
        Dim CallNewFailedName As String = "%callnew.failed." & LongToString(InstructionIndex)
        Dim CallNewFailureLabel As String = "callnew.failure." & LongToString(InstructionIndex)
        Dim CallNewStartLabel As String = "callnew.start." & LongToString(InstructionIndex)
        Dim CallNewMergeLabel As String = "callnew.merge." & LongToString(InstructionIndex)
        Dim CallNewStartedName As String = "%callnew.started." & LongToString(InstructionIndex)
        LineText = "  " & CallNewCaptureName & " = call ptr @ube_thread_capture_allocate(i64 ptrtoint (ptr getelementptr (" & CallNewCaptureType & ", ptr null, i32 1) to i64), i64 " & LongToString(CallNewSlotCount) & ", ptr " & CallNewSlotsPointer & ")" & NewLine
        LineText = LineText & "  " & CallNewFailedName & " = icmp eq ptr " & CallNewCaptureName & ", null" & NewLine
        LineText = LineText & "  br i1 " & CallNewFailedName & ", label %" & CallNewFailureLabel & ", label %" & CallNewStartLabel & NewLine
        LineText = LineText & CallNewStartLabel & ":" & NewLine
        CallNewParameterOffset = 0
        While CallNewParameterOffset < Functions(CallNewFunction).ParameterCount
            CallNewParameterIndex = Functions(CallNewFunction).FirstParameter + CallNewParameterOffset
            Dim CallNewArgumentOperand As Long = LlvmOperandAt(InstructionIndex, CallNewParameterOffset + 1, Instructions, Operands)
            If CallNewArgumentOperand < 0 Or Operands(CallNewArgumentOperand).OperandKind <> IrOperandValue() Then
                Call AddIrDiagnostic("UBE5108", "CallNew argument is not a ByVal value", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                EmitRp7CallNewInstructionToLlvm = 0
                Exit Function
            End If
            Dim CallNewArgumentValue As Long = Operands(CallNewArgumentOperand).ReferencedIndex
            Dim CallNewArgumentTypeIndex As Long = Parameters(CallNewParameterIndex).TypeIndex
            Dim CallNewArgumentType As String = LlvmTypeForSemanticType(CallNewArgumentTypeIndex, Types, TypeCount, Abi)
            Dim CallNewFieldAddress As String = "%callnew.field." & LongToString(InstructionIndex) & "." & LongToString(CallNewParameterOffset)
            LineText = LineText & "  " & CallNewFieldAddress & " = getelementptr inbounds " & CallNewCaptureType & ", ptr " & CallNewCaptureName & ", i32 0, i32 " & LongToString(CallNewParameterOffset) & NewLine
            Dim CallNewStoredValue As String = LlvmValueName(CallNewArgumentValue)
            If Types(CallNewArgumentTypeIndex).TypeKind = 40 Then
                Dim CallNewFixedCopy As String = "%callnew.fixed." & LongToString(InstructionIndex) & "." & LongToString(CallNewParameterOffset)
                LineText = LineText & "  " & CallNewFixedCopy & " = call ptr @ube_fixed_string_copy_managed(ptr " & CallNewStoredValue & ", i64 " & LongToString(Types(CallNewArgumentTypeIndex).FixedLength) & ")" & NewLine
                CallNewStoredValue = CallNewFixedCopy
            End If
            If EqualsFolded(Types(CallNewArgumentTypeIndex).TypeName, "Variant") <> 0 Then
                Dim CallNewVariantCopy As String = "%callnew.variant." & LongToString(InstructionIndex) & "." & LongToString(CallNewParameterOffset)
                LineText = LineText & "  " & CallNewVariantCopy & " = call ptr @ube_variant_copy(ptr " & CallNewStoredValue & ")" & NewLine
                CallNewStoredValue = CallNewVariantCopy
            End If
            If Types(CallNewArgumentTypeIndex).TypeKind = 26 Then
                Dim CallNewSourceAddress As String = "%callnew.source." & LongToString(InstructionIndex) & "." & LongToString(CallNewParameterOffset)
                LineText = LineText & "  " & CallNewSourceAddress & " = alloca " & CallNewArgumentType & NewLine
                LineText = LineText & "  store " & CallNewArgumentType & " " & CallNewStoredValue & ", ptr " & CallNewSourceAddress & NewLine
                LineText = LineText & "  call i32 @ube_value_copy_recursive(ptr " & CallNewFieldAddress & ", ptr " & CallNewSourceAddress & ", ptr @ube.value.layout." & LongToString(Types(CallNewArgumentTypeIndex).TypeSymbol) & ", i64 0, ptr null)" & NewLine
            Else
                LineText = LineText & "  store " & CallNewArgumentType & " " & CallNewStoredValue & ", ptr " & CallNewFieldAddress & NewLine
            End If
            CallNewParameterOffset = CallNewParameterOffset + 1
        Wend
        LineText = LineText & "  " & CallNewStartedName & " = call i64 @ube_thread_start(ptr @ube.callnew.thunk." & LongToString(InstructionIndex) & ", ptr " & CallNewCaptureName & ", ptr @ube_thread_capture_destroy)" & NewLine
        LineText = LineText & "  br label %" & CallNewMergeLabel & NewLine
        LineText = LineText & CallNewFailureLabel & ":" & NewLine & "  br label %" & CallNewMergeLabel & NewLine
        LineText = LineText & CallNewMergeLabel & ":" & NewLine
        LineText = LineText & "  " & ResultName & " = phi i64 [ 0, %" & CallNewFailureLabel & " ], [ " & CallNewStartedName & ", %" & CallNewStartLabel & " ]" & NewLine
        If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation(LineText, DebugNode)) = 0 Then
            EmitRp7CallNewInstructionToLlvm = 0
            Exit Function
        End If
        EmitRp7CallNewInstructionToLlvm = 1
        Exit Function
    End If
    EmitRp7CallNewInstructionToLlvm = 0
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

    If Opcode = IrOpErrorTest() Or Opcode = IrOpErrorSet() Or Opcode = IrOpErrorClear() Or Opcode = IrOpErrorDispatch() Or Opcode = IrOpResume() Then
        EmitIrInstructionToLlvm = EmitRp7ErrorInstructionToLlvm(InstructionIndex, DebugNode, Abi, Types, TypeCount, Symbols, SymbolCount, Functions, FunctionCount, Parameters, Storages, StorageCount, Instructions, InstructionCount, Operands, Values, Cleanups, CleanupCount, ReturnType, Chunks, ChunkCount, ChunkCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        Exit Function
    End If
    If Opcode = IrOpLoadComponent() Or Opcode = IrOpUnloadComponent() Then
        EmitIrInstructionToLlvm = EmitRp7ComponentInstructionToLlvm(InstructionIndex, DebugNode, Abi, Types, TypeCount, Symbols, SymbolCount, Functions, FunctionCount, Parameters, Storages, StorageCount, Instructions, InstructionCount, Operands, Values, Cleanups, CleanupCount, ReturnType, Chunks, ChunkCount, ChunkCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        Exit Function
    End If
    If Opcode = IrOpRaiseEvent() Then
        EmitIrInstructionToLlvm = EmitRp7EventInstructionToLlvm(InstructionIndex, DebugNode, Abi, Types, TypeCount, Symbols, SymbolCount, Functions, FunctionCount, Parameters, Storages, StorageCount, Instructions, InstructionCount, Operands, Values, Cleanups, CleanupCount, ReturnType, Chunks, ChunkCount, ChunkCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        Exit Function
    End If
    If Opcode = IrOpMonitorEnter() Or Opcode = IrOpMonitorExit() Then
        EmitIrInstructionToLlvm = EmitRp7MonitorInstructionToLlvm(InstructionIndex, DebugNode, Abi, Types, TypeCount, Symbols, SymbolCount, Functions, FunctionCount, Parameters, Storages, StorageCount, Instructions, InstructionCount, Operands, Values, Cleanups, CleanupCount, ReturnType, Chunks, ChunkCount, ChunkCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        Exit Function
    End If
    If Opcode = IrOpCallNew() Then
        EmitIrInstructionToLlvm = EmitRp7CallNewInstructionToLlvm(InstructionIndex, DebugNode, Abi, Types, TypeCount, Symbols, SymbolCount, Functions, FunctionCount, Parameters, Storages, StorageCount, Instructions, InstructionCount, Operands, Values, Cleanups, CleanupCount, ReturnType, Chunks, ChunkCount, ChunkCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        Exit Function
    End If

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
            Dim ObjectStorageSymbol As Long = Storages(ObjectMember).SymbolIndex
            If ObjectStorageSymbol >= 0 And ObjectStorageSymbol < SymbolCount Then
                If Symbols(ObjectStorageSymbol).ParentSymbol = ObjectModule And Symbols(ObjectStorageSymbol).SymbolKind = SemanticSymbolVariable() And Storages(ObjectMember).StorageKind = IrStorageGlobal() Then
                    Dim ObjectFieldType As String = LlvmTypeForSemanticType(Storages(ObjectMember).TypeIndex, Types, TypeCount, Abi)
                    LineText = LineText & "  store " & ObjectFieldType & " " & LlvmZeroValue(ObjectFieldType) & ", ptr " & LlvmGlobalName(ObjectMember) & NewLine
                    ObjectFieldOrdinal = ObjectFieldOrdinal + 1
                End If
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
                    If (Storages(LoadStorage).Flags And 256) <> 0 Then
                        Dim LoadSemanticType As Long = Storages(LoadStorage).TypeIndex
                        If LoadSemanticType >= 0 And LoadSemanticType < TypeCount Then
                            If Types(LoadSemanticType).TypeKind >= 50 And Types(LoadSemanticType).TypeKind <= 52 Then
                                If (Storages(LoadStorage).Flags And 256) <> 0 Then
                                    LineText = "  " & ResultName & " = call ptr @ube_default_form_ensure(ptr " & LoadAddress & ", ptr @ube.object.layout." & LongToString(Types(LoadSemanticType).TypeSymbol) & ", ptr @ube.object.initialize." & LongToString(Types(LoadSemanticType).TypeSymbol) & ", i32 0)" & NewLine
                                    Dim DefaultLoadStatus As String = "%default.form.load.status." & LongToString(InstructionIndex)
                                    Dim DefaultLoadHookLabel As String = "default.form.load.hook." & LongToString(InstructionIndex)
                                    Dim DefaultLoadMergeLabel As String = "default.form.load.merge." & LongToString(InstructionIndex)
                                    Dim DefaultLoadFailureBlock As Long = Instructions(InstructionIndex).FailureTarget
                                    If DefaultLoadFailureBlock < 0 Then
                                        DefaultLoadFailureBlock = Functions(FunctionIndex).FailureBlock
                                    End If
                                    LineText = LineText & "  " & DefaultLoadStatus & " = call i32 @ube_component_begin_load(ptr " & ResultName & ", i32 51)" & NewLine
                                    LineText = LineText & "  switch i32 " & DefaultLoadStatus & ", label %" & DefaultLoadMergeLabel & " [ i32 0, label %" & LlvmBlockLabel(DefaultLoadFailureBlock) & " i32 1, label %" & DefaultLoadHookLabel & " ]" & NewLine
                                    LineText = LineText & DefaultLoadHookLabel & ":" & NewLine
                                    LineText = LineText & "  call void @ube.object.load." & LongToString(Types(LoadSemanticType).TypeSymbol) & "(ptr " & ResultName & ")" & NewLine
                                    LineText = LineText & "  call i32 @ube_component_finish_load(ptr " & ResultName & ", i32 1)" & NewLine
                                    LineText = LineText & "  br label %" & DefaultLoadMergeLabel & NewLine & DefaultLoadMergeLabel & ":" & NewLine
                                Else
                                    LineText = "  " & ResultName & " = call ptr @ube_object_lazy_ensure(ptr " & LoadAddress & ", ptr @ube.object.layout." & LongToString(Types(LoadSemanticType).TypeSymbol) & ", ptr @ube.object.initialize." & LongToString(Types(LoadSemanticType).TypeSymbol) & ")" & NewLine
                                End If
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
                                    Dim ConvertRawName As String = "%convert.raw." & LongToString(InstructionIndex)
                                    Dim ConvertFailureLabel As String = "convert.failure." & LongToString(InstructionIndex)
                                    Dim ConvertMergeLabel As String = "convert.merge." & LongToString(InstructionIndex)
                                    LineText = "  " & ConvertRawName & " = trunc " & ConvertSourceType & " " & LlvmValueName(ConvertValue) & " to " & ResultType & NewLine
                                    LineText = LineText & "  " & ConvertWideName & " = sext " & ResultType & " " & ConvertRawName & " to " & ConvertSourceType & NewLine
                                    LineText = LineText & "  " & ConvertFailedName & " = icmp ne " & ConvertSourceType & " " & ConvertWideName & ", " & LlvmValueName(ConvertValue) & NewLine
                                    LineText = LineText & "  br i1 " & ConvertFailedName & ", label %" & ConvertFailureLabel & ", label %" & ConvertContinueLabel & NewLine
                                    LineText = LineText & ConvertFailureLabel & ":" & NewLine & "  call void @ube_err_set(i32 6, ptr null, ptr null)" & NewLine
                                    If Instructions(InstructionIndex).FailureTarget = Functions(FunctionIndex).FirstBlock + 2 Then
                                        LineText = LineText & "  br label %" & ConvertMergeLabel & NewLine & ConvertContinueLabel & ":" & NewLine & "  br label %" & ConvertMergeLabel & NewLine & ConvertMergeLabel & ":" & NewLine
                                        LineText = LineText & "  " & ResultName & " = phi " & ResultType & " [ 0, %" & ConvertFailureLabel & " ], [ " & ConvertRawName & ", %" & ConvertContinueLabel & " ]" & NewLine
                                    Else
                                        Dim ConvertNeutralLabel As String = "convert.neutral." & LongToString(InstructionIndex)
                                        Dim ConvertModeName As String = "%convert.mode." & LongToString(InstructionIndex)
                                        Dim ConvertModeZeroName As String = "%convert.mode.zero." & LongToString(InstructionIndex)
                                        Dim ConvertModeAddress As String = LlvmStorageAddress(Functions(FunctionIndex).ErrorModeStorage, FunctionIndex, Storages, Functions, Parameters)
                                        LineText = LineText & "  " & ConvertModeName & " = load i32, ptr " & ConvertModeAddress & NewLine
                                        LineText = LineText & "  " & ConvertModeZeroName & " = icmp eq i32 " & ConvertModeName & ", 0" & NewLine
                                        LineText = LineText & "  br i1 " & ConvertModeZeroName & ", label %" & ConvertNeutralLabel & ", label %" & LlvmBlockLabel(Instructions(InstructionIndex).FailureTarget) & NewLine
                                        LineText = LineText & ConvertNeutralLabel & ":" & NewLine & "  br label %" & ConvertMergeLabel & NewLine
                                        LineText = LineText & ConvertContinueLabel & ":" & NewLine & "  br label %" & ConvertMergeLabel & NewLine & ConvertMergeLabel & ":" & NewLine
                                        LineText = LineText & "  " & ResultName & " = phi " & ResultType & " [ 0, %" & ConvertNeutralLabel & " ], [ " & ConvertRawName & ", %" & ConvertContinueLabel & " ]" & NewLine
                                    End If
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
                    If Operands(FirstOperand).OperandKind = IrOperandStorage() Then
                        Dim EventStorage As Long = Operands(FirstOperand).ReferencedIndex
                        Dim EventFieldSymbol As Long = Storages(EventStorage).SymbolIndex
                        If EventFieldSymbol >= 0 And EventFieldSymbol < SymbolCount Then
                            If (Symbols(EventFieldSymbol).Flags And 128) <> 0 Then
                                Dim EventReceiver As String = "null"
                                Dim EventSubscriberOwner As Long = Symbols(EventFieldSymbol).ParentSymbol
                                If EventSubscriberOwner >= 0 Then
                                    If Symbols(EventSubscriberOwner).SymbolKind = SemanticSymbolModule() And Symbols(EventSubscriberOwner).Flags >= 2 Then
                                        EventReceiver = "%event.receiver." & LongToString(InstructionIndex)
                                        LineText = LineText & "  " & EventReceiver & " = load ptr, ptr @ube.current.object" & NewLine
                                    End If
                                End If
                                LineText = LineText & "  call void @ube_event_disconnect(ptr " & EventReceiver & ", i64 " & LongToString(EventFieldSymbol) & ")" & NewLine
                                Dim EventFieldType As Long = Symbols(EventFieldSymbol).DeclaredType
                                If EventFieldType >= 0 And EventFieldType < TypeCount Then
                                    Dim EventSourceModule As Long = Types(EventFieldType).TypeSymbol
                                    Dim ConnectedEvent As Long = 0
                                    Dim ConnectionOrdinal As Long = 0
                                    While ConnectedEvent < SymbolCount
                                        If Symbols(ConnectedEvent).SymbolKind = SemanticSymbolEvent() And Symbols(ConnectedEvent).ParentSymbol = EventSourceModule Then
                                            Dim ConnectionHandlerName As String = Symbols(EventFieldSymbol).SymbolName & "_" & Symbols(ConnectedEvent).SymbolName
                                            Dim ConnectionHandler As Long = 0
                                            Dim HasConnectionHandler As Long = 0
                                            While ConnectionHandler < SymbolCount
                                                If Symbols(ConnectionHandler).SymbolKind = SemanticSymbolProcedure() And Symbols(ConnectionHandler).ParentSymbol = EventSubscriberOwner And EqualsFolded(Symbols(ConnectionHandler).SymbolName, ConnectionHandlerName) <> 0 Then
                                                    HasConnectionHandler = 1
                                                End If
                                                ConnectionHandler = ConnectionHandler + 1
                                            Wend
                                            If HasConnectionHandler <> 0 Then
                                                Dim ConnectionStatus As String = "%event.connection.status." & LongToString(InstructionIndex) & "." & LongToString(ConnectionOrdinal)
                                                Dim ConnectionAccepted As String = "%event.connection.accepted." & LongToString(InstructionIndex) & "." & LongToString(ConnectionOrdinal)
                                                Dim ConnectionContinueLabel As String = "event.connection.continue." & LongToString(InstructionIndex) & "." & LongToString(ConnectionOrdinal)
                                                LineText = LineText & "  " & ConnectionStatus & " = call i32 @ube_event_connect(ptr " & EventReceiver & ", i64 " & LongToString(EventFieldSymbol) & ", ptr " & StoredValueText & ", i64 " & LongToString(ConnectedEvent) & ", ptr @ube.event.callback." & LongToString(EventFieldSymbol) & "." & LongToString(ConnectedEvent) & ")" & NewLine
                                                Dim ConnectionFailure As Long = Instructions(InstructionIndex).FailureTarget
                                                If ConnectionFailure < 0 Then
                                                    ConnectionFailure = Functions(FunctionIndex).FirstBlock + 2
                                                End If
                                                LineText = LineText & "  " & ConnectionAccepted & " = icmp ne i32 " & ConnectionStatus & ", 0" & NewLine
                                                LineText = LineText & "  br i1 " & ConnectionAccepted & ", label %" & ConnectionContinueLabel & ", label %" & LlvmBlockLabel(ConnectionFailure) & NewLine
                                                LineText = LineText & ConnectionContinueLabel & ":" & NewLine
                                                ConnectionOrdinal = ConnectionOrdinal + 1
                                            End If
                                        End If
                                        ConnectedEvent = ConnectedEvent + 1
                                    Wend
                                End If
                            End If
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
                                            ReceiverBefore = "  " & ReceiverName & " = load ptr, ptr " & ReceiverAddress & NewLine
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
                                        Dim IsComponentReceiver As Long = 0
                                        If Types(ReceiverType).TypeKind = 51 Or Types(ReceiverType).TypeKind = 52 Then
                                            IsComponentReceiver = 1
                                            Dim ComponentCallStatus As String = "%component.call.status." & LongToString(InstructionIndex)
                                            Dim ComponentCallAccepted As String = "%component.call.accepted." & LongToString(InstructionIndex)
                                            Dim ComponentCallContinueLabel As String = "component.call.continue." & LongToString(InstructionIndex)
                                            Dim ComponentCallFailure As Long = Instructions(InstructionIndex).FailureTarget
                                            If ComponentCallFailure < 0 Then
                                                ComponentCallFailure = Functions(FunctionIndex).FirstBlock + 2
                                            End If
                                            ReceiverBefore = ReceiverBefore & "  " & ComponentCallStatus & " = call i32 @ube_component_enter_call(ptr " & ReceiverName & ")" & NewLine
                                            ReceiverBefore = ReceiverBefore & "  " & ComponentCallAccepted & " = icmp ne i32 " & ComponentCallStatus & ", 0" & NewLine
                                            ReceiverBefore = ReceiverBefore & "  br i1 " & ComponentCallAccepted & ", label %" & ComponentCallContinueLabel & ", label %" & LlvmBlockLabel(ComponentCallFailure) & NewLine
                                            ReceiverBefore = ReceiverBefore & ComponentCallContinueLabel & ":" & NewLine
                                        End If
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
                                        Dim ReceiverPreviousObject As String = "%call.receiver.previous.object" & LongToString(InstructionIndex)
                                        ReceiverBefore = ReceiverBefore & "  " & ReceiverPreviousObject & " = load ptr, ptr @ube.current.object" & NewLine
                                        ReceiverBefore = ReceiverBefore & "  store ptr " & ReceiverName & ", ptr @ube.current.object" & NewLine
                                        ReceiverAfter = ReceiverAfter & "  store ptr " & ReceiverPreviousObject & ", ptr @ube.current.object" & NewLine
                                        If IsComponentReceiver <> 0 Then
                                            ReceiverAfter = ReceiverAfter & "  call void @ube_component_leave_call(ptr " & ReceiverName & ")" & NewLine
                                        End If
                                        FirstCallArgument = 2
                                    End If
                                    Dim CallPrefix As String = "  "
                                    If CalledType <> "void" Then
                                        CallPrefix = CallPrefix & ResultName & " = "
                                    End If
                                    Dim CallArguments As String = ""
                                    Dim CallArgumentPreparation As String = ""
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
                                            Dim ArgumentType As String = LlvmValueType(ArgumentValue, Values, Types, TypeCount, Abi)
                                            Dim ArgumentClass As AbiTypeClassification
                                            Dim ArgumentClassified As Long = ClassifyTargetAbiType(Parameters(CalledParameter).TypeIndex, Types, TypeCount, Abi, ArgumentClass)
                                            If ArgumentClassified <> 0 And ArgumentClass.PassKind = AbiPassIndirect() Then
                                                Dim ArgumentAddress As String = "%call.byval.address." & LongToString(InstructionIndex) & "." & LongToString(ArgumentOrdinal)
                                                CallArgumentPreparation = CallArgumentPreparation & "  " & ArgumentAddress & " = alloca " & ArgumentType & NewLine
                                                CallArgumentPreparation = CallArgumentPreparation & "  store " & ArgumentType & " " & LlvmValueName(ArgumentValue) & ", ptr " & ArgumentAddress & NewLine
                                                CallArguments = CallArguments & "ptr " & ArgumentAddress
                                            Else
                                                CallArguments = CallArguments & ArgumentType & " " & LlvmValueName(ArgumentValue)
                                            End If
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
                                        If BuildInterfaceCallLlvm(InstructionIndex, ReceiverType, ReceiverName, CalledFunction, CalledType, ResultName, CallArguments, ReceiverBefore & CallArgumentPreparation, Abi, Types, TypeCount, Symbols, SymbolCount, Functions, FunctionCount, Storages, StorageCount, LineText, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
                                            EmitIrInstructionToLlvm = 0
                                            Exit Function
                                        End If
                                    Else
                                        LineText = ReceiverBefore & CallArgumentPreparation & CallText & ReceiverAfter
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
                                                If EqualsFolded(OperatorText, "Is") <> 0 Then
                                                    LlvmOperator = "icmp eq"
                                                End If
                                                If OperatorText = "<>" Then
                                                    LlvmOperator = "icmp ne"
                                                End If
                                                If EqualsFolded(OperatorText, "IsNot") <> 0 Then
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
                                                Dim PointerTypeIndex As Long = Values(LeftValue).TypeIndex
                                                Dim PointerTypeKind As Long = -1
                                                If PointerTypeIndex >= 0 And PointerTypeIndex < TypeCount Then
                                                    PointerTypeKind = Types(PointerTypeIndex).TypeKind
                                                End If
                                                If PointerTypeKind = 11 Or PointerTypeKind = 40 Then
                                                    LineText = "  %strcmp" & LongToString(InstructionIndex) & " = call i32 @ube_string_compare(ptr " & LlvmValueName(LeftValue) & ", ptr " & LlvmValueName(RightValue) & ")" & NewLine
                                                    LineText = LineText & "  " & ResultName & " = " & LlvmOperator & " i32 %strcmp" & LongToString(InstructionIndex) & ", 0" & NewLine
                                                Else
                                                    If LlvmOperator <> "icmp eq" And LlvmOperator <> "icmp ne" Then
                                                        Call AddIrDiagnostic("UBE5108", "object identity comparison supports only Is and IsNot", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                                        EmitIrInstructionToLlvm = 0
                                                        Exit Function
                                                    End If
                                                    LineText = "  " & ResultName & " = " & LlvmOperator & " ptr " & LlvmValueName(LeftValue) & ", " & LlvmValueName(RightValue) & NewLine
                                                End If
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
                                            Dim LocalFailureLabel As String = "arithmetic.failure." & LongToString(InstructionIndex)
                                            Dim MergeLabel As String = "arithmetic.merge." & LongToString(InstructionIndex)
                                            Dim UsesNeutralFailure As Long = 0
                                            If Instructions(InstructionIndex).FailureTarget = Functions(FunctionIndex).FirstBlock + 2 Then
                                                UsesNeutralFailure = 1
                                            End If
                                            Dim ArithmeticModeStorage As Long = Functions(FunctionIndex).ErrorModeStorage
                                            If Opcode = IrOpCheckedAdd() Or Opcode = IrOpCheckedSubtract() Or Opcode = IrOpCheckedMultiply() Then
                                                Dim IntrinsicName As String = "llvm.sadd.with.overflow.i" & LlvmIntegerWidth(ResultType)
                                                If Opcode = IrOpCheckedSubtract() Then
                                                    IntrinsicName = "llvm.ssub.with.overflow.i" & LlvmIntegerWidth(ResultType)
                                                End If
                                                If Opcode = IrOpCheckedMultiply() Then
                                                    IntrinsicName = "llvm.smul.with.overflow.i" & LlvmIntegerWidth(ResultType)
                                                End If
                                                LineText = "  %pair" & LongToString(InstructionIndex) & " = call { " & ResultType & ", i1 } @" & IntrinsicName & "(" & ResultType & " " & LlvmValueName(ArithmeticLeft) & ", " & ResultType & " " & LlvmValueName(ArithmeticRight) & ")" & NewLine
                                                LineText = LineText & "  %arithmetic.raw." & LongToString(InstructionIndex) & " = extractvalue { " & ResultType & ", i1 } %pair" & LongToString(InstructionIndex) & ", 0" & NewLine
                                                LineText = LineText & "  %overflow" & LongToString(InstructionIndex) & " = extractvalue { " & ResultType & ", i1 } %pair" & LongToString(InstructionIndex) & ", 1" & NewLine
                                                LineText = LineText & "  br i1 %overflow" & LongToString(InstructionIndex) & ", label %" & LocalFailureLabel & ", label %" & ContinueLabel & NewLine
                                                LineText = LineText & LocalFailureLabel & ":" & NewLine & "  call void @ube_err_set(i32 6, ptr null, ptr null)" & NewLine
                                                If UsesNeutralFailure <> 0 Then
                                                    LineText = LineText & "  br label %" & MergeLabel & NewLine & ContinueLabel & ":" & NewLine & "  br label %" & MergeLabel & NewLine & MergeLabel & ":" & NewLine
                                                    LineText = LineText & "  " & ResultName & " = phi " & ResultType & " [ 0, %" & LocalFailureLabel & " ], [ %arithmetic.raw." & LongToString(InstructionIndex) & ", %" & ContinueLabel & " ]" & NewLine
                                                Else
                                                    Dim ArithmeticNeutralLabel As String = "arithmetic.neutral." & LongToString(InstructionIndex)
                                                    Dim ArithmeticModeName As String = "%arithmetic.mode." & LongToString(InstructionIndex)
                                                    Dim ArithmeticModeZeroName As String = "%arithmetic.mode.zero." & LongToString(InstructionIndex)
                                                    Dim ArithmeticModeAddress As String = LlvmStorageAddress(ArithmeticModeStorage, FunctionIndex, Storages, Functions, Parameters)
                                                    LineText = LineText & "  " & ArithmeticModeName & " = load i32, ptr " & ArithmeticModeAddress & NewLine
                                                    LineText = LineText & "  " & ArithmeticModeZeroName & " = icmp eq i32 " & ArithmeticModeName & ", 0" & NewLine
                                                    LineText = LineText & "  br i1 " & ArithmeticModeZeroName & ", label %" & ArithmeticNeutralLabel & ", label %" & FailureLabel & NewLine
                                                    LineText = LineText & ArithmeticNeutralLabel & ":" & NewLine & "  br label %" & MergeLabel & NewLine & ContinueLabel & ":" & NewLine & "  br label %" & MergeLabel & NewLine & MergeLabel & ":" & NewLine
                                                    LineText = LineText & "  " & ResultName & " = phi " & ResultType & " [ 0, %" & ArithmeticNeutralLabel & " ], [ %arithmetic.raw." & LongToString(InstructionIndex) & ", %" & ContinueLabel & " ]" & NewLine
                                                End If
                                            Else
                                                If Opcode = IrOpCheckedNegate() Then
                                                    LineText = "  %ismin" & LongToString(InstructionIndex) & " = icmp eq " & ResultType & " " & LlvmValueName(ArithmeticLeft) & ", " & LlvmSignedMinimum(ResultType) & NewLine
                                                    LineText = LineText & "  br i1 %ismin" & LongToString(InstructionIndex) & ", label %" & LocalFailureLabel & ", label %" & ContinueLabel & NewLine
                                                    LineText = LineText & LocalFailureLabel & ":" & NewLine & "  call void @ube_err_set(i32 6, ptr null, ptr null)" & NewLine
                                                    If UsesNeutralFailure <> 0 Then
                                                        LineText = LineText & "  br label %" & MergeLabel & NewLine & ContinueLabel & ":" & NewLine
                                                        LineText = LineText & "  %arithmetic.raw." & LongToString(InstructionIndex) & " = sub " & ResultType & " 0, " & LlvmValueName(ArithmeticLeft) & NewLine & "  br label %" & MergeLabel & NewLine & MergeLabel & ":" & NewLine
                                                        LineText = LineText & "  " & ResultName & " = phi " & ResultType & " [ 0, %" & LocalFailureLabel & " ], [ %arithmetic.raw." & LongToString(InstructionIndex) & ", %" & ContinueLabel & " ]" & NewLine
                                                    Else
                                                        ArithmeticNeutralLabel = "arithmetic.neutral." & LongToString(InstructionIndex)
                                                        ArithmeticModeName = "%arithmetic.mode." & LongToString(InstructionIndex)
                                                        ArithmeticModeZeroName = "%arithmetic.mode.zero." & LongToString(InstructionIndex)
                                                        ArithmeticModeAddress = LlvmStorageAddress(ArithmeticModeStorage, FunctionIndex, Storages, Functions, Parameters)
                                                        LineText = LineText & "  " & ArithmeticModeName & " = load i32, ptr " & ArithmeticModeAddress & NewLine
                                                        LineText = LineText & "  " & ArithmeticModeZeroName & " = icmp eq i32 " & ArithmeticModeName & ", 0" & NewLine
                                                        LineText = LineText & "  br i1 " & ArithmeticModeZeroName & ", label %" & ArithmeticNeutralLabel & ", label %" & FailureLabel & NewLine
                                                        LineText = LineText & ArithmeticNeutralLabel & ":" & NewLine & "  br label %" & MergeLabel & NewLine & ContinueLabel & ":" & NewLine
                                                        LineText = LineText & "  %arithmetic.raw." & LongToString(InstructionIndex) & " = sub " & ResultType & " 0, " & LlvmValueName(ArithmeticLeft) & NewLine & "  br label %" & MergeLabel & NewLine & MergeLabel & ":" & NewLine
                                                        LineText = LineText & "  " & ResultName & " = phi " & ResultType & " [ 0, %" & ArithmeticNeutralLabel & " ], [ %arithmetic.raw." & LongToString(InstructionIndex) & ", %" & ContinueLabel & " ]" & NewLine
                                                    End If
                                                Else
                                                    LineText = "  %iszero" & LongToString(InstructionIndex) & " = icmp eq " & ResultType & " " & LlvmValueName(ArithmeticRight) & ", 0" & NewLine
                                                    LineText = LineText & "  %isdivmin" & LongToString(InstructionIndex) & " = icmp eq " & ResultType & " " & LlvmValueName(ArithmeticLeft) & ", " & LlvmSignedMinimum(ResultType) & NewLine
                                                    LineText = LineText & "  %isnegone" & LongToString(InstructionIndex) & " = icmp eq " & ResultType & " " & LlvmValueName(ArithmeticRight) & ", -1" & NewLine
                                                    LineText = LineText & "  %isdivoverflow" & LongToString(InstructionIndex) & " = and i1 %isdivmin" & LongToString(InstructionIndex) & ", %isnegone" & LongToString(InstructionIndex) & NewLine
                                                    LineText = LineText & "  %isdivfailure" & LongToString(InstructionIndex) & " = or i1 %iszero" & LongToString(InstructionIndex) & ", %isdivoverflow" & LongToString(InstructionIndex) & NewLine
                                                    LineText = LineText & "  br i1 %isdivfailure" & LongToString(InstructionIndex) & ", label %" & LocalFailureLabel & ", label %" & ContinueLabel & NewLine
                                                    LineText = LineText & LocalFailureLabel & ":" & NewLine & "  call void @ube_err_set(i32 11, ptr null, ptr null)" & NewLine
                                                    Dim DivideOpcode As String = "sdiv"
                                                    If Opcode = IrOpCheckedRemainder() Then
                                                        DivideOpcode = "srem"
                                                    End If
                                                    If UsesNeutralFailure <> 0 Then
                                                        LineText = LineText & "  br label %" & MergeLabel & NewLine & ContinueLabel & ":" & NewLine
                                                        LineText = LineText & "  %arithmetic.raw." & LongToString(InstructionIndex) & " = " & DivideOpcode & " " & ResultType & " " & LlvmValueName(ArithmeticLeft) & ", " & LlvmValueName(ArithmeticRight) & NewLine & "  br label %" & MergeLabel & NewLine & MergeLabel & ":" & NewLine
                                                        LineText = LineText & "  " & ResultName & " = phi " & ResultType & " [ 0, %" & LocalFailureLabel & " ], [ %arithmetic.raw." & LongToString(InstructionIndex) & ", %" & ContinueLabel & " ]" & NewLine
                                                    Else
                                                        ArithmeticNeutralLabel = "arithmetic.neutral." & LongToString(InstructionIndex)
                                                        ArithmeticModeName = "%arithmetic.mode." & LongToString(InstructionIndex)
                                                        ArithmeticModeZeroName = "%arithmetic.mode.zero." & LongToString(InstructionIndex)
                                                        ArithmeticModeAddress = LlvmStorageAddress(ArithmeticModeStorage, FunctionIndex, Storages, Functions, Parameters)
                                                        LineText = LineText & "  " & ArithmeticModeName & " = load i32, ptr " & ArithmeticModeAddress & NewLine
                                                        LineText = LineText & "  " & ArithmeticModeZeroName & " = icmp eq i32 " & ArithmeticModeName & ", 0" & NewLine
                                                        LineText = LineText & "  br i1 " & ArithmeticModeZeroName & ", label %" & ArithmeticNeutralLabel & ", label %" & FailureLabel & NewLine
                                                        LineText = LineText & ArithmeticNeutralLabel & ":" & NewLine & "  br label %" & MergeLabel & NewLine & ContinueLabel & ":" & NewLine
                                                        LineText = LineText & "  %arithmetic.raw." & LongToString(InstructionIndex) & " = " & DivideOpcode & " " & ResultType & " " & LlvmValueName(ArithmeticLeft) & ", " & LlvmValueName(ArithmeticRight) & NewLine & "  br label %" & MergeLabel & NewLine & MergeLabel & ":" & NewLine
                                                        LineText = LineText & "  " & ResultName & " = phi " & ResultType & " [ 0, %" & ArithmeticNeutralLabel & " ], [ %arithmetic.raw." & LongToString(InstructionIndex) & ", %" & ContinueLabel & " ]" & NewLine
                                                    End If
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

Function EmitLlvmEventHelpers(ByRef Abi As TargetAbiDescription, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Functions() As IrFunction, ByVal FunctionCount As Long, ByRef Parameters() As IrParameter, ByRef Storages() As IrStorage, ByVal StorageCount As Long, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long) As Long
    Dim NewLine As String = StringFromByte(10)
    Dim EventSymbol As Long = 0
    While EventSymbol < SymbolCount
        If Symbols(EventSymbol).SymbolKind = SemanticSymbolEvent() Then
            Dim EventFields As String = ""
            Dim EventParameter As Long = 0
            Dim EventFieldCount As Long = 0
            While EventParameter < SymbolCount
                If Symbols(EventParameter).ParentSymbol = EventSymbol And Symbols(EventParameter).SymbolKind = SemanticSymbolParameter() Then
                    If EventFieldCount > 0 Then
                        EventFields = EventFields & ", "
                    End If
                    If (Symbols(EventParameter).Flags And 2) <> 0 Then
                        EventFields = EventFields & LlvmTypeForSemanticType(Symbols(EventParameter).DeclaredType, Types, TypeCount, Abi)
                    Else
                        EventFields = EventFields & "ptr"
                    End If
                    EventFieldCount = EventFieldCount + 1
                End If
                EventParameter = EventParameter + 1
            Wend
            If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "%ube.event.args." & LongToString(EventSymbol) & " = type { " & EventFields & " }" & NewLine) = 0 Then
                EmitLlvmEventHelpers = 0
                Exit Function
            End If
        End If
        EventSymbol = EventSymbol + 1
    Wend
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, NewLine)

    Dim SubscriberSymbol As Long = 0
    While SubscriberSymbol < SymbolCount
        If Symbols(SubscriberSymbol).SymbolKind = SemanticSymbolVariable() And (Symbols(SubscriberSymbol).Flags And 128) <> 0 Then
            Dim SubscriberType As Long = Symbols(SubscriberSymbol).DeclaredType
            If SubscriberType >= 0 And SubscriberType < TypeCount Then
                Dim SourceModule As Long = Types(SubscriberType).TypeSymbol
                EventSymbol = 0
                While EventSymbol < SymbolCount
                    If Symbols(EventSymbol).SymbolKind = SemanticSymbolEvent() And Symbols(EventSymbol).ParentSymbol = SourceModule Then
                        Dim HandlerName As String = Symbols(SubscriberSymbol).SymbolName & "_" & Symbols(EventSymbol).SymbolName
                        Dim HandlerSymbol As Long = 0
                        While HandlerSymbol < SymbolCount
                            If Symbols(HandlerSymbol).SymbolKind = SemanticSymbolProcedure() And Symbols(HandlerSymbol).ParentSymbol = Symbols(SubscriberSymbol).ParentSymbol And EqualsFolded(Symbols(HandlerSymbol).SymbolName, HandlerName) <> 0 Then
                                Dim HandlerFunction As Long = SemanticFunctionIndex(HandlerSymbol, Functions, FunctionCount)
                                If HandlerFunction >= 0 Then
                                    Dim CallbackText As String = "define internal void @ube.event.callback." & LongToString(SubscriberSymbol) & "." & LongToString(EventSymbol) & "(ptr %receiver, ptr %arguments) {" & NewLine & "entry:" & NewLine
                                    Dim SubscriberOwner As Long = Symbols(SubscriberSymbol).ParentSymbol
                                    Dim HasReceiver As Long = 0
                                    If SubscriberOwner >= 0 Then
                                        If Symbols(SubscriberOwner).SymbolKind = SemanticSymbolModule() And Symbols(SubscriberOwner).Flags >= 2 Then
                                            HasReceiver = 1
                                        End If
                                    End If
                                    Dim IsComponentCallback As Long = 0
                                    If HasReceiver <> 0 Then
                                        If Symbols(SubscriberOwner).Flags = 3 Or Symbols(SubscriberOwner).Flags = 4 Then
                                            IsComponentCallback = 1
                                            CallbackText = CallbackText & "  %component.status = call i32 @ube_component_enter_call(ptr %receiver)" & NewLine
                                            CallbackText = CallbackText & "  %component.accepted = icmp ne i32 %component.status, 0" & NewLine
                                            CallbackText = CallbackText & "  br i1 %component.accepted, label %component.callback.admitted, label %component.callback.rejected" & NewLine
                                            CallbackText = CallbackText & "component.callback.rejected:" & NewLine & "  ret void" & NewLine
                                            CallbackText = CallbackText & "component.callback.admitted:" & NewLine
                                        End If
                                    End If
                                    Dim ReceiverAfter As String = ""
                                    If HasReceiver <> 0 Then
                                        CallbackText = CallbackText & "  %previous.object = load ptr, ptr @ube.current.object" & NewLine
                                        CallbackText = CallbackText & "  store ptr %receiver, ptr @ube.current.object" & NewLine
                                        Dim FieldOrdinal As Long = 0
                                        Dim FieldSymbol As Long = 0
                                        While FieldSymbol < SymbolCount
                                            If Symbols(FieldSymbol).ParentSymbol = SubscriberOwner And Symbols(FieldSymbol).SymbolKind = SemanticSymbolVariable() Then
                                                Dim FieldStorage As Long = LlvmGlobalStorageForSymbol(FieldSymbol, Storages, StorageCount)
                                                If FieldStorage >= 0 Then
                                                    Dim FieldType As String = LlvmTypeForSemanticType(Symbols(FieldSymbol).DeclaredType, Types, TypeCount, Abi)
                                                    Dim FieldAddress As String = "%receiver.field.address." & LongToString(FieldOrdinal)
                                                    Dim FieldValue As String = "%receiver.field.value." & LongToString(FieldOrdinal)
                                                    CallbackText = CallbackText & "  " & FieldAddress & " = getelementptr inbounds %ube.class." & LongToString(SubscriberOwner) & ", ptr %receiver, i32 0, i32 " & LongToString(FieldOrdinal + 1) & NewLine
                                                    CallbackText = CallbackText & "  " & FieldValue & " = load " & FieldType & ", ptr " & FieldAddress & NewLine
                                                    CallbackText = CallbackText & "  store " & FieldType & " " & FieldValue & ", ptr " & LlvmGlobalName(FieldStorage) & NewLine
                                                    Dim ReturnValue As String = "%receiver.return.value." & LongToString(FieldOrdinal)
                                                    ReceiverAfter = ReceiverAfter & "  " & ReturnValue & " = load " & FieldType & ", ptr " & LlvmGlobalName(FieldStorage) & NewLine
                                                    ReceiverAfter = ReceiverAfter & "  store " & FieldType & " " & ReturnValue & ", ptr " & FieldAddress & NewLine
                                                End If
                                                FieldOrdinal = FieldOrdinal + 1
                                            End If
                                            FieldSymbol = FieldSymbol + 1
                                        Wend
                                    End If
                                    Dim CallbackArguments As String = ""
                                    Dim ParameterOffset As Long = 0
                                    While ParameterOffset < Functions(HandlerFunction).ParameterCount
                                        If ParameterOffset > 0 Then
                                            CallbackArguments = CallbackArguments & ", "
                                        End If
                                        Dim HandlerParameter As Long = Functions(HandlerFunction).FirstParameter + ParameterOffset
                                        Dim ArgumentAddress As String = "%argument.address." & LongToString(ParameterOffset)
                                        CallbackText = CallbackText & "  " & ArgumentAddress & " = getelementptr inbounds %ube.event.args." & LongToString(EventSymbol) & ", ptr %arguments, i32 0, i32 " & LongToString(ParameterOffset) & NewLine
                                        If Parameters(HandlerParameter).PassingMode = IrPassingByRef() Then
                                            Dim ArgumentPointer As String = "%argument.pointer." & LongToString(ParameterOffset)
                                            CallbackText = CallbackText & "  " & ArgumentPointer & " = load ptr, ptr " & ArgumentAddress & NewLine
                                            CallbackArguments = CallbackArguments & "ptr " & ArgumentPointer
                                        Else
                                            Dim ArgumentType As String = LlvmTypeForSemanticType(Parameters(HandlerParameter).TypeIndex, Types, TypeCount, Abi)
                                            Dim ArgumentValue As String = "%argument.value." & LongToString(ParameterOffset)
                                            CallbackText = CallbackText & "  " & ArgumentValue & " = load " & ArgumentType & ", ptr " & ArgumentAddress & NewLine
                                            CallbackArguments = CallbackArguments & ArgumentType & " " & ArgumentValue
                                        End If
                                        ParameterOffset = ParameterOffset + 1
                                    Wend
                                    CallbackText = CallbackText & "  call void @" & LlvmFunctionName(HandlerFunction, Functions, Symbols) & "(" & CallbackArguments & ")" & NewLine
                                    CallbackText = CallbackText & ReceiverAfter
                                    If HasReceiver <> 0 Then
                                        CallbackText = CallbackText & "  store ptr %previous.object, ptr @ube.current.object" & NewLine
                                    End If
                                    If IsComponentCallback <> 0 Then
                                        CallbackText = CallbackText & "  call void @ube_component_leave_call(ptr %receiver)" & NewLine
                                    End If
                                    CallbackText = CallbackText & "  ret void" & NewLine & "}" & NewLine & NewLine
                                    If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, CallbackText) = 0 Then
                                        EmitLlvmEventHelpers = 0
                                        Exit Function
                                    End If
                                End If
                            End If
                            HandlerSymbol = HandlerSymbol + 1
                        Wend
                    End If
                    EventSymbol = EventSymbol + 1
                Wend
            End If
        End If
        SubscriberSymbol = SubscriberSymbol + 1
    Wend
    EmitLlvmEventHelpers = 1
End Function

Function EmitLlvmCallNewHelpers(ByRef Abi As TargetAbiDescription, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Functions() As IrFunction, ByVal FunctionCount As Long, ByRef Parameters() As IrParameter, ByRef Instructions() As IrInstruction, ByVal InstructionCount As Long, ByRef Operands() As IrOperand, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long) As Long
    Dim NewLine As String = StringFromByte(10)
    Dim InstructionIndex As Long = 0
    While InstructionIndex < InstructionCount
        If Instructions(InstructionIndex).Opcode = IrOpCallNew() Then
            Dim FunctionOperand As Long = LlvmOperandAt(InstructionIndex, 0, Instructions, Operands)
            If FunctionOperand < 0 Then
                EmitLlvmCallNewHelpers = 0
                Exit Function
            End If
            Dim CalledFunction As Long = Operands(FunctionOperand).ReferencedIndex
            If CalledFunction < 0 Or CalledFunction >= FunctionCount Then
                EmitLlvmCallNewHelpers = 0
                Exit Function
            End If
            Dim CaptureType As String = "%ube.callnew.capture." & LongToString(InstructionIndex)
            Dim CaptureFields As String = ""
            Dim SlotText As String = ""
            Dim SlotCount As Long = 0
            Dim ParameterOffset As Long = 0
            While ParameterOffset < Functions(CalledFunction).ParameterCount
                If ParameterOffset > 0 Then
                    CaptureFields = CaptureFields & ", "
                End If
                Dim ParameterIndex As Long = Functions(CalledFunction).FirstParameter + ParameterOffset
                CaptureFields = CaptureFields & LlvmTypeForSemanticType(Parameters(ParameterIndex).TypeIndex, Types, TypeCount, Abi)
                Call AppendLlvmCaptureSlotPaths(Parameters(ParameterIndex).TypeIndex, CaptureType, "i32 0, i32 " & LongToString(ParameterOffset), 0, Types, TypeCount, Symbols, SymbolCount, SlotCount, SlotText)
                ParameterOffset = ParameterOffset + 1
            Wend
            If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, CaptureType & " = type { " & CaptureFields & " }" & NewLine) = 0 Then
                EmitLlvmCallNewHelpers = 0
                Exit Function
            End If
            If SlotCount > 0 Then
                If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@ube.callnew.slots." & LongToString(InstructionIndex) & " = private constant [" & LongToString(SlotCount) & " x i64] [" & SlotText & "]" & NewLine) = 0 Then
                    EmitLlvmCallNewHelpers = 0
                    Exit Function
                End If
            End If
            Dim ThunkText As String = "define internal void @ube.callnew.thunk." & LongToString(InstructionIndex) & "(ptr %capture) {" & NewLine & "entry:" & NewLine
            Dim CallArguments As String = ""
            ParameterOffset = 0
            While ParameterOffset < Functions(CalledFunction).ParameterCount
                Dim ThunkParameterIndex As Long = Functions(CalledFunction).FirstParameter + ParameterOffset
                Dim ParameterType As String = LlvmTypeForSemanticType(Parameters(ThunkParameterIndex).TypeIndex, Types, TypeCount, Abi)
                Dim FieldAddress As String = "%field.address." & LongToString(ParameterOffset)
                ThunkText = ThunkText & "  " & FieldAddress & " = getelementptr inbounds " & CaptureType & ", ptr %capture, i32 0, i32 " & LongToString(ParameterOffset) & NewLine
                If ParameterOffset > 0 Then
                    CallArguments = CallArguments & ", "
                End If
                Dim ParameterClass As AbiTypeClassification
                If ClassifyTargetAbiType(Parameters(ThunkParameterIndex).TypeIndex, Types, TypeCount, Abi, ParameterClass) = 0 Then
                    EmitLlvmCallNewHelpers = 0
                    Exit Function
                End If
                If ParameterClass.PassKind = AbiPassIndirect() Then
                    CallArguments = CallArguments & "ptr " & FieldAddress
                Else
                    Dim FieldValue As String = "%field.value." & LongToString(ParameterOffset)
                    ThunkText = ThunkText & "  " & FieldValue & " = load " & ParameterType & ", ptr " & FieldAddress & NewLine
                    CallArguments = CallArguments & ParameterType & " " & FieldValue
                End If
                ParameterOffset = ParameterOffset + 1
            Wend
            Dim TargetName As String = LlvmBootstrapIntrinsicName(Functions(CalledFunction).FunctionName)
            If StringLength(TargetName) = 0 Then
                TargetName = LlvmFunctionName(CalledFunction, Functions, Symbols)
            End If
            ThunkText = ThunkText & "  call void @" & TargetName & "(" & CallArguments & ")" & NewLine & "  ret void" & NewLine & "}" & NewLine & NewLine
            If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, ThunkText) = 0 Then
                EmitLlvmCallNewHelpers = 0
                Exit Function
            End If
        End If
        InstructionIndex = InstructionIndex + 1
    Wend
    EmitLlvmCallNewHelpers = 1
End Function

Function EmitLlvmProgramEntry(ByRef Abi As TargetAbiDescription, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Program As IrProgram, ByRef Globals() As IrGlobal, ByVal GlobalCount As Long, ByRef Functions() As IrFunction, ByVal FunctionCount As Long, ByRef Storages() As IrStorage, ByVal StorageCount As Long, ByRef Managed As ManagedMetadata, ByRef ManagedRoots() As ManagedRoot, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim NewLine As String = StringFromByte(10)
    Dim GlobalIndex As Long = 0
    Dim GlobalStorage As Long = -1
    Dim ManagedIndex As Long = 0
    Dim RootTypeIndex As Long = -1
    Dim RootSlotCount As Long = 0
    If Program.EntryFunction >= 0 Then
        If Functions(Program.EntryFunction).ParameterCount <> 0 Then
            Call AddIrDiagnostic("UBE5106", "program entry function must not have parameters", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitLlvmProgramEntry = 0
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
        If Program.StartupFormSymbol >= 0 Then
            Dim StartupFormStorage As Long = LlvmGlobalStorageForSymbol(Program.StartupFormSymbol, Storages, StorageCount)
            If StartupFormStorage < 0 Then
                Call AddIrDiagnostic("UBE5108", "startup form has no default-instance storage", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                EmitLlvmProgramEntry = 0
                Exit Function
            End If
            Dim StartupFormModule As String = LongToString(Program.StartupFormSymbol)
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  %startup.form = call ptr @ube_default_form_ensure(ptr " & LlvmGlobalName(StartupFormStorage) & ", ptr @ube.object.layout." & StartupFormModule & ", ptr @ube.object.initialize." & StartupFormModule & ", i32 1)" & NewLine)
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  %startup.form.status = call i32 @ube_component_begin_load(ptr %startup.form, i32 51)" & NewLine)
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  switch i32 %startup.form.status, label %startup.form.ready [ i32 0, label %startup.form.failed i32 1, label %startup.form.load ]" & NewLine)
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "startup.form.load:" & NewLine)
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  call void @ube.object.load." & StartupFormModule & "(ptr %startup.form)" & NewLine)
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  call i32 @ube_component_finish_load(ptr %startup.form, i32 1)" & NewLine)
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  br label %startup.form.ready" & NewLine)
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "startup.form.failed:" & NewLine & "  ret i32 1" & NewLine)
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "startup.form.ready:" & NewLine)
        End If
        If EntryType = "void" Then
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  call void @" & EntryName & "()" & NewLine)
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  call void @ube_thread_program_wait()" & NewLine)
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
                EmitLlvmProgramEntry = 0
                Exit Function
            End If
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  %result = call " & EntryType & " @" & EntryName & "()" & NewLine)
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  call void @ube_thread_program_wait()" & NewLine)
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
    EmitLlvmProgramEntry = 1
End Function

Function EmitLlvmExportWrappers(ByRef Abi As TargetAbiDescription, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByRef Functions() As IrFunction, ByVal FunctionCount As Long, ByRef Parameters() As IrParameter, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long) As Long
    Dim NewLine As String = StringFromByte(10)
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
    EmitLlvmExportWrappers = 1
End Function

Function EmitLlvmObjectLifecycleHelpers(ByRef Abi As TargetAbiDescription, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Functions() As IrFunction, ByVal FunctionCount As Long, ByRef Storages() As IrStorage, ByVal StorageCount As Long, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long) As Long
    Dim NewLine As String = StringFromByte(10)
    Dim ClassTypeIndex As Long = 0
    While ClassTypeIndex < TypeCount
        If Types(ClassTypeIndex).TypeKind >= 50 Then
        If Types(ClassTypeIndex).TypeKind <= 52 Then
            Dim ClassModule As Long = Types(ClassTypeIndex).TypeSymbol
            Dim InitializeFunction As Long = LlvmClassLifecycleFunction(ClassModule, "Class_Initialize", Functions, FunctionCount, Symbols)
            Dim TerminateFunction As Long = LlvmClassLifecycleFunction(ClassModule, "Class_Terminate", Functions, FunctionCount, Symbols)
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
            If Types(ClassTypeIndex).TypeKind = 51 Or Types(ClassTypeIndex).TypeKind = 52 Then
                Dim ComponentLoadHookName As String = "Form_Load"
                If Types(ClassTypeIndex).TypeKind = 52 Then
                    ComponentLoadHookName = "Control_Load"
                End If
                Dim ComponentLoadFunction As Long = LlvmClassLifecycleFunction(ClassModule, ComponentLoadHookName, Functions, FunctionCount, Symbols)
                Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "define internal void @ube.object.load." & LongToString(ClassModule) & "(ptr %object) {" & NewLine)
                Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "entry:" & NewLine)
                Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  %load.previous.object." & LongToString(ClassModule) & " = load ptr, ptr @ube.current.object" & NewLine)
                Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  store ptr %object, ptr @ube.current.object" & NewLine)
                Dim LoadHookFieldOrdinal As Long = 0
                Dim LoadHookMember As Long = 0
                While LoadHookMember < SymbolCount
                    If Symbols(LoadHookMember).ParentSymbol = ClassModule And Symbols(LoadHookMember).SymbolKind = SemanticSymbolVariable() Then
                        Dim LoadHookStorage As Long = LlvmGlobalStorageForSymbol(LoadHookMember, Storages, StorageCount)
                        If LoadHookStorage >= 0 Then
                            Dim LoadHookFieldType As String = LlvmTypeForSemanticType(Symbols(LoadHookMember).DeclaredType, Types, TypeCount, Abi)
                            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  %load.address." & LongToString(ClassModule) & "." & LongToString(LoadHookFieldOrdinal) & " = getelementptr inbounds %ube.class." & LongToString(ClassModule) & ", ptr %object, i32 0, i32 " & LongToString(LoadHookFieldOrdinal + 1) & NewLine)
                            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  %load.value." & LongToString(ClassModule) & "." & LongToString(LoadHookFieldOrdinal) & " = load " & LoadHookFieldType & ", ptr %load.address." & LongToString(ClassModule) & "." & LongToString(LoadHookFieldOrdinal) & NewLine)
                            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  store " & LoadHookFieldType & " %load.value." & LongToString(ClassModule) & "." & LongToString(LoadHookFieldOrdinal) & ", ptr " & LlvmGlobalName(LoadHookStorage) & NewLine)
                        End If
                        LoadHookFieldOrdinal = LoadHookFieldOrdinal + 1
                    End If
                    LoadHookMember = LoadHookMember + 1
                Wend
                If ComponentLoadFunction >= 0 Then
                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  call void @" & LlvmFunctionName(ComponentLoadFunction, Functions, Symbols) & "()" & NewLine)
                End If
                LoadHookFieldOrdinal = 0
                LoadHookMember = 0
                While LoadHookMember < SymbolCount
                    If Symbols(LoadHookMember).ParentSymbol = ClassModule And Symbols(LoadHookMember).SymbolKind = SemanticSymbolVariable() Then
                        LoadHookStorage = LlvmGlobalStorageForSymbol(LoadHookMember, Storages, StorageCount)
                        If LoadHookStorage >= 0 Then
                            LoadHookFieldType = LlvmTypeForSemanticType(Symbols(LoadHookMember).DeclaredType, Types, TypeCount, Abi)
                            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  %load.return." & LongToString(ClassModule) & "." & LongToString(LoadHookFieldOrdinal) & " = load " & LoadHookFieldType & ", ptr " & LlvmGlobalName(LoadHookStorage) & NewLine)
                            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  store " & LoadHookFieldType & " %load.return." & LongToString(ClassModule) & "." & LongToString(LoadHookFieldOrdinal) & ", ptr %load.address." & LongToString(ClassModule) & "." & LongToString(LoadHookFieldOrdinal) & NewLine)
                        End If
                        LoadHookFieldOrdinal = LoadHookFieldOrdinal + 1
                    End If
                    LoadHookMember = LoadHookMember + 1
                Wend
                Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  store ptr %load.previous.object." & LongToString(ClassModule) & ", ptr @ube.current.object" & NewLine)
                Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "  ret void" & NewLine & "}" & NewLine & NewLine)
            End If
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
    EmitLlvmObjectLifecycleHelpers = 1
End Function

Function EmitLlvmFunctions(ByRef Abi As TargetAbiDescription, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Functions() As IrFunction, ByVal FunctionCount As Long, ByRef Parameters() As IrParameter, ByRef Storages() As IrStorage, ByVal StorageCount As Long, ByRef Blocks() As IrBlock, ByRef Instructions() As IrInstruction, ByVal InstructionCount As Long, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByVal ValueCount As Long, ByRef Cleanups() As IrCleanup, ByVal CleanupCount As Long, ByRef Locations() As IrLocation, ByVal LocationCount As Long, ByRef Managed As ManagedMetadata, ByRef ManagedRoots() As ManagedRoot, ByRef ManagedSafePoints() As ManagedSafePoint, ByRef RootForValue() As Long, ByRef LastUseHeads() As Long, ByRef LastUseNext() As Long, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim NewLine As String = StringFromByte(10)
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
            EmitLlvmFunctions = 0
            Exit Function
        End If
        Dim ReturnType As String = LlvmTypeForSemanticType(Functions(FunctionIndex).ResultType, Types, TypeCount, Abi)
        If StringLength(ReturnType) = 0 Then
            Call AddIrDiagnostic("UBE5100", "target ABI cannot classify a function result type", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitLlvmFunctions = 0
            Exit Function
        End If
        Dim SymbolName As String = LlvmFunctionName(FunctionIndex, Functions, Symbols)
        If StringLength(SymbolName) = 0 Then
            Call AddIrDiagnostic("UBE5105", "IR function has no valid semantic symbol", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            EmitLlvmFunctions = 0
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
                    EmitLlvmFunctions = 0
                    Exit Function
                End If
                If Instructions(InstructionIndex).BlockIndex <> PreviousBlock Then
                    If AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, LlvmBlockLabel(Instructions(InstructionIndex).BlockIndex) & ":" & NewLine) = 0 Then
                        Call AddIrDiagnostic("UBE5103", "LLVM output limit exceeded", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        EmitLlvmFunctions = 0
                        Exit Function
                    End If
                    PreviousBlock = Instructions(InstructionIndex).BlockIndex
                    If Blocks(PreviousBlock).BlockOrdinal = 2 Then
                        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation("  call void @ube_err_set(i32 6, ptr null, ptr null)" & NewLine, FunctionLocationNode))
                    End If
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
                                        EmitLlvmFunctions = 0
                                        Exit Function
                                    End If
                                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation("  " & LlvmStorageName(StorageIndex) & " = alloca " & StorageType & NewLine, FunctionLocationNode))
                                    Dim VariableDebugNode As Long = LlvmDebugVariableNode(StorageIndex, LocationCount, FunctionCount, InstructionCount)
                                    Dim VariableExpressionNode As Long = LlvmDebugExpressionNode(StorageCount, LocationCount, FunctionCount, InstructionCount)
                                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation("  call void @llvm.dbg.declare(metadata ptr " & LlvmStorageName(StorageIndex) & ", metadata !" & LongToString(VariableDebugNode) & ", metadata !" & LongToString(VariableExpressionNode) & ")" & NewLine, FunctionLocationNode))
                                    If (Storages(StorageIndex).Flags And 4096) <> 0 Then
                                        Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation("  store ptr null, ptr " & LlvmStorageName(StorageIndex) & NewLine, FunctionLocationNode))
                                    End If
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
                                Dim ParameterStorageClass As AbiTypeClassification
                                Dim ParameterStorageClassified As Long = ClassifyTargetAbiType(Parameters(ParameterForStorage).TypeIndex, Types, TypeCount, Abi, ParameterStorageClass)
                                If ParameterStorageClassified <> 0 And ParameterStorageClass.PassKind = AbiPassIndirect() Then
                                    Dim ParameterRecursiveCount As Long = 0
                                    Dim ParameterRecursiveSymbol As Long = 0
                                    While ParameterRecursiveSymbol < SymbolCount
                                        If Symbols(ParameterRecursiveSymbol).ParentSymbol = Types(Parameters(ParameterForStorage).TypeIndex).TypeSymbol And Symbols(ParameterRecursiveSymbol).SymbolKind = SemanticSymbolMember() And Symbols(ParameterRecursiveSymbol).DeclaredType = Parameters(ParameterForStorage).TypeIndex Then
                                            ParameterRecursiveCount = ParameterRecursiveCount + 1
                                        End If
                                        ParameterRecursiveSymbol = ParameterRecursiveSymbol + 1
                                    Wend
                                    Dim ParameterRecursivePointer As String = "null"
                                    If ParameterRecursiveCount > 0 Then
                                        ParameterRecursivePointer = "@ube.value.recursive.slots." & LongToString(Types(Parameters(ParameterForStorage).TypeIndex).TypeSymbol)
                                    End If
                                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation("  call i32 @ube_value_copy_recursive(ptr " & LlvmStorageName(StorageIndex) & ", ptr %p" & LongToString(ParameterOffsetForStorage) & ", ptr @ube.value.layout." & LongToString(Types(Parameters(ParameterForStorage).TypeIndex).TypeSymbol) & ", i64 " & LongToString(ParameterRecursiveCount) & ", ptr " & ParameterRecursivePointer & ")" & NewLine, FunctionLocationNode))
                                Else
                                    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation("  store " & StorageType & " %p" & LongToString(ParameterOffsetForStorage) & ", ptr " & LlvmStorageName(StorageIndex) & NewLine, FunctionLocationNode))
                                End If
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
                    Dim MonitorCleanupOffset As Long = 0
                    While MonitorCleanupOffset < Functions(FunctionIndex).StorageCount
                        Dim MonitorCleanupStorage As Long = Functions(FunctionIndex).FirstStorage + MonitorCleanupOffset
                        If (Storages(MonitorCleanupStorage).Flags And 4096) <> 0 Then
                            Dim MonitorCleanupAddress As String = LlvmStorageAddress(MonitorCleanupStorage, FunctionIndex, Storages, Functions, Parameters)
                            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation("  call void @ube_monitor_exit_storage(ptr " & MonitorCleanupAddress & ")" & NewLine, InstructionDebugNode))
                        End If
                        MonitorCleanupOffset = MonitorCleanupOffset + 1
                    Wend
                    RootOffset = Managed.RootCount - 1
                    While RootOffset >= 0
                        If ManagedRoots(RootOffset).FunctionIndex = FunctionIndex And ManagedRoots(RootOffset).RootKind <> ManagedRootGlobal() Then
                            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, AttachLlvmDebugLocation("  call i32 @ube_gc_root_leave(ptr %gc.root.record." & LongToString(RootOffset) & ")" & NewLine, InstructionDebugNode))
                        End If
                        RootOffset = RootOffset - 1
                    Wend
                End If
                If EmitIrInstructionToLlvm(InstructionIndex, InstructionDebugNode, Abi, Types, TypeCount, Symbols, SymbolCount, Functions, FunctionCount, Parameters, Storages, StorageCount, Instructions, InstructionCount, Operands, Values, Cleanups, CleanupCount, ReturnType, Chunks, ChunkCount, ChunkCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
                    EmitLlvmFunctions = 0
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
    EmitLlvmFunctions = 1
End Function

Function EmitLlvmManagedAndAbiTables(ByRef Abi As TargetAbiDescription, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Program As IrProgram, ByRef Functions() As IrFunction, ByVal FunctionCount As Long, ByRef Parameters() As IrParameter, ByRef Managed As ManagedMetadata, ByRef ManagedLayouts() As ManagedLayout, ByRef ManagedSlots() As ManagedSlot, ByRef ManagedRoots() As ManagedRoot, ByRef ManagedSafePoints() As ManagedSafePoint, ByRef ManagedBarriers() As ManagedBarrier, ByRef ExportCount As Long, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long) As Long
    Dim NewLine As String = StringFromByte(10)
    Dim Quote As String = StringFromByte(34)
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

    ExportCount = 0
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
    EmitLlvmManagedAndAbiTables = 1
End Function

Function EmitLlvmValueLayouts(ByRef Abi As TargetAbiDescription, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long) As Long
    Dim NewLine As String = StringFromByte(10)
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
    EmitLlvmValueLayouts = 1
End Function

Function EmitLlvmRuntimeDeclarations(ByRef Abi As TargetAbiDescription, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long) As Long
    Dim NewLine As String = StringFromByte(10)
    Dim Quote As String = StringFromByte(34)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "; generated by UBE Compiler v3 RP8" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "target datalayout = " & Quote & Abi.DataLayout & Quote & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "target triple = " & Quote & Abi.Triple & Quote & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "@ube.current.object = internal thread_local global ptr null" & NewLine & NewLine)
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
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_compiler_validate_resource(ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_compiler_resource_llvm_escape(ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_compiler_validate_library_bundle(ptr, ptr, ptr, ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_unicode_is_letter(i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_unicode_simple_fold_code_point(i32)" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @llvm.dbg.declare(metadata, metadata, metadata)" & NewLine & NewLine)
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
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_default_form_ensure(ptr, ptr, ptr, i32)" & NewLine & NewLine)
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
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_err_set(i32, ptr, ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_err_number()" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_err_description()" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_err_source()" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_err_clear()" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_event_enter()" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_event_leave()" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_event_disconnect(ptr, i64)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_event_connect(ptr, i64, ptr, i64, ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_event_dispatch(ptr, i64, ptr)" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_component_begin_load(ptr, i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_component_finish_load(ptr, i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_component_accept_unload(ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_component_enter_call(ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_component_leave_call(ptr)" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_monitor_enter(ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_monitor_exit(ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_monitor_error_release(ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_monitor_error_resume(ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_monitor_exit_storage(ptr)" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i64 @ube_thread_current_id()" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i1 @ube_thread_is_alive(i64)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_thread_wait(i64, i64)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_thread_request_stop(i64)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i1 @ube_thread_stop_requested()" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_thread_yield()" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_thread_capture_allocate(i64, i64, ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_thread_capture_destroy(ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i64 @ube_thread_start(ptr, ptr, ptr)" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_thread_program_wait()" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i64 @ube_atomic_i32_create(i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_atomic_i32_destroy(i64)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_atomic_i32_load(i64)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_atomic_i32_store(i64, i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_atomic_i32_exchange(i64, i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_atomic_i32_compare_exchange(i64, i32, i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_atomic_i32_add(i64, i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i64 @ube_atomic_i64_create(i64)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_atomic_i64_destroy(i64)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i64 @ube_atomic_i64_load(i64)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_atomic_i64_store(i64, i64)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i64 @ube_atomic_i64_exchange(i64, i64)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i64 @ube_atomic_i64_compare_exchange(i64, i64, i64)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i64 @ube_atomic_i64_add(i64, i64)" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i64 @ube_thread_event_create(i32, i32)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_thread_event_destroy(i64)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_thread_event_set(i64)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_thread_event_reset(i64)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_thread_event_wait(i64, i64)" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i64 @ube_semaphore_create(i64, i64)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_semaphore_destroy(i64)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_semaphore_wait(i64, i64)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_semaphore_release(i64, i64)" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i64 @ube_message_queue_create()" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_message_queue_destroy(i64)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_message_queue_enqueue(i64, ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_message_queue_dequeue(i64, ptr, i64)" & NewLine & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i64 @ube_atomic_object_create()" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_atomic_object_destroy(i64)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_atomic_object_load(i64, ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_atomic_object_store(i64, ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_atomic_object_exchange(i64, ptr, ptr)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_atomic_object_compare_exchange(i64, ptr, ptr, ptr)" & NewLine & NewLine)
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
    EmitLlvmRuntimeDeclarations = 1
End Function

Function PrepareLlvmManagedValueRoots(ByRef Values() As IrValue, ByVal ValueCount As Long, ByRef Instructions() As IrInstruction, ByVal InstructionCount As Long, ByRef Operands() As IrOperand, ByRef Managed As ManagedMetadata, ByRef ManagedRoots() As ManagedRoot, ByRef RootForValue() As Long, ByRef LastUseHeads() As Long, ByRef LastUseNext() As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim ValueLastUses() As Long
    If BuildLlvmValueLastUses(Values, ValueCount, Instructions, InstructionCount, Operands, ValueLastUses) = 0 Then
        Call AddIrDiagnostic("UBE5103", "LLVM value-liveness analysis failed", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        PrepareLlvmManagedValueRoots = 0
        Exit Function
    End If
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
    PrepareLlvmManagedValueRoots = 1
End Function

Function EmitVerifiedIrToLlvm(ByRef Target As TargetDescription, ByRef Abi As TargetAbiDescription, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Program As IrProgram, ByRef Globals() As IrGlobal, ByVal GlobalCount As Long, ByRef Functions() As IrFunction, ByVal FunctionCount As Long, ByRef Parameters() As IrParameter, ByVal ParameterCount As Long, ByRef Storages() As IrStorage, ByVal StorageCount As Long, ByRef Blocks() As IrBlock, ByRef Instructions() As IrInstruction, ByVal InstructionCount As Long, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByVal ValueCount As Long, ByRef Cleanups() As IrCleanup, ByVal CleanupCount As Long, ByRef Locations() As IrLocation, ByVal LocationCount As Long, ByRef Managed As ManagedMetadata, ByRef ManagedLayouts() As ManagedLayout, ByRef ManagedSlots() As ManagedSlot, ByRef ManagedRoots() As ManagedRoot, ByRef ManagedSafePoints() As ManagedSafePoint, ByRef ManagedBarriers() As ManagedBarrier, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim RootForValue() As Long
    Dim LastUseHeads() As Long
    Dim LastUseNext() As Long
    If PrepareLlvmManagedValueRoots(Values, ValueCount, Instructions, InstructionCount, Operands, Managed, ManagedRoots, RootForValue, LastUseHeads, LastUseNext, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        EmitVerifiedIrToLlvm = 0
        Exit Function
    End If
    Dim NewLine As String = StringFromByte(10)
    Dim Quote As String = StringFromByte(34)
    If EmitLlvmRuntimeDeclarations(Abi, Chunks, ChunkCount, ChunkCapacity) = 0 Then
        EmitVerifiedIrToLlvm = 0
        Exit Function
    End If

    If EmitLlvmAggregateDefinitions(Abi, Types, TypeCount, Symbols, SymbolCount, Chunks, ChunkCount, ChunkCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        EmitVerifiedIrToLlvm = 0
        Exit Function
    End If
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, NewLine)
    If EmitLlvmValueLayouts(Abi, Types, TypeCount, Symbols, SymbolCount, Chunks, ChunkCount, ChunkCapacity) = 0 Then
        EmitVerifiedIrToLlvm = 0
        Exit Function
    End If

    ' These target-independent tables make the verified managed model part of
    ' the native artifact instead of leaving it only in a diagnostic dump.
    Dim ExportCount As Long = 0
    If EmitLlvmManagedAndAbiTables(Abi, Types, TypeCount, Symbols, SymbolCount, Program, Functions, FunctionCount, Parameters, Managed, ManagedLayouts, ManagedSlots, ManagedRoots, ManagedSafePoints, ManagedBarriers, ExportCount, Chunks, ChunkCount, ChunkCapacity) = 0 Then
        EmitVerifiedIrToLlvm = 0
        Exit Function
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

    If EmitLlvmEventHelpers(Abi, Types, TypeCount, Symbols, SymbolCount, Functions, FunctionCount, Parameters, Storages, StorageCount, Chunks, ChunkCount, ChunkCapacity) = 0 Then
        Call AddIrDiagnostic("UBE5108", "Event helper emission failed", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        EmitVerifiedIrToLlvm = 0
        Exit Function
    End If
    If EmitLlvmCallNewHelpers(Abi, Types, TypeCount, Symbols, SymbolCount, Functions, FunctionCount, Parameters, Instructions, InstructionCount, Operands, Chunks, ChunkCount, ChunkCapacity) = 0 Then
        Call AddIrDiagnostic("UBE5108", "CallNew helper emission failed", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        EmitVerifiedIrToLlvm = 0
        Exit Function
    End If

    If EmitLlvmFunctions(Abi, Types, TypeCount, Symbols, SymbolCount, Functions, FunctionCount, Parameters, Storages, StorageCount, Blocks, Instructions, InstructionCount, Operands, Values, ValueCount, Cleanups, CleanupCount, Locations, LocationCount, Managed, ManagedRoots, ManagedSafePoints, RootForValue, LastUseHeads, LastUseNext, Chunks, ChunkCount, ChunkCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        EmitVerifiedIrToLlvm = 0
        Exit Function
    End If

    If EmitLlvmObjectLifecycleHelpers(Abi, Types, TypeCount, Symbols, SymbolCount, Functions, FunctionCount, Storages, StorageCount, Chunks, ChunkCount, ChunkCapacity) = 0 Then
        EmitVerifiedIrToLlvm = 0
        Exit Function
    End If

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

    If EmitLlvmExportWrappers(Abi, Types, TypeCount, Symbols, Functions, FunctionCount, Parameters, Chunks, ChunkCount, ChunkCapacity) = 0 Then
        EmitVerifiedIrToLlvm = 0
        Exit Function
    End If

    If EmitLlvmProgramEntry(Abi, Types, TypeCount, Symbols, SymbolCount, Program, Globals, GlobalCount, Functions, FunctionCount, Storages, StorageCount, Managed, ManagedRoots, Chunks, ChunkCount, ChunkCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        EmitVerifiedIrToLlvm = 0
        Exit Function
    End If
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, NewLine & "!llvm.dbg.cu = !{!0}" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "!llvm.module.flags = !{!1, !2}" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "!0 = distinct !DICompileUnit(language: DW_LANG_C, file: !5, producer: " & Quote & "UBE Compiler v3 RP8" & Quote & ", isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug)" & NewLine)
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
    Dim DebugStorageIndex As Long = 0
    While DebugStorageIndex < StorageCount
        Dim DebugStorageFunction As Long = Storages(DebugStorageIndex).FunctionIndex
        If DebugStorageFunction >= 0 And DebugStorageFunction < FunctionCount Then
            Dim DebugStorageName As String = "storage" & LongToString(DebugStorageIndex)
            Dim DebugStorageSymbol As Long = Storages(DebugStorageIndex).SymbolIndex
            If DebugStorageSymbol >= 0 And DebugStorageSymbol < SymbolCount Then
                DebugStorageName = Symbols(DebugStorageSymbol).SymbolName
            End If
            Dim DebugStorageLine As Long = 1
            Dim DebugStorageFileNode As Long = 5
            Dim DebugStorageLocation As Long = Storages(DebugStorageIndex).LocationIndex
            If DebugStorageLocation >= 0 And DebugStorageLocation < LocationCount Then
                DebugStorageLine = Locations(DebugStorageLocation).LineNumber
                DebugStorageFileNode = 5 + DebugStorageLocation
                If DebugStorageLine < 1 Then
                    DebugStorageLine = 1
                End If
            End If
            Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "!" & LongToString(LlvmDebugVariableNode(DebugStorageIndex, LocationCount, FunctionCount, InstructionCount)) & " = !DILocalVariable(name: " & Quote & DebugStorageName & Quote & ", scope: !" & LongToString(LlvmDebugFunctionNode(DebugStorageFunction, LocationCount)) & ", file: !" & LongToString(DebugStorageFileNode) & ", line: " & LongToString(DebugStorageLine) & ", type: !" & LongToString(LlvmDebugVariableTypeNode(StorageCount, LocationCount, FunctionCount, InstructionCount)) & ")" & NewLine)
        End If
        DebugStorageIndex = DebugStorageIndex + 1
    Wend
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "!" & LongToString(LlvmDebugVariableTypeNode(StorageCount, LocationCount, FunctionCount, InstructionCount)) & " = !DIBasicType(name: " & Quote & "UBE value" & Quote & ", size: 64, encoding: DW_ATE_unsigned)" & NewLine)
    Call AppendLlvmChunk(Chunks, ChunkCount, ChunkCapacity, "!" & LongToString(LlvmDebugExpressionNode(StorageCount, LocationCount, FunctionCount, InstructionCount)) & " = !DIExpression()" & NewLine)
    EmitVerifiedIrToLlvm = 1
End Function
