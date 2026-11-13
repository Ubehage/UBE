Attribute VB_Name = "SourceParser"
Option Explicit

' Retained syntax belongs to the caller; no parse state is shared between projects.
Public Const MaximumSyntaxNodes As Long = 65536
Public Const MaximumProjectSyntaxNodes As Long = 131072
Public Const MaximumSyntaxDepth As Long = 64
Public Const MaximumProjectTokens As Long = 262144

Public Type SyntaxNode
    Kind As String
    Text As String
    TypeName As String
    Modifiers As String
    IsIntrinsic As Boolean
    ModuleIndex As Long
    FirstToken As Long
    LastToken As Long
    Parent As Long
    FirstChild As Long
    LastChild As Long
    NextSibling As Long
    Line As Long
    Column As Long
    Offset As Long
    Length As Long
End Type

Public Type ParsedModule
    ModuleName As String
    Tokens As TokenBuffer
    RootNode As Long
End Type

Public Type ParsedProject
    Modules() As ParsedModule
    ModuleCount As Long
    RootNode As Long
    NodeCount As Long
    Nodes() As SyntaxNode
End Type

Private Type ParserState
    NodeBase As Long
    ModuleIndex As Long
    Position As Long
    Depth As Long
    FilePath As String
    ProcedureKind As String
    DoDepth As Long
End Type

' Reads token kinds with a bounded EOF sentinel for lookahead.
Private Function TokenKind(ByRef P As ParsedProject, ByRef S As ParserState, Optional ByVal Ahead As Long = 0) As String
    Dim Index As Long
    Index = S.Position + Ahead
    If Index < 0 Or Index >= P.Modules(S.ModuleIndex).Tokens.Count Then
        TokenKind = "eof"
    Else
        TokenKind = P.Modules(S.ModuleIndex).Tokens.Items(Index).Kind
    End If
End Function

' Compares only ordinary words and symbols, never bracketed identifier contents.
Private Function AtToken(ByRef P As ParsedProject, ByRef S As ParserState, ByVal Text As String, Optional ByVal Ahead As Long = 0) As Boolean
    Dim Kind As String
    Kind = TokenKind(P, S, Ahead)
    If Kind <> "name" And Kind <> "symbol" And Kind <> "number" Then Exit Function
    AtToken = (FoldAscii(P.Modules(S.ModuleIndex).Tokens.Items(S.Position + Ahead).Text) = Text)
End Function

' Produces the first controlled diagnostic at the current source location.
Private Function SyntaxError(ByRef P As ParsedProject, ByRef S As ParserState, ByRef Diagnostic As String, ByVal Detail As String, Optional ByVal Code As String = "E_PARSE") As Boolean
    Dim Index As Long
    Index = S.Position
    If Index >= P.Modules(S.ModuleIndex).Tokens.Count Then Index = P.Modules(S.ModuleIndex).Tokens.Count - 1
    Diagnostic = "UBE: " & Code & ": " & S.FilePath & ":" & CStr(P.Modules(S.ModuleIndex).Tokens.Items(Index).Line) & ":" & CStr(P.Modules(S.ModuleIndex).Tokens.Items(Index).Column) & " " & Detail
End Function

' Consumes one exact word or punctuation token.
Private Function Expect(ByRef P As ParsedProject, ByRef S As ParserState, ByVal Text As String, ByRef Diagnostic As String) As Boolean
    If Not AtToken(P, S, Text) Then
        Expect = SyntaxError(P, S, Diagnostic, "expected " & Text)
        Exit Function
    End If
    S.Position = S.Position + 1
    Expect = True
End Function

' Requires a physical/logical line boundary; colons are statement separators only.
Private Function EndLine(ByRef P As ParsedProject, ByRef S As ParserState, ByRef Diagnostic As String) As Boolean
    If TokenKind(P, S) <> "newline" Then
        EndLine = SyntaxError(P, S, Diagnostic, "expected end of line; unsupported or trailing syntax", "E_UNSUPPORTED")
        Exit Function
    End If
    S.Position = S.Position + 1
    EndLine = True
End Function

' Skips blank and comment-only logical lines.
Private Sub SkipLines(ByRef P As ParsedProject, ByRef S As ParserState)
    Do While TokenKind(P, S) = "newline"
        S.Position = S.Position + 1
    Loop
End Sub

' Checks grammar-required whitespace using physical spans (continuations also leave a gap).
Private Function RequireSpace(ByRef P As ParsedProject, ByRef S As ParserState, ByRef Diagnostic As String) As Boolean
    If S.Position > 0 Then
        If P.Modules(S.ModuleIndex).Tokens.Items(S.Position - 1).Offset + P.Modules(S.ModuleIndex).Tokens.Items(S.Position - 1).Length >= P.Modules(S.ModuleIndex).Tokens.Items(S.Position).Offset Then
            RequireSpace = SyntaxError(P, S, Diagnostic, "whitespace required between these tokens")
            Exit Function
        End If
    End If
    RequireSpace = True
End Function

' Excludes structural keywords from bare identifiers; member names may be keywords.
Private Function IsName(ByRef P As ParsedProject, ByRef S As ParserState) As Boolean
    Dim Word As String
    Dim Reserved As String
    If TokenKind(P, S) = "identifier" Then
        IsName = True
        Exit Function
    End If
    If TokenKind(P, S) <> "name" Then Exit Function
    Word = FoldAscii(P.Modules(S.ModuleIndex).Tokens.Items(S.Position).Text)
    Reserved = "|if|then|else|elseif|end|sub|function|public|private|friend|global|dim|static|const|as|byval|byref|optional|paramarray|option|explicit|goto|gosub|on|error|resume|next|exit|call|let|set|lset|rset|true|false|and|andalso|or|orelse|not|xor|eqv|imp|mod|is|isnot|like|typeof|new|nothing|null|empty|me|"
    Reserved = Reserved & "boolean|byte|integer|long|longlong|single|double|currency|decimal|date|string|object|variant|any|intptr|uintptr|for|each|to|step|do|loop|while|until|wend|with|select|case|return|stop|print|asm|bytecode|declare|lib|alias|type|enum|event|property|interface|implements|raiseevent|redim|erase|load|unload|intrinsic|export|attribute|synclock|callnew|addressof|open|close|get|put|input|line|write|seek|kill|name|filecopy|mkdir|rmdir|chdir|chdrive|lock|unlock|width|randomize|withevents|rem|defbool|defbyte|defcur|defdate|defdbl|defint|deflng|defobj|defsng|defstr|defvar|"
    IsName = (InStr(Reserved, "|" & Word & "|") = 0)
End Function

' Takes a source identifier while retaining its decoded original spelling.
Private Function ReadName(ByRef P As ParsedProject, ByRef S As ParserState, ByRef Name As String, ByRef Diagnostic As String, Optional ByVal Member As Boolean = False) As Boolean
    Dim Previous As String
    If S.Position > 0 And Not Member Then
        Previous = FoldAscii(P.Modules(S.ModuleIndex).Tokens.Items(S.Position - 1).Text)
        If InStr("|sub|function|dim|const|public|private|friend|global|byval|byref|goto|call|let|", "|" & Previous & "|") > 0 Then
            If Not RequireSpace(P, S, Diagnostic) Then Exit Function
        End If
    End If
    If Member Then
        If TokenKind(P, S) <> "name" And TokenKind(P, S) <> "identifier" Then
            ReadName = SyntaxError(P, S, Diagnostic, "expected member name")
            Exit Function
        End If
    ElseIf Not IsName(P, S) Then
        ReadName = SyntaxError(P, S, Diagnostic, "expected identifier; unsupported keyword or construct", "E_UNSUPPORTED")
        Exit Function
    End If
    Name = TokenIdentifier(P.Modules(S.ModuleIndex).Tokens.Items(S.Position))
    S.Position = S.Position + 1
    ReadName = True
End Function

