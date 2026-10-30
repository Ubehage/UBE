UBE SOURCE 1 MODULE
Attribute UBE_Name = "CompilerSemantics"

Sub AppendSemanticWireLong(ByRef Data As String, ByVal Value As Long)
    Data = Data & LongToString(Value) & ","
End Sub

Sub AppendSemanticWireString(ByRef Data As String, ByVal Value As String)
    Data = Data & LongToString(StringLength(Value)) & ":" & Value
End Sub

Function ReadSemanticWireLong(ByVal Data As String, ByRef Cursor As Long) As Long
    If Cursor < 0 Or Cursor >= StringLength(Data) Then
        ReadSemanticWireLong = 0
        Exit Function
    End If
    Dim Sign As Long = 1
    If StringByteAt(Data, Cursor) = 45 Then
        Sign = -1
        Cursor = Cursor + 1
    End If
    Dim Value As Long = 0
    While Cursor < StringLength(Data) And StringByteAt(Data, Cursor) <> 44
        Value = Value * 10 + StringByteAt(Data, Cursor) - 48
        Cursor = Cursor + 1
    Wend
    Cursor = Cursor + 1
    ReadSemanticWireLong = Value * Sign
End Function

Function ReadSemanticWireString(ByVal Data As String, ByRef Cursor As Long) As String
    If Cursor < 0 Or Cursor >= StringLength(Data) Then
        ReadSemanticWireString = ""
        Exit Function
    End If
    Dim Length As Long = 0
    While Cursor < StringLength(Data) And StringByteAt(Data, Cursor) <> 58
        Length = Length * 10 + StringByteAt(Data, Cursor) - 48
        Cursor = Cursor + 1
    Wend
    Cursor = Cursor + 1
    ReadSemanticWireString = StringSlice(Data, Cursor, Length)
    Cursor = Cursor + Length
End Function

Function FreezeParallelSemanticData(ByRef Sources() As SourceDocument, ByVal SourceCount As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Scopes() As SemanticScope, ByVal ScopeCount As Long, ByRef Links() As SemanticSymbolLink, ByVal LinkCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long) As String
    Dim Data As String = ""
    Call AppendSemanticWireLong(Data, SourceCount)
    Dim Index As Long = 0
    While Index < SourceCount
        Call AppendSemanticWireString(Data, Sources(Index).FilePath)
        Call AppendSemanticWireLong(Data, Sources(Index).ReferenceDepth)
        Index = Index + 1
    Wend
    Call AppendSemanticWireLong(Data, TypeCount)
    Index = 0
    While Index < TypeCount
        Call AppendSemanticWireLong(Data, Types(Index).StableId)
        Call AppendSemanticWireLong(Data, Types(Index).TypeKind)
        Call AppendSemanticWireString(Data, Types(Index).TypeName)
        Call AppendSemanticWireLong(Data, Types(Index).TypeSymbol)
        Call AppendSemanticWireLong(Data, Types(Index).ElementType)
        Call AppendSemanticWireLong(Data, Types(Index).ArrayRank)
        Call AppendSemanticWireLong(Data, Types(Index).FixedLength)
        Index = Index + 1
    Wend
    Call AppendSemanticWireLong(Data, ScopeCount)
    Index = 0
    While Index < ScopeCount
        Call AppendSemanticWireLong(Data, Scopes(Index).StableId)
        Call AppendSemanticWireLong(Data, Scopes(Index).ScopeKind)
        Call AppendSemanticWireLong(Data, Scopes(Index).ParentScope)
        Call AppendSemanticWireLong(Data, Scopes(Index).OwnerSymbol)
        Call AppendSemanticWireLong(Data, Scopes(Index).SourceId)
        Call AppendSemanticWireLong(Data, Scopes(Index).SyntaxNode)
        Call AppendSemanticWireLong(Data, Scopes(Index).FirstSymbolLink)
        Call AppendSemanticWireLong(Data, Scopes(Index).LastSymbolLink)
        Call AppendSemanticWireLong(Data, Scopes(Index).SymbolCount)
        Index = Index + 1
    Wend
    Call AppendSemanticWireLong(Data, LinkCount)
    Index = 0
    While Index < LinkCount
        Call AppendSemanticWireLong(Data, Links(Index).SymbolIndex)
        Call AppendSemanticWireLong(Data, Links(Index).NextLink)
        Index = Index + 1
    Wend
    Call AppendSemanticWireLong(Data, SymbolCount)
    Index = 0
    While Index < SymbolCount
        Call AppendSemanticWireLong(Data, Symbols(Index).StableId)
        Call AppendSemanticWireLong(Data, Symbols(Index).SymbolKind)
        Call AppendSemanticWireString(Data, Symbols(Index).SymbolName)
        Call AppendSemanticWireLong(Data, Symbols(Index).ScopeIndex)
        Call AppendSemanticWireLong(Data, Symbols(Index).ParentSymbol)
        Call AppendSemanticWireLong(Data, Symbols(Index).SourceId)
        Call AppendSemanticWireLong(Data, Symbols(Index).SyntaxNode)
        Call AppendSemanticWireLong(Data, Symbols(Index).FirstToken)
        Call AppendSemanticWireLong(Data, Symbols(Index).LastToken)
        Call AppendSemanticWireLong(Data, Symbols(Index).VisibilityKind)
        Call AppendSemanticWireLong(Data, Symbols(Index).DeclaredType)
        Call AppendSemanticWireLong(Data, Symbols(Index).ParameterOrdinal)
        Call AppendSemanticWireLong(Data, Symbols(Index).Flags)
        Call AppendSemanticWireLong(Data, Symbols(Index).RelatedSymbol)
        Call AppendSemanticWireLong(Data, Symbols(Index).SecondaryScope)
        Call AppendSemanticWireLong(Data, Symbols(Index).ConstantKind)
        Call AppendSemanticWireString(Data, Symbols(Index).ConstantText)
        Index = Index + 1
    Wend
    FreezeParallelSemanticData = Data
End Function

