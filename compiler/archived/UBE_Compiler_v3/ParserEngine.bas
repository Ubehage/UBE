UBE SOURCE 1 MODULE
Attribute UBE_Name = "ParserEngine"

Function TokenMatchesLiteral(ByRef Tokens() As LexicalToken, ByVal TokenPosition As Long, ByVal TokenLimit As Long, ByVal Value As String) As Long
    If TokenPosition >= TokenLimit Then
        TokenMatchesLiteral = 0
        Exit Function
    End If
    If EqualsFolded(Tokens(TokenPosition).Spelling, Value) <> 0 Then
        TokenMatchesLiteral = 1
    Else
        TokenMatchesLiteral = 0
    End If
End Function

Function TokenIsDecimalDigits(ByRef Tokens() As LexicalToken, ByVal TokenPosition As Long, ByVal TokenLimit As Long) As Long
    If TokenPosition >= TokenLimit Then
        TokenIsDecimalDigits = 0
        Exit Function
    End If
    If Tokens(TokenPosition).TokenKind <> 4 Then
        TokenIsDecimalDigits = 0
        Exit Function
    End If
    Dim TokenText As String = Tokens(TokenPosition).Spelling
    Dim Index As Long = 0
    If StringLength(TokenText) = 0 Then
        TokenIsDecimalDigits = 0
        Exit Function
    End If
    While Index < StringLength(TokenText)
        If IsAsciiDigit(StringByteAt(TokenText, Index)) = 0 Then
            TokenIsDecimalDigits = 0
            Exit Function
        End If
        Index = Index + 1
    Wend
    TokenIsDecimalDigits = 1
End Function

Function MatchSpecialGrammarRule(ByVal RuleName As String, ByRef Tokens() As LexicalToken, ByVal TokenPosition As Long, ByVal TokenLimit As Long, ByRef ResultPosition As Long, ByRef WasSpecial As Long, ByRef Progress As ParseProgress) As Long
    WasSpecial = 1
    If RuleName = "comment" Then
        If TokenPosition < TokenLimit Then
            If Tokens(TokenPosition).TokenKind = 10 Then
                ResultPosition = TokenPosition + 1
                MatchSpecialGrammarRule = 1
                Exit Function
            End If
        End If
    Else
        If RuleName = "explicit-continuation" Then
            If TokenPosition < TokenLimit Then
                If Tokens(TokenPosition).TokenKind = 12 Then
                    ResultPosition = TokenPosition + 1
                    MatchSpecialGrammarRule = 1
                    Exit Function
                End If
            End If
        Else
            If RuleName = "bare-identifier" Then
                If TokenPosition < TokenLimit Then
                    If Tokens(TokenPosition).TokenKind = 2 Then
                        ResultPosition = TokenPosition + 1
                        MatchSpecialGrammarRule = 1
                        Exit Function
                    End If
                End If
            Else
                If RuleName = "bracketed-identifier" Then
                    If TokenPosition < TokenLimit Then
                        If Tokens(TokenPosition).TokenKind = 3 Then
                            ResultPosition = TokenPosition + 1
                            MatchSpecialGrammarRule = 1
                            Exit Function
                        End If
                    End If
                Else
                    If RuleName = "integer-literal" Then
                        If TokenPosition < TokenLimit Then
                            If Tokens(TokenPosition).TokenKind = 4 Then
                                ResultPosition = TokenPosition + 1
                                MatchSpecialGrammarRule = 1
                                Exit Function
                            End If
                        End If
                    Else
                        If RuleName = "real-literal" Then
                            If TokenPosition < TokenLimit Then
                                If Tokens(TokenPosition).TokenKind = 5 Then
                                    ResultPosition = TokenPosition + 1
                                    MatchSpecialGrammarRule = 1
                                    Exit Function
                                End If
                            End If
                        Else
                            If RuleName = "string-literal" Then
                                If TokenPosition < TokenLimit Then
                                    If Tokens(TokenPosition).TokenKind = 6 Then
                                        ResultPosition = TokenPosition + 1
                                        MatchSpecialGrammarRule = 1
                                        Exit Function
                                    End If
                                End If
                            Else
                                If RuleName = "date-literal" Then
                                    If TokenPosition < TokenLimit Then
                                        If Tokens(TokenPosition).TokenKind = 7 Then
                                            ResultPosition = TokenPosition + 1
                                            MatchSpecialGrammarRule = 1
                                            Exit Function
                                        End If
                                    End If
                                Else
                                    If RuleName = "version-number" Then
                                        If TokenPosition < TokenLimit Then
                                            If Tokens(TokenPosition).TokenKind = 5 Then
                                                ResultPosition = TokenPosition + 1
                                                MatchSpecialGrammarRule = 1
                                                Exit Function
                                            End If
                                        End If
                                    Else
                                    If RuleName = "decimal-digits" Then
                                        If TokenIsDecimalDigits(Tokens, TokenPosition, TokenLimit) <> 0 Then
                                            ResultPosition = TokenPosition + 1
                                            MatchSpecialGrammarRule = 1
                                            Exit Function
                                        End If
                                    Else
                                        If RuleName = "line-fragment" Then
                                            ResultPosition = TokenPosition
                                            While ResultPosition < TokenLimit
                                                If Tokens(ResultPosition).TokenKind = 9 Or Tokens(ResultPosition).TokenKind = 13 Then
                                                    Exit While
                                                End If
                                                ResultPosition = ResultPosition + 1
                                            Wend
                                            MatchSpecialGrammarRule = 1
                                            Exit Function
                                        Else
                                            WasSpecial = 0
                                            MatchSpecialGrammarRule = 0
                                            Exit Function
                                        End If
                                    End If
                                    End If
                                End If
                            End If
                        End If
                    End If
                End If
            End If
        End If
    End If
    Call RecordParseExpectation(TokenPosition, RuleName, Progress)
    MatchSpecialGrammarRule = 0