' Allocates a stable one-based node index, bounded over the whole project.
Private Function NewNode(ByRef P As ParsedProject, ByRef S As ParserState, ByVal Kind As String, ByVal Text As String, ByVal Start As Long, ByRef Diagnostic As String) As Long
    Dim Capacity As Long
    Dim Index As Long
    If P.NodeCount >= MaximumProjectSyntaxNodes Or P.NodeCount - S.NodeBase >= MaximumSyntaxNodes Then
        Call SyntaxError(P, S, Diagnostic, "syntax node limit exceeded", "E_LIMIT")
        Exit Function
    End If
    If P.NodeCount = UBound(P.Nodes) Then
        Capacity = UBound(P.Nodes) * 2
        If Capacity > MaximumProjectSyntaxNodes Then Capacity = MaximumProjectSyntaxNodes
        ReDim Preserve P.Nodes(1 To Capacity)
    End If
    P.NodeCount = P.NodeCount + 1
    Index = P.NodeCount
    P.Nodes(Index).Kind = Kind
    P.Nodes(Index).Text = Text
    P.Nodes(Index).ModuleIndex = S.ModuleIndex
    P.Nodes(Index).FirstToken = Start
    P.Nodes(Index).LastToken = Start
    P.Nodes(Index).Line = P.Modules(S.ModuleIndex).Tokens.Items(Start).Line
    P.Nodes(Index).Column = P.Modules(S.ModuleIndex).Tokens.Items(Start).Column
    P.Nodes(Index).Offset = P.Modules(S.ModuleIndex).Tokens.Items(Start).Offset
    NewNode = Index
End Function

' Finishes an inclusive token span without absorbing following separators.
Private Sub FinishNode(ByRef P As ParsedProject, ByRef S As ParserState, ByVal Index As Long)
    Dim Last As Long
    Last = S.Position - 1
    If Last < P.Nodes(Index).FirstToken Then
        P.Nodes(Index).LastToken = P.Nodes(Index).FirstToken - 1
        P.Nodes(Index).Length = 0
        Exit Sub
    End If
    P.Nodes(Index).LastToken = Last
    P.Nodes(Index).Length = P.Modules(S.ModuleIndex).Tokens.Items(Last).Offset + P.Modules(S.ModuleIndex).Tokens.Items(Last).Length - P.Nodes(Index).Offset
End Sub

' Attaches an already-built subtree in source evaluation order.
Private Sub AddChild(ByRef P As ParsedProject, ByVal Parent As Long, ByVal Child As Long)
    P.Nodes(Child).Parent = Parent
    If P.Nodes(Parent).FirstChild = 0 Then
        P.Nodes(Parent).FirstChild = Child
    Else
        P.Nodes(P.Nodes(Parent).LastChild).NextSibling = Child
    End If
    P.Nodes(Parent).LastChild = Child
End Sub

' Bounds recursive expressions and nested statement bodies before descent.
Private Function EnterSyntax(ByRef P As ParsedProject, ByRef S As ParserState, ByRef Diagnostic As String) As Boolean
    If S.Depth >= MaximumSyntaxDepth Then
        EnterSyntax = SyntaxError(P, S, Diagnostic, "syntax nesting limit exceeded", "E_LIMIT")
        Exit Function
    End If
    S.Depth = S.Depth + 1
    EnterSyntax = True
End Function

' Reads an explicit scalar annotation and checks any adjacent identifier type suffix.
Private Function ReadType(ByRef P As ParsedProject, ByRef S As ParserState, ByVal Suffix As String, ByRef TypeName As String, ByRef Diagnostic As String) As Boolean
    Dim Part As String
    If AtToken(P, S, "as") Then
        If Not RequireSpace(P, S, Diagnostic) Then Exit Function
        S.Position = S.Position + 1
        If Not RequireSpace(P, S, Diagnostic) Then Exit Function
        If AtToken(P, S, "long") Then
            TypeName = "Long"
        ElseIf AtToken(P, S, "boolean") Then
            TypeName = "Boolean"
        ElseIf AtToken(P, S, "byte") Then
            TypeName = "Byte"
        ElseIf AtToken(P, S, "integer") Then
            TypeName = "Integer"
        ElseIf AtToken(P, S, "longlong") Then
            TypeName = "LongLong"
        ElseIf IsName(P, S) Then
            If Not ReadName(P, S, TypeName, Diagnostic) Then Exit Function
            If InStr(TypeName, ".") > 0 Then
                ReadType = SyntaxError(P, S, Diagnostic, "dots inside a decoded record type identifier are not admitted", "E_UNSUPPORTED")
                Exit Function
            End If
            If TokenKind(P, S, -1) = "identifier" Then TypeName = P.Modules(S.ModuleIndex).Tokens.Items(S.Position - 1).Text
            Do While AtToken(P, S, ".")
                S.Position = S.Position + 1
                If Not ReadName(P, S, Part, Diagnostic, True) Then Exit Function
                If InStr(Part, ".") > 0 Then
                    ReadType = SyntaxError(P, S, Diagnostic, "dots inside a decoded record type identifier are not admitted", "E_UNSUPPORTED")
                    Exit Function
                End If
                If TokenKind(P, S, -1) = "identifier" Then Part = P.Modules(S.ModuleIndex).Tokens.Items(S.Position - 1).Text
                TypeName = TypeName & "." & Part
            Loop
            S.Position = S.Position - 1
        Else
            ReadType = SyntaxError(P, S, Diagnostic, "only fixed scalar and named record types are admitted", "E_UNSUPPORTED")
            Exit Function
        End If
        S.Position = S.Position + 1
        If Len(Suffix) > 0 And TypeName <> Suffix Then
            ReadType = SyntaxError(P, S, Diagnostic, "identifier suffix conflicts with As type")
            Exit Function
        End If
    ElseIf Len(Suffix) > 0 Then
        TypeName = Suffix
    Else
        ReadType = SyntaxError(P, S, Diagnostic, "explicit scalar type required")
        Exit Function
    End If
    ReadType = True
End Function

' Consumes the supported declaration suffix only when adjacent to its name.
Private Function ScalarSuffix(ByRef P As ParsedProject, ByRef S As ParserState) As String
    Dim SelectedType As String
    If AtToken(P, S, "&") Then
        SelectedType = "Long"
    ElseIf AtToken(P, S, "%") Then
        SelectedType = "Integer"
    ElseIf AtToken(P, S, "^") Then
        SelectedType = "LongLong"
    Else
        Exit Function
    End If
    If S.Position < 1 Then Exit Function
    If P.Modules(S.ModuleIndex).Tokens.Items(S.Position - 1).Offset + P.Modules(S.ModuleIndex).Tokens.Items(S.Position - 1).Length <> P.Modules(S.ModuleIndex).Tokens.Items(S.Position).Offset Then Exit Function
    S.Position = S.Position + 1
    ScalarSuffix = SelectedType
End Function

' Builds a qualified ordinary name; Err members receive no special syntax binding.
Private Function ParseName(ByRef P As ParsedProject, ByRef S As ParserState, ByRef Diagnostic As String) As Long
    Dim Start As Long
    Dim Name As String
    Dim Node As Long
    Dim Member As Long
    Start = S.Position
    If Not ReadName(P, S, Name, Diagnostic) Then Exit Function
    Node = NewNode(P, S, "name", Name, Start, Diagnostic)
    If Node = 0 Then Exit Function
    P.Nodes(Node).TypeName = ScalarSuffix(P, S)
    Call FinishNode(P, S, Node)
    Do While AtToken(P, S, ".")
        S.Position = S.Position + 1
        If Not ReadName(P, S, Name, Diagnostic, True) Then Exit Function
        Member = NewNode(P, S, "member", Name, Start, Diagnostic)
        If Member = 0 Then Exit Function
        P.Nodes(Member).TypeName = ScalarSuffix(P, S)
        Call AddChild(P, Member, Node)
        Node = Member
        Call FinishNode(P, S, Node)
    Loop
    ParseName = Node
End Function

