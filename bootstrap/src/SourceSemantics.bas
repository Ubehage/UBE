Attribute VB_Name = "SourceSemantics"
Option Explicit

' Declaration identities and checked scalar facts are owned by one bound project.
Public Const MaximumBoundSymbols As Long = 16384
Public Const MaximumBindingDepth As Long = 128
Public Const MaximumArrayElements As Long = 4096
Public Const MaximumRecordCells As Long = 128
Private Const MaximumRecordDepth As Long = 64
Private Const SymbolBucketCount As Long = 65521
Private Const MaximumLookupWork As Long = 4000000

Public Type BoundSymbol
    Kind As String
    Name As String
    TypeName As String
    Visibility As String
    PassingMode As String
    BindingId As String
    Origin As String
    ModuleIndex As Long
    ScopeSymbol As Long
    DeclarationNode As Long
    FirstParameter As Long
    NextParameter As Long
    ParameterCount As Long
    ConstantKnown As Boolean
    ConstantValue As Variant
    TypeSymbol As Long
    ArrayRank As Long
    HasBounds As Boolean
    LowerBound As Variant
    UpperBound As Variant
    ElementCells As Long
    StorageCells As Long
    FieldOffset As Long
    FirstField As Long
    NextField As Long
End Type

Public Type BoundNode
    SymbolIndex As Long
    ScopeSymbol As Long
    TypeName As String
    ConvertedType As String
    ArgumentMode As String
    Writable As Boolean
    ConstantKnown As Boolean
    ConstantValue As Variant
    TypeSymbol As Long
    ArrayRank As Long
    HasBounds As Boolean
    LowerBound As Variant
    UpperBound As Variant
    ElementCells As Long
    StorageCells As Long
    AccessKind As String
End Type

Public Type BoundProject
    SymbolCount As Long
    Symbols() As BoundSymbol
    NodeCount As Long
    Nodes() As BoundNode
    EntrySymbol As Long
    PackageSymbol As Long
    ModuleSymbols() As Long
    ArrayBoundsMayChange As Boolean
End Type

Private Type BindingState
    Buckets() As Long
    NextSymbol() As Long
    Regions() As String
    ConstantState() As Long
    TypeState() As Long
    Depth As Long
    LookupWork As Long
    ErrorReceiver As Long
    ProjectName As String
End Type

' Reports the first semantic diagnostic at a retained source span.
Private Function BindingError(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByVal Node As Long, ByRef Diagnostic As String, ByVal Code As String, ByVal Detail As String) As Boolean
    Dim ModuleIndex As Long
    If Node > 0 Then
        ModuleIndex = Parsed.Nodes(Node).ModuleIndex
        If ModuleIndex >= 0 Then
            Diagnostic = "UBE: " & Code & ": " & Project.Sources(ModuleIndex).FilePath & ":" & CStr(Parsed.Nodes(Node).Line) & ":" & CStr(Parsed.Nodes(Node).Column) & " " & Detail
            Exit Function
        End If
    End If
    Diagnostic = "UBE: " & Code & ": " & Project.ManifestPath & ":1:1 " & Detail
End Function

' Computes a bounded ordinal ASCII hash for a declaration region and folded name.
Private Function SymbolHash(ByVal Scope As Long, ByVal Region As String, ByVal Name As String) As Long
    Dim Key As String
    Dim Index As Long
    Dim Hash As Long
    Key = CStr(Scope) & ":" & Region & ":" & FoldAscii(Name)
    For Index = 1 To Len(Key)
        Hash = (Hash * 31 + (AscW(Mid$(Key, Index, 1)) And &HFFFF&)) Mod SymbolBucketCount
    Next Index
    SymbolHash = Hash
End Function

' Searches one exact region; a fixed work budget also bounds adversarial collisions.
Private Function FindSymbol(ByRef Bound As BoundProject, ByRef State As BindingState, ByVal Scope As Long, ByVal Region As String, ByVal Name As String) As Long
    Dim Index As Long
    State.LookupWork = State.LookupWork + 1
    If State.LookupWork > MaximumLookupWork Then Exit Function
    Index = State.Buckets(SymbolHash(Scope, Region, Name))
    Do While Index <> 0
        State.LookupWork = State.LookupWork + 1
        If State.LookupWork > MaximumLookupWork Then Exit Function
        If Bound.Symbols(Index).ScopeSymbol = Scope And State.Regions(Index) = Region Then
            If FoldAscii(Bound.Symbols(Index).Name) = FoldAscii(Name) Then
                FindSymbol = Index
                Exit Function
            End If
        End If
        Index = State.NextSymbol(Index)
    Loop
End Function

' Allocates one immutable declaration identity and rejects duplicates in its own region.
Private Function DeclareSymbol(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As BindingState, ByVal Scope As Long, ByVal Region As String, ByVal Kind As String, ByVal Name As String, ByVal Node As Long, ByVal ModuleIndex As Long, ByRef Diagnostic As String) As Long
    Dim Existing As Long
    Dim Index As Long
    Dim Bucket As Long
    Existing = FindSymbol(Bound, State, Scope, Region, Name)
    If State.LookupWork > MaximumLookupWork Then
        Call BindingError(Project, Parsed, Node, Diagnostic, "E_LIMIT", "symbol lookup work limit exceeded")
        Exit Function
    End If
    If Existing <> 0 Then
        Call BindingError(Project, Parsed, Node, Diagnostic, "E_DUPLICATE", "duplicate declaration " & Name)
        Exit Function
    End If
    If Bound.SymbolCount >= MaximumBoundSymbols Then
        Call BindingError(Project, Parsed, Node, Diagnostic, "E_LIMIT", "symbol count limit exceeded")
        Exit Function
    End If
    Bound.SymbolCount = Bound.SymbolCount + 1
    Index = Bound.SymbolCount
    Bound.Symbols(Index).Kind = Kind
    Bound.Symbols(Index).Name = Name
    Bound.Symbols(Index).ScopeSymbol = Scope
    Bound.Symbols(Index).ModuleIndex = ModuleIndex
    Bound.Symbols(Index).DeclarationNode = Node
    Bound.Symbols(Index).Origin = "source"
    State.Regions(Index) = Region
    Bucket = SymbolHash(Scope, Region, Name)
    State.NextSymbol(Index) = State.Buckets(Bucket)
    State.Buckets(Bucket) = Index
    If Node > 0 Then Bound.Nodes(Node).SymbolIndex = Index
    DeclareSymbol = Index
End Function

' Adds the reviewed error-support declarations with trusted identities, not source-name magic.
Private Function DeclareErrorSupport(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As BindingState, ByRef Diagnostic As String) As Boolean
    Dim Receiver As Long
    Dim Procedure As Long
    Dim Parameter As Long
    Dim Member As Long
    Receiver = DeclareSymbol(Project, Parsed, Bound, State, Bound.PackageSymbol, "support", "namespace", "Err", 0, -1, Diagnostic)
    If Receiver = 0 Then Exit Function
    State.ErrorReceiver = Receiver
    Bound.Symbols(Receiver).Origin = "trusted"
    Bound.Symbols(Receiver).BindingId = "error.object"
    Procedure = DeclareSymbol(Project, Parsed, Bound, State, Receiver, "value", "sub", "Raise", 0, -1, Diagnostic)
    If Procedure = 0 Then Exit Function
    Bound.Symbols(Procedure).Origin = "trusted"
    Bound.Symbols(Procedure).BindingId = "error.raise"
    Bound.Symbols(Procedure).Visibility = "public"
    Parameter = DeclareSymbol(Project, Parsed, Bound, State, Procedure, "value", "parameter", "Number", 0, -1, Diagnostic)
    If Parameter = 0 Then Exit Function
    Bound.Symbols(Parameter).Origin = "trusted"
    Bound.Symbols(Parameter).TypeName = "Long"
    Bound.Symbols(Parameter).PassingMode = "ByVal"
    Bound.Symbols(Procedure).FirstParameter = Parameter
    Bound.Symbols(Procedure).ParameterCount = 1
    Member = DeclareSymbol(Project, Parsed, Bound, State, Receiver, "value", "sub", "Clear", 0, -1, Diagnostic)
    If Member = 0 Then Exit Function
    Bound.Symbols(Member).Origin = "trusted"
    Bound.Symbols(Member).Visibility = "public"
    Bound.Symbols(Member).BindingId = "error.clear"
    Member = DeclareSymbol(Project, Parsed, Bound, State, Receiver, "value", "property", "Number", 0, -1, Diagnostic)
    If Member = 0 Then Exit Function
    Bound.Symbols(Member).Origin = "trusted"
    Bound.Symbols(Member).Visibility = "public"
    Bound.Symbols(Member).BindingId = "error.number"
    Bound.Symbols(Member).TypeName = "Long"
    DeclareErrorSupport = True
End Function

' Retains declaration type and visibility, diagnosing modifier combinations outside the contract.
Private Function DeclarationFacts(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByVal Symbol As Long, ByVal IsLocal As Boolean, ByRef Diagnostic As String) As Boolean
    Dim Node As Long
    Dim Visibility As String
    Dim Kind As String
    Node = Bound.Symbols(Symbol).DeclarationNode
    Kind = Bound.Symbols(Symbol).Kind
    Visibility = Parsed.Nodes(Node).Modifiers
    Bound.Symbols(Symbol).TypeName = Parsed.Nodes(Node).TypeName
    If IsLocal Then
        Visibility = "local"
    ElseIf Visibility = "global" Then
        If Kind <> "variable" Then
            DeclarationFacts = BindingError(Project, Parsed, Node, Diagnostic, "E_TYPE", "Global is valid only for a module variable")
            Exit Function
        End If
        Visibility = "public"
    ElseIf Len(Visibility) = 0 Then
        If Kind = "function" Or Kind = "sub" Or Kind = "type" Then Visibility = "public" Else Visibility = "private"
    End If
    Bound.Symbols(Symbol).Visibility = Visibility
    Bound.Nodes(Node).TypeName = Bound.Symbols(Symbol).TypeName
    DeclarationFacts = True
End Function

' Assigns lexical procedure/module scopes iteratively, independent of AST allocation order.
Private Sub AssignScopes(ByRef Parsed As ParsedProject, ByRef Bound As BoundProject)
    Dim Stack() As Long
    Dim Count As Long
    Dim Node As Long
    Dim Child As Long
    Dim Scope As Long
    ReDim Stack(1 To Parsed.NodeCount)
    Count = 1
    Stack(Count) = Parsed.RootNode
    Bound.Nodes(Parsed.RootNode).ScopeSymbol = Bound.PackageSymbol
    Do While Count > 0
        Node = Stack(Count)
        Count = Count - 1
        Scope = Bound.Nodes(Node).ScopeSymbol
        If Parsed.Nodes(Node).Kind = "module" Or Parsed.Nodes(Node).Kind = "sub" Or Parsed.Nodes(Node).Kind = "function" Or Parsed.Nodes(Node).Kind = "type" Then Scope = Bound.Nodes(Node).SymbolIndex
        Child = Parsed.Nodes(Node).FirstChild
        Do While Child <> 0
            Bound.Nodes(Child).ScopeSymbol = Scope
            Count = Count + 1
            Stack(Count) = Child
            Child = Parsed.Nodes(Child).NextSibling
        Loop
    Loop
End Sub

' Canonicalizes numeric labels without imposing an integer storage width.
Private Function CanonicalLabel(ByVal Name As String) As String
    Dim Index As Long
    Dim IsNumber As Boolean
    IsNumber = (Len(Name) > 0)
    For Index = 1 To Len(Name)
        If Mid$(Name, Index, 1) < "0" Or Mid$(Name, Index, 1) > "9" Then IsNumber = False
    Next Index
    If IsNumber Then
        Do While Len(Name) > 1
            If Left$(Name, 1) <> "0" Then Exit Do
            Name = Mid$(Name, 2)
        Loop
    End If
    CanonicalLabel = Name
End Function

