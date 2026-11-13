UBE SOURCE 1 MODULE
Attribute UBE_Name = "CompilerCommand"
' Owns one command request and connects project loading, checked lowering and guarded publication.

Public Type RequestResources
    FileToken As Long
    ProcessToken As Long
    StageOwned As Boolean
End Type

' Supplies the documented bootstrap backend default; an explicit --clang argument overrides it.
Private Function DefaultClang(ByRef Result() As Byte) As Boolean
    If Not BufferPrimitives.TryResizeBytes(Result, 35, False) Then Exit Function
    Result(0) = 67
    Result(1) = 58
    Result(2) = 92
    Result(3) = 80
    Result(4) = 114
    Result(5) = 111
    Result(6) = 103
    Result(7) = 114
    Result(8) = 97
    Result(9) = 109
    Result(10) = 32
    Result(11) = 70
    Result(12) = 105
    Result(13) = 108
    Result(14) = 101
    Result(15) = 115
    Result(16) = 92
    Result(17) = 76
    Result(18) = 76
    Result(19) = 86
    Result(20) = 77
    Result(21) = 92
    Result(22) = 98
    Result(23) = 105
    Result(24) = 110
    Result(25) = 92
    Result(26) = 99
    Result(27) = 108
    Result(28) = 97
    Result(29) = 110
    Result(30) = 103
    Result(31) = 46
    Result(32) = 101
    Result(33) = 120
    Result(34) = 101
    DefaultClang = True
End Function

' Releases owned resources in dependency order; failed owners remain visible to the caller.
Public Function TryCleanup(ByRef Resources As RequestResources, ByRef Stage() As Byte, ByRef Failure As Long) As Boolean
    Dim Status As Boolean
    On Error GoTo Failed
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
Private Function TryEmit(ByRef Bytes() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByRef Nodes() As SourceParser.SyntaxNode, ByRef Modules() As ProjectSyntax.ParsedModule, ByRef Counts As ProjectSyntax.ProjectCounts, ByRef PackageName() As Byte, ByVal IsExecutable As Boolean, ByRef Catalog() As Byte, ByRef RuntimeText() As Byte, ByRef Stage() As Byte, ByRef Token As Long, ByRef Failure As Long, ByRef Diagnostic As DeclarationBinder.BindingDiagnostic) As Boolean
    Dim State As NativeEmission.EmissionState
    Dim Path() As Byte
    Dim Status As Boolean
    On Error GoTo Failed
    If Not OutputPublication.TryStagePath(Stage, OutputPublication.InputIR, Path, Failure) Then Exit Function
    If Not FilePrimitives.TryCreateNew(Path, Token, Failure) Then Exit Function
    Status = NativeLowering.TryEmit(Bytes, Tokens, Nodes, Modules, Counts, PackageName, IsExecutable, Catalog, RuntimeText, Token, State, Diagnostic)
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
Private Function TryCompile(ByRef ManifestPath() As Byte, ByRef RequestedOutput() As Byte, ByRef Clang() As Byte, ByVal Mode As Long, ByRef Resources As RequestResources, ByRef Stage() As Byte) As Boolean
    Dim Bytes() As Byte
    Dim Tokens() As SourceScanner.SourceToken
    Dim Nodes() As SourceParser.SyntaxNode
    Dim Modules() As ProjectSyntax.ParsedModule
    Dim Paths() As ProjectLoader.SourcePath
    Dim PathBytes() As Byte
    Dim PackageName() As Byte
    Dim Catalog() As Byte
    Dim RuntimeText() As Byte
    Dim ImportDefinition() As Byte
    Dim Output() As Byte
    Dim DiagnosticPath() As Byte
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
    Kind = CompilerMessages.OutputError
    If Not BufferPrimitives.TryCopyBytes(DiagnosticPath, RequestedOutput) Then Code = 8: GoTo Report
    If Not OutputPublication.TryPrepare(RequestedOutput, ManifestPath, PathBytes, Paths, Counts.ModuleCount, Output, Stage, Resources.StageOwned, Resources.FileToken, Failure) Then GoTo FailedOperation
    If Not ProtectSupport(Output, Clang, Mode, Resources.FileToken, Failure) Then GoTo FailedOperation
    Kind = CompilerMessages.CompileError
    If Not TryEmit(Bytes, Tokens, Nodes, Modules, Counts, PackageName, Info.IsExecutable, Catalog, RuntimeText, Stage, Resources.FileToken, Failure, BindingError) Then
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
    If Not ProtectSupport(Output, Clang, Mode, Resources.FileToken, Failure) Then GoTo FailedOperation
    If Not OutputPublication.TryCommit(ManifestPath, PathBytes, Paths, Counts.ModuleCount, Output, Stage, Resources.StageOwned, Artifact, Resources.FileToken, Failure) Then GoTo FailedOperation
    TryCompile = True
    Exit Function