' Reads one-dimensional array shape independently of its element type and initializer.
Private Function ParseArrayShape(ByRef P As ParsedProject, ByRef S As ParserState, ByRef Diagnostic As String) As Long
    Dim Node As Long, First As Long, Lower As Long, Upper As Long, Start As Long
    Start = S.Position
    Node = NewNode(P, S, "array-shape", "fixed", Start, Diagnostic)
    If Node = 0 Then Exit Function
    S.Position = S.Position + 1
    If AtToken(P, S, ",") Then
        Call SyntaxError(P, S, Diagnostic, "only one-dimensional arrays are admitted", "E_UNSUPPORTED")
        Exit Function
    End If
    If AtToken(P, S, ")") Then
        P.Nodes(Node).Text = "dynamic"
    Else
        First = ParseExpression(P, S, 1, Diagnostic)
        If First = 0 Then Exit Function
        If AtToken(P, S, "to") Then
            S.Position = S.Position + 1
            Lower = First
            Upper = ParseExpression(P, S, 1, Diagnostic)
            If Upper = 0 Then Exit Function
        Else
            Upper = First
            Lower = NewNode(P, S, "number", "0", Start, Diagnostic)
            If Lower = 0 Then Exit Function
            ' The omitted lower bound is the admitted default zero, with no source token payload.
            P.Nodes(Lower).Length = 0
        End If
        Call AddChild(P, Node, Lower)
        Call AddChild(P, Node, Upper)
        If AtToken(P, S, ",") Then
            Call SyntaxError(P, S, Diagnostic, "only one-dimensional arrays are admitted", "E_UNSUPPORTED")
            Exit Function
        End If
    End If
    If Not Expect(P, S, ")", Diagnostic) Then Exit Function
    Call FinishNode(P, S, Node)
    ParseArrayShape = Node
End Function

' Parses a positional parenthesized argument list into an existing call node.
Private Function CallArguments(ByRef P As ParsedProject, ByRef S As ParserState, ByVal Node As Long, ByRef Diagnostic As String) As Boolean
    Dim Argument As Long
    If Not Expect(P, S, "(", Diagnostic) Then Exit Function
    If Not AtToken(P, S, ")") Then
        Do
            Argument = ParseExpression(P, S, 1, Diagnostic)
            If Argument = 0 Then Exit Function
            Call AddChild(P, Node, Argument)
            If Not AtToken(P, S, ",") Then Exit Do
            S.Position = S.Position + 1
        Loop
    End If
    If Not Expect(P, S, ")", Diagnostic) Then Exit Function
    CallArguments = True
End Function

' Retains calls and indexed/field postfix syntax for later declaration-based disambiguation.
Private Function ParsePostfix(ByRef P As ParsedProject, ByRef S As ParserState, ByRef Diagnostic As String) As Long
    Dim Node As Long, Child As Long, Start As Long, Name As String
    Start = S.Position
    Node = ParseName(P, S, Diagnostic)
    If Node = 0 Then Exit Function
    Do
        If AtToken(P, S, "(") Then
            Child = Node
            Node = NewNode(P, S, "call", "expression", Start, Diagnostic)
            If Node = 0 Then Exit Function
            Call AddChild(P, Node, Child)
            If Not CallArguments(P, S, Node, Diagnostic) Then Exit Function
        ElseIf AtToken(P, S, ".") Then
            S.Position = S.Position + 1
            If Not ReadName(P, S, Name, Diagnostic, True) Then Exit Function
            Child = Node
            Node = NewNode(P, S, "member", Name, Start, Diagnostic)
            If Node = 0 Then Exit Function
            P.Nodes(Node).TypeName = ScalarSuffix(P, S)
            Call AddChild(P, Node, Child)
        Else
            Exit Do
        End If
        Call FinishNode(P, S, Node)
    Loop
    ParsePostfix = Node
End Function

' Looks only for an equals sign directly after a postfix target, preserving grouped call arguments.
Private Function AssignmentAhead(ByRef P As ParsedProject, ByRef S As ParserState, ByVal ExplicitLet As Boolean) As Boolean
    Dim Ahead As Long, Depth As Long
    If Not IsName(P, S) Then Exit Function
    Ahead = 1
    Do
        If AtToken(P, S, "%", Ahead) Or AtToken(P, S, "&", Ahead) Or AtToken(P, S, "^", Ahead) Then Ahead = Ahead + 1
        If AtToken(P, S, ".", Ahead) Then
            If TokenKind(P, S, Ahead + 1) <> "name" And TokenKind(P, S, Ahead + 1) <> "identifier" Then Exit Function
            Ahead = Ahead + 2
        ElseIf AtToken(P, S, "(", Ahead) Then
            If Not ExplicitLet Then
                With P.Modules(S.ModuleIndex).Tokens
                    If .Items(S.Position + Ahead - 1).Offset + .Items(S.Position + Ahead - 1).Length <> .Items(S.Position + Ahead).Offset Then Exit Function
                End With
            End If
            Depth = 0
            Do
                If TokenKind(P, S, Ahead) = "newline" Or TokenKind(P, S, Ahead) = "eof" Then Exit Function
                If AtToken(P, S, "(", Ahead) Then Depth = Depth + 1
                If AtToken(P, S, ")", Ahead) Then Depth = Depth - 1
                Ahead = Ahead + 1
            Loop While Depth > 0
        Else
            AssignmentAhead = AtToken(P, S, "=", Ahead)
            Exit Function
        End If
    Loop
End Function

' Builds scalar primary/unary expressions and ordinary function invocation.
Private Function ParsePrimary(ByRef P As ParsedProject, ByRef S As ParserState, ByRef Diagnostic As String) As Long
    Dim Start As Long
    Dim Node As Long
    Dim Child As Long
    Dim Text As String
    Dim Kind As String
    Start = S.Position
    Kind = TokenKind(P, S)
    If AtToken(P, S, "+") Or AtToken(P, S, "-") Or AtToken(P, S, "not") Then
        Text = FoldAscii(P.Modules(S.ModuleIndex).Tokens.Items(S.Position).Text)
        S.Position = S.Position + 1
        Node = NewNode(P, S, "unary", Text, Start, Diagnostic)
        If Node = 0 Then Exit Function
        If Text = "not" Then
            If Not RequireSpace(P, S, Diagnostic) Then Exit Function
            Child = ParseExpression(P, S, 3, Diagnostic)
        Else
            Child = ParseExpression(P, S, 6, Diagnostic)
        End If
        If Child = 0 Then Exit Function
        Call AddChild(P, Node, Child)
    ElseIf AtToken(P, S, "(") Then
        S.Position = S.Position + 1
        Node = NewNode(P, S, "group", "", Start, Diagnostic)
        If Node = 0 Then Exit Function
        Child = ParseExpression(P, S, 1, Diagnostic)
        If Child = 0 Then Exit Function
        Call AddChild(P, Node, Child)
        If Not Expect(P, S, ")", Diagnostic) Then Exit Function
    ElseIf Kind = "number" Then
        Text = P.Modules(S.ModuleIndex).Tokens.Items(S.Position).Text
        If Not IntegerLiteral(Text) Then
            Call SyntaxError(P, S, Diagnostic, "only integer literals are admitted", "E_UNSUPPORTED")
            Exit Function
        End If
        S.Position = S.Position + 1
        Node = NewNode(P, S, "number", Text, Start, Diagnostic)
        If Node = 0 Then Exit Function
    ElseIf AtToken(P, S, "true") Or AtToken(P, S, "false") Then
        Text = FoldAscii(P.Modules(S.ModuleIndex).Tokens.Items(S.Position).Text)
        S.Position = S.Position + 1
        Node = NewNode(P, S, "boolean", Text, Start, Diagnostic)
        If Node = 0 Then Exit Function
    ElseIf IsName(P, S) Then
        Node = ParsePostfix(P, S, Diagnostic)
        If Node = 0 Then Exit Function
    Else
        If Kind = "newline" Or Kind = "eof" Or AtToken(P, S, ")") Or AtToken(P, S, ",") Or AtToken(P, S, "then") Or AtToken(P, S, "else") Then
            Call SyntaxError(P, S, Diagnostic, "expected scalar expression")
        Else
            Call SyntaxError(P, S, Diagnostic, "expected scalar expression; unsupported token", "E_UNSUPPORTED")
        End If
        Exit Function
    End If
    Call FinishNode(P, S, Node)
    ParsePrimary = Node
