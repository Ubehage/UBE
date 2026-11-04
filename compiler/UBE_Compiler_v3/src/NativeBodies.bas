UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeBodies"

' Per-module scalar target references for the second ordered graph walk.
' Source values/facts remain borrowed and immutable. The owner is never copied.
' Operand/control payloads are 24/40 bytes per node. Counts track independently
' allocated owners so failed preparation and cleanup can be retried safely.
' Status 0 unused, 1 ready, 4 failed. A failed body leaves only private output.
Type NativeControlLabels
    First As LongLong
    Second As LongLong
    Merge As LongLong
    LeftPredecessor As LongLong
    RightPredecessor As LongLong
End Type
Type NativeBodyState
    Values() As NativeOperand
    Controls() As NativeControlLabels
    CurrentBlock As LongLong
    TemporaryAddress As LongLong
    ValueCount As Long
    ControlCount As Long
    Procedure As Long
    Status As Long
    OverflowSupport As Long
    TemporaryCount As Long
    Terminated As Boolean
    NeedsErrorSupport As Boolean
    NeedsCallSupport As Boolean
    NeedsInitializationSupport As Boolean
End Type
Private Intrinsic Function TryResizeNativeOperands(ByRef Values() As NativeOperand, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeNativeOperands.UBE_Primitive = "Array.TryResize"
End Function

Private Function TryEnterNativeBodyNode(ByRef State As NativeBodyState, ByRef Module As SemanticModuleResult, ByRef Declarations As NativeDeclarationPlan, ByVal SourceCount As Long, ByRef Node As BoundNode, ByRef Event As NativeTraversalEvent, ByRef Writer As NativeLLVMWriter) As Boolean
    TryEnterNativeBodyNode = False
    Call ResetNativeFailure(Writer.Failure)
    If Node.Kind = 101 Then
        TryEnterNativeBodyNode = True
        Exit Function
    End If
    If State.Terminated Then
        ' Keep every checked statement in the walk, even after an Exit. Such
        ' remaining statements occupy an unreachable block, never a live path.
        Dim Dead As LongLong = 0
        If TryLLVMIdentity(Writer, Dead) = False Then
            Exit Function
        End If
        If TryStartNativeBlock(State, Writer, Dead) = False Then
            Exit Function
        End If
    End If
    If Node.Kind = 103 Then
        ' Allocation belongs at entry; declaration execution establishes the
        ' neutral value before any initializer child reads the same storage.
        If Node.Target < 0 Or Node.Target >= Declarations.Count Then
            Exit Function
        End If
        Dim Storage As NativeDeclarationTarget
        Call ReadNativeDeclarationTarget(Storage, Declarations.Targets(Node.Target))
        If Storage.Kind <> 2 Then
            Exit Function
        End If
        Dim Neutral As NativeOperand
        Neutral.Kind = 1
        Neutral.TypeId = Storage.TypeId
        Neutral.Representation = Storage.Representation
        If TryEmitNativeStore(Writer, Storage, SourceCount, Neutral) = False Then
            Exit Function
        End If
    End If
    Dim Control As NativeControlLabels
    If Node.Kind = 106 Or Node.Kind = 107 Then
        If TryLLVMIdentity(Writer, Control.First) = False Then
            Exit Function
        End If
        If TryLLVMIdentity(Writer, Control.Second) = False Then
            Exit Function
        End If
        Dim Alternative As Boolean = False
        If Node.Kind = 106 And Event.Parent >= 0 And Event.Ordinal >= 2 Then
            Alternative = Module.Values(Event.Parent).Kind = 106
        End If
        If Alternative Then
            Control.Merge = State.Controls(Event.Parent).Merge
        Else
            If TryLLVMIdentity(Writer, Control.Merge) = False Then
                Exit Function
            End If
        End If
        Call WriteNativeControl(State.Controls(Event.Node), Control)
        If Node.Kind = 107 Then
            If TryBranchNativeBlock(State, Writer, Control.First) = False Then
                Exit Function
            End If
            If TryStartNativeBlock(State, Writer, Control.First) = False Then
                Exit Function
            End If
        End If
    End If
    If Node.Kind = 5 And (Node.Auxiliary = 25 Or Node.Auxiliary = 27) Then
        If TryLLVMIdentity(Writer, Control.First) = False Then
            Exit Function
        End If
        If TryLLVMIdentity(Writer, Control.Merge) = False Then
            Exit Function
        End If
        Call WriteNativeControl(State.Controls(Event.Node), Control)
    End If
    TryEnterNativeBodyNode = True
End Function

Private Function TryNativeChildConversion(ByRef State As NativeBodyState, ByRef Catalog As SemanticCatalog, ByRef Module As SemanticModuleResult, ByRef Plan As NativeGraphPlan, ByRef Event As NativeTraversalEvent, ByRef Parent As BoundNode, ByRef Writer As NativeLLVMWriter) As Boolean
    TryNativeChildConversion = False
    Call ResetNativeFailure(Writer.Failure)
    Dim FactId As Long = -1
    Dim Required As Boolean = False
    If Parent.Kind = 4 Or Parent.Kind = 5 Or Parent.Kind = 106 Or Parent.Kind = 107 Then
        If Parent.SyntaxId < 0 Or Parent.SyntaxId >= Plan.SyntaxCount Then
            Exit Function
        End If
        If Parent.Kind = 4 Or Parent.Kind = 5 Then
            Required = True
            If Event.Ordinal = 0 Then
                FactId = Plan.Syntax(Parent.SyntaxId).LeftConversion - 1
            Else
                FactId = Plan.Syntax(Parent.SyntaxId).RightConversion - 1
            End If
        Else
            If Event.Ordinal = 0 Then
                Required = True
                FactId = Plan.Syntax(Parent.SyntaxId).ConditionConversion - 1
            End If
        End If
    End If
    If Parent.Kind = 103 Or Parent.Kind = 104 Then
        Required = True
        FactId = Parent.Auxiliary
    End If
    If Parent.Kind = 6 Then
        Dim ArgumentId As Long = Plan.Nodes(Event.Node).ArgumentIndex - 1
        Dim Base As Long = Plan.Nodes(Event.Parent).ArgumentBase
        Dim Count As Long = Plan.Nodes(Event.Parent).ArgumentCount
        If ArgumentId < Base Or ArgumentId - Base >= Count Or ArgumentId >= Plan.ArgumentCount Then
            Exit Function
        End If
        Dim MapId As Long = Plan.Arguments(ArgumentId).Map - 1
        If MapId < 0 Or MapId >= Module.FactCount Then
            Exit Function
        End If
        If Module.Facts(MapId).Kind <> 6 Or Module.Facts(MapId).Left <> Parent.Auxiliary Then
            Exit Function
        End If
        Required = Module.Facts(MapId).Right >= 0
        FactId = Plan.Arguments(ArgumentId).Conversion - 1
    End If
    If Required And FactId < 0 Then
        Exit Function
    End If
    If FactId >= 0 Then
        If FactId >= Module.FactCount Then
            Exit Function
        End If
        Dim Fact As SemanticFact
        Call ReadSemanticFact(Fact, Module.Facts(FactId))
        If Fact.TypeId < 1 Or Fact.TypeId >= Catalog.TypeCount Then
            Exit Function
        End If
        Dim Original As NativeOperand
        Dim Converted As NativeOperand
        Call ReadNativeOperand(Original, State.Values(Event.Node))
        If Parent.Kind = 6 And (Original.Kind = 3 Or Original.Kind = 4) Then
            If Fact.Kind <> 3 Or Fact.Left <> Original.TypeId Or Fact.TypeId <> Original.TypeId Then
                Exit Function
            End If
            If (Module.Facts(MapId).Flags And 3) <> 1 Then
                Exit Function
            End If
            TryNativeChildConversion = True
            Exit Function
        End If
        If TryEmitNativeConversion(Writer, Fact, Catalog.Types(Fact.TypeId), Original, Converted, State.NeedsErrorSupport) = False Then
            Exit Function
        End If
        Call WriteNativeOperand(State.Values(Event.Node), Converted)
    End If
    TryNativeChildConversion = True
End Function

Private Function TryFinishNativeChild(ByRef State As NativeBodyState, ByRef Catalog As SemanticCatalog, ByRef Module As SemanticModuleResult, ByRef Plan As NativeGraphPlan, ByRef Event As NativeTraversalEvent, ByRef Writer As NativeLLVMWriter) As Boolean
    TryFinishNativeChild = False
    Call ResetNativeFailure(Writer.Failure)
    If Event.Parent < 0 Then
        TryFinishNativeChild = True
        Exit Function
    End If
    Dim Parent As BoundNode
    Call ReadBoundNode(Parent, Module.Values(Event.Parent))
    If TryNativeChildConversion(State, Catalog, Module, Plan, Event, Parent, Writer) = False Then
        Exit Function
    End If
    If Parent.Kind = 6 Then
        Dim ArgumentId As Long = Plan.Nodes(Event.Node).ArgumentIndex - 1
        If ArgumentId < 0 Or ArgumentId >= Plan.ArgumentCount Then
            Exit Function
        End If
        Dim Temporary As Long = Plan.Arguments(ArgumentId).TemporaryIndex
        If Temporary > 0 Then
            If TryPrepareNativeTemporary(State, Event.Node, Temporary, Writer) = False Then
                Exit Function
            End If
        End If
    End If
    Dim Control As NativeControlLabels
    Call ReadNativeControl(Control, State.Controls(Event.Parent))
    Dim Value As NativeOperand
    Call ReadNativeOperand(Value, State.Values(Event.Node))
    If Parent.Kind = 106 Or Parent.Kind = 107 Then
        If Event.Ordinal = 0 Then
            Dim WhenTrue As LongLong = Control.First
            Dim WhenFalse As LongLong = Control.Second
            If Parent.Kind = 107 Then
                WhenTrue = Control.Second
                WhenFalse = Control.Merge
            End If
            If TryConditionalNativeBranch(State, Writer, Value, WhenTrue, WhenFalse) = False Then
                Exit Function
            End If
            If TryStartNativeBlock(State, Writer, WhenTrue) = False Then
                Exit Function
            End If
        Else
            If Event.Ordinal = 1 Then
                If Parent.Kind = 106 Then
                    If TryBranchNativeBlock(State, Writer, Control.Merge) = False Then
                        Exit Function
                    End If
                    If TryStartNativeBlock(State, Writer, Control.Second) = False Then
                        Exit Function
                    End If
                Else
                    If TryBranchNativeBlock(State, Writer, Control.First) = False Then
                        Exit Function
                    End If
                End If
            End If
        End If
    End If
    If Parent.Kind = 5 And (Parent.Auxiliary = 25 Or Parent.Auxiliary = 27) Then
        If Event.Ordinal = 0 Then
            Control.LeftPredecessor = State.CurrentBlock
            Dim TrueBlock As LongLong = Control.First
            Dim FalseBlock As LongLong = Control.Merge
            If Parent.Auxiliary = 27 Then
                TrueBlock = Control.Merge
                FalseBlock = Control.First
            End If
            If TryConditionalNativeBranch(State, Writer, Value, TrueBlock, FalseBlock) = False Then
                Exit Function
            End If
            If TryStartNativeBlock(State, Writer, Control.First) = False Then
                Exit Function
            End If
        Else
            Control.RightPredecessor = State.CurrentBlock
            If TryBranchNativeBlock(State, Writer, Control.Merge) = False Then
                Exit Function
            End If
            If TryStartNativeBlock(State, Writer, Control.Merge) = False Then
                Exit Function
            End If
        End If
        Call WriteNativeControl(State.Controls(Event.Parent), Control)
    End If
    TryFinishNativeChild = True
End Function

Private Function TryNativeBooleanPhi(ByRef State As NativeBodyState, ByRef Node As BoundNode, ByVal NodeId As Long, ByRef Right As NativeOperand, ByRef Writer As NativeLLVMWriter, ByRef Result As NativeOperand) As Boolean
    TryNativeBooleanPhi = False
    Call ResetNativeFailure(Writer.Failure)
    Dim Prepared As NativeOperand
    If TryLLVMInstruction(Writer, 1, 1, Prepared) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "phi i1 [ ") = False Then
        Exit Function
    End If
    Dim Skipped As Long = 0
    If Node.Auxiliary = 27 Then
        Skipped = 1
    End If
    If TryLLVMNumber(Writer, Skipped) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, ", ") = False Then
        Exit Function
    End If
    If TryLLVMBlockReference(Writer, State.Controls(NodeId).LeftPredecessor) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, " ], [ ") = False Then
        Exit Function
    End If
    If TryLLVMOperand(Writer, Right) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, ", ") = False Then
        Exit Function
    End If
    If TryLLVMBlockReference(Writer, State.Controls(NodeId).RightPredecessor) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, " ]") = False Then
        Exit Function
    End If
    Result = Prepared
    TryNativeBooleanPhi = True
