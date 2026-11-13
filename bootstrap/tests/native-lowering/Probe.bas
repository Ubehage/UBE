UBE SOURCE 1 MODULE
Attribute UBE_Name = "LoweringProbe"
' Loads real source modules and invokes the complete UBE lowering entry point into a private file.
Private OutputPath() As Byte
Private CatalogPath() As Byte
Private SourcePath() As Byte
Private RuntimePath() As Byte
Private Bytes() As Byte
Private Tokens() As SourceScanner.SourceToken
Private Nodes() As SourceParser.SyntaxNode
Private Modules() As ProjectSyntax.ParsedModule
Private Counts As ProjectSyntax.ProjectCounts
Private ProjectError As ProjectSyntax.ProjectDiagnostic
Private Diagnostic As DeclarationBinder.BindingDiagnostic
Private Package(0 To 0) As Byte
Private EntryIdentity As Long

' Receives counted paths for output, catalog, source and runtime support.
Public Function ConfigurePath(ByVal Kind As Long, ByVal Count As Long) As Boolean
    If Kind = 0 Then ConfigurePath = BufferPrimitives.TryResizeBytes(OutputPath, Count, False)
    If Kind = 1 Then ConfigurePath = BufferPrimitives.TryResizeBytes(CatalogPath, Count, False)
    If Kind = 2 Then ConfigurePath = BufferPrimitives.TryResizeBytes(SourcePath, Count, False)
    If Kind = 3 Then ConfigurePath = BufferPrimitives.TryResizeBytes(RuntimePath, Count, False)
End Function

' Supplies path bytes without relying on a managed-string runtime.
Public Sub SetPathByte(ByVal Kind As Long, ByVal Index As Long, ByVal Value As Byte)
    If Kind = 0 Then OutputPath(Index) = Value
    If Kind = 1 Then CatalogPath(Index) = Value
    If Kind = 2 Then SourcePath(Index) = Value
    If Kind = 3 Then RuntimePath(Index) = Value
End Sub

' Starts a fresh logical input while retaining owned scratch capacities.
Public Sub ResetProject()
    Counts.ByteCount = 0
    Counts.TokenCount = 0
    Counts.NodeCount = 0
    Counts.ModuleCount = 0
    EntryIdentity = 0
    Package(0) = 80
End Sub

' Reads, scans and parses one original UTF-8 module in input order.
Public Function AppendSource() As Long
    Dim Source() As Byte
    Dim Token As Long
    Dim Failure As Long
    On Error GoTo Failed
    If Not FileBytes.TryReadAllBytes(SourcePath, 1048576, Source, Token, Failure) Then
        If Not FilePrimitives.TryClose(Token, Failure) Then AppendSource = 101: Exit Function
        AppendSource = 102
        Exit Function
    End If
    If Not ProjectSyntax.TryAppendModule(Source, Bytes, Tokens, Nodes, Modules, Counts, ProjectError) Then AppendSource = 200 + ProjectError.Code
    Exit Function
Failed:
    AppendSource = 300
End Function

' Finds the test bridge's last source procedure through UBE declarations, not host symbol numbers.
Private Function FindEntry() As Boolean
    Dim Symbols() As DeclarationBinder.BoundSymbol
    Dim SymbolCount As Long
    Dim MainSymbol As Long
    Dim Index As Long
    On Error GoTo Failed
    If Not DeclarationBinder.TryBindDeclarations(Bytes, Tokens, Nodes, Modules, Counts, Package, False, Symbols, SymbolCount, MainSymbol, Diagnostic) Then Exit Function
    Do While Index < SymbolCount
        If Symbols(Index).ModuleIndex = Counts.ModuleCount - 1 And Symbols(Index).Kind = SourceParser.FunctionNode Then EntryIdentity = Index + 1
        Index = Index + 1
    Loop
    FindEntry = EntryIdentity > 0
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Emits complete IR only through production UBE lowering; failed private files are never used as output.
Public Function Emit(ByVal IsExecutable As Boolean) As Long
    Dim State As NativeEmission.EmissionState
    Dim Catalog() As Byte
    Dim RuntimeText() As Byte
    Dim Token As Long
    Dim Failure As Long
    Dim Result As Long
    On Error GoTo Failed
    If Not FileBytes.TryReadAllBytes(CatalogPath, 1048576, Catalog, Token, Failure) Then Result = 1: GoTo Cleanup
    If Not FileBytes.TryReadAllBytes(RuntimePath, 1048576, RuntimeText, Token, Failure) Then Result = 2: GoTo Cleanup
    If Not FilePrimitives.TryCreateNew(OutputPath, Token, Failure) Then Result = 3: GoTo Cleanup
    If Not NativeLowering.TryEmit(Bytes, Tokens, Nodes, Modules, Counts, Package, IsExecutable, Catalog, RuntimeText, Token, State, Diagnostic) Then Result = 10000 + Diagnostic.Reason: GoTo Cleanup
    If Not IsExecutable Then
        If Not FindEntry() Then Result = 4: GoTo Cleanup
    End If
Cleanup:
    If Not FilePrimitives.TryClose(Token, Failure) Then Emit = 5: Exit Function
    Emit = Result
    Exit Function
Failed:
    Result = 6
    GoTo Cleanup
End Function

' Exposes a freshly bound bridge identity solely to the test harness.
Public Function EntrySymbol() As Long
    EntrySymbol = EntryIdentity
End Function

' Exposes the original located diagnostic when the integration driver rejects private output.
Public Function DiagnosticField(ByVal Field As Long) As Long
    If Field = 0 Then DiagnosticField = Diagnostic.Code
    If Field = 1 Then DiagnosticField = Diagnostic.Reason
    If Field = 2 Then DiagnosticField = Diagnostic.ModuleIndex
    If Field = 3 Then DiagnosticField = Diagnostic.Line
End Function