End Function

' Admits integer syntax only; value/range checking belongs to scalar semantic analysis.
Private Function IntegerLiteral(ByVal Text As String) As Boolean
    Dim Index As Long
    Dim Digits As String
    Dim Character As String
    If InStr("%&^", Right$(Text, 1)) > 0 Then Text = Left$(Text, Len(Text) - 1)
    Digits = "0123456789"
    If FoldAscii(Left$(Text, 2)) = "&h" Then
        Digits = "0123456789abcdef"
        Text = Mid$(Text, 3)
    ElseIf FoldAscii(Left$(Text, 2)) = "&o" Then
        Digits = "01234567"
        Text = Mid$(Text, 3)
    End If
    If Len(Text) = 0 Then Exit Function
    For Index = 1 To Len(Text)
        Character = FoldAscii(Mid$(Text, Index, 1))
        If InStr(Digits, Character) = 0 Then Exit Function
    Next Index
    IntegerLiteral = True
End Function

' Returns normative precedence for the admitted eager logical and arithmetic operators.
Private Function OperatorRank(ByRef P As ParsedProject, ByRef S As ParserState) As Long
    If AtToken(P, S, "or") Then
        OperatorRank = 1
    ElseIf AtToken(P, S, "and") Then
        OperatorRank = 2
    ElseIf AtToken(P, S, "=") Or AtToken(P, S, "<>") Or AtToken(P, S, "<") Or AtToken(P, S, ">") Or AtToken(P, S, "<=") Or AtToken(P, S, ">=") Then
        OperatorRank = 4
    ElseIf AtToken(P, S, "+") Or AtToken(P, S, "-") Then
        OperatorRank = 5
    End If
End Function

' Uses bounded precedence climbing, retaining checked operators rather than folding them.
Private Function ParseExpression(ByRef P As ParsedProject, ByRef S As ParserState, ByVal Minimum As Long, ByRef Diagnostic As String) As Long
    Dim LeftNode As Long
    Dim RightNode As Long
    Dim Node As Long
    Dim Rank As Long
    Dim Operator As String
    Dim ComparisonSeen As Boolean
    If Not EnterSyntax(P, S, Diagnostic) Then Exit Function
    If Minimum > 3 And AtToken(P, S, "not") Then
        Call SyntaxError(P, S, Diagnostic, "Not at this precedence requires parentheses")
        Exit Function
    End If
    LeftNode = ParsePrimary(P, S, Diagnostic)
    If LeftNode = 0 Then Exit Function
    Do
        Rank = OperatorRank(P, S)
        If Rank < Minimum Or Rank = 0 Then Exit Do
        If Rank = 4 Then
            If ComparisonSeen Then
                Call SyntaxError(P, S, Diagnostic, "comparison operators cannot be chained")
                Exit Function
            End If
            ComparisonSeen = True
        End If
        Operator = FoldAscii(P.Modules(S.ModuleIndex).Tokens.Items(S.Position).Text)
        If Rank <= 2 Then
            If Not RequireSpace(P, S, Diagnostic) Then Exit Function
        End If
        S.Position = S.Position + 1
        If Rank <= 2 Then
            If Not RequireSpace(P, S, Diagnostic) Then Exit Function
        End If
        RightNode = ParseExpression(P, S, Rank + 1, Diagnostic)
        If RightNode = 0 Then Exit Function
        Node = NewNode(P, S, "binary", Operator, P.Nodes(LeftNode).FirstToken, Diagnostic)
        If Node = 0 Then Exit Function
        Call AddChild(P, Node, LeftNode)
        Call AddChild(P, Node, RightNode)
        Call FinishNode(P, S, Node)
        LeftNode = Node
        If Rank <= 2 Then ComparisonSeen = False
    Loop
    S.Depth = S.Depth - 1
    ParseExpression = LeftNode
End Function

' Identifies a statement boundary without consuming it.
Private Function StatementEnd(ByRef P As ParsedProject, ByRef S As ParserState) As Boolean
    StatementEnd = (TokenKind(P, S) = "newline" Or TokenKind(P, S) = "eof" Or AtToken(P, S, ":") Or AtToken(P, S, "else"))
End Function

' Retains a comma-separated declaration with a separate explicit type per item.
Private Function ParseVariables(ByRef P As ParsedProject, ByRef S As ParserState, ByVal Parent As Long, ByVal Visibility As String, ByVal Constant As Boolean, ByRef Diagnostic As String) As Boolean
    Dim Start As Long
    Dim Node As Long
    Dim Value As Long
    Dim Name As String
    Dim Kind As String
    Dim TypeName As String
    Dim Suffix As String
    Dim Shape As Long
    Kind = "variable"
    If Constant Then Kind = "constant"
    Do
        Start = S.Position
        If Not ReadName(P, S, Name, Diagnostic) Then Exit Function
        Suffix = ScalarSuffix(P, S)
        Shape = 0
        If AtToken(P, S, "(") Then
            If Constant Or Len(Suffix) > 0 Then
                Call SyntaxError(P, S, Diagnostic, "arrays require an As type and cannot be Const")
                Exit Function
            End If
            Shape = ParseArrayShape(P, S, Diagnostic)
            If Shape = 0 Then Exit Function
        End If
        If Not ReadType(P, S, Suffix, TypeName, Diagnostic) Then Exit Function
        Node = NewNode(P, S, Kind, Name, Start, Diagnostic)
        If Node = 0 Then Exit Function
        P.Nodes(Node).TypeName = TypeName
        P.Nodes(Node).Modifiers = Visibility
        If Shape <> 0 Then Call AddChild(P, Node, Shape)
        If AtToken(P, S, "=") Then
            S.Position = S.Position + 1
            Value = ParseExpression(P, S, 1, Diagnostic)
            If Value = 0 Then Exit Function
            Call AddChild(P, Node, Value)
        ElseIf Constant Then
            Call SyntaxError(P, S, Diagnostic, "Const requires an initializer")
            Exit Function
        End If
        Call FinishNode(P, S, Node)
        Call AddChild(P, Parent, Node)
        If Not AtToken(P, S, ",") Then Exit Do
        S.Position = S.Position + 1
    Loop
    ParseVariables = True
End Function

' Reads a named or decimal procedure-local label reference without binding it.
Private Function LabelName(ByRef P As ParsedProject, ByRef S As ParserState, ByRef Name As String, ByRef Diagnostic As String) As Boolean
    Dim Index As Long
    Dim Character As String
    If TokenKind(P, S) <> "number" Then
        LabelName = ReadName(P, S, Name, Diagnostic)
        Exit Function
    End If
    Name = P.Modules(S.ModuleIndex).Tokens.Items(S.Position).Text
    For Index = 1 To Len(Name)
        Character = Mid$(Name, Index, 1)
        If Character < "0" Or Character > "9" Then
            LabelName = SyntaxError(P, S, Diagnostic, "label number must contain decimal digits only")
            Exit Function
        End If
    Next Index
    S.Position = S.Position + 1
    LabelName = True
End Function

' Retains the three admitted handler modes without interpreting Err as success status.
Private Function ParseOnError(ByRef P As ParsedProject, ByRef S As ParserState, ByRef Diagnostic As String) As Long
    Dim Start As Long
    Dim Text As String
    Dim Node As Long
    Start = S.Position
    S.Position = S.Position + 1
    If Not Expect(P, S, "error", Diagnostic) Then Exit Function
    If AtToken(P, S, "resume") Then
        S.Position = S.Position + 1
        If Not Expect(P, S, "next", Diagnostic) Then Exit Function
        Text = "resume-next"
    Else
        If Not Expect(P, S, "goto", Diagnostic) Then Exit Function
        If Not RequireSpace(P, S, Diagnostic) Then Exit Function
        If AtToken(P, S, "0") Then
            S.Position = S.Position + 1
            Text = "default"
        Else
            If Not LabelName(P, S, Text, Diagnostic) Then Exit Function
            Text = "goto:" & Text
        End If
    End If
    Node = NewNode(P, S, "on-error", Text, Start, Diagnostic)
    If Node = 0 Then Exit Function
    Call FinishNode(P, S, Node)
    ParseOnError = Node