Function AppendParallelExpressionWork(ByVal Result As ParallelFrontendResult, ByVal NodeIndex As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken, ByRef Bindings() As SemanticNodeBinding) As Long
    Dim Data As String = ""
    Call AppendSemanticWireLong(Data, 1)
    Call AppendSemanticWireLong(Data, NodeIndex)
    Call AppendSemanticWireLong(Data, SyntaxNodes(NodeIndex).SourceId)
    Call AppendSemanticWireLong(Data, Bindings(NodeIndex).ScopeIndex)
    Call AppendSemanticWireLong(Data, Bindings(NodeIndex).OwnerSymbol)
    Dim LocalTokenCount As Long = SyntaxNodes(NodeIndex).LastToken - SyntaxNodes(NodeIndex).FirstToken + 1
    Call AppendSemanticWireLong(Data, LocalTokenCount)
    Dim TokenIndex As Long = SyntaxNodes(NodeIndex).FirstToken
    While TokenIndex <= SyntaxNodes(NodeIndex).LastToken
        Call AppendSemanticWireLong(Data, Tokens(TokenIndex).TokenKind)
        Call AppendSemanticWireLong(Data, Tokens(TokenIndex).SourceId)
        Call AppendSemanticWireLong(Data, Tokens(TokenIndex).StartByte)
        Call AppendSemanticWireLong(Data, Tokens(TokenIndex).ByteLength)
        Call AppendSemanticWireLong(Data, Tokens(TokenIndex).LineNumber)
        Call AppendSemanticWireLong(Data, Tokens(TokenIndex).ColumnNumber)
        Call AppendSemanticWireString(Data, Tokens(TokenIndex).Spelling)
        Call AppendSemanticWireString(Data, Tokens(TokenIndex).Decoded)
        TokenIndex = TokenIndex + 1
    Wend
    AppendParallelExpressionWork = Result.AppendSemanticWorkItem(Data)
End Function

Sub AppendParallelBindingWork(ByVal Result As ParallelFrontendResult, ByRef Binding As SemanticNodeBinding)
    Dim Data As String = Result.SourceFilePath
    Call AppendSemanticWireLong(Data, 2)
    Call AppendSemanticWireLong(Data, Binding.SyntaxNode)
    Call AppendSemanticWireLong(Data, Binding.ScopeIndex)
    Call AppendSemanticWireLong(Data, Binding.OwnerSymbol)
    Call AppendSemanticWireLong(Data, Binding.IrRegionOwnerEncoded)
    Call AppendSemanticWireLong(Data, Binding.IrRegionKind)
    Result.SourceFilePath = Data
End Sub

Sub ParallelSemanticWorker(ByVal Result As ParallelFrontendResult)
    Call ParallelSemanticWorkerBody(Result)
End Sub

