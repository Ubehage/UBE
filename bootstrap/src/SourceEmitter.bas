Attribute VB_Name = "SourceEmitter"
Option Explicit

' Native lowering retains explicit context ownership and fresh call outcomes.
Public Const MaximumIRCharacters As Long = 16777216
Public Const MaximumIRLines As Long = 250000
Public Const MaximumNativeSlots As Long = 128
Public Const MaximumNativeParameters As Long = 64
Public Const MaximumNativeCallDepth As Long = 256

Private Type EmissionState
    Lines() As String
    LineCount As Long
    CharacterCount As Long
    Failed As Boolean
    FailureDetail As String
    Work As Long
    ErrorNode As Long
    ValueNumber As Long
    LabelNumber As Long
    CurrentSymbol As Long
    CurrentModule As Long
    CurrentNode As Long
    CurrentNext As String
    ResultSymbol As Long
    CountedDepth As Boolean
    FieldIndex() As Long
    FieldCount As Long
    FailureSites() As Long
    FailureNext() As String
    FailureSeen() As Boolean
    FailureCount As Long
    ModuleDependencies() As Byte
End Type

' Reports a controlled emission diagnostic at a retained source span.
Private Function EmissionError(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByVal Node As Long, ByRef Diagnostic As String, ByVal Code As String, ByVal Detail As String) As Boolean
    Dim ModuleIndex As Long
    If Node > 0 Then
        ModuleIndex = Parsed.Nodes(Node).ModuleIndex
        If ModuleIndex >= 0 Then
            Diagnostic = "UBE: " & Code & ": " & Project.Sources(ModuleIndex).FilePath & ":" & CStr(Parsed.Nodes(Node).Line) & ":" & CStr(Parsed.Nodes(Node).Column) & " " & Detail
            Exit Function
        End If
    End If
    Diagnostic = "UBE: " & Code & ": " & Project.ManifestPath & ":1:1 " & Detail
End Function

' Appends bounded ASCII IR lines; allocation failure is caught by the public entry point.
Private Sub AddLine(ByRef State As EmissionState, ByVal Text As String)
    Dim Capacity As Long
    If State.Failed Then Exit Sub
    If State.LineCount >= MaximumIRLines Or Len(Text) + 2 > MaximumIRCharacters - State.CharacterCount Then
        State.Failed = True
        State.FailureDetail = "native IR output size limit exceeded"
        Exit Sub
    End If
    If State.LineCount > UBound(State.Lines) Then
        Capacity = (UBound(State.Lines) + 1) * 2
        If Capacity > MaximumIRLines Then Capacity = MaximumIRLines
        ReDim Preserve State.Lines(0 To Capacity - 1)
    End If
    State.Lines(State.LineCount) = Text
    State.LineCount = State.LineCount + 1
    State.CharacterCount = State.CharacterCount + Len(Text) + 2
End Sub

' Bounds aggregate scans over symbols and syntax across every emitted function.
Private Function EmissionWork(ByRef State As EmissionState) As Boolean
    If State.Failed Then Exit Function
    State.Work = State.Work + 1
    If State.Work > 10000000 Then
        State.Failed = True
        State.FailureDetail = "native emission work limit exceeded"
        Exit Function
    End If
    EmissionWork = True
End Function

' Allocates a deterministic SSA name within the current LLVM function.
Private Function ValueName(ByRef State As EmissionState) As String
    State.ValueNumber = State.ValueNumber + 1
    ValueName = "%v" & CStr(State.ValueNumber)
End Function

' Allocates a deterministic auxiliary basic-block name.
Private Function BlockName(ByRef State As EmissionState, ByVal Prefix As String) As String
    State.LabelNumber = State.LabelNumber + 1
    BlockName = Prefix & "." & CStr(State.LabelNumber)
End Function

' Gives each executable syntax node a stable control-flow entry label.
Private Function StatementLabel(ByVal Node As Long) As String
    StatementLabel = "stmt." & CStr(Node)
End Function

' Chooses the first statement of a sequence or its supplied continuation.
Private Function SequenceEntry(ByRef Parsed As ParsedProject, ByVal Parent As Long, ByVal Continuation As String) As String
    If Parent = 0 Then
        SequenceEntry = Continuation
    ElseIf Parsed.Nodes(Parent).FirstChild = 0 Then
        SequenceEntry = Continuation
    Else
        SequenceEntry = StatementLabel(Parsed.Nodes(Parent).FirstChild)
    End If
End Function

' Records statement continuation separately from the saved handler resume site.
Private Sub RegisterFailure(ByRef State As EmissionState)
    If Not State.FailureSeen(State.CurrentNode) Then
        State.FailureSeen(State.CurrentNode) = True
        State.FailureCount = State.FailureCount + 1
        State.FailureSites(State.FailureCount) = State.CurrentNode
        State.FailureNext(State.CurrentNode) = State.CurrentNext
    End If
End Sub

' Emits a checked branch that records a new error only on actual failure.
Private Sub GuardError(ByRef State As EmissionState, ByVal FailedValue As String, ByVal ErrorNumber As Long)
    Dim FailedBlock As String
    Dim SuccessBlock As String
    FailedBlock = BlockName(State, "operation.fail")
    SuccessBlock = BlockName(State, "operation.ok")
    Call RegisterFailure(State)
    Call AddLine(State, "  br i1 " & FailedValue & ", label %" & FailedBlock & ", label %" & SuccessBlock)
    Call AddLine(State, FailedBlock & ":")
    Call AddLine(State, "  store i64 " & CStr(ErrorNumber) & ", ptr %err")
    Call AddLine(State, "  br label %failure.dispatch")
    Call AddLine(State, SuccessBlock & ":")
End Sub

' Checks a fresh procedure outcome before exposing its ordinary result.
Private Sub GuardCall(ByRef State As EmissionState, ByVal Result As String)
    Dim Success As String
    Dim SuccessBlock As String
    Success = ValueName(State)
    SuccessBlock = BlockName(State, "call.ok")
    Call RegisterFailure(State)
    Call AddLine(State, "  " & Success & " = extractvalue { i1, i64 } " & Result & ", 0")
    Call AddLine(State, "  br i1 " & Success & ", label %" & SuccessBlock & ", label %failure.dispatch")
    Call AddLine(State, SuccessBlock & ":")