End Function

Function MatchGrammarTerminal(ByVal TerminalName As String, ByRef Tokens() As LexicalToken, ByVal TokenPosition As Long, ByVal TokenLimit As Long, ByRef ResultPosition As Long, ByRef Progress As ParseProgress) As Long
    If TokenPosition >= TokenLimit Then
        Call RecordParseExpectation(TokenPosition, TerminalName, Progress)
        MatchGrammarTerminal = 0
        Exit Function
    End If
    Dim Kind As Long = Tokens(TokenPosition).TokenKind
    Dim Matches As Long = 0
    If TerminalName = "HSPACE" And Kind = 11 Then
        Matches = 1
    Else
        If TerminalName = "NEWLINE" And Kind = 9 Then
            Matches = 1
        Else
            If TerminalName = "EOF" And Kind = 13 Then
                Matches = 1
            Else
                If TerminalName = "KEYWORD" And Kind = 1 Then
                    Matches = 1
                Else
                    If TerminalName = "REAL_TEXT" And Kind = 5 Then
                        Matches = 1
                    Else
                        If TerminalName = "STRING_TEXT" And Kind = 6 Then
                            Matches = 1
                        Else
                            If TerminalName = "DATE_TEXT" And Kind = 7 Then
                                Matches = 1
                            Else
                                If TerminalName = "BRACKET_IDENTIFIER_TEXT" And Kind = 3 Then
                                    Matches = 1
                                Else
                                    If TerminalName = "COMMENT_TEXT" And Kind = 10 Then
                                        Matches = 1
                                    Else
                                        If TerminalName = "LINE_CHAR" And Kind <> 9 And Kind <> 13 Then
                                            Matches = 1
                                        Else
                                            If TerminalName = "LETTER" And Kind = 2 Then
                                                Matches = 1
                                            End If
                                        End If
                                    End If
                                End If
                            End If
                        End If
                    End If
                End If
            End If
        End If
    End If
    If Matches <> 0 Then
        ResultPosition = TokenPosition + 1
        MatchGrammarTerminal = 1
    Else
        Call RecordParseExpectation(TokenPosition, TerminalName, Progress)
        MatchGrammarTerminal = 0
    End If
End Function

