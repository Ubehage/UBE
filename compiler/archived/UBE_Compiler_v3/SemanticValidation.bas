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

Function InterfaceMemberDeclaredName(ByVal NodeIndex As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken) As String
    Dim SawDeclaration As Long = 0
    Dim TokenIndex As Long = SyntaxNodes(NodeIndex).FirstToken
    While TokenIndex <= SyntaxNodes(NodeIndex).LastToken
        If EqualsFolded(Tokens(TokenIndex).Spelling, "Sub") <> 0 Or EqualsFolded(Tokens(TokenIndex).Spelling, "Function") <> 0 Or EqualsFolded(Tokens(TokenIndex).Spelling, "Property") <> 0 Then
            SawDeclaration = 1
        Else
            If SawDeclaration <> 0 And Tokens(TokenIndex).TokenKind = 2 Then
                If EqualsFolded(Tokens(TokenIndex).Spelling, "Get") = 0 And EqualsFolded(Tokens(TokenIndex).Spelling, "Let") = 0 And EqualsFolded(Tokens(TokenIndex).Spelling, "Set") = 0 Then
                    InterfaceMemberDeclaredName = Tokens(TokenIndex).Spelling
                    Exit Function
                End If
            End If
        End If
        TokenIndex = TokenIndex + 1
    Wend
    InterfaceMemberDeclaredName = ""
End Function

Function InterfaceMemberParameterCount(ByVal NodeIndex As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken) As Long
    Dim OpenToken As Long = -1
    Dim CloseToken As Long = -1
    Dim TokenIndex As Long = SyntaxNodes(NodeIndex).FirstToken
    While TokenIndex <= SyntaxNodes(NodeIndex).LastToken
        If Tokens(TokenIndex).Spelling = "(" And OpenToken < 0 Then
            OpenToken = TokenIndex
        End If
        If Tokens(TokenIndex).Spelling = ")" And OpenToken >= 0 Then
            CloseToken = TokenIndex
            Exit While
        End If
        TokenIndex = TokenIndex + 1
    Wend
    If OpenToken < 0 Or CloseToken <= OpenToken + 1 Then
        InterfaceMemberParameterCount = 0
        Exit Function
    End If
    Dim Result As Long = 1
    TokenIndex = OpenToken + 1
    While TokenIndex < CloseToken
        If Tokens(TokenIndex).Spelling = "," Then
            Result = Result + 1
        End If
        TokenIndex = TokenIndex + 1
    Wend
    InterfaceMemberParameterCount = Result
End Function

Function InterfaceMemberKind(ByVal NodeIndex As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken) As Long
    Dim HasProperty As Long = 0
    Dim HasGet As Long = 0
    Dim HasLet As Long = 0
    Dim HasSet As Long = 0
    Dim HasFunction As Long = 0
    Dim HasSub As Long = 0
    Dim HeaderLine As Long = Tokens(SyntaxNodes(NodeIndex).FirstToken).LineNumber
    Dim TokenIndex As Long = SyntaxNodes(NodeIndex).FirstToken
    While TokenIndex <= SyntaxNodes(NodeIndex).LastToken And Tokens(TokenIndex).LineNumber = HeaderLine
        If EqualsFolded(Tokens(TokenIndex).Spelling, "Property") <> 0 Then
            HasProperty = 1
        End If
        If EqualsFolded(Tokens(TokenIndex).Spelling, "Get") <> 0 Then
            HasGet = 1
        End If
        If EqualsFolded(Tokens(TokenIndex).Spelling, "Let") <> 0 Then
            HasLet = 1
        End If
        If EqualsFolded(Tokens(TokenIndex).Spelling, "Set") <> 0 Then
            HasSet = 1
        End If
        If EqualsFolded(Tokens(TokenIndex).Spelling, "Function") <> 0 Then
            HasFunction = 1
        End If
        If EqualsFolded(Tokens(TokenIndex).Spelling, "Sub") <> 0 Then
            HasSub = 1
        End If
        TokenIndex = TokenIndex + 1
    Wend
    If HasProperty <> 0 Then
        If HasGet <> 0 Then
            InterfaceMemberKind = 3
        End If
        If HasLet <> 0 Then
            InterfaceMemberKind = 4
        End If
        If HasSet <> 0 Then
            InterfaceMemberKind = 5
        End If
        Exit Function
    End If
    If HasFunction <> 0 Then
        InterfaceMemberKind = 2
        Exit Function
    End If
    If HasSub <> 0 Then
        InterfaceMemberKind = 1
        Exit Function
    End If
    InterfaceMemberKind = 0
