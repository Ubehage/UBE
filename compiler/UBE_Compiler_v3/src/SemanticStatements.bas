UBE SOURCE 1 MODULE
Attribute UBE_Name = "SemanticStatements"

' One worker owns this explicit continuation arena. It retains scalar syntax,
' scope and bound-node indexes only; original syntax/catalog owners stay frozen.
' The complete live frame count is reserved in expression/call traversal too.
Type SemanticStatementFrame
    SyntaxId As Long
    Kind As Long
    Stage As Long
    NextChild As Long
    Bound As Long
    Tail As Long
    Scope As Long
    Procedure As Long
    WhileTarget As Long
    Depth As Long
    Transparent As Long
End Type
Private Intrinsic Function SemanticStatementFramesLength(ByRef Values() As SemanticStatementFrame) As Long
Attribute SemanticStatementFramesLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function TryResizeSemanticStatementFrames(ByRef Values() As SemanticStatementFrame, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeSemanticStatementFrames.UBE_Primitive = "Array.TryResize"
End Function
Private Sub ReadSemanticStatementFrame(ByRef Destination As SemanticStatementFrame, ByRef Original As SemanticStatementFrame)
    Destination = Original
End Sub
Private Sub WriteSemanticStatementFrame(ByRef Destination As SemanticStatementFrame, ByRef Original As SemanticStatementFrame)
    Destination = Original
End Sub

Private Function TryPushSemanticStatement(ByVal Work As SemanticModuleWork, ByRef Frames() As SemanticStatementFrame, ByRef Count As Long, ByVal SyntaxId As Long, ByVal Kind As Long, ByVal Scope As Long, ByVal Procedure As Long, ByVal WhileTarget As Long, ByVal Depth As Long) As Boolean
    TryPushSemanticStatement = False
    Dim Maximum As Long = Work.MaximumPending
    If Work.Limits.MaximumPending < Maximum Then
        Maximum = Work.Limits.MaximumPending
    End If
    If Maximum < 0 Or Count < 0 Or Depth < 0 Then
        TryPushSemanticStatement = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    If Count >= Maximum Or Depth > Work.Limits.MaximumDepth Then
        TryPushSemanticStatement = FailSemanticBudget(Work.Failure)
        Exit Function
    End If
    Dim Capacity As Long = SemanticStatementFramesLength(Frames)
    Dim Prepared As Long = Capacity
    If TryGetStorageCapacity(Capacity, Count + 1, Maximum, Prepared) = False Then
        TryPushSemanticStatement = FailSemanticBudget(Work.Failure)
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    If Capacity <> Prepared Then
        If TryResizeSemanticStatementFrames(Frames, Prepared, True) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Work.Failure)
    End If
    Dim Frame As SemanticStatementFrame
    Frame.SyntaxId = SyntaxId
    Frame.Kind = Kind
    Frame.NextChild = -1
    Frame.Bound = -1
    Frame.Tail = -1
    Frame.Scope = Scope
    Frame.Procedure = Procedure
    Frame.WhileTarget = WhileTarget
    Frame.Depth = Depth
    Call ResetSemanticFailure(Work.Failure)
    Call WriteSemanticStatementFrame(Frames(Count), Frame)
    Count = Count + 1
    If Count > Work.Metrics.MaximumPending Then
        Work.Metrics.MaximumPending = Count
    End If
    If Depth > Work.Metrics.MaximumDepth Then
        Work.Metrics.MaximumDepth = Depth
    End If
    TryPushSemanticStatement = True
End Function

Private Function TryNewSemanticStatement(ByVal Work As SemanticModuleWork, ByVal SyntaxId As Long, ByVal Kind As Long, ByVal TypeId As Long, ByVal Target As Long, ByVal Flags As Long, ByRef Id As Long) As Boolean
    Dim Node As BoundNode
    Node.SourceId = Work.Source.SourceId
    Node.SyntaxId = SyntaxId
    Node.Kind = Kind
    Node.TypeId = TypeId
    Node.Target = Target
    Node.Flags = Flags
    Node.FirstChild = -1
    Node.NextSibling = -1
    Node.Auxiliary = -1
    Call ResetSemanticFailure(Work.Failure)
    TryNewSemanticStatement = TryAppendBoundNode(Work, Node, Id)
End Function

