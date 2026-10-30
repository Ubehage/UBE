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

Function IntegerLiteralFitsBound(ByVal LiteralText As String, ByVal DecimalBound As String, ByVal HexBound As String, ByVal OctalBound As String) As Long
    Dim FirstDigit As Long = 0
    Dim BaseValue As Long = 10
    Dim BoundText As String = DecimalBound
    Dim Length As Long = StringLength(LiteralText)
    If Length >= 2 And StringByteAt(LiteralText, 0) = 38 Then
        Dim Marker As Long = StringByteAt(LiteralText, 1)
        If Marker = 72 Or Marker = 104 Then
            BaseValue = 16
            BoundText = HexBound
            FirstDigit = 2
        Else
            If Marker = 79 Or Marker = 111 Then
                BaseValue = 8
                BoundText = OctalBound
                FirstDigit = 2
            End If
        End If
    End If
    Dim LastDigit As Long = Length - 1
    If LastDigit >= FirstDigit Then
        Dim Suffix As Long = StringByteAt(LiteralText, LastDigit)
        If Suffix = 37 Or Suffix = 38 Or Suffix = 94 Then
            LastDigit = LastDigit - 1
        End If
    End If
    While FirstDigit < LastDigit And StringByteAt(LiteralText, FirstDigit) = 48
        FirstDigit = FirstDigit + 1
    Wend
    Dim DigitCount As Long = LastDigit - FirstDigit + 1
    Dim BoundLength As Long = StringLength(BoundText)
    If DigitCount < BoundLength Then
        IntegerLiteralFitsBound = 1
        Exit Function
    End If
    If DigitCount > BoundLength Then
        IntegerLiteralFitsBound = 0
        Exit Function
    End If
    Dim Offset As Long = 0
    While Offset < DigitCount
        Dim ActualByte As Long = StringByteAt(LiteralText, FirstDigit + Offset)
        If ActualByte >= 97 And ActualByte <= 102 Then
            ActualByte = ActualByte - 32
        End If
        Dim BoundByte As Long = StringByteAt(BoundText, Offset)
        If ActualByte < BoundByte Then
            IntegerLiteralFitsBound = 1
            Exit Function
        End If
        If ActualByte > BoundByte Then
            IntegerLiteralFitsBound = 0
            Exit Function
        End If
        Offset = Offset + 1
    Wend
    IntegerLiteralFitsBound = 1
End Function

Function IntegerLiteralSemanticType(ByVal LiteralText As String, ByRef Types() As SemanticType, ByVal TypeCount As Long) As Long
    Dim Length As Long = StringLength(LiteralText)
    If Length > 0 Then
        Dim Suffix As Long = StringByteAt(LiteralText, Length - 1)
        If Suffix = 37 Then
            IntegerLiteralSemanticType = FindSemanticType("Integer", Types, TypeCount)
            Exit Function
        End If
        If Suffix = 38 Then
            IntegerLiteralSemanticType = FindSemanticType("Long", Types, TypeCount)
            Exit Function
        End If
        If Suffix = 94 Then
            IntegerLiteralSemanticType = FindSemanticType("LongLong", Types, TypeCount)
            Exit Function
        End If
    End If
    If IntegerLiteralFitsBound(LiteralText, "32767", "7FFF", "77777") <> 0 Then
        IntegerLiteralSemanticType = FindSemanticType("Integer", Types, TypeCount)
        Exit Function
    End If
    If IntegerLiteralFitsBound(LiteralText, "2147483647", "7FFFFFFF", "17777777777") <> 0 Then
        IntegerLiteralSemanticType = FindSemanticType("Long", Types, TypeCount)
        Exit Function
    End If
    IntegerLiteralSemanticType = FindSemanticType("LongLong", Types, TypeCount)
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
            LiteralExpressionType = IntegerLiteralSemanticType(Tokens(TokenIndex).Spelling, Types, TypeCount)
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