End Function

Function InterfaceParameterStart(ByVal NodeIndex As Long, ByVal Ordinal As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken) As Long
    Dim TokenIndex As Long = SyntaxNodes(NodeIndex).FirstToken
    Dim Depth As Long = 0
    Dim CurrentOrdinal As Long = 0
    While TokenIndex <= SyntaxNodes(NodeIndex).LastToken
        If Tokens(TokenIndex).Spelling = "(" Then
            Depth = Depth + 1
            If Depth = 1 Then
                If Ordinal = 0 Then
                    InterfaceParameterStart = TokenIndex + 1
                    Exit Function
                End If
            End If
        Else
            If Tokens(TokenIndex).Spelling = ")" Then
                Depth = Depth - 1
            Else
                If Depth = 1 And Tokens(TokenIndex).Spelling = "," Then
                    CurrentOrdinal = CurrentOrdinal + 1
                    If CurrentOrdinal = Ordinal Then
                        InterfaceParameterStart = TokenIndex + 1
                        Exit Function
                    End If
                End If
            End If
        End If
        TokenIndex = TokenIndex + 1
    Wend
    InterfaceParameterStart = -1
End Function

Function InterfaceParameterEnd(ByVal NodeIndex As Long, ByVal Ordinal As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken) As Long
    Dim StartToken As Long = InterfaceParameterStart(NodeIndex, Ordinal, SyntaxNodes, Tokens)
    If StartToken < 0 Then
        InterfaceParameterEnd = -1
        Exit Function
    End If
    Dim TokenIndex As Long = StartToken
    Dim NestedDepth As Long = 0
    While TokenIndex <= SyntaxNodes(NodeIndex).LastToken
        If Tokens(TokenIndex).Spelling = "(" Then
            NestedDepth = NestedDepth + 1
        Else
            If Tokens(TokenIndex).Spelling = ")" Then
                If NestedDepth = 0 Then
                    InterfaceParameterEnd = TokenIndex - 1
                    Exit Function
                End If
                NestedDepth = NestedDepth - 1
            Else
                If Tokens(TokenIndex).Spelling = "," And NestedDepth = 0 Then
                    InterfaceParameterEnd = TokenIndex - 1
                    Exit Function
                End If
            End If
        End If
        TokenIndex = TokenIndex + 1
    Wend
    InterfaceParameterEnd = SyntaxNodes(NodeIndex).LastToken
End Function

Function InterfaceParameterFlags(ByVal NodeIndex As Long, ByVal Ordinal As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken) As Long
    Dim FirstToken As Long = InterfaceParameterStart(NodeIndex, Ordinal, SyntaxNodes, Tokens)
    Dim LastToken As Long = InterfaceParameterEnd(NodeIndex, Ordinal, SyntaxNodes, Tokens)
    Dim Result As Long = 0
    Dim TokenIndex As Long = FirstToken
    While TokenIndex >= 0 And TokenIndex <= LastToken
        If EqualsFolded(Tokens(TokenIndex).Spelling, "Optional") <> 0 Then
            Result = Result + 1
        End If
        If EqualsFolded(Tokens(TokenIndex).Spelling, "ByVal") <> 0 Then
            Result = Result + 2
        End If
        If EqualsFolded(Tokens(TokenIndex).Spelling, "ByRef") <> 0 Then
            Result = Result + 4
        End If
        If EqualsFolded(Tokens(TokenIndex).Spelling, "ParamArray") <> 0 Then
            Result = Result + 8
        End If
        TokenIndex = TokenIndex + 1
    Wend
    If (Result And 6) = 0 Then
        Result = Result + 4
    End If
    InterfaceParameterFlags = Result
End Function

Function InterfaceTypeAfterAs(ByVal AsToken As Long, ByVal LastToken As Long, ByRef Tokens() As LexicalToken, ByRef Types() As SemanticType, ByVal TypeCount As Long) As Long
    Dim TypeToken As Long = AsToken + 1
    While TypeToken <= LastToken
        If Tokens(TypeToken).TokenKind < 9 Or Tokens(TypeToken).TokenKind > 12 Then
            Dim TypeName As String = Tokens(TypeToken).Spelling
            If Tokens(TypeToken).TokenKind = 3 Then
                TypeName = Tokens(TypeToken).Decoded
            End If
            InterfaceTypeAfterAs = FindSemanticType(TypeName, Types, TypeCount)
            Exit Function
        End If
        TypeToken = TypeToken + 1
    Wend
    InterfaceTypeAfterAs = -1
