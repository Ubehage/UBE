UBE SOURCE 1 MODULE
Attribute UBE_Name = "OutputPublication"
' Guards adjacent private stages and atomic publication against project input aliases.
Public Const InputIR As Long = 1
Public Const Executable As Long = 2
Public Const ImportDefinition As Long = 3
Public Const ImportLibrary As Long = 4
Public Const ImportLog As Long = 5
Public Const CompilerLog As Long = 6

' Selects a reviewed fixed stage filename without permitting arbitrary cleanup paths.
Private Function StageLeaf(ByVal Kind As Long, ByRef Leaf() As Byte) As Boolean
    If Kind = InputIR Then StageLeaf = InputIRLeaf(Leaf): Exit Function
    If Kind = Executable Then StageLeaf = ExecutableLeaf(Leaf): Exit Function
    If Kind = ImportDefinition Then StageLeaf = ImportDefinitionLeaf(Leaf): Exit Function
    If Kind = ImportLibrary Then StageLeaf = ImportLibraryLeaf(Leaf): Exit Function
    If Kind = ImportLog Then StageLeaf = ImportLogLeaf(Leaf): Exit Function
    If Kind = CompilerLog Then StageLeaf = CompilerLogLeaf(Leaf): Exit Function
End Function

' Supplies the exact input.ll stage leaf.
Private Function InputIRLeaf(ByRef Leaf() As Byte) As Boolean
    If BufferPrimitives.TryResizeBytes(Leaf, 8, False) = False Then Exit Function
    Leaf(0) = 105
    Leaf(1) = 110
    Leaf(2) = 112
    Leaf(3) = 117
    Leaf(4) = 116
    Leaf(5) = 46
    Leaf(6) = 108
    Leaf(7) = 108
    InputIRLeaf = True
End Function

' Supplies the exact output.exe stage leaf.
Private Function ExecutableLeaf(ByRef Leaf() As Byte) As Boolean
    If BufferPrimitives.TryResizeBytes(Leaf, 10, False) = False Then Exit Function
    Leaf(0) = 111
    Leaf(1) = 117
    Leaf(2) = 116
    Leaf(3) = 112
    Leaf(4) = 117
    Leaf(5) = 116
    Leaf(6) = 46
    Leaf(7) = 101
    Leaf(8) = 120
    Leaf(9) = 101
    ExecutableLeaf = True
End Function

' Supplies the exact kernel32-memory.def stage leaf.
Private Function ImportDefinitionLeaf(ByRef Leaf() As Byte) As Boolean
    If BufferPrimitives.TryResizeBytes(Leaf, 19, False) = False Then Exit Function
    Leaf(0) = 107
    Leaf(1) = 101
    Leaf(2) = 114
    Leaf(3) = 110
    Leaf(4) = 101
    Leaf(5) = 108
    Leaf(6) = 51
    Leaf(7) = 50
    Leaf(8) = 45
    Leaf(9) = 109
    Leaf(10) = 101
    Leaf(11) = 109
    Leaf(12) = 111
    Leaf(13) = 114
    Leaf(14) = 121
    Leaf(15) = 46
    Leaf(16) = 100
    Leaf(17) = 101
    Leaf(18) = 102
    ImportDefinitionLeaf = True
End Function

' Supplies the exact kernel32-memory.lib stage leaf.
Private Function ImportLibraryLeaf(ByRef Leaf() As Byte) As Boolean
    If BufferPrimitives.TryResizeBytes(Leaf, 19, False) = False Then Exit Function
    Leaf(0) = 107
    Leaf(1) = 101
    Leaf(2) = 114
    Leaf(3) = 110
    Leaf(4) = 101
    Leaf(5) = 108
    Leaf(6) = 51
    Leaf(7) = 50
    Leaf(8) = 45
    Leaf(9) = 109
    Leaf(10) = 101
    Leaf(11) = 109
    Leaf(12) = 111
    Leaf(13) = 114
    Leaf(14) = 121
    Leaf(15) = 46
    Leaf(16) = 108
    Leaf(17) = 105
    Leaf(18) = 98
    ImportLibraryLeaf = True
End Function

' Supplies the exact import.log stage leaf.
Private Function ImportLogLeaf(ByRef Leaf() As Byte) As Boolean
    If BufferPrimitives.TryResizeBytes(Leaf, 10, False) = False Then Exit Function
    Leaf(0) = 105
    Leaf(1) = 109
    Leaf(2) = 112
    Leaf(3) = 111
    Leaf(4) = 114
    Leaf(5) = 116
    Leaf(6) = 46
    Leaf(7) = 108
    Leaf(8) = 111
    Leaf(9) = 103
    ImportLogLeaf = True
