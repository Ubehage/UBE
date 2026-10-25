UBE SOURCE 1 MODULE
Attribute UBE_Name = "PerformanceProfile"

' Performance data is deliberately separate from semantic and emitted output.
' The profile is opt-in, machine-readable, and never participates in IDs or
' artifact construction, so measuring a build cannot change its result.
Type CompilerPerformanceProfile
    Enabled As Long
    StartWallMilliseconds As Long
    StartCpuMilliseconds As Long
    TotalWallMilliseconds As Long
    TotalCpuMilliseconds As Long
    PeakWorkingSetKilobytes As Long
    ProjectMilliseconds As Long
    SourceLoadMilliseconds As Long
    EnvelopeMilliseconds As Long
    FrontEndMilliseconds As Long
    GrammarMilliseconds As Long
    ParseMilliseconds As Long
    SemanticsMilliseconds As Long
    IrLowerMilliseconds As Long
    IrLowerSetupMilliseconds As Long
    IrLowerBodyMilliseconds As Long
    IrLowerFinalizeMilliseconds As Long
    IrVerifyMilliseconds As Long
    ManagedMilliseconds As Long
    LlvmMilliseconds As Long
    OutputWriteMilliseconds As Long
    SourceCount As Long
    SourceBytes As Long
    TokenCount As Long
    SyntaxNodeCount As Long
    SemanticTypeCount As Long
    SemanticScopeCount As Long
    SemanticSymbolCount As Long
    SemanticExpressionCount As Long
    IrGlobalCount As Long
    IrFunctionCount As Long
    IrBlockCount As Long
    IrInstructionCount As Long
    IrOperandCount As Long
    IrValueCount As Long
    IrEdgeCount As Long
    IrCleanupCount As Long
    IrLocationCount As Long
    GeneratedBytes As Long
End Type

Sub BeginPerformanceProfile(ByRef Profile As CompilerPerformanceProfile, ByVal Enabled As Long)
    Profile.Enabled = Enabled
    If Enabled <> 0 Then
        Profile.StartWallMilliseconds = CompilerMonotonicMilliseconds()
        Profile.StartCpuMilliseconds = CompilerProcessCpuMilliseconds()
    End If
End Sub

Function BeginProfilePhase(ByRef Profile As CompilerPerformanceProfile) As Long
    BeginProfilePhase = -1
    If Profile.Enabled <> 0 Then
        BeginProfilePhase = CompilerMonotonicMilliseconds()
    End If
End Function

Function EndProfilePhase(ByRef Profile As CompilerPerformanceProfile, ByVal StartedAt As Long) As Long
    EndProfilePhase = 0
    If Profile.Enabled = 0 Or StartedAt < 0 Then
        Exit Function
    End If
    Dim FinishedAt As Long = CompilerMonotonicMilliseconds()
    If FinishedAt >= StartedAt Then
        EndProfilePhase = FinishedAt - StartedAt
    Else
        EndProfilePhase = -1
    End If
End Function

Sub CompletePerformanceProfile(ByRef Profile As CompilerPerformanceProfile)
    If Profile.Enabled = 0 Then
        Exit Sub
    End If
    Dim FinishedWall As Long = CompilerMonotonicMilliseconds()
    Dim FinishedCpu As Long = CompilerProcessCpuMilliseconds()
    If FinishedWall >= Profile.StartWallMilliseconds Then
        Profile.TotalWallMilliseconds = FinishedWall - Profile.StartWallMilliseconds
    Else
        Profile.TotalWallMilliseconds = -1
    End If
    If FinishedCpu >= Profile.StartCpuMilliseconds Then
        Profile.TotalCpuMilliseconds = FinishedCpu - Profile.StartCpuMilliseconds
    Else
        Profile.TotalCpuMilliseconds = -1
    End If
    Profile.PeakWorkingSetKilobytes = CompilerPeakWorkingSetKilobytes()
End Sub

Function ProfileField(ByVal FieldName As String, ByVal Value As Long) As String
    ProfileField = FieldName & "=" & LongToString(Value) & StringFromByte(10)
End Function

