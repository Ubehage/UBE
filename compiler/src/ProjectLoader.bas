UBE SOURCE 1 MODULE
Attribute UBE_Name = "ProjectLoader"
' Loads an ordered manifest and source tree through explicit owners into caller-owned request storage.

Public Type SourcePath
    Start As Long
    Length As Long
    ManifestLine As Long
End Type

Public Type LoadDiagnostic
    Stage As Long
    Code As Long
    Reason As Long
    ModuleIndex As Long
    [Line] As Long
    Column As Long
    PathStart As Long
    PathLength As Long
    SourceStage As Long
    ByteOffset As Long
    Utf16Offset As Long
End Type

' Reserves finite canonical path records without embedding managed fields.
Private Intrinsic Function ResizePaths(ByRef Values() As SourcePath, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizePaths.UBE_Primitive = "Array.TryResize"
End Function

' Copies one checked byte span into independent exact-sized scratch storage.
Public Function TryCopyPathSpan(ByRef Bytes() As Byte, ByVal Start As Long, ByVal Length As Long, ByRef Result() As Byte) As Boolean
    Dim Candidate() As Byte
    Dim Actual As Long
    On Error GoTo Failed
    Actual = BufferPrimitives.ByteStorageLength(Bytes)
    If Start < 0 Or Length < 0 Or Start > Actual Then Exit Function
    If Length > Actual - Start Then Exit Function
    If BufferPrimitives.TryResizeBytes(Candidate, Length, False) = False Then Exit Function
    If BufferPrimitives.CopyByteRange(Bytes, Start, Candidate, 0, Length) = False Then Exit Function
    TryCopyPathSpan = BufferPrimitives.TryCopyBytes(Result, Candidate)
    Exit Function
Failed:
    Exit Function
End Function

' Gets the final physical path through the owner that will supply the input bytes.
Private Function TryCanonicalPath(ByVal Token As Long, ByRef Result() As Byte, ByRef Failure As Long) As Boolean
    TryCanonicalPath = WindowsPaths.TryFilePath(Token, Result, Failure)
End Function

' Closes a current owner once, retaining failed ownership and the earlier primary error.
Private Function CloseOwner(ByRef Token As Long, ByRef Failure As Long) As Boolean
    CloseOwner = FileBytes.TryClosePreservingError(Token, Failure)
End Function

' Checks the extension on the supplied manifest path, before opening arbitrary inputs.
Private Function IsManifestPath(ByRef Path() As Byte) As Boolean
    Dim Count As Long
    Dim Character As Long
    On Error GoTo Failed
    Count = BufferPrimitives.ByteStorageLength(Path)
    If Count < 4 Or Count > 4096 Then Exit Function
    If Path(Count - 4) <> 46 Then Exit Function
    Character = Path(Count - 3)
    If Character <> 85 And Character <> 117 Then Exit Function
    Character = Path(Count - 2)
    If Character <> 66 And Character <> 98 Then Exit Function
    Character = Path(Count - 1)
    If Character <> 69 And Character <> 101 Then Exit Function
    IsManifestPath = True
    Exit Function
Failed:
    Exit Function
End Function

' Retains one canonical diagnostic path before any source parsing can fail.
Private Function RetainPath(ByRef Canonical() As Byte, ByVal ManifestLine As Long, ByVal Index As Long, ByRef PathBytes() As Byte, ByRef Paths() As SourcePath, ByRef Used As Long, ByRef Diagnostic As LoadDiagnostic) As Boolean
    Dim Length As Long
    On Error GoTo Failed
    Length = BufferPrimitives.ByteStorageLength(Canonical)
    If Length < 1 Or Length > 4096 Or Used < 0 Or Used > 524288 Then Exit Function
    If Length > 524288 - Used Then Exit Function
    If BufferPrimitives.TryResizeBytes(PathBytes, Used + Length, True) = False Then Exit Function
    If BufferPrimitives.CopyByteRange(Canonical, 0, PathBytes, Used, Length) = False Then Exit Function
    Paths(Index).Start = Used
    Paths(Index).Length = Length
    Paths(Index).ManifestLine = ManifestLine
    Diagnostic.PathStart = Used
    Diagnostic.PathLength = Length
    Used = Used + Length
    RetainPath = True
    Exit Function
Failed:
    Exit Function
End Function

' Reads and validates manifest metadata before any source is opened.
Private Function TryLoadManifest(ByRef ManifestPath() As Byte, ByRef PackageName() As Byte, ByRef Root() As Byte, ByRef Manifest() As Byte, ByRef Spans() As ProjectManifest.ValueSpan, ByRef Info As ProjectManifest.ManifestInfo, ByRef Diagnostic As LoadDiagnostic, ByRef Token As Long) As Boolean
    Dim Canonical() As Byte
    Dim ManifestError As ProjectManifest.ManifestDiagnostic
    Dim Length As Long
    Dim Failure As Long
    Dim Status As Boolean
    On Error GoTo RuntimeFailure
    Diagnostic.Stage = 2
    If FilePrimitives.TryOpen(ManifestPath, 65536, Token, Length, Failure) = False Then GoTo IOFailed
    If TryCanonicalPath(Token, Canonical, Failure) = False Then GoTo IOFailed
    If WindowsPaths.TryParent(Canonical, Root, Failure) = False Then GoTo IOFailed
    Diagnostic.Stage = 3
    If FileBytes.TryReadOpenBytes(Token, Length, Manifest, Failure) = False Then GoTo IOFailed
    If CloseOwner(Token, Failure) = False Then Diagnostic.Code = Failure: Exit Function
    Diagnostic.Stage = 4
    If ProjectManifest.TryParse(Manifest, Spans, Info, ManifestError) = False Then
        Diagnostic.Code = ManifestError.Code
        Diagnostic.Line = ManifestError.Line
        Diagnostic.Column = ManifestError.Column
        Exit Function
    End If
    Diagnostic.Stage = 9
    Diagnostic.Code = 8
    TryLoadManifest = ProjectManifest.TryCopyValue(Manifest, Info.NameStart, Info.NameLength, PackageName)
    Exit Function
IOFailed:
    Diagnostic.Code = Failure
    If Diagnostic.Code = 0 Then Diagnostic.Code = 1
Cleanup:
    If Token <> 0 Then
        If Failure = 0 Then Failure = Diagnostic.Code
        Status = CloseOwner(Token, Failure)
    End If
    Exit Function
RuntimeFailure:
    Diagnostic.Code = 12
    If Failure = 0 Then Failure = 12
    GoTo Cleanup
End Function

' Verifies one physical input, closes its owner and retains syntax in source order.
Private Function TryLoadSource(ByRef Root() As Byte, ByRef Relative() As Byte, ByVal ManifestLine As Long, ByVal Index As Long, ByRef PathBytes() As Byte, ByRef Paths() As SourcePath, ByRef PathUsed As Long, ByRef Bytes() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByRef Nodes() As SourceParser.SyntaxNode, ByRef Modules() As ProjectSyntax.ParsedModule, ByRef Counts As ProjectSyntax.ProjectCounts, ByRef Diagnostic As LoadDiagnostic, ByRef Token As Long) As Boolean
    Dim Resolved() As Byte
    Dim Canonical() As Byte
    Dim Previous() As Byte
    Dim Source() As Byte
    Dim SourceError As ProjectSyntax.ProjectDiagnostic
    Dim Length As Long
    Dim Failure As Long
    Dim Prior As Long
    Dim Within As Boolean
    Dim Same As Boolean
    Dim Status As Boolean
    On Error GoTo RuntimeFailure
    Diagnostic.Stage = 5
    Diagnostic.Code = 1
    Diagnostic.Reason = 0
    Diagnostic.ModuleIndex = Index
    Diagnostic.Line = ManifestLine
    Diagnostic.Column = 1
    Diagnostic.PathStart = 0
    Diagnostic.PathLength = 0
    If WindowsPaths.TryResolveSource(Root, Relative, Resolved, Failure) = False Then GoTo IOFailed
    If WindowsPaths.TryIsWithin(Root, Resolved, Within, Failure) = False Then GoTo IOFailed
    If Within = False Then Diagnostic.Code = 11: Diagnostic.Reason = 1: GoTo Rejected
    Diagnostic.Stage = 6
    If FilePrimitives.TryOpen(Resolved, 1048576, Token, Length, Failure) = False Then GoTo IOFailed
    If TryCanonicalPath(Token, Canonical, Failure) = False Then GoTo IOFailed
    If WindowsPaths.TryIsWithin(Root, Canonical, Within, Failure) = False Then GoTo IOFailed
    If Within = False Then Diagnostic.Code = 11: Diagnostic.Reason = 1: GoTo Rejected
    Prior = 0
    Do While Prior < Index
        Failure = 8
        If TryCopyPathSpan(PathBytes, Paths(Prior).Start, Paths(Prior).Length, Previous) = False Then GoTo IOFailed
        If WindowsPaths.TrySamePath(Previous, Canonical, Same, Failure) = False Then GoTo IOFailed
        If Same Then Diagnostic.Code = 3: Diagnostic.Reason = 2: GoTo Rejected
        Prior = Prior + 1
    Loop
    Diagnostic.Stage = 9
    Diagnostic.Code = 8
    If RetainPath(Canonical, ManifestLine, Index, PathBytes, Paths, PathUsed, Diagnostic) = False Then GoTo Rejected
    Diagnostic.Stage = 7
    If FileBytes.TryReadOpenBytes(Token, Length, Source, Failure) = False Then GoTo IOFailed
    If CloseOwner(Token, Failure) = False Then Diagnostic.Code = Failure: Exit Function
    Diagnostic.Stage = 8
    If ProjectSyntax.TryAppendModule(Source, Bytes, Tokens, Nodes, Modules, Counts, SourceError) = False Then
        Diagnostic.Code = SourceError.Code
        Diagnostic.Reason = SourceError.Reason
        Diagnostic.SourceStage = SourceError.Stage
        Diagnostic.Line = SourceError.Line
        Diagnostic.Column = SourceError.Column
        Diagnostic.ByteOffset = SourceError.ByteOffset
        Diagnostic.Utf16Offset = SourceError.Utf16Offset
        GoTo Rejected
    End If
    TryLoadSource = True
    Exit Function
IOFailed:
    Diagnostic.Code = Failure
    If Diagnostic.Code = 0 Then Diagnostic.Code = 1
Rejected:
    If Token <> 0 Then
        If Failure = 0 Then Failure = Diagnostic.Code
        Status = CloseOwner(Token, Failure)
    End If
    Exit Function
RuntimeFailure:
    Diagnostic.Code = 12
    If Failure = 0 Then Failure = 12
    GoTo Rejected
End Function

' Failed requests invalidate Counts/Info.SourceCount; scratch arrays may change.
' A nonzero incoming Token is rejected before invalidating any prior request data.
' Tokens retained after a failed close belong to the caller and must be retried.
Public Function TryLoad(ByRef ManifestPath() As Byte, ByRef PackageName() As Byte, ByRef PathBytes() As Byte, ByRef Paths() As SourcePath, ByRef Bytes() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByRef Nodes() As SourceParser.SyntaxNode, ByRef Modules() As ProjectSyntax.ParsedModule, ByRef Counts As ProjectSyntax.ProjectCounts, ByRef Info As ProjectManifest.ManifestInfo, ByRef Diagnostic As LoadDiagnostic, ByRef Token As Long) As Boolean
    Dim Manifest() As Byte
    Dim Root() As Byte
    Dim Relative() As Byte
    Dim Spans() As ProjectManifest.ValueSpan
    Dim NextInfo As ProjectManifest.ManifestInfo
    Dim NextCounts As ProjectSyntax.ProjectCounts
    Dim EmptyCounts As ProjectSyntax.ProjectCounts
    Dim EmptyDiagnostic As LoadDiagnostic
    Dim Index As Long
    Dim PathUsed As Long
    On Error GoTo RuntimeFailure
    Diagnostic = EmptyDiagnostic
    Diagnostic.Stage = 1
    Diagnostic.Code = 1
    Diagnostic.ModuleIndex = -1
    Diagnostic.Line = 1
    Diagnostic.Column = 1
    Diagnostic.Utf16Offset = 1
    If Token <> 0 Then Exit Function
    Counts = EmptyCounts
    Info.SourceCount = 0
    If IsManifestPath(ManifestPath) = False Then Exit Function
    If TryLoadManifest(ManifestPath, PackageName, Root, Manifest, Spans, NextInfo, Diagnostic, Token) = False Then Exit Function
    If ResizePaths(Paths, NextInfo.SourceCount, False) = False Then Exit Function
    If BufferPrimitives.TryResizeBytes(PathBytes, 0, False) = False Then Exit Function
    Do While Index < NextInfo.SourceCount
        Diagnostic.Stage = 9
        Diagnostic.Code = 8
        Diagnostic.ModuleIndex = Index
        Diagnostic.Line = Spans(Index).Line
        Diagnostic.Column = 1
        Diagnostic.PathStart = 0
        Diagnostic.PathLength = 0
        If ProjectManifest.TryCopyValue(Manifest, Spans(Index).Start, Spans(Index).Length, Relative) = False Then Exit Function
        If TryLoadSource(Root, Relative, Spans(Index).Line, Index, PathBytes, Paths, PathUsed, Bytes, Tokens, Nodes, Modules, NextCounts, Diagnostic, Token) = False Then Exit Function
        Index = Index + 1
    Loop
    Counts = NextCounts
    Info = NextInfo
    Diagnostic = EmptyDiagnostic
    Diagnostic.ModuleIndex = -1
    TryLoad = True
    Exit Function
RuntimeFailure:
    Diagnostic.Code = 12
    Exit Function
End Function