End Sub

' Emits scalar conversion without changing explicit intermediate arithmetic types.
Private Function ConvertNative(ByRef State As EmissionState, ByVal Value As String, ByVal SourceType As String, ByVal DestinationType As String) As String
    Dim Test As String
    Dim Result As String
    Dim Narrow As String
    Dim Width As String
    Dim Extension As String
    If Len(DestinationType) = 0 Or SourceType = DestinationType Then
        ConvertNative = Value
        Exit Function
    End If
    If DestinationType = "Boolean" Then
        Test = ValueName(State)
        Result = ValueName(State)
        Call AddLine(State, "  " & Test & " = icmp ne i64 " & Value & ", 0")
        Call AddLine(State, "  " & Result & " = select i1 " & Test & ", i64 -1, i64 0")
    ElseIf IntegerConversionMayFail(SourceType, DestinationType) Then
        Width = "i" & CStr(IntegerWidth(DestinationType))
        Extension = "sext"
        If DestinationType = "Byte" Then Extension = "zext"
        Narrow = ValueName(State)
        Result = ValueName(State)
        Test = ValueName(State)
        Call AddLine(State, "  " & Narrow & " = trunc i64 " & Value & " to " & Width)
        Call AddLine(State, "  " & Result & " = " & Extension & " " & Width & " " & Narrow & " to i64")
        Call AddLine(State, "  " & Test & " = icmp ne i64 " & Value & ", " & Result)
        Call GuardError(State, Test, 6)
    Else
        Result = Value
    End If
    ConvertNative = Result
End Function

' Determines which conditions are outside the unsettled compound-header failure boundary.
Private Function ConditionMayFail(ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByVal Node As Long) As Boolean
    Dim Child As Long
    If Bound.Nodes(Node).ConstantKnown Then Exit Function
    Select Case Parsed.Nodes(Node).Kind
    Case "call"
        ConditionMayFail = True
        Exit Function
    Case "binary"
        If Parsed.Nodes(Node).Text = "+" Then
            ConditionMayFail = True
            Exit Function
        End If
    Case "unary"
        If Parsed.Nodes(Node).Text = "-" Then
            ConditionMayFail = True
            Exit Function
        End If
    End Select
    Child = Parsed.Nodes(Node).FirstChild
    Do While Child <> 0
        If IntegerConversionMayFail(Bound.Nodes(Child).TypeName, Bound.Nodes(Child).ConvertedType) Then
            ConditionMayFail = True
            Exit Function
        End If
        If ConditionMayFail(Parsed, Bound, Child) Then
            ConditionMayFail = True
            Exit Function
        End If
        Child = Parsed.Nodes(Child).NextSibling
    Loop
End Function

' Traces initializer-only module accesses, including reachable procedure bodies.
Private Function InitializerDependencies(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As EmissionState, ByRef Diagnostic As String) As Boolean
    Dim Stack() As Long
    Dim Seen() As Boolean
    Dim Count As Long
    Dim Origin As Long
    Dim Node As Long
    Dim Child As Long
    Dim Symbol As Long
    Dim Target As Long
    Dim Index As Long
    Dim Middle As Long
    Dim Other As Long
    Dim Kind As String
    Dim Work As Long
    ReDim Stack(1 To Parsed.NodeCount + Bound.SymbolCount)
    ReDim State.ModuleDependencies(0 To Parsed.ModuleCount * Parsed.ModuleCount - 1)
    For Origin = 0 To Parsed.ModuleCount - 1
        ReDim Seen(1 To Bound.SymbolCount)
        Count = 0
        Node = Parsed.Nodes(Parsed.Modules(Origin).RootNode).FirstChild
        Do While Node <> 0
            If Parsed.Nodes(Node).Kind = "variable" Then
                Child = Parsed.Nodes(Node).FirstChild
                If Child <> 0 Then
                    Count = Count + 1
                    Stack(Count) = Child
                End If
            End If
            Node = Parsed.Nodes(Node).NextSibling
        Loop
        Do While Count > 0
            Node = Stack(Count)
            Count = Count - 1
            Work = Work + 1
            If Work > 10000000 Then
                InitializerDependencies = EmissionError(Project, Parsed, Node, Diagnostic, "E_LIMIT", "initializer dependency work limit exceeded")
                Exit Function
            End If
            Symbol = Bound.Nodes(Node).SymbolIndex
            If Symbol <> 0 Then
                Kind = Bound.Symbols(Symbol).Kind
                Target = -1
                If Kind = "variable" Then
                    If Bound.Symbols(Bound.Symbols(Symbol).ScopeSymbol).Kind = "module" Then Target = Bound.Symbols(Symbol).ModuleIndex
                ElseIf Parsed.Nodes(Node).Kind = "call" And Bound.Symbols(Symbol).Origin = "source" Then
                    Target = Bound.Symbols(Symbol).ModuleIndex
                    If Not Seen(Symbol) Then
                        Seen(Symbol) = True
                        Child = Parsed.Nodes(Bound.Symbols(Symbol).DeclarationNode).FirstChild
                        Do While Child <> 0
                            If Parsed.Nodes(Child).Kind = "body" Then
                                Count = Count + 1
                                Stack(Count) = Child
                            End If
                            Child = Parsed.Nodes(Child).NextSibling
                        Loop
                    End If
                End If
                If Target >= 0 Then
                    If Target = Origin Then
                        If Parsed.Nodes(Node).ModuleIndex <> Origin Then
                            InitializerDependencies = EmissionError(Project, Parsed, Node, Diagnostic, "E_UNSUPPORTED", "potential cross-module initialization cycle is outside the bounded native profile")
                            Exit Function
                        End If
                    Else
                        State.ModuleDependencies(Origin * Parsed.ModuleCount + Target) = 1
                    End If
                End If
            End If
            Child = Parsed.Nodes(Node).FirstChild
            Do While Child <> 0
                Count = Count + 1
                If Count > UBound(Stack) Then
                    InitializerDependencies = EmissionError(Project, Parsed, Node, Diagnostic, "E_LIMIT", "initializer dependency stack limit exceeded")
                    Exit Function
                End If
                Stack(Count) = Child
                Child = Parsed.Nodes(Child).NextSibling
            Loop
        Loop
    Next Origin
    For Middle = 0 To Parsed.ModuleCount - 1
        For Index = 0 To Parsed.ModuleCount - 1
            If State.ModuleDependencies(Index * Parsed.ModuleCount + Middle) <> 0 Then
                For Other = 0 To Parsed.ModuleCount - 1
                    If State.ModuleDependencies(Middle * Parsed.ModuleCount + Other) <> 0 Then State.ModuleDependencies(Index * Parsed.ModuleCount + Other) = 1
                Next Other
            End If
        Next Index
    Next Middle
    For Index = 0 To Parsed.ModuleCount - 1
        If State.ModuleDependencies(Index * Parsed.ModuleCount + Index) <> 0 Then
            InitializerDependencies = EmissionError(Project, Parsed, Parsed.Modules(Index).RootNode, Diagnostic, "E_UNSUPPORTED", "potential cross-module initialization cycle is outside the bounded native profile")
            Exit Function
        End If
    Next Index
    InitializerDependencies = True
