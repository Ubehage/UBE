UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeBackend"
' Runs native tools in a caller-owned private stage; publication belongs to OutputPublication.

' Closes a file without replacing the primary failure and retains an unsuccessful close owner.
Private Function CloseFile(ByRef Token As Long, ByRef Failure As Long) As Boolean
    CloseFile = FileBytes.TryClosePreservingError(Token, Failure)
End Function

' Attempts bounded child cleanup and preserves the primary error, retaining any unreleased owner.
Public Function TryStop(ByRef Owner As Long, ByRef Failure As Long) As Boolean
    Dim PrimaryError As Long
    Dim CleanupFailure As Long
    Dim State As Long
    Dim ExitCode As Long
    Dim Status As Boolean
    PrimaryError = Err.Number
    If Owner = 0 Then TryStop = True: Exit Function
    Status = ProcessPrimitives.TryTerminate(Owner, CleanupFailure)
    Status = ProcessPrimitives.TryWait(Owner, 5000, State, ExitCode, CleanupFailure)
    Status = ProcessPrimitives.TryClose(Owner, CleanupFailure)
    If Failure <> 0 Then
        TryStop = Status
        Status = FilePrimitives.SetError(PrimaryError)
        Exit Function
    End If
    If Not Status Then Failure = CleanupFailure
    TryStop = Status
End Function

' Runs one tool directly with a monotonic deadline and bounded diagnostic-output detection.
Public Function TryRun(ByRef Application() As Byte, ByRef Command() As Byte, ByRef Stage() As Byte, ByRef LogPath() As Byte, ByRef FileToken As Long, ByRef ProcessToken As Long, ByRef Failure As Long, ByRef ExitCode As Long) As Boolean
    Dim Started As LongLong
    Dim Current As LongLong
    Dim Length As Long
    Dim State As Long
    Dim Status As Boolean
    On Error GoTo Failed
    If FileToken <> 0 Or ProcessToken <> 0 Then Failure = 1: TryRun = FilePrimitives.SetError(5): Exit Function
    Failure = 0
    If Not SystemPrimitives.TryMonotonicMilliseconds(Started, Failure) Then Exit Function
    If Not FilePrimitives.TryCreateNew(LogPath, FileToken, Failure) Then GoTo Cleanup
    If Not ProcessPrimitives.TryStart(Application, Command, Stage, FileToken, ProcessToken, Failure) Then GoTo Cleanup
    Do
        If Not FilePrimitives.TryLength(FileToken, Length, Failure) Then GoTo Cleanup
        If Length > 65536 Then Failure = 101: Status = FilePrimitives.SetError(57): GoTo Cleanup
        If Not SystemPrimitives.TryMonotonicMilliseconds(Current, Failure) Then GoTo Cleanup
        If Current < Started Then Failure = 100: Status = FilePrimitives.SetError(57): GoTo Cleanup
        If Current - Started >= 30000 Then Failure = 100: Status = FilePrimitives.SetError(57): GoTo Cleanup
        If Not ProcessPrimitives.TryWait(ProcessToken, 50, State, ExitCode, Failure) Then GoTo Cleanup
        If State = 1 Then Exit Do
    Loop
    If Not FilePrimitives.TryLength(FileToken, Length, Failure) Then GoTo Cleanup
    If Length > 65536 Then Failure = 101: Status = FilePrimitives.SetError(57): GoTo Cleanup
    If ExitCode <> 0 Then Failure = 102: Status = FilePrimitives.SetError(57): GoTo Cleanup
    If Not ProcessPrimitives.TryClose(ProcessToken, Failure) Then GoTo Cleanup
    If Not CloseFile(FileToken, Failure) Then Exit Function
    TryRun = True
    Exit Function
Cleanup:
    If ProcessToken <> 0 Then Status = TryStop(ProcessToken, Failure)
    If ProcessToken = 0 Then Status = CloseFile(FileToken, Failure)
    Exit Function
Failed:
    Failure = 1
    GoTo Cleanup
End Function

' Writes the reviewed import definition into an exclusively acquired private stage file.
Private Function TryWriteDefinition(ByRef Stage() As Byte, ByRef Definition() As Byte, ByRef Token As Long, ByRef Failure As Long) As Boolean
    Dim Path() As Byte
    Dim Status As Boolean
    On Error GoTo Failed
    If Not OutputPublication.TryStagePath(Stage, OutputPublication.ImportDefinition, Path, Failure) Then Exit Function
    If Not FilePrimitives.TryCreateNew(Path, Token, Failure) Then GoTo Cleanup
    Status = FileBytes.TryWriteAllBytes(Token, Definition, Failure)
    If Not CloseFile(Token, Failure) Then Exit Function
    TryWriteDefinition = Status
    Exit Function
Cleanup:
    Status = CloseFile(Token, Failure)
    Exit Function
Failed:
    Failure = 1
    GoTo Cleanup
End Function

