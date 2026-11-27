UBE SOURCE 1 MODULE
Attribute UBE_Name = "ManagedLayouts"
' Text, boxed Variant values and object references carry one traced managed identity.
Public Function IsManagedScalar(ByVal TypeCode As Long) As Boolean
    IsManagedScalar = TypeCode = SyntaxTokens.KwString Or TypeCode = SyntaxTokens.KwVariant Or TypeCode = SyntaxTokens.KwObject
End Function

' A nominal identity distinguishes a class reference without making it a value record.
Public Function IsRecordValue(ByVal TypeCode As Long, ByVal TypeSymbol As Long) As Boolean
    IsRecordValue = TypeCode = 0 And TypeSymbol <> 0
End Function

' Rejects inconsistent publication facts before raw or managed store selection.
' Type declaration layout is authoritative; caller expression counts may not erase roots.
Public Function ValidPublication(ByRef Symbols() As DeclarationBinder.BoundSymbol, ByRef Layouts() As AggregateLayout.StorageFact, ByVal TypeCode As Long, ByVal TypeSymbol As Long, ByVal Cells As Long, ByVal References As Long) As Boolean
    Dim Expected As Long
    Dim ExpectedCells As Long = 1
    Dim Node As Long
    Dim Index As Long
    Dim Offset As Long
    Dim Previous As Long = -1
    On Error GoTo Failed
    If Cells < 1 Or Cells > 128 Or References < 0 Or References > Cells Then Exit Function
    If IsManagedScalar(TypeCode) Then
        If TypeSymbol <> 0 Then
            If TypeCode <> SyntaxTokens.KwObject Or TypeSymbol < 1 Then Exit Function
            If Symbols(TypeSymbol - 1).Kind <> SourceParser.ClassNode Then Exit Function
        End If
        Expected = 1
    ElseIf TypeSymbol <> 0 Then
        If Not IsRecordValue(TypeCode, TypeSymbol) Then Exit Function
        If TypeSymbol < 1 Then Exit Function
        If Symbols(TypeSymbol - 1).Kind <> SourceParser.TypeNode Then Exit Function
        Node = Symbols(TypeSymbol - 1).DeclarationNode
        Expected = Layouts(Node - 1).ManagedReferences
        ExpectedCells = Layouts(Node - 1).ElementCells
    ElseIf TypeCode <> SyntaxTokens.KwBoolean And Not ConstantValues.IsNumeric(TypeCode) Then
        Exit Function
    End If
    If Cells <> ExpectedCells Or References <> Expected Then Exit Function
    Do While Index < References
        If Not TryReferenceOffset(Symbols, Layouts, TypeCode, TypeSymbol, Index, Offset) Then Exit Function
        If Offset <= Previous Or Offset >= Cells Then Exit Function
        Previous = Offset
        Index = Index + 1
    Loop
    ValidPublication = True
    Exit Function
Failed:
    ValidPublication = False
End Function
' Reads exact managed-reference offsets from completed finite aggregate layout facts.

' Only executable expression values need spills; declarations retain their ordinary storage roots.
Public Function StatementOf(ByRef Nodes() As SourceParser.SyntaxNode, ByVal Node As Long) As Long
    Dim Parent As Long
    Dim Kind As Long
    Dim Depth As Long
    On Error GoTo Failed
    Do While Node <> 0
        Parent = Nodes(Node - 1).Parent
        If Parent = 0 Then Exit Do
        Kind = Nodes(Parent - 1).Kind
        If Kind = SourceParser.BodyNode Or Kind = SourceParser.ThenNode Or Kind = SourceParser.ElseNode Or Kind = SourceParser.ModuleNode Or Kind = SourceParser.ClassNode Then Exit Do
        If Depth >= 256 Then Exit Function
        Depth = Depth + 1
        Node = Parent
    Loop
    StatementOf = Node
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

Public Function NeedsTextSlot(ByRef Nodes() As SourceParser.SyntaxNode, ByRef Expressions() As ExpressionBinder.BoundExpression, ByVal Node As Long) As Boolean
    Dim Kind As Long
    Dim Parent As Long
    On Error GoTo Failed
    If Expressions(Node - 1).ArrayRank <> 0 Then Exit Function
    If IsRecordValue(Expressions(Node - 1).TypeCode, Expressions(Node - 1).TypeSymbol) And Expressions(Node - 1).ConvertedType <> SyntaxTokens.KwVariant Then Exit Function
    If Not IsManagedScalar(Expressions(Node - 1).TypeCode) And Not IsManagedScalar(Expressions(Node - 1).ConvertedType) Then Exit Function
    Parent = Nodes(Node - 1).Parent
    Do While Parent <> 0
        Kind = Nodes(Parent - 1).Kind
        If Kind <> SourceParser.BinaryNode And Kind <> SourceParser.UnaryNode And Kind <> SourceParser.GroupNode And Kind <> SourceParser.MemberNode Then Exit Do
        If Expressions(Parent - 1).ConstantKnown Then Exit Function
        Parent = Nodes(Parent - 1).Parent
    Loop
    Kind = Nodes(Node - 1).Kind
    NeedsTextSlot = Kind = SourceParser.NameNode Or Kind = SourceParser.MemberNode Or Kind = SourceParser.CallNode Or Kind = SourceParser.ThreadStartNode Or Kind = SourceParser.GroupNode Or Kind = SourceParser.StringNode Or Kind = SourceParser.BinaryNode Or Kind = SourceParser.NumberNode Or Kind = SourceParser.BooleanNode Or Kind = SourceParser.UnaryNode Or Kind = SourceParser.NewObjectNode Or Kind = SourceParser.NothingNode
    Exit Function
