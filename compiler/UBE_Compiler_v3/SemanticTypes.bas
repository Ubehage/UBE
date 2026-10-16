UBE SOURCE 1 MODULE
Attribute UBE_Name = "SemanticTypes"

Function TypeFromCharacter(ByVal Value As String, ByRef Types() As SemanticType, ByVal TypeCount As Long) As Long
    If Value = "%" Then
        TypeFromCharacter = FindSemanticType("Integer", Types, TypeCount)
        Exit Function
    End If
    If Value = "&" Then
        TypeFromCharacter = FindSemanticType("Long", Types, TypeCount)
        Exit Function
    End If
    If Value = "^" Then
        TypeFromCharacter = FindSemanticType("LongLong", Types, TypeCount)
        Exit Function
    End If
    If Value = "!" Then
        TypeFromCharacter = FindSemanticType("Single", Types, TypeCount)
        Exit Function
    End If
    If Value = "#" Then
        TypeFromCharacter = FindSemanticType("Double", Types, TypeCount)
        Exit Function
    End If
    If Value = "@" Then
        TypeFromCharacter = FindSemanticType("Currency", Types, TypeCount)
        Exit Function
    End If
    If Value = "$" Then
        TypeFromCharacter = FindSemanticType("String", Types, TypeCount)
        Exit Function
    End If
    TypeFromCharacter = -1
End Function

Function TypeNodeName(ByVal TypeNode As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef SyntaxLinks() As SyntaxChildLink, ByRef Rules() As GrammarRule, ByRef Tokens() As LexicalToken) As String
    Dim IntrinsicNode As Long = FirstDescendantSyntaxNode(TypeNode, "intrinsic-type", SyntaxNodes, SyntaxLinks, Rules, 0)
    If IntrinsicNode >= 0 Then
        TypeNodeName = SyntaxNodeTokenText(IntrinsicNode, SyntaxNodes, Tokens)
        Exit Function
    End If
    Dim FixedNode As Long = FirstDescendantSyntaxNode(TypeNode, "fixed-string-type", SyntaxNodes, SyntaxLinks, Rules, 0)
    If FixedNode >= 0 Then
        TypeNodeName = "String"
        Exit Function
    End If
    TypeNodeName = SyntaxIdentifierName(TypeNode, SyntaxNodes, SyntaxLinks, Rules, Tokens)
End Function

Function DirectDeclaredTypeNode(ByVal NodeIndex As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef SyntaxLinks() As SyntaxChildLink, ByRef Rules() As GrammarRule) As Long
    Dim ClauseNode As Long = FirstDirectSyntaxChild(NodeIndex, "as-clause", SyntaxNodes, SyntaxLinks, Rules)
    If ClauseNode < 0 Then
        ClauseNode = FirstDirectSyntaxChild(NodeIndex, "as-new-clause", SyntaxNodes, SyntaxLinks, Rules)
    End If
    If ClauseNode >= 0 Then
        DirectDeclaredTypeNode = FirstDescendantSyntaxNode(ClauseNode, "type-name", SyntaxNodes, SyntaxLinks, Rules, 0)
        Exit Function
    End If
    DirectDeclaredTypeNode = -1
End Function

