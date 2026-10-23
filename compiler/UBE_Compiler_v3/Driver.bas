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

Function FindReferenceState(ByVal ManifestPath As String, ByRef SeenPaths() As String, ByVal SeenCount As Long) As Long
    Dim Index As Long = 0
    While Index < SeenCount
        If EqualsFolded(SeenPaths(Index), ManifestPath) <> 0 Then
            FindReferenceState = Index
            Exit Function
        End If
        Index = Index + 1
    Wend
    FindReferenceState = -1
End Function

Function FindReferenceSourcePath(ByVal SourcePath As String, ByRef SourcePaths() As String, ByVal SourceCount As Long) As Long
    Dim Index As Long = 0
    While Index < SourceCount
        If EqualsFolded(SourcePaths(Index), SourcePath) <> 0 Then
            FindReferenceSourcePath = Index
            Exit Function
        End If
        Index = Index + 1
    Wend
    FindReferenceSourcePath = -1
End Function

Function LoadReferenceTree(ByVal ManifestPath As String, ByVal Depth As Long, ByRef SourcePaths() As String, ByRef SourceDepths() As Long, ByRef SourceCount As Long, ByRef SourceCapacity As Long, ByRef SeenPaths() As String, ByRef SeenStates() As Long, ByRef SeenCount As Long, ByRef SeenCapacity As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    If Depth > LimitProjectReferences() Then
        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3023", ManifestPath, 1, 1, "project reference depth exceeds the configured limit")
        LoadReferenceTree = 0
        Exit Function
    End If
    Dim Existing As Long = FindReferenceState(ManifestPath, SeenPaths, SeenCount)
    If Existing >= 0 Then
        If SeenStates(Existing) = 1 Then
            Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3024", ManifestPath, 1, 1, "cyclic project Reference")
            LoadReferenceTree = 0
            Exit Function
        End If
        LoadReferenceTree = 1
        Exit Function
    End If
    If AppendString(SeenPaths, SeenCount, SeenCapacity, ManifestPath, LimitProjectReferences()) = 0 Then
        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3025", ManifestPath, 1, 1, "project reference graph exceeds the configured limit")
        LoadReferenceTree = 0
        Exit Function
    End If
    If SeenCapacity > 0 Then
        ReDim Preserve SeenStates(SeenCapacity - 1)
    End If
    Dim SeenIndex As Long = SeenCount - 1
    SeenStates(SeenIndex) = 1

    Dim ReferencedProject As ProjectDescription
    Dim ReferencedSources() As String
    Dim ReferencedSourceCount As Long = 0
    Dim ReferencedSourceCapacity As Long = 0
    Dim ChildReferences() As String
    Dim ChildReferenceCount As Long = 0
    Dim ChildReferenceCapacity As Long = 0
    If LoadProjectManifest(ManifestPath, ReferencedProject, ReferencedSources, ReferencedSourceCount, ReferencedSourceCapacity, ChildReferences, ChildReferenceCount, ChildReferenceCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        LoadReferenceTree = 0
        Exit Function
    End If
    If EqualsFolded(ReferencedProject.Kind, "Library") = 0 Then
        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3026", ManifestPath, 1, 1, "Reference target must be a Library project")
        LoadReferenceTree = 0
        Exit Function
    End If
    Dim SourceIndex As Long = 0
    While SourceIndex < ReferencedSourceCount
        Dim ExistingSource As Long = FindReferenceSourcePath(ReferencedSources(SourceIndex), SourcePaths, SourceCount)
        If ExistingSource < 0 Then
            If AppendString(SourcePaths, SourceCount, SourceCapacity, ReferencedSources(SourceIndex), LimitProjectSources()) = 0 Then
                Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3027", ManifestPath, 1, 1, "referenced source graph exceeds the configured source limit")
                LoadReferenceTree = 0
                Exit Function
            End If
            ReDim Preserve SourceDepths(SourceCapacity - 1)
            SourceDepths(SourceCount - 1) = Depth
        Else
            If SourceDepths(ExistingSource) > Depth Then
                SourceDepths(ExistingSource) = Depth
            End If
        End If
        SourceIndex = SourceIndex + 1
    Wend
    Dim ReferenceIndex As Long = 0
    While ReferenceIndex < ChildReferenceCount
        If LoadReferenceTree(ChildReferences(ReferenceIndex), Depth + 1, SourcePaths, SourceDepths, SourceCount, SourceCapacity, SeenPaths, SeenStates, SeenCount, SeenCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
            LoadReferenceTree = 0
            Exit Function
        End If
        ReferenceIndex = ReferenceIndex + 1
    Wend
    SeenStates(SeenIndex) = 2
    LoadReferenceTree = 1
End Function

Function ExpandProjectReferences(ByVal RootManifest As String, ByRef ReferencePaths() As String, ByVal ReferenceCount As Long, ByRef SourcePaths() As String, ByRef SourceDepths() As Long, ByRef SourceCount As Long, ByRef SourceCapacity As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim SeenPaths() As String
    Dim SeenStates() As Long
    Dim SeenCount As Long = 0
    Dim SeenCapacity As Long = 0
    If AppendString(SeenPaths, SeenCount, SeenCapacity, RootManifest, LimitProjectReferences()) = 0 Then
        ExpandProjectReferences = 0
        Exit Function
    End If
    ReDim SeenStates(SeenCapacity - 1)
    SeenStates(0) = 1
    Dim Index As Long = 0
    While Index < ReferenceCount
        If LoadReferenceTree(ReferencePaths(Index), 1, SourcePaths, SourceDepths, SourceCount, SourceCapacity, SeenPaths, SeenStates, SeenCount, SeenCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
            ExpandProjectReferences = 0
            Exit Function
        End If
        Index = Index + 1
    Wend
    SeenStates(0) = 2
    ExpandProjectReferences = 1
End Function

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
    If CompilerDeleteFile(IntermediateIrPath & ".h") <> 0 Or CompilerDeleteFile(OutputPath & ".h") <> 0 Then
        Call ReportNativeBuildFailure("UBE5110", OutputPath & ".h", "cannot remove a previous foreign ABI header artifact")
        RunNativeCompilerDriver = 1
        Exit Function
    End If
    If RunCompilerDriver(ManifestPath, TargetTriple, 5, IntermediateIrPath) <> 0 Then
        CleanupStatus = CompilerDeleteFile(IntermediateIrPath)
        RunNativeCompilerDriver = 1
        Exit Function
    End If

    Dim NativeProject As ProjectDescription
    Dim NativeSources() As String
    Dim NativeSourceCount As Long = 0
    Dim NativeSourceCapacity As Long = 0
    Dim NativeReferences() As String
    Dim NativeReferenceCount As Long = 0
    Dim NativeReferenceCapacity As Long = 0
    Dim NativeDiagnostics() As CompilerDiagnostic
    Dim NativeDiagnosticCount As Long = 0
    Dim NativeDiagnosticCapacity As Long = 0
    If LoadProjectManifest(ManifestPath, NativeProject, NativeSources, NativeSourceCount, NativeSourceCapacity, NativeReferences, NativeReferenceCount, NativeReferenceCapacity, NativeDiagnostics, NativeDiagnosticCount, NativeDiagnosticCapacity) = 0 Then
        CleanupStatus = CompilerDeleteFile(IntermediateIrPath)
        Call ReportDriverFailure("native project manifest", NativeDiagnostics, NativeDiagnosticCount, NativeDiagnosticCapacity)
        RunNativeCompilerDriver = 1
        Exit Function
    End If
    Dim ToolArguments() As String
    Dim ToolArgumentCount As Long = 7
    If EqualsFolded(NativeProject.Kind, "Library") <> 0 Then
        ReDim ToolArguments(7)
        ToolArguments(0) = "--target=" & TargetTriple
        ToolArguments(1) = "-O2"
        ToolArguments(2) = "-shared"
        ToolArguments(3) = IntermediateIrPath
        ToolArguments(4) = RuntimeObjectPath
        ToolArguments(5) = UnicodeRuntimeObjectPath
        ToolArguments(6) = "-o"
        ToolArguments(7) = OutputPath
        ToolArgumentCount = 8
    Else
        ReDim ToolArguments(6)
        ToolArguments(0) = "--target=" & TargetTriple
        ToolArguments(1) = "-O2"
        ToolArguments(2) = IntermediateIrPath
        ToolArguments(3) = RuntimeObjectPath
        ToolArguments(4) = UnicodeRuntimeObjectPath
        ToolArguments(5) = "-o"
        ToolArguments(6) = OutputPath
    End If
    Dim ToolStatus As Long = CompilerRunTool(ClangPath, ToolArguments, ToolArgumentCount)
    If ToolStatus <> 0 Then
        CleanupStatus = CompilerDeleteFile(OutputPath)
        CleanupStatus = CompilerDeleteFile(IntermediateIrPath)
        Call ReportNativeBuildFailure("UBE5111", ClangPath, "LLVM/Clang failed with exit status " & LongToString(ToolStatus))
        RunNativeCompilerDriver = 1
        Exit Function
    End If
    If EqualsFolded(NativeProject.Kind, "Library") <> 0 Then
        Dim HeaderText As String = ReadAllText(IntermediateIrPath & ".h")
        If WriteAllText(OutputPath & ".h", HeaderText) <> 0 Then
            CleanupStatus = CompilerDeleteFile(OutputPath)
            CleanupStatus = CompilerDeleteFile(IntermediateIrPath)
            CleanupStatus = CompilerDeleteFile(IntermediateIrPath & ".h")
            Call ReportNativeBuildFailure("UBE5113", OutputPath & ".h", "cannot preserve the generated foreign ABI declarations")
            RunNativeCompilerDriver = 1
            Exit Function
        End If
        CleanupStatus = CompilerDeleteFile(IntermediateIrPath & ".h")
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
    Dim ReferencePaths() As String
    Dim ReferenceCount As Long = 0
    Dim ReferenceCapacity As Long = 0
    If LoadProjectManifest(ManifestPath, Project, SourcePaths, SourceCount, SourceCapacity, ReferencePaths, ReferenceCount, ReferenceCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        Call ReportDriverFailure("project manifest", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        RunCompilerDriver = 1
        Exit Function
    End If
    Dim SourceDepths() As Long
    ReDim SourceDepths(SourceCapacity - 1)
    If ExpandProjectReferences(ManifestPath, ReferencePaths, ReferenceCount, SourcePaths, SourceDepths, SourceCount, SourceCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        Call ReportDriverFailure("project references", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        RunCompilerDriver = 1
        Exit Function
    End If

    Dim Sources() As SourceDocument
    If LoadProjectSources(SourcePaths, SourceCount, Sources, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        Call ReportDriverFailure("source loading", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        RunCompilerDriver = 1
        Exit Function
    End If
    Dim SourceIndex As Long = 0
    While SourceIndex < SourceCount
        Sources(SourceIndex).ReferenceDepth = SourceDepths(SourceIndex)
        SourceIndex = SourceIndex + 1
    Wend

    Dim Envelopes() As SourceEnvelopeInfo
    If ValidateSourceEnvelopes(Sources, SourceCount, Envelopes, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        Call ReportDriverFailure("source envelopes", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        RunCompilerDriver = 1
        Exit Function
    End If

    Dim Tokens() As LexicalToken
    Dim TokenCount As Long = 0
    Dim TokenCapacity As Long = 0
    SourceIndex = 0
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

    If OutputMode = 4 Or OutputMode = 5 Or OutputMode = 6 Then
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
        If StringLength(Project.StartupForm) > 0 Then
            Dim StartupFormCandidate As Long = 0
            While StartupFormCandidate < SemanticSymbolCount
                If SemanticSymbols(StartupFormCandidate).SymbolKind = SemanticSymbolModule() And SemanticSymbols(StartupFormCandidate).Flags = 3 And EqualsFolded(SemanticSymbols(StartupFormCandidate).SymbolName, Project.StartupForm) <> 0 Then
                    IrProgramValue.StartupFormSymbol = StartupFormCandidate
                End If
                StartupFormCandidate = StartupFormCandidate + 1
            Wend
            If IrProgramValue.StartupFormSymbol < 0 Then
                Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE4049", Project.ManifestPath, 1, 1, "StartupForm does not name a project form: " & Project.StartupForm)
                Call ReportDriverFailure("startup form", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                RunCompilerDriver = 1
                Exit Function
            End If
        End If
        If VerifyProgramIr(IrProgramValue, IrGlobals, IrBuild.GlobalCount, IrFunctions, IrBuild.FunctionCount, IrParameters, IrBuild.ParameterCount, IrStorages, IrBuild.StorageCount, IrBlocks, IrBuild.BlockCount, IrInstructions, IrBuild.InstructionCount, IrOperands, IrBuild.OperandCount, IrValues, IrBuild.ValueCount, IrEdges, IrBuild.EdgeCount, IrCleanups, IrBuild.CleanupCount, IrLocations, IrBuild.LocationCount, SemanticTypes, SemanticTypeCount, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
            Call ReportDriverFailure("IR verification", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            RunCompilerDriver = 1
            Exit Function
        End If
        Dim ManagedMetadataValue As ManagedMetadata
        Dim ManagedLayouts() As ManagedLayout
        Dim ManagedSlots() As ManagedSlot
        Dim ManagedRoots() As ManagedRoot
        Dim ManagedSafePoints() As ManagedSafePoint
        Dim ManagedBarriers() As ManagedBarrier
        Dim ManagedPins() As ManagedPin
        Dim ManagedFinalizers() As ManagedFinalizer
        If BuildManagedMetadata(SemanticTypes, SemanticTypeCount, SemanticSymbols, SemanticSymbolCount, IrFunctions, IrBuild.FunctionCount, IrStorages, IrBuild.StorageCount, IrBlocks, IrBuild.BlockCount, IrInstructions, IrBuild.InstructionCount, IrOperands, IrBuild.OperandCount, IrValues, IrBuild.ValueCount, IrEdges, IrBuild.EdgeCount, ManagedMetadataValue, ManagedLayouts, ManagedSlots, ManagedRoots, ManagedSafePoints, ManagedBarriers, ManagedPins, ManagedFinalizers) = 0 Then
            Call AddIrDiagnostic("UBE5208", "managed metadata construction exceeded a configured bound", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Call ReportDriverFailure("managed metadata", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            RunCompilerDriver = 1
            Exit Function
        End If
        If VerifyManagedMetadata(SemanticTypes, SemanticTypeCount, IrFunctions, IrBuild.FunctionCount, IrStorages, IrBuild.StorageCount, IrBlocks, IrBuild.BlockCount, IrInstructions, IrBuild.InstructionCount, IrOperands, IrBuild.OperandCount, IrValues, IrBuild.ValueCount, ManagedMetadataValue, ManagedLayouts, ManagedSlots, ManagedRoots, ManagedSafePoints, ManagedBarriers, ManagedPins, ManagedFinalizers, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
            Call ReportDriverFailure("managed metadata verification", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            RunCompilerDriver = 1
            Exit Function
        End If
        If OutputMode = 4 Then
            Call WriteIrDump(IrProgramValue, IrGlobals, IrBuild.GlobalCount, IrFunctions, IrBuild.FunctionCount, IrParameters, IrBuild.ParameterCount, IrStorages, IrBuild.StorageCount, IrBlocks, IrBuild.BlockCount, IrInstructions, IrBuild.InstructionCount, IrOperands, IrBuild.OperandCount, IrValues, IrBuild.ValueCount, IrEdges, IrBuild.EdgeCount, IrCleanups, IrBuild.CleanupCount, IrLocations, IrBuild.LocationCount)
        Else
            If OutputMode = 6 Then
                Call WriteManagedDump(ManagedMetadataValue, ManagedLayouts, ManagedSlots, ManagedRoots, ManagedSafePoints, ManagedBarriers, ManagedPins, ManagedFinalizers)
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
            If EmitVerifiedIrToLlvm(Target, TargetAbi, SemanticTypes, SemanticTypeCount, SemanticSymbols, SemanticSymbolCount, IrProgramValue, IrGlobals, IrBuild.GlobalCount, IrFunctions, IrBuild.FunctionCount, IrParameters, IrBuild.ParameterCount, IrStorages, IrBuild.StorageCount, IrBlocks, IrInstructions, IrBuild.InstructionCount, IrOperands, IrValues, IrBuild.ValueCount, IrCleanups, IrBuild.CleanupCount, IrLocations, IrBuild.LocationCount, ManagedMetadataValue, ManagedLayouts, ManagedSlots, ManagedRoots, ManagedSafePoints, ManagedBarriers, LlvmChunks, LlvmChunkCount, LlvmChunkCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
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
                If EqualsFolded(Project.Kind, "Library") <> 0 Then
                    If WriteForeignAbiHeader(OutputPath, SemanticTypes, SemanticTypeCount, SemanticSymbols, SemanticSymbolCount, IrFunctions, IrBuild.FunctionCount, IrParameters) <> 0 Then
                        Dim HeaderCleanup As Long = CompilerDeleteFile(OutputPath)
                        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE5113", OutputPath & ".h", 1, 1, "cannot atomically write generated foreign ABI declarations")
                        Call ReportDriverFailure("foreign ABI header write", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        RunCompilerDriver = 1
                        Exit Function
                    End If
                End If
            End If
        End If
        RunCompilerDriver = 0
        Exit Function
    End If

    Print "UBE Compiler v3 RP7: project " & Project.ProjectName & " (" & Project.Kind & "), " & LongToString(Project.SourceCount) & " source(s), " & LongToString(TokenCount) & " token(s), " & LongToString(SyntaxNodeCount) & " syntax node(s), " & LongToString(SemanticSymbolCount) & " symbol(s), host " & Host.Id & ", target " & Target.Triple
    RunCompilerDriver = 0
End Function
