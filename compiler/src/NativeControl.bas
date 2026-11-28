UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeControl"
' Emits statement continuations independently of sticky Err, including False branches for failed If tests.
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
    If N(Node - 1).Kind = SourceParser.WhileNode Then
        PreviousExit = S.WhileExit
        S.WhileExit = Continuation
    Else
        PreviousExit = S.LoopExit
        S.LoopExit = Continuation
    End If
    ' A zero continuation is a valid procedure return, not an absent loop.
    If S.LoopDepth = 0 Then S.OutermostLoopExit = Continuation
    S.LoopDepth = S.LoopDepth + 1
    Value = BodyEntry
    If Mode = 1 Or Mode = 2 Then Value = Header
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Branch, Value, 0, 0, 0) = False Then Exit Function
    If TryEmitSequence(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, Body, Header) = False Then Exit Function
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Label, Header, 0, 0, 0) = False Then Exit Function
    If Not NativeFrames.TryLeaveConstructs(N, E, S, B, Token, Catalog, Node, True, False) Then Exit Function
    S.CurrentNode = Node
    S.ErrorNode = Node
    S.CurrentNext = Continuation
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ControlSite, Node, 0, 0, 0) = False Then Exit Function
    If Not NativeFrames.TryRetireTemporaries(P, S, B, Token, Catalog) Then Exit Function
    If Not NativeEmission.Safepoint(S, B, Token, Catalog) Then Exit Function
    If Condition <> 0 Then
        Value = NativeExpressions.EmitConvertedExpression(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, Condition, SyntaxTokens.KwBoolean, Terminated)
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
    If N(Node - 1).Kind = SourceParser.WhileNode Then
        S.WhileExit = PreviousExit
    Else
        S.LoopExit = PreviousExit
    End If
    S.LoopDepth = S.LoopDepth - 1
    TryEmitLoop = True
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Compares already converted loop operands without changing their numeric family.
Private Function CompareLoop(ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal LeftValue As Long, ByVal RightValue As Long, ByVal TypeCode As Long, ByVal LessEqual As Boolean) As Long
    Dim Operator As Long = SyntaxTokens.SymGreaterEqual
    Dim Template As Long = LLVMTemplates.CompareGreaterEqual
    Dim Result As Long
    If LessEqual Then Operator = SyntaxTokens.SymLessEqual: Template = LLVMTemplates.CompareLessEqual
    If ConstantValues.IsFloating(TypeCode) Then
        CompareLoop = NativeValues.FloatingCompare(S, B, Token, Catalog, LeftValue, RightValue, TypeCode, Operator)
        Exit Function
    End If
    Result = NativeEmission.NewValue(S)
    If Not NativeEmission.TryLine(S, B, Token, Catalog, Template, Result, LeftValue, RightValue, 0) Then Exit Function
    CompareLoop = Result
End Function

' Reads one cell from invocation-owned enumeration state without carrying SSA addresses across branches.
Private Function EnumerationValue(ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal Node As Long, ByVal Cell As Long) As Long
    Dim Value As Long
    Value = NativeEmission.NewValue(S)
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.EnumerationLoad, Value, Node, Cell, 0) Then Exit Function
    EnumerationValue = Value
End Function

