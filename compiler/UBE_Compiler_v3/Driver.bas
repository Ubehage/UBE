UBE SOURCE 1 MODULE
Attribute UBE_Name = "Driver"

Sub ReportDriverFailure(ByVal StageName As String, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long)
    If DiagnosticCount = 0 Then
        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE5009", "<compiler>", 1, 1, "compiler stage failed without a diagnostic: " & StageName)
    End If
    Call ReportDiagnostics(Diagnostics, DiagnosticCount)
End Sub

Sub ReportNativeBuildFailure(ByVal Code As String, ByVal Path As String, ByVal Message As String)
    Dim Diagnostics() As CompilerDiagnostic
    Dim DiagnosticCount As Long = 0
    Dim DiagnosticCapacity As Long = 0
    Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Code, Path, 1, 1, Message)
    Call ReportDiagnostics(Diagnostics, DiagnosticCount)
End Sub

Function RunNativeCompilerDriver(ByVal ManifestPath As String, ByVal TargetTriple As String, ByVal ClangPath As String, ByVal RuntimeObjectPath As String, ByVal UnicodeRuntimeObjectPath As String, ByVal OutputPath As String, ByVal IntermediateIrPath As String) As Long
    Dim CleanupStatus As Long = 0
    If CompilerDeleteFile(IntermediateIrPath) <> 0 Then
        Call ReportNativeBuildFailure("UBE5110", IntermediateIrPath, "cannot remove the previous intermediate LLVM artifact")
        RunNativeCompilerDriver = 1
        Exit Function
    End If
    If CompilerDeleteFile(OutputPath) <> 0 Then
        Call ReportNativeBuildFailure("UBE5110", OutputPath, "cannot remove the previous native output artifact")
        RunNativeCompilerDriver = 1
        Exit Function
    End If
    If RunCompilerDriver(ManifestPath, TargetTriple, 5, IntermediateIrPath) <> 0 Then
        CleanupStatus = CompilerDeleteFile(IntermediateIrPath)
        RunNativeCompilerDriver = 1
        Exit Function
    End If

    Dim ToolArguments() As String
    ReDim ToolArguments(6)
    ToolArguments(0) = "--target=" & TargetTriple
    ToolArguments(1) = "-O2"
    ToolArguments(2) = IntermediateIrPath
    ToolArguments(3) = RuntimeObjectPath
    ToolArguments(4) = UnicodeRuntimeObjectPath
    ToolArguments(5) = "-o"
    ToolArguments(6) = OutputPath
    Dim ToolStatus As Long = CompilerRunTool(ClangPath, ToolArguments, 7)
    If ToolStatus <> 0 Then
        CleanupStatus = CompilerDeleteFile(OutputPath)
        CleanupStatus = CompilerDeleteFile(IntermediateIrPath)
        Call ReportNativeBuildFailure("UBE5111", ClangPath, "LLVM/Clang failed with exit status " & LongToString(ToolStatus))
        RunNativeCompilerDriver = 1
        Exit Function
    End If
    If CompilerDeleteFile(IntermediateIrPath) <> 0 Then
        CleanupStatus = CompilerDeleteFile(OutputPath)
        Call ReportNativeBuildFailure("UBE5112", IntermediateIrPath, "native compilation succeeded but its intermediate artifact could not be removed")
        RunNativeCompilerDriver = 1
        Exit Function
    End If
    RunNativeCompilerDriver = 0
End Function

