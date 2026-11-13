UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeOwnership"
' Emits retained storage owners for arguments that can outlive an invocation.

' Borrowed pointers carry their owner's block only when an asynchronous alias can escape.
Public Function HasIncomingOwner(ByRef A() As DeclarationBinder.BoundSymbol, ByRef P() As NativePlanning.NativeSymbolPlan, ByVal Symbol As Long) As Boolean
    If A(Symbol - 1).Kind <> SourceParser.ParameterNode Then Exit Function
    If P(Symbol - 1).StorageEscapes = False Then Exit Function
    HasIncomingOwner = A(Symbol - 1).PassingMode = SyntaxTokens.KwByRef Or A(Symbol - 1).ArrayRank <> 0 Or A(Symbol - 1).TypeSymbol <> 0
End Function

' Locals and scalar value parameters own boxes; pointer parameters borrow an incoming owner.
Public Function HasLocalBox(ByRef A() As DeclarationBinder.BoundSymbol, ByRef P() As NativePlanning.NativeSymbolPlan, ByVal Symbol As Long) As Boolean
    If P(Symbol - 1).ContextOffset >= 0 Or P(Symbol - 1).StorageEscapes = False Then Exit Function
    HasLocalBox = HasIncomingOwner(A, P, Symbol) = False
End Function