End Function

Function InterfaceParameterType(ByVal NodeIndex As Long, ByVal Ordinal As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken, ByRef Types() As SemanticType, ByVal TypeCount As Long) As Long
    Dim FirstToken As Long = InterfaceParameterStart(NodeIndex, Ordinal, SyntaxNodes, Tokens)
    Dim LastToken As Long = InterfaceParameterEnd(NodeIndex, Ordinal, SyntaxNodes, Tokens)
    Dim ArrayRank As Long = 0
    Dim TokenIndex As Long = FirstToken
    While TokenIndex >= 0 And TokenIndex <= LastToken
        If Tokens(TokenIndex).Spelling = "(" Then
            ArrayRank = 1
            Dim RankToken As Long = TokenIndex + 1
            While RankToken <= LastToken And Tokens(RankToken).Spelling <> ")"
                If Tokens(RankToken).Spelling = "," Then
                    ArrayRank = ArrayRank + 1
                End If
                RankToken = RankToken + 1
            Wend
            Exit While
        End If
        TokenIndex = TokenIndex + 1
    Wend
    TokenIndex = FirstToken
    While TokenIndex >= 0 And TokenIndex < LastToken
        If EqualsFolded(Tokens(TokenIndex).Spelling, "As") <> 0 Then
            Dim ElementType As Long = InterfaceTypeAfterAs(TokenIndex, LastToken, Tokens, Types, TypeCount)
            If ArrayRank > 0 Then
                Dim TypeIndex As Long = 0
                While TypeIndex < TypeCount
                    If Types(TypeIndex).TypeKind = 41 And Types(TypeIndex).ElementType = ElementType And Types(TypeIndex).ArrayRank = ArrayRank Then
                        InterfaceParameterType = TypeIndex
                        Exit Function
                    End If
                    TypeIndex = TypeIndex + 1
                Wend
                InterfaceParameterType = -1
                Exit Function
            End If
            InterfaceParameterType = ElementType
            Exit Function
        End If
        TokenIndex = TokenIndex + 1
    Wend
    InterfaceParameterType = FindSemanticType("Variant", Types, TypeCount)
End Function

Function InterfaceMemberResultType(ByVal NodeIndex As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken, ByRef Types() As SemanticType, ByVal TypeCount As Long) As Long
    Dim Kind As Long = InterfaceMemberKind(NodeIndex, SyntaxNodes, Tokens)
    If Kind = 1 Or Kind = 4 Or Kind = 5 Then
        InterfaceMemberResultType = -1
        Exit Function
    End If
    Dim HeaderLine As Long = Tokens(SyntaxNodes(NodeIndex).FirstToken).LineNumber
    Dim CloseToken As Long = -1
    Dim TokenIndex As Long = SyntaxNodes(NodeIndex).FirstToken
    Dim ParenthesisDepth As Long = 0
    While TokenIndex <= SyntaxNodes(NodeIndex).LastToken And Tokens(TokenIndex).LineNumber = HeaderLine
        If Tokens(TokenIndex).Spelling = "(" Then
            ParenthesisDepth = ParenthesisDepth + 1
        Else
            If Tokens(TokenIndex).Spelling = ")" Then
                ParenthesisDepth = ParenthesisDepth - 1
                If ParenthesisDepth = 0 Then
                    CloseToken = TokenIndex
                End If
            End If
        End If
        If CloseToken >= 0 And EqualsFolded(Tokens(TokenIndex).Spelling, "As") <> 0 And TokenIndex < SyntaxNodes(NodeIndex).LastToken Then
            InterfaceMemberResultType = InterfaceTypeAfterAs(TokenIndex, SyntaxNodes(NodeIndex).LastToken, Tokens, Types, TypeCount)
            Exit Function
        End If
        TokenIndex = TokenIndex + 1
    Wend
    InterfaceMemberResultType = FindSemanticType("Variant", Types, TypeCount)
End Function

