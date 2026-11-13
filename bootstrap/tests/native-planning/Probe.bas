UBE SOURCE 1 MODULE
Attribute UBE_Name = "PlanningProbe"
' Observes native storage, borrow-slot and initialization plans over runtime source files.
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
Private Symbols() As DeclarationBinder.BoundSymbol
Private SymbolCount As Long
Private EntrySymbol As Long
Private Expressions() As ExpressionBinder.BoundExpression
Private ExpressionCount As Long
Private Plans() As NativePlanning.NativeSymbolPlan
Private Pins() As Long
Private Escapes() As NativeEscapes.EscapeFact
Private Dependencies() As Byte
Private Summary As NativePlanning.NativePlanSummary

' Rebuilds every input fact privately before invoking the scratch planner.
Public Function Bind(ByVal IsExecutable As Boolean) As Long
    On Error GoTo Failed
    If Not DeclarationBinder.TryBindDeclarations(Bytes, Tokens, Nodes, Modules, Counts, PackageName, IsExecutable, Symbols, SymbolCount, EntrySymbol, Diagnostic) Then Bind = 101: Exit Function
    If Not ExpressionBinder.TryBindExpressions(Bytes, Tokens, Nodes, Modules, Counts, PackageName, IsExecutable, Expressions, ExpressionCount, Diagnostic) Then Bind = 102: Exit Function
    If Not AggregateLayout.TryLayout(Bytes, Tokens, Nodes, Modules, Counts, PackageName, IsExecutable, Layout, LayoutCount, Diagnostic) Then Bind = 103: Exit Function
    If Not PrimitiveRoles.TryBindPrimitives(Bytes, Tokens, Nodes, Modules, Counts, PackageName, IsExecutable, Roles, RoleCount, Diagnostic) Then Bind = 104: Exit Function
    If Not NativePlanning.TryPlanNative(Bytes, Tokens, Nodes, Modules, Counts, Symbols, SymbolCount, Expressions, Layout, Roles, EntrySymbol, IsExecutable, Plans, Pins, Escapes, Dependencies, Summary, Diagnostic) Then Bind = 1
    Exit Function
Failed:
    Bind = 105
End Function

' Locates actual declaration identities from original source positions rather than symbol order.
Public Function FindSymbol(ByVal ModuleIndex As Long, ByVal NameOffset As Long, ByVal Kind As Long) As Long
    Dim Index As Long
    Dim Found As Long
    Do While Index < SymbolCount
        If Symbols(Index).ModuleIndex = ModuleIndex And Symbols(Index).Kind = Kind Then
            If Tokens(Symbols(Index).NameToken).ByteStart - Modules(ModuleIndex).ByteBase = NameOffset Then
                If Found <> 0 Then FindSymbol = -1: Exit Function
                Found = Index + 1
            End If
        End If
        Index = Index + 1
    Loop
    FindSymbol = Found
End Function

' Locates an indexed expression from its physical source span.
Public Function FindNode(ByVal ModuleIndex As Long, ByVal Kind As Long, ByVal Start As Long, ByVal Length As Long) As Long
    Dim Index As Long
    Dim Finish As Long
    Index = Modules(ModuleIndex).NodeBase
    Finish = Index + Modules(ModuleIndex).NodeCount
    Do While Index < Finish
        If Nodes(Index).Kind = Kind And Nodes(Index).ByteStart - Modules(ModuleIndex).ByteBase = Start And Nodes(Index).ByteLength = Length Then FindNode = Index + 1: Exit Function
        Index = Index + 1
    Loop
End Function

' Reads independently expected symbol planning facts.
Public Function PlanField(ByVal Symbol As Long, ByVal Field As Long) As Long
    If Field = 0 Then PlanField = Plans(Symbol - 1).ContextOffset
    If Field = 1 Then PlanField = Plans(Symbol - 1).FrameCells
    If Field = 2 Then PlanField = Plans(Symbol - 1).PinCount
    If Field = 3 Then PlanField = Plans(Symbol - 1).ResultSymbol
    If Field = 4 And Plans(Symbol - 1).StorageEscapes Then PlanField = 1
    If Field = 5 Then PlanField = Plans(Symbol - 1).TemporaryOwnerCount
End Function

' Checks each scope chain against an independent ascending scan of validated declaration ownership.
Public Function CheckScopeLists() As Long
    Dim Scope As Long = 1
    Dim Index As Long
    Dim Linked As Long
    Do While Scope <= SymbolCount
        Linked = Plans(Scope - 1).FirstScopeSymbol
        Index = 1
        Do While Index <= SymbolCount
            If Symbols(Index - 1).ScopeSymbol = Scope Then
                If Linked <> Index Then CheckScopeLists = 1: Exit Function
                Linked = Plans(Linked - 1).NextScopeSymbol
            End If
            Index = Index + 1
        Loop
        If Linked <> 0 Then CheckScopeLists = 2: Exit Function
        Scope = Scope + 1
    Loop
End Function

' Reads reusable borrow-slot assignments by syntax identity.
Public Function PinValue(ByVal Node As Long) As Long
    PinValue = Pins(Node - 1)
End Function

' Reads one row-major dependency without assuming machine pointer sizes.
Public Function Dependency(ByVal Origin As Long, ByVal Target As Long) As Long
    Dim Base As Long
    Dim Index As Long
    Do While Index < Origin
        Base = Base + Counts.ModuleCount
        Index = Index + 1
    Loop
    Dependency = Dependencies(Base + Target)
End Function

' Exposes the summary validity marker and complete context count.
Public Function SummaryField(ByVal Field As Long) As Long
    If Field = 0 Then SummaryField = Summary.SymbolCount
    If Field = 1 Then SummaryField = Summary.NodeCount
    If Field = 2 Then SummaryField = Summary.ModuleCount
    If Field = 3 Then SummaryField = Summary.ContextCells
    If Field = 4 Then SummaryField = Summary.EntrySymbol
End Function

' Reports located admission errors without interpreting their category in the observer.
Public Function DiagnosticField(ByVal Field As Long) As Long
    If Field = 0 Then DiagnosticField = Diagnostic.Code
    If Field = 1 Then DiagnosticField = Diagnostic.Reason
    If Field = 2 Then DiagnosticField = Diagnostic.ModuleIndex
    If Field = 3 Then DiagnosticField = Diagnostic.Node
    If Field = 4 Then DiagnosticField = Diagnostic.TokenIndex
    If Field = 5 Then DiagnosticField = Diagnostic.ByteOffset
    If Field = 6 Then DiagnosticField = Diagnostic.Utf16Offset
    If Field = 7 Then DiagnosticField = Diagnostic.Line
    If Field = 8 Then DiagnosticField = Diagnostic.Column
End Function

' Exercises explicit scalar preconditions only; scratch maps have no public atomic preservation promise.
Public Function RejectPreconditions() As Long
    If NativePlanning.TryPlanNative(Bytes, Tokens, Nodes, Modules, Counts, Symbols, 0, Expressions, Layout, Roles, EntrySymbol, False, Plans, Pins, Escapes, Dependencies, Summary, Diagnostic) Then RejectPreconditions = 1: Exit Function
    If Summary.SymbolCount <> 0 Or Summary.NodeCount <> 0 Or Summary.ModuleCount <> 0 Or Summary.ContextCells <> 0 Or Summary.EntrySymbol <> 0 Then RejectPreconditions = 2: Exit Function
    If Diagnostic.Code <> 9 Or Diagnostic.Reason <> 50 Then RejectPreconditions = 3
End Function

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
