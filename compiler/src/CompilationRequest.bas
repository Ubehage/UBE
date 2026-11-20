UBE SOURCE 1 MODULE
Attribute UBE_Name = "CompilationRequest"
' Owns reusable compilation requests and structured diagnostics independently of command rendering.
Public Type RequestResources
    FileToken As Long
    ProcessToken As Long
    StageOwned As Boolean
End Type

Public Type RequestDiagnostic
    Kind As Long
    Operation As Long
    Code As Long
    Reason As Long
    SourceLine As Long
    SourceColumn As Long
End Type

' Releases owned resources in dependency order; failed owners remain visible to the caller.
Public Function TryCleanup(ByRef Resources As RequestResources, ByRef Stage() As Byte, ByRef Ranges() As NativeCompilation.RangeResult, ByRef Failure As Long) As Boolean
    Dim Status As Boolean
    On Error GoTo Failed
    If Not NativeCompilation.TryCleanup(Ranges, Failure) Then Exit Function
    If Resources.ProcessToken <> 0 Then
        If Not NativeBackend.TryStop(Resources.ProcessToken, Failure) Then Exit Function
    End If
    If Resources.FileToken <> 0 Then
        If Not FileBytes.TryClosePreservingError(Resources.FileToken, Failure) Then Exit Function
    End If
    If Resources.StageOwned Then
        If Not OutputPublication.TryDiscard(Stage, Resources.StageOwned, Failure) Then Exit Function
    End If
    TryCleanup = True
    Exit Function
Failed:
    Failure = 1
End Function

' Protects an optional source asset when installed, without requiring it for numeric-only programs.
Private Function ProtectOptional(ByRef Path() As Byte, ByRef Output() As Byte, ByRef Token As Long, ByRef Kind As Long, ByRef Failure As Long) As Boolean
    Dim Same As Boolean
    If Not WindowsPaths.TrySamePath(Path, Output, Same, Failure) Then Exit Function
    If Same Then Failure = 1: Exit Function
    If Not PathPrimitives.TryKind(Path, Kind, Failure) Then Exit Function
    If Kind = 0 Then ProtectOptional = True: Exit Function
    If Kind <> 1 Then Failure = 1: Exit Function
    ProtectOptional = OutputPublication.TryProtectPath(Path, Output, Token, Failure)
End Function

' Enumerates the installed manifest solely for protection; no source declarations enter lookup here.
Private Function ProtectManaged(ByRef Output() As Byte, ByRef Token As Long, ByRef Failure As Long) As Boolean
    Dim ManifestPath() As Byte
    Dim PackageName() As Byte
    Dim Root() As Byte
    Dim Manifest() As Byte
    Dim Relative() As Byte
    Dim Path() As Byte
    Dim Spans() As ProjectManifest.ValueSpan
    Dim Info As ProjectManifest.ManifestInfo
    Dim Diagnostic As ProjectLoader.LoadDiagnostic
    Dim Kind As Long
    Dim Index As Long
    On Error GoTo Failed
    If Not CompilerAssets.TrySupportPath(4, ManifestPath, Failure) Then Exit Function
    If Not ProtectOptional(ManifestPath, Output, Token, Kind, Failure) Then Exit Function
    If Kind = 0 Then ProtectManaged = True: Exit Function
    If Not ProjectLoader.TryLoadManifest(ManifestPath, PackageName, Root, Manifest, Spans, Info, Diagnostic, Token) Then Failure = Diagnostic.Code: Exit Function
    If Info.IsExecutable Then Failure = 1: Exit Function
    Do While Index < Info.SourceCount
        If Not ProjectManifest.TryCopyValue(Manifest, Spans(Index).Start, Spans(Index).Length, Relative) Then Failure = 8: Exit Function
        If Not WindowsPaths.TryResolveSource(Root, Relative, Path, Failure) Then Exit Function
        If Not ProtectOptional(Path, Output, Token, Kind, Failure) Then Exit Function
        Index = Index + 1
    Loop
    ProtectManaged = True
    Exit Function
Failed:
    Failure = 1
End Function

' Protects compiler assets and selected tool executables as well as project inputs.
Private Function ProtectSupport(ByRef Output() As Byte, ByRef Clang() As Byte, ByVal Mode As Long, ByRef Token As Long, ByRef Failure As Long) As Boolean
    Dim Path() As Byte
    Dim Index As Long
    On Error GoTo Failed
    Do While Index < 4
        If Not CompilerAssets.TrySupportPath(Index, Path, Failure) Then Exit Function
        If Not OutputPublication.TryProtectPath(Path, Output, Token, Failure) Then Exit Function
        Index = Index + 1
    Loop
    If Not ProtectManaged(Output, Token, Failure) Then Exit Function
    If Mode = 2 Then
        If Not OutputPublication.TryProtectPath(Clang, Output, Token, Failure) Then Exit Function
        If Not NativeBackend.TryImportTool(Clang, Path, Failure) Then Exit Function
        If Not OutputPublication.TryProtectPath(Path, Output, Token, Failure) Then Exit Function
    End If
    ProtectSupport = True
    Exit Function
