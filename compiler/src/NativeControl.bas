UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeControl"
' Emits statement continuations independently of sticky Err and preserves whole-condition failure exits.
Public Function SequenceEntry(ByRef N() As SourceParser.SyntaxNode, ByVal Parent As Long, ByVal Continuation As Long) As Long
    On Error GoTo Failed
    SequenceEntry = Continuation
    If Parent <> 0 Then
        If N(Parent - 1).FirstChild <> 0 Then SequenceEntry = N(Parent - 1).FirstChild
    End If
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Each sibling has its own next-statement identity, including the final statement of a nested body.
Public Function TryEmitSequence(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByRef L() As AggregateLayout.StorageFact, ByRef P() As NativePlanning.NativeSymbolPlan, ByRef Pins() As Long, ByRef Escapes() As NativeEscapes.EscapeFact, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Nexts() As Long, ByVal Parent As Long, ByVal Continuation As Long) As Boolean
    Dim Node As Long
    Dim NextNode As Long
    Dim Target As Long
    On Error GoTo Failed
    If Parent = 0 Then TryEmitSequence = True: Exit Function
    Node = N(Parent - 1).FirstChild
    Do While Node <> 0
        If NativeEmission.Charge(S) = False Then Exit Function
        NextNode = N(Node - 1).NextSibling
        Target = Continuation
        If NextNode <> 0 Then Target = NextNode
        If TryEmitStatement(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, Node, Target) = False Then Exit Function
        Node = NextNode
    Loop
    TryEmitSequence = True
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' A failed loop condition resumes beyond the entire loop, never as an ordinary False value.
Private Function TryEmitLoop(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByRef L() As AggregateLayout.StorageFact, ByRef P() As NativePlanning.NativeSymbolPlan, ByRef Pins() As Long, ByRef Escapes() As NativeEscapes.EscapeFact, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Nexts() As Long, ByVal Node As Long, ByVal Continuation As Long) As Boolean
    Dim Condition As Long
    Dim Body As Long
    Dim Header As Long
    Dim BodyEntry As Long
    Dim PreviousExit As Long
    Dim Value As Long
    Dim Test As Long
    Dim Template As Long
    Dim Mode As Long
    Dim Terminated As Boolean
    On Error GoTo Failed
    Mode = N(Node - 1).Value
    Body = N(Node - 1).FirstChild
    If Mode <> 0 Then
        Condition = Body
        Body = N(Condition - 1).NextSibling
    End If
    Header = NativeEmission.NewBlock(S)
    BodyEntry = SequenceEntry(N, Body, Header)
    PreviousExit = S.LoopExit
    S.LoopExit = Continuation
    Value = BodyEntry
    If Mode = 1 Or Mode = 2 Then Value = Header
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Branch, Value, 0, 0, 0) = False Then Exit Function
    If TryEmitSequence(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, Body, Header) = False Then Exit Function
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Label, Header, 0, 0, 0) = False Then Exit Function
    S.CurrentNode = Node
    S.ErrorNode = Node
    S.CurrentNext = Continuation
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ControlSite, Node, 0, 0, 0) = False Then Exit Function
    If Condition <> 0 Then
        Value = NativeExpressions.EmitExpression(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, Condition, Terminated)
        If S.Text.Failed Then Exit Function
        If Terminated = False Then
            Test = NativeEmission.NewValue(S)
            Template = LLVMTemplates.ValueNonzero
            If Mode = 2 Or Mode = 4 Then Template = LLVMTemplates.ControlZero
            If NativeEmission.TryLine(S, B, Token, Catalog, Template, Test, Value, 0, 0) = False Then Exit Function
            If NativeStorage.ReleaseAllPins(S, B, Token, Catalog, P(S.CurrentSymbol - 1).PinCount) = False Then Exit Function
            If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ConditionalBranch, Test, BodyEntry, Continuation, 0) = False Then Exit Function
        End If
    Else
        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Branch, BodyEntry, 0, 0, 0) = False Then Exit Function
    End If
    S.LoopExit = PreviousExit
    TryEmitLoop = True
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' An assignment publishes only after all source evaluation, conversion and aggregate snapshots succeed.
Private Function TryEmitAssignment(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByRef L() As AggregateLayout.StorageFact, ByRef P() As NativePlanning.NativeSymbolPlan, ByRef Pins() As Long, ByRef Escapes() As NativeEscapes.EscapeFact, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Nexts() As Long, ByVal Node As Long, ByRef Terminated As Boolean) As Boolean
    Dim Kind As Long
    Dim Target As Long
    Dim Symbol As Long
    Dim ValueNode As Long
    Dim Address As Long
    Dim SourceAddress As Long
    Dim Value As Long
    Dim Test As Long
    Dim Values() As Long
    Dim DeferredAddress As Boolean
    On Error GoTo Failed
    Kind = N(Node - 1).Kind
    Target = Node
    If Kind = SourceParser.VariableNode Then
        Symbol = E(Node - 1).SymbolIndex
        ValueNode = ExpressionBinder.InitializerNode(N, Node)
        Address = NativeStorage.StorageAddress(A, P, S, B, Token, Catalog, Symbol)
        If S.Text.Failed Then Exit Function
        If NativeOwnership.HasLocalBox(A, P, Symbol) And A(Symbol - 1).ArrayRank <> 0 And E(Node - 1).HasBounds Then
            If NativeOwnership.TryResetFixedArray(A, E, L, S, B, Token, Catalog, Seen, Nexts, Symbol, Address, False) = False Then Exit Function
        Else
            If NativeStorage.NeutralStorage(A, E, L, S, B, Token, Catalog, Symbol, Address, False, True) = False Then Exit Function
        End If
    Else
        Target = N(Node - 1).FirstChild
        ValueNode = N(Target - 1).NextSibling
        Symbol = E(Target - 1).SymbolIndex
        ' Direct scalar frame addresses are stable and have no evaluation effects.
        ' Materialize them at the store instead of carrying an SSA pointer across RHS calls.
        If Symbol > 0 And E(Target - 1).AccessKind = 0 And E(Target - 1).ArrayRank = 0 And E(Target - 1).TypeSymbol = 0 Then
            If P(Symbol - 1).ContextOffset < 0 Then DeferredAddress = True
        End If
        If DeferredAddress = False Then
            Address = NativeStorage.EmitAddress(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, Target, Terminated)
            If S.Text.Failed Then Exit Function
        End If
    End If
    If ValueNode <> 0 And Terminated = False Then
        If E(Target - 1).ArrayRank <> 0 Or E(Target - 1).TypeSymbol <> 0 Then
            SourceAddress = NativeStorage.EmitAddress(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, ValueNode, Terminated)
            If S.Text.Failed Then Exit Function
            If Terminated = False Then
                If E(Target - 1).ArrayRank = 1 Then
                    Test = NativeEmission.NewValue(S)
                    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ControlArrayCopy, Test, Address, SourceAddress, L(Target - 1).ElementCells) = False Then Exit Function
                    If NativeEmission.GuardStatus(S, B, Token, Catalog, Seen, Nexts, Test) = False Then Exit Function
                Else
                    If NativeStorage.SnapshotCells(S, B, Token, Catalog, SourceAddress, L(Target - 1).StorageCells, Values) = False Then Exit Function
                    If NativeStorage.StoreCells(S, B, Token, Catalog, Address, Values) = False Then Exit Function
                End If
                If NativeStorage.ReleaseNodePins(N, E, Pins, S, B, Token, Catalog, ValueNode) = False Then Exit Function
            End If
        Else
            Value = NativeExpressions.EmitConvertedExpression(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, ValueNode, E(Target - 1).TypeCode, Terminated)
            If S.Text.Failed Then Exit Function
            If Terminated = False Then
                If DeferredAddress Then
                    Address = NativeStorage.StorageAddress(A, P, S, B, Token, Catalog, Symbol)
                    If S.Text.Failed Then Exit Function
                End If
                If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.StoreValue, Value, Address, 0, 0) = False Then Exit Function
            End If
        End If
    End If
    TryEmitAssignment = True
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Emits one statement and its control-flow continuation.
Public Function TryEmitStatement(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByRef L() As AggregateLayout.StorageFact, ByRef P() As NativePlanning.NativeSymbolPlan, ByRef Pins() As Long, ByRef Escapes() As NativeEscapes.EscapeFact, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Nexts() As Long, ByVal Node As Long, ByVal Continuation As Long) As Boolean
    Dim Kind As Long
    Dim Child As Long
    Dim ThenNode As Long
    Dim ElseNode As Long
    Dim Value As Long
    Dim Test As Long
    Dim Terminated As Boolean
    Dim Target As Long
    Dim ThenEntry As Long
    Dim ElseEntry As Long
    On Error GoTo Failed
    If NativeEmission.Charge(S) = False Then Exit Function
    S.CurrentNode = Node
    S.ErrorNode = Node
    S.CurrentNext = Continuation
    Kind = N(Node - 1).Kind
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.SourceLocation, S.CurrentModule, Node, N(Node - 1).Line, N(Node - 1).Column) = False Then Exit Function
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Label, Node, 0, 0, 0) = False Then Exit Function
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ControlSite, Node, 0, 0, 0) = False Then Exit Function
    If Kind = SourceParser.VariableNode Or Kind = SourceParser.AssignmentNode Then
        If TryEmitAssignment(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, Node, Terminated) = False Then Exit Function
    ElseIf Kind = SourceParser.CallNode Or Kind = SourceParser.ThreadStartNode Then
        Value = NativeExpressions.EmitExpression(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, Node, Terminated)
        If S.Text.Failed Then Exit Function
    ElseIf Kind = SourceParser.GoToNode Or Kind = SourceParser.ExitNode Then
        Target = 0
        If Kind = SourceParser.GoToNode Then
            Target = A(E(Node - 1).SymbolIndex - 1).DeclarationNode
        ElseIf N(Node - 1).Value = SyntaxTokens.KwDo Then
            Target = S.LoopExit
        End If
        If NativeStorage.ReleaseAllPins(S, B, Token, Catalog, P(S.CurrentSymbol - 1).PinCount) = False Then Exit Function
        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Branch, Target, 0, 0, 0) = False Then Exit Function
        Terminated = True
    ElseIf Kind = SourceParser.OnErrorNode Then
        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ControlHandler, E(Node - 1).SymbolIndex, 0, 0, 0) = False Then Exit Function
    ElseIf Kind = SourceParser.IfNode Then
        Child = N(Node - 1).FirstChild
        ThenNode = N(Child - 1).NextSibling
        ElseNode = N(ThenNode - 1).NextSibling
        Value = NativeExpressions.EmitExpression(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, Child, Terminated)
        If S.Text.Failed Then Exit Function
        If Terminated = False Then
            Test = NativeEmission.NewValue(S)
            If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ValueNonzero, Test, Value, 0, 0) = False Then Exit Function
            If NativeStorage.ReleaseAllPins(S, B, Token, Catalog, P(S.CurrentSymbol - 1).PinCount) = False Then Exit Function
            ThenEntry = SequenceEntry(N, ThenNode, Continuation)
            ElseEntry = SequenceEntry(N, ElseNode, Continuation)
            If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ConditionalBranch, Test, ThenEntry, ElseEntry, 0) = False Then Exit Function
        End If
        If TryEmitSequence(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, ThenNode, Continuation) = False Then Exit Function
        If TryEmitSequence(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, ElseNode, Continuation) = False Then Exit Function
        Terminated = True
    ElseIf Kind = SourceParser.DoNode Then
        If TryEmitLoop(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, Node, Continuation) = False Then Exit Function
        Terminated = True
    ElseIf Kind <> SourceParser.ConstantNode And Kind <> SourceParser.LabelNode Then
        S.Text.Failed = True
        S.FailureCode = 9
        S.FailureReason = 64
        Exit Function
    End If
    If Terminated = False Then
        If NativeStorage.ReleaseAllPins(S, B, Token, Catalog, P(S.CurrentSymbol - 1).PinCount) = False Then Exit Function
        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Branch, Continuation, 0, 0, 0) = False Then Exit Function
    End If
    TryEmitStatement = True
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function
