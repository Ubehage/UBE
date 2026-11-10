UBE SOURCE 1 MODULE
Attribute UBE_Name = "StorageProbe"
' Observes versioned primitive identities and finite layout facts over runtime source files.
Private InputPath() As Byte
Private Source() As Byte
Private Bytes() As Byte
Private Tokens() As SourceScanner.SourceToken
Private Nodes() As SourceParser.SyntaxNode
Private Modules() As ProjectSyntax.ParsedModule
Private Counts As ProjectSyntax.ProjectCounts
Private ProjectError As ProjectSyntax.ProjectDiagnostic
Private PackageName() As Byte
Private Roles() As Long
Private RoleCount As Long
Private Layout() As AggregateLayout.StorageFact
Private LayoutCount As Long
Private Diagnostic As DeclarationBinder.BindingDiagnostic

' Measures the separately retained primitive output capacity.
Private Intrinsic Function RoleLength(ByRef Values() As Long) As Long
Attribute RoleLength.UBE_Primitive = "Array.Length"
End Function

' Measures the separately retained layout output capacity.
Private Intrinsic Function FactLength(ByRef Values() As AggregateLayout.StorageFact) As Long
Attribute FactLength.UBE_Primitive = "Array.Length"
End Function

' Allocates an exact counted path for the portable file reader.
Public Function ConfigurePath(ByVal Length As Long) As Long
    Dim Status As Boolean
    Status = BufferPrimitives.TryResizeBytes(InputPath, Length, False)
    If Status = False Then ConfigurePath = 1 Else ConfigurePath = 0
End Function

' Writes one runtime UTF-8 path byte.
Public Function SetPathByte(ByVal Index As Long, ByVal Value As Long) As Long
    InputPath(Index) = Value
    SetPathByte = 0
End Function

' Resets logical project input without modifying previously published output arrays.
Public Function ResetProject(ByVal Length As Long) As Long
    Dim Status As Boolean
    Counts.ModuleCount = 0
    Counts.ByteCount = 0
    Counts.TokenCount = 0
    Counts.NodeCount = 0
    Status = BufferPrimitives.TryResizeBytes(PackageName, Length, False)
    If Status = False Then ResetProject = 1 Else ResetProject = 0
End Function

' Installs the independent package identity bytes.
Public Function SetPackageByte(ByVal Index As Long, ByVal Value As Long) As Long
    PackageName(Index) = Value
    SetPackageByte = 0
End Function

' Reads, scans, parses and appends one source module through production code.
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

' Invokes one independent production semantic pass against the complete project input.
Public Function Bind(ByVal Mode As Long, ByVal IsExecutable As Boolean) As Long
    Dim Status As Boolean
    If Mode = 0 Then
        Status = PrimitiveRoles.TryBindPrimitives(Bytes, Tokens, Nodes, Modules, Counts, PackageName, IsExecutable, Roles, RoleCount, Diagnostic)
    Else
        Status = AggregateLayout.TryLayout(Bytes, Tokens, Nodes, Modules, Counts, PackageName, IsExecutable, Layout, LayoutCount, Diagnostic)
    End If
    If Status = False Then Bind = 1 Else Bind = 0
End Function

' Returns the logical published count for one pass.
Public Function OutputCount(ByVal Mode As Long) As Long
    If Mode = 0 Then OutputCount = RoleCount Else OutputCount = LayoutCount
End Function

' Measures output backing capacity even after a failed pass reset its logical count.
Public Function RetainedCount(ByVal Mode As Long) As Long
    If Mode = 0 Then RetainedCount = RoleLength(Roles) Else RetainedCount = FactLength(Layout)
End Function

' Finds an independently authored name position without assuming node allocation order.
Public Function FindSymbol(ByVal ModuleIndex As Long, ByVal NameOffset As Long, ByVal Kind As Long) As Long
    Dim Index As Long
    Dim Finish As Long
    Dim NameIndex As Long
    Dim Found As Long
    Index = Modules(ModuleIndex).NodeBase
    Finish = Index + Modules(ModuleIndex).NodeCount
    Do While Index < Finish
        If Nodes(Index).Kind = Kind Then
            NameIndex = Nodes(Index).NameToken
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

