UBE SOURCE 1 MODULE
Attribute UBE_Name = "ExpressionProbe"
' Observes retained expression facts over actual file, syntax and declaration inputs.
Private InputPath() As Byte
Private Source() As Byte
Private Bytes() As Byte
Private Tokens() As SourceScanner.SourceToken
Private Nodes() As SourceParser.SyntaxNode
Private Modules() As ProjectSyntax.ParsedModule
Private Counts As ProjectSyntax.ProjectCounts
Private ProjectError As ProjectSyntax.ProjectDiagnostic
Private PackageName() As Byte
Private Symbols() As DeclarationBinder.BoundSymbol
Private SymbolCount As Long
Private EntrySymbol As Long
Private Diagnostic As DeclarationBinder.BindingDiagnostic
Private Bindings() As ExpressionBinder.BoundExpression
Private BindingCount As Long
Private EscapeFacts() As NativeEscapes.EscapeFact
Private EscapeCount As Long

' Runs ownership propagation only after successful ordinary expression binding.
Public Function AnalyzeEscapes() As Long
    If NativeEscapes.TryAnalyzeEscapes(Nodes, Symbols, Bindings, Counts.NodeCount, SymbolCount, EscapeFacts, EscapeCount, Diagnostic) = False Then AnalyzeEscapes = 1
End Function

' Observes declaration storage promotion independently of argument ownership classification.
Public Function EscapingSymbol(ByVal Symbol As Long) As Boolean
    EscapingSymbol = EscapeFacts(Symbols(Symbol - 1).DeclarationNode - 1).StorageEscapes
End Function

' Reads the explicit ownership obligation for one actual argument.
Public Function EscapeField(ByVal Node As Long, ByVal Field As Long) As Long
    If Field = 0 Then
        If EscapeFacts(Node - 1).NeedsOwner Then EscapeField = 1
    End If
    If Field = 1 Then EscapeField = EscapeFacts(Node - 1).OwnerKind
    If Field = 2 Then EscapeField = EscapeFacts(Node - 1).OwnerIdentity
End Function

' Measures retained expression storage after a failed candidate resets its logical count.
Private Intrinsic Function BindingLength(ByRef Values() As ExpressionBinder.BoundExpression) As Long
Attribute BindingLength.UBE_Primitive = "Array.Length"
End Function

' Prepares an independently allocated path buffer.
Public Function ConfigurePath(ByVal Length As Long) As Long
    Dim Status As Boolean
    Status = BufferPrimitives.TryResizeBytes(InputPath, Length, False)
    If Status = False Then ConfigurePath = 1 Else ConfigurePath = 0
End Function

' Installs a runtime path byte without storing a native pointer in UBE source.
Public Function SetPathByte(ByVal Index As Long, ByVal Value As Long) As Long
    InputPath(Index) = Value
    SetPathByte = 0
End Function

' Resets logical project input while leaving older bound output independently owned.
Public Function ResetProject(ByVal NameLength As Long) As Long
    Dim Status As Boolean
    Counts.ModuleCount = 0
    Counts.ByteCount = 0
    Counts.TokenCount = 0
    Counts.NodeCount = 0
    Status = BufferPrimitives.TryResizeBytes(PackageName, NameLength, False)
    If Status = False Then ResetProject = 1 Else ResetProject = 0
End Function

' Supplies a counted ASCII package name separately from module source identity.
Public Function SetPackageByte(ByVal Index As Long, ByVal Value As Long) As Long
    PackageName(Index) = Value
    SetPackageByte = 0
End Function

' Reads and appends one complete module through the production storage pipeline.
Public Function AppendFile() As Long
    Dim Status As Boolean
    Dim Token As Long
    Dim Failure As Long
    On Error GoTo Failed
    Status = FileBytes.TryReadAllBytes(InputPath, 1048576, Source, Token, Failure)
    If Status = False Then
        Status = FilePrimitives.TryClose(Token, Failure)
        AppendFile = 1
        Exit Function
    End If
    Status = ProjectSyntax.TryAppendModule(Source, Bytes, Tokens, Nodes, Modules, Counts, ProjectError)
    If Status = False Then AppendFile = 2 Else AppendFile = 0
    Exit Function
Failed:
    AppendFile = 3
End Function

' Runs actual expression binding and separately exposes the deterministic declaration identities.
Public Function Bind(ByVal IsExecutable As Boolean) As Long
    Dim Status As Boolean
    Status = DeclarationBinder.TryBindDeclarations(Bytes, Tokens, Nodes, Modules, Counts, PackageName, IsExecutable, Symbols, SymbolCount, EntrySymbol, Diagnostic)
    Status = ExpressionBinder.TryBindExpressions(Bytes, Tokens, Nodes, Modules, Counts, PackageName, IsExecutable, Bindings, BindingCount, Diagnostic)
    If Status = False Then Bind = 1 Else Bind = 0
End Function

' Exposes the published logical expression count independently of retained backing storage.
Public Function CountBindings() As Long
    CountBindings = BindingCount
End Function

' Measures older expression output even when a failed candidate publishes no new count.
Public Function RetainedBindings() As Long
    RetainedBindings = BindingLength(Bindings)
End Function