End Function

Private Function TryFinishNativeBodyNode(ByRef State As NativeBodyState, ByRef Catalog As SemanticCatalog, ByRef Module As SemanticModuleResult, ByRef Declarations As NativeDeclarationPlan, ByRef Plan As NativeGraphPlan, ByRef Node As BoundNode, ByRef Event As NativeTraversalEvent, ByRef Writer As NativeLLVMWriter) As Boolean
    TryFinishNativeBodyNode = False
    Call ResetNativeFailure(Writer.Failure)
    Dim Value As NativeOperand
    If Node.Kind = 6 Then
        If Node.Target < 0 Or Node.Target >= Declarations.Count Then
            Exit Function
        End If
        Dim Owner As NativeOperand
        Owner.Kind = 1
        Owner.TypeId = 4
        Owner.Representation = 4
        Owner.Value = Declarations.Targets(Node.Target).SourceId
        If Owner.Value <> Declarations.Targets(State.Procedure).SourceId Then
            If TryGuardNativeInitialization(State, Declarations, Catalog.SourceCount, Owner, Writer) = False Then
                Exit Function
            End If
        End If
        Dim CallAccepted As Boolean = False
        If Declarations.Targets(Node.Target).Role = 0 Then
            CallAccepted = TryFinishNativeCall(State, Module, Declarations, Plan, Node, Event.Node, Catalog.SourceCount, Writer, Value)
        Else
            CallAccepted = TryFinishNativeIntrinsic(State, Catalog, Module, Declarations, Plan, Node, Event.Node, Writer, Value)
        End If
        If CallAccepted = False Then
            Exit Function
        End If
        Call WriteNativeOperand(State.Values(Event.Node), Value)
        TryFinishNativeBodyNode = True
        Exit Function
    End If
    If Node.Kind = 1 Or Node.Kind = 2 Then
        If Node.TypeId < 1 Or Node.TypeId >= Catalog.TypeCount Then
            Exit Function
        End If
        Value.Kind = 1
        Value.TypeId = Node.TypeId
        Value.Representation = Node.TypeId
        If Node.TypeId >= 6 Then
            Value.Representation = Catalog.Types(Node.TypeId).Representation
        End If
        Value.Value = Node.Value
        Call WriteNativeOperand(State.Values(Event.Node), Value)
    Else
        If Node.Kind = 3 Or Node.Kind = 103 Or Node.Kind = 104 Then
            If Node.Target < 0 Or Node.Target >= Declarations.Count Then
                Exit Function
            End If
            Dim Target As NativeDeclarationTarget
            Call ReadNativeDeclarationTarget(Target, Declarations.Targets(Node.Target))
            If Node.Kind = 3 Then
                Dim ExactAlias As Boolean = False
                Dim ArgumentId As Long = Plan.Nodes(Event.Node).ArgumentIndex - 1
                If ArgumentId >= 0 And ArgumentId < Plan.ArgumentCount Then
                    Dim MapId As Long = Plan.Arguments(ArgumentId).Map - 1
                    If MapId < 0 Or MapId >= Module.FactCount Then
                        Exit Function
                    End If
                    ExactAlias = (Module.Facts(MapId).Flags And 3) = 1
                End If
                If ExactAlias Then
                    Value.Kind = 3
                    If Target.Kind = 2 And Target.Scope < Catalog.SourceCount Then
                        Value.Kind = 4
                    End If
                    Value.TypeId = Target.TypeId
                    Value.Representation = Target.Representation
                    Value.Value = Target.AddressIdentity
                    If Value.Value < 0 Then
                        Exit Function
                    End If
                Else
                    If TryGuardNativeStorage(State, Declarations, Catalog.SourceCount, Target, Writer) = False Then
                        Exit Function
                    End If
                    If TryEmitNativeLoad(Writer, Target, Catalog.SourceCount, Value) = False Then
                        Exit Function
                    End If
                End If
                Call WriteNativeOperand(State.Values(Event.Node), Value)
            Else
                If Node.ChildCount > 0 Then
                    Call ReadNativeOperand(Value, State.Values(Node.FirstChild))
                    If TryGuardNativeStorage(State, Declarations, Catalog.SourceCount, Target, Writer) = False Then
                        Exit Function
                    End If
                    If TryEmitNativeStore(Writer, Target, Catalog.SourceCount, Value) = False Then
                        Exit Function
                    End If
                End If
            End If
        Else
            If Node.Kind = 4 Or Node.Kind = 5 Then
                If Node.FirstChild < 0 Or Node.FirstChild >= State.ValueCount Then
                    Exit Function
                End If
                If (Node.Kind = 4 And Node.ChildCount <> 1) Or (Node.Kind = 5 And Node.ChildCount <> 2) Then
                    Exit Function
                End If
                Dim Left As NativeOperand
                Dim Right As NativeOperand
                Call ReadNativeOperand(Left, State.Values(Node.FirstChild))
                If Node.Kind = 5 Then
                    Dim RightId As Long = Module.Values(Node.FirstChild).NextSibling
                    If RightId < 0 Or RightId >= State.ValueCount Then
                        Exit Function
                    End If
                    Call ReadNativeOperand(Right, State.Values(RightId))
                End If
                Dim Accepted As Boolean = False
                If Node.Kind = 4 Then
                    Accepted = TryEmitNativeUnary(Writer, Node, Left, Value, State.OverflowSupport, State.NeedsErrorSupport)
                Else
                    If Node.Auxiliary = 25 Or Node.Auxiliary = 27 Then
                        Accepted = TryNativeBooleanPhi(State, Node, Event.Node, Right, Writer, Value)
                    Else
                        If Left.TypeId < 1 Or Left.TypeId >= Catalog.TypeCount Then
                            Exit Function
                        End If
                        Accepted = TryEmitNativeBinary(Writer, Node, Catalog.Types(Left.TypeId), Left, Right, Value, State.OverflowSupport, State.NeedsErrorSupport)
                    End If
                End If
                If Accepted = False Then
                    Exit Function
                End If
                Call WriteNativeOperand(State.Values(Event.Node), Value)
            Else
                If Node.Kind = 106 Then
                    Dim Alternative As Boolean = False
                    If Event.Parent >= 0 And Event.Ordinal >= 2 Then
                        Alternative = Module.Values(Event.Parent).Kind = 106
                    End If
                    If Alternative = False Then
                        If TryBranchNativeBlock(State, Writer, State.Controls(Event.Node).Merge) = False Then
                            Exit Function
                        End If
                        If TryStartNativeBlock(State, Writer, State.Controls(Event.Node).Merge) = False Then
                            Exit Function
                        End If
                    End If
                Else
                    If Node.Kind = 107 Then
                        If TryStartNativeBlock(State, Writer, State.Controls(Event.Node).Merge) = False Then
                            Exit Function
                        End If
                    Else
                        If Node.Kind = 108 Then
                            If Node.Flags = 3 Then
                                If Node.Target < 0 Or Node.Target >= State.ValueCount Then
                                    Exit Function
                                End If
                                If Module.Values(Node.Target).Kind <> 107 Then
                                    Exit Function
                                End If
                                If TryBranchNativeBlock(State, Writer, State.Controls(Node.Target).Merge) = False Then
                                    Exit Function
                                End If
                            Else
                                If Node.Target <> State.Procedure Or (Node.Flags <> 1 And Node.Flags <> 2) Then
                                    Exit Function
                                End If
                                If TryNativeProcedureReturn(State, Declarations, Catalog.SourceCount, Writer) = False Then
                                    Exit Function
                                End If
                            End If
                        Else
                            If Node.Kind <> 101 And Node.Kind <> 102 And Node.Kind <> 105 Then
                                Exit Function
                            End If
                            If Node.Kind = 105 Then
                                If Node.ChildCount <> 1 Or Node.FirstChild < 0 Or Node.FirstChild >= State.ValueCount Then
                                    Exit Function
                                End If
                                If Module.Values(Node.FirstChild).Kind <> 6 Then
                                    Exit Function
                                End If
                            End If
                        End If
                    End If
                End If
            End If
        End If
    End If
    TryFinishNativeBodyNode = True
