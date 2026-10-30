UBE SOURCE 1 MODULE
Attribute UBE_Name = "GrammarEngine"

Type GrammarRule
    RuleName As String
    ExpressionNode As Long
End Type

Type GrammarExpression
    ExpressionKind As Long
    TextValue As String
    ReferenceRule As Long
    FirstChildLink As Long
    LastChildLink As Long
    ChildCount As Long
End Type

Type GrammarChildLink
    ExpressionNode As Long
    NextLink As Long
End Type

Function IsEbnfNameByte(ByVal Value As Long) As Long
    If Value >= 65 And Value <= 90 Or Value >= 97 And Value <= 122 Or Value >= 48 And Value <= 57 Or Value = 45 Or Value = 95 Then
        IsEbnfNameByte = 1
    Else
        IsEbnfNameByte = 0
    End If
End Function

Sub SkipEbnfTrivia(ByVal GrammarText As String, ByRef Cursor As Long, ByVal Length As Long)
    Dim ContinueSkipping As Long = 1
    While Cursor < Length And ContinueSkipping <> 0
        Dim CurrentByte As Long = StringByteAt(GrammarText, Cursor)
        If CurrentByte = 32 Or CurrentByte = 9 Or CurrentByte = 10 Or CurrentByte = 13 Then
            Cursor = Cursor + 1
        Else
            Dim StartsComment As Long = 0
            If CurrentByte = 40 Then
                If Cursor + 1 < Length Then
                    If StringByteAt(GrammarText, Cursor + 1) = 42 Then
                        StartsComment = 1
                    End If
                End If
            End If
            If StartsComment <> 0 Then
                Cursor = Cursor + 2
                Dim CommentClosed As Long = 0
                While Cursor < Length
                    If StringByteAt(GrammarText, Cursor) = 42 Then
                        If Cursor + 1 < Length Then
                            If StringByteAt(GrammarText, Cursor + 1) = 41 Then
                                Cursor = Cursor + 2
                                CommentClosed = 1
                                Exit While
                            End If
                        End If
                    End If
                    Cursor = Cursor + 1
                Wend
                If CommentClosed = 0 Then
                    Cursor = Length
                End If
            Else
                ContinueSkipping = 0
            End If
        End If
    Wend
End Sub

Function ReadEbnfName(ByVal GrammarText As String, ByRef Cursor As Long, ByVal Length As Long, ByRef RuleName As String) As Long
    Call SkipEbnfTrivia(GrammarText, Cursor, Length)
    Dim StartByte As Long = Cursor
    While Cursor < Length
        If IsEbnfNameByte(StringByteAt(GrammarText, Cursor)) = 0 Then
            Exit While
        End If
        Cursor = Cursor + 1
    Wend
    If Cursor = StartByte Then
        RuleName = ""
        ReadEbnfName = 0
    Else
        RuleName = StringSlice(GrammarText, StartByte, Cursor - StartByte)
        ReadEbnfName = 1
    End If
End Function

Function AppendGrammarExpression(ByRef Nodes() As GrammarExpression, ByRef NodeCount As Long, ByRef NodeCapacity As Long, ByVal Kind As Long, ByVal TextValue As String) As Long
    If NodeCount >= LimitGrammarNodes() Then
        AppendGrammarExpression = -1
        Exit Function
    End If
    If NodeCount = NodeCapacity Then
        Dim NewCapacity As Long = 256
        If NodeCapacity > 0 Then
            NewCapacity = NodeCapacity * 2
        End If
        If NewCapacity > LimitGrammarNodes() Then
            NewCapacity = LimitGrammarNodes()
        End If
        If NodeCapacity = 0 Then
            ReDim Nodes(NewCapacity - 1)
        Else
            ReDim Preserve Nodes(NewCapacity - 1)
        End If
        NodeCapacity = NewCapacity
    End If
    Dim Result As Long = NodeCount
    Nodes(Result).ExpressionKind = Kind
    Nodes(Result).TextValue = TextValue
    Nodes(Result).ReferenceRule = -1
    Nodes(Result).FirstChildLink = -1
    Nodes(Result).LastChildLink = -1
    Nodes(Result).ChildCount = 0
    NodeCount = NodeCount + 1
    AppendGrammarExpression = Result
