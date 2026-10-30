UBE SOURCE 1 MODULE
Attribute UBE_Name = "CompilerFrontend"

Function RunCompilerFrontend(ByRef Sources() As SourceDocument, ByVal SourceCount As Long, ByVal OutputMode As Long, ByVal RequestedJobs As Long, ByVal FaultSite As String, ByRef Tokens() As LexicalToken, ByRef TokenCount As Long, ByRef TokenCapacity As Long, ByRef GrammarRules() As GrammarRule, ByRef GrammarRuleCount As Long, ByRef GrammarNodes() As GrammarExpression, ByRef GrammarNodeCount As Long, ByRef GrammarLinks() As GrammarChildLink, ByRef GrammarLinkCount As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef SyntaxNodeCount As Long, ByRef SyntaxNodeCapacity As Long, ByRef SyntaxLinks() As SyntaxChildLink, ByRef SyntaxLinkCount As Long, ByRef SyntaxLinkCapacity As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long, ByRef Performance As CompilerPerformanceProfile, ByRef FailedPhase As Long) As Long
    Performance.RequestedJobs = RequestedJobs
    Performance.EffectiveJobs = 1
    Performance.ExecutionParallel = 0
    Dim PhaseStart As Long = BeginProfilePhase(Performance)
    Dim SourceIndex As Long = 0
    While SourceIndex < SourceCount
        Dim PreprocessedText As String = ""
        If PreprocessOneSource(Sources(SourceIndex), PreprocessedText, Diagnostics, DiagnosticCount, DiagnosticCapacity) <> 0 Then
            Call LexOneSource(Sources(SourceIndex), PreprocessedText, Tokens, TokenCount, TokenCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        End If
        SourceIndex = SourceIndex + 1
    Wend
    Performance.FrontEndMilliseconds = EndProfilePhase(Performance, PhaseStart)
    If DiagnosticCount <> 0 Then
        FailedPhase = 1
        RunCompilerFrontend = 0
        Exit Function
    End If
    If OutputMode <> 1 And OutputMode <> 2 Then
        Call ValidateRp8TokenSurface(Sources, Tokens, TokenCount, Diagnostics, DiagnosticCount, DiagnosticCapacity)
    End If
    If DiagnosticCount <> 0 Then
        FailedPhase = 1
        RunCompilerFrontend = 0
        Exit Function
    End If

    PhaseStart = BeginProfilePhase(Performance)
    If LoadGrammarModel(GrammarRules, GrammarRuleCount, GrammarNodes, GrammarNodeCount, GrammarLinks, GrammarLinkCount, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        Performance.GrammarMilliseconds = EndProfilePhase(Performance, PhaseStart)
        FailedPhase = 2
        RunCompilerFrontend = 0
        Exit Function
    End If
    Performance.GrammarMilliseconds = EndProfilePhase(Performance, PhaseStart)
    If OutputMode = 1 Then
        RunCompilerFrontend = 1
        Exit Function
    End If

    PhaseStart = BeginProfilePhase(Performance)
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
    Performance.ParseMilliseconds = EndProfilePhase(Performance, PhaseStart)
    If DiagnosticCount <> 0 Then
        FailedPhase = 3
        RunCompilerFrontend = 0
        Exit Function
    End If
    RunCompilerFrontend = 1
End Function
