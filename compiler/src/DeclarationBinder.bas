UBE SOURCE 1 MODULE
Attribute UBE_Name = "DeclarationBinder"
' Collects declaration identities and resolves signatures without checking executable expressions or layouts.
Public Const ModuleRegion As Long = 1
Public Const ValueRegion As Long = 2
Public Const LabelRegion As Long = 3
Public Const ResultRegion As Long = 4
Public Const ResultSymbol As Long = 30

Public Type BoundSymbol
    ModuleIndex As Long
    ScopeSymbol As Long
    DeclarationNode As Long
    NameToken As Long
    Kind As Long
    Region As Long
    Visibility As Long
    TypeCode As Long
    TypeSymbol As Long
    ArrayRank As Long
    PassingMode As Long
    FirstParameter As Long
    NextParameter As Long
    ParameterCount As Long
    FirstField As Long
    NextField As Long
End Type

Public Type BindingDiagnostic
    Code As Long
    Reason As Long
    ModuleIndex As Long
    Node As Long
    TokenIndex As Long
    ByteOffset As Long
    Utf16Offset As Long
    [Line] As Long
    Column As Long
End Type

Private Type BindingState
    Count As Long
    Capacity As Long
    Work As Long
End Type

' Allocates independent candidate symbol storage through the ordinary typed primitive.
Private Intrinsic Function ResizeSymbols(ByRef Values() As BoundSymbol, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeSymbols.UBE_Primitive = "Array.TryResize"
End Function

' Allocates bounded numeric lookup indexes owned by one binding request.
Private Intrinsic Function ResizeIndex(ByRef Values() As Long, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeIndex.UBE_Primitive = "Array.TryResize"
End Function

' Reads the extent of the retained source-byte pool.
Private Intrinsic Function ByteLength(ByRef Values() As Byte) As Long
Attribute ByteLength.UBE_Primitive = "Array.Length"
End Function

' Publishes the first located declaration diagnostic, retaining global pool identities.
Private Function Reject(ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef D As BindingDiagnostic, ByVal Code As Long, ByVal Reason As Long, ByVal ModuleIndex As Long, ByVal Node As Long) As Boolean
    On Error GoTo Failed
    If D.Code <> 0 Then Exit Function
    D.Code = Code
    D.Reason = Reason
    D.ModuleIndex = ModuleIndex
    D.Node = Node
    If Node > 0 Then
        D.TokenIndex = N(Node - 1).FirstToken
        D.ByteOffset = N(Node - 1).ByteStart
        D.Utf16Offset = N(Node - 1).Utf16Start
        D.Line = N(Node - 1).Line
        D.Column = N(Node - 1).Column
    End If
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Charges bounded declaration and lookup work before each candidate inspection.
Private Function Charge(ByRef S As BindingState) As Boolean
    On Error GoTo Failed
    If S.Work >= 4000000 Then Exit Function
    S.Work = S.Work + 1
    Charge = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Finds the canonical leading-zero offset only for all-digit label spellings.
Private Function LabelStart(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByVal Token As Long, ByVal Count As Long, ByVal Region As Long) As Long
    Dim Position As Long
    Dim First As Long
    Dim Character As Long
    On Error GoTo Failed
    If Region <> LabelRegion Then Exit Function
    Character = SyntaxTokens.SpellingByte(B, T, Token, Count, Position)
    If Character < 48 Or Character > 57 Then Exit Function
    Do While Character >= 0
        If Character < 48 Or Character > 57 Then Exit Function
        If Character = 48 And Position = First Then First = First + 1
        Position = Position + 1
        Character = SyntaxTokens.SpellingByte(B, T, Token, Count, Position)
    Loop
    If First = Position Then First = First - 1
    LabelStart = First
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Hashes decoded ASCII names together with scope and namespace using bounded integer arithmetic.
Private Function NameHash(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByVal Count As Long, ByVal Token As Long, ByVal Scope As Long, ByVal Region As Long) As Long
    Dim Hash As Long
    Dim Position As Long
    Dim Character As Long
    On Error GoTo Failed
    Hash = Scope + Region
    Position = LabelStart(B, T, Token, Count, Region)
    Character = SyntaxTokens.SpellingByte(B, T, Token, Count, Position)
    Do While Character >= 0
        Hash = Hash + Hash + Character
        Do While Hash >= 32749
            Hash = Hash - 32749
        Loop
        Position = Position + 1
        Character = SyntaxTokens.SpellingByte(B, T, Token, Count, Position)
    Loop
    NameHash = Hash
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Compares decoded names, including canonical procedure-local decimal labels.
Private Function EqualName(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByVal Count As Long, ByVal First As Long, ByVal Second As Long, ByVal Region As Long) As Boolean
    Dim LeftPosition As Long
    Dim RightPosition As Long
    Dim LeftByte As Long
    Dim RightByte As Long
    On Error GoTo Failed
    LeftPosition = LabelStart(B, T, First, Count, Region)
    RightPosition = LabelStart(B, T, Second, Count, Region)
    Do
        LeftByte = SyntaxTokens.SpellingByte(B, T, First, Count, LeftPosition)
        RightByte = SyntaxTokens.SpellingByte(B, T, Second, Count, RightPosition)
        If LeftByte <> RightByte Then Exit Function
        If LeftByte < 0 Then EqualName = True: Exit Function
        LeftPosition = LeftPosition + 1
        RightPosition = RightPosition + 1
    Loop
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Searches one selected declaration region without retrying another namespace on a wrong kind.
Private Function FindSymbol(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByVal Count As Long, ByRef A() As BoundSymbol, ByRef Buckets() As Long, ByRef Links() As Long, ByRef S As BindingState, ByVal Scope As Long, ByVal Region As Long, ByVal Token As Long) As Long
    Dim Index As Long
    On Error GoTo Failed
    If Charge(S) = False Then Exit Function
    Index = Buckets(NameHash(B, T, Count, Token, Scope, Region))
    Do While Index <> 0
        If Charge(S) = False Then Exit Function
        If A(Index - 1).ScopeSymbol = Scope And A(Index - 1).Region = Region Then
            If EqualName(B, T, Count, A(Index - 1).NameToken, Token, Region) Then FindSymbol = Index: Exit Function
        End If
        Index = Links(Index - 1)
    Loop
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Adds a stable symbol identity after duplicate, quota and allocation checks.
Private Function DeclareSymbol(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByVal TokenCount As Long, ByRef A() As BoundSymbol, ByRef Buckets() As Long, ByRef Links() As Long, ByRef S As BindingState, ByRef D As BindingDiagnostic, ByRef Item As BoundSymbol) As Long
    Dim Existing As Long
    Dim Capacity As Long
    Dim Bucket As Long
    Dim Index As Long
    On Error GoTo Failed
    Existing = FindSymbol(B, T, TokenCount, A, Buckets, Links, S, Item.ScopeSymbol, Item.Region, Item.NameToken)
    If S.Work >= 4000000 Then Reject T, N, D, 6, 2, Item.ModuleIndex, Item.DeclarationNode: Exit Function
    If Existing <> 0 Then Reject T, N, D, 1, 1, Item.ModuleIndex, Item.DeclarationNode: Exit Function
    If S.Count >= 16384 Then Reject T, N, D, 6, 1, Item.ModuleIndex, Item.DeclarationNode: Exit Function
    If S.Count = S.Capacity Then
        Capacity = S.Capacity + S.Capacity
        If Capacity = 0 Then Capacity = 128
        If Capacity > 16384 Then Capacity = 16384
        If ResizeSymbols(A, Capacity, True) = False Then Reject T, N, D, 7, 1, Item.ModuleIndex, Item.DeclarationNode: Exit Function
        S.Capacity = Capacity
    End If
    Index = S.Count
    A(Index) = Item
    S.Count = S.Count + 1
    Bucket = NameHash(B, T, TokenCount, Item.NameToken, Item.ScopeSymbol, Item.Region)
    Links(Index) = Buckets(Bucket)
    Buckets(Bucket) = Index + 1
    DeclareSymbol = Index + 1
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Derives declaration facts from retained syntax without evaluating initializers or array bounds.
Private Function DeclarationFacts(ByRef N() As SourceParser.SyntaxNode, ByRef Item As BoundSymbol) As Boolean
    Dim Child As Long
    Dim Kind As Long
    On Error GoTo Failed
    Kind = Item.Kind
    Item.NameToken = N(Item.DeclarationNode - 1).NameToken
    Item.Visibility = N(Item.DeclarationNode - 1).Modifier
    If Item.Region <> ValueRegion Or Kind = SourceParser.FieldNode Or Kind = SourceParser.ParameterNode Then Item.Visibility = 0
    If Kind = SourceParser.ParameterNode Then Item.PassingMode = N(Item.DeclarationNode - 1).Modifier
    Child = N(Item.DeclarationNode - 1).FirstChild
    If Child <> 0 Then
        If N(Child - 1).Kind = SourceParser.ArrayShapeNode Then Item.ArrayRank = 1
    End If
    DeclarationFacts = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Finds an enclosing declared container iteratively, with the same global work guard.
Private Function ContainerScope(ByRef N() As SourceParser.SyntaxNode, ByRef NodeSymbols() As Long, ByRef S As BindingState, ByVal Node As Long) As Long
    Dim Parent As Long
    On Error GoTo Failed
    Parent = N(Node - 1).Parent
    Do While Parent <> 0
        If Charge(S) = False Then Exit Function
        If NodeSymbols(Parent - 1) <> 0 Then
            If N(Parent - 1).Kind = SourceParser.ModuleNode Or N(Parent - 1).Kind = SourceParser.TypeNode Or N(Parent - 1).Kind = SourceParser.SubNode Or N(Parent - 1).Kind = SourceParser.FunctionNode Then
                ContainerScope = NodeSymbols(Parent - 1): Exit Function
            End If
        End If
        Parent = N(Parent - 1).Parent
    Loop
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Declares a syntax-backed symbol in its explicit namespace and records source visibility.
Private Function AddDeclaration(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByVal TokenCount As Long, ByRef A() As BoundSymbol, ByRef Buckets() As Long, ByRef Links() As Long, ByRef S As BindingState, ByRef D As BindingDiagnostic, ByVal ModuleIndex As Long, ByVal Node As Long, ByVal Scope As Long, ByVal Region As Long, ByVal Kind As Long) As Long
    Dim Item As BoundSymbol
    Dim ParentKind As Long
    On Error GoTo Failed
    Item.ModuleIndex = ModuleIndex
    Item.DeclarationNode = Node
    Item.ScopeSymbol = Scope
    Item.Region = Region
    Item.Kind = Kind
    If DeclarationFacts(N, Item) = False Then Exit Function
    If Item.NameToken < 0 Or Item.NameToken >= TokenCount Then Reject T, N, D, 9, 1, ModuleIndex, Node: Exit Function
    If Kind = SourceParser.ModuleNode Then
        Item.Visibility = SyntaxTokens.KwPublic
    ElseIf Region = ValueRegion Then
        ParentKind = A(Scope - 1).Kind
        If ParentKind = SourceParser.ModuleNode Then
            If Item.Visibility = SyntaxTokens.KwGlobal Then
                If Kind <> SourceParser.VariableNode Then Reject T, N, D, 3, 1, ModuleIndex, Node: Exit Function
                Item.Visibility = SyntaxTokens.KwPublic
            ElseIf Item.Visibility = 0 Then
                Item.Visibility = SyntaxTokens.KwPrivate
                If Kind = SourceParser.TypeNode Or Kind = SourceParser.FunctionNode Or Kind = SourceParser.SubNode Then Item.Visibility = SyntaxTokens.KwPublic
            End If
        Else
            Item.Visibility = 0
        End If
    End If
    If Item.Kind = SourceParser.ConstantNode And Item.ArrayRank <> 0 Then Reject T, N, D, 3, 2, ModuleIndex, Node: Exit Function
    AddDeclaration = DeclareSymbol(B, T, N, TokenCount, A, Buckets, Links, S, D, Item)
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Collects module and top-level identities before any forward type reference is resolved.
Private Function CollectTop(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef A() As BoundSymbol, ByRef Buckets() As Long, ByRef Links() As Long, ByRef NodeSymbols() As Long, ByRef ModuleSymbols() As Long, ByRef S As BindingState, ByRef D As BindingDiagnostic) As Boolean
    Dim Index As Long
    Dim Node As Long
    Dim Symbol As Long
    Dim Kind As Long
    On Error GoTo Failed
    Do While Index < C.ModuleCount
        Node = M(Index).RootNode
        Symbol = AddDeclaration(B, T, N, C.TokenCount, A, Buckets, Links, S, D, Index, Node, 0, ModuleRegion, SourceParser.ModuleNode)
        If Symbol = 0 Then Exit Function
        ModuleSymbols(Index) = Symbol
        NodeSymbols(Node - 1) = Symbol
        Index = Index + 1
    Loop
    Index = 0
    Do While Index < C.ModuleCount
        Node = N(M(Index).RootNode - 1).FirstChild
        Do While Node <> 0
            If Charge(S) = False Then CollectTop = Reject(T, N, D, 6, 2, Index, Node): Exit Function
            Kind = N(Node - 1).Kind
            If Kind = SourceParser.SubNode Or Kind = SourceParser.FunctionNode Or Kind = SourceParser.TypeNode Or Kind = SourceParser.VariableNode Or Kind = SourceParser.ConstantNode Then
                Symbol = AddDeclaration(B, T, N, C.TokenCount, A, Buckets, Links, S, D, Index, Node, ModuleSymbols(Index), ValueRegion, Kind)
                If Symbol = 0 Then Exit Function
                NodeSymbols(Node - 1) = Symbol
            End If
            Node = N(Node - 1).NextSibling
        Loop
        Index = Index + 1
    Loop
    CollectTop = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Collects ordered parameters, result identities and record fields after their containers exist.
Private Function CollectMembers(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef C As ProjectSyntax.ProjectCounts, ByRef A() As BoundSymbol, ByRef Buckets() As Long, ByRef Links() As Long, ByRef NodeSymbols() As Long, ByRef S As BindingState, ByRef D As BindingDiagnostic) As Boolean
    Dim Index As Long
    Dim TopCount As Long
    Dim Kind As Long
    Dim Node As Long
    Dim Child As Long
    Dim Symbol As Long
    Dim Previous As Long
    Dim ModuleIndex As Long
    On Error GoTo Failed
    TopCount = S.Count
    Do While Index < TopCount
        Kind = A(Index).Kind
        Node = A(Index).DeclarationNode
        ModuleIndex = A(Index).ModuleIndex
        If Kind = SourceParser.FunctionNode Then
            Symbol = AddDeclaration(B, T, N, C.TokenCount, A, Buckets, Links, S, D, ModuleIndex, Node, Index + 1, ResultRegion, ResultSymbol)
            If Symbol = 0 Then Exit Function
        End If
        If Kind = SourceParser.SubNode Or Kind = SourceParser.FunctionNode Or Kind = SourceParser.TypeNode Then
            Previous = 0
            Child = N(Node - 1).FirstChild
            Do While Child <> 0
                If Charge(S) = False Then CollectMembers = Reject(T, N, D, 6, 2, ModuleIndex, Child): Exit Function
                If N(Child - 1).Kind = SourceParser.ParameterNode Or N(Child - 1).Kind = SourceParser.FieldNode Then
                    Symbol = AddDeclaration(B, T, N, C.TokenCount, A, Buckets, Links, S, D, ModuleIndex, Child, Index + 1, ValueRegion, N(Child - 1).Kind)
                    If Symbol = 0 Then Exit Function
                    NodeSymbols(Child - 1) = Symbol
                    If Kind = SourceParser.TypeNode Then
                        If Previous = 0 Then A(Index).FirstField = Symbol Else A(Previous - 1).NextField = Symbol
                    Else
                        If Previous = 0 Then A(Index).FirstParameter = Symbol Else A(Previous - 1).NextParameter = Symbol
                        A(Index).ParameterCount = A(Index).ParameterCount + 1
                    End If
                    Previous = Symbol
                End If
                Child = N(Child - 1).NextSibling
            Loop
            If Kind = SourceParser.TypeNode And Previous = 0 Then CollectMembers = Reject(T, N, D, 3, 3, ModuleIndex, Node): Exit Function
        End If
        Index = Index + 1
    Loop
    CollectMembers = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Collects procedure-wide locals and separate labels independent of block nesting.
Private Function CollectLocals(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef A() As BoundSymbol, ByRef Buckets() As Long, ByRef Links() As Long, ByRef NodeSymbols() As Long, ByRef S As BindingState, ByRef D As BindingDiagnostic) As Boolean
    Dim ModuleIndex As Long
    Dim Node As Long
    Dim Finish As Long
    Dim Kind As Long
    Dim Scope As Long
    Dim Region As Long
    Dim Symbol As Long
    On Error GoTo Failed
    Do While ModuleIndex < C.ModuleCount
        Node = M(ModuleIndex).NodeBase + 1
        Finish = M(ModuleIndex).NodeBase + M(ModuleIndex).NodeCount
        Do While Node <= Finish
            Kind = N(Node - 1).Kind
            If NodeSymbols(Node - 1) = 0 And (Kind = SourceParser.VariableNode Or Kind = SourceParser.ConstantNode Or Kind = SourceParser.LabelNode) Then
                Scope = ContainerScope(N, NodeSymbols, S, Node)
                If S.Work >= 4000000 Then CollectLocals = Reject(T, N, D, 6, 2, ModuleIndex, Node): Exit Function
                If Scope = 0 Then CollectLocals = Reject(T, N, D, 9, 2, ModuleIndex, Node): Exit Function
                If A(Scope - 1).Kind <> SourceParser.FunctionNode And A(Scope - 1).Kind <> SourceParser.SubNode Then CollectLocals = Reject(T, N, D, 9, 2, ModuleIndex, Node): Exit Function
                Region = ValueRegion
                If Kind = SourceParser.LabelNode Then Region = LabelRegion
                Symbol = AddDeclaration(B, T, N, C.TokenCount, A, Buckets, Links, S, D, ModuleIndex, Node, Scope, Region, Kind)
                If Symbol = 0 Then Exit Function
                NodeSymbols(Node - 1) = Symbol
            End If
            Node = Node + 1
        Loop
        ModuleIndex = ModuleIndex + 1
    Loop
    CollectLocals = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Compares an explicit package-name byte value with a decoded type qualifier.
Private Function PackageMatches(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByVal TokenCount As Long, ByVal Token As Long, ByRef PackageName() As Byte) As Boolean
    Dim Index As Long
    Dim Length As Long
    Dim Character As Long
    On Error GoTo Failed
    Length = ByteLength(PackageName)
    Do While Index < Length
        Character = PackageName(Index)
        If Character >= 65 And Character <= 90 Then Character = Character + 32
        If Character <> SyntaxTokens.SpellingByte(B, T, Token, TokenCount, Index) Then Exit Function
        Index = Index + 1
    Loop
    PackageMatches = SyntaxTokens.SpellingByte(B, T, Token, TokenCount, Index) = -1
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Resolves nominal type references after every declaration has a stable identity.
Private Function ResolveType(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef C As ProjectSyntax.ProjectCounts, ByRef PackageName() As Byte, ByRef A() As BoundSymbol, ByRef Buckets() As Long, ByRef Links() As Long, ByRef ModuleSymbols() As Long, ByRef S As BindingState, ByRef D As BindingDiagnostic, ByVal Symbol As Long) As Long
    Dim Node As Long
    Dim First As Long
    Dim Last As Long
    Dim ModuleIndex As Long
    Dim Selected As Long
    Dim Candidate As Long
    Dim Index As Long
    Dim ModuleSymbol As Long
    On Error GoTo Failed
    Node = A(Symbol - 1).DeclarationNode
    ModuleIndex = A(Symbol - 1).ModuleIndex
    First = N(Node - 1).TypeFirstToken
    Last = N(Node - 1).TypeLastToken
    If Last = First Then
        Selected = FindSymbol(B, T, C.TokenCount, A, Buckets, Links, S, ModuleSymbols(ModuleIndex), ValueRegion, First)
        If Selected = 0 Then
            Do While Index < C.ModuleCount
                Candidate = FindSymbol(B, T, C.TokenCount, A, Buckets, Links, S, ModuleSymbols(Index), ValueRegion, First)
                If Candidate <> 0 Then
                    If A(Candidate - 1).Visibility = SyntaxTokens.KwPublic Or A(Candidate - 1).Visibility = SyntaxTokens.KwFriend Then
                        If Selected <> 0 Then Reject T, N, D, 4, 1, ModuleIndex, Node: Exit Function
                        Selected = Candidate
                    End If
                End If
                Index = Index + 1
            Loop
        End If
    ElseIf Last - First = 2 Or Last - First = 4 Then
        If Last - First = 4 Then
            If PackageMatches(B, T, C.TokenCount, First, PackageName) = False Then Reject T, N, D, 2, 2, ModuleIndex, Node: Exit Function
            Candidate = FindSymbol(B, T, C.TokenCount, A, Buckets, Links, S, 0, ModuleRegion, First)
            If Candidate <> 0 Then Reject T, N, D, 8, 1, ModuleIndex, Node: Exit Function
            First = First + 2
        End If
        ModuleSymbol = FindSymbol(B, T, C.TokenCount, A, Buckets, Links, S, 0, ModuleRegion, First)
        If ModuleSymbol <> 0 Then Selected = FindSymbol(B, T, C.TokenCount, A, Buckets, Links, S, ModuleSymbol, ValueRegion, First + 2)
    End If
    If S.Work >= 4000000 Then Reject T, N, D, 6, 2, ModuleIndex, Node: Exit Function
    If Selected = 0 Then Reject T, N, D, 2, 1, ModuleIndex, Node: Exit Function
    If A(Selected - 1).Kind <> SourceParser.TypeNode Then Reject T, N, D, 3, 5, ModuleIndex, Node: Exit Function
    If A(Selected - 1).Visibility = SyntaxTokens.KwPrivate And A(Selected - 1).ModuleIndex <> ModuleIndex Then Reject T, N, D, 2, 3, ModuleIndex, Node: Exit Function
    ResolveType = Selected
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Resolves declared scalar or nominal signatures without evaluating values or computing layout.
Private Function ResolveSignatures(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef C As ProjectSyntax.ProjectCounts, ByRef PackageName() As Byte, ByRef A() As BoundSymbol, ByRef Buckets() As Long, ByRef Links() As Long, ByRef ModuleSymbols() As Long, ByRef S As BindingState, ByRef D As BindingDiagnostic) As Boolean
    Dim Index As Long
    Dim Node As Long
    Dim Kind As Long
    Dim Code As Long
    Dim First As Long
    Dim Selected As Long
    On Error GoTo Failed
    Do While Index < S.Count
        Node = A(Index).DeclarationNode
        Kind = A(Index).Kind
        If Kind = SourceParser.TypeNode Then
            A(Index).TypeSymbol = Index + 1
        ElseIf Kind = SourceParser.VariableNode Or Kind = SourceParser.ConstantNode Or Kind = SourceParser.FieldNode Or Kind = SourceParser.ParameterNode Or Kind = SourceParser.FunctionNode Or Kind = ResultSymbol Then
            If Kind = SourceParser.ParameterNode Then
                If A(Index).PassingMode <> SyntaxTokens.KwByRef And A(Index).PassingMode <> SyntaxTokens.KwByVal Then ResolveSignatures = Reject(T, N, D, 3, 4, A(Index).ModuleIndex, Node): Exit Function
            End If
            Code = N(Node - 1).Suffix
            First = N(Node - 1).TypeFirstToken
            If First >= 0 Then Code = SyntaxTokens.TokenCode(B, T, First, C.TokenCount)
            If Code = SyntaxTokens.KwBoolean Or Code = SyntaxTokens.KwByte Or Code = SyntaxTokens.KwInteger Or Code = SyntaxTokens.KwLong Or Code = SyntaxTokens.KwLongLong Then
                If First >= 0 Then
                    If N(Node - 1).TypeLastToken <> First Then ResolveSignatures = Reject(T, N, D, 3, 5, A(Index).ModuleIndex, Node): Exit Function
                End If
                A(Index).TypeCode = Code
            Else
                If First < 0 Then ResolveSignatures = Reject(T, N, D, 3, 5, A(Index).ModuleIndex, Node): Exit Function
                Selected = ResolveType(B, T, N, C, PackageName, A, Buckets, Links, ModuleSymbols, S, D, Index + 1)
                If Selected = 0 Then Exit Function
                A(Index).TypeSymbol = Selected
            End If
        End If
        Index = Index + 1
    Loop
    ResolveSignatures = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Recognizes the Main identifier by decoded bytes, independently of caller casing or brackets.
Private Function IsMain(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByVal Count As Long, ByVal Token As Long) As Boolean
    On Error GoTo Failed
    If SyntaxTokens.SpellingByte(B, T, Token, Count, 0) <> 109 Then Exit Function
    If SyntaxTokens.SpellingByte(B, T, Token, Count, 1) <> 97 Then Exit Function
    If SyntaxTokens.SpellingByte(B, T, Token, Count, 2) <> 105 Then Exit Function
    If SyntaxTokens.SpellingByte(B, T, Token, Count, 3) <> 110 Then Exit Function
    IsMain = SyntaxTokens.SpellingByte(B, T, Token, Count, 4) = -1
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Selects exactly one executable Main while leaving Library projects without an entry role.
Private Function SelectEntry(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef C As ProjectSyntax.ProjectCounts, ByRef A() As BoundSymbol, ByRef S As BindingState, ByRef D As BindingDiagnostic, ByVal IsExecutable As Boolean, ByRef Entry As Long) As Boolean
    Dim Index As Long
    Dim Node As Long
    Dim Kind As Long
    On Error GoTo Failed
    If IsExecutable = False Then SelectEntry = True: Exit Function
    Do While Index < S.Count
        Kind = A(Index).Kind
        If Kind = SourceParser.SubNode Or Kind = SourceParser.FunctionNode Then
            If IsMain(B, T, C.TokenCount, A(Index).NameToken) Then
                Node = A(Index).DeclarationNode
                If N(Node - 1).IsIntrinsic Then SelectEntry = Reject(T, N, D, 3, 6, A(Index).ModuleIndex, Node): Exit Function
                If A(Index).ParameterCount <> 0 Then SelectEntry = Reject(T, N, D, 5, 2, A(Index).ModuleIndex, Node): Exit Function
                If Kind = SourceParser.FunctionNode Then
                    If A(Index).TypeCode <> SyntaxTokens.KwLong Or A(Index).ArrayRank <> 0 Then SelectEntry = Reject(T, N, D, 5, 2, A(Index).ModuleIndex, Node): Exit Function
                End If
                If Entry <> 0 Then SelectEntry = Reject(T, N, D, 5, 3, A(Index).ModuleIndex, Node): Exit Function
                Entry = Index + 1
            End If
        End If
        Index = Index + 1
    Loop
    If Entry = 0 Then SelectEntry = Reject(T, N, D, 5, 1, -1, 0): Exit Function
    SelectEntry = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Reuses arena validation and checks the separately supplied ASCII package identity.
Private Function ValidateProject(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef PackageName() As Byte, ByRef D As BindingDiagnostic) As Boolean
    Dim Index As Long
    Dim Length As Long
    Dim Character As Long
    On Error GoTo Failed
    If ProjectSyntax.IsValidProject(B, T, N, M, C) = False Then ValidateProject = Reject(T, N, D, 9, 1, -1, 0): Exit Function
    If C.ModuleCount = 0 Then ValidateProject = Reject(T, N, D, 9, 1, -1, 0): Exit Function
    Length = ByteLength(PackageName)
    If Length < 1 Or Length > 128 Then ValidateProject = Reject(T, N, D, 9, 3, -1, 0): Exit Function
    Do While Index < Length
        Character = PackageName(Index)
        If Character >= 65 And Character <= 90 Then Character = Character + 32
        If (Character < 97 Or Character > 122) And Character <> 95 Then
            If Index = 0 Or Character < 48 Or Character > 57 Then ValidateProject = Reject(T, N, D, 9, 3, -1, 0): Exit Function
        End If
        Index = Index + 1
    Loop
    ValidateProject = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Checks tree ownership and reachability once, reusing the future node-to-symbol map as visit marks.
Private Function ValidateTrees(ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef Marks() As Long, ByRef S As BindingState, ByRef D As BindingDiagnostic) As Boolean
    Dim Index As Long
    Dim Node As Long
    Dim Root As Long
    Dim Child As Long
    Dim Parent As Long
    Dim Reached As Long
    On Error GoTo Failed
    Do While Index < C.ModuleCount
        Root = M(Index).RootNode
        Node = Root
        Reached = 0
        If N(Root - 1).Parent <> 0 Or N(Root - 1).NextSibling <> 0 Then ValidateTrees = Reject(T, N, D, 9, 4, Index, Root): Exit Function
        Do
            If Charge(S) = False Then ValidateTrees = Reject(T, N, D, 6, 2, Index, Node): Exit Function
            If Marks(Node - 1) <> 0 Then ValidateTrees = Reject(T, N, D, 9, 4, Index, Node): Exit Function
            Marks(Node - 1) = 1
            Reached = Reached + 1
            Child = N(Node - 1).FirstChild
            If Child <> 0 Then
                If N(Child - 1).Parent <> Node Then ValidateTrees = Reject(T, N, D, 9, 4, Index, Child): Exit Function
                Node = Child
            Else
                If N(Node - 1).LastChild <> 0 Then ValidateTrees = Reject(T, N, D, 9, 4, Index, Node): Exit Function
                Do
                    If Node = Root Then Exit Do
                    If Charge(S) = False Then ValidateTrees = Reject(T, N, D, 6, 2, Index, Node): Exit Function
                    Parent = N(Node - 1).Parent
                    If Parent = 0 Then ValidateTrees = Reject(T, N, D, 9, 4, Index, Node): Exit Function
                    Child = N(Node - 1).NextSibling
                    If Child <> 0 Then
                        If N(Child - 1).Parent <> Parent Then ValidateTrees = Reject(T, N, D, 9, 4, Index, Child): Exit Function
                        Node = Child
                        Exit Do
                    End If
                    If N(Parent - 1).LastChild <> Node Then ValidateTrees = Reject(T, N, D, 9, 4, Index, Parent): Exit Function
                    Node = Parent
                Loop
                If Node = Root Then Exit Do
            End If
        Loop
        If Reached <> M(Index).NodeCount Then ValidateTrees = Reject(T, N, D, 9, 4, Index, Root): Exit Function
        Index = Index + 1
    Loop
    Index = 0
    Do While Index < C.NodeCount
        Marks(Index) = 0
        Index = Index + 1
    Loop
    ValidateTrees = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Publishes declaration facts atomically; expression checking, layouts and primitive authority remain later passes.
Public Function TryBindDeclarations(ByRef Bytes() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByRef Nodes() As SourceParser.SyntaxNode, ByRef Modules() As ProjectSyntax.ParsedModule, ByRef Counts As ProjectSyntax.ProjectCounts, ByRef PackageName() As Byte, ByVal IsExecutable As Boolean, ByRef Symbols() As BoundSymbol, ByRef SymbolCount As Long, ByRef EntrySymbol As Long, ByRef Diagnostic As BindingDiagnostic) As Boolean
    Dim Candidate() As BoundSymbol
    Dim Buckets() As Long
    Dim Links() As Long
    Dim NodeSymbols() As Long
    Dim ModuleSymbols() As Long
    Dim State As BindingState
    Dim Entry As Long
    On Error GoTo StorageFailure
    SymbolCount = 0
    EntrySymbol = 0
    Diagnostic.Code = 0
    Diagnostic.Reason = 0
    Diagnostic.ModuleIndex = -1
    Diagnostic.Node = 0
    Diagnostic.TokenIndex = -1
    Diagnostic.ByteOffset = 0
    Diagnostic.Utf16Offset = 1
    Diagnostic.Line = 1
    Diagnostic.Column = 1
    If ValidateProject(Bytes, Tokens, Nodes, Modules, Counts, PackageName, Diagnostic) = False Then GoTo Rejected
    If ResizeIndex(Buckets, 32749, False) = False Then GoTo StorageFailure
    If ResizeIndex(Links, 16384, False) = False Then GoTo StorageFailure
    If ResizeIndex(NodeSymbols, Counts.NodeCount, False) = False Then GoTo StorageFailure
    If ResizeIndex(ModuleSymbols, Counts.ModuleCount, False) = False Then GoTo StorageFailure
    If ValidateTrees(Tokens, Nodes, Modules, Counts, NodeSymbols, State, Diagnostic) = False Then GoTo Rejected
    If CollectTop(Bytes, Tokens, Nodes, Modules, Counts, Candidate, Buckets, Links, NodeSymbols, ModuleSymbols, State, Diagnostic) = False Then GoTo Rejected
    If CollectMembers(Bytes, Tokens, Nodes, Counts, Candidate, Buckets, Links, NodeSymbols, State, Diagnostic) = False Then GoTo Rejected
    If CollectLocals(Bytes, Tokens, Nodes, Modules, Counts, Candidate, Buckets, Links, NodeSymbols, State, Diagnostic) = False Then GoTo Rejected
    If ResolveSignatures(Bytes, Tokens, Nodes, Counts, PackageName, Candidate, Buckets, Links, ModuleSymbols, State, Diagnostic) = False Then GoTo Rejected
    If SelectEntry(Bytes, Tokens, Nodes, Counts, Candidate, State, Diagnostic, IsExecutable, Entry) = False Then GoTo Rejected
    Symbols = Candidate
    SymbolCount = State.Count
    EntrySymbol = Entry
    TryBindDeclarations = True
    Exit Function
Rejected:
    If Diagnostic.ModuleIndex >= 0 And Diagnostic.ModuleIndex < Counts.ModuleCount Then
        If Modules(Diagnostic.ModuleIndex).ByteBase >= 0 And Modules(Diagnostic.ModuleIndex).ByteBase <= Diagnostic.ByteOffset Then
            Diagnostic.ByteOffset = Diagnostic.ByteOffset - Modules(Diagnostic.ModuleIndex).ByteBase
        End If
    End If
    Exit Function
StorageFailure:
    SymbolCount = 0
    EntrySymbol = 0
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