End Function

' Supplies the exact clang.log stage leaf.
Private Function CompilerLogLeaf(ByRef Leaf() As Byte) As Boolean
    If BufferPrimitives.TryResizeBytes(Leaf, 9, False) = False Then Exit Function
    Leaf(0) = 99
    Leaf(1) = 108
    Leaf(2) = 97
    Leaf(3) = 110
    Leaf(4) = 103
    Leaf(5) = 46
    Leaf(6) = 108
    Leaf(7) = 111
    Leaf(8) = 103
    CompilerLogLeaf = True
End Function

' Resolves one of the six reviewed leaves within a stage and preserves Result on failure.
Public Function TryStagePath(ByRef Stage() As Byte, ByVal Kind As Long, ByRef Result() As Byte, ByRef Failure As Long) As Boolean
    Dim Leaf() As Byte
    On Error GoTo Failed
    Failure = 1
    If Kind < InputIR Or Kind > CompilerLog Then TryStagePath = FilePrimitives.SetError(5): Exit Function
    Failure = 3
    If StageLeaf(Kind, Leaf) = False Then Exit Function
    TryStagePath = WindowsPaths.TryResolveSource(Stage, Leaf, Result, Failure)
    Exit Function
Failed:
    Failure = 1
    Exit Function
End Function

' Resolves one bounded emission chunk; ordinal two is reserved for quota-diagnostic replay.
Public Function TryEmissionPath(ByRef Stage() As Byte, ByVal Ordinal As Long, ByRef Result() As Byte, ByRef Failure As Long) As Boolean
    Dim Leaf() As Byte
    On Error GoTo Failed
    Failure = 1
    If Ordinal < 0 Or Ordinal > 2 Then TryEmissionPath = FilePrimitives.SetError(5): Exit Function
    If Not BufferPrimitives.TryResizeBytes(Leaf, 13, False) Then Exit Function
    Leaf(0) = 101
    Leaf(1) = 109
    Leaf(2) = 105
    Leaf(3) = 115
    Leaf(4) = 115
    Leaf(5) = 105
    Leaf(6) = 111
    Leaf(7) = 110
    Leaf(8) = 45
    Leaf(9) = 48 + Ordinal
    Leaf(10) = 46
    Leaf(11) = 108
    Leaf(12) = 108
    TryEmissionPath = WindowsPaths.TryResolveSource(Stage, Leaf, Result, Failure)
    Exit Function
Failed:
    Failure = 1
End Function

' Reads the capacity of caller-owned source path records without trusting their count.
Private Intrinsic Function PathCount(ByRef Paths() As ProjectLoader.SourcePath) As Long
Attribute PathCount.UBE_Primitive = "Array.Length"
End Function

' Records an invalid publication request without consuming a prior resource owner.
Private Function InvalidRequest(ByRef Failure As Long) As Boolean
    Failure = 1
    InvalidRequest = FilePrimitives.SetError(5)
End Function

' Reads canonical spelling and hard-link identity through one owner, closing before the next input.
Private Function ReadIdentity(ByRef Path() As Byte, ByRef Identity() As Byte, ByRef Canonical() As Byte, ByRef Token As Long, ByRef Failure As Long) As Boolean
    Dim Length As Long
    Dim Status As Boolean
    On Error GoTo Failed
    If FilePrimitives.TryOpen(Path, 2147483647, Token, Length, Failure) = False Then Exit Function
    If FilePrimitives.TryIdentity(Token, Identity, Failure) = False Then GoTo Cleanup
    If WindowsPaths.TryFilePath(Token, Canonical, Failure) = False Then GoTo Cleanup
    ReadIdentity = FileBytes.TryClosePreservingError(Token, Failure)
    Exit Function
Failed:
    Failure = 1
Cleanup:
    Status = FileBytes.TryClosePreservingError(Token, Failure)
End Function

' Compares all twelve identity bytes, covering volume and both file-index words.
Private Function SameIdentity(ByRef First() As Byte, ByRef Second() As Byte) As Boolean
    Dim Index As Long
    Do While Index < 12
        If First(Index) <> Second(Index) Then Exit Function
        Index = Index + 1
    Loop
    SameIdentity = True
End Function

