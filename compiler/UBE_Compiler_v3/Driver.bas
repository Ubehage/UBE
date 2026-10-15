Function RunCompilerDriver(ByVal ManifestPath As String, ByVal TargetTriple As String) As Long
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

    Print "UBE Compiler v3 RP1: project " & Project.Name & " (" & Project.Kind & "), " & LongToString(Project.SourceCount) & " source(s), host " & Host.Id & ", target " & Target.Triple
    RunCompilerDriver = 0
End Function