' Definition lookup uses the frozen region index, never a declaration-table
' scan. The source syntax identity must match the selected catalog row exactly.
Private Function TrySemanticStatementDeclaration(ByVal Work As SemanticModuleWork, ByVal SyntaxId As Long, ByVal HeaderId As Long, ByRef Id As Long, ByRef Declaration As SemanticDeclaration) As Boolean
    TrySemanticStatementDeclaration = False
    Dim Container As SyntaxNode
    If TryReadSemanticSyntax(Work, HeaderId, Container) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    Dim Current As Long = Container.FirstChild
    Dim NameSyntax As Long = -1
    While Current >= 0
        Dim Child As SyntaxNode
        If TryReadSemanticSyntax(Work, Current, Child) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Work.Failure)
        If Child.Kind = 1 Then
            NameSyntax = Current
            Exit While
        End If
        Current = Child.NextSibling
    Wend
    If NameSyntax < 0 Then
        TrySemanticStatementDeclaration = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    Dim Level As Long = 0
    If TryResolveSemanticExpressionName(Work, NameSyntax, True, Id, Level) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    If TryReadSemanticDeclaration(Work, Id, Declaration) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    If Declaration.SourceId <> Work.Source.SourceId Or Declaration.SyntaxId <> SyntaxId Or Declaration.Scope <> Work.Scope Then
        TrySemanticStatementDeclaration = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    TrySemanticStatementDeclaration = True
End Function

Private Function TrySemanticStatementValue(ByVal Work As SemanticModuleWork, ByVal SyntaxId As Long, ByVal Destination As Long, ByVal Placement As Long, ByVal Target As Long, ByVal Pending As Long, ByVal Depth As Long, ByRef Info As SemanticExpressionInfo, ByRef Conversion As Long) As Boolean
    TrySemanticStatementValue = False
    Dim Context As Long = 0
    If IsSemanticInteger(Destination) Then
        Context = Destination
    End If
    Call ResetSemanticFailure(Work.Failure)
    If TryBindSemanticExpressionWithin(Work, SyntaxId, Context, False, False, False, Pending, Depth, Info) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    If TryConvertSemanticExpression(Work, Info, Destination, Placement, Target, -1, Conversion) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    TrySemanticStatementValue = TryMaterializeSemanticExpression(Work, Info)
End Function

Private Function TryBindSemanticStorageStatement(ByVal Work As SemanticModuleWork, ByRef Frame As SemanticStatementFrame, ByVal Pending As Long) As Boolean
    TryBindSemanticStorageStatement = False
    Dim Id As Long = -1
    Dim Declaration As SemanticDeclaration
    If TrySemanticStatementDeclaration(Work, Frame.SyntaxId, Frame.SyntaxId, Id, Declaration) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    If Declaration.Kind <> 2 Then
        TryBindSemanticStorageStatement = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    ' Catalog storage is already visible to its own initializer. The operation
    ' plan explicitly establishes neutral storage first and retains it on a
    ' runtime-dependent initializer failure; no execution is performed here.
    If TryNewSemanticStatement(Work, Frame.SyntaxId, 103, Declaration.TypeId, Id, 3, Frame.Bound) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    If Declaration.InitializerSyntaxId >= 0 Then
        Dim Info As SemanticExpressionInfo
        Dim Conversion As Long = -1
        If TrySemanticStatementValue(Work, Declaration.InitializerSyntaxId, Declaration.TypeId, 4, Id, Pending, Frame.Depth, Info, Conversion) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Work.Failure)
        Dim Tail As Long = -1
        If TryLinkBoundChild(Work, Frame.Bound, Info.Node, Tail) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Work.Failure)
        Dim Node As BoundNode
        Call ReadBoundNode(Node, Work.Values(Frame.Bound))
        Node.Auxiliary = Conversion
        Call WriteBoundNode(Work.Values(Frame.Bound), Node)
        Work.Metrics.NodeWrites = Work.Metrics.NodeWrites + 1
        Dim Fact As SemanticFact
        Fact.SourceId = Work.Source.SourceId
        Fact.SyntaxId = Declaration.InitializerSyntaxId
        Fact.Kind = 9
        Fact.TypeId = Declaration.TypeId
        Fact.Target = Id
        Fact.Left = Info.Node
        Fact.Right = Conversion
        Fact.Auxiliary = -1
        Fact.Extra = -1
        Dim FactId As Long = -1
        If TryAppendSemanticFact(Work, Fact, FactId) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Work.Failure)
    End If
    TryBindSemanticStorageStatement = True
End Function