' Rejects one current input's canonical path and hard-link identity as an output destination.
Private Function CheckInput(ByRef InputPath() As Byte, ByRef Output() As Byte, ByRef PhysicalOutput() As Byte, ByRef OutputIdentity() As Byte, ByVal Existing As Boolean, ByRef Token As Long, ByRef Failure As Long) As Boolean
    Dim Canonical() As Byte
    Dim Identity(0 To 11) As Byte
    Dim Same As Boolean
    On Error GoTo Failed
    If ReadIdentity(InputPath, Identity, Canonical, Token, Failure) = False Then Exit Function
    If WindowsPaths.TrySamePath(Canonical, Output, Same, Failure) = False Then Exit Function
    If Same Then GoTo InputAlias
    If Existing Then
        If WindowsPaths.TrySamePath(Canonical, PhysicalOutput, Same, Failure) = False Then Exit Function
        If Same Then GoTo InputAlias
        If SameIdentity(Identity, OutputIdentity) Then GoTo InputAlias
    End If
    CheckInput = True
    Exit Function
InputAlias:
    Failure = 120
    CheckInput = FilePrimitives.SetError(5)
    Exit Function
Failed:
    Failure = 1
End Function

' Revalidates every admitted source span and current input before any output mutation.
Private Function CheckInputs(ByRef ManifestPath() As Byte, ByRef PathBytes() As Byte, ByRef Paths() As ProjectLoader.SourcePath, ByVal SourceCount As Long, ByRef Output() As Byte, ByRef PhysicalOutput() As Byte, ByRef OutputIdentity() As Byte, ByVal Existing As Boolean, ByRef Token As Long, ByRef Failure As Long) As Boolean
    Dim InputPath() As Byte
    Dim Index As Long
    Dim Start As Long
    Dim Length As Long
    Dim Total As Long
    On Error GoTo Failed
    If SourceCount < 0 Or SourceCount > 128 Then CheckInputs = InvalidRequest(Failure): Exit Function
    If SourceCount > PathCount(Paths) Then CheckInputs = InvalidRequest(Failure): Exit Function
    If CheckInput(ManifestPath, Output, PhysicalOutput, OutputIdentity, Existing, Token, Failure) = False Then Exit Function
    Total = BufferPrimitives.ByteStorageLength(PathBytes)
    Do While Index < SourceCount
        Start = Paths(Index).Start
        Length = Paths(Index).Length
        If Start < 0 Or Start > Total Or Length < 1 Or Length > 4096 Then CheckInputs = InvalidRequest(Failure): Exit Function
        If Length > Total - Start Then CheckInputs = InvalidRequest(Failure): Exit Function
        Failure = 3
        If BufferPrimitives.TryResizeBytes(InputPath, Length, False) = False Then Exit Function
        If BufferPrimitives.CopyByteRange(PathBytes, Start, InputPath, 0, Length) = False Then Exit Function
        If CheckInput(InputPath, Output, PhysicalOutput, OutputIdentity, Existing, Token, Failure) = False Then Exit Function
        Index = Index + 1
    Loop
    CheckInputs = True
    Exit Function
Failed:
    Failure = 1
End Function

