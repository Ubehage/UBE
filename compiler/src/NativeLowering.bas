UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeLowering"
' Owns freshly validated facts and streams complete native IR only into a caller-owned private stage.
Private Const RuntimeLength As Long = 95098
Private Const RuntimeByteSum As Long = 7669073
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
Private Sub ReportFailure(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef S As NativeEmission.EmissionState, ByRef D As DeclarationBinder.BindingDiagnostic)
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

' No supplied declaration/layout/role facts gain authority: all are privately re-derived here.
' Token must name a fresh private output. The driver closes/discards failures and publishes only after native validation.
Public Function TryEmit(ByRef Bytes() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByRef Nodes() As SourceParser.SyntaxNode, ByRef Modules() As ProjectSyntax.ParsedModule, ByRef Counts As ProjectSyntax.ProjectCounts, ByRef PackageName() As Byte, ByVal IsExecutable As Boolean, ByRef Catalog() As Byte, ByRef RuntimeText() As Byte, ByVal Token As Long, ByRef State As NativeEmission.EmissionState, ByRef Diagnostic As DeclarationBinder.BindingDiagnostic) As Boolean
    Dim Symbols() As DeclarationBinder.BoundSymbol
    Dim Expressions() As ExpressionBinder.BoundExpression
    Dim Layouts() As AggregateLayout.StorageFact
    Dim Plans() As NativePlanning.NativeSymbolPlan
    Dim Pins() As Long
    Dim Roles() As Long
    Dim Dependencies() As Byte
    Dim Seen() As Long
    Dim Nexts() As Long
    Dim Buffer() As Byte
    Dim Summary As NativePlanning.NativePlanSummary
    Dim SymbolCount As Long
    Dim EntrySymbol As Long
    Dim FactCount As Long
    Dim Symbol As Long
    Dim Body As Long
    Dim Node As Long
    Dim NextNode As Long
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
    If DeclarationBinder.TryBindDeclarations(Bytes, Tokens, Nodes, Modules, Counts, PackageName, IsExecutable, Symbols, SymbolCount, EntrySymbol, Diagnostic) = False Then GoTo Rejected
    If ExpressionBinder.TryBindExpressions(Bytes, Tokens, Nodes, Modules, Counts, PackageName, IsExecutable, Expressions, FactCount, Diagnostic) = False Then GoTo Rejected
    If PrimitiveRoles.TryBindPrimitives(Bytes, Tokens, Nodes, Modules, Counts, PackageName, IsExecutable, Roles, FactCount, Diagnostic) = False Then GoTo Rejected
    If AggregateLayout.TryLayout(Bytes, Tokens, Nodes, Modules, Counts, PackageName, IsExecutable, Layouts, FactCount, Diagnostic) = False Then GoTo Rejected
    If NativePlanning.TryPlanNative(Bytes, Tokens, Nodes, Modules, Counts, Symbols, SymbolCount, Expressions, Layouts, Roles, EntrySymbol, IsExecutable, Plans, Pins, Dependencies, Summary, Diagnostic) = False Then GoTo Rejected
    If ResizeNumbers(Seen, Counts.NodeCount, False) = False Then GoTo Failed
    If ResizeNumbers(Nexts, Counts.NodeCount, False) = False Then GoTo Failed
    If LLVMFormat.TryLine(State.Text, Buffer, Token, Catalog, LLVMTemplates.TargetHeader, 0, 0, 0, 0) = False Then GoTo Rejected
    If NativeContext.TryEmitContext(Symbols, Plans, Summary, State.Text, Buffer, Token, Catalog) = False Then GoTo Rejected
    If LLVMWriter.TryAppendSpan(State.Text, Buffer, Token, RuntimeText, 0, RuntimeLength) = False Then GoTo Rejected
    If NativeIntrinsics.TryEmit(Symbols, SymbolCount, Layouts, Roles, State.Text, Buffer, Token, Catalog) = False Then GoTo Rejected
    Symbol = 1
    Do While Symbol <= SymbolCount
        If NativeEmission.Charge(State) = False Then GoTo Rejected
        If Symbols(Symbol - 1).Kind = SourceParser.ModuleNode Then
            If NativeFrames.TryModuleStart(Nodes, Symbols, Expressions, Layouts, Plans, State, Buffer, Token, Catalog, Symbol, Counts.NodeCount, Node) = False Then GoTo Rejected
            Do While Node <> 0
                NextNode = Nodes(Node - 1).NextSibling
                Do While NextNode <> 0
                    If NativeEmission.Charge(State) = False Then GoTo Rejected
                    If Nodes(NextNode - 1).Kind = SourceParser.VariableNode Then Exit Do
                    NextNode = Nodes(NextNode - 1).NextSibling
                Loop
                If NativeControl.TryEmitStatement(Nodes, Symbols, Expressions, Layouts, Plans, Pins, State, Buffer, Token, Catalog, Seen, Nexts, Node, NextNode) = False Then GoTo Rejected
                Node = NextNode
            Loop
            If NativeFrames.TryFailureDispatch(Nodes, Symbols, Plans, State, Buffer, Token, Catalog, Seen, Nexts) = False Then GoTo Rejected
            If NativeFrames.TryReturns(Symbols, Plans, State, Buffer, Token, Catalog, SymbolCount) = False Then GoTo Rejected
            If NativeFrames.TryModuleEnsure(State, Buffer, Token, Catalog, Symbols(Symbol - 1).ModuleIndex) = False Then GoTo Rejected
        ElseIf Symbols(Symbol - 1).Kind = SourceParser.SubNode Or Symbols(Symbol - 1).Kind = SourceParser.FunctionNode Then
            Node = Symbols(Symbol - 1).DeclarationNode
            If Roles(Node - 1) = 0 Then
                If NativeFrames.TryProcedureStart(Nodes, Symbols, Expressions, Layouts, Plans, State, Buffer, Token, Catalog, Symbol, Counts.NodeCount, Body) = False Then GoTo Rejected
                If NativeControl.TryEmitSequence(Nodes, Symbols, Expressions, Layouts, Plans, Pins, State, Buffer, Token, Catalog, Seen, Nexts, Body, 0) = False Then GoTo Rejected
                If NativeFrames.TryFailureDispatch(Nodes, Symbols, Plans, State, Buffer, Token, Catalog, Seen, Nexts) = False Then GoTo Rejected
                If NativeFrames.TryReturns(Symbols, Plans, State, Buffer, Token, Catalog, SymbolCount) = False Then GoTo Rejected
            End If
        End If
        Symbol = Symbol + 1
    Loop
    If IsExecutable Then
        If NativeContext.TryEmitEntry(EntrySymbol, State.Text, Buffer, Token, Catalog) = False Then GoTo Rejected
    End If
    If LLVMWriter.TryFinish(State.Text, Buffer, Token) = False Then GoTo Rejected
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
