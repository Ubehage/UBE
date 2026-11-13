UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeLowering"
' Owns freshly validated facts and streams complete native IR only into a caller-owned private stage.
Private Const RuntimeLength As Long = 152116
Private Const RuntimeByteSum As Long = 12376447
Private Intrinsic Function ResizeNumbers(ByRef Values() As Long, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeNumbers.UBE_Primitive = "Array.TryResize"
End Function

' Runtime assets are compiler installation inputs, not user primitive declarations.
' Length and checksum detect accidental corruption; source parity is checked by runtime-text.ps1.
Private Function ValidRuntime(ByRef Text() As Byte) As Boolean
    Dim Index As Long
    Dim Sum As Long
    On Error GoTo Failed
    If BufferPrimitives.ByteStorageLength(Text) <> RuntimeLength Then Exit Function
    Do While Index < RuntimeLength
        Sum = Sum + Text(Index)
        Index = Index + 1
    Loop
    ValidRuntime = Sum = RuntimeByteSum
    Exit Function
Failed:
    Exit Function
End Function

' Preserves an earlier frontend diagnostic, otherwise attaches the failing emission operation to its original source.
Public Sub ReportFailure(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef S As NativeEmission.EmissionState, ByRef D As DeclarationBinder.BindingDiagnostic)
    Dim Index As Long
    Dim Node As Long
    On Error GoTo Failed
    If D.Code <> 0 Then Exit Sub
    D.Code = S.FailureCode
    D.Reason = S.FailureReason
    If D.Code = 0 Then
        D.Code = 7
        D.Reason = S.Text.Failure
        If S.Text.Failure = 2 Then D.Code = 6
        If D.Reason = 0 Then D.Reason = 1
    End If
    D.ModuleIndex = -1
    D.Node = 0
    D.ByteOffset = 0
    D.TokenIndex = -1
    D.Line = 1
    D.Column = 1
    D.Utf16Offset = 1
    Node = S.ErrorNode
    If Node < 1 Or Node > C.NodeCount Then Exit Sub
    D.Node = Node
    D.TokenIndex = N(Node - 1).FirstToken
    D.Line = N(Node - 1).Line
    D.Column = N(Node - 1).Column
    D.Utf16Offset = N(Node - 1).Utf16Start
    Do While Index < C.ModuleCount
        If Node > M(Index).NodeBase And Node <= M(Index).NodeBase + M(Index).NodeCount Then
            D.ModuleIndex = Index
            D.ByteOffset = N(Node - 1).ByteStart - M(Index).ByteBase
            Exit Sub
        End If
        Index = Index + 1
    Loop
    Exit Sub
Failed:
    D.Code = 7
    D.Reason = 1
    D.ModuleIndex = -1
    D.Node = 0
    D.TokenIndex = -1
    D.ByteOffset = 0
    D.Utf16Offset = 1
    D.Line = 1
    D.Column = 1
End Sub


' Resets one private emission stream and validates the installation assets before frontend work.
Public Function TryInitialize(ByRef Catalog() As Byte, ByRef RuntimeText() As Byte, ByRef State As NativeEmission.EmissionState, ByRef Buffer() As Byte) As Boolean
    On Error GoTo Failed
    State.Work = 0
    State.ErrorNode = 0
    State.FailureCode = 0
    State.FailureReason = 0
    If LLVMWriter.TryInitialize(State.Text, Buffer) = False Then GoTo Rejected
    If LLVMFormat.TryValidateCatalog(Catalog) = False Or ValidRuntime(RuntimeText) = False Then
        State.Text.Failed = True
        State.Text.Failure = 3
        GoTo Rejected
    End If
    TryInitialize = True
    Exit Function
Rejected:
    State.Text.Failed = True
    Exit Function
Failed:
    State.Text.Failed = True
    State.Text.Failure = 1
    State.Text.ErrorNumber = Err.Number
End Function


' Derives every authoritative fact from raw retained sources in the existing diagnostic order.
' Results are request-owned scratch until True; only then may immutable snapshots reach range workers.
Public Function TryPrepare(ByRef Bytes() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByRef Nodes() As SourceParser.SyntaxNode, ByRef Modules() As ProjectSyntax.ParsedModule, ByRef Counts As ProjectSyntax.ProjectCounts, ByRef PackageName() As Byte, ByVal IsExecutable As Boolean, ByRef Symbols() As DeclarationBinder.BoundSymbol, ByRef SymbolCount As Long, ByRef EntrySymbol As Long, ByRef Expressions() As ExpressionBinder.BoundExpression, ByRef Layouts() As AggregateLayout.StorageFact, ByRef Plans() As NativePlanning.NativeSymbolPlan, ByRef Pins() As Long, ByRef Escapes() As NativeEscapes.EscapeFact, ByRef Roles() As Long, ByRef Dependencies() As Byte, ByRef Summary As NativePlanning.NativePlanSummary, ByRef Diagnostic As DeclarationBinder.BindingDiagnostic) As Boolean
    Dim FactCount As Long
    Dim EmptySummary As NativePlanning.NativePlanSummary
    On Error GoTo Failed
    SymbolCount = 0
    EntrySymbol = 0
    Summary = EmptySummary
    Diagnostic.Code = 0
    Diagnostic.Reason = 0
    Diagnostic.ModuleIndex = -1
    Diagnostic.Node = 0
    Diagnostic.TokenIndex = -1
    Diagnostic.ByteOffset = 0
    Diagnostic.Utf16Offset = 1
    Diagnostic.Line = 1
    Diagnostic.Column = 1
    If DeclarationBinder.TryBindDeclarations(Bytes, Tokens, Nodes, Modules, Counts, PackageName, IsExecutable, Symbols, SymbolCount, EntrySymbol, Diagnostic) = False Then GoTo Rejected
    If ExpressionBinder.TryBindExpressions(Bytes, Tokens, Nodes, Modules, Counts, PackageName, IsExecutable, Expressions, FactCount, Diagnostic) = False Then GoTo Rejected
    If PrimitiveRoles.TryBindPrimitives(Bytes, Tokens, Nodes, Modules, Counts, PackageName, IsExecutable, Roles, FactCount, Diagnostic) = False Then GoTo Rejected
    If AggregateLayout.TryLayout(Bytes, Tokens, Nodes, Modules, Counts, PackageName, IsExecutable, Layouts, FactCount, Diagnostic) = False Then GoTo Rejected
    If NativePlanning.TryPlanNative(Bytes, Tokens, Nodes, Modules, Counts, Symbols, SymbolCount, Expressions, Layouts, Roles, EntrySymbol, IsExecutable, Plans, Pins, Escapes, Dependencies, Summary, Diagnostic) = False Then GoTo Rejected
    TryPrepare = True
    Exit Function
Rejected:
    SymbolCount = 0
    EntrySymbol = 0
    Summary = EmptySummary
    Exit Function
Failed:
    Diagnostic.Code = 7
    Diagnostic.Reason = 1
    GoTo Rejected
End Function

' Reserves separate traversal tables for one worker without resetting its charged work or writer counters.
Public Function TryInitializeTraversal(ByVal NodeCount As Long, ByRef Seen() As Long, ByRef Nexts() As Long, ByRef State As NativeEmission.EmissionState) As Boolean
    On Error GoTo Failed
    If State.Text.Failed Then Exit Function
    If NodeCount < 1 Or NodeCount > ProjectSyntax.MaximumProjectNodes Then
        State.Text.Failure = 3
        GoTo Rejected
    End If
    If ResizeNumbers(Seen, NodeCount, False) = False Then GoTo Failed
    If ResizeNumbers(Nexts, NodeCount, False) = False Then GoTo Failed
    TryInitializeTraversal = True
    Exit Function
Rejected:
    State.Text.Failed = True
    Exit Function
Failed:
    State.Text.Failed = True
    State.Text.Failure = 1
    State.Text.ErrorNumber = Err.Number
End Function


' Emits the fixed project prefix exactly once after fresh preparation succeeds.
' Facts remain immutable; this internal helper does not validate caller-supplied semantic authority.
Public Function TryBegin(ByRef Symbols() As DeclarationBinder.BoundSymbol, ByVal SymbolCount As Long, ByRef Layouts() As AggregateLayout.StorageFact, ByRef Plans() As NativePlanning.NativeSymbolPlan, ByRef Roles() As Long, ByRef Summary As NativePlanning.NativePlanSummary, ByVal NodeCount As Long, ByRef Catalog() As Byte, ByRef RuntimeText() As Byte, ByVal Token As Long, ByRef State As NativeEmission.EmissionState, ByRef Buffer() As Byte, ByRef Seen() As Long, ByRef Nexts() As Long) As Boolean
    On Error GoTo Failed
    If State.Text.Failed Then Exit Function
    If TryInitializeTraversal(NodeCount, Seen, Nexts, State) = False Then GoTo Rejected
    If LLVMFormat.TryLine(State.Text, Buffer, Token, Catalog, LLVMTemplates.TargetHeader, 0, 0, 0, 0) = False Then GoTo Rejected
    If NativeContext.TryEmitContext(Symbols, Plans, Summary, State.Text, Buffer, Token, Catalog) = False Then GoTo Rejected
    If LLVMWriter.TryAppendSpan(State.Text, Buffer, Token, RuntimeText, 0, RuntimeLength) = False Then GoTo Rejected
    If NativeIntrinsics.TryEmit(Symbols, SymbolCount, Layouts, Roles, State.Text, Buffer, Token, Catalog) = False Then GoTo Rejected
    TryBegin = True
    Exit Function
Rejected:
    State.Text.Failed = True
    Exit Function
Failed:
    State.Text.Failed = True
    State.Text.Failure = 1
    State.Text.ErrorNumber = Err.Number
End Function


' Emits a stable inclusive symbol range using one worker's private traversal and output state.
' Callers supply immutable facts from successful TryPrepare and concatenate ranges in symbol order.
' Work, TotalBytes and LineCount are charged without resets and remain available for request-wide checks.
Public Function TryEmitRange(ByRef Nodes() As SourceParser.SyntaxNode, ByRef Symbols() As DeclarationBinder.BoundSymbol, ByVal SymbolCount As Long, ByRef Expressions() As ExpressionBinder.BoundExpression, ByRef Layouts() As AggregateLayout.StorageFact, ByRef Plans() As NativePlanning.NativeSymbolPlan, ByRef Pins() As Long, ByRef Escapes() As NativeEscapes.EscapeFact, ByRef Roles() As Long, ByVal NodeCount As Long, ByRef Catalog() As Byte, ByVal FirstSymbol As Long, ByVal LastSymbol As Long, ByVal Token As Long, ByRef State As NativeEmission.EmissionState, ByRef Buffer() As Byte, ByRef Seen() As Long, ByRef Nexts() As Long) As Boolean
    Dim Symbol As Long
    Dim Body As Long
    Dim Node As Long
    Dim NextNode As Long
    On Error GoTo Failed
    If State.Text.Failed Then Exit Function
    If SymbolCount < 1 Or SymbolCount > 16384 Or NodeCount < 1 Or NodeCount > ProjectSyntax.MaximumProjectNodes Then
        State.Text.Failure = 3
        GoTo Rejected
    End If
    If FirstSymbol < 1 Or FirstSymbol > SymbolCount + 1 Or LastSymbol < FirstSymbol - 1 Or LastSymbol > SymbolCount Then
        State.Text.Failure = 3
        GoTo Rejected
    End If
    Symbol = FirstSymbol
    Do While Symbol <= LastSymbol
        If NativeEmission.Charge(State) = False Then GoTo Rejected
        If Symbols(Symbol - 1).Kind = SourceParser.ModuleNode Then
            If NativeFrames.TryModuleStart(Nodes, Symbols, Expressions, Layouts, Plans, Escapes, State, Buffer, Token, Catalog, Symbol, NodeCount, Node) = False Then GoTo Rejected
            Do While Node <> 0
                NextNode = Nodes(Node - 1).NextSibling
                Do While NextNode <> 0
                    If NativeEmission.Charge(State) = False Then GoTo Rejected
                    If Nodes(NextNode - 1).Kind = SourceParser.VariableNode Then Exit Do
                    NextNode = Nodes(NextNode - 1).NextSibling
                Loop
                If NativeControl.TryEmitStatement(Nodes, Symbols, Expressions, Layouts, Plans, Pins, Escapes, State, Buffer, Token, Catalog, Seen, Nexts, Node, NextNode) = False Then GoTo Rejected
                Node = NextNode
            Loop
            If NativeFrames.TryFailureDispatch(Nodes, Symbols, Expressions, Plans, Escapes, State, Buffer, Token, Catalog, Seen, Nexts) = False Then GoTo Rejected
            If NativeFrames.TryReturns(Nodes, Symbols, Expressions, Plans, Escapes, State, Buffer, Token, Catalog, SymbolCount) = False Then GoTo Rejected
            If NativeFrames.TryModuleEnsure(State, Buffer, Token, Catalog, Symbols(Symbol - 1).ModuleIndex) = False Then GoTo Rejected
            If NativeThreads.TryEmitThunks(Nodes, Symbols, Expressions, Plans, Escapes, State, Buffer, Token, Catalog, Symbol) = False Then GoTo Rejected
        ElseIf Symbols(Symbol - 1).Kind = SourceParser.SubNode Or Symbols(Symbol - 1).Kind = SourceParser.FunctionNode Then
            Node = Symbols(Symbol - 1).DeclarationNode
            If Roles(Node - 1) = 0 Then
                If NativeFrames.TryProcedureStart(Nodes, Symbols, Expressions, Layouts, Plans, Escapes, State, Buffer, Token, Catalog, Symbol, NodeCount, Body) = False Then GoTo Rejected
                If NativeControl.TryEmitSequence(Nodes, Symbols, Expressions, Layouts, Plans, Pins, Escapes, State, Buffer, Token, Catalog, Seen, Nexts, Body, 0) = False Then GoTo Rejected
                If NativeFrames.TryFailureDispatch(Nodes, Symbols, Expressions, Plans, Escapes, State, Buffer, Token, Catalog, Seen, Nexts) = False Then GoTo Rejected
                If NativeFrames.TryReturns(Nodes, Symbols, Expressions, Plans, Escapes, State, Buffer, Token, Catalog, SymbolCount) = False Then GoTo Rejected
                If NativeThreads.TryEmitThunks(Nodes, Symbols, Expressions, Plans, Escapes, State, Buffer, Token, Catalog, Symbol) = False Then GoTo Rejected
            End If
        End If
        Symbol = Symbol + 1
    Loop
    TryEmitRange = True
    Exit Function
Rejected:
    State.Text.Failed = True
    Exit Function
Failed:
    State.Text.Failed = True
    State.Text.Failure = 1
    State.Text.ErrorNumber = Err.Number
End Function


' Emits the single executable entry after all ordered ranges, then flushes the private stream.
Public Function TryEnd(ByVal IsExecutable As Boolean, ByVal EntrySymbol As Long, ByRef Catalog() As Byte, ByVal Token As Long, ByRef State As NativeEmission.EmissionState, ByRef Buffer() As Byte) As Boolean
    On Error GoTo Failed
    If State.Text.Failed Then Exit Function
    If IsExecutable Then
        If NativeContext.TryEmitEntry(EntrySymbol, State.Text, Buffer, Token, Catalog) = False Then GoTo Rejected
    End If
    If LLVMWriter.TryFinish(State.Text, Buffer, Token) = False Then GoTo Rejected
    TryEnd = True
    Exit Function
Rejected:
    State.Text.Failed = True
    Exit Function
Failed:
    State.Text.Failed = True
    State.Text.Failure = 1
    State.Text.ErrorNumber = Err.Number
End Function


' No supplied declaration/layout/role facts gain authority: all are freshly derived before emission.
' The serial composition retains original validation order, allocations, numbering and global charges.
' Token names a private stage; the driver closes/discards failures and publishes only after validation.
Public Function TryEmit(ByRef Bytes() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByRef Nodes() As SourceParser.SyntaxNode, ByRef Modules() As ProjectSyntax.ParsedModule, ByRef Counts As ProjectSyntax.ProjectCounts, ByRef PackageName() As Byte, ByVal IsExecutable As Boolean, ByRef Catalog() As Byte, ByRef RuntimeText() As Byte, ByVal Token As Long, ByRef State As NativeEmission.EmissionState, ByRef Diagnostic As DeclarationBinder.BindingDiagnostic) As Boolean
    Dim Symbols() As DeclarationBinder.BoundSymbol
    Dim Expressions() As ExpressionBinder.BoundExpression
    Dim Layouts() As AggregateLayout.StorageFact
    Dim Plans() As NativePlanning.NativeSymbolPlan
    Dim Pins() As Long
    Dim Escapes() As NativeEscapes.EscapeFact
    Dim Roles() As Long
    Dim Dependencies() As Byte
    Dim Seen() As Long
    Dim Nexts() As Long
    Dim Buffer() As Byte
    Dim Summary As NativePlanning.NativePlanSummary
    Dim SymbolCount As Long
    Dim EntrySymbol As Long
    On Error GoTo Failed
    Diagnostic.Code = 0
    Diagnostic.Reason = 0
    Diagnostic.ModuleIndex = -1
    Diagnostic.Node = 0
    Diagnostic.TokenIndex = -1
    Diagnostic.ByteOffset = 0
    Diagnostic.Utf16Offset = 1
    Diagnostic.Line = 1
    Diagnostic.Column = 1
    If TryInitialize(Catalog, RuntimeText, State, Buffer) = False Then GoTo Rejected
    If TryPrepare(Bytes, Tokens, Nodes, Modules, Counts, PackageName, IsExecutable, Symbols, SymbolCount, EntrySymbol, Expressions, Layouts, Plans, Pins, Escapes, Roles, Dependencies, Summary, Diagnostic) = False Then GoTo Rejected
    If TryBegin(Symbols, SymbolCount, Layouts, Plans, Roles, Summary, Counts.NodeCount, Catalog, RuntimeText, Token, State, Buffer, Seen, Nexts) = False Then GoTo Rejected
    If TryEmitRange(Nodes, Symbols, SymbolCount, Expressions, Layouts, Plans, Pins, Escapes, Roles, Counts.NodeCount, Catalog, 1, SymbolCount, Token, State, Buffer, Seen, Nexts) = False Then GoTo Rejected
    If TryEnd(IsExecutable, EntrySymbol, Catalog, Token, State, Buffer) = False Then GoTo Rejected
    TryEmit = True
    Exit Function
Rejected:
    State.Text.Failed = True
    ReportFailure Nodes, Modules, Counts, State, Diagnostic
    If Diagnostic.Code = 0 Then Diagnostic.Code = 7: Diagnostic.Reason = 1
    Exit Function
Failed:
    State.Text.Failed = True
    State.Text.Failure = 1
    State.Text.ErrorNumber = Err.Number
    ReportFailure Nodes, Modules, Counts, State, Diagnostic
    If Diagnostic.Code = 0 Then Diagnostic.Code = 7: Diagnostic.Reason = 1
End Function