' Resolves a destination through its existing physical parent and rejects directory or input aliases.
Private Function ResolveOutput(ByRef Requested() As Byte, ByRef ManifestPath() As Byte, ByRef PathBytes() As Byte, ByRef Paths() As ProjectLoader.SourcePath, ByVal SourceCount As Long, ByRef Output() As Byte, ByRef Parent() As Byte, ByRef Token As Long, ByRef Failure As Long) As Boolean
    Dim Full() As Byte
    Dim Leaf() As Byte
    Dim Physical() As Byte
    Dim Identity(0 To 11) As Byte
    Dim Length As Long
    Dim Start As Long
    Dim Kind As Long
    Dim Status As Boolean
    On Error GoTo Failed
    Length = BufferPrimitives.ByteStorageLength(Requested)
    If Length < 1 Then ResolveOutput = InvalidRequest(Failure): Exit Function
    If Requested(Length - 1) = 46 Or Requested(Length - 1) = 32 Or Requested(Length - 1) = 92 Or Requested(Length - 1) = 47 Then ResolveOutput = InvalidRequest(Failure): Exit Function
    If WindowsPaths.TryAbsolutePath(Requested, Full, Failure) = False Then Exit Function
    Length = BufferPrimitives.ByteStorageLength(Full)
    Start = Length
    Do While Start > 0
        If Full(Start - 1) = 92 Then Exit Do
        Start = Start - 1
    Loop
    If Start < 1 Or Start = Length Then ResolveOutput = InvalidRequest(Failure): Exit Function
    Failure = 3
    If BufferPrimitives.TryResizeBytes(Leaf, Length - Start, False) = False Then Exit Function
    If BufferPrimitives.CopyByteRange(Full, Start, Leaf, 0, Length - Start) = False Then Exit Function
    If WindowsPaths.TryParent(Full, Parent, Failure) = False Then Exit Function
    If FilePrimitives.TryOpenDirectory(Parent, Token, Failure) = False Then Exit Function
    If WindowsPaths.TryFilePath(Token, Parent, Failure) = False Then GoTo Cleanup
    If FileBytes.TryClosePreservingError(Token, Failure) = False Then Exit Function
    If WindowsPaths.TryResolveSource(Parent, Leaf, Output, Failure) = False Then Exit Function
    If PathPrimitives.TryKind(Output, Kind, Failure) = False Then Exit Function
    If Kind <> 0 And Kind <> 1 Then ResolveOutput = InvalidRequest(Failure): Exit Function
    If Kind = 1 Then
        If ReadIdentity(Output, Identity, Physical, Token, Failure) = False Then Exit Function
    End If
    ResolveOutput = CheckInputs(ManifestPath, PathBytes, Paths, SourceCount, Output, Physical, Identity, Kind = 1, Token, Failure)
    Exit Function
Failed:
    Failure = 1
Cleanup:
    If Token <> 0 Then Status = FileBytes.TryClosePreservingError(Token, Failure)
End Function

' Independently protects one additional support/tool input without extending project source records.
Public Function TryProtectPath(ByRef InputPath() As Byte, ByRef Output() As Byte, ByRef Token As Long, ByRef Failure As Long) As Boolean
    Dim NoBytes() As Byte
    Dim NoPaths() As ProjectLoader.SourcePath
    Dim Checked() As Byte
    Dim Parent() As Byte
    On Error GoTo Failed
    If Token <> 0 Then TryProtectPath = InvalidRequest(Failure): Exit Function
    Failure = 0
    TryProtectPath = ResolveOutput(Output, InputPath, NoBytes, NoPaths, 0, Checked, Parent, Token, Failure)
    Exit Function
Failed:
    Failure = 1
End Function

' Creates the bounded .ube-<monotonic tick>-<attempt> leaf in ordinary counted-byte code.
Private Function StageName(ByVal Tick As LongLong, ByVal Attempt As Long, ByRef Result() As Byte) As Boolean
    Dim Buffer(0 To 63) As Byte
    Dim Used As Long = 5
    On Error GoTo Failed
    Buffer(0) = 46
    Buffer(1) = 117
    Buffer(2) = 98
    Buffer(3) = 101
    Buffer(4) = 45
    If ByteText.TryAppendInteger(Buffer, Used, Tick) = False Then Exit Function
    Buffer(Used) = 45
    Used = Used + 1
    If ByteText.TryAppendInteger(Buffer, Used, Attempt) = False Then Exit Function
    If BufferPrimitives.TryResizeBytes(Buffer, Used, True) = False Then Exit Function
    StageName = BufferPrimitives.TryCopyBytes(Result, Buffer)
    Exit Function
Failed:
    Exit Function
End Function