Function MatchGrammarRule(ByVal RuleIndex As Long, ByRef Rules() As GrammarRule, ByVal RuleCount As Long, ByRef GrammarNodes() As GrammarExpression, ByRef GrammarLinks() As GrammarChildLink, ByRef Tokens() As LexicalToken, ByVal TokenPosition As Long, ByVal TokenLimit As Long, ByVal SourceId As Long, ByVal ParentSyntax As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef SyntaxNodeCount As Long, ByRef SyntaxNodeCapacity As Long, ByRef SyntaxLinks() As SyntaxChildLink, ByRef SyntaxLinkCount As Long, ByRef SyntaxLinkCapacity As Long, ByRef ResultPosition As Long, ByRef Progress As ParseProgress, ByVal Depth As Long) As Long
    If Depth > LimitSyntaxDepth() Then
        Progress.LimitExceeded = 1
        Call RecordParseExpectation(TokenPosition, "shallower syntax", Progress)
        MatchGrammarRule = 0
        Exit Function
    End If
    Dim SavedNodeCount As Long = SyntaxNodeCount
    Dim SavedLinkCount As Long = SyntaxLinkCount
    Dim SavedFirstChild As Long = -1
    Dim SavedLastChild As Long = -1
    Dim SavedChildCount As Long = 0
    If ParentSyntax >= 0 Then
        SavedFirstChild = SyntaxNodes(ParentSyntax).FirstChildLink
        SavedLastChild = SyntaxNodes(ParentSyntax).LastChildLink
        SavedChildCount = SyntaxNodes(ParentSyntax).ChildCount
    End If
    Dim SyntaxIndex As Long = AppendSyntaxNode(SyntaxNodes, SyntaxNodeCount, SyntaxNodeCapacity, RuleIndex, SourceId, TokenPosition, ParentSyntax)
    If SyntaxIndex < 0 Then
        Progress.LimitExceeded = 1
        Call RecordParseExpectation(TokenPosition, "syntax within configured node limit", Progress)
        MatchGrammarRule = 0
        Exit Function
    End If
    Dim WasSpecial As Long = 0
    Dim Matched As Long = MatchSpecialGrammarRule(Rules(RuleIndex).RuleName, Tokens, TokenPosition, TokenLimit, ResultPosition, WasSpecial, Progress)
    If WasSpecial = 0 Then
        Matched = MatchGrammarExpression(Rules(RuleIndex).ExpressionNode, Rules, RuleCount, GrammarNodes, GrammarLinks, Tokens, TokenPosition, TokenLimit, SourceId, SyntaxIndex, SyntaxNodes, SyntaxNodeCount, SyntaxNodeCapacity, SyntaxLinks, SyntaxLinkCount, SyntaxLinkCapacity, ResultPosition, Progress, Depth + 1)
    End If
    If Matched = 0 Then
        Call RestoreSyntaxCheckpoint(ParentSyntax, SavedNodeCount, SavedLinkCount, SavedFirstChild, SavedLastChild, SavedChildCount, SyntaxNodes, SyntaxNodeCount, SyntaxLinkCount)
        MatchGrammarRule = 0
        Exit Function
    End If
    SyntaxNodes(SyntaxIndex).LastToken = ResultPosition - 1
    If AppendSyntaxChild(SyntaxNodes, ParentSyntax, SyntaxIndex, SyntaxLinks, SyntaxLinkCount, SyntaxLinkCapacity) = 0 Then
        Progress.LimitExceeded = 1
        Call RestoreSyntaxCheckpoint(ParentSyntax, SavedNodeCount, SavedLinkCount, SavedFirstChild, SavedLastChild, SavedChildCount, SyntaxNodes, SyntaxNodeCount, SyntaxLinkCount)
        MatchGrammarRule = 0
        Exit Function
    End If
    MatchGrammarRule = 1
End Function

