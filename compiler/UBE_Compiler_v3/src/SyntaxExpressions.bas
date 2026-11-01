UBE SOURCE 1 MODULE
Attribute UBE_Name = "SyntaxExpressions"

' One invocation owns all continuation frames. Frames borrow document/token views
' and store only scalar node identities; they never copy source or a subtree.
' Depth counts open groups/calls, pending prefixes and right-power operands.
' Precedence continuations use bounded heap workspace rather than native recursion.
Type SyntaxExpressionFrame
    Minimum As Long
    Continuation As Long
    Root As Long
    FirstByte As Long
    OperatorKind As Long
    ParentNode As Long
    Tail As Long
    Depth As Long
    AllowCalls As Boolean
    AllowNamed As Boolean
    SeenComparison As Boolean
    HadArgument As Boolean
    CallKind As Long
End Type

' Returns the physical frame capacity without retaining the borrowed array.
Intrinsic Function SyntaxExpressionFrameLength(ByRef Values() As SyntaxExpressionFrame) As Long
Attribute SyntaxExpressionFrameLength.UBE_Primitive = "Array.Length"
End Function

' Prepares frame storage atomically; failure keeps the previous owned workspace.
Intrinsic Function TryResizeSyntaxExpressionFrames(ByRef Values() As SyntaxExpressionFrame, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeSyntaxExpressionFrames.UBE_Primitive = "Array.TryResize"
End Function

' Maps logical operator kinds to the frozen primary-specification precedence.
Function SyntaxExpressionPrecedence(ByVal Kind As Long) As Long
    SyntaxExpressionPrecedence = 0
    If Kind = 30 Then
        SyntaxExpressionPrecedence = 1
    End If
    If Kind = 29 Then
        SyntaxExpressionPrecedence = 2
    End If
    If Kind = 28 Then
        SyntaxExpressionPrecedence = 3
    End If
    If Kind = 26 Or Kind = 27 Then
        SyntaxExpressionPrecedence = 4
    End If
    If Kind = 24 Or Kind = 25 Then
        SyntaxExpressionPrecedence = 5
    End If
    If Kind = 6 Then
        SyntaxExpressionPrecedence = 6
    End If
    If Kind >= 15 And Kind <= 23 Then
        SyntaxExpressionPrecedence = 7
    End If
    If Kind = 14 Then
        SyntaxExpressionPrecedence = 8
    End If
    If Kind = 12 Or Kind = 13 Then
        SyntaxExpressionPrecedence = 9
    End If
    If Kind = 8 Or Kind = 9 Then
        SyntaxExpressionPrecedence = 10
    End If
    If Kind = 10 Then
        SyntaxExpressionPrecedence = 11
    End If
    If Kind = 11 Then
        SyntaxExpressionPrecedence = 12
    End If
    If Kind = 4 Or Kind = 5 Then
        SyntaxExpressionPrecedence = 13
    End If
    If Kind = 7 Then
        SyntaxExpressionPrecedence = 14
    End If
End Function

' Classifies the cached token without rewriting scanner boundaries or source text.
Function TrySyntaxExpressionToken(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByRef Kind As Long) As Boolean
    TrySyntaxExpressionToken = False
    Kind = 0
    If TrySyntaxPeek(Document, Tokens, State) = False Then
        Exit Function
    End If
    State.Metrics.Transitions = State.Metrics.Transitions + 1
    Dim TokenKind As Long = State.Cursor.Token.Kind
    If TokenKind = 1 Or TokenKind = 6 Then
        Kind = 1
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TokenKind = 3 Or TokenKind = 4 Or TokenKind = 5 Or TokenKind = 14 Then
        Kind = 2
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    Dim Matches As Boolean = False
    If TrySyntaxAt(Document, Tokens, State, "^", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 7
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "*", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 8
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "/", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 9
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "\", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 10
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Mod", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 11
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "+", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 12
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "-", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 13
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "&", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 14
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "=", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 15
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "<>", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 16
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "<", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 17
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "<=", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 18
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, ">", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 19
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, ">=", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 20
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Like", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 21
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Is", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 22
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "IsNot", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 23
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "And", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 24
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "AndAlso", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 25
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Or", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 26
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "OrElse", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 27
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Xor", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 28
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Eqv", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 29
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Imp", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 30
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Not", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 6
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "(", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = -1
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, ")", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = -2
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, ",", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = -3
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, ".", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = -4
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "!", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = -5
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, ":=", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = -6
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "New", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 32
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "AddressOf", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 31
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "TypeOf", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 37
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "CallNew", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 39
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "True", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 2
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "False", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 2
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Nothing", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 2
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Null", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 2
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Empty", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 2
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Me", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 1
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Mid", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 1
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Len", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 1
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "String", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 1
        TrySyntaxExpressionToken = True
        Exit Function
    End If

    If TrySyntaxAt(Document, Tokens, State, "Spc", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 1
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Tab", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 1
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Date", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 1
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Input", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 1
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Error", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 1
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Seek", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 1
        TrySyntaxExpressionToken = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "#", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = -7
    End If
    TrySyntaxExpressionToken = True
End Function

' Date text cannot cross a physical newline. Unlike ordinary grammar spacing,
' a continuation token is retained as the exact offending token, with one actual
' record-read count per access and no inspection of its source payload.
Function TrySyntaxDatePeek(ByRef Tokens() As SourceToken, ByRef State As SyntaxState) As Boolean
    TrySyntaxDatePeek = False
    If State.Cursor.Ready Then
        If State.Cursor.Token.Kind = 11 Then
            TrySyntaxDatePeek = SyntaxFail(State, 102)
            Exit Function
        End If
        TrySyntaxDatePeek = True
        Exit Function
    End If
    State.Cursor.HadSpace = False
    While State.Cursor.Index < State.TokenCount
        State.Failure.Kind = 5
        Call CopyScannerToken(State.Cursor.Token, Tokens(State.Cursor.Index))
        State.Metrics.TokenReads = State.Metrics.TokenReads + 1
        Dim Kind As Long = State.Cursor.Token.Kind
        If Kind = 11 Then
            State.Cursor.Ready = True
            TrySyntaxDatePeek = SyntaxFail(State, 102)
            Exit Function
        End If
        If Kind < 8 Or Kind > 12 Then
            State.Cursor.Ready = True
            TrySyntaxDatePeek = True
            Exit Function
        End If
        If Kind = 8 Then
            State.Cursor.HadSpace = True
        End If
        State.Cursor.Index = State.Cursor.Index + 1
        State.Metrics.Transitions = State.Metrics.Transitions + 1
    Wend
    TrySyntaxDatePeek = SyntaxFail(State, 1)
End Function
' Consumes an opaque date candidate only where a literal is expected. Raw MODULE
' scans retain hash punctuation; expression-fragment scans may already provide
' one date token. Both paths return the exact original span without conversion,
' byte cooking, new tokens, source copying or interpretation of calendar fields.
Function TrySyntaxDateLiteral(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByRef FirstByte As Long, ByRef LastByte As Long) As Boolean
    TrySyntaxDateLiteral = False
    FirstByte = 0
    LastByte = 0
    If TrySyntaxPeek(Document, Tokens, State) = False Then
        Exit Function
    End If
    FirstByte = State.Cursor.Token.First.ByteOffset
    If State.Cursor.Token.Kind = 14 Then
        LastByte = State.Cursor.Token.Last.ByteOffset
        Call SyntaxConsume(State.Cursor, State.Metrics)
        TrySyntaxDateLiteral = True
        Exit Function
    End If
    Dim Matches As Boolean = False
    If TrySyntaxAt(Document, Tokens, State, "#", Matches) = False Then
        Exit Function
    End If
    If Matches = False Then
        TrySyntaxDateLiteral = SyntaxFail(State, 102)
        Exit Function
    End If
    Call SyntaxConsume(State.Cursor, State.Metrics)
    Dim Closed As Boolean = False
    While Closed = False
        If TrySyntaxDatePeek(Tokens, State) = False Then
            Exit Function
        End If
        If State.Cursor.Token.Kind = 13 Or State.Cursor.Token.Kind = 15 Then
            TrySyntaxDateLiteral = SyntaxFail(State, 102)
            Exit Function
        End If
        If TrySyntaxAt(Document, Tokens, State, "#", Matches) = False Then
            Exit Function
        End If
        ' A raw real token may own its final hash as the existing Double suffix.
        ' Inspect that one original boundary character only; never scan/copy its
        ' payload or split an interior string/comment token to invent new tokens.
        If Matches = False And State.Cursor.Token.Kind = 4 Then
            Dim TokenLast As Long = State.Cursor.Token.Last.ByteOffset
            Dim TokenFirst As Long = State.Cursor.Token.First.ByteOffset
            If TokenLast > TokenFirst Then
                State.Metrics.NameReads = State.Metrics.NameReads + 1
                If TryMatchEnvelopeWord(Document.Bytes, TokenLast - 1, TokenLast, "#", Matches) = False Then
                    Exit Function
                End If
            End If
        End If
        If Matches Then
            If State.Cursor.Token.Kind = 7 And State.Cursor.Token.First.ByteOffset = FirstByte + 1 Then
                TrySyntaxDateLiteral = SyntaxFail(State, 101)
                Exit Function
            End If
            LastByte = State.Cursor.Token.Last.ByteOffset
            Closed = True
        End If
        Call SyntaxConsume(State.Cursor, State.Metrics)
    Wend
    TrySyntaxDateLiteral = True
End Function

' Scoped Then/Else contexts distinguish an adjacent Single suffix from a legal
' reserved member. One following token preserves expression continuations. Else
' is optional, so a logical end or a non-body token also preserves that member.
' Cursor copies are scalar-only; actual lookahead work remains counted.
Function TrySyntaxContextSuffix(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByRef Suffix As Boolean) As Boolean
    TrySyntaxContextSuffix = False
    Suffix = False
    If (State.IfCondition = False And State.InlineElse = False) Or State.Cursor.HadSpace = False Then
        TrySyntaxContextSuffix = True
        Exit Function
    End If
    Dim Matches As Boolean = False
    Dim ContextWord As Boolean = False
    Dim IsElse As Boolean = False
    If State.IfCondition Then
        If TrySyntaxAt(Document, Tokens, State, "Then", Matches) = False Then
            Exit Function
        End If
        ContextWord = Matches
    End If
    If State.InlineElse Then
        If TrySyntaxAt(Document, Tokens, State, "Else", IsElse) = False Then
            Exit Function
        End If
        ContextWord = ContextWord Or IsElse
    End If
    If ContextWord = False Then
        TrySyntaxContextSuffix = True
        Exit Function
    End If
    Dim MemberCursor As SyntaxCursor = State.Cursor
    Call SyntaxConsume(State.Cursor, State.Metrics)
    If TrySyntaxPeek(Document, Tokens, State) = False Then
        Exit Function
    End If
    Dim Kind As Long = 0
    If TrySyntaxExpressionToken(Document, Tokens, State, Kind) = False Then
        Exit Function
    End If
    Dim PreserveMember As Boolean = Kind >= 7 And Kind <= 30
    PreserveMember = PreserveMember Or Kind = -1 Or Kind = -2 Or Kind = -3 Or Kind = -4 Or Kind = -5
    ' A spaced group (or an in-With leading member) can also begin the Then
    ' body. Keep the default Bang interpretation, but remember that bounded
    ' ambiguity so the grammar can defer if its required Then never follows.
    If IsElse = False And State.Cursor.HadSpace Then
        If Kind = -1 Or (Kind = -4 And State.WithDepth > 0) Then
            If State.AmbiguousSuffixByte < 0 Then
                State.AmbiguousSuffixByte = MemberCursor.LastByte - 1
            End If
        End If
    End If
    If IsElse Then
        If TrySyntaxAt(Document, Tokens, State, "Else", Matches) = False Then
            Exit Function
        End If
    Else
        If TrySyntaxAt(Document, Tokens, State, "Then", Matches) = False Then
            Exit Function
        End If
    End If
    PreserveMember = PreserveMember Or Matches
    If State.Cursor.Token.First.ByteOffset = MemberCursor.Token.Last.ByteOffset Then
        If TrySyntaxAt(Document, Tokens, State, "$", Matches) = False Then
            Exit Function
        End If
        PreserveMember = PreserveMember Or Matches
        If TrySyntaxAt(Document, Tokens, State, "%", Matches) = False Then
            Exit Function
        End If
        PreserveMember = PreserveMember Or Matches
        If TrySyntaxAt(Document, Tokens, State, "#", Matches) = False Then
            Exit Function
        End If
        PreserveMember = PreserveMember Or Matches
        If TrySyntaxAt(Document, Tokens, State, "@", Matches) = False Then
            Exit Function
        End If
        PreserveMember = PreserveMember Or Matches
    End If
    If IsElse And PreserveMember = False Then
        Dim StartsBody As Boolean = Kind = 1 Or Kind = 2 Or Kind = 31 Or Kind = 32 Or Kind = 39
        Dim Deferred As Boolean = False
        If StartsBody = False Then
            If TryGrammarDeferred(Document, Tokens, State, Deferred) = False Then
                Exit Function
            End If
            StartsBody = Deferred
        End If
        If StartsBody = False Then
            If TrySyntaxElseBodyWord(Document, Tokens, State, StartsBody) = False Then
                Exit Function
            End If
        End If
        PreserveMember = StartsBody = False
    End If
    State.Cursor = MemberCursor
    Suffix = PreserveMember = False
    TrySyntaxContextSuffix = True
End Function

' Recognizes the supported statement introducers following an optional Else.
' Deferred statement families use the existing grammar classifier, while names
' and primary forms are handled by the caller. Nothing is consumed here.
Function TrySyntaxElseBodyWord(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByRef Matches As Boolean) As Boolean
    TrySyntaxElseBodyWord = False
    Matches = False
    Dim Found As Boolean = False
    If TrySyntaxAt(Document, Tokens, State, "Call", Found) = False Then
        Exit Function
    End If
    If Found Then
        Matches = True
        TrySyntaxElseBodyWord = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Let", Found) = False Then
        Exit Function
    End If
    If Found Then
        Matches = True
        TrySyntaxElseBodyWord = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Set", Found) = False Then
        Exit Function
    End If
    If Found Then
        Matches = True
        TrySyntaxElseBodyWord = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "LSet", Found) = False Then
        Exit Function
    End If
    If Found Then
        Matches = True
        TrySyntaxElseBodyWord = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "RSet", Found) = False Then
        Exit Function
    End If
    If Found Then
        Matches = True
        TrySyntaxElseBodyWord = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "If", Found) = False Then
        Exit Function
    End If
    If Found Then
        Matches = True
        TrySyntaxElseBodyWord = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "While", Found) = False Then
        Exit Function
    End If
    If Found Then
        Matches = True
        TrySyntaxElseBodyWord = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "With", Found) = False Then
        Exit Function
    End If
    If Found Then
        Matches = True
        TrySyntaxElseBodyWord = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Exit", Found) = False Then
        Exit Function
    End If
    If Found Then
        Matches = True
        TrySyntaxElseBodyWord = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "GoTo", Found) = False Then
        Exit Function
    End If
    If Found Then
        Matches = True
        TrySyntaxElseBodyWord = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Return", Found) = False Then
        Exit Function
    End If
    If Found Then
        Matches = True
        TrySyntaxElseBodyWord = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Print", Found) = False Then
        Exit Function
    End If
    If Found Then
        Matches = True
        TrySyntaxElseBodyWord = True
        Exit Function
    End If
    TrySyntaxElseBodyWord = True