Failed:
    Failure = 1
End Function

' Emits into a private stage and closes it before any native invocation or publication.
Private Function TryEmit(ByRef Bytes() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByRef Nodes() As SourceParser.SyntaxNode, ByRef Modules() As ProjectSyntax.ParsedModule, ByRef Counts As ProjectSyntax.ProjectCounts, ByRef PackageName() As Byte, ByVal IsExecutable As Boolean, ByRef Catalog() As Byte, ByRef RuntimeText() As Byte, ByRef Stage() As Byte, ByVal WorkerCount As Long, ByRef Ranges() As NativeCompilation.RangeResult, ByRef Token As Long, ByRef Failure As Long, ByRef Diagnostic As DeclarationBinder.BindingDiagnostic) As Boolean
    Dim State As NativeEmission.EmissionState
    Dim Path() As Byte
    Dim Status As Boolean
    On Error GoTo Failed
    If Not OutputPublication.TryStagePath(Stage, OutputPublication.InputIR, Path, Failure) Then Exit Function
    If Not FilePrimitives.TryCreateNew(Path, Token, Failure) Then Exit Function
    Status = NativeCompilation.TryEmit(Bytes, Tokens, Nodes, Modules, Counts, PackageName, IsExecutable, Catalog, RuntimeText, Stage, WorkerCount, Token, Ranges, State, Diagnostic)
    If Not Status Then
        Failure = Diagnostic.Code
        If Failure = 0 Then Failure = State.Text.Failure
        If Failure = 0 Then Failure = 1
    End If
    If Not FileBytes.TryClosePreservingError(Token, Failure) Then Exit Function
    TryEmit = Status
    Exit Function
Failed:
    Failure = 1
End Function