Function BindingOwnerForNode(ByVal SyntaxNodeIndex As Long, ByRef Bindings() As SemanticNodeBinding, ByVal BindingCount As Long) As Long
    If SyntaxNodeIndex >= 0 And SyntaxNodeIndex < BindingCount Then
        If Bindings(SyntaxNodeIndex).SyntaxNode = SyntaxNodeIndex Then
            BindingOwnerForNode = Bindings(SyntaxNodeIndex).OwnerSymbol
            Exit Function
        End If
    End If
    BindingOwnerForNode = -1
End Function

Function SymbolAccessibleFromSource(ByVal CurrentSourceId As Long, ByVal SymbolIndex As Long, ByRef Sources() As SourceDocument, ByRef Symbols() As SemanticSymbol) As Long
    If SymbolIndex < 0 Or CurrentSourceId <= 0 Or Symbols(SymbolIndex).SourceId <= 0 Then
        SymbolAccessibleFromSource = 0
        Exit Function
    End If
    If Symbols(SymbolIndex).SourceId = CurrentSourceId Then
        SymbolAccessibleFromSource = 1
        Exit Function
    End If
    Dim CurrentDepth As Long = Sources(CurrentSourceId - 1).ReferenceDepth
    Dim CandidateDepth As Long = Sources(Symbols(SymbolIndex).SourceId - 1).ReferenceDepth
    If CurrentDepth = 0 And CandidateDepth > 0 Then
        If CandidateDepth <> 1 Or Symbols(SymbolIndex).VisibilityKind <> 1 Then
            SymbolAccessibleFromSource = 0
            Exit Function
        End If
        Dim ParentSymbol As Long = Symbols(SymbolIndex).ParentSymbol
        If ParentSymbol < 0 Then
            SymbolAccessibleFromSource = 0
            Exit Function
        End If
        If Symbols(ParentSymbol).SymbolKind <> SemanticSymbolModule() Then
            SymbolAccessibleFromSource = 0
            Exit Function
        End If
    End If
    SymbolAccessibleFromSource = 1
End Function

Function FindInaccessibleReferenceSymbol(ByVal NodeIndex As Long, ByRef Sources() As SourceDocument, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long) As Long
    Dim NameToken As Long = SyntaxNodes(NodeIndex).FirstToken
    While NameToken <= SyntaxNodes(NodeIndex).LastToken
        If Tokens(NameToken).TokenKind = 2 Or Tokens(NameToken).TokenKind = 3 Then
            Exit While
        End If
        NameToken = NameToken + 1
    Wend
    If NameToken > SyntaxNodes(NodeIndex).LastToken Then
        FindInaccessibleReferenceSymbol = -1
        Exit Function
    End If
    Dim SoughtName As String = Tokens(NameToken).Spelling
    If Tokens(NameToken).TokenKind = 3 Then
        SoughtName = Tokens(NameToken).Decoded
    End If
    Dim SymbolIndex As Long = 0
    While SymbolIndex < SymbolCount
        If Symbols(SymbolIndex).SymbolName = SoughtName Or EqualsFolded(Symbols(SymbolIndex).SymbolName, SoughtName) <> 0 Then
            If Symbols(SymbolIndex).SourceId > 0 Then
                If Sources(Symbols(SymbolIndex).SourceId - 1).ReferenceDepth > 0 Then
                    If SymbolAccessibleFromSource(SyntaxNodes(NodeIndex).SourceId, SymbolIndex, Sources, Symbols) = 0 Then
                        FindInaccessibleReferenceSymbol = SymbolIndex
                        Exit Function
                    End If
                End If
            End If
        End If
        SymbolIndex = SymbolIndex + 1
    Wend
    FindInaccessibleReferenceSymbol = -1
End Function