Function MatchGrammarExpression(ByVal ExpressionIndex As Long, ByRef Rules() As GrammarRule, ByVal RuleCount As Long, ByRef GrammarNodes() As GrammarExpression, ByRef GrammarLinks() As GrammarChildLink, ByRef Tokens() As LexicalToken, ByVal TokenPosition As Long, ByVal TokenLimit As Long, ByVal SourceId As Long, ByVal ParentSyntax As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef SyntaxNodeCount As Long, ByRef SyntaxNodeCapacity As Long, ByRef SyntaxLinks() As SyntaxChildLink, ByRef SyntaxLinkCount As Long, ByRef SyntaxLinkCapacity As Long, ByRef ResultPosition As Long, ByRef Progress As ParseProgress, ByVal Depth As Long) As Long
    If Depth > LimitSyntaxDepth() Then
        Progress.LimitExceeded = 1
        MatchGrammarExpression = 0
        Exit Function
    End If
    Dim Kind As Long = GrammarNodes(ExpressionIndex).ExpressionKind
    If Kind = 1 Then
        If GrammarNodes(ExpressionIndex).ReferenceRule >= 0 Then
            MatchGrammarExpression = MatchGrammarRule(GrammarNodes(ExpressionIndex).ReferenceRule, Rules, RuleCount, GrammarNodes, GrammarLinks, Tokens, TokenPosition, TokenLimit, SourceId, ParentSyntax, SyntaxNodes, SyntaxNodeCount, SyntaxNodeCapacity, SyntaxLinks, SyntaxLinkCount, SyntaxLinkCapacity, ResultPosition, Progress, Depth + 1)
        Else
            MatchGrammarExpression = MatchGrammarTerminal(GrammarNodes(ExpressionIndex).TextValue, Tokens, TokenPosition, TokenLimit, ResultPosition, Progress)
        End If
        Exit Function
    End If
    If Kind = 2 Then
        If TokenMatchesLiteral(Tokens, TokenPosition, TokenLimit, GrammarNodes(ExpressionIndex).TextValue) <> 0 Then
            ResultPosition = TokenPosition + 1
            MatchGrammarExpression = 1
        Else
            Call RecordParseExpectation(TokenPosition, GrammarNodes(ExpressionIndex).TextValue, Progress)
            MatchGrammarExpression = 0
        End If
        Exit Function
    End If
    Dim SavedNodeCount As Long = SyntaxNodeCount
    Dim SavedLinkCount As Long = SyntaxLinkCount
    Dim SavedFirstChild As Long = -1
    Dim SavedLastChild As Long = -1
    Dim SavedChildCount As Long = 0
    If ParentSyntax >= 0 Then
        SavedFirstChild = SyntaxNodes(ParentSyntax).FirstChildLink
        SavedLastChild = SyntaxNodes(ParentSyntax).LastChildLink
        SavedChildCount = SyntaxNodes(ParentSyntax).ChildCount
    End If
    If Kind = 3 Then
        Dim CurrentPosition As Long = TokenPosition
        Dim ChildLink As Long = GrammarNodes(ExpressionIndex).FirstChildLink
        While ChildLink >= 0
            Dim NextPosition As Long = CurrentPosition
            If MatchGrammarExpression(GrammarLinks(ChildLink).ExpressionNode, Rules, RuleCount, GrammarNodes, GrammarLinks, Tokens, CurrentPosition, TokenLimit, SourceId, ParentSyntax, SyntaxNodes, SyntaxNodeCount, SyntaxNodeCapacity, SyntaxLinks, SyntaxLinkCount, SyntaxLinkCapacity, NextPosition, Progress, Depth + 1) = 0 Then
                Call RestoreSyntaxCheckpoint(ParentSyntax, SavedNodeCount, SavedLinkCount, SavedFirstChild, SavedLastChild, SavedChildCount, SyntaxNodes, SyntaxNodeCount, SyntaxLinkCount)
                MatchGrammarExpression = 0
                Exit Function
            End If
            CurrentPosition = NextPosition
            ChildLink = GrammarLinks(ChildLink).NextLink
        Wend
        ResultPosition = CurrentPosition
        MatchGrammarExpression = 1
        Exit Function
    End If
    If Kind = 4 Then
        Dim AlternativeLink As Long = GrammarNodes(ExpressionIndex).FirstChildLink
        While AlternativeLink >= 0
            Dim AlternativePosition As Long = TokenPosition
            If MatchGrammarExpression(GrammarLinks(AlternativeLink).ExpressionNode, Rules, RuleCount, GrammarNodes, GrammarLinks, Tokens, TokenPosition, TokenLimit, SourceId, ParentSyntax, SyntaxNodes, SyntaxNodeCount, SyntaxNodeCapacity, SyntaxLinks, SyntaxLinkCount, SyntaxLinkCapacity, AlternativePosition, Progress, Depth + 1) <> 0 Then
                ResultPosition = AlternativePosition
                MatchGrammarExpression = 1
                Exit Function
            End If
            Call RestoreSyntaxCheckpoint(ParentSyntax, SavedNodeCount, SavedLinkCount, SavedFirstChild, SavedLastChild, SavedChildCount, SyntaxNodes, SyntaxNodeCount, SyntaxLinkCount)
            AlternativeLink = GrammarLinks(AlternativeLink).NextLink
        Wend
        MatchGrammarExpression = 0
        Exit Function
    End If
    Dim WrappedLink As Long = GrammarNodes(ExpressionIndex).FirstChildLink
    If WrappedLink < 0 Then
        ResultPosition = TokenPosition
        MatchGrammarExpression = 1
        Exit Function
    End If
    If Kind = 5 Then
        Dim OptionalPosition As Long = TokenPosition
        If MatchGrammarExpression(GrammarLinks(WrappedLink).ExpressionNode, Rules, RuleCount, GrammarNodes, GrammarLinks, Tokens, TokenPosition, TokenLimit, SourceId, ParentSyntax, SyntaxNodes, SyntaxNodeCount, SyntaxNodeCapacity, SyntaxLinks, SyntaxLinkCount, SyntaxLinkCapacity, OptionalPosition, Progress, Depth + 1) = 0 Then
            Call RestoreSyntaxCheckpoint(ParentSyntax, SavedNodeCount, SavedLinkCount, SavedFirstChild, SavedLastChild, SavedChildCount, SyntaxNodes, SyntaxNodeCount, SyntaxLinkCount)
            ResultPosition = TokenPosition
        Else
            ResultPosition = OptionalPosition
        End If
        MatchGrammarExpression = 1
        Exit Function
    End If
    If Kind = 6 Then
        Dim RepeatPosition As Long = TokenPosition
        Dim KeepRepeating As Long = 1
        While KeepRepeating <> 0
            Dim IterationNodeCount As Long = SyntaxNodeCount
            Dim IterationLinkCount As Long = SyntaxLinkCount
            Dim IterationFirstChild As Long = -1
            Dim IterationLastChild As Long = -1
            Dim IterationChildCount As Long = 0
            If ParentSyntax >= 0 Then
                IterationFirstChild = SyntaxNodes(ParentSyntax).FirstChildLink
                IterationLastChild = SyntaxNodes(ParentSyntax).LastChildLink
                IterationChildCount = SyntaxNodes(ParentSyntax).ChildCount
            End If
            Dim IterationPosition As Long = RepeatPosition
            If MatchGrammarExpression(GrammarLinks(WrappedLink).ExpressionNode, Rules, RuleCount, GrammarNodes, GrammarLinks, Tokens, RepeatPosition, TokenLimit, SourceId, ParentSyntax, SyntaxNodes, SyntaxNodeCount, SyntaxNodeCapacity, SyntaxLinks, SyntaxLinkCount, SyntaxLinkCapacity, IterationPosition, Progress, Depth + 1) = 0 Then
                Call RestoreSyntaxCheckpoint(ParentSyntax, IterationNodeCount, IterationLinkCount, IterationFirstChild, IterationLastChild, IterationChildCount, SyntaxNodes, SyntaxNodeCount, SyntaxLinkCount)
                KeepRepeating = 0
            Else
                If IterationPosition = RepeatPosition Then
                    KeepRepeating = 0
                Else
                    RepeatPosition = IterationPosition
                End If
            End If
        Wend
        ResultPosition = RepeatPosition
        MatchGrammarExpression = 1
        Exit Function
    End If
    MatchGrammarExpression = 0
