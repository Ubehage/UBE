UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeThreads"
' Emits asynchronous captures and statically bound entry thunks using ordinary call semantics.

Private Intrinsic Function ResizeValues(ByRef Values() As Long, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeValues.UBE_Primitive = "Array.TryResize"
End Function

' Appends one fragment of an ordinary native call signature.
Private Function Fragment(ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal Template As Long, ByVal First As Long, ByVal Second As Long) As Boolean
    On Error GoTo Failed
    Fragment = LLVMFormat.TryFormat(S.Text, B, Token, Catalog, Template, First, Second, 0, 0)
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
End Function

' Drops only the references acquired by this capture, never the caller's references.
Private Function DropCaptures(ByRef N() As SourceParser.SyntaxNode, ByRef E() As ExpressionBinder.BoundExpression, ByRef F() As NativeEscapes.EscapeFact, ByRef Owners() As Long, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal Node As Long) As Boolean
    Dim Argument As Long
    Dim Index As Long
    Dim HasArray As Long
    Dim Released As Boolean
    Dim Collected As Long
    On Error GoTo Failed
    Argument = N(N(Node - 1).FirstChild - 1).NextSibling
    Do While Argument <> 0
        If NativeEmission.Charge(S) = False Then Exit Function
        If F(Argument - 1).NeedsOwner Then
            HasArray = 0
            If E(Argument - 1).ArrayRank <> 0 Then HasArray = 1
            If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.DropOwner, Owners(Index), HasArray, 0, 0) = False Then Exit Function
            Released = True
        End If
        Index = Index + 1
        Argument = N(Argument - 1).NextSibling
    Loop
    If Released Then
        Collected = NativeEmission.NewValue(S)
        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CollectMemory, Collected, 0, 0, 0) = False Then Exit Function
    End If
    DropCaptures = True
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
End Function

