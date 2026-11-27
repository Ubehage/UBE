UBE SOURCE 1 MODULE
Attribute UBE_Name = "ManagedSupport"
' Resolves ordinary UBE target-support identities without exposing their source namespace.
Public Type RolePlan
    ConcatSymbol As Long
    CompareBinarySymbol As Long
    FromIntegerSymbol As Long
    FromBooleanSymbol As Long
    ToIntegerSymbol As Long
    ToBooleanSymbol As Long
    FromUtf8Symbol As Long
    CollectSymbol As Long
    FromFloatingSymbol As Long
    ToFloatingSymbol As Long
    PowerSymbol As Long
End Type

' Uses retained syntax, not source text searches or user procedure names.
Public Function NeedsSource(ByRef Bytes() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByRef Nodes() As SourceParser.SyntaxNode, ByRef Counts As ProjectSyntax.ProjectCounts) As Boolean
    Dim Index As Long
    Dim Token As Long
    Do While Index < Counts.NodeCount
        If Nodes(Index).Kind = SourceParser.StringNode Or Nodes(Index).Suffix = SyntaxTokens.KwString Then NeedsSource = True: Exit Function
        If Nodes(Index).Kind = SourceParser.BinaryNode And Nodes(Index).Value = SyntaxTokens.SymAmpersand Then NeedsSource = True: Exit Function
        If Nodes(Index).Kind = SourceParser.BinaryNode And Nodes(Index).Value = SyntaxTokens.SymCaret Then NeedsSource = True: Exit Function
        Token = Nodes(Index).TypeFirstToken
        If Token >= 0 Then
            If SyntaxTokens.TokenCode(Bytes, Tokens, Token, Counts.TokenCount) = SyntaxTokens.KwString Then NeedsSource = True: Exit Function
        End If
        If Nodes(Index).Kind = SourceParser.PrimitiveNode Then
            Token = Nodes(Index).NameToken
            If SyntaxTokens.SpellingByte(Bytes, Tokens, Token, Counts.TokenCount, 0) = 109 And SyntaxTokens.SpellingByte(Bytes, Tokens, Token, Counts.TokenCount, 1) = 101 And SyntaxTokens.SpellingByte(Bytes, Tokens, Token, Counts.TokenCount, 2) = 109 And SyntaxTokens.SpellingByte(Bytes, Tokens, Token, Counts.TokenCount, 3) = 111 And SyntaxTokens.SpellingByte(Bytes, Tokens, Token, Counts.TokenCount, 4) = 114 And SyntaxTokens.SpellingByte(Bytes, Tokens, Token, Counts.TokenCount, 5) = 121 And SyntaxTokens.SpellingByte(Bytes, Tokens, Token, Counts.TokenCount, 6) = 46 And SyntaxTokens.SpellingByte(Bytes, Tokens, Token, Counts.TokenCount, 7) = 99 And SyntaxTokens.SpellingByte(Bytes, Tokens, Token, Counts.TokenCount, 8) = 111 And SyntaxTokens.SpellingByte(Bytes, Tokens, Token, Counts.TokenCount, 9) = 108 And SyntaxTokens.SpellingByte(Bytes, Tokens, Token, Counts.TokenCount, 10) = 108 And SyntaxTokens.SpellingByte(Bytes, Tokens, Token, Counts.TokenCount, 11) = 101 And SyntaxTokens.SpellingByte(Bytes, Tokens, Token, Counts.TokenCount, 12) = 99 And SyntaxTokens.SpellingByte(Bytes, Tokens, Token, Counts.TokenCount, 13) = 116 And SyntaxTokens.SpellingByte(Bytes, Tokens, Token, Counts.TokenCount, 14) = -1 Then NeedsSource = True: Exit Function
            If SyntaxTokens.SpellingByte(Bytes, Tokens, Token, Counts.TokenCount, 0) = 109 And SyntaxTokens.SpellingByte(Bytes, Tokens, Token, Counts.TokenCount, 1) = 97 And SyntaxTokens.SpellingByte(Bytes, Tokens, Token, Counts.TokenCount, 2) = 110 And SyntaxTokens.SpellingByte(Bytes, Tokens, Token, Counts.TokenCount, 3) = 97 And SyntaxTokens.SpellingByte(Bytes, Tokens, Token, Counts.TokenCount, 4) = 103 And SyntaxTokens.SpellingByte(Bytes, Tokens, Token, Counts.TokenCount, 5) = 101 And SyntaxTokens.SpellingByte(Bytes, Tokens, Token, Counts.TokenCount, 6) = 100 And SyntaxTokens.SpellingByte(Bytes, Tokens, Token, Counts.TokenCount, 7) = 46 Then NeedsSource = True: Exit Function
        End If
        Index = Index + 1
    Loop
