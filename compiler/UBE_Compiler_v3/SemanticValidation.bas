UBE SOURCE 1 MODULE
Attribute UBE_Name = "SemanticValidation"

Function HasAncestorRule(ByVal NodeIndex As Long, ByVal RuleName As String, ByRef SyntaxNodes() As SyntaxNode, ByRef Rules() As GrammarRule) As Long
    Dim CurrentNode As Long = SyntaxNodes(NodeIndex).ParentNode
    Dim Depth As Long = 0
    While CurrentNode >= 0 And Depth < LimitSemanticDepth()
        If SyntaxRuleIs(CurrentNode, RuleName, SyntaxNodes, Rules) <> 0 Then
            HasAncestorRule = 1
            Exit Function
        End If
        CurrentNode = SyntaxNodes(CurrentNode).ParentNode
        Depth = Depth + 1
    Wend
    HasAncestorRule = 0
End Function

Function ProcedureOwnerForNode(ByVal NodeIndex As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long) As Long
    Dim CurrentNode As Long = NodeIndex
    While CurrentNode >= 0
        Dim SymbolIndex As Long = 0
        While SymbolIndex < SymbolCount
            If Symbols(SymbolIndex).SyntaxNode = CurrentNode Then
                If Symbols(SymbolIndex).SymbolKind = SemanticSymbolProcedure() Or Symbols(SymbolIndex).SymbolKind = SemanticSymbolProperty() Then
                    ProcedureOwnerForNode = SymbolIndex
                    Exit Function
                End If
            End If
            SymbolIndex = SymbolIndex + 1
        Wend
        CurrentNode = SyntaxNodes(CurrentNode).ParentNode
    Wend
    ProcedureOwnerForNode = -1
End Function

Function LastIdentifierInNode(ByVal NodeIndex As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken) As String
    Dim Result As String = ""
    Dim TokenIndex As Long = SyntaxNodes(NodeIndex).FirstToken
    While TokenIndex <= SyntaxNodes(NodeIndex).LastToken
        If Tokens(TokenIndex).TokenKind = 2 Then
            Result = Tokens(TokenIndex).Spelling
        Else
            If Tokens(TokenIndex).TokenKind = 3 Then
                Result = Tokens(TokenIndex).Decoded
            End If
        End If
        TokenIndex = TokenIndex + 1
    Wend
    LastIdentifierInNode = Result
End Function