Function RunCompilerDriver(ByVal ManifestPath As String, ByVal TargetTriple As String, ByVal OutputMode As Long, ByVal OutputPath As String) As Long
    Dim Diagnostics() As CompilerDiagnostic
    Dim DiagnosticCount As Long = 0
    Dim DiagnosticCapacity As Long = 0
    Dim Target As TargetDescription
    Dim Host As HostDescription
    Call ResolveBootstrapHost(Host)
    If ResolveTarget(TargetTriple, Target, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        Call ReportDriverFailure("target resolution", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        RunCompilerDriver = 1
        Exit Function
    End If

    Dim Project As ProjectDescription
    Dim SourcePaths() As String
    Dim SourceCount As Long = 0
    Dim SourceCapacity As Long = 0
    If LoadProjectManifest(ManifestPath, Project, SourcePaths, SourceCount, SourceCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        Call ReportDriverFailure("project manifest", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        RunCompilerDriver = 1
        Exit Function
    End If

    Dim Sources() As SourceDocument
    If LoadProjectSources(SourcePaths, SourceCount, Sources, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        Call ReportDriverFailure("source loading", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        RunCompilerDriver = 1
        Exit Function
    End If

    Dim Envelopes() As SourceEnvelopeInfo
    If ValidateSourceEnvelopes(Sources, SourceCount, Envelopes, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        Call ReportDriverFailure("source envelopes", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        RunCompilerDriver = 1
        Exit Function
    End If

    Dim Tokens() As LexicalToken
    Dim TokenCount As Long = 0
    Dim TokenCapacity As Long = 0
    Dim SourceIndex As Long = 0
    While SourceIndex < SourceCount
        Dim PreprocessedText As String = ""
        If PreprocessOneSource(Sources(SourceIndex), PreprocessedText, Diagnostics, DiagnosticCount, DiagnosticCapacity) <> 0 Then
            Call LexOneSource(Sources(SourceIndex), PreprocessedText, Tokens, TokenCount, TokenCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        End If
        SourceIndex = SourceIndex + 1
    Wend
    If DiagnosticCount <> 0 Then
        Call ReportDriverFailure("preprocessing or lexing", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        RunCompilerDriver = 1
        Exit Function
    End If

    Dim GrammarRules() As GrammarRule
    Dim GrammarRuleCount As Long = 0
    Dim GrammarNodes() As GrammarExpression
    Dim GrammarNodeCount As Long = 0
    Dim GrammarLinks() As GrammarChildLink
    Dim GrammarLinkCount As Long = 0
    If LoadGrammarModel(GrammarRules, GrammarRuleCount, GrammarNodes, GrammarNodeCount, GrammarLinks, GrammarLinkCount, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        Call ReportDriverFailure("grammar model", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        RunCompilerDriver = 1
        Exit Function
    End If

    If OutputMode = 1 Then
        Call WriteTokenDump(Tokens, TokenCount)
        RunCompilerDriver = 0
        Exit Function
    End If

    Dim SyntaxNodes() As SyntaxNode
    Dim SyntaxNodeCount As Long = 0
    Dim SyntaxNodeCapacity As Long = 0
    Dim SyntaxLinks() As SyntaxChildLink
    Dim SyntaxLinkCount As Long = 0
    Dim SyntaxLinkCapacity As Long = 0
    Dim TokenCursor As Long = 0
    SourceIndex = 0
    While SourceIndex < SourceCount
        Dim SourceTokenStart As Long = TokenCursor
        While TokenCursor < TokenCount
            If Tokens(TokenCursor).SourceId <> Sources(SourceIndex).SourceId Then
                Exit While
            End If
            TokenCursor = TokenCursor + 1
        Wend
        Call ParseOneSource(Sources(SourceIndex), GrammarRules, GrammarRuleCount, GrammarNodes, GrammarLinks, Tokens, SourceTokenStart, TokenCursor, SyntaxNodes, SyntaxNodeCount, SyntaxNodeCapacity, SyntaxLinks, SyntaxLinkCount, SyntaxLinkCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        SourceIndex = SourceIndex + 1
    Wend
    If DiagnosticCount <> 0 Then
        Call ReportDriverFailure("syntax parsing", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        RunCompilerDriver = 1
        Exit Function
    End If

    If OutputMode = 2 Then
        Call WriteSyntaxDump(SyntaxNodes, SyntaxNodeCount, GrammarRules, Tokens, GrammarRuleCount)
        RunCompilerDriver = 0
        Exit Function
    End If

    Dim SemanticStateValue As SemanticState
    Dim SemanticTypes() As SemanticType
    Dim SemanticTypeCount As Long = 0
    Dim SemanticTypeCapacity As Long = 0
    Dim SemanticScopes() As SemanticScope
    Dim SemanticScopeCount As Long = 0
    Dim SemanticScopeCapacity As Long = 0
    Dim SemanticSymbols() As SemanticSymbol
    Dim SemanticSymbolCount As Long = 0
    Dim SemanticSymbolCapacity As Long = 0
    Dim SemanticLinks() As SemanticSymbolLink
    Dim SemanticLinkCount As Long = 0
    Dim SemanticLinkCapacity As Long = 0
    Dim SemanticExpressions() As SemanticExpression
    Dim SemanticExpressionCount As Long = 0
    Dim SemanticExpressionCapacity As Long = 0
    Dim SemanticBindings() As SemanticNodeBinding
    Dim SemanticBindingCount As Long = 0
    Dim SemanticBindingCapacity As Long = 0
    Call AnalyzeSemantics(Project, Sources, SourceCount, Envelopes, Tokens, SyntaxNodes, SyntaxNodeCount, SyntaxLinks, GrammarRules, SemanticStateValue, SemanticTypes, SemanticTypeCount, SemanticTypeCapacity, SemanticScopes, SemanticScopeCount, SemanticScopeCapacity, SemanticSymbols, SemanticSymbolCount, SemanticSymbolCapacity, SemanticLinks, SemanticLinkCount, SemanticLinkCapacity, SemanticExpressions, SemanticExpressionCount, SemanticExpressionCapacity, SemanticBindings, SemanticBindingCount, SemanticBindingCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity)
    If DiagnosticCount <> 0 Then
        Call ReportDriverFailure("semantic analysis", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        RunCompilerDriver = 1
        Exit Function
    End If

    If OutputMode = 3 Then
        Call WriteSemanticDump(SemanticStateValue, SemanticTypes, SemanticTypeCount, SemanticScopes, SemanticScopeCount, SemanticSymbols, SemanticSymbolCount)
        RunCompilerDriver = 0
        Exit Function
    End If

    If OutputMode = 4 Or OutputMode = 5 Then
        Dim IrProgramValue As IrProgram
        Dim IrGlobals() As IrGlobal
        Dim IrFunctions() As IrFunction
        Dim IrParameters() As IrParameter
        Dim IrStorages() As IrStorage
        Dim IrBlocks() As IrBlock
        Dim IrInstructions() As IrInstruction
        Dim IrOperands() As IrOperand
        Dim IrValues() As IrValue
        Dim IrEdges() As IrEdge
        Dim IrCleanups() As IrCleanup
        Dim IrLocations() As IrLocation
        Dim IrBuild As IrBuildState
        If LowerSemanticProgramToIr(SemanticStateValue, SemanticTypes, SemanticTypeCount, SemanticSymbols, SemanticSymbolCount, SemanticExpressions, SemanticExpressionCount, SemanticBindings, SemanticBindingCount, SyntaxNodes, GrammarRules, Tokens, IrProgramValue, IrGlobals, IrFunctions, IrParameters, IrStorages, IrBlocks, IrInstructions, IrOperands, IrValues, IrEdges, IrCleanups, IrLocations, IrBuild, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
            Call ReportDriverFailure("IR lowering", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            RunCompilerDriver = 1
            Exit Function
        End If
        If VerifyProgramIr(IrProgramValue, IrGlobals, IrBuild.GlobalCount, IrFunctions, IrBuild.FunctionCount, IrParameters, IrBuild.ParameterCount, IrStorages, IrBuild.StorageCount, IrBlocks, IrBuild.BlockCount, IrInstructions, IrBuild.InstructionCount, IrOperands, IrBuild.OperandCount, IrValues, IrBuild.ValueCount, IrEdges, IrBuild.EdgeCount, IrCleanups, IrBuild.CleanupCount, IrLocations, IrBuild.LocationCount, SemanticTypes, SemanticTypeCount, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
            Call ReportDriverFailure("IR verification", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            RunCompilerDriver = 1
            Exit Function
        End If
        If OutputMode = 4 Then
            Call WriteIrDump(IrProgramValue, IrGlobals, IrBuild.GlobalCount, IrFunctions, IrBuild.FunctionCount, IrParameters, IrBuild.ParameterCount, IrStorages, IrBuild.StorageCount, IrBlocks, IrBuild.BlockCount, IrInstructions, IrBuild.InstructionCount, IrOperands, IrBuild.OperandCount, IrValues, IrBuild.ValueCount, IrEdges, IrBuild.EdgeCount, IrCleanups, IrBuild.CleanupCount, IrLocations, IrBuild.LocationCount)
        Else
            Dim TargetAbi As TargetAbiDescription
            If ResolveTargetAbi(Target, TargetAbi) = 0 Then
                Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE5101", "<target>", 1, 1, "target has no frozen RP5 ABI description")
                Call ReportDriverFailure("target ABI", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                RunCompilerDriver = 1
                Exit Function
            End If
            Dim LlvmChunks() As String
            Dim LlvmChunkCount As Long = 0
            Dim LlvmChunkCapacity As Long = 0
            If EmitVerifiedIrToLlvm(Target, TargetAbi, SemanticTypes, SemanticTypeCount, SemanticSymbols, SemanticSymbolCount, IrProgramValue, IrGlobals, IrBuild.GlobalCount, IrFunctions, IrBuild.FunctionCount, IrParameters, IrBuild.ParameterCount, IrStorages, IrBuild.StorageCount, IrBlocks, IrInstructions, IrBuild.InstructionCount, IrOperands, IrValues, IrCleanups, IrBuild.CleanupCount, IrLocations, IrBuild.LocationCount, LlvmChunks, LlvmChunkCount, LlvmChunkCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
                Call ReportDriverFailure("LLVM emission", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                RunCompilerDriver = 1
                Exit Function
            End If
            Dim LlvmText As String = StringArrayJoin(LlvmChunks, LlvmChunkCount)
            If StringLength(LlvmText) > LimitGeneratedBytes() Then
                Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE5102", OutputPath, 1, 1, "generated LLVM exceeds the configured output limit")
                Call ReportDriverFailure("LLVM output size", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                RunCompilerDriver = 1
                Exit Function
            End If
            Dim WriteStatus As Long = WriteAllText(OutputPath, LlvmText)
            If WriteStatus <> 0 Then
                Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE5109", OutputPath, 1, 1, "cannot atomically write generated LLVM output")
                Call ReportDriverFailure("LLVM output write", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                RunCompilerDriver = 1
                Exit Function
            End If
        End If
        RunCompilerDriver = 0
        Exit Function
    End If

    Print "UBE Compiler v3 RP5: project " & Project.ProjectName & " (" & Project.Kind & "), " & LongToString(Project.SourceCount) & " source(s), " & LongToString(TokenCount) & " token(s), " & LongToString(SyntaxNodeCount) & " syntax node(s), " & LongToString(SemanticSymbolCount) & " symbol(s), host " & Host.Id & ", target " & Target.Triple
    RunCompilerDriver = 0
End Function
