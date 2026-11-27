UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeManagedLayout"
' Emits immutable precise metadata for value layouts and permanent program storage.

' Emits one finite nominal value's ordered offsets and its descriptor wrapper.
Private Function EmitValue(ByRef A() As DeclarationBinder.BoundSymbol, ByRef L() As AggregateLayout.StorageFact, ByRef S As LLVMWriter.WriterState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal TypeSymbol As Long, ByVal Cells As Long, ByVal References As Long) As Boolean
    Dim Index As Long
    Dim Offset As Long
    Dim TypeCode As Long
    Dim Template As Long
    On Error GoTo Failed
    If TypeSymbol = 0 Then TypeCode = SyntaxTokens.KwString
    If TypeSymbol <> 0 Then
        If A(TypeSymbol - 1).Kind = SourceParser.ClassNode Then TypeCode = SyntaxTokens.KwObject
    End If
    If Not LLVMFormat.TryFormat(S, B, Token, Catalog, LLVMTemplates.ManagedOffsetsStart, TypeSymbol, References, 0, 0) Then Exit Function
    Do While Index < References
        If Not ManagedLayouts.TryReferenceOffset(A, L, TypeCode, TypeSymbol, Index, Offset) Then GoTo Failed
        Template = LLVMTemplates.TextLiteralByte
        If Index + 1 = References Then Template = LLVMTemplates.TextLiteralLastByte
        If Not LLVMFormat.TryFormat(S, B, Token, Catalog, Template, Offset, 0, 0, 0) Then Exit Function
        Index = Index + 1
    Loop
    If Not LLVMFormat.TryFormat(S, B, Token, Catalog, LLVMTemplates.ManagedOffsetsEnd, 0, 0, 0, 0) Then Exit Function
    If Not LLVMWriter.TryEndLine(S, B, Token) Then Exit Function
    If Not LLVMFormat.TryFormat(S, B, Token, Catalog, LLVMTemplates.ManagedValueLayout, TypeSymbol, Cells, References, 0) Then Exit Function
    EmitValue = LLVMWriter.TryEndLine(S, B, Token)
    Exit Function
Failed:
    S.Failed = True
    S.Failure = 3
End Function

' Emits only non-array reference offsets; an array root follows its current descriptor separately.
Private Function EmitGlobalReferences(ByRef A() As DeclarationBinder.BoundSymbol, ByRef L() As AggregateLayout.StorageFact, ByRef P() As NativePlanning.NativeSymbolPlan, ByVal SymbolCount As Long, ByVal References As Long, ByRef S As LLVMWriter.WriterState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte) As Boolean
    Dim Index As Long
    Dim Reference As Long
    Dim Written As Long
    Dim Node As Long
    Dim Offset As Long
    Dim Template As Long
    On Error GoTo Failed
    If Not LLVMFormat.TryFormat(S, B, Token, Catalog, LLVMTemplates.ManagedGlobalOffsetsStart, References, 0, 0, 0) Then Exit Function
    Do While Index < SymbolCount
        If P(Index).ContextOffset >= 0 And A(Index).ArrayRank = 0 Then
            Node = A(Index).DeclarationNode
            Reference = 0
            Do While Reference < L(Node - 1).ManagedReferences
                If Not ManagedLayouts.TryReferenceOffset(A, L, A(Index).TypeCode, A(Index).TypeSymbol, Reference, Offset) Then GoTo Failed
                Written = Written + 1
                Template = LLVMTemplates.TextLiteralByte
                If Written = References Then Template = LLVMTemplates.TextLiteralLastByte
                If Not LLVMFormat.TryFormat(S, B, Token, Catalog, Template, P(Index).ContextOffset + Offset, 0, 0, 0) Then Exit Function
                Reference = Reference + 1
            Loop
        End If
        Index = Index + 1
    Loop
    If Written <> References Then GoTo Failed
    If Not LLVMFormat.TryFormat(S, B, Token, Catalog, LLVMTemplates.ManagedOffsetsEnd, 0, 0, 0, 0) Then Exit Function
    EmitGlobalReferences = LLVMWriter.TryEndLine(S, B, Token)
    Exit Function
Failed:
    S.Failed = True
    S.Failure = 3
End Function

