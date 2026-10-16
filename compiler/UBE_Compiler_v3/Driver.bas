UBE SOURCE 1 MODULE
Attribute UBE_Name = "Driver"

Function RunCompilerDriver(ByVal ManifestPath As String, ByVal TargetTriple As String, ByVal OutputMode As Long) As Long
    Dim Diagnostics() As CompilerDiagnostic
    Dim DiagnosticCount As Long = 0
    Dim DiagnosticCapacity As Long = 0
    Dim Target As TargetDescription
    Dim Host As HostDescription
    Call ResolveBootstrapHost(Host)
    If ResolveTarget(TargetTriple, Target, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        Call ReportDiagnostics(Diagnostics, DiagnosticCount)
        RunCompilerDriver = 1
        Exit Function
    End If

    Dim Project As ProjectDescription
    Dim SourcePaths() As String
    Dim SourceCount As Long = 0
    Dim SourceCapacity As Long = 0
    If LoadProjectManifest(ManifestPath, Project, SourcePaths, SourceCount, SourceCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        Call ReportDiagnostics(Diagnostics, DiagnosticCount)
        RunCompilerDriver = 1
        Exit Function
    End If

    Dim Sources() As SourceDocument
    If LoadProjectSources(SourcePaths, SourceCount, Sources, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        Call ReportDiagnostics(Diagnostics, DiagnosticCount)
        RunCompilerDriver = 1
        Exit Function
    End If

    Dim Envelopes() As SourceEnvelopeInfo
    If ValidateSourceEnvelopes(Sources, SourceCount, Envelopes, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        Call ReportDiagnostics(Diagnostics, DiagnosticCount)
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
        Call ReportDiagnostics(Diagnostics, DiagnosticCount)
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
        Call ReportDiagnostics(Diagnostics, DiagnosticCount)
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
        Call ReportDiagnostics(Diagnostics, DiagnosticCount)
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
    Call AnalyzeSemantics(Project, Sources, SourceCount, Envelopes, Tokens, SyntaxNodes, SyntaxNodeCount, SyntaxLinks, GrammarRules, SemanticStateValue, SemanticTypes, SemanticTypeCount, SemanticTypeCapacity, SemanticScopes, SemanticScopeCount, SemanticScopeCapacity, SemanticSymbols, SemanticSymbolCount, SemanticSymbolCapacity, SemanticLinks, SemanticLinkCount, SemanticLinkCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity)
    If DiagnosticCount <> 0 Then
        Call ReportDiagnostics(Diagnostics, DiagnosticCount)
        RunCompilerDriver = 1
        Exit Function
    End If

    If OutputMode = 3 Then
        Call WriteSemanticDump(SemanticStateValue, SemanticTypes, SemanticTypeCount, SemanticScopes, SemanticScopeCount, SemanticSymbols, SemanticSymbolCount)
        RunCompilerDriver = 0
        Exit Function
    End If

    Print "UBE Compiler v3 RP4: project " & Project.ProjectName & " (" & Project.Kind & "), " & LongToString(Project.SourceCount) & " source(s), " & LongToString(TokenCount) & " token(s), " & LongToString(SyntaxNodeCount) & " syntax node(s), " & LongToString(SemanticSymbolCount) & " symbol(s), host " & Host.Id & ", target " & Target.Triple
    RunCompilerDriver = 0
End Function
