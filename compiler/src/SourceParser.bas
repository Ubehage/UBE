UBE SOURCE 1 MODULE
Attribute UBE_Name = "SourceParser"
' Retains caller-owned syntax trees over immutable source bytes and scanner tokens.
Public Const ModuleNode As Long = 1
Public Const OptionNode As Long = 2
Public Const VariableNode As Long = 3
Public Const ConstantNode As Long = 4
Public Const TypeNode As Long = 5
Public Const FieldNode As Long = 6
Public Const SubNode As Long = 7
Public Const FunctionNode As Long = 8
Public Const ParameterNode As Long = 9
Public Const PrimitiveNode As Long = 10
Public Const BodyNode As Long = 11
Public Const ArrayShapeNode As Long = 12
Public Const NameNode As Long = 13
Public Const MemberNode As Long = 14
Public Const CallNode As Long = 15
Public Const NumberNode As Long = 16
Public Const BooleanNode As Long = 17
Public Const UnaryNode As Long = 18
Public Const BinaryNode As Long = 19
Public Const GroupNode As Long = 20
Public Const AssignmentNode As Long = 21
Public Const IfNode As Long = 22
Public Const ThenNode As Long = 23
Public Const ElseNode As Long = 24
Public Const DoNode As Long = 25
Public Const ExitNode As Long = 26
Public Const GoToNode As Long = 27
Public Const LabelNode As Long = 28
Public Const OnErrorNode As Long = 29
Public Const ThreadStartNode As Long = 30

Public Type SyntaxNode
    Kind As Long
    Value As Long
    Modifier As Long
    Suffix As Long
    IsIntrinsic As Boolean
    NameToken As Long
    TypeFirstToken As Long
    TypeLastToken As Long
    FirstToken As Long
    LastToken As Long
    Parent As Long
    FirstChild As Long
    LastChild As Long
    NextSibling As Long
    ByteStart As Long
    ByteLength As Long
    Utf16Start As Long
    Utf16Length As Long
    [Line] As Long
    Column As Long
End Type

Public Type ParseDiagnostic
    Code As Long
    Reason As Long
    TokenIndex As Long
    ByteOffset As Long
    Utf16Offset As Long
    [Line] As Long
    Column As Long
End Type

Private Type ParserState
    Position As Long
    TokenCount As Long
    NodeCount As Long
    Capacity As Long
    Depth As Long
    ProcedureKind As Long
    DoDepth As Long
End Type