Private Function TryBindSemanticAssignment(ByVal Work As SemanticModuleWork, ByRef Frame As SemanticStatementFrame, ByRef Syntax As SyntaxNode, ByVal Pending As Long) As Boolean
    TryBindSemanticAssignment = False
    Dim TargetSyntax As Long = Syntax.FirstChild
    Dim TargetNode As SyntaxNode
    If TryReadSemanticSyntax(Work, TargetSyntax, TargetNode) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    Dim Id As Long = -1
    Dim Level As Long = 0
    If TryResolveSemanticExpressionName(Work, TargetSyntax, True, Id, Level) = False Then
        Dim OriginalFailure As SemanticFailure = Work.Failure
        If OriginalFailure.Code = 1431 Then
            If Work.Diagnostic.Code = 1431 And Work.Diagnostic.SourceId = OriginalFailure.SourceId And Work.Diagnostic.FirstByte = OriginalFailure.FirstByte And Work.Diagnostic.LastByte = OriginalFailure.LastByte Then
                Work.Diagnostic.FirstByte = Syntax.FirstByte
                Work.Diagnostic.LastByte = Syntax.LastByte
            End If
            OriginalFailure.FirstByte = Syntax.FirstByte
            OriginalFailure.LastByte = Syntax.LastByte
            Work.Failure = OriginalFailure
        End If
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    Dim Declaration As SemanticDeclaration
    If TryReadSemanticDeclaration(Work, Id, Declaration) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    Dim ResultTarget As Boolean = Declaration.Kind = 6 And Id = Frame.Procedure And Level = 2
    If Declaration.Kind <> 2 And Declaration.Kind <> 4 And ResultTarget = False Then
        TryBindSemanticAssignment = SemanticWorkError(Work, 1414, TargetSyntax)
        Exit Function
    End If
    If Frame.Kind = 42 Then
        TryBindSemanticAssignment = SemanticWorkError(Work, 1415, Frame.SyntaxId)
        Exit Function
    End If
    Dim BindingSyntax As Long = TargetSyntax
    If TargetNode.Kind = 34 Then
        Dim Qualifier As SyntaxNode
        If TryReadSemanticSyntax(Work, TargetNode.FirstChild, Qualifier) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Work.Failure)
        BindingSyntax = Qualifier.NextSibling
    End If
    Dim Role As Long = 3
    Dim Placement As Long = 3
    If ResultTarget Then
        Role = 4
        Placement = 5
    End If
    Dim Binding As Long = -1
    If TryAppendSemanticBinding(Work, BindingSyntax, Id, Role, Level, Binding) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    If TargetNode.NextSibling < 0 Then
        TryBindSemanticAssignment = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    If TryNewSemanticStatement(Work, Frame.SyntaxId, 104, Declaration.TypeId, Id, 0, Frame.Bound) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    Dim Info As SemanticExpressionInfo
    Dim Conversion As Long = -1
    If TrySemanticStatementValue(Work, TargetNode.NextSibling, Declaration.TypeId, Placement, Id, Pending, Frame.Depth, Info, Conversion) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    Dim Tail As Long = -1
    If TryLinkBoundChild(Work, Frame.Bound, Info.Node, Tail) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    Dim Node As BoundNode
    Call ReadBoundNode(Node, Work.Values(Frame.Bound))
    Node.Auxiliary = Conversion
    Call WriteBoundNode(Work.Values(Frame.Bound), Node)
    Work.Metrics.NodeWrites = Work.Metrics.NodeWrites + 1
    TryBindSemanticAssignment = True
End Function

Private Function TryBindSemanticCallStatement(ByVal Work As SemanticModuleWork, ByRef Frame As SemanticStatementFrame, ByVal Pending As Long) As Boolean
    TryBindSemanticCallStatement = False
    Dim Info As SemanticExpressionInfo
    Call ResetSemanticFailure(Work.Failure)
    If TryBindSemanticExpressionWithin(Work, Frame.SyntaxId, 0, False, False, True, Pending, Frame.Depth, Info) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    If TryMaterializeSemanticExpression(Work, Info) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    If TryNewSemanticStatement(Work, Frame.SyntaxId, 105, Info.TypeId, Info.Target, 0, Frame.Bound) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    Dim Tail As Long = -1
    TryBindSemanticCallStatement = TryLinkBoundChild(Work, Frame.Bound, Info.Node, Tail)
End Function

