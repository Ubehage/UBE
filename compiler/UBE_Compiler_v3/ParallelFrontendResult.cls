UBE SOURCE 1 CLASS
Attribute UBE_Name = "ParallelFrontendResult"

Public SourceId As Long
Public SourceFilePath As String
Public SourceContents As String
Public SourceCombinedStartByte As Long
Public SourceByteLength As Long
Public SourceReferenceDepth As Long
Public Tokens() As LexicalToken
Public TokenCount As Long
Public TokenCapacity As Long
Public SyntaxNodes() As SyntaxNode
Public SyntaxNodeCount As Long
Public SyntaxNodeCapacity As Long
Public SyntaxLinks() As SyntaxChildLink
Public SyntaxLinkCount As Long
Public SyntaxLinkCapacity As Long
Public Diagnostics() As CompilerDiagnostic
Public DiagnosticCount As Long
Public DiagnosticCapacity As Long
Public Completed As Long
Public ParseRequested As Long
Public PublishTokens As Long

Public Sub SetSource(ByVal Source As SourceDocument)
    SourceId = Source.SourceId
    SourceFilePath = Source.FilePath
    SourceContents = Source.Contents
    SourceCombinedStartByte = Source.CombinedStartByte
    SourceByteLength = Source.ByteLength
    SourceReferenceDepth = Source.ReferenceDepth
End Sub

Public Sub ResetResult()
    TokenCount = 0
    SyntaxNodeCount = 0
    SyntaxLinkCount = 0
    DiagnosticCount = 0
    Completed = 0
End Sub

Public Sub StoreWorkerResult(ByRef SourceTokens() As LexicalToken, ByVal SourceTokenCount As Long, ByRef SourceSyntaxNodes() As SyntaxNode, ByVal SourceSyntaxNodeCount As Long, ByRef SourceSyntaxLinks() As SyntaxChildLink, ByVal SourceSyntaxLinkCount As Long, ByRef SourceDiagnostics() As CompilerDiagnostic, ByVal SourceDiagnosticCount As Long)
    TokenCount = 0
    TokenCapacity = 0
    Dim Index As Long = 0
    If PublishTokens <> 0 Then
        TokenCount = SourceTokenCount
        TokenCapacity = TokenCount
        If TokenCount > 0 Then
            ReDim Tokens(TokenCount - 1)
        End If
        While Index < TokenCount
            Tokens(Index).TokenKind = SourceTokens(Index).TokenKind
            Tokens(Index).SourceId = SourceTokens(Index).SourceId
            Tokens(Index).StartByte = SourceTokens(Index).StartByte
            Tokens(Index).ByteLength = SourceTokens(Index).ByteLength
            Tokens(Index).LineNumber = SourceTokens(Index).LineNumber
            Tokens(Index).ColumnNumber = SourceTokens(Index).ColumnNumber
            Tokens(Index).Spelling = SourceTokens(Index).Spelling
            Tokens(Index).Decoded = SourceTokens(Index).Decoded
            Index = Index + 1
        Wend
    End If
    SyntaxNodeCount = SourceSyntaxNodeCount
    SyntaxNodeCapacity = SyntaxNodeCount
    If SyntaxNodeCount > 0 Then
        ReDim SyntaxNodes(SyntaxNodeCount - 1)
    End If
    Index = 0
    While Index < SyntaxNodeCount
        SyntaxNodes(Index).StableId = SourceSyntaxNodes(Index).StableId
        SyntaxNodes(Index).ProductionRule = SourceSyntaxNodes(Index).ProductionRule
        SyntaxNodes(Index).SourceId = SourceSyntaxNodes(Index).SourceId
        SyntaxNodes(Index).FirstToken = SourceSyntaxNodes(Index).FirstToken
        SyntaxNodes(Index).LastToken = SourceSyntaxNodes(Index).LastToken
        SyntaxNodes(Index).ParentNode = SourceSyntaxNodes(Index).ParentNode
        SyntaxNodes(Index).FirstChildLink = SourceSyntaxNodes(Index).FirstChildLink
        SyntaxNodes(Index).LastChildLink = SourceSyntaxNodes(Index).LastChildLink
        SyntaxNodes(Index).ChildCount = SourceSyntaxNodes(Index).ChildCount
        Index = Index + 1
    Wend
    SyntaxLinkCount = SourceSyntaxLinkCount
    SyntaxLinkCapacity = SyntaxLinkCount
    If SyntaxLinkCount > 0 Then
        ReDim SyntaxLinks(SyntaxLinkCount - 1)
    End If
    Index = 0
    While Index < SyntaxLinkCount
        SyntaxLinks(Index).NodeIndex = SourceSyntaxLinks(Index).NodeIndex
        SyntaxLinks(Index).NextLink = SourceSyntaxLinks(Index).NextLink
        Index = Index + 1
    Wend
    DiagnosticCount = SourceDiagnosticCount
    DiagnosticCapacity = DiagnosticCount
    If DiagnosticCount > 0 Then
        ReDim Diagnostics(DiagnosticCount - 1)
    End If
    Index = 0
    While Index < DiagnosticCount
        Diagnostics(Index).Code = SourceDiagnostics(Index).Code
        Diagnostics(Index).FilePath = SourceDiagnostics(Index).FilePath
        Diagnostics(Index).LineNumber = SourceDiagnostics(Index).LineNumber
        Diagnostics(Index).ColumnNumber = SourceDiagnostics(Index).ColumnNumber
        Diagnostics(Index).Message = SourceDiagnostics(Index).Message
        Index = Index + 1
    Wend
    Completed = 1
