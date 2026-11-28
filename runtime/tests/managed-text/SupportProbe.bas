UBE SOURCE 1 MODULE
Attribute UBE_Name = "SupportProbe"
' Executes role binding against independently supplied source and trusted domain inputs.

Private Intrinsic Function ResizeModules(ByRef Values() As ProjectSyntax.ParsedModule, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeModules.UBE_Primitive = "Array.TryResize"
End Function

Private Intrinsic Function SpanCount(ByRef Values() As Long) As Long
Attribute SpanCount.UBE_Primitive = "Array.Length"
End Function

Public Function CheckAsset(ByRef Bytes() As Byte, ByVal Identity As Long, ByVal Expected As Boolean) As Long
    If ManagedSourceAssets.Validate(Bytes, Identity) <> Expected Then CheckAsset = 1
End Function

Public Function CheckProjectAssets(ByRef Bytes() As Byte, ByRef Starts() As Long, ByRef Sizes() As Long, ByVal Mode As Long, ByVal Expected As Boolean) As Long
    Dim Modules() As ProjectSyntax.ParsedModule
    Dim Counts As ProjectSyntax.ProjectCounts
    Dim Index As Long
    Dim BadModule As Long
    Dim Count As Long
    Count = SpanCount(Starts)
    If Not ResizeModules(Modules, Count, False) Then CheckProjectAssets = 3: Exit Function
    Counts.ModuleCount = Count
    Counts.ByteCount = BufferPrimitives.ByteStorageLength(Bytes)
    Do While Index < Count
        Modules(Index).LookupDomain = 1
        Modules(Index).ByteBase = Starts(Index)
        Modules(Index).ByteCount = Sizes(Index)
        If Mode = 9 Then Modules(Index).LookupDomain = 0
        Index = Index + 1
    Loop
    If Mode = 1 Then Modules(0).LookupDomain = 2
    If Mode = 2 Then Modules(0).ByteBase = -1
    If Mode = 3 Then Modules(0).ByteCount = Counts.ByteCount + 1
    If Mode = 4 Then Counts.ModuleCount = Count - 1
    If Mode = 5 Then Counts.ModuleCount = Count + 1
    If Mode = 6 Then Modules(0).ByteBase = Counts.ByteCount + 1
    If Mode = 7 Then Modules(0).ByteBase = Starts(1): Modules(0).ByteCount = Sizes(1)
    If Mode = 8 Then Modules(0).LookupDomain = 0
    If Mode = 10 Then Counts.ByteCount = Counts.ByteCount + 1
    If Mode = 11 Then Modules(0).ByteCount = -1
    If ManagedSourceAssets.ValidateProject(Bytes, Modules, Counts, BadModule) <> Expected Then CheckProjectAssets = 1: Exit Function
    If Expected And BadModule <> -1 Then CheckProjectAssets = 2
End Function

Public Function CheckNeed(ByRef Source() As Byte, ByVal Expected As Boolean) As Long
    Dim Bytes() As Byte
    Dim Tokens() As SourceScanner.SourceToken
    Dim Nodes() As SourceParser.SyntaxNode
    Dim Modules() As ProjectSyntax.ParsedModule
    Dim Counts As ProjectSyntax.ProjectCounts
    Dim Diagnostic As ProjectSyntax.ProjectDiagnostic
    If Not ProjectSyntax.TryAppendModule(Source, Bytes, Tokens, Nodes, Modules, Counts, Diagnostic) Then CheckNeed = 1: Exit Function
    If ManagedSupport.NeedsSource(Bytes, Tokens, Nodes, Counts) <> Expected Then CheckNeed = 2
End Function

Private Function RoleSymbol(ByRef Plan As ManagedSupport.RolePlan, ByVal Index As Long) As Long
    If Index = 0 Then RoleSymbol = Plan.ConcatSymbol
    If Index = 1 Then RoleSymbol = Plan.CompareBinarySymbol
    If Index = 2 Then RoleSymbol = Plan.FromIntegerSymbol
    If Index = 3 Then RoleSymbol = Plan.FromBooleanSymbol
    If Index = 4 Then RoleSymbol = Plan.ToIntegerSymbol
    If Index = 5 Then RoleSymbol = Plan.ToBooleanSymbol
    If Index = 6 Then RoleSymbol = Plan.FromUtf8Symbol
    If Index = 7 Then RoleSymbol = Plan.CollectSymbol
    If Index = 8 Then RoleSymbol = Plan.FromFloatingSymbol
    If Index = 9 Then RoleSymbol = Plan.ToFloatingSymbol
    If Index = 10 Then RoleSymbol = Plan.PowerSymbol
End Function

Private Function SamePlan(ByRef First As ManagedSupport.RolePlan, ByRef Second As ManagedSupport.RolePlan) As Boolean
    SamePlan = First = Second
End Function

Public Function Check(ByRef PublicSource() As Byte, ByRef TextSource() As Byte, ByRef CollectorSource() As Byte, ByRef PowerSource() As Byte, ByRef PublicationSource() As Byte, ByRef Expected() As Long, ByVal Domain As Long, ByVal Reason As Long) As Long
    Dim Bytes() As Byte
    Dim Tokens() As SourceScanner.SourceToken
    Dim Nodes() As SourceParser.SyntaxNode
    Dim Modules() As ProjectSyntax.ParsedModule
    Dim Counts As ProjectSyntax.ProjectCounts
    Dim InputError As ProjectSyntax.ProjectDiagnostic
    Dim Symbols() As DeclarationBinder.BoundSymbol
    Dim SymbolCount As Long
    Dim EntrySymbol As Long
    Dim PackageName(0 To 0) As Byte
    Dim Diagnostic As DeclarationBinder.BindingDiagnostic
    Dim Plan As ManagedSupport.RolePlan
    Dim Before As ManagedSupport.RolePlan
    Dim Status As Boolean
    Dim Index As Long
    Dim Symbol As Long
    On Error GoTo Failed
    PackageName(0) = 80
    If Not ProjectSyntax.TryAppendModule(PublicSource, Bytes, Tokens, Nodes, Modules, Counts, InputError) Then Check = 1: Exit Function
    If BufferPrimitives.ByteStorageLength(TextSource) > 0 Then
        If Not ProjectSyntax.TryAppendModuleInDomain(TextSource, Domain, Bytes, Tokens, Nodes, Modules, Counts, InputError) Then Check = 2: Exit Function
    End If
    If BufferPrimitives.ByteStorageLength(CollectorSource) > 0 Then
        If Not ProjectSyntax.TryAppendModuleInDomain(CollectorSource, Domain, Bytes, Tokens, Nodes, Modules, Counts, InputError) Then Check = 3: Exit Function
    End If
    If BufferPrimitives.ByteStorageLength(PowerSource) > 0 Then
        If Not ProjectSyntax.TryAppendModuleInDomain(PowerSource, Domain, Bytes, Tokens, Nodes, Modules, Counts, InputError) Then Check = 19: Exit Function
    End If
    If BufferPrimitives.ByteStorageLength(PublicationSource) > 0 Then
        If Not ProjectSyntax.TryAppendModuleInDomain(PublicationSource, Domain, Bytes, Tokens, Nodes, Modules, Counts, InputError) Then Check = 21: Exit Function
    End If
    Status = DeclarationBinder.TryBindDeclarations(Bytes, Tokens, Nodes, Modules, Counts, PackageName, False, Symbols, SymbolCount, EntrySymbol, Diagnostic)
    If Reason = -1 Then
        If Status Or Diagnostic.Code = 0 Then Check = 20
        Exit Function
    End If
    If Not Status Then Check = 4: Exit Function
    Plan.ConcatSymbol = 777
    Plan.CollectSymbol = 888
    Plan.PublishTextSymbol = 999
    Before = Plan
    Status = ManagedSupport.TryResolve(Bytes, Tokens, Nodes, Modules, Counts, Symbols, SymbolCount, Plan, Diagnostic)
    If Reason <> 0 Then
        If Status Or Diagnostic.Code <> 8 Or Diagnostic.Reason <> Reason Then Check = 5: Exit Function
        If Not SamePlan(Plan, Before) Then Check = 6: Exit Function
    Else
        If Not Status Or Diagnostic.Code <> 0 Then Check = 7: Exit Function
        If Plan.ConcatSymbol = 0 Then
            If Plan.PublishTextSymbol <> 0 Then Check = 22: Exit Function
        Else
            Symbol = Plan.PublishTextSymbol
            If Symbol < 1 Or Symbol > SymbolCount Then Check = 23: Exit Function
            If Symbols(Symbol - 1).ModuleIndex <> Counts.ModuleCount - 1 Or Symbols(Symbol - 1).LookupDomain <> 1 Then Check = 24: Exit Function
        End If
        Do While Index < 11
            Symbol = RoleSymbol(Plan, Index)
            If Symbol <> Expected(Index) Then Check = 8 + Index: Exit Function
            If Symbol > 0 Then
                If Symbol > SymbolCount Then Check = 16: Exit Function
                If Symbols(Symbol - 1).LookupDomain <> 1 Then Check = 17: Exit Function
            End If
            Index = Index + 1
        Loop
    End If
    Exit Function
Failed:
    Check = 18
End Function