' Collects package/module/member identities before resolving any uses.
Private Function CollectDeclarations(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As BindingState, ByRef Diagnostic As String) As Boolean
    Dim ModuleIndex As Long
    Dim ModuleNode As Long
    Dim Node As Long
    Dim Child As Long
    Dim Symbol As Long
    Dim Scope As Long
    Dim Result As Long
    Dim PreviousParameter As Long
    Dim Kind As String
    Dim Name As String
    Bound.PackageSymbol = DeclareSymbol(Project, Parsed, Bound, State, 0, "package", "package", Project.ProjectName, Parsed.RootNode, -1, Diagnostic)
    If Bound.PackageSymbol = 0 Then Exit Function
    For ModuleIndex = 0 To Parsed.ModuleCount - 1
        ModuleNode = Parsed.Modules(ModuleIndex).RootNode
        Symbol = DeclareSymbol(Project, Parsed, Bound, State, Bound.PackageSymbol, "module", "module", Parsed.Modules(ModuleIndex).ModuleName, ModuleNode, ModuleIndex, Diagnostic)
        If Symbol = 0 Then Exit Function
        Bound.ModuleSymbols(ModuleIndex) = Symbol
    Next ModuleIndex
    If Not DeclareErrorSupport(Project, Parsed, Bound, State, Diagnostic) Then Exit Function
    For ModuleIndex = 0 To Parsed.ModuleCount - 1
        Node = Parsed.Nodes(Parsed.Modules(ModuleIndex).RootNode).FirstChild
        Do While Node <> 0
            Kind = Parsed.Nodes(Node).Kind
            If Kind = "sub" Or Kind = "function" Or Kind = "variable" Or Kind = "constant" Or Kind = "type" Then
                Symbol = DeclareSymbol(Project, Parsed, Bound, State, Bound.ModuleSymbols(ModuleIndex), "value", Kind, Parsed.Nodes(Node).Text, Node, ModuleIndex, Diagnostic)
                If Symbol = 0 Then Exit Function
                If Not DeclarationFacts(Project, Parsed, Bound, Symbol, False, Diagnostic) Then Exit Function
            End If
            Node = Parsed.Nodes(Node).NextSibling
        Loop
    Next ModuleIndex
    Call AssignScopes(Parsed, Bound)
    For Node = 1 To Parsed.NodeCount
        Kind = Parsed.Nodes(Node).Kind
        ModuleIndex = Parsed.Nodes(Node).ModuleIndex
        Scope = Bound.Nodes(Node).ScopeSymbol
        If Kind = "sub" Or Kind = "function" Then
            Symbol = Bound.Nodes(Node).SymbolIndex
            If Kind = "function" Then
                Result = DeclareSymbol(Project, Parsed, Bound, State, Symbol, "result", "result", Parsed.Nodes(Node).Text, 0, ModuleIndex, Diagnostic)
                If Result = 0 Then Exit Function
                Bound.Symbols(Result).TypeName = Parsed.Nodes(Node).TypeName
                Bound.Symbols(Result).Visibility = "local"
                Bound.Symbols(Result).DeclarationNode = Node
            End If
            PreviousParameter = 0
            Child = Parsed.Nodes(Node).FirstChild
            Do While Child <> 0
                If Parsed.Nodes(Child).Kind = "parameter" Then
                    Result = DeclareSymbol(Project, Parsed, Bound, State, Symbol, "value", "parameter", Parsed.Nodes(Child).Text, Child, ModuleIndex, Diagnostic)
                    If Result = 0 Then Exit Function
                    Bound.Symbols(Result).TypeName = Parsed.Nodes(Child).TypeName
                    Bound.Symbols(Result).PassingMode = Parsed.Nodes(Child).Modifiers
                    Bound.Symbols(Result).Visibility = "local"
                    Bound.Nodes(Child).TypeName = Parsed.Nodes(Child).TypeName
                    If PreviousParameter = 0 Then Bound.Symbols(Symbol).FirstParameter = Result Else Bound.Symbols(PreviousParameter).NextParameter = Result
                    Bound.Symbols(Symbol).ParameterCount = Bound.Symbols(Symbol).ParameterCount + 1
                    PreviousParameter = Result
                End If
                Child = Parsed.Nodes(Child).NextSibling
            Loop
        ElseIf Kind = "variable" Or Kind = "constant" Then
            If Bound.Nodes(Node).SymbolIndex = 0 Then
                Symbol = DeclareSymbol(Project, Parsed, Bound, State, Scope, "value", Kind, Parsed.Nodes(Node).Text, Node, ModuleIndex, Diagnostic)
                If Symbol = 0 Then Exit Function
                If Not DeclarationFacts(Project, Parsed, Bound, Symbol, True, Diagnostic) Then Exit Function
            End If
        ElseIf Kind = "label" Then
            Name = CanonicalLabel(Parsed.Nodes(Node).Text)
            Symbol = DeclareSymbol(Project, Parsed, Bound, State, Scope, "label", "label", Name, Node, ModuleIndex, Diagnostic)
            If Symbol = 0 Then Exit Function
            Bound.Symbols(Symbol).Visibility = "local"
        End If
    Next Node
    CollectDeclarations = True
End Function

' Selects ordinary lexical declarations first and only then the trusted support receiver.
Private Function LookupName(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As BindingState, ByVal Node As Long, ByVal Assignment As Boolean, ByRef Diagnostic As String) As Long
    Dim Scope As Long
    Dim ModuleIndex As Long
    Dim Index As Long
    Dim Candidate As Long
    Dim Selected As Long
    Dim Name As String
    Name = Parsed.Nodes(Node).Text
    Scope = Bound.Nodes(Node).ScopeSymbol
    ModuleIndex = Parsed.Nodes(Node).ModuleIndex
    If Bound.Symbols(Scope).Kind = "sub" Or Bound.Symbols(Scope).Kind = "function" Then
        Selected = FindSymbol(Bound, State, Scope, "value", Name)
        If Selected <> 0 Then GoTo Found
        If Assignment Then
            Selected = FindSymbol(Bound, State, Scope, "result", Name)
            If Selected <> 0 Then GoTo Found
        End If
    End If
    Selected = FindSymbol(Bound, State, Bound.ModuleSymbols(ModuleIndex), "value", Name)
    If Selected <> 0 Then GoTo Found
    For Index = 0 To Parsed.ModuleCount - 1
        Candidate = FindSymbol(Bound, State, Bound.ModuleSymbols(Index), "value", Name)
        If Candidate <> 0 Then
            If Bound.Symbols(Candidate).Visibility = "public" Or Bound.Symbols(Candidate).Visibility = "friend" Then
                If Selected <> 0 Then
                    Call BindingError(Project, Parsed, Node, Diagnostic, "E_AMBIGUOUS", "ambiguous package declaration " & Name)
                    Exit Function
                End If
                Selected = Candidate
            End If
        End If
    Next Index
    If Selected <> 0 Then GoTo Found
    Selected = FindSymbol(Bound, State, Bound.PackageSymbol, "module", Name)
    If Selected <> 0 Then GoTo Found
    If FoldAscii(Name) = FoldAscii(Project.ProjectName) Then
        Selected = Bound.PackageSymbol
        GoTo Found
    End If
    Selected = FindSymbol(Bound, State, Bound.PackageSymbol, "support", Name)
Found:
    If State.LookupWork > MaximumLookupWork Then
        Call BindingError(Project, Parsed, Node, Diagnostic, "E_LIMIT", "symbol lookup work limit exceeded")
        Exit Function
    End If
    If Selected = 0 Then
        Call BindingError(Project, Parsed, Node, Diagnostic, "E_NAME", "undeclared name " & Name)
        Exit Function
    End If
    LookupName = Selected
End Function

' Resolves qualified receivers to declarations, enforcing visibility without fallback after selection.
Private Function ResolveReference(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As BindingState, ByVal Node As Long, ByVal Assignment As Boolean, ByRef Diagnostic As String) As Long
    Dim Symbol As Long
    Dim Receiver As Long
    Dim Kind As String
    Dim Root As Long
    Dim Candidate As Long
    Dim ReceiverNode As Long
    Dim FieldAccess As Boolean
    If Not EnterBinding(Project, Parsed, State, Node, Diagnostic) Then Exit Function
    Kind = Parsed.Nodes(Node).Kind
    If Kind = "name" Then
        Symbol = LookupName(Project, Parsed, Bound, State, Node, Assignment, Diagnostic)
        If Symbol = 0 Then Exit Function
    ElseIf Kind = "member" Then
        Root = Parsed.Nodes(Node).FirstChild
        If Parsed.Nodes(Root).Kind = "member" Then
            Root = Parsed.Nodes(Root).FirstChild
            If Parsed.Nodes(Root).Kind = "name" Then
                If FoldAscii(Parsed.Nodes(Root).Text) = FoldAscii(Project.ProjectName) Then
                    Candidate = LookupName(Project, Parsed, Bound, State, Root, False, Diagnostic)
                    If Candidate = 0 Then Exit Function
                    If Bound.Symbols(Candidate).Kind = "module" Then
                        Call BindingError(Project, Parsed, Node, Diagnostic, "E_UNSUPPORTED", "three-part package/module qualification with the same root name is not yet defined")
                        Exit Function
                    End If
                End If
            End If
        End If
        ReceiverNode = Parsed.Nodes(Node).FirstChild
        If Parsed.Nodes(ReceiverNode).Kind = "call" Or Parsed.Nodes(ReceiverNode).Kind = "group" Then
            If Not BindExpression(Project, Parsed, Bound, State, ReceiverNode, 0, Diagnostic) Then Exit Function
            Receiver = Bound.Nodes(ReceiverNode).SymbolIndex
        Else
            Receiver = ResolveReference(Project, Parsed, Bound, State, ReceiverNode, False, Diagnostic)
            If Receiver = 0 Then Exit Function
        End If
        Kind = ""
        If Receiver <> 0 Then Kind = Bound.Symbols(Receiver).Kind
        If Bound.Nodes(ReceiverNode).ArrayRank <> 0 Then
            Call BindingError(Project, Parsed, Node, Diagnostic, "E_TYPE", "array must be indexed before selecting an element field")
            Exit Function
        ElseIf Bound.Nodes(ReceiverNode).TypeSymbol <> 0 And Kind <> "type" Then
            Symbol = FindSymbol(Bound, State, Bound.Nodes(ReceiverNode).TypeSymbol, "value", Parsed.Nodes(Node).Text)
            FieldAccess = True
        ElseIf Kind = "package" Then
            Symbol = FindSymbol(Bound, State, Receiver, "module", Parsed.Nodes(Node).Text)
        ElseIf Kind = "module" Or Kind = "namespace" Then
            Symbol = FindSymbol(Bound, State, Receiver, "value", Parsed.Nodes(Node).Text)
        Else
            Call BindingError(Project, Parsed, Node, Diagnostic, "E_TYPE", "selected scalar declaration has no members")
            Exit Function
        End If
        If State.LookupWork > MaximumLookupWork Then
            Call BindingError(Project, Parsed, Node, Diagnostic, "E_LIMIT", "symbol lookup work limit exceeded")
            Exit Function
        End If
        If Symbol = 0 Then
            Call BindingError(Project, Parsed, Node, Diagnostic, "E_NAME", "member not found on selected declaration: " & Parsed.Nodes(Node).Text)
            Exit Function
        End If
        If Bound.Symbols(Symbol).Visibility = "private" Then
            If Bound.Symbols(Symbol).ModuleIndex <> Parsed.Nodes(Node).ModuleIndex Then
                Call BindingError(Project, Parsed, Node, Diagnostic, "E_NAME", "Private member is not accessible")
                Exit Function
            End If
        End If
    Else
        Call BindingError(Project, Parsed, Node, Diagnostic, "E_TYPE", "expected a declaration reference")
        Exit Function
    End If
    Bound.Nodes(Node).SymbolIndex = Symbol
    If Len(Parsed.Nodes(Node).TypeName) > 0 Then
        If Bound.Symbols(Symbol).ArrayRank <> 0 Or Bound.Symbols(Symbol).TypeSymbol <> 0 Then
            Call BindingError(Project, Parsed, Node, Diagnostic, "E_TYPE", "identifier suffixes cannot annotate aggregate values")
            Exit Function
        End If
        If Parsed.Nodes(Node).TypeName <> Bound.Symbols(Symbol).TypeName Then
            Call BindingError(Project, Parsed, Node, Diagnostic, "E_TYPE", "identifier suffix must agree with the selected declaration type")
            Exit Function
        End If
    End If
    Call SymbolValue(Bound, Node, Symbol)
    Kind = Bound.Symbols(Symbol).Kind
    Bound.Nodes(Node).Writable = (Kind = "variable" Or Kind = "parameter" Or Kind = "result")
    If FieldAccess Then
        Bound.Nodes(Node).AccessKind = "field"
        Bound.Nodes(Node).Writable = Bound.Nodes(ReceiverNode).Writable
    End If
    State.Depth = State.Depth - 1
    ResolveReference = Symbol
