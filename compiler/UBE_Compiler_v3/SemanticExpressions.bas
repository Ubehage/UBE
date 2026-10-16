UBE SOURCE 1 MODULE
Attribute UBE_Name = "SemanticExpressions"

Function ValidateDecimalConstant(ByVal DigitText As String) As Long
    Dim Length As Long = StringLength(DigitText)
    If Length = 0 Or Length > 19 Then
        ValidateDecimalConstant = 0
        Exit Function
    End If
    If Length = 19 Then
        If DigitText > "9223372036854775807" Then
            ValidateDecimalConstant = 0
            Exit Function
        End If
    End If
    Dim Index As Long = 0
    While Index < Length
        Dim Digit As Long = StringByteAt(DigitText, Index) - 48
        If Digit < 0 Or Digit > 9 Then
            ValidateDecimalConstant = 0
            Exit Function
        End If
        Index = Index + 1
    Wend
    ValidateDecimalConstant = 1
End Function

Function LiteralExpressionType(ByVal NodeIndex As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken, ByRef Types() As SemanticType, ByVal TypeCount As Long) As Long
    Dim TokenIndex As Long = SyntaxNodes(NodeIndex).FirstToken
    While TokenIndex <= SyntaxNodes(NodeIndex).LastToken
        If Tokens(TokenIndex).TokenKind = 6 Then
            LiteralExpressionType = FindSemanticType("String", Types, TypeCount)
            Exit Function
        End If
        If Tokens(TokenIndex).TokenKind = 7 Then
            LiteralExpressionType = FindSemanticType("Date", Types, TypeCount)
            Exit Function
        End If
        If Tokens(TokenIndex).TokenKind = 5 Then
            LiteralExpressionType = FindSemanticType("Double", Types, TypeCount)
            Exit Function
        End If
        If Tokens(TokenIndex).TokenKind = 4 Then
            LiteralExpressionType = FindSemanticType("LongLong", Types, TypeCount)
            Exit Function
        End If
        If EqualsFolded(Tokens(TokenIndex).Spelling, "True") <> 0 Or EqualsFolded(Tokens(TokenIndex).Spelling, "False") <> 0 Then
            LiteralExpressionType = FindSemanticType("Boolean", Types, TypeCount)
            Exit Function
        End If
        If EqualsFolded(Tokens(TokenIndex).Spelling, "Null") <> 0 Then
            LiteralExpressionType = FindSemanticType("Null", Types, TypeCount)
            Exit Function
        End If
        TokenIndex = TokenIndex + 1
    Wend
    LiteralExpressionType = -1
End Function

Function AnalyzeExpressions(ByRef Sources() As SourceDocument, ByRef SyntaxNodes() As SyntaxNode, ByVal SyntaxNodeCount As Long, ByRef SyntaxLinks() As SyntaxChildLink, ByRef Rules() As GrammarRule, ByRef Tokens() As LexicalToken, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef State As SemanticState, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    State.ExpressionCount = 0
    State.TypedExpressionCount = 0
    Dim NodeTypes() As Long
    ReDim NodeTypes(SyntaxNodeCount - 1)
    Dim NodeIndex As Long = 0
    While NodeIndex < SyntaxNodeCount
        NodeTypes(NodeIndex) = -1
        NodeIndex = NodeIndex + 1
    Wend
    NodeIndex = SyntaxNodeCount - 1
    While NodeIndex >= 0
        If SyntaxRuleIs(NodeIndex, "expression", SyntaxNodes, Rules) <> 0 Then
            State.ExpressionCount = State.ExpressionCount + 1
            Dim ExpressionType As Long = LiteralExpressionType(NodeIndex, SyntaxNodes, Tokens, Types, TypeCount)
            If ExpressionType < 0 Then
                If SyntaxNodeContainsToken(NodeIndex, "Nothing", SyntaxNodes, Tokens) <> 0 Then
                    ExpressionType = FindSemanticType("Nothing", Types, TypeCount)
                Else
                    If SyntaxNodeContainsToken(NodeIndex, "Empty", SyntaxNodes, Tokens) <> 0 Then
                        ExpressionType = FindSemanticType("Empty", Types, TypeCount)
                    Else
                        If SyntaxNodeContainsToken(NodeIndex, "&", SyntaxNodes, Tokens) <> 0 Then
                            ExpressionType = FindSemanticType("String", Types, TypeCount)
                        Else
                            If SyntaxNodeContainsToken(NodeIndex, "Is", SyntaxNodes, Tokens) <> 0 Or SyntaxNodeContainsToken(NodeIndex, "Like", SyntaxNodes, Tokens) <> 0 Then
                                ExpressionType = FindSemanticType("Boolean", Types, TypeCount)
                            Else
                                ExpressionType = FindSemanticType("Variant", Types, TypeCount)
                            End If
                        End If
                    End If
                End If
            End If
            NodeTypes(NodeIndex) = ExpressionType
            If ExpressionType >= 0 Then
                State.TypedExpressionCount = State.TypedExpressionCount + 1
            Else
                Call AddSemanticDiagnostic("UBE4040", NodeIndex, "expression has no semantic type", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
            End If
        End If
        NodeIndex = NodeIndex - 1
    Wend

    Dim SymbolIndex As Long = 0
    While SymbolIndex < SymbolCount
        If Symbols(SymbolIndex).SymbolKind = SemanticSymbolConstant() Or Symbols(SymbolIndex).SymbolKind = SemanticSymbolMember() Then
            Dim LiteralNode As Long = FirstDescendantSyntaxNode(Symbols(SymbolIndex).SyntaxNode, "integer-literal", SyntaxNodes, SyntaxLinks, Rules, 0)
            If LiteralNode >= 0 Then
                Dim ConstantText As String = SyntaxNodeTokenText(LiteralNode, SyntaxNodes, Tokens)
                If ValidateDecimalConstant(ConstantText) = 0 Then
                    Call AddSemanticDiagnostic("UBE4041", LiteralNode, "integer constant is outside the signed LongLong range", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Else
                    Symbols(SymbolIndex).ConstantKind = 1
                    Symbols(SymbolIndex).ConstantText = ConstantText
                End If
            End If
        End If
        SymbolIndex = SymbolIndex + 1
    Wend
    AnalyzeExpressions = 1
End Function