End Function

' Name suffixes retain their original extent. Lookahead is a scalar cursor copy,
' so a clear following operand keeps power/concatenation as operators, a following
' member keeps bang access, and ambiguous competing parses remain deferred.
Function TrySyntaxNameSuffix(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByVal NodeId As Long) As Boolean
    TrySyntaxNameSuffix = False
    If TrySyntaxPeek(Document, Tokens, State) = False Then
        Exit Function
    End If
    If State.Cursor.HadSpace Or State.Cursor.Token.Kind <> 7 Then
        TrySyntaxNameSuffix = True
        Exit Function
    End If
    If State.Cursor.Token.First.ByteOffset <> State.Pending(0).Nodes(NodeId).LastByte Then
        TrySyntaxNameSuffix = True
        Exit Function
    End If
    Dim Matches As Boolean = False
    Dim Suffix As Boolean = False
    If TrySyntaxAt(Document, Tokens, State, "$", Matches) = False Then
        Exit Function
    End If
    Suffix = Matches
    If TrySyntaxAt(Document, Tokens, State, "%", Matches) = False Then
        Exit Function
    End If
    Suffix = Suffix Or Matches
    If TrySyntaxAt(Document, Tokens, State, "#", Matches) = False Then
        Exit Function
    End If
    Suffix = Suffix Or Matches
    If TrySyntaxAt(Document, Tokens, State, "@", Matches) = False Then
        Exit Function
    End If
    Suffix = Suffix Or Matches
    If Suffix Then
        State.Pending(0).Nodes(NodeId).LastByte = State.Cursor.Token.Last.ByteOffset
        Call SyntaxConsume(State.Cursor, State.Metrics)
        TrySyntaxNameSuffix = True
        Exit Function
    End If
    Dim BangSuffix As Boolean = False
    If TrySyntaxAt(Document, Tokens, State, "!", BangSuffix) = False Then
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "&", Matches) = False Then
        Exit Function
    End If
    Suffix = Matches
    If TrySyntaxAt(Document, Tokens, State, "^", Matches) = False Then
        Exit Function
    End If
    If BangSuffix = False And Suffix = False And Matches = False Then
        TrySyntaxNameSuffix = True
        Exit Function
    End If
    Dim Original As SyntaxCursor = State.Cursor
    Call SyntaxConsume(State.Cursor, State.Metrics)
    If TrySyntaxPeek(Document, Tokens, State) = False Then
        Exit Function
    End If
    Dim Following As Long = State.Cursor.Token.Kind
    Dim Ambiguous As Boolean = False
    Suffix = False
    If BangSuffix Then
        ' Every reserved spelling remains a member after bang. Without a member,
        ' the trailing exclamation mark has only its established Single role.
        Suffix = Following <> 1 And Following <> 2 And Following <> 6
        If Suffix = False Then
            If TrySyntaxContextSuffix(Document, Tokens, State, Suffix) = False Then
                Exit Function
            End If
        End If
    Else
        Suffix = Following = 13 Or Following = 15
        If TrySyntaxAt(Document, Tokens, State, ",", Matches) = False Then
            Exit Function
        End If
        Suffix = Suffix Or Matches
        If TrySyntaxAt(Document, Tokens, State, ")", Matches) = False Then
            Exit Function
        End If
        Suffix = Suffix Or Matches
        If TrySyntaxAt(Document, Tokens, State, ":", Matches) = False Then
            Exit Function
        End If
        Suffix = Suffix Or Matches
        If TrySyntaxAt(Document, Tokens, State, ";", Matches) = False Then
            Exit Function
        End If
        Suffix = Suffix Or Matches
        If TrySyntaxAt(Document, Tokens, State, "Then", Matches) = False Then
            Exit Function
        End If
        Suffix = Suffix Or Matches
        If TrySyntaxAt(Document, Tokens, State, "Else", Matches) = False Then
            Exit Function
        End If
        Suffix = Suffix Or Matches
        If TrySyntaxAt(Document, Tokens, State, "To", Matches) = False Then
            Exit Function
        End If
        Suffix = Suffix Or Matches
        If TrySyntaxAt(Document, Tokens, State, "As", Matches) = False Then
            Exit Function
        End If
        Suffix = Suffix Or Matches
        If Suffix = False Then
            Dim FollowingKind As Long = 0
            If TrySyntaxExpressionToken(Document, Tokens, State, FollowingKind) = False Then
                Exit Function
            End If
            Dim Operand As Boolean = FollowingKind = 1 Or FollowingKind = 2 Or FollowingKind = 31 Or FollowingKind = 32 Or FollowingKind = 39
            If Operand = False Then
                If FollowingKind >= 7 And FollowingKind <= 30 And FollowingKind <> 12 And FollowingKind <> 13 Then
                    Suffix = True
                Else
                    If FollowingKind = -5 Or (FollowingKind = -4 And State.WithDepth = 0) Then
                        Suffix = True
                    Else
                        Ambiguous = True
                    End If
                End If
            End If
        End If
    End If
    If Suffix Then
        State.Pending(0).Nodes(NodeId).LastByte = Original.Token.Last.ByteOffset
    Else
        State.Cursor = Original
        If Ambiguous Then
            TrySyntaxNameSuffix = SyntaxFail(State, 3)
            Exit Function
        End If
    End If
    TrySyntaxNameSuffix = True