Sub ParallelSemanticWorkerBody(ByVal Result As ParallelFrontendResult)
    Dim FrozenData As String = Result.SourceContents
    If StringLength(FrozenData) = 0 Or Result.SemanticWorkItemCount <= 0 Then
        Dim MissingExpressions() As SemanticExpression
        Dim MissingBindings() As SemanticNodeBinding
        Dim MissingDiagnostics() As CompilerDiagnostic
        Dim MissingDiagnosticCount As Long = 0
        Dim MissingDiagnosticCapacity As Long = 0
        Call AddDiagnostic(MissingDiagnostics, MissingDiagnosticCount, MissingDiagnosticCapacity, "UBE5323", "<compiler-semantics>", 1, 1, "parallel semantic worker received an incomplete frozen snapshot")
        SyncLock ParallelGrammarLoadLock
            Call Result.StoreSemanticWorkerResult(MissingExpressions, 0, MissingBindings, 0, MissingDiagnostics, MissingDiagnosticCount, 0, 0)
        End SyncLock
        Exit Sub
    End If
    Dim FrozenCursor As Long = 0
    Dim HeaderSourceCount As Long = ReadSemanticWireLong(FrozenData, FrozenCursor)
    If HeaderSourceCount <> Result.SourceId Then
        Dim HeaderExpressions() As SemanticExpression
        Dim HeaderBindings() As SemanticNodeBinding
        Dim HeaderDiagnostics() As CompilerDiagnostic
        Dim HeaderDiagnosticCount As Long = 0
        Dim HeaderDiagnosticCapacity As Long = 0
        Call AddDiagnostic(HeaderDiagnostics, HeaderDiagnosticCount, HeaderDiagnosticCapacity, "UBE5323", "<compiler-semantics>", 1, 1, "parallel semantic snapshot source count changed from " & LongToString(Result.SourceId) & " to " & LongToString(HeaderSourceCount))
        SyncLock ParallelGrammarLoadLock
            Call Result.StoreSemanticWorkerResult(HeaderExpressions, 0, HeaderBindings, 0, HeaderDiagnostics, HeaderDiagnosticCount, 0, 0)
        End SyncLock
        Exit Sub
    End If
    Dim Sources() As SourceDocument
    Dim SourceCount As Long = 0
    Dim Types() As SemanticType
    Dim TypeCount As Long = 0
    Dim Scopes() As SemanticScope
    Dim ScopeCount As Long = 0
    Dim Links() As SemanticSymbolLink
    Dim LinkCount As Long = 0
    Dim Symbols() As SemanticSymbol
    Dim SymbolCount As Long = 0
    SourceCount = HeaderSourceCount
    ReDim Sources(SourceCount - 1)
    Dim FrozenIndex As Long = 0
    Dim WireLongValue As Long = 0
    Dim WireStringValue As String = ""
    While FrozenIndex < SourceCount
        Sources(FrozenIndex).SourceId = FrozenIndex + 1
        WireStringValue = ReadSemanticWireString(FrozenData, FrozenCursor)
        Sources(FrozenIndex).FilePath = WireStringValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Sources(FrozenIndex).ReferenceDepth = WireLongValue
        FrozenIndex = FrozenIndex + 1
    Wend
    TypeCount = ReadSemanticWireLong(FrozenData, FrozenCursor)
    If TypeCount <= 0 Or TypeCount > LimitSemanticTypes() Then
        Dim TypeFailureExpressions() As SemanticExpression
        Dim TypeFailureBindings() As SemanticNodeBinding
        Dim TypeFailureDiagnostics() As CompilerDiagnostic
        Dim TypeFailureCount As Long = 0
        Dim TypeFailureCapacity As Long = 0
        Call AddDiagnostic(TypeFailureDiagnostics, TypeFailureCount, TypeFailureCapacity, "UBE5323", "<compiler-semantics>", 1, 1, "parallel semantic worker rejected malformed frozen types")
        SyncLock ParallelGrammarLoadLock
            Call Result.StoreSemanticWorkerResult(TypeFailureExpressions, 0, TypeFailureBindings, 0, TypeFailureDiagnostics, TypeFailureCount, 0, 0)
        End SyncLock
        Exit Sub
    End If
    ReDim Types(TypeCount - 1)
    FrozenIndex = 0
    While FrozenIndex < TypeCount
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Types(FrozenIndex).StableId = WireLongValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Types(FrozenIndex).TypeKind = WireLongValue
        WireStringValue = ReadSemanticWireString(FrozenData, FrozenCursor)
        Types(FrozenIndex).TypeName = WireStringValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Types(FrozenIndex).TypeSymbol = WireLongValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Types(FrozenIndex).ElementType = WireLongValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Types(FrozenIndex).ArrayRank = WireLongValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Types(FrozenIndex).FixedLength = WireLongValue
        FrozenIndex = FrozenIndex + 1
    Wend
    ScopeCount = ReadSemanticWireLong(FrozenData, FrozenCursor)
    If ScopeCount <= 0 Or ScopeCount > LimitSemanticScopes() Then
        Dim ScopeFailureExpressions() As SemanticExpression
        Dim ScopeFailureBindings() As SemanticNodeBinding
        Dim ScopeFailureDiagnostics() As CompilerDiagnostic
        Dim ScopeFailureCount As Long = 0
        Dim ScopeFailureCapacity As Long = 0
        Call AddDiagnostic(ScopeFailureDiagnostics, ScopeFailureCount, ScopeFailureCapacity, "UBE5323", "<compiler-semantics>", 1, 1, "parallel semantic worker rejected malformed frozen scopes")
        SyncLock ParallelGrammarLoadLock
            Call Result.StoreSemanticWorkerResult(ScopeFailureExpressions, 0, ScopeFailureBindings, 0, ScopeFailureDiagnostics, ScopeFailureCount, 0, 0)
        End SyncLock
        Exit Sub
    End If
    ReDim Scopes(ScopeCount - 1)
    FrozenIndex = 0
    While FrozenIndex < ScopeCount
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Scopes(FrozenIndex).StableId = WireLongValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Scopes(FrozenIndex).ScopeKind = WireLongValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Scopes(FrozenIndex).ParentScope = WireLongValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Scopes(FrozenIndex).OwnerSymbol = WireLongValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Scopes(FrozenIndex).SourceId = WireLongValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Scopes(FrozenIndex).SyntaxNode = WireLongValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Scopes(FrozenIndex).FirstSymbolLink = WireLongValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Scopes(FrozenIndex).LastSymbolLink = WireLongValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Scopes(FrozenIndex).SymbolCount = WireLongValue
        FrozenIndex = FrozenIndex + 1
    Wend
    LinkCount = ReadSemanticWireLong(FrozenData, FrozenCursor)
    If LinkCount < 0 Or LinkCount > LimitSemanticSymbols() Then
        Dim LinkFailureExpressions() As SemanticExpression
        Dim LinkFailureBindings() As SemanticNodeBinding
        Dim LinkFailureDiagnostics() As CompilerDiagnostic
        Dim LinkFailureCount As Long = 0
        Dim LinkFailureCapacity As Long = 0
        Call AddDiagnostic(LinkFailureDiagnostics, LinkFailureCount, LinkFailureCapacity, "UBE5323", "<compiler-semantics>", 1, 1, "parallel semantic worker rejected malformed frozen links")
        SyncLock ParallelGrammarLoadLock
            Call Result.StoreSemanticWorkerResult(LinkFailureExpressions, 0, LinkFailureBindings, 0, LinkFailureDiagnostics, LinkFailureCount, 0, 0)
        End SyncLock
        Exit Sub
    End If
    If LinkCount > 0 Then
        ReDim Links(LinkCount - 1)
    End If
    FrozenIndex = 0
    While FrozenIndex < LinkCount
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Links(FrozenIndex).SymbolIndex = WireLongValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Links(FrozenIndex).NextLink = WireLongValue
        FrozenIndex = FrozenIndex + 1
    Wend
    SymbolCount = ReadSemanticWireLong(FrozenData, FrozenCursor)
    If SymbolCount <= 0 Or SymbolCount > LimitSemanticSymbols() Then
        Dim SymbolFailureExpressions() As SemanticExpression
        Dim SymbolFailureBindings() As SemanticNodeBinding
        Dim SymbolFailureDiagnostics() As CompilerDiagnostic
        Dim SymbolFailureCount As Long = 0
        Dim SymbolFailureCapacity As Long = 0
        Call AddDiagnostic(SymbolFailureDiagnostics, SymbolFailureCount, SymbolFailureCapacity, "UBE5323", "<compiler-semantics>", 1, 1, "parallel semantic worker rejected malformed frozen symbols")
        SyncLock ParallelGrammarLoadLock
            Call Result.StoreSemanticWorkerResult(SymbolFailureExpressions, 0, SymbolFailureBindings, 0, SymbolFailureDiagnostics, SymbolFailureCount, 0, 0)
        End SyncLock
        Exit Sub
    End If
    ReDim Symbols(SymbolCount - 1)
    FrozenIndex = 0
    While FrozenIndex < SymbolCount
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Symbols(FrozenIndex).StableId = WireLongValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Symbols(FrozenIndex).SymbolKind = WireLongValue
        WireStringValue = ReadSemanticWireString(FrozenData, FrozenCursor)
        Symbols(FrozenIndex).SymbolName = WireStringValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Symbols(FrozenIndex).ScopeIndex = WireLongValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Symbols(FrozenIndex).ParentSymbol = WireLongValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Symbols(FrozenIndex).SourceId = WireLongValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Symbols(FrozenIndex).SyntaxNode = WireLongValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Symbols(FrozenIndex).FirstToken = WireLongValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Symbols(FrozenIndex).LastToken = WireLongValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Symbols(FrozenIndex).VisibilityKind = WireLongValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Symbols(FrozenIndex).DeclaredType = WireLongValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Symbols(FrozenIndex).ParameterOrdinal = WireLongValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Symbols(FrozenIndex).Flags = WireLongValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Symbols(FrozenIndex).RelatedSymbol = WireLongValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Symbols(FrozenIndex).SecondaryScope = WireLongValue
        WireLongValue = ReadSemanticWireLong(FrozenData, FrozenCursor)
        Symbols(FrozenIndex).ConstantKind = WireLongValue
        Symbols(FrozenIndex).ConstantInteger = 0
        WireStringValue = ReadSemanticWireString(FrozenData, FrozenCursor)
        Symbols(FrozenIndex).ConstantText = WireStringValue
        FrozenIndex = FrozenIndex + 1
    Wend
    Dim Expressions() As SemanticExpression
    Dim ExpressionCount As Long = 0
    Dim ExpressionCapacity As Long = 0
    Dim OutputBindings() As SemanticNodeBinding
    Dim OutputBindingCount As Long = 0
    Dim OutputBindingCapacity As Long = 0
    Dim Diagnostics() As CompilerDiagnostic
    Dim DiagnosticCount As Long = 0
    Dim DiagnosticCapacity As Long = 0
    Dim AnalyzedExpressionCount As Long = 0
    Dim TypedExpressionCount As Long = 0
    Dim GlobalCacheNames() As String
    Dim GlobalCacheSourceIds() As Long
    Dim GlobalCacheResults() As Long
    Dim GlobalCacheCount As Long = 0
    Dim ScopedCacheScopes() As Long
    Dim ScopedCacheNames() As String
    Dim ScopedCacheResults() As Long
    Dim ScopedCacheCount As Long = 0
    If SymbolCount > 0 Then
        ReDim ScopedCacheScopes(SymbolCount - 1)
        ReDim ScopedCacheNames(SymbolCount - 1)
        ReDim ScopedCacheResults(SymbolCount - 1)
        ReDim GlobalCacheSourceIds(SymbolCount - 1)
        ReDim GlobalCacheNames(SymbolCount - 1)
        ReDim GlobalCacheResults(SymbolCount - 1)
    End If
    Dim EmptySyntaxLinks() As SyntaxChildLink
    Dim EmptyRules() As GrammarRule
    Dim WorkItemIndex As Long = 0
    While WorkItemIndex < Result.SemanticWorkItemCount
        Dim WorkData As String = Result.SemanticWorkItemAt(WorkItemIndex)
        Dim WorkCursor As Long = 0
        While WorkCursor < StringLength(WorkData)
        Dim RecordKind As Long = 0
        RecordKind = ReadSemanticWireLong(WorkData, WorkCursor)
        If RecordKind = 1 Then
            Dim OriginalNode As Long = 0
            OriginalNode = ReadSemanticWireLong(WorkData, WorkCursor)
            Dim SyntaxNodes() As SyntaxNode
            ReDim SyntaxNodes(0)
                WireLongValue = ReadSemanticWireLong(WorkData, WorkCursor)
            SyntaxNodes(0).SourceId = WireLongValue
            SyntaxNodes(0).FirstToken = 0
            Dim Bindings() As SemanticNodeBinding
            ReDim Bindings(0)
            Bindings(0).SyntaxNode = 0
                WireLongValue = ReadSemanticWireLong(WorkData, WorkCursor)
            Bindings(0).ScopeIndex = WireLongValue
                WireLongValue = ReadSemanticWireLong(WorkData, WorkCursor)
            Bindings(0).OwnerSymbol = WireLongValue
            Dim TokenCount As Long = 0
            TokenCount = ReadSemanticWireLong(WorkData, WorkCursor)
            If TokenCount <= 0 Or TokenCount > LimitTokenCount() Then
                Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE5323", "<compiler-semantics>", 1, 1, "parallel semantic worker rejected malformed procedure work")
                Exit While
            End If
            Dim Tokens() As LexicalToken
            If TokenCount > 0 Then
                ReDim Tokens(TokenCount - 1)
            End If
            SyntaxNodes(0).LastToken = TokenCount - 1
            Dim TokenIndex As Long = 0
            While TokenIndex < TokenCount
                WireLongValue = ReadSemanticWireLong(WorkData, WorkCursor)
                Tokens(TokenIndex).TokenKind = WireLongValue
                WireLongValue = ReadSemanticWireLong(WorkData, WorkCursor)
                Tokens(TokenIndex).SourceId = WireLongValue
                WireLongValue = ReadSemanticWireLong(WorkData, WorkCursor)
                Tokens(TokenIndex).StartByte = WireLongValue
                WireLongValue = ReadSemanticWireLong(WorkData, WorkCursor)
                Tokens(TokenIndex).ByteLength = WireLongValue
                WireLongValue = ReadSemanticWireLong(WorkData, WorkCursor)
                Tokens(TokenIndex).LineNumber = WireLongValue
                WireLongValue = ReadSemanticWireLong(WorkData, WorkCursor)
                Tokens(TokenIndex).ColumnNumber = WireLongValue
                WireStringValue = ReadSemanticWireString(WorkData, WorkCursor)
                Tokens(TokenIndex).Spelling = WireStringValue
                WireStringValue = ReadSemanticWireString(WorkData, WorkCursor)
                Tokens(TokenIndex).Decoded = WireStringValue
                TokenIndex = TokenIndex + 1
            Wend
            AnalyzedExpressionCount = AnalyzedExpressionCount + 1
            Dim ResolvedSymbol As Long = ResolveExpressionSymbol(0, Sources, SyntaxNodes, EmptySyntaxLinks, EmptyRules, Tokens, Scopes, Links, Symbols, SymbolCount, Bindings, 1, ScopedCacheScopes, ScopedCacheNames, ScopedCacheResults, ScopedCacheCount, GlobalCacheSourceIds, GlobalCacheNames, GlobalCacheResults, GlobalCacheCount)
            If ResolvedSymbol < 0 Then
                Dim InaccessibleSymbol As Long = FindInaccessibleReferenceSymbol(0, Sources, SyntaxNodes, Tokens, Symbols, SymbolCount)
                If InaccessibleSymbol >= 0 Then
                    Call AddSemanticDiagnostic("UBE4043", 0, "declaration is not public in a direct project Reference: " & Symbols(InaccessibleSymbol).SymbolName, Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                End If
            End If
            Dim ExpressionType As Long = -1
            Dim ValueCategory As Long = 0
            If ResolvedSymbol >= 0 Then
                If Symbols(ResolvedSymbol).DeclaredType >= 0 Then
                    ExpressionType = Symbols(ResolvedSymbol).DeclaredType
                End If
                If Symbols(ResolvedSymbol).SymbolKind = SemanticSymbolVariable() Or Symbols(ResolvedSymbol).SymbolKind = SemanticSymbolParameter() Then
                    ValueCategory = 1
                Else
                    ValueCategory = 2
                End If
            End If
            If ExpressionType < 0 Then
                ExpressionType = LiteralExpressionType(0, SyntaxNodes, Tokens, Types, TypeCount)
            End If
            If ExpressionType < 0 Then
                If SyntaxNodeContainsToken(0, "Nothing", SyntaxNodes, Tokens) <> 0 Then
                    ExpressionType = FindSemanticType("Nothing", Types, TypeCount)
                ElseIf SyntaxNodeContainsToken(0, "Empty", SyntaxNodes, Tokens) <> 0 Then
                    ExpressionType = FindSemanticType("Empty", Types, TypeCount)
                ElseIf SyntaxNodeContainsToken(0, "&", SyntaxNodes, Tokens) <> 0 Then
                    ExpressionType = FindSemanticType("String", Types, TypeCount)
                ElseIf SyntaxNodeContainsToken(0, "Is", SyntaxNodes, Tokens) <> 0 Or SyntaxNodeContainsToken(0, "Like", SyntaxNodes, Tokens) <> 0 Then
                    ExpressionType = FindSemanticType("Boolean", Types, TypeCount)
                Else
                    ExpressionType = FindSemanticType("Variant", Types, TypeCount)
                End If
            End If
            If ExpressionType >= 0 Then
                TypedExpressionCount = TypedExpressionCount + 1
                Dim ConstantKind As Long = 0
                Dim ConstantText As String = ""
                If TokenCount = 1 Then
                    If Tokens(0).TokenKind = 4 Or Tokens(0).TokenKind = 5 Or Tokens(0).TokenKind = 6 Or Tokens(0).TokenKind = 7 Then
                        ConstantKind = Tokens(0).TokenKind
                        ConstantText = Tokens(0).Decoded
                        If StringLength(ConstantText) = 0 Then
                            ConstantText = Tokens(0).Spelling
                        End If
                    ElseIf EqualsFolded(Tokens(0).Spelling, "True") <> 0 Or EqualsFolded(Tokens(0).Spelling, "False") <> 0 Or EqualsFolded(Tokens(0).Spelling, "Null") <> 0 Or EqualsFolded(Tokens(0).Spelling, "Empty") <> 0 Or EqualsFolded(Tokens(0).Spelling, "Nothing") <> 0 Then
                        ConstantKind = Tokens(0).TokenKind
                        ConstantText = Tokens(0).Spelling
                    End If
                End If
                Call AppendSemanticExpression(Expressions, ExpressionCount, ExpressionCapacity, OriginalNode, ExpressionType, ResolvedSymbol, 0, ValueCategory, ConstantKind, ConstantText, 0)
            Else
                Call AddSemanticDiagnostic("UBE4040", 0, "expression has no semantic type", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
            End If
        Else
            Dim BindingNode As Long = 0
            Dim BindingScope As Long = 0
            Dim BindingOwner As Long = 0
            BindingNode = ReadSemanticWireLong(WorkData, WorkCursor)
            BindingScope = ReadSemanticWireLong(WorkData, WorkCursor)
            BindingOwner = ReadSemanticWireLong(WorkData, WorkCursor)
            Dim AddedBinding As Long = AppendSemanticNodeBinding(OutputBindings, OutputBindingCount, OutputBindingCapacity, BindingNode, BindingScope, BindingOwner)
            If AddedBinding >= 0 Then
                WireLongValue = ReadSemanticWireLong(WorkData, WorkCursor)
                OutputBindings(AddedBinding).IrRegionOwnerEncoded = WireLongValue
                WireLongValue = ReadSemanticWireLong(WorkData, WorkCursor)
                OutputBindings(AddedBinding).IrRegionKind = WireLongValue
            End If
        End If
        Wend
        WorkItemIndex = WorkItemIndex + 1
    Wend
    SyncLock ParallelGrammarLoadLock
        Call Result.StoreSemanticWorkerResult(Expressions, ExpressionCount, OutputBindings, OutputBindingCount, Diagnostics, DiagnosticCount, AnalyzedExpressionCount, TypedExpressionCount)
    End SyncLock
End Sub

Sub SortParallelSemanticExpressions(ByRef Expressions() As SemanticExpression, ByVal ExpressionCount As Long)
    Dim Index As Long = 1
    While Index < ExpressionCount
        Dim Value As SemanticExpression = Expressions(Index)
        Dim Position As Long = Index
        While Position > 0
            If Expressions(Position - 1).SyntaxNode <= Value.SyntaxNode Then
                Exit While
            End If
            Expressions(Position) = Expressions(Position - 1)
            Position = Position - 1
        Wend
        Expressions(Position) = Value
        Index = Index + 1
    Wend
    Index = 0
    While Index < ExpressionCount
        Expressions(Index).StableId = Index + 1
        Index = Index + 1
    Wend
End Sub

Sub SortParallelSemanticBindings(ByRef Bindings() As SemanticNodeBinding, ByVal BindingCount As Long)
    Dim Index As Long = 1
    While Index < BindingCount
        Dim ValueStableId As Long = Bindings(Index).StableId
        Dim ValueSyntaxNode As Long = Bindings(Index).SyntaxNode
        Dim ValueScopeIndex As Long = Bindings(Index).ScopeIndex
        Dim ValueOwnerSymbol As Long = Bindings(Index).OwnerSymbol
        Dim ValueIrRegionOwnerEncoded As Long = Bindings(Index).IrRegionOwnerEncoded
        Dim ValueIrRegionKind As Long = Bindings(Index).IrRegionKind
        Dim Position As Long = Index
        While Position > 0
            If Bindings(Position - 1).SyntaxNode <= ValueSyntaxNode Then
                Exit While
            End If
            Bindings(Position).StableId = Bindings(Position - 1).StableId
            Bindings(Position).SyntaxNode = Bindings(Position - 1).SyntaxNode
            Bindings(Position).ScopeIndex = Bindings(Position - 1).ScopeIndex
            Bindings(Position).OwnerSymbol = Bindings(Position - 1).OwnerSymbol
            Bindings(Position).IrRegionOwnerEncoded = Bindings(Position - 1).IrRegionOwnerEncoded
            Bindings(Position).IrRegionKind = Bindings(Position - 1).IrRegionKind
            Position = Position - 1
        Wend
        Bindings(Position).StableId = ValueStableId
        Bindings(Position).SyntaxNode = ValueSyntaxNode
        Bindings(Position).ScopeIndex = ValueScopeIndex
        Bindings(Position).OwnerSymbol = ValueOwnerSymbol
        Bindings(Position).IrRegionOwnerEncoded = ValueIrRegionOwnerEncoded
        Bindings(Position).IrRegionKind = ValueIrRegionKind
        Index = Index + 1
    Wend
    Index = 0
    While Index < BindingCount
        Bindings(Index).StableId = Index + 1
        Index = Index + 1
    Wend
End Sub

Sub AddParallelSemanticDiagnostic(ByVal Code As String, ByVal Message As String, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long)
    Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Code, "<compiler-semantics>", 1, 1, Message)
End Sub

Function RunCompilerSemantics(ByRef Project As ProjectDescription, ByRef Sources() As SourceDocument, ByVal SourceCount As Long, ByRef Envelopes() As SourceEnvelopeInfo, ByRef Tokens() As LexicalToken, ByVal TokenCount As Long, ByRef SyntaxNodes() As SyntaxNode, ByVal SyntaxNodeCount As Long, ByRef SyntaxLinks() As SyntaxChildLink, ByVal SyntaxLinkCount As Long, ByRef Rules() As GrammarRule, ByVal RuleCount As Long, ByRef State As SemanticState, ByRef Types() As SemanticType, ByRef TypeCount As Long, ByRef TypeCapacity As Long, ByRef Scopes() As SemanticScope, ByRef ScopeCount As Long, ByRef ScopeCapacity As Long, ByRef Symbols() As SemanticSymbol, ByRef SymbolCount As Long, ByRef SymbolCapacity As Long, ByRef Links() As SemanticSymbolLink, ByRef LinkCount As Long, ByRef LinkCapacity As Long, ByRef Expressions() As SemanticExpression, ByRef ExpressionCount As Long, ByRef ExpressionCapacity As Long, ByRef Bindings() As SemanticNodeBinding, ByRef BindingCount As Long, ByRef BindingCapacity As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long, ByVal RequestedJobs As Long, ByVal FaultSite As String, ByRef EffectiveJobs As Long) As Long
    EffectiveJobs = 1
    If RequestedJobs <= 1 Then
        RunCompilerSemantics = AnalyzeSemantics(Project, Sources, SourceCount, Envelopes, Tokens, SyntaxNodes, SyntaxNodeCount, SyntaxLinks, Rules, RuleCount, State, Types, TypeCount, TypeCapacity, Scopes, ScopeCount, ScopeCapacity, Symbols, SymbolCount, SymbolCapacity, Links, LinkCount, LinkCapacity, Expressions, ExpressionCount, ExpressionCapacity, Bindings, BindingCount, BindingCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        Exit Function
    End If
    If FreezeSemanticDeclarations(Sources, SourceCount, Envelopes, Tokens, SyntaxNodes, SyntaxNodeCount, SyntaxLinks, Rules, RuleCount, State, Types, TypeCount, TypeCapacity, Scopes, ScopeCount, ScopeCapacity, Symbols, SymbolCount, SymbolCapacity, Links, LinkCount, LinkCapacity, Bindings, BindingCount, BindingCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        RunCompilerSemantics = 0
        Exit Function
    End If
    Dim ProcedureCount As Long = 0
    Dim SymbolIndex As Long = 0
    While SymbolIndex < SymbolCount
        If Symbols(SymbolIndex).SymbolKind = SemanticSymbolProcedure() Or Symbols(SymbolIndex).SymbolKind = SemanticSymbolProperty() Or Symbols(SymbolIndex).SymbolKind = SemanticSymbolEvent() Then
            ProcedureCount = ProcedureCount + 1
        End If
        SymbolIndex = SymbolIndex + 1
    Wend
    Dim WorkerCount As Long = RequestedJobs
    If WorkerCount > 32 Then
        WorkerCount = 32
    End If
    If WorkerCount > ProcedureCount Then
        WorkerCount = ProcedureCount
    End If
    If WorkerCount <= 1 Then
        Call AnalyzeExpressions(Sources, SyntaxNodes, SyntaxNodeCount, SyntaxLinks, Rules, RuleCount, Tokens, Types, TypeCount, Scopes, Links, Symbols, SymbolCount, State, Expressions, ExpressionCount, ExpressionCapacity, Bindings, BindingCount, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        Call FinalizeSemanticAnalysis(Project, Sources, SyntaxNodes, SyntaxNodeCount, SyntaxLinks, Rules, Tokens, Types, TypeCount, Symbols, SymbolCount, State, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        RunCompilerSemantics = 1
        Exit Function
    End If
    ' Each Phase 4 worker currently receives and reconstructs the complete
    ' frozen semantic universe. Measurements on UBECore and the compiler show
    ' that this transport is more expensive than coordinator analysis at every
    ' supported job count. Do not activate a known-slower optimization during
    ' normal compilation. Explicit semantic fault sites still enter the worker
    ' path so creation, transfer, drain, merge, and cleanup remain covered.
    Dim ExerciseSemanticWorkers As Long = 0
    If EqualsFolded(FaultSite, "semantic-worker-creation") <> 0 Or EqualsFolded(FaultSite, "semantic-transfer") <> 0 Or EqualsFolded(FaultSite, "semantic-worker-wait") <> 0 Or EqualsFolded(FaultSite, "semantic-merge") <> 0 Then
        ExerciseSemanticWorkers = 1
    End If
    If ExerciseSemanticWorkers = 0 Then
        Call AnalyzeExpressions(Sources, SyntaxNodes, SyntaxNodeCount, SyntaxLinks, Rules, RuleCount, Tokens, Types, TypeCount, Scopes, Links, Symbols, SymbolCount, State, Expressions, ExpressionCount, ExpressionCapacity, Bindings, BindingCount, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        Call FinalizeSemanticAnalysis(Project, Sources, SyntaxNodes, SyntaxNodeCount, SyntaxLinks, Rules, Tokens, Types, TypeCount, Symbols, SymbolCount, State, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        RunCompilerSemantics = 1
        Exit Function
    End If
    ' The current worker wire format owns one token slice per expression.
    ' Nested expressions overlap, so a compiler-sized source can otherwise
    ' multiply its token set many times over before workers begin. Keep that
    ' representation bounded: when publication would exceed one complete
    ' project token budget, use the proven sequential body analyzer. This also
    ' bounds the explicit worker fault-path regressions retained above.
    Dim SemanticTransferTokenCount As Long = 0
    Dim TransferNodeIndex As Long = 0
    Dim SemanticTransferFits As Long = 1
    While TransferNodeIndex < SyntaxNodeCount
        If SyntaxRuleIs(TransferNodeIndex, "expression", SyntaxNodes, Rules) <> 0 Then
            Dim TransferTokenCount As Long = SyntaxNodes(TransferNodeIndex).LastToken - SyntaxNodes(TransferNodeIndex).FirstToken + 1
            If TransferTokenCount <= 0 Then
                SemanticTransferFits = 0
                Exit While
            End If
            If TransferTokenCount > TokenCount Or SemanticTransferTokenCount > TokenCount - TransferTokenCount Then
                SemanticTransferFits = 0
                Exit While
            End If
            SemanticTransferTokenCount = SemanticTransferTokenCount + TransferTokenCount
        End If
        TransferNodeIndex = TransferNodeIndex + 1
    Wend
    If SemanticTransferFits = 0 Then
        Call AnalyzeExpressions(Sources, SyntaxNodes, SyntaxNodeCount, SyntaxLinks, Rules, RuleCount, Tokens, Types, TypeCount, Scopes, Links, Symbols, SymbolCount, State, Expressions, ExpressionCount, ExpressionCapacity, Bindings, BindingCount, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        Call FinalizeSemanticAnalysis(Project, Sources, SyntaxNodes, SyntaxNodeCount, SyntaxLinks, Rules, Tokens, Types, TypeCount, Symbols, SymbolCount, State, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        RunCompilerSemantics = 1
        Exit Function
    End If
    EffectiveJobs = WorkerCount
    ' Semantic result publication must own its synchronization setup. Normal
    ' front-end compilation can intentionally remain sequential, so it is not
    ' valid to depend on the front-end worker path having initialized this
    ' shared publication lock as a side effect.
    If ParallelGrammarLoadLock Is Nothing Then
        Set ParallelGrammarLoadLock = New ParallelFrontendResult
    End If
    If EqualsFolded(FaultSite, "semantic-worker-creation") <> 0 Then
        Call AddParallelSemanticDiagnostic("UBE5320", "parallel semantic worker creation failed", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        RunCompilerSemantics = 0
        Exit Function
    End If
    Dim FrozenData As String = FreezeParallelSemanticData(Sources, SourceCount, Types, TypeCount, Scopes, ScopeCount, Links, LinkCount, Symbols, SymbolCount)
    Dim VerifyCursor As Long = 0
    If ReadSemanticWireLong(FrozenData, VerifyCursor) <> SourceCount Then
        Call AddParallelSemanticDiagnostic("UBE5323", "parallel semantic coordinator produced malformed frozen state", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        RunCompilerSemantics = 0
        Exit Function
    End If
    Dim WorkerBySymbol() As Long
    ReDim WorkerBySymbol(SymbolCount - 1)
    SymbolIndex = 0
    Dim ProcedureOrdinal As Long = 0
    While SymbolIndex < SymbolCount
        WorkerBySymbol(SymbolIndex) = 0
        If Symbols(SymbolIndex).SymbolKind = SemanticSymbolProcedure() Or Symbols(SymbolIndex).SymbolKind = SemanticSymbolProperty() Or Symbols(SymbolIndex).SymbolKind = SemanticSymbolEvent() Then
            WorkerBySymbol(SymbolIndex) = ProcedureOrdinal Mod WorkerCount
            ProcedureOrdinal = ProcedureOrdinal + 1
        End If
        SymbolIndex = SymbolIndex + 1
    Wend
    Dim WorkerIndex As Long = 0
    While WorkerIndex < WorkerCount
        Dim PreparedResult As ParallelFrontendResult
        Set PreparedResult = AcquireParallelResultSlot(WorkerIndex)
        Dim WorkerFrozenData As String = StringSlice(FrozenData, 0, StringLength(FrozenData))
        If WorkerIndex = 0 And EqualsFolded(FaultSite, "semantic-transfer") <> 0 Then
            WorkerFrozenData = ""
        End If
        Call PreparedResult.PrepareSemantic(WorkerFrozenData, SourceCount)
        WorkerIndex = WorkerIndex + 1
    Wend
    Dim NodeIndex As Long = 0
    While NodeIndex < SyntaxNodeCount
        If SyntaxRuleIs(NodeIndex, "expression", SyntaxNodes, Rules) <> 0 Then
            Dim ExpressionOwner As Long = Bindings(NodeIndex).OwnerSymbol
            Dim ExpressionWorker As Long = 0
            If ExpressionOwner >= 0 And ExpressionOwner < SymbolCount Then
                ExpressionWorker = WorkerBySymbol(ExpressionOwner)
            End If
        If AppendParallelExpressionWork(AcquireParallelResultSlot(ExpressionWorker), NodeIndex, SyntaxNodes, Tokens, Bindings) = 0 Then
            Call AddParallelSemanticDiagnostic("UBE5323", "parallel semantic expression publication exceeded a configured bound", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            RunCompilerSemantics = 0
            Exit Function
        End If
        End If
        NodeIndex = NodeIndex + 1
    Wend
    ' Declaration freezing already produced the complete binding table in
    ' canonical syntax-node order. Procedure workers only read the binding for
    ' each expression; they do not transform bindings. Keep that coordinator-
    ' owned table in place instead of serializing every syntax-node binding to
    ' a worker, copying it back unchanged, and insertion-sorting the result.
    ' On the self-host input that redundant round trip exceeded one million
    ' records and dominated the parallel semantic phase.
    ExpressionCount = 0
    ExpressionCapacity = 0
    Dim ThreadIds() As LongLong
    ReDim ThreadIds(WorkerCount - 1)
    Dim LaunchedCount As Long = 0
    WorkerIndex = 0
    While WorkerIndex < WorkerCount
        Dim Result As ParallelFrontendResult
        Set Result = AcquireParallelResultSlot(WorkerIndex)
        ThreadIds(WorkerIndex) = CallNew ParallelSemanticWorker(Result)
        If ThreadIds(WorkerIndex) <= 0 Then
            Call AddParallelSemanticDiagnostic("UBE5320", "parallel semantic worker creation failed", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Exit While
        End If
        LaunchedCount = LaunchedCount + 1
        WorkerIndex = WorkerIndex + 1
    Wend
    WorkerIndex = 0
    While WorkerIndex < LaunchedCount
        Dim WaitResult As ParallelFrontendResult
        Set WaitResult = AcquireParallelResultSlot(WorkerIndex)
        If RuntimeThreadWait(ThreadIds(WorkerIndex), -1) = 0 Then
            Call AddParallelSemanticDiagnostic("UBE5321", "parallel semantic worker drain failed", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        Else
            If WaitResult.Completed <> 1 Then
                Call AddParallelSemanticDiagnostic("UBE5321", "parallel semantic worker returned without a result", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            End If
        End If
        WorkerIndex = WorkerIndex + 1
    Wend
    If EqualsFolded(FaultSite, "semantic-worker-wait") <> 0 Then
        Call AddParallelSemanticDiagnostic("UBE5321", "parallel semantic worker drain failed", Diagnostics, DiagnosticCount, DiagnosticCapacity)
    End If
    If LaunchedCount <> WorkerCount Or DiagnosticCount <> 0 Then
        RunCompilerSemantics = 0
        Exit Function
    End If
    If EqualsFolded(FaultSite, "semantic-merge") <> 0 Then
        Call AddParallelSemanticDiagnostic("UBE5322", "parallel semantic deterministic merge failed", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        RunCompilerSemantics = 0
        Exit Function
    End If
    State.ExpressionCount = 0
    State.TypedExpressionCount = 0
    Dim WorkerExpressionCursors() As Long
    ReDim WorkerExpressionCursors(WorkerCount - 1)
    Dim RemainingWorkerExpressions As Long = 0
    WorkerIndex = 0
    While WorkerIndex < WorkerCount
        Dim MergeResult As ParallelFrontendResult
        Set MergeResult = AcquireParallelResultSlot(WorkerIndex)
        RemainingWorkerExpressions = RemainingWorkerExpressions + MergeResult.SemanticExpressionCount
        Call MergeResult.MergeDiagnostics(Diagnostics, DiagnosticCount, DiagnosticCapacity)
        State.ExpressionCount = State.ExpressionCount + MergeResult.SemanticAnalyzedExpressionCount
        State.TypedExpressionCount = State.TypedExpressionCount + MergeResult.SemanticTypedExpressionCount
        WorkerIndex = WorkerIndex + 1
    Wend
    ' Each worker receives expression nodes in ascending syntax order, so its
    ' result is already sorted. Merge those bounded sorted streams directly
    ' instead of appending in worker order and insertion-sorting the complete
    ' self-host expression set.
    While RemainingWorkerExpressions > 0
        Dim BestWorker As Long = -1
        Dim BestSyntaxNode As Long = -1
        WorkerIndex = 0
        While WorkerIndex < WorkerCount
            Dim CandidateResult As ParallelFrontendResult
            Set CandidateResult = AcquireParallelResultSlot(WorkerIndex)
            Dim CandidateCursor As Long = WorkerExpressionCursors(WorkerIndex)
            If CandidateCursor < CandidateResult.SemanticExpressionCount Then
                Dim CandidateSyntaxNode As Long = CandidateResult.SemanticExpressionSyntaxNodeAt(CandidateCursor)
                If BestWorker < 0 Then
                    BestWorker = WorkerIndex
                    BestSyntaxNode = CandidateSyntaxNode
                ElseIf CandidateSyntaxNode < BestSyntaxNode Then
                    BestWorker = WorkerIndex
                    BestSyntaxNode = CandidateSyntaxNode
                End If
            End If
            WorkerIndex = WorkerIndex + 1
        Wend
        If BestWorker < 0 Then
            Call AddParallelSemanticDiagnostic("UBE5322", "parallel semantic deterministic merge lost an expression result", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            RunCompilerSemantics = 0
            Exit Function
        End If
        Dim SelectedResult As ParallelFrontendResult
        Set SelectedResult = AcquireParallelResultSlot(BestWorker)
        Dim SelectedCursor As Long = WorkerExpressionCursors(BestWorker)
        If SelectedResult.AppendSemanticExpressionAt(SelectedCursor, Expressions, ExpressionCount, ExpressionCapacity) = 0 Then
            Call AddParallelSemanticDiagnostic("UBE5322", "parallel semantic deterministic merge exceeded the expression limit", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            RunCompilerSemantics = 0
            Exit Function
        End If
        WorkerExpressionCursors(BestWorker) = SelectedCursor + 1
        RemainingWorkerExpressions = RemainingWorkerExpressions - 1
    Wend
    Call SortParallelDiagnostics(Diagnostics, DiagnosticCount)
    Call FinalizeSemanticConstants(Sources, SyntaxNodes, SyntaxLinks, Rules, Tokens, Symbols, SymbolCount, Diagnostics, DiagnosticCount, DiagnosticCapacity)
    Call FinalizeSemanticAnalysis(Project, Sources, SyntaxNodes, SyntaxNodeCount, SyntaxLinks, Rules, Tokens, Types, TypeCount, Symbols, SymbolCount, State, Diagnostics, DiagnosticCount, DiagnosticCapacity)
    RunCompilerSemantics = 1
End Function