' Prepares scratch canonical paths and reserves one adjacent directory without reusing another request's stage.
Public Function TryPrepare(ByRef Requested() As Byte, ByRef ManifestPath() As Byte, ByRef PathBytes() As Byte, ByRef Paths() As ProjectLoader.SourcePath, ByVal SourceCount As Long, ByRef Output() As Byte, ByRef Stage() As Byte, ByRef StageOwned As Boolean, ByRef Token As Long, ByRef Failure As Long) As Boolean
    Dim Parent() As Byte
    Dim Leaf() As Byte
    Dim Candidate() As Byte
    Dim Tick As LongLong
    Dim Attempt As Long
    Dim OriginalError As Long
    Dim Status As Boolean
    On Error GoTo Failed
    If Token <> 0 Or StageOwned Then TryPrepare = InvalidRequest(Failure): Exit Function
    Failure = 0
    If ResolveOutput(Requested, ManifestPath, PathBytes, Paths, SourceCount, Output, Parent, Token, Failure) = False Then Exit Function
    If SystemPrimitives.TryMonotonicMilliseconds(Tick, Failure) = False Then Exit Function
    If Tick < 0 Then TryPrepare = InvalidRequest(Failure): Exit Function
    OriginalError = Err.Number
    Do While Attempt < 128
        Failure = 3
        If StageName(Tick, Attempt, Leaf) = False Then Exit Function
        If WindowsPaths.TryResolveSource(Parent, Leaf, Candidate, Failure) = False Then Exit Function
        If BufferPrimitives.ByteStorageLength(Candidate) > 4076 Then TryPrepare = InvalidRequest(Failure): Exit Function
        Failure = 3
        If BufferPrimitives.TryCopyBytes(Stage, Candidate) = False Then Exit Function
        If DirectoryPrimitives.TryCreate(Stage, Failure) Then
            StageOwned = True
            TryPrepare = True
            Exit Function
        End If
        If Failure <> 17 Then Exit Function
        Status = FilePrimitives.SetError(OriginalError)
        Attempt = Attempt + 1
    Loop
    Failure = 121
    TryPrepare = FilePrimitives.SetError(58)
    Exit Function
Failed:
    Failure = 1
End Function

' Rechecks destination/input aliases immediately before atomically replacing it with a closed validated stage file.
Public Function TryCommit(ByRef ManifestPath() As Byte, ByRef PathBytes() As Byte, ByRef Paths() As ProjectLoader.SourcePath, ByVal SourceCount As Long, ByRef Output() As Byte, ByRef Stage() As Byte, ByVal StageOwned As Boolean, ByVal Kind As Long, ByRef Token As Long, ByRef Failure As Long) As Boolean
    Dim Checked() As Byte
    Dim Parent() As Byte
    Dim Source() As Byte
    Dim Same As Boolean
    On Error GoTo Failed
    If Token <> 0 Or StageOwned = False Then TryCommit = InvalidRequest(Failure): Exit Function
    If Kind <> InputIR And Kind <> Executable Then TryCommit = InvalidRequest(Failure): Exit Function
    Failure = 0
    If ResolveOutput(Output, ManifestPath, PathBytes, Paths, SourceCount, Checked, Parent, Token, Failure) = False Then Exit Function
    If WindowsPaths.TrySamePath(Output, Checked, Same, Failure) = False Then Exit Function
    If Same = False Then TryCommit = InvalidRequest(Failure): Exit Function
    If TryStagePath(Stage, Kind, Source, Failure) = False Then Exit Function
    TryCommit = FilePrimitives.TryReplace(Source, Checked, Failure)
    Exit Function
Failed:
    Failure = 1
End Function

' Removes only reviewed leaves and the empty owned directory; failures keep ownership available for retry.
Public Function TryDiscard(ByRef Stage() As Byte, ByRef StageOwned As Boolean, ByRef Failure As Long) As Boolean
    Dim Path() As Byte
    Dim Kind As Long = 1
    Dim PrimaryFailure As Long
    Dim PrimaryError As Long
    Dim CleanupFailure As Long
    Dim Status As Boolean
    On Error GoTo Failed
    If StageOwned = False Then TryDiscard = True: Exit Function
    PrimaryFailure = Failure
    PrimaryError = Err.Number
    Do While Kind <= CompilerLog
        If TryStagePath(Stage, Kind, Path, CleanupFailure) = False Then GoTo Rejected
        If FilePrimitives.TryDelete(Path, CleanupFailure) = False Then
            If CleanupFailure <> 18 Then GoTo Rejected
        End If
        Kind = Kind + 1
    Loop
    Kind = 0
    Do While Kind <= 2
        If Not TryEmissionPath(Stage, Kind, Path, CleanupFailure) Then GoTo Rejected
        If Not FilePrimitives.TryDelete(Path, CleanupFailure) Then
            If CleanupFailure <> 18 Then GoTo Rejected
        End If
        Kind = Kind + 1
    Loop
    If DirectoryPrimitives.TryRemove(Stage, CleanupFailure) = False Then GoTo Rejected
    StageOwned = False
    Failure = PrimaryFailure
    Status = FilePrimitives.SetError(PrimaryError)
    TryDiscard = True
    Exit Function
Failed:
    CleanupFailure = 1
Rejected:
    Failure = CleanupFailure
    If PrimaryFailure <> 0 Then
        Failure = PrimaryFailure
        Status = FilePrimitives.SetError(PrimaryError)
    End If
End Function


