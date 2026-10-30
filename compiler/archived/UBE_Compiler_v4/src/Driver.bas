UBE SOURCE 1 MODULE
Attribute UBE_Name = "Driver"

Function BuildShellRecord(ByVal Session As BuildSession, ByVal FinalResult As ShellPhaseResult, ByRef RecordText As String) As Long
    RecordText = ""
    If AppendRecordField(RecordText, "format", "UBE-v4-shell-record-1", 4096) = 0 Then BuildShellRecord = 0: Exit Function
    If AppendRecordField(RecordText, "session", "1", 4096) = 0 Then BuildShellRecord = 0: Exit Function
    If AppendRecordField(RecordText, "project", Session.ProjectPath, 4096) = 0 Then BuildShellRecord = 0: Exit Function
    If AppendRecordField(RecordText, "target", Session.TargetTriple, 4096) = 0 Then BuildShellRecord = 0: Exit Function
    If AppendRecordField(RecordText, "jobs", "1", 4096) = 0 Then BuildShellRecord = 0: Exit Function
    If AppendRecordField(RecordText, "phases", "load,frontend,tool", 4096) = 0 Then BuildShellRecord = 0: Exit Function
    If AppendRecordField(RecordText, "work-units", "3", 4096) = 0 Then BuildShellRecord = 0: Exit Function
    If AppendRecordField(RecordText, "last-phase", FinalResult.Payload, 4096) = 0 Then BuildShellRecord = 0: Exit Function
    If AppendRecordField(RecordText, "status", "passed", 4096) = 0 Then BuildShellRecord = 0: Exit Function
    BuildShellRecord = 1
End Function

Function RunCompilerSession(ByVal Session As BuildSession) As Long
    Dim Diagnostics() As CompilerDiagnostic
    Dim DiagnosticCount As Long = 0
    Dim DiagnosticCapacity As Long = 0
    Dim Token As CancellationToken
    Call InitializeCancellation(Token)
    Dim LoadResult As ShellPhaseResult
    Dim FrontendResult As ShellPhaseResult
    Dim ToolResult As ShellPhaseResult
    Dim Status As Long = 1

    If Session.PublishRecord <> 0 Then
        If RemoveCompilerArtifact(Session.OutputPath) <> 0 Then
            Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE6008", Session.OutputPath, "could not remove the previous output artifact")
            Call ReportCompilerDiagnostics(Diagnostics, DiagnosticCount)
            RunCompilerSession = 1
            Exit Function
        End If
    End If
    If RunFakeLoadPhase(Session, Token, LoadResult, Diagnostics, DiagnosticCount, DiagnosticCapacity) <> 0 Then
        If Session.FaultSite = "cancel" Then Call RequestCancellation(Token)
        If RunFakeFrontendPhase(Session, Token, LoadResult, FrontendResult, Diagnostics, DiagnosticCount, DiagnosticCapacity) <> 0 Then
            If RunFakeToolPhase(Session, Token, FrontendResult, ToolResult, Diagnostics, DiagnosticCount, DiagnosticCapacity) <> 0 Then
                Status = 0
            End If
        End If
    End If

    If Status = 0 And Session.PublishRecord <> 0 Then
        Dim RecordText As String = ""
        If BuildShellRecord(Session, ToolResult, RecordText) = 0 Then
            Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE6005", Session.OutputPath, "shell record allocation or validation failed")
            Status = 1
        Else
            If Session.FaultSite = "write" Then
                Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE6007", Session.OutputPath, "injected output publication failure")
                Status = 1
            Else
                If PublishCompilerText(Session.OutputPath, RecordText) <> 0 Then
                    Status = 1
                End If
            End If
        End If
    End If

    If Status <> 0 And Session.PublishRecord <> 0 Then
        Call RemoveCompilerArtifact(Session.OutputPath)
    End If
    Call ReleaseShellPhaseResult(ToolResult)
    Call ReleaseShellPhaseResult(FrontendResult)
    Call ReleaseShellPhaseResult(LoadResult)
    If ToolResult.LiveResources <> 0 Or FrontendResult.LiveResources <> 0 Or LoadResult.LiveResources <> 0 Then
        Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE6011", Session.ProjectPath, "phase cleanup left a live resource")
        Status = 1
    End If
    If DiagnosticCount > 0 Then Call ReportCompilerDiagnostics(Diagnostics, DiagnosticCount)
    If Status = 0 And Session.PublishRecord = 0 Then
        Print "UBE Compiler v4 shell: accepted " & Session.ProjectPath & " for " & Session.TargetTriple
    End If
    RunCompilerSession = Status
End Function