Private Function TryBindSemanticExitStatement(ByVal Work As SemanticModuleWork, ByRef Frame As SemanticStatementFrame, ByRef Syntax As SyntaxNode) As Boolean
    TryBindSemanticExitStatement = False
    Dim Word As SyntaxNode
    If TryReadSemanticSyntax(Work, Syntax.FirstChild, Word) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    Dim Flags As Long = 0
    Dim Target As Long = -1
    Dim Matches As Boolean = False
    If TrySemanticWord(Work.Catalog, Work.Source.SourceId, Word, "while", Matches, Work.Failure) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    If Matches And Frame.WhileTarget >= 0 Then
        Flags = 3
        Target = Frame.WhileTarget
    End If
    If Frame.Procedure >= 0 Then
        Dim Declaration As SemanticDeclaration
        If TryReadSemanticDeclaration(Work, Frame.Procedure, Declaration) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Work.Failure)
        If TrySemanticWord(Work.Catalog, Work.Source.SourceId, Word, "sub", Matches, Work.Failure) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Work.Failure)
        If Matches And Declaration.Kind = 5 Then
            Flags = 1
            Target = Frame.Procedure
        End If
        If TrySemanticWord(Work.Catalog, Work.Source.SourceId, Word, "function", Matches, Work.Failure) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Work.Failure)
        If Matches And Declaration.Kind = 6 Then
            Flags = 2
            Target = Frame.Procedure
        End If
    End If
    If Flags = 0 Then
        TryBindSemanticExitStatement = SemanticWorkError(Work, 1421, Frame.SyntaxId)
        Exit Function
    End If
    TryBindSemanticExitStatement = TryNewSemanticStatement(Work, Frame.SyntaxId, 108, 0, Target, Flags, Frame.Bound)
End Function

