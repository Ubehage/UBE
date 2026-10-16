UBE SOURCE 1 MODULE
Attribute UBE_Name = "SemanticAnalysis"

Function SemanticScopePackage() As Long
    SemanticScopePackage = 1
End Function

Function SemanticScopeModule() As Long
    SemanticScopeModule = 2
End Function

Function SemanticScopeMember() As Long
    SemanticScopeMember = 3
End Function

Function SemanticScopeProcedure() As Long
    SemanticScopeProcedure = 4
End Function

Function SemanticScopeBlock() As Long
    SemanticScopeBlock = 5
End Function

Function SemanticScopeLabels() As Long
    SemanticScopeLabels = 6
End Function

Function SemanticSymbolModule() As Long
    SemanticSymbolModule = 1
End Function

Function SemanticSymbolVariable() As Long
    SemanticSymbolVariable = 2
End Function

Function SemanticSymbolConstant() As Long
    SemanticSymbolConstant = 3
End Function

Function SemanticSymbolProcedure() As Long
    SemanticSymbolProcedure = 4
End Function

Function SemanticSymbolProperty() As Long
    SemanticSymbolProperty = 5
End Function

Function SemanticSymbolType() As Long
    SemanticSymbolType = 6
End Function

Function SemanticSymbolEnum() As Long
    SemanticSymbolEnum = 7
End Function

Function SemanticSymbolMember() As Long
    SemanticSymbolMember = 8
End Function

Function SemanticSymbolEvent() As Long
    SemanticSymbolEvent = 9
End Function

Function SemanticSymbolInterface() As Long
    SemanticSymbolInterface = 10
End Function

Function SemanticSymbolParameter() As Long
    SemanticSymbolParameter = 11
End Function

Function SemanticSymbolLabel() As Long
    SemanticSymbolLabel = 12
End Function

Function SemanticTypeUnknown() As Long
    SemanticTypeUnknown = 0
End Function

Function AddSemanticDiagnostic(ByVal Code As String, ByVal NodeIndex As Long, ByVal Message As String, ByRef Sources() As SourceDocument, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim SourceIndex As Long = SyntaxNodes(NodeIndex).SourceId - 1
    Dim Path As String = "<source>"
    If SourceIndex >= 0 Then
        Path = Sources(SourceIndex).FilePath
    End If
    AddSemanticDiagnostic = AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Code, Path, SyntaxNodeLine(NodeIndex, SyntaxNodes, Tokens), SyntaxNodeColumn(NodeIndex, SyntaxNodes, Tokens), Message)
End Function

Function InitializeSemanticTypes(ByRef Types() As SemanticType, ByRef TypeCount As Long, ByRef TypeCapacity As Long) As Long
    Dim Names() As String
    ReDim Names(15)
    Names(0) = "<unknown>"
    Names(1) = "Boolean"
    Names(2) = "Byte"
    Names(3) = "Integer"
    Names(4) = "Long"
    Names(5) = "LongLong"
    Names(6) = "Single"
    Names(7) = "Double"
    Names(8) = "Currency"
    Names(9) = "Decimal"
    Names(10) = "Date"
    Names(11) = "String"
    Names(12) = "Object"
    Names(13) = "Variant"
    Names(14) = "Any"
    Names(15) = "IntPtr"
    Dim Index As Long = 0
    While Index <= 15
        If AppendSemanticType(Types, TypeCount, TypeCapacity, Index, Names(Index), -1, -1, 0, 0) < 0 Then
            InitializeSemanticTypes = 0
            Exit Function
        End If
        Index = Index + 1
    Wend
    If AppendSemanticType(Types, TypeCount, TypeCapacity, 16, "UIntPtr", -1, -1, 0, 0) < 0 Then
        InitializeSemanticTypes = 0
        Exit Function
    End If
    If AppendSemanticType(Types, TypeCount, TypeCapacity, 17, "Empty", -1, -1, 0, 0) < 0 Then
        InitializeSemanticTypes = 0
        Exit Function
    End If
    If AppendSemanticType(Types, TypeCount, TypeCapacity, 18, "Null", -1, -1, 0, 0) < 0 Then
        InitializeSemanticTypes = 0
        Exit Function
    End If
    If AppendSemanticType(Types, TypeCount, TypeCapacity, 19, "Nothing", -1, -1, 0, 0) < 0 Then
        InitializeSemanticTypes = 0
        Exit Function
    End If
    InitializeSemanticTypes = 1