End Function

' Validated Value.Pack/Unpack declarations have no ordinary callee or frame.
' Consume their one retained formal association during the second argument
' visit, after the child has evaluated and applied its selected conversion.
Private Function TryFinishNativeIntrinsic(ByRef State As NativeBodyState, ByRef Catalog As SemanticCatalog, ByRef Module As SemanticModuleResult, ByRef Declarations As NativeDeclarationPlan, ByRef Plan As NativeGraphPlan, ByRef Node As BoundNode, ByVal NodeId As Long, ByRef Writer As NativeLLVMWriter, ByRef Result As NativeOperand) As Boolean
    TryFinishNativeIntrinsic = False
    Call ResetNativeFailure(Writer.Failure)
    If Node.Target < 0 Or Node.Target >= Declarations.Count Or Node.ChildCount <> 1 Then
        Exit Function
    End If
    Dim Target As NativeDeclarationTarget
    Call ReadNativeDeclarationTarget(Target, Declarations.Targets(Node.Target))
    If Target.Kind <> 6 Or Target.ParameterCount <> 1 Or (Target.Role <> 1 And Target.Role <> 2) Then
        Exit Function
    End If
    If Node.TypeId <> Target.TypeId Or Plan.Nodes(NodeId).ArgumentCount <> 1 Then
        Exit Function
    End If
    Dim Index As Long = Plan.Nodes(NodeId).ArgumentBase
    If Index < 0 Or Index >= Plan.ArgumentCount Then
        Exit Function
    End If
    If TryVisitNativeIndex(Writer.Limits, Writer.Usage, Writer.Cancellation, Writer.Failure) = False Then
        Exit Function
    End If
    Call ResetNativeFailure(Writer.Failure)
    Dim Argument As NativeArgumentLinks
    Argument = Plan.Arguments(Index)
    If Argument.Node <> Node.FirstChild + 1 Or Argument.Map < 1 Or Argument.Map > Module.FactCount Then
        Exit Function
    End If
    If Module.Facts(Argument.Map - 1).Target <> Target.FirstParameter Then
        Exit Function
    End If
    Dim Original As NativeOperand
    Call ReadNativeOperand(Original, State.Values(Argument.Node - 1))
    Dim NativeId As Long = Target.TypeId
    If Target.Role = 2 Then
        NativeId = Original.TypeId
    End If
    If NativeId < 6 Or NativeId >= Catalog.TypeCount Then
        Exit Function
    End If
    TryFinishNativeIntrinsic = TryEmitNativeRepresentation(Writer, Target.Role, Catalog.Types(NativeId), NativeId, Original, Result)
End Function

' Each static forced/default ByRef argument has one eight-byte entry slot.
' This is the largest admitted representation and preserves every alignment.
' Reset its value at each evaluation, before later arguments and admission.
Private Function TryPrepareNativeTemporary(ByRef State As NativeBodyState, ByVal NodeId As Long, ByVal Index As Long, ByRef Writer As NativeLLVMWriter) As Boolean
    TryPrepareNativeTemporary = False
    Call ResetNativeFailure(Writer.Failure)
    If Index < 1 Or Index > State.TemporaryCount Or State.TemporaryAddress < 0 Then
        Exit Function
    End If
    Dim Value As NativeOperand
    Call ReadNativeOperand(Value, State.Values(NodeId))
    If Value.Kind <> 1 And Value.Kind <> 2 Then
        Exit Function
    End If
    Dim Address As LongLong = 0
    If TryLLVMIdentity(Writer, Address) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "  %v") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, Address) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, " = getelementptr inbounds [") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, State.TemporaryCount) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, " x i64], ptr %v") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, State.TemporaryAddress) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, ", i64 0, i64 ") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, Index - 1) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "") = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "  store ") = False Then
        Exit Function
    End If
    If TryLLVMTypedOperand(Writer, Value) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, ", ptr %v") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, Address) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, ", align 8") = False Then
        Exit Function
    End If
    Value.Kind = 3
    Value.Value = Address
    Call WriteNativeOperand(State.Values(NodeId), Value)
    TryPrepareNativeTemporary = True
End Function