Failed:
    NeedsTextSlot = False
End Function

' Record comparisons evaluate the right operand after retaining a rooted independent left snapshot.
Public Function NeedsRecordSnapshot(ByRef Nodes() As SourceParser.SyntaxNode, ByRef Expressions() As ExpressionBinder.BoundExpression, ByRef Layouts() As AggregateLayout.StorageFact, ByVal Node As Long) As Boolean
    Dim Parent As Long
    On Error GoTo Failed
    If Not IsRecordValue(Expressions(Node - 1).TypeCode, Expressions(Node - 1).TypeSymbol) Or Expressions(Node - 1).ArrayRank <> 0 Then Exit Function
    If Layouts(Node - 1).ManagedReferences = 0 Then Exit Function
    Parent = Nodes(Node - 1).Parent
    If Parent = 0 Then Exit Function
    If Nodes(Parent - 1).Kind <> SourceParser.BinaryNode Then Exit Function
    NeedsRecordSnapshot = Nodes(Parent - 1).Value = SyntaxTokens.SymEqual Or Nodes(Parent - 1).Value = SyntaxTokens.SymNotEqual
    Exit Function
Failed:
    NeedsRecordSnapshot = False
End Function

' Counts only private value temporaries; escaped payloads remain owned by their leases.
Public Function TemporaryReferences(ByRef Nodes() As SourceParser.SyntaxNode, ByRef Expressions() As ExpressionBinder.BoundExpression, ByRef Layouts() As AggregateLayout.StorageFact, ByVal Node As Long, ByVal Owned As Boolean) As Long
    On Error GoTo Failed
    If Owned Or Expressions(Node - 1).ArrayRank <> 0 Then Exit Function
    If Expressions(Node - 1).ArgumentMode = 3 Then
        If IsManagedScalar(Expressions(Node - 1).ConvertedType) Then TemporaryReferences = 1
    ElseIf Expressions(Node - 1).ArgumentMode = 1 Or NeedsRecordSnapshot(Nodes, Expressions, Layouts, Node) Then
        If IsRecordValue(Expressions(Node - 1).TypeCode, Expressions(Node - 1).TypeSymbol) And Expressions(Node - 1).ConvertedType <> SyntaxTokens.KwVariant Then TemporaryReferences = Layouts(Node - 1).ManagedReferences
    End If
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Reference indexes enumerate String cells in field order; numeric cells never become roots.
' Facts must belong to one successfully bound and laid-out immutable source request.
Public Function TryReferenceOffset(ByRef Symbols() As DeclarationBinder.BoundSymbol, ByRef Layouts() As AggregateLayout.StorageFact, ByVal TypeCode As Long, ByVal TypeSymbol As Long, ByVal ReferenceIndex As Long, ByRef Offset As Long) As Boolean
    Dim Field As Long
    Dim Node As Long
    Dim Position As Long
    Dim Depth As Long
    Dim Count As Long
    Dim Selected As Boolean
    On Error GoTo Failed
    If ReferenceIndex < 0 Then Exit Function
    Do
        If IsManagedScalar(TypeCode) Then
            If ReferenceIndex <> 0 Then Exit Function
            Offset = Position
            TryReferenceOffset = True
            Exit Function
        End If
        If TypeSymbol < 1 Or Depth >= 64 Then Exit Function
        If Symbols(TypeSymbol - 1).Kind <> SourceParser.TypeNode Then Exit Function
        Node = Symbols(TypeSymbol - 1).DeclarationNode
        If ReferenceIndex >= Layouts(Node - 1).ManagedReferences Then Exit Function
        Field = Symbols(TypeSymbol - 1).FirstField
        Selected = False
        Do While Field <> 0
            Node = Symbols(Field - 1).DeclarationNode
            Count = Layouts(Node - 1).ManagedReferences
            If ReferenceIndex < Count Then
                Position = Position + Layouts(Node - 1).FieldOffset
                TypeCode = Symbols(Field - 1).TypeCode
                TypeSymbol = Symbols(Field - 1).TypeSymbol
                Selected = True
                Exit Do
            End If
            ReferenceIndex = ReferenceIndex - Count
            Field = Symbols(Field - 1).NextField
        Loop
        If Not Selected Then Exit Function
        Depth = Depth + 1
    Loop
    Exit Function
Failed:
    TryReferenceOffset = False
End Function
