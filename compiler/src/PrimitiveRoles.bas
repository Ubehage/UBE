UBE SOURCE 1 MODULE
Attribute UBE_Name = "PrimitiveRoles"
' Grants primitive identities only to validated attributed declarations in caller-owned syntax.
Public Const ArrayLength As Long = 1
Public Const MemoryCopyBytes As Long = 2
Public Const ArrayTryResize As Long = 3
Public Const ArrayTryCopy As Long = 4
Public Const FileTryOpen As Long = 5
Public Const FileTryCreateNew As Long = 6
Public Const FileTryRead As Long = 7
Public Const FileTryWrite As Long = 8
Public Const FileTryClose As Long = 9
Public Const FileTryFlush As Long = 10
Public Const ErrorSet As Long = 11

' Allocates a private zero-filled role map before atomic publication.
Private Intrinsic Function ResizeRoles(ByRef Values() As Long, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeRoles.UBE_Primitive = "Array.TryResize"
End Function

' Supplies the reviewed ASCII spelling table; source text is decoded only by SyntaxTokens.
Private Function RoleCharacter(ByVal Role As Long, ByVal Position As Long) As Long
    RoleCharacter = -1
    If Role = 1 Then
        If Position = 0 Then RoleCharacter = 97: Exit Function
        If Position = 1 Then RoleCharacter = 114: Exit Function
        If Position = 2 Then RoleCharacter = 114: Exit Function
        If Position = 3 Then RoleCharacter = 97: Exit Function
        If Position = 4 Then RoleCharacter = 121: Exit Function
        If Position = 5 Then RoleCharacter = 46: Exit Function
        If Position = 6 Then RoleCharacter = 108: Exit Function
        If Position = 7 Then RoleCharacter = 101: Exit Function
        If Position = 8 Then RoleCharacter = 110: Exit Function
        If Position = 9 Then RoleCharacter = 103: Exit Function
        If Position = 10 Then RoleCharacter = 116: Exit Function
        If Position = 11 Then RoleCharacter = 104: Exit Function
        Exit Function
    End If
    If Role = 2 Then
        If Position = 0 Then RoleCharacter = 109: Exit Function
        If Position = 1 Then RoleCharacter = 101: Exit Function
        If Position = 2 Then RoleCharacter = 109: Exit Function
        If Position = 3 Then RoleCharacter = 111: Exit Function
        If Position = 4 Then RoleCharacter = 114: Exit Function
        If Position = 5 Then RoleCharacter = 121: Exit Function
        If Position = 6 Then RoleCharacter = 46: Exit Function
        If Position = 7 Then RoleCharacter = 99: Exit Function
        If Position = 8 Then RoleCharacter = 111: Exit Function
        If Position = 9 Then RoleCharacter = 112: Exit Function
        If Position = 10 Then RoleCharacter = 121: Exit Function
        If Position = 11 Then RoleCharacter = 98: Exit Function
        If Position = 12 Then RoleCharacter = 121: Exit Function
        If Position = 13 Then RoleCharacter = 116: Exit Function
        If Position = 14 Then RoleCharacter = 101: Exit Function
        If Position = 15 Then RoleCharacter = 115: Exit Function
        Exit Function
    End If
    If Role = 3 Then
        If Position = 0 Then RoleCharacter = 97: Exit Function
        If Position = 1 Then RoleCharacter = 114: Exit Function
        If Position = 2 Then RoleCharacter = 114: Exit Function
        If Position = 3 Then RoleCharacter = 97: Exit Function
        If Position = 4 Then RoleCharacter = 121: Exit Function
        If Position = 5 Then RoleCharacter = 46: Exit Function
        If Position = 6 Then RoleCharacter = 116: Exit Function
        If Position = 7 Then RoleCharacter = 114: Exit Function
        If Position = 8 Then RoleCharacter = 121: Exit Function
        If Position = 9 Then RoleCharacter = 114: Exit Function
        If Position = 10 Then RoleCharacter = 101: Exit Function
        If Position = 11 Then RoleCharacter = 115: Exit Function
        If Position = 12 Then RoleCharacter = 105: Exit Function
        If Position = 13 Then RoleCharacter = 122: Exit Function
        If Position = 14 Then RoleCharacter = 101: Exit Function
        Exit Function
    End If
    If Role = 4 Then
        If Position = 0 Then RoleCharacter = 97: Exit Function
        If Position = 1 Then RoleCharacter = 114: Exit Function
        If Position = 2 Then RoleCharacter = 114: Exit Function
        If Position = 3 Then RoleCharacter = 97: Exit Function
        If Position = 4 Then RoleCharacter = 121: Exit Function
        If Position = 5 Then RoleCharacter = 46: Exit Function
        If Position = 6 Then RoleCharacter = 116: Exit Function
        If Position = 7 Then RoleCharacter = 114: Exit Function
        If Position = 8 Then RoleCharacter = 121: Exit Function
        If Position = 9 Then RoleCharacter = 99: Exit Function
        If Position = 10 Then RoleCharacter = 111: Exit Function
        If Position = 11 Then RoleCharacter = 112: Exit Function
        If Position = 12 Then RoleCharacter = 121: Exit Function
        Exit Function
    End If
    If Role = 5 Then
        If Position = 0 Then RoleCharacter = 102: Exit Function
        If Position = 1 Then RoleCharacter = 105: Exit Function
        If Position = 2 Then RoleCharacter = 108: Exit Function
        If Position = 3 Then RoleCharacter = 101: Exit Function
        If Position = 4 Then RoleCharacter = 46: Exit Function
        If Position = 5 Then RoleCharacter = 116: Exit Function
        If Position = 6 Then RoleCharacter = 114: Exit Function
        If Position = 7 Then RoleCharacter = 121: Exit Function
        If Position = 8 Then RoleCharacter = 111: Exit Function
        If Position = 9 Then RoleCharacter = 112: Exit Function
        If Position = 10 Then RoleCharacter = 101: Exit Function
        If Position = 11 Then RoleCharacter = 110: Exit Function
        Exit Function
    End If
    If Role = 6 Then
        If Position = 0 Then RoleCharacter = 102: Exit Function
        If Position = 1 Then RoleCharacter = 105: Exit Function
        If Position = 2 Then RoleCharacter = 108: Exit Function
        If Position = 3 Then RoleCharacter = 101: Exit Function
        If Position = 4 Then RoleCharacter = 46: Exit Function
        If Position = 5 Then RoleCharacter = 116: Exit Function
        If Position = 6 Then RoleCharacter = 114: Exit Function
        If Position = 7 Then RoleCharacter = 121: Exit Function
        If Position = 8 Then RoleCharacter = 99: Exit Function
        If Position = 9 Then RoleCharacter = 114: Exit Function
        If Position = 10 Then RoleCharacter = 101: Exit Function
        If Position = 11 Then RoleCharacter = 97: Exit Function
        If Position = 12 Then RoleCharacter = 116: Exit Function
        If Position = 13 Then RoleCharacter = 101: Exit Function
        If Position = 14 Then RoleCharacter = 110: Exit Function
        If Position = 15 Then RoleCharacter = 101: Exit Function
        If Position = 16 Then RoleCharacter = 119: Exit Function
        Exit Function
    End If
    If Role = 7 Then
        If Position = 0 Then RoleCharacter = 102: Exit Function
        If Position = 1 Then RoleCharacter = 105: Exit Function
        If Position = 2 Then RoleCharacter = 108: Exit Function
        If Position = 3 Then RoleCharacter = 101: Exit Function
        If Position = 4 Then RoleCharacter = 46: Exit Function
        If Position = 5 Then RoleCharacter = 116: Exit Function
        If Position = 6 Then RoleCharacter = 114: Exit Function
        If Position = 7 Then RoleCharacter = 121: Exit Function
        If Position = 8 Then RoleCharacter = 114: Exit Function
        If Position = 9 Then RoleCharacter = 101: Exit Function
        If Position = 10 Then RoleCharacter = 97: Exit Function
        If Position = 11 Then RoleCharacter = 100: Exit Function
        Exit Function
    End If
    If Role = 8 Then
        If Position = 0 Then RoleCharacter = 102: Exit Function
        If Position = 1 Then RoleCharacter = 105: Exit Function
        If Position = 2 Then RoleCharacter = 108: Exit Function
        If Position = 3 Then RoleCharacter = 101: Exit Function
        If Position = 4 Then RoleCharacter = 46: Exit Function
        If Position = 5 Then RoleCharacter = 116: Exit Function
        If Position = 6 Then RoleCharacter = 114: Exit Function
        If Position = 7 Then RoleCharacter = 121: Exit Function
        If Position = 8 Then RoleCharacter = 119: Exit Function
        If Position = 9 Then RoleCharacter = 114: Exit Function
        If Position = 10 Then RoleCharacter = 105: Exit Function
        If Position = 11 Then RoleCharacter = 116: Exit Function
        If Position = 12 Then RoleCharacter = 101: Exit Function
        Exit Function
    End If
    If Role = 9 Then
        If Position = 0 Then RoleCharacter = 102: Exit Function
        If Position = 1 Then RoleCharacter = 105: Exit Function
        If Position = 2 Then RoleCharacter = 108: Exit Function
        If Position = 3 Then RoleCharacter = 101: Exit Function
        If Position = 4 Then RoleCharacter = 46: Exit Function
        If Position = 5 Then RoleCharacter = 116: Exit Function
        If Position = 6 Then RoleCharacter = 114: Exit Function
        If Position = 7 Then RoleCharacter = 121: Exit Function
        If Position = 8 Then RoleCharacter = 99: Exit Function
        If Position = 9 Then RoleCharacter = 108: Exit Function
        If Position = 10 Then RoleCharacter = 111: Exit Function
        If Position = 11 Then RoleCharacter = 115: Exit Function
        If Position = 12 Then RoleCharacter = 101: Exit Function
        Exit Function
    End If
    If Role = 10 Then
        If Position = 0 Then RoleCharacter = 102: Exit Function
        If Position = 1 Then RoleCharacter = 105: Exit Function
        If Position = 2 Then RoleCharacter = 108: Exit Function
        If Position = 3 Then RoleCharacter = 101: Exit Function
        If Position = 4 Then RoleCharacter = 46: Exit Function
        If Position = 5 Then RoleCharacter = 116: Exit Function
        If Position = 6 Then RoleCharacter = 114: Exit Function
        If Position = 7 Then RoleCharacter = 121: Exit Function
        If Position = 8 Then RoleCharacter = 102: Exit Function
        If Position = 9 Then RoleCharacter = 108: Exit Function
        If Position = 10 Then RoleCharacter = 117: Exit Function
        If Position = 11 Then RoleCharacter = 115: Exit Function
        If Position = 12 Then RoleCharacter = 104: Exit Function
        Exit Function
    End If
    If Role = 11 Then
        If Position = 0 Then RoleCharacter = 101: Exit Function
        If Position = 1 Then RoleCharacter = 114: Exit Function
        If Position = 2 Then RoleCharacter = 114: Exit Function
        If Position = 3 Then RoleCharacter = 111: Exit Function
        If Position = 4 Then RoleCharacter = 114: Exit Function
        If Position = 5 Then RoleCharacter = 46: Exit Function
        If Position = 6 Then RoleCharacter = 115: Exit Function
        If Position = 7 Then RoleCharacter = 101: Exit Function
        If Position = 8 Then RoleCharacter = 116: Exit Function
        Exit Function
    End If
End Function

' Compares every decoded character including the terminator, so names and hashes cannot confer authority.
Private Function ReadRole(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByVal Count As Long, ByVal Token As Long) As Long
    Dim Role As Long
    Dim Position As Long
    Dim Expected As Long
    Dim Actual As Long
    On Error GoTo Failed
    Role = 1
    Do While Role <= 11
        Position = 0
        Do
            Expected = RoleCharacter(Role, Position)
            Actual = SyntaxTokens.SpellingByte(B, T, Token, Count, Position)
            If Expected <> Actual Then Exit Do
            If Expected = -1 Then ReadRole = Role: Exit Function
            Position = Position + 1
        Loop
        Role = Role + 1
    Loop
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Records a declaration-local error without changing a previously published map.
Private Function Reject(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal ModuleIndex As Long, ByVal Node As Long, ByVal Code As Long, ByVal Reason As Long) As Boolean
    On Error GoTo Failed
    D.Code = Code
    D.Reason = Reason
    D.ModuleIndex = ModuleIndex
    D.Node = Node
    D.TokenIndex = N(Node - 1).FirstToken
    D.ByteOffset = N(Node - 1).ByteStart - M(ModuleIndex).ByteBase
    D.Utf16Offset = N(Node - 1).Utf16Start
    D.Line = N(Node - 1).Line
    D.Column = N(Node - 1).Column
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Returns exact arity for each reviewed primitive role.
Private Function ParameterCount(ByVal Role As Long) As Long
    If Role = ArrayLength Or Role = ErrorSet Then ParameterCount = 1: Exit Function
    If Role = ArrayTryCopy Or Role = FileTryClose Or Role = FileTryFlush Then ParameterCount = 2: Exit Function
    If Role = ArrayTryResize Or Role = FileTryCreateNew Then ParameterCount = 3: Exit Function
    If Role = MemoryCopyBytes Or Role = FileTryOpen Then ParameterCount = 5: Exit Function
    ParameterCount = 6
End Function

' Classifies each formal as generic array, byte array, value Long, reference Long, or value Boolean.
Private Function ParameterShape(ByVal Role As Long, ByVal Position As Long) As Long
    ParameterShape = 3
    If Role = ArrayLength Or Role = ArrayTryCopy Then ParameterShape = 1: Exit Function
    If Role = ArrayTryResize Then
        If Position = 1 Then ParameterShape = 1
        If Position = 3 Then ParameterShape = 5
        Exit Function
    End If
    If Role = MemoryCopyBytes Then
        If Position = 1 Or Position = 3 Then ParameterShape = 2
        Exit Function
    End If
    If Role = FileTryOpen Then
        If Position = 1 Then ParameterShape = 2
        If Position >= 3 Then ParameterShape = 4
        Exit Function
    End If
    If Role = FileTryCreateNew Then
        ParameterShape = 4
        If Position = 1 Then ParameterShape = 2
        Exit Function
    End If
    If Role = FileTryRead Or Role = FileTryWrite Then
        If Position = 2 Then ParameterShape = 2
        If Position >= 5 Then ParameterShape = 4
        Exit Function
    End If
    If Role = FileTryClose Then ParameterShape = 4: Exit Function
    If Role = FileTryFlush And Position = 2 Then ParameterShape = 4
End Function

' Checks mode, scalar or nominal identity, rank, and the rank-only array declaration form.
Private Function MatchesParameter(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByVal Symbol As Long, ByVal Shape As Long) As Boolean
    Dim Child As Long
    Dim ExpectedType As Long
    Dim ExpectedMode As Long
    On Error GoTo Failed
    If Shape = 1 Or Shape = 2 Then
        If A(Symbol - 1).PassingMode <> SyntaxTokens.KwByref Then Exit Function
        If A(Symbol - 1).ArrayRank <> 1 Then Exit Function
        Child = N(A(Symbol - 1).DeclarationNode - 1).FirstChild
        If Child = 0 Then Exit Function
        If N(Child - 1).Kind <> SourceParser.ArrayShapeNode Or N(Child - 1).Value <> 2 Then Exit Function
        If N(Child - 1).FirstChild <> 0 Or N(Child - 1).LastChild <> 0 Then Exit Function
        If Shape = 2 Then
            If A(Symbol - 1).TypeCode <> SyntaxTokens.KwByte Or A(Symbol - 1).TypeSymbol <> 0 Then Exit Function
        End If
        MatchesParameter = True
        Exit Function
    End If
    If A(Symbol - 1).ArrayRank <> 0 Or A(Symbol - 1).TypeSymbol <> 0 Then Exit Function
    ExpectedType = SyntaxTokens.KwLong
    ExpectedMode = SyntaxTokens.KwByval
    If Shape = 4 Then ExpectedMode = SyntaxTokens.KwByref
    If Shape = 5 Then ExpectedType = SyntaxTokens.KwBoolean
    MatchesParameter = A(Symbol - 1).TypeCode = ExpectedType And A(Symbol - 1).PassingMode = ExpectedMode
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Validates one signature after declaration resolution has established nominal and parameter identities.
Private Function MatchesSignature(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByVal Symbol As Long, ByVal Role As Long) As Boolean
    Dim ExpectedType As Long
    Dim Parameter As Long
    Dim Position As Long
    On Error GoTo Failed
    If A(Symbol - 1).Kind <> SourceParser.FunctionNode Then Exit Function
    If A(Symbol - 1).TypeSymbol <> 0 Or A(Symbol - 1).ArrayRank <> 0 Then Exit Function
    ExpectedType = SyntaxTokens.KwBoolean
    If Role = ArrayLength Then ExpectedType = SyntaxTokens.KwLong
    If A(Symbol - 1).TypeCode <> ExpectedType Then Exit Function
    If A(Symbol - 1).ParameterCount <> ParameterCount(Role) Then Exit Function
    Parameter = A(Symbol - 1).FirstParameter
    Position = 1
    Do While Parameter <> 0
        If MatchesParameter(N, A, Parameter, ParameterShape(Role, Position)) = False Then Exit Function
        Parameter = A(Parameter - 1).NextParameter
        Position = Position + 1
    Loop
    MatchesSignature = Position = ParameterCount(Role) + 1
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Validates metadata and publishes only declaration-node identities, never call-site authority.
Private Function BindProcedure(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef A() As DeclarationBinder.BoundSymbol, ByVal Symbol As Long, ByRef Candidate() As Long, ByRef D As DeclarationBinder.BindingDiagnostic) As Boolean
    Dim Node As Long
    Dim Child As Long
    Dim AttributeNode As Long
    Dim AttributeCount As Long
    Dim BodyCount As Long
    Dim Role As Long
    Dim First As Long
    Dim Second As Long
    Dim ModuleIndex As Long
    On Error GoTo Failed
    Node = A(Symbol - 1).DeclarationNode
    ModuleIndex = A(Symbol - 1).ModuleIndex
    Child = N(Node - 1).FirstChild
    Do While Child <> 0
        If N(Child - 1).Kind = SourceParser.PrimitiveNode Then
            AttributeCount = AttributeCount + 1
            AttributeNode = Child
        End If
        If N(Node - 1).IsIntrinsic And N(Child - 1).Kind = SourceParser.BodyNode Then
            BodyCount = BodyCount + 1
            If N(Child - 1).FirstChild <> 0 Then BindProcedure = Reject(N, M, D, ModuleIndex, Child, 3, 4): Exit Function
        End If
        Child = N(Child - 1).NextSibling
    Loop
    If N(Node - 1).IsIntrinsic = False Then
        If AttributeCount <> 0 Then BindProcedure = Reject(N, M, D, ModuleIndex, AttributeNode, 3, 1): Exit Function
        BindProcedure = True
        Exit Function
    End If
    If AttributeCount <> 1 Then BindProcedure = Reject(N, M, D, ModuleIndex, Node, 3, 2): Exit Function
    If BodyCount <> 1 Then BindProcedure = Reject(N, M, D, ModuleIndex, Node, 3, 4): Exit Function
    If N(AttributeNode - 1).NameToken < 0 Or N(AttributeNode - 1).TypeFirstToken < 0 Then BindProcedure = Reject(N, M, D, ModuleIndex, AttributeNode, 9, 1): Exit Function
    If SyntaxTokens.TokenCode(B, T, N(AttributeNode - 1).NameToken, C.TokenCount) <> SyntaxTokens.CodeString Then BindProcedure = Reject(N, M, D, ModuleIndex, AttributeNode, 9, 1): Exit Function
    If N(AttributeNode - 1).TypeFirstToken <> N(AttributeNode - 1).TypeLastToken Then BindProcedure = Reject(N, M, D, ModuleIndex, AttributeNode, 9, 1): Exit Function
    If SyntaxTokens.SameIdentifier(B, T, N(AttributeNode - 1).TypeFirstToken, A(Symbol - 1).NameToken, C.TokenCount) = False Then BindProcedure = Reject(N, M, D, ModuleIndex, AttributeNode, 3, 3): Exit Function
    Role = ReadRole(B, T, C.TokenCount, N(AttributeNode - 1).NameToken)
    If Role = 0 Then BindProcedure = Reject(N, M, D, ModuleIndex, AttributeNode, 8, 1): Exit Function
    If MatchesSignature(N, A, Symbol, Role) = False Then BindProcedure = Reject(N, M, D, ModuleIndex, Node, 3, 5): Exit Function
    If Role = ArrayTryCopy Then
        First = A(Symbol - 1).FirstParameter
        Second = A(First - 1).NextParameter
        If A(First - 1).TypeCode <> A(Second - 1).TypeCode Or A(First - 1).TypeSymbol <> A(Second - 1).TypeSymbol Then BindProcedure = Reject(N, M, D, ModuleIndex, Node, 3, 6): Exit Function
    End If
    Candidate(Node - 1) = Role
    BindProcedure = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Re-derives declarations and atomically publishes reviewed primitive roles over validated project syntax.
Public Function TryBindPrimitives(ByRef Bytes() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByRef Nodes() As SourceParser.SyntaxNode, ByRef Modules() As ProjectSyntax.ParsedModule, ByRef Counts As ProjectSyntax.ProjectCounts, ByRef PackageName() As Byte, ByVal IsExecutable As Boolean, ByRef Roles() As Long, ByRef RoleCount As Long, ByRef Diagnostic As DeclarationBinder.BindingDiagnostic) As Boolean
    Dim Symbols() As DeclarationBinder.BoundSymbol
    Dim SymbolCount As Long
    Dim EntrySymbol As Long
    Dim Candidate() As Long
    Dim Index As Long
    Dim Parent As Long
    Dim ModuleIndex As Long
    On Error GoTo StorageFailure
    RoleCount = 0
    If DeclarationBinder.TryBindDeclarations(Bytes, Tokens, Nodes, Modules, Counts, PackageName, IsExecutable, Symbols, SymbolCount, EntrySymbol, Diagnostic) = False Then Exit Function
    Index = 1
    Do While Index <= Counts.NodeCount
        If Nodes(Index - 1).Kind = SourceParser.PrimitiveNode Then
            Parent = Nodes(Index - 1).Parent
            If Parent = 0 Then GoTo InvalidPlacement
            If Nodes(Parent - 1).Kind <> SourceParser.SubNode And Nodes(Parent - 1).Kind <> SourceParser.FunctionNode Then GoTo InvalidPlacement
        End If
        Index = Index + 1
    Loop
    If ResizeRoles(Candidate, Counts.NodeCount, False) = False Then GoTo StorageFailure
    Index = 1
    Do While Index <= SymbolCount
        If Symbols(Index - 1).Kind = SourceParser.SubNode Or Symbols(Index - 1).Kind = SourceParser.FunctionNode Then
            If BindProcedure(Bytes, Tokens, Nodes, Modules, Counts, Symbols, Index, Candidate, Diagnostic) = False Then Exit Function
        End If
        Index = Index + 1
    Loop
    Roles = Candidate
    RoleCount = Counts.NodeCount
    TryBindPrimitives = True
    Exit Function
InvalidPlacement:
    ModuleIndex = 0
    Do While ModuleIndex < Counts.ModuleCount
        If Index > Modules(ModuleIndex).NodeBase And Index <= Modules(ModuleIndex).NodeBase + Modules(ModuleIndex).NodeCount Then
            TryBindPrimitives = Reject(Nodes, Modules, Diagnostic, ModuleIndex, Index, 9, 1)
            Exit Function
        End If
        ModuleIndex = ModuleIndex + 1
    Loop
StorageFailure:
    RoleCount = 0
    Diagnostic.Code = 7
    Diagnostic.Reason = 1
    Diagnostic.ModuleIndex = -1
    Diagnostic.Node = 0
    Diagnostic.TokenIndex = -1
    Diagnostic.ByteOffset = 0
    Diagnostic.Utf16Offset = 1
    Diagnostic.Line = 1
    Diagnostic.Column = 1
End Function
