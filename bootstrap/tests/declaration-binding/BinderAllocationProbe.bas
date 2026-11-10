UBE SOURCE 1 MODULE
Attribute UBE_Name = "BinderAllocationProbe"
' Observes declaration publication and cleanup independently of allocation failures.
Private Bytes() As Byte
Private Tokens() As SourceScanner.SourceToken
Private Nodes() As SourceParser.SyntaxNode
Private Modules() As ProjectSyntax.ParsedModule
Private Counts As ProjectSyntax.ProjectCounts
Private PackageName() As Byte
Private Symbols() As DeclarationBinder.BoundSymbol
Private SymbolCount As Long
Private EntrySymbol As Long
Private Diagnostic As DeclarationBinder.BindingDiagnostic

Private Intrinsic Function ResizeSymbols(ByRef Values() As DeclarationBinder.BoundSymbol, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeSymbols.UBE_Primitive = "Array.TryResize"
End Function

Private Intrinsic Function SymbolLength(ByRef Values() As DeclarationBinder.BoundSymbol) As Long
Attribute SymbolLength.UBE_Primitive = "Array.Length"
End Function

' Creates a complete input and distinctive old output before target fault injection.
Public Function Prepare(ByRef Data() As Byte) As Long
    Dim Status As Boolean
    Dim InputError As ProjectSyntax.ProjectDiagnostic
    On Error GoTo Failed
    Status = ProjectSyntax.TryAppendModule(Data, Bytes, Tokens, Nodes, Modules, Counts, InputError)
    If Status = False Then Prepare = 1: Exit Function
    Status = BufferPrimitives.TryResizeBytes(PackageName, 6, False)
    If Status = False Then Prepare = 2: Exit Function
    PackageName(0) = 83
    PackageName(1) = 97
    PackageName(2) = 109
    PackageName(3) = 112
    PackageName(4) = 108
    PackageName(5) = 101
    Status = ResizeSymbols(Symbols, 1, False)
    If Status = False Then Prepare = 3: Exit Function
    Symbols(0).ModuleIndex = 101
    Symbols(0).ScopeSymbol = 102
    Symbols(0).DeclarationNode = 103
    Symbols(0).NameToken = 104
    Symbols(0).Kind = 105
    Symbols(0).Region = 106
    Symbols(0).Visibility = 107
    Symbols(0).TypeCode = 108
    Symbols(0).TypeSymbol = 109
    Symbols(0).ArrayRank = 110
    Symbols(0).PassingMode = 111
    Symbols(0).FirstParameter = 112
    Symbols(0).NextParameter = 113
    Symbols(0).ParameterCount = 114
    Symbols(0).FirstField = 115
    Symbols(0).NextField = 116
    SymbolCount = 777
    EntrySymbol = 888
    Err.Clear
    Prepare = 0
    Exit Function
Failed:
    Prepare = 99
End Function

Private Function OldOutput() As Boolean
    On Error GoTo Failed
    If SymbolLength(Symbols) <> 1 Then OldOutput = False: Exit Function
    If Symbols(0).ModuleIndex <> 101 Then OldOutput = False: Exit Function
    If Symbols(0).ScopeSymbol <> 102 Then OldOutput = False: Exit Function
    If Symbols(0).DeclarationNode <> 103 Then OldOutput = False: Exit Function
    If Symbols(0).NameToken <> 104 Then OldOutput = False: Exit Function
    If Symbols(0).Kind <> 105 Then OldOutput = False: Exit Function
    If Symbols(0).Region <> 106 Then OldOutput = False: Exit Function
    If Symbols(0).Visibility <> 107 Then OldOutput = False: Exit Function
    If Symbols(0).TypeCode <> 108 Then OldOutput = False: Exit Function
    If Symbols(0).TypeSymbol <> 109 Then OldOutput = False: Exit Function
    If Symbols(0).ArrayRank <> 110 Then OldOutput = False: Exit Function
    If Symbols(0).PassingMode <> 111 Then OldOutput = False: Exit Function
    If Symbols(0).FirstParameter <> 112 Then OldOutput = False: Exit Function
    If Symbols(0).NextParameter <> 113 Then OldOutput = False: Exit Function
    If Symbols(0).ParameterCount <> 114 Then OldOutput = False: Exit Function
    If Symbols(0).FirstField <> 115 Then OldOutput = False: Exit Function
    If Symbols(0).NextField <> 116 Then OldOutput = False: Exit Function
    OldOutput = True
    Exit Function
Failed:
    OldOutput = False
End Function

Public Function RejectAllocation() As Long
    Dim Status As Boolean
    On Error GoTo Failed
    Status = DeclarationBinder.TryBindDeclarations(Bytes, Tokens, Nodes, Modules, Counts, PackageName, False, Symbols, SymbolCount, EntrySymbol, Diagnostic)
    If Status Then RejectAllocation = 1: Exit Function
    If SymbolCount <> 0 Or EntrySymbol <> 0 Then RejectAllocation = 2: Exit Function
    If Diagnostic.Code <> 7 Then RejectAllocation = 3: Exit Function
    If Err.Number <> 7 Then RejectAllocation = 4: Exit Function
    If OldOutput() = False Then RejectAllocation = 5: Exit Function
    RejectAllocation = 0
    Exit Function
Failed:
    RejectAllocation = 99
End Function

Public Function RetryBind() As Long
    Dim Status As Boolean
    On Error GoTo Failed
    Status = DeclarationBinder.TryBindDeclarations(Bytes, Tokens, Nodes, Modules, Counts, PackageName, False, Symbols, SymbolCount, EntrySymbol, Diagnostic)
    If Status = False Then RetryBind = 1: Exit Function
    If SymbolCount <> 303 Or EntrySymbol <> 0 Then RetryBind = 2: Exit Function
    If SymbolLength(Symbols) <> 512 Then RetryBind = 3: Exit Function
    If Symbols(0).Kind <> SourceParser.ModuleNode Then RetryBind = 4: Exit Function
    If Diagnostic.Code <> 0 Or Err.Number <> 7 Then RetryBind = 5: Exit Function
    RetryBind = 0
    Exit Function
Failed:
    RetryBind = 99
End Function

Public Function DepthAttempt() As Boolean
    On Error GoTo Failed
    DepthAttempt = DeclarationBinder.TryBindDeclarations(Bytes, Tokens, Nodes, Modules, Counts, PackageName, False, Symbols, SymbolCount, EntrySymbol, Diagnostic)
    Exit Function
Failed:
    DepthAttempt = False
End Function

Public Function CheckDepth(ByVal Success As Boolean) As Long
    On Error GoTo Failed
    If Success Then
        If SymbolCount <> 303 Or EntrySymbol <> 0 Then CheckDepth = 1: Exit Function
        If SymbolLength(Symbols) <> 512 Or Diagnostic.Code <> 0 Then CheckDepth = 2: Exit Function
    Else
        If Err.Number <> 28 Then CheckDepth = 3: Exit Function
        If OldOutput() = False Then CheckDepth = 4: Exit Function
        If Diagnostic.Code = 0 Then
            If SymbolCount <> 777 Or EntrySymbol <> 888 Then CheckDepth = 5: Exit Function
        Else
            If SymbolCount <> 0 Or EntrySymbol <> 0 Then CheckDepth = 6: Exit Function
            If Diagnostic.Line < 1 Or Diagnostic.Column < 1 Or Diagnostic.ByteOffset < 0 Then CheckDepth = 7: Exit Function
        End If
    End If
    CheckDepth = 0
    Exit Function
Failed:
    CheckDepth = 99
End Function