' Starts one frame without recursively entering another statement. Metadata and
' Const/default expressions have already been prepared in the frozen catalog.
Private Function TryStartSemanticStatement(ByVal Work As SemanticModuleWork, ByRef Frames() As SemanticStatementFrame, ByVal Count As Long, ByRef Frame As SemanticStatementFrame, ByRef Complete As Boolean) As Boolean
    TryStartSemanticStatement = False
    Complete = False
    Dim Syntax As SyntaxNode
    If TryReadSemanticSyntax(Work, Frame.SyntaxId, Syntax) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    If Frame.Kind = 45 Or Frame.Kind = 46 Or Frame.Kind = 48 Or Frame.Kind = -1 Then
        Dim Kind As Long = 102
        If Frame.Kind = 45 Then
            Kind = 100
        End If
        If TryNewSemanticStatement(Work, Frame.SyntaxId, Kind, 0, Frame.Scope, 0, Frame.Bound) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Work.Failure)
        If Frame.Kind = 45 Then
            Work.Root = Frame.Bound
        End If
        Frame.NextChild = Syntax.FirstChild
        If Frame.Kind = -1 Then
            ' An inline branch has one complete ownership block even when its
            ' one syntax statement expands into several storage declarations.
            Frame.NextChild = Frame.SyntaxId
        End If
        Frame.Stage = 1
        TryStartSemanticStatement = True
        Exit Function
    End If
    If Frame.Kind = 65 Or Frame.Kind = 66 Then
        Dim Id As Long = -1
        Dim Declaration As SemanticDeclaration
        If TrySemanticStatementDeclaration(Work, Frame.SyntaxId, Syntax.FirstChild, Id, Declaration) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Work.Failure)
        If Declaration.Kind <> 5 And Declaration.Kind <> 6 Then
            TryStartSemanticStatement = FailSemanticDomain(Work.Failure)
            Exit Function
        End If
        If Frame.Kind = 66 Then
            Complete = True
            TryStartSemanticStatement = True
            Exit Function
        End If
        If Declaration.BodySyntaxId < 0 Then
            TryStartSemanticStatement = FailSemanticDomain(Work.Failure)
            Exit Function
        End If
        If TryNewSemanticStatement(Work, Frame.SyntaxId, 101, Declaration.TypeId, Id, 0, Frame.Bound) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Work.Failure)
        Frame.Scope = Id
        Frame.Procedure = Id
        Frame.WhileTarget = -1
        Frame.NextChild = Declaration.BodySyntaxId
        Frame.Stage = 1
        TryStartSemanticStatement = True
        Exit Function
    End If
    If Frame.Kind = 54 Or Frame.Kind = 70 Then
        If Count < 2 Then
            TryStartSemanticStatement = FailSemanticDomain(Work.Failure)
            Exit Function
        End If
        Call ResetSemanticFailure(Work.Failure)
        Dim Parent As SemanticStatementFrame
        Call ReadSemanticStatementFrame(Parent, Frames(Count - 2))
        Frame.Bound = Parent.Bound
        Frame.Tail = Parent.Tail
        Frame.Transparent = 1
        Frame.NextChild = Syntax.FirstChild
        Frame.Stage = 1
        TryStartSemanticStatement = True
        Exit Function
    End If
    If Frame.Kind = 67 Or Frame.Kind = 68 Or Frame.Kind = 69 Or Frame.Kind = 71 Then
        Kind = 106
        If Frame.Kind = 71 Then
            Kind = 107
        End If
        If TryNewSemanticStatement(Work, Frame.SyntaxId, Kind, 0, Frame.Scope, 0, Frame.Bound) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Work.Failure)
        If Frame.Kind = 71 Then
            Frame.WhileTarget = Frame.Bound
        End If
        Dim Info As SemanticExpressionInfo
        Dim Conversion As Long = -1
        If TrySemanticStatementValue(Work, Syntax.FirstChild, 1, 7, Frame.SyntaxId, Count, Frame.Depth, Info, Conversion) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Work.Failure)
        If TryLinkBoundChild(Work, Frame.Bound, Info.Node, Frame.Tail) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Work.Failure)
        Dim Condition As SyntaxNode
        If TryReadSemanticSyntax(Work, Syntax.FirstChild, Condition) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Work.Failure)
        Frame.NextChild = Condition.NextSibling
        Frame.Stage = 1
        TryStartSemanticStatement = True
        Exit Function
    End If
    Complete = True
    If Frame.Kind = 77 Then
        TryStartSemanticStatement = TryBindSemanticStorageStatement(Work, Frame, Count)
        Exit Function
    End If
    If Frame.Kind = 40 Or Frame.Kind = 41 Or Frame.Kind = 42 Then
        TryStartSemanticStatement = TryBindSemanticAssignment(Work, Frame, Syntax, Count)
        Exit Function
    End If
    If Frame.Kind = 43 Or Frame.Kind = 44 Then
        TryStartSemanticStatement = TryBindSemanticCallStatement(Work, Frame, Count)
        Exit Function
    End If
    If Frame.Kind = 59 Then
        TryStartSemanticStatement = TryBindSemanticExitStatement(Work, Frame, Syntax)
        Exit Function
    End If
    If Frame.Kind = 55 Or Frame.Kind = 51 Or Frame.Kind = 52 Or Frame.Kind = 64 Then
        TryStartSemanticStatement = True
        Exit Function
    End If
    If Frame.Kind = 50 And Frame.Procedure < 0 And Frame.Scope = Work.Source.ModuleDeclaration And Syntax.ChildCount = 0 Then
        ' Native unit admission already owns the envelope/name spans. Its leaf
        ' header50 is metadata, distinct from a procedure's header50 subtree.
        TryStartSemanticStatement = True
        Exit Function
    End If
    If Frame.Kind = 49 Then
        ' Locate the retained keyword token without visiting the scalar operand.
        Dim Keyword As SourceToken
        Dim TokenFailure As Long = 5
        If TryFindSemanticSourceToken(Work.Source.SyntaxInput.Tokens, Syntax.FirstByte, Keyword, TokenFailure) = False Then
            If TokenFailure = 1 Then
                TryStartSemanticStatement = FailSemanticDomain(Work.Failure)
            End If
            Exit Function
        End If
        Call RecordSemanticDiagnostic(Work.Diagnostic, 1400, Work.Source.SourceId, Keyword.First.ByteOffset, Keyword.Last.ByteOffset, -1, 0, 0)
        Work.Failure = Work.Diagnostic
        Exit Function
    End If
    TryStartSemanticStatement = SemanticWorkError(Work, 1400, Frame.SyntaxId)
End Function