End Function

' Verifies bounded frames and deferred boundaries before writing any output.
Private Function CheckEmissionProfile(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As EmissionState, ByRef Diagnostic As String) As Boolean
    Dim Slots() As Long
    Dim Symbol As Long
    Dim Scope As Long
    Dim Node As Long
    Dim Kind As String
    Dim Name As String
    ReDim Slots(1 To Bound.SymbolCount)
    ReDim State.FieldIndex(1 To Bound.SymbolCount)
    For Symbol = 1 To Bound.SymbolCount
        Kind = Bound.Symbols(Symbol).Kind
        State.FieldIndex(Symbol) = -1
        If Bound.Symbols(Symbol).Origin = "source" Then
            Node = Bound.Symbols(Symbol).DeclarationNode
            If Kind = "sub" Or Kind = "function" Then
                Name = FoldAscii(Bound.Symbols(Symbol).Name)
                If Name = "module_initialize" Or Name = "module_terminate" Then
                    CheckEmissionProfile = EmissionError(Project, Parsed, Node, Diagnostic, "E_UNSUPPORTED", "lifecycle hook execution/failure delivery is outside the native profile")
                    Exit Function
                End If
                If Bound.Symbols(Symbol).ParameterCount > MaximumNativeParameters Then
                    CheckEmissionProfile = EmissionError(Project, Parsed, Node, Diagnostic, "E_LIMIT", "native procedure parameter limit exceeded")
                    Exit Function
                End If
            ElseIf Kind = "variable" Or Kind = "parameter" Or Kind = "result" Then
                Scope = Bound.Symbols(Symbol).ScopeSymbol
                If Bound.Symbols(Scope).Kind = "module" Then
                    State.FieldIndex(Symbol) = State.FieldCount
                    State.FieldCount = State.FieldCount + 1
                Else
                    Slots(Scope) = Slots(Scope) + 1
                End If
            End If
        End If
    Next Symbol
    For Node = 1 To Parsed.NodeCount
        State.ErrorNode = Node
        Scope = Bound.Nodes(Node).ScopeSymbol
        If Bound.Nodes(Node).ArgumentMode = "temp" Then Slots(Scope) = Slots(Scope) + 1
        If Parsed.Nodes(Node).Kind = "if" Then
            If ConditionMayFail(Parsed, Bound, Parsed.Nodes(Node).FirstChild) Then
                CheckEmissionProfile = EmissionError(Project, Parsed, Node, Diagnostic, "E_UNSUPPORTED", "potential failure in an If condition awaits its compound-header continuation contract")
                Exit Function
            End If
        End If
        If Parsed.Nodes(Node).Kind = "call" And Scope = Bound.EntrySymbol Then
            Symbol = Bound.Nodes(Node).SymbolIndex
            If Symbol <> 0 Then
                If Bound.Symbols(Symbol).BindingId = "error.raise" Then
                    CheckEmissionProfile = EmissionError(Project, Parsed, Node, Diagnostic, "E_UNSUPPORTED", "direct Raise in the root Main procedure awaits its boundary contract")
                    Exit Function
                End If
            End If
        End If
    Next Node
    For Symbol = 1 To Bound.SymbolCount
        If Slots(Symbol) + 4 > MaximumNativeSlots Then
            CheckEmissionProfile = EmissionError(Project, Parsed, Bound.Symbols(Symbol).DeclarationNode, Diagnostic, "E_LIMIT", "native scalar storage/temporary frame limit exceeded")
            Exit Function
        End If
    Next Symbol
    CheckEmissionProfile = InitializerDependencies(Project, Parsed, Bound, State, Diagnostic)
End Function

' Completes another module before a cross-module procedure or storage access.
Private Sub EnsureModule(ByRef State As EmissionState, ByVal ModuleIndex As Long)
    Dim Result As String
    If ModuleIndex = State.CurrentModule Then Exit Sub
    Result = ValueName(State)
    Call AddLine(State, "  " & Result & " = call i1 @ube.module.ensure." & CStr(ModuleIndex) & "(ptr %ctx)")
End Sub

' Locates declared writable storage without reading it or reevaluating an alias argument.
Private Function StorageAddress(ByRef Bound As BoundProject, ByRef State As EmissionState, ByVal Symbol As Long) As String
    Dim Address As String
    If State.FieldIndex(Symbol) >= 0 Then
        Call EnsureModule(State, Bound.Symbols(Symbol).ModuleIndex)
        Address = ValueName(State)
        Call AddLine(State, "  " & Address & " = getelementptr %ube.context, ptr %ctx, i32 0, i32 3, i64 " & CStr(State.FieldIndex(Symbol)))
    ElseIf Bound.Symbols(Symbol).Kind = "parameter" And Bound.Symbols(Symbol).PassingMode = "ByRef" Then
        Address = "%arg." & CStr(Symbol)
    Else
        Address = "%slot." & CStr(Symbol)
    End If
    StorageAddress = Address
End Function

