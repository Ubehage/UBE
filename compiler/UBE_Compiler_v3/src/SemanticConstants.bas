UBE SOURCE 1 MODULE
Attribute UBE_Name = "SemanticConstants"

' One preparation graph covers constants and optional defaults. Names are
' inspected once to collect edges, then expressions are bound exactly once in
' dependency order. No repeated body binding or source-controlled recursion.
Type SemanticInitializer
    Declaration As Long
    SourceId As Long
    Scope As Long
    SyntaxId As Long
    FirstEdge As Long
    LastEdge As Long
    State As Long
End Type
Type SemanticConstantEdge
    Target As Long
    SyntaxId As Long
    NextEdge As Long
End Type
Type SemanticConstantFrame
    Initializer As Long
    NextEdge As Long
    Awaiting As Long
End Type
Type SemanticDependencyFrame
    SyntaxId As Long
    NextChild As Long
    Depth As Long
    Entered As Boolean
End Type
Private Intrinsic Function TryResizeSemanticInitializers(ByRef Values() As SemanticInitializer, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeSemanticInitializers.UBE_Primitive = "Array.TryResize"
End Function
Private Intrinsic Function SemanticInitializersLength(ByRef Values() As SemanticInitializer) As Long
Attribute SemanticInitializersLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function TryResizeSemanticConstantEdges(ByRef Values() As SemanticConstantEdge, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeSemanticConstantEdges.UBE_Primitive = "Array.TryResize"
End Function
Private Intrinsic Function SemanticConstantEdgesLength(ByRef Values() As SemanticConstantEdge) As Long
Attribute SemanticConstantEdgesLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function TryResizeSemanticConstantFrames(ByRef Values() As SemanticConstantFrame, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeSemanticConstantFrames.UBE_Primitive = "Array.TryResize"
End Function
Private Intrinsic Function SemanticConstantFramesLength(ByRef Values() As SemanticConstantFrame) As Long
Attribute SemanticConstantFramesLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function TryResizeSemanticDependencyFrames(ByRef Values() As SemanticDependencyFrame, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeSemanticDependencyFrames.UBE_Primitive = "Array.TryResize"
End Function
Private Intrinsic Function SemanticDependencyFramesLength(ByRef Values() As SemanticDependencyFrame) As Long
Attribute SemanticDependencyFramesLength.UBE_Primitive = "Array.Length"
End Function
Private Sub ReadSemanticInitializer(ByRef Destination As SemanticInitializer, ByRef Original As SemanticInitializer)
    Destination = Original
End Sub
Private Sub WriteSemanticInitializer(ByRef Destination As SemanticInitializer, ByRef Original As SemanticInitializer)
    Destination = Original
End Sub
Private Sub ReadSemanticConstantEdge(ByRef Destination As SemanticConstantEdge, ByRef Original As SemanticConstantEdge)
    Destination = Original
End Sub
Private Sub WriteSemanticConstantEdge(ByRef Destination As SemanticConstantEdge, ByRef Original As SemanticConstantEdge)
    Destination = Original
End Sub
Private Sub ReadSemanticConstantFrame(ByRef Destination As SemanticConstantFrame, ByRef Original As SemanticConstantFrame)
    Destination = Original
End Sub
Private Sub WriteSemanticConstantFrame(ByRef Destination As SemanticConstantFrame, ByRef Original As SemanticConstantFrame)
    Destination = Original
End Sub
Private Sub ReadSemanticDependencyFrame(ByRef Destination As SemanticDependencyFrame, ByRef Original As SemanticDependencyFrame)
    Destination = Original
End Sub
Private Sub WriteSemanticDependencyFrame(ByRef Destination As SemanticDependencyFrame, ByRef Original As SemanticDependencyFrame)
    Destination = Original
End Sub

Private Function TryChargeSemanticScratch(ByVal Work As SemanticModuleWork, ByVal Required As Long) As Boolean
    TryChargeSemanticScratch = False
    If Required < 0 Then
        TryChargeSemanticScratch = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    If Required > Work.MaximumPending Or Required > Work.Limits.MaximumPending Then
        TryChargeSemanticScratch = FailSemanticBudget(Work.Failure)
        Exit Function
    End If
    If Required > Work.Metrics.MaximumPending Then
        Work.Metrics.MaximumPending = Required
    End If
    TryChargeSemanticScratch = True
End Function

Private Function TryContinueSemanticConstants(ByVal Work As SemanticModuleWork) As Boolean
    TryContinueSemanticConstants = TryContinueSemanticWork(Work)
End Function

Private Function TryPushSemanticDependency(ByVal Work As SemanticModuleWork, ByRef Frames() As SemanticDependencyFrame, ByRef Count As Long, ByVal BasePending As Long, ByVal SyntaxId As Long, ByVal Depth As Long) As Boolean
    TryPushSemanticDependency = False
    If Depth > Work.Limits.MaximumDepth Then
        TryPushSemanticDependency = FailSemanticBudget(Work.Failure)
        Exit Function
    End If
    If TryChargeSemanticScratch(Work, BasePending + Count + 1) = False Then
        Exit Function
    End If
    Dim Capacity As Long = SemanticDependencyFramesLength(Frames)
    Dim Prepared As Long = Capacity
    If TryGetStorageCapacity(Capacity, Count + 1, Work.MaximumPending, Prepared) = False Then
        TryPushSemanticDependency = FailSemanticBudget(Work.Failure)
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    If Prepared <> Capacity Then
        If TryResizeSemanticDependencyFrames(Frames, Prepared, True) = False Then
            Exit Function
        End If
    End If
    Dim Frame As SemanticDependencyFrame
    Frame.SyntaxId = SyntaxId
    Frame.NextChild = -1
    Frame.Depth = Depth
    Call WriteSemanticDependencyFrame(Frames(Count), Frame)
    Count = Count + 1
    If Depth > Work.Metrics.MaximumDepth Then
        Work.Metrics.MaximumDepth = Depth
    End If
    TryPushSemanticDependency = True
End Function

' Only another constant can create a dependency. Other expression eligibility
' and all operator/type checks remain in the single ordinary expression binder.
Private Function TryCollectSemanticDependencies(ByVal Work As SemanticModuleWork, ByRef Initializers() As SemanticInitializer, ByVal InitializerId As Long, ByRef Map() As Long, ByRef Edges() As SemanticConstantEdge, ByRef EdgeCount As Long, ByVal BasePending As Long) As Boolean
    TryCollectSemanticDependencies = False
    Dim Initializer As SemanticInitializer
    Call ReadSemanticInitializer(Initializer, Initializers(InitializerId))
    Set Work.Source = Work.Catalog.Sources(Initializer.SourceId)
    Work.Scope = Initializer.Scope
    Dim Frames() As SemanticDependencyFrame
    Dim Count As Long = 0
    If TryPushSemanticDependency(Work, Frames, Count, BasePending + EdgeCount, Initializer.SyntaxId, 0) = False Then
        Exit Function
    End If
    While Count > 0
        Call ResetSemanticFailure(Work.Failure)
        If TryContinueSemanticWork(Work) = False Then
            Exit Function
        End If
        Dim Frame As SemanticDependencyFrame
        Call ReadSemanticDependencyFrame(Frame, Frames(Count - 1))
        Work.Metrics.Transitions = Work.Metrics.Transitions + 1
        Dim Node As SyntaxNode
        If TryReadSemanticSyntax(Work, Frame.SyntaxId, Node) = False Then
            Exit Function
        End If
        If Frame.Entered = False Then
            Frame.Entered = True
            If Node.Kind = 1 Or Node.Kind = 34 Then
                Dim DeclarationId As Long = -1
                Dim Level As Long = 0
                If TryLookupSemanticExpressionName(Work, Frame.SyntaxId, False, False, DeclarationId, Level) = False Then
                    Exit Function
                End If
                Dim Declaration As SemanticDeclaration
                If TryReadSemanticDeclaration(Work, DeclarationId, Declaration) = False Then
                    Exit Function
                End If
                If Declaration.Kind = 3 Then
                    If Declaration.SourceId = Initializer.SourceId And Declaration.Scope = Initializer.Scope And DeclarationId >= Initializer.Declaration Then
                        TryCollectSemanticDependencies = SemanticWorkError(Work, 1413, Frame.SyntaxId)
                        Exit Function
                    End If
                    Dim Target As Long = Map(DeclarationId) - 1
                    If Target < 0 Then
                        TryCollectSemanticDependencies = FailSemanticDomain(Work.Failure)
                        Exit Function
                    End If
                    If TryChargeSemanticScratch(Work, BasePending + EdgeCount + Count + 1) = False Then
                        Exit Function
                    End If
                    Dim Capacity As Long = SemanticConstantEdgesLength(Edges)
                    Dim Prepared As Long = Capacity
                    If TryGetStorageCapacity(Capacity, EdgeCount + 1, Work.MaximumPending, Prepared) = False Then
                        TryCollectSemanticDependencies = FailSemanticBudget(Work.Failure)
                        Exit Function
                    End If
                    Call ResetSemanticFailure(Work.Failure)
                    If Capacity <> Prepared Then
                        If TryResizeSemanticConstantEdges(Edges, Prepared, True) = False Then
                            Exit Function
                        End If
                    End If
                    Dim Edge As SemanticConstantEdge
                    Edge.Target = Target
                    Edge.SyntaxId = Frame.SyntaxId
                    Edge.NextEdge = -1
                    If Initializer.LastEdge >= 0 Then
                        Dim Previous As SemanticConstantEdge
                        Call ReadSemanticConstantEdge(Previous, Edges(Initializer.LastEdge))
                        Previous.NextEdge = EdgeCount
                        Call WriteSemanticConstantEdge(Edges(Initializer.LastEdge), Previous)
                    Else
                        Initializer.FirstEdge = EdgeCount
                    End If
                    Initializer.LastEdge = EdgeCount
                    Call WriteSemanticConstantEdge(Edges(EdgeCount), Edge)
                    EdgeCount = EdgeCount + 1
                End If
            Else
                If Node.Kind = 3 Or (Node.Kind >= 4 And Node.Kind <= 6) Or Node.Kind = 8 Or Node.Kind = 10 Or Node.Kind = 11 Or Node.Kind = 12 Or Node.Kind = 13 Or (Node.Kind >= 15 And Node.Kind <= 20) Or (Node.Kind >= 24 And Node.Kind <= 30) Then
                    Frame.NextChild = Node.FirstChild
                End If
            End If
        End If
        If Frame.NextChild < 0 Then
            Count = Count - 1
        Else
            Dim Child As Long = Frame.NextChild
            Dim ChildNode As SyntaxNode
            If TryReadSemanticSyntax(Work, Child, ChildNode) = False Then
                Exit Function
            End If
            Frame.NextChild = ChildNode.NextSibling
            Call WriteSemanticDependencyFrame(Frames(Count - 1), Frame)
            Dim Depth As Long = Frame.Depth
            If Node.Kind >= 3 And Node.Kind <= 6 Then
                Depth = Depth + 1
            End If
            If TryPushSemanticDependency(Work, Frames, Count, BasePending + EdgeCount, Child, Depth) = False Then
                Exit Function
            End If
        End If
    Wend
    Call WriteSemanticInitializer(Initializers(InitializerId), Initializer)
    TryCollectSemanticDependencies = True
End Function

Private Function TryEvaluateSemanticInitializer(ByVal Work As SemanticModuleWork, ByRef Initializer As SemanticInitializer, ByVal OuterPending As Long) As Boolean
    TryEvaluateSemanticInitializer = False
    Set Work.Source = Work.Catalog.Sources(Initializer.SourceId)
    Work.Scope = Initializer.Scope
    Dim Declaration As SemanticDeclaration
    If TryReadSemanticDeclaration(Work, Initializer.Declaration, Declaration) = False Then
        Exit Function
    End If
    Dim Context As Long = 0
    If IsSemanticInteger(Declaration.TypeId) Then
        Context = Declaration.TypeId
    End If
    Dim Info As SemanticExpressionInfo
    If TryBindSemanticExpressionWithin(Work, Initializer.SyntaxId, Context, True, False, False, OuterPending, 0, Info) = False Then
        Exit Function
    End If
    If (Info.Flags And 1) = 0 Then
        TryEvaluateSemanticInitializer = SemanticWorkError(Work, 1413, Initializer.SyntaxId)
        Exit Function
    End If
    Dim Placement As Long = 8
    Dim Ordinal As Long = -1
    If Declaration.Kind = 4 Then
        Placement = 9
        Ordinal = Declaration.Ordinal
    End If
    Dim ConversionId As Long = -1
    If TryConvertSemanticExpression(Work, Info, Declaration.TypeId, Placement, Initializer.Declaration, Ordinal, ConversionId) = False Then
        Exit Function
    End If
    If TryMaterializeSemanticExpression(Work, Info) = False Then
        Exit Function
    End If
    Dim Conversion As SemanticFact
    Call ReadSemanticFact(Conversion, Work.Facts(ConversionId))
    Declaration.Value = Conversion.Value
    Declaration.ValueKnown = 1
    Call WriteSemanticDeclaration(Work.Catalog.Declarations(Initializer.Declaration), Declaration)
    Work.Metrics.DeclarationWrites = Work.Metrics.DeclarationWrites + 1
    Dim Link As SemanticFact
    Link.SourceId = Initializer.SourceId
    Link.SyntaxId = Initializer.SyntaxId
    Link.Kind = 9
    Link.TypeId = Declaration.TypeId
    Link.Target = Initializer.Declaration
    Link.Left = Info.Node
    Link.Right = ConversionId
    Link.Auxiliary = -1
    Link.Extra = -1
    Dim LinkId As Long = -1
    TryEvaluateSemanticInitializer = TryAppendSemanticFact(Work, Link, LinkId)
End Function

' Copy only scalar semantic records once at preparation publication. No source,
' catalog graph or per-insertion whole array is copied by this merge.
Private Function TryMergeSemanticInitializerFacts(ByVal Work As SemanticModuleWork) As Boolean
    TryMergeSemanticInitializerFacts = False
    Dim FactBase As Long = Work.Catalog.FactCount
    Dim ValueBase As Long = Work.Catalog.ValueCount
    Dim Index As Long = 0
    While Index < Work.ValueCount
        Dim Node As BoundNode
        Call ReadBoundNode(Node, Work.Values(Index))
        If Node.FirstChild >= 0 Then
            Node.FirstChild = Node.FirstChild + ValueBase
        End If
        If Node.NextSibling >= 0 Then
            Node.NextSibling = Node.NextSibling + ValueBase
        End If
        Dim Id As Long = -1
        If TryAppendCatalogValue(Work.Catalog, Node, Id, Work.Failure) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Work.Failure)
        Index = Index + 1
    Wend
    Index = 0
    While Index < Work.FactCount
        Dim Fact As SemanticFact
        Call ReadSemanticFact(Fact, Work.Facts(Index))
        If Fact.Kind = 1 And Fact.Auxiliary >= 0 Then
            Fact.Auxiliary = Fact.Auxiliary + ValueBase
        End If
        If Fact.Kind = 9 Then
            Fact.Left = Fact.Left + ValueBase
            Fact.Right = Fact.Right + FactBase
        End If
        Dim FactId As Long = -1
        If TryAppendCatalogFact(Work.Catalog, Fact, FactId, Work.Failure) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Work.Failure)
        Index = Index + 1
    Wend
    TryMergeSemanticInitializerFacts = True
End Function

Function TryPrepareSemanticConstants(ByVal Catalog As SemanticCatalog, ByVal Cancellation As SourceCancellation, ByRef Failure As SemanticFailure) As Boolean
    TryPrepareSemanticConstants = False
    Call ResetSemanticFailure(Failure)
    Dim Work As SemanticModuleWork
    Set Work = New SemanticModuleWork
    If Work Is Nothing Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    Set Work.Catalog = Catalog
    Set Work.Cancellation = Cancellation
    If (Work.Catalog Is Catalog) = False Or (Work.Cancellation Is Cancellation) = False Then
        Exit Function
    End If
    Work.Limits = Catalog.Limits
    Work.MaximumPending = Catalog.Limits.MaximumPending
    Work.MaximumFacts = Catalog.Limits.MaximumFacts - Catalog.FactCount - Catalog.ValueCount
    Dim Initializers() As SemanticInitializer
    Dim Map() As Long
    Dim Edges() As SemanticConstantEdge
    Dim Frames() As SemanticConstantFrame
    Dim InitializerCount As Long = 0
    Dim EdgeCount As Long = 0
    Dim Index As Long = 0
    Dim BasePending As Long = Catalog.DeclarationCount
    If TryChargeSemanticScratch(Work, BasePending) = False Then
        Failure = Work.Failure
        Exit Function
    End If
    Call ResetSemanticFailure(Failure)
    If TryResizeSemanticLongs(Map, Catalog.DeclarationCount, False) = False Then
        Exit Function
    End If
    While Index < Catalog.DeclarationCount
        If TryContinueSemanticConstants(Work) = False Then
            Failure = Work.Failure
            Exit Function
        End If
        Dim Declaration As SemanticDeclaration
        If TryReadSemanticDeclaration(Work, Index, Declaration) = False Then
            Failure = Work.Failure
            Exit Function
        End If
        If (Declaration.Kind = 3 Or Declaration.Kind = 4) And Declaration.InitializerSyntaxId >= 0 Then
            If TryChargeSemanticScratch(Work, BasePending + InitializerCount + 1) = False Then
                Failure = Work.Failure
                Exit Function
            End If
            Dim Capacity As Long = SemanticInitializersLength(Initializers)
            Dim Prepared As Long = Capacity
            If TryGetStorageCapacity(Capacity, InitializerCount + 1, Work.MaximumPending, Prepared) = False Then
                TryPrepareSemanticConstants = FailSemanticBudget(Failure)
                Exit Function
            End If
            Call ResetSemanticFailure(Failure)
            If Capacity <> Prepared Then
                If TryResizeSemanticInitializers(Initializers, Prepared, True) = False Then
                    Exit Function
                End If
            End If
            Dim Initializer As SemanticInitializer
            Initializer.Declaration = Index
            Initializer.SourceId = Declaration.SourceId
            Initializer.Scope = Declaration.Scope
            Initializer.SyntaxId = Declaration.InitializerSyntaxId
            Initializer.FirstEdge = -1
            Initializer.LastEdge = -1
            Call WriteSemanticInitializer(Initializers(InitializerCount), Initializer)
            Map(Index) = InitializerCount + 1
            InitializerCount = InitializerCount + 1
        End If
        Index = Index + 1
    Wend
    BasePending = BasePending + InitializerCount
    Index = 0
    While Index < InitializerCount
        If TryContinueSemanticConstants(Work) = False Then
            Failure = Work.Failure
            Exit Function
        End If
        If TryCollectSemanticDependencies(Work, Initializers, Index, Map, Edges, EdgeCount, BasePending) = False Then
            If Work.Failure.Kind = 3 Or Work.Failure.Kind = 8 Then
                Call RecordSemanticDiagnostic(Work.Diagnostic, Work.Failure.Code, Work.Failure.SourceId, Work.Failure.FirstByte, Work.Failure.LastByte, Work.Failure.RelatedSourceId, Work.Failure.RelatedFirst, Work.Failure.RelatedLast)
                Call ReadSemanticInitializer(Initializer, Initializers(Index))
                Initializer.State = 3
                Call WriteSemanticInitializer(Initializers(Index), Initializer)
            Else
                Failure = Work.Failure
                Exit Function
            End If
        End If
        Index = Index + 1
    Wend
    BasePending = BasePending + EdgeCount
    Dim Count As Long = 0
    Index = 0
    While Index < InitializerCount Or Count > 0
        If TryContinueSemanticConstants(Work) = False Then
            Failure = Work.Failure
            Exit Function
        End If
        Dim Frame As SemanticConstantFrame
        If Count = 0 Then
            Call ReadSemanticInitializer(Initializer, Initializers(Index))
            If Initializer.State = 2 Or Initializer.State = 3 Then
                Index = Index + 1
            Else
                Frame.Initializer = Index
                Frame.NextEdge = Initializer.FirstEdge
                Frame.Awaiting = -1
                Initializer.State = 1
                Call WriteSemanticInitializer(Initializers(Index), Initializer)
            End If
        Else
            Call ReadSemanticConstantFrame(Frame, Frames(Count - 1))
            Call ReadSemanticInitializer(Initializer, Initializers(Frame.Initializer))
        End If
        If Initializer.State <> 2 And Initializer.State <> 3 Then
            Dim PushTarget As Long = -1
            If Count = 0 Then
                PushTarget = Frame.Initializer
            Else
                If Frame.Awaiting >= 0 Then
                    Dim Awaited As SemanticInitializer
                    Call ReadSemanticInitializer(Awaited, Initializers(Frame.Awaiting))
                    If Awaited.State = 3 Then
                        Initializer.State = 3
                        Call WriteSemanticInitializer(Initializers(Frame.Initializer), Initializer)
                        Count = Count - 1
                    Else
                        Frame.Awaiting = -1
                        Call WriteSemanticConstantFrame(Frames(Count - 1), Frame)
                    End If
                End If
                If Initializer.State <> 3 Then
                If Frame.NextEdge >= 0 Then
                    Dim Edge As SemanticConstantEdge
                    Call ReadSemanticConstantEdge(Edge, Edges(Frame.NextEdge))
                    Frame.NextEdge = Edge.NextEdge
                    Call WriteSemanticConstantFrame(Frames(Count - 1), Frame)
                    Dim Dependency As SemanticInitializer
                    Call ReadSemanticInitializer(Dependency, Initializers(Edge.Target))
                    If Dependency.State = 1 Then
                        Set Work.Source = Catalog.Sources(Initializer.SourceId)
                        Call SemanticWorkError(Work, 1413, Edge.SyntaxId)
                        If Work.Failure.Kind <> 3 And Work.Failure.Kind <> 8 Then
                            Failure = Work.Failure
                            Exit Function
                        End If
                        Initializer.State = 3
                        Call WriteSemanticInitializer(Initializers(Frame.Initializer), Initializer)
                        Count = Count - 1
                    End If
                    If Dependency.State = 0 Then
                        PushTarget = Edge.Target
                        Frame.Awaiting = PushTarget
                        Call WriteSemanticConstantFrame(Frames(Count - 1), Frame)
                    End If
                    If Dependency.State = 3 Then
                        Initializer.State = 3
                        Call WriteSemanticInitializer(Initializers(Frame.Initializer), Initializer)
                        Count = Count - 1
                    End If
                Else
                    If TryEvaluateSemanticInitializer(Work, Initializer, BasePending + Count) = False Then
                        If Work.Failure.Kind = 3 Or Work.Failure.Kind = 8 Then
                            Call RecordSemanticDiagnostic(Work.Diagnostic, Work.Failure.Code, Work.Failure.SourceId, Work.Failure.FirstByte, Work.Failure.LastByte, Work.Failure.RelatedSourceId, Work.Failure.RelatedFirst, Work.Failure.RelatedLast)
                            Initializer.State = 3
                        Else
                            Failure = Work.Failure
                            Exit Function
                        End If
                    Else
                        Initializer.State = 2
                    End If
                    Call WriteSemanticInitializer(Initializers(Frame.Initializer), Initializer)
                    Count = Count - 1
                End If
                End If
            End If
            If PushTarget >= 0 Then
                If TryChargeSemanticScratch(Work, BasePending + Count + 1) = False Then
                    Failure = Work.Failure
                    Exit Function
                End If
                Capacity = SemanticConstantFramesLength(Frames)
                Prepared = Capacity
                If TryGetStorageCapacity(Capacity, Count + 1, Work.MaximumPending, Prepared) = False Then
                    TryPrepareSemanticConstants = FailSemanticBudget(Failure)
                    Exit Function
                End If
                Call ResetSemanticFailure(Failure)
                If Capacity <> Prepared Then
                    If TryResizeSemanticConstantFrames(Frames, Prepared, True) = False Then
                        Exit Function
                    End If
                End If
                Call ReadSemanticInitializer(Dependency, Initializers(PushTarget))
                Dependency.State = 1
                Call WriteSemanticInitializer(Initializers(PushTarget), Dependency)
                Frame.Initializer = PushTarget
                Frame.NextEdge = Dependency.FirstEdge
                Frame.Awaiting = -1
                Call WriteSemanticConstantFrame(Frames(Count), Frame)
                Count = Count + 1
            End If
        End If
    Wend
    If Work.Diagnostic.Kind <> 0 Then
        Failure = Work.Diagnostic
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    If TryMergeSemanticInitializerFacts(Work) = False Then
        Failure = Work.Failure
        Exit Function
    End If
    Call ResetSemanticFailure(Failure)
    If TryMergeSemanticMetrics(Catalog.Metrics, Work.Metrics) = False Then
        Exit Function
    End If
    Failure.Kind = 0
    Failure.Code = 0
    TryPrepareSemanticConstants = True
End Function