End Function

' Guards semantic AST recursion independently of the parser's syntactic depth bound.
Private Function EnterBinding(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef State As BindingState, ByVal Node As Long, ByRef Diagnostic As String) As Boolean
    If State.Depth >= MaximumBindingDepth Then
        EnterBinding = BindingError(Project, Parsed, Node, Diagnostic, "E_LIMIT", "semantic expression depth limit exceeded")
        Exit Function
    End If
    State.Depth = State.Depth + 1
    EnterBinding = True
End Function

' Copies value facts only, preserving each node's own declaration and lexical identity.
Private Sub CopyValue(ByRef Bound As BoundProject, ByVal Destination As Long, ByVal Source As Long)
    Bound.Nodes(Destination).TypeName = Bound.Nodes(Source).TypeName
    Bound.Nodes(Destination).ConstantKnown = Bound.Nodes(Source).ConstantKnown
    If Bound.Nodes(Source).ConstantKnown Then Bound.Nodes(Destination).ConstantValue = Bound.Nodes(Source).ConstantValue
    Bound.Nodes(Destination).TypeSymbol = Bound.Nodes(Source).TypeSymbol
    Bound.Nodes(Destination).ArrayRank = Bound.Nodes(Source).ArrayRank
    Bound.Nodes(Destination).HasBounds = Bound.Nodes(Source).HasBounds
    Bound.Nodes(Destination).LowerBound = Bound.Nodes(Source).LowerBound
    Bound.Nodes(Destination).UpperBound = Bound.Nodes(Source).UpperBound
    Bound.Nodes(Destination).ElementCells = Bound.Nodes(Source).ElementCells
    Bound.Nodes(Destination).StorageCells = Bound.Nodes(Source).StorageCells
End Sub

' Copies nominal identity, rank and storage facts from a selected declaration.
Private Sub SymbolValue(ByRef Bound As BoundProject, ByVal Node As Long, ByVal Symbol As Long)
    With Bound.Nodes(Node)
        .TypeName = Bound.Symbols(Symbol).TypeName
        .TypeSymbol = Bound.Symbols(Symbol).TypeSymbol
        .ArrayRank = Bound.Symbols(Symbol).ArrayRank
        .HasBounds = Bound.Symbols(Symbol).HasBounds
        If .ArrayRank <> 0 And Bound.ArrayBoundsMayChange Then .HasBounds = False
        .LowerBound = Bound.Symbols(Symbol).LowerBound
        .UpperBound = Bound.Symbols(Symbol).UpperBound
        .ElementCells = Bound.Symbols(Symbol).ElementCells
        .StorageCells = Bound.Symbols(Symbol).StorageCells
    End With
End Sub

' Recognizes a retained aggregate value independently of its display type name.
Private Function AggregateValue(ByRef Bound As BoundProject, ByVal Node As Long) As Boolean
    AggregateValue = (Bound.Nodes(Node).TypeSymbol <> 0 Or Bound.Nodes(Node).ArrayRank <> 0)
End Function

' Decodes a bracketed type-reference component without confusing it with an intrinsic type token.
Private Function TypeComponent(ByVal Text As String) As String
    If Len(Text) >= 2 Then
        If Left$(Text, 1) = "[" And Right$(Text, 1) = "]" Then Text = Replace(Mid$(Text, 2, Len(Text) - 2), "]]", "]")
    End If
    TypeComponent = Text
End Function

' Returns the initializer following an optional declared array shape.
Public Function DeclarationValueNode(ByRef Parsed As ParsedProject, ByVal Node As Long) As Long
    Dim Child As Long
    Child = Parsed.Nodes(Node).FirstChild
    If Child <> 0 Then
        If Parsed.Nodes(Child).Kind = "array-shape" Then Child = Parsed.Nodes(Child).NextSibling
    End If
    DeclarationValueNode = Child
End Function

' Resolves a record type through module/package visibility without structural type equivalence.
Private Function ResolveType(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As BindingState, ByVal Node As Long, ByVal Name As String, ByRef Diagnostic As String) As Long
    Dim Parts() As String
    Dim ModuleSymbol As Long
    Dim Symbol As Long
    Dim Candidate As Long
    Dim Index As Long
    Dim ModuleIndex As Long
    Parts = Split(Name, ".")
    For Index = 0 To UBound(Parts)
        Parts(Index) = TypeComponent(Parts(Index))
    Next Index
    ModuleIndex = Parsed.Nodes(Node).ModuleIndex
    If UBound(Parts) = 0 Then
        Symbol = FindSymbol(Bound, State, Bound.ModuleSymbols(ModuleIndex), "value", Parts(0))
        If Symbol = 0 Then
            For Index = 0 To Parsed.ModuleCount - 1
                Candidate = FindSymbol(Bound, State, Bound.ModuleSymbols(Index), "value", Parts(0))
                If Candidate <> 0 Then
                    If Bound.Symbols(Candidate).Visibility = "public" Or Bound.Symbols(Candidate).Visibility = "friend" Then
                        If Symbol <> 0 Then
                            Call BindingError(Project, Parsed, Node, Diagnostic, "E_AMBIGUOUS", "ambiguous type declaration " & Name)
                            Exit Function
                        End If
                        Symbol = Candidate
                    End If
                End If
            Next Index
        End If
    ElseIf UBound(Parts) = 1 Or UBound(Parts) = 2 Then
        Index = 0
        If UBound(Parts) = 2 Then
            If FoldAscii(Parts(0)) <> FoldAscii(Project.ProjectName) Then
                Call BindingError(Project, Parsed, Node, Diagnostic, "E_NAME", "unknown type package qualifier")
                Exit Function
            End If
            If FindSymbol(Bound, State, Bound.PackageSymbol, "module", Parts(0)) <> 0 Then
                Call BindingError(Project, Parsed, Node, Diagnostic, "E_UNSUPPORTED", "colliding package/module type qualifier is not yet defined")
                Exit Function
            End If
            Index = 1
        End If
        ModuleSymbol = FindSymbol(Bound, State, Bound.PackageSymbol, "module", Parts(Index))
        If ModuleSymbol <> 0 Then Symbol = FindSymbol(Bound, State, ModuleSymbol, "value", Parts(Index + 1))
    End If
    If Symbol = 0 Then
        Call BindingError(Project, Parsed, Node, Diagnostic, "E_NAME", "unknown record type " & Name)
        Exit Function
    End If
    If Bound.Symbols(Symbol).Kind <> "type" Then
        Call BindingError(Project, Parsed, Node, Diagnostic, "E_TYPE", "selected declaration is not a Type")
        Exit Function
    End If
    If Bound.Symbols(Symbol).Visibility = "private" And Bound.Symbols(Symbol).ModuleIndex <> ModuleIndex Then
        Call BindingError(Project, Parsed, Node, Diagnostic, "E_NAME", "Private Type is not accessible")
        Exit Function
    End If
    ResolveType = Symbol
End Function

' Computes bounded finite record layout and rejects recursive value edges explicitly.
Private Function LayoutRecord(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As BindingState, ByVal Symbol As Long, ByVal Depth As Long, ByRef Diagnostic As String) As Boolean
    Dim Field As Long
    Dim Cells As Long
    Dim Count As Long
    If State.TypeState(Symbol) = 2 Then
        LayoutRecord = True
        Exit Function
    End If
    If State.TypeState(Symbol) = 1 Then
        LayoutRecord = BindingError(Project, Parsed, Bound.Symbols(Symbol).DeclarationNode, Diagnostic, "E_UNSUPPORTED", "recursive Type storage is outside the finite-record profile")
        Exit Function
    End If
    If Depth >= MaximumRecordDepth Then
        LayoutRecord = BindingError(Project, Parsed, Bound.Symbols(Symbol).DeclarationNode, Diagnostic, "E_LIMIT", "record layout depth limit exceeded")
        Exit Function
    End If
    State.TypeState(Symbol) = 1
    Field = Bound.Symbols(Symbol).FirstField
    Do While Field <> 0
        Cells = 1
        If Bound.Symbols(Field).TypeSymbol <> 0 Then
            If Not LayoutRecord(Project, Parsed, Bound, State, Bound.Symbols(Field).TypeSymbol, Depth + 1, Diagnostic) Then Exit Function
            Cells = Bound.Symbols(Bound.Symbols(Field).TypeSymbol).StorageCells
        End If
        If Cells > MaximumRecordCells - Count Then
            LayoutRecord = BindingError(Project, Parsed, Bound.Symbols(Field).DeclarationNode, Diagnostic, "E_LIMIT", "finite record cell limit exceeded")
            Exit Function
        End If
        Bound.Symbols(Field).FieldOffset = Count
        Bound.Symbols(Field).ElementCells = Cells
        Bound.Symbols(Field).StorageCells = Cells
        Count = Count + Cells
        Field = Bound.Symbols(Field).NextField
    Loop
    If Count = 0 Then
        LayoutRecord = BindingError(Project, Parsed, Bound.Symbols(Symbol).DeclarationNode, Diagnostic, "E_TYPE", "Type must contain a field")
        Exit Function
    End If
    Bound.Symbols(Symbol).ElementCells = Count
    Bound.Symbols(Symbol).StorageCells = Count
    State.TypeState(Symbol) = 2
    LayoutRecord = True
End Function

' Checks fixed rank-one bounds exactly; ByRef array parameters retain their caller's shape.
Private Function BindArrayShape(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As BindingState, ByVal Symbol As Long, ByVal Shape As Long, ByRef Diagnostic As String) As Boolean
    Dim LowerNode As Long
    Dim UpperNode As Long
    Dim Count As Variant
    Bound.Symbols(Symbol).ArrayRank = 1
    If Parsed.Nodes(Shape).Text = "dynamic" Then
        If Bound.Symbols(Symbol).Kind = "parameter" And Bound.Symbols(Symbol).PassingMode = "ByRef" Then
            Bound.Symbols(Symbol).StorageCells = 0
            BindArrayShape = True
        ElseIf Bound.Symbols(Symbol).Kind = "variable" Then
            Bound.Symbols(Symbol).StorageCells = 4
            BindArrayShape = True
        Else
            BindArrayShape = BindingError(Project, Parsed, Shape, Diagnostic, "E_UNSUPPORTED", "dynamic arrays require owned variables or rank-only ByRef parameters")
        End If
        Exit Function
    End If
    LowerNode = Parsed.Nodes(Shape).FirstChild
    UpperNode = Parsed.Nodes(LowerNode).NextSibling
    If Not BindExpression(Project, Parsed, Bound, State, LowerNode, Symbol, Diagnostic, "LongLong") Then Exit Function
    If Not BindExpression(Project, Parsed, Bound, State, UpperNode, Symbol, Diagnostic, "LongLong") Then Exit Function
    If Not Bound.Nodes(LowerNode).ConstantKnown Or Not Bound.Nodes(UpperNode).ConstantKnown Then
        BindArrayShape = BindingError(Project, Parsed, Shape, Diagnostic, "E_CONSTANT", "fixed array bounds must be compile-time constants")
        Exit Function
    End If
    If Not ConvertValue(Project, Parsed, Bound, LowerNode, "LongLong", Diagnostic) Then Exit Function
    If Not ConvertValue(Project, Parsed, Bound, UpperNode, "LongLong", Diagnostic) Then Exit Function
    Bound.Symbols(Symbol).LowerBound = ConvertedConstant(Bound, LowerNode, "LongLong")
    Bound.Symbols(Symbol).UpperBound = ConvertedConstant(Bound, UpperNode, "LongLong")
    Count = Bound.Symbols(Symbol).UpperBound - Bound.Symbols(Symbol).LowerBound + CDec(1)
    If Count < CDec(1) Then
        BindArrayShape = BindingError(Project, Parsed, Shape, Diagnostic, "E_CONSTANT", "array upper bound is below its lower bound")
        Exit Function
    End If
    If Count > CDec(MaximumArrayElements) Then
        BindArrayShape = BindingError(Project, Parsed, Shape, Diagnostic, "E_LIMIT", "fixed array element limit exceeded")
        Exit Function
    End If
    Bound.Symbols(Symbol).HasBounds = True
    Bound.Symbols(Symbol).StorageCells = 4 + CLng(Count) * Bound.Symbols(Symbol).ElementCells
    BindArrayShape = True