Function PerformanceProfileText(ByRef Profile As CompilerPerformanceProfile) As String
    Dim TextValue As String = "UBE-COMPILER-PROFILE 1" & StringFromByte(10)
    TextValue = TextValue & "execution=sequential" & StringFromByte(10)
    TextValue = TextValue & ProfileField("requested_jobs", 1)
    TextValue = TextValue & ProfileField("effective_jobs", 1)
    TextValue = TextValue & ProfileField("total_wall_ms", Profile.TotalWallMilliseconds)
    TextValue = TextValue & ProfileField("total_cpu_ms", Profile.TotalCpuMilliseconds)
    TextValue = TextValue & ProfileField("peak_working_set_kib", Profile.PeakWorkingSetKilobytes)
    TextValue = TextValue & ProfileField("phase_project_ms", Profile.ProjectMilliseconds)
    TextValue = TextValue & ProfileField("phase_source_load_ms", Profile.SourceLoadMilliseconds)
    TextValue = TextValue & ProfileField("phase_envelope_ms", Profile.EnvelopeMilliseconds)
    TextValue = TextValue & ProfileField("phase_front_end_ms", Profile.FrontEndMilliseconds)
    TextValue = TextValue & ProfileField("phase_grammar_ms", Profile.GrammarMilliseconds)
    TextValue = TextValue & ProfileField("phase_parse_ms", Profile.ParseMilliseconds)
    TextValue = TextValue & ProfileField("phase_semantics_ms", Profile.SemanticsMilliseconds)
    TextValue = TextValue & ProfileField("phase_ir_lower_ms", Profile.IrLowerMilliseconds)
    TextValue = TextValue & ProfileField("phase_ir_lower_setup_ms", Profile.IrLowerSetupMilliseconds)
    TextValue = TextValue & ProfileField("phase_ir_lower_body_ms", Profile.IrLowerBodyMilliseconds)
    TextValue = TextValue & ProfileField("phase_ir_lower_finalize_ms", Profile.IrLowerFinalizeMilliseconds)
    TextValue = TextValue & ProfileField("phase_ir_verify_ms", Profile.IrVerifyMilliseconds)
    TextValue = TextValue & ProfileField("phase_managed_ms", Profile.ManagedMilliseconds)
    TextValue = TextValue & ProfileField("phase_llvm_ms", Profile.LlvmMilliseconds)
    TextValue = TextValue & ProfileField("phase_output_write_ms", Profile.OutputWriteMilliseconds)
    TextValue = TextValue & ProfileField("source_count", Profile.SourceCount)
    TextValue = TextValue & ProfileField("source_bytes", Profile.SourceBytes)
    TextValue = TextValue & ProfileField("token_count", Profile.TokenCount)
    TextValue = TextValue & ProfileField("syntax_node_count", Profile.SyntaxNodeCount)
    TextValue = TextValue & ProfileField("semantic_type_count", Profile.SemanticTypeCount)
    TextValue = TextValue & ProfileField("semantic_scope_count", Profile.SemanticScopeCount)
    TextValue = TextValue & ProfileField("semantic_symbol_count", Profile.SemanticSymbolCount)
    TextValue = TextValue & ProfileField("semantic_expression_count", Profile.SemanticExpressionCount)
    TextValue = TextValue & ProfileField("ir_global_count", Profile.IrGlobalCount)
    TextValue = TextValue & ProfileField("ir_function_count", Profile.IrFunctionCount)
    TextValue = TextValue & ProfileField("ir_block_count", Profile.IrBlockCount)
    TextValue = TextValue & ProfileField("ir_instruction_count", Profile.IrInstructionCount)
    TextValue = TextValue & ProfileField("ir_operand_count", Profile.IrOperandCount)
    TextValue = TextValue & ProfileField("ir_value_count", Profile.IrValueCount)
    TextValue = TextValue & ProfileField("ir_edge_count", Profile.IrEdgeCount)
    TextValue = TextValue & ProfileField("ir_cleanup_count", Profile.IrCleanupCount)
    TextValue = TextValue & ProfileField("ir_location_count", Profile.IrLocationCount)
    TextValue = TextValue & ProfileField("generated_bytes", Profile.GeneratedBytes)
    PerformanceProfileText = TextValue
End Function

Function WritePerformanceProfile(ByVal Path As String, ByRef Profile As CompilerPerformanceProfile) As Long
    WritePerformanceProfile = WriteAllText(Path, PerformanceProfileText(Profile))
End Function