Private Function TryLLVMCallArgument(ByRef Writer As NativeLLVMWriter, ByRef Parameter As NativeDeclarationTarget, ByRef Value As NativeOperand, ByRef Owner As NativeOperand) As Boolean
    TryLLVMCallArgument = False
    Call ResetNativeFailure(Writer.Failure)
    If Parameter.Kind <> 4 Or Parameter.TypeId <> Value.TypeId Or Parameter.Representation <> Value.Representation Then
        Exit Function
    End If
    If (Parameter.Flags And 4) <> 0 Then
        If Value.Kind <> 1 And Value.Kind <> 2 Then
            Exit Function
        End If
        TryLLVMCallArgument = TryLLVMTypedOperand(Writer, Value)
        Exit Function
    End If
    If (Value.Kind <> 3 And Value.Kind <> 4) Or Value.Value < 0 Then
        Exit Function
    End If
    Dim Prefix As String = "ptr %v"
    If Value.Kind = 4 Then
        Prefix = "ptr @ube.g"
    End If
    If TryLLVMText(Writer, Prefix) = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, Value.Value) = False Then
        Exit Function
    End If
    If Owner.TypeId <> 4 Or Owner.Representation <> 4 Or (Owner.Kind <> 1 And Owner.Kind <> 2) Then
        Exit Function
    End If
    If TryLLVMText(Writer, ", ") = False Then
        Exit Function
    End If
    TryLLVMCallArgument = TryLLVMTypedOperand(Writer, Owner)
End Function

' All argument values/addresses already exist in written evaluation order.
' Guard the next complete footprint, then emit its formal-order operands in
' the second argument-map visit. Refusal never enters the callee and produces
' the selected neutral result while recording Err 28 on this native thread.
Private Function TryFinishNativeCall(ByRef State As NativeBodyState, ByRef Module As SemanticModuleResult, ByRef Declarations As NativeDeclarationPlan, ByRef Plan As NativeGraphPlan, ByRef Node As BoundNode, ByVal NodeId As Long, ByVal SourceCount As Long, ByRef Writer As NativeLLVMWriter, ByRef Result As NativeOperand) As Boolean
    TryFinishNativeCall = False
    Call ResetNativeFailure(Writer.Failure)
    Dim Target As NativeDeclarationTarget
    Call ReadNativeDeclarationTarget(Target, Declarations.Targets(Node.Target))
    If (Target.Kind <> 5 And Target.Kind <> 6) Or Target.Role <> 0 Or Target.TypeId <> Node.TypeId Then
        Exit Function
    End If
    If Target.ValueIdentity < 0 Or Target.FrameIndex < 0 Or Target.FrameIndex >= Declarations.FrameCount Then
        Exit Function
    End If
    Dim Base As Long = Plan.Nodes(NodeId).ArgumentBase
    Dim Count As Long = Plan.Nodes(NodeId).ArgumentCount
    If Count <> Target.ParameterCount Or Count <> Node.ChildCount Or Base < 0 Or Base > Plan.ArgumentCount - Count Then
        Exit Function
    End If
    Dim Permitted As NativeOperand
    If SourceCount < 1 Or Declarations.FrameCount > 2147483646 - SourceCount Then
        Exit Function
    End If
    If TryEmitNativeCallGuard(Writer, Declarations.FrameCount + SourceCount + 1, Target.FrameIndex, Permitted) = False Then
        Exit Function
    End If
    Dim Admitted As LongLong = 0
    Dim Refused As LongLong = 0
    Dim Merge As LongLong = 0
    If TryLLVMIdentity(Writer, Admitted) = False Then
        Exit Function
    End If
    If TryLLVMIdentity(Writer, Refused) = False Then
        Exit Function
    End If
    If TryLLVMIdentity(Writer, Merge) = False Then
        Exit Function
    End If
    If TryConditionalNativeBranch(State, Writer, Permitted, Admitted, Refused) = False Then
        Exit Function
    End If
    If TryStartNativeBlock(State, Writer, Refused) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  call void @ube_err_set_stack_exhausted()") = False Then
        Exit Function
    End If
    If TryBranchNativeBlock(State, Writer, Merge) = False Then
        Exit Function
    End If
    If TryStartNativeBlock(State, Writer, Admitted) = False Then
        Exit Function
    End If
    Dim Called As NativeOperand
    If Target.Kind = 6 Then
        If TryLLVMInstruction(Writer, Target.TypeId, Target.Representation, Called) = False Then
            Exit Function
        End If
    Else
        If TryLLVMText(Writer, "  ") = False Then
            Exit Function
        End If
    End If
    If TryLLVMText(Writer, "call ") = False Then
        Exit Function
    End If
    If TryLLVMType(Writer, Target.Representation, Target.TypeId >= 6) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, " @ube.f") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, Target.ValueIdentity) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "(") = False Then
        Exit Function
    End If
    Dim Ordinal As Long = 0
    While Ordinal < Count
        If TryVisitNativeIndex(Writer.Limits, Writer.Usage, Writer.Cancellation, Writer.Failure) = False Then
            Exit Function
        End If
        Call ResetNativeFailure(Writer.Failure)
        Dim Argument As NativeArgumentLinks
        Argument = Plan.Arguments(Base + Ordinal)
        If Argument.Map < 1 Or Argument.Map > Module.FactCount Or Argument.Node < 1 Or Argument.Node > State.ValueCount Then
            Exit Function
        End If
        Dim Map As SemanticFact
        Call ReadSemanticFact(Map, Module.Facts(Argument.Map - 1))
        If Map.Kind <> 6 Or Map.Target <> Target.FirstParameter + Ordinal Or Map.Left <> Node.Auxiliary Then
            Exit Function
        End If
        If Map.Target < 0 Or Map.Target >= Declarations.Count Then
            Exit Function
        End If
        Dim Parameter As NativeDeclarationTarget
        Call ReadNativeDeclarationTarget(Parameter, Declarations.Targets(Map.Target))
        Dim Value As NativeOperand
        Call ReadNativeOperand(Value, State.Values(Argument.Node - 1))
        Dim Owner As NativeOperand
        Owner.Kind = 1
        Owner.TypeId = 4
        Owner.Representation = 4
        Owner.Value = -1
        If (Parameter.Flags And 4) = 0 And (Map.Flags And 3) = 1 Then
            Dim Actual As BoundNode
            Call ReadBoundNode(Actual, Module.Values(Argument.Node - 1))
            If Actual.Kind <> 3 Or Actual.Target < 0 Or Actual.Target >= Declarations.Count Then
                Exit Function
            End If
            Dim Storage As NativeDeclarationTarget
            Call ReadNativeDeclarationTarget(Storage, Declarations.Targets(Actual.Target))
            If TryReadNativeStorageOwner(Storage, SourceCount, Owner) = False Then
                Exit Function
            End If
        End If
        If Ordinal > 0 Then
            If TryLLVMText(Writer, ", ") = False Then
                Exit Function
            End If
        End If
        If TryLLVMCallArgument(Writer, Parameter, Value, Owner) = False Then
            Exit Function
        End If
        Ordinal = Ordinal + 1
    Wend
    If TryLLVMLine(Writer, ")") = False Then
        Exit Function
    End If
    If TryBranchNativeBlock(State, Writer, Merge) = False Then
        Exit Function
    End If
    If TryStartNativeBlock(State, Writer, Merge) = False Then
        Exit Function
    End If
    Dim Prepared As NativeOperand
    If Target.Kind = 6 Then
        If TryLLVMInstruction(Writer, Target.TypeId, Target.Representation, Prepared) = False Then
            Exit Function
        End If
        If TryLLVMText(Writer, "phi ") = False Then
            Exit Function
        End If
        If TryLLVMType(Writer, Target.Representation, Target.TypeId >= 6) = False Then
            Exit Function
        End If
        If TryLLVMText(Writer, " [ ") = False Then
            Exit Function
        End If
        If TryLLVMConstant(Writer, Target.Representation, Target.TypeId >= 6, 0) = False Then
            Exit Function
        End If
        If TryLLVMText(Writer, ", ") = False Then
            Exit Function
        End If
        If TryLLVMBlockReference(Writer, Refused) = False Then
            Exit Function
        End If
        If TryLLVMText(Writer, " ], [ ") = False Then
            Exit Function
        End If
        If TryLLVMOperand(Writer, Called) = False Then
            Exit Function
        End If
        If TryLLVMText(Writer, ", ") = False Then
            Exit Function
        End If
        If TryLLVMBlockReference(Writer, Admitted) = False Then
            Exit Function
        End If
        If TryLLVMLine(Writer, " ]") = False Then
            Exit Function
        End If
    End If
    State.NeedsCallSupport = True
    ' A callee may have failed a required module even when this call itself
    ' returned normally. Check after the merge so the result phi retains its
    ' two actual predecessors. Ordinary stack refusal does not set the latch.
    Dim LocalOwner As NativeOperand
    LocalOwner.Kind = 1
    LocalOwner.TypeId = 4
    LocalOwner.Representation = 4
    LocalOwner.Value = -1
    If TryGuardNativeInitialization(State, Declarations, SourceCount, LocalOwner, Writer) = False Then
        Exit Function
    End If
    Result = Prepared
    TryFinishNativeCall = True