End Function

Function FindSemanticType(ByVal SoughtTypeName As String, ByRef Types() As SemanticType, ByVal TypeCount As Long) As Long
    Dim Index As Long = 0
    While Index < TypeCount
        If EqualsFolded(Types(Index).TypeName, SoughtTypeName) <> 0 Then
            FindSemanticType = Index
            Exit Function
        End If
        Index = Index + 1
    Wend
    FindSemanticType = -1
End Function

Function NearestSemanticScope(ByVal NodeIndex As Long, ByRef NodeScopes() As Long, ByRef SyntaxNodes() As SyntaxNode) As Long
    Dim Current As Long = NodeIndex
    While Current >= 0
        If NodeScopes(Current) >= 0 Then
            NearestSemanticScope = NodeScopes(Current)
            Exit Function
        End If
        Current = SyntaxNodes(Current).ParentNode
    Wend
    NearestSemanticScope = -1
End Function

Function NearestProcedureSymbol(ByVal NodeIndex As Long, ByRef NodeOwners() As Long, ByRef SyntaxNodes() As SyntaxNode) As Long
    Dim Current As Long = NodeIndex
    While Current >= 0
        If NodeOwners(Current) >= 0 Then
            NearestProcedureSymbol = NodeOwners(Current)
            Exit Function
        End If
        Current = SyntaxNodes(Current).ParentNode
    Wend
    NearestProcedureSymbol = -1
End Function

Function DeclarationNameNode(ByVal NodeIndex As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef SyntaxLinks() As SyntaxChildLink, ByRef Rules() As GrammarRule) As Long
    DeclarationNameNode = FirstDescendantSyntaxNode(NodeIndex, "identifier", SyntaxNodes, SyntaxLinks, Rules, 0)
End Function

