UBE SOURCE 1 MODULE
Attribute UBE_Name = "ContextLoadingProbe"
Private Const Control As Long = 0
Private ManifestPath() As Byte
Private SecondPath() As Byte
Private SpoofPath() As Byte
Private FirstPath() As Byte
Private Gate As RequestGate
Private Ready As Long
Private Released As Boolean

Private Function ReadSource(ByRef Path() As Byte, ByRef Source() As Byte) As Boolean
    Dim Token As Long
    Dim Failure As Long
    On Error GoTo Failed
    ReadSource = FileBytes.TryReadAllBytes(Path, 10000, Source, Token, Failure)
    Exit Function
Failed:
    ReadSource = False
End Function

' Checks original coordinates and values in the retained tokens, not a parallel selector.
Private Function Inspect(ByRef Bytes() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByRef Modules() As ProjectSyntax.ParsedModule, ByRef Counts As ProjectSyntax.ProjectCounts, ByVal Hosted As Boolean, ByRef Actual As Long) As Boolean
    Dim Index As Long
    Dim Token As Long
    Dim Found As Long
    Dim Expected As Long
    Dim ExpectedLine As Long = 7
    Dim ExpectedByte As Long = FALSE_BYTE
    Dim ExpectedUnit As Long = FALSE_UNIT
    Dim Difference As Long
    On Error GoTo Failed
    If Hosted Then
        Expected = 1
        ExpectedLine = 5
        ExpectedByte = TRUE_BYTE
        ExpectedUnit = TRUE_UNIT
    End If
    For Index = 0 To Counts.ModuleCount - 1
        If Modules(Index).IsInIDE <> Hosted Then Exit Function
        Difference = Modules(Index).ByteCount - FIRST_LENGTH
        Found = 0
        For Token = Modules(Index).TokenBase To Modules(Index).TokenBase + Modules(Index).TokenCount - 1
            If Tokens(Token).Kind = SourceScanner.NumberToken And Tokens(Token).Line > 2 Then
                Found = Found + 1
                Actual = Bytes(Tokens(Token).ByteStart) - 48
                If Actual <> Expected + Control Then Exit Function
                If Tokens(Token).Line <> ExpectedLine Or Tokens(Token).Column <> VALUE_COLUMN Then Exit Function
                If Tokens(Token).ByteStart <> Modules(Index).ByteBase + ExpectedByte + Difference Then Exit Function
                If Tokens(Token).Utf16Start <> ExpectedUnit + Difference Then Exit Function
            End If
        Next
        If Found <> 1 Then Exit Function
    Next
    Inspect = True
    Exit Function
Failed:
    Inspect = False
End Function

' Tests explicit/default loading and append inheritance using request-local arenas.
Private Function CheckRequest(ByVal Hosted As Boolean, ByVal UseDefault As Boolean, ByVal Appends As Boolean, ByRef Actual As Long) As Boolean
    Dim Package() As Byte
    Dim Paths() As ProjectLoader.SourcePath
    Dim PathBytes() As Byte
    Dim Bytes() As Byte
    Dim Tokens() As SourceScanner.SourceToken
    Dim Nodes() As SourceParser.SyntaxNode
    Dim Modules() As ProjectSyntax.ParsedModule
    Dim Counts As ProjectSyntax.ProjectCounts
    Dim Saved As ProjectSyntax.ProjectCounts
    Dim Info As ProjectManifest.ManifestInfo
    Dim Diagnostic As ProjectLoader.LoadDiagnostic
    Dim ParseError As ProjectSyntax.ProjectDiagnostic
    Dim Source() As Byte
    Dim Token As Long
    Dim Status As Boolean
    On Error GoTo Failed
    If UseDefault Then
        Status = ProjectLoader.TryLoad(ManifestPath, Package, PathBytes, Paths, Bytes, Tokens, Nodes, Modules, Counts, Info, Diagnostic, Token)
    Else
        Status = ProjectLoader.TryLoadWithContext(ManifestPath, Hosted, Package, PathBytes, Paths, Bytes, Tokens, Nodes, Modules, Counts, Info, Diagnostic, Token)
    End If
    If Not Status Or Token <> 0 Or Counts.ModuleCount <> 1 Or Info.SourceCount <> 1 Then Exit Function
    If Modules(0).ByteCount <> FIRST_LENGTH Then Exit Function
    If Not Inspect(Bytes, Tokens, Modules, Counts, Hosted, Actual) Then Exit Function
    If Appends Then
        If Not ReadSource(SecondPath, Source) Then Exit Function
        Saved = Counts
        If ProjectSyntax.TryAppendModuleWithContext(Source, 0, Not Hosted, Bytes, Tokens, Nodes, Modules, Counts, ParseError) Then Exit Function
        If ParseError.Stage <> 3 Or ParseError.Code <> 6 Or ParseError.Reason <> 1 Then Exit Function
        If Counts.ModuleCount <> Saved.ModuleCount Or Counts.NodeCount <> Saved.NodeCount Or Counts.TokenCount <> Saved.TokenCount Or Counts.ByteCount <> Saved.ByteCount Then Exit Function
        If Not Inspect(Bytes, Tokens, Modules, Counts, Hosted, Actual) Then Exit Function
        If Not ProjectSyntax.TryAppendModule(Source, Bytes, Tokens, Nodes, Modules, Counts, ParseError) Then Exit Function
        If Counts.ModuleCount <> 2 Or Modules(1).LookupDomain <> 0 Then Exit Function
        If Modules(1).ByteCount <> FIRST_LENGTH + 1 Then Exit Function
        If Not Inspect(Bytes, Tokens, Modules, Counts, Hosted, Actual) Then Exit Function
        If Not ProjectSyntax.TryAppendModuleInDomain(Source, 1, Bytes, Tokens, Nodes, Modules, Counts, ParseError) Then Exit Function
        If Counts.ModuleCount <> 3 Or Modules(2).LookupDomain <> 1 Then Exit Function
        If Not Inspect(Bytes, Tokens, Modules, Counts, Hosted, Actual) Then Exit Function
        Saved = Counts
        If Not ReadSource(SpoofPath, Source) Then Exit Function
        If ProjectSyntax.TryAppendModule(Source, Bytes, Tokens, Nodes, Modules, Counts, ParseError) Then Exit Function
        If ParseError.Stage <> 1 Or ParseError.Code <> 2 Or ParseError.Reason <> 3 Then Exit Function
        If ParseError.Line <> 3 Or ParseError.Column <> 1 Then Exit Function
        If ParseError.ByteOffset <> SPOOF_BYTE Then Exit Function
        If Counts.ModuleCount <> Saved.ModuleCount Or Counts.NodeCount <> Saved.NodeCount Or Counts.TokenCount <> Saved.TokenCount Or Counts.ByteCount <> Saved.ByteCount Then Exit Function
        If Not Inspect(Bytes, Tokens, Modules, Counts, Hosted, Actual) Then Exit Function
    End If
    CheckRequest = True
    Exit Function