' Emits one eager arithmetic operation with checked overflow in the selected integer width.
Private Function CheckedArithmetic(ByRef State As EmissionState, ByVal LeftValue As String, ByVal RightValue As String, ByVal TypeName As String, ByVal Subtract As Boolean) As String
    Dim Width As String
    Dim Operation As String
    Dim LeftOperand As String
    Dim RightOperand As String
    Dim Pair As String
    Dim Overflow As String
    Dim NarrowResult As String
    Dim Result As String
    Width = "i" & CStr(IntegerWidth(TypeName))
    Operation = "sadd"
    If Subtract Then Operation = "ssub"
    LeftOperand = LeftValue
    RightOperand = RightValue
    If Width <> "i64" Then
        LeftOperand = ValueName(State)
        RightOperand = ValueName(State)
        Call AddLine(State, "  " & LeftOperand & " = trunc i64 " & LeftValue & " to " & Width)
        Call AddLine(State, "  " & RightOperand & " = trunc i64 " & RightValue & " to " & Width)
    End If
    Pair = ValueName(State)
    Overflow = ValueName(State)
    NarrowResult = ValueName(State)
    Call AddLine(State, "  " & Pair & " = call { " & Width & ", i1 } @llvm." & Operation & ".with.overflow." & Width & "(" & Width & " " & LeftOperand & ", " & Width & " " & RightOperand & ")")
    Call AddLine(State, "  " & Overflow & " = extractvalue { " & Width & ", i1 } " & Pair & ", 1")
    Call GuardError(State, Overflow, 6)
    Call AddLine(State, "  " & NarrowResult & " = extractvalue { " & Width & ", i1 } " & Pair & ", 0")
    Result = NarrowResult
    If Width <> "i64" Then
        Result = ValueName(State)
        Call AddLine(State, "  " & Result & " = sext " & Width & " " & NarrowResult & " to i64")
    End If
    CheckedArithmetic = Result
End Function

' Emits source-order argument preparation and dispatches only already-bound trusted identities.
Private Function EmitCall(ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As EmissionState, ByVal Node As Long, ByRef Terminated As Boolean) As String
    Dim Symbol As Long
    Dim Callee As Long
    Dim Argument As Long
    Dim Value As String
    Dim Arguments As String
    Dim Address As String
    Dim Pair As String
    Dim Result As String
    Dim Role As String
    Symbol = Bound.Nodes(Node).SymbolIndex
    Callee = Parsed.Nodes(Node).FirstChild
    Argument = Parsed.Nodes(Callee).NextSibling
    Arguments = "ptr %ctx"
    Role = Bound.Symbols(Symbol).BindingId
    Do While Argument <> 0
        If Bound.Nodes(Argument).ArgumentMode = "alias" Then
            Address = StorageAddress(Bound, State, Bound.Nodes(Argument).SymbolIndex)
            Arguments = Arguments & ", ptr " & Address
        Else
            Value = EmitExpression(Parsed, Bound, State, Argument)
            Value = ConvertNative(State, Value, Bound.Nodes(Argument).TypeName, Bound.Nodes(Argument).ConvertedType)
            If Bound.Nodes(Argument).ArgumentMode = "temp" Then
                Address = "%temp." & CStr(Argument)
                Call AddLine(State, "  store i64 " & Value & ", ptr " & Address)
                Arguments = Arguments & ", ptr " & Address
            Else
                Arguments = Arguments & ", i64 " & Value
            End If
        End If
        Argument = Parsed.Nodes(Argument).NextSibling
    Loop
    If Role = "error.raise" Then
        Call AddLine(State, "  store i64 " & Value & ", ptr %err")
        Call AddLine(State, "  br label %return.fail")
        Terminated = True
        EmitCall = "0"
        Exit Function
    ElseIf Role = "error.clear" Then
        Call AddLine(State, "  store i64 0, ptr %err")
        EmitCall = "0"
        Exit Function
    End If
    Call EnsureModule(State, Bound.Symbols(Symbol).ModuleIndex)
    Pair = ValueName(State)
    Call AddLine(State, "  " & Pair & " = call { i1, i64 } @ube.proc." & CStr(Symbol) & "(" & Arguments & ")")
    Call GuardCall(State, Pair)
    Result = ValueName(State)
    Call AddLine(State, "  " & Result & " = extractvalue { i1, i64 } " & Pair & ", 1")
    EmitCall = Result
End Function

' Lowers scalar expressions in written evaluation order, using exact bound constants when available.
Private Function EmitExpression(ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As EmissionState, ByVal Node As Long) As String
    Dim Kind As String
    Dim Child As Long
    Dim RightNode As Long
    Dim Symbol As Long
    Dim LeftValue As String
    Dim RightValue As String
    Dim Address As String
    Dim Result As String
    Dim Test As String
    Dim Predicate As String
    Dim Terminated As Boolean
    If Bound.Nodes(Node).ConstantKnown Then
        EmitExpression = CStr(Bound.Nodes(Node).ConstantValue)
        Exit Function
    End If
    Kind = Parsed.Nodes(Node).Kind
    Select Case Kind
    Case "name", "member"
        Symbol = Bound.Nodes(Node).SymbolIndex
        Result = ValueName(State)
        If Bound.Symbols(Symbol).BindingId = "error.number" Then
            Call AddLine(State, "  " & Result & " = load i64, ptr %err")
        Else
            Address = StorageAddress(Bound, State, Symbol)
            Call AddLine(State, "  " & Result & " = load i64, ptr " & Address)
        End If
    Case "group"
        Result = EmitExpression(Parsed, Bound, State, Parsed.Nodes(Node).FirstChild)
    Case "unary"
        Child = Parsed.Nodes(Node).FirstChild
        LeftValue = EmitExpression(Parsed, Bound, State, Child)
        If Parsed.Nodes(Node).Text = "-" Then
            Result = CheckedArithmetic(State, "0", LeftValue, Bound.Nodes(Node).TypeName, True)
        Else
            Result = LeftValue
        End If
    Case "call"
        Result = EmitCall(Parsed, Bound, State, Node, Terminated)
    Case "binary"
        Child = Parsed.Nodes(Node).FirstChild
        RightNode = Parsed.Nodes(Child).NextSibling
        LeftValue = EmitExpression(Parsed, Bound, State, Child)
        LeftValue = ConvertNative(State, LeftValue, Bound.Nodes(Child).TypeName, Bound.Nodes(Child).ConvertedType)
        RightValue = EmitExpression(Parsed, Bound, State, RightNode)
        RightValue = ConvertNative(State, RightValue, Bound.Nodes(RightNode).TypeName, Bound.Nodes(RightNode).ConvertedType)
        If Parsed.Nodes(Node).Text = "+" Then
            Result = CheckedArithmetic(State, LeftValue, RightValue, Bound.Nodes(Node).TypeName, False)
        ElseIf Parsed.Nodes(Node).Text = "and" Then
            Result = ValueName(State)
            ' Canonical signed extension makes i64 And equal the selected integral-width result.
            Call AddLine(State, "  " & Result & " = and i64 " & LeftValue & ", " & RightValue)
        Else
            Select Case Parsed.Nodes(Node).Text
            Case "=": Predicate = "eq"
            Case "<>": Predicate = "ne"
            Case "<": Predicate = "slt"
            Case ">": Predicate = "sgt"
            Case "<=": Predicate = "sle"
            Case ">=": Predicate = "sge"
            End Select
            Test = ValueName(State)
            Result = ValueName(State)
            Call AddLine(State, "  " & Test & " = icmp " & Predicate & " i64 " & LeftValue & ", " & RightValue)
            Call AddLine(State, "  " & Result & " = select i1 " & Test & ", i64 -1, i64 0")
        End If
    End Select
    EmitExpression = Result