End Function

Private Intrinsic Function SymbolLength(ByRef Values() As DeclarationBinder.BoundSymbol) As Long
Attribute SymbolLength.UBE_Primitive = "Array.Length"
End Function

Private Function NameByte(ByVal Identity As Long, ByVal Position As Long) As Long
    NameByte = -1
    If Identity = 11 Then
        If Position = 0 Then NameByte = 101: Exit Function
        If Position = 1 Then NameByte = 118: Exit Function
        If Position = 2 Then NameByte = 97: Exit Function
        If Position = 3 Then NameByte = 108: Exit Function
        If Position = 4 Then NameByte = 117: Exit Function
        If Position = 5 Then NameByte = 97: Exit Function
        If Position = 6 Then NameByte = 116: Exit Function
        If Position = 7 Then NameByte = 101: Exit Function
        Exit Function
    End If
    If Identity = 15 Then
        If Position = 0 Then NameByte = 98: Exit Function
        If Position = 1 Then NameByte = 105: Exit Function
        If Position = 2 Then NameByte = 110: Exit Function
        If Position = 3 Then NameByte = 97: Exit Function
        If Position = 4 Then NameByte = 114: Exit Function
        If Position = 5 Then NameByte = 121: Exit Function
        If Position = 6 Then NameByte = 102: Exit Function
        If Position = 7 Then NameByte = 108: Exit Function
        If Position = 8 Then NameByte = 111: Exit Function
        If Position = 9 Then NameByte = 97: Exit Function
        If Position = 10 Then NameByte = 116: Exit Function
        If Position = 11 Then NameByte = 112: Exit Function
        If Position = 12 Then NameByte = 111: Exit Function
        If Position = 13 Then NameByte = 119: Exit Function
        If Position = 14 Then NameByte = 101: Exit Function
        If Position = 15 Then NameByte = 114: Exit Function
        Exit Function
    End If
    If Identity = 1 Then
        If Position = 0 Then NameByte = 99: Exit Function
        If Position = 1 Then NameByte = 111: Exit Function
        If Position = 2 Then NameByte = 110: Exit Function
        If Position = 3 Then NameByte = 99: Exit Function
        If Position = 4 Then NameByte = 97: Exit Function
        If Position = 5 Then NameByte = 116: Exit Function
        Exit Function
    End If
    If Identity = 2 Then
        If Position = 0 Then NameByte = 99: Exit Function
        If Position = 1 Then NameByte = 111: Exit Function
        If Position = 2 Then NameByte = 109: Exit Function
        If Position = 3 Then NameByte = 112: Exit Function
        If Position = 4 Then NameByte = 97: Exit Function
        If Position = 5 Then NameByte = 114: Exit Function
        If Position = 6 Then NameByte = 101: Exit Function
        If Position = 7 Then NameByte = 98: Exit Function
        If Position = 8 Then NameByte = 105: Exit Function
        If Position = 9 Then NameByte = 110: Exit Function
        If Position = 10 Then NameByte = 97: Exit Function
        If Position = 11 Then NameByte = 114: Exit Function
        If Position = 12 Then NameByte = 121: Exit Function
        Exit Function
    End If
    If Identity = 3 Then
        If Position = 0 Then NameByte = 102: Exit Function
        If Position = 1 Then NameByte = 114: Exit Function
        If Position = 2 Then NameByte = 111: Exit Function
        If Position = 3 Then NameByte = 109: Exit Function
        If Position = 4 Then NameByte = 105: Exit Function
        If Position = 5 Then NameByte = 110: Exit Function
        If Position = 6 Then NameByte = 116: Exit Function
        If Position = 7 Then NameByte = 101: Exit Function
        If Position = 8 Then NameByte = 103: Exit Function
        If Position = 9 Then NameByte = 101: Exit Function
        If Position = 10 Then NameByte = 114: Exit Function
        Exit Function
    End If
    If Identity = 4 Then
        If Position = 0 Then NameByte = 102: Exit Function
        If Position = 1 Then NameByte = 114: Exit Function
        If Position = 2 Then NameByte = 111: Exit Function
        If Position = 3 Then NameByte = 109: Exit Function
        If Position = 4 Then NameByte = 98: Exit Function
        If Position = 5 Then NameByte = 111: Exit Function
        If Position = 6 Then NameByte = 111: Exit Function
        If Position = 7 Then NameByte = 108: Exit Function
        If Position = 8 Then NameByte = 101: Exit Function
        If Position = 9 Then NameByte = 97: Exit Function
        If Position = 10 Then NameByte = 110: Exit Function
        Exit Function
    End If
    If Identity = 5 Then
        If Position = 0 Then NameByte = 116: Exit Function
        If Position = 1 Then NameByte = 111: Exit Function
        If Position = 2 Then NameByte = 105: Exit Function
        If Position = 3 Then NameByte = 110: Exit Function
        If Position = 4 Then NameByte = 116: Exit Function
        If Position = 5 Then NameByte = 101: Exit Function
        If Position = 6 Then NameByte = 103: Exit Function
        If Position = 7 Then NameByte = 101: Exit Function
        If Position = 8 Then NameByte = 114: Exit Function
        Exit Function
    End If
    If Identity = 6 Then
        If Position = 0 Then NameByte = 116: Exit Function
        If Position = 1 Then NameByte = 111: Exit Function
        If Position = 2 Then NameByte = 98: Exit Function
        If Position = 3 Then NameByte = 111: Exit Function
        If Position = 4 Then NameByte = 111: Exit Function
        If Position = 5 Then NameByte = 108: Exit Function
        If Position = 6 Then NameByte = 101: Exit Function
        If Position = 7 Then NameByte = 97: Exit Function
        If Position = 8 Then NameByte = 110: Exit Function
        Exit Function
    End If
    If Identity = 7 Then
        If Position = 0 Then NameByte = 102: Exit Function
        If Position = 1 Then NameByte = 114: Exit Function
        If Position = 2 Then NameByte = 111: Exit Function
        If Position = 3 Then NameByte = 109: Exit Function
        If Position = 4 Then NameByte = 117: Exit Function
        If Position = 5 Then NameByte = 116: Exit Function
        If Position = 6 Then NameByte = 102: Exit Function
        If Position = 7 Then NameByte = 56: Exit Function
        Exit Function
    End If
    If Identity = 8 Then
        If Position = 0 Then NameByte = 99: Exit Function
        If Position = 1 Then NameByte = 111: Exit Function
        If Position = 2 Then NameByte = 108: Exit Function
        If Position = 3 Then NameByte = 108: Exit Function
        If Position = 4 Then NameByte = 101: Exit Function
        If Position = 5 Then NameByte = 99: Exit Function
        If Position = 6 Then NameByte = 116: Exit Function
        Exit Function
    End If
    If Identity = 13 Then
        If Position = 0 Then NameByte = 116: Exit Function
        If Position = 1 Then NameByte = 101: Exit Function
        If Position = 2 Then NameByte = 120: Exit Function
        If Position = 3 Then NameByte = 116: Exit Function
        Exit Function
    End If
    If Identity = 14 Then
        If Position = 0 Then NameByte = 109: Exit Function
        If Position = 1 Then NameByte = 97: Exit Function
        If Position = 2 Then NameByte = 110: Exit Function
        If Position = 3 Then NameByte = 97: Exit Function
        If Position = 4 Then NameByte = 103: Exit Function
        If Position = 5 Then NameByte = 101: Exit Function
        If Position = 6 Then NameByte = 100: Exit Function
        If Position = 7 Then NameByte = 109: Exit Function
        If Position = 8 Then NameByte = 101: Exit Function
        If Position = 9 Then NameByte = 109: Exit Function
        If Position = 10 Then NameByte = 111: Exit Function
        If Position = 11 Then NameByte = 114: Exit Function
        If Position = 12 Then NameByte = 121: Exit Function
        Exit Function
    End If
    If Identity = 9 Then
        If Position = 0 Then NameByte = 102: Exit Function
        If Position = 1 Then NameByte = 114: Exit Function
        If Position = 2 Then NameByte = 111: Exit Function
        If Position = 3 Then NameByte = 109: Exit Function
        If Position = 4 Then NameByte = 102: Exit Function
        If Position = 5 Then NameByte = 108: Exit Function
        If Position = 6 Then NameByte = 111: Exit Function
        If Position = 7 Then NameByte = 97: Exit Function
        If Position = 8 Then NameByte = 116: Exit Function
        If Position = 9 Then NameByte = 105: Exit Function
        If Position = 10 Then NameByte = 110: Exit Function
        If Position = 11 Then NameByte = 103: Exit Function
        Exit Function
    End If
    If Identity = 10 Then
        If Position = 0 Then NameByte = 116: Exit Function
        If Position = 1 Then NameByte = 111: Exit Function
        If Position = 2 Then NameByte = 102: Exit Function
        If Position = 3 Then NameByte = 108: Exit Function
        If Position = 4 Then NameByte = 111: Exit Function
        If Position = 5 Then NameByte = 97: Exit Function
        If Position = 6 Then NameByte = 116: Exit Function
        If Position = 7 Then NameByte = 105: Exit Function
        If Position = 8 Then NameByte = 110: Exit Function
        If Position = 9 Then NameByte = 103: Exit Function
        Exit Function
    End If