End Function

Private Function TryEmitNativeSubtree(ByRef State As NativeBodyState, ByRef Catalog As SemanticCatalog, ByRef Module As SemanticModuleResult, ByRef Declarations As NativeDeclarationPlan, ByRef Plan As NativeGraphPlan, ByVal Root As Long, ByRef Writer As NativeLLVMWriter) As Boolean
    TryEmitNativeSubtree = False
    Call ResetNativeFailure(Writer.Failure)
    If TryBeginNativeTraversal(Plan.Cursor, Module.Values, Module.ValueCount, Root, Writer.Limits, Writer.Usage, Writer.Cancellation, Writer.Failure) = False Then
        Exit Function
    End If
    Dim Complete As Boolean = False
    While Complete = False
        Dim Event As NativeTraversalEvent
        Call ResetNativeFailure(Writer.Failure)
        If TryNextNativeTraversal(Plan.Cursor, Module.Values, Module.ValueCount, Writer.Limits, Writer.Usage, Writer.Cancellation, Event, Writer.Failure) = False Then
            Exit Function
        End If
        Call ResetNativeFailure(Writer.Failure)
        Complete = Event.Kind = 0
        If Event.Kind = 2 And Module.Values(Root).Kind = 100 Then
            If Module.Values(Event.Node).Kind = 101 Then
                If Event.Parent <> Root Or TrySkipNativeTraversalChild(Plan.Cursor) = False Then
                    Exit Function
                End If
            End If
        End If
        If Event.Kind = 1 Or Event.Kind = 3 Then
            Dim Node As BoundNode
            Call ReadBoundNode(Node, Module.Values(Event.Node))
            If Node.Kind = 100 Then
                If Event.Node <> Root Then
                    Exit Function
                End If
            Else
            If Event.Kind = 1 Then
                If TryEnterNativeBodyNode(State, Module, Declarations, Catalog.SourceCount, Node, Event, Writer) = False Then
                    Exit Function
                End If
            Else
                If TryFinishNativeBodyNode(State, Catalog, Module, Declarations, Plan, Node, Event, Writer) = False Then
                    Exit Function
                End If
                If TryFinishNativeChild(State, Catalog, Module, Plan, Event, Writer) = False Then
                    Exit Function
                End If
            End If
            End If
        End If
    Wend
    TryEmitNativeSubtree = True
End Function

' Consume one procedure subtree with the existing explicit cursor. Its graph
' was prepared in the first module walk. Every enter/edge/exit is counted by
' the cursor; conversion happens when its child finishes, before the next child.
Function TryEmitNativeProcedure(ByRef State As NativeBodyState, ByRef Catalog As SemanticCatalog, ByRef Module As SemanticModuleResult, ByRef Declarations As NativeDeclarationPlan, ByRef Plan As NativeGraphPlan, ByVal Root As Long, ByRef Writer As NativeLLVMWriter) As Boolean
    TryEmitNativeProcedure = False
    Call ResetNativeFailure(Writer.Failure)
    If State.Status <> 1 Or Declarations.Status <> 1 Or Plan.Status <> 1 Or Root < 0 Or Root >= State.ValueCount Then
        Exit Function
    End If
    If Module Is Nothing Or Catalog Is Nothing Then
        Exit Function
    End If
    If Module.ValueCount <> State.ValueCount Or State.ControlCount <> State.ValueCount Or Plan.NodeCount <> State.ValueCount Then
        Exit Function
    End If
    State.Status = 4
    Dim Procedure As BoundNode
    Call ReadBoundNode(Procedure, Module.Values(Root))
    If Procedure.Kind <> 101 Then
        Exit Function
    End If
    If TryBeginNativeProcedure(State, Declarations, Catalog.SourceCount, Procedure.Target, Plan.Nodes(Root).TemporaryCount, Writer) = False Then
        Exit Function
    End If
    If TryEmitNativeSubtree(State, Catalog, Module, Declarations, Plan, Root, Writer) = False Then
        Exit Function
    End If
    If TryNativeProcedureReturn(State, Declarations, Catalog.SourceCount, Writer) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "}") = False Then
        Exit Function
    End If
    State.Status = 1
    Writer.Failure.Code = 0
    Writer.Failure.Resource = 0
    TryEmitNativeProcedure = True
End Function
' Emit only the module's declaration subtrees. Procedure roots were indexed
' during planning and their bodies are emitted separately, exactly once.
Function TryEmitNativeInitializer(ByRef State As NativeBodyState, ByRef Catalog As SemanticCatalog, ByRef Module As SemanticModuleResult, ByRef Declarations As NativeDeclarationPlan, ByRef Plan As NativeGraphPlan, ByRef Writer As NativeLLVMWriter) As Boolean
    TryEmitNativeInitializer = False
    Call ResetNativeFailure(Writer.Failure)
    If State.Status <> 1 Or Declarations.Status <> 1 Or Plan.Status <> 1 Then
        Exit Function
    End If
    If Module Is Nothing Or Catalog Is Nothing Then
        Exit Function
    End If
    If Module.SourceId < 0 Or Module.SourceId >= Catalog.SourceCount Or Module.Root < 0 Or Module.Root >= State.ValueCount Then
        Exit Function
    End If
    If Module.ValueCount <> State.ValueCount Or State.ControlCount <> State.ValueCount Or Plan.NodeCount <> State.ValueCount Then
        Exit Function
    End If
    State.Status = 4
    Dim Root As BoundNode
    Call ReadBoundNode(Root, Module.Values(Module.Root))
    If Root.Kind <> 100 Or Root.Target < 0 Or Root.Target >= Declarations.Count Or Root.ChildCount < 0 Or Root.ChildCount > State.ValueCount Then
        Exit Function
    End If
    If Declarations.Targets(Root.Target).Kind <> 1 Or Declarations.Targets(Root.Target).SourceId <> Module.SourceId Then
        Exit Function
    End If
    State.Procedure = Root.Target
    ' One definition visit and one target function identity, then root entry.
    If TryVisitNativeIndex(Writer.Limits, Writer.Usage, Writer.Cancellation, Writer.Failure) = False Then
        Exit Function
    End If
    If TryChargeNativeResource(Writer.Limits, Writer.Usage, 3, 1, Writer.Failure) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "define i1 @ube.module.init") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, Module.SourceId) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "() {") = False Then
        Exit Function
    End If
    Dim Entry As LongLong = 0
    If TryLLVMIdentity(Writer, Entry) = False Then
        Exit Function
    End If
    If TryStartNativeBlock(State, Writer, Entry) = False Then
        Exit Function
    End If
    If TryAllocateNativeTemporaries(State, Plan.Nodes(Module.Root).TemporaryCount, Writer) = False Then
        Exit Function
    End If
    If TryEmitNativeSubtree(State, Catalog, Module, Declarations, Plan, Module.Root, Writer) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  ret i1 true") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "}") = False Then
        Exit Function
    End If
    State.Terminated = True
    State.Status = 1
    Writer.Failure.Code = 0
    Writer.Failure.Resource = 0
    TryEmitNativeInitializer = True
End Function

