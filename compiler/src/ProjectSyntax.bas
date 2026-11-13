UBE SOURCE 1 MODULE
Attribute UBE_Name = "ProjectSyntax"
Public Const MaximumProjectNodes As Long = 131072
' Retains module syntax in caller-owned flat arenas with committed logical prefixes.
Public Type ParsedModule
    ByteBase As Long
    ByteCount As Long
    TokenBase As Long
    TokenCount As Long
    NodeBase As Long
    NodeCount As Long
    RootNode As Long
    NameToken As Long
End Type

Public Type ProjectCounts
    ModuleCount As Long
    ByteCount As Long
    TokenCount As Long
    NodeCount As Long
End Type

Public Type ProjectDiagnostic
    Stage As Long
    Code As Long
    Reason As Long
    ModuleIndex As Long
    ByteOffset As Long
    Utf16Offset As Long
    [Line] As Long
    Column As Long
End Type

' Reads the physical token capacity independently of the published prefix.
Private Intrinsic Function TokenLength(ByRef Values() As SourceScanner.SourceToken) As Long
Attribute TokenLength.UBE_Primitive = "Array.Length"
End Function

' Reads the physical node capacity independently of the published prefix.
Private Intrinsic Function NodeLength(ByRef Values() As SourceParser.SyntaxNode) As Long
Attribute NodeLength.UBE_Primitive = "Array.Length"
End Function

' Reads the physical module capacity independently of the published prefix.
Private Intrinsic Function ModuleLength(ByRef Values() As ParsedModule) As Long
Attribute ModuleLength.UBE_Primitive = "Array.Length"
End Function