End Function

' Emits a source statement and its explicit continuation; incomplete assignments never store.
Private Sub EmitStatement(ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As EmissionState, ByVal Node As Long, ByVal Continuation As String)
    Dim Kind As String
    Dim Child As Long
    Dim ValueNode As Long
    Dim ThenNode As Long
    Dim ElseNode As Long
    Dim Symbol As Long
    Dim Value As String
    Dim Address As String
    Dim Test As String
    Dim Terminated As Boolean
    State.CurrentNode = Node
    State.ErrorNode = Node
    State.CurrentNext = Continuation
    Kind = Parsed.Nodes(Node).Kind
    Call AddLine(State, StatementLabel(Node) & ":")
    Call AddLine(State, "  ; source module=" & CStr(Parsed.Nodes(Node).ModuleIndex) & " line=" & CStr(Parsed.Nodes(Node).Line) & " column=" & CStr(Parsed.Nodes(Node).Column) & " node=" & CStr(Node))
    Call AddLine(State, "  store i32 " & CStr(Node) & ", ptr %failure.site")
    Select Case Kind
    Case "variable", "assignment"
        If Kind = "variable" Then
            Symbol = Bound.Nodes(Node).SymbolIndex
            ValueNode = Parsed.Nodes(Node).FirstChild
            Address = StorageAddress(Bound, State, Symbol)
            Call AddLine(State, "  store i64 0, ptr " & Address)
        Else
            Child = Parsed.Nodes(Node).FirstChild
            ValueNode = Parsed.Nodes(Child).NextSibling
            Symbol = Bound.Nodes(Child).SymbolIndex
            Address = StorageAddress(Bound, State, Symbol)
        End If
        If ValueNode <> 0 Then
            Value = EmitExpression(Parsed, Bound, State, ValueNode)
            Value = ConvertNative(State, Value, Bound.Nodes(ValueNode).TypeName, Bound.Symbols(Symbol).TypeName)
            Call AddLine(State, "  store i64 " & Value & ", ptr " & Address)
        End If
    Case "call"
        Value = EmitCall(Parsed, Bound, State, Node, Terminated)
    Case "goto"
        Call AddLine(State, "  br label %" & StatementLabel(Bound.Symbols(Bound.Nodes(Node).SymbolIndex).DeclarationNode))
        Terminated = True
    Case "exit"
        Call AddLine(State, "  br label %return.ok")
        Terminated = True
    Case "on-error"
        Symbol = Bound.Nodes(Node).SymbolIndex
        Call AddLine(State, "  store i32 " & CStr(Symbol) & ", ptr %handler.target")
    Case "if"
        Child = Parsed.Nodes(Node).FirstChild
        ThenNode = Parsed.Nodes(Child).NextSibling
        ElseNode = Parsed.Nodes(ThenNode).NextSibling
        Value = EmitExpression(Parsed, Bound, State, Child)
        Test = ValueName(State)
        Call AddLine(State, "  " & Test & " = icmp ne i64 " & Value & ", 0")
        Call AddLine(State, "  br i1 " & Test & ", label %" & SequenceEntry(Parsed, ThenNode, Continuation) & ", label %" & SequenceEntry(Parsed, ElseNode, Continuation))
        Call EmitSequence(Parsed, Bound, State, ThenNode, Continuation)
        If ElseNode <> 0 Then Call EmitSequence(Parsed, Bound, State, ElseNode, Continuation)
        Terminated = True
    Case "constant", "label"
        ' Constants have no runtime storage; a label remains an actual branch target.
    End Select
    If Not Terminated Then Call AddLine(State, "  br label %" & Continuation)
End Sub

' Emits all sibling statements with separate source-level failure continuations.
Private Sub EmitSequence(ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As EmissionState, ByVal Parent As Long, ByVal Continuation As String)
    Dim Node As Long
    Dim NextNode As Long
    Dim NextLabel As String
    Node = Parsed.Nodes(Parent).FirstChild
    Do While Node <> 0
        NextNode = Parsed.Nodes(Node).NextSibling
        NextLabel = Continuation
        If NextNode <> 0 Then NextLabel = StatementLabel(NextNode)
        Call EmitStatement(Parsed, Bound, State, Node, NextLabel)
        Node = NextNode
    Loop
End Sub