End Function

Private Function Matches(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByVal Count As Long, ByVal Token As Long, ByVal Identity As Long) As Boolean
    Dim Position As Long
    Dim Expected As Long
    If Token < 0 Or Token >= Count Then Exit Function
    Do
        Expected = NameByte(Identity, Position)
        If SyntaxTokens.SpellingByte(B, T, Token, Count, Position) <> Expected Then Exit Function
        If Expected < 0 Then Matches = True: Exit Function
        Position = Position + 1
    Loop
End Function

Private Function Reject(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Node As Long, ByVal Reason As Long) As Boolean
    Dim Index As Long
    If D.Code <> 0 Then Exit Function
    D.Code = 8
    D.Reason = Reason
    D.ModuleIndex = -1
    D.Node = Node
    D.TokenIndex = -1
    D.Line = 1
    D.Column = 1
    D.ByteOffset = 0
    D.Utf16Offset = 1
    If Node < 1 Or Node > C.NodeCount Then Exit Function
    Do While Index < C.ModuleCount
        If Node > M(Index).NodeBase And Node <= M(Index).NodeBase + M(Index).NodeCount Then
            D.ModuleIndex = Index
            D.TokenIndex = N(Node - 1).FirstToken
            D.ByteOffset = N(Node - 1).ByteStart - M(Index).ByteBase
            D.Utf16Offset = N(Node - 1).Utf16Start
            D.Line = N(Node - 1).Line
            D.Column = N(Node - 1).Column
            Exit Function
        End If
        Index = Index + 1
    Loop