' Publishes a fully captured call, then cleans up the caller's temporary references on either outcome.
Public Function EmitStart(ByRef N() As SourceParser.SyntaxNode, ByRef E() As ExpressionBinder.BoundExpression, ByRef P() As NativePlanning.NativeSymbolPlan, ByRef F() As NativeEscapes.EscapeFact, ByRef Pins() As Long, ByRef Values() As Long, ByRef Owners() As Long, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Nexts() As Long, ByVal Node As Long, ByVal Count As Long) As Long
    Dim Block As Long
    Dim Payload As Long
    Dim Accepted As Long
    Dim Pair As Long
    Dim Pointer As Long
    Dim Index As Long
    Dim Argument As Long
    Dim Cells As Long
    Dim Template As Long
    Dim FailureBlock As Long
    Dim DoneBlock As Long
    Dim Result As Long
    On Error GoTo Failed
    Cells = Count + Count
    If Cells = 0 Then Cells = 1
    Block = NativeEmission.NewValue(S)
    Payload = NativeEmission.NewValue(S)
    Accepted = NativeEmission.NewValue(S)
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.NewOwner, Block, Cells, 0, 0) = False Then Exit Function
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.OwnerAllocated, Accepted, Block, 0, 0) = False Then Exit Function
    If NativeEmission.GuardStatus(S, B, Token, Catalog, Seen, Nexts, Accepted) = False Then Exit Function
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.OwnerPayload, Payload, Block, 0, 0) = False Then Exit Function
    Argument = N(N(Node - 1).FirstChild - 1).NextSibling
    Do While Argument <> 0
        If NativeEmission.Charge(S) = False Then Exit Function
        Pointer = NativeEmission.NewValue(S)
        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CellAddress, Pointer, Payload, Index + Index, 0) = False Then Exit Function
        Template = LLVMTemplates.StoreValue
        If E(Argument - 1).ArgumentMode <> 1 Or E(Argument - 1).ArrayRank <> 0 Or E(Argument - 1).TypeSymbol <> 0 Then Template = LLVMTemplates.StorePointer
        If NativeEmission.TryLine(S, B, Token, Catalog, Template, Values(Index), Pointer, 0, 0) = False Then Exit Function
        If F(Argument - 1).NeedsOwner Then
            Pointer = NativeEmission.NewValue(S)
            If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CellAddress, Pointer, Payload, Index + Index + 1, 0) = False Then Exit Function
            If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.RetainOwner, Owners(Index), 0, 0, 0) = False Then Exit Function
            If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.StorePointer, Owners(Index), Pointer, 0, 0) = False Then Exit Function
        End If
        Index = Index + 1
        Argument = N(Argument - 1).NextSibling
    Loop
    Pair = NativeEmission.NewValue(S)
    Accepted = NativeEmission.NewValue(S)
    FailureBlock = NativeEmission.NewBlock(S)
    DoneBlock = NativeEmission.NewBlock(S)
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.StartThread, Pair, Node, Block, 0) = False Then Exit Function
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CallSuccess, Accepted, Pair, 0, 0) = False Then Exit Function
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ConditionalBranch, Accepted, DoneBlock, FailureBlock, 0) = False Then Exit Function
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Label, FailureBlock, 0, 0, 0) = False Then Exit Function
    If DropCaptures(N, E, F, Owners, S, B, Token, Catalog, Node) = False Then Exit Function
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.DropOwner, Block, 0, 0, 0) = False Then Exit Function
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Branch, DoneBlock, 0, 0, 0) = False Then Exit Function
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Label, DoneBlock, 0, 0, 0) = False Then Exit Function
    If NativeStorage.ReleaseNodePins(N, E, Pins, S, B, Token, Catalog, Node) = False Then Exit Function
    If NativeFrames.TryReleaseArgumentArrays(N, E, P, F, S, B, Token, Catalog, Node) = False Then Exit Function
    If NativeEmission.GuardCall(S, B, Token, Catalog, Seen, Nexts, Pair) = False Then Exit Function
    Result = NativeEmission.NewValue(S)
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CallValue, Result, Pair, 0, 0) = False Then Exit Function
    EmitStart = Result
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Reconstructs a statically checked ordinary call and returns only its fresh completion outcome.
Private Function TryEmitThunk(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByRef P() As NativePlanning.NativeSymbolPlan, ByRef F() As NativeEscapes.EscapeFact, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal Node As Long) As Boolean
    Dim Values() As Long
    Dim Owners() As Long
    Dim Argument As Long
    Dim Parameter As Long
    Dim Symbol As Long
    Dim Index As Long
    Dim Pointer As Long
    Dim Pair As Long
    Dim Accepted As Long
    Dim Template As Long
    On Error GoTo Failed
    If ResizeValues(Values, 64, False) = False Then GoTo Failed
    If ResizeValues(Owners, 64, False) = False Then GoTo Failed
    S.ValueNumber = 0
    S.CurrentNode = Node
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ThreadThunkStart, Node, 0, 0, 0) = False Then Exit Function
    Argument = N(N(Node - 1).FirstChild - 1).NextSibling
    Do While Argument <> 0
        If NativeEmission.Charge(S) = False Then Exit Function
        Pointer = NativeEmission.NewValue(S)
        Values(Index) = NativeEmission.NewValue(S)
        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CaptureAddress, Pointer, Index + Index, 0, 0) = False Then Exit Function
        Template = LLVMTemplates.LoadVolatileValue
        If E(Argument - 1).ArgumentMode <> 1 Or E(Argument - 1).ArrayRank <> 0 Or E(Argument - 1).TypeSymbol <> 0 Then Template = LLVMTemplates.LoadOwnerPointer
        If NativeEmission.TryLine(S, B, Token, Catalog, Template, Values(Index), Pointer, 0, 0) = False Then Exit Function
        If F(Argument - 1).NeedsOwner Then
            Pointer = NativeEmission.NewValue(S)
            Owners(Index) = NativeEmission.NewValue(S)
            If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CaptureAddress, Pointer, Index + Index + 1, 0, 0) = False Then Exit Function
            If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.LoadOwnerPointer, Owners(Index), Pointer, 0, 0) = False Then Exit Function
        End If
        Index = Index + 1
        Argument = N(Argument - 1).NextSibling
    Loop
    Accepted = NativeEmission.NewValue(S)
    If E(Node - 1).TrustedRole = 2 Then
        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.StoreErrorValue, Values(0), 0, 0, 0) = False Then Exit Function
        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.BooleanConstant, Accepted, 0, 0, 0) = False Then Exit Function
    ElseIf E(Node - 1).TrustedRole = 3 Then
        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.StoreError, 0, 0, 0, 0) = False Then Exit Function
        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.BooleanConstant, Accepted, 1, 0, 0) = False Then Exit Function
    Else
        Symbol = E(Node - 1).SymbolIndex
        Parameter = A(Symbol - 1).FirstParameter
        Pair = NativeEmission.NewValue(S)
        If Fragment(S, B, Token, Catalog, LLVMTemplates.CallStart, Pair, Symbol) = False Then Exit Function
        Index = 0
        Argument = N(N(Node - 1).FirstChild - 1).NextSibling
        Do While Argument <> 0
            If NativeEmission.Charge(S) = False Then Exit Function
            Template = LLVMTemplates.CallValueArgument
            If E(Argument - 1).ArgumentMode <> 1 Or E(Argument - 1).ArrayRank <> 0 Or E(Argument - 1).TypeSymbol <> 0 Then Template = LLVMTemplates.CallReferenceArgument
            If Fragment(S, B, Token, Catalog, Template, Values(Index), 0) = False Then Exit Function
            If NativeOwnership.HasIncomingOwner(A, P, Parameter) Then
                If Fragment(S, B, Token, Catalog, LLVMTemplates.CallReferenceArgument, Owners(Index), 0) = False Then Exit Function
            End If
            Index = Index + 1
            Parameter = A(Parameter - 1).NextParameter
            Argument = N(Argument - 1).NextSibling
        Loop
        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CallEnd, 0, 0, 0, 0) = False Then Exit Function
        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CallSuccess, Accepted, Pair, 0, 0) = False Then Exit Function
    End If
    If DropCaptures(N, E, F, Owners, S, B, Token, Catalog, Node) = False Then Exit Function
    TryEmitThunk = NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ThreadThunkEnd, Accepted, 0, 0, 0)
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Emits each call site's thunk once while traversing only its owning lexical scope.
Public Function TryEmitThunks(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByRef P() As NativePlanning.NativeSymbolPlan, ByRef F() As NativeEscapes.EscapeFact, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal Symbol As Long) As Boolean
    Dim Root As Long
    Dim Node As Long
    On Error GoTo Failed
    Root = A(Symbol - 1).DeclarationNode
    Node = Root
    Do While Node <> 0
        If NativeEmission.Charge(S) = False Then Exit Function
        If N(Node - 1).Kind = SourceParser.ThreadStartNode And E(Node - 1).ScopeSymbol = Symbol Then
            If TryEmitThunk(N, A, E, P, F, S, B, Token, Catalog, Node) = False Then Exit Function
        End If
        Node = NativeFrames.NextInScope(N, Root, Node)
    Loop
    TryEmitThunks = True
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function