' Emits one central handler dispatcher, preserving the saved site while a handler is active.
Private Sub EmitFailureDispatch(ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As EmissionState)
    Dim Index As Long
    Dim Node As Long
    Dim Active As String
    Dim Target As String
    Dim Enabled As String
    Dim Inactive As String
    Dim Eligible As String
    Dim Site As String
    Call AddLine(State, "failure.dispatch:")
    Active = ValueName(State)
    Target = ValueName(State)
    Enabled = ValueName(State)
    Inactive = ValueName(State)
    Eligible = ValueName(State)
    Site = ValueName(State)
    Call AddLine(State, "  " & Active & " = load i1, ptr %handler.active")
    Call AddLine(State, "  " & Target & " = load i32, ptr %handler.target")
    Call AddLine(State, "  " & Site & " = load i32, ptr %failure.site")
    Call AddLine(State, "  " & Enabled & " = icmp ne i32 " & Target & ", 0")
    Call AddLine(State, "  " & Inactive & " = xor i1 " & Active & ", true")
    Call AddLine(State, "  " & Eligible & " = and i1 " & Enabled & ", " & Inactive)
    Call AddLine(State, "  br i1 " & Eligible & ", label %handler.enter, label %failure.skip")
    Call AddLine(State, "handler.enter:")
    Call AddLine(State, "  store i1 true, ptr %handler.active")
    Call AddLine(State, "  store i32 " & Site & ", ptr %handler.resume")
    Call AddLine(State, "  switch i32 " & Target & ", label %failure.skip [")
    For Index = 1 To Bound.SymbolCount
        If Not EmissionWork(State) Then Exit Sub
        If Bound.Symbols(Index).Kind = "label" And Bound.Symbols(Index).ScopeSymbol = State.CurrentSymbol Then
            Call AddLine(State, "    i32 " & CStr(Index) & ", label %" & StatementLabel(Bound.Symbols(Index).DeclarationNode))
        End If
    Next Index
    Call AddLine(State, "  ]")
    Call AddLine(State, "failure.skip:")
    Call AddLine(State, "  switch i32 " & Site & ", label %return.fail [")
    For Index = 1 To State.FailureCount
        Node = State.FailureSites(Index)
        Call AddLine(State, "    i32 " & CStr(Node) & ", label %" & State.FailureNext(Node))
    Next Index
    Call AddLine(State, "  ]")
End Sub

' Allocates all scalar storage and grouped ByRef temporaries once in the native entry block.
Private Sub EmitFrame(ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As EmissionState)
    Dim Index As Long
    Dim Kind As String
    State.ResultSymbol = 0
    Call AddLine(State, "  %handler.target = alloca i32, align 4")
    Call AddLine(State, "  %handler.active = alloca i1, align 1")
    Call AddLine(State, "  %failure.site = alloca i32, align 4")
    Call AddLine(State, "  %handler.resume = alloca i32, align 4")
    Call AddLine(State, "  store i32 0, ptr %handler.target")
    Call AddLine(State, "  store i1 false, ptr %handler.active")
    Call AddLine(State, "  store i32 0, ptr %failure.site")
    Call AddLine(State, "  store i32 0, ptr %handler.resume")
    For Index = 1 To Bound.SymbolCount
        If Not EmissionWork(State) Then Exit Sub
        If Bound.Symbols(Index).ScopeSymbol = State.CurrentSymbol Then
            Kind = Bound.Symbols(Index).Kind
            If Kind = "result" Then State.ResultSymbol = Index
            If Kind = "variable" Or Kind = "result" Or (Kind = "parameter" And Bound.Symbols(Index).PassingMode = "ByVal") Then
                If State.FieldIndex(Index) < 0 Then
                    Call AddLine(State, "  %slot." & CStr(Index) & " = alloca i64, align 8")
                    If Kind = "parameter" Then
                        Call AddLine(State, "  store i64 %arg." & CStr(Index) & ", ptr %slot." & CStr(Index))
                    Else
                        Call AddLine(State, "  store i64 0, ptr %slot." & CStr(Index))
                    End If
                End If
            End If
        End If
    Next Index
    For Index = 1 To Parsed.NodeCount
        If Not EmissionWork(State) Then Exit Sub
        If Bound.Nodes(Index).ScopeSymbol = State.CurrentSymbol And Bound.Nodes(Index).ArgumentMode = "temp" Then
            Call AddLine(State, "  %temp." & CStr(Index) & " = alloca i64, align 8")
        End If
    Next Index
End Sub

' Emits balanced depth accounting and success/failure returns without clearing Err.
Private Sub EmitReturns(ByRef State As EmissionState)
    Dim Value As String
    Dim Result As String
    Dim Depth As String
    Dim Reduced As String
    Call AddLine(State, "return.ok:")
    If State.CountedDepth Then
        Depth = ValueName(State)
        Reduced = ValueName(State)
        Call AddLine(State, "  " & Depth & " = load i64, ptr %depth.ptr")
        Call AddLine(State, "  " & Reduced & " = sub i64 " & Depth & ", 1")
        Call AddLine(State, "  store i64 " & Reduced & ", ptr %depth.ptr")
    End If
    Value = "0"
    If State.ResultSymbol <> 0 Then
        Value = ValueName(State)
        Call AddLine(State, "  " & Value & " = load i64, ptr %slot." & CStr(State.ResultSymbol))
    End If
    Result = ValueName(State)
    Call AddLine(State, "  " & Result & " = insertvalue { i1, i64 } { i1 true, i64 0 }, i64 " & Value & ", 1")
    Call AddLine(State, "  ret { i1, i64 } " & Result)
    Call AddLine(State, "return.fail:")
    If State.CountedDepth Then
        Depth = ValueName(State)
        Reduced = ValueName(State)
        Call AddLine(State, "  " & Depth & " = load i64, ptr %depth.ptr")
        Call AddLine(State, "  " & Reduced & " = sub i64 " & Depth & ", 1")
        Call AddLine(State, "  store i64 " & Reduced & ", ptr %depth.ptr")
    End If
    Call AddLine(State, "  ret { i1, i64 } { i1 false, i64 0 }")
    Call AddLine(State, "}")
    Call AddLine(State, "")
End Sub