End Function

Function AppendGrammarChild(ByRef Nodes() As GrammarExpression, ByVal ParentNode As Long, ByVal ChildNode As Long, ByRef Links() As GrammarChildLink, ByRef LinkCount As Long, ByRef LinkCapacity As Long) As Long
    If LinkCount >= LimitGrammarNodes() * 2 Then
        AppendGrammarChild = 0
        Exit Function
    End If
    If LinkCount = LinkCapacity Then
        Dim NewCapacity As Long = 256
        If LinkCapacity > 0 Then
            NewCapacity = LinkCapacity * 2
        End If
        If NewCapacity > LimitGrammarNodes() * 2 Then
            NewCapacity = LimitGrammarNodes() * 2
        End If
        If LinkCapacity = 0 Then
            ReDim Links(NewCapacity - 1)
        Else
            ReDim Preserve Links(NewCapacity - 1)
        End If
        LinkCapacity = NewCapacity
    End If
    Dim LinkIndex As Long = LinkCount
    Links(LinkIndex).ExpressionNode = ChildNode
    Links(LinkIndex).NextLink = -1
    If Nodes(ParentNode).FirstChildLink < 0 Then
        Nodes(ParentNode).FirstChildLink = LinkIndex
    Else
        Links(Nodes(ParentNode).LastChildLink).NextLink = LinkIndex
    End If
    Nodes(ParentNode).LastChildLink = LinkIndex
    Nodes(ParentNode).ChildCount = Nodes(ParentNode).ChildCount + 1
    LinkCount = LinkCount + 1
    AppendGrammarChild = 1
End Function

Function ReadEbnfLiteral(ByVal GrammarText As String, ByRef Cursor As Long, ByVal Length As Long, ByRef Value As String) As Long
    Call SkipEbnfTrivia(GrammarText, Cursor, Length)
    If Cursor >= Length Then
        ReadEbnfLiteral = 0
        Exit Function
    End If
    Dim QuoteByte As Long = StringByteAt(GrammarText, Cursor)
    If QuoteByte <> 34 And QuoteByte <> 39 Then
        ReadEbnfLiteral = 0
        Exit Function
    End If
    Cursor = Cursor + 1
    Value = ""
    While Cursor < Length
        Dim CurrentByte As Long = StringByteAt(GrammarText, Cursor)
        If CurrentByte = QuoteByte Then
            Cursor = Cursor + 1
            ReadEbnfLiteral = 1
            Exit Function
        End If
        Value = Value & StringFromByte(CurrentByte)
        Cursor = Cursor + 1
    Wend
    ReadEbnfLiteral = 0
End Function

Function ParseEbnfDefinition(ByVal GrammarText As String, ByRef Cursor As Long, ByVal Length As Long, ByRef Nodes() As GrammarExpression, ByRef NodeCount As Long, ByRef NodeCapacity As Long, ByRef Links() As GrammarChildLink, ByRef LinkCount As Long, ByRef LinkCapacity As Long, ByRef ResultNode As Long, ByVal Depth As Long) As Long
    If Depth > LimitSyntaxDepth() Then
        ParseEbnfDefinition = 0
        Exit Function
    End If
    Dim FirstNode As Long = -1
    If ParseEbnfSequence(GrammarText, Cursor, Length, Nodes, NodeCount, NodeCapacity, Links, LinkCount, LinkCapacity, FirstNode, Depth + 1) = 0 Then
        ParseEbnfDefinition = 0
        Exit Function
    End If
    Call SkipEbnfTrivia(GrammarText, Cursor, Length)
    If Cursor >= Length Or StringByteAt(GrammarText, Cursor) <> 124 Then
        ResultNode = FirstNode
        ParseEbnfDefinition = 1
        Exit Function
    End If
    Dim AlternativeNode As Long = AppendGrammarExpression(Nodes, NodeCount, NodeCapacity, 4, "")
    If AlternativeNode < 0 Then
        ParseEbnfDefinition = 0
        Exit Function
    End If
    Call AppendGrammarChild(Nodes, AlternativeNode, FirstNode, Links, LinkCount, LinkCapacity)
    While Cursor < Length
        Call SkipEbnfTrivia(GrammarText, Cursor, Length)
        If Cursor >= Length Or StringByteAt(GrammarText, Cursor) <> 124 Then
            Exit While
        End If
        Cursor = Cursor + 1
        Dim NextNode As Long = -1
        If ParseEbnfSequence(GrammarText, Cursor, Length, Nodes, NodeCount, NodeCapacity, Links, LinkCount, LinkCapacity, NextNode, Depth + 1) = 0 Then
            ParseEbnfDefinition = 0
            Exit Function
        End If
        Call AppendGrammarChild(Nodes, AlternativeNode, NextNode, Links, LinkCount, LinkCapacity)
    Wend
    ResultNode = AlternativeNode
    ParseEbnfDefinition = 1