' Locates one authored syntactic span within its original module, independent of global IDs.
Public Function FindNode(ByVal ModuleIndex As Long, ByVal Kind As Long, ByVal Start As Long, ByVal Length As Long) As Long
    Dim Index As Long
    Dim Finish As Long
    Dim Found As Long
    Index = Modules(ModuleIndex).NodeBase
    Finish = Index + Modules(ModuleIndex).NodeCount
    Do While Index < Finish
        If Nodes(Index).Kind = Kind And Nodes(Index).ByteStart - Modules(ModuleIndex).ByteBase = Start And Nodes(Index).ByteLength = Length Then
            If Found <> 0 Then FindNode = -1: Exit Function
            Found = Index + 1
        End If
        Index = Index + 1
    Loop
    FindNode = Found
End Function

' Reads typed binding facts without reconstructing name resolution or constant evaluation.
Public Function BindingField(ByVal Identity As Long, ByVal Field As Long) As Long
    Dim Index As Long
    Index = Identity - 1
    If Field = 0 Then BindingField = Bindings(Index).SymbolIndex: Exit Function
    If Field = 1 Then BindingField = Bindings(Index).ScopeSymbol: Exit Function
    If Field = 2 Then BindingField = Bindings(Index).TypeCode: Exit Function
    If Field = 3 Then BindingField = Bindings(Index).TypeSymbol: Exit Function
    If Field = 4 Then BindingField = Bindings(Index).ArrayRank: Exit Function
    If Field = 5 Then BindingField = Bindings(Index).ConvertedType: Exit Function
    If Field = 6 Then BindingField = Bindings(Index).ArgumentMode: Exit Function
    If Field = 7 Then BindingField = Bindings(Index).Writable: Exit Function
    If Field = 8 Then BindingField = Bindings(Index).ConstantKnown: Exit Function
    If Field = 9 Then BindingField = Bindings(Index).AccessKind: Exit Function
    If Field = 10 Then BindingField = Bindings(Index).TrustedRole: Exit Function
    If Field = 11 Then BindingField = Bindings(Index).HasBounds: Exit Function
    Err.Raise 5
End Function

' Returns exact signed 64-bit constant bits through the normal LongLong result ABI.
Public Function BindingValue(ByVal Identity As Long) As LongLong
    BindingValue = Bindings(Identity - 1).ConstantValue
End Function

' Exposes signed array bounds independently of the host's integer width.
Public Function BindingBound(ByVal Identity As Long, ByVal Upper As Boolean) As LongLong
    If Upper Then BindingBound = Bindings(Identity - 1).UpperBound Else BindingBound = Bindings(Identity - 1).LowerBound
End Function

' Mutates one caller-owned input fact to exercise bounded rejection before publication.
Public Function CorruptProject(ByVal Mode As Long) As Long
    Dim Child As Long
    Child = Nodes(Modules(0).RootNode - 1).FirstChild
    If Mode = 1 Then Tokens(0).ByteStart = -1
    If Mode = 2 Then Tokens(0).ByteStart = Counts.ByteCount + 1
    If Mode = 3 Then Nodes(Child - 1).NextSibling = Child
    If Mode = 4 Then Nodes(Child - 1).Parent = Child
    If Mode = 5 Then Modules(0).TokenCount = Counts.TokenCount + 1
    If Mode = 6 Then PackageName(0) = 49
    CorruptProject = 0
End Function

' Locates a declaration using its original module-local name position and kind.
Public Function FindSymbol(ByVal ModuleIndex As Long, ByVal NameOffset As Long, ByVal Kind As Long) As Long
    Dim Index As Long
    Dim NameIndex As Long
    Dim Found As Long
    Do While Index < SymbolCount
        If Symbols(Index).ModuleIndex = ModuleIndex And Symbols(Index).Kind = Kind Then
            NameIndex = Symbols(Index).NameToken
            If NameIndex >= 0 Then
                If Tokens(NameIndex).ByteStart - Modules(ModuleIndex).ByteBase = NameOffset Then
                    If Found <> 0 Then FindSymbol = -1: Exit Function
                    Found = Index + 1
                End If
            End If
        End If
        Index = Index + 1
    Loop
    FindSymbol = Found
End Function

' Exposes first-failure location and category without reconstructing diagnostics.
Public Function DiagnosticField(ByVal Field As Long) As Long
    If Field = 0 Then DiagnosticField = Diagnostic.Code: Exit Function
    If Field = 1 Then DiagnosticField = Diagnostic.Reason: Exit Function
    If Field = 2 Then DiagnosticField = Diagnostic.ModuleIndex: Exit Function
    If Field = 3 Then DiagnosticField = Diagnostic.Node: Exit Function
    If Field = 4 Then DiagnosticField = Diagnostic.TokenIndex: Exit Function
    If Field = 5 Then DiagnosticField = Diagnostic.ByteOffset: Exit Function
    If Field = 6 Then DiagnosticField = Diagnostic.Utf16Offset: Exit Function
    If Field = 7 Then DiagnosticField = Diagnostic.Line: Exit Function
    If Field = 8 Then DiagnosticField = Diagnostic.Column: Exit Function
    Err.Raise 5
End Function