' Starts one source procedure with checked call depth and a neutral frame.
Private Sub EmitProcedure(ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As EmissionState, ByVal Symbol As Long)
    Dim Signature As String
    Dim Parameter As Long
    Dim Child As Long
    Dim Body As Long
    Dim Depth As String
    Dim Allowed As String
    Dim Increased As String
    Dim Initialized As String
    State.ValueNumber = 0
    State.LabelNumber = 0
    State.CurrentSymbol = Symbol
    State.CurrentModule = Bound.Symbols(Symbol).ModuleIndex
    State.CountedDepth = True
    State.FailureCount = 0
    Signature = "ptr %ctx"
    Parameter = Bound.Symbols(Symbol).FirstParameter
    Do While Parameter <> 0
        If Bound.Symbols(Parameter).PassingMode = "ByRef" Then
            Signature = Signature & ", ptr %arg." & CStr(Parameter)
        Else
            Signature = Signature & ", i64 %arg." & CStr(Parameter)
        End If
        Parameter = Bound.Symbols(Parameter).NextParameter
    Loop
    Call AddLine(State, "define { i1, i64 } @ube.proc." & CStr(Symbol) & "(" & Signature & ") {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %err = getelementptr %ube.context, ptr %ctx, i32 0, i32 0")
    Call AddLine(State, "  %depth.ptr = getelementptr %ube.context, ptr %ctx, i32 0, i32 1")
    Call EmitFrame(Parsed, Bound, State)
    Depth = ValueName(State)
    Allowed = ValueName(State)
    Increased = ValueName(State)
    Initialized = ValueName(State)
    Call AddLine(State, "  " & Depth & " = load i64, ptr %depth.ptr")
    Call AddLine(State, "  " & Allowed & " = icmp ult i64 " & Depth & ", " & CStr(MaximumNativeCallDepth))
    Call AddLine(State, "  br i1 " & Allowed & ", label %depth.enter, label %depth.refused")
    Call AddLine(State, "depth.refused:")
    Call AddLine(State, "  store i64 28, ptr %err")
    Call AddLine(State, "  ret { i1, i64 } { i1 false, i64 0 }")
    Call AddLine(State, "depth.enter:")
    Call AddLine(State, "  " & Increased & " = add i64 " & Depth & ", 1")
    Call AddLine(State, "  store i64 " & Increased & ", ptr %depth.ptr")
    Call AddLine(State, "  " & Initialized & " = call i1 @ube.module.ensure." & CStr(State.CurrentModule) & "(ptr %ctx)")
    Child = Parsed.Nodes(Bound.Symbols(Symbol).DeclarationNode).FirstChild
    Do While Child <> 0
        If Parsed.Nodes(Child).Kind = "body" Then Body = Child
        Child = Parsed.Nodes(Child).NextSibling
    Loop
    Call AddLine(State, "  br label %" & SequenceEntry(Parsed, Body, "return.ok"))
    If Body <> 0 Then Call EmitSequence(Parsed, Bound, State, Body, "return.ok")
    Call EmitFailureDispatch(Parsed, Bound, State)
    Call EmitReturns(State)
End Sub

' Emits scalar module initialization with the ordinary failed-statement continuation rule.
Private Sub EmitModuleInitializer(ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As EmissionState, ByVal ModuleIndex As Long)
    Dim Node As Long
    Dim NextNode As Long
    Dim FirstNode As Long
    Dim NextLabel As String
    State.ValueNumber = 0
    State.LabelNumber = 0
    State.CurrentSymbol = Bound.ModuleSymbols(ModuleIndex)
    State.CurrentModule = ModuleIndex
    State.CountedDepth = False
    State.FailureCount = 0
    Call AddLine(State, "define internal { i1, i64 } @ube.module.initialize." & CStr(ModuleIndex) & "(ptr %ctx) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %err = getelementptr %ube.context, ptr %ctx, i32 0, i32 0")
    Call EmitFrame(Parsed, Bound, State)
    Node = Parsed.Nodes(Parsed.Modules(ModuleIndex).RootNode).FirstChild
    Do While Node <> 0
        If Parsed.Nodes(Node).Kind = "variable" Then
            FirstNode = Node
            Exit Do
        End If
        Node = Parsed.Nodes(Node).NextSibling
    Loop
    If FirstNode = 0 Then
        Call AddLine(State, "  br label %return.ok")
    Else
        Call AddLine(State, "  br label %" & StatementLabel(FirstNode))
    End If
    Node = FirstNode
    Do While Node <> 0
        NextNode = Parsed.Nodes(Node).NextSibling
        Do While NextNode <> 0
            If Parsed.Nodes(NextNode).Kind = "variable" Then Exit Do
            NextNode = Parsed.Nodes(NextNode).NextSibling
        Loop
        NextLabel = "return.ok"
        If NextNode <> 0 Then NextLabel = StatementLabel(NextNode)
        Call EmitStatement(Parsed, Bound, State, Node, NextLabel)
        Node = NextNode
    Loop
    Call EmitFailureDispatch(Parsed, Bound, State)
    Call EmitReturns(State)
    Call AddLine(State, "define internal i1 @ube.module.ensure." & CStr(ModuleIndex) & "(ptr %ctx) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %state.ptr = getelementptr %ube.context, ptr %ctx, i32 0, i32 2, i64 " & CStr(ModuleIndex))
    Call AddLine(State, "  %state = load i64, ptr %state.ptr")
    Call AddLine(State, "  %needed = icmp eq i64 %state, 0")
    Call AddLine(State, "  br i1 %needed, label %initialize, label %done")
    Call AddLine(State, "initialize:")
    Call AddLine(State, "  store i64 1, ptr %state.ptr")
    Call AddLine(State, "  %result = call { i1, i64 } @ube.module.initialize." & CStr(ModuleIndex) & "(ptr %ctx)")
    Call AddLine(State, "  store i64 2, ptr %state.ptr")
    Call AddLine(State, "  br label %done")
    Call AddLine(State, "done:")
    Call AddLine(State, "  ret i1 true")
    Call AddLine(State, "}")
    Call AddLine(State, "")
End Sub

