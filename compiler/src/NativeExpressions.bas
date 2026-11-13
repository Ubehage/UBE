UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeExpressions"
' Lowers validated expressions in written order, preserving fresh failures and storage identities.

' Holds prepared argument SSA identities without consuming a large fixed compiler frame.
Private Intrinsic Function ResizeValues(ByRef Values() As Long, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeValues.UBE_Primitive = "Array.TryResize"
End Function

' Records an impossible internal expression request without accepting partial output.
Private Sub InvalidRequest(ByRef S As NativeEmission.EmissionState)
    S.Text.Failed = True
    S.FailureCode = 9
    S.FailureReason = 62
    S.ErrorNode = S.CurrentNode
End Sub

' Writes part of a call instruction only after all argument evaluation has completed.
Private Function Fragment(ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal Template As Long, ByVal P0 As LongLong, ByVal P1 As LongLong) As Boolean
    On Error GoTo Failed
    If S.Text.Failed Then Exit Function
    Fragment = LLVMFormat.TryFormat(S.Text, B, Token, Catalog, Template, P0, P1, 0, 0)
    If S.Text.Failed Then S.ErrorNode = S.CurrentNode
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Captures the complete left record before any right-side evaluation can mutate its storage.
Private Function EmitRecordComparison(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByRef L() As AggregateLayout.StorageFact, ByRef P() As NativePlanning.NativeSymbolPlan, ByRef Pins() As Long, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Nexts() As Long, ByVal Node As Long, ByRef Terminated As Boolean) As Long
    Dim LeftNode As Long
    Dim RightNode As Long
    Dim Count As Long
    Dim Index As Long
    Dim Address As Long
    Dim LeftValues() As Long
    Dim RightValues() As Long
    Dim Equal As Long
    Dim Test As Long
    Dim Combined As Long
    Dim Result As Long
    On Error GoTo Failed
    LeftNode = N(Node - 1).FirstChild
    RightNode = N(LeftNode - 1).NextSibling
    Count = L(LeftNode - 1).StorageCells
    If Count < 1 Or Count > 128 Then InvalidRequest S: Exit Function
    Address = NativeStorage.EmitAddress(N, A, E, L, P, Pins, S, B, Token, Catalog, Seen, Nexts, LeftNode, Terminated)
    If Address = 0 Or Terminated Then Exit Function
    If NativeStorage.SnapshotCells(S, B, Token, Catalog, Address, Count, LeftValues) = False Then Exit Function
    If NativeStorage.ReleaseNodePins(N, E, Pins, S, B, Token, Catalog, LeftNode) = False Then Exit Function
    Address = NativeStorage.EmitAddress(N, A, E, L, P, Pins, S, B, Token, Catalog, Seen, Nexts, RightNode, Terminated)
    If Address = 0 Or Terminated Then Exit Function
    If NativeStorage.SnapshotCells(S, B, Token, Catalog, Address, Count, RightValues) = False Then Exit Function
    If NativeStorage.ReleaseNodePins(N, E, Pins, S, B, Token, Catalog, RightNode) = False Then Exit Function
    Do While Index < Count
        Test = NativeEmission.NewValue(S)
        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CompareEqual, Test, LeftValues(Index), RightValues(Index), 0) = False Then Exit Function
        If Index = 0 Then
            Equal = Test
        Else
            Combined = NativeEmission.NewValue(S)
            If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.BooleanAnd, Combined, Equal, Test, 0) = False Then Exit Function
            Equal = Combined
        End If
        Index = Index + 1
    Loop
    If N(Node - 1).Value = SyntaxTokens.SymNotEqual Then
        Test = NativeEmission.NewValue(S)
        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.BooleanInvert, Test, Equal, 0, 0) = False Then Exit Function
        Equal = Test
    End If
    Result = NativeEmission.NewValue(S)
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.BooleanSelect, Result, Equal, 0, 0) = False Then Exit Function
    EmitRecordComparison = Result
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Prepares arguments once in source order and guards the fresh call result after releasing borrows.
Private Function EmitCall(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByRef L() As AggregateLayout.StorageFact, ByRef P() As NativePlanning.NativeSymbolPlan, ByRef Pins() As Long, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Nexts() As Long, ByVal Node As Long, ByRef Terminated As Boolean) As Long
    Dim Values() As Long
    Dim Symbol As Long
    Dim Callee As Long
    Dim Argument As Long
    Dim Count As Long
    Dim Index As Long
    Dim Value As Long
    Dim Address As Long
    Dim Pair As Long
    Dim Result As Long
    Dim Template As Long
    Dim Role As Long
    On Error GoTo Failed
    Symbol = E(Node - 1).SymbolIndex
    Role = E(Node - 1).TrustedRole
    Callee = N(Node - 1).FirstChild
    Argument = N(Callee - 1).NextSibling
    If ResizeValues(Values, 64, False) = False Then GoTo Failed
    Do While Argument <> 0
        If Count >= 64 Then InvalidRequest S: Exit Function
        If E(Argument - 1).ArgumentMode = 2 Then
            Value = NativeStorage.EmitAddress(N, A, E, L, P, Pins, S, B, Token, Catalog, Seen, Nexts, Argument, Terminated)
            If Value = 0 Or Terminated Then Exit Function
        ElseIf E(Argument - 1).ArgumentMode = 1 And E(Argument - 1).ConstantKnown And Role = 0 Then
            ' A checked pure constant can be materialized after module initialization without spanning its call.
            Value = 0
        Else
            Value = EmitConvertedExpression(N, A, E, L, P, Pins, S, B, Token, Catalog, Seen, Nexts, Argument, E(Argument - 1).ConvertedType, Terminated)
            If Value = 0 Or Terminated Then Exit Function
            If E(Argument - 1).ArgumentMode = 3 Then
                Address = NativeStorage.TempAddress(S, B, Token, Catalog, Argument)
                If Address = 0 Then Exit Function
                If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.StoreValue, Value, Address, 0, 0) = False Then Exit Function
                Value = Address
            End If
        End If
        Values(Count) = Value
        Count = Count + 1
        Argument = N(Argument - 1).NextSibling
    Loop
    If Role = 2 Then
        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.StoreErrorValue, Value, 0, 0, 0) = False Then Exit Function
        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ReturnFailureBranch, 0, 0, 0, 0) = False Then Exit Function
        Terminated = True
        Exit Function
    ElseIf Role = 3 Then
        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.StoreError, 0, 0, 0, 0) = False Then Exit Function
        EmitCall = NativeEmission.Literal(S, B, Token, Catalog, 0)
        Exit Function
    End If
    If Symbol < 1 Then InvalidRequest S: Exit Function
    If NativeStorage.EnsureModule(S, B, Token, Catalog, A(Symbol - 1).ModuleIndex) = False Then Exit Function
    Argument = N(Callee - 1).NextSibling
    Do While Argument <> 0
        If Values(Index) = 0 Then
            Value = EmitConvertedExpression(N, A, E, L, P, Pins, S, B, Token, Catalog, Seen, Nexts, Argument, E(Argument - 1).ConvertedType, Terminated)
            If Value = 0 Or Terminated Then Exit Function
            Values(Index) = Value
        End If
        Index = Index + 1
        Argument = N(Argument - 1).NextSibling
    Loop
    Index = 0
    Pair = NativeEmission.NewValue(S)
    If Fragment(S, B, Token, Catalog, LLVMTemplates.CallStart, Pair, Symbol) = False Then Exit Function
    Argument = N(Callee - 1).NextSibling
    Do While Argument <> 0
        Template = LLVMTemplates.CallValueArgument
        If E(Argument - 1).ArgumentMode = 2 Or E(Argument - 1).ArgumentMode = 3 Then Template = LLVMTemplates.CallReferenceArgument
        If Fragment(S, B, Token, Catalog, Template, Values(Index), 0) = False Then Exit Function
        Index = Index + 1
        Argument = N(Argument - 1).NextSibling
    Loop
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CallEnd, 0, 0, 0, 0) = False Then Exit Function
    If NativeStorage.ReleaseNodePins(N, E, Pins, S, B, Token, Catalog, Node) = False Then Exit Function
    If NativeEmission.GuardCall(S, B, Token, Catalog, Seen, Nexts, Pair) = False Then Exit Function
    Result = NativeEmission.NewValue(S)
    If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CallValue, Result, Pair, 0, 0) = False Then Exit Function
    EmitCall = Result
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Converts a checked constant before materialization; runtime values retain their ordinary checked conversion edge.
Public Function EmitConvertedExpression(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByRef L() As AggregateLayout.StorageFact, ByRef P() As NativePlanning.NativeSymbolPlan, ByRef Pins() As Long, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Nexts() As Long, ByVal Node As Long, ByVal DestinationType As Long, ByRef Terminated As Boolean) As Long
    Dim Converted As LongLong
    Dim Reason As Long
    Dim Value As Long
    On Error GoTo Failed
    If S.Text.Failed Or Terminated Then Exit Function
    If DestinationType = 0 Then DestinationType = E(Node - 1).TypeCode
    If E(Node - 1).ConstantKnown Then
        If Not NativeEmission.Charge(S) Then Exit Function
        If Not ConstantValues.TryConvert(E(Node - 1).ConstantValue, E(Node - 1).TypeCode, DestinationType, Converted, Reason) Then InvalidRequest S: Exit Function
        EmitConvertedExpression = NativeEmission.Literal(S, B, Token, Catalog, Converted)
        Exit Function
    End If
    Value = EmitExpression(N, A, E, L, P, Pins, S, B, Token, Catalog, Seen, Nexts, Node, Terminated)
    If Value = 0 Or Terminated Then Exit Function
    EmitConvertedExpression = NativeValues.ConvertValue(S, B, Token, Catalog, Seen, Nexts, Value, E(Node - 1).TypeCode, DestinationType)
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function