End Function

' Recognizes the exact rank-only parameter shape required by intrinsic declarations.
Private Function IntrinsicArrayParameter(ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByVal Parameter As Long) As Boolean
    Dim Child As Long
    Child = Parsed.Nodes(Bound.Symbols(Parameter).DeclarationNode).FirstChild
    If Child = 0 Then Exit Function
    IntrinsicArrayParameter = (Parsed.Nodes(Child).Kind = "array-shape" And Parsed.Nodes(Child).Text = "dynamic")
End Function

' Describes exact host-operation parameters: A is ByRef Byte(), V is ByVal Long, R is ByRef Long.
Private Function HostPrimitiveSignature(ByVal Role As String) As String
    Select Case Role
    Case "file.tryopen": HostPrimitiveSignature = "AVRRR"
    Case "file.trycreatenew": HostPrimitiveSignature = "ARR"
    Case "file.tryread", "file.trywrite": HostPrimitiveSignature = "VAVVRR"
    Case "file.tryclose": HostPrimitiveSignature = "RR"
    Case "file.tryflush": HostPrimitiveSignature = "VR"
    Case "error.set": HostPrimitiveSignature = "V"
    End Select
End Function

' Checks host-operation scalar outputs and counted-byte arrays without admitting shape/type substitutions.
Private Function HostPrimitiveParameter(ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByVal Parameter As Long, ByVal Expected As String) As Boolean
    Dim Child As Long
    If Expected = "A" Then
        HostPrimitiveParameter = IntrinsicArrayParameter(Parsed, Bound, Parameter) And Bound.Symbols(Parameter).TypeName = "Byte" And Bound.Symbols(Parameter).PassingMode = "ByRef"
        Exit Function
    End If
    Child = Parsed.Nodes(Bound.Symbols(Parameter).DeclarationNode).FirstChild
    If Child <> 0 Then
        If Parsed.Nodes(Child).Kind = "array-shape" Then Exit Function
    End If
    If Bound.Symbols(Parameter).TypeName <> "Long" Then Exit Function
    If Expected = "V" Then
        HostPrimitiveParameter = (Bound.Symbols(Parameter).PassingMode = "ByVal")
    ElseIf Expected = "R" Then
        HostPrimitiveParameter = (Bound.Symbols(Parameter).PassingMode = "ByRef")
    End If
End Function

' Validates only explicitly attributed intrinsic declarations; ordinary names carry no authority.
Private Function ValidateIntrinsicDeclarations(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef Diagnostic As String) As Boolean
    Dim Symbol As Long
    Dim Node As Long
    Dim Child As Long
    Dim AttributeNode As Long
    Dim AttributeCount As Long
    Dim Parameter As Long
    Dim Position As Long
    Dim Role As String
    Dim HostSignature As String
    Dim Kind As String
    Dim ArrayParameter As Boolean
    Dim SignatureMatches As Boolean
    For Symbol = 1 To Bound.SymbolCount
        Kind = Bound.Symbols(Symbol).Kind
        If Bound.Symbols(Symbol).Origin = "source" And (Kind = "sub" Or Kind = "function") Then
            Node = Bound.Symbols(Symbol).DeclarationNode
            AttributeNode = 0
            AttributeCount = 0
            Child = Parsed.Nodes(Node).FirstChild
            Do While Child <> 0
                If Parsed.Nodes(Child).Kind = "primitive" Then
                    AttributeCount = AttributeCount + 1
                    AttributeNode = Child
                End If
                If Parsed.Nodes(Node).IsIntrinsic And Parsed.Nodes(Child).Kind = "body" Then
                    If Parsed.Nodes(Child).FirstChild <> 0 Then
                        ValidateIntrinsicDeclarations = BindingError(Project, Parsed, Child, Diagnostic, "E_TYPE", "Intrinsic declarations cannot contain an implemented source body")
                        Exit Function
                    End If
                End If
                Child = Parsed.Nodes(Child).NextSibling
            Loop
            If Not Parsed.Nodes(Node).IsIntrinsic Then
                If AttributeCount <> 0 Then
                    ValidateIntrinsicDeclarations = BindingError(Project, Parsed, AttributeNode, Diagnostic, "E_TYPE", "UBE_Primitive requires an Intrinsic declaration")
                    Exit Function
                End If
            Else
                If AttributeCount <> 1 Then
                    ValidateIntrinsicDeclarations = BindingError(Project, Parsed, Node, Diagnostic, "E_TYPE", "Intrinsic requires exactly one UBE_Primitive attribute")
                    Exit Function
                End If
                If FoldAscii(Parsed.Nodes(AttributeNode).TypeName) <> FoldAscii(Bound.Symbols(Symbol).Name) Then
                    ValidateIntrinsicDeclarations = BindingError(Project, Parsed, AttributeNode, Diagnostic, "E_TYPE", "UBE_Primitive target must match its containing declaration")
                    Exit Function
                End If
                Role = FoldAscii(Parsed.Nodes(AttributeNode).Text)
                HostSignature = HostPrimitiveSignature(Role)
                If Role <> "array.length" And Role <> "memory.copybytes" And Role <> "array.tryresize" And Role <> "array.trycopy" And Len(HostSignature) = 0 Then
                    ValidateIntrinsicDeclarations = BindingError(Project, Parsed, AttributeNode, Diagnostic, "E_UNSUPPORTED", "unknown or unsupported primitive role " & Parsed.Nodes(AttributeNode).Text)
                    Exit Function
                End If
                If Project.KindName = "exe" And FoldAscii(Bound.Symbols(Symbol).Name) = "main" Then
                    ValidateIntrinsicDeclarations = BindingError(Project, Parsed, Node, Diagnostic, "E_TYPE", "Main cannot be an Intrinsic declaration")
                    Exit Function
                End If
                SignatureMatches = (Kind = "function")
                If Len(HostSignature) > 0 Then
                    SignatureMatches = SignatureMatches And Bound.Symbols(Symbol).TypeName = "Boolean" And Bound.Symbols(Symbol).ParameterCount = Len(HostSignature)
                ElseIf Role = "array.length" Then
                    SignatureMatches = SignatureMatches And Bound.Symbols(Symbol).TypeName = "Long" And Bound.Symbols(Symbol).ParameterCount = 1
                ElseIf Role = "array.tryresize" Then
                    SignatureMatches = SignatureMatches And Bound.Symbols(Symbol).TypeName = "Boolean" And Bound.Symbols(Symbol).ParameterCount = 3
                ElseIf Role = "array.trycopy" Then
                    SignatureMatches = SignatureMatches And Bound.Symbols(Symbol).TypeName = "Boolean" And Bound.Symbols(Symbol).ParameterCount = 2
                Else
                    SignatureMatches = SignatureMatches And Bound.Symbols(Symbol).TypeName = "Boolean" And Bound.Symbols(Symbol).ParameterCount = 5
                End If
                Parameter = Bound.Symbols(Symbol).FirstParameter
                Position = 1
                Do While Parameter <> 0
                    ArrayParameter = IntrinsicArrayParameter(Parsed, Bound, Parameter)
                    If Len(HostSignature) > 0 Then
                        SignatureMatches = SignatureMatches And HostPrimitiveParameter(Parsed, Bound, Parameter, Mid$(HostSignature, Position, 1))
                    ElseIf Role = "array.length" Or Role = "array.trycopy" Or Position = 1 Or (Role = "memory.copybytes" And Position = 3) Then
                        SignatureMatches = SignatureMatches And ArrayParameter And Bound.Symbols(Parameter).PassingMode = "ByRef"
                        If Role = "memory.copybytes" Then SignatureMatches = SignatureMatches And Bound.Symbols(Parameter).TypeName = "Byte"
                    ElseIf Role = "array.tryresize" And Position = 3 Then
                        SignatureMatches = SignatureMatches And Not ArrayParameter And Bound.Symbols(Parameter).PassingMode = "ByVal" And Bound.Symbols(Parameter).TypeName = "Boolean"
                    Else
                        SignatureMatches = SignatureMatches And Not ArrayParameter And Bound.Symbols(Parameter).PassingMode = "ByVal" And Bound.Symbols(Parameter).TypeName = "Long"
                    End If
                    Parameter = Bound.Symbols(Parameter).NextParameter
                    Position = Position + 1
                Loop
                If Not SignatureMatches Then
                    ValidateIntrinsicDeclarations = BindingError(Project, Parsed, Node, Diagnostic, "E_TYPE", "declaration does not match the required " & Role & " signature")
                    Exit Function
                End If
                Bound.Symbols(Symbol).BindingId = Role
                If Role = "array.tryresize" Or Role = "array.trycopy" Then Bound.ArrayBoundsMayChange = True
            End If
        End If
    Next Symbol
    ValidateIntrinsicDeclarations = True
End Function

' Completes nominal types and declaration shapes before ordinary expression checking.
Private Function PrepareValueTypes(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As BindingState, ByRef Diagnostic As String) As Boolean
    Dim OriginalCount As Long
    Dim Symbol As Long
    Dim Field As Long
    Dim Previous As Long
    Dim Node As Long
    Dim Child As Long
    Dim Shape As Long
    Dim Kind As String
    Dim Name As String
    OriginalCount = Bound.SymbolCount
    For Symbol = 1 To OriginalCount
        If Bound.Symbols(Symbol).Kind = "type" Then
            Bound.Symbols(Symbol).TypeSymbol = Symbol
            Bound.Symbols(Symbol).TypeName = Parsed.Modules(Bound.Symbols(Symbol).ModuleIndex).ModuleName & "." & Bound.Symbols(Symbol).Name
            Child = Parsed.Nodes(Bound.Symbols(Symbol).DeclarationNode).FirstChild
            Previous = 0
            Do While Child <> 0
                Field = DeclareSymbol(Project, Parsed, Bound, State, Symbol, "value", "field", Parsed.Nodes(Child).Text, Child, Bound.Symbols(Symbol).ModuleIndex, Diagnostic)
                If Field = 0 Then Exit Function
                Bound.Symbols(Field).TypeName = Parsed.Nodes(Child).TypeName
                Bound.Symbols(Field).Visibility = "field"
                If Previous = 0 Then Bound.Symbols(Symbol).FirstField = Field Else Bound.Symbols(Previous).NextField = Field
                Previous = Field
                Shape = Parsed.Nodes(Child).FirstChild
                If Shape <> 0 Then
                    PrepareValueTypes = BindingError(Project, Parsed, Shape, Diagnostic, "E_UNSUPPORTED", "array fields are outside the finite scalar-record profile")
                    Exit Function
                End If
                Child = Parsed.Nodes(Child).NextSibling
            Loop
        End If
    Next Symbol
    For Symbol = 1 To Bound.SymbolCount
        Kind = Bound.Symbols(Symbol).Kind
        If Kind = "variable" Or Kind = "parameter" Or Kind = "constant" Or Kind = "field" Or Kind = "result" Or Kind = "function" Then
            Name = Bound.Symbols(Symbol).TypeName
            Node = Bound.Symbols(Symbol).DeclarationNode
            If Name <> "Boolean" And IntegerWidth(Name) = 0 Then
                If InStr("|String|Object|Variant|Date|Single|Double|Currency|Decimal|Any|IntPtr|UIntPtr|", "|" & Name & "|") > 0 Then
                    PrepareValueTypes = BindingError(Project, Parsed, Node, Diagnostic, "E_UNSUPPORTED", "datatype is outside the scalar/finite-record profile")
                    Exit Function
                End If
                Field = ResolveType(Project, Parsed, Bound, State, Node, Name, Diagnostic)
                If Field = 0 Then Exit Function
                Bound.Symbols(Symbol).TypeSymbol = Field
                Bound.Symbols(Symbol).TypeName = Bound.Symbols(Field).TypeName
            End If
        End If
    Next Symbol
    For Symbol = 1 To Bound.SymbolCount
        If Bound.Symbols(Symbol).Kind = "type" Then
            If Not LayoutRecord(Project, Parsed, Bound, State, Symbol, 0, Diagnostic) Then Exit Function
        End If
    Next Symbol
    For Symbol = 1 To Bound.SymbolCount
        Kind = Bound.Symbols(Symbol).Kind
        Node = Bound.Symbols(Symbol).DeclarationNode
        If Kind = "variable" Or Kind = "parameter" Or Kind = "constant" Or Kind = "field" Or Kind = "result" Or Kind = "function" Then
            Bound.Symbols(Symbol).ElementCells = 1
            If Bound.Symbols(Symbol).TypeSymbol <> 0 Then Bound.Symbols(Symbol).ElementCells = Bound.Symbols(Bound.Symbols(Symbol).TypeSymbol).StorageCells
            Bound.Symbols(Symbol).StorageCells = Bound.Symbols(Symbol).ElementCells
            If Node > 0 And Kind <> "result" Then
                Shape = Parsed.Nodes(Node).FirstChild
                If Shape <> 0 Then
                    If Parsed.Nodes(Shape).Kind = "array-shape" Then
                        If Not BindArrayShape(Project, Parsed, Bound, State, Symbol, Shape, Diagnostic) Then Exit Function
                    End If
                End If
            End If
            If Bound.Symbols(Symbol).TypeSymbol <> 0 Or Bound.Symbols(Symbol).ArrayRank <> 0 Then
                If Kind = "function" Or Kind = "result" Or Kind = "constant" Then
                    PrepareValueTypes = BindingError(Project, Parsed, Node, Diagnostic, "E_UNSUPPORTED", "aggregate results and Const declarations are outside this profile")
                    Exit Function
                End If
                If Kind = "parameter" And Bound.Symbols(Symbol).PassingMode <> "ByRef" Then
                    PrepareValueTypes = BindingError(Project, Parsed, Node, Diagnostic, "E_UNSUPPORTED", "aggregate ByVal parameters are outside this profile")
                    Exit Function
                End If
            End If
        End If
    Next Symbol
    For Node = 1 To Parsed.NodeCount
        Symbol = Bound.Nodes(Node).SymbolIndex
        If Symbol <> 0 Then Call SymbolValue(Bound, Node, Symbol)
    Next Node
    PrepareValueTypes = True