' Compiles request-owned source facts; resources and private-stage ownership survive failure for cleanup.
Public Function TryCompile(ByRef ManifestPath() As Byte, ByRef RequestedOutput() As Byte, ByRef Clang() As Byte, ByVal Mode As Long, ByVal WorkerCount As Long, ByRef Resources As RequestResources, ByRef Stage() As Byte, ByRef Ranges() As NativeCompilation.RangeResult, ByRef Report As RequestDiagnostic, ByRef DiagnosticPath() As Byte) As Boolean
    Dim Bytes() As Byte
    Dim Tokens() As SourceScanner.SourceToken
    Dim Nodes() As SourceParser.SyntaxNode
    Dim Modules() As ProjectSyntax.ParsedModule
    Dim Paths() As ProjectLoader.SourcePath
    Dim PathBytes() As Byte
    Dim PackageName() As Byte
    Dim SupportPath() As Byte
    Dim Catalog() As Byte
    Dim RuntimeText() As Byte
    Dim ImportDefinition() As Byte
    Dim Output() As Byte
    Dim Counts As ProjectSyntax.ProjectCounts
    Dim Info As ProjectManifest.ManifestInfo
    Dim LoadError As ProjectLoader.LoadDiagnostic
    Dim BindingError As DeclarationBinder.BindingDiagnostic
    Dim Failure As Long
    Dim ExitCode As Long
    Dim Kind As Long
    Dim Operation As Long
    Dim Code As Long
    Dim Reason As Long
    Dim SourceLine As Long
    Dim SourceColumn As Long
    Dim Artifact As Long
    Dim Status As Boolean
    On Error GoTo Failed
    Kind = CompilerMessages.LoadError
    Report.Kind = 0
    Report.Operation = 0
    Report.Code = 0
    Report.Reason = 0
    Report.SourceLine = 0
    Report.SourceColumn = 0
    If WorkerCount < 1 Or WorkerCount > NativeCompilation.MaximumWorkers Then Kind = CompilerMessages.UsageError: Code = 1: GoTo Report
    If Resources.FileToken <> 0 Or Resources.ProcessToken <> 0 Or Resources.StageOwned Then Kind = CompilerMessages.OutputError: Code = 1: GoTo Report
    If Not BufferPrimitives.TryCopyBytes(DiagnosticPath, ManifestPath) Then Code = 8: GoTo Report
    If Not ProjectLoader.TryLoad(ManifestPath, PackageName, PathBytes, Paths, Bytes, Tokens, Nodes, Modules, Counts, Info, LoadError, Resources.FileToken) Then
        Operation = LoadError.Stage
        Code = LoadError.Code
        Reason = LoadError.Reason
        SourceLine = LoadError.Line
        SourceColumn = LoadError.Column
        If LoadError.PathLength > 0 Then Status = ProjectLoader.TryCopyPathSpan(PathBytes, LoadError.PathStart, LoadError.PathLength, DiagnosticPath)
        GoTo Report
    End If
    Kind = CompilerMessages.BackendError
    If Mode = 2 And Not Info.IsExecutable Then Code = 1: Reason = 1: GoTo Report
    Kind = CompilerMessages.AssetError
    If Not CompilerAssets.TryLoad(Catalog, RuntimeText, ImportDefinition, Resources.FileToken, Failure) Then GoTo FailedOperation
    If ManagedSupport.NeedsSource(Bytes, Tokens, Nodes, Counts) Then
        If Not CompilerAssets.TrySupportPath(4, SupportPath, Failure) Then GoTo FailedOperation
        If Not BufferPrimitives.TryCopyBytes(DiagnosticPath, SupportPath) Then Failure = 8: GoTo FailedOperation
        If Not ProjectLoader.TryAppendSupport(SupportPath, PathBytes, Paths, Bytes, Tokens, Nodes, Modules, Counts, LoadError, Resources.FileToken) Then
            Operation = LoadError.Stage
            Code = LoadError.Code
            Reason = LoadError.Reason
            SourceLine = LoadError.Line
            SourceColumn = LoadError.Column
            If LoadError.PathLength > 0 Then Status = ProjectLoader.TryCopyPathSpan(PathBytes, LoadError.PathStart, LoadError.PathLength, DiagnosticPath)
            GoTo Report
        End If
    End If
    Kind = CompilerMessages.OutputError
    If Not BufferPrimitives.TryCopyBytes(DiagnosticPath, RequestedOutput) Then Code = 8: GoTo Report
    If Not OutputPublication.TryPrepare(RequestedOutput, ManifestPath, PathBytes, Paths, Counts.ModuleCount, Output, Stage, Resources.StageOwned, Resources.FileToken, Failure) Then GoTo FailedOperation
    If Not ProtectSupport(Output, Clang, Mode, Resources.FileToken, Failure) Then GoTo FailedOperation
    Kind = CompilerMessages.CompileError
    If Not TryEmit(Bytes, Tokens, Nodes, Modules, Counts, PackageName, Info.IsExecutable, Catalog, RuntimeText, Stage, WorkerCount, Ranges, Resources.FileToken, Failure, BindingError) Then
        Code = BindingError.Code
        If Code = 0 Then Code = Failure
        Reason = BindingError.Reason
        SourceLine = BindingError.Line
        SourceColumn = BindingError.Column
        If BindingError.ModuleIndex >= 0 And BindingError.ModuleIndex < Counts.ModuleCount Then
            Status = ProjectLoader.TryCopyPathSpan(PathBytes, Paths(BindingError.ModuleIndex).Start, Paths(BindingError.ModuleIndex).Length, DiagnosticPath)
        End If
        GoTo Report
    End If
    Artifact = OutputPublication.InputIR
    If Mode = 2 Then
        Kind = CompilerMessages.BackendError
        If Not NativeBackend.TryBuild(Clang, Stage, Info.Optimization, ImportDefinition, Resources.FileToken, Resources.ProcessToken, Failure, ExitCode) Then Reason = ExitCode: GoTo FailedOperation
        Artifact = OutputPublication.Executable
    End If
    Kind = CompilerMessages.PublicationError
    If ThreadPrimitives.StopRequested() Then Code = 1: GoTo Report
    If Not ProtectSupport(Output, Clang, Mode, Resources.FileToken, Failure) Then GoTo FailedOperation
    If Not OutputPublication.TryCommit(ManifestPath, PathBytes, Paths, Counts.ModuleCount, Output, Stage, Resources.StageOwned, Artifact, Resources.FileToken, Failure) Then GoTo FailedOperation
    TryCompile = True
    Exit Function
FailedOperation:
    Code = Failure
Report:
    Report.Kind = Kind
    Report.Operation = Operation
    Report.Code = Code
    Report.Reason = Reason
    Report.SourceLine = SourceLine
    Report.SourceColumn = SourceColumn
    Exit Function
Failed:
    Kind = CompilerMessages.InternalError
    Code = Err.Number
    GoTo Report
End Function

