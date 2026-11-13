UBE SOURCE 1 MODULE
Attribute UBE_Name = "IntrinsicProbe"
' Validates runtime-loaded declarations before invoking the actual intrinsic emitter.
Private OutputPath() As Byte
Private CatalogPath() As Byte
Private SourcePath() As Byte

' Allocates one independent runtime path.
Public Function ConfigurePath(ByVal Kind As Long, ByVal Count As Long) As Boolean
    If Kind = 0 Then ConfigurePath = BufferPrimitives.TryResizeBytes(OutputPath, Count, False)
    If Kind = 1 Then ConfigurePath = BufferPrimitives.TryResizeBytes(CatalogPath, Count, False)
    If Kind = 2 Then ConfigurePath = BufferPrimitives.TryResizeBytes(SourcePath, Count, False)
End Function

' Supplies each byte without source-level managed strings.
Public Sub SetPathByte(ByVal Kind As Long, ByVal Index As Long, ByVal Value As Byte)
    If Kind = 0 Then OutputPath(Index) = Value
    If Kind = 1 Then CatalogPath(Index) = Value
    If Kind = 2 Then SourcePath(Index) = Value
End Sub

' Reads, parses and validates one complete declaration corpus before writing wrappers.
Public Function Emit() As Long
    Dim Source() As Byte
    Dim Bytes() As Byte
    Dim Tokens() As SourceScanner.SourceToken
    Dim Nodes() As SourceParser.SyntaxNode
    Dim Modules() As ProjectSyntax.ParsedModule
    Dim Counts As ProjectSyntax.ProjectCounts
    Dim ProjectDiagnostic As ProjectSyntax.ProjectDiagnostic
    Dim Symbols() As DeclarationBinder.BoundSymbol
    Dim SymbolCount As Long
    Dim EntrySymbol As Long
    Dim Layout() As AggregateLayout.StorageFact
    Dim LayoutCount As Long
    Dim Roles() As Long
    Dim RoleCount As Long
    Dim Diagnostic As DeclarationBinder.BindingDiagnostic
    Dim Package(0 To 0) As Byte
    Dim State As LLVMWriter.WriterState
    Dim Buffer() As Byte
    Dim Catalog() As Byte
    Dim Token As Long
    Dim Failure As Long
    Dim Result As Long
    On Error GoTo Failed
    Package(0) = 80
    If FileBytes.TryReadAllBytes(SourcePath, 1048576, Source, Token, Failure) = False Then Emit = 1: Exit Function
    If ProjectSyntax.TryAppendModule(Source, Bytes, Tokens, Nodes, Modules, Counts, ProjectDiagnostic) = False Then Emit = 2: Exit Function
    If DeclarationBinder.TryBindDeclarations(Bytes, Tokens, Nodes, Modules, Counts, Package, False, Symbols, SymbolCount, EntrySymbol, Diagnostic) = False Then Emit = 3: Exit Function
    If PrimitiveRoles.TryBindPrimitives(Bytes, Tokens, Nodes, Modules, Counts, Package, False, Roles, RoleCount, Diagnostic) = False Then Emit = 4: Exit Function
    If AggregateLayout.TryLayout(Bytes, Tokens, Nodes, Modules, Counts, Package, False, Layout, LayoutCount, Diagnostic) = False Then Emit = 5: Exit Function
    If FileBytes.TryReadAllBytes(CatalogPath, 1048576, Catalog, Token, Failure) = False Then Emit = 6: Exit Function
    If LLVMFormat.TryValidateCatalog(Catalog) = False Then Emit = 7: Exit Function
    If FilePrimitives.TryCreateNew(OutputPath, Token, Failure) = False Then Emit = 8: Exit Function
    If LLVMWriter.TryInitialize(State, Buffer) = False Then Result = 9: GoTo Cleanup
    If NativeIntrinsics.TryEmit(Symbols, SymbolCount, Layout, Roles, State, Buffer, Token, Catalog) = False Then Result = 10: GoTo Cleanup
    If LLVMWriter.TryFinish(State, Buffer, Token) = False Then Result = 11: GoTo Cleanup
Cleanup:
    If FilePrimitives.TryClose(Token, Failure) = False Then Emit = 12: Exit Function
    Emit = Result
    Exit Function
Failed:
    Result = 13
    GoTo Cleanup
End Function
