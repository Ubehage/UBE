UBE SOURCE 1 MODULE
Attribute UBE_Name = "SemanticExpressionTraversal"

' Source nesting and flat arithmetic both use this bounded explicit workspace.
' Depth counts groups, prefixes and calls, not left-associative tree height.
Type SemanticExpressionFrame
    SyntaxId As Long
    Stage As Long
    Kind As Long
    Context As Long
    Depth As Long
    Flags As Long
    Child As Long
    PlanId As Long
    Left As SemanticExpressionInfo
End Type
Private Intrinsic Function SemanticExpressionFramesLength(ByRef Values() As SemanticExpressionFrame) As Long
Attribute SemanticExpressionFramesLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function TryResizeSemanticExpressionFrames(ByRef Values() As SemanticExpressionFrame, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeSemanticExpressionFrames.UBE_Primitive = "Array.TryResize"
End Function
Private Sub ReadSemanticExpressionFrame(ByRef Destination As SemanticExpressionFrame, ByRef Original As SemanticExpressionFrame)
    Destination = Original
End Sub
Private Sub WriteSemanticExpressionFrame(ByRef Destination As SemanticExpressionFrame, ByRef Original As SemanticExpressionFrame)
    Destination = Original
End Sub

Private Function TryPushSemanticExpression(ByVal Work As SemanticModuleWork, ByRef Frames() As SemanticExpressionFrame, ByRef Count As Long, ByRef Pending As Long, ByVal SyntaxId As Long, ByVal Context As Long, ByVal Depth As Long, ByVal Flags As Long) As Boolean
    TryPushSemanticExpression = False
    If Depth > Work.Limits.MaximumDepth Then
        TryPushSemanticExpression = FailSemanticBudget(Work.Failure)
        Exit Function
    End If
    Dim Maximum As Long = Work.MaximumPending
    If Work.Limits.MaximumPending < Maximum Then
        Maximum = Work.Limits.MaximumPending
    End If
    If Count >= Maximum Or Pending >= Maximum Then
        TryPushSemanticExpression = FailSemanticBudget(Work.Failure)
        Exit Function
    End If
    Dim Capacity As Long = SemanticExpressionFramesLength(Frames)
    Dim Prepared As Long = Capacity
    If TryGetStorageCapacity(Capacity, Count + 1, Maximum, Prepared) = False Then
        TryPushSemanticExpression = FailSemanticBudget(Work.Failure)
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    If Prepared <> Capacity Then
        If TryResizeSemanticExpressionFrames(Frames, Prepared, True) = False Then
            Exit Function
        End If
    End If
    Dim Frame As SemanticExpressionFrame
    Frame.SyntaxId = SyntaxId
    Frame.Context = Context
    Frame.Depth = Depth
    Frame.Flags = Flags
    Frame.Child = -1
    Frame.PlanId = -1
    Call WriteSemanticExpressionFrame(Frames(Count), Frame)
    Count = Count + 1
    Pending = Pending + 1
    If Pending > Work.Metrics.MaximumPending Then
        Work.Metrics.MaximumPending = Pending
    End If
    If Depth > Work.Metrics.MaximumDepth Then
        Work.Metrics.MaximumDepth = Depth
    End If
    TryPushSemanticExpression = True
End Function

' Recognize a single signed literal through groups, without absorbing another
' unary operation. For a match each grouped token is read at most twice.
Private Function TryFindSignedSemanticLiteral(ByVal Work As SemanticModuleWork, ByVal Operand As Long, ByVal Depth As Long, ByRef Literal As Long, ByRef Groups As Long) As Boolean
    TryFindSignedSemanticLiteral = False
    Literal = -1
    Groups = 0
    Dim At As Long = Operand
    Dim Node As SyntaxNode
    If TryReadSemanticSyntax(Work, At, Node) = False Then
        Exit Function
    End If
    While Node.Kind = 3
        Groups = Groups + 1
        If Depth + Groups > Work.Limits.MaximumDepth Then
            TryFindSignedSemanticLiteral = FailSemanticBudget(Work.Failure)
            Exit Function
        End If
        At = Node.FirstChild
        If TryReadSemanticSyntax(Work, At, Node) = False Then
            Exit Function
        End If
    Wend
    If Node.Kind = 2 Then
        Call ResetSemanticFailure(Work.Failure)
        Dim Character As Long = Work.Source.SyntaxInput.Owner.Document.Bytes(Node.FirstByte)
        If Character >= 48 And Character <= 57 Then
            Literal = At
        End If
    End If
    TryFindSignedSemanticLiteral = True
End Function

Private Function TryBindSignedSemanticLiteral(ByVal Work As SemanticModuleWork, ByRef Frame As SemanticExpressionFrame, ByRef Syntax As SyntaxNode, ByVal Literal As Long, ByVal Groups As Long, ByRef Info As SemanticExpressionInfo) As Boolean
    TryBindSignedSemanticLiteral = False
    If TryReadSemanticLiteral(Work, Literal, Frame.Context, Frame.Kind = 5, Info) = False Then
        If Work.Failure.Kind = 3 Or Work.Failure.Kind = 8 Then
            TryBindSignedSemanticLiteral = SemanticWorkError(Work, Work.Failure.Code, Frame.SyntaxId)
        End If
        Exit Function
    End If
    Dim SuffixedNegative As Boolean = Info.Selection = 4 And Frame.Kind = 5
    If SuffixedNegative Then
        ' A suffixed literal remains the positive operand of ordinary negation.
        ' Only the still-deferred signed-minimum spelling used the combined read.
        Dim Positive As LongLong = 0
        Dim Status As Long = 5
        If TryEvaluateInteger(6, Info.Value, 0, SemanticLongLongMinimum(), SemanticLongLongMaximum(), Positive, Status) = False Then
            TryBindSignedSemanticLiteral = FailSemanticDomain(Work.Failure)
            Exit Function
        End If
        Info.Value = Positive
    End If
    If Info.Selection <> 4 Then
        Info.Flags = Info.Flags Or 2048
    End If
    If (Frame.Flags And 64) <> 0 Then
        Info.Flags = Info.Flags Or 64
    End If
    If TryAnnotateSemanticExpression(Work, Info) = False Then
        Exit Function
    End If
    Dim At As Long = Syntax.FirstChild
    While At <> Literal
        Dim Group As SyntaxNode
        If TryReadSemanticSyntax(Work, At, Group) = False Then
            Exit Function
        End If
        Info.SyntaxId = At
        Info.Annotation = -1
        Info.Flags = Info.Flags Or 4
        If TryAnnotateSemanticExpression(Work, Info) = False Then
            Exit Function
        End If
        At = Group.FirstChild
    Wend
    Dim Promoted As Long = SemanticPromotedInteger(Info.TypeId)
    Dim Conversion As Long = -1
    If TryConvertSemanticExpression(Work, Info, Promoted, 1, Frame.SyntaxId, 0, Conversion) = False Then
        Exit Function
    End If
    Info.TypeId = Promoted
    If SuffixedNegative Then
        Dim Minimum As LongLong = 0
        Dim Maximum As LongLong = 0
        If TrySemanticIntegerBounds(Promoted, Minimum, Maximum) = False Then
            TryBindSignedSemanticLiteral = FailSemanticDomain(Work.Failure)
            Exit Function
        End If
        Status = 5
        Dim NegativeValue As LongLong = 0
        If TryEvaluateInteger(6, Info.Value, 0, Minimum, Maximum, NegativeValue, Status) = False Then
            TryBindSignedSemanticLiteral = SemanticWorkError(Work, 1410, Frame.SyntaxId)
            Exit Function
        End If
        Info.Value = NegativeValue
    End If
    Info.SyntaxId = Frame.SyntaxId
    Info.OriginSyntaxId = Frame.SyntaxId
    Info.Flags = (Info.Flags And Not 4) Or 16
    Info.Annotation = -1
    If Frame.Depth + Groups + 1 > Work.Metrics.MaximumDepth Then
        Work.Metrics.MaximumDepth = Frame.Depth + Groups + 1
    End If
    TryBindSignedSemanticLiteral = True
End Function

' A complete expression invocation owns both continuation arenas. No helper
' recursively evaluates a child or deep-copies an arena into a frame.
Function TryBindSemanticExpression(ByVal Work As SemanticModuleWork, ByVal SyntaxId As Long, ByVal IntegerContext As Long, ByVal RequiredConstant As Boolean, ByVal RequireStorage As Boolean, ByVal Discard As Boolean, ByRef Info As SemanticExpressionInfo) As Boolean
    TryBindSemanticExpression = TryBindSemanticExpressionWithin(Work, SyntaxId, IntegerContext, RequiredConstant, RequireStorage, Discard, 0, 0, Info)
End Function

Function TryBindSemanticExpressionWithin(ByVal Work As SemanticModuleWork, ByVal SyntaxId As Long, ByVal IntegerContext As Long, ByVal RequiredConstant As Boolean, ByVal RequireStorage As Boolean, ByVal Discard As Boolean, ByVal OuterPending As Long, ByVal OuterDepth As Long, ByRef Info As SemanticExpressionInfo) As Boolean
    TryBindSemanticExpressionWithin = False
    Call ResetSemanticFailure(Work.Failure)
    Dim Frames() As SemanticExpressionFrame
    Dim Calls As SemanticCallState
    Dim Count As Long = 0
    Dim Pending As Long = OuterPending
    Dim InitialFlags As Long = 0
    If RequireStorage Then
        InitialFlags = 2
    End If
    If Discard Then
        InitialFlags = InitialFlags Or 4
    End If
    If TryPushSemanticExpression(Work, Frames, Count, Pending, SyntaxId, IntegerContext, OuterDepth, InitialFlags) = False Then
        Exit Function
    End If
    Dim Returned As SemanticExpressionInfo
    While Count > 0
        Call ResetSemanticFailure(Work.Failure)
        If TryContinueSemanticWork(Work) = False Then
            Exit Function
        End If
        Dim Frame As SemanticExpressionFrame
        Call ReadSemanticExpressionFrame(Frame, Frames(Count - 1))
        Work.Metrics.Transitions = Work.Metrics.Transitions + 1
        Dim Syntax As SyntaxNode
        If TryReadSemanticSyntax(Work, Frame.SyntaxId, Syntax) = False Then
            Exit Function
        End If
        Dim Complete As Boolean = False
        Dim Push As Boolean = False
        Dim ChildSyntax As Long = -1
        Dim ChildContext As Long = 0
        Dim ChildDepth As Long = Frame.Depth
        Dim ChildFlags As Long = Frame.Flags And 64
        Dim Skipped As Boolean = (Frame.Flags And 64) <> 0
        If Frame.Stage = 0 Then
            Frame.Kind = Syntax.Kind
            If Syntax.Kind = 2 Then
                If TryReadSemanticLiteral(Work, Frame.SyntaxId, Frame.Context, False, Returned) = False Then
                    Exit Function
                End If
                Complete = True
            Else
                If Syntax.Kind = 1 Or Syntax.Kind = 34 Then
                Dim DeclarationId As Long = -1
                Dim Level As Long = 0
                If TryResolveSemanticExpressionName(Work, Frame.SyntaxId, False, DeclarationId, Level) = False Then
                    Exit Function
                End If
                Dim Declaration As SemanticDeclaration
                If TryReadSemanticDeclaration(Work, DeclarationId, Declaration) = False Then
                    Exit Function
                End If
                If Declaration.Kind = 5 Or Declaration.Kind = 6 Then
                    Frame.Stage = 5
                    Frame.Child = DeclarationId
                    Frame.Left.Selection = Level
                Else
                    If TryReadSemanticStorage(Work, Frame.SyntaxId, DeclarationId, Level, RequiredConstant, Skipped, (Frame.Flags And 2) <> 0, Returned) = False Then
                        Exit Function
                    End If
                    Complete = True
                End If
            Else
                If Syntax.Kind = 38 Or Syntax.Kind = 43 Or Syntax.Kind = 44 Then
                Frame.Stage = 5
            Else
                If Syntax.Kind = 3 Then
                Frame.Stage = 1
                Push = True
                ChildSyntax = Syntax.FirstChild
                ChildContext = Frame.Context
                ChildDepth = Frame.Depth + 1
            Else
                If Syntax.Kind >= 4 And Syntax.Kind <= 6 Then
                Dim Literal As Long = -1
                Dim Groups As Long = 0
                If Syntax.Kind = 4 Or Syntax.Kind = 5 Then
                    If Frame.Depth >= Work.Limits.MaximumDepth Then
                        TryBindSemanticExpressionWithin = FailSemanticBudget(Work.Failure)
                        Exit Function
                    End If
                    If TryFindSignedSemanticLiteral(Work, Syntax.FirstChild, Frame.Depth + 1, Literal, Groups) = False Then
                        Exit Function
                    End If
                End If
                If Literal >= 0 Then
                    If TryBindSignedSemanticLiteral(Work, Frame, Syntax, Literal, Groups, Returned) = False Then
                        Exit Function
                    End If
                    Complete = True
                Else
                    Frame.Stage = 2
                    Push = True
                    ChildSyntax = Syntax.FirstChild
                    ChildDepth = Frame.Depth + 1
                    If SemanticPropagatesIntegerContext(Syntax.Kind) Then
                        ChildContext = Frame.Context
                    End If
                End If
            Else
                If Syntax.Kind = 8 Or Syntax.Kind = 10 Or Syntax.Kind = 11 Or Syntax.Kind = 12 Or Syntax.Kind = 13 Or (Syntax.Kind >= 15 And Syntax.Kind <= 20) Or (Syntax.Kind >= 24 And Syntax.Kind <= 30) Then
                Frame.Stage = 3
                Push = True
                ChildSyntax = Syntax.FirstChild
                If SemanticPropagatesIntegerContext(Syntax.Kind) Then
                    ChildContext = Frame.Context
                End If
            Else
                Dim DeferredCode As Long = 1400
                If Syntax.Kind >= 7 And Syntax.Kind <= 30 Then
                    DeferredCode = 1432
                End If
                TryBindSemanticExpressionWithin = SemanticWorkError(Work, DeferredCode, Frame.SyntaxId)
                Exit Function
            End If
            End If
            End If
            End If
            End If
            End If
            If Frame.Stage = 5 Then
                If RequiredConstant Then
                    TryBindSemanticExpressionWithin = SemanticWorkError(Work, 1413, Frame.SyntaxId)
                    Exit Function
                End If
                If Frame.Depth >= Work.Limits.MaximumDepth Then
                    TryBindSemanticExpressionWithin = FailSemanticBudget(Work.Failure)
                    Exit Function
                End If
                If Syntax.Kind = 1 Or Syntax.Kind = 34 Then
                    If TryPrepareResolvedSemanticCall(Work, Frame.SyntaxId, (Frame.Flags And 4) <> 0, Skipped, Frame.Child, Frame.Left.Selection, Calls, Pending, Frame.PlanId) = False Then
                        Exit Function
                    End If
                Else
                    If TryPrepareSemanticCall(Work, Frame.SyntaxId, (Frame.Flags And 4) <> 0, Skipped, Calls, Pending, Frame.PlanId) = False Then
                        Exit Function
                    End If
                End If
            End If
        Else
            If Frame.Stage = 1 Then
            Returned.SyntaxId = Frame.SyntaxId
            Returned.IntegerContext = Frame.Context
            Returned.Annotation = -1
            Returned.Flags = (Returned.Flags And Not 2) Or 4
            Complete = True
        Else
            If Frame.Stage = 2 Then
            Dim Unused As SemanticExpressionInfo
            Dim UnaryResult As SemanticExpressionInfo
            If TryFinishSemanticOperator(Work, Frame.SyntaxId, Frame.Kind, Returned, Unused, True, Skipped, UnaryResult) = False Then
                Exit Function
            End If
            Returned = UnaryResult
            Complete = True
        Else
            If Frame.Stage = 3 Then
            Frame.Left = Returned
            Dim LeftSyntax As SyntaxNode
            If TryReadSemanticSyntax(Work, Syntax.FirstChild, LeftSyntax) = False Then
                Exit Function
            End If
            Frame.Stage = 4
            Push = True
            ChildSyntax = LeftSyntax.NextSibling
            If SemanticPropagatesIntegerContext(Frame.Kind) Then
                ChildContext = Frame.Context
            End If
            If (Returned.Flags And 1) <> 0 Then
                If (Frame.Kind = 25 And Returned.Value = 0) Or (Frame.Kind = 27 And Returned.Value <> 0) Then
                    ChildFlags = ChildFlags Or 64
                End If
            End If
        Else
            If Frame.Stage = 4 Then
            Dim BinaryResult As SemanticExpressionInfo
            If TryFinishSemanticOperator(Work, Frame.SyntaxId, Frame.Kind, Frame.Left, Returned, False, Skipped, BinaryResult) = False Then
                Exit Function
            End If
            Returned = BinaryResult
            Complete = True
        Else
            If Frame.Stage = 6 Then
            If TryAcceptSemanticCallArgument(Work, Calls, Frame.PlanId, Returned) = False Then
                Exit Function
            End If
            Frame.Stage = 5
        End If
        End If
        End If
        End If
        End If
        End If
        If Frame.Stage = 5 Then
            Dim HasArgument As Boolean = False
            Dim ArgumentStorage As Boolean = False
            If TryNextSemanticCallArgument(Work, Calls, Frame.PlanId, HasArgument, ChildSyntax, ChildContext, ArgumentStorage) = False Then
                Exit Function
            End If
            If HasArgument Then
                Push = True
                ChildDepth = Frame.Depth + 1
                If ArgumentStorage Then
                    ChildFlags = ChildFlags Or 2
                End If
                Frame.Stage = 6
            Else
                If TryCompleteSemanticCall(Work, Calls, Frame.PlanId, Pending, Returned) = False Then
                    Exit Function
                End If
                Complete = True
            End If
        End If
        If Complete Then
            Returned.IntegerContext = Frame.Context
            If Skipped Then
                Returned.Flags = Returned.Flags Or 64
            End If
            If TryAnnotateSemanticExpression(Work, Returned) = False Then
                Exit Function
            End If
            Count = Count - 1
            Pending = Pending - 1
        Else
            Call ResetSemanticFailure(Work.Failure)
            Call WriteSemanticExpressionFrame(Frames(Count - 1), Frame)
            If Push Then
                If TryPushSemanticExpression(Work, Frames, Count, Pending, ChildSyntax, ChildContext, ChildDepth, ChildFlags) = False Then
                    Exit Function
                End If
            End If
        End If
    Wend
    Info = Returned
    TryBindSemanticExpressionWithin = True
End Function