' Emits caller-owned context setup and manifest-order startup without hidden runtime allocation.
Private Sub EmitContext(ByRef Parsed As ParsedProject, ByRef State As EmissionState)
    Dim Words As Long
    Dim Index As Long
    Words = 2 + Parsed.ModuleCount + State.FieldCount
    Call AddLine(State, "%ube.context = type { i64, i64, [" & CStr(Parsed.ModuleCount) & " x i64], [" & CStr(State.FieldCount) & " x i64] }")
    Call AddLine(State, "")
    Call AddLine(State, "declare { i16, i1 } @llvm.sadd.with.overflow.i16(i16, i16)")
    Call AddLine(State, "declare { i32, i1 } @llvm.sadd.with.overflow.i32(i32, i32)")
    Call AddLine(State, "declare { i64, i1 } @llvm.sadd.with.overflow.i64(i64, i64)")
    Call AddLine(State, "declare { i16, i1 } @llvm.ssub.with.overflow.i16(i16, i16)")
    Call AddLine(State, "declare { i32, i1 } @llvm.ssub.with.overflow.i32(i32, i32)")
    Call AddLine(State, "declare { i64, i1 } @llvm.ssub.with.overflow.i64(i64, i64)")
    Call AddLine(State, "")
    Call AddLine(State, "define i64 @ube.context.size() {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  ret i64 " & CStr(Words * 8))
    Call AddLine(State, "}")
    Call AddLine(State, "define void @ube.context.init(ptr %ctx) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  br label %zero")
    Call AddLine(State, "zero:")
    Call AddLine(State, "  %index = phi i64 [ 0, %entry ], [ %next, %zero ]")
    Call AddLine(State, "  %slot = getelementptr i64, ptr %ctx, i64 %index")
    Call AddLine(State, "  store volatile i64 0, ptr %slot, align 8")
    Call AddLine(State, "  %next = add i64 %index, 1")
    Call AddLine(State, "  %more = icmp ult i64 %next, " & CStr(Words))
    Call AddLine(State, "  br i1 %more, label %zero, label %done")
    Call AddLine(State, "done:")
    Call AddLine(State, "  ret void")
    Call AddLine(State, "}")
    Call AddLine(State, "define i1 @ube.project.init(ptr %ctx) {")
    Call AddLine(State, "entry:")
    For Index = 0 To Parsed.ModuleCount - 1
        Call AddLine(State, "  %module." & CStr(Index) & " = call i1 @ube.module.ensure." & CStr(Index) & "(ptr %ctx)")
    Next Index
    Call AddLine(State, "  ret i1 true")
    Call AddLine(State, "}")
    Call AddLine(State, "")
End Sub

' Emits the single-execution native launcher; its defensive failure code is not a UBE result value.
Private Sub EmitEntry(ByRef Bound As BoundProject, ByRef State As EmissionState)
    Call AddLine(State, "@ube.entry.context = private global %ube.context zeroinitializer, align 8")
    Call AddLine(State, "define i32 @main() {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  call void @ube.context.init(ptr @ube.entry.context)")
    Call AddLine(State, "  %initialized = call i1 @ube.project.init(ptr @ube.entry.context)")
    Call AddLine(State, "  br i1 %initialized, label %invoke, label %unavailable")
    Call AddLine(State, "invoke:")
    Call AddLine(State, "  %result = call { i1, i64 } @ube.proc." & CStr(Bound.EntrySymbol) & "(ptr @ube.entry.context)")
    Call AddLine(State, "  %success = extractvalue { i1, i64 } %result, 0")
    Call AddLine(State, "  br i1 %success, label %complete, label %unavailable")
    Call AddLine(State, "complete:")
    Call AddLine(State, "  %value = extractvalue { i1, i64 } %result, 1")
    Call AddLine(State, "  %status = trunc i64 %value to i32")
    Call AddLine(State, "  ret i32 %status")
    Call AddLine(State, "unavailable:")
    Call AddLine(State, "  ; Defensive native-launch transport status, never a successful UBE FAIL value.")
    Call AddLine(State, "  ret i32 1")
    Call AddLine(State, "}")
End Sub

' Produces deterministic complete IR only after checking the admitted native execution boundary.
Public Function EmitProject(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef IRText As String, ByRef Diagnostic As String) As Boolean
    Dim State As EmissionState
    Dim Index As Long
    Dim Kind As String
    On Error GoTo Failed
    IRText = ""
    Diagnostic = ""
    If Bound.NodeCount <> Parsed.NodeCount Or Bound.SymbolCount < 1 Or Parsed.ModuleCount < 1 Then
        EmitProject = EmissionError(Project, Parsed, 0, Diagnostic, "E_EMIT", "native emission requires a complete bound project")
        Exit Function
    End If
    ReDim State.Lines(0 To 1023)
    ReDim State.FailureSites(1 To Parsed.NodeCount)
    ReDim State.FailureNext(1 To Parsed.NodeCount)
    ReDim State.FailureSeen(1 To Parsed.NodeCount)
    If Not CheckEmissionProfile(Project, Parsed, Bound, State, Diagnostic) Then Exit Function
    Call AddLine(State, "; UBE scalar native output; fresh success flag is separate from sticky Err.")
    Call AddLine(State, "target triple = " & Chr$(34) & "x86_64-pc-windows-msvc" & Chr$(34))
    Call AddLine(State, "")
    Call EmitContext(Parsed, State)
    For Index = 0 To Parsed.ModuleCount - 1
        Call EmitModuleInitializer(Parsed, Bound, State, Index)
        If State.Failed Then Exit For
    Next Index
    For Index = 1 To Bound.SymbolCount
        Kind = Bound.Symbols(Index).Kind
        If Bound.Symbols(Index).Origin = "source" Then
            If Kind = "sub" Or Kind = "function" Then Call EmitProcedure(Parsed, Bound, State, Index)
        End If
        If State.Failed Then Exit For
    Next Index
    If Project.KindName = "exe" Then Call EmitEntry(Bound, State)
    If State.Failed Then
        EmitProject = EmissionError(Project, Parsed, State.ErrorNode, Diagnostic, "E_LIMIT", State.FailureDetail)
        Exit Function
    End If
    ReDim Preserve State.Lines(0 To State.LineCount - 1)
    IRText = Join(State.Lines, vbCrLf) & vbCrLf
    EmitProject = True
    Exit Function
Failed:
    On Error Resume Next
    IRText = ""
    EmitProject = EmissionError(Project, Parsed, State.ErrorNode, Diagnostic, "E_INTERNAL", "unable to emit bounded native IR")
End Function