End Function

' Parses a single statement into a durable subtree; unsupported forms fail explicitly.
Private Function ParseStatement(ByRef P As ParsedProject, ByRef S As ParserState, ByRef Diagnostic As String) As Long
    Dim Start As Long
    Dim Node As Long
    Dim Target As Long
    Dim Value As Long
    Dim Text As String
    Dim ExplicitCall As Boolean
    Dim ExplicitLet As Boolean
    Start = S.Position
    If AtToken(P, S, "do") Then
        ParseStatement = ParseDo(P, S, Diagnostic)
        Exit Function
    End If
    If AtToken(P, S, "if") Then
        ParseStatement = ParseIf(P, S, Diagnostic)
        Exit Function
    End If
    If AtToken(P, S, "on") Then
        ParseStatement = ParseOnError(P, S, Diagnostic)
        Exit Function
    End If
    If AtToken(P, S, "goto") Then
        S.Position = S.Position + 1
        If Not RequireSpace(P, S, Diagnostic) Then Exit Function
        If Not LabelName(P, S, Text, Diagnostic) Then Exit Function
        Node = NewNode(P, S, "goto", Text, Start, Diagnostic)
    ElseIf AtToken(P, S, "exit") Then
        S.Position = S.Position + 1
        If AtToken(P, S, "do") Then
            If S.DoDepth = 0 Then
                Call SyntaxError(P, S, Diagnostic, "Exit Do requires an enclosing Do loop")
                Exit Function
            End If
            Text = "do"
        ElseIf Not AtToken(P, S, S.ProcedureKind) Then
            Call SyntaxError(P, S, Diagnostic, "Exit must match the containing procedure")
            Exit Function
        Else
            Text = S.ProcedureKind
        End If
        If Not RequireSpace(P, S, Diagnostic) Then Exit Function
        S.Position = S.Position + 1
        Node = NewNode(P, S, "exit", Text, Start, Diagnostic)
    Else
        ExplicitCall = AtToken(P, S, "call")
        ExplicitLet = AtToken(P, S, "let")
        If ExplicitCall Or ExplicitLet Then S.Position = S.Position + 1
        If ExplicitCall Or ExplicitLet Then
            If Not RequireSpace(P, S, Diagnostic) Then Exit Function
        End If
        If Not ExplicitCall And AssignmentAhead(P, S, ExplicitLet) Then
            Target = ParsePostfix(P, S, Diagnostic)
        Else
            Target = ParseName(P, S, Diagnostic)
        End If
        If Target = 0 Then Exit Function
        If AtToken(P, S, "=") And Not ExplicitCall Then
            S.Position = S.Position + 1
            Node = NewNode(P, S, "assignment", "", Start, Diagnostic)
            If Node = 0 Then Exit Function
            Call AddChild(P, Node, Target)
            Value = ParseExpression(P, S, 1, Diagnostic)
            If Value = 0 Then Exit Function
            Call AddChild(P, Node, Value)
        Else
            If ExplicitLet Then
                Call SyntaxError(P, S, Diagnostic, "Let requires an assignment")
                Exit Function
            End If
            Text = "statement"
            If ExplicitCall Then Text = "explicit"
            Node = NewNode(P, S, "call", Text, Start, Diagnostic)
            If Node = 0 Then Exit Function
            Call AddChild(P, Node, Target)
            If ExplicitCall Then
                If AtToken(P, S, "(") Then
                    If Not CallArguments(P, S, Node, Diagnostic) Then Exit Function
                End If
            ElseIf Not StatementEnd(P, S) Then
                If Not RequireSpace(P, S, Diagnostic) Then Exit Function
                Do
                    Value = ParseExpression(P, S, 1, Diagnostic)
                    If Value = 0 Then Exit Function
                    Call AddChild(P, Node, Value)
                    If Not AtToken(P, S, ",") Then Exit Do
                    S.Position = S.Position + 1
                Loop
            End If
        End If
    End If
    If Node = 0 Then Exit Function
    Call FinishNode(P, S, Node)
    ParseStatement = Node
End Function

' Reads one colon-separated statement line, stopping before an inline Else.
Private Function ParseStatementLine(ByRef P As ParsedProject, ByRef S As ParserState, ByVal Parent As Long, ByRef Diagnostic As String, Optional ByVal Inline As Boolean = False) As Boolean
    Dim Node As Long
    Do
        If Inline And AtToken(P, S, "do") Then
            ParseStatementLine = SyntaxError(P, S, Diagnostic, "Do requires a block statement boundary")
            Exit Function
        End If
        Node = ParseStatement(P, S, Diagnostic)
        If Node = 0 Then Exit Function
        Call AddChild(P, Parent, Node)
        If Not AtToken(P, S, ":") Then Exit Do
        S.Position = S.Position + 1
        If TokenKind(P, S) = "newline" Then Exit Do
    Loop
    If Inline And AtToken(P, S, "else") Then
        ParseStatementLine = True
    ElseIf TokenKind(P, S) = "newline" Then
        ParseStatementLine = True
    Else
        ParseStatementLine = SyntaxError(P, S, Diagnostic, "expected statement separator; unsupported or trailing syntax", "E_UNSUPPORTED")
    End If
End Function

' Reads a body until a structural terminator, preserving labels and declaration order.
Private Function ParseBody(ByRef P As ParsedProject, ByRef S As ParserState, ByVal Parent As Long, ByRef Diagnostic As String) As Boolean
    Dim Node As Long
    Dim Start As Long
    Dim Name As String
    Dim Constant As Boolean
    If Not EnterSyntax(P, S, Diagnostic) Then Exit Function
    Do
        Call SkipLines(P, S)
        If TokenKind(P, S) = "eof" Or AtToken(P, S, "end") Or AtToken(P, S, "else") Or AtToken(P, S, "elseif") Or AtToken(P, S, "loop") Then Exit Do
        If (IsName(P, S) And AtToken(P, S, ":", 1)) Or TokenKind(P, S) = "number" Then
            Start = S.Position
            If Not LabelName(P, S, Name, Diagnostic) Then Exit Function
            If AtToken(P, S, ":") Then S.Position = S.Position + 1
            Node = NewNode(P, S, "label", Name, Start, Diagnostic)
            If Node = 0 Then Exit Function
            Call FinishNode(P, S, Node)
            Call AddChild(P, Parent, Node)
            If TokenKind(P, S) = "newline" Then GoTo NextLine
        End If
        If AtToken(P, S, "dim") Or AtToken(P, S, "const") Then
            Constant = AtToken(P, S, "const")
            S.Position = S.Position + 1
            If Not ParseVariables(P, S, Parent, "local", Constant, Diagnostic) Then Exit Function
        Else
            If Not ParseStatementLine(P, S, Parent, Diagnostic) Then Exit Function
        End If
NextLine:
        If Not EndLine(P, S, Diagnostic) Then Exit Function
    Loop
    S.Depth = S.Depth - 1
    ParseBody = True
End Function