End Function

' Consumes one name; reserved words become names only in the member position.
Function TrySyntaxReadName(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByVal MemberAllowed As Boolean, ByRef Root As Long) As Boolean
    TrySyntaxReadName = False
    If TrySyntaxPeek(Document, Tokens, State) = False Then
        Exit Function
    End If
    Dim TokenKind As Long = State.Cursor.Token.Kind
    If TokenKind <> 1 And TokenKind <> 6 And (MemberAllowed = False Or TokenKind <> 2) Then
        TrySyntaxReadName = SyntaxFail(State, 104)
        Exit Function
    End If
    If TrySyntaxNewNode(State, 1, State.Cursor.Token.First.ByteOffset, State.Cursor.Token.Last.ByteOffset, Root) = False Then
        Exit Function
    End If
    Call SyntaxConsume(State.Cursor, State.Metrics)
    TrySyntaxReadName = True
End Function

' Builds a qualified-name chain iteratively, with constant work per member edge.
Function TrySyntaxQualifiedName(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByRef Root As Long) As Boolean
    TrySyntaxQualifiedName = False
    If TrySyntaxReadName(Document, Tokens, State, False, Root) = False Then
        Exit Function
    End If
    Dim More As Boolean = True
    While More
        Dim Matches As Boolean = False
        If TrySyntaxAt(Document, Tokens, State, ".", Matches) = False Then
            Exit Function
        End If
        More = Matches
        If More Then
            Call SyntaxConsume(State.Cursor, State.Metrics)
            Dim Child As Long = -1
            If TrySyntaxReadName(Document, Tokens, State, True, Child) = False Then
                Exit Function
            End If
            Dim Combined As Long = -1
            If TrySyntaxNewNode(State, 34, State.Pending(0).Nodes(Root).FirstByte, State.Pending(0).Nodes(Child).LastByte, Combined) = False Then
                Exit Function
            End If
            Dim Tail As Long = -1
            If TrySyntaxAttach(State, Combined, Root, Tail) = False Then
                Exit Function
            End If
            If TrySyntaxAttach(State, Combined, Child, Tail) = False Then
                Exit Function
            End If
            Root = Combined
        End If
    Wend
    TrySyntaxQualifiedName = True