End Function

' Validates resolved primitive element identity and conservatively invalidates mutable shape facts.
Private Function PrepareArrayEffects(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As BindingState, ByRef Diagnostic As String) As Boolean
    Dim Symbol As Long
    Dim First As Long
    Dim Second As Long
    Dim Node As Long
    Dim Target As Long
    Dim Receiver As Long
    For Symbol = 1 To Bound.SymbolCount
        If Bound.Symbols(Symbol).BindingId = "array.trycopy" Then
            First = Bound.Symbols(Symbol).FirstParameter
            Second = Bound.Symbols(First).NextParameter
            If Bound.Symbols(First).TypeSymbol <> Bound.Symbols(Second).TypeSymbol Or Bound.Symbols(First).TypeName <> Bound.Symbols(Second).TypeName Then
                PrepareArrayEffects = BindingError(Project, Parsed, Bound.Symbols(Symbol).DeclarationNode, Diagnostic, "E_TYPE", "array.trycopy parameters require the same nominal element type")
                Exit Function
            End If
        End If
    Next Symbol
    If Not Bound.ArrayBoundsMayChange Then
        For Node = 1 To Parsed.NodeCount
            Target = 0
            If Parsed.Nodes(Node).Kind = "variable" Then
                Symbol = Bound.Nodes(Node).SymbolIndex
                If Symbol <> 0 Then
                    If Bound.Symbols(Symbol).ArrayRank <> 0 Then
                        If DeclarationValueNode(Parsed, Node) <> 0 Then Bound.ArrayBoundsMayChange = True
                    End If
                End If
            ElseIf Parsed.Nodes(Node).Kind = "assignment" Then
                Target = Parsed.Nodes(Node).FirstChild
                ' Whole arrays can only be names or qualified module members: array fields and nested arrays are not admitted.
                Receiver = Target
                Do While Parsed.Nodes(Receiver).Kind = "member"
                    Receiver = Parsed.Nodes(Receiver).FirstChild
                Loop
                If Parsed.Nodes(Receiver).Kind = "name" Then
                    Symbol = ResolveReference(Project, Parsed, Bound, State, Target, True, Diagnostic)
                    If Symbol = 0 Then Exit Function
                    If Bound.Symbols(Symbol).ArrayRank <> 0 Then Bound.ArrayBoundsMayChange = True
                End If
            End If
            If Bound.ArrayBoundsMayChange Then Exit For
        Next Node
    End If
    If Bound.ArrayBoundsMayChange Then
        For Node = 1 To Bound.NodeCount
            If Bound.Nodes(Node).ArrayRank <> 0 Then Bound.Nodes(Node).HasBounds = False
        Next Node
    End If
    PrepareArrayEffects = True
End Function

' Returns fixed integer width for the admitted storage and intermediate types.
Public Function IntegerWidth(ByVal TypeName As String) As Long
    Select Case TypeName
    Case "Byte": IntegerWidth = 8
    Case "Integer": IntegerWidth = 16
    Case "Long": IntegerWidth = 32
    Case "LongLong": IntegerWidth = 64
    End Select
End Function

' Supplies canonical exact lower bounds to semantic checking and native conversion guards.
Public Function IntegerMinimumText(ByVal TypeName As String) As String
    Select Case TypeName
    Case "Byte": IntegerMinimumText = "0"
    Case "Integer": IntegerMinimumText = "-32768"
    Case "Long": IntegerMinimumText = "-2147483648"
    Case "LongLong": IntegerMinimumText = "-9223372036854775808"
    End Select
End Function

' Supplies canonical exact upper bounds without a floating-point intermediary.
Public Function IntegerMaximumText(ByVal TypeName As String) As String
    Select Case TypeName
    Case "Byte": IntegerMaximumText = "255"
    Case "Integer": IntegerMaximumText = "32767"
    Case "Long": IntegerMaximumText = "2147483647"
    Case "LongLong": IntegerMaximumText = "9223372036854775807"
    End Select
End Function

' Classifies whether any value in the admitted source domain can fail conversion.
Public Function IntegerConversionMayFail(ByVal SourceType As String, ByVal DestinationType As String) As Boolean
    Dim Minimum As Variant
    Dim Maximum As Variant
    If DestinationType = "Boolean" Or SourceType = DestinationType Then Exit Function
    If IntegerWidth(DestinationType) = 0 Then Exit Function
    If SourceType = "Boolean" Then
        Minimum = CDec(-1)
        Maximum = CDec(0)
    ElseIf IntegerWidth(SourceType) > 0 Then
        Minimum = CDec(IntegerMinimumText(SourceType))
        Maximum = CDec(IntegerMaximumText(SourceType))
    Else
        IntegerConversionMayFail = True
        Exit Function
    End If
    IntegerConversionMayFail = (Minimum < CDec(IntegerMinimumText(DestinationType)) Or Maximum > CDec(IntegerMaximumText(DestinationType)))
End Function

' Tests exact integer ranges using Decimal variants, never floating intermediates.
Private Function FitsInteger(ByVal Value As Variant, ByVal TypeName As String) As Boolean
    If IntegerWidth(TypeName) = 0 Then Exit Function
    FitsInteger = (Value >= CDec(IntegerMinimumText(TypeName)) And Value <= CDec(IntegerMaximumText(TypeName)))
End Function

' Reads decimal literal magnitude exactly and applies a directly attached unary sign before range selection.
Private Function BindNumber(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByVal Node As Long, ByVal Negated As Boolean, ByRef Diagnostic As String, Optional ByVal DestinationType As String = "") As Boolean
    Dim Text As String
    Dim Index As Long
    Dim Digit As Long
    Dim Value As Variant
    Dim ExplicitType As String
    Dim TypeName As String
    Text = Parsed.Nodes(Node).Text
    If Left$(Text, 1) = "&" Then
        BindNumber = BindingError(Project, Parsed, Node, Diagnostic, "E_UNSUPPORTED", "hexadecimal and octal value interpretation is not admitted by this semantic profile")
        Exit Function
    End If
    Select Case Right$(Text, 1)
    Case "%": ExplicitType = "Integer"
    Case "&": ExplicitType = "Long"
    Case "^": ExplicitType = "LongLong"
    End Select
    If Len(ExplicitType) > 0 Then Text = Left$(Text, Len(Text) - 1)
    Value = CDec(0)
    For Index = 1 To Len(Text)
        Digit = AscW(Mid$(Text, Index, 1)) - 48
        If Digit < 0 Or Digit > 9 Then
            BindNumber = BindingError(Project, Parsed, Node, Diagnostic, "E_UNSUPPORTED", "expected decimal integer literal")
            Exit Function
        End If
        Value = Value * CDec(10) + CDec(Digit)
        If Value > CDec("9223372036854775808") Then
            BindNumber = BindingError(Project, Parsed, Node, Diagnostic, "E_CONSTANT", "integer literal exceeds signed 64-bit range")
            Exit Function
        End If
    Next Index
    If Negated Then Value = -Value
    TypeName = ExplicitType
    If Len(TypeName) = 0 Then
        TypeName = DestinationType
        If IntegerWidth(TypeName) = 0 Then TypeName = "Long"
        If Not FitsInteger(Value, TypeName) And TypeName = "Byte" Then TypeName = "Integer"
        If Not FitsInteger(Value, TypeName) And TypeName = "Integer" Then TypeName = "Long"
        If Not FitsInteger(Value, TypeName) And TypeName = "Long" Then TypeName = "LongLong"
    End If
    If Not FitsInteger(Value, TypeName) Then
        BindNumber = BindingError(Project, Parsed, Node, Diagnostic, "E_CONSTANT", "integer literal is outside its selected type")
        Exit Function
    End If
    Bound.Nodes(Node).TypeName = TypeName
    Bound.Nodes(Node).ConstantKnown = True
    Bound.Nodes(Node).ConstantValue = Value
    BindNumber = True
End Function

' Retains an implicit boundary conversion and folds it only when its source is known.
Private Function ConvertValue(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByVal Node As Long, ByVal Destination As String, ByRef Diagnostic As String) As Boolean
    Dim Source As String
    Dim Value As Variant
    Source = Bound.Nodes(Node).TypeName
    If AggregateValue(Bound, Node) Then
        ConvertValue = BindingError(Project, Parsed, Node, Diagnostic, "E_TYPE", "aggregate value cannot undergo scalar conversion")
        Exit Function
    End If
    If Source <> "Boolean" And IntegerWidth(Source) = 0 Then
        ConvertValue = BindingError(Project, Parsed, Node, Diagnostic, "E_TYPE", "value cannot convert to " & Destination)
        Exit Function
    End If
    If Destination <> "Boolean" And IntegerWidth(Destination) = 0 Then
        ConvertValue = BindingError(Project, Parsed, Node, Diagnostic, "E_TYPE", "unsupported scalar destination")
        Exit Function
    End If
    Bound.Nodes(Node).ConvertedType = Destination
    If Bound.Nodes(Node).ConstantKnown Then
        Value = Bound.Nodes(Node).ConstantValue
        If Destination = "Boolean" Then
            If Value = CDec(0) Then Value = CDec(0) Else Value = CDec(-1)
        ElseIf Not FitsInteger(Value, Destination) Then
            ConvertValue = BindingError(Project, Parsed, Node, Diagnostic, "E_CONSTANT", "constant conversion is outside " & Destination & " range")
            Exit Function
        End If
        ' ConstantValue describes the typed expression; conversion result is derived separately.
    End If
    ConvertValue = True
End Function

' Obtains the exact value after a previously checked scalar boundary conversion.
Private Function ConvertedConstant(ByRef Bound As BoundProject, ByVal Node As Long, ByVal Destination As String) As Variant
    Dim Value As Variant
    Value = Bound.Nodes(Node).ConstantValue
    If Destination = "Boolean" Then
        If Value = CDec(0) Then Value = CDec(0) Else Value = CDec(-1)
    End If
    ConvertedConstant = Value
End Function

