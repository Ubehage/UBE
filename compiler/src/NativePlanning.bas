UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativePlanning"
' Plans bounded native storage and initialization from matching facts privately validated by the emitter.
Public Type NativeSymbolPlan
    ContextOffset As Long
    FrameCells As Long
    TemporaryTextCount As Long
    TextSlotCount As Long
    PinCount As Long
    FirstConstruct As Long
    LastConstruct As Long
    ResultSymbol As Long
    FirstScopeSymbol As Long
    NextScopeSymbol As Long
    ArgumentArrayCount As Long
    StorageEscapes As Boolean
    TemporaryOwnerCount As Long
End Type

Public Type NativePlanSummary
    ManagedRoles As ManagedSupport.RolePlan
    SymbolCount As Long
    NodeCount As Long
    ModuleCount As Long
    ContextCells As Long
    EntrySymbol As Long
End Type

' Replaces caller-owned scratch plans with neutral candidate storage.
Private Intrinsic Function ResizePlans(ByRef Values() As NativeSymbolPlan, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizePlans.UBE_Primitive = "Array.TryResize"
End Function

' Allocates bounded numeric indexes and dependency traversal workspaces.
Private Intrinsic Function ResizeNumbers(ByRef Values() As Long, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeNumbers.UBE_Primitive = "Array.TryResize"
End Function

' Locates a retained node without requiring a mutable scope on module root nodes.
Private Function ModuleOf(ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByVal Node As Long) As Long
    Dim Index As Long
    On Error GoTo Failed
    ModuleOf = -1
    Do While Index < C.ModuleCount
        If Node > M(Index).NodeBase And Node <= M(Index).NodeBase + M(Index).NodeCount Then ModuleOf = Index: Exit Function
        Index = Index + 1
    Loop
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Reports a located admission failure while preserving earlier diagnostics.
Private Function Reject(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Node As Long, ByVal Code As Long, ByVal Reason As Long) As Boolean
    Dim ModuleIndex As Long
    On Error GoTo Failed
    If D.Code <> 0 Then Exit Function
    ModuleIndex = ModuleOf(M, C, Node)
    D.Code = Code
    D.Reason = Reason
    D.ModuleIndex = ModuleIndex
    D.Node = Node
    D.TokenIndex = -1
    D.ByteOffset = 0
    D.Utf16Offset = 1
    D.Line = 1
    D.Column = 1
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

' Adds source coordinates to a failure produced by the node-indexed escape analysis.
Private Function LocateEscapeFailure(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef D As DeclarationBinder.BindingDiagnostic) As Boolean
    Dim Code As Long
    Dim Reason As Long
    Dim Node As Long
    Code = D.Code
    Reason = D.Reason
    Node = D.Node
    D.Code = 0
    LocateEscapeFailure = Reject(N, M, C, D, Node, Code, Reason)
End Function

' Reserves heap-frame capacity with checked indexing; controls are already charged.
Private Function AddCells(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef Plans() As NativeSymbolPlan, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Scope As Long, ByVal Cells As Long, ByVal Node As Long) As Boolean
    On Error GoTo Failed
    If Cells < 0 Or Cells > 2147483647 - Plans(Scope - 1).FrameCells Then AddCells = Reject(N, M, C, D, Node, 6, 50): Exit Function
    Plans(Scope - 1).FrameCells = Plans(Scope - 1).FrameCells + Cells
    AddCells = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Assigns module offsets, owned storage, borrowed parameter cells and procedure result identities.
Private Function PlanSymbols(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef A() As DeclarationBinder.BoundSymbol, ByVal Count As Long, ByRef L() As AggregateLayout.StorageFact, ByRef Plans() As NativeSymbolPlan, ByRef ContextCells As Long, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal ManagedRequired As Boolean) As Boolean
    Dim Index As Long
    Dim Kind As Long
    Dim Node As Long
    Dim Scope As Long
    Dim Cells As Long
    Dim Borrowed As Boolean
    On Error GoTo Failed
    Do While Index < Count
        Plans(Index).ContextOffset = -1
        Kind = A(Index).Kind
        If Kind = SourceParser.ModuleNode Or Kind = SourceParser.ClassNode Or Kind = SourceParser.SubNode Or Kind = SourceParser.FunctionNode Then
            Plans(Index).FrameCells = 4
            If ManagedRequired Then Plans(Index).FrameCells = 8
            If DeclarationBinder.IsInstanceMember(A, Index + 1) Then Plans(Index).FrameCells = Plans(Index).FrameCells + 5
        End If
        Index = Index + 1
    Loop
    ' Prepending in reverse identity order creates ascending per-scope lists without repeated global scans.
    Index = Count
    Do While Index > 0
        Index = Index - 1
        Scope = A(Index).ScopeSymbol
        If Scope > 0 And Not (A(Index).Kind = SourceParser.VariableNode And DeclarationBinder.IsInstanceMember(A, Index + 1)) Then
            Plans(Index).NextScopeSymbol = Plans(Scope - 1).FirstScopeSymbol
            Plans(Scope - 1).FirstScopeSymbol = Index + 1
        End If
    Loop
    Index = 0
    Do While Index < Count
        Kind = A(Index).Kind
        Node = A(Index).DeclarationNode
        If Kind = SourceParser.SubNode Or Kind = SourceParser.FunctionNode Then
            If SyntaxTokens.IsLifecycleName(B, T, C.TokenCount, A(Index).NameToken, False) Then PlanSymbols = Reject(N, M, C, D, Node, 8, 50): Exit Function
            If A(Index).ParameterCount > 64 Then PlanSymbols = Reject(N, M, C, D, Node, 6, 51): Exit Function
        ElseIf Kind = SourceParser.VariableNode Or Kind = SourceParser.ParameterNode Or Kind = DeclarationBinder.ResultSymbol Then
            Scope = A(Index).ScopeSymbol
            Cells = L(Node - 1).StorageCells
            If A(Scope - 1).Kind = SourceParser.ClassNode Then
                ' Instance fields belong to the managed object payload, never an invocation frame.
            ElseIf A(Scope - 1).Kind = SourceParser.ModuleNode Then
                If Cells < 1 Or Cells > 65536 - ContextCells Then PlanSymbols = Reject(N, M, C, D, Node, 6, 54): Exit Function
                Plans(Index).ContextOffset = ContextCells
                ContextCells = ContextCells + Cells
            Else
                Borrowed = False
                If Plans(Index).StorageEscapes Then Cells = 1
                If Kind = SourceParser.ParameterNode Then
                    If A(Index).PassingMode = SyntaxTokens.KwByRef Or A(Index).ArrayRank <> 0 Or ManagedLayouts.IsRecordValue(A(Index).TypeCode, A(Index).TypeSymbol) Then
                        Borrowed = True
                        Cells = 0
                        If ManagedRequired And Plans(Index).StorageEscapes Then Cells = 1
                    End If
                End If
                ' Borrowed addresses are SSA parameters; only rooted incoming owners occupy storage.
                If ManagedRequired And L(Node - 1).ManagedReferences > 0 Then
                    If Not Plans(Index).StorageEscapes Or Borrowed Then Cells = Cells + 4
                End If
                If ManagedRequired And Plans(Index).StorageEscapes Then Cells = Cells + 4
                If Not AddCells(N, M, C, Plans, D, Scope, Cells, Node) Then Exit Function
                If Kind = DeclarationBinder.ResultSymbol Then Plans(Scope - 1).ResultSymbol = Index + 1
            End If
        End If
        Index = Index + 1
    Loop
    PlanSymbols = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Accounts the maximum live scalar String slots in each statement independently of other storage.
Private Function PlanTextSlots(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef E() As ExpressionBinder.BoundExpression, ByRef Plans() As NativeSymbolPlan, ByRef D As DeclarationBinder.BindingDiagnostic) As Boolean
    Dim StatementText() As Long
    Dim Node As Long = 1
    Dim Scope As Long
    Dim Statement As Long
    Dim Cells As Long
    On Error GoTo Failed
    If Not ResizeNumbers(StatementText, C.NodeCount, False) Then GoTo Failed
    Do While Node <= C.NodeCount
        If ManagedLayouts.NeedsTextSlot(N, E, Node) Then
            Scope = E(Node - 1).ScopeSymbol
            Statement = ManagedLayouts.StatementOf(N, Node)
            If Statement = 0 Then PlanTextSlots = Reject(N, M, C, D, Node, 6, 55): Exit Function
            StatementText(Statement - 1) = StatementText(Statement - 1) + 1
            If StatementText(Statement - 1) > Plans(Scope - 1).TextSlotCount Then
                Cells = 2
                If Plans(Scope - 1).TextSlotCount = 0 Then Cells = Cells + 4
                If Not AddCells(N, M, C, Plans, D, Scope, Cells, Node) Then Exit Function
                Plans(Scope - 1).TextSlotCount = StatementText(Statement - 1)
                Plans(Scope - 1).TemporaryTextCount = Plans(Scope - 1).TemporaryTextCount + 1
            End If
        End If
        Node = Node + 1
    Loop
    PlanTextSlots = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Charges grouped argument temporaries, reusable statement pins and record snapshots before emission.
Private Function PlanManagedTemporaries(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef E() As ExpressionBinder.BoundExpression, ByRef L() As AggregateLayout.StorageFact, ByRef Plans() As NativeSymbolPlan, ByRef Escapes() As NativeEscapes.EscapeFact, ByRef D As DeclarationBinder.BindingDiagnostic) As Boolean
    Dim Node As Long = 1
    Dim Scope As Long
    Dim Cells As Long
    On Error GoTo Failed
    Do While Node <= C.NodeCount
        Scope = E(Node - 1).ScopeSymbol
        Cells = ManagedLayouts.TemporaryReferences(N, E, L, Node, Escapes(Node - 1).NeedsOwner)
        If Cells <> 0 Then
            If Not AddCells(N, M, C, Plans, D, Scope, Cells, Node) Then Exit Function
            Plans(Scope - 1).TemporaryTextCount = Plans(Scope - 1).TemporaryTextCount + Cells
        End If
        If ManagedLayouts.NeedsRecordSnapshot(N, E, L, Node) Then
            If Not AddCells(N, M, C, Plans, D, Scope, L(Node - 1).StorageCells + 4, Node) Then Exit Function
        End If
        If Escapes(Node - 1).NeedsOwner And Escapes(Node - 1).OwnerKind = NativeEscapes.TemporaryOwner Then
            If Not AddCells(N, M, C, Plans, D, Scope, 4, Node) Then Exit Function
        End If
        Node = Node + 1
    Loop
    PlanManagedTemporaries = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Charges loop, monitor and Variant conversion storage in source-node order.
Private Function PlanConstructStorage(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef E() As ExpressionBinder.BoundExpression, ByRef L() As AggregateLayout.StorageFact, ByRef Plans() As NativeSymbolPlan, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Node As Long, ByVal Scope As Long) As Boolean
    Dim Kind As Long
    Dim Child As Long
    Dim Cells As Long
    On Error GoTo Failed
    Kind = N(Node - 1).Kind
    If E(Node - 1).TypeCode = SyntaxTokens.KwVariant And E(Node - 1).ConvertedType <> 0 And E(Node - 1).ConvertedType <> SyntaxTokens.KwVariant Then
        If Not AddCells(N, M, C, Plans, D, Scope, 1, Node) Then Exit Function
    End If
    If Kind = SourceParser.ForNode Then
        Cells = 2
        If N(Node - 1).Value = 2 Then
            Cells = 9
            Child = N(Node - 1).FirstChild
            Child = N(Child - 1).NextSibling
            If L(Child - 1).ManagedReferences > 0 Then Cells = 13
            If Plans(Scope - 1).FirstConstruct = 0 Then
                If Not AddCells(N, M, C, Plans, D, Scope, 1, Node) Then Exit Function
                Plans(Scope - 1).FirstConstruct = Node
            End If
            Plans(Scope - 1).LastConstruct = Node
        End If
        If Not AddCells(N, M, C, Plans, D, Scope, Cells, Node) Then Exit Function
    End If
    If Kind = SourceParser.SyncLockNode Then
        If Plans(Scope - 1).FirstConstruct = 0 Then
            If Not AddCells(N, M, C, Plans, D, Scope, 1, Node) Then Exit Function
            Plans(Scope - 1).FirstConstruct = Node
        End If
        Plans(Scope - 1).LastConstruct = Node
        If Not AddCells(N, M, C, Plans, D, Scope, 6, Node) Then Exit Function
    End If
    PlanConstructStorage = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Charges one argument's owner, grouped temporary or aggregate snapshot storage.
Private Function PlanArgumentStorage(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef E() As ExpressionBinder.BoundExpression, ByRef L() As AggregateLayout.StorageFact, ByRef Plans() As NativeSymbolPlan, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Node As Long, ByVal Scope As Long, ByRef Escapes() As NativeEscapes.EscapeFact) As Boolean
    Dim Cells As Long
    On Error GoTo Failed
    If Escapes(Node - 1).NeedsOwner And Escapes(Node - 1).OwnerKind = NativeEscapes.TemporaryOwner Then
        If Not AddCells(N, M, C, Plans, D, Scope, 1, Node) Then Exit Function
    ElseIf E(Node - 1).ArgumentMode = 3 Then
        If Not AddCells(N, M, C, Plans, D, Scope, 1, Node) Then Exit Function
        If ManagedLayouts.IsManagedScalar(E(Node - 1).ConvertedType) And Not Escapes(Node - 1).NeedsOwner Then
            If Not AddCells(N, M, C, Plans, D, Scope, 4, Node) Then Exit Function
        End If
    ElseIf E(Node - 1).ArgumentMode = 1 Then
        Cells = 0
        If E(Node - 1).ArrayRank <> 0 Then
            Cells = 4
            If Escapes(Node - 1).NeedsOwner Then Cells = 1
            Plans(Scope - 1).ArgumentArrayCount = Plans(Scope - 1).ArgumentArrayCount + 1
        ElseIf ManagedLayouts.IsRecordValue(E(Node - 1).TypeCode, E(Node - 1).TypeSymbol) And E(Node - 1).ConvertedType <> SyntaxTokens.KwVariant Then
            Cells = L(Node - 1).StorageCells
            If Escapes(Node - 1).NeedsOwner Then Cells = 1
        End If
        If Cells <> 0 Then
            If L(Node - 1).ManagedReferences > 0 And Not Escapes(Node - 1).NeedsOwner Then Cells = Cells + 4
            If Not AddCells(N, M, C, Plans, D, Scope, Cells, Node) Then Exit Function
        End If
    End If
    PlanArgumentStorage = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Charges ordinary temporary values, statement pins and record evaluation snapshots.
Private Function PlanNodes(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef E() As ExpressionBinder.BoundExpression, ByRef L() As AggregateLayout.StorageFact, ByVal EntrySymbol As Long, ByVal IsExecutable As Boolean, ByRef Plans() As NativeSymbolPlan, ByRef Pins() As Long, ByRef Escapes() As NativeEscapes.EscapeFact, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal ManagedRequired As Boolean) As Boolean
    Dim StatementPins() As Long
    Dim Node As Long = 1
    Dim Scope As Long
    Dim Statement As Long
    Dim Parent As Long
    Dim Kind As Long
    Dim Cells As Long
    Dim Work As Long
    On Error GoTo Failed
    If Not ResizeNumbers(StatementPins, C.NodeCount, False) Then GoTo Failed
    Do While Node <= C.NodeCount
        Scope = E(Node - 1).ScopeSymbol
        Kind = N(Node - 1).Kind
        If Not PlanConstructStorage(N, M, C, E, L, Plans, D, Node, Scope) Then Exit Function
        If Not PlanArgumentStorage(N, M, C, E, L, Plans, D, Node, Scope, Escapes) Then Exit Function
        If E(Node - 1).AccessKind = 2 Then
            Statement = Node
            Parent = N(Statement - 1).Parent
            Do While Parent <> 0
                If Work >= 10000000 Then PlanNodes = Reject(N, M, C, D, Node, 6, 55): Exit Function
                Work = Work + 1
                Kind = N(Parent - 1).Kind
                If Kind = SourceParser.BodyNode Or Kind = SourceParser.ThenNode Or Kind = SourceParser.ElseNode Or Kind = SourceParser.ModuleNode Then Exit Do
                Statement = Parent
                Parent = N(Statement - 1).Parent
            Loop
            StatementPins(Statement - 1) = StatementPins(Statement - 1) + 1
            Pins(Node - 1) = StatementPins(Statement - 1)
            If Pins(Node - 1) > Plans(Scope - 1).PinCount Then
                Cells = 1
                If ManagedRequired Then Cells = 5
                If Not AddCells(N, M, C, Plans, D, Scope, Cells, Node) Then Exit Function
                Plans(Scope - 1).PinCount = Pins(Node - 1)
            End If
        End If
        Kind = N(Node - 1).Kind
        If IsExecutable And Kind = SourceParser.CallNode And Scope = EntrySymbol And E(Node - 1).TrustedRole = 2 Then PlanNodes = Reject(N, M, C, D, Node, 8, 51): Exit Function
        Node = Node + 1
    Loop
    PlanNodes = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Pushes one pending dependency visit only after checking the retained stack bound.
Private Function PushNode(ByRef Stack() As Long, ByRef Count As Long, ByVal Capacity As Long, ByVal Node As Long) As Boolean
    On Error GoTo Failed
    If Count >= Capacity Then Exit Function
    Stack(Count) = Node
    Count = Count + 1
    PushNode = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Collects transitive source calls and module accesses reachable from declaration initializers.
Private Function InitializerDependencies(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef A() As DeclarationBinder.BoundSymbol, ByVal SymbolCount As Long, ByRef E() As ExpressionBinder.BoundExpression, ByRef Dependencies() As Byte, ByRef D As DeclarationBinder.BindingDiagnostic) As Boolean
    Dim Stack() As Long
    Dim Seen() As Long
    Dim Bases() As Long
    Dim Capacity As Long
    Dim Count As Long
    Dim Origin As Long
    Dim Node As Long
    Dim Child As Long
    Dim Symbol As Long
    Dim Target As Long
    Dim Kind As Long
    Dim Work As Long
    Dim Middle As Long
    Dim Index As Long
    Dim Other As Long
    Dim MatrixCells As Long
    On Error GoTo Failed
    If SymbolCount > 2147483647 - C.NodeCount Then InitializerDependencies = Reject(N, M, C, D, 0, 6, 53): Exit Function
    Capacity = C.NodeCount + SymbolCount
    If Not ResizeNumbers(Stack, Capacity, False) Then GoTo Failed
    If Not ResizeNumbers(Seen, SymbolCount, False) Then GoTo Failed
    If Not ResizeNumbers(Bases, C.ModuleCount, False) Then GoTo Failed
    Do While Index < C.ModuleCount
        Bases(Index) = MatrixCells
        If C.ModuleCount > 2147483647 - MatrixCells Then InitializerDependencies = Reject(N, M, C, D, 0, 6, 53): Exit Function
        MatrixCells = MatrixCells + C.ModuleCount
        Index = Index + 1
    Loop
    If Not BufferPrimitives.TryResizeBytes(Dependencies, MatrixCells, False) Then GoTo Failed
    Do While Origin < C.ModuleCount
        Count = 0
        Node = N(M(Origin).RootNode - 1).FirstChild
        Do While Node <> 0
            If N(Node - 1).Kind = SourceParser.VariableNode Then
                Child = ExpressionBinder.InitializerNode(N, Node)
                If Child <> 0 Then
                    If Not PushNode(Stack, Count, Capacity, Child) Then InitializerDependencies = Reject(N, M, C, D, Node, 6, 53): Exit Function
                End If
            End If
            Node = N(Node - 1).NextSibling
        Loop
        Do While Count > 0
            Count = Count - 1
            Node = Stack(Count)
            If Work >= 10000000 Then InitializerDependencies = Reject(N, M, C, D, Node, 6, 52): Exit Function
            Work = Work + 1
            Symbol = E(Node - 1).SymbolIndex
            If Symbol <> 0 Then
                Kind = A(Symbol - 1).Kind
                Target = -1
                If Kind = SourceParser.VariableNode Then
                    If A(A(Symbol - 1).ScopeSymbol - 1).Kind = SourceParser.ModuleNode Then Target = A(Symbol - 1).ModuleIndex
                ElseIf N(Node - 1).Kind = SourceParser.CallNode Then
                    Target = A(Symbol - 1).ModuleIndex
                    If Seen(Symbol - 1) <> Origin + 1 Then
                        Seen(Symbol - 1) = Origin + 1
                        Child = N(A(Symbol - 1).DeclarationNode - 1).FirstChild
                        Do While Child <> 0
                            If N(Child - 1).Kind = SourceParser.BodyNode Then
                                If Not PushNode(Stack, Count, Capacity, Child) Then InitializerDependencies = Reject(N, M, C, D, Node, 6, 53): Exit Function
                            End If
                            Child = N(Child - 1).NextSibling
                        Loop
                    End If
                End If
                If Target >= 0 Then
                    If Target = Origin Then
                        If A(E(Node - 1).ScopeSymbol - 1).ModuleIndex <> Origin Then InitializerDependencies = Reject(N, M, C, D, Node, 8, 52): Exit Function
                    Else
                        Dependencies(Bases(Origin) + Target) = 1
                    End If
                End If
            End If
            Child = N(Node - 1).FirstChild
            Do While Child <> 0
                If Not PushNode(Stack, Count, Capacity, Child) Then InitializerDependencies = Reject(N, M, C, D, Node, 6, 53): Exit Function
                Child = N(Child - 1).NextSibling
            Loop
        Loop
        Origin = Origin + 1
    Loop
    Do While Middle < C.ModuleCount
        Index = 0
        Do While Index < C.ModuleCount
            If Dependencies(Bases(Index) + Middle) <> 0 Then
                Other = 0
                Do While Other < C.ModuleCount
                    If Dependencies(Bases(Middle) + Other) <> 0 Then Dependencies(Bases(Index) + Other) = 1
                    Other = Other + 1
                Loop
            End If
            Index = Index + 1
        Loop
        Middle = Middle + 1
    Loop
    Index = 0
    Do While Index < C.ModuleCount
        If Dependencies(Bases(Index) + Index) <> 0 Then InitializerDependencies = Reject(N, M, C, D, M(Index).RootNode, 8, 52): Exit Function
        Index = Index + 1
    Loop
    InitializerDependencies = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Prepares scratch maps from fresh matching semantic facts; summary counts commit only on complete success.
Public Function TryPlanNative(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef A() As DeclarationBinder.BoundSymbol, ByVal SymbolCount As Long, ByRef E() As ExpressionBinder.BoundExpression, ByRef L() As AggregateLayout.StorageFact, ByRef Roles() As Long, ByVal EntrySymbol As Long, ByVal IsExecutable As Boolean, ByRef Plans() As NativeSymbolPlan, ByRef Pins() As Long, ByRef Escapes() As NativeEscapes.EscapeFact, ByRef Dependencies() As Byte, ByRef Summary As NativePlanSummary, ByRef Diagnostic As DeclarationBinder.BindingDiagnostic) As Boolean
    Dim EmptyRoles As ManagedSupport.RolePlan
    Dim ContextCells As Long
    Dim FactCount As Long
    Dim ManagedRequired As Boolean
    Dim Symbol As Long
    Dim Node As Long
    On Error GoTo StorageFailure
    Summary.ManagedRoles = EmptyRoles
    Summary.SymbolCount = 0
    Summary.NodeCount = 0
    Summary.ModuleCount = 0
    Summary.ContextCells = 0
    Summary.EntrySymbol = 0
    Diagnostic.Code = 0
    If SymbolCount < 1 Or C.NodeCount < 1 Or C.ModuleCount < 1 Or EntrySymbol < 0 Or EntrySymbol > SymbolCount Then TryPlanNative = Reject(N, M, C, Diagnostic, 0, 9, 50): Exit Function
    ' Any managed expression requires precise roots, including implicit text conversions.
    Symbol = 1
    Do While Symbol <= SymbolCount
        If ManagedLayouts.IsManagedScalar(A(Symbol - 1).TypeCode) Then ManagedRequired = True
        Symbol = Symbol + 1
    Loop
    Node = 1
    Do While Node <= C.NodeCount
        If ManagedLayouts.IsManagedScalar(E(Node - 1).TypeCode) Or ManagedLayouts.IsManagedScalar(E(Node - 1).ConvertedType) Then ManagedRequired = True
        Node = Node + 1
    Loop
    If Not ResizePlans(Plans, SymbolCount, False) Then GoTo StorageFailure
    If Not ResizeNumbers(Pins, C.NodeCount, False) Then GoTo StorageFailure
    If Not NativeEscapes.TryAnalyzeEscapes(N, A, E, C.NodeCount, SymbolCount, Escapes, FactCount, Diagnostic) Then
        If Diagnostic.Node > 0 Then TryPlanNative = LocateEscapeFailure(N, M, C, Diagnostic)
        Exit Function
    End If
    Symbol = 1
    Do While Symbol <= SymbolCount
        Plans(Symbol - 1).StorageEscapes = Escapes(A(Symbol - 1).DeclarationNode - 1).StorageEscapes
        Symbol = Symbol + 1
    Loop
    If Not PlanSymbols(B, T, N, M, C, A, SymbolCount, L, Plans, ContextCells, Diagnostic, ManagedRequired) Then Exit Function
    If ManagedRequired Then
        If Not PlanTextSlots(N, M, C, E, Plans, Diagnostic) Then Exit Function
        If Not PlanManagedTemporaries(N, M, C, E, L, Plans, Escapes, Diagnostic) Then Exit Function
    End If
    If Not PlanNodes(N, M, C, E, L, EntrySymbol, IsExecutable, Plans, Pins, Escapes, Diagnostic, ManagedRequired) Then Exit Function
    If Not InitializerDependencies(N, M, C, A, SymbolCount, E, Dependencies, Diagnostic) Then Exit Function
    Node = 1
    Do While Node <= C.NodeCount
        If Escapes(Node - 1).NeedsOwner And Escapes(Node - 1).OwnerKind = NativeEscapes.TemporaryOwner Then
            Symbol = E(Node - 1).ScopeSymbol
            Plans(Symbol - 1).TemporaryOwnerCount = Plans(Symbol - 1).TemporaryOwnerCount + 1
        End If
        Node = Node + 1
    Loop
    Summary.SymbolCount = SymbolCount
    Summary.NodeCount = C.NodeCount
    Summary.ModuleCount = C.ModuleCount
    Summary.ContextCells = ContextCells
    Summary.EntrySymbol = EntrySymbol
    TryPlanNative = True
    Exit Function
StorageFailure:
    Summary.SymbolCount = 0
    Summary.NodeCount = 0
    Summary.ModuleCount = 0
    Summary.ContextCells = 0
    Summary.EntrySymbol = 0
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