' Retains the evaluated array storage, not a copy of its elements, until the construct is left.
Private Function TryEmitEach(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByRef L() As AggregateLayout.StorageFact, ByRef P() As NativePlanning.NativeSymbolPlan, ByRef Pins() As Long, ByRef Escapes() As NativeEscapes.EscapeFact, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Nexts() As Long, ByVal Node As Long, ByVal Continuation As Long) As Boolean
    Dim Target As Long
    Dim Collection As Long
    Dim Body As Long
    Dim Header As Long
    Dim Increment As Long
    Dim Advance As Long
    Dim Assign As Long
    Dim BodyEntry As Long
    Dim PreviousExit As Long
    Dim Address As Long
    Dim Index As Long
    Dim Limit As Long
    Dim Lower As Long
    Dim Value As Long
    Dim One As Long
    Dim Test As Long
    Dim Pointer As Long
    Dim Data As Long
    Dim Offset As Long
    Dim Relative As Long
    Dim Template As Long
    Dim Terminated As Boolean
    On Error GoTo Failed
    Target = N(Node - 1).FirstChild
    Collection = N(Target - 1).NextSibling
    Body = N(Collection - 1).NextSibling
    Header = NativeEmission.NewBlock(S)
    Increment = NativeEmission.NewBlock(S)
    Advance = NativeEmission.NewBlock(S)
    Assign = NativeEmission.NewBlock(S)
    BodyEntry = SequenceEntry(N, Body, Increment)
    PreviousExit = S.ForExit
    S.ForExit = Continuation
    If S.LoopDepth = 0 Then S.OutermostLoopExit = Continuation
    S.LoopDepth = S.LoopDepth + 1
    Address = NativeStorage.EmitAddress(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, Collection, Terminated)
    If Address = 0 Or Terminated Then Exit Function
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.EnumerationCapture, Node, Address, 0, 0) Then Exit Function
    If Not NativeStorage.ReleaseAllPins(S, B, Token, Catalog, P(S.CurrentSymbol - 1).PinCount) Then Exit Function
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Branch, Header, 0, 0, 0) Then Exit Function
    If Not TryEmitSequence(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, Body, Increment) Then Exit Function
    S.CurrentNode = Node
    S.ErrorNode = Node
    S.CurrentNext = Continuation
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Label, Increment, 0, 0, 0) Then Exit Function
    If Not NativeFrames.TryLeaveConstructs(N, E, S, B, Token, Catalog, Node, True, False) Then Exit Function
    Index = EnumerationValue(S, B, Token, Catalog, Node, 4)
    Limit = EnumerationValue(S, B, Token, Catalog, Node, 1)
    Test = NativeEmission.NewValue(S)
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CompareGreaterEqual, Test, Index, Limit, 0) Then Exit Function
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ConditionalBranch, Test, Continuation, Advance, 0) Then Exit Function
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Label, Advance, 0, 0, 0) Then Exit Function
    One = NativeEmission.Literal(S, B, Token, Catalog, -1)
    Value = NativeEmission.NewValue(S)
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.RelativeIndex, Value, Index, One, 0) Then Exit Function
    Pointer = NativeEmission.NewValue(S)
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.EnumerationStoreIndex, Pointer, Node, Value, 0) Then Exit Function
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Branch, Header, 0, 0, 0) Then Exit Function
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Label, Header, 0, 0, 0) Then Exit Function
    If Not NativeFrames.TryLeaveConstructs(N, E, S, B, Token, Catalog, Node, True, False) Then Exit Function
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ControlSite, Node, 0, 0, 0) Then Exit Function
    If Not NativeFrames.TryRetireTemporaries(P, S, B, Token, Catalog) Then Exit Function
    If Not NativeEmission.Safepoint(S, B, Token, Catalog) Then Exit Function
    Index = EnumerationValue(S, B, Token, Catalog, Node, 4)
    Limit = EnumerationValue(S, B, Token, Catalog, Node, 1)
    Test = NativeEmission.NewValue(S)
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CompareLessEqual, Test, Index, Limit, 0) Then Exit Function
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ConditionalBranch, Test, Assign, Continuation, 0) Then Exit Function
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Label, Assign, 0, 0, 0) Then Exit Function
    Lower = EnumerationValue(S, B, Token, Catalog, Node, 0)
    Relative = NativeEmission.NewValue(S)
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.RelativeIndex, Relative, Index, Lower, 0) Then Exit Function
    Offset = NativeEmission.NewValue(S)
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ElementOffset, Offset, Relative, L(Collection - 1).ElementCells, 0) Then Exit Function
    Data = NativeEmission.NewValue(S)
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.EnumerationPayload, Data, Node, 0, 0) Then Exit Function
    Address = NativeEmission.NewValue(S)
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.IndexedAddress, Address, Data, Offset, 0) Then Exit Function
    If ManagedLayouts.IsRecordValue(E(Collection - 1).TypeCode, E(Collection - 1).TypeSymbol) Then
        Value = NativeStorage.BoxRecord(A, L, S, B, Token, Catalog, Seen, Nexts, Target, Address, E(Collection - 1).TypeSymbol)
    Else
        Value = NativeEmission.NewValue(S)
        Template = LLVMTemplates.LoadValue
        If ManagedLayouts.IsManagedScalar(E(Collection - 1).TypeCode) Then Template = LLVMTemplates.TextRootLoad
        If Not NativeEmission.TryLine(S, B, Token, Catalog, Template, Value, Address, Target, 0) Then Exit Function
        If E(Collection - 1).TypeCode = SyntaxTokens.KwObject Then
            Value = NativeStorage.BoxReference(S, B, Token, Catalog, Seen, Nexts, Target, Value, E(Collection - 1).TypeSymbol)
        Else
            Value = NativeText.ConvertVariant(A, S, B, Token, Catalog, Seen, Nexts, Target, Value, E(Collection - 1).TypeCode, SyntaxTokens.KwVariant)
        End If
    End If
    If Value = 0 Then Exit Function
    Address = NativeStorage.EmitAddress(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, Target, Terminated)
    If Address = 0 Or Terminated Then Exit Function
    If Not NativeStorage.StoreScalar(S, B, Token, Catalog, Address, Value, SyntaxTokens.KwVariant) Then Exit Function
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Branch, BodyEntry, 0, 0, 0) Then Exit Function
    S.ForExit = PreviousExit
    S.LoopDepth = S.LoopDepth - 1
    TryEmitEach = True
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Bounds and steps live in the checked invocation frame, surviving body calls and recursion.
Private Function TryEmitFor(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByRef L() As AggregateLayout.StorageFact, ByRef P() As NativePlanning.NativeSymbolPlan, ByRef Pins() As Long, ByRef Escapes() As NativeEscapes.EscapeFact, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Nexts() As Long, ByVal Node As Long, ByVal Continuation As Long) As Boolean
    Dim Target As Long
    Dim Initial As Long
    Dim Limit As Long
    Dim StepNode As Long
    Dim Body As Long
    Dim TypeCode As Long
    Dim ArithmeticType As Long
    Dim Address As Long
    Dim Slots As Long
    Dim StepAddress As Long
    Dim InitialValue As Long
    Dim LimitValue As Long
    Dim StepValue As Long
    Dim Value As Long
    Dim Zero As Long
    Dim Test As Long
    Dim Header As Long
    Dim Increment As Long
    Dim Ascending As Long
    Dim Descending As Long
    Dim BodyEntry As Long
    Dim PreviousExit As Long
    Dim Terminated As Boolean
    On Error GoTo Failed
    Target = N(Node - 1).FirstChild
    Initial = N(Target - 1).NextSibling
    Limit = N(Initial - 1).NextSibling
    Body = N(Limit - 1).NextSibling
    If N(Node - 1).Value <> 0 Then StepNode = Body: Body = N(Body - 1).NextSibling
    TypeCode = E(Node - 1).TypeCode
    ArithmeticType = TypeCode
    If TypeCode = SyntaxTokens.KwByte Then ArithmeticType = SyntaxTokens.KwInteger
    Header = NativeEmission.NewBlock(S)
    Increment = NativeEmission.NewBlock(S)
    Ascending = NativeEmission.NewBlock(S)
    Descending = NativeEmission.NewBlock(S)
    BodyEntry = SequenceEntry(N, Body, Increment)
    PreviousExit = S.ForExit
    S.ForExit = Continuation
    If S.LoopDepth = 0 Then S.OutermostLoopExit = Continuation
    S.LoopDepth = S.LoopDepth + 1
    Slots = NativeStorage.TempAddress(Escapes, S, B, Token, Catalog, Node)
    StepAddress = NativeEmission.NewValue(S)
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CellAddress, StepAddress, Slots, 1, 0) Then Exit Function
    InitialValue = NativeExpressions.EmitConvertedExpression(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, Initial, TypeCode, Terminated)
    If Not Terminated Then LimitValue = NativeExpressions.EmitConvertedExpression(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, Limit, TypeCode, Terminated)
    If Not Terminated Then
        If StepNode <> 0 Then
            StepValue = NativeExpressions.EmitConvertedExpression(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, StepNode, TypeCode, Terminated)
        Else
            StepValue = NativeEmission.Literal(S, B, Token, Catalog, 1)
            StepValue = NativeValues.ConvertValue(S, B, Token, Catalog, Seen, Nexts, StepValue, SyntaxTokens.KwLong, TypeCode)
        End If
    End If
    If S.Text.Failed Then Exit Function
    If Not Terminated Then
        Address = NativeStorage.EmitAddress(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, Target, Terminated)
        If Not NativeStorage.StoreScalar(S, B, Token, Catalog, Address, InitialValue, TypeCode) Then Exit Function
        If Not NativeStorage.StoreScalar(S, B, Token, Catalog, Slots, LimitValue, TypeCode) Then Exit Function
        If Not NativeStorage.StoreScalar(S, B, Token, Catalog, StepAddress, StepValue, TypeCode) Then Exit Function
        If Not NativeStorage.ReleaseAllPins(S, B, Token, Catalog, P(S.CurrentSymbol - 1).PinCount) Then Exit Function
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Branch, Header, 0, 0, 0) Then Exit Function
    End If
    If Not TryEmitSequence(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, Body, Increment) Then Exit Function
    S.CurrentNode = Node
    S.ErrorNode = Node
    S.CurrentNext = Continuation
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Label, Increment, 0, 0, 0) Then Exit Function
    If Not NativeFrames.TryLeaveConstructs(N, E, S, B, Token, Catalog, Node, True, False) Then Exit Function
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ControlSite, Node, 0, 0, 0) Then Exit Function
    If Not NativeFrames.TryRetireTemporaries(P, S, B, Token, Catalog) Then Exit Function
    If Not NativeEmission.Safepoint(S, B, Token, Catalog) Then Exit Function
    ' Re-materialize addresses here so arbitrary source branches cannot bypass SSA definitions.
    Slots = NativeStorage.TempAddress(Escapes, S, B, Token, Catalog, Node)
    StepAddress = NativeEmission.NewValue(S)
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CellAddress, StepAddress, Slots, 1, 0) Then Exit Function
    Address = NativeStorage.EmitAddress(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, Target, Terminated)
    Value = NativeEmission.NewValue(S)
    StepValue = NativeEmission.NewValue(S)
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.LoadValue, Value, Address, 0, 0) Then Exit Function
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.LoadValue, StepValue, StepAddress, 0, 0) Then Exit Function
    Value = NativeValues.CheckedArithmetic(S, B, Token, Catalog, Seen, Nexts, Value, StepValue, ArithmeticType, False)
    Value = NativeValues.ConvertValue(S, B, Token, Catalog, Seen, Nexts, Value, ArithmeticType, TypeCode)
    If S.Text.Failed Then Exit Function
    If Not NativeStorage.StoreScalar(S, B, Token, Catalog, Address, Value, TypeCode) Then Exit Function
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Branch, Header, 0, 0, 0) Then Exit Function
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Label, Header, 0, 0, 0) Then Exit Function
    Slots = NativeStorage.TempAddress(Escapes, S, B, Token, Catalog, Node)
    StepAddress = NativeEmission.NewValue(S)
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CellAddress, StepAddress, Slots, 1, 0) Then Exit Function
    Address = NativeStorage.EmitAddress(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, Target, Terminated)
    Value = NativeEmission.NewValue(S)
    StepValue = NativeEmission.NewValue(S)
    LimitValue = NativeEmission.NewValue(S)
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.LoadValue, Value, Address, 0, 0) Then Exit Function
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.LoadValue, StepValue, StepAddress, 0, 0) Then Exit Function
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.LoadValue, LimitValue, Slots, 0, 0) Then Exit Function
    Zero = NativeEmission.Literal(S, B, Token, Catalog, 0)
    Test = CompareLoop(S, B, Token, Catalog, StepValue, Zero, TypeCode, False)
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ConditionalBranch, Test, Ascending, Descending, 0) Then Exit Function
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Label, Ascending, 0, 0, 0) Then Exit Function
    Test = CompareLoop(S, B, Token, Catalog, Value, LimitValue, TypeCode, True)
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ConditionalBranch, Test, BodyEntry, Continuation, 0) Then Exit Function
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Label, Descending, 0, 0, 0) Then Exit Function
    Test = CompareLoop(S, B, Token, Catalog, Value, LimitValue, TypeCode, False)
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ConditionalBranch, Test, BodyEntry, Continuation, 0) Then Exit Function
    S.ForExit = PreviousExit
    S.LoopDepth = S.LoopDepth - 1
    TryEmitFor = True
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
        If E(Target - 1).ArrayRank <> 0 Or ManagedLayouts.IsRecordValue(E(Target - 1).TypeCode, E(Target - 1).TypeSymbol) Then
            If E(ValueNode - 1).TypeCode = SyntaxTokens.KwVariant And E(ValueNode - 1).ArrayRank = 0 Then
                Value = NativeExpressions.EmitExpression(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, ValueNode, Terminated)
                If Value = 0 Or Terminated Then Exit Function
                SourceAddress = NativeStorage.VariantRecordAddress(A, L, S, B, Token, Catalog, Seen, Nexts, Value, E(Target - 1).TypeSymbol)
            Else
                SourceAddress = NativeStorage.EmitAddress(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, ValueNode, Terminated)
            End If
            If S.Text.Failed Then Exit Function
            If Terminated = False Then
                If E(Target - 1).ArrayRank = 1 Then
                    Test = NativeEmission.NewValue(S)
                    If Not NativeStorage.CopyArray(A, L, S, B, Token, Catalog, Test, Address, SourceAddress, L(Target - 1).ElementCells, L(Target - 1).ManagedReferences, E(Target - 1).TypeCode, E(Target - 1).TypeSymbol) Then Exit Function
                    If NativeEmission.GuardStatus(S, B, Token, Catalog, Seen, Nexts, Test) = False Then Exit Function
                Else
                    If NativeStorage.SnapshotCells(S, B, Token, Catalog, SourceAddress, L(Target - 1).StorageCells, Values) = False Then Exit Function
                    If Not NativeStorage.StoreTypedCells(A, L, E(Target - 1).TypeCode, E(Target - 1).TypeSymbol, L(Target - 1).ManagedReferences, S, B, Token, Catalog, Address, Values) Then Exit Function
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
                If Not NativeStorage.StoreScalar(S, B, Token, Catalog, Address, Value, E(Target - 1).TypeCode) Then Exit Function
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
    If Not NativeFrames.TryLeaveConstructs(N, E, S, B, Token, Catalog, Node, False, False) Then Exit Function
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ControlSite, Node, 0, 0, 0) = False Then Exit Function
    If Not NativeFrames.TryRetireTemporaries(P, S, B, Token, Catalog) Then Exit Function
    If Not NativeEmission.Safepoint(S, B, Token, Catalog) Then Exit Function
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
        ElseIf N(Node - 1).Value = SyntaxTokens.KwWhile Then
            Target = S.WhileExit
        ElseIf N(Node - 1).Value = SyntaxTokens.KwFor Then
            Target = S.ForExit
        ElseIf N(Node - 1).Value = SyntaxTokens.KwLoop Then
            Target = S.OutermostLoopExit
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
        ' A fresh condition failure follows the same branch as False; handlers still dispatch first.
        ElseEntry = SequenceEntry(N, ElseNode, Continuation)
        S.CurrentNext = ElseEntry
        Value = NativeExpressions.EmitConvertedExpression(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, Child, SyntaxTokens.KwBoolean, Terminated)
        If S.Text.Failed Then Exit Function
        If Terminated = False Then
            Test = NativeEmission.NewValue(S)
            If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ValueNonzero, Test, Value, 0, 0) = False Then Exit Function
            If NativeStorage.ReleaseAllPins(S, B, Token, Catalog, P(S.CurrentSymbol - 1).PinCount) = False Then Exit Function
            ThenEntry = SequenceEntry(N, ThenNode, Continuation)
            If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ConditionalBranch, Test, ThenEntry, ElseEntry, 0) = False Then Exit Function
        End If
        If TryEmitSequence(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, ThenNode, Continuation) = False Then Exit Function
        If TryEmitSequence(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, ElseNode, Continuation) = False Then Exit Function
        Terminated = True
    ElseIf Kind = SourceParser.SyncLockNode Then
        Child = N(Node - 1).FirstChild
        ThenNode = N(Child - 1).NextSibling
        Value = NativeExpressions.EmitExpression(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, Child, Terminated)
        If S.Text.Failed Then Exit Function
        If Not Terminated Then
            If S.ManagedRoles.MonitorEnterSymbol = 0 Then S.Text.Failed = True: Exit Function
            If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.MonitorCapture, Node, Value, 0, 0) Then Exit Function
            Test = NativeEmission.NewValue(S)
            If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.MonitorAcquire, Test, S.ManagedRoles.MonitorEnterSymbol, Value, 0) Then Exit Function
            If Not NativeEmission.GuardCall(S, B, Token, Catalog, Seen, Nexts, Test) Then Exit Function
            If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.MonitorAcquired, Node, 0, 0, 0) Then Exit Function
            If Not NativeStorage.ReleaseAllPins(S, B, Token, Catalog, P(S.CurrentSymbol - 1).PinCount) Then Exit Function
            ThenEntry = SequenceEntry(N, ThenNode, Continuation)
            If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.Branch, ThenEntry, 0, 0, 0) Then Exit Function
        End If
        If Not TryEmitSequence(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, ThenNode, Continuation) Then Exit Function
        Terminated = True
    ElseIf Kind = SourceParser.DoNode Or Kind = SourceParser.WhileNode Then
        If TryEmitLoop(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, Node, Continuation) = False Then Exit Function
        Terminated = True
    ElseIf Kind = SourceParser.ForNode Then
        If N(Node - 1).Value = 2 Then
            If Not TryEmitEach(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, Node, Continuation) Then Exit Function
        Else
            If Not TryEmitFor(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, Node, Continuation) Then Exit Function
        End If
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