Private Intrinsic Function TryResizeNativeControls(ByRef Values() As NativeControlLabels, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeNativeControls.UBE_Primitive = "Array.TryResize"
End Function
Private Sub ReadNativeOperand(ByRef Destination As NativeOperand, ByRef Original As NativeOperand)
    Destination = Original
End Sub
Private Sub WriteNativeOperand(ByRef Destination As NativeOperand, ByRef Original As NativeOperand)
    Destination = Original
End Sub
Private Sub ReadNativeControl(ByRef Destination As NativeControlLabels, ByRef Original As NativeControlLabels)
    Destination = Original
End Sub
Private Sub WriteNativeControl(ByRef Destination As NativeControlLabels, ByRef Original As NativeControlLabels)
    Destination = Original
End Sub

Function TryBeginNativeBodies(ByRef State As NativeBodyState, ByVal Count As Long, ByRef Writer As NativeLLVMWriter) As Boolean
    TryBeginNativeBodies = False
    Call ResetNativeFailure(Writer.Failure)
    If State.Status <> 0 Or State.ValueCount <> 0 Or State.ControlCount <> 0 Or Count < 1 Then
        Exit Function
    End If
    State.Status = 4
    Dim Bytes As LongLong = Count
    Bytes = Bytes * 64
    If TryChargeNativeResource(Writer.Limits, Writer.Usage, 1, Bytes, Writer.Failure) = False Then
        Exit Function
    End If
    Dim Healthy As Boolean = False
    Call ResetNativeFailure(Writer.Failure)
    If TryContinueNativeOutput(Writer.Cancellation, Writer.Failure) Then
        Call ResetNativeFailure(Writer.Failure)
        If TryResizeNativeOperands(State.Values, Count, False) Then
            State.ValueCount = Count
            Call ResetNativeFailure(Writer.Failure)
            If TryContinueNativeOutput(Writer.Cancellation, Writer.Failure) Then
                Call ResetNativeFailure(Writer.Failure)
                If TryResizeNativeControls(State.Controls, Count, False) Then
                    State.ControlCount = Count
                    Call ResetNativeFailure(Writer.Failure)
                    Healthy = TryContinueNativeOutput(Writer.Cancellation, Writer.Failure)
                Else
                    Writer.Failure.Code = 1502
                    Writer.Failure.Resource = 1
                End If
            End If
        Else
            Writer.Failure.Code = 1502
            Writer.Failure.Resource = 1
        End If
    End If
    If Healthy = False Then
        Dim Owned As LongLong = State.ValueCount
        Dim Controls As LongLong = State.ControlCount
        Owned = Owned * 24 + Controls * 40
        Dim Cleanup As NativeFailure
        Call TryReleaseNativeResource(Writer.Usage, 1, Bytes - Owned, Cleanup)
        Exit Function
    End If
    State.Status = 1
    State.OverflowSupport = 0
    State.NeedsErrorSupport = False
    State.NeedsCallSupport = False
    State.NeedsInitializationSupport = False
    Writer.Failure.Code = 0
    TryBeginNativeBodies = True
End Function

Function TryDisposeNativeBodies(ByRef State As NativeBodyState, ByRef Writer As NativeLLVMWriter) As Boolean
    TryDisposeNativeBodies = False
    Call ResetNativeFailure(Writer.Failure)
    If TryResizeNativeOperands(State.Values, 0, False) = False Then
        Exit Function
    End If
    Dim Bytes As LongLong = State.ValueCount
    Dim Cleanup As NativeFailure
    Call TryReleaseNativeResource(Writer.Usage, 1, Bytes * 24, Cleanup)
    State.ValueCount = 0
    Call ResetNativeFailure(Writer.Failure)
    If TryResizeNativeControls(State.Controls, 0, False) = False Then
        Exit Function
    End If
    Bytes = State.ControlCount
    Call TryReleaseNativeResource(Writer.Usage, 1, Bytes * 40, Cleanup)
    State.ControlCount = 0
    State.Status = 0
    Writer.Failure.Code = 0
    Writer.Failure.Resource = 0
    TryDisposeNativeBodies = True
End Function

Private Function TryLLVMBlockReference(ByRef Writer As NativeLLVMWriter, ByVal Identity As LongLong) As Boolean
    TryLLVMBlockReference = False
    If TryLLVMText(Writer, "%b") = False Then
        Exit Function
    End If
    TryLLVMBlockReference = TryLLVMNumber(Writer, Identity)
End Function
Private Function TryStartNativeBlock(ByRef State As NativeBodyState, ByRef Writer As NativeLLVMWriter, ByVal Identity As LongLong) As Boolean
    TryStartNativeBlock = False
    Call ResetNativeFailure(Writer.Failure)
    If Identity < 0 Then
        Exit Function
    End If
    If TryLLVMText(Writer, "b") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, Identity) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, ":") = False Then
        Exit Function
    End If
    State.CurrentBlock = Identity
    State.Terminated = False
    TryStartNativeBlock = True
End Function
Private Function TryBranchNativeBlock(ByRef State As NativeBodyState, ByRef Writer As NativeLLVMWriter, ByVal Identity As LongLong) As Boolean
    TryBranchNativeBlock = False
    Call ResetNativeFailure(Writer.Failure)
    If State.Terminated Then
        TryBranchNativeBlock = True
        Exit Function
    End If
    If TryLLVMText(Writer, "  br label ") = False Then
        Exit Function
    End If
    If TryLLVMBlockReference(Writer, Identity) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "") = False Then
        Exit Function
    End If
    State.Terminated = True
    TryBranchNativeBlock = True
End Function
Private Function TryConditionalNativeBranch(ByRef State As NativeBodyState, ByRef Writer As NativeLLVMWriter, ByRef Value As NativeOperand, ByVal WhenTrue As LongLong, ByVal WhenFalse As LongLong) As Boolean
    TryConditionalNativeBranch = False
    Call ResetNativeFailure(Writer.Failure)
    If Value.TypeId <> 1 Or State.Terminated Then
        Exit Function
    End If
    If TryLLVMText(Writer, "  br ") = False Then
        Exit Function
    End If
    If TryLLVMTypedOperand(Writer, Value) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, ", label ") = False Then
        Exit Function
    End If
    If TryLLVMBlockReference(Writer, WhenTrue) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, ", label ") = False Then
        Exit Function
    End If
    If TryLLVMBlockReference(Writer, WhenFalse) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "") = False Then
        Exit Function
    End If
    State.Terminated = True
    TryConditionalNativeBranch = True
End Function

' The shared requirement helper owns initialization and the failure latch.
' This body consumer owns only the ordered call and immediate neutral unwind.
' No payload, additional graph visit or declaration scan is introduced.
Private Function TryGuardNativeInitialization(ByRef State As NativeBodyState, ByRef Declarations As NativeDeclarationPlan, ByVal SourceCount As Long, ByRef Owner As NativeOperand, ByRef Writer As NativeLLVMWriter) As Boolean
    TryGuardNativeInitialization = False
    Call ResetNativeFailure(Writer.Failure)
    If State.Procedure < 0 Or State.Procedure >= Declarations.Count Or SourceCount < 1 Then
        Exit Function
    End If
    Dim Lexical As Long = Declarations.Targets(State.Procedure).SourceId
    If Lexical < 0 Or Lexical >= SourceCount Then
        Exit Function
    End If
    If Owner.TypeId <> 4 Or Owner.Representation <> 4 Or (Owner.Kind <> 1 And Owner.Kind <> 2) Then
        Exit Function
    End If
    If Owner.Kind = 1 Then
        If Owner.Value < -1 Or Owner.Value >= SourceCount Then
            Exit Function
        End If
    End If
    Dim Permitted As NativeOperand
    If TryLLVMInstruction(Writer, 1, 1, Permitted) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "call i1 @ube.module.require(") = False Then
        Exit Function
    End If
    If TryLLVMTypedOperand(Writer, Owner) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, ", i32 ") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, Lexical) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, ")") = False Then
        Exit Function
    End If
    Dim ContinueBlock As LongLong = 0
    Dim FailureBlock As LongLong = 0
    If TryLLVMIdentity(Writer, ContinueBlock) = False Then
        Exit Function
    End If
    If TryLLVMIdentity(Writer, FailureBlock) = False Then
        Exit Function
    End If
    If TryConditionalNativeBranch(State, Writer, Permitted, ContinueBlock, FailureBlock) = False Then
        Exit Function
    End If
    If TryStartNativeBlock(State, Writer, FailureBlock) = False Then
        Exit Function
    End If
    Dim Procedure As NativeDeclarationTarget
    Call ReadNativeDeclarationTarget(Procedure, Declarations.Targets(State.Procedure))
    If Procedure.Kind = 1 Then
        If TryLLVMLine(Writer, "  ret i1 false") = False Then
            Exit Function
        End If
    Else
        If Procedure.Kind <> 5 And Procedure.Kind <> 6 Then
            Exit Function
        End If
        If TryLLVMText(Writer, "  ret ") = False Then
            Exit Function
        End If
        If Procedure.Kind = 6 Then
            Dim Neutral As NativeOperand
            Neutral.Kind = 1
            Neutral.TypeId = Procedure.TypeId
            Neutral.Representation = Procedure.Representation
            Neutral.Value = 0
            If TryLLVMTypedOperand(Writer, Neutral) = False Then
                Exit Function
            End If
        Else
            If TryLLVMText(Writer, "void") = False Then
                Exit Function
            End If
        End If
        If TryLLVMLine(Writer, "") = False Then
            Exit Function
        End If
    End If
    State.Terminated = True
    If TryStartNativeBlock(State, Writer, ContinueBlock) = False Then
        Exit Function
    End If
    State.NeedsInitializationSupport = True
    TryGuardNativeInitialization = True