' Reads the role at a syntax declaration identity, never inferring authority from spelling.
Public Function RoleValue(ByVal Identity As Long) As Long
    RoleValue = Roles(Identity - 1)
End Function

' Finds an exact expression span independently of global node allocation order.
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

' Verifies that primitive authority is published only on procedure declarations.
Public Function InvalidRolePlacements() As Long
    Dim Index As Long
    Dim InvalidCount As Long
    Do While Index < RoleCount
        If Roles(Index) <> 0 Then
            If Nodes(Index).Kind <> SourceParser.FunctionNode And Nodes(Index).Kind <> SourceParser.SubNode Then InvalidCount = InvalidCount + 1
        End If
        Index = Index + 1
    Loop
    InvalidRolePlacements = InvalidCount
End Function

' Reads one finite-layout fact in the private cell representation.
Public Function LayoutField(ByVal Identity As Long, ByVal Field As Long) As Long
    If Field = 0 Then LayoutField = Layout(Identity - 1).ElementCells: Exit Function
    If Field = 1 Then LayoutField = Layout(Identity - 1).StorageCells: Exit Function
    If Field = 2 Then LayoutField = Layout(Identity - 1).FieldOffset: Exit Function
    Err.Raise 5
End Function

' Reports the first controlled semantic failure with its original source coordinates.
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

' Exposes parse-stage rejection when a source body is not admitted into the project.
Public Function ProjectDiagnosticField(ByVal Field As Long) As Long
    If Field = 0 Then ProjectDiagnosticField = ProjectError.Stage: Exit Function
    If Field = 1 Then ProjectDiagnosticField = ProjectError.Code: Exit Function
    If Field = 2 Then ProjectDiagnosticField = ProjectError.Reason: Exit Function
End Function

' Mutates shape metadata while retaining an otherwise connected input tree.
Public Function CorruptShape(ByVal Mode As Long) As Long
    Dim Index As Long
    Dim FixedShape As Long
    Dim ParameterShape As Long
    Dim FixedOwner As Long
    Dim ParameterOwner As Long
    Do While Index < Counts.NodeCount
        If Nodes(Index).Kind = SourceParser.ArrayShapeNode Then
            If Nodes(Index).Value = 1 And FixedShape = 0 Then FixedShape = Index + 1
            If Nodes(Nodes(Index).Parent - 1).Kind = SourceParser.ParameterNode And ParameterShape = 0 Then ParameterShape = Index + 1
        End If
        Index = Index + 1
    Loop
    If FixedShape = 0 Then CorruptShape = 1: Exit Function
    If Mode = 1 Then Nodes(FixedShape - 1).Value = 3: CorruptShape = 0: Exit Function
    If Mode = 3 Then Nodes(FixedShape - 1).Value = 2: CorruptShape = 0: Exit Function
    If ParameterShape = 0 Then CorruptShape = 2: Exit Function
    FixedOwner = Nodes(FixedShape - 1).Parent
    ParameterOwner = Nodes(ParameterShape - 1).Parent
    Nodes(FixedOwner - 1).FirstChild = ParameterShape
    Nodes(FixedOwner - 1).LastChild = ParameterShape
    Nodes(ParameterOwner - 1).FirstChild = FixedShape
    Nodes(ParameterOwner - 1).LastChild = FixedShape
    Nodes(FixedShape - 1).Parent = ParameterOwner
    Nodes(ParameterShape - 1).Parent = FixedOwner
    If Mode = 4 Then Nodes(FixedShape - 1).Value = 2
    CorruptShape = 0
End Function

' Preserves tree links while placing a primitive attribute outside any procedure.
Public Function CorruptPrimitivePlacement() As Long
    Dim Index As Long
    Do While Index < Counts.NodeCount
        If Nodes(Index).Kind = SourceParser.VariableNode Then
            Nodes(Index).Kind = SourceParser.PrimitiveNode
            CorruptPrimitivePlacement = 0
            Exit Function
        End If
        Index = Index + 1
    Loop
    CorruptPrimitivePlacement = 1
End Function