End Function

Function ParseEbnfSequence(ByVal GrammarText As String, ByRef Cursor As Long, ByVal Length As Long, ByRef Nodes() As GrammarExpression, ByRef NodeCount As Long, ByRef NodeCapacity As Long, ByRef Links() As GrammarChildLink, ByRef LinkCount As Long, ByRef LinkCapacity As Long, ByRef ResultNode As Long, ByVal Depth As Long) As Long
    Dim FirstNode As Long = -1
    If ParseEbnfPrimary(GrammarText, Cursor, Length, Nodes, NodeCount, NodeCapacity, Links, LinkCount, LinkCapacity, FirstNode, Depth + 1) = 0 Then
        ParseEbnfSequence = 0
        Exit Function
    End If
    Call SkipEbnfTrivia(GrammarText, Cursor, Length)
    If Cursor >= Length Or StringByteAt(GrammarText, Cursor) <> 44 Then
        ResultNode = FirstNode
        ParseEbnfSequence = 1
        Exit Function
    End If
    Dim SequenceNode As Long = AppendGrammarExpression(Nodes, NodeCount, NodeCapacity, 3, "")
    If SequenceNode < 0 Then
        ParseEbnfSequence = 0
        Exit Function
    End If
    Call AppendGrammarChild(Nodes, SequenceNode, FirstNode, Links, LinkCount, LinkCapacity)
    While Cursor < Length
        Call SkipEbnfTrivia(GrammarText, Cursor, Length)
        If Cursor >= Length Or StringByteAt(GrammarText, Cursor) <> 44 Then
            Exit While
        End If
        Cursor = Cursor + 1
        Dim NextNode As Long = -1
        If ParseEbnfPrimary(GrammarText, Cursor, Length, Nodes, NodeCount, NodeCapacity, Links, LinkCount, LinkCapacity, NextNode, Depth + 1) = 0 Then
            ParseEbnfSequence = 0
            Exit Function
        End If
        Call AppendGrammarChild(Nodes, SequenceNode, NextNode, Links, LinkCount, LinkCapacity)
    Wend
    ResultNode = SequenceNode
    ParseEbnfSequence = 1
End Function