' Computes signed integral And with exact Decimal bit extraction through all 64 bits.
Private Function IntegerAnd(ByVal LeftValue As Variant, ByVal RightValue As Variant, ByVal TypeName As String) As Variant
    Dim Width As Long
    Dim Index As Long
    Dim Modulus As Variant
    Dim Half As Variant
    Dim Power As Variant
    Dim Result As Variant
    Dim LeftHalf As Variant
    Dim RightHalf As Variant
    Width = 32
    Modulus = CDec("4294967296")
    If TypeName = "Integer" Then
        Width = 16
        Modulus = CDec("65536")
    End If
    If TypeName = "LongLong" Then
        Width = 64
        Modulus = CDec("18446744073709551616")
    End If
    Half = Modulus / CDec(2)
    If LeftValue < CDec(0) Then LeftValue = LeftValue + Modulus
    If RightValue < CDec(0) Then RightValue = RightValue + Modulus
    Power = CDec(1)
    Result = CDec(0)
    For Index = 1 To Width
        LeftHalf = Fix(LeftValue / CDec(2))
        RightHalf = Fix(RightValue / CDec(2))
        If LeftValue - LeftHalf * CDec(2) <> CDec(0) And RightValue - RightHalf * CDec(2) <> CDec(0) Then Result = Result + Power
        LeftValue = LeftHalf
        RightValue = RightHalf
        Power = Power * CDec(2)
    Next Index
    If Result >= Half Then Result = Result - Modulus
    IntegerAnd = Result
End Function

' Ensures required constants use only earlier same-module constants, with explicit pending cross-module ordering.
Private Function ConstantDependency(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByVal Node As Long, ByVal Symbol As Long, ByVal Required As Long, ByRef Diagnostic As String) As Boolean
    Dim SourceNode As Long
    Dim RequiredNode As Long
    If Bound.Symbols(Symbol).Kind <> "constant" Then
        ConstantDependency = BindingError(Project, Parsed, Node, Diagnostic, "E_CONSTANT", "required constant cannot read nonconstant storage or a property")
        Exit Function
    End If
    SourceNode = Bound.Symbols(Symbol).DeclarationNode
    RequiredNode = Bound.Symbols(Required).DeclarationNode
    If Bound.Symbols(Symbol).ModuleIndex <> Bound.Symbols(Required).ModuleIndex Then
        ConstantDependency = BindingError(Project, Parsed, Node, Diagnostic, "E_UNSUPPORTED", "cross-module required-constant dependency ordering is not yet defined")
        Exit Function
    End If
    If Parsed.Nodes(SourceNode).Offset >= Parsed.Nodes(RequiredNode).Offset Then
        ConstantDependency = BindingError(Project, Parsed, Node, Diagnostic, "E_CONSTANT", "required constant must refer to a previously declared constant")
        Exit Function
    End If
    ConstantDependency = True
End Function

' Evaluates one declared constant using checked source types and its own source context.
Private Function EvaluateConstant(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As BindingState, ByVal Symbol As Long, ByRef Diagnostic As String) As Boolean
    Dim Node As Long
    Dim Initializer As Long
    Node = Bound.Symbols(Symbol).DeclarationNode
    If State.ConstantState(Symbol) = 2 Then
        EvaluateConstant = True
        Exit Function
    End If
    If State.ConstantState(Symbol) = 1 Then
        EvaluateConstant = BindingError(Project, Parsed, Node, Diagnostic, "E_CONSTANT", "cyclic required constant dependency")
        Exit Function
    End If
    State.ConstantState(Symbol) = 1
    Initializer = Parsed.Nodes(Node).FirstChild
    If Initializer = 0 Then
        EvaluateConstant = BindingError(Project, Parsed, Node, Diagnostic, "E_CONSTANT", "required constant has no initializer")
        Exit Function
    End If
    If Not BindExpression(Project, Parsed, Bound, State, Initializer, Symbol, Diagnostic, Bound.Symbols(Symbol).TypeName) Then Exit Function
    If Not Bound.Nodes(Initializer).ConstantKnown Then
        EvaluateConstant = BindingError(Project, Parsed, Initializer, Diagnostic, "E_CONSTANT", "initializer is not a required constant")
        Exit Function
    End If
    If Not ConvertValue(Project, Parsed, Bound, Initializer, Bound.Symbols(Symbol).TypeName, Diagnostic) Then Exit Function
    Bound.Symbols(Symbol).ConstantKnown = True
    Bound.Symbols(Symbol).ConstantValue = ConvertedConstant(Bound, Initializer, Bound.Symbols(Symbol).TypeName)
    Bound.Nodes(Node).ConstantKnown = True
    Bound.Nodes(Node).ConstantValue = Bound.Symbols(Symbol).ConstantValue
    State.ConstantState(Symbol) = 2
    EvaluateConstant = True
End Function

' Binds one indexed element using the array descriptor's actual LongLong bounds.
Private Function BindIndex(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As BindingState, ByVal Node As Long, ByVal Receiver As Long, ByRef Diagnostic As String) As Boolean
    Dim IndexNode As Long
    Dim Value As Variant
    IndexNode = Parsed.Nodes(Receiver).NextSibling
    If IndexNode = 0 Then
        BindIndex = BindingError(Project, Parsed, Node, Diagnostic, "E_ARGUMENT", "rank-one array indexing requires exactly one index")
        Exit Function
    End If
    If Parsed.Nodes(IndexNode).NextSibling <> 0 Then
        BindIndex = BindingError(Project, Parsed, Node, Diagnostic, "E_ARGUMENT", "rank-one array indexing requires exactly one index")
        Exit Function
    End If
    If Not BindExpression(Project, Parsed, Bound, State, IndexNode, 0, Diagnostic, "LongLong") Then Exit Function
    If Not ConvertValue(Project, Parsed, Bound, IndexNode, "LongLong", Diagnostic) Then Exit Function
    If Bound.Nodes(Receiver).HasBounds And Bound.Nodes(IndexNode).ConstantKnown Then
        Value = ConvertedConstant(Bound, IndexNode, "LongLong")
        If Value < Bound.Nodes(Receiver).LowerBound Or Value > Bound.Nodes(Receiver).UpperBound Then
            BindIndex = BindingError(Project, Parsed, IndexNode, Diagnostic, "E_CONSTANT", "constant index is outside the known array bounds")
            Exit Function
        End If
    End If
    With Bound.Nodes(Node)
        .SymbolIndex = 0
        .TypeName = Bound.Nodes(Receiver).TypeName
        .TypeSymbol = Bound.Nodes(Receiver).TypeSymbol
        .ArrayRank = 0
        .HasBounds = False
        .ElementCells = Bound.Nodes(Receiver).ElementCells
        .StorageCells = .ElementCells
        .Writable = Bound.Nodes(Receiver).Writable
        .AccessKind = "index"
    End With
    BindIndex = True
End Function

' Compares element/rank or nominal-record identity without including bounds in the type.
Private Function SameValueType(ByRef Bound As BoundProject, ByVal Node As Long, ByVal Symbol As Long) As Boolean
    SameValueType = (Bound.Nodes(Node).ArrayRank = Bound.Symbols(Symbol).ArrayRank And Bound.Nodes(Node).TypeSymbol = Bound.Symbols(Symbol).TypeSymbol And Bound.Nodes(Node).TypeName = Bound.Symbols(Symbol).TypeName)
End Function

' Resolves the selected callable once, then prepares positional arguments with explicit alias/temporary modes.
Private Function BindCall(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As BindingState, ByVal Node As Long, ByVal ValueContext As Boolean, ByRef Diagnostic As String) As Boolean
    Dim Callee As Long
    Dim Symbol As Long
    Dim Argument As Long
    Dim Parameter As Long
    Dim Count As Long
    Dim ActualSymbol As Long
    Dim Kind As String
    Callee = Parsed.Nodes(Node).FirstChild
    Symbol = ResolveReference(Project, Parsed, Bound, State, Callee, False, Diagnostic)
    If Symbol = 0 Then Exit Function
    If Bound.Nodes(Callee).ArrayRank <> 0 Then
        If Not ValueContext Then
            BindCall = BindingError(Project, Parsed, Node, Diagnostic, "E_TYPE", "array indexing is not a procedure-call statement")
        Else
            BindCall = BindIndex(Project, Parsed, Bound, State, Node, Callee, Diagnostic)
        End If
        Exit Function
    End If
    Kind = Bound.Symbols(Symbol).Kind
    If Kind <> "sub" And Kind <> "function" Then
        BindCall = BindingError(Project, Parsed, Node, Diagnostic, "E_TYPE", "selected declaration is not callable")
        Exit Function
    End If
    If ValueContext And Kind = "sub" Then
        BindCall = BindingError(Project, Parsed, Node, Diagnostic, "E_TYPE", "Sub invocation cannot be used as a value")
        Exit Function
    End If
    Argument = Parsed.Nodes(Callee).NextSibling
    Do While Argument <> 0
        Count = Count + 1
        Argument = Parsed.Nodes(Argument).NextSibling
    Loop
    If Count <> Bound.Symbols(Symbol).ParameterCount Then
        BindCall = BindingError(Project, Parsed, Node, Diagnostic, "E_ARGUMENT", "wrong argument count for selected declaration " & Bound.Symbols(Symbol).Name)
        Exit Function
    End If
    Bound.Nodes(Node).SymbolIndex = Symbol
    Call SymbolValue(Bound, Node, Symbol)
    If Kind = "sub" Then Bound.Nodes(Node).TypeName = "Void"
    Parameter = Bound.Symbols(Symbol).FirstParameter
    Argument = Parsed.Nodes(Callee).NextSibling
    Do While Argument <> 0
        If Not BindExpression(Project, Parsed, Bound, State, Argument, 0, Diagnostic, Bound.Symbols(Parameter).TypeName) Then Exit Function
        If AggregateValue(Bound, Argument) Or Bound.Symbols(Parameter).ArrayRank <> 0 Or Bound.Symbols(Parameter).TypeSymbol <> 0 Then
            If Bound.Symbols(Parameter).PassingMode <> "ByRef" Or Parsed.Nodes(Argument).Kind = "group" Then
                BindCall = BindingError(Project, Parsed, Argument, Diagnostic, "E_UNSUPPORTED", "aggregate ByVal and grouped ByRef temporaries are outside this profile")
                Exit Function
            End If
            If Not Bound.Nodes(Argument).Writable Or Not SameValueType(Bound, Argument, Parameter) Then
                BindCall = BindingError(Project, Parsed, Argument, Diagnostic, "E_ARGUMENT", "aggregate ByRef requires exact nominal/element type, rank and writable storage")
                Exit Function
            End If
            Bound.Nodes(Argument).ArgumentMode = "alias"
            Bound.Nodes(Argument).ConvertedType = Bound.Symbols(Parameter).TypeName
        ElseIf Bound.Symbols(Parameter).PassingMode = "ByVal" Then
            Bound.Nodes(Argument).ArgumentMode = "value"
            If Not ConvertValue(Project, Parsed, Bound, Argument, Bound.Symbols(Parameter).TypeName, Diagnostic) Then Exit Function
        ElseIf Parsed.Nodes(Argument).Kind = "group" Then
            Bound.Nodes(Argument).ArgumentMode = "temp"
            If Not ConvertValue(Project, Parsed, Bound, Argument, Bound.Symbols(Parameter).TypeName, Diagnostic) Then Exit Function
        Else
            ActualSymbol = Bound.Nodes(Argument).SymbolIndex
            If Not Bound.Nodes(Argument).Writable Then
                BindCall = BindingError(Project, Parsed, Argument, Diagnostic, "E_ARGUMENT", "direct ByRef requires writable caller storage")
                Exit Function
            End If
            If Bound.Nodes(Argument).AccessKind <> "field" And Bound.Nodes(Argument).AccessKind <> "index" Then
                If ActualSymbol = 0 Then
                    BindCall = BindingError(Project, Parsed, Argument, Diagnostic, "E_ARGUMENT", "direct ByRef requires a storage identity")
                    Exit Function
                End If
                If Bound.Symbols(ActualSymbol).Kind <> "variable" And Bound.Symbols(ActualSymbol).Kind <> "parameter" Then
                    BindCall = BindingError(Project, Parsed, Argument, Diagnostic, "E_ARGUMENT", "direct ByRef cannot alias this result or property")
                    Exit Function
                End If
            End If
            If Bound.Nodes(Argument).TypeName <> Bound.Symbols(Parameter).TypeName Then
                BindCall = BindingError(Project, Parsed, Argument, Diagnostic, "E_ARGUMENT", "direct ByRef requires exact declared type")
                Exit Function
            End If
            Bound.Nodes(Argument).ArgumentMode = "alias"
            Bound.Nodes(Argument).ConvertedType = Bound.Symbols(Parameter).TypeName
        End If
        Parameter = Bound.Symbols(Parameter).NextParameter
        Argument = Parsed.Nodes(Argument).NextSibling
    Loop
    BindCall = True