' Catalog preparation is complete on entry. This binds one native MODULE into
' private facts/values only: no publication, worker admission or catalog write.
' Strict depth-first written order permits stopping on the first body error;
' unsupported constructs diagnose at their own span without inspecting children.
Function TryBindSemanticModule(ByVal Work As SemanticModuleWork) As Boolean
    TryBindSemanticModule = False
    If Work Is Nothing Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    If Work.Catalog Is Nothing Then
        TryBindSemanticModule = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    If Work.Source Is Nothing Then
        TryBindSemanticModule = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    If Work.Cancellation Is Nothing Then
        TryBindSemanticModule = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    If Work.FactCount <> 0 Or Work.ValueCount <> 0 Or Work.Limits.MaximumDepth < 0 Then
        TryBindSemanticModule = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    Work.Root = -1
    Work.Scope = Work.Source.ModuleDeclaration
    Dim RootSyntax As Long = Work.Source.SyntaxInput.Syntax(0).Root
    Dim RootNode As SyntaxNode
    If TryReadSemanticSyntax(Work, RootSyntax, RootNode) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    If RootNode.Kind <> 45 Then
        TryBindSemanticModule = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    Dim Frames() As SemanticStatementFrame
    Dim Count As Long = 0
    If TryPushSemanticStatement(Work, Frames, Count, RootSyntax, 45, Work.Scope, -1, -1, 0) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    Dim Healthy As Boolean = True
    While Count > 0 And Healthy
        Call ResetSemanticFailure(Work.Failure)
        If TryContinueSemanticWork(Work) = False Then
            Healthy = False
        Else
            Dim Frame As SemanticStatementFrame
            Call ReadSemanticStatementFrame(Frame, Frames(Count - 1))
            Work.Scope = Frame.Scope
            Work.Metrics.Transitions = Work.Metrics.Transitions + 1
            Dim Complete As Boolean = False
            If Frame.Stage = 0 Then
                Healthy = TryStartSemanticStatement(Work, Frames, Count, Frame, Complete)
                If Healthy Then
                    Call ResetSemanticFailure(Work.Failure)
                    Call WriteSemanticStatementFrame(Frames(Count - 1), Frame)
                End If
            Else
                Complete = Frame.NextChild < 0
                If Complete = False Then
                    Dim ChildId As Long = Frame.NextChild
                    Dim Child As SyntaxNode
                    Healthy = TryReadSemanticSyntax(Work, ChildId, Child)
                    If Healthy Then
                        Frame.NextChild = Child.NextSibling
                        If Frame.Kind = 65 Or Frame.Kind = -1 Then
                            Frame.NextChild = -1
                        End If
                        Call ResetSemanticFailure(Work.Failure)
                        Call WriteSemanticStatementFrame(Frames(Count - 1), Frame)
                        Dim Visit As Boolean = True
                        If Frame.Kind = 54 Then
                            Visit = Child.Kind = 77
                        End If
                        If Visit Then
                            Dim Depth As Long = Frame.Depth
                            Dim ChildKind As Long = Child.Kind
                            If Frame.Kind = 67 And Child.Kind <> 46 And Child.Kind <> 48 Then
                                ChildKind = -1
                            Else
                                If Child.Kind = 65 Or Child.Kind = 66 Then
                                    Depth = 1
                                End If
                                If Child.Kind >= 67 And Child.Kind <= 71 Then
                                    Depth = Depth + 1
                                End If
                            End If
                            Healthy = TryPushSemanticStatement(Work, Frames, Count, ChildId, ChildKind, Frame.Scope, Frame.Procedure, Frame.WhileTarget, Depth)
                        End If
                    End If
                End If
            End If
            If Healthy And Complete Then
                Count = Count - 1
                If Count > 0 Then
                    Call ResetSemanticFailure(Work.Failure)
                    Dim Parent As SemanticStatementFrame
                    Call ReadSemanticStatementFrame(Parent, Frames(Count - 1))
                    If Frame.Transparent <> 0 Then
                        If Parent.Bound <> Frame.Bound Then
                            Healthy = FailSemanticDomain(Work.Failure)
                        Else
                            Parent.Tail = Frame.Tail
                        End If
                    Else
                        If Frame.Bound >= 0 Then
                            Healthy = TryLinkBoundChild(Work, Parent.Bound, Frame.Bound, Parent.Tail)
                        End If
                    End If
                    If Healthy Then
                        Call ResetSemanticFailure(Work.Failure)
                        Call WriteSemanticStatementFrame(Frames(Count - 1), Parent)
                    End If
                End If
            End If
        End If
    Wend
    If Healthy = False Then
        If Work.Failure.Kind = 3 Or Work.Failure.Kind = 8 Then
            Call RecordSemanticDiagnostic(Work.Diagnostic, Work.Failure.Code, Work.Failure.SourceId, Work.Failure.FirstByte, Work.Failure.LastByte, Work.Failure.RelatedSourceId, Work.Failure.RelatedFirst, Work.Failure.RelatedLast)
            Work.Failure = Work.Diagnostic
        End If
        Exit Function
    End If
    Work.Scope = Work.Source.ModuleDeclaration
    TryBindSemanticModule = True
End Function
