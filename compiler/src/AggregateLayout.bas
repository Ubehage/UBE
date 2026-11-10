UBE SOURCE 1 MODULE
Attribute UBE_Name = "AggregateLayout"
' Computes bounded logical cell layouts from freshly checked project syntax without assigning native frame addresses.
Public Type StorageFact
    ElementCells As Long
    StorageCells As Long
    FieldOffset As Long
End Type

' Allocates private layout facts before independent publication.
Private Intrinsic Function ResizeFacts(ByRef Values() As StorageFact, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeFacts.UBE_Primitive = "Array.TryResize"
End Function

' Allocates per-type visitation state for bounded recursive layout.
Private Intrinsic Function ResizeStates(ByRef Values() As Long, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeStates.UBE_Primitive = "Array.TryResize"
End Function

' Reports a located layout rejection using source-local coordinates and retained global identities.
Private Function Reject(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef A() As DeclarationBinder.BoundSymbol, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Symbol As Long, ByVal Code As Long, ByVal Reason As Long) As Boolean
    Dim Node As Long
    Dim ModuleIndex As Long
    On Error GoTo Failed
    If D.Code <> 0 Then Exit Function
    Node = A(Symbol - 1).DeclarationNode
    ModuleIndex = A(Symbol - 1).ModuleIndex
    D.Code = Code
    D.Reason = Reason
    D.ModuleIndex = ModuleIndex
    D.Node = Node
    D.TokenIndex = N(Node - 1).FirstToken
    D.ByteOffset = N(Node - 1).ByteStart - M(ModuleIndex).ByteBase
    D.Utf16Offset = N(Node - 1).Utf16Start
    D.Line = N(Node - 1).Line
    D.Column = N(Node - 1).Column
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Flattens finite records in field declaration order and rejects storage cycles even in unused types.
Private Function LayoutRecord(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef A() As DeclarationBinder.BoundSymbol, ByRef F() As StorageFact, ByRef State() As Long, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal Symbol As Long, ByVal Depth As Long) As Boolean
    Dim Field As Long
    Dim Cells As Long
    Dim Count As Long
    On Error GoTo Failed
    If State(Symbol - 1) = 2 Then LayoutRecord = True: Exit Function
    If State(Symbol - 1) = 1 Then LayoutRecord = Reject(N, M, A, D, Symbol, 8, 40): Exit Function
    If Depth >= 64 Then LayoutRecord = Reject(N, M, A, D, Symbol, 6, 41): Exit Function
    State(Symbol - 1) = 1
    Field = A(Symbol - 1).FirstField
    Do While Field <> 0
        Cells = 1
        If A(Field - 1).TypeSymbol <> 0 Then
            If Not LayoutRecord(N, M, A, F, State, D, A(Field - 1).TypeSymbol, Depth + 1) Then Exit Function
            Cells = F(A(Field - 1).TypeSymbol - 1).StorageCells
        End If
        If Cells > 128 - Count Then LayoutRecord = Reject(N, M, A, D, Field, 6, 42): Exit Function
        F(Field - 1).FieldOffset = Count
        F(Field - 1).ElementCells = Cells
        F(Field - 1).StorageCells = Cells
        Count = Count + Cells
        Field = A(Field - 1).NextField
    Loop
    If Count = 0 Then LayoutRecord = Reject(N, M, A, D, Symbol, 3, 44): Exit Function
    F(Symbol - 1).ElementCells = Count
    F(Symbol - 1).StorageCells = Count
    State(Symbol - 1) = 2
    LayoutRecord = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Computes fixed owner size from checked bounds without overflowing signed arithmetic.
Private Function ArrayCells(ByRef E As ExpressionBinder.BoundExpression, ByVal Stride As Long, ByRef Cells As Long) As Boolean
    Dim Count As LongLong
    Dim Difference As LongLong
    Dim Total As LongLong = 4
    Dim TypeCode As Long
    Dim Reason As Long
    Dim Index As Long
    On Error GoTo Failed
    If Stride < 1 Or Stride > 128 Then Exit Function
    If Not ConstantValues.TryBinary(SyntaxTokens.SymMinus, E.UpperBound, SyntaxTokens.KwLongLong, E.LowerBound, SyntaxTokens.KwLongLong, Difference, TypeCode, Reason) Then Exit Function
    If Not ConstantValues.TryBinary(SyntaxTokens.SymPlus, Difference, SyntaxTokens.KwLongLong, 1, SyntaxTokens.KwLongLong, Count, TypeCode, Reason) Then Exit Function
    If Count < 1 Or Count > 1048576 Then Exit Function
    ' At most 128 additions of at most 1048576 cells fit Long; retain LongLong intermediates explicitly.
    Do While Index < Stride
        Total = Total + Count
        Index = Index + 1
    Loop
    If Total > 2147483647 Then Exit Function
    Cells = Total
    ArrayCells = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Rejects malformed retained array shape tags before expression binding can interpret their bounds.
Private Function ValidArrayShapes(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef A() As DeclarationBinder.BoundSymbol, ByVal Count As Long, ByRef D As DeclarationBinder.BindingDiagnostic) As Boolean
    Dim Index As Long
    Dim Shape As Long
    Dim LowerNode As Long
    Dim UpperNode As Long
    On Error GoTo Failed
    Do While Index < Count
        If A(Index).ArrayRank <> 0 Then
            Shape = N(A(Index).DeclarationNode - 1).FirstChild
            If Shape = 0 Then ValidArrayShapes = Reject(N, M, A, D, Index + 1, 9, 46): Exit Function
            If N(Shape - 1).Kind <> SourceParser.ArrayShapeNode Then ValidArrayShapes = Reject(N, M, A, D, Index + 1, 9, 46): Exit Function
            If N(Shape - 1).Value <> 1 And N(Shape - 1).Value <> 2 Then ValidArrayShapes = Reject(N, M, A, D, Index + 1, 9, 46): Exit Function
            LowerNode = N(Shape - 1).FirstChild
            If N(Shape - 1).Value = 2 Then
                If LowerNode <> 0 Or N(Shape - 1).LastChild <> 0 Then ValidArrayShapes = Reject(N, M, A, D, Index + 1, 9, 46): Exit Function
            Else
                If LowerNode = 0 Then ValidArrayShapes = Reject(N, M, A, D, Index + 1, 9, 46): Exit Function
                UpperNode = N(LowerNode - 1).NextSibling
                If UpperNode = 0 Then ValidArrayShapes = Reject(N, M, A, D, Index + 1, 9, 46): Exit Function
                If N(UpperNode - 1).NextSibling <> 0 Or N(Shape - 1).LastChild <> UpperNode Then ValidArrayShapes = Reject(N, M, A, D, Index + 1, 9, 46): Exit Function
            End If
            If A(Index).Kind = SourceParser.ParameterNode And N(Shape - 1).Value <> 2 Then ValidArrayShapes = Reject(N, M, A, D, Index + 1, 9, 46): Exit Function
        End If
        Index = Index + 1
    Loop
    ValidArrayShapes = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Assigns declaration sizes while distinguishing owned descriptors from borrowed array parameters.
Private Function LayoutValues(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef A() As DeclarationBinder.BoundSymbol, ByVal Count As Long, ByRef E() As ExpressionBinder.BoundExpression, ByRef F() As StorageFact, ByRef D As DeclarationBinder.BindingDiagnostic) As Boolean
    Dim Index As Long
    Dim Kind As Long
    Dim Node As Long
    Dim Cells As Long
    Dim Scope As Long
    Dim ModuleCells As Long
    On Error GoTo Failed
    Do While Index < Count
        Kind = A(Index).Kind
        Node = A(Index).DeclarationNode
        If Kind <> SourceParser.TypeNode And Kind <> SourceParser.FieldNode Then
            Cells = 0
            If A(Index).TypeCode = SyntaxTokens.KwBoolean Or ConstantValues.IntegerWidth(A(Index).TypeCode) <> 0 Then Cells = 1
            If A(Index).TypeSymbol <> 0 Then Cells = F(A(Index).TypeSymbol - 1).StorageCells
            F(Index).ElementCells = Cells
            F(Index).StorageCells = Cells
            If A(Index).ArrayRank <> 0 Then
                If Kind = SourceParser.ParameterNode Then
                    F(Index).StorageCells = 0
                ElseIf E(Node - 1).HasBounds Then
                    If Not ArrayCells(E(Node - 1), Cells, F(Index).StorageCells) Then LayoutValues = Reject(N, M, A, D, Index + 1, 6, 45): Exit Function
                Else
                    F(Index).StorageCells = 4
                End If
            End If
        End If
        If Kind = SourceParser.VariableNode Then
            Scope = A(Index).ScopeSymbol
            If A(Scope - 1).Kind = SourceParser.ModuleNode Then
                Cells = F(Index).StorageCells
                If Cells < 1 Or Cells > 65536 - ModuleCells Then LayoutValues = Reject(N, M, A, D, Index + 1, 6, 43): Exit Function
                ModuleCells = ModuleCells + Cells
            End If
        End If
        Index = Index + 1
    Loop
    LayoutValues = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Projects logical expression sizes and relative field offsets without allocating frame slots or payloads.
Private Sub ProjectFacts(ByRef N() As SourceParser.SyntaxNode, ByRef C As ProjectSyntax.ProjectCounts, ByRef A() As DeclarationBinder.BoundSymbol, ByVal Count As Long, ByRef E() As ExpressionBinder.BoundExpression, ByRef SymbolFacts() As StorageFact, ByRef Candidate() As StorageFact)
    Dim Index As Long
    Dim Symbol As Long
    Dim Cells As Long
    Dim Node As Long
    On Error GoTo Failed
    Do While Index < C.NodeCount
        Symbol = E(Index).SymbolIndex
        If Symbol <> 0 Then
            Candidate(Index) = SymbolFacts(Symbol - 1)
        Else
            Cells = 0
            If E(Index).TypeCode = SyntaxTokens.KwBoolean Or ConstantValues.IntegerWidth(E(Index).TypeCode) <> 0 Then Cells = 1
            If E(Index).TypeSymbol <> 0 Then Cells = SymbolFacts(E(Index).TypeSymbol - 1).StorageCells
            Candidate(Index).ElementCells = Cells
            Candidate(Index).StorageCells = Cells
            If E(Index).ArrayRank <> 0 Then Candidate(Index).StorageCells = 0
        End If
        Index = Index + 1
    Loop
    Index = 0
    Do While Index < Count
        Node = A(Index).DeclarationNode
        Candidate(Node - 1) = SymbolFacts(Index)
        Index = Index + 1
    Loop
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

' Revalidates source semantics and publishes an independent complete layout only after all bounds pass.
Public Function TryLayout(ByRef Bytes() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByRef Nodes() As SourceParser.SyntaxNode, ByRef Modules() As ProjectSyntax.ParsedModule, ByRef Counts As ProjectSyntax.ProjectCounts, ByRef PackageName() As Byte, ByVal IsExecutable As Boolean, ByRef Layout() As StorageFact, ByRef LayoutCount As Long, ByRef Diagnostic As DeclarationBinder.BindingDiagnostic) As Boolean
    Dim Symbols() As DeclarationBinder.BoundSymbol
    Dim Expressions() As ExpressionBinder.BoundExpression
    Dim SymbolFacts() As StorageFact
    Dim Candidate() As StorageFact
    Dim States() As Long
    Dim SymbolCount As Long
    Dim ExpressionCount As Long
    Dim EntrySymbol As Long
    Dim Index As Long
    On Error GoTo StorageFailure
    LayoutCount = 0
    If Not DeclarationBinder.TryBindDeclarations(Bytes, Tokens, Nodes, Modules, Counts, PackageName, IsExecutable, Symbols, SymbolCount, EntrySymbol, Diagnostic) Then Exit Function
    If Not ValidArrayShapes(Nodes, Modules, Symbols, SymbolCount, Diagnostic) Then Exit Function
    If Not ExpressionBinder.TryBindExpressions(Bytes, Tokens, Nodes, Modules, Counts, PackageName, IsExecutable, Expressions, ExpressionCount, Diagnostic) Then Exit Function
    If Not ResizeFacts(SymbolFacts, SymbolCount, False) Then GoTo StorageFailure
    If Not ResizeStates(States, SymbolCount, False) Then GoTo StorageFailure
    If Not ResizeFacts(Candidate, Counts.NodeCount, False) Then GoTo StorageFailure
    Do While Index < SymbolCount
        If Symbols(Index).Kind = SourceParser.TypeNode Then
            If Not LayoutRecord(Nodes, Modules, Symbols, SymbolFacts, States, Diagnostic, Index + 1, 0) Then Exit Function
        End If
        Index = Index + 1
    Loop
    If Not LayoutValues(Nodes, Modules, Symbols, SymbolCount, Expressions, SymbolFacts, Diagnostic) Then Exit Function
    ProjectFacts Nodes, Counts, Symbols, SymbolCount, Expressions, SymbolFacts, Candidate
    Layout = Candidate
    LayoutCount = Counts.NodeCount
    TryLayout = True
    Exit Function
StorageFailure:
    LayoutCount = 0
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