Function ResolveExpressionSymbol(ByVal NodeIndex As Long, ByRef Sources() As SourceDocument, ByRef SyntaxNodes() As SyntaxNode, ByRef SyntaxLinks() As SyntaxChildLink, ByRef Rules() As GrammarRule, ByRef Tokens() As LexicalToken, ByRef Scopes() As SemanticScope, ByRef SymbolLinks() As SemanticSymbolLink, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Bindings() As SemanticNodeBinding, ByVal BindingCount As Long, ByRef ScopedCacheScopes() As Long, ByRef ScopedCacheNames() As String, ByRef ScopedCacheResults() As Long, ByRef ScopedCacheCount As Long, ByRef GlobalCacheSourceIds() As Long, ByRef GlobalCacheNames() As String, ByRef GlobalCacheResults() As Long, ByRef GlobalCacheCount As Long) As Long
    Dim IdentifierToken As Long = SyntaxNodes(NodeIndex).FirstToken
    While IdentifierToken <= SyntaxNodes(NodeIndex).LastToken
        If Tokens(IdentifierToken).TokenKind = 2 Or Tokens(IdentifierToken).TokenKind = 3 Then
            Exit While
        End If
        If Tokens(IdentifierToken).TokenKind = 4 Or Tokens(IdentifierToken).TokenKind = 5 Or Tokens(IdentifierToken).TokenKind = 6 Or Tokens(IdentifierToken).TokenKind = 7 Then
            ResolveExpressionSymbol = -1
            Exit Function
        End If
        If Tokens(IdentifierToken).TokenKind = 1 Then
            If EqualsFolded(Tokens(IdentifierToken).Spelling, "True") <> 0 Then
                ResolveExpressionSymbol = -1
                Exit Function
            End If
            If EqualsFolded(Tokens(IdentifierToken).Spelling, "False") <> 0 Then
                ResolveExpressionSymbol = -1
                Exit Function
            End If
            If EqualsFolded(Tokens(IdentifierToken).Spelling, "Null") <> 0 Then
                ResolveExpressionSymbol = -1
                Exit Function
            End If
            If EqualsFolded(Tokens(IdentifierToken).Spelling, "Nothing") <> 0 Then
                ResolveExpressionSymbol = -1
                Exit Function
            End If
            If EqualsFolded(Tokens(IdentifierToken).Spelling, "Empty") <> 0 Then
                ResolveExpressionSymbol = -1
                Exit Function
            End If
        End If
        IdentifierToken = IdentifierToken + 1
    Wend
    If IdentifierToken > SyntaxNodes(NodeIndex).LastToken Then
        ResolveExpressionSymbol = -1
        Exit Function
    End If
    Dim SoughtName As String = Tokens(IdentifierToken).Spelling
    If Tokens(IdentifierToken).TokenKind = 3 Then
        SoughtName = Tokens(IdentifierToken).Decoded
    End If
    Dim BoundScope As Long = -1
    If NodeIndex >= 0 And NodeIndex < BindingCount Then
        BoundScope = Bindings(NodeIndex).ScopeIndex
    End If
    If BoundScope >= 0 Then
        Dim ScopedCacheIndex As Long = 0
        While ScopedCacheIndex < ScopedCacheCount
            If ScopedCacheScopes(ScopedCacheIndex) = BoundScope Then
                If ScopedCacheNames(ScopedCacheIndex) = SoughtName Or EqualsFolded(ScopedCacheNames(ScopedCacheIndex), SoughtName) <> 0 Then
                    ResolveExpressionSymbol = ScopedCacheResults(ScopedCacheIndex)
                    Exit Function
                End If
            End If
            ScopedCacheIndex = ScopedCacheIndex + 1
        Wend
        Dim VisibleSymbol As Long = FindVisibleSymbol(BoundScope, SoughtName, Scopes, Symbols, SymbolLinks)
        If VisibleSymbol >= 0 Then
            If ScopedCacheCount < SymbolCount Then
                ScopedCacheScopes(ScopedCacheCount) = BoundScope
                ScopedCacheNames(ScopedCacheCount) = SoughtName
                ScopedCacheResults(ScopedCacheCount) = VisibleSymbol
                ScopedCacheCount = ScopedCacheCount + 1
            End If
            ResolveExpressionSymbol = VisibleSymbol
            Exit Function
        End If
    End If
    Dim OwnerSymbol As Long = BindingOwnerForNode(NodeIndex, Bindings, BindingCount)
    If OwnerSymbol >= 0 Then
        If Symbols(OwnerSymbol).SymbolName = SoughtName Or EqualsFolded(Symbols(OwnerSymbol).SymbolName, SoughtName) <> 0 Then
            ResolveExpressionSymbol = OwnerSymbol
            Exit Function
        End If
    End If
    Dim CacheIndex As Long = 0
    While CacheIndex < GlobalCacheCount
        If GlobalCacheSourceIds(CacheIndex) = SyntaxNodes(NodeIndex).SourceId Then
            If GlobalCacheNames(CacheIndex) = SoughtName Then
                ResolveExpressionSymbol = GlobalCacheResults(CacheIndex)
                Exit Function
            End If
            If EqualsFolded(GlobalCacheNames(CacheIndex), SoughtName) <> 0 Then
                ResolveExpressionSymbol = GlobalCacheResults(CacheIndex)
                Exit Function
            End If
        End If
        CacheIndex = CacheIndex + 1
    Wend
    Dim MatchIndex As Long = -1
    Dim MatchCount As Long = 0
    Dim SymbolIndex As Long = 0
    While SymbolIndex < SymbolCount
        If Symbols(SymbolIndex).SourceId = SyntaxNodes(NodeIndex).SourceId And (Symbols(SymbolIndex).SymbolName = SoughtName Or EqualsFolded(Symbols(SymbolIndex).SymbolName, SoughtName) <> 0) Then
            If Symbols(SymbolIndex).SymbolKind <> SemanticSymbolModule() And SymbolAccessibleFromSource(SyntaxNodes(NodeIndex).SourceId, SymbolIndex, Sources, Symbols) <> 0 Then
                MatchIndex = SymbolIndex
                MatchCount = MatchCount + 1
            End If
        End If
        SymbolIndex = SymbolIndex + 1
    Wend
    If MatchCount <> 1 Then
        MatchIndex = -1
        MatchCount = 0
        SymbolIndex = 0
        While SymbolIndex < SymbolCount
            If Symbols(SymbolIndex).SymbolName = SoughtName Or EqualsFolded(Symbols(SymbolIndex).SymbolName, SoughtName) <> 0 Then
                If (Symbols(SymbolIndex).SymbolKind = SemanticSymbolProcedure() Or Symbols(SymbolIndex).SymbolKind = SemanticSymbolProperty() Or Symbols(SymbolIndex).SymbolKind = SemanticSymbolVariable() Or Symbols(SymbolIndex).SymbolKind = SemanticSymbolConstant()) And SymbolAccessibleFromSource(SyntaxNodes(NodeIndex).SourceId, SymbolIndex, Sources, Symbols) <> 0 Then
                    MatchIndex = SymbolIndex
                    MatchCount = MatchCount + 1
                End If
            End If
            SymbolIndex = SymbolIndex + 1
        Wend
    End If
    If MatchCount = 1 Then
        ResolveExpressionSymbol = MatchIndex
    Else
        ResolveExpressionSymbol = -1
    End If
    If GlobalCacheCount < SymbolCount Then
        GlobalCacheSourceIds(GlobalCacheCount) = SyntaxNodes(NodeIndex).SourceId
        GlobalCacheNames(GlobalCacheCount) = SoughtName
        GlobalCacheResults(GlobalCacheCount) = ResolveExpressionSymbol
        GlobalCacheCount = GlobalCacheCount + 1
    End If
