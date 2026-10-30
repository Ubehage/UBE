UBE SOURCE 1 MODULE
Attribute UBE_Name = "SourcePhase"

Type SourceSetResult
    Succeeded As Long
    ProjectId As Long
    SourceId As Long
    ProjectPath As String
    SourcePath As String
    SourceBytes As String
    ByteCount As Long
    WorkUnits As LongLong
    Dump As String
End Type

Sub ReleaseSourceSet(ByRef Result As SourceSetResult)
    Result.Succeeded = 0
    Result.SourceBytes = ""
    Result.Dump = ""
End Sub

Function ValidateSourceSet(ByVal Result As SourceSetResult) As Long
    If Result.Succeeded = 0 Or Result.ProjectId <> 1 Or Result.SourceId <> 1 Then ValidateSourceSet = 0: Exit Function
    If Result.SourcePath = "" Or Result.ByteCount <= 0 Then ValidateSourceSet = 0: Exit Function
    If Result.ByteCount <> CompilerTextLength(Result.SourceBytes) Then ValidateSourceSet = 0: Exit Function
    ValidateSourceSet = 1
End Function

Function RunSourcePhase(ByVal Session As BuildSession, ByRef Result As SourceSetResult, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Call ReleaseSourceSet(Result)
    Dim Manifest As String = ""
    If ReadRequiredCompilerText(Session.ProjectPath, Manifest) = 0 Then
        Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE6100", Session.ProjectPath, "project manifest is empty or unreadable")
        RunSourcePhase = 0
        Exit Function
    End If
    Dim Cursor As Long = 0
    Dim ManifestLine As String = ""
    Dim LineStart As Long = 0
    Dim RelativePath As String = ""
    While ReadCompilerLine(Manifest, Cursor, ManifestLine, LineStart) <> 0
        If CompilerTextMatchesAt(ManifestLine, 0, "Source = " & CompilerTextFromByte(34)) <> 0 Then
            If RelativePath <> "" Or CompilerTextLength(ManifestLine) < 12 Or CompilerTextByteAt(ManifestLine, CompilerTextLength(ManifestLine) - 1) <> 34 Then
                Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE6100", Session.ProjectPath, "Task 3 requires exactly one quoted Source entry")
                RunSourcePhase = 0
                Exit Function
            End If
            If CompilerTextSlice(ManifestLine, 10, CompilerTextLength(ManifestLine) - 11, RelativePath) = 0 Then RelativePath = ""
        End If
    Wend
    Dim Normalized As String = ""
    If RelativePath = "" Or NormalizeCompilerRelativePath(RelativePath, Normalized) = 0 Then
        Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE6100", Session.ProjectPath, "Task 3 requires one valid relative Source entry")
        RunSourcePhase = 0
        Exit Function
    End If
    Result.SourcePath = CompilerPathPrefix(Session.ProjectPath) & Normalized
    If ReadRequiredCompilerText(Result.SourcePath, Result.SourceBytes) = 0 Then
        Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE6100", Result.SourcePath, "source is empty or unreadable")
        RunSourcePhase = 0
        Exit Function
    End If
    Result.ByteCount = CompilerTextLength(Result.SourceBytes)
    If Result.ByteCount > Session.MaximumSourceBytes Then
        Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE6100", Result.SourcePath, "source exceeds the session byte limit")
        RunSourcePhase = 0
        Exit Function
    End If
    Result.ProjectId = 1
    Result.SourceId = 1
    Result.ProjectPath = Session.ProjectPath
    Result.WorkUnits = Result.ByteCount
    Result.Succeeded = 1
    Call AppendPhaseField(Result.Dump, "phase", "source")
    Call AppendPhaseField(Result.Dump, "source-id", "1")
    Call AppendPhaseField(Result.Dump, "path", Result.SourcePath)
    Call AppendPhaseField(Result.Dump, "bytes", CompilerLongToText(Result.ByteCount))
    If Session.FaultSite = "source-envelope" Then Result.SourceId = 0
    If ValidateSourceSet(Result) = 0 Then
        Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE6108", Result.SourcePath, "source phase published an invalid envelope")
        RunSourcePhase = 0
        Exit Function
    End If
    RunSourcePhase = 1
End Function