End Function

Private Function TryGuardNativeStorage(ByRef State As NativeBodyState, ByRef Declarations As NativeDeclarationPlan, ByVal SourceCount As Long, ByRef Target As NativeDeclarationTarget, ByRef Writer As NativeLLVMWriter) As Boolean
    TryGuardNativeStorage = False
    Dim Owner As NativeOperand
    If TryReadNativeStorageOwner(Target, SourceCount, Owner) = False Then
        Exit Function
    End If
    If State.Procedure < 0 Or State.Procedure >= Declarations.Count Then
        Exit Function
    End If
    If Owner.Kind = 1 Then
        If Owner.Value = -1 Or Owner.Value = Declarations.Targets(State.Procedure).SourceId Then
            TryGuardNativeStorage = True
            Exit Function
        End If
    End If
    TryGuardNativeStorage = TryGuardNativeInitialization(State, Declarations, SourceCount, Owner, Writer)
End Function

Private Function TryNativeProcedureReturn(ByRef State As NativeBodyState, ByRef Declarations As NativeDeclarationPlan, ByVal SourceCount As Long, ByRef Writer As NativeLLVMWriter) As Boolean
    TryNativeProcedureReturn = False
    Call ResetNativeFailure(Writer.Failure)
    If State.Terminated Then
        TryNativeProcedureReturn = True
        Exit Function
    End If
    Dim Target As NativeDeclarationTarget
    Call ReadNativeDeclarationTarget(Target, Declarations.Targets(State.Procedure))
    Dim Value As NativeOperand
    If Target.Kind = 6 Then
        If TryEmitNativeLoad(Writer, Target, SourceCount, Value) = False Then
            Exit Function
        End If
    End If
    If TryLLVMText(Writer, "  ret ") = False Then
        Exit Function
    End If
    If Target.Kind = 6 Then
        If TryLLVMTypedOperand(Writer, Value) = False Then
            Exit Function
        End If
    Else
        If TryLLVMText(Writer, "void") = False Then
            Exit Function
        End If
    End If
    If TryLLVMLine(Writer, "") = False Then
        Exit Function
    End If
    State.Terminated = True
    TryNativeProcedureReturn = True
End Function

' Charge declaration-definition visits even though these are prepared target
' rows rather than source catalog rows. Parameters name incoming identities;
' local definitions name distinct address identities planned by NativeDeclarations.
Private Function TryBeginNativeProcedure(ByRef State As NativeBodyState, ByRef Declarations As NativeDeclarationPlan, ByVal SourceCount As Long, ByVal ProcedureId As Long, ByVal TemporaryCount As Long, ByRef Writer As NativeLLVMWriter) As Boolean
    TryBeginNativeProcedure = False
    Call ResetNativeFailure(Writer.Failure)
    If ProcedureId < 0 Or ProcedureId >= Declarations.Count Or TemporaryCount < 0 Or TemporaryCount > State.ValueCount Then
        Exit Function
    End If
    If TryVisitNativeIndex(Writer.Limits, Writer.Usage, Writer.Cancellation, Writer.Failure) = False Then
        Exit Function
    End If
    Call ResetNativeFailure(Writer.Failure)
    Dim Procedure As NativeDeclarationTarget
    Call ReadNativeDeclarationTarget(Procedure, Declarations.Targets(ProcedureId))
    If (Procedure.Kind <> 5 And Procedure.Kind <> 6) Or Procedure.Role <> 0 Or Procedure.ValueIdentity < 0 Then
        Exit Function
    End If
    State.Procedure = ProcedureId
    If TryLLVMText(Writer, "define ") = False Then
        Exit Function
    End If
    If TryEmitNativeSignature(Declarations, Procedure, ProcedureId, SourceCount, True, Writer) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, ") {") = False Then
        Exit Function
    End If
    Dim Entry As LongLong = 0
    If TryLLVMIdentity(Writer, Entry) = False Then
        Exit Function
    End If
    If TryStartNativeBlock(State, Writer, Entry) = False Then
        Exit Function
    End If
    If Procedure.Kind = 6 Then
        If TryEmitNativeStorage(Writer, Procedure, SourceCount) = False Then
            Exit Function
        End If
    End If
    Dim Member As Long = Procedure.FirstMember
    Dim Previous As Long = 0
    While Member > 0
        If Member <= Previous Or Member > Declarations.Count Then
            Exit Function
        End If
        If TryVisitNativeIndex(Writer.Limits, Writer.Usage, Writer.Cancellation, Writer.Failure) = False Then
            Exit Function
        End If
        Call ResetNativeFailure(Writer.Failure)
        Dim Local As NativeDeclarationTarget
        Call ReadNativeDeclarationTarget(Local, Declarations.Targets(Member - 1))
        If Local.Kind = 2 Or Local.Kind = 4 Then
            If TryEmitNativeStorage(Writer, Local, SourceCount) = False Then
                Exit Function
            End If
        End If
        Previous = Member
        Member = Local.NextMember
    Wend
    If TryAllocateNativeTemporaries(State, TemporaryCount, Writer) = False Then
        Exit Function
    End If
    TryBeginNativeProcedure = True
End Function

Private Function TryAllocateNativeTemporaries(ByRef State As NativeBodyState, ByVal TemporaryCount As Long, ByRef Writer As NativeLLVMWriter) As Boolean
    TryAllocateNativeTemporaries = False
    Call ResetNativeFailure(Writer.Failure)
    If TemporaryCount < 0 Or TemporaryCount > State.ValueCount Then
        Exit Function
    End If
    State.TemporaryCount = TemporaryCount
    State.TemporaryAddress = -1
    If TemporaryCount > 0 Then
        If TryLLVMIdentity(Writer, State.TemporaryAddress) = False Then
            Exit Function
        End If
        If TryLLVMText(Writer, "  %v") = False Then
            Exit Function
        End If
        If TryLLVMNumber(Writer, State.TemporaryAddress) = False Then
            Exit Function
        End If
        If TryLLVMText(Writer, " = alloca [") = False Then
            Exit Function
        End If
        If TryLLVMNumber(Writer, TemporaryCount) = False Then
            Exit Function
        End If
        If TryLLVMLine(Writer, " x i64], align 8") = False Then
            Exit Function
        End If
    End If
    TryAllocateNativeTemporaries = True
End Function

