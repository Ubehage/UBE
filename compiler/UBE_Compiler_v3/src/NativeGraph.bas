UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeGraph"

' Private indexes into immutable checked facts/values. No expression, type,
' argument or name is resolved here. Every stored identity is index+1; zero
' means absent. ArgumentBase alone is a zero-based offset, with ArgumentCount.
' A caller retains all checked/syntax owners through planning and emission.
' Each mutable plan belongs to one serial lowering context and is never copied.
' Payload sizes: syntax links 20, node links 20, argument links 24 bytes.
' Procedure roots use four bytes each, capped by min(frame count, node count).
' Import marks use D bytes; distinct target ids use 4*min(D,V) bytes.
' Status: 0 unused, 1 ready, 4 failed. Dispose before preparing another module.
Type NativeSyntaxLinks
    LeftConversion As Long
    RightConversion As Long
    ConditionConversion As Long
    ArgumentConversion As Long
    ExpressionNode As Long
End Type
Type NativeNodeLinks
    Scope As Long
    ArgumentBase As Long
    ArgumentCount As Long
    ArgumentIndex As Long
    TemporaryCount As Long
End Type
Type NativeArgumentLinks
    Child As Long
    Map As Long
    Conversion As Long
    Node As Long
    WrittenParameter As Long
    TemporaryIndex As Long
End Type
Type NativeGraphPlan
    Syntax() As NativeSyntaxLinks
    Nodes() As NativeNodeLinks
    Arguments() As NativeArgumentLinks
    Cursor As NativeTraversal
    SyntaxCount As Long
    NodeCount As Long
    ArgumentCount As Long
    ArgumentCapacity As Long
    Status As Long
    ProcedureRoots() As Long
    ProcedureCapacity As Long
    ProcedureCount As Long
    FirstFrame As Long
    ImportMarks() As Boolean
    Imports() As Long
    ImportMarkCount As Long
    ImportCapacity As Long
    ImportCount As Long