' Lowers every admitted scalar expression or call using already checked identities and types.
Public Function EmitExpression(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByRef L() As AggregateLayout.StorageFact, ByRef P() As NativePlanning.NativeSymbolPlan, ByRef Pins() As Long, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Nexts() As Long, ByVal Node As Long, ByRef Terminated As Boolean) As Long
    Dim Kind As Long
    Dim Child As Long
    Dim RightNode As Long
    Dim LeftValue As Long
    Dim RightValue As Long
    Dim Address As Long
    Dim Result As Long
    Dim Test As Long
    Dim Template As Long
    Dim Operator As Long
    On Error GoTo Failed
    If Terminated Then Exit Function
    If NativeEmission.Charge(S) = False Then Exit Function
    If E(Node - 1).ConstantKnown Then
        EmitExpression = NativeEmission.Literal(S, B, Token, Catalog, E(Node - 1).ConstantValue)
        Exit Function
    End If
    If E(Node - 1).AccessKind = 1 Or E(Node - 1).AccessKind = 2 Then
        Address = NativeStorage.EmitAddress(N, A, E, L, P, Pins, S, B, Token, Catalog, Seen, Nexts, Node, Terminated)
        If Address = 0 Or Terminated Then Exit Function
        Result = NativeEmission.NewValue(S)
        If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.LoadValue, Result, Address, 0, 0) = False Then Exit Function
        If NativeStorage.ReleaseNodePins(N, E, Pins, S, B, Token, Catalog, Node) = False Then Exit Function
        EmitExpression = Result
        Exit Function
    End If
    Kind = N(Node - 1).Kind
    If Kind = SourceParser.NameNode Or Kind = SourceParser.MemberNode Then
        If E(Node - 1).TrustedRole = 4 Then
            Result = NativeEmission.NewValue(S)
            If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.LoadError, Result, 0, 0, 0) = False Then Exit Function
        Else
            Address = NativeStorage.StorageAddress(A, P, S, B, Token, Catalog, E(Node - 1).SymbolIndex)
            If Address = 0 Then Exit Function
            Result = NativeEmission.NewValue(S)
            If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.LoadValue, Result, Address, 0, 0) = False Then Exit Function
        End If
    ElseIf Kind = SourceParser.GroupNode Then
        Result = EmitExpression(N, A, E, L, P, Pins, S, B, Token, Catalog, Seen, Nexts, N(Node - 1).FirstChild, Terminated)
    ElseIf Kind = SourceParser.UnaryNode Then
        Child = N(Node - 1).FirstChild
        LeftValue = EmitConvertedExpression(N, A, E, L, P, Pins, S, B, Token, Catalog, Seen, Nexts, Child, E(Child - 1).ConvertedType, Terminated)
        If LeftValue = 0 Or Terminated Then Exit Function
        Operator = N(Node - 1).Value
        If Operator = SyntaxTokens.SymMinus Then
            RightValue = NativeEmission.Literal(S, B, Token, Catalog, 0)
            Result = NativeValues.CheckedArithmetic(S, B, Token, Catalog, Seen, Nexts, RightValue, LeftValue, E(Node - 1).TypeCode, True)
        ElseIf Operator = SyntaxTokens.KwNot Then
            Result = NativeValues.Complement(S, B, Token, Catalog, Seen, Nexts, LeftValue, E(Node - 1).TypeCode)
        ElseIf Operator = SyntaxTokens.SymPlus Then
            Result = LeftValue
        Else
            InvalidRequest S: Exit Function
        End If
    ElseIf Kind = SourceParser.CallNode Then
        Result = EmitCall(N, A, E, L, P, Pins, S, B, Token, Catalog, Seen, Nexts, Node, Terminated)
    ElseIf Kind = SourceParser.BinaryNode Then
        Child = N(Node - 1).FirstChild
        If E(Child - 1).TypeSymbol <> 0 Then
            EmitExpression = EmitRecordComparison(N, A, E, L, P, Pins, S, B, Token, Catalog, Seen, Nexts, Node, Terminated)
            Exit Function
        End If
        RightNode = N(Child - 1).NextSibling
        LeftValue = EmitConvertedExpression(N, A, E, L, P, Pins, S, B, Token, Catalog, Seen, Nexts, Child, E(Child - 1).ConvertedType, Terminated)
        If LeftValue = 0 Or Terminated Then Exit Function
        RightValue = EmitConvertedExpression(N, A, E, L, P, Pins, S, B, Token, Catalog, Seen, Nexts, RightNode, E(RightNode - 1).ConvertedType, Terminated)
        If RightValue = 0 Or Terminated Then Exit Function
        Operator = N(Node - 1).Value
        If Operator = SyntaxTokens.SymPlus Or Operator = SyntaxTokens.SymMinus Then
            Result = NativeValues.CheckedArithmetic(S, B, Token, Catalog, Seen, Nexts, LeftValue, RightValue, E(Node - 1).TypeCode, Operator = SyntaxTokens.SymMinus)
        ElseIf Operator = SyntaxTokens.KwAnd Or Operator = SyntaxTokens.KwOr Then
            Template = LLVMTemplates.IntegerAnd
            If Operator = SyntaxTokens.KwOr Then Template = LLVMTemplates.IntegerOr
            Result = NativeEmission.NewValue(S)
            If NativeEmission.TryLine(S, B, Token, Catalog, Template, Result, LeftValue, RightValue, 0) = False Then Exit Function
        Else
            If Operator = SyntaxTokens.SymEqual Then Template = LLVMTemplates.CompareEqual
            If Operator = SyntaxTokens.SymNotEqual Then Template = LLVMTemplates.DifferentValues
            If Operator = SyntaxTokens.SymLess Then Template = LLVMTemplates.BelowBound
            If Operator = SyntaxTokens.SymGreater Then Template = LLVMTemplates.AboveBound
            If Operator = SyntaxTokens.SymLessEqual Then Template = LLVMTemplates.CompareLessEqual
            If Operator = SyntaxTokens.SymGreaterEqual Then Template = LLVMTemplates.CompareGreaterEqual
            If Template = 0 Then InvalidRequest S: Exit Function
            Test = NativeEmission.NewValue(S)
            Result = NativeEmission.NewValue(S)
            If NativeEmission.TryLine(S, B, Token, Catalog, Template, Test, LeftValue, RightValue, 0) = False Then Exit Function
            If NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.BooleanSelect, Result, Test, 0, 0) = False Then Exit Function
        End If
    Else
        InvalidRequest S: Exit Function
    End If
    If S.Text.Failed Or Terminated Then Exit Function
    EmitExpression = Result
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = S.CurrentNode
End Function
