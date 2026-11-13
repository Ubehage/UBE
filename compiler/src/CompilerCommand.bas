UBE SOURCE 1 MODULE
Attribute UBE_Name = "CompilerCommand"
' Owns one command request and connects project loading, checked lowering and guarded publication.



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

' Decodes the admitted command paths and keeps source-independent request state local.
Private Function TryExecute(ByRef CommandLine() As Byte, ByRef Options As CommandOptions.CommandRequest, ByRef Resources As CompilationRequest.RequestResources, ByRef Stage() As Byte, ByRef Ranges() As NativeCompilation.RangeResult) As Boolean
    Dim ManifestPath() As Byte
    Dim OutputPath() As Byte
    Dim ClangInput() As Byte
    Dim Clang() As Byte
    Dim Report As CompilationRequest.RequestDiagnostic
    Dim DiagnosticPath() As Byte
    Dim Found As Boolean
    Dim Completed As Boolean
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
    Completed = CompilationRequest.TryCompile(ManifestPath, OutputPath, Clang, Options.Mode, NativeCompilation.MaximumWorkers, Resources, Stage, Ranges, Report, DiagnosticPath)
    If Not Completed Then Status = CompilerMessages.TryWriteError(Report.Kind, Report.Operation, Report.Code, Report.Reason, DiagnosticPath, Report.SourceLine, Report.SourceColumn)
    TryExecute = Completed
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
    Dim Resources As CompilationRequest.RequestResources
    Dim Ranges() As NativeCompilation.RangeResult
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
    Completed = TryExecute(CommandLine, Options, Resources, Stage, Ranges)
    Failure = 0
    If Not CompilationRequest.TryCleanup(Resources, Stage, Ranges, Failure) Then
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
    Status = CompilationRequest.TryCleanup(Resources, Stage, Ranges, Failure)
End Function