Function ValidateSemanticContracts(ByRef Project As ProjectDescription, ByRef Sources() As SourceDocument, ByRef SyntaxNodes() As SyntaxNode, ByVal SyntaxNodeCount As Long, ByRef SyntaxLinks() As SyntaxChildLink, ByRef Rules() As GrammarRule, ByRef Tokens() As LexicalToken, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef State As SemanticState, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim SymbolIndex As Long = 0
    While SymbolIndex < SymbolCount
        If Symbols(SymbolIndex).SymbolKind = SemanticSymbolParameter() Then
            If Symbols(SymbolIndex).Flags And 8 Then
                Dim LaterSymbol As Long = SymbolIndex + 1
                While LaterSymbol < SymbolCount
                    If Symbols(LaterSymbol).SymbolKind = SemanticSymbolParameter() And Symbols(LaterSymbol).ParentSymbol = Symbols(SymbolIndex).ParentSymbol Then
                        Call AddSemanticDiagnostic("UBE4020", Symbols(SymbolIndex).SyntaxNode, "ParamArray must be the final parameter", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        LaterSymbol = SymbolCount
                    End If
                    LaterSymbol = LaterSymbol + 1
                Wend
                If Symbols(SymbolIndex).Flags And 1 Then
                    Call AddSemanticDiagnostic("UBE4021", Symbols(SymbolIndex).SyntaxNode, "ParamArray cannot also be Optional", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                End If
            End If
            If (Symbols(SymbolIndex).Flags And 1) = 0 And (Symbols(SymbolIndex).Flags And 8) = 0 Then
                Dim PriorSymbol As Long = 0
                Dim HasPriorOptional As Long = 0
                While PriorSymbol < SymbolIndex
                    If Symbols(PriorSymbol).SymbolKind = SemanticSymbolParameter() And Symbols(PriorSymbol).ParentSymbol = Symbols(SymbolIndex).ParentSymbol Then
                        If Symbols(PriorSymbol).Flags And 1 Then
                            HasPriorOptional = 1
                        End If
                    End If
                    PriorSymbol = PriorSymbol + 1
                Wend
                If HasPriorOptional <> 0 Then
                    Call AddSemanticDiagnostic("UBE4028", Symbols(SymbolIndex).SyntaxNode, "required parameter cannot follow an Optional parameter", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                End If
            End If
        End If
        SymbolIndex = SymbolIndex + 1
    Wend

    If State.EntrySymbol >= 0 Then
        Dim EntryParameters As Long = 0
        SymbolIndex = 0
        While SymbolIndex < SymbolCount
            If Symbols(SymbolIndex).SymbolKind = SemanticSymbolParameter() And Symbols(SymbolIndex).ParentSymbol = State.EntrySymbol Then
                EntryParameters = EntryParameters + 1
            End If
            SymbolIndex = SymbolIndex + 1
        Wend
        If EntryParameters <> 0 Then
            Call AddSemanticDiagnostic("UBE4022", Symbols(State.EntrySymbol).SyntaxNode, "Main cannot declare parameters", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        End If
        If SyntaxNodeContainsToken(Symbols(State.EntrySymbol).SyntaxNode, "Function", SyntaxNodes, Tokens) <> 0 Then
            Dim ResultClause As Long = FirstDescendantSyntaxNode(Symbols(State.EntrySymbol).SyntaxNode, "result-as-clause", SyntaxNodes, SyntaxLinks, Rules, 0)
            Dim ResultTypeNode As Long = -1
            If ResultClause >= 0 Then
                ResultTypeNode = FirstDescendantSyntaxNode(ResultClause, "type-name", SyntaxNodes, SyntaxLinks, Rules, 0)
            End If
            If ResultTypeNode < 0 Then
                Call AddSemanticDiagnostic("UBE4023", Symbols(State.EntrySymbol).SyntaxNode, "Function Main must return Long", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Else
                If EqualsFolded(TypeNodeName(ResultTypeNode, SyntaxNodes, SyntaxLinks, Rules, Tokens), "Long") = 0 Then
                    Call AddSemanticDiagnostic("UBE4023", ResultTypeNode, "Function Main must return Long", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                End If
            End If
        End If
    End If

    Dim NodeIndex As Long = 0
    While NodeIndex < SyntaxNodeCount
        Dim RuleName As String = Rules(SyntaxNodes(NodeIndex).ProductionRule).RuleName
        If EqualsFolded(RuleName, "exit-statement") <> 0 Then
            Dim ExitValid As Long = 0
            If SyntaxNodeContainsToken(NodeIndex, "Sub", SyntaxNodes, Tokens) <> 0 Then
                ExitValid = HasAncestorRule(NodeIndex, "sub-function-declaration", SyntaxNodes, Rules)
            End If
            If SyntaxNodeContainsToken(NodeIndex, "Function", SyntaxNodes, Tokens) <> 0 Then
                ExitValid = HasAncestorRule(NodeIndex, "sub-function-declaration", SyntaxNodes, Rules)
            End If
            If SyntaxNodeContainsToken(NodeIndex, "Property", SyntaxNodes, Tokens) <> 0 Then
                ExitValid = HasAncestorRule(NodeIndex, "property-declaration", SyntaxNodes, Rules)
            End If
            If SyntaxNodeContainsToken(NodeIndex, "For", SyntaxNodes, Tokens) <> 0 Then
                ExitValid = HasAncestorRule(NodeIndex, "for-statement", SyntaxNodes, Rules)
            End If
            If SyntaxNodeContainsToken(NodeIndex, "Do", SyntaxNodes, Tokens) <> 0 Then
                ExitValid = HasAncestorRule(NodeIndex, "do-statement", SyntaxNodes, Rules)
            End If
            If SyntaxNodeContainsToken(NodeIndex, "While", SyntaxNodes, Tokens) <> 0 Then
                ExitValid = HasAncestorRule(NodeIndex, "while-statement", SyntaxNodes, Rules)
            End If
            If ExitValid = 0 Then
                Call AddSemanticDiagnostic("UBE4024", NodeIndex, "Exit does not name an enclosing construct", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
            End If
        End If
        If EqualsFolded(RuleName, "label-reference") <> 0 Then
            Dim LabelName As String = LastIdentifierInNode(NodeIndex, SyntaxNodes, Tokens)
            If StringLength(LabelName) = 0 Then
                LabelName = SyntaxNodeTokenText(NodeIndex, SyntaxNodes, Tokens)
            End If
            Dim OwnerSymbol As Long = ProcedureOwnerForNode(NodeIndex, SyntaxNodes, Symbols, SymbolCount)
            Dim FoundLabel As Long = 0
            SymbolIndex = 0
            While SymbolIndex < SymbolCount
                If Symbols(SymbolIndex).SymbolKind = SemanticSymbolLabel() And Symbols(SymbolIndex).ParentSymbol = OwnerSymbol Then
                    If EqualsFolded(Symbols(SymbolIndex).SymbolName, LabelName) <> 0 Then
                        FoundLabel = 1
                    End If
                End If
                SymbolIndex = SymbolIndex + 1
            Wend
            If FoundLabel = 0 Then
                Call AddSemanticDiagnostic("UBE4025", NodeIndex, "unknown procedure label: " & LabelName, Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
            End If
        End If
        If EqualsFolded(RuleName, "call-new-expression") <> 0 Then
            Dim QualifiedNode As Long = FirstDescendantSyntaxNode(NodeIndex, "qualified-name", SyntaxNodes, SyntaxLinks, Rules, 0)
            Dim TargetName As String = LastIdentifierInNode(QualifiedNode, SyntaxNodes, Tokens)
            Dim MatchCount As Long = 0
            SymbolIndex = 0
            While SymbolIndex < SymbolCount
                If Symbols(SymbolIndex).SymbolKind = SemanticSymbolProcedure() And EqualsFolded(Symbols(SymbolIndex).SymbolName, TargetName) <> 0 Then
                    If SyntaxNodeContainsToken(Symbols(SymbolIndex).SyntaxNode, "Sub", SyntaxNodes, Tokens) <> 0 Then
                        MatchCount = MatchCount + 1
                    End If
                End If
                SymbolIndex = SymbolIndex + 1
            Wend
            If MatchCount = 0 Then
                Call AddSemanticDiagnostic("UBE4026", NodeIndex, "CallNew target must resolve to a known Sub: " & TargetName, Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Else
                If MatchCount > 1 Then
                    Call AddSemanticDiagnostic("UBE4027", NodeIndex, "CallNew target is ambiguous: " & TargetName, Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                End If
            End If
        End If
        NodeIndex = NodeIndex + 1
    Wend
    ValidateSemanticContracts = 1
End Function
