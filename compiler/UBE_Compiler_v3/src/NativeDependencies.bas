UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeDependencies"

' Private checked-source warning discovery. Owners and bounds are described in
' NATIVE-WARNING-IMPLEMENTATION.md. Checked source/catalog/targets are borrowed
' unchanged. No name resolution, syntax-sized index or public graph is created.
' Status 0 unused, 2 complete, 4 failed. Dispose even after partial failure.
Type NativeDependencyProcedure
    Root As Long
    Seen As Long
    QueuedDeclaration As Long
End Type
Type NativeDependencyFormal
    Seen As Long
    FirstEdge As Long
    QueuedParameter As Long
End Type
Type NativeDependencyEdge
    Target As Long
    NextEdge As Long
    SourceId As Long
    FirstByte As Long
    LastByte As Long
    TargetModule As Long
End Type
Type NativeDependencies
    Procedures() As NativeDependencyProcedure
    Formals() As NativeDependencyFormal
    Edges() As NativeDependencyEdge
    Arguments() As Long
    Cursor As NativeTraversal
    ProcedureCapacity As Long
    FormalCapacity As Long
    EdgeCapacity As Long
    ArgumentCapacity As Long
    EdgeCount As Long
    ProcedureHead As Long
    ProcedureTail As Long
    FormalHead As Long
    FormalTail As Long
    RootModule As Long
    Status As Long
