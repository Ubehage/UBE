UBE SOURCE 1 MODULE
Attribute UBE_Name = "EscapeAllocationProbe"
' Exercises escape-plan publication with the shared allocation-failure harness.
Private Bytes() As Byte
Private Tokens() As SourceScanner.SourceToken
Private Nodes() As SourceParser.SyntaxNode
Private Modules() As ProjectSyntax.ParsedModule
Private Counts As ProjectSyntax.ProjectCounts
Private PackageName() As Byte
Private Symbols() As DeclarationBinder.BoundSymbol
Private SymbolCount As Long
Private EntrySymbol As Long
Private Expressions() As ExpressionBinder.BoundExpression
Private ExpressionCount As Long
Private Facts() As NativeEscapes.EscapeFact
Private FactCount As Long
Private Diagnostic As DeclarationBinder.BindingDiagnostic

Private Intrinsic Function ResizeFacts(ByRef Values() As NativeEscapes.EscapeFact, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeFacts.UBE_Primitive = "Array.TryResize"
End Function

Private Intrinsic Function FactLength(ByRef Values() As NativeEscapes.EscapeFact) As Long
Attribute FactLength.UBE_Primitive = "Array.Length"
End Function

Public Function Prepare(ByRef Data() As Byte) As Long
    Dim InputError As ProjectSyntax.ProjectDiagnostic
    On Error GoTo Failed
    If ProjectSyntax.TryAppendModule(Data, Bytes, Tokens, Nodes, Modules, Counts, InputError) = False Then Prepare = 1: Exit Function
    If BufferPrimitives.TryResizeBytes(PackageName, 6, False) = False Then Prepare = 2: Exit Function
    PackageName(0) = 83
    PackageName(1) = 97
    PackageName(2) = 109
    PackageName(3) = 112
    PackageName(4) = 108
    PackageName(5) = 101
    If DeclarationBinder.TryBindDeclarations(Bytes, Tokens, Nodes, Modules, Counts, PackageName, False, Symbols, SymbolCount, EntrySymbol, Diagnostic) = False Then Prepare = 3: Exit Function
    If ExpressionBinder.TryBindExpressions(Bytes, Tokens, Nodes, Modules, Counts, PackageName, False, Expressions, ExpressionCount, Diagnostic) = False Then Prepare = 4: Exit Function
    If ResizeFacts(Facts, 1, False) = False Then Prepare = 5: Exit Function
    Facts(0).StorageEscapes = True
    Facts(0).NeedsOwner = True
    Facts(0).OwnerKind = 101
    Facts(0).OwnerIdentity = 102
    FactCount = 777
    Err.Clear
    Exit Function
Failed:
    Prepare = 99
End Function

Private Function OldOutput() As Boolean
    On Error GoTo Failed
    If FactLength(Facts) <> 1 Then Exit Function
    If Facts(0).StorageEscapes <> True Or Facts(0).NeedsOwner <> True Then Exit Function
    If Facts(0).OwnerKind <> 101 Or Facts(0).OwnerIdentity <> 102 Then Exit Function
    OldOutput = True
    Exit Function
Failed:
    OldOutput = False
End Function

Public Function RejectAllocation() As Long
    On Error GoTo Failed
    If NativeEscapes.TryAnalyzeEscapes(Nodes, Symbols, Expressions, Counts.NodeCount, SymbolCount, Facts, FactCount, Diagnostic) Then RejectAllocation = 1: Exit Function
    If FactCount <> 0 Then RejectAllocation = 2: Exit Function
    If Diagnostic.Code <> 7 Then RejectAllocation = 3: Exit Function
    If Err.Number <> 7 Then RejectAllocation = 4: Exit Function
    If OldOutput() = False Then RejectAllocation = 5
    Exit Function
Failed:
    RejectAllocation = 99
End Function

Public Function RetryBind(ByVal ExpectedError As Long) As Long
    On Error GoTo Failed
    If NativeEscapes.TryAnalyzeEscapes(Nodes, Symbols, Expressions, Counts.NodeCount, SymbolCount, Facts, FactCount, Diagnostic) = False Then RetryBind = 1: Exit Function
    If FactCount <> Counts.NodeCount Then RetryBind = 2: Exit Function
    If FactLength(Facts) <> Counts.NodeCount Then RetryBind = 3: Exit Function
    If Diagnostic.Code <> 0 Or Err.Number <> ExpectedError Then RetryBind = 5
    Exit Function
Failed:
    RetryBind = 99
End Function

Public Function DepthAttempt() As Boolean
    On Error GoTo Failed
    DepthAttempt = NativeEscapes.TryAnalyzeEscapes(Nodes, Symbols, Expressions, Counts.NodeCount, SymbolCount, Facts, FactCount, Diagnostic)
    Exit Function
Failed:
    DepthAttempt = False
End Function

Public Function CheckDepth(ByVal Success As Boolean) As Long
    On Error GoTo Failed
    If Success Then
        If FactCount <> Counts.NodeCount Or FactLength(Facts) <> Counts.NodeCount Or Diagnostic.Code <> 0 Then CheckDepth = 1
    Else
        If Err.Number <> 28 Then CheckDepth = 3: Exit Function
        If OldOutput() = False Then CheckDepth = 4: Exit Function
        If Diagnostic.Code = 0 Then
            If FactCount <> 777 Then CheckDepth = 5
        Else
            If FactCount <> 0 Then CheckDepth = 6
        End If
    End If
    Exit Function
Failed:
    CheckDepth = 99
End Function