Function InterfaceMemberSignatureMatches(ByVal InterfaceNode As Long, ByVal CandidateSymbol As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long) As Long
    If Symbols(CandidateSymbol).VisibilityKind <> 1 Then
        InterfaceMemberSignatureMatches = 0
        Exit Function
    End If
    Dim CandidateNode As Long = Symbols(CandidateSymbol).SyntaxNode
    If InterfaceMemberKind(InterfaceNode, SyntaxNodes, Tokens) <> InterfaceMemberKind(CandidateNode, SyntaxNodes, Tokens) Then
        InterfaceMemberSignatureMatches = 0
        Exit Function
    End If
    Dim ParameterCount As Long = InterfaceMemberParameterCount(InterfaceNode, SyntaxNodes, Tokens)
    If CountCalledParameters(CandidateSymbol, Symbols, SymbolCount) <> ParameterCount Then
        InterfaceMemberSignatureMatches = 0
        Exit Function
    End If
    Dim Ordinal As Long = 0
    While Ordinal < ParameterCount
        Dim CandidateParameter As Long = -1
        Dim SymbolIndex As Long = 0
        While SymbolIndex < SymbolCount
            If Symbols(SymbolIndex).SymbolKind = SemanticSymbolParameter() And Symbols(SymbolIndex).ParentSymbol = CandidateSymbol And Symbols(SymbolIndex).ParameterOrdinal = Ordinal Then
                CandidateParameter = SymbolIndex
                Exit While
            End If
            SymbolIndex = SymbolIndex + 1
        Wend
        Dim ExpectedFlags As Long = InterfaceParameterFlags(InterfaceNode, Ordinal, SyntaxNodes, Tokens)
        Dim ActualFlags As Long = 0
        If CandidateParameter >= 0 Then
            ActualFlags = Symbols(CandidateParameter).Flags And 15
        End If
        If (ActualFlags And 6) = 0 Then
            ActualFlags = ActualFlags + 4
        End If
        If CandidateParameter < 0 Or ActualFlags <> ExpectedFlags Or Symbols(CandidateParameter).DeclaredType <> InterfaceParameterType(InterfaceNode, Ordinal, SyntaxNodes, Tokens, Types, TypeCount) Then
            InterfaceMemberSignatureMatches = 0
            Exit Function
        End If
        Ordinal = Ordinal + 1
    Wend
    If Symbols(CandidateSymbol).DeclaredType <> InterfaceMemberResultType(InterfaceNode, SyntaxNodes, Tokens, Types, TypeCount) Then
        InterfaceMemberSignatureMatches = 0
        Exit Function
    End If
    InterfaceMemberSignatureMatches = 1
End Function

Function EventHandlerSignatureMatches(ByVal EventSymbol As Long, ByVal HandlerSymbol As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long) As Long
    Dim EventCount As Long = 0
    Dim HandlerCount As Long = 0
    Dim SymbolIndex As Long = 0
    While SymbolIndex < SymbolCount
        If Symbols(SymbolIndex).SymbolKind = SemanticSymbolParameter() Then
            If Symbols(SymbolIndex).ParentSymbol = EventSymbol Then
                EventCount = EventCount + 1
            End If
            If Symbols(SymbolIndex).ParentSymbol = HandlerSymbol Then
                HandlerCount = HandlerCount + 1
            End If
        End If
        SymbolIndex = SymbolIndex + 1
    Wend
    If EventCount <> HandlerCount Then
        EventHandlerSignatureMatches = 0
        Exit Function
    End If
    Dim Ordinal As Long = 0
    While Ordinal < EventCount
        Dim EventParameter As Long = -1
        Dim HandlerParameter As Long = -1
        SymbolIndex = 0
        While SymbolIndex < SymbolCount
            If Symbols(SymbolIndex).SymbolKind = SemanticSymbolParameter() And Symbols(SymbolIndex).ParameterOrdinal = Ordinal Then
                If Symbols(SymbolIndex).ParentSymbol = EventSymbol Then
                    EventParameter = SymbolIndex
                End If
                If Symbols(SymbolIndex).ParentSymbol = HandlerSymbol Then
                    HandlerParameter = SymbolIndex
                End If
            End If
            SymbolIndex = SymbolIndex + 1
        Wend
        If EventParameter < 0 Or HandlerParameter < 0 Then
            EventHandlerSignatureMatches = 0
            Exit Function
        End If
        Dim EventPassing As Long = Symbols(EventParameter).Flags And 6
        Dim HandlerPassing As Long = Symbols(HandlerParameter).Flags And 6
        If EventPassing = 0 Then
            EventPassing = 4
        End If
        If HandlerPassing = 0 Then
            HandlerPassing = 4
        End If
        If EventPassing <> HandlerPassing Or Symbols(EventParameter).DeclaredType <> Symbols(HandlerParameter).DeclaredType Then
            EventHandlerSignatureMatches = 0
            Exit Function
        End If
        Ordinal = Ordinal + 1
    Wend
    EventHandlerSignatureMatches = 1