' Retains one optional pre/post loop condition and a body; each Exit Do selects its nearest loop.
Private Function ParseDo(ByRef P As ParsedProject, ByRef S As ParserState, ByRef Diagnostic As String) As Long
    Dim Start As Long
    Dim Node As Long
    Dim Body As Long
    Dim Condition As Long
    Dim Mode As String
    Start = S.Position
    If Not EnterSyntax(P, S, Diagnostic) Then Exit Function
    S.Position = S.Position + 1
    Mode = "always"
    Node = NewNode(P, S, "do", Mode, Start, Diagnostic)
    If Node = 0 Then Exit Function
    If AtToken(P, S, "while") Or AtToken(P, S, "until") Then
        If Not RequireSpace(P, S, Diagnostic) Then Exit Function
        Mode = "pre-" & FoldAscii(P.Modules(S.ModuleIndex).Tokens.Items(S.Position).Text)
        S.Position = S.Position + 1
        If Not RequireSpace(P, S, Diagnostic) Then Exit Function
        Condition = ParseExpression(P, S, 1, Diagnostic)
        If Condition = 0 Then Exit Function
    End If
    If Not EndLine(P, S, Diagnostic) Then Exit Function
    Body = NewNode(P, S, "body", "", S.Position, Diagnostic)
    If Body = 0 Then Exit Function
    S.DoDepth = S.DoDepth + 1
    If Not ParseBody(P, S, Body, Diagnostic) Then Exit Function
    S.DoDepth = S.DoDepth - 1
    Call FinishNode(P, S, Body)
    If Not Expect(P, S, "loop", Diagnostic) Then Exit Function
    If AtToken(P, S, "while") Or AtToken(P, S, "until") Then
        If Condition <> 0 Then
            Call SyntaxError(P, S, Diagnostic, "Do cannot have both precondition and postcondition")
            Exit Function
        End If
        If Not RequireSpace(P, S, Diagnostic) Then Exit Function
        Mode = "post-" & FoldAscii(P.Modules(S.ModuleIndex).Tokens.Items(S.Position).Text)
        S.Position = S.Position + 1
        If Not RequireSpace(P, S, Diagnostic) Then Exit Function
        Condition = ParseExpression(P, S, 1, Diagnostic)
        If Condition = 0 Then Exit Function
    End If
    P.Nodes(Node).Text = Mode
    If Condition <> 0 Then Call AddChild(P, Node, Condition)
    Call AddChild(P, Node, Body)
    Call FinishNode(P, S, Node)
    S.Depth = S.Depth - 1
    ParseDo = Node
End Function

' Parses both If forms; ElseIf is retained as an If child of its Else branch.
Private Function ParseIf(ByRef P As ParsedProject, ByRef S As ParserState, ByRef Diagnostic As String) As Long
    Dim Start As Long
    Dim Node As Long
    Dim Condition As Long
    Dim Branch As Long
    Dim Nested As Long
    Dim IsElseIf As Boolean
    Start = S.Position
    IsElseIf = AtToken(P, S, "elseif")
    S.Position = S.Position + 1
    If Not EnterSyntax(P, S, Diagnostic) Then Exit Function
    If Not RequireSpace(P, S, Diagnostic) Then Exit Function
    Node = NewNode(P, S, "if", "", Start, Diagnostic)
    If Node = 0 Then Exit Function
    Condition = ParseExpression(P, S, 1, Diagnostic)
    If Condition = 0 Then Exit Function
    Call AddChild(P, Node, Condition)
    If Not RequireSpace(P, S, Diagnostic) Then Exit Function
    If Not Expect(P, S, "then", Diagnostic) Then Exit Function
    Branch = NewNode(P, S, "then", "", S.Position, Diagnostic)
    If Branch = 0 Then Exit Function
    Call AddChild(P, Node, Branch)
    If TokenKind(P, S) = "newline" Then
        P.Nodes(Node).Text = "block"
        S.Position = S.Position + 1
        If Not ParseBody(P, S, Branch, Diagnostic) Then Exit Function
        Call FinishNode(P, S, Branch)
        If AtToken(P, S, "elseif") Then
            Branch = NewNode(P, S, "else", "", S.Position, Diagnostic)
            If Branch = 0 Then Exit Function
            Call AddChild(P, Node, Branch)
            Nested = ParseIf(P, S, Diagnostic)
            If Nested = 0 Then Exit Function
            Call AddChild(P, Branch, Nested)
            Call FinishNode(P, S, Branch)
        Else
            If AtToken(P, S, "else") Then
                Branch = NewNode(P, S, "else", "", S.Position, Diagnostic)
                If Branch = 0 Then Exit Function
                Call AddChild(P, Node, Branch)
                S.Position = S.Position + 1
                If Not EndLine(P, S, Diagnostic) Then Exit Function
                If Not ParseBody(P, S, Branch, Diagnostic) Then Exit Function
                Call FinishNode(P, S, Branch)
            End If
            If Not Expect(P, S, "end", Diagnostic) Then Exit Function
            If Not Expect(P, S, "if", Diagnostic) Then Exit Function
        End If
    Else
        If IsElseIf Then
            Call SyntaxError(P, S, Diagnostic, "ElseIf requires a block line boundary")
            Exit Function
        End If
        P.Nodes(Node).Text = "inline"
        If Not RequireSpace(P, S, Diagnostic) Then Exit Function
        If Not ParseStatementLine(P, S, Branch, Diagnostic, True) Then Exit Function
        Call FinishNode(P, S, Branch)
        If AtToken(P, S, "else") Then
            Branch = NewNode(P, S, "else", "", S.Position, Diagnostic)
            If Branch = 0 Then Exit Function
            Call AddChild(P, Node, Branch)
            S.Position = S.Position + 1
            If Not RequireSpace(P, S, Diagnostic) Then Exit Function
            If Not ParseStatementLine(P, S, Branch, Diagnostic, True) Then Exit Function
            Call FinishNode(P, S, Branch)
        End If
    End If
    Call FinishNode(P, S, Node)
    S.Depth = S.Depth - 1
    ParseIf = Node
End Function

' Reads typed positional parameters, defaulting omitted passing mode to ByRef.
Private Function ParseParameters(ByRef P As ParsedProject, ByRef S As ParserState, ByVal Parent As Long, ByRef Diagnostic As String) As Boolean
    Dim Start As Long
    Dim Name As String
    Dim Mode As String
    Dim TypeName As String
    Dim Suffix As String
    Dim Node As Long
    Dim Shape As Long
    S.Position = S.Position + 1
    If Not AtToken(P, S, ")") Then
        Do
            Start = S.Position
            Mode = "ByRef"
            If AtToken(P, S, "byval") Then
                Mode = "ByVal"
                S.Position = S.Position + 1
            ElseIf AtToken(P, S, "byref") Then
                S.Position = S.Position + 1
            End If
            If Not ReadName(P, S, Name, Diagnostic) Then Exit Function
            Suffix = ScalarSuffix(P, S)
            Shape = 0
            If AtToken(P, S, "(") Then
                If Len(Suffix) > 0 Then
                    Call SyntaxError(P, S, Diagnostic, "array parameters require an As type")
                    Exit Function
                End If
                Shape = ParseArrayShape(P, S, Diagnostic)
                If Shape = 0 Then Exit Function
                If P.Nodes(Shape).Text <> "dynamic" Then
                    Call SyntaxError(P, S, Diagnostic, "array parameters declare rank only")
                    Exit Function
                End If
            End If
            If Not ReadType(P, S, Suffix, TypeName, Diagnostic) Then Exit Function
            Node = NewNode(P, S, "parameter", Name, Start, Diagnostic)
            If Node = 0 Then Exit Function
            P.Nodes(Node).TypeName = TypeName
            P.Nodes(Node).Modifiers = Mode
            If Shape <> 0 Then Call AddChild(P, Node, Shape)
            Call FinishNode(P, S, Node)
            Call AddChild(P, Parent, Node)
            If Not AtToken(P, S, ",") Then Exit Do
            S.Position = S.Position + 1
        Loop
    End If
    ParseParameters = Expect(P, S, ")", Diagnostic)
End Function

