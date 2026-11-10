UBE SOURCE 1 MODULE
Attribute UBE_Name = "LayoutAllocationProbe"
' Observes atomic semantic publication independently of allocator failures.
Private Bytes() As Byte
Private Tokens() As SourceScanner.SourceToken
Private Nodes() As SourceParser.SyntaxNode
Private Modules() As ProjectSyntax.ParsedModule
Private Counts As ProjectSyntax.ProjectCounts
Private PackageName() As Byte
Private Bindings() As AggregateLayout.StorageFact
Private BindingCount As Long
Private Diagnostic As DeclarationBinder.BindingDiagnostic

Private Intrinsic Function ResizeBindings(ByRef Values() As AggregateLayout.StorageFact, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeBindings.UBE_Primitive = "Array.TryResize"
End Function

Private Intrinsic Function BindingLength(ByRef Values() As AggregateLayout.StorageFact) As Long
Attribute BindingLength.UBE_Primitive = "Array.Length"
End Function

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
    Status = ResizeBindings(Bindings, 1, False)
    If Status = False Then Prepare = 3: Exit Function
    Bindings(0).ElementCells = 101
    Bindings(0).StorageCells = 102
    Bindings(0).FieldOffset = 103
    BindingCount = 777
    Err.Clear
    Prepare = 0
    Exit Function
Failed:
    Prepare = 99
End Function

Private Function OldOutput() As Boolean
    On Error GoTo Failed
    If BindingLength(Bindings) <> 1 Then OldOutput = False: Exit Function
    If Bindings(0).ElementCells <> 101 Or Bindings(0).StorageCells <> 102 Or Bindings(0).FieldOffset <> 103 Then OldOutput = False: Exit Function
    OldOutput = True
    Exit Function
Failed:
    OldOutput = False
End Function

Public Function RejectAllocation() As Long
    Dim Status As Boolean
    On Error GoTo Failed
    Status = AggregateLayout.TryLayout(Bytes, Tokens, Nodes, Modules, Counts, PackageName, False, Bindings, BindingCount, Diagnostic)
    If Status Then RejectAllocation = 1: Exit Function
    If BindingCount <> 0 Then RejectAllocation = 2: Exit Function
    If Diagnostic.Code <> 7 Then RejectAllocation = 3: Exit Function
    If Err.Number <> 7 Then RejectAllocation = 4: Exit Function
    If OldOutput() = False Then RejectAllocation = 5: Exit Function
    RejectAllocation = 0
    Exit Function
Failed:
    RejectAllocation = 99
End Function

' Checks publication and sticky error independently of the separate semantic oracle.
Public Function RetryBind(ByVal ExpectedError As Long) As Long
    Dim Status As Boolean
    On Error GoTo Failed
    Status = AggregateLayout.TryLayout(Bytes, Tokens, Nodes, Modules, Counts, PackageName, False, Bindings, BindingCount, Diagnostic)
    If Status = False Then RetryBind = 1: Exit Function
    If BindingCount <> Counts.NodeCount Then RetryBind = 2: Exit Function
    If BindingLength(Bindings) <> Counts.NodeCount Then RetryBind = 3: Exit Function
    If Diagnostic.Code <> 0 Or Err.Number <> ExpectedError Then RetryBind = 5: Exit Function
    RetryBind = 0
    Exit Function
Failed:
    RetryBind = 99
End Function

Public Function DepthAttempt() As Boolean
    On Error GoTo Failed
    DepthAttempt = AggregateLayout.TryLayout(Bytes, Tokens, Nodes, Modules, Counts, PackageName, False, Bindings, BindingCount, Diagnostic)
    Exit Function
Failed:
    DepthAttempt = False
End Function

Public Function CheckDepth(ByVal Success As Boolean) As Long
    On Error GoTo Failed
    If Success Then
        If BindingCount <> Counts.NodeCount Then CheckDepth = 1: Exit Function
        If BindingLength(Bindings) <> Counts.NodeCount Or Diagnostic.Code <> 0 Then CheckDepth = 2: Exit Function
    Else
        If Err.Number <> 28 Then CheckDepth = 3: Exit Function
        If OldOutput() = False Then CheckDepth = 4: Exit Function
        If Diagnostic.Code = 0 Then
            If BindingCount <> 777 Then CheckDepth = 5: Exit Function
        Else
            If BindingCount <> 0 Then CheckDepth = 6: Exit Function
            If Diagnostic.Line < 1 Or Diagnostic.Column < 1 Or Diagnostic.ByteOffset < 0 Then CheckDepth = 7: Exit Function
        End If
    End If
    CheckDepth = 0
    Exit Function
Failed:
    CheckDepth = 99
End Function