' Emits descriptor positions and exact element layouts without enumerating numeric payload cells.
Private Function EmitGlobalArrays(ByRef A() As DeclarationBinder.BoundSymbol, ByRef L() As AggregateLayout.StorageFact, ByRef P() As NativePlanning.NativeSymbolPlan, ByVal SymbolCount As Long, ByVal Arrays As Long, ByRef S As LLVMWriter.WriterState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte) As Boolean
    Dim Index As Long
    Dim Written As Long
    Dim Node As Long
    Dim Template As Long
    On Error GoTo Failed
    If Not LLVMFormat.TryFormat(S, B, Token, Catalog, LLVMTemplates.ManagedGlobalArraysStart, Arrays, 0, 0, 0) Then Exit Function
    Do While Index < SymbolCount
        If P(Index).ContextOffset >= 0 And A(Index).ArrayRank <> 0 Then
            Node = A(Index).DeclarationNode
            If L(Node - 1).ManagedReferences > 0 Then
                Written = Written + 1
                Template = LLVMTemplates.ManagedGlobalArrayEntry
                If Written = Arrays Then Template = LLVMTemplates.ManagedGlobalArrayLastEntry
                If Not LLVMFormat.TryFormat(S, B, Token, Catalog, Template, P(Index).ContextOffset, A(Index).TypeSymbol, 0, 0) Then Exit Function
            End If
        End If
        Index = Index + 1
    Loop
    If Written <> Arrays Then GoTo Failed
    If Not LLVMFormat.TryFormat(S, B, Token, Catalog, LLVMTemplates.ManagedOffsetsEnd, 0, 0, 0, 0) Then Exit Function
    EmitGlobalArrays = LLVMWriter.TryEndLine(S, B, Token)
    Exit Function
Failed:
    S.Failed = True
    S.Failure = 3
End Function

' One immutable catalog is shared by all worker ranges and program invocations.
Public Function TryEmit(ByRef Symbols() As DeclarationBinder.BoundSymbol, ByRef Layouts() As AggregateLayout.StorageFact, ByRef Plans() As NativePlanning.NativeSymbolPlan, ByRef Summary As NativePlanning.NativePlanSummary, ByRef State As LLVMWriter.WriterState, ByRef Buffer() As Byte, ByVal Token As Long, ByRef Catalog() As Byte) As Boolean
    Dim Index As Long
    Dim Node As Long
    Dim References As Long
    Dim Arrays As Long
    Dim Cells As Long
    On Error GoTo Failed
    If State.Failed Then Exit Function
    If Summary.ManagedRoles.CollectSymbol = 0 Then TryEmit = True: Exit Function
    If Not NativeObjects.TryDeclarations(Symbols, Summary.SymbolCount, State, Buffer, Token, Catalog) Then Exit Function
    If Not LLVMFormat.TryFormat(State, Buffer, Token, Catalog, LLVMTemplates.ManagedRetireDefinition, 0, 0, 0, 0) Then Exit Function
    If Not LLVMWriter.TryEndLine(State, Buffer, Token) Then Exit Function
    If Not EmitValue(Symbols, Layouts, State, Buffer, Token, Catalog, 0, 1, 1) Then Exit Function
    If Not LLVMFormat.TryFormat(State, Buffer, Token, Catalog, LLVMTemplates.ManagedOwnerLayout, 0, 0, 0, 0) Then Exit Function
    If Not LLVMWriter.TryEndLine(State, Buffer, Token) Then Exit Function
    Do While Index < Summary.SymbolCount
        Node = Symbols(Index).DeclarationNode
        If Symbols(Index).Kind = SourceParser.TypeNode And Layouts(Node - 1).ManagedReferences > 0 Then
            If Not EmitValue(Symbols, Layouts, State, Buffer, Token, Catalog, Index + 1, Layouts(Node - 1).StorageCells, Layouts(Node - 1).ManagedReferences) Then Exit Function
        ElseIf Symbols(Index).Kind = SourceParser.ClassNode Then
            ' This is the layout of a reference to the class, never its instance fields.
            If Not EmitValue(Symbols, Layouts, State, Buffer, Token, Catalog, Index + 1, 1, 1) Then Exit Function
        End If
        If Plans(Index).ContextOffset >= 0 Then
            If Symbols(Index).ArrayRank = 0 Then
                References = References + Layouts(Node - 1).ManagedReferences
            ElseIf Layouts(Node - 1).ManagedReferences > 0 Then
                Arrays = Arrays + 1
            End If
        End If
        Index = Index + 1
    Loop
    If Not EmitGlobalReferences(Symbols, Layouts, Plans, Summary.SymbolCount, References, State, Buffer, Token, Catalog) Then Exit Function
    If Not EmitGlobalArrays(Symbols, Layouts, Plans, Summary.SymbolCount, Arrays, State, Buffer, Token, Catalog) Then Exit Function
    Cells = Summary.ContextCells
    If Cells = 0 Then Cells = 1
    If Not LLVMFormat.TryFormat(State, Buffer, Token, Catalog, LLVMTemplates.ManagedGlobalLayout, Cells, References, Arrays, 0) Then Exit Function
    TryEmit = LLVMWriter.TryEndLine(State, Buffer, Token)
    Exit Function
Failed:
    State.Failed = True
    State.Failure = 3
End Function