End Function

' Applies the selected eager scalar operator and folds only when both operands are known.
Private Function BindBinary(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As BindingState, ByVal Node As Long, ByVal Required As Long, ByRef Diagnostic As String, ByVal DestinationType As String) As Boolean
    Dim LeftNode As Long
    Dim RightNode As Long
    Dim LeftType As String
    Dim RightType As String
    Dim SelectedType As String
    Dim Operator As String
    Dim Result As Variant
    Dim LeftValue As Variant
    Dim RightValue As Variant
    Dim Comparison As Boolean
    Dim Truth As Boolean
    Dim OperandContext As String
    LeftNode = Parsed.Nodes(Node).FirstChild
    RightNode = Parsed.Nodes(LeftNode).NextSibling
    Operator = Parsed.Nodes(Node).Text
    If Operator = "+" Or Operator = "and" Then OperandContext = DestinationType
    If Not BindExpression(Project, Parsed, Bound, State, LeftNode, Required, Diagnostic, OperandContext) Then Exit Function
    If Not BindExpression(Project, Parsed, Bound, State, RightNode, Required, Diagnostic, OperandContext) Then Exit Function
    LeftType = Bound.Nodes(LeftNode).TypeName
    RightType = Bound.Nodes(RightNode).TypeName
    Operator = Parsed.Nodes(Node).Text
    If AggregateValue(Bound, LeftNode) Or AggregateValue(Bound, RightNode) Then
        If Bound.Nodes(LeftNode).ArrayRank <> 0 Or Bound.Nodes(RightNode).ArrayRank <> 0 Then
            BindBinary = BindingError(Project, Parsed, Node, Diagnostic, "E_UNSUPPORTED", "whole-array comparison is outside this profile")
            Exit Function
        End If
        If Bound.Nodes(LeftNode).TypeSymbol = 0 Or Bound.Nodes(LeftNode).TypeSymbol <> Bound.Nodes(RightNode).TypeSymbol Then
            BindBinary = BindingError(Project, Parsed, Node, Diagnostic, "E_TYPE", "record comparison requires the same declared Type")
            Exit Function
        End If
        If Operator <> "=" And Operator <> "<>" Then
            BindBinary = BindingError(Project, Parsed, Node, Diagnostic, "E_TYPE", "records admit only equality and inequality")
            Exit Function
        End If
        Bound.Nodes(Node).TypeName = "Boolean"
        BindBinary = True
        Exit Function
    End If
    If (LeftType = "Boolean") <> (RightType = "Boolean") Then
        BindBinary = BindingError(Project, Parsed, Node, Diagnostic, "E_UNSUPPORTED", "mixed Boolean/integer operator domain is not admitted")
        Exit Function
    End If
    SelectedType = "Integer"
    If LeftType = "Long" Or RightType = "Long" Then SelectedType = "Long"
    If LeftType = "LongLong" Or RightType = "LongLong" Then SelectedType = "LongLong"
    If LeftType = "Boolean" Then SelectedType = "Boolean"
    Comparison = (Operator = "=" Or Operator = "<>" Or Operator = "<" Or Operator = ">" Or Operator = "<=" Or Operator = ">=")
    If SelectedType = "Boolean" Then
        If Operator <> "and" And Operator <> "=" And Operator <> "<>" Then
            BindBinary = BindingError(Project, Parsed, Node, Diagnostic, "E_UNSUPPORTED", "noninteger arithmetic/order domain is not admitted")
            Exit Function
        End If
    End If
    Bound.Nodes(Node).TypeName = SelectedType
    If Comparison Then Bound.Nodes(Node).TypeName = "Boolean"
    ' Operand promotions are retained independently from any enclosing destination conversion.
    Bound.Nodes(LeftNode).ConvertedType = SelectedType
    Bound.Nodes(RightNode).ConvertedType = SelectedType
    If Bound.Nodes(LeftNode).ConstantKnown And Bound.Nodes(RightNode).ConstantKnown Then
        LeftValue = Bound.Nodes(LeftNode).ConstantValue
        RightValue = Bound.Nodes(RightNode).ConstantValue
        Select Case Operator
        Case "+"
            Result = LeftValue + RightValue
        Case "and"
            If SelectedType = "Boolean" Then
                If LeftValue <> CDec(0) And RightValue <> CDec(0) Then Result = CDec(-1) Else Result = CDec(0)
            Else
                Result = IntegerAnd(LeftValue, RightValue, SelectedType)
            End If
        Case "=": Truth = (LeftValue = RightValue)
        Case "<>": Truth = (LeftValue <> RightValue)
        Case "<": Truth = (LeftValue < RightValue)
        Case ">": Truth = (LeftValue > RightValue)
        Case "<=": Truth = (LeftValue <= RightValue)
        Case ">=": Truth = (LeftValue >= RightValue)
        Case Else
            BindBinary = BindingError(Project, Parsed, Node, Diagnostic, "E_UNSUPPORTED", "operator is outside the semantic profile")
            Exit Function
        End Select
        If Comparison Then
            If Truth Then Result = CDec(-1) Else Result = CDec(0)
        ElseIf SelectedType <> "Boolean" Then
            If Not FitsInteger(Result, SelectedType) Then
                BindBinary = BindingError(Project, Parsed, Node, Diagnostic, "E_CONSTANT", "constant operation overflows selected " & SelectedType & " arithmetic")
                Exit Function
            End If
        End If
        Bound.Nodes(Node).ConstantKnown = True
        Bound.Nodes(Node).ConstantValue = Result
    End If
    BindBinary = True
End Function

' Binds expression identities and types, retaining checked constants rather than executing source calls.
Private Function BindExpression(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As BindingState, ByVal Node As Long, ByVal Required As Long, ByRef Diagnostic As String, Optional ByVal DestinationType As String = "") As Boolean
    Dim Kind As String
    Dim Symbol As Long
    Dim Child As Long
    Dim Value As Variant
    If Not EnterBinding(Project, Parsed, State, Node, Diagnostic) Then Exit Function
    Kind = Parsed.Nodes(Node).Kind
    Select Case Kind
    Case "number"
        If Not BindNumber(Project, Parsed, Bound, Node, False, Diagnostic, DestinationType) Then Exit Function
    Case "boolean"
        Bound.Nodes(Node).TypeName = "Boolean"
        Bound.Nodes(Node).ConstantKnown = True
        If Parsed.Nodes(Node).Text = "true" Then Bound.Nodes(Node).ConstantValue = CDec(-1) Else Bound.Nodes(Node).ConstantValue = CDec(0)
    Case "name", "member"
        Symbol = ResolveReference(Project, Parsed, Bound, State, Node, False, Diagnostic)
        If Symbol = 0 Then Exit Function
        If Required <> 0 Then
            If Not ConstantDependency(Project, Parsed, Bound, Node, Symbol, Required, Diagnostic) Then Exit Function
        End If
        Kind = Bound.Symbols(Symbol).Kind
        If Kind = "constant" Then
            If Not EvaluateConstant(Project, Parsed, Bound, State, Symbol, Diagnostic) Then Exit Function
            Bound.Nodes(Node).ConstantKnown = True
            Bound.Nodes(Node).ConstantValue = Bound.Symbols(Symbol).ConstantValue
        ElseIf Kind <> "variable" And Kind <> "parameter" And Kind <> "property" And Kind <> "field" Then
            BindExpression = BindingError(Project, Parsed, Node, Diagnostic, "E_TYPE", "declaration is not a scalar value; expression calls require parentheses")
            Exit Function
        End If
    Case "group"
        Child = Parsed.Nodes(Node).FirstChild
        If Not BindExpression(Project, Parsed, Bound, State, Child, Required, Diagnostic, DestinationType) Then Exit Function
        Call CopyValue(Bound, Node, Child)
        Bound.Nodes(Node).Writable = False
    Case "unary"
        Child = Parsed.Nodes(Node).FirstChild
        If Parsed.Nodes(Node).Text = "-" And Parsed.Nodes(Child).Kind = "number" Then
            If Not BindNumber(Project, Parsed, Bound, Child, True, Diagnostic, DestinationType) Then Exit Function
            Call CopyValue(Bound, Node, Child)
            If Bound.Nodes(Node).TypeName = "Byte" Then
                Bound.Nodes(Node).TypeName = "Integer"
                Bound.Nodes(Child).ConvertedType = "Integer"
            End If
            ' This token magnitude belongs to the signed literal; it is not a standalone positive value.
            Bound.Nodes(Child).ConstantKnown = False
            Bound.Nodes(Child).ConstantValue = Empty
        Else
            If Not BindExpression(Project, Parsed, Bound, State, Child, Required, Diagnostic, DestinationType) Then Exit Function
            If AggregateValue(Bound, Child) Then
                BindExpression = BindingError(Project, Parsed, Node, Diagnostic, "E_TYPE", "aggregate values do not support unary arithmetic")
                Exit Function
            End If
            If Bound.Nodes(Child).TypeName = "Boolean" Then
                BindExpression = BindingError(Project, Parsed, Node, Diagnostic, "E_UNSUPPORTED", "Boolean unary arithmetic is outside the operator domain")
                Exit Function
            End If
            Call CopyValue(Bound, Node, Child)
            If Bound.Nodes(Node).TypeName = "Byte" Then
                Bound.Nodes(Node).TypeName = "Integer"
                Bound.Nodes(Child).ConvertedType = "Integer"
            End If
            If Bound.Nodes(Node).ConstantKnown Then
                Value = Bound.Nodes(Node).ConstantValue
                If Parsed.Nodes(Node).Text = "-" Then Value = -Value
                If Not FitsInteger(Value, Bound.Nodes(Node).TypeName) Then
                    BindExpression = BindingError(Project, Parsed, Node, Diagnostic, "E_CONSTANT", "unary constant overflows its selected integer type")
                    Exit Function
                End If
                Bound.Nodes(Node).ConstantValue = Value
            End If
        End If
    Case "binary"
        If Not BindBinary(Project, Parsed, Bound, State, Node, Required, Diagnostic, DestinationType) Then Exit Function
    Case "call"
        If Required <> 0 Then
            BindExpression = BindingError(Project, Parsed, Node, Diagnostic, "E_CONSTANT", "required constants cannot call procedures")
            Exit Function
        End If
        If Not BindCall(Project, Parsed, Bound, State, Node, True, Diagnostic) Then Exit Function
    Case Else
        BindExpression = BindingError(Project, Parsed, Node, Diagnostic, "E_TYPE", "syntax node is not a scalar expression")
        Exit Function
    End Select
    If Bound.Nodes(Node).TypeSymbol = 0 And Bound.Nodes(Node).ArrayRank = 0 Then
        If Bound.Nodes(Node).TypeName = "Boolean" Or IntegerWidth(Bound.Nodes(Node).TypeName) > 0 Then
            Bound.Nodes(Node).ElementCells = 1
            Bound.Nodes(Node).StorageCells = 1
        End If
    End If
    State.Depth = State.Depth - 1
    BindExpression = True
End Function