End Function

Sub AddParseDiagnostic(ByRef Source As SourceDocument, ByRef Tokens() As LexicalToken, ByVal TokenCount As Long, ByRef Progress As ParseProgress, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long)
    Dim BytePosition As Long = Source.ByteLength
    If Progress.FurthestToken >= 0 And Progress.FurthestToken < TokenCount Then
        BytePosition = Tokens(Progress.FurthestToken).StartByte
    End If
    Dim Message As String = "source does not match UBE 1.0 grammar"
    If StringLength(Progress.Expected) > 0 Then
        Message = Message & "; expected " & Progress.Expected
    End If
    Dim Code As String = "UBE3700"
    If Progress.LimitExceeded <> 0 Then
        Code = "UBE3701"
        Message = "syntax nesting or node limit exceeded"
    End If
    Call AddLexicalDiagnostic(Source, BytePosition, Code, Message, Diagnostics, DiagnosticCount, DiagnosticCapacity)
End Sub

Function TokenAfterPhysicalLine(ByRef Tokens() As LexicalToken, ByVal TokenPosition As Long, ByVal TokenLimit As Long) As Long
    Dim Cursor As Long = TokenPosition
    While Cursor < TokenLimit
        Cursor = Cursor + 1
        If Tokens(Cursor - 1).TokenKind = 9 Then
            TokenAfterPhysicalLine = Cursor
            Exit Function
        End If
    Wend
    TokenAfterPhysicalLine = TokenLimit
End Function