' Retains explicit primitive metadata for declaration-identity validation by binding.
Private Function ParsePrimitiveAttribute(ByRef P As ParsedProject, ByRef S As ParserState, ByVal Parent As Long, ByRef Diagnostic As String) As Boolean
    Dim Start As Long, Node As Long
    Dim Target As String, AttributeName As String, Role As String
    Start = S.Position
    S.Position = S.Position + 1
    If Not RequireSpace(P, S, Diagnostic) Then Exit Function
    If Not ReadName(P, S, Target, Diagnostic) Then Exit Function
    If Not Expect(P, S, ".", Diagnostic) Then Exit Function
    If Not ReadName(P, S, AttributeName, Diagnostic, True) Then Exit Function
    If FoldAscii(AttributeName) <> "ube_primitive" Then
        ParsePrimitiveAttribute = SyntaxError(P, S, Diagnostic, "only UBE_Primitive procedure metadata is admitted", "E_UNSUPPORTED")
        Exit Function
    End If
    If Not Expect(P, S, "=", Diagnostic) Then Exit Function
    If TokenKind(P, S) <> "string" Then
        ParsePrimitiveAttribute = SyntaxError(P, S, Diagnostic, "UBE_Primitive requires one role string")
        Exit Function
    End If
    Role = P.Modules(S.ModuleIndex).Tokens.Items(S.Position).Text
    Role = Replace(Mid$(Role, 2, Len(Role) - 2), Chr$(34) & Chr$(34), Chr$(34))
    S.Position = S.Position + 1
    Node = NewNode(P, S, "primitive", Role, Start, Diagnostic)
    If Node = 0 Then Exit Function
    P.Nodes(Node).TypeName = Target
    Call FinishNode(P, S, Node)
    Call AddChild(P, Parent, Node)
    ParsePrimitiveAttribute = EndLine(P, S, Diagnostic)
End Function

' Retains procedure signature, explicit metadata and body without inferring intrinsic roles from names.
Private Function ParseProcedure(ByRef P As ParsedProject, ByRef S As ParserState, ByVal Parent As Long, ByVal Visibility As String, ByRef Diagnostic As String, Optional ByVal IsIntrinsic As Boolean = False) As Boolean
    Dim Start As Long
    Dim Name As String
    Dim Kind As String
    Dim TypeName As String
    Dim Suffix As String
    Dim Node As Long
    Dim Body As Long
    Start = S.Position
    If IsIntrinsic Then Start = Start - 1
    Kind = FoldAscii(P.Modules(S.ModuleIndex).Tokens.Items(S.Position).Text)
    S.ProcedureKind = Kind
    S.Position = S.Position + 1
    If Not RequireSpace(P, S, Diagnostic) Then Exit Function
    If Not ReadName(P, S, Name, Diagnostic) Then Exit Function
    If Kind = "function" Then Suffix = ScalarSuffix(P, S)
    Node = NewNode(P, S, Kind, Name, Start, Diagnostic)
    If Node = 0 Then Exit Function
    P.Nodes(Node).Modifiers = Visibility
    P.Nodes(Node).IsIntrinsic = IsIntrinsic
    If AtToken(P, S, "(") Then
        If Not ParseParameters(P, S, Node, Diagnostic) Then Exit Function
    End If
    If Kind = "function" Then
        If Not ReadType(P, S, Suffix, TypeName, Diagnostic) Then Exit Function
        P.Nodes(Node).TypeName = TypeName
    End If
    If Not EndLine(P, S, Diagnostic) Then Exit Function
    Call SkipLines(P, S)
    Do While AtToken(P, S, "attribute")
        If Not ParsePrimitiveAttribute(P, S, Node, Diagnostic) Then Exit Function
        Call SkipLines(P, S)
    Loop
    Body = NewNode(P, S, "body", "", S.Position, Diagnostic)
    If Body = 0 Then Exit Function
    Call AddChild(P, Node, Body)
    If IsIntrinsic Then
        If Not AtToken(P, S, "end") Then
            ParseProcedure = SyntaxError(P, S, Diagnostic, "Intrinsic declarations cannot contain an executable body")
            Exit Function
        End If
    Else
        If Not ParseBody(P, S, Body, Diagnostic) Then Exit Function
    End If
    Call FinishNode(P, S, Body)
    If Not Expect(P, S, "end", Diagnostic) Then Exit Function
    If Not Expect(P, S, Kind, Diagnostic) Then Exit Function
    Call FinishNode(P, S, Node)
    If Not EndLine(P, S, Diagnostic) Then Exit Function
    Call AddChild(P, Parent, Node)
    S.ProcedureKind = ""
    ParseProcedure = True
End Function

' Retains nominal field-only record declarations without choosing their native layout.
Private Function ParseRecord(ByRef P As ParsedProject, ByRef S As ParserState, ByVal Parent As Long, ByVal Visibility As String, ByRef Diagnostic As String) As Boolean
    Dim Start As Long, Node As Long, Field As Long, Shape As Long, FieldCount As Long
    Dim Name As String, TypeName As String, Suffix As String
    Start = S.Position
    S.Position = S.Position + 1
    If Not RequireSpace(P, S, Diagnostic) Then Exit Function
    If Not ReadName(P, S, Name, Diagnostic) Then Exit Function
    Node = NewNode(P, S, "type", Name, Start, Diagnostic)
    If Node = 0 Then Exit Function
    P.Nodes(Node).Modifiers = Visibility
    If AtToken(P, S, "as") Then
        ParseRecord = SyntaxError(P, S, Diagnostic, "opaque native representations are outside the record profile", "E_UNSUPPORTED")
        Exit Function
    End If
    If Not EndLine(P, S, Diagnostic) Then Exit Function
    Do
        Call SkipLines(P, S)
        If AtToken(P, S, "end") Then Exit Do
        If TokenKind(P, S) = "eof" Then
            ParseRecord = SyntaxError(P, S, Diagnostic, "expected End Type")
            Exit Function
        End If
        Start = S.Position
        If Not ReadName(P, S, Name, Diagnostic) Then Exit Function
        Suffix = ScalarSuffix(P, S)
        Shape = 0
        If AtToken(P, S, "(") Then
            If Len(Suffix) > 0 Then
                ParseRecord = SyntaxError(P, S, Diagnostic, "array fields require an As type")
                Exit Function
            End If
            Shape = ParseArrayShape(P, S, Diagnostic)
            If Shape = 0 Then Exit Function
        End If
        If Not ReadType(P, S, Suffix, TypeName, Diagnostic) Then Exit Function
        Field = NewNode(P, S, "field", Name, Start, Diagnostic)
        If Field = 0 Then Exit Function
        P.Nodes(Field).TypeName = TypeName
        If Shape <> 0 Then Call AddChild(P, Field, Shape)
        If AtToken(P, S, "=") Then
            ParseRecord = SyntaxError(P, S, Diagnostic, "record fields cannot have initializers")
            Exit Function
        End If
        Call FinishNode(P, S, Field)
        Call AddChild(P, Node, Field)
        FieldCount = FieldCount + 1
        If Not EndLine(P, S, Diagnostic) Then Exit Function
    Loop
    If FieldCount = 0 Then
        ParseRecord = SyntaxError(P, S, Diagnostic, "record requires at least one field")
        Exit Function
    End If
    S.Position = S.Position + 1
    If Not Expect(P, S, "type", Diagnostic) Then Exit Function
    Call FinishNode(P, S, Node)
    If Not EndLine(P, S, Diagnostic) Then Exit Function
    Call AddChild(P, Parent, Node)
    ParseRecord = True
End Function

' Consumes the mandatory native envelope and checks its identity against the loader.
Private Function ParseEnvelope(ByRef P As ParsedProject, ByRef S As ParserState, ByRef Diagnostic As String) As Boolean
    Dim Text As String
    Call SkipLines(P, S)
    If Not Expect(P, S, "ube", Diagnostic) Then Exit Function
    If Not Expect(P, S, "source", Diagnostic) Then Exit Function
    If Not Expect(P, S, "1", Diagnostic) Then Exit Function
    If Not Expect(P, S, "module", Diagnostic) Then Exit Function
    If Not EndLine(P, S, Diagnostic) Then Exit Function
    Call SkipLines(P, S)
    If Not Expect(P, S, "attribute", Diagnostic) Then Exit Function
    If Not Expect(P, S, "ube_name", Diagnostic) Then Exit Function
    If Not Expect(P, S, "=", Diagnostic) Then Exit Function
    If TokenKind(P, S) <> "string" Then
        ParseEnvelope = SyntaxError(P, S, Diagnostic, "expected native module identity string")
        Exit Function
    End If
    Text = P.Modules(S.ModuleIndex).Tokens.Items(S.Position).Text
    Text = Replace(Mid$(Text, 2, Len(Text) - 2), Chr$(34) & Chr$(34), Chr$(34))
    If Text <> P.Modules(S.ModuleIndex).ModuleName Then
        ParseEnvelope = SyntaxError(P, S, Diagnostic, "native module identity differs from loaded module")
        Exit Function
    End If
    S.Position = S.Position + 1
    ParseEnvelope = EndLine(P, S, Diagnostic)