Function AddCheckedSemanticSymbol(ByVal Kind As Long, ByVal SymbolName As String, ByVal ScopeIndex As Long, ByVal ParentSymbol As Long, ByVal NodeIndex As Long, ByVal AllowPropertyPeer As Long, ByRef Sources() As SourceDocument, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken, ByRef Symbols() As SemanticSymbol, ByRef SymbolCount As Long, ByRef SymbolCapacity As Long, ByRef Scopes() As SemanticScope, ByRef Links() As SemanticSymbolLink, ByRef LinkCount As Long, ByRef LinkCapacity As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim Existing As Long = FindSymbolInScope(ScopeIndex, SymbolName, Scopes, Symbols, Links)
    If Existing >= 0 Then
        If AllowPropertyPeer <> 0 And Symbols(Existing).SymbolKind = SemanticSymbolProperty() Then
            AddCheckedSemanticSymbol = Existing
            Exit Function
        End If
        Call AddSemanticDiagnostic("UBE4001", NodeIndex, "duplicate declaration after case folding: " & SymbolName, Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        AddCheckedSemanticSymbol = -1
        Exit Function
    End If
    AddCheckedSemanticSymbol = AppendSemanticSymbol(Symbols, SymbolCount, SymbolCapacity, Scopes, Links, LinkCount, LinkCapacity, Kind, SymbolName, ScopeIndex, ParentSymbol, SyntaxNodes(NodeIndex).SourceId, NodeIndex, SyntaxNodes(NodeIndex).FirstToken, SyntaxNodes(NodeIndex).LastToken)
End Function

Sub MarkScopeTree(ByVal NodeIndex As Long, ByVal ScopeIndex As Long, ByVal OwnerSymbol As Long, ByRef NodeScopes() As Long, ByRef NodeOwners() As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef SyntaxLinks() As SyntaxChildLink)
    NodeScopes(NodeIndex) = ScopeIndex
    NodeOwners(NodeIndex) = OwnerSymbol
End Sub

Function AnalyzeSemantics(ByRef Project As ProjectDescription, ByRef Sources() As SourceDocument, ByVal SourceCount As Long, ByRef Envelopes() As SourceEnvelopeInfo, ByRef Tokens() As LexicalToken, ByRef SyntaxNodes() As SyntaxNode, ByVal SyntaxNodeCount As Long, ByRef SyntaxLinks() As SyntaxChildLink, ByRef Rules() As GrammarRule, ByRef State As SemanticState, ByRef Types() As SemanticType, ByRef TypeCount As Long, ByRef TypeCapacity As Long, ByRef Scopes() As SemanticScope, ByRef ScopeCount As Long, ByRef ScopeCapacity As Long, ByRef Symbols() As SemanticSymbol, ByRef SymbolCount As Long, ByRef SymbolCapacity As Long, ByRef Links() As SemanticSymbolLink, ByRef LinkCount As Long, ByRef LinkCapacity As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    If InitializeSemanticTypes(Types, TypeCount, TypeCapacity) = 0 Then
        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE4099", "<semantic>", 1, 1, "semantic type limit exceeded")
        AnalyzeSemantics = 0
        Exit Function
    End If
    State.PackageScope = AppendSemanticScope(Scopes, ScopeCount, ScopeCapacity, SemanticScopePackage(), -1, -1, 0, -1)
    State.EntrySymbol = -1
    State.EntryCount = 0
    State.HasErrors = 0
    Dim NodeScopes() As Long
    Dim NodeOwners() As Long
    ReDim NodeScopes(SyntaxNodeCount - 1)
    ReDim NodeOwners(SyntaxNodeCount - 1)
    Dim NodeIndex As Long = 0
    While NodeIndex < SyntaxNodeCount
        NodeScopes(NodeIndex) = -1
        NodeOwners(NodeIndex) = -1
        NodeIndex = NodeIndex + 1
    Wend

    Dim SourceIndex As Long = 0
    While SourceIndex < SourceCount
        Dim RootNode As Long = -1
        NodeIndex = 0
        While NodeIndex < SyntaxNodeCount And RootNode < 0
            If SyntaxNodes(NodeIndex).ParentNode < 0 And SyntaxNodes(NodeIndex).SourceId = Sources(SourceIndex).SourceId Then
                RootNode = NodeIndex
            End If
            NodeIndex = NodeIndex + 1
        Wend
        If RootNode >= 0 Then
            Dim ModuleSymbol As Long = AddCheckedSemanticSymbol(SemanticSymbolModule(), Envelopes(SourceIndex).SourceName, State.PackageScope, -1, RootNode, 0, Sources, SyntaxNodes, Tokens, Symbols, SymbolCount, SymbolCapacity, Scopes, Links, LinkCount, LinkCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity)
            If ModuleSymbol >= 0 Then
                Dim ModuleScope As Long = AppendSemanticScope(Scopes, ScopeCount, ScopeCapacity, SemanticScopeModule(), State.PackageScope, ModuleSymbol, Sources(SourceIndex).SourceId, RootNode)
                Symbols(ModuleSymbol).RelatedSymbol = ModuleScope
                Call MarkScopeTree(RootNode, ModuleScope, ModuleSymbol, NodeScopes, NodeOwners, SyntaxNodes, SyntaxLinks)
            End If
        End If
        SourceIndex = SourceIndex + 1
    Wend

    NodeIndex = 0
    While NodeIndex < SyntaxNodeCount
        Dim RuleName As String = Rules(SyntaxNodes(NodeIndex).ProductionRule).RuleName
        If EqualsFolded(RuleName, "statement-block") <> 0 Then
            Dim EnclosingScope As Long = NearestSemanticScope(SyntaxNodes(NodeIndex).ParentNode, NodeScopes, SyntaxNodes)
            Dim EnclosingOwner As Long = NearestProcedureSymbol(SyntaxNodes(NodeIndex).ParentNode, NodeOwners, SyntaxNodes)
            If EnclosingScope >= 0 Then
                Dim BlockScope As Long = AppendSemanticScope(Scopes, ScopeCount, ScopeCapacity, SemanticScopeBlock(), EnclosingScope, EnclosingOwner, SyntaxNodes(NodeIndex).SourceId, NodeIndex)
                Call MarkScopeTree(NodeIndex, BlockScope, EnclosingOwner, NodeScopes, NodeOwners, SyntaxNodes, SyntaxLinks)
            End If
        End If
        Dim SymbolKind As Long = 0
        Dim CreatesMemberScope As Long = 0
        Dim CreatesProcedureScope As Long = 0
        Dim AllowPropertyPeer As Long = 0
        If EqualsFolded(RuleName, "const-item") <> 0 Then
            SymbolKind = SemanticSymbolConstant()
        End If
        If EqualsFolded(RuleName, "variable-item") <> 0 Then
            SymbolKind = SemanticSymbolVariable()
        End If
        If EqualsFolded(RuleName, "type-declaration") <> 0 Then
            SymbolKind = SemanticSymbolType()
            CreatesMemberScope = 1
        End If
        If EqualsFolded(RuleName, "enum-declaration") <> 0 Then
            SymbolKind = SemanticSymbolEnum()
            CreatesMemberScope = 1
        End If
        If EqualsFolded(RuleName, "enum-member") <> 0 Then
            SymbolKind = SemanticSymbolMember()
        End If
        If EqualsFolded(RuleName, "type-field") <> 0 Then
            SymbolKind = SemanticSymbolMember()
        End If
        If EqualsFolded(RuleName, "event-declaration") <> 0 Then
            SymbolKind = SemanticSymbolEvent()
        End If
        If EqualsFolded(RuleName, "interface-declaration") <> 0 Then
            SymbolKind = SemanticSymbolInterface()
            CreatesMemberScope = 1
        End If
        If EqualsFolded(RuleName, "sub-function-declaration") <> 0 Then
            SymbolKind = SemanticSymbolProcedure()
            CreatesProcedureScope = 1
        End If
        If EqualsFolded(RuleName, "intrinsic-declaration") <> 0 Then
            SymbolKind = SemanticSymbolProcedure()
            CreatesProcedureScope = 1
        End If
        If EqualsFolded(RuleName, "external-declaration") <> 0 Then
            SymbolKind = SemanticSymbolProcedure()
            CreatesProcedureScope = 1
        End If
        If EqualsFolded(RuleName, "property-declaration") <> 0 Then
            SymbolKind = SemanticSymbolProperty()
            CreatesProcedureScope = 1
            AllowPropertyPeer = 1
        End If
        If SymbolKind <> 0 Then
            Dim NameNode As Long = DeclarationNameNode(NodeIndex, SyntaxNodes, SyntaxLinks, Rules)
            Dim DeclaredName As String = SyntaxNodeTokenText(NameNode, SyntaxNodes, Tokens)
            Dim ParentScope As Long = NearestSemanticScope(SyntaxNodes(NodeIndex).ParentNode, NodeScopes, SyntaxNodes)
            Dim ParentOwner As Long = NearestProcedureSymbol(SyntaxNodes(NodeIndex).ParentNode, NodeOwners, SyntaxNodes)
            If StringLength(DeclaredName) > 0 And ParentScope >= 0 Then
                Dim AddedSymbol As Long = AddCheckedSemanticSymbol(SymbolKind, DeclaredName, ParentScope, ParentOwner, NodeIndex, AllowPropertyPeer, Sources, SyntaxNodes, Tokens, Symbols, SymbolCount, SymbolCapacity, Scopes, Links, LinkCount, LinkCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                If AddedSymbol >= 0 Then
                    If SymbolKind = SemanticSymbolType() Or SymbolKind = SemanticSymbolEnum() Or SymbolKind = SemanticSymbolInterface() Then
                        Dim NewType As Long = AppendSemanticType(Types, TypeCount, TypeCapacity, SymbolKind + 20, DeclaredName, AddedSymbol, -1, 0, 0)
                        Symbols(AddedSymbol).DeclaredType = NewType
                    End If
                    If CreatesMemberScope <> 0 Then
                        Dim MemberScope As Long = AppendSemanticScope(Scopes, ScopeCount, ScopeCapacity, SemanticScopeMember(), ParentScope, AddedSymbol, SyntaxNodes(NodeIndex).SourceId, NodeIndex)
                        Symbols(AddedSymbol).RelatedSymbol = MemberScope
                        Call MarkScopeTree(NodeIndex, MemberScope, AddedSymbol, NodeScopes, NodeOwners, SyntaxNodes, SyntaxLinks)
                    End If
                    If CreatesProcedureScope <> 0 Then
                        Dim ProcedureScope As Long = AppendSemanticScope(Scopes, ScopeCount, ScopeCapacity, SemanticScopeProcedure(), ParentScope, AddedSymbol, SyntaxNodes(NodeIndex).SourceId, NodeIndex)
                        Symbols(AddedSymbol).RelatedSymbol = ProcedureScope
                        Symbols(AddedSymbol).SecondaryScope = AppendSemanticScope(Scopes, ScopeCount, ScopeCapacity, SemanticScopeLabels(), ProcedureScope, AddedSymbol, SyntaxNodes(NodeIndex).SourceId, NodeIndex)
                        Call MarkScopeTree(NodeIndex, ProcedureScope, AddedSymbol, NodeScopes, NodeOwners, SyntaxNodes, SyntaxLinks)
                        If EqualsFolded(DeclaredName, "Main") <> 0 Then
                            State.EntryCount = State.EntryCount + 1
                            State.EntrySymbol = AddedSymbol
                        End If
                    End If
                End If
            End If
        End If
        NodeIndex = NodeIndex + 1
    Wend

    NodeIndex = 0
    While NodeIndex < SyntaxNodeCount
        Dim CurrentRule As String = Rules(SyntaxNodes(NodeIndex).ProductionRule).RuleName
        If EqualsFolded(CurrentRule, "parameter") <> 0 Then
            Dim ParameterNameNode As Long = DeclarationNameNode(NodeIndex, SyntaxNodes, SyntaxLinks, Rules)
            Dim ParameterName As String = SyntaxNodeTokenText(ParameterNameNode, SyntaxNodes, Tokens)
            Dim ParameterScope As Long = NearestSemanticScope(NodeIndex, NodeScopes, SyntaxNodes)
            Dim ParameterOwner As Long = NearestProcedureSymbol(NodeIndex, NodeOwners, SyntaxNodes)
            If StringLength(ParameterName) > 0 And ParameterScope >= 0 Then
                Dim AddedParameter As Long = AddCheckedSemanticSymbol(SemanticSymbolParameter(), ParameterName, ParameterScope, ParameterOwner, NodeIndex, 0, Sources, SyntaxNodes, Tokens, Symbols, SymbolCount, SymbolCapacity, Scopes, Links, LinkCount, LinkCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                If AddedParameter >= 0 Then
                    Dim ParameterNumber As Long = 0
                    Dim EarlierSymbol As Long = 0
                    While EarlierSymbol < AddedParameter
                        If Symbols(EarlierSymbol).SymbolKind = SemanticSymbolParameter() And Symbols(EarlierSymbol).ParentSymbol = ParameterOwner Then
                            ParameterNumber = ParameterNumber + 1
                        End If
                        EarlierSymbol = EarlierSymbol + 1
                    Wend
                    Symbols(AddedParameter).ParameterOrdinal = ParameterNumber
                    If SyntaxNodeContainsToken(NodeIndex, "Optional", SyntaxNodes, Tokens) <> 0 Then
                        Symbols(AddedParameter).Flags = Symbols(AddedParameter).Flags + 1
                    End If
                    If SyntaxNodeContainsToken(NodeIndex, "ByVal", SyntaxNodes, Tokens) <> 0 Then
                        Symbols(AddedParameter).Flags = Symbols(AddedParameter).Flags + 2
                    End If
                    If SyntaxNodeContainsToken(NodeIndex, "ByRef", SyntaxNodes, Tokens) <> 0 Then
                        Symbols(AddedParameter).Flags = Symbols(AddedParameter).Flags + 4
                    End If
                    If SyntaxNodeContainsToken(NodeIndex, "ParamArray", SyntaxNodes, Tokens) <> 0 Then
                        Symbols(AddedParameter).Flags = Symbols(AddedParameter).Flags + 8
                    End If
                End If
            End If
        End If
        If EqualsFolded(CurrentRule, "label-declaration") <> 0 Then
            Dim LabelName As String = SyntaxIdentifierName(NodeIndex, SyntaxNodes, SyntaxLinks, Rules, Tokens)
            Dim LabelOwner As Long = NearestProcedureSymbol(NodeIndex, NodeOwners, SyntaxNodes)
            Dim LabelParent As Long = -1
            If LabelOwner >= 0 Then
                LabelParent = Symbols(LabelOwner).SecondaryScope
            End If
            If StringLength(LabelName) > 0 And LabelParent >= 0 Then
                Call AddCheckedSemanticSymbol(SemanticSymbolLabel(), LabelName, LabelParent, LabelOwner, NodeIndex, 0, Sources, SyntaxNodes, Tokens, Symbols, SymbolCount, SymbolCapacity, Scopes, Links, LinkCount, LinkCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity)
            End If
        End If
        If EqualsFolded(CurrentRule, "legacy-def-type-statement") <> 0 Then
            Call AddSemanticDiagnostic("UBE4010", NodeIndex, "legacy Def type directives are not supported; write an explicit As type", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        End If
        If EqualsFolded(CurrentRule, "inline-assembly-statement") <> 0 Or EqualsFolded(CurrentRule, "bytecode-statement") <> 0 Then
            Call AddSemanticDiagnostic("UBE4030", NodeIndex, "unsafe source requires an explicitly enabled unsafe build context", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        End If
        NodeIndex = NodeIndex + 1
    Wend

    Call ResolveSymbolTypes(Sources, SyntaxNodes, SyntaxLinks, Rules, Tokens, Types, TypeCount, TypeCapacity, Symbols, SymbolCount, Diagnostics, DiagnosticCount, DiagnosticCapacity)
    Call AnalyzeExpressions(Sources, SyntaxNodes, SyntaxNodeCount, SyntaxLinks, Rules, Tokens, Types, TypeCount, Symbols, SymbolCount, State, Diagnostics, DiagnosticCount, DiagnosticCapacity)
    Call ValidateSemanticContracts(Project, Sources, SyntaxNodes, SyntaxNodeCount, SyntaxLinks, Rules, Tokens, Types, TypeCount, Symbols, SymbolCount, State, Diagnostics, DiagnosticCount, DiagnosticCapacity)

    If EqualsFolded(Project.Kind, "Exe") <> 0 Then
        If State.EntryCount = 0 Then
            Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE4002", Project.ManifestPath, 1, 1, "executable project requires exactly one module-level Main")
        Else
            If State.EntryCount > 1 Then
                Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE4003", Project.ManifestPath, 1, 1, "executable project has more than one module-level Main")
            End If
        End If
    Else
        If State.EntryCount <> 0 Then
            Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE4004", Project.ManifestPath, 1, 1, "library projects cannot declare Main")
        End If
    End If
    If DiagnosticCount <> 0 Then
        State.HasErrors = 1
    End If
    AnalyzeSemantics = 1
End Function
