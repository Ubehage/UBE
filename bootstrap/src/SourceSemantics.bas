Attribute VB_Name = "SourceSemantics"
Option Explicit

' Declaration identities and checked scalar facts are owned by one bound project.
Public Const MaximumBoundSymbols As Long = 16384
Public Const MaximumBindingDepth As Long = 128
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
End Type

Public Type BoundProject
    SymbolCount As Long
    Symbols() As BoundSymbol
    NodeCount As Long
    Nodes() As BoundNode
    EntrySymbol As Long
    PackageSymbol As Long
    ModuleSymbols() As Long
End Type

Private Type BindingState
    Buckets() As Long
    NextSymbol() As Long
    Regions() As String
    ConstantState() As Long
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
        If Kind = "function" Or Kind = "sub" Then Visibility = "public" Else Visibility = "private"
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
        If Parsed.Nodes(Node).Kind = "module" Or Parsed.Nodes(Node).Kind = "sub" Or Parsed.Nodes(Node).Kind = "function" Then Scope = Bound.Nodes(Node).SymbolIndex
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
            If Kind = "sub" Or Kind = "function" Or Kind = "variable" Or Kind = "constant" Then
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
        Receiver = ResolveReference(Project, Parsed, Bound, State, Parsed.Nodes(Node).FirstChild, False, Diagnostic)
        If Receiver = 0 Then Exit Function
        Kind = Bound.Symbols(Receiver).Kind
        If Kind = "package" Then
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
        If Parsed.Nodes(Node).TypeName <> Bound.Symbols(Symbol).TypeName Then
            Call BindingError(Project, Parsed, Node, Diagnostic, "E_TYPE", "identifier suffix must agree with the selected declaration type")
            Exit Function
        End If
    End If
    Bound.Nodes(Node).TypeName = Bound.Symbols(Symbol).TypeName
    Kind = Bound.Symbols(Symbol).Kind
    Bound.Nodes(Node).Writable = (Kind = "variable" Or Kind = "parameter" Or Kind = "result")
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
End Sub

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
    Bound.Nodes(Node).TypeName = Bound.Symbols(Symbol).TypeName
    If Kind = "sub" Then Bound.Nodes(Node).TypeName = "Void"
    Parameter = Bound.Symbols(Symbol).FirstParameter
    Argument = Parsed.Nodes(Callee).NextSibling
    Do While Argument <> 0
        If Not BindExpression(Project, Parsed, Bound, State, Argument, 0, Diagnostic, Bound.Symbols(Parameter).TypeName) Then Exit Function
        If Bound.Symbols(Parameter).PassingMode = "ByVal" Then
            Bound.Nodes(Argument).ArgumentMode = "value"
            If Not ConvertValue(Project, Parsed, Bound, Argument, Bound.Symbols(Parameter).TypeName, Diagnostic) Then Exit Function
        ElseIf Parsed.Nodes(Argument).Kind = "group" Then
            Bound.Nodes(Argument).ArgumentMode = "temp"
            If Not ConvertValue(Project, Parsed, Bound, Argument, Bound.Symbols(Parameter).TypeName, Diagnostic) Then Exit Function
        Else
            ActualSymbol = Bound.Nodes(Argument).SymbolIndex
            If Not Bound.Nodes(Argument).Writable Or ActualSymbol = 0 Then
                BindCall = BindingError(Project, Parsed, Argument, Diagnostic, "E_ARGUMENT", "direct ByRef requires writable caller storage")
                Exit Function
            End If
            If Bound.Symbols(ActualSymbol).Kind <> "variable" And Bound.Symbols(ActualSymbol).Kind <> "parameter" Then
                BindCall = BindingError(Project, Parsed, Argument, Diagnostic, "E_ARGUMENT", "direct ByRef cannot alias this result or property")
                Exit Function
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
        ElseIf Kind <> "variable" And Kind <> "parameter" And Kind <> "property" Then
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
        Value = Parsed.Nodes(Node).FirstChild
        If Value = 0 Then
            BindAssignment = True
            Exit Function
        End If
    Else
        Target = Parsed.Nodes(Node).FirstChild
        Value = Parsed.Nodes(Target).NextSibling
        Symbol = ResolveReference(Project, Parsed, Bound, State, Target, True, Diagnostic)
        If Symbol = 0 Then Exit Function
        If Not Bound.Nodes(Target).Writable Then
            BindAssignment = BindingError(Project, Parsed, Target, Diagnostic, "E_TYPE", "assignment requires writable scalar storage")
            Exit Function
        End If
        Bound.Nodes(Node).SymbolIndex = Symbol
    End If
    TypeName = Bound.Symbols(Symbol).TypeName
    If Not BindExpression(Project, Parsed, Bound, State, Value, 0, Diagnostic, TypeName) Then Exit Function
    If Not ConvertValue(Project, Parsed, Bound, Value, TypeName, Diagnostic) Then Exit Function
    Bound.Nodes(Node).TypeName = TypeName
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
    State.ProjectName = Project.ProjectName
    Bound.NodeCount = Parsed.NodeCount
    If Not CollectDeclarations(Project, Parsed, Bound, State, Diagnostic) Then GoTo Rejected
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

' Exposes declaration identity and trusted binding roles for acceptance assertions.
Public Function FormatSymbol(ByRef Bound As BoundProject, ByVal Index As Long) As String
    If Index < 1 Or Index > Bound.SymbolCount Then Exit Function
    With Bound.Symbols(Index)
        FormatSymbol = "SYMBOL " & CStr(Index) & "|" & .Kind & "|" & BoundText(.Name) & "|" & .TypeName & "|" & .Visibility & "|" & CStr(.ModuleIndex) & "|" & CStr(.ScopeSymbol) & "|" & CStr(.DeclarationNode) & "|" & .PassingMode & "|" & .BindingId & "|" & CStr(.FirstParameter) & "|" & CStr(.NextParameter) & "|" & CStr(.ParameterCount) & "|" & ConstantText(.ConstantKnown, .ConstantValue)
    End With
End Function

' Exposes each retained source node's selected symbol, value type and call/conversion treatment.
Public Function FormatBinding(ByRef Bound As BoundProject, ByVal Index As Long) As String
    Dim Writable As String
    If Index < 1 Or Index > Bound.NodeCount Then Exit Function
    Writable = "0"
    If Bound.Nodes(Index).Writable Then Writable = "1"
    With Bound.Nodes(Index)
        FormatBinding = "BOUND " & CStr(Index) & "|" & CStr(.SymbolIndex) & "|" & .TypeName & "|" & .ConvertedType & "|" & .ArgumentMode & "|" & Writable & "|" & ConstantText(.ConstantKnown, .ConstantValue) & "|" & CStr(.ScopeSymbol)
    End With
End Function