End Sub

Public Sub MergeDiagnostics(ByRef Target() As CompilerDiagnostic, ByRef TargetCount As Long, ByRef TargetCapacity As Long)
    Dim Index As Long = 0
    While Index < DiagnosticCount
        Call AddDiagnostic(Target, TargetCount, TargetCapacity, Diagnostics(Index).Code, Diagnostics(Index).FilePath, Diagnostics(Index).LineNumber, Diagnostics(Index).ColumnNumber, Diagnostics(Index).Message)
        Index = Index + 1
    Wend
End Sub

Public Sub CopyTokens(ByRef Target() As LexicalToken, ByRef TargetCount As Long)
    Dim Index As Long = 0
    While Index < TokenCount
        Target(TargetCount).TokenKind = Tokens(Index).TokenKind
        Target(TargetCount).SourceId = Tokens(Index).SourceId
        Target(TargetCount).StartByte = Tokens(Index).StartByte
        Target(TargetCount).ByteLength = Tokens(Index).ByteLength
        Target(TargetCount).LineNumber = Tokens(Index).LineNumber
        Target(TargetCount).ColumnNumber = Tokens(Index).ColumnNumber
        Target(TargetCount).Spelling = Tokens(Index).Spelling
        Target(TargetCount).Decoded = Tokens(Index).Decoded
        TargetCount = TargetCount + 1
        Index = Index + 1
    Wend
End Sub

Public Sub CopySyntax(ByRef TargetNodes() As SyntaxNode, ByRef TargetNodeCount As Long, ByRef TargetLinks() As SyntaxChildLink, ByRef TargetLinkCount As Long, ByVal TokenBase As Long)
    Dim NodeBase As Long = TargetNodeCount
    Dim LinkBase As Long = TargetLinkCount
    Dim Index As Long = 0
    While Index < SyntaxNodeCount
        TargetNodes(TargetNodeCount).ProductionRule = SyntaxNodes(Index).ProductionRule
        TargetNodes(TargetNodeCount).SourceId = SyntaxNodes(Index).SourceId
        TargetNodes(TargetNodeCount).FirstToken = SyntaxNodes(Index).FirstToken
        TargetNodes(TargetNodeCount).LastToken = SyntaxNodes(Index).LastToken
        TargetNodes(TargetNodeCount).ParentNode = SyntaxNodes(Index).ParentNode
        TargetNodes(TargetNodeCount).FirstChildLink = SyntaxNodes(Index).FirstChildLink
        TargetNodes(TargetNodeCount).LastChildLink = SyntaxNodes(Index).LastChildLink
        TargetNodes(TargetNodeCount).ChildCount = SyntaxNodes(Index).ChildCount
        TargetNodes(TargetNodeCount).StableId = TargetNodeCount + 1
        If TargetNodes(TargetNodeCount).ParentNode >= 0 Then
            TargetNodes(TargetNodeCount).ParentNode = TargetNodes(TargetNodeCount).ParentNode + NodeBase
        End If
        If TargetNodes(TargetNodeCount).FirstChildLink >= 0 Then
            TargetNodes(TargetNodeCount).FirstChildLink = TargetNodes(TargetNodeCount).FirstChildLink + LinkBase
        End If
        If TargetNodes(TargetNodeCount).LastChildLink >= 0 Then
            TargetNodes(TargetNodeCount).LastChildLink = TargetNodes(TargetNodeCount).LastChildLink + LinkBase
        End If
        If TargetNodes(TargetNodeCount).FirstToken >= 0 Then
            TargetNodes(TargetNodeCount).FirstToken = TargetNodes(TargetNodeCount).FirstToken + TokenBase
        End If
        If TargetNodes(TargetNodeCount).LastToken >= 0 Then
            TargetNodes(TargetNodeCount).LastToken = TargetNodes(TargetNodeCount).LastToken + TokenBase
        End If
        TargetNodeCount = TargetNodeCount + 1
        Index = Index + 1
    Wend
    Index = 0
    While Index < SyntaxLinkCount
        TargetLinks(TargetLinkCount).NodeIndex = SyntaxLinks(Index).NodeIndex
        TargetLinks(TargetLinkCount).NextLink = SyntaxLinks(Index).NextLink
        TargetLinks(TargetLinkCount).NodeIndex = TargetLinks(TargetLinkCount).NodeIndex + NodeBase
        If TargetLinks(TargetLinkCount).NextLink >= 0 Then
            TargetLinks(TargetLinkCount).NextLink = TargetLinks(TargetLinkCount).NextLink + LinkBase
        End If
        TargetLinkCount = TargetLinkCount + 1
        Index = Index + 1
    Wend
End Sub
