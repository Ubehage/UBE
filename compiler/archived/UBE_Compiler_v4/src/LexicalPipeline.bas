UBE SOURCE 1 MODULE
Attribute UBE_Name = "LexicalPipeline"

Function RunTokenDump(ByVal Session As BuildSession) As Long
    Dim Diagnostics() As CompilerDiagnostic
    Dim DiagnosticCount As Long = 0
    Dim DiagnosticCapacity As Long = 0
    Dim Sources() As ImmutableSourceSnapshot
    Dim ProjectResult As ProjectSourceSetResult
    Dim Tokens() As FullLexicalToken
    Dim TokenCount As Long = 0
    Dim TokenCapacity As Long = 0
    Dim Status As Long = 1
    If RunProjectSourcePhase(Session, Sources, ProjectResult, Diagnostics, DiagnosticCount, DiagnosticCapacity) <> 0 Then
        Dim SourceIndex As Long = 0
        Dim AllSucceeded As Long = 1
        While SourceIndex < ProjectResult.SourceCount And AllSucceeded <> 0
            Dim Preprocessed As PreprocessedSource
            If RunPreprocessorForSource(Session, Sources(SourceIndex), Preprocessed, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
                AllSucceeded = 0
            Else
                If RunFullLexerForSource(Session, Sources(SourceIndex), Preprocessed, Tokens, TokenCount, TokenCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then AllSucceeded = 0
            End If
            Preprocessed.ProcessedText = ""
            SourceIndex = SourceIndex + 1
        Wend
        If AllSucceeded <> 0 Then
            Dim Dump As String = ""
            If BuildFullTokenDump(Tokens, TokenCount, Dump) <> 0 Then
                Print Dump;
                Status = 0
            Else
                Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3406", Session.ProjectPath, "token dump exceeds the artifact limit")
            End If
        End If
    End If
    If DiagnosticCount > 0 Then Call ReportCompilerDiagnostics(Diagnostics, DiagnosticCount)
    Dim CleanupIndex As Long = 0
    While CleanupIndex < ProjectResult.SourceCount
        Sources(CleanupIndex).Contents = ""
        CleanupIndex = CleanupIndex + 1
    Wend
    RunTokenDump = Status
End Function
