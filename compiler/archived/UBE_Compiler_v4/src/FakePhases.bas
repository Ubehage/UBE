UBE SOURCE 1 MODULE
Attribute UBE_Name = "FakePhases"

Type ShellPhaseResult
    Succeeded As Long
    Cancelled As Long
    Payload As String
    WorkUnits As LongLong
    LiveResources As Long
End Type

' Clears every owned field. Task 2 phases acquire no persistent native handle;
' LiveResources exists so failure paths prove that invariant explicitly.
Sub ReleaseShellPhaseResult(ByRef Result As ShellPhaseResult)
    Result.Succeeded = 0
    Result.Cancelled = 0
    Result.Payload = ""
    Result.WorkUnits = 0
    Result.LiveResources = 0
End Sub

Function PhaseCancelled(ByVal Session As BuildSession, ByRef Token As CancellationToken, ByRef Result As ShellPhaseResult, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    If IsCancellationRequested(Token) = 0 Then
        PhaseCancelled = 0
        Exit Function
    End If
    Result.Cancelled = 1
    Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE6004", Session.ProjectPath, "compiler session cancelled")
    PhaseCancelled = 1
End Function

' Fake load phase: reads one required nonempty control file and publishes only
' a bounded private payload. Real project parsing begins in Task 3/4.
Function RunFakeLoadPhase(ByVal Session As BuildSession, ByRef Token As CancellationToken, ByRef Result As ShellPhaseResult, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Call ReleaseShellPhaseResult(Result)
    If PhaseCancelled(Session, Token, Result, Diagnostics, DiagnosticCount, DiagnosticCapacity) <> 0 Then
        RunFakeLoadPhase = 0
        Exit Function
    End If
    If Session.FaultSite = "allocation" Then
        Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE6005", Session.ProjectPath, "injected phase allocation failure")
        RunFakeLoadPhase = 0
        Exit Function
    End If
    Dim Contents As String = ""
    If ReadRequiredCompilerText(Session.ProjectPath, Contents) = 0 Then
        Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE6002", Session.ProjectPath, "project control file is empty or unreadable")
        RunFakeLoadPhase = 0
        Exit Function
    End If
    Dim BoundedContents As String = ""
    If AppendBoundedText(BoundedContents, Contents, Session.MaximumManifestBytes) = 0 Then
        Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE6003", Session.ProjectPath, "project control file exceeds the session byte limit")
        RunFakeLoadPhase = 0
        Exit Function
    End If
    Result.Payload = "loaded"
    Result.WorkUnits = 1
    Result.Succeeded = 1
    RunFakeLoadPhase = 1
End Function

' Fake frontend phase proves envelope validation and failure propagation only.
Function RunFakeFrontendPhase(ByVal Session As BuildSession, ByRef Token As CancellationToken, ByVal InputResult As ShellPhaseResult, ByRef Result As ShellPhaseResult, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Call ReleaseShellPhaseResult(Result)
    If PhaseCancelled(Session, Token, Result, Diagnostics, DiagnosticCount, DiagnosticCapacity) <> 0 Then
        RunFakeFrontendPhase = 0
        Exit Function
    End If
    If InputResult.Succeeded = 0 Or InputResult.Payload <> "loaded" Then
        Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE6009", Session.ProjectPath, "fake frontend received an invalid phase envelope")
        RunFakeFrontendPhase = 0
        Exit Function
    End If
    Result.Payload = "frontend"
    Result.WorkUnits = InputResult.WorkUnits + 1
    Result.Succeeded = 1
    RunFakeFrontendPhase = 1
End Function

' Fake tool phase proves a separate backend/tool failure boundary without
' adding LLVM or launching a real backend before Task 3/9.
Function RunFakeToolPhase(ByVal Session As BuildSession, ByRef Token As CancellationToken, ByVal InputResult As ShellPhaseResult, ByRef Result As ShellPhaseResult, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Call ReleaseShellPhaseResult(Result)
    If PhaseCancelled(Session, Token, Result, Diagnostics, DiagnosticCount, DiagnosticCapacity) <> 0 Then
        RunFakeToolPhase = 0
        Exit Function
    End If
    If InputResult.Succeeded = 0 Or InputResult.Payload <> "frontend" Then
        Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE6010", Session.ProjectPath, "fake tool received an invalid phase envelope")
        RunFakeToolPhase = 0
        Exit Function
    End If
    If Session.FaultSite = "tool" Then
        Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE6006", Session.ProjectPath, "injected tool failure")
        RunFakeToolPhase = 0
        Exit Function
    End If
    Result.Payload = "tool"
    Result.WorkUnits = InputResult.WorkUnits + 1
    Result.Succeeded = 1
    RunFakeToolPhase = 1
End Function
