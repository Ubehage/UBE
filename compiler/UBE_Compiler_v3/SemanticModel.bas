UBE SOURCE 1 MODULE
Attribute UBE_Name = "SemanticModel"

Type SemanticType
    StableId As Long
    TypeKind As Long
    TypeName As String
    TypeSymbol As Long
    ElementType As Long
    ArrayRank As Long
    FixedLength As Long
End Type

Type SemanticScope
    StableId As Long
    ScopeKind As Long
    ParentScope As Long
    OwnerSymbol As Long
    SourceId As Long
    SyntaxNode As Long
    FirstSymbolLink As Long
    LastSymbolLink As Long
    SymbolCount As Long
End Type

Type SemanticSymbol
    StableId As Long
    SymbolKind As Long
    SymbolName As String
    ScopeIndex As Long
    ParentSymbol As Long
    SourceId As Long
    SyntaxNode As Long
    FirstToken As Long
    LastToken As Long
    VisibilityKind As Long
    DeclaredType As Long
    ParameterOrdinal As Long
    Flags As Long
    RelatedSymbol As Long
    SecondaryScope As Long
    ConstantKind As Long
    ConstantInteger As LongLong
    ConstantText As String
    IrNameBucketHead As Long
    IrNameNext As Long
End Type

Type SemanticSymbolLink
    SymbolIndex As Long
    NextLink As Long
End Type

Type SemanticState
    PackageScope As Long
    EntrySymbol As Long
    EntryCount As Long
    HasErrors As Long
    ExpressionCount As Long
    TypedExpressionCount As Long
End Type

Type SemanticExpression
    StableId As Long
    SyntaxNode As Long
    TypeIndex As Long
    ResolvedSymbol As Long
    ConversionKind As Long
    ValueCategory As Long
    ConstantKind As Long
    ConstantText As String
    Flags As Long
End Type

Type SemanticNodeBinding
    StableId As Long
    SyntaxNode As Long
    ScopeIndex As Long
    OwnerSymbol As Long
    IrRegionOwnerEncoded As Long
    IrRegionKind As Long
End Type