FailedOperation:
    Code = Failure
Report:
    Status = CompilerMessages.TryWriteError(Kind, Operation, Code, Reason, DiagnosticPath, SourceLine, SourceColumn)
    Exit Function
Failed:
    Kind = CompilerMessages.InternalError
    Code = Err.Number
    GoTo Report
End Function

' Decodes the admitted command paths and keeps source-independent request state local.
Private Function TryExecute(ByRef CommandLine() As Byte, ByRef Options As CommandOptions.CommandRequest, ByRef Resources As RequestResources, ByRef Stage() As Byte) As Boolean
    Dim ManifestPath() As Byte
    Dim OutputPath() As Byte
    Dim ClangInput() As Byte
    Dim Clang() As Byte
    Dim Found As Boolean
    Dim Failure As Long
    Dim Status As Boolean
    On Error GoTo Failed
    If Not WindowsArguments.TryReadArgument(CommandLine, 2, ManifestPath, Found) Then GoTo Failed
    If Not Found Then GoTo Failed
    If Not WindowsArguments.TryReadArgument(CommandLine, 3, OutputPath, Found) Then GoTo Failed
    If Not Found Then GoTo Failed
    If Options.Mode = 2 Then
        If Options.ClangArgument = 0 Then
            If Not DefaultClang(ClangInput) Then GoTo Failed
        Else
            If Not WindowsArguments.TryReadArgument(CommandLine, Options.ClangArgument, ClangInput, Found) Then GoTo Failed
            If Not Found Then GoTo Failed
        End If
        If Not WindowsPaths.TryAbsolutePath(ClangInput, Clang, Failure) Then GoTo Failed
    End If
    TryExecute = TryCompile(ManifestPath, OutputPath, Clang, Options.Mode, Resources, Stage)
    Exit Function
Failed:
    Status = CompilerMessages.TryWriteError(CompilerMessages.UsageError, 0, Failure, Err.Number, ManifestPath, 0, 0)
End Function

' Runs one command, reports controlled failures, and never consumes a failed operation's result.
Public Function Main() As Long
    Dim CommandLine() As Byte
    Dim Stage() As Byte
    Dim EmptyPath() As Byte
    Dim Options As CommandOptions.CommandRequest
    Dim Diagnostic As CommandOptions.CommandDiagnostic
    Dim Resources As RequestResources
    Dim Count As Long
    Dim Failure As Long
    Dim Kind As Long
    Dim Status As Boolean
    Dim Completed As Boolean
    On Error GoTo Failed
    Main = 1
    If Not BufferPrimitives.TryResizeBytes(CommandLine, 131072, False) Then GoTo Failed
    If Not SystemPrimitives.TryReadCommandLine(CommandLine, Count, Failure) Then GoTo Failed
    If Not BufferPrimitives.TryResizeBytes(CommandLine, Count, True) Then GoTo Failed
    If Not CommandOptions.TryParse(CommandLine, Options, Diagnostic) Then
        Status = CompilerMessages.TryWriteError(CompilerMessages.UsageError, Diagnostic.Argument, Diagnostic.Code, Err.Number, EmptyPath, 0, 0)
        Main = 2
        Exit Function
    End If
    Completed = TryExecute(CommandLine, Options, Resources, Stage)
    Failure = 0
    If Not TryCleanup(Resources, Stage, Failure) Then
        Kind = CompilerMessages.CleanupError
        If Completed Then Kind = CompilerMessages.CleanupWarning
        Status = CompilerMessages.TryWriteError(Kind, 0, Failure, Err.Number, Stage, 0, 0)
    End If
    If Completed Then
        If CompilerMessages.TryWriteSuccess(Options.Mode) Then Main = 0
    End If
    Exit Function
Failed:
    Main = 1
    Status = CompilerMessages.TryWriteError(CompilerMessages.InternalError, 0, Failure, Err.Number, EmptyPath, 0, 0)
    Status = TryCleanup(Resources, Stage, Failure)
End Function