Function IsRecoveryBoundary(ByRef Tokens() As LexicalToken, ByVal TokenPosition As Long, ByVal TokenLimit As Long) As Long
    Dim Cursor As Long = TokenPosition
    While Cursor < TokenLimit
        If Tokens(Cursor).TokenKind = 11 Then
            Cursor = Cursor + 1
        Else
            Exit While
        End If
    Wend
    If Cursor >= TokenLimit Or Tokens(Cursor).TokenKind = 9 Or Tokens(Cursor).TokenKind = 10 Or Tokens(Cursor).TokenKind = 13 Then
        IsRecoveryBoundary = 1
        Exit Function
    End If
    Dim Word As String = Tokens(Cursor).Spelling
    If EqualsFolded(Word, "End") <> 0 Or EqualsFolded(Word, "Else") <> 0 Or EqualsFolded(Word, "ElseIf") <> 0 Or EqualsFolded(Word, "Next") <> 0 Or EqualsFolded(Word, "Wend") <> 0 Or EqualsFolded(Word, "Loop") <> 0 Then
        IsRecoveryBoundary = 1
    Else
        IsRecoveryBoundary = 0
    End If
End Function

Sub RecoverParseDiagnostics(ByRef Source As SourceDocument, ByRef Rules() As GrammarRule, ByVal RuleCount As Long, ByRef GrammarNodes() As GrammarExpression, ByRef GrammarLinks() As GrammarChildLink, ByRef Tokens() As LexicalToken, ByVal StartToken As Long, ByVal TokenLimit As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef SyntaxNodeCount As Long, ByRef SyntaxNodeCapacity As Long, ByRef SyntaxLinks() As SyntaxChildLink, ByRef SyntaxLinkCount As Long, ByRef SyntaxLinkCapacity As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long)
    Dim StatementRule As Long = FindGrammarRule(Rules, RuleCount, "statement-line")
    Dim LocalRule As Long = FindGrammarRule(Rules, RuleCount, "local-declaration")
    Dim ModuleRule As Long = FindGrammarRule(Rules, RuleCount, "module-item")
    Dim Cursor As Long = TokenAfterPhysicalLine(Tokens, StartToken, TokenLimit)
    Dim RecoveryDiagnostics As Long = 0
    While Cursor < TokenLimit And RecoveryDiagnostics < 16
        If Tokens(Cursor).TokenKind = 13 Then
            Exit While
        End If
        Dim SavedNodeCount As Long = SyntaxNodeCount
        Dim SavedLinkCount As Long = SyntaxLinkCount
        Dim ResultPosition As Long = Cursor
        Dim Progress As ParseProgress
        Progress.FurthestToken = Cursor
        Progress.Expected = "statement or declaration"
        Progress.LimitExceeded = 0
        Dim Matched As Long = 0
        If StatementRule >= 0 Then
            Matched = MatchGrammarRule(StatementRule, Rules, RuleCount, GrammarNodes, GrammarLinks, Tokens, Cursor, TokenLimit, Source.SourceId, -1, SyntaxNodes, SyntaxNodeCount, SyntaxNodeCapacity, SyntaxLinks, SyntaxLinkCount, SyntaxLinkCapacity, ResultPosition, Progress, 0)
        End If
        If Matched = 0 And LocalRule >= 0 Then
            SyntaxNodeCount = SavedNodeCount
            SyntaxLinkCount = SavedLinkCount
            ResultPosition = Cursor
            Matched = MatchGrammarRule(LocalRule, Rules, RuleCount, GrammarNodes, GrammarLinks, Tokens, Cursor, TokenLimit, Source.SourceId, -1, SyntaxNodes, SyntaxNodeCount, SyntaxNodeCapacity, SyntaxLinks, SyntaxLinkCount, SyntaxLinkCapacity, ResultPosition, Progress, 0)
        End If
        If Matched = 0 And ModuleRule >= 0 Then
            SyntaxNodeCount = SavedNodeCount
            SyntaxLinkCount = SavedLinkCount
            ResultPosition = Cursor
            Matched = MatchGrammarRule(ModuleRule, Rules, RuleCount, GrammarNodes, GrammarLinks, Tokens, Cursor, TokenLimit, Source.SourceId, -1, SyntaxNodes, SyntaxNodeCount, SyntaxNodeCapacity, SyntaxLinks, SyntaxLinkCount, SyntaxLinkCapacity, ResultPosition, Progress, 0)
        End If
        SyntaxNodeCount = SavedNodeCount
        SyntaxLinkCount = SavedLinkCount
        If Matched <> 0 And ResultPosition > Cursor Then
            Cursor = ResultPosition
        Else
            If IsRecoveryBoundary(Tokens, Cursor, TokenLimit) = 0 Then
                Progress.FurthestToken = Cursor
                Progress.Expected = "valid statement or declaration"
                Call AddParseDiagnostic(Source, Tokens, TokenLimit, Progress, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                RecoveryDiagnostics = RecoveryDiagnostics + 1
            End If
            Cursor = TokenAfterPhysicalLine(Tokens, Cursor, TokenLimit)
        End If
    Wend
End Sub

Function ValidateParserNesting(ByRef Tokens() As LexicalToken, ByVal FirstToken As Long, ByVal TokenLimit As Long, ByRef Progress As ParseProgress) As Long
    Dim ParenthesisDepth As Long = 0
    Dim TokenIndex As Long = FirstToken
    While TokenIndex < TokenLimit
        If Tokens(TokenIndex).TokenKind = 8 Then
            If Tokens(TokenIndex).Spelling = "(" Then
                ParenthesisDepth = ParenthesisDepth + 1
                If ParenthesisDepth > LimitParenthesisDepth() Then
                    Progress.FurthestToken = TokenIndex
                    Progress.Expected = "bounded parenthesis nesting"
                    Progress.LimitExceeded = 1
                    ValidateParserNesting = 0
                    Exit Function
                End If
            Else
                If Tokens(TokenIndex).Spelling = ")" Then
                    If ParenthesisDepth > 0 Then
                        ParenthesisDepth = ParenthesisDepth - 1
                    End If
                End If
            End If
        End If
        TokenIndex = TokenIndex + 1
    Wend
    ValidateParserNesting = 1
End Function

Function ParseOneSource(ByRef Source As SourceDocument, ByRef Rules() As GrammarRule, ByVal RuleCount As Long, ByRef GrammarNodes() As GrammarExpression, ByRef GrammarLinks() As GrammarChildLink, ByRef Tokens() As LexicalToken, ByVal FirstToken As Long, ByVal TokenLimit As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef SyntaxNodeCount As Long, ByRef SyntaxNodeCapacity As Long, ByRef SyntaxLinks() As SyntaxChildLink, ByRef SyntaxLinkCount As Long, ByRef SyntaxLinkCapacity As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim ProgramRule As Long = FindGrammarRule(Rules, RuleCount, "program")
    Dim Progress As ParseProgress
    Progress.FurthestToken = FirstToken
    Progress.Expected = "program"
    Progress.LimitExceeded = 0
    If ValidateParserNesting(Tokens, FirstToken, TokenLimit, Progress) = 0 Then
        Call AddParseDiagnostic(Source, Tokens, TokenLimit, Progress, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        ParseOneSource = 0
        Exit Function
    End If
    Dim ResultPosition As Long = FirstToken
    Dim SavedNodeCount As Long = SyntaxNodeCount
    Dim SavedLinkCount As Long = SyntaxLinkCount
    If MatchGrammarRule(ProgramRule, Rules, RuleCount, GrammarNodes, GrammarLinks, Tokens, FirstToken, TokenLimit, Source.SourceId, -1, SyntaxNodes, SyntaxNodeCount, SyntaxNodeCapacity, SyntaxLinks, SyntaxLinkCount, SyntaxLinkCapacity, ResultPosition, Progress, 0) = 0 Then
        SyntaxNodeCount = SavedNodeCount
        SyntaxLinkCount = SavedLinkCount
        Call AddParseDiagnostic(Source, Tokens, TokenLimit, Progress, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        If Progress.LimitExceeded = 0 Then
            Call RecoverParseDiagnostics(Source, Rules, RuleCount, GrammarNodes, GrammarLinks, Tokens, Progress.FurthestToken, TokenLimit, SyntaxNodes, SyntaxNodeCount, SyntaxNodeCapacity, SyntaxLinks, SyntaxLinkCount, SyntaxLinkCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        End If
        ParseOneSource = 0
        Exit Function
    End If
    If ResultPosition <> TokenLimit Then
        Progress.FurthestToken = ResultPosition
        Progress.Expected = "end of source"
        SyntaxNodeCount = SavedNodeCount
        SyntaxLinkCount = SavedLinkCount
        Call AddParseDiagnostic(Source, Tokens, TokenLimit, Progress, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        ParseOneSource = 0
        Exit Function
    End If
    ParseOneSource = 1
End Function