End Function

' Type spellings retain one original view; resolving them is a later obligation.
Function TrySyntaxTypeName(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByRef Root As Long) As Boolean
    TrySyntaxTypeName = False
    If TrySyntaxPeek(Document, Tokens, State) = False Then
        Exit Function
    End If
    Dim FirstByte As Long = State.Cursor.Token.First.ByteOffset
    Dim Accepted As Boolean = State.Cursor.Token.Kind = 1 Or State.Cursor.Token.Kind = 6
    Dim Matches As Boolean = False
    If TrySyntaxAt(Document, Tokens, State, "Boolean", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Accepted = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Byte", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Accepted = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Integer", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Accepted = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Long", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Accepted = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "LongLong", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Accepted = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "IntPtr", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Accepted = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "UIntPtr", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Accepted = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Single", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Accepted = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Double", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Accepted = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Currency", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Accepted = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Decimal", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Accepted = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Date", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Accepted = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "String", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Accepted = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Object", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Accepted = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Variant", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Accepted = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Any", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Accepted = True
    End If

    If Accepted = False Then
        TrySyntaxTypeName = SyntaxFail(State, 102)
        Exit Function
    End If
    Dim IsString As Boolean = False
    If TrySyntaxAt(Document, Tokens, State, "String", IsString) = False Then
        Exit Function
    End If
    Call SyntaxConsume(State.Cursor, State.Metrics)
    Dim LastByte As Long = State.Cursor.LastByte
    Dim More As Boolean = True
    While More
        If TrySyntaxAt(Document, Tokens, State, ".", Matches) = False Then
            Exit Function
        End If
        More = Matches
        If More Then
            Call SyntaxConsume(State.Cursor, State.Metrics)
            If TrySyntaxPeek(Document, Tokens, State) = False Then
                Exit Function
            End If
            Dim TokenKind As Long = State.Cursor.Token.Kind
            If TokenKind <> 1 And TokenKind <> 2 And TokenKind <> 6 Then
                TrySyntaxTypeName = SyntaxFail(State, 104)
                Exit Function
            End If
            LastByte = State.Cursor.Token.Last.ByteOffset
            Call SyntaxConsume(State.Cursor, State.Metrics)
        End If
    Wend
    If IsString Then
        If TrySyntaxAt(Document, Tokens, State, "*", Matches) = False Then
            Exit Function
        End If
        If Matches Then
            Call SyntaxConsume(State.Cursor, State.Metrics)
            If TrySyntaxPeek(Document, Tokens, State) = False Then
                Exit Function
            End If
            If State.Cursor.Token.Kind <> 3 Then
                TrySyntaxTypeName = SyntaxFail(State, 102)
                Exit Function
            End If
            Dim AtByte As Long = State.Cursor.Token.First.ByteOffset
            While AtByte < State.Cursor.Token.Last.ByteOffset
                Dim Value As Long = -1
                If TryScannerByte(Document.Bytes, State.SourceLength, AtByte, Value) = False Then
                    Exit Function
                End If
                If Value < 48 Or Value > 57 Then
                    TrySyntaxTypeName = SyntaxFail(State, 102)
                    Exit Function
                End If
                State.Metrics.NameReads = State.Metrics.NameReads + 1
                AtByte = AtByte + 1
            Wend
            LastByte = State.Cursor.Token.Last.ByteOffset
            Call SyntaxConsume(State.Cursor, State.Metrics)
        End If
    End If
    TrySyntaxTypeName = TrySyntaxNewNode(State, 74, FirstByte, LastByte, Root)
End Function

' Pushes one scalar continuation within independent depth and workspace budgets.
Function TrySyntaxPushExpression(ByRef Frames() As SyntaxExpressionFrame, ByRef Count As Long, ByRef State As SyntaxState, ByVal Minimum As Long, ByVal Depth As Long, ByVal AllowCalls As Boolean, ByVal AllowNamed As Boolean) As Boolean
    TrySyntaxPushExpression = False
    If Depth > State.MaximumDepth Or State.ControlPending > State.MaximumPending Or Count >= State.MaximumPending - State.ControlPending Then
        TrySyntaxPushExpression = SyntaxFail(State, 2)
        Exit Function
    End If
    Dim Capacity As Long = SyntaxExpressionFrameLength(Frames)
    If Count = Capacity Then
        Dim Prepared As Long = 8
        If Capacity > 0 Then
            If Capacity > State.MaximumPending - Capacity Then
                Prepared = State.MaximumPending
            Else
                Prepared = Capacity * 2
            End If
        End If
        If Prepared > State.MaximumPending Then
            Prepared = State.MaximumPending
        End If
        If TryResizeSyntaxExpressionFrames(Frames, Prepared, True) = False Then
            Exit Function
        End If
    End If
    Dim Item As SyntaxExpressionFrame
    Item.Minimum = Minimum
    Item.Root = -1
    Item.ParentNode = -1
    Item.Tail = -1
    Item.Depth = Depth
    Item.AllowCalls = AllowCalls
    Item.AllowNamed = AllowNamed
    Item.CallKind = 38
    Frames(Count) = Item
    Count = Count + 1
    If Count + State.ControlPending > State.Metrics.MaximumPending Then
        State.Metrics.MaximumPending = Count + State.ControlPending
    End If
    If Depth > State.Metrics.MaximumDepth Then
        State.Metrics.MaximumDepth = Depth
    End If
    State.Metrics.Transitions = State.Metrics.Transitions + 1
    TrySyntaxPushExpression = True
End Function

' Adds a unary/binary parent by linking existing roots; no child payload is copied.
Function TrySyntaxCombineExpression(ByRef State As SyntaxState, ByVal Kind As Long, ByVal FirstByte As Long, ByVal LeftNode As Long, ByVal RightNode As Long, ByRef Root As Long) As Boolean
    TrySyntaxCombineExpression = False
    If TrySyntaxNewNode(State, Kind, FirstByte, State.Pending(0).Nodes(RightNode).LastByte, Root) = False Then
        Exit Function
    End If
    Dim Tail As Long = -1
    If LeftNode >= 0 Then
        If TrySyntaxAttach(State, Root, LeftNode, Tail) = False Then
            Exit Function
        End If
    End If
    If TrySyntaxAttach(State, Root, RightNode, Tail) = False Then
        Exit Function
    End If
    TrySyntaxCombineExpression = True
End Function

' All three grammar entry helpers use the same iterative implementation.
Function TryParseSyntaxExpression(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByRef Root As Long) As Boolean
    TryParseSyntaxExpression = TryParseSyntaxExpressionMode(Document, Tokens, State, 1, True, False, Root)
End Function

' Parses the structural assignment/call target without consuming binary operators.
Function TryParseSyntaxPostfix(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByVal AllowCalls As Boolean, ByRef Root As Long) As Boolean
    TryParseSyntaxPostfix = TryParseSyntaxExpressionMode(Document, Tokens, State, 15, AllowCalls, False, Root)
End Function

' Parses one argument, retaining a named argument's original name/value ordering.
Function TryParseSyntaxArgument(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByRef Root As Long) As Boolean
    TryParseSyntaxArgument = TryParseSyntaxExpressionMode(Document, Tokens, State, 1, True, True, Root)
End Function

' Executes precedence and grammar continuations on an owned explicit heap stack.
' Continuations 0/1 select a primary or following postfix/operator; 2/3/5/6/9
' await binary, group, prefix, TypeOf or named-argument children. Calls use 4/7/8
' to preserve omitted slots and require their own comma/closing-token context.
Function TryParseSyntaxExpressionMode(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByVal Minimum As Long, ByVal AllowCalls As Boolean, ByVal AllowNamed As Boolean, ByRef Root As Long) As Boolean
    TryParseSyntaxExpressionMode = False
    Root = -1
    Dim Frames() As SyntaxExpressionFrame
    Dim FrameCount As Long = 0
    If TrySyntaxPushExpression(Frames, FrameCount, State, Minimum, State.ActiveDepth, AllowCalls, AllowNamed) = False Then
        Exit Function
    End If
    While FrameCount > 0
        Dim Frame As SyntaxExpressionFrame = Frames(FrameCount - 1)
        If TrySyntaxPeek(Document, Tokens, State) = False Then
            Exit Function
        End If
        Dim Kind As Long = 0
        If TrySyntaxExpressionToken(Document, Tokens, State, Kind) = False Then
            Exit Function
        End If
        Dim Matches As Boolean = False
        Dim Completed As Boolean = False
        Dim Pushed As Boolean = False
        If Frame.Continuation = 0 Then
            Frame.FirstByte = State.Cursor.Token.First.ByteOffset
            If Kind = 1 Or Kind = 2 Or Kind = -7 Then
                If Kind = -7 Then
                    Dim DateFirst As Long = 0
                    Dim DateLast As Long = 0
                    If TrySyntaxDateLiteral(Document, Tokens, State, DateFirst, DateLast) = False Then
                        Exit Function
                    End If
                    If TrySyntaxNewNode(State, 2, DateFirst, DateLast, Frame.Root) = False Then
                        Exit Function
                    End If
                Else
                    If TrySyntaxNewNode(State, Kind, Frame.FirstByte, State.Cursor.Token.Last.ByteOffset, Frame.Root) = False Then
                        Exit Function
                    End If
                    Call SyntaxConsume(State.Cursor, State.Metrics)
                    If Kind = 1 Then
                        If TrySyntaxNameSuffix(Document, Tokens, State, Frame.Root) = False Then
                            Exit Function
                        End If
                    End If
                End If
                Frame.Continuation = 1
            Else
                If Kind = -1 Then
                    If Frame.Depth >= State.MaximumDepth Then
                        TryParseSyntaxExpressionMode = SyntaxFail(State, 2)
                        Exit Function
                    End If
                    Frame.Continuation = 3
                    Call SyntaxConsume(State.Cursor, State.Metrics)
                    Frames(FrameCount - 1) = Frame
                    If TrySyntaxPushExpression(Frames, FrameCount, State, 1, Frame.Depth + 1, True, False) = False Then
                        Exit Function
                    End If
                    Pushed = True
                Else
                    If Kind = 12 Then
                        Kind = 4
                    End If
                    If Kind = 13 Then
                        Kind = 5
                    End If
                    If Kind = 4 Or Kind = 5 Or Kind = 6 Then
                        If Frame.Minimum > 14 Or (Kind = 6 And Frame.Minimum > 6) Then
                            TryParseSyntaxExpressionMode = SyntaxFail(State, 101)
                            Exit Function
                        End If
                        If Frame.Depth >= State.MaximumDepth Then
                            TryParseSyntaxExpressionMode = SyntaxFail(State, 2)
                            Exit Function
                        End If
                        Frame.OperatorKind = Kind
                        Frame.Continuation = 5
                        Call SyntaxConsume(State.Cursor, State.Metrics)
                        If TrySyntaxPeek(Document, Tokens, State) = False Then
                            Exit Function
                        End If
                        If Kind = 6 And State.Cursor.HadSpace = False Then
                            TryParseSyntaxExpressionMode = SyntaxFail(State, 102)
                            Exit Function
                        End If
                        Frames(FrameCount - 1) = Frame
                        If TrySyntaxPushExpression(Frames, FrameCount, State, SyntaxExpressionPrecedence(Kind), Frame.Depth + 1, True, False) = False Then
                            Exit Function
                        End If
                        Pushed = True
                    Else
                        If Kind = 31 Or Kind = 32 Or Kind = 39 Then
                            Frame.OperatorKind = Kind
                            Call SyntaxConsume(State.Cursor, State.Metrics)
                            If TrySyntaxPeek(Document, Tokens, State) = False Then
                                Exit Function
                            End If
                            If State.Cursor.HadSpace = False Then
                                TryParseSyntaxExpressionMode = SyntaxFail(State, 102)
                                Exit Function
                            End If
                            Dim Target As Long = -1
                            If Kind = 32 Then
                                If TrySyntaxTypeName(Document, Tokens, State, Target) = False Then
                                    Exit Function
                                End If
                            Else
                                If TrySyntaxQualifiedName(Document, Tokens, State, Target) = False Then
                                    Exit Function
                                End If
                            End If
                            If Kind = 39 Then
                                Frame.Root = Target
                                Frame.CallKind = 39
                                Frame.Continuation = 1
                                If TrySyntaxAt(Document, Tokens, State, "(", Matches) = False Then
                                    Exit Function
                                End If
                                If Matches = False Then
                                    TryParseSyntaxExpressionMode = SyntaxFail(State, 102)
                                    Exit Function
                                End If
                            Else
                                If TrySyntaxCombineExpression(State, Kind, Frame.FirstByte, -1, Target, Frame.Root) = False Then
                                    Exit Function
                                End If
                                Frame.Continuation = 1
                            End If
                        Else
                            If Kind = 37 And Frame.Minimum <= 7 Then
                                Frame.Continuation = 6
                                Call SyntaxConsume(State.Cursor, State.Metrics)
                                If TrySyntaxPeek(Document, Tokens, State) = False Then
                                    Exit Function
                                End If
                                If State.Cursor.HadSpace = False Then
                                    TryParseSyntaxExpressionMode = SyntaxFail(State, 102)
                                    Exit Function
                                End If
                                Frames(FrameCount - 1) = Frame
                                If TrySyntaxPushExpression(Frames, FrameCount, State, 8, Frame.Depth, True, False) = False Then
                                    Exit Function
                                End If
                                Pushed = True
                            Else
                                If Kind = -4 And State.WithDepth > 0 Then
                                    Call SyntaxConsume(State.Cursor, State.Metrics)
                                    Dim MemberNode As Long = -1
                                    If TrySyntaxReadName(Document, Tokens, State, True, MemberNode) = False Then
                                        Exit Function
                                    End If
                                    If TrySyntaxNameSuffix(Document, Tokens, State, MemberNode) = False Then
                                        Exit Function
                                    End If
                                    If TrySyntaxCombineExpression(State, 33, Frame.FirstByte, -1, MemberNode, Frame.Root) = False Then
                                        Exit Function
                                    End If
                                    Frame.Continuation = 1
                                Else
                                    TryParseSyntaxExpressionMode = SyntaxFail(State, 101)
                                    Exit Function
                                End If
                            End If
                        End If
                    End If
                End If
            End If
        Else
            If Frame.Continuation = 1 Then
                If Kind = -4 Or Kind = -5 Then
                    Dim MemberKind As Long = 34
                    If Kind = -5 Then
                        MemberKind = 35
                    End If
                    Call SyntaxConsume(State.Cursor, State.Metrics)
                    MemberNode = -1
                    If TrySyntaxReadName(Document, Tokens, State, True, MemberNode) = False Then
                        Exit Function
                    End If
                    If TrySyntaxNameSuffix(Document, Tokens, State, MemberNode) = False Then
                        Exit Function
                    End If
                    Dim Combined As Long = -1
                    If TrySyntaxCombineExpression(State, MemberKind, State.Pending(0).Nodes(Frame.Root).FirstByte, Frame.Root, MemberNode, Combined) = False Then
                        Exit Function
                    End If
                    Frame.Root = Combined
                Else
                    If Kind = -1 And Frame.AllowCalls Then
                        If Frame.Depth >= State.MaximumDepth Then
                            TryParseSyntaxExpressionMode = SyntaxFail(State, 2)
                            Exit Function
                        End If
                        Dim FirstByte As Long = State.Pending(0).Nodes(Frame.Root).FirstByte
                        If Frame.CallKind = 39 Then
                            FirstByte = Frame.FirstByte
                        End If
                        If TrySyntaxNewNode(State, Frame.CallKind, FirstByte, State.Cursor.Token.Last.ByteOffset, Frame.ParentNode) = False Then
                            Exit Function
                        End If
                        Frame.Tail = -1
                        If TrySyntaxAttach(State, Frame.ParentNode, Frame.Root, Frame.Tail) = False Then
                            Exit Function
                        End If
                        Call SyntaxConsume(State.Cursor, State.Metrics)
                        Frame.Continuation = 4
                        Frame.HadArgument = False
                    Else
                        If Kind = -6 And Frame.AllowNamed And State.Pending(0).Nodes(Frame.Root).Kind = 1 Then
                            Frame.Continuation = 9
                            Call SyntaxConsume(State.Cursor, State.Metrics)
                            Frames(FrameCount - 1) = Frame
                            If TrySyntaxPushExpression(Frames, FrameCount, State, 1, Frame.Depth, True, False) = False Then
                                Exit Function
                            End If
                            Pushed = True
                        Else
                            Dim Precedence As Long = SyntaxExpressionPrecedence(Kind)
                            If Kind < 7 Or Kind > 30 Or Precedence < Frame.Minimum Then
                                Completed = True
                            Else
                                If Precedence = 7 And Frame.SeenComparison Then
                                    TryParseSyntaxExpressionMode = SyntaxFail(State, 103)
                                    Exit Function
                                End If
                                If Precedence = 7 Then
                                    Frame.SeenComparison = True
                                End If
                                Dim WordSpacing As Boolean = Kind = 11 Or Kind >= 24
                                If WordSpacing And State.Cursor.HadSpace = False Then
                                    TryParseSyntaxExpressionMode = SyntaxFail(State, 102)
                                    Exit Function
                                End If
                                If Kind = 7 And Frame.Depth >= State.MaximumDepth Then
                                    TryParseSyntaxExpressionMode = SyntaxFail(State, 2)
                                    Exit Function
                                End If
                                Call SyntaxConsume(State.Cursor, State.Metrics)
                                If TrySyntaxPeek(Document, Tokens, State) = False Then
                                    Exit Function
                                End If
                                If Kind = 22 And State.Cursor.HadSpace Then
                                    If TrySyntaxAt(Document, Tokens, State, "Not", Matches) = False Then
                                        Exit Function
                                    End If
                                    If Matches Then
                                        Kind = 23
                                        Call SyntaxConsume(State.Cursor, State.Metrics)
                                        If TrySyntaxPeek(Document, Tokens, State) = False Then
                                            Exit Function
                                        End If
                                    End If
                                End If
                                If WordSpacing And State.Cursor.HadSpace = False Then
                                    TryParseSyntaxExpressionMode = SyntaxFail(State, 102)
                                    Exit Function
                                End If
                                Frame.OperatorKind = Kind
                                Frame.Continuation = 2
                                Dim ChildMinimum As Long = Precedence + 1
                                Dim ChildDepth As Long = Frame.Depth
                                If Kind = 7 Then
                                    ChildMinimum = 13
                                    ChildDepth = ChildDepth + 1
                                End If
                                Frames(FrameCount - 1) = Frame
                                If TrySyntaxPushExpression(Frames, FrameCount, State, ChildMinimum, ChildDepth, True, False) = False Then
                                    Exit Function
                                End If
                                Pushed = True
                            End If
                        End If
                    End If
                End If
            Else
                If Frame.Continuation = 4 Then
                    If Kind = -2 Or Kind = -3 Then
                        If Kind = -3 Or Frame.HadArgument Then
                            Dim EmptyNode As Long = -1
                            If TrySyntaxNewNode(State, 73, State.Cursor.Token.First.ByteOffset, State.Cursor.Token.First.ByteOffset, EmptyNode) = False Then
                                Exit Function
                            End If
                            If TrySyntaxAttach(State, Frame.ParentNode, EmptyNode, Frame.Tail) = False Then
                                Exit Function
                            End If
                        End If
                        If Kind = -2 Then
                            State.Pending(0).Nodes(Frame.ParentNode).LastByte = State.Cursor.Token.Last.ByteOffset
                            Call SyntaxConsume(State.Cursor, State.Metrics)
                            Frame.Root = Frame.ParentNode
                            Frame.Continuation = 1
                            Frame.CallKind = 38
                        Else
                            Call SyntaxConsume(State.Cursor, State.Metrics)
                            Frame.HadArgument = True
                        End If
                    Else
                        Frame.Continuation = 7
                        Frames(FrameCount - 1) = Frame
                        If TrySyntaxPushExpression(Frames, FrameCount, State, 1, Frame.Depth + 1, True, True) = False Then
                            Exit Function
                        End If
                        Pushed = True
                    End If
                Else
                    If Frame.Continuation = 8 Then
                        If Kind = -2 Then
                            State.Pending(0).Nodes(Frame.ParentNode).LastByte = State.Cursor.Token.Last.ByteOffset
                            Call SyntaxConsume(State.Cursor, State.Metrics)
                            Frame.Root = Frame.ParentNode
                            Frame.Continuation = 1
                            Frame.CallKind = 38
                        Else
                            If Kind <> -3 Then
                                TryParseSyntaxExpressionMode = SyntaxFail(State, 102)
                                Exit Function
                            End If
                            Call SyntaxConsume(State.Cursor, State.Metrics)
                            Frame.Continuation = 4
                            Frame.HadArgument = True
                        End If
                    Else
                        TryParseSyntaxExpressionMode = SyntaxFail(State, 1)
                        Exit Function
                    End If
                End If
            End If
        End If
        If Completed Then
            ' Returning a child resumes its saved grammar continuation. Pushed
            ' frames are never overwritten with the suspended parent's state.
            Dim ResultNode As Long = Frame.Root
            FrameCount = FrameCount - 1
            State.Metrics.Transitions = State.Metrics.Transitions + 1
            If FrameCount = 0 Then
                Root = ResultNode
                TryParseSyntaxExpressionMode = True
                Exit Function
            End If
            Frame = Frames(FrameCount - 1)
            If Frame.Continuation = 2 Or Frame.Continuation = 9 Then
                Dim CombinedKind As Long = Frame.OperatorKind
                If Frame.Continuation = 9 Then
                    CombinedKind = 36
                End If
                Combined = -1
                If TrySyntaxCombineExpression(State, CombinedKind, State.Pending(0).Nodes(Frame.Root).FirstByte, Frame.Root, ResultNode, Combined) = False Then
                    Exit Function
                End If
                Frame.Root = Combined
                Frame.Continuation = 1
                Frame.AllowNamed = False
            Else
                If Frame.Continuation = 3 Then
                    If TrySyntaxAt(Document, Tokens, State, ")", Matches) = False Then
                        Exit Function
                    End If
                    If Matches = False Then
                        TryParseSyntaxExpressionMode = SyntaxFail(State, 102)
                        Exit Function
                    End If
                    Dim GroupNode As Long = -1
                    If TrySyntaxNewNode(State, 3, Frame.FirstByte, State.Cursor.Token.Last.ByteOffset, GroupNode) = False Then
                        Exit Function
                    End If
                    Dim Tail As Long = -1
                    If TrySyntaxAttach(State, GroupNode, ResultNode, Tail) = False Then
                        Exit Function
                    End If
                    Call SyntaxConsume(State.Cursor, State.Metrics)
                    Frame.Root = GroupNode
                    Frame.Continuation = 1
                Else
                    If Frame.Continuation = 5 Then
                        If TrySyntaxCombineExpression(State, Frame.OperatorKind, Frame.FirstByte, -1, ResultNode, Frame.Root) = False Then
                            Exit Function
                        End If
                        Frame.Continuation = 1
                    Else
                        If Frame.Continuation = 6 Then
                            If TrySyntaxAt(Document, Tokens, State, "Is", Matches) = False Then
                                Exit Function
                            End If
                            If Matches = False Or State.Cursor.HadSpace = False Then
                                TryParseSyntaxExpressionMode = SyntaxFail(State, 102)
                                Exit Function
                            End If
                            Call SyntaxConsume(State.Cursor, State.Metrics)
                            If TrySyntaxPeek(Document, Tokens, State) = False Then
                                Exit Function
                            End If
                            If State.Cursor.HadSpace = False Then
                                TryParseSyntaxExpressionMode = SyntaxFail(State, 102)
                                Exit Function
                            End If
                            Dim TypeNode As Long = -1
                            If TrySyntaxTypeName(Document, Tokens, State, TypeNode) = False Then
                                Exit Function
                            End If
                            If TrySyntaxCombineExpression(State, 37, Frame.FirstByte, ResultNode, TypeNode, Frame.Root) = False Then
                                Exit Function
                            End If
                            Frame.Continuation = 1
                            Frame.SeenComparison = True
                        Else
                            If Frame.Continuation = 7 Then
                                If TrySyntaxAttach(State, Frame.ParentNode, ResultNode, Frame.Tail) = False Then
                                    Exit Function
                                End If
                                Frame.Continuation = 8
                            Else
                                TryParseSyntaxExpressionMode = SyntaxFail(State, 1)
                                Exit Function
                            End If
                        End If
                    End If
                End If
            End If
        End If
        If FrameCount > 0 And Pushed = False Then
            Frames(FrameCount - 1) = Frame
        End If
    Wend
End Function