End Function

Private Function ParameterCount(ByVal Role As Long) As Long
    ParameterCount = 1
    If Role = 1 Or Role = 2 Or Role = 9 Or Role = 10 Or Role = 11 Then ParameterCount = 2
    If Role = 5 Or Role = 7 Then ParameterCount = 3
End Function

Private Function ResultType(ByVal Role As Long) As Long
    ResultType = SyntaxTokens.KwString
    If Role = 2 Or Role = 8 Then ResultType = SyntaxTokens.KwLong
    If Role = 5 Or Role = 10 Or Role = 11 Then ResultType = SyntaxTokens.KwLongLong
    If Role = 6 Then ResultType = SyntaxTokens.KwBoolean
End Function

Private Function ParameterType(ByVal Role As Long, ByVal Index As Long) As Long
    ParameterType = SyntaxTokens.KwString
    If Role = 3 Or (Role = 5 And Index > 0) Then ParameterType = SyntaxTokens.KwLongLong
    If Role = 4 Or Role = 8 Then ParameterType = SyntaxTokens.KwBoolean
    If Role = 9 Or Role = 11 Then ParameterType = SyntaxTokens.KwLongLong
    If (Role = 9 Or Role = 10) And Index = 1 Then ParameterType = SyntaxTokens.KwLong
    If Role = 7 Then
        ParameterType = SyntaxTokens.KwLong
        If Index = 0 Then ParameterType = SyntaxTokens.KwByte
    End If