Function ResolveSymbolTypes(ByRef Sources() As SourceDocument, ByRef SyntaxNodes() As SyntaxNode, ByRef SyntaxLinks() As SyntaxChildLink, ByRef Rules() As GrammarRule, ByRef Tokens() As LexicalToken, ByRef Types() As SemanticType, ByRef TypeCount As Long, ByRef TypeCapacity As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim SymbolIndex As Long = 0
    While SymbolIndex < SymbolCount
        Dim Kind As Long = Symbols(SymbolIndex).SymbolKind
        If Kind = SemanticSymbolVariable() Or Kind = SemanticSymbolConstant() Or Kind = SemanticSymbolMember() Or Kind = SemanticSymbolParameter() Then
            Dim NodeIndex As Long = Symbols(SymbolIndex).SyntaxNode
            Dim TypeNode As Long = DirectDeclaredTypeNode(NodeIndex, SyntaxNodes, SyntaxLinks, Rules)
            Dim ResolvedType As Long = -1
            If TypeNode >= 0 Then
                Dim DeclaredTypeName As String = TypeNodeName(TypeNode, SyntaxNodes, SyntaxLinks, Rules, Tokens)
                ResolvedType = FindSemanticType(DeclaredTypeName, Types, TypeCount)
                If ResolvedType < 0 Then
                    Call AddSemanticDiagnostic("UBE4011", TypeNode, "unknown type: " & DeclaredTypeName, Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                End If
            Else
                Dim TypedNode As Long = FirstDirectSyntaxChild(NodeIndex, "typed-name", SyntaxNodes, SyntaxLinks, Rules)
                Dim CharacterNode As Long = -1
                If TypedNode >= 0 Then
                    CharacterNode = FirstDirectSyntaxChild(TypedNode, "type-character", SyntaxNodes, SyntaxLinks, Rules)
                End If
                If CharacterNode >= 0 Then
                    ResolvedType = TypeFromCharacter(SyntaxNodeTokenText(CharacterNode, SyntaxNodes, Tokens), Types, TypeCount)
                Else
                    If Kind <> SemanticSymbolMember() Then
                        Call AddSemanticDiagnostic("UBE4012", NodeIndex, "declaration requires an explicit As type or type character", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    End If
                End If
            End If
            If ResolvedType >= 0 Then
                Dim FixedNode As Long = -1
                If TypeNode >= 0 Then
                    FixedNode = FirstDescendantSyntaxNode(TypeNode, "fixed-string-type", SyntaxNodes, SyntaxLinks, Rules, 0)
                End If
                If FixedNode >= 0 Then
                    ResolvedType = AppendSemanticType(Types, TypeCount, TypeCapacity, 40, "String * fixed", -1, FindSemanticType("String", Types, TypeCount), 0, 1)
                End If
                Dim ArrayNode As Long = FirstDirectSyntaxChild(NodeIndex, "array-specifier", SyntaxNodes, SyntaxLinks, Rules)
                If ArrayNode < 0 Then
                    ArrayNode = FirstDirectSyntaxChild(NodeIndex, "array-rank", SyntaxNodes, SyntaxLinks, Rules)
                End If
                If ArrayNode >= 0 Then
                    Dim Rank As Long = 1
                    Dim TokenIndex As Long = SyntaxNodes(ArrayNode).FirstToken
                    While TokenIndex <= SyntaxNodes(ArrayNode).LastToken
                        If Tokens(TokenIndex).Spelling = "," Then
                            Rank = Rank + 1
                        End If
                        TokenIndex = TokenIndex + 1
                    Wend
                    ResolvedType = AppendSemanticType(Types, TypeCount, TypeCapacity, 41, Types(ResolvedType).TypeName & "()", -1, ResolvedType, Rank, 0)
                End If
                Symbols(SymbolIndex).DeclaredType = ResolvedType
                If EqualsFolded(Types(ResolvedType).TypeName, "Any") <> 0 Then
                    Dim ParentNode As Long = SyntaxNodes(NodeIndex).ParentNode
                    Dim IsExternal As Long = 0
                    While ParentNode >= 0
                        If SyntaxRuleIs(ParentNode, "external-declaration", SyntaxNodes, Rules) <> 0 Then
                            IsExternal = 1
                        End If
                        ParentNode = SyntaxNodes(ParentNode).ParentNode
                    Wend
                    If IsExternal = 0 Then
                        Call AddSemanticDiagnostic("UBE4013", NodeIndex, "Any is restricted to external declaration parameters", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    End If
                End If
            End If
        End If
        SymbolIndex = SymbolIndex + 1
    Wend
    ResolveSymbolTypes = 1
End Function