' Checks assignments and initializers without making mutable storage a compile-time constant symbol.
Private Function BindAssignment(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As BindingState, ByVal Node As Long, ByRef Diagnostic As String) As Boolean
    Dim Target As Long
    Dim Value As Long
    Dim Symbol As Long
    Dim TypeName As String
    If Parsed.Nodes(Node).Kind = "variable" Then
        Symbol = Bound.Nodes(Node).SymbolIndex
        Target = Node
        Value = DeclarationValueNode(Parsed, Node)
        If Value = 0 Then
            BindAssignment = True
            Exit Function
        End If
    Else
        Target = Parsed.Nodes(Node).FirstChild
        Value = Parsed.Nodes(Target).NextSibling
        If Parsed.Nodes(Target).Kind = "call" Then
            If Not BindCall(Project, Parsed, Bound, State, Target, True, Diagnostic) Then Exit Function
            Symbol = Bound.Nodes(Target).SymbolIndex
        Else
            Symbol = ResolveReference(Project, Parsed, Bound, State, Target, True, Diagnostic)
            If Symbol = 0 Then Exit Function
        End If
        If Not Bound.Nodes(Target).Writable Then
            BindAssignment = BindingError(Project, Parsed, Target, Diagnostic, "E_TYPE", "assignment requires writable scalar storage")
            Exit Function
        End If
        Bound.Nodes(Node).SymbolIndex = Symbol
    End If
    TypeName = Bound.Nodes(Target).TypeName
    If Not BindExpression(Project, Parsed, Bound, State, Value, 0, Diagnostic, TypeName) Then Exit Function
    If AggregateValue(Bound, Target) Or AggregateValue(Bound, Value) Then
        If Bound.Nodes(Target).TypeSymbol <> Bound.Nodes(Value).TypeSymbol Or Bound.Nodes(Target).ArrayRank <> Bound.Nodes(Value).ArrayRank Or TypeName <> Bound.Nodes(Value).TypeName Then
            BindAssignment = BindingError(Project, Parsed, Node, Diagnostic, "E_TYPE", "aggregate assignment requires identical nominal/element type and rank")
            Exit Function
        End If
        Call CopyValue(Bound, Node, Target)
        Bound.Nodes(Node).ConstantKnown = False
        Bound.Nodes(Value).ConvertedType = TypeName
        BindAssignment = True
        Exit Function
    End If
    If Not ConvertValue(Project, Parsed, Bound, Value, TypeName, Diagnostic) Then Exit Function
    Bound.Nodes(Node).TypeName = TypeName
    Bound.Nodes(Node).ElementCells = 1
    Bound.Nodes(Node).StorageCells = 1
    If Bound.Nodes(Value).ConstantKnown Then
        Bound.Nodes(Node).ConstantKnown = True
        Bound.Nodes(Node).ConstantValue = ConvertedConstant(Bound, Value, TypeName)
    End If
    BindAssignment = True
End Function

' Resolves both ordinary and handler branches in the separate procedure-local label region.
Private Function BindBranch(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As BindingState, ByVal Node As Long, ByRef Diagnostic As String) As Boolean
    Dim Name As String
    Dim Symbol As Long
    Name = Parsed.Nodes(Node).Text
    If Parsed.Nodes(Node).Kind = "on-error" Then
        If Left$(Name, 5) <> "goto:" Then
            BindBranch = True
            Exit Function
        End If
        Name = Mid$(Name, 6)
    End If
    Symbol = FindSymbol(Bound, State, Bound.Nodes(Node).ScopeSymbol, "label", CanonicalLabel(Name))
    If State.LookupWork > MaximumLookupWork Then
        BindBranch = BindingError(Project, Parsed, Node, Diagnostic, "E_LIMIT", "symbol lookup work limit exceeded")
        Exit Function
    End If
    If Symbol = 0 Then
        BindBranch = BindingError(Project, Parsed, Node, Diagnostic, "E_LABEL", "target label is not declared in this procedure: " & Name)
        Exit Function
    End If
    Bound.Nodes(Node).SymbolIndex = Symbol
    BindBranch = True
End Function

' Selects a single valid executable entry; library procedures never acquire an implicit entry role.
Private Function SelectEntry(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef Diagnostic As String) As Boolean
    Dim Index As Long
    Dim Node As Long
    Dim Kind As String
    If Project.KindName = "library" Then
        SelectEntry = True
        Exit Function
    End If
    For Index = 1 To Bound.SymbolCount
        Kind = Bound.Symbols(Index).Kind
        If (Kind = "sub" Or Kind = "function") And Bound.Symbols(Index).Origin = "source" Then
            If FoldAscii(Bound.Symbols(Index).Name) = "main" Then
                Node = Bound.Symbols(Index).DeclarationNode
                If Bound.Symbols(Index).ParameterCount <> 0 Then
                    SelectEntry = BindingError(Project, Parsed, Node, Diagnostic, "E_ENTRY", "Main must have no parameters")
                    Exit Function
                End If
                If Kind = "function" And Bound.Symbols(Index).TypeName <> "Long" Then
                    SelectEntry = BindingError(Project, Parsed, Node, Diagnostic, "E_ENTRY", "Main Function must return Long")
                    Exit Function
                End If
                If Bound.EntrySymbol <> 0 Then
                    SelectEntry = BindingError(Project, Parsed, Node, Diagnostic, "E_ENTRY", "executable has more than one Main")
                    Exit Function
                End If
                Bound.EntrySymbol = Index
            End If
        End If
    Next Index
    If Bound.EntrySymbol = 0 Then
        SelectEntry = BindingError(Project, Parsed, 0, Diagnostic, "E_ENTRY", "executable requires one Sub Main() or Function Main() As Long")
        Exit Function
    End If
    SelectEntry = True
End Function

' Visits executable semantic roots once; recursive expression facts are retained beneath them.
Private Function CheckNodes(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As BindingState, ByRef Diagnostic As String) As Boolean
    Dim Node As Long
    Dim Child As Long
    Dim Parent As Long
    Dim Kind As String
    For Node = 1 To Parsed.NodeCount
        Kind = Parsed.Nodes(Node).Kind
        Select Case Kind
        Case "variable", "assignment"
            If Not BindAssignment(Project, Parsed, Bound, State, Node, Diagnostic) Then Exit Function
        Case "if"
            Child = Parsed.Nodes(Node).FirstChild
            If Not BindExpression(Project, Parsed, Bound, State, Child, 0, Diagnostic) Then Exit Function
            If Not ConvertValue(Project, Parsed, Bound, Child, "Boolean", Diagnostic) Then Exit Function
        Case "goto", "on-error"
            If Not BindBranch(Project, Parsed, Bound, State, Node, Diagnostic) Then Exit Function
        Case "call"
            Parent = Parsed.Nodes(Node).Parent
            If Parent > 0 Then
                Kind = Parsed.Nodes(Parent).Kind
                If Kind = "body" Or Kind = "then" Or Kind = "else" Then
                    If Not BindCall(Project, Parsed, Bound, State, Node, False, Diagnostic) Then Exit Function
                End If
            End If
        End Select
    Next Node
    CheckNodes = True
End Function

' Publishes a complete bound package only after declarations, constants, calls and entry checks pass.
Public Function BindProject(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef Diagnostic As String) As Boolean
    Dim State As BindingState
    Dim Index As Long
    On Error GoTo Failed
    Call ClearBound(Bound)
    Diagnostic = ""
    If Parsed.RootNode = 0 Or Parsed.NodeCount < 1 Or Parsed.ModuleCount <> Project.SourceCount Then
        BindProject = BindingError(Project, Parsed, 0, Diagnostic, "E_TYPE", "semantic analysis requires a complete parsed project")
        Exit Function
    End If
    ReDim Bound.Symbols(1 To MaximumBoundSymbols)
    ReDim Bound.Nodes(1 To Parsed.NodeCount)
    ReDim Bound.ModuleSymbols(0 To Parsed.ModuleCount - 1)
    ReDim State.Buckets(0 To SymbolBucketCount - 1)
    ReDim State.NextSymbol(1 To MaximumBoundSymbols)
    ReDim State.Regions(1 To MaximumBoundSymbols)
    ReDim State.ConstantState(1 To MaximumBoundSymbols)
    ReDim State.TypeState(1 To MaximumBoundSymbols)
    State.ProjectName = Project.ProjectName
    Bound.NodeCount = Parsed.NodeCount
    If Not CollectDeclarations(Project, Parsed, Bound, State, Diagnostic) Then GoTo Rejected
    If Not ValidateIntrinsicDeclarations(Project, Parsed, Bound, Diagnostic) Then GoTo Rejected
    If Not PrepareValueTypes(Project, Parsed, Bound, State, Diagnostic) Then GoTo Rejected
    If Not PrepareArrayEffects(Project, Parsed, Bound, State, Diagnostic) Then GoTo Rejected
    ' Complete constant declarations before ordinary expressions, independent of caller module order.
    For Index = 1 To Bound.SymbolCount
        If Bound.Symbols(Index).Kind = "constant" Then
            If Not EvaluateConstant(Project, Parsed, Bound, State, Index, Diagnostic) Then GoTo Rejected
        End If
    Next Index
    If Not SelectEntry(Project, Parsed, Bound, Diagnostic) Then GoTo Rejected
    If Not CheckNodes(Project, Parsed, Bound, State, Diagnostic) Then GoTo Rejected
    If State.LookupWork > MaximumLookupWork Then
        Call BindingError(Project, Parsed, 0, Diagnostic, "E_LIMIT", "symbol lookup work limit exceeded")
        GoTo Rejected
    End If
    ReDim Preserve Bound.Symbols(1 To Bound.SymbolCount)
    BindProject = True
    Exit Function
Failed:
    On Error Resume Next
    Diagnostic = "UBE: E_INTERNAL: " & Project.ManifestPath & ":1:1 unable to retain bounded semantic analysis"
Rejected:
    Call ClearBound(Bound)
End Function

' Resets caller-owned output on entry or failure so partial results cannot advertise success.
Private Sub ClearBound(ByRef Bound As BoundProject)
    Bound.SymbolCount = 0
    Bound.NodeCount = 0
    Bound.EntrySymbol = 0
    Bound.PackageSymbol = 0
    Bound.ArrayBoundsMayChange = False
    Erase Bound.Symbols
    Erase Bound.Nodes
    Erase Bound.ModuleSymbols
End Sub

' Escapes deterministic record delimiters without changing declaration identity.
Private Function BoundText(ByVal Text As String) As String
    Text = Replace(Text, "\", "\\")
    Text = Replace(Text, "|", "\p")
    Text = Replace(Text, vbCr, "\r")
    Text = Replace(Text, vbLf, "\n")
    BoundText = Text
End Function

' Formats whole-number Decimal constants without any floating conversion or grouping.
Private Function ConstantText(ByVal Known As Boolean, ByVal Value As Variant) As String
    If Known Then ConstantText = CStr(Value)
End Function

' Formats metadata flags independently of host Boolean spelling or numeric representation.
Private Function FlagText(ByVal Value As Boolean) As String
    If Value Then FlagText = "1" Else FlagText = "0"
End Function

' Exposes declaration identity and trusted binding roles for acceptance assertions.
Public Function FormatSymbol(ByRef Bound As BoundProject, ByVal Index As Long) As String
    If Index < 1 Or Index > Bound.SymbolCount Then Exit Function
    With Bound.Symbols(Index)
        FormatSymbol = "SYMBOL " & CStr(Index) & "|" & .Kind & "|" & BoundText(.Name) & "|" & BoundText(.TypeName) & "|" & .Visibility & "|" & CStr(.ModuleIndex) & "|" & CStr(.ScopeSymbol) & "|" & CStr(.DeclarationNode) & "|" & .PassingMode & "|" & .BindingId & "|" & CStr(.FirstParameter) & "|" & CStr(.NextParameter) & "|" & CStr(.ParameterCount) & "|" & ConstantText(.ConstantKnown, .ConstantValue)
        FormatSymbol = FormatSymbol & "|" & CStr(.TypeSymbol) & "|" & CStr(.ArrayRank) & "|" & FlagText(.HasBounds) & "|" & ConstantText(.HasBounds, .LowerBound) & "|" & ConstantText(.HasBounds, .UpperBound)
        FormatSymbol = FormatSymbol & "|" & CStr(.ElementCells) & "|" & CStr(.StorageCells) & "|" & CStr(.FieldOffset) & "|" & CStr(.FirstField) & "|" & CStr(.NextField)
    End With
End Function

' Exposes each retained source node's selected symbol, value type and call/conversion treatment.
Public Function FormatBinding(ByRef Bound As BoundProject, ByVal Index As Long) As String
    Dim Writable As String
    If Index < 1 Or Index > Bound.NodeCount Then Exit Function
    Writable = "0"
    If Bound.Nodes(Index).Writable Then Writable = "1"
    With Bound.Nodes(Index)
        FormatBinding = "BOUND " & CStr(Index) & "|" & CStr(.SymbolIndex) & "|" & BoundText(.TypeName) & "|" & BoundText(.ConvertedType) & "|" & .ArgumentMode & "|" & Writable & "|" & ConstantText(.ConstantKnown, .ConstantValue) & "|" & CStr(.ScopeSymbol)
        FormatBinding = FormatBinding & "|" & CStr(.TypeSymbol) & "|" & CStr(.ArrayRank) & "|" & FlagText(.HasBounds) & "|" & ConstantText(.HasBounds, .LowerBound) & "|" & ConstantText(.HasBounds, .UpperBound)
        FormatBinding = FormatBinding & "|" & CStr(.ElementCells) & "|" & CStr(.StorageCells) & "|" & .AccessKind
    End With
End Function