End Function

Private Function ValidSignature(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByVal SymbolCount As Long, ByVal Symbol As Long, ByVal Role As Long) As Boolean
    Dim Parameter As Long
    Dim Index As Long
    Dim Rank As Long
    Dim Passing As Long
    Dim Body As Long
    If A(Symbol - 1).Kind <> SourceParser.FunctionNode Or A(Symbol - 1).Visibility <> SyntaxTokens.KwPublic Then Exit Function
    If A(Symbol - 1).TypeCode <> ResultType(Role) Or A(Symbol - 1).TypeSymbol <> 0 Or A(Symbol - 1).ArrayRank <> 0 Then Exit Function
    If A(Symbol - 1).ParameterCount <> ParameterCount(Role) Then Exit Function
    If N(A(Symbol - 1).DeclarationNode - 1).IsIntrinsic Then Exit Function
    Body = N(A(Symbol - 1).DeclarationNode - 1).LastChild
    If Body < 1 Then Exit Function
    If N(Body - 1).Kind <> SourceParser.BodyNode Or N(Body - 1).FirstChild = 0 Then Exit Function
    Parameter = A(Symbol - 1).FirstParameter
    Do While Index < ParameterCount(Role)
        If Parameter < 1 Or Parameter > SymbolCount Then Exit Function
        If A(Parameter - 1).Kind <> SourceParser.ParameterNode Or A(Parameter - 1).ScopeSymbol <> Symbol Or A(Parameter - 1).LookupDomain <> 1 Then Exit Function
        Rank = 0
        Passing = SyntaxTokens.KwByVal
        If Role = 7 And Index = 0 Then Rank = 1: Passing = SyntaxTokens.KwByRef
        If A(Parameter - 1).ArrayRank <> Rank Or A(Parameter - 1).PassingMode <> Passing Then Exit Function
        If A(Parameter - 1).TypeCode <> ParameterType(Role, Index) Or A(Parameter - 1).TypeSymbol <> 0 Then Exit Function
        Parameter = A(Parameter - 1).NextParameter
        Index = Index + 1
    Loop
    ValidSignature = Parameter = 0
End Function