End Function

Function ValidateSemanticContracts(ByRef Project As ProjectDescription, ByRef Sources() As SourceDocument, ByRef SyntaxNodes() As SyntaxNode, ByVal SyntaxNodeCount As Long, ByRef SyntaxLinks() As SyntaxChildLink, ByRef Rules() As GrammarRule, ByRef Tokens() As LexicalToken, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef State As SemanticState, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim SymbolIndex As Long = 0
    While SymbolIndex < SymbolCount
        If Symbols(SymbolIndex).SymbolKind = SemanticSymbolVariable() And (Symbols(SymbolIndex).Flags And 128) <> 0 Then
            Dim EventFieldOwner As Long = Symbols(SymbolIndex).ParentSymbol
            Dim EventFieldType As Long = Symbols(SymbolIndex).DeclaredType
            Dim EventSourceSymbol As Long = -1
            If EventFieldOwner < 0 Or EventFieldOwner >= SymbolCount Or Symbols(EventFieldOwner).SymbolKind <> SemanticSymbolModule() Then
                Call AddSemanticDiagnostic("UBE4044", Symbols(SymbolIndex).SyntaxNode, "WithEvents is available only for a module, class, form, or control field", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
            End If
            If EventFieldType >= 0 And EventFieldType < TypeCount Then
                Dim EventFieldTypeKind As Long = Types(EventFieldType).TypeKind
                If EventFieldTypeKind = 30 Or (EventFieldTypeKind >= 50 And EventFieldTypeKind <= 52) Then
                    EventSourceSymbol = Types(EventFieldType).TypeSymbol
                End If
            End If
            If EventSourceSymbol < 0 Then
                Call AddSemanticDiagnostic("UBE4045", Symbols(SymbolIndex).SyntaxNode, "WithEvents requires a scalar class, interface, form, or control type", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Else
                Dim DeclaredEventCount As Long = 0
                Dim EventCandidate As Long = 0
                While EventCandidate < SymbolCount
                    If Symbols(EventCandidate).SymbolKind = SemanticSymbolEvent() And Symbols(EventCandidate).ParentSymbol = EventSourceSymbol Then
                        DeclaredEventCount = DeclaredEventCount + 1
                        Dim HandlerName As String = Symbols(SymbolIndex).SymbolName & "_" & Symbols(EventCandidate).SymbolName
                        Dim HandlerCandidate As Long = 0
                        While HandlerCandidate < SymbolCount
                            If Symbols(HandlerCandidate).ParentSymbol = EventFieldOwner And EqualsFolded(Symbols(HandlerCandidate).SymbolName, HandlerName) <> 0 Then
                                Dim HandlerValid As Long = 1
                                If Symbols(HandlerCandidate).SymbolKind <> SemanticSymbolProcedure() Or Symbols(HandlerCandidate).VisibilityKind <> 2 Or Symbols(HandlerCandidate).DeclaredType >= 0 Then
                                    HandlerValid = 0
                                End If
                                If SyntaxNodeContainsToken(Symbols(HandlerCandidate).SyntaxNode, "Sub", SyntaxNodes, Tokens) = 0 Then
                                    HandlerValid = 0
                                End If
                                If HandlerValid <> 0 Then
                                    HandlerValid = EventHandlerSignatureMatches(EventCandidate, HandlerCandidate, Symbols, SymbolCount)
                                End If
                                If HandlerValid = 0 Then
                                    Call AddSemanticDiagnostic("UBE4047", Symbols(HandlerCandidate).SyntaxNode, "WithEvents handler must be a Private Sub with the exact Event signature: " & HandlerName, Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                End If
                            End If
                            HandlerCandidate = HandlerCandidate + 1
                        Wend
                    End If
                    EventCandidate = EventCandidate + 1
                Wend
                If DeclaredEventCount = 0 Then
                    Call AddSemanticDiagnostic("UBE4046", Symbols(SymbolIndex).SyntaxNode, "WithEvents type does not declare any events", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                End If
            End If
            If (Symbols(SymbolIndex).Flags And 16) <> 0 Then
                Call AddSemanticDiagnostic("UBE4048", Symbols(SymbolIndex).SyntaxNode, "WithEvents cannot be combined with As New", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
            End If
        End If
        If (Symbols(SymbolIndex).Flags And 64) <> 0 Then
            If EqualsFolded(Project.Kind, "Library") = 0 Then
                Call AddSemanticDiagnostic("UBE4031", Symbols(SymbolIndex).SyntaxNode, "Public Export is valid only in a Library project", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
            End If
            If Symbols(SymbolIndex).VisibilityKind <> 1 Or Symbols(SymbolIndex).SymbolKind <> SemanticSymbolProcedure() Then
                Call AddSemanticDiagnostic("UBE4032", Symbols(SymbolIndex).SyntaxNode, "Export requires an explicitly Public Sub or Function", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
            End If
            If Symbols(SymbolIndex).DeclaredType >= 0 Then
                Dim ExportResultKind As Long = Types(Symbols(SymbolIndex).DeclaredType).TypeKind
                If ExportResultKind <> 4 And ExportResultKind <> 5 And ExportResultKind <> 12 And ExportResultKind <> 30 And (ExportResultKind < 50 Or ExportResultKind > 52) Then
                    Call AddSemanticDiagnostic("UBE4036", Symbols(SymbolIndex).SyntaxNode, "this RP6 foreign ABI subset supports only Long, LongLong, or object-like results", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                End If
            End If
            Dim ExportParameterSymbol As Long = 0
            While ExportParameterSymbol < SymbolCount
                If Symbols(ExportParameterSymbol).SymbolKind = SemanticSymbolParameter() And Symbols(ExportParameterSymbol).ParentSymbol = SymbolIndex Then
                    Dim ExportParameterKind As Long = Types(Symbols(ExportParameterSymbol).DeclaredType).TypeKind
                    If ExportParameterKind <> 4 And ExportParameterKind <> 5 Then
                        Call AddSemanticDiagnostic("UBE4037", Symbols(ExportParameterSymbol).SyntaxNode, "this RP6 foreign ABI subset supports only Long or LongLong parameters", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    End If
                End If
                ExportParameterSymbol = ExportParameterSymbol + 1
            Wend
        End If
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
        If Symbols(SymbolIndex).SymbolKind = SemanticSymbolProcedure() Then
            Dim IsModuleInitialize As Long = EqualsFolded(Symbols(SymbolIndex).SymbolName, "Module_Initialize")
            Dim IsModuleTerminate As Long = EqualsFolded(Symbols(SymbolIndex).SymbolName, "Module_Terminate")
            Dim IsClassInitialize As Long = EqualsFolded(Symbols(SymbolIndex).SymbolName, "Class_Initialize")
            Dim IsClassTerminate As Long = EqualsFolded(Symbols(SymbolIndex).SymbolName, "Class_Terminate")
            If IsModuleInitialize <> 0 Or IsModuleTerminate <> 0 Or IsClassInitialize <> 0 Or IsClassTerminate <> 0 Then
                Dim LifecycleParameterCount As Long = 0
                Dim LifecycleParameter As Long = 0
                While LifecycleParameter < SymbolCount
                    If Symbols(LifecycleParameter).SymbolKind = SemanticSymbolParameter() And Symbols(LifecycleParameter).ParentSymbol = SymbolIndex Then
                        LifecycleParameterCount = LifecycleParameterCount + 1
                    End If
                    LifecycleParameter = LifecycleParameter + 1
                Wend
                If LifecycleParameterCount <> 0 Or Symbols(SymbolIndex).DeclaredType >= 0 Or Symbols(SymbolIndex).VisibilityKind <> 2 Then
                    Call AddSemanticDiagnostic("UBE4033", Symbols(SymbolIndex).SyntaxNode, "lifecycle hooks must be Private parameterless Subs", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                End If
                Dim LifecycleOwner As Long = Symbols(SymbolIndex).ParentSymbol
                If LifecycleOwner < 0 Then
                    Call AddSemanticDiagnostic("UBE4034", Symbols(SymbolIndex).SyntaxNode, "lifecycle hook has no owning module or class", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Else
                    If IsModuleInitialize <> 0 Or IsModuleTerminate <> 0 Then
                        If Symbols(LifecycleOwner).SymbolKind <> SemanticSymbolModule() Or Symbols(LifecycleOwner).Flags <> 1 Then
                            Call AddSemanticDiagnostic("UBE4034", Symbols(SymbolIndex).SyntaxNode, "Module lifecycle hooks are valid only in standard modules", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        End If
                    Else
                        If Symbols(LifecycleOwner).SymbolKind <> SemanticSymbolModule() Or Symbols(LifecycleOwner).Flags < 2 Then
                            Call AddSemanticDiagnostic("UBE4034", Symbols(SymbolIndex).SyntaxNode, "Class lifecycle hooks are valid only in classes, forms, or controls", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        End If
                    End If
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
            If LabelName = "0" Then
                Dim LabelAncestor As Long = SyntaxNodes(NodeIndex).ParentNode
                While LabelAncestor >= 0 And FoundLabel = 0
                    If EqualsFolded(Rules(SyntaxNodes(LabelAncestor).ProductionRule).RuleName, "error-statement") <> 0 Then
                        If SyntaxNodeContainsToken(LabelAncestor, "On", SyntaxNodes, Tokens) <> 0 And SyntaxNodeContainsToken(LabelAncestor, "GoTo", SyntaxNodes, Tokens) <> 0 Then
                            FoundLabel = 1
                        End If
                        LabelAncestor = -1
                    Else
                        LabelAncestor = SyntaxNodes(LabelAncestor).ParentNode
                    End If
                Wend
            End If
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
        If EqualsFolded(RuleName, "implements-statement") <> 0 Then
            Dim ImplementedName As String = LastIdentifierInNode(NodeIndex, SyntaxNodes, Tokens)
            Dim ImplementedInterface As Long = -1
            Dim ImplementingModule As Long = -1
            SymbolIndex = 0
            While SymbolIndex < SymbolCount
                If Symbols(SymbolIndex).SymbolKind = SemanticSymbolInterface() And EqualsFolded(Symbols(SymbolIndex).SymbolName, ImplementedName) <> 0 Then
                    ImplementedInterface = SymbolIndex
                End If
                If Symbols(SymbolIndex).SymbolKind = SemanticSymbolModule() And Symbols(SymbolIndex).SourceId = SyntaxNodes(NodeIndex).SourceId Then
                    ImplementingModule = SymbolIndex
                End If
                SymbolIndex = SymbolIndex + 1
            Wend
            If ImplementedInterface < 0 Then
                Call AddSemanticDiagnostic("UBE4038", NodeIndex, "Implements names an unknown Interface: " & ImplementedName, Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Else
                If ImplementingModule < 0 Or Symbols(ImplementingModule).Flags < 2 Then
                    Call AddSemanticDiagnostic("UBE4039", NodeIndex, "Implements is valid only in a class, form, or control", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Else
                    Dim InterfaceNode As Long = Symbols(ImplementedInterface).SyntaxNode
                    Dim MemberNode As Long = 0
                    While MemberNode < SyntaxNodeCount
                        Dim IsInterfaceMember As Long = 0
                        If EqualsFolded(Rules(SyntaxNodes(MemberNode).ProductionRule).RuleName, "interface-member") <> 0 Then
                            Dim MemberAncestor As Long = SyntaxNodes(MemberNode).ParentNode
                            While MemberAncestor >= 0
                                If MemberAncestor = InterfaceNode Then
                                    IsInterfaceMember = 1
                                    MemberAncestor = -1
                                Else
                                    MemberAncestor = SyntaxNodes(MemberAncestor).ParentNode
                                End If
                            Wend
                        End If
                        If IsInterfaceMember <> 0 Then
                            Dim RequiredName As String = InterfaceMemberDeclaredName(MemberNode, SyntaxNodes, Tokens)
                            Dim RequiredParameters As Long = InterfaceMemberParameterCount(MemberNode, SyntaxNodes, Tokens)
                            Dim RequiredIsProperty As Long = SyntaxNodeContainsToken(MemberNode, "Property", SyntaxNodes, Tokens)
                            Dim MatchingMember As Long = -1
                            Dim CandidateMember As Long = 0
                            While CandidateMember < SymbolCount
                                If Symbols(CandidateMember).ParentSymbol = ImplementingModule Then
                                    Dim CandidateNameMatches As Long = EqualsFolded(Symbols(CandidateMember).SymbolName, RequiredName)
                                    If EqualsFolded(Symbols(CandidateMember).ConstantText, RequiredName) <> 0 Then
                                        CandidateNameMatches = 1
                                    End If
                                    If CandidateNameMatches <> 0 Then
                                        If RequiredIsProperty <> 0 And Symbols(CandidateMember).SymbolKind = SemanticSymbolProperty() Then
                                            If CountCalledParameters(CandidateMember, Symbols, SymbolCount) = RequiredParameters And InterfaceMemberSignatureMatches(MemberNode, CandidateMember, SyntaxNodes, Tokens, Types, TypeCount, Symbols, SymbolCount) <> 0 Then
                                                MatchingMember = CandidateMember
                                            End If
                                        End If
                                        If RequiredIsProperty = 0 And Symbols(CandidateMember).SymbolKind = SemanticSymbolProcedure() Then
                                            If CountCalledParameters(CandidateMember, Symbols, SymbolCount) = RequiredParameters And InterfaceMemberSignatureMatches(MemberNode, CandidateMember, SyntaxNodes, Tokens, Types, TypeCount, Symbols, SymbolCount) <> 0 Then
                                                MatchingMember = CandidateMember
                                            End If
                                        End If
                                    End If
                                End If
                                CandidateMember = CandidateMember + 1
                            Wend
                            If MatchingMember < 0 Then
                                Call AddSemanticDiagnostic("UBE4040", NodeIndex, "class does not provide the required Interface member: " & RequiredName, Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                            End If
                        End If
                        MemberNode = MemberNode + 1
                    Wend
                End If
            End If
        End If
        If EqualsFolded(RuleName, "call-new-expression") <> 0 Then
            Dim QualifiedNode As Long = FirstDescendantSyntaxNode(NodeIndex, "qualified-name", SyntaxNodes, SyntaxLinks, Rules, 0)
            Dim TargetName As String = LastIdentifierInNode(QualifiedNode, SyntaxNodes, Tokens)
            Dim MatchCount As Long = 0
            Dim CallNewTargetSymbol As Long = -1
            SymbolIndex = 0
            While SymbolIndex < SymbolCount
                If Symbols(SymbolIndex).SymbolKind = SemanticSymbolProcedure() And EqualsFolded(Symbols(SymbolIndex).SymbolName, TargetName) <> 0 Then
                    If SyntaxNodeContainsToken(Symbols(SymbolIndex).SyntaxNode, "Sub", SyntaxNodes, Tokens) <> 0 Then
                        MatchCount = MatchCount + 1
                        CallNewTargetSymbol = SymbolIndex
                    End If
                End If
                SymbolIndex = SymbolIndex + 1
            Wend
            If MatchCount = 0 Then
                Call AddSemanticDiagnostic("UBE4026", NodeIndex, "CallNew target must resolve to a known Sub: " & TargetName, Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Else
                If MatchCount > 1 Then
                    Call AddSemanticDiagnostic("UBE4027", NodeIndex, "CallNew target is ambiguous: " & TargetName, Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                Else
                    Dim CallNewParameterSymbol As Long = 0
                    While CallNewParameterSymbol < SymbolCount
                        If Symbols(CallNewParameterSymbol).SymbolKind = SemanticSymbolParameter() And Symbols(CallNewParameterSymbol).ParentSymbol = CallNewTargetSymbol Then
                            If (Symbols(CallNewParameterSymbol).Flags And 2) = 0 Then
                                Call AddSemanticDiagnostic("UBE4028", NodeIndex, "CallNew target parameters must be declared ByVal: " & Symbols(CallNewParameterSymbol).SymbolName, Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                            End If
                        End If
                        CallNewParameterSymbol = CallNewParameterSymbol + 1
                    Wend
                End If
            End If
        End If
        If EqualsFolded(RuleName, "call-statement") <> 0 Then
            Dim CalledName As String = LastIdentifierInNode(NodeIndex, SyntaxNodes, Tokens)
            If EqualsFolded(CalledName, "Module_Initialize") <> 0 Or EqualsFolded(CalledName, "Module_Terminate") <> 0 Or EqualsFolded(CalledName, "Class_Initialize") <> 0 Or EqualsFolded(CalledName, "Class_Terminate") <> 0 Then
                Call AddSemanticDiagnostic("UBE4035", NodeIndex, "lifecycle hooks cannot be called directly", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
            End If
        End If
        NodeIndex = NodeIndex + 1
    Wend
    ValidateSemanticContracts = 1
End Function
