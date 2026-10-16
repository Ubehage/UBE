UBE SOURCE 1 MODULE
Attribute UBE_Name = "SyntaxQuery"

Function SyntaxRuleIs(ByVal NodeIndex As Long, ByVal RuleName As String, ByRef SyntaxNodes() As SyntaxNode, ByRef Rules() As GrammarRule) As Long
    If NodeIndex < 0 Then
        SyntaxRuleIs = 0
        Exit Function
    End If
    SyntaxRuleIs = EqualsFolded(Rules(SyntaxNodes(NodeIndex).ProductionRule).RuleName, RuleName)
End Function

Function FirstDirectSyntaxChild(ByVal ParentNode As Long, ByVal RuleName As String, ByRef SyntaxNodes() As SyntaxNode, ByRef SyntaxLinks() As SyntaxChildLink, ByRef Rules() As GrammarRule) As Long
    Dim LinkIndex As Long = SyntaxNodes(ParentNode).FirstChildLink
    While LinkIndex >= 0
        Dim ChildNode As Long = SyntaxLinks(LinkIndex).NodeIndex
        If SyntaxRuleIs(ChildNode, RuleName, SyntaxNodes, Rules) <> 0 Then
            FirstDirectSyntaxChild = ChildNode
            Exit Function
        End If
        LinkIndex = SyntaxLinks(LinkIndex).NextLink
    Wend
    FirstDirectSyntaxChild = -1
End Function

Function FirstDescendantSyntaxNode(ByVal ParentNode As Long, ByVal RuleName As String, ByRef SyntaxNodes() As SyntaxNode, ByRef SyntaxLinks() As SyntaxChildLink, ByRef Rules() As GrammarRule, ByVal Depth As Long) As Long
    If Depth > LimitSemanticDepth() Then
        FirstDescendantSyntaxNode = -1
        Exit Function
    End If
    Dim LinkIndex As Long = SyntaxNodes(ParentNode).FirstChildLink
    While LinkIndex >= 0
        Dim ChildNode As Long = SyntaxLinks(LinkIndex).NodeIndex
        If SyntaxRuleIs(ChildNode, RuleName, SyntaxNodes, Rules) <> 0 Then
            FirstDescendantSyntaxNode = ChildNode
            Exit Function
        End If
        Dim NestedNode As Long = FirstDescendantSyntaxNode(ChildNode, RuleName, SyntaxNodes, SyntaxLinks, Rules, Depth + 1)
        If NestedNode >= 0 Then
            FirstDescendantSyntaxNode = NestedNode
            Exit Function
        End If
        LinkIndex = SyntaxLinks(LinkIndex).NextLink
    Wend
    FirstDescendantSyntaxNode = -1
End Function

Function SyntaxNodeTokenText(ByVal NodeIndex As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken) As String
    If NodeIndex < 0 Or SyntaxNodes(NodeIndex).FirstToken < 0 Then
        SyntaxNodeTokenText = ""
        Exit Function
    End If
    Dim TokenIndex As Long = SyntaxNodes(NodeIndex).FirstToken
    If Tokens(TokenIndex).TokenKind = 3 Then
        SyntaxNodeTokenText = Tokens(TokenIndex).Decoded
    Else
        SyntaxNodeTokenText = Tokens(TokenIndex).Spelling
    End If
End Function

Function SyntaxIdentifierName(ByVal ParentNode As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef SyntaxLinks() As SyntaxChildLink, ByRef Rules() As GrammarRule, ByRef Tokens() As LexicalToken) As String
    Dim IdentifierNode As Long = FirstDescendantSyntaxNode(ParentNode, "identifier", SyntaxNodes, SyntaxLinks, Rules, 0)
    SyntaxIdentifierName = SyntaxNodeTokenText(IdentifierNode, SyntaxNodes, Tokens)
End Function

Function SyntaxNodeContainsToken(ByVal NodeIndex As Long, ByVal Value As String, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken) As Long
    Dim TokenIndex As Long = SyntaxNodes(NodeIndex).FirstToken
    While TokenIndex <= SyntaxNodes(NodeIndex).LastToken
        If EqualsFolded(Tokens(TokenIndex).Spelling, Value) <> 0 Then
            SyntaxNodeContainsToken = 1
            Exit Function
        End If
        TokenIndex = TokenIndex + 1
    Wend
    SyntaxNodeContainsToken = 0
End Function

Function SyntaxNodeSourceByte(ByVal NodeIndex As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken) As Long
    If NodeIndex < 0 Or SyntaxNodes(NodeIndex).FirstToken < 0 Then
        SyntaxNodeSourceByte = 0
    Else
        SyntaxNodeSourceByte = Tokens(SyntaxNodes(NodeIndex).FirstToken).StartByte
    End If
End Function

Function SyntaxNodeLine(ByVal NodeIndex As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken) As Long
    If NodeIndex < 0 Or SyntaxNodes(NodeIndex).FirstToken < 0 Then
        SyntaxNodeLine = 1
    Else
        SyntaxNodeLine = Tokens(SyntaxNodes(NodeIndex).FirstToken).LineNumber
    End If
End Function

Function SyntaxNodeColumn(ByVal NodeIndex As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken) As Long
    If NodeIndex < 0 Or SyntaxNodes(NodeIndex).FirstToken < 0 Then
        SyntaxNodeColumn = 1
    Else
        SyntaxNodeColumn = Tokens(SyntaxNodes(NodeIndex).FirstToken).ColumnNumber
    End If
End Function
