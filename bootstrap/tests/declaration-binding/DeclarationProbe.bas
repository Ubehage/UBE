UBE SOURCE 1 MODULE
Attribute UBE_Name = "DeclarationProbe"
' Observes caller-owned declaration identities over real scanned and parsed module files.
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

' Reads the committed project node prefix after successful or refused appends.
Public Function CountNodes() As Long
    CountNodes = Counts.NodeCount
End Function

' Distinguishes cumulative capacity refusal from scanner, parser or allocation errors.
Public Function AppendLimitDiagnostic() As Long
    If ProjectError.Stage <> 3 Or ProjectError.Code <> 4 Then AppendLimitDiagnostic = 1
End Function

' Measures retained symbol storage even after a failed binding resets its count.
Private Intrinsic Function SymbolLength(ByRef Values() As DeclarationBinder.BoundSymbol) As Long
Attribute SymbolLength.UBE_Primitive = "Array.Length"
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

' Runs declaration binding without inspecting or executing source expressions.
Public Function Bind(ByVal IsExecutable As Boolean) As Long
    Dim Status As Boolean
    Status = DeclarationBinder.TryBindDeclarations(Bytes, Tokens, Nodes, Modules, Counts, PackageName, IsExecutable, Symbols, SymbolCount, EntrySymbol, Diagnostic)
    If Status = False Then Bind = 1 Else Bind = 0
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

' Exposes successful logical count independently of retained backing capacity.
Public Function CountSymbols() As Long
    CountSymbols = SymbolCount
End Function

' Exposes the selected entry declaration identity, or zero for a Library.
Public Function EntryIdentity() As Long
    EntryIdentity = EntrySymbol
End Function

' Measures preserved backing storage after failed candidate publication.
Public Function RetainedCount() As Long
    RetainedCount = SymbolLength(Symbols)
End Function

' Reads scalar binding metadata by stable field number for native assertions.
Public Function SymbolField(ByVal Identity As Long, ByVal Field As Long) As Long
    Dim Index As Long
    Index = Identity - 1
    If Field = 0 Then SymbolField = Symbols(Index).ModuleIndex: Exit Function
    If Field = 1 Then SymbolField = Symbols(Index).ScopeSymbol: Exit Function
    If Field = 2 Then SymbolField = Symbols(Index).DeclarationNode: Exit Function
    If Field = 3 Then SymbolField = Symbols(Index).NameToken: Exit Function
    If Field = 4 Then SymbolField = Symbols(Index).Kind: Exit Function
    If Field = 5 Then SymbolField = Symbols(Index).Region: Exit Function
    If Field = 6 Then SymbolField = Symbols(Index).Visibility: Exit Function
    If Field = 7 Then SymbolField = Symbols(Index).TypeCode: Exit Function
    If Field = 8 Then SymbolField = Symbols(Index).TypeSymbol: Exit Function
    If Field = 9 Then SymbolField = Symbols(Index).ArrayRank: Exit Function
    If Field = 10 Then SymbolField = Symbols(Index).PassingMode: Exit Function
    If Field = 11 Then SymbolField = Symbols(Index).FirstParameter: Exit Function
    If Field = 12 Then SymbolField = Symbols(Index).NextParameter: Exit Function
    If Field = 13 Then SymbolField = Symbols(Index).ParameterCount: Exit Function
    If Field = 14 Then SymbolField = Symbols(Index).FirstField: Exit Function
    If Field = 15 Then SymbolField = Symbols(Index).NextField: Exit Function
    Err.Raise 5
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