End Type
Private Intrinsic Function NativePlanValuesLength(ByRef Values() As BoundNode) As Long
Attribute NativePlanValuesLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function NativePlanFactsLength(ByRef Values() As SemanticFact) As Long
Attribute NativePlanFactsLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function TryResizeNativeSyntaxLinks(ByRef Values() As NativeSyntaxLinks, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeNativeSyntaxLinks.UBE_Primitive = "Array.TryResize"
End Function
Private Intrinsic Function TryResizeNativeNodeLinks(ByRef Values() As NativeNodeLinks, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeNativeNodeLinks.UBE_Primitive = "Array.TryResize"
End Function
Private Intrinsic Function TryResizeNativeArgumentLinks(ByRef Values() As NativeArgumentLinks, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeNativeArgumentLinks.UBE_Primitive = "Array.TryResize"
End Function
Private Intrinsic Function TryResizeNativeGraphIds(ByRef Values() As Long, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeNativeGraphIds.UBE_Primitive = "Array.TryResize"
End Function
Private Intrinsic Function TryResizeNativeImportMarks(ByRef Values() As Boolean, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeNativeImportMarks.UBE_Primitive = "Array.TryResize"
End Function
Private Intrinsic Function NativeGraphIdsLength(ByRef Values() As Long) As Long
Attribute NativeGraphIdsLength.UBE_Primitive = "Array.Length"
End Function
Private Sub ReadNativeSyntaxLinks(ByRef Destination As NativeSyntaxLinks, ByRef Original As NativeSyntaxLinks)
    Destination = Original
End Sub
Private Sub WriteNativeSyntaxLinks(ByRef Destination As NativeSyntaxLinks, ByRef Original As NativeSyntaxLinks)
    Destination = Original
End Sub
Private Sub ReadNativeNodeLinks(ByRef Destination As NativeNodeLinks, ByRef Original As NativeNodeLinks)
    Destination = Original
End Sub
Private Sub WriteNativeNodeLinks(ByRef Destination As NativeNodeLinks, ByRef Original As NativeNodeLinks)
    Destination = Original
End Sub
Private Sub ReadNativeArgumentLinks(ByRef Destination As NativeArgumentLinks, ByRef Original As NativeArgumentLinks)
    Destination = Original
End Sub
Private Sub WriteNativeArgumentLinks(ByRef Destination As NativeArgumentLinks, ByRef Original As NativeArgumentLinks)
    Destination = Original
End Sub

' Metadata/index visits share the same cumulative work and polling boundary as
' traversal events. Count the visits that actually occur, including failures.
Function TryVisitNativeIndex(ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByRef Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryVisitNativeIndex = False
    Call ResetNativeFailure(Failure)
    If Usage.Work Mod 4096 = 0 Then
        If TryContinueNativeOutput(Cancellation, Failure) = False Then
            Exit Function
        End If
    End If
    TryVisitNativeIndex = TryChargeNativeResource(Limits, Usage, 5, 1, Failure)
End Function

Private Function TryAllocateNativeGraphLinks(ByRef Plan As NativeGraphPlan, ByVal SyntaxCount As Long, ByVal NodeCount As Long, ByVal ProcedureCapacity As Long, ByVal DeclarationCount As Long, ByVal ImportCapacity As Long, ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByRef Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryAllocateNativeGraphLinks = False
    Call ResetNativeFailure(Failure)
    Dim Bytes As LongLong = SyntaxCount
    Dim NodesBytes As LongLong = NodeCount
    Dim ProcedureBytes As LongLong = ProcedureCapacity
    Dim MarkBytes As LongLong = DeclarationCount
    Dim ImportBytes As LongLong = ImportCapacity
    Bytes = Bytes * 20 + NodesBytes * 20 + ProcedureBytes * 4 + MarkBytes + ImportBytes * 4
    If TryChargeNativeResource(Limits, Usage, 1, Bytes, Failure) = False Then
        Exit Function
    End If
    Dim Healthy As Boolean = False
    Call ResetNativeFailure(Failure)
    If TryContinueNativeOutput(Cancellation, Failure) Then
        Call ResetNativeFailure(Failure)
        If TryResizeNativeSyntaxLinks(Plan.Syntax, SyntaxCount, False) Then
            Plan.SyntaxCount = SyntaxCount
            Call ResetNativeFailure(Failure)
            If TryContinueNativeOutput(Cancellation, Failure) Then
                Call ResetNativeFailure(Failure)
                If TryResizeNativeNodeLinks(Plan.Nodes, NodeCount, False) Then
                    Plan.NodeCount = NodeCount
                    Call ResetNativeFailure(Failure)
                    Healthy = TryContinueNativeOutput(Cancellation, Failure)
                    If Healthy And ProcedureCapacity > 0 Then
                        Call ResetNativeFailure(Failure)
                        Healthy = TryResizeNativeGraphIds(Plan.ProcedureRoots, ProcedureCapacity, False)
                        If Healthy Then
                            Plan.ProcedureCapacity = ProcedureCapacity
                            Call ResetNativeFailure(Failure)
                            Healthy = TryContinueNativeOutput(Cancellation, Failure)
                        Else
                            Failure.Code = 1502
                            Failure.Resource = 1
                        End If
                    End If
                Else
                    Failure.Code = 1502
                    Failure.Resource = 1
                End If
            End If
        Else
            Failure.Code = 1502
            Failure.Resource = 1
        End If
    End If
    If Healthy And DeclarationCount > 0 Then
        Call ResetNativeFailure(Failure)
        Healthy = TryResizeNativeImportMarks(Plan.ImportMarks, DeclarationCount, False)
        If Healthy Then
            Plan.ImportMarkCount = DeclarationCount
            Call ResetNativeFailure(Failure)
            Healthy = TryContinueNativeOutput(Cancellation, Failure)
        Else
            Failure.Code = 1502
            Failure.Resource = 1
        End If
    End If
    If Healthy And ImportCapacity > 0 Then
        Call ResetNativeFailure(Failure)
        Healthy = TryResizeNativeGraphIds(Plan.Imports, ImportCapacity, False)
        If Healthy Then
            Plan.ImportCapacity = ImportCapacity
            Call ResetNativeFailure(Failure)
            Healthy = TryContinueNativeOutput(Cancellation, Failure)
        Else
            Failure.Code = 1502
            Failure.Resource = 1
        End If
    End If
    If Healthy = False Then
        Dim Owned As LongLong = Plan.SyntaxCount
        NodesBytes = Plan.NodeCount
        ProcedureBytes = Plan.ProcedureCapacity
        MarkBytes = Plan.ImportMarkCount
        ImportBytes = Plan.ImportCapacity
        Owned = Owned * 20 + NodesBytes * 20 + ProcedureBytes * 4 + MarkBytes + ImportBytes * 4
        Dim Cleanup As NativeFailure
        Call TryReleaseNativeResource(Usage, 1, Bytes - Owned, Cleanup)
        Exit Function
    End If
    Failure.Code = 0
    TryAllocateNativeGraphLinks = True
End Function

Private Function TryReserveNativeArguments(ByRef Plan As NativeGraphPlan, ByVal Count As Long, ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByRef Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryReserveNativeArguments = False
    Call ResetNativeFailure(Failure)
    If Count < 0 Or Plan.ArgumentCount < 0 Or Count > Plan.NodeCount - Plan.ArgumentCount Then
        Exit Function
    End If
    Dim Required As Long = Plan.ArgumentCount + Count
    If Required > Plan.ArgumentCapacity Then
        Dim Capacity As Long = Plan.ArgumentCapacity
        If TryGetStorageCapacity(Capacity, Required, Plan.NodeCount, Capacity) = False Then
            Exit Function
        End If
        Dim Bytes As LongLong = Capacity
        Bytes = Bytes * 24
        If TryChargeNativeResource(Limits, Usage, 1, Bytes, Failure) = False Then
            Exit Function
        End If
        Call ResetNativeFailure(Failure)
        Dim Healthy As Boolean = TryContinueNativeOutput(Cancellation, Failure)
        If Healthy Then
            Call ResetNativeFailure(Failure)
            Healthy = TryResizeNativeArgumentLinks(Plan.Arguments, Capacity, True)
            If Healthy = False Then
                Failure.Code = 1502
                Failure.Resource = 1
            End If
        End If
        Dim Cleanup As NativeFailure
        If Healthy = False Then
            Call TryReleaseNativeResource(Usage, 1, Bytes, Cleanup)
            Exit Function
        End If
        Dim OldBytes As LongLong = Plan.ArgumentCapacity
        OldBytes = OldBytes * 24
        Call TryReleaseNativeResource(Usage, 1, OldBytes, Cleanup)
        Plan.ArgumentCapacity = Capacity
        Call ResetNativeFailure(Failure)
        If TryContinueNativeOutput(Cancellation, Failure) = False Then
            Exit Function
        End If
    End If
    Plan.ArgumentCount = Required
    Failure.Code = 0
    Failure.Resource = 0
    TryReserveNativeArguments = True
End Function

' Only the already-selected conversion edges enter this index. Default values
' are already exact-typed in the call's parameter map and need no conversion.
' Syntax identity disambiguates written arguments, including parentheses.
Private Function TryIndexNativeConversions(ByRef Plan As NativeGraphPlan, ByRef Facts() As SemanticFact, ByVal FactCount As Long, ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByRef Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryIndexNativeConversions = False
    Dim Id As Long = 0
    While Id < FactCount
        Call ResetNativeFailure(Failure)
        If TryVisitNativeIndex(Limits, Usage, Cancellation, Failure) = False Then
            Exit Function
        End If
        Call ResetNativeFailure(Failure)
        Dim Fact As SemanticFact
        Call ReadSemanticFact(Fact, Facts(Id))
        If Fact.Kind = 1 And Fact.Auxiliary >= 0 Then
            If Fact.SyntaxId < 0 Or Fact.SyntaxId >= Plan.SyntaxCount Or Fact.Auxiliary >= Plan.NodeCount Then
                Exit Function
            End If
            Dim Expression As NativeSyntaxLinks
            Call ReadNativeSyntaxLinks(Expression, Plan.Syntax(Fact.SyntaxId))
            If Expression.ExpressionNode <> 0 And Expression.ExpressionNode <> Fact.Auxiliary + 1 Then
                Exit Function
            End If
            Expression.ExpressionNode = Fact.Auxiliary + 1
            Call WriteNativeSyntaxLinks(Plan.Syntax(Fact.SyntaxId), Expression)
        End If
        If Fact.Kind = 3 And (Fact.Right = 1 Or Fact.Right = 2 Or Fact.Right = 6 Or Fact.Right = 7) Then
            Dim SyntaxId As Long = Fact.Target
            If Fact.Right = 6 Then
                SyntaxId = Fact.SyntaxId
            End If
            If SyntaxId < 0 Or SyntaxId >= Plan.SyntaxCount Then
                Exit Function
            End If
            Dim Links As NativeSyntaxLinks
            Call ReadNativeSyntaxLinks(Links, Plan.Syntax(SyntaxId))
            If Fact.Right = 1 Then
                If Links.LeftConversion <> 0 Then
                    Exit Function
                End If
                Links.LeftConversion = Id + 1
            End If
            If Fact.Right = 2 Then
                If Links.RightConversion <> 0 Then
                    Exit Function
                End If
                Links.RightConversion = Id + 1
            End If
            If Fact.Right = 6 Then
                If Links.ArgumentConversion <> 0 Then
                    Exit Function
                End If
                Links.ArgumentConversion = Id + 1
            End If
            If Fact.Right = 7 Then
                If Links.ConditionConversion <> 0 Then
                    Exit Function
                End If
                Links.ConditionConversion = Id + 1
            End If
            Call WriteNativeSyntaxLinks(Plan.Syntax(SyntaxId), Links)
        End If
        Id = Id + 1
    Wend
    Failure.Code = 0
    TryIndexNativeConversions = True
End Function

' Resolve a call's parameter association from its retained map, not names or
' child order. Child holds written evaluation order; Node holds parameter
' order. Written arguments use the checker's materialized-expression identity.
' Reverse parameter order consumes omitted default children from the tail, so
' association requires one parameter-map pass without reordering evaluation.
Private Function TryPlanNativeCall(ByRef Plan As NativeGraphPlan, ByRef Values() As BoundNode, ByRef Facts() As SemanticFact, ByVal FactCount As Long, ByVal NodeId As Long, ByRef Declarations As NativeDeclarationPlan, ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByRef Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryPlanNativeCall = False
    Call ResetNativeFailure(Failure)
    Dim Links As NativeNodeLinks
    Call ReadNativeNodeLinks(Links, Plan.Nodes(NodeId))
    Dim CallId As Long = Values(NodeId).Auxiliary
    If CallId < 0 Or CallId >= FactCount Then
        Exit Function
    End If
    Dim Header As SemanticFact
    Call ReadSemanticFact(Header, Facts(CallId))
    If Header.Kind <> 5 Or Header.Target <> Values(NodeId).Target Or Header.Right <> Links.ArgumentCount Then
        Exit Function
    End If
    If Header.Auxiliary < 0 Or Header.Auxiliary > Links.ArgumentCount Then
        Exit Function
    End If
    If Links.ArgumentCount > 0 Then
        If Header.Left < 0 Or Header.Left > FactCount - Links.ArgumentCount Then
            Exit Function
        End If
    End If
    Dim Ordinal As Long = Links.ArgumentCount - 1
    Dim DefaultOrdinal As Long = 0
    While Ordinal >= 0
        Call ResetNativeFailure(Failure)
        If TryVisitNativeIndex(Limits, Usage, Cancellation, Failure) = False Then
            Exit Function
        End If
        Call ResetNativeFailure(Failure)
        Dim Map As SemanticFact
        Call ReadSemanticFact(Map, Facts(Header.Left + Ordinal))
        If Map.Kind <> 6 Or Map.Left <> CallId Or Map.Extra <> Ordinal Then
            Exit Function
        End If
        If Map.Target < 0 Or Map.Target >= Declarations.Count Then
            Exit Function
        End If
        Dim Parameter As NativeDeclarationTarget
        Call ReadNativeDeclarationTarget(Parameter, Declarations.Targets(Map.Target))
        If Parameter.Kind <> 4 Or Parameter.Scope <> Header.Target Or Parameter.TypeId <> Map.TypeId Then
            Exit Function
        End If
        Dim Mode As Long = Map.Flags And 3
        Dim ByValue As Boolean = (Parameter.Flags And 4) <> 0
        If (Mode = 0 And ByValue = False) Or ((Mode = 1 Or Mode = 2) And ByValue) Then
            Exit Function
        End If
        Dim Argument As NativeArgumentLinks
        Call ReadNativeArgumentLinks(Argument, Plan.Arguments(Links.ArgumentBase + Ordinal))
        Argument.Map = Header.Left + Ordinal + 1
        If Map.Right >= 0 Then
            If Map.Right >= Plan.SyntaxCount Or Map.Auxiliary < 0 Or Map.Auxiliary >= Header.Auxiliary Then
                Exit Function
            End If
            Argument.Conversion = Plan.Syntax(Map.Right).ArgumentConversion
            If Argument.Conversion <= 0 Or Argument.Conversion > FactCount Then
                Exit Function
            End If
            Dim Conversion As SemanticFact
            Call ReadSemanticFact(Conversion, Facts(Argument.Conversion - 1))
            If Conversion.Target <> Map.Target Or Conversion.TypeId <> Map.TypeId Or Conversion.Auxiliary <> Ordinal Then
                Exit Function
            End If
            Argument.Node = Plan.Syntax(Map.Right).ExpressionNode
        Else
            Dim DefaultIndex As Long = Links.ArgumentCount - DefaultOrdinal - 1
            Argument.Node = Plan.Arguments(Links.ArgumentBase + DefaultIndex).Child
            DefaultOrdinal = DefaultOrdinal + 1
        End If
        If Argument.Node <= 0 Or Argument.Node > Plan.NodeCount Then
            Exit Function
        End If
        ' Direct child-to-formal lookup for conversion at the child's emission
        ' point. Build it during this existing map visit, including defaults.
        If Plan.Nodes(Argument.Node - 1).ArgumentIndex <> 0 Then
            Exit Function
        End If
        Plan.Nodes(Argument.Node - 1).ArgumentIndex = Links.ArgumentBase + Ordinal + 1
        If Mode = 2 Or (Mode = 3 And ByValue = False) Then
            Dim Scope As Long = Links.Scope - 1
            If Scope < 0 Or Scope >= Plan.NodeCount Then
                Exit Function
            End If
            If Plan.Nodes(Scope).TemporaryCount >= Plan.NodeCount Then
                Exit Function
            End If
            Plan.Nodes(Scope).TemporaryCount = Plan.Nodes(Scope).TemporaryCount + 1
            Argument.TemporaryIndex = Plan.Nodes(Scope).TemporaryCount
        End If
        Call WriteNativeArgumentLinks(Plan.Arguments(Links.ArgumentBase + Ordinal), Argument)
        If Map.Right >= 0 Then
            Dim Position As NativeArgumentLinks
            Call ReadNativeArgumentLinks(Position, Plan.Arguments(Links.ArgumentBase + Map.Auxiliary))
            If Position.WrittenParameter <> 0 Then
                Exit Function
            End If
            Position.WrittenParameter = Ordinal + 1
            Call WriteNativeArgumentLinks(Plan.Arguments(Links.ArgumentBase + Map.Auxiliary), Position)
        End If
        Ordinal = Ordinal - 1
    Wend
    Failure.Code = 0
    TryPlanNativeCall = True
End Function

' Import discovery belongs to the already charged node-entry event. Exact
' address transport requires a declaration even when it needs no runtime guard.
Private Function TryIndexNativeImport(ByRef Plan As NativeGraphPlan, ByRef Node As BoundNode, ByRef Declarations As NativeDeclarationPlan) As Boolean
    TryIndexNativeImport = False
    If Node.Kind <> 3 And Node.Kind <> 6 And Node.Kind <> 104 Then
        TryIndexNativeImport = True
        Exit Function
    End If
    If Node.Target < 0 Or Node.Target >= Declarations.Count Or Node.Target >= Plan.ImportMarkCount Then
        Exit Function
    End If
    Dim Target As NativeDeclarationTarget
    Call ReadNativeDeclarationTarget(Target, Declarations.Targets(Node.Target))
    If Target.SourceId = Node.SourceId Then
        TryIndexNativeImport = True
        Exit Function
    End If
    Dim Needed As Boolean = False
    If Node.Kind = 6 Then
        Needed = (Target.Kind = 5 Or Target.Kind = 6) And Target.Role = 0
    Else
        If Target.Kind = 2 Then
            If Target.Scope < 0 Or Target.Scope >= Declarations.Count Then
                Exit Function
            End If
            Needed = Declarations.Targets(Target.Scope).Kind = 1
        End If
    End If
    If Needed And Plan.ImportMarks(Node.Target) = False Then
        If Plan.ImportCount < 0 Or Plan.ImportCount >= Plan.ImportCapacity Then
            Exit Function
        End If
        Plan.Imports(Plan.ImportCount) = Node.Target + 1
        Plan.ImportMarks(Node.Target) = True
        Plan.ImportCount = Plan.ImportCount + 1
    End If
    TryIndexNativeImport = True
End Function

Function TryPrepareNativeGraph(ByRef Plan As NativeGraphPlan, ByRef Values() As BoundNode, ByVal ValueCount As Long, ByVal Root As Long, ByRef Facts() As SemanticFact, ByVal FactCount As Long, ByVal SyntaxCount As Long, ByRef Declarations As NativeDeclarationPlan, ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByRef Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryPrepareNativeGraph = False
    Call ResetNativeFailure(Failure)
    If Plan.Status <> 0 Or Plan.SyntaxCount <> 0 Or Plan.NodeCount <> 0 Or Plan.ArgumentCapacity <> 0 Or Plan.ProcedureCapacity <> 0 Or Plan.ProcedureCount <> 0 Or Plan.ImportMarkCount <> 0 Or Plan.ImportCapacity <> 0 Or Plan.ImportCount <> 0 Or Declarations.Status <> 1 Then
        Exit Function
    End If
    Plan.Status = 4
    If ValueCount < 1 Or ValueCount > NativePlanValuesLength(Values) Or FactCount < 0 Or FactCount > NativePlanFactsLength(Facts) Or SyntaxCount < 1 Or Declarations.FrameCount < 0 Or Declarations.Count < 0 Then
        Exit Function
    End If
    Call ResetNativeFailure(Failure)
    Dim ProcedureCapacity As Long = Declarations.FrameCount
    If ProcedureCapacity > ValueCount Then
        ProcedureCapacity = ValueCount
    End If
    Dim ImportCapacity As Long = Declarations.Count
    If ImportCapacity > ValueCount Then
        ImportCapacity = ValueCount
    End If
    Plan.FirstFrame = -1
    If TryAllocateNativeGraphLinks(Plan, SyntaxCount, ValueCount, ProcedureCapacity, Declarations.Count, ImportCapacity, Limits, Usage, Cancellation, Failure) = False Then
        Exit Function
    End If
    Call ResetNativeFailure(Failure)
    If TryIndexNativeConversions(Plan, Facts, FactCount, Limits, Usage, Cancellation, Failure) = False Then
        Exit Function
    End If
    Call ResetNativeFailure(Failure)
    If TryBeginNativeTraversal(Plan.Cursor, Values, ValueCount, Root, Limits, Usage, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Complete As Boolean = False
    While Complete = False
        Dim Event As NativeTraversalEvent
        Call ResetNativeFailure(Failure)
        If TryNextNativeTraversal(Plan.Cursor, Values, ValueCount, Limits, Usage, Cancellation, Event, Failure) = False Then
            Exit Function
        End If
        Call ResetNativeFailure(Failure)
        Complete = Event.Kind = 0
        If Event.Kind <> 0 Then
            Dim Node As BoundNode
            Call ReadBoundNode(Node, Values(Event.Node))
            If Event.Kind = 1 Then
                Dim Links As NativeNodeLinks
                Call ReadNativeNodeLinks(Links, Plan.Nodes(Event.Node))
                If Links.Scope <> 0 Then
                    ' The checker's ownership graph has one parent per live
                    ' occurrence. Do not silently collapse duplicated effects.
                    Exit Function
                End If
                Links.Scope = Event.Node + 1
                If Event.Parent >= 0 And Node.Kind <> 101 Then
                    Links.Scope = Plan.Nodes(Event.Parent).Scope
                End If
                If Node.Kind = 101 Then
                    If Node.Target < 0 Or Node.Target >= Declarations.Count Or Plan.ProcedureCount >= Plan.ProcedureCapacity Then
                        Exit Function
                    End If
                    Dim Procedure As NativeDeclarationTarget
                    Call ReadNativeDeclarationTarget(Procedure, Declarations.Targets(Node.Target))
                    If (Procedure.Kind <> 5 And Procedure.Kind <> 6) Or Procedure.Role <> 0 Or Procedure.FrameIndex < 0 Or Procedure.FrameIndex >= Declarations.FrameCount Then
                        Exit Function
                    End If
                    If Plan.ProcedureCount = 0 Then
                        Plan.FirstFrame = Procedure.FrameIndex
                    End If
                    If Procedure.FrameIndex - Plan.FirstFrame <> Plan.ProcedureCount Then
                        Exit Function
                    End If
                    Plan.ProcedureRoots(Plan.ProcedureCount) = Event.Node + 1
                    Plan.ProcedureCount = Plan.ProcedureCount + 1
                End If
                If Node.Kind = 6 Then
                    Links.ArgumentBase = Plan.ArgumentCount
                    Links.ArgumentCount = Node.ChildCount
                    Call ResetNativeFailure(Failure)
                    If TryReserveNativeArguments(Plan, Node.ChildCount, Limits, Usage, Cancellation, Failure) = False Then
                        Exit Function
                    End If
                End If
                If TryIndexNativeImport(Plan, Node, Declarations) = False Then
                    Exit Function
                End If
                Call WriteNativeNodeLinks(Plan.Nodes(Event.Node), Links)
            End If
            If Event.Kind = 2 Then
                Dim Parent As BoundNode
                Call ReadBoundNode(Parent, Values(Event.Parent))
                If Parent.Kind = 6 Then
                    Dim Base As Long = Plan.Nodes(Event.Parent).ArgumentBase
                    Dim Child As NativeArgumentLinks
                    Call ReadNativeArgumentLinks(Child, Plan.Arguments(Base + Event.Ordinal))
                    Child.Child = Event.Node + 1
                    Call WriteNativeArgumentLinks(Plan.Arguments(Base + Event.Ordinal), Child)
                End If
            End If
            If Event.Kind = 3 And Node.Kind = 6 Then
                Call ResetNativeFailure(Failure)
                If TryPlanNativeCall(Plan, Values, Facts, FactCount, Event.Node, Declarations, Limits, Usage, Cancellation, Failure) = False Then
                    Exit Function
                End If
            End If
        End If
    Wend
    Plan.Status = 1
    Failure.Code = 0
    Failure.Resource = 0
    TryPrepareNativeGraph = True
End Function

' Constant-time resolved lookup, charged by its surrounding definition visit.
' Preserve the caller's root on invalid identity or incomplete plan.
Function TryReadNativeProcedureRoot(ByRef Plan As NativeGraphPlan, ByVal FrameIndex As Long, ByRef Root As Long) As Boolean
    TryReadNativeProcedureRoot = False
    If Plan.Status <> 1 Or Plan.FirstFrame < 0 Or FrameIndex < Plan.FirstFrame Or Plan.ProcedureCount < 0 Then
        Exit Function
    End If
    If Plan.ProcedureCount > Plan.ProcedureCapacity Or Plan.ProcedureCount > NativeGraphIdsLength(Plan.ProcedureRoots) Then
        Exit Function
    End If
    Dim Index As Long = FrameIndex - Plan.FirstFrame
    If Index >= Plan.ProcedureCount Then
        Exit Function
    End If
    Dim Prepared As Long = Plan.ProcedureRoots(Index)
    If Prepared < 1 Or Prepared > Plan.NodeCount Then
        Exit Function
    End If
    Root = Prepared - 1
    TryReadNativeProcedureRoot = True
End Function

Function TryDisposeNativeGraph(ByRef Plan As NativeGraphPlan, ByRef Usage As NativeUsage, ByRef Failure As NativeFailure) As Boolean
    TryDisposeNativeGraph = False
    Call ResetNativeFailure(Failure)
    If TryDisposeNativeTraversal(Plan.Cursor, Usage, Failure) = False Then
        Exit Function
    End If
    Call ResetNativeFailure(Failure)
    If TryResizeNativeSyntaxLinks(Plan.Syntax, 0, False) = False Then
        Exit Function
    End If
    Dim Bytes As LongLong = Plan.SyntaxCount
    Bytes = Bytes * 20
    Dim Cleanup As NativeFailure
    Call TryReleaseNativeResource(Usage, 1, Bytes, Cleanup)
    Plan.SyntaxCount = 0
    Call ResetNativeFailure(Failure)
    If TryResizeNativeNodeLinks(Plan.Nodes, 0, False) = False Then
        Exit Function
    End If
    Bytes = Plan.NodeCount
    Bytes = Bytes * 20
    Call TryReleaseNativeResource(Usage, 1, Bytes, Cleanup)
    Plan.NodeCount = 0
    Call ResetNativeFailure(Failure)
    If TryResizeNativeArgumentLinks(Plan.Arguments, 0, False) = False Then
        Exit Function
    End If
    Bytes = Plan.ArgumentCapacity
    Bytes = Bytes * 24
    Call TryReleaseNativeResource(Usage, 1, Bytes, Cleanup)
    Plan.ArgumentCount = 0
    Plan.ArgumentCapacity = 0
    Call ResetNativeFailure(Failure)
    If TryResizeNativeGraphIds(Plan.ProcedureRoots, 0, False) = False Then
        Exit Function
    End If
    Bytes = Plan.ProcedureCapacity
    Bytes = Bytes * 4
    Call TryReleaseNativeResource(Usage, 1, Bytes, Cleanup)
    Plan.ProcedureCapacity = 0
    Plan.ProcedureCount = 0
    Plan.FirstFrame = 0
    Call ResetNativeFailure(Failure)
    If TryResizeNativeImportMarks(Plan.ImportMarks, 0, False) = False Then
        Exit Function
    End If
    Bytes = Plan.ImportMarkCount
    Call TryReleaseNativeResource(Usage, 1, Bytes, Cleanup)
    Plan.ImportMarkCount = 0
    Call ResetNativeFailure(Failure)
    If TryResizeNativeGraphIds(Plan.Imports, 0, False) = False Then
        Exit Function
    End If
    Bytes = Plan.ImportCapacity
    Bytes = Bytes * 4
    Call TryReleaseNativeResource(Usage, 1, Bytes, Cleanup)
    Plan.ImportCapacity = 0
    Plan.ImportCount = 0
    Plan.Status = 0
    Failure.Code = 0
    Failure.Resource = 0
    TryDisposeNativeGraph = True
End Function
