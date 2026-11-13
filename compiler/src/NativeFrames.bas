UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeFrames"
' Emits invocation-local control cells, preallocated storage and balanced native returns.

' Walks one lexical subtree without rescanning other procedures or recursively consuming host frames.
Public Function NextInScope(ByRef N() As SourceParser.SyntaxNode, ByVal Root As Long, ByVal Node As Long) As Long
    Dim Kind As Long
    On Error GoTo Failed
    Kind = N(Node - 1).Kind
    If Node = Root Or (Kind <> SourceParser.SubNode And Kind <> SourceParser.FunctionNode And Kind <> SourceParser.TypeNode) Then
        If N(Node - 1).FirstChild <> 0 Then NextInScope = N(Node - 1).FirstChild: Exit Function
    End If
    Do While Node <> Root
        If N(Node - 1).NextSibling <> 0 Then NextInScope = N(Node - 1).NextSibling: Exit Function
        Node = N(Node - 1).Parent
    Loop
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Emits a signature fragment without introducing a newline between its ordered parameters.
Private Function Fragment(ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal Template As Long, ByVal Value As Long) As Boolean
    On Error GoTo Failed
    If S.Text.Failed Then Exit Function
    Fragment = LLVMFormat.TryFormat(S.Text, B, Token, Catalog, Template, Value, 0, 0, 0)
    If S.Text.Failed Then S.ErrorNode = S.CurrentNode
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Allocates each local owner, value parameter, grouped temporary and borrow slot once at native entry.
Private Function EmitFrame(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByRef L() As AggregateLayout.StorageFact, ByRef P() As NativePlanning.NativeSymbolPlan, ByRef Escapes() As NativeEscapes.EscapeFact, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte) As Boolean
    Dim Symbol As Long
    Dim Kind As Long
    Dim Node As Long
    Dim Root As Long
    Dim Address As Long
    Dim Slot As Long
    Dim Cells As Long
    On Error GoTo Failed
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.FrameControls, 0, 0, 0, 0) = False Then Exit Function
    Symbol = P(S.CurrentSymbol - 1).FirstScopeSymbol
    Do While Symbol <> 0
        If NativeEmission.Charge(S) = False Then Exit Function
        Kind = A(Symbol - 1).Kind
        If Kind = SourceParser.VariableNode Or Kind = DeclarationBinder.ResultSymbol Or (Kind = SourceParser.ParameterNode And A(Symbol - 1).PassingMode = SyntaxTokens.KwByVal And A(Symbol - 1).ArrayRank = 0 And A(Symbol - 1).TypeSymbol = 0) Then
            Node = A(Symbol - 1).DeclarationNode
            If P(Symbol - 1).ContextOffset < 0 Then
                If NativeOwnership.HasLocalBox(A, P, Symbol) Then
                    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.AllocateLocalOwner, Symbol, 0, 0, 0) = False Then Exit Function
                Else
                    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.AllocateSlot, Symbol, L(Node - 1).StorageCells, 0, 0) = False Then Exit Function
                    If Kind = SourceParser.ParameterNode Then
                        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.StoreParameter, Symbol, 0, 0, 0) = False Then Exit Function
                    Else
                        Address = NativeStorage.StorageAddress(A, P, S, B, Token, Catalog, Symbol)
                        If Address = 0 Then Exit Function
                        If NativeStorage.NeutralStorage(A, E, L, S, B, Token, Catalog, Symbol, Address, False, False) = False Then Exit Function
                    End If
                End If
            ElseIf A(Symbol - 1).ArrayRank = 1 Then
                Address = NativeStorage.StorageAddress(A, P, S, B, Token, Catalog, Symbol)
                If Address = 0 Then Exit Function
                If NativeStorage.NeutralStorage(A, E, L, S, B, Token, Catalog, Symbol, Address, True, False) = False Then Exit Function
            End If
        End If
        Symbol = P(Symbol - 1).NextScopeSymbol
    Loop
    Root = A(S.CurrentSymbol - 1).DeclarationNode
    Node = Root
    Do While Node <> 0
        If NativeEmission.Charge(S) = False Then Exit Function
        If E(Node - 1).ScopeSymbol = S.CurrentSymbol And Escapes(Node - 1).NeedsOwner And Escapes(Node - 1).OwnerKind = NativeEscapes.TemporaryOwner Then
            If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.AllocateTemporaryOwner, Node, 0, 0, 0) = False Then Exit Function
        ElseIf E(Node - 1).ScopeSymbol = S.CurrentSymbol And E(Node - 1).ArgumentMode = 3 Then
            If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.AllocateTemporary, Node, 0, 0, 0) = False Then Exit Function
        ElseIf E(Node - 1).ScopeSymbol = S.CurrentSymbol And E(Node - 1).ArgumentMode = 1 Then
            Cells = 0
            If E(Node - 1).ArrayRank <> 0 Then
                Cells = 4
            ElseIf E(Node - 1).TypeSymbol <> 0 Then
                Cells = L(Node - 1).StorageCells
            End If
            If Cells <> 0 Then
                If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.AllocateAggregateTemporary, Node, Cells, 0, 0) = False Then Exit Function
                If E(Node - 1).ArrayRank <> 0 Then
                    Address = NativeStorage.TempAddress(Escapes, S, B, Token, Catalog, Node)
                    If Address = 0 Then Exit Function
                    If NativeStorage.TryInitializeEmptyArray(S, B, Token, Catalog, Address) = False Then Exit Function
                End If
            End If
        End If
        Node = NextInScope(N, Root, Node)
    Loop
    Slot = 1
    Do While Slot <= P(S.CurrentSymbol - 1).PinCount
        If NativeEmission.Charge(S) = False Then Exit Function
        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.AllocatePin, Slot, 0, 0, 0) = False Then Exit Function
        Slot = Slot + 1
    Loop
    EmitFrame = True
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Starts an ordinary procedure and guards call depth before any source statement can execute.
Public Function TryProcedureStart(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByRef L() As AggregateLayout.StorageFact, ByRef P() As NativePlanning.NativeSymbolPlan, ByRef Escapes() As NativeEscapes.EscapeFact, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal Symbol As Long, ByVal NodeCount As Long, ByRef Body As Long) As Boolean
    Dim Parameter As Long
    Dim Template As Long
    Dim Child As Long
    Dim EntryNode As Long
    Dim Initialized As Long
    On Error GoTo Failed
    Body = 0
    If S.Text.Failed Then Exit Function
    NativeEmission.BeginFunction S, Symbol, A(Symbol - 1).ModuleIndex, NodeCount, P(Symbol - 1).ResultSymbol, True
    S.CurrentNode = A(Symbol - 1).DeclarationNode
    If Fragment(S, B, Token, Catalog, LLVMTemplates.ProcedureStart, Symbol) = False Then Exit Function
    Parameter = A(Symbol - 1).FirstParameter
    Do While Parameter <> 0
        If NativeEmission.Charge(S) = False Then Exit Function
        Template = LLVMTemplates.ValueParameter
        If A(Parameter - 1).PassingMode = SyntaxTokens.KwByRef Or A(Parameter - 1).ArrayRank <> 0 Or A(Parameter - 1).TypeSymbol <> 0 Then Template = LLVMTemplates.ReferenceParameter
        If Fragment(S, B, Token, Catalog, Template, Parameter) = False Then Exit Function
        If NativeOwnership.HasIncomingOwner(A, P, Parameter) Then
            If Fragment(S, B, Token, Catalog, LLVMTemplates.OwnerParameter, Parameter) = False Then Exit Function
        End If
        Parameter = A(Parameter - 1).NextParameter
    Loop
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ProcedureBody, 0, 0, 0, 0) = False Then Exit Function
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ProcedurePointers, 0, 0, 0, 0) = False Then Exit Function
    If EmitFrame(N, A, E, L, P, Escapes, S, B, Token, Catalog) = False Then Exit Function
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ProcedureDepth, 0, 0, 0, 0) = False Then Exit Function
    If NativeOwnership.TryInitializeLocals(A, E, L, P, S, B, Token, Catalog) = False Then Exit Function
    Initialized = NativeEmission.NewValue(S)
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.EnsureModuleValue, Initialized, S.CurrentModule, 0, 0) = False Then Exit Function
    Child = N(A(Symbol - 1).DeclarationNode - 1).FirstChild
    Do While Child <> 0
        If NativeEmission.Charge(S) = False Then Exit Function
        If N(Child - 1).Kind = SourceParser.BodyNode Then Body = Child: Exit Do
        Child = N(Child - 1).NextSibling
    Loop
    If Body <> 0 Then EntryNode = N(Body - 1).FirstChild
    TryProcedureStart = NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Branch, EntryNode, 0, 0, 0)
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Starts a module initializer with descriptor headers established before declaration-order initialization.
Public Function TryModuleStart(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByRef L() As AggregateLayout.StorageFact, ByRef P() As NativePlanning.NativeSymbolPlan, ByRef Escapes() As NativeEscapes.EscapeFact, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal ModuleSymbol As Long, ByVal NodeCount As Long, ByRef FirstVariable As Long) As Boolean
    Dim Child As Long
    On Error GoTo Failed
    FirstVariable = 0
    If S.Text.Failed Then Exit Function
    NativeEmission.BeginFunction S, ModuleSymbol, A(ModuleSymbol - 1).ModuleIndex, NodeCount, 0, False
    S.CurrentNode = A(ModuleSymbol - 1).DeclarationNode
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ModuleInitializeStart, S.CurrentModule, 0, 0, 0) = False Then Exit Function
    If EmitFrame(N, A, E, L, P, Escapes, S, B, Token, Catalog) = False Then Exit Function
    Child = N(A(ModuleSymbol - 1).DeclarationNode - 1).FirstChild
    Do While Child <> 0
        If NativeEmission.Charge(S) = False Then Exit Function
        If N(Child - 1).Kind = SourceParser.VariableNode Then FirstVariable = Child: Exit Do
        Child = N(Child - 1).NextSibling
    Loop
    TryModuleStart = NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Branch, FirstVariable, 0, 0, 0)
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Releases caller-owned array snapshots in one completed call or abandoned invocation subtree.
' Every descriptor is initialized at entry, so unevaluated and already released arguments are harmless.
Public Function TryReleaseArgumentArrays(ByRef N() As SourceParser.SyntaxNode, ByRef E() As ExpressionBinder.BoundExpression, ByRef P() As NativePlanning.NativeSymbolPlan, ByRef Escapes() As NativeEscapes.EscapeFact, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal Root As Long) As Boolean
    Dim Node As Long
    Dim Address As Long
    Dim Collected As Long
    Dim Released As Boolean
    On Error GoTo Failed
    If S.Text.Failed Then Exit Function
    If P(S.CurrentSymbol - 1).ArgumentArrayCount = 0 And P(S.CurrentSymbol - 1).TemporaryOwnerCount = 0 Then TryReleaseArgumentArrays = True: Exit Function
    Node = Root
    Do While Node <> 0
        If NativeEmission.Charge(S) = False Then Exit Function
        If E(Node - 1).ScopeSymbol = S.CurrentSymbol And Escapes(Node - 1).NeedsOwner And Escapes(Node - 1).OwnerKind = NativeEscapes.TemporaryOwner Then
            If NativeOwnership.ReleaseTemporary(E, S, B, Token, Catalog, Node) = False Then Exit Function
            Released = True
        ElseIf E(Node - 1).ScopeSymbol = S.CurrentSymbol And E(Node - 1).ArgumentMode = 1 And E(Node - 1).ArrayRank <> 0 Then
            Address = NativeStorage.TempAddress(Escapes, S, B, Token, Catalog, Node)
            If Address = 0 Then Exit Function
            If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ClearArray, Address, 0, 0, 0) = False Then Exit Function
            Released = True
        End If
        Node = NextInScope(N, Root, Node)
    Loop
    If Released Then
        Collected = NativeEmission.NewValue(S)
        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CollectMemory, Collected, 0, 0, 0) = False Then Exit Function
    End If
    TryReleaseArgumentArrays = True
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Dispatches fresh failures after releasing abandoned borrows and private argument snapshots.
Public Function TryFailureDispatch(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByRef P() As NativePlanning.NativeSymbolPlan, ByRef Escapes() As NativeEscapes.EscapeFact, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Nexts() As Long) As Boolean
    Dim Symbol As Long
    Dim Root As Long
    Dim Node As Long
    On Error GoTo Failed
    If S.Text.Failed Then Exit Function
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.FailureDispatchLabel, 0, 0, 0, 0) = False Then Exit Function
    If NativeStorage.ReleaseAllPins(S, B, Token, Catalog, P(S.CurrentSymbol - 1).PinCount) = False Then Exit Function
    If TryReleaseArgumentArrays(N, E, P, Escapes, S, B, Token, Catalog, A(S.CurrentSymbol - 1).DeclarationNode) = False Then Exit Function
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.FailureHandlerDispatch, 0, 0, 0, 0) = False Then Exit Function
    Symbol = P(S.CurrentSymbol - 1).FirstScopeSymbol
    Do While Symbol <> 0
        If NativeEmission.Charge(S) = False Then Exit Function
        If A(Symbol - 1).Kind = SourceParser.LabelNode Then
            If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.SwitchCase, Symbol, A(Symbol - 1).DeclarationNode, 0, 0) = False Then Exit Function
        End If
        Symbol = P(Symbol - 1).NextScopeSymbol
    Loop
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.SwitchEnd, 0, 0, 0, 0) = False Then Exit Function
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.FailureSkipDispatch, 0, 0, 0, 0) = False Then Exit Function
    Root = A(S.CurrentSymbol - 1).DeclarationNode
    Node = Root
    Do While Node <> 0
        If NativeEmission.Charge(S) = False Then Exit Function
        If Seen(Node - 1) = S.CurrentSymbol Then
            If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.SwitchCase, Node, Nexts(Node - 1), 0, 0) = False Then Exit Function
        End If
        Node = NextInScope(N, Root, Node)
    Loop
    TryFailureDispatch = NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.SwitchEnd, 0, 0, 0, 0)
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Balances pins, owned arrays and guarded depth on both successful and failed source returns.
Public Function TryReturns(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByRef P() As NativePlanning.NativeSymbolPlan, ByRef Escapes() As NativeEscapes.EscapeFact, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal SymbolCount As Long) As Boolean
    Dim Value As Long
    Dim Result As Long
    Dim Address As Long
    On Error GoTo Failed
    If S.Text.Failed Then Exit Function
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Label, 0, 0, 0, 0) = False Then Exit Function
    If NativeStorage.ReleaseAllPins(S, B, Token, Catalog, P(S.CurrentSymbol - 1).PinCount) = False Then Exit Function
    If TryReleaseArgumentArrays(N, E, P, Escapes, S, B, Token, Catalog, A(S.CurrentSymbol - 1).DeclarationNode) = False Then Exit Function
    If NativeStorage.ReleaseLocalArrays(A, P, S, B, Token, Catalog, SymbolCount) = False Then Exit Function
    If S.CountedDepth Then
        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ReturnDepthSuccess, 0, 0, 0, 0) = False Then Exit Function
    End If
    If S.ResultSymbol = 0 Then
        Value = NativeEmission.Literal(S, B, Token, Catalog, 0)
        If Value = 0 Then Exit Function
    Else
        Address = NativeStorage.StorageAddress(A, P, S, B, Token, Catalog, S.ResultSymbol)
        If Address = 0 Then Exit Function
        Value = NativeEmission.NewValue(S)
        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.LoadVolatileValue, Value, Address, 0, 0) = False Then Exit Function
    End If
    If NativeOwnership.ReleaseLocals(A, P, S, B, Token, Catalog) = False Then Exit Function
    Result = NativeEmission.NewValue(S)
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ReturnSuccessValue, Result, Value, 0, 0) = False Then Exit Function
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ReturnFailureLabel, 0, 0, 0, 0) = False Then Exit Function
    If NativeOwnership.ReleaseLocals(A, P, S, B, Token, Catalog) = False Then Exit Function
    If NativeStorage.ReleaseAllPins(S, B, Token, Catalog, P(S.CurrentSymbol - 1).PinCount) = False Then Exit Function
    If TryReleaseArgumentArrays(N, E, P, Escapes, S, B, Token, Catalog, A(S.CurrentSymbol - 1).DeclarationNode) = False Then Exit Function
    If NativeStorage.ReleaseLocalArrays(A, P, S, B, Token, Catalog, SymbolCount) = False Then Exit Function
    If S.CountedDepth Then
        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ReturnDepthFailure, 0, 0, 0, 0) = False Then Exit Function
    End If
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ReturnFailedValue, 0, 0, 0, 0) = False Then Exit Function
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.FunctionEnd, 0, 0, 0, 0) = False Then Exit Function
    TryReturns = LLVMWriter.TryEndLine(S.Text, B, Token)
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Defines the on-access initializer wrapper; only validated acyclic initialization dependencies reach lowering.
Public Function TryModuleEnsure(ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal ModuleIndex As Long) As Boolean
    On Error GoTo Failed
    If S.Text.Failed Then Exit Function
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ModuleEnsureDefinition, ModuleIndex, 0, 0, 0) = False Then Exit Function
    TryModuleEnsure = LLVMWriter.TryEndLine(S.Text, B, Token)
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function
