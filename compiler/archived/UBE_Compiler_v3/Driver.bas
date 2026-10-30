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

Function LoadReferenceTree(ByVal ManifestPath As String, ByVal TargetTriple As String, ByVal Depth As Long, ByRef SourcePaths() As String, ByRef SourceDepths() As Long, ByRef SourceCount As Long, ByRef SourceCapacity As Long, ByRef SeenPaths() As String, ByRef SeenStates() As Long, ByRef SeenCount As Long, ByRef SeenCapacity As Long, ByRef ResourceData As String, ByRef ResourceLengths As String, ByRef ResourceCount As Long, ByRef ResourceBytes As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
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
    If LoadProjectManifest(ManifestPath, TargetTriple, ReferencedProject, ReferencedSources, ReferencedSourceCount, ReferencedSourceCapacity, ChildReferences, ChildReferenceCount, ChildReferenceCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        LoadReferenceTree = 0
        Exit Function
    End If
    If EqualsFolded(ReferencedProject.Kind, "Library") = 0 Then
        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3026", ManifestPath, 1, 1, "Reference target must be a Library project")
        LoadReferenceTree = 0
        Exit Function
    End If
    If ResourceBytes > LimitCombinedResourceBytes() - ReferencedProject.ResourceBytes Then
        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3049", ManifestPath, 1, 1, "combined reference-graph resources exceed the 67108864-byte limit")
        LoadReferenceTree = 0
        Exit Function
    End If
    If ReferencedProject.ResourceCount > 0 Then
        If StringLength(ResourceLengths) > 0 Then
            ResourceLengths = ResourceLengths & ", "
        End If
        ResourceLengths = ResourceLengths & ReferencedProject.ResourceLengths
        ResourceData = ResourceData & ReferencedProject.ResourceData
        ResourceCount = ResourceCount + ReferencedProject.ResourceCount
        ResourceBytes = ResourceBytes + ReferencedProject.ResourceBytes
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
        If LoadReferenceTree(ChildReferences(ReferenceIndex), TargetTriple, Depth + 1, SourcePaths, SourceDepths, SourceCount, SourceCapacity, SeenPaths, SeenStates, SeenCount, SeenCapacity, ResourceData, ResourceLengths, ResourceCount, ResourceBytes, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
            LoadReferenceTree = 0
            Exit Function
        End If
        ReferenceIndex = ReferenceIndex + 1
    Wend
    SeenStates(SeenIndex) = 2
    LoadReferenceTree = 1
End Function

Function ExpandProjectReferences(ByVal RootManifest As String, ByVal TargetTriple As String, ByRef ReferencePaths() As String, ByVal ReferenceCount As Long, ByRef SourcePaths() As String, ByRef SourceDepths() As Long, ByRef SourceCount As Long, ByRef SourceCapacity As Long, ByRef ResourceData As String, ByRef ResourceLengths As String, ByRef ResourceCount As Long, ByRef ResourceBytes As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
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
        If LoadReferenceTree(ReferencePaths(Index), TargetTriple, 1, SourcePaths, SourceDepths, SourceCount, SourceCapacity, SeenPaths, SeenStates, SeenCount, SeenCapacity, ResourceData, ResourceLengths, ResourceCount, ResourceBytes, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
            ExpandProjectReferences = 0
            Exit Function
        End If
        Index = Index + 1
    Wend
    SeenStates(0) = 2
    ExpandProjectReferences = 1
End Function

Function RunNativeCompilerDriver(ByVal ManifestPath As String, ByVal TargetTriple As String, ByVal ClangPath As String, ByVal RuntimeObjectPath As String, ByVal UnicodeRuntimeObjectPath As String, ByVal OutputPath As String, ByVal IntermediateIrPath As String, ByVal RequestedJobs As Long, ByVal FaultSite As String) As Long
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
    If RunCompilerDriver(ManifestPath, TargetTriple, 5, IntermediateIrPath, "", RequestedJobs, FaultSite) <> 0 Then
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
    If LoadProjectManifest(ManifestPath, TargetTriple, NativeProject, NativeSources, NativeSourceCount, NativeSourceCapacity, NativeReferences, NativeReferenceCount, NativeReferenceCapacity, NativeDiagnostics, NativeDiagnosticCount, NativeDiagnosticCapacity) = 0 Then
        CleanupStatus = CompilerDeleteFile(IntermediateIrPath)
        Call ReportDriverFailure("native project manifest", NativeDiagnostics, NativeDiagnosticCount, NativeDiagnosticCapacity)
        RunNativeCompilerDriver = 1
        Exit Function
    End If
    Dim ToolArguments() As String
    Dim ToolArgumentCount As Long = 8
    Dim OptimizationFlag As String = "-O2"
    If EqualsFolded(NativeProject.Optimization, "Size") <> 0 Then
        OptimizationFlag = "-Os"
    Else
        OptimizationFlag = "-O" & NativeProject.Optimization
    End If
    Dim DebugFlag As String = "-g"
    If EqualsFolded(NativeProject.DebugInformation, "None") <> 0 Then
        DebugFlag = "-g0"
    Else
        If EqualsFolded(NativeProject.DebugInformation, "Line") <> 0 Then
            DebugFlag = "-gline-tables-only"
        End If
    End If
    If EqualsFolded(NativeProject.Kind, "Library") <> 0 Then
        ReDim ToolArguments(8)
        ToolArguments(0) = "--target=" & TargetTriple
        ToolArguments(1) = OptimizationFlag
        ToolArguments(2) = DebugFlag
        ToolArguments(3) = "-shared"
        ToolArguments(4) = IntermediateIrPath
        ToolArguments(5) = RuntimeObjectPath
        ToolArguments(6) = UnicodeRuntimeObjectPath
        ToolArguments(7) = "-o"
        ToolArguments(8) = OutputPath
        ToolArgumentCount = 9
    Else
        ReDim ToolArguments(7)
        ToolArguments(0) = "--target=" & TargetTriple
        ToolArguments(1) = OptimizationFlag
        ToolArguments(2) = DebugFlag
        ToolArguments(3) = IntermediateIrPath
        ToolArguments(4) = RuntimeObjectPath
        ToolArguments(5) = UnicodeRuntimeObjectPath
        ToolArguments(6) = "-o"
        ToolArguments(7) = OutputPath
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

Function RunCompilerDriver(ByVal ManifestPath As String, ByVal TargetTriple As String, ByVal OutputMode As Long, ByVal OutputPath As String, ByVal ProfilePath As String, ByVal RequestedJobs As Long, ByVal FaultSite As String) As Long
    Dim Performance As CompilerPerformanceProfile
    Dim ProfileEnabled As Long = 0
    If StringLength(ProfilePath) > 0 Then
        ProfileEnabled = 1
    End If
    Call BeginPerformanceProfile(Performance, ProfileEnabled, RequestedJobs)
    Dim ProfilePhaseStart As Long = BeginProfilePhase(Performance)
    Dim Diagnostics() As CompilerDiagnostic
    Dim DiagnosticCount As Long = 0
    Dim DiagnosticCapacity As Long = 0
    If ProfileEnabled <> 0 Then
        If EqualsFolded(ProfilePath, OutputPath) <> 0 Then
            Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE5115", ProfilePath, 1, 1, "performance profile path must differ from the LLVM output path")
            Call ReportDriverFailure("performance profile path", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            RunCompilerDriver = 1
            Exit Function
        End If
        If CompilerDeleteFile(ProfilePath) <> 0 Then
            Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE5115", ProfilePath, 1, 1, "cannot remove the previous compiler performance profile")
            Call ReportDriverFailure("performance profile cleanup", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            RunCompilerDriver = 1
            Exit Function
        End If
    End If
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
    If LoadProjectManifest(ManifestPath, TargetTriple, Project, SourcePaths, SourceCount, SourceCapacity, ReferencePaths, ReferenceCount, ReferenceCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        Call ReportDriverFailure("project manifest", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        RunCompilerDriver = 1
        Exit Function
    End If
    Dim SourceDepths() As Long
    ReDim SourceDepths(SourceCapacity - 1)
    Dim ResourceData As String = Project.ResourceData
    Dim ResourceLengths As String = Project.ResourceLengths
    Dim ResourceCount As Long = Project.ResourceCount
    Dim ResourceBytes As Long = Project.ResourceBytes
    If ExpandProjectReferences(ManifestPath, TargetTriple, ReferencePaths, ReferenceCount, SourcePaths, SourceDepths, SourceCount, SourceCapacity, ResourceData, ResourceLengths, ResourceCount, ResourceBytes, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        Call ReportDriverFailure("project references", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        RunCompilerDriver = 1
        Exit Function
    End If
    Performance.ProjectMilliseconds = EndProfilePhase(Performance, ProfilePhaseStart)

    ProfilePhaseStart = BeginProfilePhase(Performance)
    Dim Sources() As SourceDocument
    If LoadProjectSources(SourcePaths, SourceCount, Sources, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        Call ReportDriverFailure("source loading", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        RunCompilerDriver = 1
        Exit Function
    End If
    Performance.SourceLoadMilliseconds = EndProfilePhase(Performance, ProfilePhaseStart)
    Performance.SourceCount = SourceCount
    Dim SourceIndex As Long = 0
    While SourceIndex < SourceCount
        Sources(SourceIndex).ReferenceDepth = SourceDepths(SourceIndex)
        Performance.SourceBytes = Performance.SourceBytes + Sources(SourceIndex).ByteLength
        SourceIndex = SourceIndex + 1
    Wend

    ProfilePhaseStart = BeginProfilePhase(Performance)
    Dim Envelopes() As SourceEnvelopeInfo
    If ValidateSourceEnvelopes(Sources, SourceCount, Envelopes, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        Call ReportDriverFailure("source envelopes", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        RunCompilerDriver = 1
        Exit Function
    End If
    Performance.EnvelopeMilliseconds = EndProfilePhase(Performance, ProfilePhaseStart)

    Dim Tokens() As LexicalToken
    Dim TokenCount As Long = 0
    Dim TokenCapacity As Long = 0
    Dim GrammarRules() As GrammarRule
    Dim GrammarRuleCount As Long = 0
    Dim GrammarNodes() As GrammarExpression
    Dim GrammarNodeCount As Long = 0
    Dim GrammarLinks() As GrammarChildLink
    Dim GrammarLinkCount As Long = 0
    Dim SyntaxNodes() As SyntaxNode
    Dim SyntaxNodeCount As Long = 0
    Dim SyntaxNodeCapacity As Long = 0
    Dim SyntaxLinks() As SyntaxChildLink
    Dim SyntaxLinkCount As Long = 0
    Dim SyntaxLinkCapacity As Long = 0
    Dim FailedFrontendPhase As Long = 0
    If RunCompilerFrontend(Sources, SourceCount, OutputMode, RequestedJobs, FaultSite, Tokens, TokenCount, TokenCapacity, GrammarRules, GrammarRuleCount, GrammarNodes, GrammarNodeCount, GrammarLinks, GrammarLinkCount, SyntaxNodes, SyntaxNodeCount, SyntaxNodeCapacity, SyntaxLinks, SyntaxLinkCount, SyntaxLinkCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity, Performance, FailedFrontendPhase) = 0 Then
        If FailedFrontendPhase = 1 Then
            Call ReportDriverFailure("preprocessing or lexing", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        Else
            If FailedFrontendPhase = 2 Then
                Call ReportDriverFailure("grammar model", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Else
                Call ReportDriverFailure("syntax parsing", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            End If
        End If
        RunCompilerDriver = 1
        Exit Function
    End If
    Performance.TokenCount = TokenCount
    Performance.SyntaxNodeCount = SyntaxNodeCount

    If OutputMode = 1 Then
        Call WriteTokenDump(Tokens, TokenCount)
        RunCompilerDriver = 0
        Exit Function
    End If

    If OutputMode = 2 Then
        Call WriteSyntaxDump(SyntaxNodes, SyntaxNodeCount, GrammarRules, Tokens, GrammarRuleCount)
        RunCompilerDriver = 0
        Exit Function
    End If

    ProfilePhaseStart = BeginProfilePhase(Performance)
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
    Dim SemanticEffectiveJobs As Long = 1
    Call RunCompilerSemantics(Project, Sources, SourceCount, Envelopes, Tokens, TokenCount, SyntaxNodes, SyntaxNodeCount, SyntaxLinks, SyntaxLinkCount, GrammarRules, GrammarRuleCount, SemanticStateValue, SemanticTypes, SemanticTypeCount, SemanticTypeCapacity, SemanticScopes, SemanticScopeCount, SemanticScopeCapacity, SemanticSymbols, SemanticSymbolCount, SemanticSymbolCapacity, SemanticLinks, SemanticLinkCount, SemanticLinkCapacity, SemanticExpressions, SemanticExpressionCount, SemanticExpressionCapacity, SemanticBindings, SemanticBindingCount, SemanticBindingCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity, RequestedJobs, FaultSite, SemanticEffectiveJobs)
    If SemanticEffectiveJobs > Performance.EffectiveJobs Then
        Performance.EffectiveJobs = SemanticEffectiveJobs
    End If
    If SemanticEffectiveJobs > 1 Then
        Performance.ExecutionParallel = 1
    End If
    Call ValidateRp8Closure(Sources, SyntaxNodes, SyntaxNodeCount, SyntaxLinks, GrammarRules, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
    If DiagnosticCount <> 0 Then
        Call ReportDriverFailure("semantic analysis", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        RunCompilerDriver = 1
        Exit Function
    End If
    Performance.SemanticsMilliseconds = EndProfilePhase(Performance, ProfilePhaseStart)
    Performance.SemanticTypeCount = SemanticTypeCount
    Performance.SemanticScopeCount = SemanticScopeCount
    Performance.SemanticSymbolCount = SemanticSymbolCount
    Performance.SemanticExpressionCount = SemanticExpressionCount

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
        ProfilePhaseStart = BeginProfilePhase(Performance)
        If LowerSemanticProgramToIr(SemanticStateValue, SemanticTypes, SemanticTypeCount, SemanticSymbols, SemanticSymbolCount, SemanticExpressions, SemanticExpressionCount, SemanticBindings, SemanticBindingCount, SyntaxNodes, GrammarRules, Tokens, IrProgramValue, IrGlobals, IrFunctions, IrParameters, IrStorages, IrBlocks, IrInstructions, IrOperands, IrValues, IrEdges, IrCleanups, IrLocations, IrBuild, Performance.Enabled, Performance.IrLowerSetupMilliseconds, Performance.IrLowerBodyMilliseconds, Performance.IrLowerFinalizeMilliseconds, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
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
        Performance.IrLowerMilliseconds = EndProfilePhase(Performance, ProfilePhaseStart)
        Performance.IrGlobalCount = IrBuild.GlobalCount
        Performance.IrFunctionCount = IrBuild.FunctionCount
        Performance.IrBlockCount = IrBuild.BlockCount
        Performance.IrInstructionCount = IrBuild.InstructionCount
        Performance.IrOperandCount = IrBuild.OperandCount
        Performance.IrValueCount = IrBuild.ValueCount
        Performance.IrEdgeCount = IrBuild.EdgeCount
        Performance.IrCleanupCount = IrBuild.CleanupCount
        Performance.IrLocationCount = IrBuild.LocationCount
        ProfilePhaseStart = BeginProfilePhase(Performance)
        If VerifyProgramIr(IrProgramValue, IrGlobals, IrBuild.GlobalCount, IrFunctions, IrBuild.FunctionCount, IrParameters, IrBuild.ParameterCount, IrStorages, IrBuild.StorageCount, IrBlocks, IrBuild.BlockCount, IrInstructions, IrBuild.InstructionCount, IrOperands, IrBuild.OperandCount, IrValues, IrBuild.ValueCount, IrEdges, IrBuild.EdgeCount, IrCleanups, IrBuild.CleanupCount, IrLocations, IrBuild.LocationCount, SemanticTypes, SemanticTypeCount, Performance.IrVerifyEdgeProbeCount, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
            Call ReportDriverFailure("IR verification", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            RunCompilerDriver = 1
            Exit Function
        End If
        Performance.IrVerifyMilliseconds = EndProfilePhase(Performance, ProfilePhaseStart)
        ProfilePhaseStart = BeginProfilePhase(Performance)
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
        Performance.ManagedMilliseconds = EndProfilePhase(Performance, ProfilePhaseStart)
        If OutputMode = 4 Then
            Call WriteIrDump(IrProgramValue, IrGlobals, IrBuild.GlobalCount, IrFunctions, IrBuild.FunctionCount, IrParameters, IrBuild.ParameterCount, IrStorages, IrBuild.StorageCount, IrBlocks, IrBuild.BlockCount, IrInstructions, IrBuild.InstructionCount, IrOperands, IrBuild.OperandCount, IrValues, IrBuild.ValueCount, IrEdges, IrBuild.EdgeCount, IrCleanups, IrBuild.CleanupCount, IrLocations, IrBuild.LocationCount)
        Else
            If OutputMode = 6 Then
                Call WriteManagedDump(ManagedMetadataValue, ManagedLayouts, ManagedSlots, ManagedRoots, ManagedSafePoints, ManagedBarriers, ManagedPins, ManagedFinalizers)
            Else
                ProfilePhaseStart = BeginProfilePhase(Performance)
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
            If EmitVerifiedIrToLlvm(Target, TargetAbi, SemanticTypes, SemanticTypeCount, SemanticSymbols, SemanticSymbolCount, IrProgramValue, IrGlobals, IrBuild.GlobalCount, IrFunctions, IrBuild.FunctionCount, IrParameters, IrBuild.ParameterCount, IrStorages, IrBuild.StorageCount, IrBlocks, IrInstructions, IrBuild.InstructionCount, IrOperands, IrValues, IrBuild.ValueCount, IrCleanups, IrBuild.CleanupCount, IrLocations, IrBuild.LocationCount, ManagedMetadataValue, ManagedLayouts, ManagedSlots, ManagedRoots, ManagedSafePoints, ManagedBarriers, Performance.LlvmInstructionVisitCount, LlvmChunks, LlvmChunkCount, LlvmChunkCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
                Call ReportDriverFailure("LLVM emission", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                RunCompilerDriver = 1
                Exit Function
            End If
            If AppendLlvmResources(ResourceCount, ResourceLengths, ResourceData, ResourceBytes, LlvmChunks, LlvmChunkCount, LlvmChunkCapacity) = 0 Then
                Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE5114", OutputPath, 1, 1, "resource LLVM emission exceeded a configured bound")
                Call ReportDriverFailure("resource LLVM emission", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                RunCompilerDriver = 1
                Exit Function
            End If
                Dim LlvmText As String = StringArrayJoin(LlvmChunks, LlvmChunkCount)
                LlvmText = FilterLlvmDebugInformation(LlvmText, Project.DebugInformation)
                If StringLength(LlvmText) > LimitGeneratedBytes() Then
                Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE5102", OutputPath, 1, 1, "generated LLVM exceeds the configured output limit")
                Call ReportDriverFailure("LLVM output size", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                RunCompilerDriver = 1
                Exit Function
                End If
                Performance.GeneratedBytes = StringLength(LlvmText)
                Performance.LlvmMilliseconds = EndProfilePhase(Performance, ProfilePhaseStart)
                ProfilePhaseStart = BeginProfilePhase(Performance)
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
                Performance.OutputWriteMilliseconds = EndProfilePhase(Performance, ProfilePhaseStart)
                If Performance.Enabled <> 0 Then
                    Call CompletePerformanceProfile(Performance)
                    If WritePerformanceProfile(ProfilePath, Performance) <> 0 Then
                        Dim ProfileOutputCleanup As Long = CompilerDeleteFile(OutputPath)
                        ProfileOutputCleanup = CompilerDeleteFile(OutputPath & ".h")
                        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE5115", ProfilePath, 1, 1, "cannot atomically write compiler performance profile")
                        Call ReportDriverFailure("performance profile write", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        RunCompilerDriver = 1
                        Exit Function
                    End If
                End If
            End If
        End If
        RunCompilerDriver = 0
        Exit Function
    End If

    Print "UBE Compiler v3 RP8: project " & Project.ProjectName & " (" & Project.Kind & "), " & LongToString(Project.SourceCount) & " source(s), " & LongToString(TokenCount) & " token(s), " & LongToString(SyntaxNodeCount) & " syntax node(s), " & LongToString(SemanticSymbolCount) & " symbol(s), host " & Host.Id & ", target " & Target.Triple
    RunCompilerDriver = 0
End Function