' Reserves tokens while retaining every committed element.
Private Intrinsic Function ResizeTokens(ByRef Values() As SourceScanner.SourceToken, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeTokens.UBE_Primitive = "Array.TryResize"
End Function

' Reserves nodes while retaining every committed element.
Private Intrinsic Function ResizeNodes(ByRef Values() As SourceParser.SyntaxNode, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeNodes.UBE_Primitive = "Array.TryResize"
End Function

' Reserves module records while retaining every committed element.
Private Intrinsic Function ResizeModules(ByRef Values() As ParsedModule, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeModules.UBE_Primitive = "Array.TryResize"
End Function

' Validates a bounded source span without overflowing its end position.
Private Function SpanFits(ByVal Start As Long, ByVal Length As Long, ByVal Base As Long, ByVal Count As Long) As Boolean
    If Start < Base Or Length < 0 Then Exit Function
    If Start - Base > Count Then Exit Function
    SpanFits = Length <= Count - (Start - Base)
End Function

' Accepts a missing tree link or a node owned by the specified module.
Private Function LinkFits(ByVal Link As Long, ByRef M As ParsedModule) As Boolean
    LinkFits = Link = 0 Or (Link > M.NodeBase And Link <= M.NodeBase + M.NodeCount)
End Function

' Checks finite arena spans without following potentially corrupt tree links.
Private Function ValidModule(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef M As ParsedModule) As Boolean
    Dim I As Long
    Dim Finish As Long
    On Error GoTo Failed
    If M.ByteCount <= 0 Or M.TokenCount < 2 Or M.NodeCount < 1 Or M.NodeCount > 65536 Then Exit Function
    If M.RootNode <> M.NodeBase + 1 Then Exit Function
    If M.NameToken < M.TokenBase Or M.NameToken >= M.TokenBase + M.TokenCount Then Exit Function
    If N(M.NodeBase).Kind <> SourceParser.ModuleNode Then Exit Function
    If N(M.NodeBase).NameToken <> M.NameToken Then Exit Function
    I = M.TokenBase
    Finish = I + M.TokenCount
    Do While I < Finish
        If T(I).Kind < 1 Or T(I).Kind > 7 Then Exit Function
        If T(I).Utf16Length < 0 Then Exit Function
        If T(I).Kind = SourceScanner.EndToken Then
            If I <> Finish - 1 Then Exit Function
        Else
            If I = Finish - 1 Then Exit Function
        End If
        If Not SpanFits(T(I).ByteStart, T(I).ByteLength, M.ByteBase, M.ByteCount) Then Exit Function
        If T(I).Line < 1 Or T(I).Column < 1 Or T(I).Utf16Start < 1 Then Exit Function
        I = I + 1
    Loop
    If Not SyntaxTokens.IsModuleNameToken(B, T, M.NameToken, Finish) Then Exit Function
    I = M.NodeBase
    Finish = I + M.NodeCount
    Do While I < Finish
        If N(I).Kind < 1 Or N(I).Kind > SourceParser.ThreadStartNode Then Exit Function
        If N(I).Utf16Start < 1 Or N(I).Utf16Length < 0 Or N(I).Line < 1 Or N(I).Column < 1 Then Exit Function
        If Not SpanFits(N(I).ByteStart, N(I).ByteLength, M.ByteBase, M.ByteCount) Then Exit Function
        If N(I).FirstToken < M.TokenBase Or N(I).FirstToken >= M.TokenBase + M.TokenCount Then Exit Function
        If N(I).LastToken < N(I).FirstToken - 1 Or N(I).LastToken >= M.TokenBase + M.TokenCount Then Exit Function
        If N(I).NameToken <> -1 Then
            If N(I).NameToken < M.TokenBase Or N(I).NameToken >= M.TokenBase + M.TokenCount Then Exit Function
        End If
        If N(I).TypeFirstToken <> -1 Then
            If N(I).TypeFirstToken < M.TokenBase Or N(I).TypeFirstToken >= M.TokenBase + M.TokenCount Then Exit Function
        End If
        If N(I).TypeLastToken <> -1 Then
            If N(I).TypeLastToken < M.TokenBase Or N(I).TypeLastToken >= M.TokenBase + M.TokenCount Then Exit Function
        End If
        If Not LinkFits(N(I).Parent, M) Then Exit Function
        If Not LinkFits(N(I).FirstChild, M) Then Exit Function
        If Not LinkFits(N(I).LastChild, M) Then Exit Function
        If Not LinkFits(N(I).NextSibling, M) Then Exit Function
        I = I + 1
    Loop
    ValidModule = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Checks zero-based physical storage and the contiguous committed module prefixes.
Public Function IsValidProject(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef M() As ParsedModule, ByRef C As ProjectCounts) As Boolean
    Dim I As Long
    Dim Size As Long
    Dim Probe As Long
    Dim Seen As ProjectCounts
    On Error GoTo Failed
    If C.ModuleCount < 0 Or C.ModuleCount > 128 Then Exit Function
    If C.ByteCount < 0 Or C.ByteCount > 1048576 Then Exit Function
    If C.TokenCount < 0 Or C.TokenCount > 262144 Then Exit Function
    If C.NodeCount < 0 Or C.NodeCount > MaximumProjectNodes Then Exit Function
    Size = BufferPrimitives.ByteStorageLength(B)
    If C.ByteCount > Size Then Exit Function
    If Size > 0 Then Probe = B(0): Probe = B(Size - 1)
    Size = TokenLength(T)
    If C.TokenCount > Size Then Exit Function
    If Size > 0 Then Probe = T(0).Kind: Probe = T(Size - 1).Kind
    Size = NodeLength(N)
    If C.NodeCount > Size Then Exit Function
    If Size > 0 Then Probe = N(0).Kind: Probe = N(Size - 1).Kind
    Size = ModuleLength(M)
    If C.ModuleCount > Size Then Exit Function
    If Size > 0 Then Probe = M(0).ByteBase: Probe = M(Size - 1).ByteBase
    Do While I < C.ModuleCount
        If M(I).ByteBase <> Seen.ByteCount Or M(I).TokenBase <> Seen.TokenCount Or M(I).NodeBase <> Seen.NodeCount Then Exit Function
        If M(I).ByteCount < 0 Or M(I).ByteCount > C.ByteCount - Seen.ByteCount Then Exit Function
        If M(I).TokenCount < 0 Or M(I).TokenCount > C.TokenCount - Seen.TokenCount Then Exit Function
        If M(I).NodeCount < 0 Or M(I).NodeCount > C.NodeCount - Seen.NodeCount Then Exit Function
        If Not ValidModule(B, T, N, M(I)) Then Exit Function
        Seen.ByteCount = Seen.ByteCount + M(I).ByteCount
        Seen.TokenCount = Seen.TokenCount + M(I).TokenCount
        Seen.NodeCount = Seen.NodeCount + M(I).NodeCount
        I = I + 1
    Loop
    IsValidProject = Seen.ByteCount = C.ByteCount And Seen.TokenCount = C.TokenCount And Seen.NodeCount = C.NodeCount
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Compares validated quoted ASCII module identities across separate byte arenas.
Private Function SameModule(ByRef A() As Byte, ByRef AT() As SourceScanner.SourceToken, ByVal AI As Long, ByRef B() As Byte, ByRef BT() As SourceScanner.SourceToken, ByVal BI As Long) As Boolean
    Dim I As Long
    Dim LeftCode As Long
    Dim RightCode As Long
    On Error GoTo Failed
    If AT(AI).ByteLength <> BT(BI).ByteLength Then Exit Function
    Do While I < AT(AI).ByteLength - 2
        LeftCode = SyntaxTokens.SpellingByte(A, AT, AI, AI + 1, I)
        RightCode = SyntaxTokens.SpellingByte(B, BT, BI, BI + 1, I)
        If LeftCode <> RightCode Then Exit Function
        I = I + 1
    Loop
    SameModule = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Reserves each arena before any logical prefix is extended; capacity changes are allowed on failure.
Private Function Reserve(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef M() As ParsedModule, ByRef C As ProjectCounts, ByRef Added As ParsedModule) As Boolean
    On Error GoTo Failed
    If BufferPrimitives.ByteStorageLength(B) < C.ByteCount + Added.ByteCount Then
        If Not BufferPrimitives.TryResizeBytes(B, C.ByteCount + Added.ByteCount, True) Then Exit Function
    End If
    If TokenLength(T) < C.TokenCount + Added.TokenCount Then
        If Not ResizeTokens(T, C.TokenCount + Added.TokenCount, True) Then Exit Function
    End If
    If NodeLength(N) < C.NodeCount + Added.NodeCount Then
        If Not ResizeNodes(N, C.NodeCount + Added.NodeCount, True) Then Exit Function
    End If
    If ModuleLength(M) < C.ModuleCount + 1 Then
        If Not ResizeModules(M, C.ModuleCount + 1, True) Then Exit Function
    End If
    Reserve = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Rebases one candidate node, preserving absent token sentinels and local physical coordinates.
Private Sub RebaseNode(ByRef N As SourceParser.SyntaxNode, ByRef M As ParsedModule)
    On Error GoTo Failed
    N.ByteStart = N.ByteStart + M.ByteBase
    N.FirstToken = N.FirstToken + M.TokenBase
    N.LastToken = N.LastToken + M.TokenBase
    If N.NameToken >= 0 Then N.NameToken = N.NameToken + M.TokenBase
    If N.TypeFirstToken >= 0 Then N.TypeFirstToken = N.TypeFirstToken + M.TokenBase
    If N.TypeLastToken >= 0 Then N.TypeLastToken = N.TypeLastToken + M.TokenBase
    If N.Parent > 0 Then N.Parent = N.Parent + M.NodeBase
    If N.FirstChild > 0 Then N.FirstChild = N.FirstChild + M.NodeBase
    If N.LastChild > 0 Then N.LastChild = N.LastChild + M.NodeBase
    If N.NextSibling > 0 Then N.NextSibling = N.NextSibling + M.NodeBase
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

' Appends a parsed module and publishes counts only after every source span and identity is retained.
Public Function TryAppendModule(ByRef Source() As Byte, ByRef Bytes() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByRef Nodes() As SourceParser.SyntaxNode, ByRef Modules() As ParsedModule, ByRef Counts As ProjectCounts, ByRef Diagnostic As ProjectDiagnostic) As Boolean
    Dim CandidateTokens() As SourceScanner.SourceToken
    Dim CandidateNodes() As SourceParser.SyntaxNode
    Dim ScanError As SourceScanner.ScanDiagnostic
    Dim ParseError As SourceParser.ParseDiagnostic
    Dim Added As ParsedModule
    Dim I As Long
    On Error GoTo Failed
    Diagnostic.Stage = 3
    Diagnostic.Code = 6
    Diagnostic.Reason = 1
    Diagnostic.ModuleIndex = Counts.ModuleCount
    Diagnostic.ByteOffset = 0
    Diagnostic.Utf16Offset = 1
    Diagnostic.Line = 1
    Diagnostic.Column = 1
    If Not IsValidProject(Bytes, Tokens, Nodes, Modules, Counts) Then Exit Function
    Added.ByteCount = BufferPrimitives.ByteStorageLength(Source)
    If Not SourceScanner.TryScan(Source, CandidateTokens, Added.TokenCount, ScanError) Then
        Diagnostic.Stage = 1
        Diagnostic.Code = ScanError.Code
        Diagnostic.Reason = ScanError.Reason
        Diagnostic.ByteOffset = ScanError.ByteOffset
        Diagnostic.Utf16Offset = ScanError.Utf16Offset
        Diagnostic.Line = ScanError.Line
        Diagnostic.Column = ScanError.Column
        Exit Function
    End If
    If Not SourceParser.TryParseModule(Source, CandidateTokens, Added.TokenCount, CandidateNodes, Added.NodeCount, Added.RootNode, ParseError) Then
        Diagnostic.Stage = 2
        Diagnostic.Code = ParseError.Code
        Diagnostic.Reason = ParseError.Reason
        Diagnostic.ByteOffset = ParseError.ByteOffset
        Diagnostic.Utf16Offset = ParseError.Utf16Offset
        Diagnostic.Line = ParseError.Line
        Diagnostic.Column = ParseError.Column
        Exit Function
    End If
    Added.NameToken = CandidateNodes(Added.RootNode - 1).NameToken
    Diagnostic.Code = 3
    Do While I < Counts.ModuleCount
        If SameModule(Source, CandidateTokens, Added.NameToken, Bytes, Tokens, Modules(I).NameToken) Then Exit Function
        I = I + 1
    Loop
    Diagnostic.Code = 4
    If Counts.ModuleCount >= 128 Then Exit Function
    If Added.ByteCount > 1048576 - Counts.ByteCount Then Exit Function
    If Added.TokenCount > 262144 - Counts.TokenCount Then Exit Function
    If Added.NodeCount > MaximumProjectNodes - Counts.NodeCount Then Exit Function
    Diagnostic.Code = 5
    If Not Reserve(Bytes, Tokens, Nodes, Modules, Counts, Added) Then Exit Function
    Added.ByteBase = Counts.ByteCount
    Added.TokenBase = Counts.TokenCount
    Added.NodeBase = Counts.NodeCount
    If Not BufferPrimitives.CopyByteRange(Source, 0, Bytes, Added.ByteBase, Added.ByteCount) Then GoTo Failed
    I = 0
    Do While I < Added.TokenCount
        CandidateTokens(I).ByteStart = CandidateTokens(I).ByteStart + Added.ByteBase
        Tokens(Added.TokenBase + I) = CandidateTokens(I)
        I = I + 1
    Loop
    I = 0
    Do While I < Added.NodeCount
        RebaseNode CandidateNodes(I), Added
        Nodes(Added.NodeBase + I) = CandidateNodes(I)
        I = I + 1
    Loop
    Added.RootNode = Added.RootNode + Added.NodeBase
    Added.NameToken = Added.NameToken + Added.TokenBase
    Modules(Counts.ModuleCount) = Added
    Counts.ByteCount = Counts.ByteCount + Added.ByteCount
    Counts.TokenCount = Counts.TokenCount + Added.TokenCount
    Counts.NodeCount = Counts.NodeCount + Added.NodeCount
    Counts.ModuleCount = Counts.ModuleCount + 1
    Diagnostic.Code = 0
    Diagnostic.Reason = 0
    TryAppendModule = True
    Exit Function
Failed:
    Diagnostic.Stage = 3
    Diagnostic.Code = 6
    Diagnostic.Reason = 2
    Diagnostic.ByteOffset = 0
    Diagnostic.Utf16Offset = 1
    Diagnostic.Line = 1
    Diagnostic.Column = 1
End Function
