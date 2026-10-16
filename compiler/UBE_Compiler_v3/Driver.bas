UBE SOURCE 1 MODULE
Attribute UBE_Name = "Driver"

Function RunCompilerDriver(ByVal ManifestPath As String, ByVal TargetTriple As String, ByVal DumpTokens As Long) As Long
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

    If DumpTokens <> 0 Then
        Call WriteTokenDump(Tokens, TokenCount)
        RunCompilerDriver = 0
        Exit Function
    End If

    Print "UBE Compiler v3 RP2: project " & Project.Name & " (" & Project.Kind & "), " & LongToString(Project.SourceCount) & " source(s), " & LongToString(TokenCount) & " token(s), host " & Host.Id & ", target " & Target.Triple
    RunCompilerDriver = 0
End Function