Failed:
    CheckRequest = False
End Function

Private Function ParsedDefault() As Boolean
    Dim Source() As Byte
    Dim Bytes() As Byte
    Dim Tokens() As SourceScanner.SourceToken
    Dim Nodes() As SourceParser.SyntaxNode
    Dim Modules() As ProjectSyntax.ParsedModule
    Dim Counts As ProjectSyntax.ProjectCounts
    Dim Diagnostic As ProjectSyntax.ProjectDiagnostic
    Dim Actual As Long = -1
    On Error GoTo Failed
    If Not ReadSource(FirstPath, Source) Then Exit Function
    If Not ProjectSyntax.TryAppendModule(Source, Bytes, Tokens, Nodes, Modules, Counts, Diagnostic) Then Exit Function
    If Counts.ModuleCount <> 1 Then Exit Function
    ParsedDefault = Inspect(Bytes, Tokens, Modules, Counts, False, Actual)
    Exit Function
Failed:
    ParsedDefault = False
End Function

Private Sub RunRequest(ByVal Hosted As Boolean, ByRef Result As Long)
    Dim GateOpen As Boolean
    Dim Attempts As Long
    Dim Round As Long
    Dim Actual As Long = -1
    On Error GoTo Failed
    Result = -1
    SyncLock Gate
        Ready = Ready + 1
    End SyncLock
    Do While Attempts < 100000
        SyncLock Gate
            GateOpen = Released
        End SyncLock
        If GateOpen Then Exit Do
        ThreadPrimitives.Yield
        Attempts = Attempts + 1
    Loop
    If Not GateOpen Then Exit Sub
    Err.Clear
    For Round = 1 To 8
        If Not CheckRequest(Hosted, False, False, Actual) Then Exit Sub
        If Err.Number <> 0 Then Exit Sub
    Next
    Result = 100 + Actual
    Exit Sub
Failed:
    Result = -2
End Sub

Private Function ParallelRequests() As Boolean
    Dim First As LongLong
    Dim Second As LongLong
    Dim FalseResult As Long = -1
    Dim TrueResult As Long = -1
    Dim Observed As Long
    Dim Attempts As Long
    Dim Waited As Long
    On Error GoTo Failed
    Set Gate = New RequestGate
    First = CallNew RunRequest(False, FalseResult)
    Second = CallNew RunRequest(True, TrueResult)
    Do While Attempts < 100000
        SyncLock Gate
            Observed = Ready
        End SyncLock
        If Observed = 2 Then Exit Do
        ThreadPrimitives.Yield
        Attempts = Attempts + 1
    Loop
    SyncLock Gate
        Released = True
    End SyncLock
    Waited = ThreadPrimitives.Wait(First, 30000)
    If Waited <> 1 Then Exit Function
    Waited = ThreadPrimitives.Wait(Second, 30000)
    If Waited <> 1 Then Exit Function
    If Observed <> 2 Or FalseResult <> 100 Or TrueResult <> 101 Then Exit Function
    ParallelRequests = True
    Exit Function
Failed:
    ParallelRequests = False
End Function

Private Function UnexpectedFailure() As Boolean
    Err.Raise 53
End Function

Public Function Main() As Long
    Dim Passed As Boolean
    Dim Actual As Long
    On Error GoTo Failed
    ConfigurePath ManifestPath, 0
    ConfigurePath SecondPath, 1
    ConfigurePath SpoofPath, 2
    ConfigurePath FirstPath, 3
    Main = 1
    Passed = ParsedDefault()
    If Not Passed Then Exit Function
    Passed = False
    Passed = CheckRequest(False, True, True, Actual)
    If Not Passed Then Exit Function
    Main = 2
    Passed = False
    Passed = CheckRequest(True, False, True, Actual)
    If Not Passed Then Exit Function
    Main = 3
    Passed = False
    Passed = CheckRequest(False, False, True, Actual)
    If Not Passed Then Exit Function
    Main = 4
    Passed = False
    Passed = ParallelRequests()
    If Not Passed Then Exit Function
    Main = 0
    Exit Function
Failed:
    Main = 99
End Function

' GENERATED PATHS