End Type
Private Intrinsic Function TryResizeDependencyProcedures(ByRef Values() As NativeDependencyProcedure, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeDependencyProcedures.UBE_Primitive = "Array.TryResize"
End Function
Private Intrinsic Function TryResizeDependencyFormals(ByRef Values() As NativeDependencyFormal, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeDependencyFormals.UBE_Primitive = "Array.TryResize"
End Function
Private Intrinsic Function TryResizeDependencyEdges(ByRef Values() As NativeDependencyEdge, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeDependencyEdges.UBE_Primitive = "Array.TryResize"
End Function
Private Intrinsic Function DependencyModulesLength(ByRef Values() As SemanticModuleResult) As Long
Attribute DependencyModulesLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function DependencySourcesLength(ByRef Values() As SemanticSource) As Long
Attribute DependencySourcesLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function DependencyValuesLength(ByRef Values() As BoundNode) As Long
Attribute DependencyValuesLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function DependencyFactsLength(ByRef Values() As SemanticFact) As Long
Attribute DependencyFactsLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function DependencySyntaxLength(ByRef Values() As SyntaxResult) As Long
Attribute DependencySyntaxLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function DependencyNodesLength(ByRef Values() As SyntaxNode) As Long
Attribute DependencyNodesLength.UBE_Primitive = "Array.Length"
End Function

Private Function TryDependencyVisit(ByRef Writer As NativeLLVMWriter) As Boolean
    TryDependencyVisit = TryVisitNativeIndex(Writer.Limits, Writer.Usage, Writer.Cancellation, Writer.Failure)
End Function
Private Function TryDependencyReserve(ByVal Bytes As LongLong, ByRef Writer As NativeLLVMWriter) As Boolean
    TryDependencyReserve = False
    Call ResetNativeFailure(Writer.Failure)
    If TryContinueNativeOutput(Writer.Cancellation, Writer.Failure) = False Then
        Exit Function
    End If
    TryDependencyReserve = TryChargeNativeResource(Writer.Limits, Writer.Usage, 1, Bytes, Writer.Failure)
End Function

Private Function TryBeginDependencyStorage(ByRef State As NativeDependencies, ByRef Declarations As NativeDeclarationPlan, ByRef Writer As NativeLLVMWriter) As Boolean
    TryBeginDependencyStorage = False
    Call ResetNativeFailure(Writer.Failure)
    Dim Bytes As LongLong = Declarations.FrameCount
    Bytes = Bytes * 12
    If TryDependencyReserve(Bytes, Writer) = False Then
        Exit Function
    End If
    Dim Cleanup As NativeFailure
    If TryResizeDependencyProcedures(State.Procedures, Declarations.FrameCount, False) = False Then
        Call TryReleaseNativeResource(Writer.Usage, 1, Bytes, Cleanup)
        Writer.Failure.Code = 1502
        Writer.Failure.Resource = 1
        Exit Function
    End If
    State.ProcedureCapacity = Declarations.FrameCount
    Bytes = Declarations.ByRefCount
    Bytes = Bytes * 12
    Call ResetNativeFailure(Writer.Failure)
    If TryDependencyReserve(Bytes, Writer) = False Then
        Exit Function
    End If
    If TryResizeDependencyFormals(State.Formals, Declarations.ByRefCount, False) = False Then
        Call TryReleaseNativeResource(Writer.Usage, 1, Bytes, Cleanup)
        Writer.Failure.Code = 1502
        Writer.Failure.Resource = 1
        Exit Function
    End If
    State.FormalCapacity = Declarations.ByRefCount
    Call ResetNativeFailure(Writer.Failure)
    TryBeginDependencyStorage = TryContinueNativeOutput(Writer.Cancellation, Writer.Failure)
End Function

' These two variable-size owners grow independently. Charge old+new overlap;
' successful growth remains accounted even when the following poll fails.
Private Function TryDependencyArguments(ByRef State As NativeDependencies, ByVal Count As Long, ByRef Writer As NativeLLVMWriter) As Boolean
    TryDependencyArguments = False
    Call ResetNativeFailure(Writer.Failure)
    If Count < 0 Then
        Exit Function
    End If
    If Count > State.ArgumentCapacity Then
        Dim Capacity As Long = 0
        If TryGetStorageCapacity(State.ArgumentCapacity, Count, 2147483647, Capacity) = False Then
            Writer.Failure.Code = 1502
            Writer.Failure.Resource = 1
            Exit Function
        End If
        Dim Bytes As LongLong = Capacity
        Bytes = Bytes * 4
        If TryDependencyReserve(Bytes, Writer) = False Then
            Exit Function
        End If
        Dim Cleanup As NativeFailure
        If TryResizeSemanticLongs(State.Arguments, Capacity, False) = False Then
            Call TryReleaseNativeResource(Writer.Usage, 1, Bytes, Cleanup)
            Writer.Failure.Code = 1502
            Writer.Failure.Resource = 1
            Exit Function
        End If
        Bytes = State.ArgumentCapacity
        Bytes = Bytes * 4
        Call TryReleaseNativeResource(Writer.Usage, 1, Bytes, Cleanup)
        State.ArgumentCapacity = Capacity
        Call ResetNativeFailure(Writer.Failure)
        If TryContinueNativeOutput(Writer.Cancellation, Writer.Failure) = False Then
            Exit Function
        End If
    End If
    Dim Id As Long = 0
    While Id < Count
        Call ResetNativeFailure(Writer.Failure)
        If TryDependencyVisit(Writer) = False Then
            Exit Function
        End If
        State.Arguments(Id) = 0
        Id = Id + 1
    Wend
    Writer.Failure.Code = 0
    TryDependencyArguments = True
End Function

Private Function TryDependencyForward(ByRef State As NativeDependencies, ByVal FromParameter As Long, ByVal ToParameter As Long, ByVal TargetModule As Long, ByVal SourceId As Long, ByRef Span As NativeWarningSpan, ByRef Writer As NativeLLVMWriter) As Boolean
    TryDependencyForward = False
    Call ResetNativeFailure(Writer.Failure)
    If FromParameter < 0 Or FromParameter >= State.FormalCapacity Or ToParameter < 0 Or ToParameter >= State.FormalCapacity Then
        Exit Function
    End If
    If State.EdgeCount = 2147483647 Then
        Writer.Failure.Code = 1502
        Writer.Failure.Resource = 1
        Exit Function
    End If
    If State.EdgeCount = State.EdgeCapacity Then
        Dim Capacity As Long = 0
        If TryGetStorageCapacity(State.EdgeCapacity, State.EdgeCount + 1, 2147483647, Capacity) = False Then
            Writer.Failure.Code = 1502
            Writer.Failure.Resource = 1
            Exit Function
        End If
        Dim Bytes As LongLong = Capacity
        Bytes = Bytes * 24
        If TryDependencyReserve(Bytes, Writer) = False Then
            Exit Function
        End If
        Dim Cleanup As NativeFailure
        If TryResizeDependencyEdges(State.Edges, Capacity, True) = False Then
            Call TryReleaseNativeResource(Writer.Usage, 1, Bytes, Cleanup)
            Writer.Failure.Code = 1502
            Writer.Failure.Resource = 1
            Exit Function
        End If
        Bytes = State.EdgeCapacity
        Bytes = Bytes * 24
        Call TryReleaseNativeResource(Writer.Usage, 1, Bytes, Cleanup)
        State.EdgeCapacity = Capacity
        Call ResetNativeFailure(Writer.Failure)
        If TryContinueNativeOutput(Writer.Cancellation, Writer.Failure) = False Then
            Exit Function
        End If
    End If
    State.Edges(State.EdgeCount).Target = ToParameter
    State.Edges(State.EdgeCount).NextEdge = State.Formals(FromParameter).FirstEdge
    State.Edges(State.EdgeCount).SourceId = SourceId
    State.Edges(State.EdgeCount).FirstByte = Span.FirstByte
    State.Edges(State.EdgeCount).LastByte = Span.LastByte
    State.Edges(State.EdgeCount).TargetModule = TargetModule
    State.EdgeCount = State.EdgeCount + 1
    State.Formals(FromParameter).FirstEdge = State.EdgeCount
    Writer.Failure.Code = 0
    TryDependencyForward = True
End Function

Private Function TryDependencySeed(ByRef State As NativeDependencies, ByVal Parameter As Long, ByRef Writer As NativeLLVMWriter) As Boolean
    TryDependencySeed = False
    Call ResetNativeFailure(Writer.Failure)
    If Parameter < 0 Or Parameter >= State.FormalCapacity Then
        Exit Function
    End If
    If State.Formals(Parameter).Seen = 0 Then
        If State.FormalTail >= State.FormalCapacity Then
            Exit Function
        End If
        If TryChargeNativeResource(Writer.Limits, Writer.Usage, 4, 1, Writer.Failure) = False Then
            Exit Function
        End If
        State.Formals(State.FormalTail).QueuedParameter = Parameter
        State.FormalTail = State.FormalTail + 1
        State.Formals(Parameter).Seen = 1
    End If
    Writer.Failure.Code = 0
    TryDependencySeed = True
End Function

Private Function TryDependencyProcedure(ByRef State As NativeDependencies, ByRef Target As NativeDeclarationTarget, ByVal DeclarationId As Long, ByRef Writer As NativeLLVMWriter) As Boolean
    TryDependencyProcedure = False
    Call ResetNativeFailure(Writer.Failure)
    If Target.Role <> 0 Then
        Writer.Failure.Code = 0
        TryDependencyProcedure = True
        Exit Function
    End If
    Dim Index As Long = Target.FrameIndex
    If Index < 0 Or Index >= State.ProcedureCapacity Then
        Exit Function
    End If
    If State.Procedures(Index).Root <= 0 Then
        Exit Function
    End If
    If State.Procedures(Index).Seen = 0 Then
        If State.ProcedureTail >= State.ProcedureCapacity Then
            Exit Function
        End If
        If TryChargeNativeResource(Writer.Limits, Writer.Usage, 4, 1, Writer.Failure) = False Then
            Exit Function
        End If
        State.Procedures(State.ProcedureTail).QueuedDeclaration = DeclarationId
        State.ProcedureTail = State.ProcedureTail + 1
        State.Procedures(Index).Seen = 1
    End If
    Writer.Failure.Code = 0
    TryDependencyProcedure = True
End Function

Private Function TryDependencySpan(ByRef Catalog As SemanticCatalog, ByVal SourceId As Long, ByVal SyntaxId As Long, ByVal Assignment As Boolean, ByRef Span As NativeWarningSpan, ByRef Writer As NativeLLVMWriter) As Boolean
    TryDependencySpan = False
    Call ResetNativeFailure(Writer.Failure)
    If SourceId < 0 Or SourceId >= Catalog.SourceCount Then
        Exit Function
    End If
    If Catalog.Sources(SourceId) Is Nothing Then
        Exit Function
    End If
    If Catalog.Sources(SourceId).SyntaxInput Is Nothing Then
        Exit Function
    End If
    If Catalog.Sources(SourceId).SyntaxInput.Owner Is Nothing Then
        Exit Function
    End If
    If DependencySyntaxLength(Catalog.Sources(SourceId).SyntaxInput.Syntax) <> 1 Then
        Exit Function
    End If
    Dim Count As Long = Catalog.Sources(SourceId).SyntaxInput.Syntax(0).NodeCount
    If Count < 0 Or Count > DependencyNodesLength(Catalog.Sources(SourceId).SyntaxInput.Syntax(0).Nodes) Then
        Exit Function
    End If
    If SyntaxId < 0 Or SyntaxId >= Count Then
        Exit Function
    End If
    Dim Syntax As SyntaxNode
    Call ReadSyntaxNode(Syntax, Catalog.Sources(SourceId).SyntaxInput.Syntax(0).Nodes(SyntaxId))
    If Assignment Then
        If Syntax.FirstChild < 0 Or Syntax.FirstChild >= Count Then
            Exit Function
        End If
        Call ReadSyntaxNode(Syntax, Catalog.Sources(SourceId).SyntaxInput.Syntax(0).Nodes(Syntax.FirstChild))
    End If
    If Syntax.FirstByte < 0 Or Syntax.LastByte < Syntax.FirstByte Or Syntax.LastByte > ByteStorageLength(Catalog.Sources(SourceId).SyntaxInput.Owner.Document.Bytes) Then
        Exit Function
    End If
    Span.FirstByte = Syntax.FirstByte
    Span.LastByte = Syntax.LastByte
    Writer.Failure.Code = 0
    TryDependencySpan = True
End Function

Private Function TryDependencyRecord(ByRef State As NativeDependencies, ByRef Warnings As NativeWarningGraph, ByVal TargetModule As Long, ByVal SourceId As Long, ByRef Span As NativeWarningSpan, ByRef Writer As NativeLLVMWriter) As Boolean
    TryDependencyRecord = TryAddNativeWarningDependency(Warnings, State.RootModule, TargetModule, SourceId, Span.FirstByte, Span.LastByte, Writer.Limits, Writer.Usage, Writer.Cancellation, Writer.Failure)
End Function

Private Function TryDependencyCall(ByRef State As NativeDependencies, ByRef Module As SemanticModuleResult, ByRef Declarations As NativeDeclarationPlan, ByRef Warnings As NativeWarningGraph, ByRef Node As BoundNode, ByRef Writer As NativeLLVMWriter) As Boolean
    TryDependencyCall = False
    Call ResetNativeFailure(Writer.Failure)
    If Node.Target < 0 Or Node.Target >= Declarations.Count Or Node.Auxiliary < 0 Or Node.Auxiliary >= Module.FactCount Then
        Exit Function
    End If
    Dim Target As NativeDeclarationTarget
    Call ReadNativeDeclarationTarget(Target, Declarations.Targets(Node.Target))
    If Target.Kind <> 5 And Target.Kind <> 6 Then
        Exit Function
    End If
    Dim Span As NativeWarningSpan
    If TryDependencySpan(Module.Catalog, Node.SourceId, Node.SyntaxId, False, Span, Writer) = False Then
        Exit Function
    End If
    If Target.SourceId <> Module.SourceId Then
        Call ResetNativeFailure(Writer.Failure)
        If TryDependencyRecord(State, Warnings, Target.SourceId, Node.SourceId, Span, Writer) = False Then
            Exit Function
        End If
    End If
    Call ResetNativeFailure(Writer.Failure)
    If TryDependencyProcedure(State, Target, Node.Target, Writer) = False Then
        Exit Function
    End If
    Dim Header As SemanticFact
    Call ReadSemanticFact(Header, Module.Facts(Node.Auxiliary))
    Call ResetNativeFailure(Writer.Failure)
    If Header.Kind <> 5 Or Header.Target <> Node.Target Or Header.Right <> Node.ChildCount Or Header.Right < 0 Or Header.Auxiliary < 0 Or Header.Auxiliary > Header.Right Then
        Exit Function
    End If
    If Header.Right > 0 Then
        If Header.Left < 0 Or Header.Left > Module.FactCount - Header.Right Then
            Exit Function
        End If
    End If
    If TryDependencyArguments(State, Header.Auxiliary, Writer) = False Then
        Exit Function
    End If
    Dim Ordinal As Long = 0
    Dim Map As SemanticFact
    While Ordinal < Header.Right
        Call ResetNativeFailure(Writer.Failure)
        If TryDependencyVisit(Writer) = False Then
            Exit Function
        End If
        Call ReadSemanticFact(Map, Module.Facts(Header.Left + Ordinal))
        Call ResetNativeFailure(Writer.Failure)
        If Map.Kind <> 6 Or Map.Left <> Node.Auxiliary Or Map.Extra <> Ordinal Then
            Exit Function
        End If
        If Map.Right >= 0 Then
            If Map.Auxiliary < 0 Or Map.Auxiliary >= Header.Auxiliary Then
                Exit Function
            End If
            If State.Arguments(Map.Auxiliary) <> 0 Then
                Exit Function
            End If
            State.Arguments(Map.Auxiliary) = Header.Left + Ordinal + 1
        End If
        Ordinal = Ordinal + 1
    Wend
    Dim Child As Long = Node.FirstChild
    Ordinal = 0
    While Ordinal < Header.Auxiliary
        Call ResetNativeFailure(Writer.Failure)
        If TryDependencyVisit(Writer) = False Then
            Exit Function
        End If
        Call ResetNativeFailure(Writer.Failure)
        If State.Arguments(Ordinal) > 0 Then
            If Child < 0 Or Child >= Module.ValueCount Then
                Exit Function
            End If
            Call ReadSemanticFact(Map, Module.Facts(State.Arguments(Ordinal) - 1))
            If (Map.Flags And 3) = 1 Then
                Call ResetNativeFailure(Writer.Failure)
                If Map.Target < 0 Or Map.Target >= Declarations.Count Then
                    Exit Function
                End If
                Dim Parameter As NativeDeclarationTarget
                Call ReadNativeDeclarationTarget(Parameter, Declarations.Targets(Map.Target))
                If Parameter.Kind <> 4 Or Parameter.Scope <> Node.Target Or Parameter.ByRefIndex < 0 Then
                    Exit Function
                End If
                If Module.Values(Child).Kind <> 3 Or Module.Values(Child).Target < 0 Or Module.Values(Child).Target >= Declarations.Count Then
                    Exit Function
                End If
                Dim Actual As NativeDeclarationTarget
                Call ReadNativeDeclarationTarget(Actual, Declarations.Targets(Module.Values(Child).Target))
                If Actual.Kind = 2 And Actual.Scope >= 0 And Actual.Scope < Warnings.ModuleCount And Actual.SourceId = State.RootModule Then
                    If TryDependencySeed(State, Parameter.ByRefIndex, Writer) = False Then
                        Exit Function
                    End If
                    If Parameter.SourceId <> State.RootModule Then
                        Call ResetNativeFailure(Writer.Failure)
                        If TryDependencyRecord(State, Warnings, State.RootModule, Node.SourceId, Span, Writer) = False Then
                            Exit Function
                        End If
                    End If
                Else
                    If Actual.Kind = 4 And Actual.ByRefIndex >= 0 Then
                        If TryDependencyForward(State, Actual.ByRefIndex, Parameter.ByRefIndex, Parameter.SourceId, Node.SourceId, Span, Writer) = False Then
                            Exit Function
                        End If
                    End If
                End If
            End If
            Child = Module.Values(Child).NextSibling
        End If
        Ordinal = Ordinal + 1
    Wend
    Writer.Failure.Code = 0
    TryDependencyCall = True
End Function

Private Function TryDependencyBody(ByRef State As NativeDependencies, ByRef Module As SemanticModuleResult, ByVal Root As Long, ByRef Declarations As NativeDeclarationPlan, ByRef Warnings As NativeWarningGraph, ByRef Writer As NativeLLVMWriter) As Boolean
    TryDependencyBody = False
    Call ResetNativeFailure(Writer.Failure)
    If TryBeginNativeTraversal(State.Cursor, Module.Values, Module.ValueCount, Root, Writer.Limits, Writer.Usage, Writer.Cancellation, Writer.Failure) = False Then
        Exit Function
    End If
    Dim Event As NativeTraversalEvent
    While State.Cursor.Status <> 2
        Call ResetNativeFailure(Writer.Failure)
        If TryNextNativeTraversal(State.Cursor, Module.Values, Module.ValueCount, Writer.Limits, Writer.Usage, Writer.Cancellation, Event, Writer.Failure) = False Then
            Exit Function
        End If
        If Event.Kind = 1 Then
            Dim Node As BoundNode
            Call ReadBoundNode(Node, Module.Values(Event.Node))
            Call ResetNativeFailure(Writer.Failure)
            If Node.SourceId < 0 Or Node.SourceId >= Warnings.ModuleCount Then
                Exit Function
            End If
            ' Pure default literals retain their declaration's source identity,
            ' even when materialized as a child of a call in another module.
            If Node.SourceId <> Module.SourceId And Node.Kind <> 1 Then
                Exit Function
            End If
            If Node.Kind = 6 Then
                If TryDependencyCall(State, Module, Declarations, Warnings, Node, Writer) = False Then
                    Exit Function
                End If
            Else
                If Node.Kind = 3 Or Node.Kind = 104 Then
                    If Node.Target < 0 Or Node.Target >= Declarations.Count Then
                        Exit Function
                    End If
                    Dim Target As NativeDeclarationTarget
                    Call ReadNativeDeclarationTarget(Target, Declarations.Targets(Node.Target))
                    If Target.Kind = 2 And Target.Scope >= 0 And Target.Scope < Warnings.ModuleCount And Target.SourceId <> Module.SourceId Then
                        Dim Span As NativeWarningSpan
                        If TryDependencySpan(Module.Catalog, Node.SourceId, Node.SyntaxId, Node.Kind = 104, Span, Writer) = False Then
                            Exit Function
                        End If
                        Call ResetNativeFailure(Writer.Failure)
                        If TryDependencyRecord(State, Warnings, Target.SourceId, Node.SourceId, Span, Writer) = False Then
                            Exit Function
                        End If
                    End If
                End If
            End If
        End If
    Wend
    Writer.Failure.Code = 0
    TryDependencyBody = True
End Function

Private Function TryDependencyPropagate(ByRef State As NativeDependencies, ByRef Warnings As NativeWarningGraph, ByRef Writer As NativeLLVMWriter) As Boolean
    TryDependencyPropagate = False
    Dim Cleanup As NativeFailure
    While State.FormalHead < State.FormalTail
        Call ResetNativeFailure(Writer.Failure)
        If TryDependencyVisit(Writer) = False Then
            Exit Function
        End If
        Dim Parameter As Long = State.Formals(State.FormalHead).QueuedParameter
        State.FormalHead = State.FormalHead + 1
        Call TryReleaseNativeResource(Writer.Usage, 4, 1, Cleanup)
        Dim EdgeId As Long = State.Formals(Parameter).FirstEdge
        While EdgeId > 0
            Call ResetNativeFailure(Writer.Failure)
            If TryDependencyVisit(Writer) = False Then
                Exit Function
            End If
            Call ResetNativeFailure(Writer.Failure)
            If EdgeId > State.EdgeCount Then
                Exit Function
            End If
            Dim Edge As NativeDependencyEdge
            Edge = State.Edges(EdgeId - 1)
            If TryDependencySeed(State, Edge.Target, Writer) = False Then
                Exit Function
            End If
            If Edge.TargetModule <> State.RootModule Then
                Dim Span As NativeWarningSpan
                Span.FirstByte = Edge.FirstByte
                Span.LastByte = Edge.LastByte
                Call ResetNativeFailure(Writer.Failure)
                If TryDependencyRecord(State, Warnings, State.RootModule, Edge.SourceId, Span, Writer) = False Then
                    Exit Function
                End If
            End If
            EdgeId = Edge.NextEdge
        Wend
    Wend
    Writer.Failure.Code = 0
    TryDependencyPropagate = True
End Function

Private Function TryDependencyRoots(ByRef State As NativeDependencies, ByRef Result As SemanticResult, ByRef Declarations As NativeDeclarationPlan, ByRef Writer As NativeLLVMWriter) As Boolean
    TryDependencyRoots = False
    Dim SourceId As Long = 0
    While SourceId < Result.Catalog.SourceCount
        Call ResetNativeFailure(Writer.Failure)
        If TryDependencyVisit(Writer) = False Then
            Exit Function
        End If
        Call ResetNativeFailure(Writer.Failure)
        If Result.Modules(SourceId) Is Nothing Then
            Exit Function
        End If
        Dim Module As SemanticModuleResult
        Set Module = Result.Modules(SourceId)
        If Module.Catalog Is Nothing Then
            Exit Function
        End If
        If Module.SourceId <> SourceId Or Module.ValueCount < 1 Or Module.ValueCount > DependencyValuesLength(Module.Values) Or Module.FactCount < 0 Or Module.FactCount > DependencyFactsLength(Module.Facts) Then
            Exit Function
        End If
        If Module.Root < 0 Or Module.Root >= Module.ValueCount Then
            Exit Function
        End If
        If Module.Values(Module.Root).Kind <> 100 Then
            Exit Function
        End If
        Dim Child As Long = Module.Values(Module.Root).FirstChild
        Dim Remaining As Long = Module.Values(Module.Root).ChildCount
        If Remaining < 0 Then
            Exit Function
        End If
        While Remaining > 0
            Call ResetNativeFailure(Writer.Failure)
            If TryDependencyVisit(Writer) = False Then
                Exit Function
            End If
            Call ResetNativeFailure(Writer.Failure)
            If Child < 0 Or Child >= Module.ValueCount Then
                Exit Function
            End If
            Dim Node As BoundNode
            Call ReadBoundNode(Node, Module.Values(Child))
            If Node.Kind = 101 Then
                If Node.Target < 0 Or Node.Target >= Declarations.Count Then
                    Exit Function
                End If
                Dim Target As NativeDeclarationTarget
                Call ReadNativeDeclarationTarget(Target, Declarations.Targets(Node.Target))
                If Target.SourceId <> SourceId Or Target.FrameIndex < 0 Or Target.FrameIndex >= State.ProcedureCapacity Or Target.Role <> 0 Then
                    Exit Function
                End If
                If State.Procedures(Target.FrameIndex).Root <> 0 Then
                    Exit Function
                End If
                State.Procedures(Target.FrameIndex).Root = Child + 1
            Else
                If Node.Kind <> 103 Then
                    Exit Function
                End If
            End If
            Child = Node.NextSibling
            Remaining = Remaining - 1
        Wend
        If Child <> -1 Then
            Exit Function
        End If
        SourceId = SourceId + 1
    Wend
    Writer.Failure.Code = 0
    TryDependencyRoots = True
End Function

Private Function TryCollectNativeDependencies(ByRef State As NativeDependencies, ByRef Result As SemanticResult, ByRef Declarations As NativeDeclarationPlan, ByRef Warnings As NativeWarningGraph, ByRef Writer As NativeLLVMWriter) As Boolean
    TryCollectNativeDependencies = False
    Call ResetNativeFailure(Writer.Failure)
    If TryBeginDependencyStorage(State, Declarations, Writer) = False Then
        Exit Function
    End If
    Call ResetNativeFailure(Writer.Failure)
    If TryDependencyRoots(State, Result, Declarations, Writer) = False Then
        Exit Function
    End If
    State.RootModule = 0
    While State.RootModule < Warnings.ModuleCount
        Dim Id As Long = 0
        While Id < State.ProcedureCapacity
            Call ResetNativeFailure(Writer.Failure)
            If TryDependencyVisit(Writer) = False Then
                Exit Function
            End If
            State.Procedures(Id).Seen = 0
            Id = Id + 1
        Wend
        Id = 0
        While Id < State.FormalCapacity
            Call ResetNativeFailure(Writer.Failure)
            If TryDependencyVisit(Writer) = False Then
                Exit Function
            End If
            State.Formals(Id).Seen = 0
            State.Formals(Id).FirstEdge = 0
            Id = Id + 1
        Wend
        State.EdgeCount = 0
        State.ProcedureHead = 0
        State.ProcedureTail = 0
        State.FormalHead = 0
        State.FormalTail = 0
        Dim Module As SemanticModuleResult
        Set Module = Result.Modules(State.RootModule)
        Dim Child As Long = Module.Values(Module.Root).FirstChild
        While Child >= 0
            Call ResetNativeFailure(Writer.Failure)
            If TryDependencyVisit(Writer) = False Then
                Exit Function
            End If
            If Module.Values(Child).Kind = 103 Then
                Call ResetNativeFailure(Writer.Failure)
                If TryDependencyBody(State, Module, Child, Declarations, Warnings, Writer) = False Then
                    Exit Function
                End If
            End If
            Child = Module.Values(Child).NextSibling
        Wend
        While State.ProcedureHead < State.ProcedureTail
            Call ResetNativeFailure(Writer.Failure)
            If TryDependencyVisit(Writer) = False Then
                Exit Function
            End If
            Dim DeclarationId As Long = State.Procedures(State.ProcedureHead).QueuedDeclaration
            State.ProcedureHead = State.ProcedureHead + 1
            Dim Cleanup As NativeFailure
            Call TryReleaseNativeResource(Writer.Usage, 4, 1, Cleanup)
            Dim Target As NativeDeclarationTarget
            Call ReadNativeDeclarationTarget(Target, Declarations.Targets(DeclarationId))
            Set Module = Result.Modules(Target.SourceId)
            Call ResetNativeFailure(Writer.Failure)
            If TryDependencyBody(State, Module, State.Procedures(Target.FrameIndex).Root - 1, Declarations, Warnings, Writer) = False Then
                Exit Function
            End If
        Wend
        Call ResetNativeFailure(Writer.Failure)
        If TryDependencyPropagate(State, Warnings, Writer) = False Then
            Exit Function
        End If
        State.RootModule = State.RootModule + 1
    Wend
    Call ResetNativeFailure(Writer.Failure)
    TryCollectNativeDependencies = TryContinueNativeOutput(Writer.Cancellation, Writer.Failure)
End Function

Function TryDiscoverNativeWarnings(ByRef State As NativeDependencies, ByRef Result As SemanticResult, ByRef Declarations As NativeDeclarationPlan, ByRef Warnings As NativeWarningGraph, ByRef Writer As NativeLLVMWriter) As Boolean
    TryDiscoverNativeWarnings = False
    Call ResetNativeFailure(Writer.Failure)
    If State.Status <> 0 Or State.ProcedureCapacity <> 0 Or State.FormalCapacity <> 0 Or State.EdgeCapacity <> 0 Or State.ArgumentCapacity <> 0 Or State.Cursor.Capacity <> 0 Then
        Exit Function
    End If
    If Result Is Nothing Then
        Exit Function
    End If
    If Result.Catalog Is Nothing Then
        Exit Function
    End If
    If Warnings.Status <> 1 Or Warnings.ModuleCount <> Result.Catalog.SourceCount Or Warnings.ModuleCount < 1 Then
        Exit Function
    End If
    If Warnings.ModuleCount > DependencyModulesLength(Result.Modules) Or Warnings.ModuleCount > DependencySourcesLength(Result.Catalog.Sources) Then
        Exit Function
    End If
    If Declarations.Status <> 1 Or Declarations.Count <> Result.Catalog.DeclarationCount Or Declarations.FrameCount < 0 Or Declarations.ByRefCount < 0 Then
        Exit Function
    End If
    State.Status = 4
    Call ResetNativeFailure(Writer.Failure)
    If TryCollectNativeDependencies(State, Result, Declarations, Warnings, Writer) = False Then
        Warnings.Status = 4
        Exit Function
    End If
    State.Status = 2
    Writer.Failure.Code = 0
    TryDiscoverNativeWarnings = True
End Function

Function TryDisposeNativeDependencies(ByRef State As NativeDependencies, ByRef Writer As NativeLLVMWriter) As Boolean
    TryDisposeNativeDependencies = False
    Call ResetNativeFailure(Writer.Failure)
    If TryDisposeNativeTraversal(State.Cursor, Writer.Usage, Writer.Failure) = False Then
        Exit Function
    End If
    Dim Bytes As LongLong = State.ProcedureCapacity
    Bytes = Bytes * 12
    Dim Cleanup As NativeFailure
    Call ResetNativeFailure(Writer.Failure)
    If TryResizeDependencyProcedures(State.Procedures, 0, False) = False Then
        Exit Function
    End If
    Call TryReleaseNativeResource(Writer.Usage, 1, Bytes, Cleanup)
    State.ProcedureCapacity = 0
    Bytes = State.FormalCapacity
    Bytes = Bytes * 12
    If TryResizeDependencyFormals(State.Formals, 0, False) = False Then
        Exit Function
    End If
    Call TryReleaseNativeResource(Writer.Usage, 1, Bytes, Cleanup)
    State.FormalCapacity = 0
    Bytes = State.EdgeCapacity
    Bytes = Bytes * 24
    If TryResizeDependencyEdges(State.Edges, 0, False) = False Then
        Exit Function
    End If
    Call TryReleaseNativeResource(Writer.Usage, 1, Bytes, Cleanup)
    State.EdgeCapacity = 0
    Bytes = State.ArgumentCapacity
    Bytes = Bytes * 4
    If TryResizeSemanticLongs(State.Arguments, 0, False) = False Then
        Exit Function
    End If
    Call TryReleaseNativeResource(Writer.Usage, 1, Bytes, Cleanup)
    State.ArgumentCapacity = 0
    Call TryReleaseNativeResource(Writer.Usage, 4, State.ProcedureTail - State.ProcedureHead, Cleanup)
    Call TryReleaseNativeResource(Writer.Usage, 4, State.FormalTail - State.FormalHead, Cleanup)
    State.EdgeCount = 0
    State.ProcedureHead = 0
    State.ProcedureTail = 0
    State.FormalHead = 0
    State.FormalTail = 0
    State.RootModule = 0
    State.Status = 0
    Writer.Failure.Code = 0
    Writer.Failure.Resource = 0
    TryDisposeNativeDependencies = True
End Function