Function ParseEbnfPrimary(ByVal GrammarText As String, ByRef Cursor As Long, ByVal Length As Long, ByRef Nodes() As GrammarExpression, ByRef NodeCount As Long, ByRef NodeCapacity As Long, ByRef Links() As GrammarChildLink, ByRef LinkCount As Long, ByRef LinkCapacity As Long, ByRef ResultNode As Long, ByVal Depth As Long) As Long
    If Depth > LimitSyntaxDepth() Then
        ParseEbnfPrimary = 0
        Exit Function
    End If
    Call SkipEbnfTrivia(GrammarText, Cursor, Length)
    If Cursor >= Length Then
        ParseEbnfPrimary = 0
        Exit Function
    End If
    Dim CurrentByte As Long = StringByteAt(GrammarText, Cursor)
    If CurrentByte = 34 Or CurrentByte = 39 Then
        Dim LiteralValue As String = ""
        If ReadEbnfLiteral(GrammarText, Cursor, Length, LiteralValue) = 0 Then
            ParseEbnfPrimary = 0
            Exit Function
        End If
        ResultNode = AppendGrammarExpression(Nodes, NodeCount, NodeCapacity, 2, LiteralValue)
        If ResultNode < 0 Then
            ParseEbnfPrimary = 0
        Else
            ParseEbnfPrimary = 1
        End If
        Exit Function
    End If
    Dim ClosingByte As Long = 0
    Dim WrapperKind As Long = 0
    If CurrentByte = 40 Then
        ClosingByte = 41
        WrapperKind = 0
    Else
        If CurrentByte = 91 Then
            ClosingByte = 93
            WrapperKind = 5
        Else
            If CurrentByte = 123 Then
                ClosingByte = 125
                WrapperKind = 6
            End If
        End If
    End If
    If ClosingByte <> 0 Then
        Cursor = Cursor + 1
        Dim InnerNode As Long = -1
        If ParseEbnfDefinition(GrammarText, Cursor, Length, Nodes, NodeCount, NodeCapacity, Links, LinkCount, LinkCapacity, InnerNode, Depth + 1) = 0 Then
            ParseEbnfPrimary = 0
            Exit Function
        End If
        Call SkipEbnfTrivia(GrammarText, Cursor, Length)
        If Cursor >= Length Then
            ParseEbnfPrimary = 0
            Exit Function
        End If
        If StringByteAt(GrammarText, Cursor) <> ClosingByte Then
            ParseEbnfPrimary = 0
            Exit Function
        End If
        Cursor = Cursor + 1
        If WrapperKind = 0 Then
            ResultNode = InnerNode
        Else
            ResultNode = AppendGrammarExpression(Nodes, NodeCount, NodeCapacity, WrapperKind, "")
            If ResultNode < 0 Then
                ParseEbnfPrimary = 0
                Exit Function
            End If
            Call AppendGrammarChild(Nodes, ResultNode, InnerNode, Links, LinkCount, LinkCapacity)
        End If
        ParseEbnfPrimary = 1
        Exit Function
    End If
    Dim ReferenceName As String = ""
    If ReadEbnfName(GrammarText, Cursor, Length, ReferenceName) = 0 Then
        ParseEbnfPrimary = 0
        Exit Function
    End If
    ResultNode = AppendGrammarExpression(Nodes, NodeCount, NodeCapacity, 1, ReferenceName)
    If ResultNode < 0 Then
        ParseEbnfPrimary = 0
    Else
        ParseEbnfPrimary = 1
    End If
End Function

Function AppendGrammarRule(ByRef Rules() As GrammarRule, ByRef RuleCount As Long, ByRef RuleCapacity As Long, ByVal RuleName As String, ByVal ExpressionNode As Long) As Long
    If RuleCount >= LimitGrammarRules() Then
        AppendGrammarRule = 0
        Exit Function
    End If
    If RuleCount = RuleCapacity Then
        Dim NewCapacity As Long = 64
        If RuleCapacity > 0 Then
            NewCapacity = RuleCapacity * 2
        End If
        If NewCapacity > LimitGrammarRules() Then
            NewCapacity = LimitGrammarRules()
        End If
        If RuleCapacity = 0 Then
            ReDim Rules(NewCapacity - 1)
        Else
            ReDim Preserve Rules(NewCapacity - 1)
        End If
        RuleCapacity = NewCapacity
    End If
    Rules(RuleCount).RuleName = RuleName
    Rules(RuleCount).ExpressionNode = ExpressionNode
    RuleCount = RuleCount + 1
    AppendGrammarRule = 1
End Function