' Materializes an owner pointer without changing its reference count.
Public Function SymbolOwner(ByRef A() As DeclarationBinder.BoundSymbol, ByRef P() As NativePlanning.NativeSymbolPlan, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal Symbol As Long) As Long
    Dim Value As Long
    Dim Template As Long
    On Error GoTo Failed
    Value = NativeEmission.NewValue(S)
    Template = LLVMTemplates.NullOwner
    If P(Symbol - 1).ContextOffset < 0 Then
        Template = LLVMTemplates.LoadLocalOwner
        If HasIncomingOwner(A, P, Symbol) Then Template = LLVMTemplates.IncomingOwner
    End If
    If NativeEmission.TryLine(S, B, Token, Catalog, Template, Value, Symbol, 0, 0) = False Then Exit Function
    SymbolOwner = Value
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Obtains the owner chosen by static analysis after the argument address has been evaluated.
Public Function ArgumentOwner(ByRef A() As DeclarationBinder.BoundSymbol, ByRef P() As NativePlanning.NativeSymbolPlan, ByRef F() As NativeEscapes.EscapeFact, ByRef Pins() As Long, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal Node As Long) As Long
    Dim Value As Long
    Dim Template As Long
    Dim Identity As Long
    On Error GoTo Failed
    Identity = F(Node - 1).OwnerIdentity
    If F(Node - 1).OwnerKind = NativeEscapes.SymbolOwner Or F(Node - 1).OwnerKind = NativeEscapes.ProgramOwner Then
        ArgumentOwner = SymbolOwner(A, P, S, B, Token, Catalog, Identity)
        Exit Function
    End If
    Template = LLVMTemplates.LoadTemporaryOwner
    If F(Node - 1).OwnerKind = NativeEscapes.PayloadOwner Then
        Template = LLVMTemplates.LoadPinOwner
        Identity = Pins(Identity - 1)
    End If
    Value = NativeEmission.NewValue(S)
    If NativeEmission.TryLine(S, B, Token, Catalog, Template, Value, Identity, 0, 0) = False Then Exit Function
    ArgumentOwner = Value
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Allocates a distinct box for each dynamic argument evaluation, including loop iterations.
Public Function TryAllocateTemporary(ByRef E() As ExpressionBinder.BoundExpression, ByRef L() As AggregateLayout.StorageFact, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Nexts() As Long, ByVal Node As Long) As Boolean
    Dim Cells As Long
    Dim Block As Long
    Dim Accepted As Long
    Dim Address As Long
    On Error GoTo Failed
    Cells = 1
    If E(Node - 1).TypeSymbol <> 0 Then Cells = L(Node - 1).StorageCells
    If E(Node - 1).ArrayRank <> 0 Then Cells = 4
    Block = NativeEmission.NewValue(S)
    Accepted = NativeEmission.NewValue(S)
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.NewOwner, Block, Cells, 0, 0) = False Then Exit Function
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.OwnerAllocated, Accepted, Block, 0, 0) = False Then Exit Function
    If NativeEmission.GuardStatus(S, B, Token, Catalog, Seen, Nexts, Accepted) = False Then Exit Function
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.SetTemporaryOwner, Node, Block, 0, 0) = False Then Exit Function
    If E(Node - 1).ArrayRank <> 0 Then
        Address = NativeEmission.NewValue(S)
        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.OwnerPayload, Address, Block, 0, 0) = False Then Exit Function
        If NativeStorage.TryInitializeEmptyArray(S, B, Token, Catalog, Address) = False Then Exit Function
    End If
    TryAllocateTemporary = True
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Drops a completed or abandoned argument box while preserving boxes retained by workers.
Public Function ReleaseTemporary(ByRef E() As ExpressionBinder.BoundExpression, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal Node As Long) As Boolean
    Dim Block As Long
    Dim HasArray As Long
    On Error GoTo Failed
    If E(Node - 1).ArrayRank <> 0 Then HasArray = 1
    Block = NativeEmission.NewValue(S)
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.LoadTemporaryOwner, Block, Node, 0, 0) = False Then Exit Function
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.DropOwner, Block, HasArray, 0, 0) = False Then Exit Function
    ReleaseTemporary = NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ClearTemporaryOwner, Node, 0, 0, 0)
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Installs a separately owned fixed payload, preserving its declared lower and upper bounds.
Public Function TryResetFixedArray(ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByRef L() As AggregateLayout.StorageFact, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Nexts() As Long, ByVal Symbol As Long, ByVal Address As Long, ByVal Prologue As Boolean) As Boolean
    Dim Node As Long
    Dim Block As Long
    Dim Accepted As Long
    Dim Cells As Long
    On Error GoTo Failed
    Node = A(Symbol - 1).DeclarationNode
    Cells = E(Node - 1).UpperBound - E(Node - 1).LowerBound + 1
    Block = NativeEmission.NewValue(S)
    Accepted = NativeEmission.NewValue(S)
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.NewArrayOwner, Block, Cells, L(Node - 1).ElementCells, 0) = False Then Exit Function
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.OwnerAllocated, Accepted, Block, 0, 0) = False Then Exit Function
    If Prologue Then
        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.OwnerEntryGuard, Accepted, 0, 0, 0) = False Then Exit Function
    Else
        If NativeEmission.GuardStatus(S, B, Token, Catalog, Seen, Nexts, Accepted) = False Then Exit Function
    End If
    TryResetFixedArray = NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.InstallOwnedArray, Address, Block, E(Node - 1).LowerBound, E(Node - 1).UpperBound)
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Allocates boxed locals only after depth admission and all cleanup slots are initialized.
Public Function TryInitializeLocals(ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByRef L() As AggregateLayout.StorageFact, ByRef P() As NativePlanning.NativeSymbolPlan, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte) As Boolean
    Dim Symbol As Long
    Dim Node As Long
    Dim Cells As Long
    Dim Block As Long
    Dim Accepted As Long
    Dim Address As Long
    Dim Seen() As Long
    Dim Nexts() As Long
    On Error GoTo Failed
    Symbol = P(S.CurrentSymbol - 1).FirstScopeSymbol
    Do While Symbol <> 0
        If NativeEmission.Charge(S) = False Then Exit Function
        If HasLocalBox(A, P, Symbol) Then
            Node = A(Symbol - 1).DeclarationNode
            Cells = L(Node - 1).StorageCells
            If A(Symbol - 1).ArrayRank <> 0 Then Cells = 4
            Block = NativeEmission.NewValue(S)
            Accepted = NativeEmission.NewValue(S)
            Address = NativeEmission.NewValue(S)
            If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.NewOwner, Block, Cells, 0, 0) = False Then Exit Function
            If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.SetLocalOwner, Symbol, Block, 0, 0) = False Then Exit Function
            If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.OwnerAllocated, Accepted, Block, 0, 0) = False Then Exit Function
            If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.OwnerEntryGuard, Accepted, 0, 0, 0) = False Then Exit Function
            If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.OwnerPayload, Address, Block, 0, 0) = False Then Exit Function
            If A(Symbol - 1).ArrayRank <> 0 Then
                If NativeStorage.TryInitializeEmptyArray(S, B, Token, Catalog, Address) = False Then Exit Function
                If E(Node - 1).HasBounds Then
                    If TryResetFixedArray(A, E, L, S, B, Token, Catalog, Seen, Nexts, Symbol, Address, True) = False Then Exit Function
                End If
            ElseIf A(Symbol - 1).Kind = SourceParser.ParameterNode Then
                If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.StoreBoxParameter, Symbol, Address, 0, 0) = False Then Exit Function
            End If
        End If
        Symbol = P(Symbol - 1).NextScopeSymbol
    Loop
    TryInitializeLocals = True
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Releases the invocation's references without clearing a descriptor still owned by a worker.
Public Function ReleaseLocals(ByRef A() As DeclarationBinder.BoundSymbol, ByRef P() As NativePlanning.NativeSymbolPlan, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte) As Boolean
    Dim Symbol As Long
    Dim Block As Long
    Dim HasArray As Long
    Dim Released As Boolean
    Dim Collected As Long
    On Error GoTo Failed
    Symbol = P(S.CurrentSymbol - 1).FirstScopeSymbol
    Do While Symbol <> 0
        If NativeEmission.Charge(S) = False Then Exit Function
        If HasLocalBox(A, P, Symbol) Then
            Block = SymbolOwner(A, P, S, B, Token, Catalog, Symbol)
            If Block = 0 Then Exit Function
            HasArray = 0
            If A(Symbol - 1).ArrayRank <> 0 Then HasArray = 1
            If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.DropOwner, Block, HasArray, 0, 0) = False Then Exit Function
            Released = True
        End If
        Symbol = P(Symbol - 1).NextScopeSymbol
    Loop
    If Released Then
        Collected = NativeEmission.NewValue(S)
        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CollectMemory, Collected, 0, 0, 0) = False Then Exit Function
    End If
    ReleaseLocals = True
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function