' Plan changes only after every required role and support initialization boundary succeeds.
Public Function TryResolve(ByRef Bytes() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByRef Nodes() As SourceParser.SyntaxNode, ByRef Modules() As ProjectSyntax.ParsedModule, ByRef Counts As ProjectSyntax.ProjectCounts, ByRef Symbols() As DeclarationBinder.BoundSymbol, ByVal SymbolCount As Long, ByRef Plan As RolePlan, ByRef Diagnostic As DeclarationBinder.BindingDiagnostic) As Boolean
    Dim Candidate As RolePlan
    Dim Found(0 To 10) As Long
    Dim Index As Long
    Dim Node As Long
    Dim ModuleIndex As Long
    Dim ModuleSymbol As Long
    Dim Role As Long
    Dim ModuleName As Long
    Dim Needed As Boolean
    Dim FirstNode As Long
    On Error GoTo Failed
    If Not ProjectSyntax.IsValidProject(Bytes, Tokens, Nodes, Modules, Counts) Then TryResolve = Reject(Nodes, Modules, Counts, Diagnostic, 0, 80): Exit Function
    If SymbolCount < 0 Or SymbolCount > SymbolLength(Symbols) Then TryResolve = Reject(Nodes, Modules, Counts, Diagnostic, 0, 80): Exit Function
    Do While Index < SymbolCount
        Node = Symbols(Index).DeclarationNode
        ModuleIndex = Symbols(Index).ModuleIndex
        If Node < 1 Or Node > Counts.NodeCount Or ModuleIndex < 0 Or ModuleIndex >= Counts.ModuleCount Then TryResolve = Reject(Nodes, Modules, Counts, Diagnostic, 0, 80): Exit Function
        If Symbols(Index).LookupDomain <> Modules(ModuleIndex).LookupDomain Then TryResolve = Reject(Nodes, Modules, Counts, Diagnostic, Node, 80): Exit Function
        If Symbols(Index).TypeCode = SyntaxTokens.KwString Or Symbols(Index).LookupDomain = 1 Then
            Needed = True
            If FirstNode = 0 Then FirstNode = Node
        End If
        If Symbols(Index).LookupDomain = 1 Then
            ModuleSymbol = Symbols(Index).ScopeSymbol
            If ModuleSymbol > 0 And ModuleSymbol <= SymbolCount Then
                If Symbols(ModuleSymbol - 1).Kind = SourceParser.ModuleNode And Symbols(ModuleSymbol - 1).LookupDomain = 1 And Symbols(ModuleSymbol - 1).ModuleIndex = ModuleIndex Then
                    If Symbols(Index).Kind = SourceParser.VariableNode Then
                        If ExpressionBinder.InitializerNode(Nodes, Node) > 0 Then TryResolve = Reject(Nodes, Modules, Counts, Diagnostic, Node, 83): Exit Function
                    End If
                    If Symbols(Index).Kind = SourceParser.FunctionNode Or Symbols(Index).Kind = SourceParser.SubNode Then
                        Role = 1
                        Do While Role <= 11
                            ModuleName = 13
                            If Role = 8 Then ModuleName = 14
                            If Role = 11 Then ModuleName = 15
                            If Matches(Bytes, Tokens, Counts.TokenCount, Symbols(ModuleSymbol - 1).NameToken, ModuleName) Then
                                If Matches(Bytes, Tokens, Counts.TokenCount, Symbols(Index).NameToken, Role) Then
                                    If Found(Role - 1) <> 0 Then TryResolve = Reject(Nodes, Modules, Counts, Diagnostic, Node, 82): Exit Function
                                    If Not ValidSignature(Nodes, Symbols, SymbolCount, Index + 1, Role) Then TryResolve = Reject(Nodes, Modules, Counts, Diagnostic, Node, 82): Exit Function
                                    Found(Role - 1) = Index + 1
                                End If
                            End If
                            Role = Role + 1
                        Loop
                    End If
                End If
            End If
        End If
        Index = Index + 1
    Loop
    Index = 0
    Do While Index < Counts.NodeCount
        If Nodes(Index).Kind = SourceParser.StringNode Then
            Needed = True
            If FirstNode = 0 Then FirstNode = Index + 1
        End If
        Index = Index + 1
    Loop
    If Needed Then
        Role = 0
        Do While Role < 11
            If Found(Role) = 0 Then TryResolve = Reject(Nodes, Modules, Counts, Diagnostic, FirstNode, 81): Exit Function
            Role = Role + 1
        Loop
        Candidate.ConcatSymbol = Found(0)
        Candidate.CompareBinarySymbol = Found(1)
        Candidate.FromIntegerSymbol = Found(2)
        Candidate.FromBooleanSymbol = Found(3)
        Candidate.ToIntegerSymbol = Found(4)
        Candidate.ToBooleanSymbol = Found(5)
        Candidate.FromUtf8Symbol = Found(6)
        Candidate.FromFloatingSymbol = Found(8)
        Candidate.ToFloatingSymbol = Found(9)
        Candidate.PowerSymbol = Found(10)
        Candidate.CollectSymbol = Found(7)
    End If
    Plan = Candidate
    TryResolve = True
    Exit Function
Failed:
    TryResolve = Reject(Nodes, Modules, Counts, Diagnostic, 0, 80)
End Function