' A shared signature keeps imports and definitions on the same private ABI.
' The caller charges the procedure row; this routine charges each formal once.
Private Function TryEmitNativeSignature(ByRef Declarations As NativeDeclarationPlan, ByRef Procedure As NativeDeclarationTarget, ByVal ProcedureId As Long, ByVal SourceCount As Long, ByVal Named As Boolean, ByRef Writer As NativeLLVMWriter) As Boolean
    TryEmitNativeSignature = False
    Call ResetNativeFailure(Writer.Failure)
    If Procedure.ParameterCount < 0 Or Procedure.ParameterCount > Declarations.Count Then
        Exit Function
    End If
    If Procedure.ParameterCount > 0 Then
        If Procedure.FirstParameter < 0 Or Procedure.FirstParameter > Declarations.Count - Procedure.ParameterCount Then
            Exit Function
        End If
    End If
    If TryLLVMType(Writer, Procedure.Representation, Procedure.TypeId >= 6) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, " @ube.f") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, Procedure.ValueIdentity) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "(") = False Then
        Exit Function
    End If
    Dim Ordinal As Long = 0
    While Ordinal < Procedure.ParameterCount
        If TryVisitNativeIndex(Writer.Limits, Writer.Usage, Writer.Cancellation, Writer.Failure) = False Then
            Exit Function
        End If
        Call ResetNativeFailure(Writer.Failure)
        Dim Parameter As NativeDeclarationTarget
        Call ReadNativeDeclarationTarget(Parameter, Declarations.Targets(Procedure.FirstParameter + Ordinal))
        If Parameter.Kind <> 4 Or Parameter.Scope <> ProcedureId Then
            Exit Function
        End If
        If Ordinal > 0 Then
            If TryLLVMText(Writer, ", ") = False Then
                Exit Function
            End If
        End If
        Dim Accepted As Boolean = False
        If (Parameter.Flags And 4) <> 0 Then
            Accepted = TryLLVMType(Writer, Parameter.Representation, Parameter.TypeId >= 6)
        Else
            Accepted = TryLLVMText(Writer, "ptr")
        End If
        If Accepted = False Then
            Exit Function
        End If
        If Named Then
            If TryLLVMText(Writer, " %v") = False Then
                Exit Function
            End If
            If TryLLVMNumber(Writer, Parameter.ValueIdentity) = False Then
                Exit Function
            End If
        End If
        If (Parameter.Flags And 4) = 0 Then
            Dim Owner As NativeOperand
            If TryReadNativeStorageOwner(Parameter, SourceCount, Owner) = False Then
                Exit Function
            End If
            If TryLLVMText(Writer, ", ") = False Then
                Exit Function
            End If
            If Named Then
                Accepted = TryLLVMTypedOperand(Writer, Owner)
            Else
                Accepted = TryLLVMText(Writer, "i32")
            End If
            If Accepted = False Then
                Exit Function
            End If
        End If
        Ordinal = Ordinal + 1
    Wend
    TryEmitNativeSignature = True
End Function

' Emit only the distinct foreign targets retained by the planning walk.
Function TryEmitNativeImports(ByRef Declarations As NativeDeclarationPlan, ByRef Plan As NativeGraphPlan, ByVal SourceId As Long, ByVal SourceCount As Long, ByRef Writer As NativeLLVMWriter) As Boolean
    TryEmitNativeImports = False
    Call ResetNativeFailure(Writer.Failure)
    If Declarations.Status <> 1 Or Plan.Status <> 1 Or SourceId < 0 Or SourceId >= SourceCount Then
        Exit Function
    End If
    If Plan.ImportCount < 0 Or Plan.ImportCount > Plan.ImportCapacity Or Plan.ImportMarkCount <> Declarations.Count Then
        Exit Function
    End If
    Dim Index As Long = 0
    While Index < Plan.ImportCount
        If TryVisitNativeIndex(Writer.Limits, Writer.Usage, Writer.Cancellation, Writer.Failure) = False Then
            Exit Function
        End If
        Call ResetNativeFailure(Writer.Failure)
        Dim Id As Long = Plan.Imports(Index) - 1
        If Id < 0 Or Id >= Declarations.Count Then
            Exit Function
        End If
        Dim Target As NativeDeclarationTarget
        Call ReadNativeDeclarationTarget(Target, Declarations.Targets(Id))
        If Target.SourceId < 0 Or Target.SourceId >= SourceCount Or Target.SourceId = SourceId Then
            Exit Function
        End If
        If Target.Kind = 2 Then
            If Target.Scope < 0 Or Target.Scope >= SourceCount Or Target.AddressIdentity < 0 Then
                Exit Function
            End If
            If TryLLVMAddress(Writer, Target.AddressIdentity, True) = False Then
                Exit Function
            End If
            If TryLLVMText(Writer, " = external global ") = False Then
                Exit Function
            End If
            If TryLLVMType(Writer, Target.Representation, Target.TypeId >= 6) = False Then
                Exit Function
            End If
            If TryLLVMLine(Writer, "") = False Then
                Exit Function
            End If
        Else
            If (Target.Kind <> 5 And Target.Kind <> 6) Or Target.Role <> 0 Or Target.ValueIdentity < 0 Then
                Exit Function
            End If
            If TryLLVMText(Writer, "declare ") = False Then
                Exit Function
            End If
            If TryEmitNativeSignature(Declarations, Target, Id, SourceCount, False, Writer) = False Then
                Exit Function
            End If
            If TryLLVMLine(Writer, ")") = False Then
                Exit Function
            End If
        End If
        Index = Index + 1
    Wend
    Writer.Failure.Code = 0
    TryEmitNativeImports = True
End Function

' The caller owns graph/body preparation, one reusable writer and disposal.
' Visit only this module's linked members and its indexed procedure roots.
Function TryEmitNativeModule(ByRef State As NativeBodyState, ByRef Catalog As SemanticCatalog, ByRef Module As SemanticModuleResult, ByRef Declarations As NativeDeclarationPlan, ByRef Plan As NativeGraphPlan, ByRef Writer As NativeLLVMWriter) As Boolean
    TryEmitNativeModule = False
    Call ResetNativeFailure(Writer.Failure)
    If Catalog Is Nothing Or Module Is Nothing Then
        Exit Function
    End If
    If State.Status <> 1 Or Declarations.Status <> 1 Or Plan.Status <> 1 Then
        Exit Function
    End If
    If Module.SourceId < 0 Or Module.SourceId >= Catalog.SourceCount Or Module.SourceId >= Declarations.Count Then
        Exit Function
    End If
    If TryVisitNativeIndex(Writer.Limits, Writer.Usage, Writer.Cancellation, Writer.Failure) = False Then
        Exit Function
    End If
    Call ResetNativeFailure(Writer.Failure)
    Dim Owner As NativeDeclarationTarget
    Call ReadNativeDeclarationTarget(Owner, Declarations.Targets(Module.SourceId))
    If Owner.Kind <> 1 Or Owner.SourceId <> Module.SourceId Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "target triple = ""x86_64-w64-windows-gnu""") = False Then
        Exit Function
    End If
    If TryEmitNativeImports(Declarations, Plan, Module.SourceId, Catalog.SourceCount, Writer) = False Then
        Exit Function
    End If
    Dim Member As Long = Owner.FirstMember
    Dim Previous As Long = 0
    While Member > 0
        If Member <= Previous Or Member > Declarations.Count Then
            Exit Function
        End If
        If TryVisitNativeIndex(Writer.Limits, Writer.Usage, Writer.Cancellation, Writer.Failure) = False Then
            Exit Function
        End If
        Call ResetNativeFailure(Writer.Failure)
        Dim Target As NativeDeclarationTarget
        Call ReadNativeDeclarationTarget(Target, Declarations.Targets(Member - 1))
        If Target.Scope <> Module.SourceId Or Target.SourceId <> Module.SourceId Then
            Exit Function
        End If
        If Target.Kind = 2 Then
            If TryEmitNativeStorage(Writer, Target, Catalog.SourceCount) = False Then
                Exit Function
            End If
        End If
        If (Target.Kind = 5 Or Target.Kind = 6) And Target.Role = 0 Then
            Dim ProcedureRoot As Long = -1
            If TryReadNativeProcedureRoot(Plan, Target.FrameIndex, ProcedureRoot) = False Then
                Exit Function
            End If
            If TryEmitNativeProcedure(State, Catalog, Module, Declarations, Plan, ProcedureRoot, Writer) = False Then
                Exit Function
            End If
        End If
        Previous = Member
        Member = Target.NextMember
    Wend
    If TryEmitNativeInitializer(State, Catalog, Module, Declarations, Plan, Writer) = False Then
        Exit Function
    End If
    If State.NeedsCallSupport Or State.NeedsInitializationSupport Then
        If Catalog.SourceCount < 1 Or Catalog.SourceCount >= 2147483647 Or Declarations.FrameCount < 0 Or Declarations.FrameCount > 2147483646 - Catalog.SourceCount Then
            Exit Function
        End If
        If TryEmitNativeStackSupport(Writer, Declarations.FrameCount + Catalog.SourceCount + 1) = False Then
            Exit Function
        End If
        State.NeedsErrorSupport = True
    End If
    If State.NeedsInitializationSupport Then
        If TryEmitNativeInitializationSupport(Writer, Catalog.SourceCount, Declarations.FrameCount) = False Then
            Exit Function
        End If
    End If
    If TryEmitNativeOverflowDeclarations(Writer, State.OverflowSupport) = False Then
        Exit Function
    End If
    If State.NeedsErrorSupport Then
        If TryEmitNativeErrorSupport(Writer) = False Then
            Exit Function
        End If
    End If
    TryEmitNativeModule = True
End Function
