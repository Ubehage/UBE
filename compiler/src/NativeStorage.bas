UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeStorage"
' Emits caller-planned storage paths, original-payload borrows and owned aggregate lifecycle operations.

' Allocates bounded compiler-side SSA snapshot identities.
Private Intrinsic Function ResizeValues(ByRef Values() As Long, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeValues.UBE_Primitive = "Array.TryResize"
End Function

' Measures the exact completed snapshot to commit.
Private Intrinsic Function ValueCount(ByRef Values() As Long) As Long
Attribute ValueCount.UBE_Primitive = "Array.Length"
End Function

' Ensures a referenced module has completed before cross-module storage access.
Public Function EnsureModule(ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal ModuleIndex As Long) As Boolean
    Dim Value As Long
    On Error GoTo Failed
    If S.Text.Failed Then Exit Function
    If ModuleIndex = S.CurrentModule Then EnsureModule = True: Exit Function
    Value = NativeEmission.NewValue(S)
    EnsureModule = NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.EnsureModuleValue, Value, ModuleIndex, 0, 0)
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Returns an SSA pointer for context, borrowed parameter or owned local storage.
Public Function StorageAddress(ByRef A() As DeclarationBinder.BoundSymbol, ByRef P() As NativePlanning.NativeSymbolPlan, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal Symbol As Long) As Long
    Dim Value As Long
    Dim Template As Long
    On Error GoTo Failed
    If S.Text.Failed Then Exit Function
    Value = NativeEmission.NewValue(S)
    If P(Symbol - 1).ContextOffset >= 0 Then
        If Not EnsureModule(S, B, Token, Catalog, A(Symbol - 1).ModuleIndex) Then Exit Function
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ContextAddress, Value, P(Symbol - 1).ContextOffset, 0, 0) Then Exit Function
    Else
        Template = LLVMTemplates.SlotAddress
        If A(Symbol - 1).Kind = SourceParser.ParameterNode And A(Symbol - 1).PassingMode = SyntaxTokens.KwByRef Then Template = LLVMTemplates.ArgumentAddress
        If Not NativeEmission.TryLine(S, B, Token, Catalog, Template, Value, Symbol, 0, 0) Then Exit Function
    End If
    StorageAddress = Value
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Returns the address of one preplanned grouped-ByRef temporary.
Public Function TempAddress(ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal Node As Long) As Long
    Dim Value As Long
    On Error GoTo Failed
    If S.Text.Failed Then Exit Function
    Value = NativeEmission.NewValue(S)
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.TemporaryAddress, Value, Node, 0, 0) Then Exit Function
    TempAddress = Value
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Resolves one lvalue, retaining the captured indexed payload before index evaluation can replace it.
Public Function EmitAddress(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByRef L() As AggregateLayout.StorageFact, ByRef P() As NativePlanning.NativeSymbolPlan, ByRef Pins() As Long, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Nexts() As Long, ByVal Node As Long, ByRef Terminated As Boolean) As Long
    Dim Receiver As Long
    Dim IndexNode As Long
    Dim Symbol As Long
    Dim Base As Long
    Dim Result As Long
    Dim IndexValue As Long
    Dim Lower As Long
    Dim Upper As Long
    Dim Pointer As Long
    Dim Data As Long
    Dim Block As Long
    Dim Below As Long
    Dim Above As Long
    Dim Invalid As Long
    Dim Relative As Long
    Dim Offset As Long
    On Error GoTo Failed
    If Not NativeEmission.Charge(S) Then Exit Function
    If Terminated Then Exit Function
    If N(Node - 1).Kind = SourceParser.GroupNode Then
        EmitAddress = EmitAddress(N, A, E, L, P, Pins, S, B, Token, Catalog, Seen, Nexts, N(Node - 1).FirstChild, Terminated)
        Exit Function
    End If
    If E(Node - 1).AccessKind = 1 Then
        Receiver = N(Node - 1).FirstChild
        Base = EmitAddress(N, A, E, L, P, Pins, S, B, Token, Catalog, Seen, Nexts, Receiver, Terminated)
        If Base = 0 Or Terminated Then Exit Function
        Symbol = E(Node - 1).SymbolIndex
        Result = NativeEmission.NewValue(S)
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CellAddress, Result, Base, L(A(Symbol - 1).DeclarationNode - 1).FieldOffset, 0) Then Exit Function
    ElseIf E(Node - 1).AccessKind = 2 Then
        Receiver = N(Node - 1).FirstChild
        IndexNode = N(Receiver - 1).NextSibling
        Base = EmitAddress(N, A, E, L, P, Pins, S, B, Token, Catalog, Seen, Nexts, Receiver, Terminated)
        If Base = 0 Or Terminated Then Exit Function
        Lower = NativeEmission.NewValue(S)
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.LoadValue, Lower, Base, 0, 0) Then Exit Function
        Pointer = NativeEmission.NewValue(S)
        Upper = NativeEmission.NewValue(S)
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CellAddress, Pointer, Base, 1, 0) Then Exit Function
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.LoadValue, Upper, Pointer, 0, 0) Then Exit Function
        Pointer = NativeEmission.NewValue(S)
        Data = NativeEmission.NewValue(S)
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CellAddress, Pointer, Base, 2, 0) Then Exit Function
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.LoadPointer, Data, Pointer, 0, 0) Then Exit Function
        Pointer = NativeEmission.NewValue(S)
        Block = NativeEmission.NewValue(S)
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CellAddress, Pointer, Base, 3, 0) Then Exit Function
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.LoadPointer, Block, Pointer, 0, 0) Then Exit Function
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.RetainBlock, Block, 0, 0, 0) Then Exit Function
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.PinBlock, Block, Pins(Node - 1), 0, 0) Then Exit Function
        IndexValue = NativeExpressions.EmitExpression(N, A, E, L, P, Pins, S, B, Token, Catalog, Seen, Nexts, IndexNode, Terminated)
        If IndexValue = 0 Or Terminated Then Exit Function
        IndexValue = NativeValues.ConvertValue(S, B, Token, Catalog, Seen, Nexts, IndexValue, E(IndexNode - 1).TypeCode, SyntaxTokens.KwLongLong)
        If IndexValue = 0 Then Exit Function
        Below = NativeEmission.NewValue(S)
        Above = NativeEmission.NewValue(S)
        Invalid = NativeEmission.NewValue(S)
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.BelowBound, Below, IndexValue, Lower, 0) Then Exit Function
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.AboveBound, Above, IndexValue, Upper, 0) Then Exit Function
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.EitherCondition, Invalid, Below, Above, 0) Then Exit Function
        If Not NativeEmission.GuardError(S, B, Token, Catalog, Seen, Nexts, Invalid, 9) Then Exit Function
        Relative = NativeEmission.NewValue(S)
        Offset = NativeEmission.NewValue(S)
        Result = NativeEmission.NewValue(S)
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.RelativeIndex, Relative, IndexValue, Lower, 0) Then Exit Function
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ElementOffset, Offset, Relative, L(Receiver - 1).ElementCells, 0) Then Exit Function
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.IndexedAddress, Result, Data, Offset, 0) Then Exit Function
    Else
        Result = StorageAddress(A, P, S, B, Token, Catalog, E(Node - 1).SymbolIndex)
    End If
    EmitAddress = Result
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Drops one prepared borrow and clears its slot before any later cleanup can repeat it.
Public Function ReleasePin(ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal Slot As Long) As Boolean
    Dim Block As Long
    On Error GoTo Failed
    If S.Text.Failed Then Exit Function
    Block = NativeEmission.NewValue(S)
    ReleasePin = NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ReleasePin, Block, Slot, 0, 0)
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Releases only borrows belonging to a completed expression subtree.
Public Function ReleaseNodePins(ByRef N() As SourceParser.SyntaxNode, ByRef E() As ExpressionBinder.BoundExpression, ByRef Pins() As Long, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal Node As Long) As Boolean
    Dim Child As Long
    On Error GoTo Failed
    If Not NativeEmission.Charge(S) Then Exit Function
    If E(Node - 1).AccessKind = 2 Then
        If Not ReleasePin(S, B, Token, Catalog, Pins(Node - 1)) Then Exit Function
    End If
    Child = N(Node - 1).FirstChild
    Do While Child <> 0
        If Not ReleaseNodePins(N, E, Pins, S, B, Token, Catalog, Child) Then Exit Function
        Child = N(Child - 1).NextSibling
    Loop
    ReleaseNodePins = True
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Clears all invocation borrow slots before collecting eligible retired blocks.
Public Function ReleaseAllPins(ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal Count As Long) As Boolean
    Dim Slot As Long = 1
    Dim Collected As Long
    On Error GoTo Failed
    If S.Text.Failed Then Exit Function
    Do While Slot <= Count
        If Not NativeEmission.Charge(S) Then Exit Function
        If Not ReleasePin(S, B, Token, Catalog, Slot) Then Exit Function
        Slot = Slot + 1
    Loop
    Collected = NativeEmission.NewValue(S)
    ReleaseAllPins = NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CollectMemory, Collected, 0, 0, 0)
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Releases local owned arrays only; borrowed parameters retain their caller's ownership.
Public Function ReleaseLocalArrays(ByRef A() As DeclarationBinder.BoundSymbol, ByRef P() As NativePlanning.NativeSymbolPlan, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal SymbolCount As Long) As Boolean
    Dim Symbol As Long
    Dim Address As Long
    Dim Collected As Long
    On Error GoTo Failed
    If S.Text.Failed Then Exit Function
    If Not S.CountedDepth Then ReleaseLocalArrays = True: Exit Function
    Symbol = P(S.CurrentSymbol - 1).FirstScopeSymbol
    Do While Symbol <> 0
        If Not NativeEmission.Charge(S) Then Exit Function
        If A(Symbol - 1).ScopeSymbol = S.CurrentSymbol And A(Symbol - 1).Kind = SourceParser.VariableNode And A(Symbol - 1).ArrayRank = 1 Then
            Address = StorageAddress(A, P, S, B, Token, Catalog, Symbol)
            If Address = 0 Then Exit Function
            If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ClearArray, Address, 0, 0, 0) Then Exit Function
        End If
        Symbol = P(Symbol - 1).NextScopeSymbol
    Loop
    Collected = NativeEmission.NewValue(S)
    ReleaseLocalArrays = NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CollectMemory, Collected, 0, 0, 0)
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Reads the complete bounded aggregate before any destination write can alias it.
Public Function SnapshotCells(ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal Address As Long, ByVal Count As Long, ByRef Values() As Long) As Boolean
    Dim Index As Long
    Dim Pointer As Long
    Dim Value As Long
    On Error GoTo Failed
    If S.Text.Failed Then Exit Function
    If Count < 1 Or Count > 128 Then
        S.Text.Failed = True
        S.FailureCode = 9
        S.FailureReason = 62
        S.ErrorNode = S.CurrentNode
        Exit Function
    End If
    If Not ResizeValues(Values, Count, False) Then GoTo Failed
    Do While Index < Count
        Pointer = NativeEmission.NewValue(S)
        Value = NativeEmission.NewValue(S)
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CellAddress, Pointer, Address, Index, 0) Then Exit Function
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.LoadVolatileValue, Value, Pointer, 0, 0) Then Exit Function
        Values(Index) = Value
        Index = Index + 1
    Loop
    SnapshotCells = True
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Commits a completed snapshot with volatile cells to avoid synthesized CRT copies.
Public Function StoreCells(ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal Address As Long, ByRef Values() As Long) As Boolean
    Dim Index As Long
    Dim Count As Long
    Dim Pointer As Long
    On Error GoTo Failed
    If S.Text.Failed Then Exit Function
    Count = ValueCount(Values)
    If Count < 1 Or Count > 128 Then
        S.Text.Failed = True
        S.FailureCode = 9
        S.FailureReason = 62
        S.ErrorNode = S.CurrentNode
        Exit Function
    End If
    Do While Index < Count
        Pointer = NativeEmission.NewValue(S)
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CellAddress, Pointer, Address, Index, 0) Then Exit Function
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.StoreVolatileValue, Values(Index), Pointer, 0, 0) Then Exit Function
        Index = Index + 1
    Loop
    StoreCells = True
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Initializes descriptors and admitted fixed payloads; bulk zero stores stay independent of the CRT.
Public Function NeutralStorage(ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByRef L() As AggregateLayout.StorageFact, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal Symbol As Long, ByVal Address As Long, ByVal HeaderOnly As Boolean, ByVal ReleaseExisting As Boolean) As Boolean
    Dim Index As Long
    Dim Count As Long
    Dim Node As Long
    Dim Pointer As Long
    Dim Data As Long
    Dim Template As Long
    On Error GoTo Failed
    If S.Text.Failed Then Exit Function
    Node = A(Symbol - 1).DeclarationNode
    Count = L(Node - 1).StorageCells
    If A(Symbol - 1).ArrayRank = 1 Then
        If ReleaseExisting Then
            If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ClearArray, Address, 0, 0, 0) Then Exit Function
        End If
        Pointer = NativeEmission.NewValue(S)
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CellAddress, Pointer, Address, 1, 0) Then Exit Function
        If E(Node - 1).HasBounds Then
            If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.StoreConstant, E(Node - 1).LowerBound, Address, 0, 0) Then Exit Function
            If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.StoreConstant, E(Node - 1).UpperBound, Pointer, 0, 0) Then Exit Function
            Data = NativeEmission.NewValue(S)
            If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CellAddress, Data, Address, 4, 0) Then Exit Function
        Else
            If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.StoreConstant, 0, Address, 0, 0) Then Exit Function
            If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.StoreConstant, -1, Pointer, 0, 0) Then Exit Function
        End If
        Pointer = NativeEmission.NewValue(S)
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CellAddress, Pointer, Address, 2, 0) Then Exit Function
        If Data = 0 Then
            If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.StoreNullPointer, Pointer, 0, 0, 0) Then Exit Function
        Else
            If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.StorePointer, Data, Pointer, 0, 0) Then Exit Function
        End If
        Pointer = NativeEmission.NewValue(S)
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CellAddress, Pointer, Address, 3, 0) Then Exit Function
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.StoreNullPointer, Pointer, 0, 0, 0) Then Exit Function
        If HeaderOnly Then NeutralStorage = True: Exit Function
        Index = 4
        Template = LLVMTemplates.StoreVolatileConstant
    Else
        Template = LLVMTemplates.StoreConstant
        If Count > 1 Then Template = LLVMTemplates.StoreVolatileConstant
    End If
    Do While Index < Count
        Pointer = NativeEmission.NewValue(S)
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CellAddress, Pointer, Address, Index, 0) Then Exit Function
        If Not NativeEmission.TryLine(S, B, Token, Catalog, Template, 0, Pointer, 0, 0) Then Exit Function
        Index = Index + 1
    Loop
    NeutralStorage = True
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function