Function FindGrammarRule(ByRef Rules() As GrammarRule, ByVal RuleCount As Long, ByVal RuleName As String) As Long
    Dim Index As Long = 0
    While Index < RuleCount
        If Rules(Index).RuleName = RuleName Then
            FindGrammarRule = Index
            Exit Function
        End If
        Index = Index + 1
    Wend
    FindGrammarRule = -1
End Function

Function LoadGrammarModel(ByRef Rules() As GrammarRule, ByRef RuleCount As Long, ByRef Nodes() As GrammarExpression, ByRef NodeCount As Long, ByRef Links() As GrammarChildLink, ByRef LinkCount As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim GrammarText As String = ""
    Call LoadEmbeddedGrammar(GrammarText)
    Dim Cursor As Long = 0
    Dim Length As Long = StringLength(GrammarText)
    Dim RuleCapacity As Long = 0
    Dim NodeCapacity As Long = 0
    Dim LinkCapacity As Long = 0
    RuleCount = 0
    NodeCount = 0
    LinkCount = 0
    While Cursor < Length
        Call SkipEbnfTrivia(GrammarText, Cursor, Length)
        If Cursor >= Length Then
            Exit While
        End If
        Dim RuleName As String = ""
        If ReadEbnfName(GrammarText, Cursor, Length, RuleName) = 0 Then
            Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3600", "<embedded-grammar>", 1, 1, "expected grammar production name")
            LoadGrammarModel = 0
            Exit Function
        End If
        Call SkipEbnfTrivia(GrammarText, Cursor, Length)
        If Cursor >= Length Then
            Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3601", "<embedded-grammar>", 1, 1, "grammar production is missing equals")
            LoadGrammarModel = 0
            Exit Function
        End If
        If StringByteAt(GrammarText, Cursor) <> 61 Then
            Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3601", "<embedded-grammar>", 1, 1, "grammar production is missing equals")
            LoadGrammarModel = 0
            Exit Function
        End If
        Cursor = Cursor + 1
        Dim ExpressionNode As Long = -1
        If ParseEbnfDefinition(GrammarText, Cursor, Length, Nodes, NodeCount, NodeCapacity, Links, LinkCount, LinkCapacity, ExpressionNode, 0) = 0 Then
            Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3602", "<embedded-grammar>", 1, 1, "malformed embedded grammar expression for " & RuleName)
            LoadGrammarModel = 0
            Exit Function
        End If
        Call SkipEbnfTrivia(GrammarText, Cursor, Length)
        If Cursor >= Length Then
            Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3603", "<embedded-grammar>", 1, 1, "grammar production is missing semicolon")
            LoadGrammarModel = 0
            Exit Function
        End If
        If StringByteAt(GrammarText, Cursor) <> 59 Then
            Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3603", "<embedded-grammar>", 1, 1, "grammar production is missing semicolon")
            LoadGrammarModel = 0
            Exit Function
        End If
        Cursor = Cursor + 1
        If FindGrammarRule(Rules, RuleCount, RuleName) >= 0 Then
            Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3604", "<embedded-grammar>", 1, 1, "duplicate embedded grammar production: " & RuleName)
            LoadGrammarModel = 0
            Exit Function
        End If
        If AppendGrammarRule(Rules, RuleCount, RuleCapacity, RuleName, ExpressionNode) = 0 Then
            Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3605", "<embedded-grammar>", 1, 1, "embedded grammar exceeds configured limits")
            LoadGrammarModel = 0
            Exit Function
        End If
    Wend
    Dim NodeIndex As Long = 0
    While NodeIndex < NodeCount
        If Nodes(NodeIndex).ExpressionKind = 1 Then
            Nodes(NodeIndex).ReferenceRule = FindGrammarRule(Rules, RuleCount, Nodes(NodeIndex).TextValue)
        End If
        NodeIndex = NodeIndex + 1
    Wend
    If FindGrammarRule(Rules, RuleCount, "program") < 0 Then
        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3606", "<embedded-grammar>", 1, 1, "embedded grammar has no program production")
        LoadGrammarModel = 0
        Exit Function
    End If
    LoadGrammarModel = 1
End Function