' Validates the bounded archive framing produced by llvm-dlltool before using it as a linker input.
Private Function TryCheckArchive(ByRef Stage() As Byte, ByRef Token As Long, ByRef Failure As Long) As Boolean
    Dim Path() As Byte
    Dim Header(0 To 7) As Byte
    Dim Length As Long
    Dim Offset As Long
    Dim Progress As Long
    Dim Status As Boolean
    On Error GoTo Failed
    If Not OutputPublication.TryStagePath(Stage, OutputPublication.ImportLibrary, Path, Failure) Then Exit Function
    If Not FilePrimitives.TryOpen(Path, 65536, Token, Length, Failure) Then GoTo Cleanup
    If Length < 8 Then GoTo InvalidArchive
    Do While Offset < 8
        If Not FilePrimitives.TryRead(Token, Header, Offset, 8 - Offset, Progress, Failure) Then GoTo Cleanup
        If Progress <= 0 Or Progress > 8 - Offset Then GoTo InvalidArchive
        Offset = Offset + Progress
    Loop
    If Header(0) <> 33 Or Header(1) <> 60 Or Header(2) <> 97 Or Header(3) <> 114 Then GoTo InvalidArchive
    If Header(4) <> 99 Or Header(5) <> 104 Or Header(6) <> 62 Or Header(7) <> 10 Then GoTo InvalidArchive
    Status = True
    GoTo Cleanup
InvalidArchive:
    Failure = 103
    Status = FilePrimitives.SetError(5)
Cleanup:
    If Not CloseFile(Token, Failure) Then Exit Function
    TryCheckArchive = Status
    Exit Function
Failed:
    Failure = 1
    GoTo Cleanup
End Function

' Resolves the existing LLVM import tool beside the explicitly selected Clang executable.
Public Function TryImportTool(ByRef Clang() As Byte, ByRef Result() As Byte, ByRef Failure As Long) As Boolean
    Dim Parent() As Byte
    Dim Leaf(0 To 15) As Byte
    On Error GoTo Failed
    If Not WindowsPaths.TryParent(Clang, Parent, Failure) Then Exit Function
    Leaf(0) = 108: Leaf(1) = 108: Leaf(2) = 118: Leaf(3) = 109
    Leaf(4) = 45: Leaf(5) = 100: Leaf(6) = 108: Leaf(7) = 108
    Leaf(8) = 116: Leaf(9) = 111: Leaf(10) = 111: Leaf(11) = 108
    Leaf(12) = 46: Leaf(13) = 101: Leaf(14) = 120: Leaf(15) = 101
    TryImportTool = WindowsPaths.TryResolveSource(Parent, Leaf, Result, Failure)
    Exit Function
Failed:
    Failure = 1
End Function

' Builds and validates a private native executable without replacing a public destination.
Public Function TryBuild(ByRef Clang() As Byte, ByRef Stage() As Byte, ByVal Optimization As Long, ByRef ImportDefinition() As Byte, ByRef FileToken As Long, ByRef ProcessToken As Long, ByRef Failure As Long, ByRef ExitCode As Long) As Boolean
    Dim ImportTool() As Byte
    Dim Command() As Byte
    Dim LogPath() As Byte
    Dim NativePath() As Byte
    Dim Status As Boolean
    On Error GoTo Failed
    If FileToken <> 0 Or ProcessToken <> 0 Then Failure = 1: TryBuild = FilePrimitives.SetError(5): Exit Function
    Failure = 0
    If Not TryWriteDefinition(Stage, ImportDefinition, FileToken, Failure) Then Exit Function
    If Not TryImportTool(Clang, ImportTool, Failure) Then Exit Function
    If Not NativeToolArguments.TryImportCommand(ImportTool, Stage, Command, Failure) Then Exit Function
    If Not OutputPublication.TryStagePath(Stage, OutputPublication.ImportLog, LogPath, Failure) Then Exit Function
    If Not TryRun(ImportTool, Command, Stage, LogPath, FileToken, ProcessToken, Failure, ExitCode) Then Exit Function
    If Not TryCheckArchive(Stage, FileToken, Failure) Then Exit Function
    If Not NativeToolArguments.TryClangCommand(Clang, Stage, Optimization, Command, Failure) Then Exit Function
    If Not OutputPublication.TryStagePath(Stage, OutputPublication.CompilerLog, LogPath, Failure) Then Exit Function
    If Not TryRun(Clang, Command, Stage, LogPath, FileToken, ProcessToken, Failure, ExitCode) Then Exit Function
    If Not OutputPublication.TryStagePath(Stage, OutputPublication.Executable, NativePath, Failure) Then Exit Function
    TryBuild = WindowsImages.TryCheckAMD64Executable(NativePath, 67108864, FileToken, Failure)
    Exit Function
Failed:
    Failure = 1
    If ProcessToken <> 0 Then Status = TryStop(ProcessToken, Failure)
    If ProcessToken = 0 Then Status = CloseFile(FileToken, Failure)
End Function
