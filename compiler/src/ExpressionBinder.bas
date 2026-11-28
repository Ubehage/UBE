UBE SOURCE 1 MODULE
Attribute UBE_Name = "ExpressionBinder"
' Checks retained references, values and constants without assigning source primitive authority or native layouts.
Public Type BoundExpression
    SymbolIndex As Long
    ScopeSymbol As Long
    TypeCode As Long
    TypeSymbol As Long
    ArrayRank As Long
    ConvertedType As Long
    ConvertedTypeSymbol As Long
    ReferenceAssignment As Boolean
    ArgumentMode As Long
    Writable As Boolean
    ConstantKnown As Boolean
    ConstantValue As LongLong
    AccessKind As Long
    TrustedRole As Long
    HasBounds As Boolean
    LowerBound As LongLong
    UpperBound As LongLong
    ConstantTextStart As Long
    ConstantTextLength As Long
    IsIDEContextConstant As Boolean
    IsCurrentInstance As Boolean
    InstanceReceiver As Long
End Type

Private Type ExpressionState
    Lookup As DeclarationBinder.BindingState
    Depth As Long
    ShapeMayChange As Boolean
    TextUsed As Long
End Type

' Allocates one candidate fact for every retained node.
Private Intrinsic Function ResizeFacts(ByRef Values() As BoundExpression, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeFacts.UBE_Primitive = "Array.TryResize"
End Function

' Allocates per-declaration constant evaluation states.
Private Intrinsic Function ResizeStates(ByRef Values() As Long, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeStates.UBE_Primitive = "Array.TryResize"
End Function

' Final publication transfers private candidates without allocating or failing after commit.
Private Intrinsic Function MoveFacts(ByRef Destination() As BoundExpression, ByRef Source() As BoundExpression) As Boolean
Attribute MoveFacts.UBE_Primitive = "Array.Move"
End Function

Private Intrinsic Function MoveBytes(ByRef Destination() As Byte, ByRef Source() As Byte) As Boolean
Attribute MoveBytes.UBE_Primitive = "Array.Move"
End Function

' Formats only known scalar values into the same immutable arena used by quoted literals.
Private Function AsText(ByRef F() As BoundExpression, ByRef X() As Byte, ByRef S As ExpressionState, ByVal Node As Long, ByRef Start As Long, ByRef Length As Long) As Boolean
    If Not F(Node - 1).ConstantKnown Then Exit Function
    If F(Node - 1).TypeCode = SyntaxTokens.KwString Then
        Start = F(Node - 1).ConstantTextStart
        Length = F(Node - 1).ConstantTextLength
        AsText = True
        Exit Function
    End If
    AsText = ConstantText.TryAppendScalar(F(Node - 1).ConstantValue, F(Node - 1).TypeCode, X, S.TextUsed, Start, Length)
End Function

' Locates the source module through the already assigned lexical container.
Private Function ModuleOf(ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByVal Node As Long) As Long
    On Error GoTo Failed
    If Node = 0 Then ModuleOf = -1: Exit Function
    If F(Node - 1).ScopeSymbol = 0 Then ModuleOf = -1: Exit Function
    ModuleOf = A(F(Node - 1).ScopeSymbol - 1).ModuleIndex
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Records one source-local diagnostic while retaining global node and token identities.
Private Function Reject(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Code As Long, ByVal Reason As Long, ByVal Node As Long) As Boolean
    Dim ModuleIndex As Long
    On Error GoTo Failed
    If D.Code <> 0 Then Exit Function
    ModuleIndex = ModuleOf(A, F, Node)
    D.Code = Code
    D.Reason = Reason
    D.ModuleIndex = ModuleIndex
    D.Node = Node
    If Node > 0 Then
        D.TokenIndex = N(Node - 1).FirstToken
        D.ByteOffset = N(Node - 1).ByteStart
        If ModuleIndex >= 0 Then D.ByteOffset = D.ByteOffset - M(ModuleIndex).ByteBase
        D.Utf16Offset = N(Node - 1).Utf16Start
        D.Line = N(Node - 1).Line
        D.Column = N(Node - 1).Column
    End If
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Bounds every recursive semantic descent before it can reach the native call-frame guard.
Private Function EnterBinding(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef S As ExpressionState, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Node As Long) As Boolean
    If Not DeclarationBinder.ContinueBinding(S.Lookup) Then EnterBinding = Reject(N, M, A, F, D, 104, 0, Node): Exit Function
    On Error GoTo Failed
    If S.Depth >= 64 Then EnterBinding = Reject(N, M, A, F, D, 6, 10, Node): Exit Function
    S.Depth = S.Depth + 1
    EnterBinding = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Copies value facts without changing lexical scope or surrounding argument metadata.
Private Sub CopyValue(ByRef F() As BoundExpression, ByVal Destination As Long, ByVal Source As Long)
    On Error GoTo Failed
    F(Destination - 1).SymbolIndex = F(Source - 1).SymbolIndex
    F(Destination - 1).TypeCode = F(Source - 1).TypeCode
    F(Destination - 1).TypeSymbol = F(Source - 1).TypeSymbol
    F(Destination - 1).ArrayRank = F(Source - 1).ArrayRank
    F(Destination - 1).Writable = F(Source - 1).Writable
    F(Destination - 1).ConstantKnown = F(Source - 1).ConstantKnown
    F(Destination - 1).IsIDEContextConstant = F(Source - 1).IsIDEContextConstant
    F(Destination - 1).IsCurrentInstance = F(Source - 1).IsCurrentInstance
    F(Destination - 1).InstanceReceiver = F(Source - 1).InstanceReceiver
    F(Destination - 1).ConstantValue = F(Source - 1).ConstantValue
    F(Destination - 1).ConstantTextStart = F(Source - 1).ConstantTextStart
    F(Destination - 1).ConstantTextLength = F(Source - 1).ConstantTextLength
    F(Destination - 1).AccessKind = F(Source - 1).AccessKind
    F(Destination - 1).TrustedRole = F(Source - 1).TrustedRole
    F(Destination - 1).HasBounds = F(Source - 1).HasBounds
    F(Destination - 1).LowerBound = F(Source - 1).LowerBound
    F(Destination - 1).UpperBound = F(Source - 1).UpperBound
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

' Projects declaration identity and type without treating mutable initializer facts as constants.
Private Sub SymbolValue(ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef S As ExpressionState, ByVal Node As Long, ByVal Symbol As Long)
    Dim Kind As Long
    Dim Declaration As Long
    On Error GoTo Failed
    Kind = A(Symbol - 1).Kind
    Declaration = A(Symbol - 1).DeclarationNode
    F(Node - 1).SymbolIndex = Symbol
    F(Node - 1).TypeCode = A(Symbol - 1).TypeCode
    F(Node - 1).TypeSymbol = A(Symbol - 1).TypeSymbol
    F(Node - 1).ArrayRank = A(Symbol - 1).ArrayRank
    F(Node - 1).Writable = Kind = SourceParser.VariableNode Or Kind = SourceParser.ParameterNode Or Kind = SourceParser.FieldNode Or Kind = DeclarationBinder.ResultSymbol
    F(Node - 1).ConstantKnown = False
    F(Node - 1).IsIDEContextConstant = False
    F(Node - 1).IsCurrentInstance = False
    F(Node - 1).InstanceReceiver = 0
    F(Node - 1).ConstantValue = 0
    F(Node - 1).ConstantTextStart = 0
    F(Node - 1).ConstantTextLength = 0
    F(Node - 1).TrustedRole = 0
    F(Node - 1).AccessKind = 0
    If Kind = SourceParser.VariableNode And DeclarationBinder.IsInstanceMember(A, Symbol) Then F(Node - 1).AccessKind = 4
    F(Node - 1).HasBounds = False
    If Node <> Declaration And S.ShapeMayChange = False Then
        F(Node - 1).HasBounds = F(Declaration - 1).HasBounds
        F(Node - 1).LowerBound = F(Declaration - 1).LowerBound
        F(Node - 1).UpperBound = F(Declaration - 1).UpperBound
    End If
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

' Assigns lexical scopes in a nonrecursive walk over the validated ownership tree.
Private Sub AssignScopes(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef A() As DeclarationBinder.BoundSymbol, ByRef I() As Long, ByRef F() As BoundExpression, ByRef S As ExpressionState)
    Dim ModuleIndex As Long
    Dim Root As Long
    Dim Node As Long
    Dim Child As Long
    Dim Scope As Long
    Dim Kind As Long
    On Error GoTo Failed
    Do While ModuleIndex < C.ModuleCount
        If Not DeclarationBinder.ContinueBinding(S.Lookup) Then Exit Sub
        Root = M(ModuleIndex).RootNode
        Node = Root
        Do
            If Not DeclarationBinder.ContinueBinding(S.Lookup) Then Exit Sub
            Scope = F(Node - 1).ScopeSymbol
            Kind = N(Node - 1).Kind
            If I(Node - 1) <> 0 Then SymbolValue A, F, S, Node, I(Node - 1)
            If Kind = SourceParser.ModuleNode Or Kind = SourceParser.ClassNode Or Kind = SourceParser.SubNode Or Kind = SourceParser.FunctionNode Or Kind = SourceParser.TypeNode Then Scope = I(Node - 1)
            Child = N(Node - 1).FirstChild
            If Child <> 0 Then
                F(Child - 1).ScopeSymbol = Scope
                Node = Child
            Else
                Do
                    If Node = Root Then Exit Do
                    Child = N(Node - 1).NextSibling
                    If Child <> 0 Then
                        F(Child - 1).ScopeSymbol = F(Node - 1).ScopeSymbol
                        Node = Child
                        Exit Do
                    End If
                    Node = N(Node - 1).Parent
                Loop
                If Node = Root Then Exit Do
            End If
        Loop
        ModuleIndex = ModuleIndex + 1
    Loop
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

' Identifies the reviewed support receiver/member names only after normal declaration lookup.
Private Function SupportName(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByVal Token As Long, ByVal Count As Long) As Long
    Dim C0 As Long
    Dim C1 As Long
    Dim C2 As Long
    Dim C3 As Long
    Dim C4 As Long
    Dim C5 As Long
    On Error GoTo Failed
    C0 = SyntaxTokens.SpellingByte(B, T, Token, Count, 0)
    C1 = SyntaxTokens.SpellingByte(B, T, Token, Count, 1)
    C2 = SyntaxTokens.SpellingByte(B, T, Token, Count, 2)
    C3 = SyntaxTokens.SpellingByte(B, T, Token, Count, 3)
    C4 = SyntaxTokens.SpellingByte(B, T, Token, Count, 4)
    C5 = SyntaxTokens.SpellingByte(B, T, Token, Count, 5)
    If C0 = 101 And C1 = 114 And C2 = 114 And C3 = -1 Then SupportName = 1
    If C0 = 114 And C1 = 97 And C2 = 105 And C3 = 115 And C4 = 101 And C5 = -1 Then SupportName = 2
    If C0 = 99 And C1 = 108 And C2 = 101 And C3 = 97 And C4 = 114 And C5 = -1 Then SupportName = 3
    If C0 = 110 And C1 = 117 And C2 = 109 And C3 = 98 And C4 = 101 And C5 = 114 Then
        If SyntaxTokens.SpellingByte(B, T, Token, Count, 6) = -1 Then SupportName = 4
    End If
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Binds the current identity only inside an executing instance procedure.
Private Function BindCurrentInstance(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Node As Long, ByVal Scope As Long) As Boolean
    Dim Parent As Long
    If Not DeclarationBinder.IsInstanceMember(A, Scope) Then BindCurrentInstance = Reject(N, M, A, F, D, 3, 18, Node): Exit Function
    If A(Scope - 1).Kind <> SourceParser.SubNode And A(Scope - 1).Kind <> SourceParser.FunctionNode Then BindCurrentInstance = Reject(N, M, A, F, D, 3, 18, Node): Exit Function
    Parent = N(Node - 1).Parent
    Do While Parent <> 0
        If N(Parent - 1).Kind = SourceParser.VariableNode Or N(Parent - 1).Kind = SourceParser.ConstantNode Then BindCurrentInstance = Reject(N, M, A, F, D, 3, 18, Node): Exit Function
        If N(Parent - 1).Kind = SourceParser.BodyNode Then Exit Do
        Parent = N(Parent - 1).Parent
    Loop
    F(Node - 1).IsCurrentInstance = True
    F(Node - 1).TypeCode = SyntaxTokens.KwObject
    F(Node - 1).TypeSymbol = A(Scope - 1).ScopeSymbol
    F(Node - 1).Writable = False
    BindCurrentInstance = True
End Function

' Selects the public standard-library fallback; -1 preserves ambiguity distinctly from absence.
Private Function FindStandardName(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef C As ProjectSyntax.ProjectCounts, ByRef A() As DeclarationBinder.BoundSymbol, ByRef H() As Long, ByRef L() As Long, ByRef U() As Long, ByRef Lookup As DeclarationBinder.BindingState, ByVal Token As Long) As Long
    Dim Index As Long
    Dim Candidate As Long
    Dim Selected As Long
    On Error GoTo Failed
    Do While Index < C.ModuleCount
        If Not DeclarationBinder.ContinueBinding(Lookup) Then Exit Function
        Candidate = 0
        If A(U(Index) - 1).LookupDomain = 2 And A(U(Index) - 1).Kind = SourceParser.ModuleNode Then Candidate = DeclarationBinder.FindSymbol(B, T, C.TokenCount, A, H, L, Lookup, U(Index), DeclarationBinder.ValueRegion, Token, 2)
        If Candidate <> 0 Then
            If A(Candidate - 1).Visibility = SyntaxTokens.KwPublic Then
                If Selected <> 0 Then FindStandardName = -1: Exit Function
                Selected = Candidate
            End If
        End If
        Index = Index + 1
    Loop
    If Selected = 0 Then Selected = DeclarationBinder.FindSymbol(B, T, C.TokenCount, A, H, L, Lookup, 0, DeclarationBinder.ModuleRegion, Token, 2)
    FindStandardName = Selected
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Selects one lexical namespace level; ambiguity and wrong kinds never trigger fallback.
Private Function LookupName(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef P() As Byte, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef H() As Long, ByRef L() As Long, ByRef U() As Long, ByRef S As ExpressionState, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Node As Long, ByVal Assignment As Boolean) As Boolean
    Dim Scope As Long
    Dim ModuleIndex As Long
    Dim Token As Long
    Dim Selected As Long
    Dim Candidate As Long
    Dim Index As Long
    Dim Parent As Long
    Dim Callable As Boolean
    On Error GoTo Failed
    Scope = F(Node - 1).ScopeSymbol
    ModuleIndex = ModuleOf(A, F, Node)
    Token = N(Node - 1).NameToken
    Parent = N(Node - 1).Parent
    If SyntaxTokens.TokenCode(B, T, Token, C.TokenCount) = SyntaxTokens.KwMe Then
        LookupName = BindCurrentInstance(N, M, A, F, D, Node, Scope)
        Exit Function
    End If
    If SyntaxTokens.IsIDEContextName(B, T, Token, C.TokenCount) Then
        If Parent <> 0 Then
            If N(Parent - 1).Kind = SourceParser.MemberNode And N(Parent - 1).FirstChild = Node Then
                If DeclarationBinder.PackageMatches(B, T, C.TokenCount, Token, P) Then
                    F(Node - 1).AccessKind = 3
                    LookupName = True
                    Exit Function
                End If
            End If
        End If
        F(Node - 1).TypeCode = SyntaxTokens.KwBoolean
        F(Node - 1).ConstantKnown = True
        F(Node - 1).IsIDEContextConstant = True
        F(Node - 1).ConstantValue = 0
        If M(ModuleIndex).IsInIDE Then F(Node - 1).ConstantValue = -1
        F(Node - 1).Writable = False
        LookupName = True
        Exit Function
    End If
    If Parent <> 0 Then
        If N(Parent - 1).FirstChild = Node Then Callable = N(Parent - 1).Kind = SourceParser.CallNode Or N(Parent - 1).Kind = SourceParser.ThreadStartNode
    End If
    If A(Scope - 1).Kind = SourceParser.FunctionNode Or A(Scope - 1).Kind = SourceParser.SubNode Then
        Selected = DeclarationBinder.FindSymbol(B, T, C.TokenCount, A, H, L, S.Lookup, Scope, DeclarationBinder.ValueRegion, Token, M(ModuleIndex).LookupDomain)
        If Selected <> 0 Then GoTo Found
        If Assignment Or Not Callable Then
            Selected = DeclarationBinder.FindSymbol(B, T, C.TokenCount, A, H, L, S.Lookup, Scope, DeclarationBinder.ResultRegion, Token, M(ModuleIndex).LookupDomain)
            If Selected <> 0 Then GoTo Found
        End If
    End If
    Selected = DeclarationBinder.FindSymbol(B, T, C.TokenCount, A, H, L, S.Lookup, U(ModuleIndex), DeclarationBinder.ValueRegion, Token, M(ModuleIndex).LookupDomain)
    If Selected <> 0 Then GoTo Found
    Do While Index < C.ModuleCount
        If Not DeclarationBinder.ContinueBinding(S.Lookup) Then LookupName = Reject(N, M, A, F, D, 104, 0, Node): Exit Function
        Candidate = 0
        If A(U(Index) - 1).Kind = SourceParser.ModuleNode Then Candidate = DeclarationBinder.FindSymbol(B, T, C.TokenCount, A, H, L, S.Lookup, U(Index), DeclarationBinder.ValueRegion, Token, M(ModuleIndex).LookupDomain)
        If Candidate <> 0 Then
            If A(Candidate - 1).Visibility = SyntaxTokens.KwPublic Or A(Candidate - 1).Visibility = SyntaxTokens.KwFriend Then
                If Selected <> 0 Then LookupName = Reject(N, M, A, F, D, 4, 10, Node): Exit Function
                Selected = Candidate
            End If
        End If
        Index = Index + 1
    Loop
    If Selected <> 0 Then GoTo Found
    Selected = DeclarationBinder.FindSymbol(B, T, C.TokenCount, A, H, L, S.Lookup, 0, DeclarationBinder.ModuleRegion, Token, M(ModuleIndex).LookupDomain)
    If Selected <> 0 Then GoTo Found
    If S.Lookup.CancelledObserved Then LookupName = Reject(N, M, A, F, D, 104, 0, Node): Exit Function
    If S.Lookup.Work >= 4000000 Then LookupName = Reject(N, M, A, F, D, 6, 11, Node): Exit Function
    If DeclarationBinder.PackageMatches(B, T, C.TokenCount, Token, P) Then F(Node - 1).AccessKind = 3: LookupName = True: Exit Function
    If M(ModuleIndex).LookupDomain <> 1 Then
        If DeclarationBinder.StandardPackageMatches(B, T, C.TokenCount, Token) Then F(Node - 1).AccessKind = 5: LookupName = True: Exit Function
    End If
    If M(ModuleIndex).LookupDomain = 0 Then
        Selected = FindStandardName(B, T, C, A, H, L, U, S.Lookup, Token)
        If Selected = -1 Then LookupName = Reject(N, M, A, F, D, 4, 10, Node): Exit Function
        If Selected <> 0 Then GoTo Found
    End If
    If SupportName(B, T, Token, C.TokenCount) = 1 Then F(Node - 1).TrustedRole = 1: LookupName = True: Exit Function
Found:
    If S.Lookup.CancelledObserved Then LookupName = Reject(N, M, A, F, D, 104, 0, Node): Exit Function
    If S.Lookup.Work >= 4000000 Then LookupName = Reject(N, M, A, F, D, 6, 11, Node): Exit Function
    If Selected = 0 Then LookupName = Reject(N, M, A, F, D, 2, 10, Node): Exit Function
    If DeclarationBinder.IsInstanceMember(A, Selected) And Not DeclarationBinder.IsInstanceMember(A, Scope) Then LookupName = Reject(N, M, A, F, D, 3, 18, Node): Exit Function
    SymbolValue A, F, S, Node, Selected
    LookupName = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Recognizes aggregate value facts independently of their nominal spelling.
Private Function Aggregate(ByRef F() As BoundExpression, ByVal Node As Long) As Boolean
    On Error GoTo Failed
    Aggregate = ManagedLayouts.IsRecordValue(F(Node - 1).TypeCode, F(Node - 1).TypeSymbol) Or F(Node - 1).ArrayRank <> 0
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Statically known reference compatibility; Nothing has no nominal identity.
Private Function ReferenceAssignable(ByRef F() As BoundExpression, ByVal Node As Long, ByVal DestinationSymbol As Long) As Boolean
    If F(Node - 1).TypeCode <> SyntaxTokens.KwObject Or F(Node - 1).ArrayRank <> 0 Then Exit Function
    If F(Node - 1).ConstantKnown And F(Node - 1).ConstantValue = 0 Then ReferenceAssignable = True: Exit Function
    ReferenceAssignable = DestinationSymbol = 0 Or DestinationSymbol = F(Node - 1).TypeSymbol
End Function

' Retains and validates a scalar boundary conversion without overwriting the expression value.
Private Function ConvertValue(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef X() As Byte, ByRef S As ExpressionState, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Node As Long, ByVal Destination As Long) As Boolean
    Dim Value As LongLong
    Dim Reason As Long
    On Error GoTo Failed
    If Destination = SyntaxTokens.KwVariant And F(Node - 1).ArrayRank = 0 And ManagedLayouts.IsRecordValue(F(Node - 1).TypeCode, F(Node - 1).TypeSymbol) Then
        F(Node - 1).ConvertedType = Destination
        ConvertValue = True: Exit Function
    End If
    If Aggregate(F, Node) Then ConvertValue = Reject(N, M, A, F, D, 3, 10, Node): Exit Function
    If F(Node - 1).TypeCode = SyntaxTokens.KwObject Or Destination = SyntaxTokens.KwObject Then
        If F(Node - 1).TypeCode <> Destination Then ConvertValue = Reject(N, M, A, F, D, 8, 86, Node): Exit Function
        F(Node - 1).ConvertedType = Destination
        ConvertValue = True: Exit Function
    End If
    If F(Node - 1).TypeCode = SyntaxTokens.KwVariant Or Destination = SyntaxTokens.KwVariant Then
        F(Node - 1).ConvertedType = Destination
        ConvertValue = True
        Exit Function
    End If
    If F(Node - 1).TypeCode <> SyntaxTokens.KwString And F(Node - 1).TypeCode <> SyntaxTokens.KwBoolean And Not ConstantValues.IsNumeric(F(Node - 1).TypeCode) Then ConvertValue = Reject(N, M, A, F, D, 3, 10, Node): Exit Function
    If Destination <> SyntaxTokens.KwString And Destination <> SyntaxTokens.KwBoolean And Not ConstantValues.IsNumeric(Destination) Then ConvertValue = Reject(N, M, A, F, D, 3, 10, Node): Exit Function
    F(Node - 1).ConvertedType = Destination
    If F(Node - 1).ConstantKnown And Destination <> SyntaxTokens.KwString Then
        If F(Node - 1).TypeCode = SyntaxTokens.KwString Then
            If Not ConstantValues.TryTextValue(X, F(Node - 1).ConstantTextStart, F(Node - 1).ConstantTextLength, Destination, Value) Then ConvertValue = Reject(N, M, A, F, D, 11, 10, Node): Exit Function
        Else
            If ConstantValues.TryConvert(F(Node - 1).ConstantValue, F(Node - 1).TypeCode, Destination, Value, Reason) = False Then ConvertValue = Reject(N, M, A, F, D, 11, 10, Node): Exit Function
        End If
    End If
    ConvertValue = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Selects a checked member after its receiver has been bound.
Private Function ResolveMemberValue(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef H() As Long, ByRef L() As Long, ByRef S As ExpressionState, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Node As Long, ByVal Receiver As Long) As Boolean
    Dim Symbol As Long
    Dim Selected As Long
    Dim Role As Long
    Dim Field As Boolean
    On Error GoTo Failed
    Symbol = F(Receiver - 1).SymbolIndex
    If F(Receiver - 1).ArrayRank <> 0 Then ResolveMemberValue = Reject(N, M, A, F, D, 3, 11, Node): Exit Function
    If F(Receiver - 1).TrustedRole = 1 Then
        Role = SupportName(B, T, N(Node - 1).NameToken, C.TokenCount)
        If Role < 2 Then ResolveMemberValue = Reject(N, M, A, F, D, 2, 11, Node): Exit Function
        F(Node - 1).TrustedRole = Role
        F(Node - 1).SymbolIndex = 0
        F(Node - 1).Writable = False
        If Role = 4 Then F(Node - 1).TypeCode = SyntaxTokens.KwLong
    Else
        If F(Receiver - 1).AccessKind = 5 Then
            Selected = DeclarationBinder.FindSymbol(B, T, C.TokenCount, A, H, L, S.Lookup, 0, DeclarationBinder.ModuleRegion, N(Node - 1).NameToken, 2)
        ElseIf F(Receiver - 1).AccessKind = 3 Then
            Selected = DeclarationBinder.FindSymbol(B, T, C.TokenCount, A, H, L, S.Lookup, 0, DeclarationBinder.ModuleRegion, N(Node - 1).NameToken, M(ModuleOf(A, F, Node)).LookupDomain)
        ElseIf F(Receiver - 1).TypeSymbol <> 0 Then
            If Symbol <> 0 Then
                If A(Symbol - 1).Kind = SourceParser.TypeNode Or A(Symbol - 1).Kind = SourceParser.ClassNode Then ResolveMemberValue = Reject(N, M, A, F, D, 3, 11, Node): Exit Function
            End If
            Field = True
            Selected = DeclarationBinder.FindSymbol(B, T, C.TokenCount, A, H, L, S.Lookup, F(Receiver - 1).TypeSymbol, DeclarationBinder.ValueRegion, N(Node - 1).NameToken, M(A(F(Receiver - 1).TypeSymbol - 1).ModuleIndex).LookupDomain)
        ElseIf Symbol <> 0 Then
            If A(Symbol - 1).Kind <> SourceParser.ModuleNode Then ResolveMemberValue = Reject(N, M, A, F, D, 3, 11, Node): Exit Function
            Selected = DeclarationBinder.FindSymbol(B, T, C.TokenCount, A, H, L, S.Lookup, Symbol, DeclarationBinder.ValueRegion, N(Node - 1).NameToken, M(A(Symbol - 1).ModuleIndex).LookupDomain)
        Else
            ResolveMemberValue = Reject(N, M, A, F, D, 3, 11, Node): Exit Function
        End If
        If S.Lookup.CancelledObserved Then ResolveMemberValue = Reject(N, M, A, F, D, 104, 0, Node): Exit Function
        If S.Lookup.Work >= 4000000 Then ResolveMemberValue = Reject(N, M, A, F, D, 6, 11, Node): Exit Function
        If Selected = 0 Then ResolveMemberValue = Reject(N, M, A, F, D, 2, 11, Node): Exit Function
        If M(A(Selected - 1).ModuleIndex).LookupDomain <> M(ModuleOf(A, F, Node)).LookupDomain Then
            If A(Selected - 1).Kind <> SourceParser.ModuleNode And A(Selected - 1).Visibility <> SyntaxTokens.KwPublic Then ResolveMemberValue = Reject(N, M, A, F, D, 2, 12, Node): Exit Function
        End If
        If A(Selected - 1).Visibility = SyntaxTokens.KwPrivate And A(Selected - 1).ModuleIndex <> ModuleOf(A, F, Node) Then ResolveMemberValue = Reject(N, M, A, F, D, 2, 12, Node): Exit Function
        SymbolValue A, F, S, Node, Selected
        If Field Then
            If F(Receiver - 1).TypeCode = SyntaxTokens.KwObject Then
                If Not DeclarationBinder.IsInstanceMember(A, Selected) Then ResolveMemberValue = Reject(N, M, A, F, D, 3, 11, Node): Exit Function
                F(Node - 1).InstanceReceiver = Receiver
            Else
                F(Node - 1).AccessKind = 1
                F(Node - 1).Writable = F(Receiver - 1).Writable
            End If
        End If
    End If
    ResolveMemberValue = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Resolves ordinary receivers, fields and the separately reviewed error-support receiver.
Private Function ResolveReference(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef P() As Byte, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef H() As Long, ByRef L() As Long, ByRef U() As Long, ByRef K() As Long, ByRef X() As Byte, ByRef S As ExpressionState, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Node As Long, ByVal Assignment As Boolean) As Boolean
    Dim Receiver As Long
    Dim Root As Long
    Dim Symbol As Long
    On Error GoTo Failed
    If EnterBinding(N, M, A, F, S, D, Node) = False Then Exit Function
    If N(Node - 1).Kind = SourceParser.NameNode Then
        If LookupName(B, T, N, M, C, P, A, F, H, L, U, S, D, Node, Assignment) = False Then Exit Function
    ElseIf N(Node - 1).Kind = SourceParser.MemberNode Then
        Receiver = N(Node - 1).FirstChild
        If N(Receiver - 1).Kind = SourceParser.MemberNode Then
            Root = N(Receiver - 1).FirstChild
            If N(Root - 1).Kind = SourceParser.NameNode Then
                If DeclarationBinder.PackageMatches(B, T, C.TokenCount, N(Root - 1).NameToken, P) Then
                    If LookupName(B, T, N, M, C, P, A, F, H, L, U, S, D, Root, False) = False Then Exit Function
                    Symbol = F(Root - 1).SymbolIndex
                    If Symbol <> 0 Then
                        If A(Symbol - 1).Kind = SourceParser.ModuleNode Then ResolveReference = Reject(N, M, A, F, D, 8, 10, Node): Exit Function
                    End If
                End If
            End If
        End If
        If N(Receiver - 1).Kind = SourceParser.CallNode Or N(Receiver - 1).Kind = SourceParser.GroupNode Then
            If BindExpression(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, Receiver, 0, 0) = False Then Exit Function
        Else
            If ResolveReference(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, Receiver, False) = False Then Exit Function
        End If
        If Not ResolveMemberValue(B, T, N, M, C, A, F, H, L, S, D, Node, Receiver) Then Exit Function
    Else
        ResolveReference = Reject(N, M, A, F, D, 3, 12, Node): Exit Function
    End If
    S.Depth = S.Depth - 1
    ResolveReference = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Checks rank-one indexing and rejects a known invalid index only under stable shape facts.
Private Function BindIndex(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef P() As Byte, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef H() As Long, ByRef L() As Long, ByRef U() As Long, ByRef K() As Long, ByRef X() As Byte, ByRef S As ExpressionState, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Node As Long, ByVal Receiver As Long) As Boolean
    Dim Index As Long
    Dim Value As LongLong
    Dim Reason As Long
    On Error GoTo Failed
    Index = N(Receiver - 1).NextSibling
    If Index = 0 Then BindIndex = Reject(N, M, A, F, D, 10, 10, Node): Exit Function
    If N(Index - 1).NextSibling <> 0 Then BindIndex = Reject(N, M, A, F, D, 10, 10, Node): Exit Function
    If BindExpression(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, Index, 0, SyntaxTokens.KwLongLong) = False Then Exit Function
    If ConvertValue(N, M, A, F, X, S, D, Index, SyntaxTokens.KwLongLong) = False Then Exit Function
    If F(Index - 1).ConstantKnown And F(Receiver - 1).HasBounds Then
        If ConstantValues.TryConvert(F(Index - 1).ConstantValue, F(Index - 1).TypeCode, SyntaxTokens.KwLongLong, Value, Reason) = False Then BindIndex = Reject(N, M, A, F, D, 11, 10, Index): Exit Function
        If Value < F(Receiver - 1).LowerBound Or Value > F(Receiver - 1).UpperBound Then BindIndex = Reject(N, M, A, F, D, 11, 11, Index): Exit Function
    End If
    F(Node - 1).TypeCode = F(Receiver - 1).TypeCode
    F(Node - 1).TypeSymbol = F(Receiver - 1).TypeSymbol
    F(Node - 1).ArrayRank = 0
    F(Node - 1).SymbolIndex = 0
    F(Node - 1).Writable = F(Receiver - 1).Writable
    F(Node - 1).AccessKind = 2
    F(Node - 1).HasBounds = False
    BindIndex = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Matches declaration type identity and rank independently of an array's current bounds.
Private Function SameType(ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByVal Node As Long, ByVal Symbol As Long) As Boolean
    On Error GoTo Failed
    SameType = F(Node - 1).TypeCode = A(Symbol - 1).TypeCode And F(Node - 1).TypeSymbol = A(Symbol - 1).TypeSymbol And F(Node - 1).ArrayRank = A(Symbol - 1).ArrayRank
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Validates object identity compatibility and exact ByRef reference storage.
Private Function BindReferenceArgument(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Argument As Long, ByVal Parameter As Long, ByVal Destination As Long) As Boolean
    On Error GoTo Failed
    If F(Argument - 1).ArrayRank <> 0 Then BindReferenceArgument = Reject(N, M, A, F, D, 10, 12, Argument): Exit Function
    If A(Parameter - 1).PassingMode = SyntaxTokens.KwByVal Or N(Argument - 1).Kind = SourceParser.GroupNode Then
        If F(Argument - 1).TypeCode <> SyntaxTokens.KwVariant Then
            If Not ReferenceAssignable(F, Argument, A(Parameter - 1).TypeSymbol) Then BindReferenceArgument = Reject(N, M, A, F, D, 10, 12, Argument): Exit Function
        End If
        F(Argument - 1).ArgumentMode = 1
        If A(Parameter - 1).PassingMode <> SyntaxTokens.KwByVal Then F(Argument - 1).ArgumentMode = 3
    Else
        If Not F(Argument - 1).Writable Or Not SameType(A, F, Argument, Parameter) Then BindReferenceArgument = Reject(N, M, A, F, D, 10, 12, Argument): Exit Function
        F(Argument - 1).ArgumentMode = 2
    End If
    F(Argument - 1).ConvertedType = Destination
    F(Argument - 1).ConvertedTypeSymbol = A(Parameter - 1).TypeSymbol
    BindReferenceArgument = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Validates one already-bound argument and records its passing conversion.
Private Function BindArgumentValue(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef X() As Byte, ByRef S As ExpressionState, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Argument As Long, ByVal Parameter As Long, ByVal Destination As Long, ByVal Role As Long) As Boolean
    Dim Symbol As Long
    On Error GoTo Failed
    If Role = 2 Then
        F(Argument - 1).ArgumentMode = 1
        If ConvertValue(N, M, A, F, X, S, D, Argument, Destination) = False Then Exit Function
    ElseIf A(Parameter - 1).TypeCode = SyntaxTokens.KwVariant And A(Parameter - 1).ArrayRank = 0 And ManagedLayouts.IsRecordValue(F(Argument - 1).TypeCode, F(Argument - 1).TypeSymbol) And F(Argument - 1).ArrayRank = 0 Then
        If A(Parameter - 1).PassingMode <> SyntaxTokens.KwByVal And N(Argument - 1).Kind <> SourceParser.GroupNode Then BindArgumentValue = Reject(N, M, A, F, D, 10, 12, Argument): Exit Function
        F(Argument - 1).ArgumentMode = 1
        If A(Parameter - 1).PassingMode <> SyntaxTokens.KwByVal Then F(Argument - 1).ArgumentMode = 3
        If Not ConvertValue(N, M, A, F, X, S, D, Argument, SyntaxTokens.KwVariant) Then Exit Function
    ElseIf A(Parameter - 1).TypeCode = SyntaxTokens.KwObject And A(Parameter - 1).ArrayRank = 0 Then
        If Not BindReferenceArgument(N, M, A, F, D, Argument, Parameter, Destination) Then Exit Function
    ElseIf Aggregate(F, Argument) Or ManagedLayouts.IsRecordValue(A(Parameter - 1).TypeCode, A(Parameter - 1).TypeSymbol) Or A(Parameter - 1).ArrayRank <> 0 Then
        If SameType(A, F, Argument, Parameter) = False Then BindArgumentValue = Reject(N, M, A, F, D, 10, 12, Argument): Exit Function
        If A(Parameter - 1).PassingMode = SyntaxTokens.KwByVal Then
            F(Argument - 1).ArgumentMode = 1
        Else
            If N(Argument - 1).Kind = SourceParser.GroupNode Then BindArgumentValue = Reject(N, M, A, F, D, 8, 11, Argument): Exit Function
            If F(Argument - 1).Writable = False Then BindArgumentValue = Reject(N, M, A, F, D, 10, 12, Argument): Exit Function
            F(Argument - 1).ArgumentMode = 2
        End If
        F(Argument - 1).ConvertedType = Destination
    ElseIf A(Parameter - 1).PassingMode = SyntaxTokens.KwByVal Or N(Argument - 1).Kind = SourceParser.GroupNode Then
        F(Argument - 1).ArgumentMode = 1
        If A(Parameter - 1).PassingMode <> SyntaxTokens.KwByVal Then F(Argument - 1).ArgumentMode = 3
        If ConvertValue(N, M, A, F, X, S, D, Argument, Destination) = False Then Exit Function
    Else
        If F(Argument - 1).Writable = False Or SameType(A, F, Argument, Parameter) = False Then BindArgumentValue = Reject(N, M, A, F, D, 10, 12, Argument): Exit Function
        If F(Argument - 1).AccessKind = 0 Then
            Symbol = F(Argument - 1).SymbolIndex
            If Symbol = 0 Then BindArgumentValue = Reject(N, M, A, F, D, 10, 12, Argument): Exit Function
            If A(Symbol - 1).Kind <> SourceParser.VariableNode And A(Symbol - 1).Kind <> SourceParser.ParameterNode And A(Symbol - 1).Kind <> DeclarationBinder.ResultSymbol Then BindArgumentValue = Reject(N, M, A, F, D, 10, 12, Argument): Exit Function
        End If
        F(Argument - 1).ArgumentMode = 2
        F(Argument - 1).ConvertedType = Destination
    End If
    BindArgumentValue = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Checks one selected procedure signature and retains exact argument value/alias/temporary treatment.
Private Function BindCall(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef P() As Byte, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef H() As Long, ByRef L() As Long, ByRef U() As Long, ByRef K() As Long, ByRef X() As Byte, ByRef S As ExpressionState, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Node As Long, ByVal ValueContext As Boolean) As Boolean
    Dim Callee As Long
    Dim Symbol As Long
    Dim Argument As Long
    Dim Parameter As Long
    Dim Count As Long
    Dim Expected As Long
    Dim Kind As Long
    Dim Role As Long
    Dim Destination As Long
    Dim ThreadStart As Boolean
    On Error GoTo Failed
    ThreadStart = N(Node - 1).Kind = SourceParser.ThreadStartNode
    Callee = N(Node - 1).FirstChild
    If N(Callee - 1).Kind = SourceParser.CallNode Then
        If BindExpression(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, Callee, 0, 0) = False Then Exit Function
    Else
        If ResolveReference(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, Callee, False) = False Then Exit Function
    End If
    If F(Callee - 1).ArrayRank <> 0 Then
        If ThreadStart Then BindCall = Reject(N, M, A, F, D, 3, 17, Node): Exit Function
        If ValueContext = False Then BindCall = Reject(N, M, A, F, D, 3, 14, Node): Exit Function
        BindCall = BindIndex(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, Node, Callee): Exit Function
    End If
    Symbol = F(Callee - 1).SymbolIndex
    Role = F(Callee - 1).TrustedRole
    If Role = 2 Or Role = 3 Then
        Kind = SourceParser.SubNode
        If Role = 2 Then Expected = 1
        F(Node - 1).TrustedRole = Role
    Else
        If Symbol = 0 Then BindCall = Reject(N, M, A, F, D, 3, 15, Node): Exit Function
        Kind = A(Symbol - 1).Kind
        If Kind <> SourceParser.SubNode And Kind <> SourceParser.FunctionNode Then BindCall = Reject(N, M, A, F, D, 3, 15, Node): Exit Function
        Expected = A(Symbol - 1).ParameterCount
        Parameter = A(Symbol - 1).FirstParameter
        SymbolValue A, F, S, Node, Symbol
        F(Node - 1).InstanceReceiver = F(Callee - 1).InstanceReceiver
        If ThreadStart And DeclarationBinder.IsInstanceMember(A, Symbol) Then BindCall = Reject(N, M, A, F, D, 3, 17, Node): Exit Function
        F(Node - 1).Writable = False
    End If
    If ThreadStart Then
        F(Node - 1).TypeCode = SyntaxTokens.KwLongLong
        F(Node - 1).TypeSymbol = 0
        F(Node - 1).ArrayRank = 0
    ElseIf ValueContext And Kind = SourceParser.SubNode Then
        BindCall = Reject(N, M, A, F, D, 3, 16, Node): Exit Function
    End If
    Argument = N(Callee - 1).NextSibling
    Do While Argument <> 0
        If Not DeclarationBinder.ContinueBinding(S.Lookup) Then BindCall = Reject(N, M, A, F, D, 104, 0, Node): Exit Function
        Count = Count + 1
        Argument = N(Argument - 1).NextSibling
    Loop
    If Count <> Expected Then BindCall = Reject(N, M, A, F, D, 10, 11, Node): Exit Function
    Argument = N(Callee - 1).NextSibling
    Do While Argument <> 0
        If Not DeclarationBinder.ContinueBinding(S.Lookup) Then BindCall = Reject(N, M, A, F, D, 104, 0, Node): Exit Function
        Destination = SyntaxTokens.KwLong
        If Parameter <> 0 Then Destination = A(Parameter - 1).TypeCode
        If BindExpression(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, Argument, 0, Destination) = False Then Exit Function
        If Not BindArgumentValue(N, M, A, F, X, S, D, Argument, Parameter, Destination, Role) Then Exit Function
        If Parameter <> 0 Then Parameter = A(Parameter - 1).NextParameter
        Argument = N(Argument - 1).NextSibling
    Loop
    BindCall = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Binds a decimal literal with authoritative suffix and directly attached sign semantics.
Private Function BindNumber(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Node As Long, ByVal Negated As Boolean, ByVal Destination As Long) As Boolean
    Dim Value As LongLong
    Dim TypeCode As Long
    Dim Reason As Long
    Dim Code As Long
    On Error GoTo Failed
    If N(Node - 1).NameToken = -1 Then
        TypeCode = Destination
        If Not ConstantValues.IsNumeric(TypeCode) Then TypeCode = SyntaxTokens.KwLong
    Else
        If ConstantValues.TryLiteral(B, T(N(Node - 1).NameToken), Destination, Negated, Value, TypeCode, Reason) = False Then
            Code = 11
            If Reason = 1 Then Code = 8
            BindNumber = Reject(N, M, A, F, D, Code, 20, Node): Exit Function
        End If
    End If
    F(Node - 1).TypeCode = TypeCode
    F(Node - 1).ConstantKnown = True
    F(Node - 1).ConstantValue = Value
    BindNumber = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Applies the declared earlier-constant rule without inventing cross-module declaration ordering.
Private Function ConstantDependency(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Node As Long, ByVal Symbol As Long, ByVal Required As Long) As Boolean
    On Error GoTo Failed
    If F(Node - 1).IsIDEContextConstant Then ConstantDependency = True: Exit Function
    If Symbol = 0 Then ConstantDependency = Reject(N, M, A, F, D, 11, 21, Node): Exit Function
    If A(Symbol - 1).Kind <> SourceParser.ConstantNode Then ConstantDependency = Reject(N, M, A, F, D, 11, 21, Node): Exit Function
    If A(Symbol - 1).ModuleIndex <> A(Required - 1).ModuleIndex Then ConstantDependency = Reject(N, M, A, F, D, 8, 12, Node): Exit Function
    If N(A(Symbol - 1).DeclarationNode - 1).ByteStart >= N(A(Required - 1).DeclarationNode - 1).ByteStart Then ConstantDependency = Reject(N, M, A, F, D, 11, 22, Node): Exit Function
    ConstantDependency = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Evaluates a required constant once using its declared destination type.
Private Function EvaluateConstant(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef P() As Byte, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef H() As Long, ByRef L() As Long, ByRef U() As Long, ByRef K() As Long, ByRef X() As Byte, ByRef S As ExpressionState, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Symbol As Long) As Boolean
    Dim Node As Long
    Dim Initializer As Long
    Dim Value As LongLong
    Dim Reason As Long
    On Error GoTo Failed
    Node = A(Symbol - 1).DeclarationNode
    If K(Symbol - 1) = 2 Then EvaluateConstant = True: Exit Function
    If EnterBinding(N, M, A, F, S, D, Node) = False Then Exit Function
    If K(Symbol - 1) = 1 Then EvaluateConstant = Reject(N, M, A, F, D, 11, 23, Node): Exit Function
    K(Symbol - 1) = 1
    Initializer = N(Node - 1).FirstChild
    If Initializer = 0 Then EvaluateConstant = Reject(N, M, A, F, D, 11, 24, Node): Exit Function
    If BindExpression(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, Initializer, Symbol, A(Symbol - 1).TypeCode) = False Then Exit Function
    If F(Initializer - 1).ConstantKnown = False Then EvaluateConstant = Reject(N, M, A, F, D, 11, 24, Node): Exit Function
    If ConvertValue(N, M, A, F, X, S, D, Initializer, A(Symbol - 1).TypeCode) = False Then Exit Function
    If A(Symbol - 1).TypeCode = SyntaxTokens.KwString Then
        If Not AsText(F, X, S, Initializer, F(Node - 1).ConstantTextStart, F(Node - 1).ConstantTextLength) Then EvaluateConstant = Reject(N, M, A, F, D, 7, 1, Node): Exit Function
    ElseIf F(Initializer - 1).TypeCode = SyntaxTokens.KwString Then
        If Not ConstantValues.TryTextValue(X, F(Initializer - 1).ConstantTextStart, F(Initializer - 1).ConstantTextLength, A(Symbol - 1).TypeCode, Value) Then EvaluateConstant = Reject(N, M, A, F, D, 11, 10, Node): Exit Function
    Else
        If ConstantValues.TryConvert(F(Initializer - 1).ConstantValue, F(Initializer - 1).TypeCode, A(Symbol - 1).TypeCode, Value, Reason) = False Then EvaluateConstant = Reject(N, M, A, F, D, 11, 10, Node): Exit Function
    End If
    F(Node - 1).ConstantKnown = True
    F(Node - 1).ConstantValue = Value
    K(Symbol - 1) = 2
    S.Depth = S.Depth - 1
    EvaluateConstant = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Folds text operations in their own value domain, never treating a text span as an integer.
Private Function BindTextBinary(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef X() As Byte, ByRef S As ExpressionState, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Node As Long, ByVal LeftNode As Long, ByVal RightNode As Long) As Boolean
    Dim Operator As Long
    Dim LeftStart As Long
    Dim LeftLength As Long
    Dim RightStart As Long
    Dim RightLength As Long
    Dim Order As Long
    Dim Value As LongLong
    Dim ResultType As Long
    Dim Reason As Long
    On Error GoTo Failed
    Operator = N(Node - 1).Value
    If Operator = SyntaxTokens.SymAmpersand Then
        If Not ConvertValue(N, M, A, F, X, S, D, LeftNode, SyntaxTokens.KwString) Then Exit Function
        If Not ConvertValue(N, M, A, F, X, S, D, RightNode, SyntaxTokens.KwString) Then Exit Function
        F(Node - 1).TypeCode = SyntaxTokens.KwString
    Else
        If F(LeftNode - 1).TypeCode <> SyntaxTokens.KwString Or F(RightNode - 1).TypeCode <> SyntaxTokens.KwString Then BindTextBinary = Reject(N, M, A, F, D, 8, 14, Node): Exit Function
        If Operator <> SyntaxTokens.SymEqual And Operator <> SyntaxTokens.SymNotEqual And Operator <> SyntaxTokens.SymLess And Operator <> SyntaxTokens.SymGreater And Operator <> SyntaxTokens.SymLessEqual And Operator <> SyntaxTokens.SymGreaterEqual Then BindTextBinary = Reject(N, M, A, F, D, 8, 14, Node): Exit Function
        F(LeftNode - 1).ConvertedType = SyntaxTokens.KwString
        F(RightNode - 1).ConvertedType = SyntaxTokens.KwString
        F(Node - 1).TypeCode = SyntaxTokens.KwBoolean
    End If
    If F(LeftNode - 1).ConstantKnown And F(RightNode - 1).ConstantKnown Then
        If Not AsText(F, X, S, LeftNode, LeftStart, LeftLength) Then BindTextBinary = Reject(N, M, A, F, D, 7, 1, Node): Exit Function
        If Not AsText(F, X, S, RightNode, RightStart, RightLength) Then BindTextBinary = Reject(N, M, A, F, D, 7, 1, Node): Exit Function
        If Operator = SyntaxTokens.SymAmpersand Then
            If Not ConstantText.TryConcatenate(X, S.TextUsed, LeftStart, LeftLength, RightStart, RightLength, F(Node - 1).ConstantTextStart, F(Node - 1).ConstantTextLength) Then BindTextBinary = Reject(N, M, A, F, D, 7, 1, Node): Exit Function
        Else
            If Not ConstantText.TryCompare(X, S.TextUsed, LeftStart, LeftLength, RightStart, RightLength, Order) Then BindTextBinary = Reject(N, M, A, F, D, 7, 1, Node): Exit Function
            If Not ConstantValues.TryBinary(Operator, Order, SyntaxTokens.KwLong, 0, SyntaxTokens.KwLong, Value, ResultType, Reason) Then BindTextBinary = Reject(N, M, A, F, D, 11, 25, Node): Exit Function
            F(Node - 1).ConstantValue = Value
        End If
        F(Node - 1).ConstantKnown = True
    End If
    BindTextBinary = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Selects scalar operator domains and folds only independently proven typed operands.
Private Function BindBinary(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef P() As Byte, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef H() As Long, ByRef L() As Long, ByRef U() As Long, ByRef K() As Long, ByRef X() As Byte, ByRef S As ExpressionState, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Node As Long, ByVal Required As Long, ByVal Destination As Long) As Boolean
    Dim LeftNode As Long
    Dim RightNode As Long
    Dim Operator As Long
    Dim Context As Long
    Dim Selected As Long
    Dim ResultType As Long
    Dim Value As LongLong
    Dim Reason As Long
    Dim Code As Long
    Dim Comparison As Boolean
    On Error GoTo Failed
    LeftNode = N(Node - 1).FirstChild
    RightNode = N(LeftNode - 1).NextSibling
    Operator = N(Node - 1).Value
    If Operator = SyntaxTokens.SymPlus Or Operator = SyntaxTokens.SymMinus Or Operator = SyntaxTokens.SymStar Or Operator = SyntaxTokens.SymBackslash Or Operator = SyntaxTokens.KwMod Or Operator = SyntaxTokens.KwAnd Or Operator = SyntaxTokens.KwOr Then Context = Destination
    If BindExpression(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, LeftNode, Required, Context) = False Then Exit Function
    If BindExpression(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, RightNode, Required, Context) = False Then Exit Function
    If Operator = SyntaxTokens.KwIs Or Operator = SyntaxTokens.KwIsNot Then
        If F(LeftNode - 1).ArrayRank <> 0 Or F(RightNode - 1).ArrayRank <> 0 Or F(LeftNode - 1).TypeCode <> SyntaxTokens.KwObject Or F(RightNode - 1).TypeCode <> SyntaxTokens.KwObject Then BindBinary = Reject(N, M, A, F, D, 3, 17, Node): Exit Function
        F(Node - 1).TypeCode = SyntaxTokens.KwBoolean
        BindBinary = True: Exit Function
    End If
    If F(LeftNode - 1).TypeCode = SyntaxTokens.KwObject Or F(RightNode - 1).TypeCode = SyntaxTokens.KwObject Then BindBinary = Reject(N, M, A, F, D, 8, 86, Node): Exit Function
    If Aggregate(F, LeftNode) Or Aggregate(F, RightNode) Then
        If F(LeftNode - 1).ArrayRank <> 0 Or F(RightNode - 1).ArrayRank <> 0 Then BindBinary = Reject(N, M, A, F, D, 8, 13, Node): Exit Function
        If F(LeftNode - 1).TypeSymbol = 0 Or F(LeftNode - 1).TypeSymbol <> F(RightNode - 1).TypeSymbol Then BindBinary = Reject(N, M, A, F, D, 3, 17, Node): Exit Function
        If Operator <> SyntaxTokens.SymEqual And Operator <> SyntaxTokens.SymNotEqual Then BindBinary = Reject(N, M, A, F, D, 3, 17, Node): Exit Function
        ' Signature admission excludes array fields; all remaining fields are comparable scalars or nominal records, including recursive edges.
        F(Node - 1).TypeCode = SyntaxTokens.KwBoolean
        BindBinary = True: Exit Function
    End If
    If Operator = SyntaxTokens.SymAmpersand Or F(LeftNode - 1).TypeCode = SyntaxTokens.KwString Or F(RightNode - 1).TypeCode = SyntaxTokens.KwString Then
        BindBinary = BindTextBinary(N, M, A, F, X, S, D, Node, LeftNode, RightNode): Exit Function
    End If
    Selected = ConstantValues.BinaryType(F(LeftNode - 1).TypeCode, F(RightNode - 1).TypeCode)
    If Selected = 0 Then BindBinary = Reject(N, M, A, F, D, 8, 14, Node): Exit Function
    If Operator = SyntaxTokens.SymSlash Or Operator = SyntaxTokens.SymCaret Then
        If Selected = SyntaxTokens.KwBoolean Then BindBinary = Reject(N, M, A, F, D, 8, 14, Node): Exit Function
        Selected = SyntaxTokens.KwDouble
    End If
    If ConstantValues.IsFloating(Selected) Then
        If Operator = SyntaxTokens.KwAnd Or Operator = SyntaxTokens.KwOr Then BindBinary = Reject(N, M, A, F, D, 8, 14, Node): Exit Function
        If Operator = SyntaxTokens.SymBackslash Or Operator = SyntaxTokens.KwMod Then Selected = SyntaxTokens.KwLongLong
    End If
    Comparison = Operator = SyntaxTokens.SymEqual Or Operator = SyntaxTokens.SymNotEqual Or Operator = SyntaxTokens.SymLess Or Operator = SyntaxTokens.SymGreater Or Operator = SyntaxTokens.SymLessEqual Or Operator = SyntaxTokens.SymGreaterEqual
    If Comparison = False And Operator <> SyntaxTokens.SymPlus And Operator <> SyntaxTokens.SymMinus And Operator <> SyntaxTokens.SymStar And Operator <> SyntaxTokens.SymSlash And Operator <> SyntaxTokens.SymCaret And Operator <> SyntaxTokens.SymBackslash And Operator <> SyntaxTokens.KwMod And Operator <> SyntaxTokens.KwAnd And Operator <> SyntaxTokens.KwOr Then BindBinary = Reject(N, M, A, F, D, 8, 14, Node): Exit Function
    If Selected = SyntaxTokens.KwBoolean Then
        If Operator <> SyntaxTokens.KwAnd And Operator <> SyntaxTokens.KwOr And Operator <> SyntaxTokens.SymEqual And Operator <> SyntaxTokens.SymNotEqual Then BindBinary = Reject(N, M, A, F, D, 8, 14, Node): Exit Function
    End If
    If Operator = SyntaxTokens.SymSlash Or Operator = SyntaxTokens.SymBackslash Or Operator = SyntaxTokens.KwMod Then
        If F(RightNode - 1).ConstantKnown Then
            If Not ConstantValues.TryConvert(F(RightNode - 1).ConstantValue, F(RightNode - 1).TypeCode, Selected, Value, Reason) Then BindBinary = Reject(N, M, A, F, D, 11, 25, Node): Exit Function
            If Operator = SyntaxTokens.SymSlash Then Value = Value And 9223372036854775807&&
            If Value = 0 Then BindBinary = Reject(N, M, A, F, D, 11, 25, Node): Exit Function
        End If
    End If
    F(Node - 1).TypeCode = Selected
    If Comparison Then F(Node - 1).TypeCode = SyntaxTokens.KwBoolean
    F(LeftNode - 1).ConvertedType = Selected
    F(RightNode - 1).ConvertedType = Selected
    If F(LeftNode - 1).ConstantKnown And F(RightNode - 1).ConstantKnown Then
        If ConstantValues.TryBinary(Operator, F(LeftNode - 1).ConstantValue, F(LeftNode - 1).TypeCode, F(RightNode - 1).ConstantValue, F(RightNode - 1).TypeCode, Value, ResultType, Reason) = False Then
            Code = 11
            If Reason = 1 Then Code = 8
            BindBinary = Reject(N, M, A, F, D, Code, 25, Node): Exit Function
        End If
        F(Node - 1).ConstantKnown = True
        F(Node - 1).ConstantValue = Value
    End If
    BindBinary = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Binds one typed expression and keeps pre-conversion constants separate from boundary conversions.
Private Function BindUnary(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef P() As Byte, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef H() As Long, ByRef L() As Long, ByRef U() As Long, ByRef K() As Long, ByRef X() As Byte, ByRef S As ExpressionState, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Node As Long, ByVal Required As Long, ByVal Destination As Long) As Boolean
    Dim Child As Long
    Dim Value As LongLong
    Dim TypeCode As Long
    Dim Reason As Long
    Dim Code As Long
    On Error GoTo Failed
        Child = N(Node - 1).FirstChild
        If N(Node - 1).Value <> SyntaxTokens.SymPlus And N(Node - 1).Value <> SyntaxTokens.SymMinus And N(Node - 1).Value <> SyntaxTokens.KwNot Then BindUnary = Reject(N, M, A, F, D, 8, 14, Node): Exit Function
        If N(Node - 1).Value = SyntaxTokens.SymMinus And N(Child - 1).Kind = SourceParser.NumberNode Then
            If BindNumber(B, T, N, M, A, F, D, Child, True, Destination) = False Then Exit Function
            CopyValue F, Node, Child
            F(Node - 1).TypeCode = ConstantValues.PromotedType(F(Node - 1).TypeCode)
            F(Child - 1).ConvertedType = F(Node - 1).TypeCode
            F(Child - 1).ConstantKnown = False
            F(Child - 1).ConstantValue = 0
        Else
            If BindExpression(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, Child, Required, Destination) = False Then Exit Function
            If Aggregate(F, Child) Then BindUnary = Reject(N, M, A, F, D, 3, 19, Node): Exit Function
            If F(Child - 1).TypeCode = SyntaxTokens.KwString Or F(Child - 1).TypeCode = SyntaxTokens.KwObject Then BindUnary = Reject(N, M, A, F, D, 8, 14, Node): Exit Function
            If ConstantValues.IsFloating(F(Child - 1).TypeCode) And N(Node - 1).Value = SyntaxTokens.KwNot Then BindUnary = Reject(N, M, A, F, D, 8, 14, Node): Exit Function
            If F(Child - 1).TypeCode = SyntaxTokens.KwBoolean And N(Node - 1).Value <> SyntaxTokens.KwNot Then BindUnary = Reject(N, M, A, F, D, 8, 14, Node): Exit Function
            CopyValue F, Node, Child
            F(Node - 1).TypeCode = ConstantValues.PromotedType(F(Child - 1).TypeCode)
            F(Child - 1).ConvertedType = F(Node - 1).TypeCode
            If F(Child - 1).ConstantKnown Then
                If ConstantValues.TryUnary(N(Node - 1).Value, F(Child - 1).ConstantValue, F(Child - 1).TypeCode, Value, TypeCode, Reason) = False Then
                    Code = 11
                    If Reason = 1 Then Code = 8
                    BindUnary = Reject(N, M, A, F, D, Code, 26, Node): Exit Function
                End If
                F(Node - 1).ConstantValue = Value
            End If
        End If
        F(Node - 1).Writable = False
        F(Node - 1).SymbolIndex = 0
        F(Node - 1).AccessKind = 0
        F(Node - 1).TrustedRole = 0
    BindUnary = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

Private Function BindExpression(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef P() As Byte, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef H() As Long, ByRef L() As Long, ByRef U() As Long, ByRef K() As Long, ByRef X() As Byte, ByRef S As ExpressionState, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Node As Long, ByVal Required As Long, ByVal Destination As Long) As Boolean
    Dim Kind As Long
    Dim Symbol As Long
    Dim Child As Long
    Dim Value As LongLong
    Dim TypeCode As Long
    Dim Reason As Long
    Dim Code As Long
    On Error GoTo Failed
    If EnterBinding(N, M, A, F, S, D, Node) = False Then Exit Function
    Kind = N(Node - 1).Kind
    If Kind = SourceParser.NumberNode Then
        If BindNumber(B, T, N, M, A, F, D, Node, False, Destination) = False Then Exit Function
    ElseIf Kind = SourceParser.BooleanNode Then
        F(Node - 1).TypeCode = SyntaxTokens.KwBoolean
        F(Node - 1).ConstantKnown = True
        F(Node - 1).ConstantValue = 0
        If N(Node - 1).Value = SyntaxTokens.KwTrue Then F(Node - 1).ConstantValue = -1
    ElseIf Kind = SourceParser.StringNode Then
        If Not ConstantText.TryAppendLiteral(B, N(Node - 1).ByteStart, N(Node - 1).ByteLength, X, S.TextUsed, F(Node - 1).ConstantTextStart, F(Node - 1).ConstantTextLength) Then BindExpression = Reject(N, M, A, F, D, 7, 1, Node): Exit Function
        F(Node - 1).TypeCode = SyntaxTokens.KwString
        F(Node - 1).ConstantKnown = True
    ElseIf Kind = SourceParser.NothingNode Then
        If Required <> 0 Then BindExpression = Reject(N, M, A, F, D, 11, 27, Node): Exit Function
        F(Node - 1).TypeCode = SyntaxTokens.KwObject
        F(Node - 1).ConstantKnown = True
        F(Node - 1).ConstantValue = 0
    ElseIf Kind = SourceParser.NewObjectNode Then
        If Required <> 0 Then BindExpression = Reject(N, M, A, F, D, 11, 27, Node): Exit Function
        Code = ModuleOf(A, F, Node)
        Symbol = DeclarationBinder.ResolveTypeNode(B, T, N, C, P, A, H, L, U, S.Lookup, D, Node, Code, A(F(Node - 1).ScopeSymbol - 1).LookupDomain)
        If Symbol = 0 Then
            If D.ModuleIndex >= 0 Then D.ByteOffset = D.ByteOffset - M(D.ModuleIndex).ByteBase
            Exit Function
        End If
        If A(Symbol - 1).Kind <> SourceParser.ClassNode Then BindExpression = Reject(N, M, A, F, D, 3, 20, Node): Exit Function
        F(Node - 1).TypeCode = SyntaxTokens.KwObject
        F(Node - 1).TypeSymbol = Symbol
    ElseIf Kind = SourceParser.NameNode Or Kind = SourceParser.MemberNode Then
        If ResolveReference(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, Node, False) = False Then Exit Function
        Symbol = F(Node - 1).SymbolIndex
        If Required <> 0 Then
            If ConstantDependency(N, M, A, F, D, Node, Symbol, Required) = False Then Exit Function
        End If
        If F(Node - 1).TrustedRole <> 4 And Not F(Node - 1).IsIDEContextConstant And Not F(Node - 1).IsCurrentInstance Then
            If Symbol = 0 Then BindExpression = Reject(N, M, A, F, D, 3, 18, Node): Exit Function
            Kind = A(Symbol - 1).Kind
            If Kind = SourceParser.ConstantNode Then
                If EvaluateConstant(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, Symbol) = False Then Exit Function
                F(Node - 1).ConstantKnown = True
                F(Node - 1).ConstantValue = F(A(Symbol - 1).DeclarationNode - 1).ConstantValue
                F(Node - 1).ConstantTextStart = F(A(Symbol - 1).DeclarationNode - 1).ConstantTextStart
                F(Node - 1).ConstantTextLength = F(A(Symbol - 1).DeclarationNode - 1).ConstantTextLength
            ElseIf Kind <> SourceParser.VariableNode And Kind <> SourceParser.ParameterNode And Kind <> SourceParser.FieldNode And Kind <> DeclarationBinder.ResultSymbol Then
                BindExpression = Reject(N, M, A, F, D, 3, 18, Node): Exit Function
            End If
        End If
    ElseIf Kind = SourceParser.GroupNode Then
        Child = N(Node - 1).FirstChild
        If BindExpression(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, Child, Required, Destination) = False Then Exit Function
        CopyValue F, Node, Child
        F(Node - 1).Writable = False
    ElseIf Kind = SourceParser.UnaryNode Then
        If Not BindUnary(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, Node, Required, Destination) Then Exit Function
    ElseIf Kind = SourceParser.BinaryNode Then
        If BindBinary(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, Node, Required, Destination) = False Then Exit Function
    ElseIf Kind = SourceParser.CallNode Or Kind = SourceParser.ThreadStartNode Then
        If Required <> 0 Then BindExpression = Reject(N, M, A, F, D, 11, 27, Node): Exit Function
        If BindCall(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, Node, True) = False Then Exit Function
    Else
        BindExpression = Reject(N, M, A, F, D, 3, 20, Node): Exit Function
    End If
    S.Depth = S.Depth - 1
    BindExpression = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Finds the initializer following a declaration's optional rank-one shape.
Public Function InitializerNode(ByRef N() As SourceParser.SyntaxNode, ByVal Node As Long) As Long
    Dim Child As Long
    On Error GoTo Failed
    Child = N(Node - 1).FirstChild
    If Child <> 0 Then
        If N(Child - 1).Kind = SourceParser.ArrayShapeNode Then Child = N(Child - 1).NextSibling
    End If
    InitializerNode = Child
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Binds Set after its target and source expressions have been resolved.
Private Function BindReferenceAssignment(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Node As Long, ByVal Target As Long, ByVal ValueNode As Long) As Boolean
    On Error GoTo Failed
    If F(ValueNode - 1).ArrayRank <> 0 Then BindReferenceAssignment = Reject(N, M, A, F, D, 3, 22, Node): Exit Function
    If N(Node - 1).Kind <> SourceParser.AssignmentNode Or N(Node - 1).Value <> SyntaxTokens.KwSet Then BindReferenceAssignment = Reject(N, M, A, F, D, 3, 22, Node): Exit Function
    If F(Target - 1).TypeCode = SyntaxTokens.KwVariant Then
        If F(ValueNode - 1).TypeCode <> SyntaxTokens.KwObject And F(ValueNode - 1).TypeCode <> SyntaxTokens.KwVariant Then BindReferenceAssignment = Reject(N, M, A, F, D, 3, 22, Node): Exit Function
    ElseIf F(Target - 1).TypeCode = SyntaxTokens.KwObject Then
        If F(ValueNode - 1).TypeCode <> SyntaxTokens.KwVariant Then
            If Not ReferenceAssignable(F, ValueNode, F(Target - 1).TypeSymbol) Then BindReferenceAssignment = Reject(N, M, A, F, D, 3, 22, Node): Exit Function
        End If
    Else
        BindReferenceAssignment = Reject(N, M, A, F, D, 3, 22, Node): Exit Function
    End If
    If Node <> Target Then CopyValue F, Node, Target
    F(Node - 1).ConstantKnown = False
    F(ValueNode - 1).ConvertedType = F(Target - 1).TypeCode
    F(ValueNode - 1).ConvertedTypeSymbol = F(Target - 1).TypeSymbol
    F(ValueNode - 1).ReferenceAssignment = True
    BindReferenceAssignment = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Converts a bound scalar assignment and retains its checked constant value.
Private Function BindScalarAssignment(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef X() As Byte, ByRef S As ExpressionState, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Node As Long, ByVal Target As Long, ByVal ValueNode As Long) As Boolean
    Dim Value As LongLong
    Dim Reason As Long
    On Error GoTo Failed
    If ConvertValue(N, M, A, F, X, S, D, ValueNode, F(Target - 1).TypeCode) = False Then Exit Function
    F(Node - 1).TypeCode = F(Target - 1).TypeCode
    F(Node - 1).SymbolIndex = F(Target - 1).SymbolIndex
    If F(ValueNode - 1).ConstantKnown And F(Target - 1).TypeCode <> SyntaxTokens.KwVariant Then
        If F(Target - 1).TypeCode = SyntaxTokens.KwString Then
            If Not AsText(F, X, S, ValueNode, F(Node - 1).ConstantTextStart, F(Node - 1).ConstantTextLength) Then BindScalarAssignment = Reject(N, M, A, F, D, 7, 1, Node): Exit Function
        ElseIf F(ValueNode - 1).TypeCode = SyntaxTokens.KwString Then
            If Not ConstantValues.TryTextValue(X, F(ValueNode - 1).ConstantTextStart, F(ValueNode - 1).ConstantTextLength, F(Target - 1).TypeCode, Value) Then BindScalarAssignment = Reject(N, M, A, F, D, 11, 10, Node): Exit Function
        Else
            If ConstantValues.TryConvert(F(ValueNode - 1).ConstantValue, F(ValueNode - 1).TypeCode, F(Target - 1).TypeCode, Value, Reason) = False Then BindScalarAssignment = Reject(N, M, A, F, D, 11, 10, Node): Exit Function
        End If
        F(Node - 1).ConstantKnown = True
        F(Node - 1).ConstantValue = Value
    End If
    BindScalarAssignment = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Applies assignment conversions after both expressions have been bound in order.
Private Function BindAssignedValue(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef X() As Byte, ByRef S As ExpressionState, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Node As Long, ByVal Target As Long, ByVal ValueNode As Long) As Boolean
    On Error GoTo Failed
    If F(Target - 1).ArrayRank = 0 And (F(Target - 1).TypeCode = SyntaxTokens.KwObject Or F(ValueNode - 1).TypeCode = SyntaxTokens.KwObject Or N(Node - 1).Value = SyntaxTokens.KwSet) Then
        BindAssignedValue = BindReferenceAssignment(N, M, A, F, D, Node, Target, ValueNode): Exit Function
    End If
    If N(Node - 1).Kind = SourceParser.AssignmentNode And N(Node - 1).Value = SyntaxTokens.KwSet Then BindAssignedValue = Reject(N, M, A, F, D, 3, 22, Node): Exit Function
    If F(Target - 1).ArrayRank = 0 And F(ValueNode - 1).ArrayRank = 0 Then
        If F(Target - 1).TypeCode = SyntaxTokens.KwVariant And ManagedLayouts.IsRecordValue(F(ValueNode - 1).TypeCode, F(ValueNode - 1).TypeSymbol) Then
            If Not ConvertValue(N, M, A, F, X, S, D, ValueNode, SyntaxTokens.KwVariant) Then Exit Function
            If Node <> Target Then CopyValue F, Node, Target
            F(Node - 1).ConstantKnown = False
            BindAssignedValue = True: Exit Function
        ElseIf ManagedLayouts.IsRecordValue(F(Target - 1).TypeCode, F(Target - 1).TypeSymbol) And F(ValueNode - 1).TypeCode = SyntaxTokens.KwVariant Then
            F(ValueNode - 1).ConvertedType = 0
            If Node <> Target Then CopyValue F, Node, Target
            F(Node - 1).ConstantKnown = False
            BindAssignedValue = True: Exit Function
        End If
    End If
    If Aggregate(F, Target) Or Aggregate(F, ValueNode) Then
        If F(Target - 1).TypeCode <> F(ValueNode - 1).TypeCode Or F(Target - 1).TypeSymbol <> F(ValueNode - 1).TypeSymbol Or F(Target - 1).ArrayRank <> F(ValueNode - 1).ArrayRank Then BindAssignedValue = Reject(N, M, A, F, D, 3, 22, Node): Exit Function
        If Node <> Target Then CopyValue F, Node, Target
        F(Node - 1).ConstantKnown = False
        F(ValueNode - 1).ConvertedType = F(Target - 1).TypeCode
    Else
        If Not BindScalarAssignment(N, M, A, F, X, S, D, Node, Target, ValueNode) Then Exit Function
    End If
    BindAssignedValue = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Checks destination identity and retains converted constant facts without making mutable storage constant.
Private Function BindAssignment(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef P() As Byte, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef H() As Long, ByRef L() As Long, ByRef U() As Long, ByRef K() As Long, ByRef X() As Byte, ByRef S As ExpressionState, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Node As Long) As Boolean
    Dim Target As Long
    Dim ValueNode As Long
    On Error GoTo Failed
    If N(Node - 1).Kind = SourceParser.VariableNode Then
        Target = Node
        ValueNode = InitializerNode(N, Node)
        If ValueNode = 0 Then BindAssignment = True: Exit Function
    Else
        Target = N(Node - 1).FirstChild
        ValueNode = N(Target - 1).NextSibling
        If N(Target - 1).Kind = SourceParser.CallNode Then
            If BindCall(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, Target, True) = False Then Exit Function
        Else
            If ResolveReference(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, Target, True) = False Then Exit Function
        End If
        If F(Target - 1).Writable = False Then BindAssignment = Reject(N, M, A, F, D, 3, 21, Target): Exit Function
    End If
    If BindExpression(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, ValueNode, 0, F(Target - 1).TypeCode) = False Then Exit Function
    BindAssignment = BindAssignedValue(N, M, A, F, X, S, D, Node, Target, ValueNode)
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Resolves branches in the containing procedure's separate label namespace.
Private Function BindBranch(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef H() As Long, ByRef L() As Long, ByRef S As ExpressionState, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Node As Long) As Boolean
    Dim Symbol As Long
    On Error GoTo Failed
    If N(Node - 1).Kind = SourceParser.OnErrorNode And N(Node - 1).Value <> 2 Then BindBranch = True: Exit Function
    Symbol = DeclarationBinder.FindSymbol(B, T, C.TokenCount, A, H, L, S.Lookup, F(Node - 1).ScopeSymbol, DeclarationBinder.LabelRegion, N(Node - 1).NameToken, M(ModuleOf(A, F, Node)).LookupDomain)
    If S.Lookup.CancelledObserved Then BindBranch = Reject(N, M, A, F, D, 104, 0, Node): Exit Function
    If S.Lookup.Work >= 4000000 Then BindBranch = Reject(N, M, A, F, D, 6, 11, Node): Exit Function
    If Symbol = 0 Then BindBranch = Reject(N, M, A, F, D, 12, 10, Node): Exit Function
    F(Node - 1).SymbolIndex = Symbol
    BindBranch = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Validates declaration bounds independently of later shape-proof invalidation.
Private Function BindBounds(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef P() As Byte, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef H() As Long, ByRef L() As Long, ByRef U() As Long, ByRef K() As Long, ByRef X() As Byte, ByRef S As ExpressionState, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Symbol As Long) As Boolean
    Dim Node As Long
    Dim Shape As Long
    Dim LowerNode As Long
    Dim UpperNode As Long
    Dim Lower As LongLong
    Dim Upper As LongLong
    Dim Difference As LongLong
    Dim TypeCode As Long
    Dim Reason As Long
    On Error GoTo Failed
    Node = A(Symbol - 1).DeclarationNode
    Shape = N(Node - 1).FirstChild
    If Shape = 0 Then BindBounds = True: Exit Function
    If N(Shape - 1).Kind <> SourceParser.ArrayShapeNode Or N(Shape - 1).Value = 2 Then BindBounds = True: Exit Function
    LowerNode = N(Shape - 1).FirstChild
    UpperNode = N(LowerNode - 1).NextSibling
    If BindExpression(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, LowerNode, Symbol, SyntaxTokens.KwLongLong) = False Then Exit Function
    If BindExpression(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, UpperNode, Symbol, SyntaxTokens.KwLongLong) = False Then Exit Function
    If F(LowerNode - 1).ConstantKnown = False Or F(UpperNode - 1).ConstantKnown = False Then BindBounds = Reject(N, M, A, F, D, 11, 28, Node): Exit Function
    If ConvertValue(N, M, A, F, X, S, D, LowerNode, SyntaxTokens.KwLongLong) = False Then Exit Function
    If ConvertValue(N, M, A, F, X, S, D, UpperNode, SyntaxTokens.KwLongLong) = False Then Exit Function
    If ConstantValues.TryConvert(F(LowerNode - 1).ConstantValue, F(LowerNode - 1).TypeCode, SyntaxTokens.KwLongLong, Lower, Reason) = False Then BindBounds = Reject(N, M, A, F, D, 11, 10, Node): Exit Function
    If ConstantValues.TryConvert(F(UpperNode - 1).ConstantValue, F(UpperNode - 1).TypeCode, SyntaxTokens.KwLongLong, Upper, Reason) = False Then BindBounds = Reject(N, M, A, F, D, 11, 10, Node): Exit Function
    If Lower > Upper Then BindBounds = Reject(N, M, A, F, D, 11, 29, Node): Exit Function
    If ConstantValues.TryBinary(SyntaxTokens.SymMinus, Upper, SyntaxTokens.KwLongLong, Lower, SyntaxTokens.KwLongLong, Difference, TypeCode, Reason) = False Then BindBounds = Reject(N, M, A, F, D, 6, 12, Node): Exit Function
    If Difference >= 1048576 Then BindBounds = Reject(N, M, A, F, D, 6, 12, Node): Exit Function
    F(Node - 1).HasBounds = True
    F(Node - 1).LowerBound = Lower
    F(Node - 1).UpperBound = Upper
    F(Shape - 1).HasBounds = True
    F(Shape - 1).LowerBound = Lower
    F(Shape - 1).UpperBound = Upper
    BindBounds = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Determines shape effects before ordinary expression binding, avoiding statement-order-dependent proofs.
Private Function ShapeEffects(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef P() As Byte, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef H() As Long, ByRef L() As Long, ByRef U() As Long, ByRef K() As Long, ByRef X() As Byte, ByRef S As ExpressionState, ByRef D As DeclarationBinder.BindingDiagnostic) As Boolean
    Dim Node As Long = 1
    Dim Target As Long
    Dim Changed As Boolean
    On Error GoTo Failed
    S.ShapeMayChange = True
    Do While Node <= C.NodeCount
        If Not DeclarationBinder.ContinueBinding(S.Lookup) Then ShapeEffects = Reject(N, M, A, F, D, 104, 0, Node): Exit Function
        If N(Node - 1).IsIntrinsic Then Changed = True: Exit Do
        If N(Node - 1).Kind = SourceParser.VariableNode And F(Node - 1).ArrayRank <> 0 Then
            If InitializerNode(N, Node) <> 0 Then Changed = True: Exit Do
        End If
        Node = Node + 1
    Loop
    Node = 1
    If Changed = False Then
        Do While Node <= C.NodeCount
            If Not DeclarationBinder.ContinueBinding(S.Lookup) Then ShapeEffects = Reject(N, M, A, F, D, 104, 0, Node): Exit Function
            If N(Node - 1).Kind = SourceParser.AssignmentNode Then
                Target = N(Node - 1).FirstChild
                If N(Target - 1).Kind = SourceParser.NameNode Or N(Target - 1).Kind = SourceParser.MemberNode Then
                    If ResolveReference(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, Target, True) = False Then Exit Function
                    If F(Target - 1).ArrayRank <> 0 Then Changed = True: Exit Do
                End If
            End If
            Node = Node + 1
        Loop
    End If
    S.ShapeMayChange = Changed
    ShapeEffects = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Stable record paths retain their receiver identity without evaluating array-element aliases.
Private Function StableLoopVariable(ByRef N() As SourceParser.SyntaxNode, ByRef F() As BoundExpression, ByVal Node As Long) As Boolean
    Do While F(Node - 1).AccessKind = 1
        Node = N(Node - 1).FirstChild
    Loop
    StableLoopVariable = F(Node - 1).AccessKind = 0
End Function

Private Function SameLoopVariable(ByRef N() As SourceParser.SyntaxNode, ByRef F() As BoundExpression, ByVal LeftNode As Long, ByVal RightNode As Long) As Boolean
    Do
        If F(LeftNode - 1).AccessKind <> F(RightNode - 1).AccessKind Or F(LeftNode - 1).SymbolIndex <> F(RightNode - 1).SymbolIndex Then Exit Function
        If F(LeftNode - 1).AccessKind = 0 Then SameLoopVariable = True: Exit Function
        If F(LeftNode - 1).AccessKind <> 1 Then Exit Function
        LeftNode = N(LeftNode - 1).FirstChild
        RightNode = N(RightNode - 1).FirstChild
    Loop
End Function

' Resolves a counted-loop variable and converts each evaluated-once header operand.
Private Function BindFor(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef P() As Byte, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef H() As Long, ByRef L() As Long, ByRef U() As Long, ByRef K() As Long, ByRef X() As Byte, ByRef S As ExpressionState, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Node As Long) As Boolean
    Dim Target As Long
    Dim Child As Long
    Dim Parent As Long
    Dim Other As Long
    On Error GoTo Failed
    Target = N(Node - 1).FirstChild
    If Not ResolveReference(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, Target, True) Then Exit Function
    If Not F(Target - 1).Writable Or Aggregate(F, Target) Then BindFor = Reject(N, M, A, F, D, 3, 21, Target): Exit Function
    If N(Node - 1).Value = 2 Then
        If F(Target - 1).TypeCode <> SyntaxTokens.KwVariant Then BindFor = Reject(N, M, A, F, D, 3, 21, Target): Exit Function
    Else
        If Not ConstantValues.IsNumeric(F(Target - 1).TypeCode) Then BindFor = Reject(N, M, A, F, D, 3, 21, Target): Exit Function
    End If
    ' Stable scalar storage is admitted first; array-element aliases need retained ownership.
    If Not StableLoopVariable(N, F, Target) Then BindFor = Reject(N, M, A, F, D, 8, 85, Target): Exit Function
    Parent = N(Node - 1).Parent
    Do While Parent <> 0
        If N(Parent - 1).Kind = SourceParser.SubNode Or N(Parent - 1).Kind = SourceParser.FunctionNode Then Exit Do
        If N(Parent - 1).Kind = SourceParser.ForNode Then
            Other = N(Parent - 1).FirstChild
            If SameLoopVariable(N, F, Other, Target) Then BindFor = Reject(N, M, A, F, D, 3, 23, Target): Exit Function
        End If
        Parent = N(Parent - 1).Parent
    Loop
    F(Node - 1).TypeCode = F(Target - 1).TypeCode
    Child = N(Target - 1).NextSibling
    If N(Node - 1).Value = 2 Then
        If Not BindExpression(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, Child, 0, 0) Then Exit Function
        If F(Child - 1).ArrayRank <> 1 Then BindFor = Reject(N, M, A, F, D, 3, 21, Child): Exit Function
        If F(Child - 1).TypeSymbol <> 0 And F(Child - 1).TypeCode <> SyntaxTokens.KwObject And Not ManagedLayouts.IsRecordValue(F(Child - 1).TypeCode, F(Child - 1).TypeSymbol) Then BindFor = Reject(N, M, A, F, D, 8, 85, Child): Exit Function
        Child = N(Child - 1).NextSibling
    Else
        Do While N(Child - 1).Kind <> SourceParser.BodyNode
            If Not BindExpression(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, Child, 0, F(Target - 1).TypeCode) Then Exit Function
            If Not ConvertValue(N, M, A, F, X, S, D, Child, F(Target - 1).TypeCode) Then Exit Function
            Child = N(Child - 1).NextSibling
        Loop
    End If
    Child = N(Child - 1).NextSibling
    If Child <> 0 Then
        If Not ResolveReference(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, Child, True) Then Exit Function
        If Not SameLoopVariable(N, F, Child, Target) Then BindFor = Reject(N, M, A, F, D, 3, 23, Child): Exit Function
    End If
    BindFor = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Checks only executable semantic roots; nested expressions are handled with their actual destination context.
Private Function CheckRoots(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef P() As Byte, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As BoundExpression, ByRef H() As Long, ByRef L() As Long, ByRef U() As Long, ByRef K() As Long, ByRef X() As Byte, ByRef S As ExpressionState, ByRef D As DeclarationBinder.BindingDiagnostic) As Boolean
    Dim Node As Long = 1
    Dim Kind As Long
    Dim Child As Long
    Dim Parent As Long
    Dim Found As Boolean
    On Error GoTo Failed
    Do While Node <= C.NodeCount
        If Not DeclarationBinder.ContinueBinding(S.Lookup) Then CheckRoots = Reject(N, M, A, F, D, 104, 0, Node): Exit Function
        Kind = N(Node - 1).Kind
        If Kind = SourceParser.VariableNode Or Kind = SourceParser.AssignmentNode Then
            If BindAssignment(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, Node) = False Then Exit Function
        ElseIf Kind = SourceParser.ForNode Then
            If Not BindFor(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, Node) Then Exit Function
        ElseIf Kind = SourceParser.SyncLockNode Then
            Child = N(Node - 1).FirstChild
            If Not BindExpression(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, Child, 0, 0) Then Exit Function
            If F(Child - 1).ArrayRank <> 0 Or F(Child - 1).TypeCode <> SyntaxTokens.KwObject Then CheckRoots = Reject(N, M, A, F, D, 3, 21, Child): Exit Function
        ElseIf (Kind = SourceParser.CallNode Or Kind = SourceParser.ThreadStartNode) And N(Node - 1).Value <> 0 Then
            If BindCall(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, Node, False) = False Then Exit Function
        ElseIf Kind = SourceParser.IfNode Or Kind = SourceParser.WhileNode Or (Kind = SourceParser.DoNode And N(Node - 1).Value <> 0) Then
            Child = N(Node - 1).FirstChild
            If BindExpression(B, T, N, M, C, P, A, F, H, L, U, K, X, S, D, Child, 0, 0) = False Then Exit Function
            If ConvertValue(N, M, A, F, X, S, D, Child, SyntaxTokens.KwBoolean) = False Then Exit Function
        ElseIf Kind = SourceParser.GoToNode Or Kind = SourceParser.OnErrorNode Then
            If BindBranch(B, T, N, M, C, A, F, H, L, S, D, Node) = False Then Exit Function
        ElseIf Kind = SourceParser.ExitNode Then
            If N(Node - 1).Value = SyntaxTokens.KwDo Or N(Node - 1).Value = SyntaxTokens.KwWhile Or N(Node - 1).Value = SyntaxTokens.KwFor Or N(Node - 1).Value = SyntaxTokens.KwLoop Then
                Parent = N(Node - 1).Parent
                Found = False
                Do While Parent <> 0
                    If Not DeclarationBinder.ContinueBinding(S.Lookup) Then CheckRoots = Reject(N, M, A, F, D, 104, 0, Node): Exit Function
                    If N(Parent - 1).Kind = SourceParser.SubNode Or N(Parent - 1).Kind = SourceParser.FunctionNode Then Exit Do
                    If N(Parent - 1).Kind = SourceParser.DoNode And (N(Node - 1).Value = SyntaxTokens.KwDo Or N(Node - 1).Value = SyntaxTokens.KwLoop) Then Found = True: Exit Do
                    If N(Parent - 1).Kind = SourceParser.WhileNode And (N(Node - 1).Value = SyntaxTokens.KwWhile Or N(Node - 1).Value = SyntaxTokens.KwLoop) Then Found = True: Exit Do
                    If N(Parent - 1).Kind = SourceParser.ForNode And (N(Node - 1).Value = SyntaxTokens.KwFor Or N(Node - 1).Value = SyntaxTokens.KwLoop) Then Found = True: Exit Do
                    Parent = N(Parent - 1).Parent
                Loop
                If Found = False Then CheckRoots = Reject(N, M, A, F, D, 3, 23, Node): Exit Function
            Else
                Parent = A(F(Node - 1).ScopeSymbol - 1).Kind
                If (N(Node - 1).Value = SyntaxTokens.KwSub And Parent <> SourceParser.SubNode) Or (N(Node - 1).Value = SyntaxTokens.KwFunction And Parent <> SourceParser.FunctionNode) Then CheckRoots = Reject(N, M, A, F, D, 3, 23, Node): Exit Function
            End If
        End If
        Node = Node + 1
    Loop
    CheckRoots = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Derives private declaration identities and publishes one complete independent expression-fact array.
Public Function TryBindExpressions(ByRef Bytes() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByRef Nodes() As SourceParser.SyntaxNode, ByRef Modules() As ProjectSyntax.ParsedModule, ByRef Counts As ProjectSyntax.ProjectCounts, ByRef PackageName() As Byte, ByVal IsExecutable As Boolean, ByRef Bindings() As BoundExpression, ByRef BindingCount As Long, ByRef TextArena() As Byte, ByRef TextUsed As Long, ByRef Diagnostic As DeclarationBinder.BindingDiagnostic) As Boolean
    Dim Symbols() As DeclarationBinder.BoundSymbol
    Dim Candidate() As BoundExpression
    Dim CandidateText() As Byte
    Dim Buckets() As Long
    Dim Links() As Long
    Dim NodeSymbols() As Long
    Dim ModuleSymbols() As Long
    Dim ConstantStates() As Long
    Dim State As ExpressionState
    Dim SymbolCount As Long
    Dim EntrySymbol As Long
    Dim Index As Long
    Dim Node As Long
    Dim Moved As Boolean
    On Error GoTo StorageFailure
    BindingCount = 0
    TextUsed = 0
    If DeclarationBinder.TryBindDeclarations(Bytes, Tokens, Nodes, Modules, Counts, PackageName, IsExecutable, Symbols, SymbolCount, EntrySymbol, Diagnostic) = False Then Exit Function
    If DeclarationBinder.TryBuildIndex(Bytes, Tokens, Nodes, Counts, Symbols, SymbolCount, Buckets, Links, NodeSymbols, ModuleSymbols, State.Lookup) = False Then GoTo StorageFailure
    If ResizeFacts(Candidate, Counts.NodeCount, False) = False Then GoTo StorageFailure
    If ResizeStates(ConstantStates, SymbolCount, False) = False Then GoTo StorageFailure
    AssignScopes Nodes, Modules, Counts, Symbols, NodeSymbols, Candidate, State
    If State.Lookup.CancelledObserved Then GoTo StorageFailure
    Do While Index < SymbolCount
        If Not DeclarationBinder.ContinueBinding(State.Lookup) Then GoTo StorageFailure
        Node = Symbols(Index).DeclarationNode
        If Symbols(Index).Kind = SourceParser.FunctionNode Or Symbols(Index).Kind = SourceParser.ParameterNode Then
            If ManagedLayouts.IsRecordValue(Symbols(Index).TypeCode, Symbols(Index).TypeSymbol) Or Symbols(Index).ArrayRank <> 0 Then
                If Symbols(Index).Kind = SourceParser.FunctionNode Then TryBindExpressions = Reject(Nodes, Modules, Symbols, Candidate, Diagnostic, 8, 11, Node): Exit Function
            End If
        End If
        If Symbols(Index).Kind = SourceParser.FieldNode And Symbols(Index).ArrayRank <> 0 Then TryBindExpressions = Reject(Nodes, Modules, Symbols, Candidate, Diagnostic, 8, 11, Node): Exit Function
        If Symbols(Index).Kind = SourceParser.ConstantNode Then
            If EvaluateConstant(Bytes, Tokens, Nodes, Modules, Counts, PackageName, Symbols, Candidate, Buckets, Links, ModuleSymbols, ConstantStates, CandidateText, State, Diagnostic, Index + 1) = False Then Exit Function
        End If
        Index = Index + 1
    Loop
    If ShapeEffects(Bytes, Tokens, Nodes, Modules, Counts, PackageName, Symbols, Candidate, Buckets, Links, ModuleSymbols, ConstantStates, CandidateText, State, Diagnostic) = False Then Exit Function
    Index = 0
    Do While Index < SymbolCount
        If Not DeclarationBinder.ContinueBinding(State.Lookup) Then GoTo StorageFailure
        If Symbols(Index).ArrayRank <> 0 Then
            If BindBounds(Bytes, Tokens, Nodes, Modules, Counts, PackageName, Symbols, Candidate, Buckets, Links, ModuleSymbols, ConstantStates, CandidateText, State, Diagnostic, Index + 1) = False Then Exit Function
        End If
        Index = Index + 1
    Loop
    If CheckRoots(Bytes, Tokens, Nodes, Modules, Counts, PackageName, Symbols, Candidate, Buckets, Links, ModuleSymbols, ConstantStates, CandidateText, State, Diagnostic) = False Then Exit Function
    Moved = MoveFacts(Bindings, Candidate)
    Moved = MoveBytes(TextArena, CandidateText)
    BindingCount = Counts.NodeCount
    TextUsed = State.TextUsed
    TryBindExpressions = True
    Exit Function
StorageFailure:
    BindingCount = 0
    TextUsed = 0
    Diagnostic.Code = 7
    If State.Lookup.CancelledObserved Then Diagnostic.Code = 104
    Diagnostic.Reason = 1
    Diagnostic.ModuleIndex = -1
    Diagnostic.Node = 0
    Diagnostic.TokenIndex = -1
    Diagnostic.ByteOffset = 0
    Diagnostic.Utf16Offset = 1
    Diagnostic.Line = 1
    Diagnostic.Column = 1
End Function
