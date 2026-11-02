UBE SOURCE 1 MODULE
Attribute UBE_Name = "SemanticCalls"

' Invocation-owned continuation arenas. Only the latest plan may run/complete;
' expression frames retain scalar plan IDs, never copies of these arrays.
Type SemanticCallPlan
    SyntaxId As Long
    TargetSyntaxId As Long
    Target As Long
    TypeId As Long
    SlotBase As Long
    SlotCount As Long
    FirstWritten As Long
    LastWritten As Long
    NextWritten As Long
    ActiveSlot As Long
    WrittenCount As Long
    CallFact As Long
    Node As Long
    Tail As Long
    Flags As Long
End Type
Type SemanticCallSlot
    Parameter As Long
    ExpressionSyntaxId As Long
    SlotSyntaxId As Long
    NameSyntaxId As Long
    WrittenOrdinal As Long
    Flags As Long
    Mode As Long
    NextWritten As Long
    Node As Long
    Conversion As Long
End Type
Type SemanticCallState
    Plans() As SemanticCallPlan
    Slots() As SemanticCallSlot
    PlanCount As Long
    SlotCount As Long
End Type
Private Intrinsic Function SemanticCallPlansLength(ByRef Values() As SemanticCallPlan) As Long
Attribute SemanticCallPlansLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function TryResizeSemanticCallPlans(ByRef Values() As SemanticCallPlan, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeSemanticCallPlans.UBE_Primitive = "Array.TryResize"
End Function
Private Intrinsic Function SemanticCallSlotsLength(ByRef Values() As SemanticCallSlot) As Long
Attribute SemanticCallSlotsLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function TryResizeSemanticCallSlots(ByRef Values() As SemanticCallSlot, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeSemanticCallSlots.UBE_Primitive = "Array.TryResize"
End Function
Private Sub ReadSemanticCallPlan(ByRef Destination As SemanticCallPlan, ByRef Original As SemanticCallPlan)
    Destination = Original
End Sub
Private Sub WriteSemanticCallPlan(ByRef Destination As SemanticCallPlan, ByRef Original As SemanticCallPlan)
    Destination = Original
End Sub
Private Sub ReadSemanticCallSlot(ByRef Destination As SemanticCallSlot, ByRef Original As SemanticCallSlot)
    Destination = Original
End Sub
Private Sub WriteSemanticCallSlot(ByRef Destination As SemanticCallSlot, ByRef Original As SemanticCallSlot)
    Destination = Original
End Sub
Private Function TryReadCallSyntax(ByVal Work As SemanticModuleWork, ByVal SyntaxId As Long, ByRef Node As SyntaxNode) As Boolean
    Call ResetSemanticFailure(Work.Failure)
    TryReadCallSyntax = TryReadSemanticSyntax(Work, SyntaxId, Node)
End Function
Private Function FailSemanticCall(ByVal Work As SemanticModuleWork, ByVal SyntaxId As Long, ByVal Code As Long) As Boolean
    FailSemanticCall = False
    Call ResetSemanticFailure(Work.Failure)
    FailSemanticCall = SemanticWorkError(Work, Code, SyntaxId)
End Function
Private Function TryReadCallDeclaration(ByVal Work As SemanticModuleWork, ByVal Id As Long, ByRef Declaration As SemanticDeclaration) As Boolean
    Call ResetSemanticFailure(Work.Failure)
    TryReadCallDeclaration = TryReadSemanticDeclaration(Work, Id, Declaration)
End Function

' Resolve exactly one lookup level. A wrong local target never retries an outer
' declaration. Qualified targets consist of one module Name and one member Name.
Private Function TryResolveSemanticCallTarget(ByVal Work As SemanticModuleWork, ByVal SyntaxId As Long, ByVal ResolvedTarget As Long, ByVal ResolvedLevel As Long, ByRef Target As Long) As Boolean
    TryResolveSemanticCallTarget = False
    Target = -1
    Dim Node As SyntaxNode
    Call ResetSemanticFailure(Work.Failure)
    If TryReadCallSyntax(Work, SyntaxId, Node) = False Then
        Exit Function
    End If
    If Node.Kind <> 1 And Node.Kind <> 34 Then
        Dim Code As Long = 1400
        If Node.Kind >= 2 And Node.Kind <= 30 Then
            Code = 1409
        End If
        Call ResetSemanticFailure(Work.Failure)
        TryResolveSemanticCallTarget = FailSemanticCall(Work, SyntaxId, Code)
        Exit Function
    End If
    Dim Level As Long = 0
    If ResolvedTarget >= 0 Then
        Target = ResolvedTarget
        Level = ResolvedLevel
    Else
        Call ResetSemanticFailure(Work.Failure)
        If TryResolveSemanticExpressionName(Work, SyntaxId, False, Target, Level) = False Then
            Exit Function
        End If
    End If
    Dim BindingSyntax As Long = SyntaxId
    If Node.Kind = 34 Then
        Dim Left As SyntaxNode
        Call ResetSemanticFailure(Work.Failure)
        If TryReadCallSyntax(Work, Node.FirstChild, Left) = False Then
            Exit Function
        End If
        BindingSyntax = Left.NextSibling
    End If
    Dim Declaration As SemanticDeclaration
    Call ResetSemanticFailure(Work.Failure)
    If TryReadCallDeclaration(Work, Target, Declaration) = False Then
        Exit Function
    End If
    If Declaration.Kind <> 5 And Declaration.Kind <> 6 Then
        Call ResetSemanticFailure(Work.Failure)
        TryResolveSemanticCallTarget = FailSemanticCall(Work, BindingSyntax, 1409)
        Exit Function
    End If
    Dim Ignored As Long = -1
    Call ResetSemanticFailure(Work.Failure)
    If TryAppendSemanticBinding(Work, BindingSyntax, Target, 5, Level, Ignored) = False Then
        Exit Function
    End If
    TryResolveSemanticCallTarget = True
End Function

Private Function TryContinueSemanticCall(ByVal Work As SemanticModuleWork, ByVal Iteration As Long) As Boolean
    TryContinueSemanticCall = False
    If (Iteration And 63) = 0 Then
        Call ResetSemanticFailure(Work.Failure)
        If TryContinueSemanticWork(Work) = False Then
            Exit Function
        End If
    End If
    TryContinueSemanticCall = True
End Function

Private Function TryReserveSemanticCall(ByVal Work As SemanticModuleWork, ByRef State As SemanticCallState, ByVal Parameters As Long, ByRef PendingCount As Long) As Boolean
    TryReserveSemanticCall = False
    Call ResetSemanticFailure(Work.Failure)
    Dim Maximum As Long = Work.Limits.MaximumPending
    If Work.MaximumPending < Maximum Then
        Maximum = Work.MaximumPending
    End If
    If Maximum < 0 Or PendingCount < 0 Or State.PlanCount < 0 Or State.SlotCount < 0 Or Parameters < 0 Then
        TryReserveSemanticCall = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    If PendingCount >= Maximum Or Parameters > Maximum - PendingCount - 1 Then
        TryReserveSemanticCall = FailSemanticBudget(Work.Failure)
        Exit Function
    End If
    If State.SlotCount > Maximum - Parameters Or State.PlanCount >= Maximum Then
        TryReserveSemanticCall = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    Dim Capacity As Long = SemanticCallPlansLength(State.Plans)
    Dim Prepared As Long = Capacity
    Call ResetSemanticFailure(Work.Failure)
    If TryGetStorageCapacity(Capacity, State.PlanCount + 1, Maximum, Prepared) = False Then
        TryReserveSemanticCall = FailSemanticBudget(Work.Failure)
        Exit Function
    End If
    If Prepared <> Capacity Then
        Call ResetSemanticFailure(Work.Failure)
        If TryResizeSemanticCallPlans(State.Plans, Prepared, True) = False Then
            Exit Function
        End If
    End If
    Capacity = SemanticCallSlotsLength(State.Slots)
    Call ResetSemanticFailure(Work.Failure)
    If TryGetStorageCapacity(Capacity, State.SlotCount + Parameters, Maximum, Prepared) = False Then
        TryReserveSemanticCall = FailSemanticBudget(Work.Failure)
        Exit Function
    End If
    If Prepared <> Capacity Then
        Call ResetSemanticFailure(Work.Failure)
        If TryResizeSemanticCallSlots(State.Slots, Prepared, True) = False Then
            Exit Function
        End If
    End If
    PendingCount = PendingCount + Parameters + 1
    If PendingCount > Work.Metrics.MaximumPending Then
        Work.Metrics.MaximumPending = PendingCount
    End If
    TryReserveSemanticCall = True
End Function

Private Function TryValidateSemanticCallParameterName(ByVal Work As SemanticModuleWork, ByVal NameSyntax As Long, ByVal TypeId As Long) As Boolean
    TryValidateSemanticCallParameterName = False
    Dim NameRecord As SyntaxNode
    Call ResetSemanticFailure(Work.Failure)
    If TryReadCallSyntax(Work, NameSyntax, NameRecord) = False Then
        Exit Function
    End If
    If NameRecord.FirstChild >= 0 Then
        Dim Suffix As SyntaxNode
        Call ResetSemanticFailure(Work.Failure)
        If TryReadCallSyntax(Work, NameRecord.FirstChild, Suffix) = False Then
            Exit Function
        End If
        If Suffix.Kind = 83 Then
            Dim Character As Long = Work.Source.SyntaxInput.Owner.Document.Bytes(Suffix.FirstByte)
            Dim SuffixType As Long = -1
            If Character = 37 Then
                SuffixType = 3
            Else
                If Character = 38 Then
                    SuffixType = 4
                Else
                    If Character = 94 Then
                        SuffixType = 5
                    End If
                End If
            End If
            If SuffixType <> TypeId Then
                ' Every admitted parameter already has its known scalar/native
                ' type. An unsupported type character is a known conflict too.
                Call ResetSemanticFailure(Work.Failure)
                TryValidateSemanticCallParameterName = FailSemanticCall(Work, NameSyntax, 1403)
                Exit Function
            End If
        End If
    End If
    TryValidateSemanticCallParameterName = True
End Function

Private Function TryPrepareSemanticCallCore(ByVal Work As SemanticModuleWork, ByVal SyntaxId As Long, ByVal Discard As Boolean, ByVal Skipped As Boolean, ByVal ResolvedTarget As Long, ByVal ResolvedLevel As Long, ByRef State As SemanticCallState, ByRef PendingCount As Long, ByRef PlanId As Long) As Boolean
    TryPrepareSemanticCallCore = False
    PlanId = -1
    If Work Is Nothing Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    Dim Syntax As SyntaxNode
    Call ResetSemanticFailure(Work.Failure)
    If TryReadCallSyntax(Work, SyntaxId, Syntax) = False Then
        Exit Function
    End If
    Dim Plan As SemanticCallPlan
    Plan.SyntaxId = SyntaxId
    Plan.TargetSyntaxId = SyntaxId
    Plan.FirstWritten = -1
    Plan.LastWritten = -1
    Plan.ActiveSlot = -1
    Plan.CallFact = -1
    Plan.Node = -1
    Plan.Tail = -1
    Dim FirstArgument As Long = -1
    If Syntax.Kind = 38 Or Syntax.Kind = 43 Or Syntax.Kind = 44 Then
        Plan.TargetSyntaxId = Syntax.FirstChild
        Dim TargetNode As SyntaxNode
        Call ResetSemanticFailure(Work.Failure)
        If TryReadCallSyntax(Work, Plan.TargetSyntaxId, TargetNode) = False Then
            Exit Function
        End If
        FirstArgument = TargetNode.NextSibling
    Else
        If Syntax.Kind <> 1 And Syntax.Kind <> 34 Then
            Call ResetSemanticFailure(Work.Failure)
            TryPrepareSemanticCallCore = FailSemanticCall(Work, SyntaxId, 1400)
            Exit Function
        End If
    End If
    Call ResetSemanticFailure(Work.Failure)
    If TryResolveSemanticCallTarget(Work, Plan.TargetSyntaxId, ResolvedTarget, ResolvedLevel, Plan.Target) = False Then
        Exit Function
    End If
    Dim Procedure As SemanticDeclaration
    Call ResetSemanticFailure(Work.Failure)
    If TryReadCallDeclaration(Work, Plan.Target, Procedure) = False Then
        Exit Function
    End If
    If Discard = False And Procedure.Kind <> 6 Then
        Call ResetSemanticFailure(Work.Failure)
        TryPrepareSemanticCallCore = FailSemanticCall(Work, SyntaxId, 1409)
        Exit Function
    End If
    Plan.TypeId = Procedure.TypeId
    If Discard And Procedure.Kind = 6 Then
        Plan.Flags = 1
    End If
    If Skipped Then
        Plan.Flags = Plan.Flags Or 4
    End If
    If (Procedure.Flags And 16) <> 0 And Procedure.Auxiliary <> 0 Then
        Plan.Flags = Plan.Flags Or 2
    End If
    Plan.SlotBase = State.SlotCount
    Plan.SlotCount = Procedure.ParameterCount
    Call ResetSemanticFailure(Work.Failure)
    If TryReserveSemanticCall(Work, State, Plan.SlotCount, PendingCount) = False Then
        Exit Function
    End If
    Dim Ordinal As Long = 0
    While Ordinal < Plan.SlotCount
        Call ResetSemanticFailure(Work.Failure)
        If TryContinueSemanticCall(Work, Ordinal) = False Then
            Exit Function
        End If
        Dim Slot As SemanticCallSlot
        Slot.Parameter = Procedure.FirstParameter + Ordinal
        Slot.ExpressionSyntaxId = -1
        Slot.SlotSyntaxId = -1
        Slot.NameSyntaxId = -1
        Slot.WrittenOrdinal = -1
        Slot.Flags = 0
        Slot.Mode = 0
        Slot.NextWritten = -1
        Slot.Node = -1
        Slot.Conversion = -1
        Call ResetSemanticFailure(Work.Failure)
        Call WriteSemanticCallSlot(State.Slots(Plan.SlotBase + Ordinal), Slot)
        Ordinal = Ordinal + 1
    Wend
    State.SlotCount = State.SlotCount + Plan.SlotCount
    PlanId = State.PlanCount
    State.PlanCount = State.PlanCount + 1
    ' Written list has no per-use parameter or source scan. Named matching uses
    ' the same frozen per-procedure index as ordinary declaration lookup.
    Dim ArgumentId As Long = FirstArgument
    Dim Positional As Long = 0
    Dim NamedSeen As Boolean = False
    While ArgumentId >= 0
        Call ResetSemanticFailure(Work.Failure)
        If TryContinueSemanticCall(Work, Plan.WrittenCount) = False Then
            Exit Function
        End If
        Dim Argument As SyntaxNode
        Call ResetSemanticFailure(Work.Failure)
        If TryReadCallSyntax(Work, ArgumentId, Argument) = False Then
            Exit Function
        End If
        Dim ParameterOrdinal As Long = Positional
        Dim ExpressionId As Long = ArgumentId
        Dim NameSyntax As Long = -1
        Dim SlotFlags As Long = 1
        If Argument.Kind = 36 Then
            NamedSeen = True
            NameSyntax = Argument.FirstChild
            Dim NameNode As SyntaxNode
            Call ResetSemanticFailure(Work.Failure)
            If TryReadCallSyntax(Work, NameSyntax, NameNode) = False Then
                Exit Function
            End If
            ExpressionId = NameNode.NextSibling
            Dim NameId As Long = -1
            Dim ParameterId As Long = -1
            Dim Matches As Long = 0
            Call ResetSemanticFailure(Work.Failure)
            If TryGetSemanticName(Work.Catalog, Work.Source.SourceId, NameSyntax, NameId, Work.Failure) = False Then
                Exit Function
            End If
            Call ResetSemanticFailure(Work.Failure)
            If TrySemanticPartition(Work.Catalog, Plan.Target + 1, NameId, ParameterId, Matches, Work.Failure) = False Then
                Exit Function
            End If
            Call ResetSemanticFailure(Work.Failure)
            If Matches <> 1 Then
                Call ResetSemanticFailure(Work.Failure)
                TryPrepareSemanticCallCore = FailSemanticCall(Work, NameSyntax, 1418)
                Exit Function
            End If
            Dim Parameter As SemanticDeclaration
            Call ResetSemanticFailure(Work.Failure)
            If TryReadCallDeclaration(Work, ParameterId, Parameter) = False Then
                Exit Function
            End If
            If Parameter.Kind <> 4 Or Parameter.Scope <> Plan.Target Then
                Call ResetSemanticFailure(Work.Failure)
                TryPrepareSemanticCallCore = FailSemanticCall(Work, NameSyntax, 1418)
                Exit Function
            End If
            Call ResetSemanticFailure(Work.Failure)
            If TryValidateSemanticCallParameterName(Work, NameSyntax, Parameter.TypeId) = False Then
                Exit Function
            End If
            ParameterOrdinal = Parameter.Ordinal
            SlotFlags = SlotFlags Or 2
        Else
            If NamedSeen Then
                Call ResetSemanticFailure(Work.Failure)
                TryPrepareSemanticCallCore = FailSemanticCall(Work, ArgumentId, 1418)
                Exit Function
            End If
            Positional = Positional + 1
        End If
        If ParameterOrdinal < 0 Or ParameterOrdinal >= Plan.SlotCount Then
            Call ResetSemanticFailure(Work.Failure)
            TryPrepareSemanticCallCore = FailSemanticCall(Work, ArgumentId, 1418)
            Exit Function
        End If
        Dim SlotId As Long = Plan.SlotBase + ParameterOrdinal
        Call ResetSemanticFailure(Work.Failure)
        Call ReadSemanticCallSlot(Slot, State.Slots(SlotId))
        If Slot.Flags <> 0 Then
            Dim DuplicateSyntax As Long = ArgumentId
            If NameSyntax >= 0 Then
                DuplicateSyntax = NameSyntax
            End If
            Call ResetSemanticFailure(Work.Failure)
            TryPrepareSemanticCallCore = FailSemanticCall(Work, DuplicateSyntax, 1418)
            Exit Function
        End If
        Slot.ExpressionSyntaxId = ExpressionId
        Slot.SlotSyntaxId = ArgumentId
        Slot.NameSyntaxId = NameSyntax
        Slot.WrittenOrdinal = Plan.WrittenCount
        Slot.Flags = SlotFlags
        If Argument.Kind = 73 Then
            Slot.ExpressionSyntaxId = -1
            Slot.Flags = Slot.Flags Or 4
        End If
        If Plan.LastWritten >= 0 Then
            Dim Previous As SemanticCallSlot
            Call ResetSemanticFailure(Work.Failure)
            Call ReadSemanticCallSlot(Previous, State.Slots(Plan.LastWritten))
            Previous.NextWritten = SlotId
            Call WriteSemanticCallSlot(State.Slots(Plan.LastWritten), Previous)
        Else
            Plan.FirstWritten = SlotId
        End If
        Plan.LastWritten = SlotId
        Plan.WrittenCount = Plan.WrittenCount + 1
        Call ResetSemanticFailure(Work.Failure)
        Call WriteSemanticCallSlot(State.Slots(SlotId), Slot)
        ArgumentId = Argument.NextSibling
    Wend
    Ordinal = 0
    While Ordinal < Plan.SlotCount
        Call ResetSemanticFailure(Work.Failure)
        If TryContinueSemanticCall(Work, Ordinal) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Work.Failure)
        Call ReadSemanticCallSlot(Slot, State.Slots(Plan.SlotBase + Ordinal))
        Call ResetSemanticFailure(Work.Failure)
        If TryReadCallDeclaration(Work, Slot.Parameter, Parameter) = False Then
            Exit Function
        End If
        If Slot.ExpressionSyntaxId < 0 Then
            If (Parameter.Flags And 8) = 0 Or Parameter.ValueKnown = 0 Then
                Dim ErrorSyntax As Long = SyntaxId
                If Slot.SlotSyntaxId >= 0 Then
                    ErrorSyntax = Slot.SlotSyntaxId
                End If
                Call ResetSemanticFailure(Work.Failure)
                TryPrepareSemanticCallCore = FailSemanticCall(Work, ErrorSyntax, 1418)
                Exit Function
            End If
        End If
        Ordinal = Ordinal + 1
    Wend
    Dim Fact As SemanticFact
    Fact.SourceId = Work.Source.SourceId
    Fact.SyntaxId = SyntaxId
    Fact.Kind = 5
    Fact.TypeId = Plan.TypeId
    Fact.Target = Plan.Target
    Fact.Left = -1
    Fact.Right = Plan.SlotCount
    Fact.Flags = Plan.Flags And 3
    Fact.Auxiliary = Plan.WrittenCount
    Fact.Extra = -1
    Call ResetSemanticFailure(Work.Failure)
    If TryAppendSemanticFact(Work, Fact, Plan.CallFact) = False Then
        Exit Function
    End If
    Plan.NextWritten = Plan.FirstWritten
    Call ResetSemanticFailure(Work.Failure)
    Call WriteSemanticCallPlan(State.Plans(PlanId), Plan)
    TryPrepareSemanticCallCore = True
End Function

Function TryPrepareSemanticCall(ByVal Work As SemanticModuleWork, ByVal SyntaxId As Long, ByVal Discard As Boolean, ByVal Skipped As Boolean, ByRef State As SemanticCallState, ByRef PendingCount As Long, ByRef PlanId As Long) As Boolean
    TryPrepareSemanticCall = False
    If Work Is Nothing Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    TryPrepareSemanticCall = TryPrepareSemanticCallCore(Work, SyntaxId, Discard, Skipped, -1, 0, State, PendingCount, PlanId)
End Function

Function TryPrepareResolvedSemanticCall(ByVal Work As SemanticModuleWork, ByVal SyntaxId As Long, ByVal Discard As Boolean, ByVal Skipped As Boolean, ByVal ResolvedTarget As Long, ByVal ResolvedLevel As Long, ByRef State As SemanticCallState, ByRef PendingCount As Long, ByRef PlanId As Long) As Boolean
    TryPrepareResolvedSemanticCall = False
    If Work Is Nothing Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    TryPrepareResolvedSemanticCall = TryPrepareSemanticCallCore(Work, SyntaxId, Discard, Skipped, ResolvedTarget, ResolvedLevel, State, PendingCount, PlanId)
End Function

Function TryNextSemanticCallArgument(ByVal Work As SemanticModuleWork, ByRef State As SemanticCallState, ByVal PlanId As Long, ByRef HasExpression As Boolean, ByRef ExpressionSyntaxId As Long, ByRef IntegerContext As Long, ByRef RequireStorage As Boolean) As Boolean
    TryNextSemanticCallArgument = False
    If Work Is Nothing Then
        Exit Function
    End If
    HasExpression = False
    ExpressionSyntaxId = -1
    IntegerContext = 0
    RequireStorage = False
    Call ResetSemanticFailure(Work.Failure)
    If PlanId < 0 Or PlanId <> State.PlanCount - 1 Then
        TryNextSemanticCallArgument = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    Dim Plan As SemanticCallPlan
    Call ReadSemanticCallPlan(Plan, State.Plans(PlanId))
    If Plan.ActiveSlot >= 0 Then
        TryNextSemanticCallArgument = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    Dim SkippedSlots As Long = 0
    While Plan.NextWritten >= 0 And HasExpression = False
        Call ResetSemanticFailure(Work.Failure)
        If TryContinueSemanticCall(Work, SkippedSlots) = False Then
            Exit Function
        End If
        SkippedSlots = SkippedSlots + 1
        Dim Slot As SemanticCallSlot
        Call ResetSemanticFailure(Work.Failure)
        Call ReadSemanticCallSlot(Slot, State.Slots(Plan.NextWritten))
        Dim Current As Long = Plan.NextWritten
        Plan.NextWritten = Slot.NextWritten
        If Slot.ExpressionSyntaxId >= 0 Then
            Dim Parameter As SemanticDeclaration
            Call ResetSemanticFailure(Work.Failure)
            If TryReadCallDeclaration(Work, Slot.Parameter, Parameter) = False Then
                Exit Function
            End If
            Dim Expression As SyntaxNode
            Call ResetSemanticFailure(Work.Failure)
            If TryReadCallSyntax(Work, Slot.ExpressionSyntaxId, Expression) = False Then
                Exit Function
            End If
            RequireStorage = (Parameter.Flags And 4) = 0 And Expression.Kind <> 3
            If RequireStorage = False Then
                If Parameter.TypeId >= 2 And Parameter.TypeId <= 5 Then
                    IntegerContext = Parameter.TypeId
                End If
            End If
            Plan.ActiveSlot = Current
            ExpressionSyntaxId = Slot.ExpressionSyntaxId
            HasExpression = True
        End If
    Wend
    Call ResetSemanticFailure(Work.Failure)
    Call WriteSemanticCallPlan(State.Plans(PlanId), Plan)
    TryNextSemanticCallArgument = True
End Function

Function TryAcceptSemanticCallArgument(ByVal Work As SemanticModuleWork, ByRef State As SemanticCallState, ByVal PlanId As Long, ByRef Info As SemanticExpressionInfo) As Boolean
    TryAcceptSemanticCallArgument = False
    If Work Is Nothing Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    If PlanId < 0 Or PlanId <> State.PlanCount - 1 Then
        TryAcceptSemanticCallArgument = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    Dim Plan As SemanticCallPlan
    Call ReadSemanticCallPlan(Plan, State.Plans(PlanId))
    If Plan.ActiveSlot < Plan.SlotBase Or Plan.ActiveSlot >= Plan.SlotBase + Plan.SlotCount Then
        TryAcceptSemanticCallArgument = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    Dim Slot As SemanticCallSlot
    Call ReadSemanticCallSlot(Slot, State.Slots(Plan.ActiveSlot))
    If Info.SyntaxId <> Slot.ExpressionSyntaxId Or Info.SourceId <> Work.Source.SourceId Then
        TryAcceptSemanticCallArgument = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    Dim Parameter As SemanticDeclaration
    Call ResetSemanticFailure(Work.Failure)
    If TryReadCallDeclaration(Work, Slot.Parameter, Parameter) = False Then
        Exit Function
    End If
    If (Parameter.Flags And 4) = 0 Then
        Slot.Mode = 1
        If (Info.Flags And 4) <> 0 Then
            Slot.Mode = 2
        Else
            If (Info.Flags And 2) = 0 Or Info.TypeId <> Parameter.TypeId Or Info.Target < 0 Then
                Call ResetSemanticFailure(Work.Failure)
                TryAcceptSemanticCallArgument = FailSemanticCall(Work, Slot.ExpressionSyntaxId, 1417)
                Exit Function
            End If
        End If
    End If
    Call ResetSemanticFailure(Work.Failure)
    If TryConvertSemanticExpression(Work, Info, Parameter.TypeId, 6, Slot.Parameter, Parameter.Ordinal, Slot.Conversion) = False Then
        Exit Function
    End If
    Dim Ignored As Long = -1
    ' Direct alias traversal already emitted role10 at the real lookup level.
    ' Grouped temporaries use ordinary reads and never acquire an alias binding.
    If Slot.NameSyntaxId >= 0 Then
        Call ResetSemanticFailure(Work.Failure)
        If TryAppendSemanticBinding(Work, Slot.NameSyntaxId, Slot.Parameter, 8, 7, Ignored) = False Then
            Exit Function
        End If
    End If
    Call ResetSemanticFailure(Work.Failure)
    If TryMaterializeSemanticExpression(Work, Info) = False Then
        Exit Function
    End If
    Slot.Node = Info.Node
    Call ResetSemanticFailure(Work.Failure)
    Call WriteSemanticCallSlot(State.Slots(Plan.ActiveSlot), Slot)
    Plan.ActiveSlot = -1
    Call WriteSemanticCallPlan(State.Plans(PlanId), Plan)
    TryAcceptSemanticCallArgument = True
End Function

Private Function TryCompleteSemanticCallDefault(ByVal Work As SemanticModuleWork, ByRef Plan As SemanticCallPlan, ByRef Slot As SemanticCallSlot) As Boolean
    TryCompleteSemanticCallDefault = False
    Dim Parameter As SemanticDeclaration
    Call ResetSemanticFailure(Work.Failure)
    If TryReadCallDeclaration(Work, Slot.Parameter, Parameter) = False Then
        Exit Function
    End If
    Dim Info As SemanticExpressionInfo
    Info.SourceId = Work.Source.SourceId
    Info.SyntaxId = Plan.SyntaxId
    If Slot.SlotSyntaxId >= 0 Then
        Info.SyntaxId = Slot.SlotSyntaxId
    End If
    Info.OriginSyntaxId = Info.SyntaxId
    Info.TypeId = Parameter.TypeId
    Info.Flags = 1
    If (Plan.Flags And 4) <> 0 Then
        Info.Flags = Info.Flags Or 64
    End If
    Info.Value = Parameter.Value
    Info.Target = -1
    Info.Node = -1
    Info.Annotation = -1
    Call ResetSemanticFailure(Work.Failure)
    If TryConvertSemanticExpression(Work, Info, Parameter.TypeId, 10, Slot.Parameter, Parameter.Ordinal, Slot.Conversion) = False Then
        Exit Function
    End If
    Info.SourceId = Parameter.SourceId
    Info.SyntaxId = Parameter.InitializerSyntaxId
    Info.OriginSyntaxId = Parameter.InitializerSyntaxId
    Info.Annotation = -1
    Call ResetSemanticFailure(Work.Failure)
    If TryMaterializeSemanticExpression(Work, Info) = False Then
        Exit Function
    End If
    Slot.Node = Info.Node
    Slot.Mode = 3
    TryCompleteSemanticCallDefault = True
End Function

Function TryCompleteSemanticCall(ByVal Work As SemanticModuleWork, ByRef State As SemanticCallState, ByVal PlanId As Long, ByRef PendingCount As Long, ByRef Info As SemanticExpressionInfo) As Boolean
    TryCompleteSemanticCall = False
    If Work Is Nothing Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    If PlanId < 0 Or PlanId <> State.PlanCount - 1 Then
        TryCompleteSemanticCall = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    Dim Plan As SemanticCallPlan
    Call ReadSemanticCallPlan(Plan, State.Plans(PlanId))
    If Plan.ActiveSlot <> -1 Or Plan.NextWritten <> -1 Or PendingCount <= Plan.SlotCount Then
        TryCompleteSemanticCall = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    Dim Ordinal As Long = 0
    While Ordinal < Plan.SlotCount
        Call ResetSemanticFailure(Work.Failure)
        If TryContinueSemanticCall(Work, Ordinal) = False Then
            Exit Function
        End If
        Dim Slot As SemanticCallSlot
        Call ResetSemanticFailure(Work.Failure)
        Call ReadSemanticCallSlot(Slot, State.Slots(Plan.SlotBase + Ordinal))
        If Slot.ExpressionSyntaxId < 0 Then
            Call ResetSemanticFailure(Work.Failure)
            If TryCompleteSemanticCallDefault(Work, Plan, Slot) = False Then
                Exit Function
            End If
            Call ResetSemanticFailure(Work.Failure)
            Call WriteSemanticCallSlot(State.Slots(Plan.SlotBase + Ordinal), Slot)
        End If
        Ordinal = Ordinal + 1
    Wend
    Dim Node As BoundNode
    Node.SourceId = Work.Source.SourceId
    Node.SyntaxId = Plan.SyntaxId
    Node.Kind = 6
    Node.TypeId = Plan.TypeId
    Node.Target = Plan.Target
    Node.FirstChild = -1
    Node.NextSibling = -1
    Node.Auxiliary = Plan.CallFact
    If (Plan.Flags And 1) <> 0 Then
        Node.Flags = 4
    End If
    If (Plan.Flags And 4) = 0 Then
        Call ResetSemanticFailure(Work.Failure)
        If TryAppendBoundNode(Work, Node, Plan.Node) = False Then
            Exit Function
        End If
    ' Live children follow written evaluation order. Defaults are pure known
    ' constants and follow the written expressions in parameter order.
    Dim Current As Long = Plan.FirstWritten
    Dim WrittenChildren As Long = 0
    While Current >= 0
        Call ResetSemanticFailure(Work.Failure)
        If TryContinueSemanticCall(Work, WrittenChildren) = False Then
            Exit Function
        End If
        WrittenChildren = WrittenChildren + 1
        Call ResetSemanticFailure(Work.Failure)
        Call ReadSemanticCallSlot(Slot, State.Slots(Current))
        If Slot.ExpressionSyntaxId >= 0 Then
            Call ResetSemanticFailure(Work.Failure)
            If TryLinkBoundChild(Work, Plan.Node, Slot.Node, Plan.Tail) = False Then
                Exit Function
            End If
        End If
        Current = Slot.NextWritten
    Wend
    Ordinal = 0
    While Ordinal < Plan.SlotCount
        Call ResetSemanticFailure(Work.Failure)
        If TryContinueSemanticCall(Work, Ordinal) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Work.Failure)
        Call ReadSemanticCallSlot(Slot, State.Slots(Plan.SlotBase + Ordinal))
        If Slot.ExpressionSyntaxId < 0 Then
            Call ResetSemanticFailure(Work.Failure)
            If TryLinkBoundChild(Work, Plan.Node, Slot.Node, Plan.Tail) = False Then
                Exit Function
            End If
        End If
        Ordinal = Ordinal + 1
    Wend
    End If
    Dim FirstFact As Long = -1
    If Plan.SlotCount > 0 Then
        FirstFact = Work.FactCount
    End If
    ' Emit a contiguous parameter-ordinal argument map after all expression and
    ' conversion work, even when nested calls emitted their own facts in between.
    Ordinal = 0
    While Ordinal < Plan.SlotCount
        Call ResetSemanticFailure(Work.Failure)
        If TryContinueSemanticCall(Work, Ordinal) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Work.Failure)
        Call ReadSemanticCallSlot(Slot, State.Slots(Plan.SlotBase + Ordinal))
        Dim Parameter As SemanticDeclaration
        Call ResetSemanticFailure(Work.Failure)
        If TryReadCallDeclaration(Work, Slot.Parameter, Parameter) = False Then
            Exit Function
        End If
        Dim Fact As SemanticFact
        Fact.SourceId = Work.Source.SourceId
        Fact.SyntaxId = Slot.SlotSyntaxId
        If Fact.SyntaxId < 0 Then
            Fact.SyntaxId = Plan.SyntaxId
        End If
        Fact.Kind = 6
        Fact.Target = Slot.Parameter
        Fact.TypeId = Parameter.TypeId
        Fact.Left = Plan.CallFact
        Fact.Right = Slot.ExpressionSyntaxId
        Fact.Auxiliary = Slot.WrittenOrdinal
        Fact.Extra = Ordinal
        Fact.Flags = Slot.Mode
        Fact.Value = 0
        If (Slot.Flags And 2) <> 0 Then
            Fact.Flags = Fact.Flags Or 4
        End If
        If (Slot.Flags And 4) <> 0 Then
            Fact.Flags = Fact.Flags Or 8
        End If
        If Slot.WrittenOrdinal < 0 Then
            Fact.Flags = Fact.Flags Or 16
        End If
        If Slot.ExpressionSyntaxId < 0 Then
            Fact.Value = Parameter.Value
        End If
        Dim Ignored As Long = -1
        Call ResetSemanticFailure(Work.Failure)
        If TryAppendSemanticFact(Work, Fact, Ignored) = False Then
            Exit Function
        End If
        Ordinal = Ordinal + 1
    Wend
    Dim CallFact As SemanticFact
    Call ResetSemanticFailure(Work.Failure)
    Call ReadSemanticFact(CallFact, Work.Facts(Plan.CallFact))
    CallFact.Left = FirstFact
    Call WriteSemanticFact(Work.Facts(Plan.CallFact), CallFact)
    Work.Metrics.FactWrites = Work.Metrics.FactWrites + 1
    Dim Result As SemanticExpressionInfo
    Result.SourceId = Work.Source.SourceId
    Result.SyntaxId = Plan.SyntaxId
    Result.OriginSyntaxId = Plan.SyntaxId
    Result.TypeId = Plan.TypeId
    Result.Target = Plan.Target
    Result.Node = Plan.Node
    Result.Annotation = -1
    If (Plan.Flags And 4) <> 0 Then
        Result.Flags = 64
    End If
    Info = Result
    State.SlotCount = Plan.SlotBase
    State.PlanCount = PlanId
    PendingCount = PendingCount - Plan.SlotCount - 1
    TryCompleteSemanticCall = True
End Function