' Grows candidate storage without publishing incomplete syntax.
Private Intrinsic Function ResizeNodes(ByRef Values() As SyntaxNode, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeNodes.UBE_Primitive = "Array.TryResize"
End Function

' Reads the actual retained token extent before indexing caller storage.
Private Intrinsic Function TokenLength(ByRef Values() As SourceScanner.SourceToken) As Long
Attribute TokenLength.UBE_Primitive = "Array.Length"
End Function

' Reads the actual immutable source extent before validating token spans.
Private Intrinsic Function SourceLength(ByRef Values() As Byte) As Long
Attribute SourceLength.UBE_Primitive = "Array.Length"
End Function

' Records the first located rejection; helper failures are propagated to the public boundary.
Private Function Reject(ByRef T() As SourceScanner.SourceToken, ByRef S As ParserState, ByRef D As ParseDiagnostic, ByVal Code As Long, ByVal Reason As Long) As Boolean
    Dim Index As Long
    On Error GoTo Failed
    If D.Code <> 0 Then Exit Function
    D.Code = Code
    D.Reason = Reason
    Index = S.Position
    If Index >= S.TokenCount Then Index = S.TokenCount - 1
    If Index < 0 Then Index = 0
    D.TokenIndex = Index
    If S.TokenCount > 0 Then
        D.ByteOffset = T(Index).ByteStart
        D.Utf16Offset = T(Index).Utf16Start
        D.Line = T(Index).Line
        D.Column = T(Index).Column
    End If
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Reads a bounded token classification with an EOF sentinel.
Private Function KindAt(ByRef T() As SourceScanner.SourceToken, ByRef S As ParserState, ByVal Ahead As Long) As Long
    Dim Index As Long
    On Error GoTo Failed
    Index = S.Position + Ahead
    If Index < 0 Or Index >= S.TokenCount Then KindAt = SourceScanner.EndToken: Exit Function
    KindAt = T(Index).Kind
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Classifies ordinary keyword and punctuation spellings through shared token helpers.
Private Function CodeAt(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef S As ParserState, ByVal Ahead As Long) As Long
    On Error GoTo Failed
    CodeAt = SyntaxTokens.TokenCode(B, T, S.Position + Ahead, S.TokenCount)
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Requires whitespace where the language grammar specifies spacing1.
Private Function RequireSpace(ByRef T() As SourceScanner.SourceToken, ByRef S As ParserState, ByRef D As ParseDiagnostic) As Boolean
    On Error GoTo Failed
    If S.Position > 0 And S.Position < S.TokenCount Then
        If T(S.Position - 1).ByteStart + T(S.Position - 1).ByteLength >= T(S.Position).ByteStart Then
            RequireSpace = Reject(T, S, D, 2, 2): Exit Function
        End If
    End If
    RequireSpace = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Requires one classified terminal and advances only on a match.
Private Function Expect(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef S As ParserState, ByRef D As ParseDiagnostic, ByVal Code As Long) As Boolean
    On Error GoTo Failed
    If CodeAt(B, T, S, 0) <> Code Then Expect = Reject(T, S, D, 2, 1): Exit Function
    S.Position = S.Position + 1
    Expect = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Consumes one logical newline without admitting trailing unsupported syntax.
Private Function EndLine(ByRef T() As SourceScanner.SourceToken, ByRef S As ParserState, ByRef D As ParseDiagnostic) As Boolean
    On Error GoTo Failed
    If KindAt(T, S, 0) <> SourceScanner.NewlineToken Then EndLine = Reject(T, S, D, 2, 3): Exit Function
    S.Position = S.Position + 1
    EndLine = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Skips empty logical lines without consuming the EOF token.
Private Sub SkipLines(ByRef T() As SourceScanner.SourceToken, ByRef S As ParserState)
    On Error GoTo Failed
    Do While KindAt(T, S, 0) = SourceScanner.NewlineToken
        S.Position = S.Position + 1
    Loop
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

' Retains an identifier token; member names may use ordinary reserved words.
Private Function ReadName(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef S As ParserState, ByRef D As ParseDiagnostic, ByVal Member As Boolean) As Long
    Dim Code As Long
    On Error GoTo Failed
    If SyntaxTokens.IsIdentifierToken(B, T, S.Position, S.TokenCount, Member) = False Then
        ReadName = -1
        Code = 3
        If Member Or KindAt(T, S, 0) = SourceScanner.NewlineToken Or KindAt(T, S, 0) = SourceScanner.EndToken Then Code = 2
        Reject T, S, D, Code, 4
        Exit Function
    End If
    ReadName = S.Position
    S.Position = S.Position + 1
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Allocates one durable one-based node ID inside a bounded candidate array.
Private Function NewNode(ByRef T() As SourceScanner.SourceToken, ByRef N() As SyntaxNode, ByRef S As ParserState, ByRef D As ParseDiagnostic, ByVal Kind As Long, ByVal Start As Long) As Long
    Dim Capacity As Long
    Dim Index As Long
    On Error GoTo Failed
    If S.NodeCount >= 65536 Then Reject T, S, D, 4, 5: Exit Function
    If S.NodeCount = S.Capacity Then
        Capacity = S.Capacity + S.Capacity
        If Capacity = 0 Then Capacity = 128
        If Capacity > 65536 Then Capacity = 65536
        If ResizeNodes(N, Capacity, True) = False Then Reject T, S, D, 5, 6: Exit Function
        S.Capacity = Capacity
    End If
    Index = S.NodeCount
    S.NodeCount = S.NodeCount + 1
    N(Index).Kind = Kind
    N(Index).NameToken = -1
    N(Index).TypeFirstToken = -1
    N(Index).TypeLastToken = -1
    N(Index).FirstToken = Start
    N(Index).LastToken = Start - 1
    N(Index).ByteStart = T(Start).ByteStart
    N(Index).Utf16Start = T(Start).Utf16Start
    N(Index).Line = T(Start).Line
    N(Index).Column = T(Start).Column
    NewNode = Index + 1
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Completes inclusive token and physical source spans; empty bodies remain zero length.
Private Sub FinishNode(ByRef T() As SourceScanner.SourceToken, ByRef N() As SyntaxNode, ByRef S As ParserState, ByVal Node As Long)
    Dim Index As Long
    Dim Last As Long
    On Error GoTo Failed
    Index = Node - 1
    Last = S.Position - 1
    N(Index).LastToken = Last
    If Last < N(Index).FirstToken Then Exit Sub
    N(Index).ByteLength = T(Last).ByteStart + T(Last).ByteLength - N(Index).ByteStart
    N(Index).Utf16Length = T(Last).Utf16Start + T(Last).Utf16Length - N(Index).Utf16Start
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

' Attaches an existing subtree exactly once in source evaluation order.
Private Sub AddChild(ByRef N() As SyntaxNode, ByVal Parent As Long, ByVal Child As Long)
    Dim Tail As Long
    On Error GoTo Failed
    N(Child - 1).Parent = Parent
    Tail = N(Parent - 1).LastChild
    If Tail = 0 Then
        N(Parent - 1).FirstChild = Child
    Else
        N(Tail - 1).NextSibling = Child
    End If
    N(Parent - 1).LastChild = Child
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

' Bounds recursive syntax before descent, independently of runtime call depth.
Private Function EnterSyntax(ByRef T() As SourceScanner.SourceToken, ByRef S As ParserState, ByRef D As ParseDiagnostic) As Boolean
    On Error GoTo Failed
    If S.Depth >= 48 Then EnterSyntax = Reject(T, S, D, 4, 7): Exit Function
    S.Depth = S.Depth + 1
    EnterSyntax = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Consumes only adjacent admitted type suffixes and returns their scalar type code.
Private Function ScalarSuffix(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef S As ParserState) As Long
    Dim Code As Long
    Dim Result As Long
    On Error GoTo Failed
    Code = CodeAt(B, T, S, 0)
    If Code = SyntaxTokens.SymPercent Then Result = SyntaxTokens.KwInteger
    If Code = SyntaxTokens.SymAmpersand Then Result = SyntaxTokens.KwLong
    If Code = SyntaxTokens.SymCaret Then Result = SyntaxTokens.KwLongLong
    If Result = 0 Or S.Position < 1 Then Exit Function
    If T(S.Position - 1).ByteStart + T(S.Position - 1).ByteLength <> T(S.Position).ByteStart Then Exit Function
    S.Position = S.Position + 1
    ScalarSuffix = Result
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Rejects dots embedded in decoded type-name components, which would erase qualification boundaries.
Private Function TypeComponent(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef S As ParserState, ByRef D As ParseDiagnostic, ByVal Index As Long) As Boolean
    Dim Position As Long
    Dim Finish As Long
    On Error GoTo Failed
    Position = T(Index).ByteStart
    Finish = Position + T(Index).ByteLength
    Do While Position < Finish
        If B(Position) = 46 Then TypeComponent = Reject(T, S, D, 3, 40): Exit Function
        Position = Position + 1
    Loop
    TypeComponent = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Retains explicit scalar or qualified record type spelling and authoritative suffix assertions.
Private Function ReadType(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SyntaxNode, ByRef S As ParserState, ByRef D As ParseDiagnostic, ByVal Node As Long, ByVal Suffix As Long) As Boolean
    Dim Start As Long
    Dim Code As Long
    Dim NameIndex As Long
    On Error GoTo Failed
    N(Node - 1).Suffix = Suffix
    If CodeAt(B, T, S, 0) <> SyntaxTokens.KwAs Then
        If Suffix = 0 Then ReadType = Reject(T, S, D, 2, 8): Exit Function
        ReadType = True: Exit Function
    End If
    If RequireSpace(T, S, D) = False Then Exit Function
    S.Position = S.Position + 1
    If RequireSpace(T, S, D) = False Then Exit Function
    Start = S.Position
    Code = CodeAt(B, T, S, 0)
    If Code = SyntaxTokens.KwBoolean Or Code = SyntaxTokens.KwByte Or Code = SyntaxTokens.KwInteger Or Code = SyntaxTokens.KwLong Or Code = SyntaxTokens.KwLongLong Then
        S.Position = S.Position + 1
    Else
        NameIndex = ReadName(B, T, S, D, False)
        If NameIndex < 0 Then Exit Function
        If TypeComponent(B, T, S, D, NameIndex) = False Then Exit Function
        Do While CodeAt(B, T, S, 0) = SyntaxTokens.SymDot
            S.Position = S.Position + 1
            NameIndex = ReadName(B, T, S, D, True)
            If NameIndex < 0 Then Exit Function
            If TypeComponent(B, T, S, D, NameIndex) = False Then Exit Function
        Loop
    End If
    If Suffix <> 0 Then
        If Code <> Suffix Or S.Position <> Start + 1 Then ReadType = Reject(T, S, D, 2, 9): Exit Function
    End If
    N(Node - 1).TypeFirstToken = Start
    N(Node - 1).TypeLastToken = S.Position - 1
    ReadType = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Builds ordinary qualified names without assigning runtime meaning to any spelling.
Private Function ParseName(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SyntaxNode, ByRef S As ParserState, ByRef D As ParseDiagnostic) As Long
    Dim Start As Long
    Dim NameIndex As Long
    Dim Node As Long
    Dim Member As Long
    On Error GoTo Failed
    Start = S.Position
    NameIndex = ReadName(B, T, S, D, False)
    If NameIndex < 0 Then Exit Function
    Node = NewNode(T, N, S, D, NameNode, Start)
    If Node = 0 Then Exit Function
    N(Node - 1).NameToken = NameIndex
    N(Node - 1).Suffix = ScalarSuffix(B, T, S)
    FinishNode T, N, S, Node
    Do While CodeAt(B, T, S, 0) = SyntaxTokens.SymDot
        S.Position = S.Position + 1
        NameIndex = ReadName(B, T, S, D, True)
        If NameIndex < 0 Then Exit Function
        Member = NewNode(T, N, S, D, MemberNode, Start)
        If Member = 0 Then Exit Function
        N(Member - 1).NameToken = NameIndex
        N(Member - 1).Suffix = ScalarSuffix(B, T, S)
        AddChild N, Member, Node
        Node = Member
        FinishNode T, N, S, Node
    Loop
    ParseName = Node
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Parses positional parenthesized arguments into an existing call node.
Private Function CallArguments(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SyntaxNode, ByRef S As ParserState, ByRef D As ParseDiagnostic, ByVal Node As Long) As Boolean
    Dim Argument As Long
    On Error GoTo Failed
    If Expect(B, T, S, D, SyntaxTokens.SymOpen) = False Then Exit Function
    If CodeAt(B, T, S, 0) <> SyntaxTokens.SymClose Then
        Do
            Argument = ParseExpression(B, T, N, S, D, 1)
            If Argument = 0 Then Exit Function
            AddChild N, Node, Argument
            If CodeAt(B, T, S, 0) <> SyntaxTokens.SymComma Then Exit Do
            S.Position = S.Position + 1
        Loop
    End If
    CallArguments = Expect(B, T, S, D, SyntaxTokens.SymClose)
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Parses a thread target using the explicit Call target and argument syntax.
Private Function ParseThreadStart(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SyntaxNode, ByRef S As ParserState, ByRef D As ParseDiagnostic) As Long
    Dim Start As Long
    Dim Target As Long
    Dim Node As Long
    On Error GoTo Failed
    Start = S.Position
    S.Position = S.Position + 1
    If RequireSpace(T, S, D) = False Then Exit Function
    Target = ParseName(B, T, N, S, D)
    If Target = 0 Then Exit Function
    Node = NewNode(T, N, S, D, ThreadStartNode, Start)
    If Node = 0 Then Exit Function
    AddChild N, Node, Target
    If CodeAt(B, T, S, 0) = SyntaxTokens.SymOpen Then
        If CallArguments(B, T, N, S, D, Node) = False Then Exit Function
    End If
    FinishNode T, N, S, Node
    ParseThreadStart = Node
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Retains call, index and field postfix syntax for later declaration-based binding.
Private Function ParsePostfix(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SyntaxNode, ByRef S As ParserState, ByRef D As ParseDiagnostic) As Long
    Dim Start As Long
    Dim Node As Long
    Dim Child As Long
    Dim NameIndex As Long
    Dim Code As Long
    On Error GoTo Failed
    Start = S.Position
    Node = ParseName(B, T, N, S, D)
    If Node = 0 Then Exit Function
    Do
        Code = CodeAt(B, T, S, 0)
        If Code = SyntaxTokens.SymOpen Then
            Child = Node
            Node = NewNode(T, N, S, D, CallNode, Start)
            If Node = 0 Then Exit Function
            AddChild N, Node, Child
            If CallArguments(B, T, N, S, D, Node) = False Then Exit Function
        ElseIf Code = SyntaxTokens.SymDot Then
            S.Position = S.Position + 1
            NameIndex = ReadName(B, T, S, D, True)
            If NameIndex < 0 Then Exit Function
            Child = Node
            Node = NewNode(T, N, S, D, MemberNode, Start)
            If Node = 0 Then Exit Function
            N(Node - 1).NameToken = NameIndex
            N(Node - 1).Suffix = ScalarSuffix(B, T, S)
            AddChild N, Node, Child
        Else
            Exit Do
        End If
        FinishNode T, N, S, Node
    Loop
    ParsePostfix = Node
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Reports normative precedence for the admitted eager operators.
Private Function OperatorRank(ByVal Code As Long) As Long
    If Code = SyntaxTokens.KwOr Then OperatorRank = 1
    If Code = SyntaxTokens.KwAnd Then OperatorRank = 2
    If Code = SyntaxTokens.SymEqual Or Code = SyntaxTokens.SymNotEqual Or Code = SyntaxTokens.SymLess Or Code = SyntaxTokens.SymGreater Or Code = SyntaxTokens.SymLessEqual Or Code = SyntaxTokens.SymGreaterEqual Then OperatorRank = 4
    If Code = SyntaxTokens.SymPlus Or Code = SyntaxTokens.SymMinus Then OperatorRank = 5
    If Code = SyntaxTokens.SymStar Then OperatorRank = 6
    If Code = SyntaxTokens.SymBackslash Then OperatorRank = 7
    If Code = SyntaxTokens.KwMod Then OperatorRank = 8
End Function

' Parses literal, grouped and unary primaries with retained source spelling.
Private Function ParsePrimary(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SyntaxNode, ByRef S As ParserState, ByRef D As ParseDiagnostic) As Long
    Dim Start As Long
    Dim Node As Long
    Dim Child As Long
    Dim Code As Long
    Dim Minimum As Long
    Dim Kind As Long
    On Error GoTo Failed
    Start = S.Position
    Code = CodeAt(B, T, S, 0)
    Kind = KindAt(T, S, 0)
    If Code = SyntaxTokens.KwCallNew Then
        Node = ParseThreadStart(B, T, N, S, D)
        If Node = 0 Then Exit Function
    ElseIf Code = SyntaxTokens.SymPlus Or Code = SyntaxTokens.SymMinus Or Code = SyntaxTokens.KwNot Then
        S.Position = S.Position + 1
        Node = NewNode(T, N, S, D, UnaryNode, Start)
        If Node = 0 Then Exit Function
        N(Node - 1).Value = Code
        Minimum = 9
        If Code = SyntaxTokens.KwNot Then
            Minimum = 3
            If RequireSpace(T, S, D) = False Then Exit Function
        End If
        Child = ParseExpression(B, T, N, S, D, Minimum)
        If Child = 0 Then Exit Function
        AddChild N, Node, Child
    ElseIf Code = SyntaxTokens.SymOpen Then
        S.Position = S.Position + 1
        Node = NewNode(T, N, S, D, GroupNode, Start)
        If Node = 0 Then Exit Function
        Child = ParseExpression(B, T, N, S, D, 1)
        If Child = 0 Then Exit Function
        AddChild N, Node, Child
        If Expect(B, T, S, D, SyntaxTokens.SymClose) = False Then Exit Function
    ElseIf Kind = SourceScanner.NumberToken Then
        If SyntaxTokens.IsIntegerToken(B, T, S.Position, S.TokenCount) = False Then Reject T, S, D, 3, 10: Exit Function
        S.Position = S.Position + 1
        Node = NewNode(T, N, S, D, NumberNode, Start)
        If Node = 0 Then Exit Function
        N(Node - 1).NameToken = Start
    ElseIf Code = SyntaxTokens.KwTrue Or Code = SyntaxTokens.KwFalse Then
        S.Position = S.Position + 1
        Node = NewNode(T, N, S, D, BooleanNode, Start)
        If Node = 0 Then Exit Function
        N(Node - 1).Value = Code
        N(Node - 1).NameToken = Start
    ElseIf SyntaxTokens.IsIdentifierToken(B, T, S.Position, S.TokenCount, False) Then
        Node = ParsePostfix(B, T, N, S, D)
        If Node = 0 Then Exit Function
    Else
        If Kind = SourceScanner.NewlineToken Or Kind = SourceScanner.EndToken Or Code = SyntaxTokens.SymClose Or Code = SyntaxTokens.SymComma Or Code = SyntaxTokens.KwThen Or Code = SyntaxTokens.KwElse Then
            Reject T, S, D, 2, 11
        Else
            Reject T, S, D, 3, 11
        End If
        Exit Function
    End If
    FinishNode T, N, S, Node
    ParsePrimary = Node
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Builds precedence-climbing expression trees without folding away checked operations.
Private Function ParseExpression(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SyntaxNode, ByRef S As ParserState, ByRef D As ParseDiagnostic, ByVal Minimum As Long) As Long
    Dim LeftNode As Long
    Dim RightNode As Long
    Dim Node As Long
    Dim Rank As Long
    Dim Code As Long
    Dim ComparisonSeen As Boolean
    On Error GoTo Failed
    If EnterSyntax(T, S, D) = False Then Exit Function
    If Minimum > 3 And CodeAt(B, T, S, 0) = SyntaxTokens.KwNot Then Reject T, S, D, 2, 12: Exit Function
    LeftNode = ParsePrimary(B, T, N, S, D)
    If LeftNode = 0 Then Exit Function
    Do
        Code = CodeAt(B, T, S, 0)
        Rank = OperatorRank(Code)
        If Rank = 0 Or Rank < Minimum Then Exit Do
        If Rank = 4 Then
            If ComparisonSeen Then Reject T, S, D, 2, 13: Exit Function
            ComparisonSeen = True
        End If
        If Rank <= 2 Or Code = SyntaxTokens.KwMod Then
            If RequireSpace(T, S, D) = False Then Exit Function
        End If
        S.Position = S.Position + 1
        If Rank <= 2 Or Code = SyntaxTokens.KwMod Then
            If RequireSpace(T, S, D) = False Then Exit Function
        End If
        RightNode = ParseExpression(B, T, N, S, D, Rank + 1)
        If RightNode = 0 Then Exit Function
        Node = NewNode(T, N, S, D, BinaryNode, N(LeftNode - 1).FirstToken)
        If Node = 0 Then Exit Function
        N(Node - 1).Value = Code
        AddChild N, Node, LeftNode
        AddChild N, Node, RightNode
        FinishNode T, N, S, Node
        LeftNode = Node
    Loop
    S.Depth = S.Depth - 1
    ParseExpression = LeftNode
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Retains rank-one bounds, including an explicit synthetic zero for omitted lower bounds.
Private Function ParseArrayShape(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SyntaxNode, ByRef S As ParserState, ByRef D As ParseDiagnostic) As Long
    Dim Start As Long
    Dim Node As Long
    Dim First As Long
    Dim Lower As Long
    Dim Upper As Long
    On Error GoTo Failed
    Start = S.Position
    Node = NewNode(T, N, S, D, ArrayShapeNode, Start)
    If Node = 0 Then Exit Function
    N(Node - 1).Value = 1
    S.Position = S.Position + 1
    If CodeAt(B, T, S, 0) = SyntaxTokens.SymComma Then Reject T, S, D, 3, 14: Exit Function
    If CodeAt(B, T, S, 0) = SyntaxTokens.SymClose Then
        N(Node - 1).Value = 2
    Else
        First = ParseExpression(B, T, N, S, D, 1)
        If First = 0 Then Exit Function
        If CodeAt(B, T, S, 0) = SyntaxTokens.KwTo Then
            S.Position = S.Position + 1
            Lower = First
            Upper = ParseExpression(B, T, N, S, D, 1)
            If Upper = 0 Then Exit Function
        Else
            Upper = First
            Lower = NewNode(T, N, S, D, NumberNode, Start)
            If Lower = 0 Then Exit Function
        End If
        AddChild N, Node, Lower
        AddChild N, Node, Upper
        If CodeAt(B, T, S, 0) = SyntaxTokens.SymComma Then Reject T, S, D, 3, 14: Exit Function
    End If
    If Expect(B, T, S, D, SyntaxTokens.SymClose) = False Then Exit Function
    FinishNode T, N, S, Node
    ParseArrayShape = Node
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Parses independent explicitly typed items in a module or local declaration.
Private Function ParseVariables(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SyntaxNode, ByRef S As ParserState, ByRef D As ParseDiagnostic, ByVal Parent As Long, ByVal Visibility As Long, ByVal Constant As Boolean) As Boolean
    Dim Start As Long
    Dim Node As Long
    Dim Value As Long
    Dim NameIndex As Long
    Dim Kind As Long
    Dim Suffix As Long
    Dim Shape As Long
    On Error GoTo Failed
    Kind = VariableNode
    If Constant Then Kind = ConstantNode
    Do
        Start = S.Position
        If CodeAt(B, T, S, -1) <> SyntaxTokens.SymComma Then
            If RequireSpace(T, S, D) = False Then Exit Function
        End If
        NameIndex = ReadName(B, T, S, D, False)
        If NameIndex < 0 Then Exit Function
        Suffix = ScalarSuffix(B, T, S)
        Node = NewNode(T, N, S, D, Kind, Start)
        If Node = 0 Then Exit Function
        N(Node - 1).NameToken = NameIndex
        N(Node - 1).Modifier = Visibility
        If CodeAt(B, T, S, 0) = SyntaxTokens.SymOpen Then
            If Constant Or Suffix <> 0 Then Reject T, S, D, 2, 15: Exit Function
            Shape = ParseArrayShape(B, T, N, S, D)
            If Shape = 0 Then Exit Function
            AddChild N, Node, Shape
        End If
        If ReadType(B, T, N, S, D, Node, Suffix) = False Then Exit Function
        If CodeAt(B, T, S, 0) = SyntaxTokens.SymEqual Then
            S.Position = S.Position + 1
            Value = ParseExpression(B, T, N, S, D, 1)
            If Value = 0 Then Exit Function
            AddChild N, Node, Value
        ElseIf Constant Then
            Reject T, S, D, 2, 16: Exit Function
        End If
        FinishNode T, N, S, Node
        AddChild N, Parent, Node
        If CodeAt(B, T, S, 0) <> SyntaxTokens.SymComma Then Exit Do
        S.Position = S.Position + 1
    Loop
    ParseVariables = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Determines whether a statement argument list has reached a logical separator.
Private Function StatementEnd(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef S As ParserState) As Boolean
    Dim Kind As Long
    Dim Code As Long
    On Error GoTo Failed
    Kind = KindAt(T, S, 0)
    Code = CodeAt(B, T, S, 0)
    StatementEnd = Kind = SourceScanner.NewlineToken Or Kind = SourceScanner.EndToken Or Code = SyntaxTokens.SymColon Or Code = SyntaxTokens.KwElse
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Looks for an adjacent indexed assignment while preserving grouped no-Call arguments.
Private Function AssignmentAhead(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef S As ParserState, ByVal ExplicitLet As Boolean) As Boolean
    Dim Ahead As Long
    Dim Depth As Long
    Dim Code As Long
    Dim Kind As Long
    On Error GoTo Failed
    If SyntaxTokens.IsIdentifierToken(B, T, S.Position, S.TokenCount, False) = False Then Exit Function
    Ahead = 1
    Do
        Code = CodeAt(B, T, S, Ahead)
        If Code = SyntaxTokens.SymPercent Or Code = SyntaxTokens.SymAmpersand Or Code = SyntaxTokens.SymCaret Then Ahead = Ahead + 1
        Code = CodeAt(B, T, S, Ahead)
        If Code = SyntaxTokens.SymDot Then
            Kind = KindAt(T, S, Ahead + 1)
            If Kind <> SourceScanner.WordToken And Kind <> SourceScanner.IdentifierToken Then Exit Function
            Ahead = Ahead + 2
        ElseIf Code = SyntaxTokens.SymOpen Then
            If ExplicitLet = False Then
                If T(S.Position + Ahead - 1).ByteStart + T(S.Position + Ahead - 1).ByteLength <> T(S.Position + Ahead).ByteStart Then Exit Function
            End If
            Depth = 0
            Do
                Kind = KindAt(T, S, Ahead)
                If Kind = SourceScanner.NewlineToken Or Kind = SourceScanner.EndToken Then Exit Function
                Code = CodeAt(B, T, S, Ahead)
                If Code = SyntaxTokens.SymOpen Then Depth = Depth + 1
                If Code = SyntaxTokens.SymClose Then Depth = Depth - 1
                Ahead = Ahead + 1
                If Depth = 0 Then Exit Do
            Loop
        Else
            AssignmentAhead = Code = SyntaxTokens.SymEqual
            Exit Function
        End If
    Loop
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Retains named and plain decimal labels independently of value-name lookup.
Private Function ReadLabel(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef S As ParserState, ByRef D As ParseDiagnostic) As Long
    On Error GoTo Failed
    If KindAt(T, S, 0) <> SourceScanner.NumberToken Then
        ReadLabel = ReadName(B, T, S, D, False): Exit Function
    End If
    If SyntaxTokens.IsDecimalLabelToken(B, T, S.Position, S.TokenCount) = False Then
        Reject T, S, D, 2, 17
        ReadLabel = -1
        Exit Function
    End If
    ReadLabel = S.Position
    S.Position = S.Position + 1
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Retains the three supported On Error modes and any source label token.
Private Function ParseOnError(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SyntaxNode, ByRef S As ParserState, ByRef D As ParseDiagnostic) As Long
    Dim Start As Long
    Dim Node As Long
    Dim Mode As Long
    Dim NameIndex As Long
    On Error GoTo Failed
    Start = S.Position
    NameIndex = -1
    S.Position = S.Position + 1
    If Expect(B, T, S, D, SyntaxTokens.KwError) = False Then Exit Function
    If CodeAt(B, T, S, 0) = SyntaxTokens.KwResume Then
        S.Position = S.Position + 1
        If Expect(B, T, S, D, SyntaxTokens.KwNext) = False Then Exit Function
        Mode = 1
    Else
        If Expect(B, T, S, D, SyntaxTokens.KwGoTo) = False Then Exit Function
        If RequireSpace(T, S, D) = False Then Exit Function
        NameIndex = ReadLabel(B, T, S, D)
        If NameIndex < 0 Then Exit Function
        Mode = 2
        If T(NameIndex).Kind = SourceScanner.NumberToken Then
            If T(NameIndex).ByteLength = 1 Then
                If B(T(NameIndex).ByteStart) = 48 Then Mode = 0
            End If
        End If
    End If
    Node = NewNode(T, N, S, D, OnErrorNode, Start)
    If Node = 0 Then Exit Function
    N(Node - 1).Value = Mode
    N(Node - 1).NameToken = NameIndex
    FinishNode T, N, S, Node
    ParseOnError = Node
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Parses one executable statement, preserving explicit calls and assignment evaluation order.
Private Function ParseStatement(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SyntaxNode, ByRef S As ParserState, ByRef D As ParseDiagnostic) As Long
    Dim Start As Long
    Dim Code As Long
    Dim Node As Long
    Dim Target As Long
    Dim Value As Long
    Dim NameIndex As Long
    Dim ExplicitCall As Boolean
    Dim ExplicitLet As Boolean
    On Error GoTo Failed
    Start = S.Position
    Code = CodeAt(B, T, S, 0)
    If Code = SyntaxTokens.KwDo Then ParseStatement = ParseDo(B, T, N, S, D): Exit Function
    If Code = SyntaxTokens.KwIf Then ParseStatement = ParseIf(B, T, N, S, D): Exit Function
    If Code = SyntaxTokens.KwOn Then ParseStatement = ParseOnError(B, T, N, S, D): Exit Function
    If Code = SyntaxTokens.KwCallNew Then
        Node = ParseThreadStart(B, T, N, S, D)
        If Node = 0 Then Exit Function
        N(Node - 1).Value = 1
        ParseStatement = Node
        Exit Function
    End If
    If Code = SyntaxTokens.KwGoTo Then
        S.Position = S.Position + 1
        If RequireSpace(T, S, D) = False Then Exit Function
        NameIndex = ReadLabel(B, T, S, D)
        If NameIndex < 0 Then Exit Function
        Node = NewNode(T, N, S, D, GoToNode, Start)
        If Node = 0 Then Exit Function
        N(Node - 1).NameToken = NameIndex
    ElseIf Code = SyntaxTokens.KwExit Then
        S.Position = S.Position + 1
        Code = CodeAt(B, T, S, 0)
        If Code = SyntaxTokens.KwDo Then
            If S.DoDepth = 0 Then Reject T, S, D, 2, 18: Exit Function
        ElseIf Code <> S.ProcedureKind Then
            Reject T, S, D, 2, 19: Exit Function
        End If
        If RequireSpace(T, S, D) = False Then Exit Function
        S.Position = S.Position + 1
        Node = NewNode(T, N, S, D, ExitNode, Start)
        If Node = 0 Then Exit Function
        N(Node - 1).Value = Code
    Else
        ExplicitCall = Code = SyntaxTokens.KwCall
        ExplicitLet = Code = SyntaxTokens.KwLet
        If ExplicitCall Or ExplicitLet Then
            S.Position = S.Position + 1
            If RequireSpace(T, S, D) = False Then Exit Function
        End If
        If ExplicitCall = False And AssignmentAhead(B, T, S, ExplicitLet) Then
            Target = ParsePostfix(B, T, N, S, D)
        Else
            Target = ParseName(B, T, N, S, D)
        End If
        If Target = 0 Then Exit Function
        If CodeAt(B, T, S, 0) = SyntaxTokens.SymEqual And ExplicitCall = False Then
            S.Position = S.Position + 1
            Node = NewNode(T, N, S, D, AssignmentNode, Start)
            If Node = 0 Then Exit Function
            AddChild N, Node, Target
            Value = ParseExpression(B, T, N, S, D, 1)
            If Value = 0 Then Exit Function
            AddChild N, Node, Value
        Else
            If ExplicitLet Then Reject T, S, D, 2, 20: Exit Function
            Node = NewNode(T, N, S, D, CallNode, Start)
            If Node = 0 Then Exit Function
            N(Node - 1).Value = 1
            If ExplicitCall Then N(Node - 1).Value = 2
            AddChild N, Node, Target
            If ExplicitCall Then
                If CodeAt(B, T, S, 0) = SyntaxTokens.SymOpen Then
                    If CallArguments(B, T, N, S, D, Node) = False Then Exit Function
                End If
            ElseIf StatementEnd(B, T, S) = False Then
                If RequireSpace(T, S, D) = False Then Exit Function
                Do
                    Value = ParseExpression(B, T, N, S, D, 1)
                    If Value = 0 Then Exit Function
                    AddChild N, Node, Value
                    If CodeAt(B, T, S, 0) <> SyntaxTokens.SymComma Then Exit Do
                    S.Position = S.Position + 1
                Loop
            End If
        End If
    End If
    FinishNode T, N, S, Node
    ParseStatement = Node
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Parses a colon-separated logical line while leaving the nearest inline Else untouched.
Private Function ParseStatementLine(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SyntaxNode, ByRef S As ParserState, ByRef D As ParseDiagnostic, ByVal Parent As Long, ByVal Inline As Boolean) As Boolean
    Dim Node As Long
    On Error GoTo Failed
    Do
        If Inline And CodeAt(B, T, S, 0) = SyntaxTokens.KwDo Then ParseStatementLine = Reject(T, S, D, 2, 21): Exit Function
        Node = ParseStatement(B, T, N, S, D)
        If Node = 0 Then Exit Function
        AddChild N, Parent, Node
        If CodeAt(B, T, S, 0) <> SyntaxTokens.SymColon Then Exit Do
        S.Position = S.Position + 1
        If KindAt(T, S, 0) = SourceScanner.NewlineToken Then Exit Do
    Loop
    If Inline And CodeAt(B, T, S, 0) = SyntaxTokens.KwElse Then ParseStatementLine = True: Exit Function
    If KindAt(T, S, 0) <> SourceScanner.NewlineToken Then ParseStatementLine = Reject(T, S, D, 2, 3): Exit Function
    ParseStatementLine = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Reads a declaration-and-statement body up to its nearest structural terminator.
Private Function ParseBody(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SyntaxNode, ByRef S As ParserState, ByRef D As ParseDiagnostic, ByVal Parent As Long) As Boolean
    Dim Node As Long
    Dim Start As Long
    Dim NameIndex As Long
    Dim Code As Long
    Dim IsLabel As Boolean
    Dim Constant As Boolean
    On Error GoTo Failed
    If EnterSyntax(T, S, D) = False Then Exit Function
    Do
        SkipLines T, S
        Code = CodeAt(B, T, S, 0)
        If KindAt(T, S, 0) = SourceScanner.EndToken Or Code = SyntaxTokens.KwEnd Or Code = SyntaxTokens.KwElse Or Code = SyntaxTokens.KwElseIf Or Code = SyntaxTokens.KwLoop Then Exit Do
        IsLabel = KindAt(T, S, 0) = SourceScanner.NumberToken
        If SyntaxTokens.IsIdentifierToken(B, T, S.Position, S.TokenCount, False) And CodeAt(B, T, S, 1) = SyntaxTokens.SymColon Then IsLabel = True
        If IsLabel Then
            Start = S.Position
            NameIndex = ReadLabel(B, T, S, D)
            If NameIndex < 0 Then Exit Function
            If CodeAt(B, T, S, 0) = SyntaxTokens.SymColon Then S.Position = S.Position + 1
            Node = NewNode(T, N, S, D, LabelNode, Start)
            If Node = 0 Then Exit Function
            N(Node - 1).NameToken = NameIndex
            FinishNode T, N, S, Node
            AddChild N, Parent, Node
            If KindAt(T, S, 0) = SourceScanner.NewlineToken Then GoTo NextLine
        End If
        Code = CodeAt(B, T, S, 0)
        If Code = SyntaxTokens.KwDim Or Code = SyntaxTokens.KwConst Then
            Constant = Code = SyntaxTokens.KwConst
            S.Position = S.Position + 1
            If ParseVariables(B, T, N, S, D, Parent, 0, Constant) = False Then Exit Function
        Else
            If ParseStatementLine(B, T, N, S, D, Parent, False) = False Then Exit Function
        End If
NextLine:
        If EndLine(T, S, D) = False Then Exit Function
    Loop
    S.Depth = S.Depth - 1
    ParseBody = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Retains pre-test, post-test and unconditional Do loops with condition before body in child order.
Private Function ParseDo(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SyntaxNode, ByRef S As ParserState, ByRef D As ParseDiagnostic) As Long
    Dim Start As Long
    Dim Node As Long
    Dim Body As Long
    Dim Condition As Long
    Dim Mode As Long
    Dim Code As Long
    On Error GoTo Failed
    Start = S.Position
    If EnterSyntax(T, S, D) = False Then Exit Function
    S.Position = S.Position + 1
    Node = NewNode(T, N, S, D, DoNode, Start)
    If Node = 0 Then Exit Function
    Code = CodeAt(B, T, S, 0)
    If Code = SyntaxTokens.KwWhile Or Code = SyntaxTokens.KwUntil Then
        If RequireSpace(T, S, D) = False Then Exit Function
        Mode = 1
        If Code = SyntaxTokens.KwUntil Then Mode = 2
        S.Position = S.Position + 1
        If RequireSpace(T, S, D) = False Then Exit Function
        Condition = ParseExpression(B, T, N, S, D, 1)
        If Condition = 0 Then Exit Function
    End If
    If EndLine(T, S, D) = False Then Exit Function
    Body = NewNode(T, N, S, D, BodyNode, S.Position)
    If Body = 0 Then Exit Function
    S.DoDepth = S.DoDepth + 1
    If ParseBody(B, T, N, S, D, Body) = False Then Exit Function
    S.DoDepth = S.DoDepth - 1
    FinishNode T, N, S, Body
    If Expect(B, T, S, D, SyntaxTokens.KwLoop) = False Then Exit Function
    Code = CodeAt(B, T, S, 0)
    If Code = SyntaxTokens.KwWhile Or Code = SyntaxTokens.KwUntil Then
        If Condition <> 0 Then Reject T, S, D, 2, 22: Exit Function
        If RequireSpace(T, S, D) = False Then Exit Function
        Mode = 3
        If Code = SyntaxTokens.KwUntil Then Mode = 4
        S.Position = S.Position + 1
        If RequireSpace(T, S, D) = False Then Exit Function
        Condition = ParseExpression(B, T, N, S, D, 1)
        If Condition = 0 Then Exit Function
    End If
    N(Node - 1).Value = Mode
    If Condition <> 0 Then AddChild N, Node, Condition
    AddChild N, Node, Body
    FinishNode T, N, S, Node
    S.Depth = S.Depth - 1
    ParseDo = Node
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Retains both If forms and nests each ElseIf inside the preceding Else branch.
Private Function ParseIf(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SyntaxNode, ByRef S As ParserState, ByRef D As ParseDiagnostic) As Long
    Dim Start As Long
    Dim Node As Long
    Dim Condition As Long
    Dim Branch As Long
    Dim Nested As Long
    Dim IsElseIf As Boolean
    On Error GoTo Failed
    Start = S.Position
    IsElseIf = CodeAt(B, T, S, 0) = SyntaxTokens.KwElseIf
    S.Position = S.Position + 1
    If EnterSyntax(T, S, D) = False Then Exit Function
    If RequireSpace(T, S, D) = False Then Exit Function
    Node = NewNode(T, N, S, D, IfNode, Start)
    If Node = 0 Then Exit Function
    Condition = ParseExpression(B, T, N, S, D, 1)
    If Condition = 0 Then Exit Function
    AddChild N, Node, Condition
    If RequireSpace(T, S, D) = False Then Exit Function
    If Expect(B, T, S, D, SyntaxTokens.KwThen) = False Then Exit Function
    Branch = NewNode(T, N, S, D, ThenNode, S.Position)
    If Branch = 0 Then Exit Function
    AddChild N, Node, Branch
    If KindAt(T, S, 0) = SourceScanner.NewlineToken Then
        N(Node - 1).Value = 1
        S.Position = S.Position + 1
        If ParseBody(B, T, N, S, D, Branch) = False Then Exit Function
        FinishNode T, N, S, Branch
        If CodeAt(B, T, S, 0) = SyntaxTokens.KwElseIf Then
            Branch = NewNode(T, N, S, D, ElseNode, S.Position)
            If Branch = 0 Then Exit Function
            AddChild N, Node, Branch
            Nested = ParseIf(B, T, N, S, D)
            If Nested = 0 Then Exit Function
            AddChild N, Branch, Nested
            FinishNode T, N, S, Branch
        Else
            If CodeAt(B, T, S, 0) = SyntaxTokens.KwElse Then
                Branch = NewNode(T, N, S, D, ElseNode, S.Position)
                If Branch = 0 Then Exit Function
                AddChild N, Node, Branch
                S.Position = S.Position + 1
                If EndLine(T, S, D) = False Then Exit Function
                If ParseBody(B, T, N, S, D, Branch) = False Then Exit Function
                FinishNode T, N, S, Branch
            End If
            If Expect(B, T, S, D, SyntaxTokens.KwEnd) = False Then Exit Function
            If Expect(B, T, S, D, SyntaxTokens.KwIf) = False Then Exit Function
        End If
    Else
        If IsElseIf Then Reject T, S, D, 2, 23: Exit Function
        N(Node - 1).Value = 2
        If RequireSpace(T, S, D) = False Then Exit Function
        If ParseStatementLine(B, T, N, S, D, Branch, True) = False Then Exit Function
        FinishNode T, N, S, Branch
        If CodeAt(B, T, S, 0) = SyntaxTokens.KwElse Then
            Branch = NewNode(T, N, S, D, ElseNode, S.Position)
            If Branch = 0 Then Exit Function
            AddChild N, Node, Branch
            S.Position = S.Position + 1
            If RequireSpace(T, S, D) = False Then Exit Function
            If ParseStatementLine(B, T, N, S, D, Branch, True) = False Then Exit Function
            FinishNode T, N, S, Branch
        End If
    End If
    FinishNode T, N, S, Node
    S.Depth = S.Depth - 1
    ParseIf = Node
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Retains positional parameters with explicit scalar or qualified record types.
Private Function ParseParameters(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SyntaxNode, ByRef S As ParserState, ByRef D As ParseDiagnostic, ByVal Parent As Long) As Boolean
    Dim Start As Long
    Dim Node As Long
    Dim NameIndex As Long
    Dim Mode As Long
    Dim Suffix As Long
    Dim Shape As Long
    Dim Code As Long
    On Error GoTo Failed
    S.Position = S.Position + 1
    If CodeAt(B, T, S, 0) <> SyntaxTokens.SymClose Then
        Do
            Start = S.Position
            Mode = SyntaxTokens.KwByRef
            Code = CodeAt(B, T, S, 0)
            If Code = SyntaxTokens.KwByVal Or Code = SyntaxTokens.KwByRef Then
                Mode = Code
                S.Position = S.Position + 1
                If RequireSpace(T, S, D) = False Then Exit Function
            End If
            NameIndex = ReadName(B, T, S, D, False)
            If NameIndex < 0 Then Exit Function
            Suffix = ScalarSuffix(B, T, S)
            Node = NewNode(T, N, S, D, ParameterNode, Start)
            If Node = 0 Then Exit Function
            N(Node - 1).NameToken = NameIndex
            N(Node - 1).Modifier = Mode
            If CodeAt(B, T, S, 0) = SyntaxTokens.SymOpen Then
                If Suffix <> 0 Then Reject T, S, D, 2, 15: Exit Function
                Shape = ParseArrayShape(B, T, N, S, D)
                If Shape = 0 Then Exit Function
                If N(Shape - 1).Value <> 2 Then Reject T, S, D, 2, 24: Exit Function
                AddChild N, Node, Shape
            End If
            If ReadType(B, T, N, S, D, Node, Suffix) = False Then Exit Function
            FinishNode T, N, S, Node
            AddChild N, Parent, Node
            If CodeAt(B, T, S, 0) <> SyntaxTokens.SymComma Then Exit Do
            S.Position = S.Position + 1
        Loop
    End If
    ParseParameters = Expect(B, T, S, D, SyntaxTokens.SymClose)
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Retains primitive role and declaration-target token spans without granting intrinsic authority.
Private Function ParsePrimitiveAttribute(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SyntaxNode, ByRef S As ParserState, ByRef D As ParseDiagnostic, ByVal Parent As Long) As Boolean
    Dim Start As Long
    Dim Node As Long
    Dim Target As Long
    On Error GoTo Failed
    Start = S.Position
    S.Position = S.Position + 1
    If RequireSpace(T, S, D) = False Then Exit Function
    Target = ReadName(B, T, S, D, False)
    If Target < 0 Then Exit Function
    If Expect(B, T, S, D, SyntaxTokens.SymDot) = False Then Exit Function
    If SyntaxTokens.DecodedIdentifierCode(B, T, S.Position, S.TokenCount) <> SyntaxTokens.KwUbePrimitive Then ParsePrimitiveAttribute = Reject(T, S, D, 3, 25): Exit Function
    S.Position = S.Position + 1
    If Expect(B, T, S, D, SyntaxTokens.SymEqual) = False Then Exit Function
    If KindAt(T, S, 0) <> SourceScanner.StringToken Then ParsePrimitiveAttribute = Reject(T, S, D, 2, 26): Exit Function
    Node = NewNode(T, N, S, D, PrimitiveNode, Start)
    If Node = 0 Then Exit Function
    N(Node - 1).NameToken = S.Position
    N(Node - 1).TypeFirstToken = Target
    N(Node - 1).TypeLastToken = Target
    S.Position = S.Position + 1
    FinishNode T, N, S, Node
    AddChild N, Parent, Node
    ParsePrimitiveAttribute = EndLine(T, S, D)
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Retains a procedure signature, metadata and body with no spelling-based runtime special cases.
Private Function ParseProcedure(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SyntaxNode, ByRef S As ParserState, ByRef D As ParseDiagnostic, ByVal Parent As Long, ByVal Visibility As Long, ByVal IsIntrinsic As Boolean) As Boolean
    Dim Start As Long
    Dim NameIndex As Long
    Dim Kind As Long
    Dim Suffix As Long
    Dim Node As Long
    Dim Body As Long
    On Error GoTo Failed
    Start = S.Position
    If IsIntrinsic Then Start = Start - 1
    S.ProcedureKind = CodeAt(B, T, S, 0)
    Kind = SubNode
    If S.ProcedureKind = SyntaxTokens.KwFunction Then Kind = FunctionNode
    S.Position = S.Position + 1
    If RequireSpace(T, S, D) = False Then Exit Function
    NameIndex = ReadName(B, T, S, D, False)
    If NameIndex < 0 Then Exit Function
    If Kind = FunctionNode Then Suffix = ScalarSuffix(B, T, S)
    Node = NewNode(T, N, S, D, Kind, Start)
    If Node = 0 Then Exit Function
    N(Node - 1).NameToken = NameIndex
    N(Node - 1).Modifier = Visibility
    N(Node - 1).IsIntrinsic = IsIntrinsic
    If CodeAt(B, T, S, 0) = SyntaxTokens.SymOpen Then
        If ParseParameters(B, T, N, S, D, Node) = False Then Exit Function
    End If
    If Kind = FunctionNode Then
        If ReadType(B, T, N, S, D, Node, Suffix) = False Then Exit Function
    End If
    If EndLine(T, S, D) = False Then Exit Function
    SkipLines T, S
    Do While CodeAt(B, T, S, 0) = SyntaxTokens.KwAttribute
        If ParsePrimitiveAttribute(B, T, N, S, D, Node) = False Then Exit Function
        SkipLines T, S
    Loop
    Body = NewNode(T, N, S, D, BodyNode, S.Position)
    If Body = 0 Then Exit Function
    AddChild N, Node, Body
    If IsIntrinsic Then
        If CodeAt(B, T, S, 0) <> SyntaxTokens.KwEnd Then ParseProcedure = Reject(T, S, D, 2, 27): Exit Function
    Else
        If ParseBody(B, T, N, S, D, Body) = False Then Exit Function
    End If
    FinishNode T, N, S, Body
    If Expect(B, T, S, D, SyntaxTokens.KwEnd) = False Then Exit Function
    If Expect(B, T, S, D, S.ProcedureKind) = False Then Exit Function
    FinishNode T, N, S, Node
    If EndLine(T, S, D) = False Then Exit Function
    AddChild N, Parent, Node
    S.ProcedureKind = 0
    ParseProcedure = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Retains field-only nominal record syntax without fixing layout or resolving type identities.
Private Function ParseRecord(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SyntaxNode, ByRef S As ParserState, ByRef D As ParseDiagnostic, ByVal Parent As Long, ByVal Visibility As Long) As Boolean
    Dim Start As Long
    Dim Node As Long
    Dim Field As Long
    Dim Shape As Long
    Dim FieldCount As Long
    Dim NameIndex As Long
    Dim Suffix As Long
    On Error GoTo Failed
    Start = S.Position
    S.Position = S.Position + 1
    If RequireSpace(T, S, D) = False Then Exit Function
    NameIndex = ReadName(B, T, S, D, False)
    If NameIndex < 0 Then Exit Function
    Node = NewNode(T, N, S, D, TypeNode, Start)
    If Node = 0 Then Exit Function
    N(Node - 1).NameToken = NameIndex
    N(Node - 1).Modifier = Visibility
    If CodeAt(B, T, S, 0) = SyntaxTokens.KwAs Then ParseRecord = Reject(T, S, D, 3, 28): Exit Function
    If EndLine(T, S, D) = False Then Exit Function
    Do
        SkipLines T, S
        If CodeAt(B, T, S, 0) = SyntaxTokens.KwEnd Then Exit Do
        If KindAt(T, S, 0) = SourceScanner.EndToken Then ParseRecord = Reject(T, S, D, 2, 29): Exit Function
        Start = S.Position
        NameIndex = ReadName(B, T, S, D, False)
        If NameIndex < 0 Then Exit Function
        Suffix = ScalarSuffix(B, T, S)
        Field = NewNode(T, N, S, D, FieldNode, Start)
        If Field = 0 Then Exit Function
        N(Field - 1).NameToken = NameIndex
        If CodeAt(B, T, S, 0) = SyntaxTokens.SymOpen Then
            If Suffix <> 0 Then ParseRecord = Reject(T, S, D, 2, 15): Exit Function
            Shape = ParseArrayShape(B, T, N, S, D)
            If Shape = 0 Then Exit Function
            AddChild N, Field, Shape
        End If
        If ReadType(B, T, N, S, D, Field, Suffix) = False Then Exit Function
        If CodeAt(B, T, S, 0) = SyntaxTokens.SymEqual Then ParseRecord = Reject(T, S, D, 2, 30): Exit Function
        FinishNode T, N, S, Field
        AddChild N, Node, Field
        FieldCount = FieldCount + 1
        If EndLine(T, S, D) = False Then Exit Function
    Loop
    If FieldCount = 0 Then ParseRecord = Reject(T, S, D, 2, 31): Exit Function
    S.Position = S.Position + 1
    If Expect(B, T, S, D, SyntaxTokens.KwType) = False Then Exit Function
    FinishNode T, N, S, Node
    If EndLine(T, S, D) = False Then Exit Function
    AddChild N, Parent, Node
    ParseRecord = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Checks the native module envelope and retains its validated quoted identity token.
Private Function ParseEnvelope(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SyntaxNode, ByRef S As ParserState, ByRef D As ParseDiagnostic, ByVal Root As Long) As Boolean
    Dim HeaderLine As Long
    On Error GoTo Failed
    SkipLines T, S
    HeaderLine = T(S.Position).Line
    If Expect(B, T, S, D, SyntaxTokens.KwUbe) = False Then Exit Function
    If RequireSpace(T, S, D) = False Then Exit Function
    If Expect(B, T, S, D, SyntaxTokens.KwSource) = False Then Exit Function
    If RequireSpace(T, S, D) = False Then Exit Function
    If KindAt(T, S, 0) <> SourceScanner.NumberToken Then ParseEnvelope = Reject(T, S, D, 2, 32): Exit Function
    If T(S.Position).ByteLength <> 1 Then ParseEnvelope = Reject(T, S, D, 2, 32): Exit Function
    If B(T(S.Position).ByteStart) <> 49 Then ParseEnvelope = Reject(T, S, D, 2, 32): Exit Function
    S.Position = S.Position + 1
    If RequireSpace(T, S, D) = False Then Exit Function
    If Expect(B, T, S, D, SyntaxTokens.KwModule) = False Then Exit Function
    If T(S.Position - 1).Line <> HeaderLine Then ParseEnvelope = Reject(T, S, D, 2, 32): Exit Function
    If EndLine(T, S, D) = False Then Exit Function
    SkipLines T, S
    HeaderLine = T(S.Position).Line
    If Expect(B, T, S, D, SyntaxTokens.KwAttribute) = False Then Exit Function
    If RequireSpace(T, S, D) = False Then Exit Function
    If Expect(B, T, S, D, SyntaxTokens.KwUbeName) = False Then Exit Function
    If Expect(B, T, S, D, SyntaxTokens.SymEqual) = False Then Exit Function
    If SyntaxTokens.IsModuleNameToken(B, T, S.Position, S.TokenCount) = False Then ParseEnvelope = Reject(T, S, D, 2, 33): Exit Function
    If T(S.Position).Line <> HeaderLine Then ParseEnvelope = Reject(T, S, D, 2, 33): Exit Function
    N(Root - 1).NameToken = S.Position
    S.Position = S.Position + 1
    ParseEnvelope = EndLine(T, S, D)
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Parses module declarations and the single optional initial Option Explicit directive.
Private Function ParseModule(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SyntaxNode, ByRef S As ParserState, ByRef D As ParseDiagnostic) As Boolean
    Dim Root As Long
    Dim Node As Long
    Dim Start As Long
    Dim Visibility As Long
    Dim Code As Long
    Dim Constant As Boolean
    Dim OptionsClosed As Boolean
    Dim ExplicitSeen As Boolean
    On Error GoTo Failed
    Root = NewNode(T, N, S, D, ModuleNode, 0)
    If Root = 0 Then Exit Function
    If ParseEnvelope(B, T, N, S, D, Root) = False Then Exit Function
    Do
        SkipLines T, S
        If KindAt(T, S, 0) = SourceScanner.EndToken Then Exit Do
        Start = S.Position
        Code = CodeAt(B, T, S, 0)
        If Code = SyntaxTokens.KwOption Then
            If OptionsClosed Or ExplicitSeen Then ParseModule = Reject(T, S, D, 2, 34): Exit Function
            S.Position = S.Position + 1
            If Expect(B, T, S, D, SyntaxTokens.KwExplicit) = False Then Exit Function
            If CodeAt(B, T, S, 0) = SyntaxTokens.KwOn Then S.Position = S.Position + 1
            Node = NewNode(T, N, S, D, OptionNode, Start)
            If Node = 0 Then Exit Function
            FinishNode T, N, S, Node
            AddChild N, Root, Node
            ExplicitSeen = True
            If EndLine(T, S, D) = False Then Exit Function
        Else
            OptionsClosed = True
            Visibility = 0
            If Code = SyntaxTokens.KwPublic Or Code = SyntaxTokens.KwPrivate Or Code = SyntaxTokens.KwFriend Or Code = SyntaxTokens.KwGlobal Then
                Visibility = Code
                S.Position = S.Position + 1
                If RequireSpace(T, S, D) = False Then Exit Function
            End If
            Code = CodeAt(B, T, S, 0)
            If Code = SyntaxTokens.KwIntrinsic Then
                S.Position = S.Position + 1
                If RequireSpace(T, S, D) = False Then Exit Function
                Code = CodeAt(B, T, S, 0)
                If Code <> SyntaxTokens.KwSub And Code <> SyntaxTokens.KwFunction Then ParseModule = Reject(T, S, D, 2, 35): Exit Function
                If ParseProcedure(B, T, N, S, D, Root, Visibility, True) = False Then Exit Function
            ElseIf Code = SyntaxTokens.KwSub Or Code = SyntaxTokens.KwFunction Then
                If ParseProcedure(B, T, N, S, D, Root, Visibility, False) = False Then Exit Function
            ElseIf Code = SyntaxTokens.KwType Then
                If ParseRecord(B, T, N, S, D, Root, Visibility) = False Then Exit Function
            Else
                Constant = Code = SyntaxTokens.KwConst
                If Visibility <> 0 And Code = SyntaxTokens.KwDim Then ParseModule = Reject(T, S, D, 2, 36): Exit Function
                If Code = SyntaxTokens.KwDim Or Constant Then
                    S.Position = S.Position + 1
                ElseIf Visibility = 0 Then
                    ParseModule = Reject(T, S, D, 3, 37): Exit Function
                End If
                If ParseVariables(B, T, N, S, D, Root, Visibility, Constant) = False Then Exit Function
                If EndLine(T, S, D) = False Then Exit Function
            End If
        End If
    Loop
    FinishNode T, N, S, Root
    ParseModule = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Validates zero-based caller buffers and bounded monotonic scanner metadata before parsing.
Private Function ValidateTokens(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef S As ParserState, ByRef D As ParseDiagnostic) As Boolean
    Dim Length As Long
    Dim Actual As Long
    Dim Index As Long
    Dim LastEnd As Long
    Dim LastUtf16 As Long
    Dim Probe As Long
    On Error GoTo Failed
    Length = SourceLength(B)
    Actual = TokenLength(T)
    If Length > 1048576 Or S.TokenCount < 2 Or S.TokenCount > 65536 Or S.TokenCount > Actual Then ValidateTokens = Reject(T, S, D, 4, 38): Exit Function
    If Length > 0 Then
        Probe = B(0)
        Probe = B(Length - 1)
    End If
    Probe = T(0).Kind
    Probe = T(Actual - 1).Kind
    Index = 0
    Do While Index < S.TokenCount
        S.Position = Index
        If T(Index).Kind < SourceScanner.WordToken Or T(Index).Kind > SourceScanner.EndToken Then ValidateTokens = Reject(T, S, D, 2, 39): Exit Function
        If T(Index).ByteStart < LastEnd Or T(Index).ByteLength < 0 Or T(Index).ByteStart > Length Then ValidateTokens = Reject(T, S, D, 2, 39): Exit Function
        If T(Index).ByteLength > Length - T(Index).ByteStart Then ValidateTokens = Reject(T, S, D, 2, 39): Exit Function
        If T(Index).Utf16Start < 1 Or T(Index).Utf16Start < LastUtf16 Or T(Index).Utf16Start > Length + 1 Or T(Index).Utf16Length < 0 Then ValidateTokens = Reject(T, S, D, 2, 39): Exit Function
        If T(Index).Utf16Length > Length + 1 - T(Index).Utf16Start Then ValidateTokens = Reject(T, S, D, 2, 39): Exit Function
        If T(Index).Line < 1 Or T(Index).Line > Length + 1 Or T(Index).Column < 1 Or T(Index).Column > Length + 1 Then ValidateTokens = Reject(T, S, D, 2, 39): Exit Function
        If T(Index).Kind = SourceScanner.EndToken And Index <> S.TokenCount - 1 Then ValidateTokens = Reject(T, S, D, 2, 39): Exit Function
        LastEnd = T(Index).ByteStart + T(Index).ByteLength
        LastUtf16 = T(Index).Utf16Start + T(Index).Utf16Length
        Index = Index + 1
    Loop
    If T(S.TokenCount - 1).Kind <> SourceScanner.EndToken Or T(S.TokenCount - 1).ByteStart <> Length Or T(S.TokenCount - 1).ByteLength <> 0 Then ValidateTokens = Reject(T, S, D, 2, 39): Exit Function
    If T(S.TokenCount - 2).Kind <> SourceScanner.NewlineToken Then ValidateTokens = Reject(T, S, D, 2, 39): Exit Function
    S.Position = 0
    ValidateTokens = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Publishes one independent module tree only after complete parsing; prior nodes survive every failure.
Public Function TryParseModule(ByRef Source() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByVal TokenCount As Long, ByRef Nodes() As SyntaxNode, ByRef NodeCount As Long, ByRef RootNode As Long, ByRef Diagnostic As ParseDiagnostic) As Boolean
    Dim Candidate() As SyntaxNode
    Dim State As ParserState
    On Error GoTo StorageFailure
    NodeCount = 0
    RootNode = 0
    Diagnostic.Code = 0
    Diagnostic.Reason = 0
    Diagnostic.TokenIndex = 0
    Diagnostic.ByteOffset = 0
    Diagnostic.Utf16Offset = 1
    Diagnostic.Line = 1
    Diagnostic.Column = 1
    State.TokenCount = TokenCount
    If ValidateTokens(Source, Tokens, State, Diagnostic) = False Then Exit Function
    If ParseModule(Source, Tokens, Candidate, State, Diagnostic) = False Then Exit Function
    Nodes = Candidate
    NodeCount = State.NodeCount
    RootNode = 1
    TryParseModule = True
    Exit Function
StorageFailure:
    NodeCount = 0
    RootNode = 0
    Diagnostic.Code = 5
    Diagnostic.Reason = 6
    Diagnostic.TokenIndex = State.Position
End Function