Function AppendSemanticExpression(ByRef Items() As SemanticExpression, ByRef Count As Long, ByRef Capacity As Long, ByVal SyntaxNode As Long, ByVal TypeIndex As Long, ByVal ResolvedSymbol As Long, ByVal ConversionKind As Long, ByVal ValueCategory As Long, ByVal ConstantKind As Long, ByVal ConstantText As String, ByVal Flags As Long) As Long
    If Count >= LimitSyntaxNodes() Then
        AppendSemanticExpression = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = 256
        If Capacity > 0 Then
            NewCapacity = Capacity * 2
        End If
        If NewCapacity > LimitSyntaxNodes() Then
            NewCapacity = LimitSyntaxNodes()
        End If
        If Capacity = 0 Then
            ReDim Items(NewCapacity - 1)
        Else
            ReDim Preserve Items(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Dim Result As Long = Count
    Items(Result).StableId = Result + 1
    Items(Result).SyntaxNode = SyntaxNode
    Items(Result).TypeIndex = TypeIndex
    Items(Result).ResolvedSymbol = ResolvedSymbol
    Items(Result).ConversionKind = ConversionKind
    Items(Result).ValueCategory = ValueCategory
    Items(Result).ConstantKind = ConstantKind
    Items(Result).ConstantText = ConstantText
    Items(Result).Flags = Flags
    Count = Count + 1
    AppendSemanticExpression = Result
End Function

Function AppendSemanticNodeBinding(ByRef Items() As SemanticNodeBinding, ByRef Count As Long, ByRef Capacity As Long, ByVal SyntaxNode As Long, ByVal ScopeIndex As Long, ByVal OwnerSymbol As Long) As Long
    If Count >= LimitSyntaxNodes() Then
        AppendSemanticNodeBinding = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = 512
        If Capacity > 0 Then
            NewCapacity = Capacity * 2
        End If
        If NewCapacity > LimitSyntaxNodes() Then
            NewCapacity = LimitSyntaxNodes()
        End If
        If Capacity = 0 Then
            ReDim Items(NewCapacity - 1)
        Else
            ReDim Preserve Items(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Dim Result As Long = Count
    Items(Result).StableId = Result + 1
    Items(Result).SyntaxNode = SyntaxNode
    Items(Result).ScopeIndex = ScopeIndex
    Items(Result).OwnerSymbol = OwnerSymbol
    Count = Count + 1
    AppendSemanticNodeBinding = Result
End Function

Function AppendSemanticType(ByRef Types() As SemanticType, ByRef TypeCount As Long, ByRef TypeCapacity As Long, ByVal TypeKind As Long, ByVal TypeName As String, ByVal TypeSymbol As Long, ByVal ElementType As Long, ByVal ArrayRank As Long, ByVal FixedLength As Long) As Long
    If TypeCount >= LimitSemanticTypes() Then
        AppendSemanticType = -1
        Exit Function
    End If
    If TypeCount = TypeCapacity Then
        Dim NewCapacity As Long = 64
        If TypeCapacity > 0 Then
            NewCapacity = TypeCapacity * 2
        End If
        If NewCapacity > LimitSemanticTypes() Then
            NewCapacity = LimitSemanticTypes()
        End If
        If TypeCapacity = 0 Then
            ReDim Types(NewCapacity - 1)
        Else
            ReDim Preserve Types(NewCapacity - 1)
        End If
        TypeCapacity = NewCapacity
    End If
    Dim Result As Long = TypeCount
    Types(Result).StableId = Result + 1
    Types(Result).TypeKind = TypeKind
    Types(Result).TypeName = TypeName
    Types(Result).TypeSymbol = TypeSymbol
    Types(Result).ElementType = ElementType
    Types(Result).ArrayRank = ArrayRank
    Types(Result).FixedLength = FixedLength
    TypeCount = TypeCount + 1
    AppendSemanticType = Result
End Function

Function AppendSemanticScope(ByRef Scopes() As SemanticScope, ByRef ScopeCount As Long, ByRef ScopeCapacity As Long, ByVal ScopeKind As Long, ByVal ParentScope As Long, ByVal OwnerSymbol As Long, ByVal SourceId As Long, ByVal SyntaxNode As Long) As Long
    If ScopeCount >= LimitSemanticScopes() Then
        AppendSemanticScope = -1
        Exit Function
    End If
    If ScopeCount = ScopeCapacity Then
        Dim NewCapacity As Long = 64
        If ScopeCapacity > 0 Then
            NewCapacity = ScopeCapacity * 2
        End If
        If NewCapacity > LimitSemanticScopes() Then
            NewCapacity = LimitSemanticScopes()
        End If
        If ScopeCapacity = 0 Then
            ReDim Scopes(NewCapacity - 1)
        Else
            ReDim Preserve Scopes(NewCapacity - 1)
        End If
        ScopeCapacity = NewCapacity
    End If
    Dim Result As Long = ScopeCount
    Scopes(Result).StableId = Result + 1
    Scopes(Result).ScopeKind = ScopeKind
    Scopes(Result).ParentScope = ParentScope
    Scopes(Result).OwnerSymbol = OwnerSymbol
    Scopes(Result).SourceId = SourceId
    Scopes(Result).SyntaxNode = SyntaxNode
    Scopes(Result).FirstSymbolLink = -1
    Scopes(Result).LastSymbolLink = -1
    Scopes(Result).SymbolCount = 0
    ScopeCount = ScopeCount + 1
    AppendSemanticScope = Result
End Function

Function AppendSemanticSymbol(ByRef Symbols() As SemanticSymbol, ByRef SymbolCount As Long, ByRef SymbolCapacity As Long, ByRef Scopes() As SemanticScope, ByRef Links() As SemanticSymbolLink, ByRef LinkCount As Long, ByRef LinkCapacity As Long, ByVal SymbolKind As Long, ByVal SymbolName As String, ByVal ScopeIndex As Long, ByVal ParentSymbol As Long, ByVal SourceId As Long, ByVal SyntaxNode As Long, ByVal FirstToken As Long, ByVal LastToken As Long) As Long
    If SymbolCount >= LimitSemanticSymbols() Or LinkCount >= LimitSemanticSymbols() Then
        AppendSemanticSymbol = -1
        Exit Function
    End If
    If SymbolCount = SymbolCapacity Then
        Dim NewCapacity As Long = 256
        If SymbolCapacity > 0 Then
            NewCapacity = SymbolCapacity * 2
        End If
        If NewCapacity > LimitSemanticSymbols() Then
            NewCapacity = LimitSemanticSymbols()
        End If
        If SymbolCapacity = 0 Then
            ReDim Symbols(NewCapacity - 1)
        Else
            ReDim Preserve Symbols(NewCapacity - 1)
        End If
        SymbolCapacity = NewCapacity
    End If
    If LinkCount = LinkCapacity Then
        Dim NewLinkCapacity As Long = 256
        If LinkCapacity > 0 Then
            NewLinkCapacity = LinkCapacity * 2
        End If
        If NewLinkCapacity > LimitSemanticSymbols() Then
            NewLinkCapacity = LimitSemanticSymbols()
        End If
        If LinkCapacity = 0 Then
            ReDim Links(NewLinkCapacity - 1)
        Else
            ReDim Preserve Links(NewLinkCapacity - 1)
        End If
        LinkCapacity = NewLinkCapacity
    End If
    Dim Result As Long = SymbolCount
    Symbols(Result).StableId = Result + 1
    Symbols(Result).SymbolKind = SymbolKind
    Symbols(Result).SymbolName = SymbolName
    Symbols(Result).ScopeIndex = ScopeIndex
    Symbols(Result).ParentSymbol = ParentSymbol
    Symbols(Result).SourceId = SourceId
    Symbols(Result).SyntaxNode = SyntaxNode
    Symbols(Result).FirstToken = FirstToken
    Symbols(Result).LastToken = LastToken
    Symbols(Result).VisibilityKind = 0
    Symbols(Result).DeclaredType = 0
    Symbols(Result).ParameterOrdinal = -1
    Symbols(Result).Flags = 0
    Symbols(Result).RelatedSymbol = -1
    Symbols(Result).SecondaryScope = -1
    Symbols(Result).ConstantKind = 0
    Symbols(Result).ConstantInteger = 0
    Symbols(Result).ConstantText = ""
    Dim NewLink As Long = LinkCount
    Links(NewLink).SymbolIndex = Result
    Links(NewLink).NextLink = -1
    If Scopes(ScopeIndex).FirstSymbolLink < 0 Then
        Scopes(ScopeIndex).FirstSymbolLink = NewLink
    Else
        Links(Scopes(ScopeIndex).LastSymbolLink).NextLink = NewLink
    End If
    Scopes(ScopeIndex).LastSymbolLink = NewLink
    Scopes(ScopeIndex).SymbolCount = Scopes(ScopeIndex).SymbolCount + 1
    LinkCount = LinkCount + 1
    SymbolCount = SymbolCount + 1
    AppendSemanticSymbol = Result
End Function

Function FindSymbolInScope(ByVal ScopeIndex As Long, ByVal SymbolName As String, ByRef Scopes() As SemanticScope, ByRef Symbols() As SemanticSymbol, ByRef Links() As SemanticSymbolLink) As Long
    Dim LinkIndex As Long = Scopes(ScopeIndex).FirstSymbolLink
    While LinkIndex >= 0
        Dim SymbolIndex As Long = Links(LinkIndex).SymbolIndex
        If Symbols(SymbolIndex).SymbolName = SymbolName Or EqualsFolded(Symbols(SymbolIndex).SymbolName, SymbolName) <> 0 Then
            FindSymbolInScope = SymbolIndex
            Exit Function
        End If
        LinkIndex = Links(LinkIndex).NextLink
    Wend
    FindSymbolInScope = -1
End Function

Function FindVisibleSymbol(ByVal ScopeIndex As Long, ByVal SymbolName As String, ByRef Scopes() As SemanticScope, ByRef Symbols() As SemanticSymbol, ByRef Links() As SemanticSymbolLink) As Long
    Dim CurrentScope As Long = ScopeIndex
    While CurrentScope >= 0
        Dim Result As Long = FindSymbolInScope(CurrentScope, SymbolName, Scopes, Symbols, Links)
        If Result >= 0 Then
            FindVisibleSymbol = Result
            Exit Function
        End If
        CurrentScope = Scopes(CurrentScope).ParentScope
    Wend
    FindVisibleSymbol = -1
End Function