End Function

' Parses module declarations in source order with Option Explicit before declarations.
Private Function ParseModule(ByRef P As ParsedProject, ByRef S As ParserState, ByRef Diagnostic As String) As Boolean
    Dim Root As Long
    Dim Node As Long
    Dim Start As Long
    Dim Visibility As String
    Dim Constant As Boolean
    Dim OptionsClosed As Boolean
    Dim ExplicitSeen As Boolean
    Root = NewNode(P, S, "module", P.Modules(S.ModuleIndex).ModuleName, 0, Diagnostic)
    If Root = 0 Then Exit Function
    P.Modules(S.ModuleIndex).RootNode = Root
    Call AddChild(P, P.RootNode, Root)
    If Not ParseEnvelope(P, S, Diagnostic) Then Exit Function
    Do
        Call SkipLines(P, S)
        If TokenKind(P, S) = "eof" Then Exit Do
        Start = S.Position
        If AtToken(P, S, "option") Then
            If OptionsClosed Or ExplicitSeen Then
                Call SyntaxError(P, S, Diagnostic, "Option Explicit must occur once before declarations")
                Exit Function
            End If
            S.Position = S.Position + 1
            If Not Expect(P, S, "explicit", Diagnostic) Then Exit Function
            If AtToken(P, S, "off") Then
                Call SyntaxError(P, S, Diagnostic, "strict typing cannot be disabled", "E_UNSUPPORTED")
                Exit Function
            End If
            If AtToken(P, S, "on") Then S.Position = S.Position + 1
            Node = NewNode(P, S, "option", "Explicit", Start, Diagnostic)
            If Node = 0 Then Exit Function
            Call FinishNode(P, S, Node)
            Call AddChild(P, Root, Node)
            ExplicitSeen = True
            If Not EndLine(P, S, Diagnostic) Then Exit Function
        Else
            OptionsClosed = True
            Visibility = ""
            If AtToken(P, S, "public") Or AtToken(P, S, "private") Or AtToken(P, S, "friend") Or AtToken(P, S, "global") Then
                Visibility = FoldAscii(P.Modules(S.ModuleIndex).Tokens.Items(S.Position).Text)
                S.Position = S.Position + 1
            End If
            If AtToken(P, S, "intrinsic") Then
                If Len(Visibility) > 0 Then
                    If Not RequireSpace(P, S, Diagnostic) Then Exit Function
                End If
                S.Position = S.Position + 1
                If Not RequireSpace(P, S, Diagnostic) Then Exit Function
                If Not AtToken(P, S, "sub") And Not AtToken(P, S, "function") Then
                    ParseModule = SyntaxError(P, S, Diagnostic, "Intrinsic requires a Sub or Function declaration")
                    Exit Function
                End If
                If Not ParseProcedure(P, S, Root, Visibility, Diagnostic, True) Then Exit Function
            ElseIf AtToken(P, S, "sub") Or AtToken(P, S, "function") Then
                If Not ParseProcedure(P, S, Root, Visibility, Diagnostic) Then Exit Function
            ElseIf AtToken(P, S, "type") Then
                If Not ParseRecord(P, S, Root, Visibility, Diagnostic) Then Exit Function
            Else
                Constant = AtToken(P, S, "const")
                If Len(Visibility) > 0 And AtToken(P, S, "dim") Then
                    Call SyntaxError(P, S, Diagnostic, "Dim cannot be combined with a visibility modifier")
                    Exit Function
                End If
                If AtToken(P, S, "dim") Or Constant Then
                    S.Position = S.Position + 1
                ElseIf Len(Visibility) = 0 Then
                    Call SyntaxError(P, S, Diagnostic, "expected typed module declaration or procedure", "E_UNSUPPORTED")
                    Exit Function
                End If
                If Not ParseVariables(P, S, Root, Visibility, Constant, Diagnostic) Then Exit Function
                If Not EndLine(P, S, Diagnostic) Then Exit Function
            End If
        End If
    Loop
    Call FinishNode(P, S, Root)
    ParseModule = True
End Function

' Tokenizes and parses all retained sources, publishing success only after every module.
Public Function ParseProject(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Diagnostic As String) As Boolean
    Dim S As ParserState
    Dim Index As Long
    Dim TotalTokens As Long
    Dim TokenAllowance As Long
    On Error GoTo Failed
    Diagnostic = ""
    Parsed.NodeCount = 0
    Parsed.ModuleCount = 0
    Parsed.RootNode = 0
    Erase Parsed.Modules
    Erase Parsed.Nodes
    If Project.SourceCount < 1 Or Project.SourceCount > MaximumSources Then
        ParseProject = Reject(Diagnostic, "E_PARSE", "project has no admitted source modules")
        Exit Function
    End If
    ReDim Parsed.Modules(0 To Project.SourceCount - 1)
    ReDim Parsed.Nodes(1 To 1024)
    Parsed.NodeCount = 1
    Parsed.RootNode = 1
    Parsed.Nodes(1).Kind = "project"
    Parsed.Nodes(1).Text = Project.ProjectName
    Parsed.Nodes(1).ModuleIndex = -1
    For Index = 0 To Project.SourceCount - 1
        Parsed.Modules(Index).ModuleName = Project.Sources(Index).ModuleName
        TokenAllowance = MaximumProjectTokens - TotalTokens
        If TokenAllowance > MaximumSourceTokens Then TokenAllowance = MaximumSourceTokens
        If Not LexSource(Project.Sources(Index), Parsed.Modules(Index).Tokens, Diagnostic, TokenAllowance) Then GoTo Rejected
        TotalTokens = TotalTokens + Parsed.Modules(Index).Tokens.Count
        S.ModuleIndex = Index
        S.NodeBase = Parsed.NodeCount
        S.Position = 0
        S.Depth = 0
        S.ProcedureKind = ""
        S.FilePath = Project.Sources(Index).FilePath
        If Not ParseModule(Parsed, S, Diagnostic) Then GoTo Rejected
    Next Index
    Parsed.ModuleCount = Project.SourceCount
    ReDim Preserve Parsed.Nodes(1 To Parsed.NodeCount)
    ParseProject = True
    Exit Function
Failed:
    On Error Resume Next
    Diagnostic = "UBE: E_INTERNAL: unable to retain bounded source syntax"
Rejected:
    Parsed.RootNode = 0
    Parsed.NodeCount = 0
    Parsed.ModuleCount = 0
    Erase Parsed.Modules
    Erase Parsed.Nodes
End Function

' Escapes only dump framing characters, leaving source spelling deterministic.
Private Function DumpText(ByVal Text As String) As String
    Text = Replace(Text, "\", "\\")
    Text = Replace(Text, "|", "\p")
    Text = Replace(Text, vbCr, "\r")
    Text = Replace(Text, vbLf, "\n")
    DumpText = Text
End Function

' Formats a stable node record for structural acceptance tests and inspection tools.
Public Function FormatNode(ByRef Parsed As ParsedProject, ByVal Index As Long) As String
    If Index < 1 Or Index > Parsed.NodeCount Then Exit Function
    With Parsed.Nodes(Index)
        FormatNode = "NODE " & CStr(Index) & "|" & .Kind & "|" & DumpText(.Text) & "|" & CStr(.ModuleIndex) & "|" & CStr(.Line) & "|" & CStr(.Column) & "|" & CStr(.FirstChild) & "|" & CStr(.NextSibling) & "|" & CStr(.Parent) & "|" & DumpText(.TypeName) & "|" & .Modifiers & "|" & CStr(.Offset) & "|" & CStr(.Length)
    End With
End Function