End Function

Function AnalyzeExpressionWorker(ByRef Sources() As SourceDocument, ByRef SyntaxNodes() As SyntaxNode, ByVal SyntaxNodeCount As Long, ByRef SyntaxLinks() As SyntaxChildLink, ByRef Rules() As GrammarRule, ByVal ExpressionRule As Long, ByRef Tokens() As LexicalToken, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Scopes() As SemanticScope, ByRef SymbolLinks() As SemanticSymbolLink, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef WorkerBySymbol() As Long, ByVal WorkerIndex As Long, ByVal WorkerCount As Long, ByRef Expressions() As SemanticExpression, ByRef ExpressionCount As Long, ByRef ExpressionCapacity As Long, ByRef Bindings() As SemanticNodeBinding, ByVal BindingCount As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long, ByRef WorkerExpressionCount As Long, ByRef WorkerTypedExpressionCount As Long) As Long
    WorkerExpressionCount = 0
    WorkerTypedExpressionCount = 0
    Dim NodeTypes() As Long
    ReDim NodeTypes(SyntaxNodeCount - 1)
    Dim GlobalCacheNames() As String
    Dim GlobalCacheSourceIds() As Long
    Dim GlobalCacheResults() As Long
    Dim GlobalCacheCount As Long = 0
    Dim ScopedCacheScopes() As Long
    Dim ScopedCacheNames() As String
    Dim ScopedCacheResults() As Long
    Dim ScopedCacheCount As Long = 0
    If SymbolCount > 0 Then
        ReDim ScopedCacheScopes(SymbolCount - 1)
        ReDim ScopedCacheNames(SymbolCount - 1)
        ReDim ScopedCacheResults(SymbolCount - 1)
        ReDim GlobalCacheSourceIds(SymbolCount - 1)
        ReDim GlobalCacheNames(SymbolCount - 1)
        ReDim GlobalCacheResults(SymbolCount - 1)
    End If
    Dim NodeIndex As Long = 0
    While NodeIndex < SyntaxNodeCount
        NodeTypes(NodeIndex) = -1
        NodeIndex = NodeIndex + 1
    Wend
    NodeIndex = 0
    While NodeIndex < SyntaxNodeCount
        Dim AnalyzeNode As Long = 1
        If WorkerCount > 1 Then
            AnalyzeNode = 0
            Dim ExpressionOwner As Long = BindingOwnerForNode(NodeIndex, Bindings, BindingCount)
            If ExpressionOwner >= 0 And ExpressionOwner < SymbolCount Then
                If WorkerBySymbol(ExpressionOwner) = WorkerIndex Then
                    AnalyzeNode = 1
                End If
            Else
                If WorkerIndex = 0 Then
                    AnalyzeNode = 1
                End If
            End If
        End If
        If AnalyzeNode <> 0 Then
        If SyntaxNodes(NodeIndex).ProductionRule = ExpressionRule Then
            WorkerExpressionCount = WorkerExpressionCount + 1
            Dim ResolvedSymbol As Long = ResolveExpressionSymbol(NodeIndex, Sources, SyntaxNodes, SyntaxLinks, Rules, Tokens, Scopes, SymbolLinks, Symbols, SymbolCount, Bindings, BindingCount, ScopedCacheScopes, ScopedCacheNames, ScopedCacheResults, ScopedCacheCount, GlobalCacheSourceIds, GlobalCacheNames, GlobalCacheResults, GlobalCacheCount)
            If ResolvedSymbol < 0 Then
                Dim InaccessibleSymbol As Long = FindInaccessibleReferenceSymbol(NodeIndex, Sources, SyntaxNodes, Tokens, Symbols, SymbolCount)
                If InaccessibleSymbol >= 0 Then
                    Call AddSemanticDiagnostic("UBE4043", NodeIndex, "declaration is not public in a direct project Reference: " & Symbols(InaccessibleSymbol).SymbolName, Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                End If
            End If
            Dim ExpressionType As Long = -1
            Dim ValueCategory As Long = 0
            If ResolvedSymbol >= 0 Then
                If Symbols(ResolvedSymbol).DeclaredType >= 0 Then
                    ExpressionType = Symbols(ResolvedSymbol).DeclaredType
                End If
                If Symbols(ResolvedSymbol).SymbolKind = SemanticSymbolVariable() Or Symbols(ResolvedSymbol).SymbolKind = SemanticSymbolParameter() Then
                    ValueCategory = 1
                Else
                    ValueCategory = 2
                End If
            End If
            If ExpressionType < 0 Then
                ExpressionType = LiteralExpressionType(NodeIndex, SyntaxNodes, Tokens, Types, TypeCount)
            End If
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
                WorkerTypedExpressionCount = WorkerTypedExpressionCount + 1
                Dim ConstantKind As Long = 0
                Dim ExpressionConstantText As String = ""
                If SyntaxNodes(NodeIndex).FirstToken = SyntaxNodes(NodeIndex).LastToken Then
                    Dim OnlyToken As Long = SyntaxNodes(NodeIndex).FirstToken
                    If Tokens(OnlyToken).TokenKind = 4 Or Tokens(OnlyToken).TokenKind = 5 Or Tokens(OnlyToken).TokenKind = 6 Or Tokens(OnlyToken).TokenKind = 7 Then
                        ConstantKind = Tokens(OnlyToken).TokenKind
                        ExpressionConstantText = Tokens(OnlyToken).Decoded
                        If StringLength(ExpressionConstantText) = 0 Then
                            ExpressionConstantText = Tokens(OnlyToken).Spelling
                        End If
                    Else
                        If EqualsFolded(Tokens(OnlyToken).Spelling, "True") <> 0 Or EqualsFolded(Tokens(OnlyToken).Spelling, "False") <> 0 Or EqualsFolded(Tokens(OnlyToken).Spelling, "Null") <> 0 Or EqualsFolded(Tokens(OnlyToken).Spelling, "Empty") <> 0 Or EqualsFolded(Tokens(OnlyToken).Spelling, "Nothing") <> 0 Then
                            ConstantKind = Tokens(OnlyToken).TokenKind
                            ExpressionConstantText = Tokens(OnlyToken).Spelling
                        End If
                    End If
                End If
                If AppendSemanticExpression(Expressions, ExpressionCount, ExpressionCapacity, NodeIndex, ExpressionType, ResolvedSymbol, 0, ValueCategory, ConstantKind, ExpressionConstantText, 0) < 0 Then
                    Call AddSemanticDiagnostic("UBE4042", NodeIndex, "semantic expression limit exceeded", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                End If
            Else
                Call AddSemanticDiagnostic("UBE4040", NodeIndex, "expression has no semantic type", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
            End If
        End If
        End If
        NodeIndex = NodeIndex + 1
    Wend

    AnalyzeExpressionWorker = 1
End Function

Sub FinalizeSemanticConstants(ByRef Sources() As SourceDocument, ByRef SyntaxNodes() As SyntaxNode, ByRef SyntaxLinks() As SyntaxChildLink, ByRef Rules() As GrammarRule, ByRef Tokens() As LexicalToken, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long)
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
End Sub

Function AnalyzeExpressions(ByRef Sources() As SourceDocument, ByRef SyntaxNodes() As SyntaxNode, ByVal SyntaxNodeCount As Long, ByRef SyntaxLinks() As SyntaxChildLink, ByRef Rules() As GrammarRule, ByVal RuleCount As Long, ByRef Tokens() As LexicalToken, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Scopes() As SemanticScope, ByRef SymbolLinks() As SemanticSymbolLink, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef State As SemanticState, ByRef Expressions() As SemanticExpression, ByRef ExpressionCount As Long, ByRef ExpressionCapacity As Long, ByRef Bindings() As SemanticNodeBinding, ByVal BindingCount As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim WorkerBySymbol() As Long
    Dim WorkerExpressionCount As Long = 0
    Dim WorkerTypedExpressionCount As Long = 0
    Dim ExpressionRule As Long = FindGrammarRule(Rules, RuleCount, "expression")
    Call AnalyzeExpressionWorker(Sources, SyntaxNodes, SyntaxNodeCount, SyntaxLinks, Rules, ExpressionRule, Tokens, Types, TypeCount, Scopes, SymbolLinks, Symbols, SymbolCount, WorkerBySymbol, 0, 1, Expressions, ExpressionCount, ExpressionCapacity, Bindings, BindingCount, Diagnostics, DiagnosticCount, DiagnosticCapacity, WorkerExpressionCount, WorkerTypedExpressionCount)
    State.ExpressionCount = WorkerExpressionCount
    State.TypedExpressionCount = WorkerTypedExpressionCount
    Call FinalizeSemanticConstants(Sources, SyntaxNodes, SyntaxLinks, Rules, Tokens, Symbols, SymbolCount, Diagnostics, DiagnosticCount, DiagnosticCapacity)
    AnalyzeExpressions = 1
End Function
