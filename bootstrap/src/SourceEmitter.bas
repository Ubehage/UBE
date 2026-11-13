Attribute VB_Name = "SourceEmitter"
Option Explicit

' Native lowering retains explicit context ownership and fresh call outcomes.
Public Const MaximumIRCharacters As Long = 16777216
Public Const MaximumIRLines As Long = 500000
Public Const MaximumNativeSlots As Long = 128
Public Const MaximumNativeParameters As Long = 64
Public Const MaximumNativeCallDepth As Long = 256
Public Const MaximumModuleStorageCells As Long = 65536

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
    LoopExit As String
    FieldIndex() As Long
    FieldCount As Long
    FailureSites() As Long
    FailureNext() As String
    FailureSeen() As Boolean
    FailureCount As Long
    ModuleDependencies() As Byte
    PinSlot() As Long
    PinCount() As Long
    FirstScopeSymbol() As Long
    NextScopeSymbol() As Long
    FirstTemporary() As Long
    NextTemporary() As Long
    ArgumentArrayCount() As Long
    Escapes() As NativeEscapes.EscapeFact
    FrameBoxCount() As Long
End Type

' Only promoted owned locals require a frame box; borrowed parameters carry an owner.
Private Function BoxedStorage(ByRef Bound As BoundProject, ByRef State As EmissionState, ByVal Symbol As Long) As Boolean
    Dim Node As Long
    Node = Bound.Symbols(Symbol).DeclarationNode
    If Node < 1 Then Exit Function
    If Not State.Escapes(Node - 1).StorageEscapes Then Exit Function
    If Bound.Symbols(Symbol).Kind = "parameter" Then
        If Bound.Symbols(Symbol).PassingMode = "ByRef" Or Bound.Symbols(Symbol).ArrayRank <> 0 Or Bound.Symbols(Symbol).TypeSymbol <> 0 Then Exit Function
    End If
    BoxedStorage = True
End Function

Private Function OwnerParameter(ByRef Bound As BoundProject, ByRef State As EmissionState, ByVal Symbol As Long) As Boolean
    If Bound.Symbols(Symbol).Kind <> "parameter" Then Exit Function
    If Bound.Symbols(Symbol).DeclarationNode < 1 Then Exit Function
    If Not State.Escapes(Bound.Symbols(Symbol).DeclarationNode - 1).StorageEscapes Then Exit Function
    OwnerParameter = Bound.Symbols(Symbol).PassingMode = "ByRef" Or Bound.Symbols(Symbol).ArrayRank <> 0 Or Bound.Symbols(Symbol).TypeSymbol <> 0
End Function

Private Function BoxedTemporary(ByRef State As EmissionState, ByVal Node As Long) As Boolean
    BoxedTemporary = State.Escapes(Node - 1).NeedsOwner And State.Escapes(Node - 1).OwnerKind = NativeEscapes.TemporaryOwner
End Function

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
    Call AddLine(State, "  store atomic i64 " & CStr(ErrorNumber) & ", ptr %err monotonic, align 8")
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

' Converts a primitive operation status to the ordinary failed-statement edge without overwriting Err.
Private Sub GuardStatus(ByRef State As EmissionState, ByVal Success As String)
    Dim SuccessBlock As String
    SuccessBlock = BlockName(State, "operation.ok")
    Call RegisterFailure(State)
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
                Child = DeclarationValueNode(Parsed, Node)
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

' Reserves bounded frame cells before addition, including aggregate snapshots and control storage.
Private Function AddFrameCells(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Slots() As Long, ByVal Scope As Long, ByVal Count As Long, ByVal Node As Long, ByRef Diagnostic As String) As Boolean
    If Count < 0 Or Count > MaximumNativeSlots - 4 - Slots(Scope) Then
        AddFrameCells = EmissionError(Project, Parsed, Node, Diagnostic, "E_LIMIT", "native storage/temporary frame limit exceeded")
        Exit Function
    End If
    Slots(Scope) = Slots(Scope) + Count
    AddFrameCells = True
End Function

' Verifies bounded frames and deferred boundaries before writing any output.
Private Function CheckEmissionProfile(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As EmissionState, ByRef Diagnostic As String) As Boolean
    Dim Slots() As Long
    Dim Symbol As Long
    Dim Scope As Long
    Dim Node As Long
    Dim Kind As String
    Dim Name As String
    Dim Cells As Long
    Dim Child As Long
    Dim Statement As Long
    Dim Parent As Long
    Dim StatementPins() As Long
    Dim EscapeCount As Long
    Dim EscapeError As Long
    If Not NativeEscapes.TryAnalyzeEscapes(Parsed, Bound, Parsed.NodeCount, Bound.SymbolCount, State.Escapes, EscapeCount, EscapeError) Then
        CheckEmissionProfile = EmissionError(Project, Parsed, 0, Diagnostic, "E_LIMIT", "unable to complete bounded native escape analysis")
        Exit Function
    End If
    ReDim Slots(1 To Bound.SymbolCount)
    ReDim State.PinSlot(1 To Parsed.NodeCount)
    ReDim State.PinCount(1 To Bound.SymbolCount)
    ReDim StatementPins(1 To Parsed.NodeCount)
    ReDim State.FieldIndex(1 To Bound.SymbolCount)
    ReDim State.FirstScopeSymbol(1 To Bound.SymbolCount)
    ReDim State.NextScopeSymbol(1 To Bound.SymbolCount)
    ReDim State.FirstTemporary(1 To Bound.SymbolCount)
    ReDim State.NextTemporary(1 To Parsed.NodeCount)
    ReDim State.ArgumentArrayCount(1 To Bound.SymbolCount)
    ReDim State.FrameBoxCount(1 To Bound.SymbolCount)
    ' Reverse insertion retains the previous increasing-symbol/node emission order.
    For Symbol = Bound.SymbolCount To 1 Step -1
        If Not EmissionWork(State) Then
            CheckEmissionProfile = EmissionError(Project, Parsed, Bound.Symbols(Symbol).DeclarationNode, Diagnostic, "E_LIMIT", "native scope indexing work limit exceeded")
            Exit Function
        End If
        Scope = Bound.Symbols(Symbol).ScopeSymbol
        If Scope > 0 Then
            State.NextScopeSymbol(Symbol) = State.FirstScopeSymbol(Scope)
            State.FirstScopeSymbol(Scope) = Symbol
        End If
    Next Symbol
    For Node = Parsed.NodeCount To 1 Step -1
        If Not EmissionWork(State) Then
            CheckEmissionProfile = EmissionError(Project, Parsed, Node, Diagnostic, "E_LIMIT", "native scope indexing work limit exceeded")
            Exit Function
        End If
        If Bound.Nodes(Node).ArgumentMode = "temp" Or (Bound.Nodes(Node).ArgumentMode = "value" And (Bound.Nodes(Node).ArrayRank <> 0 Or Bound.Nodes(Node).TypeSymbol <> 0)) Then
            Scope = Bound.Nodes(Node).ScopeSymbol
            State.NextTemporary(Node) = State.FirstTemporary(Scope)
            State.FirstTemporary(Scope) = Node
            If Bound.Nodes(Node).ArgumentMode = "value" And Bound.Nodes(Node).ArrayRank <> 0 Then State.ArgumentArrayCount(Scope) = State.ArgumentArrayCount(Scope) + 1
            If BoxedTemporary(State, Node) And Bound.Nodes(Node).ArrayRank = 0 Then State.ArgumentArrayCount(Scope) = State.ArgumentArrayCount(Scope) + 1
        End If
    Next Node
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
                    Cells = Bound.Symbols(Symbol).StorageCells
                    If Cells < 1 Or Cells > MaximumModuleStorageCells - State.FieldCount Then
                        CheckEmissionProfile = EmissionError(Project, Parsed, Node, Diagnostic, "E_LIMIT", "native module storage context limit exceeded")
                        Exit Function
                    End If
                    State.FieldIndex(Symbol) = State.FieldCount
                    State.FieldCount = State.FieldCount + Cells
                Else
                    Cells = Bound.Symbols(Symbol).StorageCells
                    If Kind = "parameter" Then
                        If Bound.Symbols(Symbol).PassingMode = "ByRef" Or Bound.Symbols(Symbol).ArrayRank <> 0 Or Bound.Symbols(Symbol).TypeSymbol <> 0 Then Cells = 1
                    End If
                    If BoxedStorage(Bound, State, Symbol) Then
                        Cells = 1
                        State.FrameBoxCount(Scope) = State.FrameBoxCount(Scope) + 1
                    End If
                    If OwnerParameter(Bound, State, Symbol) Then Cells = Cells + 1
                    If Cells < 1 Then Cells = 1
                    If Not AddFrameCells(Project, Parsed, Slots, Scope, Cells, Node, Diagnostic) Then Exit Function
                End If
            End If
        End If
    Next Symbol
    For Node = 1 To Parsed.NodeCount
        State.ErrorNode = Node
        Scope = Bound.Nodes(Node).ScopeSymbol
        If Bound.Nodes(Node).ArgumentMode = "temp" Then
            If Not AddFrameCells(Project, Parsed, Slots, Scope, 1, Node, Diagnostic) Then Exit Function
        ElseIf Bound.Nodes(Node).ArgumentMode = "value" Then
            Cells = 0
            If Bound.Nodes(Node).ArrayRank <> 0 Then
                Cells = 4
            ElseIf Bound.Nodes(Node).TypeSymbol <> 0 Then
                Cells = Bound.Nodes(Node).StorageCells * 2
            End If
            If Cells <> 0 Then
                If BoxedTemporary(State, Node) Then
                    Cells = 1
                    If Bound.Nodes(Node).ArrayRank = 0 Then Cells = Cells + Bound.Nodes(Node).StorageCells
                End If
                If Not AddFrameCells(Project, Parsed, Slots, Scope, Cells, Node, Diagnostic) Then Exit Function
            End If
        End If
        If Bound.Nodes(Node).AccessKind = "index" Then
            Statement = Node
            Parent = Parsed.Nodes(Statement).Parent
            Do While Parent <> 0
                Kind = Parsed.Nodes(Parent).Kind
                If Kind = "body" Or Kind = "then" Or Kind = "else" Or Kind = "module" Then Exit Do
                Statement = Parent
                Parent = Parsed.Nodes(Statement).Parent
            Loop
            StatementPins(Statement) = StatementPins(Statement) + 1
            State.PinSlot(Node) = StatementPins(Statement)
            If State.PinSlot(Node) > State.PinCount(Scope) Then
                If Not AddFrameCells(Project, Parsed, Slots, Scope, 1, Node, Diagnostic) Then Exit Function
                State.PinCount(Scope) = State.PinSlot(Node)
            End If
        End If
        If Parsed.Nodes(Node).Kind = "assignment" Or Parsed.Nodes(Node).Kind = "variable" Then
            Cells = Bound.Nodes(Node).StorageCells
            If Parsed.Nodes(Node).Kind = "assignment" Then
                Child = Parsed.Nodes(Node).FirstChild
                Cells = Bound.Nodes(Child).StorageCells
                If Bound.Nodes(Child).ArrayRank <> 0 Or Bound.Nodes(Child).TypeSymbol = 0 Then Cells = 0
            Else
                Symbol = Bound.Nodes(Node).SymbolIndex
                Cells = Bound.Symbols(Symbol).StorageCells
                If Bound.Symbols(Symbol).ArrayRank <> 0 Or Bound.Symbols(Symbol).TypeSymbol = 0 Then Cells = 0
                Child = DeclarationValueNode(Parsed, Node)
                If Child = 0 Then Cells = 0
            End If
            If Not AddFrameCells(Project, Parsed, Slots, Scope, Cells, Node, Diagnostic) Then Exit Function
        ElseIf Parsed.Nodes(Node).Kind = "binary" Then
            Child = Parsed.Nodes(Node).FirstChild
            If Bound.Nodes(Child).TypeSymbol <> 0 Then
                If Not AddFrameCells(Project, Parsed, Slots, Scope, 2 * Bound.Nodes(Child).StorageCells, Node, Diagnostic) Then Exit Function
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
                CheckEmissionProfile = EmissionError(Project, Parsed, Bound.Symbols(Symbol).DeclarationNode, Diagnostic, "E_LIMIT", "native storage/temporary frame limit exceeded")
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
        Call AddLine(State, "  " & Address & " = call ptr @ube.storage.address(ptr %ctx, i64 " & CStr(State.FieldIndex(Symbol)) & ")")
    ElseIf Bound.Symbols(Symbol).Kind = "parameter" And (Bound.Symbols(Symbol).PassingMode = "ByRef" Or Bound.Symbols(Symbol).ArrayRank <> 0 Or Bound.Symbols(Symbol).TypeSymbol <> 0) Then
        Address = "%arg." & CStr(Symbol)
    Else
        Address = "%slot." & CStr(Symbol)
    End If
    StorageAddress = Address
End Function

' Evaluates a scalar/record/array storage path once, checking indexes before any element pointer exists.
Private Sub GuardBoxAllocation(ByRef State As EmissionState, ByVal Block As String, ByVal Prologue As Boolean)
    Dim Missing As String, Ready As String, Failed As String
    Missing = ValueName(State)
    Call AddLine(State, "  " & Missing & " = icmp eq ptr " & Block & ", null")
    If Not Prologue Then
        Call GuardError(State, Missing, 7)
        Exit Sub
    End If
    Ready = BlockName(State, "box.ready"): Failed = BlockName(State, "box.failed")
    Call AddLine(State, "  br i1 " & Missing & ", label %" & Failed & ", label %" & Ready)
    Call AddLine(State, Failed & ":")
    Call AddLine(State, "  store atomic i64 7, ptr %err monotonic, align 8")
    Call AddLine(State, "  br label %return.fail")
    Call AddLine(State, Ready & ":")
End Sub

' Allocates one fresh owner before exposing its payload to source operations.
Private Function AllocateBox(ByRef State As EmissionState, ByVal Slot As String, ByVal Cells As Long, ByVal ContainsArray As Boolean, ByVal Prologue As Boolean, Optional ByVal Address As String = "") As String
    Dim Block As String
    Block = ValueName(State)
    Call AddLine(State, "  " & Block & " = call ptr @ube.memory.new(ptr %ctx, i64 " & CStr(Cells) & ", i64 1)")
    Call GuardBoxAllocation(State, Block, Prologue)
    Call AddLine(State, "  store ptr " & Block & ", ptr " & Slot)
    If Len(Address) = 0 Then Address = ValueName(State)
    Call AddLine(State, "  " & Address & " = getelementptr i64, ptr " & Block & ", i64 3")
    If ContainsArray Then Call InitializeEmptyArray(State, Address)
    AllocateBox = Address
End Function

' Keeps original fixed bounds while giving an escaping array an independently retained payload.
Private Sub InitializeOwnedArray(ByRef Bound As BoundProject, ByRef State As EmissionState, ByVal Symbol As Long, ByVal Address As String, ByVal Prologue As Boolean)
    Dim Block As String, Count As String
    If Not Bound.Symbols(Symbol).HasBounds Then
        Call AddLine(State, "  call void @ube.array.clear(ptr %ctx, ptr " & Address & ")")
        Exit Sub
    End If
    Count = CStr(Bound.Symbols(Symbol).UpperBound - Bound.Symbols(Symbol).LowerBound + CDec(1))
    Block = ValueName(State)
    Call AddLine(State, "  " & Block & " = call ptr @ube.memory.new(ptr %ctx, i64 " & Count & ", i64 " & CStr(Bound.Symbols(Symbol).ElementCells) & ")")
    Call GuardBoxAllocation(State, Block, Prologue)
    Call AddLine(State, "  call void @ube.array.install(ptr %ctx, ptr " & Address & ", ptr " & Block & ", i64 " & CStr(Bound.Symbols(Symbol).LowerBound) & ", i64 " & CStr(Bound.Symbols(Symbol).UpperBound) & ")")
End Sub

' Reuses the captured owner identity without reevaluating an lvalue or its index.
Private Function ArgumentOwner(ByRef Bound As BoundProject, ByRef State As EmissionState, ByVal Node As Long) As String
    Dim Identity As Long, Slot As String, Result As String
    Identity = State.Escapes(Node - 1).OwnerIdentity
    Select Case State.Escapes(Node - 1).OwnerKind
    Case NativeEscapes.ProgramOwner
        ArgumentOwner = "null": Exit Function
    Case NativeEscapes.SymbolOwner
        If OwnerParameter(Bound, State, Identity) Then ArgumentOwner = "%owner.arg." & CStr(Identity): Exit Function
        Slot = "%owner.slot." & CStr(Identity)
    Case NativeEscapes.TemporaryOwner
        Slot = "%owner.temp." & CStr(Identity)
    Case NativeEscapes.PayloadOwner
        Slot = "%pin." & CStr(State.PinSlot(Identity))
    Case Else
        State.Failed = True: State.FailureDetail = "missing argument storage owner": ArgumentOwner = "null": Exit Function
    End Select
    Result = ValueName(State)
    Call AddLine(State, "  " & Result & " = load ptr, ptr " & Slot)
    ArgumentOwner = Result
End Function

' Resolves one storage path while preserving array snapshot ownership.
Private Function EmitAddress(ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As EmissionState, ByVal Node As Long) As String
    Dim Receiver As Long, IndexNode As Long, Symbol As Long
    Dim Base As String, Result As String, IndexValue As String
    Dim Lower As String, Upper As String, Snapshot As String
    Dim Below As String, Above As String, Invalid As String, Relative As String, Offset As String
    Dim Data As String, Block As String
    If Parsed.Nodes(Node).Kind = "group" Then
        EmitAddress = EmitAddress(Parsed, Bound, State, Parsed.Nodes(Node).FirstChild)
        Exit Function
    End If
    If Bound.Nodes(Node).AccessKind = "field" Then
        Receiver = Parsed.Nodes(Node).FirstChild
        Base = EmitAddress(Parsed, Bound, State, Receiver)
        Symbol = Bound.Nodes(Node).SymbolIndex
        Result = ValueName(State)
        Call AddLine(State, "  " & Result & " = getelementptr i64, ptr " & Base & ", i64 " & CStr(Bound.Symbols(Symbol).FieldOffset))
    ElseIf Bound.Nodes(Node).AccessKind = "index" Then
        Receiver = Parsed.Nodes(Node).FirstChild
        IndexNode = Parsed.Nodes(Receiver).NextSibling
        Base = EmitAddress(Parsed, Bound, State, Receiver)
        Snapshot = ValueName(State): Lower = ValueName(State): Upper = ValueName(State)
        Data = ValueName(State): Block = ValueName(State)
        Below = ValueName(State): Above = ValueName(State): Invalid = ValueName(State)
        Call AddLine(State, "  " & Snapshot & " = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr " & Base & ")")
        Call AddLine(State, "  " & Lower & " = extractvalue { i64, i64, ptr, ptr } " & Snapshot & ", 0")
        Call AddLine(State, "  " & Upper & " = extractvalue { i64, i64, ptr, ptr } " & Snapshot & ", 1")
        Call AddLine(State, "  " & Data & " = extractvalue { i64, i64, ptr, ptr } " & Snapshot & ", 2")
        Call AddLine(State, "  " & Block & " = extractvalue { i64, i64, ptr, ptr } " & Snapshot & ", 3")
        Call AddLine(State, "  store ptr " & Block & ", ptr %pin." & CStr(State.PinSlot(Node)))
        ' Receiver identity is captured before index evaluation can resize its descriptor.
        IndexValue = EmitExpression(Parsed, Bound, State, IndexNode)
        IndexValue = ConvertNative(State, IndexValue, Bound.Nodes(IndexNode).TypeName, "LongLong")
        Call AddLine(State, "  " & Below & " = icmp slt i64 " & IndexValue & ", " & Lower)
        Call AddLine(State, "  " & Above & " = icmp sgt i64 " & IndexValue & ", " & Upper)
        Call AddLine(State, "  " & Invalid & " = or i1 " & Below & ", " & Above)
        Call GuardError(State, Invalid, 9)
        Relative = ValueName(State): Offset = ValueName(State): Result = ValueName(State)
        Call AddLine(State, "  " & Relative & " = sub i64 " & IndexValue & ", " & Lower)
        Call AddLine(State, "  " & Offset & " = mul i64 " & Relative & ", " & CStr(Bound.Nodes(Receiver).ElementCells))
        Call AddLine(State, "  " & Result & " = getelementptr i64, ptr " & Data & ", i64 " & Offset)
    Else
        Result = StorageAddress(Bound, State, Bound.Nodes(Node).SymbolIndex)
    End If
    EmitAddress = Result
End Function

' Releases a prepared element borrow once; nulling its slot makes all exit paths idempotent.
Private Sub ReleasePin(ByRef State As EmissionState, ByVal Slot As Long)
    Dim Block As String
    Block = ValueName(State)
    Call AddLine(State, "  " & Block & " = load ptr, ptr %pin." & CStr(Slot))
    Call AddLine(State, "  store ptr null, ptr %pin." & CStr(Slot))
    Call AddLine(State, "  call void @ube.block.drop(ptr %ctx, ptr " & Block & ")")
End Sub

' Ends only the indexed borrows contained in a completed value or call argument tree.
Private Sub ReleaseNodePins(ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As EmissionState, ByVal Node As Long)
    Dim Child As Long
    If Not EmissionWork(State) Then Exit Sub
    If Bound.Nodes(Node).AccessKind = "index" Then Call ReleasePin(State, State.PinSlot(Node))
    Child = Parsed.Nodes(Node).FirstChild
    Do While Child <> 0
        Call ReleaseNodePins(Parsed, Bound, State, Child)
        Child = Parsed.Nodes(Child).NextSibling
    Loop
End Sub

' Clears every pending borrow on statement abandonment, branch, or procedure exit.
Private Sub ReleaseAllPins(ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As EmissionState)
    Dim Node As Long, Collected As String
    For Node = 1 To State.PinCount(State.CurrentSymbol)
        If Not EmissionWork(State) Then Exit Sub
        Call ReleasePin(State, Node)
    Next Node
    Collected = ValueName(State)
    Call AddLine(State, "  " & Collected & " = call i1 @ube.memory.collect(ptr %ctx)")
    Call ReleaseArgumentArrays(Parsed, Bound, State)
End Sub

' Releases private array argument descriptors after a call, or all descriptors on abandonment.
Private Sub ReleaseArgumentArrays(ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As EmissionState, Optional ByVal Node As Long = 0)
    Dim Index As Long, Collected As String
    If State.ArgumentArrayCount(State.CurrentSymbol) = 0 Then Exit Sub
    If Node <> 0 Then
        Call ReleaseArgumentTree(Parsed, Bound, State, Node)
    Else
        Index = State.FirstTemporary(State.CurrentSymbol)
        Do While Index <> 0
            If Not EmissionWork(State) Then Exit Sub
            If BoxedTemporary(State, Index) Then
                Call DropOwnerSlot(State, "%owner.temp." & CStr(Index), Bound.Nodes(Index).ArrayRank <> 0)
            ElseIf Bound.Nodes(Index).ArgumentMode = "value" And Bound.Nodes(Index).ArrayRank <> 0 Then
                Call AddLine(State, "  call void @ube.array.clear(ptr %ctx, ptr %temp." & CStr(Index) & ")")
            End If
            Index = State.NextTemporary(Index)
        Loop
    End If
    Collected = ValueName(State)
    Call AddLine(State, "  " & Collected & " = call i1 @ube.memory.collect(ptr %ctx)")
End Sub

' Visits only one completed call subtree, leaving earlier outer-call snapshots live.
Private Sub ReleaseArgumentTree(ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As EmissionState, ByVal Node As Long)
    Dim Child As Long
    If Not EmissionWork(State) Then Exit Sub
    If BoxedTemporary(State, Node) Then
        Call DropOwnerSlot(State, "%owner.temp." & CStr(Node), Bound.Nodes(Node).ArrayRank <> 0)
    ElseIf Bound.Nodes(Node).ArgumentMode = "value" And Bound.Nodes(Node).ArrayRank <> 0 Then
        Call AddLine(State, "  call void @ube.array.clear(ptr %ctx, ptr %temp." & CStr(Node) & ")")
    End If
    Child = Parsed.Nodes(Node).FirstChild
    Do While Child <> 0
        Call ReleaseArgumentTree(Parsed, Bound, State, Child)
        Child = Parsed.Nodes(Child).NextSibling
    Loop
End Sub

' Releases compiler-owned local array values; borrowed array parameters never lose caller ownership.
Private Sub ReleaseLocalArrays(ByRef Bound As BoundProject, ByRef State As EmissionState)
    Dim Symbol As Long, Collected As String
    If Not State.CountedDepth Then Exit Sub
    Symbol = State.FirstScopeSymbol(State.CurrentSymbol)
    Do While Symbol <> 0
        If Not EmissionWork(State) Then Exit Sub
        If Bound.Symbols(Symbol).ScopeSymbol = State.CurrentSymbol And Bound.Symbols(Symbol).Kind = "variable" And Bound.Symbols(Symbol).ArrayRank = 1 And Not BoxedStorage(Bound, State, Symbol) Then
            Call AddLine(State, "  call void @ube.array.clear(ptr %ctx, ptr %slot." & CStr(Symbol) & ")")
        End If
        Symbol = State.NextScopeSymbol(Symbol)
    Loop
    Collected = ValueName(State)
    Call AddLine(State, "  " & Collected & " = call i1 @ube.memory.collect(ptr %ctx)")
End Sub

' Releases one nullable outer box reference without clearing storage retained by another thread.
Private Sub DropOwnerSlot(ByRef State As EmissionState, ByVal Slot As String, ByVal ContainsArray As Boolean)
    Dim Block As String
    Block = ValueName(State)
    Call AddLine(State, "  " & Block & " = load ptr, ptr " & Slot)
    Call AddLine(State, "  store ptr null, ptr " & Slot)
    Call AddLine(State, "  call void @ube.box.drop(ptr %ctx, ptr " & Block & ", i1 " & IIf(ContainsArray, "true", "false") & ")")
End Sub

' Drops only owners allocated by this activation; parameter owners are borrowed.
Private Sub ReleaseFrameBoxes(ByRef Bound As BoundProject, ByRef State As EmissionState)
    Dim Symbol As Long, Collected As String
    If State.FrameBoxCount(State.CurrentSymbol) = 0 Then Exit Sub
    Symbol = State.FirstScopeSymbol(State.CurrentSymbol)
    Do While Symbol <> 0
        If Not EmissionWork(State) Then Exit Sub
        If BoxedStorage(Bound, State, Symbol) Then Call DropOwnerSlot(State, "%owner.slot." & CStr(Symbol), Bound.Symbols(Symbol).ArrayRank <> 0)
        Symbol = State.NextScopeSymbol(Symbol)
    Loop
    Collected = ValueName(State)
    Call AddLine(State, "  " & Collected & " = call i1 @ube.memory.collect(ptr %ctx)")
End Sub

' Reads a complete value before mutation; volatile bulk cells prevent unavailable libc copy synthesis.
Private Sub SnapshotCells(ByRef State As EmissionState, ByVal Address As String, ByVal Count As Long, ByRef Values() As String)
    Dim Index As Long, Pointer As String
    ReDim Values(0 To Count - 1)
    For Index = 0 To Count - 1
        Pointer = ValueName(State): Values(Index) = ValueName(State)
        Call AddLine(State, "  " & Pointer & " = getelementptr i64, ptr " & Address & ", i64 " & CStr(Index))
        Call AddLine(State, "  " & Values(Index) & " = load atomic volatile i64, ptr " & Pointer & " monotonic, align 8")
    Next Index
End Sub

' Commits a completed independent aggregate snapshot, including known unchanged array bounds.
Private Sub StoreCells(ByRef State As EmissionState, ByVal Address As String, ByRef Values() As String)
    Dim Index As Long, Pointer As String
    For Index = 0 To UBound(Values)
        Pointer = ValueName(State)
        Call AddLine(State, "  " & Pointer & " = getelementptr i64, ptr " & Address & ", i64 " & CStr(Index))
        Call AddLine(State, "  store atomic volatile i64 " & Values(Index) & ", ptr " & Pointer & " monotonic, align 8")
    Next Index
End Sub

' Initializes an unpublished empty descriptor without releasing uninitialized storage.
Private Sub InitializeEmptyArray(ByRef State As EmissionState, ByVal Address As String)
    Dim Pointer As String
    Pointer = ValueName(State)
    Call AddLine(State, "  " & Pointer & " = getelementptr i64, ptr " & Address & ", i64 1")
    Call AddLine(State, "  store atomic i64 0, ptr " & Address & " monotonic, align 8")
    Call AddLine(State, "  store atomic i64 -1, ptr " & Pointer & " monotonic, align 8")
    Pointer = ValueName(State)
    Call AddLine(State, "  " & Pointer & " = getelementptr i64, ptr " & Address & ", i64 2")
    Call AddLine(State, "  store ptr null, ptr " & Pointer)
    Pointer = ValueName(State)
    Call AddLine(State, "  " & Pointer & " = getelementptr i64, ptr " & Address & ", i64 3")
    Call AddLine(State, "  store ptr null, ptr " & Pointer)
End Sub

' Establishes neutral scalar cells and the immutable admitted fixed-array shape.
Private Sub NeutralStorage(ByRef Bound As BoundProject, ByRef State As EmissionState, ByVal Symbol As Long, ByVal Address As String, Optional ByVal HeaderOnly As Boolean = False, Optional ByVal ReleaseExisting As Boolean = True)
    Dim Index As Long, Count As Long, Pointer As String, Value As String, Store As String, Data As String
    Count = Bound.Symbols(Symbol).StorageCells
    If Bound.Symbols(Symbol).ArrayRank = 1 And BoxedStorage(Bound, State, Symbol) Then
        Call InitializeOwnedArray(Bound, State, Symbol, Address, False)
        Exit Sub
    End If
    If Bound.Symbols(Symbol).ArrayRank = 1 Then
        If ReleaseExisting Then Call AddLine(State, "  call void @ube.array.clear(ptr %ctx, ptr " & Address & ")")
        If Not Bound.Symbols(Symbol).HasBounds Then
            Call InitializeEmptyArray(State, Address)
            Exit Sub
        End If
        Pointer = ValueName(State)
        Call AddLine(State, "  " & Pointer & " = getelementptr i64, ptr " & Address & ", i64 1")
        Call AddLine(State, "  store atomic i64 " & CStr(Bound.Symbols(Symbol).LowerBound) & ", ptr " & Address & " monotonic, align 8")
        Call AddLine(State, "  store atomic i64 " & CStr(Bound.Symbols(Symbol).UpperBound) & ", ptr " & Pointer & " monotonic, align 8")
        Data = ValueName(State)
        Call AddLine(State, "  " & Data & " = getelementptr i64, ptr " & Address & ", i64 4")
        Pointer = ValueName(State)
        Call AddLine(State, "  " & Pointer & " = getelementptr i64, ptr " & Address & ", i64 2")
        Call AddLine(State, "  store ptr " & Data & ", ptr " & Pointer)
        Pointer = ValueName(State)
        Call AddLine(State, "  " & Pointer & " = getelementptr i64, ptr " & Address & ", i64 3")
        Call AddLine(State, "  store ptr null, ptr " & Pointer)
        If HeaderOnly Then Exit Sub
        For Index = 4 To Count - 1
            Pointer = ValueName(State)
            Call AddLine(State, "  " & Pointer & " = getelementptr i64, ptr " & Address & ", i64 " & CStr(Index))
            Call AddLine(State, "  store atomic volatile i64 0, ptr " & Pointer & " monotonic, align 8")
        Next Index
        Exit Sub
    End If
    Store = "  store atomic i64 "
    ' Bulk volatile neutralization prevents an optimizer-created dependency on CRT memset.
    If Count > 1 Then Store = "  store atomic volatile i64 "
    For Index = 0 To Count - 1
        Value = "0"
        Pointer = ValueName(State)
        Call AddLine(State, "  " & Pointer & " = getelementptr i64, ptr " & Address & ", i64 " & CStr(Index))
        Call AddLine(State, Store & Value & ", ptr " & Pointer & " monotonic, align 8")
    Next Index
End Sub

' Compares every typed scalar record field, taking the left value before evaluating the right.
Private Function EmitRecordComparison(ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As EmissionState, ByVal Node As Long) As String
    Dim LeftNode As Long, RightNode As Long, Index As Long, Count As Long
    Dim LeftValues() As String, RightValues() As String
    Dim Address As String, Equal As String, Test As String, Combined As String, Result As String
    LeftNode = Parsed.Nodes(Node).FirstChild: RightNode = Parsed.Nodes(LeftNode).NextSibling
    Count = Bound.Nodes(LeftNode).StorageCells
    Address = EmitAddress(Parsed, Bound, State, LeftNode)
    Call SnapshotCells(State, Address, Count, LeftValues)
    Call ReleaseNodePins(Parsed, Bound, State, LeftNode)
    Address = EmitAddress(Parsed, Bound, State, RightNode)
    Call SnapshotCells(State, Address, Count, RightValues)
    Call ReleaseNodePins(Parsed, Bound, State, RightNode)
    Equal = "true"
    For Index = 0 To Count - 1
        Test = ValueName(State): Combined = ValueName(State)
        Call AddLine(State, "  " & Test & " = icmp eq i64 " & LeftValues(Index) & ", " & RightValues(Index))
        Call AddLine(State, "  " & Combined & " = and i1 " & Equal & ", " & Test)
        Equal = Combined
    Next Index
    If Parsed.Nodes(Node).Text = "<>" Then
        Test = ValueName(State)
        Call AddLine(State, "  " & Test & " = xor i1 " & Equal & ", true")
        Equal = Test
    End If
    Result = ValueName(State)
    Call AddLine(State, "  " & Result & " = select i1 " & Equal & ", i64 -1, i64 0")
    EmitRecordComparison = Result
End Function

' Emits one eager arithmetic operation with checked overflow in the selected integer width.
Private Function CheckedArithmetic(ByRef State As EmissionState, ByVal LeftValue As String, ByVal RightValue As String, ByVal TypeName As String, ByVal Operation As String) As String
    Dim Width As String
    Dim LeftOperand As String
    Dim RightOperand As String
    Dim Pair As String
    Dim Overflow As String
    Dim NarrowResult As String
    Dim Result As String
    Width = "i" & CStr(IntegerWidth(TypeName))
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

' Guards division before LLVM can observe a zero divisor or a signed overflow pair.
Private Function CheckedDivision(ByRef State As EmissionState, ByVal LeftValue As String, ByVal RightValue As String, ByVal TypeName As String, ByVal Remainder As Boolean) As String
    Dim Zero As String
    Dim Minimum As String
    Dim NegativeOne As String
    Dim Overflow As String
    Dim Divisor As String
    Dim Result As String
    Dim Operation As String
    Zero = ValueName(State)
    Call AddLine(State, "  " & Zero & " = icmp eq i64 " & RightValue & ", 0")
    Call GuardError(State, Zero, 11)
    Minimum = ValueName(State)
    NegativeOne = ValueName(State)
    Overflow = ValueName(State)
    Call AddLine(State, "  " & Minimum & " = icmp eq i64 " & LeftValue & ", " & IntegerMinimumText(TypeName))
    Call AddLine(State, "  " & NegativeOne & " = icmp eq i64 " & RightValue & ", -1")
    Call AddLine(State, "  " & Overflow & " = and i1 " & Minimum & ", " & NegativeOne)
    Divisor = RightValue
    Operation = "sdiv"
    If Remainder Then
        Operation = "srem"
        Divisor = ValueName(State)
        Call AddLine(State, "  " & Divisor & " = select i1 " & Overflow & ", i64 1, i64 " & RightValue)
    Else
        Call GuardError(State, Overflow, 6)
    End If
    Result = ValueName(State)
    Call AddLine(State, "  " & Result & " = " & Operation & " i64 " & LeftValue & ", " & Divisor)
    CheckedDivision = Result
End Function

' Complements a logical value or the exact bound integral width, retaining canonical cell extension.
Private Function ComplementNative(ByRef State As EmissionState, ByVal Value As String, ByVal TypeName As String) As String
    Dim Width As Long
    Dim Operand As String
    Dim Complement As String
    Dim Result As String
    Dim Extension As String
    Width = IntegerWidth(TypeName)
    If TypeName = "Boolean" Or Width = 64 Then
        Result = ValueName(State)
        Call AddLine(State, "  " & Result & " = xor i64 " & Value & ", -1")
    Else
        Operand = ValueName(State)
        Complement = ValueName(State)
        Result = ValueName(State)
        Call AddLine(State, "  " & Operand & " = trunc i64 " & Value & " to i" & CStr(Width))
        Call AddLine(State, "  " & Complement & " = xor i" & CStr(Width) & " " & Operand & ", -1")
        Extension = "sext"
        If TypeName = "Byte" Then Extension = "zext"
        Call AddLine(State, "  " & Result & " = " & Extension & " i" & CStr(Width) & " " & Complement & " to i64")
    End If
    ComplementNative = Result
End Function

' Emits source-order argument preparation and dispatches only already-bound trusted identities.
' Copies an aggregate argument before evaluating later arguments; the caller retains cleanup ownership.
Private Function PrepareAggregateArgument(ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As EmissionState, ByVal Node As Long) As String
    Dim Source As String, Destination As String, Copied As String
    Dim Values() As String
    Source = EmitAddress(Parsed, Bound, State, Node)
    Destination = "%temp." & CStr(Node)
    If BoxedTemporary(State, Node) Then
        If Bound.Nodes(Node).ArrayRank <> 0 Then
            Destination = AllocateBox(State, "%owner.temp." & CStr(Node), 4, True, False)
        Else
            Destination = AllocateBox(State, "%owner.temp." & CStr(Node), Bound.Nodes(Node).StorageCells, False, False)
        End If
    End If
    If Bound.Nodes(Node).ArrayRank <> 0 Then
        Copied = ValueName(State)
        Call AddLine(State, "  " & Copied & " = call i1 @ube.array.trycopy(ptr %ctx, ptr " & Destination & ", ptr " & Source & ", i64 " & CStr(Bound.Nodes(Node).ElementCells) & ")")
        Call GuardStatus(State, Copied)
    Else
        Call SnapshotCells(State, Source, Bound.Nodes(Node).StorageCells, Values)
        Call StoreCells(State, Destination, Values)
    End If
    PrepareAggregateArgument = Destination
End Function

' Evaluates arguments in written order and releases caller-owned snapshots before guarding fresh status.
Private Function ArgumentType(ByRef Bound As BoundProject, ByVal Node As Long) As String
    ArgumentType = "i64"
    If Bound.Nodes(Node).ArgumentMode <> "value" Or Bound.Nodes(Node).ArrayRank <> 0 Or Bound.Nodes(Node).TypeSymbol <> 0 Then ArgumentType = "ptr"
End Function

' Uses the ordinary value/alias/temporary rules for synchronous and asynchronous calls.
Private Sub PrepareArgument(ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As EmissionState, ByVal Argument As Long, ByRef Value As String)
    Dim Address As String
    If Bound.Nodes(Argument).ArgumentMode = "alias" Then
        Value = EmitAddress(Parsed, Bound, State, Argument)
    ElseIf Bound.Nodes(Argument).ArgumentMode = "value" And (Bound.Nodes(Argument).ArrayRank <> 0 Or Bound.Nodes(Argument).TypeSymbol <> 0) Then
        Value = PrepareAggregateArgument(Parsed, Bound, State, Argument)
    Else
        Value = EmitExpression(Parsed, Bound, State, Argument)
        Value = ConvertNative(State, Value, Bound.Nodes(Argument).TypeName, Bound.Nodes(Argument).ConvertedType)
        If Bound.Nodes(Argument).ArgumentMode = "temp" Then
            Address = "%temp." & CStr(Argument)
            If BoxedTemporary(State, Argument) Then Address = AllocateBox(State, "%owner.temp." & CStr(Argument), 1, False, False)
            Call AddLine(State, "  store atomic i64 " & Value & ", ptr " & Address & " monotonic, align 8")
            Value = Address
        End If
    End If
End Sub

' Releases only the capture's references, preserving caller-owned references until ordinary cleanup.
Private Sub DropCaptureOwners(ByRef Bound As BoundProject, ByRef State As EmissionState, ByRef Arguments() As Long, ByRef Owners() As String, ByVal Count As Long)
    Dim Index As Long
    For Index = 0 To Count - 1
        Call AddLine(State, "  call void @ube.box.drop(ptr %ctx, ptr " & Owners(Index) & ", i1 " & IIf(Bound.Nodes(Arguments(Index)).ArrayRank <> 0, "true", "false") & ")")
    Next Index
End Sub

' Publishes a complete typed capture only after every ordinary argument has been prepared.
Private Function EmitThreadStart(ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As EmissionState, ByVal Node As Long) As String
    Dim Values() As String, Owners() As String, Actuals() As Long
    Dim Symbol As Long, Argument As Long, Count As Long, Index As Long, Cells As Long
    Dim Capsule As String, Payload As String, Address As String, Pair As String, Success As String
    Dim Failed As String, Ready As String, SavedError As String, Collected As String, Result As String
    Symbol = Bound.Nodes(Node).SymbolIndex
    Count = Bound.Symbols(Symbol).ParameterCount
    ReDim Values(0 To Count): ReDim Owners(0 To Count): ReDim Actuals(0 To Count)
    Argument = Parsed.Nodes(Parsed.Nodes(Node).FirstChild).NextSibling
    Do While Argument <> 0
        Actuals(Index) = Argument
        Call PrepareArgument(Parsed, Bound, State, Argument, Values(Index))
        Owners(Index) = "null"
        If State.Escapes(Argument - 1).NeedsOwner Then Owners(Index) = ArgumentOwner(Bound, State, Argument)
        Index = Index + 1
        Argument = Parsed.Nodes(Argument).NextSibling
    Loop
    Cells = Count * 2: If Cells = 0 Then Cells = 1
    Capsule = ValueName(State)
    Call AddLine(State, "  " & Capsule & " = call ptr @ube.memory.new(ptr %ctx, i64 " & CStr(Cells) & ", i64 1)")
    Call GuardBoxAllocation(State, Capsule, False)
    Payload = ValueName(State)
    Call AddLine(State, "  " & Payload & " = getelementptr i64, ptr " & Capsule & ", i64 3")
    For Index = 0 To Count - 1
        Address = ValueName(State)
        Call AddLine(State, "  " & Address & " = getelementptr i64, ptr " & Payload & ", i64 " & CStr(Index * 2))
        Call AddLine(State, "  store " & ArgumentType(Bound, Actuals(Index)) & " " & Values(Index) & ", ptr " & Address)
        Address = ValueName(State)
        Call AddLine(State, "  " & Address & " = getelementptr i64, ptr " & Payload & ", i64 " & CStr(Index * 2 + 1))
        Call AddLine(State, "  call void @ube.block.retain(ptr " & Owners(Index) & ")")
        Call AddLine(State, "  store ptr " & Owners(Index) & ", ptr " & Address)
    Next Index
    Pair = ValueName(State): Success = ValueName(State)
    Failed = BlockName(State, "thread.failed"): Ready = BlockName(State, "thread.ready")
    Call AddLine(State, "  " & Pair & " = call { i1, i64 } @ube.thread.start(ptr %ctx, ptr @ube.thread.call." & CStr(Node) & ", ptr " & Capsule & ")")
    Call AddLine(State, "  " & Success & " = extractvalue { i1, i64 } " & Pair & ", 0")
    Call AddLine(State, "  br i1 " & Success & ", label %" & Ready & ", label %" & Failed)
    Call AddLine(State, Failed & ":")
    SavedError = ValueName(State)
    Call AddLine(State, "  " & SavedError & " = load atomic i64, ptr %err monotonic, align 8")
    Call DropCaptureOwners(Bound, State, Actuals, Owners, Count)
    Call AddLine(State, "  call void @ube.block.drop(ptr %ctx, ptr " & Capsule & ")")
    Collected = ValueName(State)
    Call AddLine(State, "  " & Collected & " = call i1 @ube.memory.collect(ptr %ctx)")
    Call AddLine(State, "  store atomic i64 " & SavedError & ", ptr %err monotonic, align 8")
    Call AddLine(State, "  br label %" & Ready)
    Call AddLine(State, Ready & ":")
    Call ReleaseNodePins(Parsed, Bound, State, Node)
    Call ReleaseArgumentArrays(Parsed, Bound, State, Node)
    Call GuardCall(State, Pair)
    Result = ValueName(State)
    Call AddLine(State, "  " & Result & " = extractvalue { i1, i64 } " & Pair & ", 1")
    EmitThreadStart = Result
End Function

' Dispatches already-bound ordinary calls or a distinct thread-start operation.
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
    Dim Parameter As Long
    If Parsed.Nodes(Node).Kind = "thread-start" Then EmitCall = EmitThreadStart(Parsed, Bound, State, Node): Exit Function
    Symbol = Bound.Nodes(Node).SymbolIndex
    Callee = Parsed.Nodes(Node).FirstChild
    Argument = Parsed.Nodes(Callee).NextSibling
    Arguments = "ptr %ctx"
    Role = Bound.Symbols(Symbol).BindingId
    Parameter = Bound.Symbols(Symbol).FirstParameter
    Do While Argument <> 0
        Call PrepareArgument(Parsed, Bound, State, Argument, Value)
        Arguments = Arguments & ", " & ArgumentType(Bound, Argument) & " " & Value
        If Parameter <> 0 Then
            If OwnerParameter(Bound, State, Parameter) Then Arguments = Arguments & ", ptr " & ArgumentOwner(Bound, State, Argument)
            Parameter = Bound.Symbols(Parameter).NextParameter
        End If
        Argument = Parsed.Nodes(Argument).NextSibling
    Loop
    If Role = "error.raise" Then
        Call AddLine(State, "  store atomic i64 " & Value & ", ptr %err monotonic, align 8")
        Call AddLine(State, "  br label %return.fail")
        Terminated = True
        EmitCall = "0"
        Exit Function
    ElseIf Role = "error.clear" Then
        Call AddLine(State, "  store atomic i64 0, ptr %err monotonic, align 8")
        EmitCall = "0"
        Exit Function
    End If
    Call EnsureModule(State, Bound.Symbols(Symbol).ModuleIndex)
    Pair = ValueName(State)
    Call AddLine(State, "  " & Pair & " = call { i1, i64 } @ube.proc." & CStr(Symbol) & "(" & Arguments & ")")
    Call ReleaseNodePins(Parsed, Bound, State, Node)
    Call ReleaseArgumentArrays(Parsed, Bound, State, Node)
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
    If Bound.Nodes(Node).AccessKind = "index" Or Bound.Nodes(Node).AccessKind = "field" Then
        Address = EmitAddress(Parsed, Bound, State, Node)
        Result = ValueName(State)
        Call AddLine(State, "  " & Result & " = load atomic i64, ptr " & Address & " monotonic, align 8")
        Call ReleaseNodePins(Parsed, Bound, State, Node)
        EmitExpression = Result
        Exit Function
    End If
    Kind = Parsed.Nodes(Node).Kind
    Select Case Kind
    Case "name", "member"
        Symbol = Bound.Nodes(Node).SymbolIndex
        Result = ValueName(State)
        If Bound.Symbols(Symbol).BindingId = "error.number" Then
            Call AddLine(State, "  " & Result & " = load atomic i64, ptr %err monotonic, align 8")
        Else
            Address = StorageAddress(Bound, State, Symbol)
            Call AddLine(State, "  " & Result & " = load atomic i64, ptr " & Address & " monotonic, align 8")
        End If
    Case "group"
        Result = EmitExpression(Parsed, Bound, State, Parsed.Nodes(Node).FirstChild)
    Case "unary"
        Child = Parsed.Nodes(Node).FirstChild
        LeftValue = EmitExpression(Parsed, Bound, State, Child)
        LeftValue = ConvertNative(State, LeftValue, Bound.Nodes(Child).TypeName, Bound.Nodes(Child).ConvertedType)
        If Parsed.Nodes(Node).Text = "-" Then
            Result = CheckedArithmetic(State, "0", LeftValue, Bound.Nodes(Node).TypeName, "ssub")
        ElseIf Parsed.Nodes(Node).Text = "not" Then
            Result = ComplementNative(State, LeftValue, Bound.Nodes(Node).TypeName)
        Else
            Result = LeftValue
        End If
    Case "call", "thread-start"
        Result = EmitCall(Parsed, Bound, State, Node, Terminated)
    Case "binary"
        Child = Parsed.Nodes(Node).FirstChild
        If Bound.Nodes(Child).TypeSymbol <> 0 Then
            EmitExpression = EmitRecordComparison(Parsed, Bound, State, Node)
            Exit Function
        End If
        RightNode = Parsed.Nodes(Child).NextSibling
        LeftValue = EmitExpression(Parsed, Bound, State, Child)
        LeftValue = ConvertNative(State, LeftValue, Bound.Nodes(Child).TypeName, Bound.Nodes(Child).ConvertedType)
        RightValue = EmitExpression(Parsed, Bound, State, RightNode)
        RightValue = ConvertNative(State, RightValue, Bound.Nodes(RightNode).TypeName, Bound.Nodes(RightNode).ConvertedType)
        If Parsed.Nodes(Node).Text = "+" Then
            Result = CheckedArithmetic(State, LeftValue, RightValue, Bound.Nodes(Node).TypeName, "sadd")
        ElseIf Parsed.Nodes(Node).Text = "-" Then
            Result = CheckedArithmetic(State, LeftValue, RightValue, Bound.Nodes(Node).TypeName, "ssub")
        ElseIf Parsed.Nodes(Node).Text = "*" Then
            Result = CheckedArithmetic(State, LeftValue, RightValue, Bound.Nodes(Node).TypeName, "smul")
        ElseIf Parsed.Nodes(Node).Text = "\" Or Parsed.Nodes(Node).Text = "mod" Then
            Result = CheckedDivision(State, LeftValue, RightValue, Bound.Nodes(Node).TypeName, Parsed.Nodes(Node).Text = "mod")
        ElseIf Parsed.Nodes(Node).Text = "and" Or Parsed.Nodes(Node).Text = "or" Then
            Result = ValueName(State)
            ' Canonical signed extension makes i64 And equal the selected integral-width result.
            Call AddLine(State, "  " & Result & " = " & Parsed.Nodes(Node).Text & " i64 " & LeftValue & ", " & RightValue)
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

' Emits a loop with statement-local body failures and whole-construct condition-failure continuation.
Private Sub EmitLoop(ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As EmissionState, ByVal Node As Long, ByVal Continuation As String)
    Dim Condition As Long
    Dim Body As Long
    Dim Header As String
    Dim BodyEntry As String
    Dim PreviousExit As String
    Dim Value As String
    Dim Test As String
    Dim Predicate As String
    Dim Mode As String
    Mode = Parsed.Nodes(Node).Text
    Body = Parsed.Nodes(Node).FirstChild
    If Mode <> "always" Then
        Condition = Body
        Body = Parsed.Nodes(Condition).NextSibling
    End If
    Header = BlockName(State, "loop.condition")
    BodyEntry = SequenceEntry(Parsed, Body, Header)
    PreviousExit = State.LoopExit
    State.LoopExit = Continuation
    If Left$(Mode, 4) = "pre-" Then
        Call AddLine(State, "  br label %" & Header)
    Else
        Call AddLine(State, "  br label %" & BodyEntry)
    End If
    Call EmitSequence(Parsed, Bound, State, Body, Header)
    Call AddLine(State, Header & ":")
    ' Each iteration restores the header's failure identity after body statements have changed it.
    State.CurrentNode = Node
    State.ErrorNode = Node
    State.CurrentNext = Continuation
    Call AddLine(State, "  store i32 " & CStr(Node) & ", ptr %failure.site")
    If Condition <> 0 Then
        Value = EmitExpression(Parsed, Bound, State, Condition)
        Test = ValueName(State)
        Predicate = "ne"
        If Right$(Mode, 5) = "until" Then Predicate = "eq"
        Call AddLine(State, "  " & Test & " = icmp " & Predicate & " i64 " & Value & ", 0")
        Call ReleaseAllPins(Parsed, Bound, State)
        Call AddLine(State, "  br i1 " & Test & ", label %" & BodyEntry & ", label %" & Continuation)
    Else
        Call AddLine(State, "  br label %" & BodyEntry)
    End If
    State.LoopExit = PreviousExit
End Sub

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
    Dim Values() As String
    Dim SourceAddress As String
    Dim Cells As Long
    Dim Aggregate As Boolean
    Dim ArrayRank As Long
    Dim Stride As Long
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
            ValueNode = DeclarationValueNode(Parsed, Node)
            Address = StorageAddress(Bound, State, Symbol)
            Call NeutralStorage(Bound, State, Symbol, Address)
            Aggregate = Bound.Symbols(Symbol).ArrayRank <> 0 Or Bound.Symbols(Symbol).TypeSymbol <> 0
            Cells = Bound.Symbols(Symbol).StorageCells
            ArrayRank = Bound.Symbols(Symbol).ArrayRank
            Stride = Bound.Symbols(Symbol).ElementCells
        Else
            Child = Parsed.Nodes(Node).FirstChild
            ValueNode = Parsed.Nodes(Child).NextSibling
            Symbol = Bound.Nodes(Child).SymbolIndex
            Address = EmitAddress(Parsed, Bound, State, Child)
            Aggregate = Bound.Nodes(Child).ArrayRank <> 0 Or Bound.Nodes(Child).TypeSymbol <> 0
            Cells = Bound.Nodes(Child).StorageCells
            ArrayRank = Bound.Nodes(Child).ArrayRank
            Stride = Bound.Nodes(Child).ElementCells
        End If
        If ValueNode <> 0 Then
            If Aggregate Then
                SourceAddress = EmitAddress(Parsed, Bound, State, ValueNode)
                If ArrayRank = 1 Then
                    Test = ValueName(State)
                    Call AddLine(State, "  " & Test & " = call i1 @ube.array.trycopy(ptr %ctx, ptr " & Address & ", ptr " & SourceAddress & ", i64 " & CStr(Stride) & ")")
                    Call GuardStatus(State, Test)
                Else
                    Call SnapshotCells(State, SourceAddress, Cells, Values)
                    Call StoreCells(State, Address, Values)
                End If
                Call ReleaseNodePins(Parsed, Bound, State, ValueNode)
            Else
                Value = EmitExpression(Parsed, Bound, State, ValueNode)
                If Kind = "variable" Then
                    Value = ConvertNative(State, Value, Bound.Nodes(ValueNode).TypeName, Bound.Symbols(Symbol).TypeName)
                Else
                    Value = ConvertNative(State, Value, Bound.Nodes(ValueNode).TypeName, Bound.Nodes(Child).TypeName)
                End If
                Call AddLine(State, "  store atomic i64 " & Value & ", ptr " & Address & " monotonic, align 8")
            End If
        End If
    Case "call", "thread-start"
        Value = EmitCall(Parsed, Bound, State, Node, Terminated)
    Case "goto"
        Call ReleaseAllPins(Parsed, Bound, State)
        Call AddLine(State, "  br label %" & StatementLabel(Bound.Symbols(Bound.Nodes(Node).SymbolIndex).DeclarationNode))
        Terminated = True
    Case "exit"
        If Parsed.Nodes(Node).Text = "do" Then
            Call ReleaseAllPins(Parsed, Bound, State)
            Call AddLine(State, "  br label %" & State.LoopExit)
        Else
            Call AddLine(State, "  br label %return.ok")
        End If
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
        Call ReleaseAllPins(Parsed, Bound, State)
        Call AddLine(State, "  br i1 " & Test & ", label %" & SequenceEntry(Parsed, ThenNode, Continuation) & ", label %" & SequenceEntry(Parsed, ElseNode, Continuation))
        Call EmitSequence(Parsed, Bound, State, ThenNode, Continuation)
        If ElseNode <> 0 Then Call EmitSequence(Parsed, Bound, State, ElseNode, Continuation)
        Terminated = True
    Case "do"
        Call EmitLoop(Parsed, Bound, State, Node, Continuation)
        Terminated = True
    Case "constant", "label"
        ' Constants have no runtime storage; a label remains an actual branch target.
    End Select
    If Not Terminated Then
        Call ReleaseAllPins(Parsed, Bound, State)
        Call AddLine(State, "  br label %" & Continuation)
    End If
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
    Call ReleaseAllPins(Parsed, Bound, State)
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
    Index = State.FirstScopeSymbol(State.CurrentSymbol)
    Do While Index <> 0
        If Not EmissionWork(State) Then Exit Sub
        If Bound.Symbols(Index).Kind = "label" And Bound.Symbols(Index).ScopeSymbol = State.CurrentSymbol Then
            Call AddLine(State, "    i32 " & CStr(Index) & ", label %" & StatementLabel(Bound.Symbols(Index).DeclarationNode))
        End If
        Index = State.NextScopeSymbol(Index)
    Loop
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
    Dim Address As String
    Dim Cells As Long
    State.ResultSymbol = 0
    Call AddLine(State, "  %handler.target = alloca i32, align 4")
    Call AddLine(State, "  %handler.active = alloca i1, align 1")
    Call AddLine(State, "  %failure.site = alloca i32, align 4")
    Call AddLine(State, "  %handler.resume = alloca i32, align 4")
    Call AddLine(State, "  store i32 0, ptr %handler.target")
    Call AddLine(State, "  store i1 false, ptr %handler.active")
    Call AddLine(State, "  store i32 0, ptr %failure.site")
    Call AddLine(State, "  store i32 0, ptr %handler.resume")
    Index = State.FirstScopeSymbol(State.CurrentSymbol)
    Do While Index <> 0
        If Not EmissionWork(State) Then Exit Sub
        If Bound.Symbols(Index).ScopeSymbol = State.CurrentSymbol Then
            Kind = Bound.Symbols(Index).Kind
            If Kind = "result" Then State.ResultSymbol = Index
            If Kind = "variable" Or Kind = "result" Or (Kind = "parameter" And Bound.Symbols(Index).PassingMode = "ByVal" And Bound.Symbols(Index).ArrayRank = 0 And Bound.Symbols(Index).TypeSymbol = 0) Then
                If State.FieldIndex(Index) < 0 Then
                    If BoxedStorage(Bound, State, Index) Then
                        Call AddLine(State, "  %owner.slot." & CStr(Index) & " = alloca ptr, align 8")
                        Call AddLine(State, "  store ptr null, ptr %owner.slot." & CStr(Index))
                    Else
                        Call AddLine(State, "  %slot." & CStr(Index) & " = alloca [" & CStr(Bound.Symbols(Index).StorageCells) & " x i64], align 8")
                        If Kind = "parameter" Then
                            Call AddLine(State, "  store atomic i64 %arg." & CStr(Index) & ", ptr %slot." & CStr(Index) & " monotonic, align 8")
                        Else
                            Call NeutralStorage(Bound, State, Index, "%slot." & CStr(Index), False, False)
                        End If
                    End If
                ElseIf Bound.Symbols(Index).ArrayRank = 1 Then
                    Address = StorageAddress(Bound, State, Index)
                    Call NeutralStorage(Bound, State, Index, Address, True, False)
                End If
            End If
        End If
        Index = State.NextScopeSymbol(Index)
    Loop
    Index = State.FirstTemporary(State.CurrentSymbol)
    Do While Index <> 0
        If Not EmissionWork(State) Then Exit Sub
        If BoxedTemporary(State, Index) Then
            Call AddLine(State, "  %owner.temp." & CStr(Index) & " = alloca ptr, align 8")
            Call AddLine(State, "  store ptr null, ptr %owner.temp." & CStr(Index))
        ElseIf Bound.Nodes(Index).ScopeSymbol = State.CurrentSymbol And Bound.Nodes(Index).ArgumentMode = "temp" Then
            Call AddLine(State, "  %temp." & CStr(Index) & " = alloca i64, align 8")
        ElseIf Bound.Nodes(Index).ScopeSymbol = State.CurrentSymbol And Bound.Nodes(Index).ArgumentMode = "value" Then
            Cells = Bound.Nodes(Index).StorageCells
            If Bound.Nodes(Index).ArrayRank <> 0 Then Cells = 4
            Call AddLine(State, "  %temp." & CStr(Index) & " = alloca [" & CStr(Cells) & " x i64], align 8")
            If Bound.Nodes(Index).ArrayRank <> 0 Then Call InitializeEmptyArray(State, "%temp." & CStr(Index))
        End If
        Index = State.NextTemporary(Index)
    Loop
    For Index = 1 To State.PinCount(State.CurrentSymbol)
        Call AddLine(State, "  %pin." & CStr(Index) & " = alloca ptr, align 8")
        Call AddLine(State, "  store ptr null, ptr %pin." & CStr(Index))
    Next Index
End Sub

' Allocates promoted locals only after the call-depth guard has succeeded.
Private Sub EmitFrameBoxes(ByRef Bound As BoundProject, ByRef State As EmissionState)
    Dim Symbol As Long, Cells As Long, Address As String
    If State.FrameBoxCount(State.CurrentSymbol) = 0 Then Exit Sub
    Symbol = State.FirstScopeSymbol(State.CurrentSymbol)
    Do While Symbol <> 0
        If Not EmissionWork(State) Then Exit Sub
        If BoxedStorage(Bound, State, Symbol) Then
            Cells = Bound.Symbols(Symbol).StorageCells
            If Bound.Symbols(Symbol).ArrayRank <> 0 Then Cells = 4
            Address = AllocateBox(State, "%owner.slot." & CStr(Symbol), Cells, Bound.Symbols(Symbol).ArrayRank <> 0, True, "%slot." & CStr(Symbol))
            If Bound.Symbols(Symbol).ArrayRank <> 0 Then
                Call InitializeOwnedArray(Bound, State, Symbol, Address, True)
            ElseIf Bound.Symbols(Symbol).Kind = "parameter" Then
                Call AddLine(State, "  store atomic i64 %arg." & CStr(Symbol) & ", ptr " & Address & " monotonic, align 8")
            End If
        End If
        Symbol = State.NextScopeSymbol(Symbol)
    Loop
End Sub

' Emits balanced depth accounting and success/failure returns without clearing Err.
Private Sub EmitReturns(ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As EmissionState)
    Dim Value As String
    Dim Result As String
    Dim Depth As String
    Dim Reduced As String
    Call AddLine(State, "return.ok:")
    Call ReleaseAllPins(Parsed, Bound, State)
    Call ReleaseLocalArrays(Bound, State)
    If State.CountedDepth Then
        Depth = ValueName(State)
        Reduced = ValueName(State)
        Call AddLine(State, "  " & Depth & " = load atomic i64, ptr %depth.ptr monotonic, align 8")
        Call AddLine(State, "  " & Reduced & " = sub i64 " & Depth & ", 1")
        Call AddLine(State, "  store atomic i64 " & Reduced & ", ptr %depth.ptr monotonic, align 8")
    End If
    Value = "0"
    If State.ResultSymbol <> 0 Then
        Value = ValueName(State)
        Call AddLine(State, "  " & Value & " = load atomic i64, ptr %slot." & CStr(State.ResultSymbol) & " monotonic, align 8")
    End If
    Call ReleaseFrameBoxes(Bound, State)
    Result = ValueName(State)
    Call AddLine(State, "  " & Result & " = insertvalue { i1, i64 } { i1 true, i64 0 }, i64 " & Value & ", 1")
    Call AddLine(State, "  ret { i1, i64 } " & Result)
    Call AddLine(State, "return.fail:")
    Call ReleaseAllPins(Parsed, Bound, State)
    Call ReleaseLocalArrays(Bound, State)
    Call ReleaseFrameBoxes(Bound, State)
    If State.CountedDepth Then
        Depth = ValueName(State)
        Reduced = ValueName(State)
        Call AddLine(State, "  " & Depth & " = load atomic i64, ptr %depth.ptr monotonic, align 8")
        Call AddLine(State, "  " & Reduced & " = sub i64 " & Depth & ", 1")
        Call AddLine(State, "  store atomic i64 " & Reduced & ", ptr %depth.ptr monotonic, align 8")
    End If
    Call AddLine(State, "  ret { i1, i64 } { i1 false, i64 0 }")
    Call AddLine(State, "}")
    Call AddLine(State, "")
End Sub

' Emits bounded pointer-free allocation ownership and target adapters without source-name magic.
Private Sub EmitMemoryRuntime(ByRef State As EmissionState)
    Call AddLine(State, "%ube.block = type { ptr, i64, i64 }")
    Call AddLine(State, "define internal i1 @ube.array.descriptor.overlaps(ptr %array, ptr %output) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %start = ptrtoint ptr %array to i64")
    Call AddLine(State, "  %address = ptrtoint ptr %output to i64")
    Call AddLine(State, "  %distance = sub i64 %address, %start")
    Call AddLine(State, "  %inside = icmp ult i64 %distance, 32")
    Call AddLine(State, "  %before = sub i64 %start, %address")
    Call AddLine(State, "  %crosses = icmp ult i64 %before, 8")
    Call AddLine(State, "  %intersects = or i1 %inside, %crosses")
    Call AddLine(State, "  %exists = icmp ne ptr %array, null")
    Call AddLine(State, "  %overlaps = and i1 %intersects, %exists")
    Call AddLine(State, "  ret i1 %overlaps")
    Call AddLine(State, "}")
    Call AddLine(State, "define internal ptr @ube.thread.program(ptr %ctx) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %address = getelementptr %ube.thread, ptr %ctx, i32 0, i32 2")
    Call AddLine(State, "  %program = load ptr, ptr %address")
    Call AddLine(State, "  ret ptr %program")
    Call AddLine(State, "}")
    Call AddLine(State, "define void @ube.thread.init(ptr %ctx, ptr %program, ptr %control) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %err = getelementptr %ube.thread, ptr %ctx, i32 0, i32 0")
    Call AddLine(State, "  %depth = getelementptr %ube.thread, ptr %ctx, i32 0, i32 1")
    Call AddLine(State, "  %owner = getelementptr %ube.thread, ptr %ctx, i32 0, i32 2")
    Call AddLine(State, "  %state = getelementptr %ube.thread, ptr %ctx, i32 0, i32 3")
    Call AddLine(State, "  store atomic i64 0, ptr %err monotonic, align 8")
    Call AddLine(State, "  store atomic i64 0, ptr %depth monotonic, align 8")
    Call AddLine(State, "  store ptr %program, ptr %owner")
    Call AddLine(State, "  store ptr %control, ptr %state")
    Call AddLine(State, "  ret void")
    Call AddLine(State, "}")
    Call AddLine(State, "define internal ptr @ube.module.state(ptr %ctx, i64 %index) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %program = call ptr @ube.thread.program(ptr %ctx)")
    Call AddLine(State, "  %address = getelementptr %ube.program, ptr %program, i32 0, i32 0, i64 %index")
    Call AddLine(State, "  ret ptr %address")
    Call AddLine(State, "}")
    Call AddLine(State, "")
    Call AddLine(State, "define internal ptr @ube.storage.address(ptr %ctx, i64 %index) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %program = call ptr @ube.thread.program(ptr %ctx)")
    Call AddLine(State, "  %address = getelementptr %ube.program, ptr %program, i32 0, i32 1, i64 %index")
    Call AddLine(State, "  ret ptr %address")
    Call AddLine(State, "}")
    Call AddLine(State, "")
    Call AddLine(State, "define internal ptr @ube.resource.slot(ptr %ctx, i64 %index) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %program = call ptr @ube.thread.program(ptr %ctx)")
    Call AddLine(State, "  %address = getelementptr %ube.program, ptr %program, i32 0, i32 5, i64 %index")
    Call AddLine(State, "  ret ptr %address")
    Call AddLine(State, "}")
    Call AddLine(State, "")
    Call AddLine(State, "define internal ptr @ube.module.owner(ptr %ctx, i64 %index) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %program = call ptr @ube.thread.program(ptr %ctx)")
    Call AddLine(State, "  %address = getelementptr %ube.program, ptr %program, i32 0, i32 9, i64 %index")
    Call AddLine(State, "  ret ptr %address")
    Call AddLine(State, "}")
    Call AddLine(State, "")
    Call AddLine(State, "define internal ptr @ube.memory.head(ptr %ctx) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %program = call ptr @ube.thread.program(ptr %ctx)")
    Call AddLine(State, "  %address = getelementptr %ube.program, ptr %program, i32 0, i32 2")
    Call AddLine(State, "  ret ptr %address")
    Call AddLine(State, "}")
    Call AddLine(State, "")
    Call AddLine(State, "define internal ptr @ube.memory.bytes(ptr %ctx) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %program = call ptr @ube.thread.program(ptr %ctx)")
    Call AddLine(State, "  %address = getelementptr %ube.program, ptr %program, i32 0, i32 3")
    Call AddLine(State, "  ret ptr %address")
    Call AddLine(State, "}")
    Call AddLine(State, "")
    Call AddLine(State, "define internal ptr @ube.memory.count(ptr %ctx) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %program = call ptr @ube.thread.program(ptr %ctx)")
    Call AddLine(State, "  %address = getelementptr %ube.program, ptr %program, i32 0, i32 4")
    Call AddLine(State, "  ret ptr %address")
    Call AddLine(State, "}")
    Call AddLine(State, "declare dllimport ptr @VirtualAlloc(ptr, i64, i32, i32)")
    Call AddLine(State, "declare dllimport i32 @VirtualFree(ptr, i64, i32)")
    Call AddLine(State, "define ptr @ube.target.allocate(i64 %bytes) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %p = call ptr @VirtualAlloc(ptr null, i64 %bytes, i32 12288, i32 4)")
    Call AddLine(State, "  ret ptr %p")
    Call AddLine(State, "}")
    Call AddLine(State, "define i1 @ube.target.release(ptr %block) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %status = call i32 @VirtualFree(ptr %block, i64 0, i32 32768)")
    Call AddLine(State, "  %ok = icmp ne i32 %status, 0")
    Call AddLine(State, "  ret i1 %ok")
    Call AddLine(State, "}")
    Call AddLine(State, "define internal void @ube.block.retain(ptr %block) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %exists = icmp ne ptr %block, null")
    Call AddLine(State, "  br i1 %exists, label %retain, label %done")
    Call AddLine(State, "retain:")
    Call AddLine(State, "  %refs.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 1")
    Call AddLine(State, "  %previous = atomicrmw add ptr %refs.ptr, i64 1 monotonic")
    Call AddLine(State, "  br label %done")
    Call AddLine(State, "done:")
    Call AddLine(State, "  ret void")
    Call AddLine(State, "}")
    Call AddLine(State, "define internal void @ube.block.drop(ptr %ctx, ptr %block) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %exists = icmp ne ptr %block, null")
    Call AddLine(State, "  br i1 %exists, label %drop, label %done")
    Call AddLine(State, "drop:")
    Call AddLine(State, "  %program = call ptr @ube.thread.program(ptr %ctx)")
    Call AddLine(State, "  %pending = getelementptr %ube.program, ptr %program, i32 0, i32 12")
    Call AddLine(State, "  %refs.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 1")
    Call AddLine(State, "  %previous = atomicrmw sub ptr %refs.ptr, i64 1 release")
    Call AddLine(State, "  %last = icmp eq i64 %previous, 1")
    Call AddLine(State, "  br i1 %last, label %retired, label %done")
    Call AddLine(State, "retired:")
    Call AddLine(State, "  %marked = atomicrmw or ptr %pending, i64 1 release")
    Call AddLine(State, "  br label %done")
    Call AddLine(State, "done:")
    Call AddLine(State, "  ret void")
    Call AddLine(State, "}")
    Call AddLine(State, "define internal i1 @ube.memory.collect.locked(ptr %ctx) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %program = call ptr @ube.thread.program(ptr %ctx)")
    Call AddLine(State, "  %pending = getelementptr %ube.program, ptr %program, i32 0, i32 12")
    Call AddLine(State, "  %acknowledged = atomicrmw xchg ptr %pending, i64 0 acq_rel")
    Call AddLine(State, "  %head = call ptr @ube.memory.head(ptr %ctx)")
    Call AddLine(State, "  %bytes.ptr = call ptr @ube.memory.bytes(ptr %ctx)")
    Call AddLine(State, "  %count.ptr = call ptr @ube.memory.count(ptr %ctx)")
    Call AddLine(State, "  br label %scan")
    Call AddLine(State, "scan:")
    Call AddLine(State, "  %link = phi ptr [ %head, %entry ], [ %block, %keep ], [ %link, %freed ]")
    Call AddLine(State, "  %worked = phi i1 [ false, %entry ], [ %worked, %keep ], [ true, %freed ]")
    Call AddLine(State, "  %block = load ptr, ptr %link")
    Call AddLine(State, "  %exists = icmp ne ptr %block, null")
    Call AddLine(State, "  br i1 %exists, label %inspect, label %done")
    Call AddLine(State, "inspect:")
    Call AddLine(State, "  %refs.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 1")
    Call AddLine(State, "  %refs = load atomic i64, ptr %refs.ptr acquire, align 8")
    Call AddLine(State, "  %unused = icmp eq i64 %refs, 0")
    Call AddLine(State, "  br i1 %unused, label %release, label %keep")
    Call AddLine(State, "release:")
    Call AddLine(State, "  %next = load ptr, ptr %block")
    Call AddLine(State, "  %charge.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 2")
    Call AddLine(State, "  %charge = load atomic i64, ptr %charge.ptr monotonic, align 8")
    Call AddLine(State, "  %ok = call i1 @ube.target.release(ptr %block)")
    Call AddLine(State, "  br i1 %ok, label %freed, label %refused")
    Call AddLine(State, "refused:")
    Call AddLine(State, "  %remarked = atomicrmw or ptr %pending, i64 1 release")
    Call AddLine(State, "  br label %keep")
    Call AddLine(State, "freed:")
    Call AddLine(State, "  store ptr %next, ptr %link")
    Call AddLine(State, "  %bytes = load atomic i64, ptr %bytes.ptr monotonic, align 8")
    Call AddLine(State, "  %less.bytes = sub i64 %bytes, %charge")
    Call AddLine(State, "  store atomic i64 %less.bytes, ptr %bytes.ptr monotonic, align 8")
    Call AddLine(State, "  %count = load atomic i64, ptr %count.ptr monotonic, align 8")
    Call AddLine(State, "  %less.count = sub i64 %count, 1")
    Call AddLine(State, "  store atomic i64 %less.count, ptr %count.ptr monotonic, align 8")
    Call AddLine(State, "  br label %scan")
    Call AddLine(State, "keep:")
    Call AddLine(State, "  br label %scan")
    Call AddLine(State, "done:")
    Call AddLine(State, "  ret i1 %worked")
    Call AddLine(State, "}")
    Call AddLine(State, "define internal ptr @ube.memory.new.locked(ptr %ctx, i64 %count, i64 %stride) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %negative = icmp sle i64 %count, 0")
    Call AddLine(State, "  %large = icmp sgt i64 %count, " & CStr(MaximumArrayElements) & "")
    Call AddLine(State, "  %bad.stride.low = icmp sle i64 %stride, 0")
    Call AddLine(State, "  %bad.stride.high = icmp sgt i64 %stride, 128")
    Call AddLine(State, "  %bad.count = or i1 %negative, %large")
    Call AddLine(State, "  %bad.stride = or i1 %bad.stride.low, %bad.stride.high")
    Call AddLine(State, "  %bad = or i1 %bad.count, %bad.stride")
    Call AddLine(State, "  br i1 %bad, label %failed, label %size")
    Call AddLine(State, "size:")
    Call AddLine(State, "  %cells = mul i64 %count, %stride")
    Call AddLine(State, "  %payload.bytes = mul i64 %cells, 8")
    Call AddLine(State, "  %total = add i64 %payload.bytes, 24")
    Call AddLine(State, "  %rounded = add i64 %total, 4095")
    Call AddLine(State, "  %pages = lshr i64 %rounded, 12")
    Call AddLine(State, "  %charge = shl i64 %pages, 12")
    Call AddLine(State, "  %charge.large = icmp ugt i64 %charge, 67108864")
    Call AddLine(State, "  br i1 %charge.large, label %failed, label %quota")
    Call AddLine(State, "quota:")
    Call AddLine(State, "  %available = sub i64 67108864, %charge")
    Call AddLine(State, "  %head = call ptr @ube.memory.head(ptr %ctx)")
    Call AddLine(State, "  %bytes.ptr = call ptr @ube.memory.bytes(ptr %ctx)")
    Call AddLine(State, "  %count.ptr = call ptr @ube.memory.count(ptr %ctx)")
    Call AddLine(State, "  br label %attempt")
    Call AddLine(State, "attempt:")
    Call AddLine(State, "  %retry = phi i1 [ false, %quota ], [ true, %collect ]")
    Call AddLine(State, "  %bytes = load atomic i64, ptr %bytes.ptr monotonic, align 8")
    Call AddLine(State, "  %blocks = load atomic i64, ptr %count.ptr monotonic, align 8")
    Call AddLine(State, "  %over.bytes = icmp ugt i64 %bytes, %available")
    Call AddLine(State, "  %over.blocks = icmp uge i64 %blocks, 4096")
    Call AddLine(State, "  %over = or i1 %over.bytes, %over.blocks")
    Call AddLine(State, "  br i1 %over, label %miss, label %allocate")
    Call AddLine(State, "allocate:")
    Call AddLine(State, "  %block = call ptr @ube.target.allocate(i64 %charge)")
    Call AddLine(State, "  %ok = icmp ne ptr %block, null")
    Call AddLine(State, "  br i1 %ok, label %allocated, label %miss")
    Call AddLine(State, "miss:")
    Call AddLine(State, "  br i1 %retry, label %failed, label %collect")
    Call AddLine(State, "collect:")
    Call AddLine(State, "  %collected = call i1 @ube.memory.collect.locked(ptr %ctx)")
    Call AddLine(State, "  br label %attempt")
    Call AddLine(State, "allocated:")
    Call AddLine(State, "  %old.head = load ptr, ptr %head")
    Call AddLine(State, "  store ptr %old.head, ptr %block")
    Call AddLine(State, "  %refs.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 1")
    Call AddLine(State, "  store atomic i64 1, ptr %refs.ptr monotonic, align 8")
    Call AddLine(State, "  %charge.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 2")
    Call AddLine(State, "  store atomic i64 %charge, ptr %charge.ptr monotonic, align 8")
    Call AddLine(State, "  store ptr %block, ptr %head")
    Call AddLine(State, "  %new.bytes = add i64 %bytes, %charge")
    Call AddLine(State, "  %new.blocks = add i64 %blocks, 1")
    Call AddLine(State, "  store atomic i64 %new.bytes, ptr %bytes.ptr monotonic, align 8")
    Call AddLine(State, "  store atomic i64 %new.blocks, ptr %count.ptr monotonic, align 8")
    Call AddLine(State, "  %data = getelementptr %ube.block, ptr %block, i64 1")
    Call AddLine(State, "  br label %zero")
    Call AddLine(State, "zero:")
    Call AddLine(State, "  %index = phi i64 [ 0, %allocated ], [ %next.index, %zero ]")
    Call AddLine(State, "  %cell = getelementptr i64, ptr %data, i64 %index")
    Call AddLine(State, "  store atomic volatile i64 0, ptr %cell monotonic, align 8")
    Call AddLine(State, "  %next.index = add i64 %index, 1")
    Call AddLine(State, "  %more = icmp ult i64 %next.index, %cells")
    Call AddLine(State, "  br i1 %more, label %zero, label %done")
    Call AddLine(State, "done:")
    Call AddLine(State, "  ret ptr %block")
    Call AddLine(State, "failed:")
    Call AddLine(State, "  ret ptr null")
    Call AddLine(State, "}")
    Call AddLine(State, "define internal void @ube.array.clear(ptr %ctx, ptr %array) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %program = call ptr @ube.thread.program(ptr %ctx)")
    Call AddLine(State, "  call void @ube.program.storage.lock(ptr %program)")
    Call AddLine(State, "  call void @ube.array.clear.locked(ptr %ctx, ptr %array)")
    Call AddLine(State, "  call void @ube.program.storage.unlock(ptr %program)")
    Call AddLine(State, "  ret void")
    Call AddLine(State, "}")
    Call AddLine(State, "define internal void @ube.array.clear.locked(ptr %ctx, ptr %array) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %program = call ptr @ube.thread.program(ptr %ctx)")
    Call AddLine(State, "  call void @ube.array.lock(ptr %program, ptr %array)")
    Call AddLine(State, "  %upper.ptr = getelementptr i64, ptr %array, i64 1")
    Call AddLine(State, "  %data.ptr = getelementptr i64, ptr %array, i64 2")
    Call AddLine(State, "  %block.ptr = getelementptr i64, ptr %array, i64 3")
    Call AddLine(State, "  %old = load ptr, ptr %block.ptr")
    Call AddLine(State, "  store atomic i64 0, ptr %array monotonic, align 8")
    Call AddLine(State, "  store atomic i64 -1, ptr %upper.ptr monotonic, align 8")
    Call AddLine(State, "  store ptr null, ptr %data.ptr")
    Call AddLine(State, "  store ptr null, ptr %block.ptr")
    Call AddLine(State, "  call void @ube.block.drop(ptr %ctx, ptr %old)")
    Call AddLine(State, "  call void @ube.array.unlock(ptr %program, ptr %array)")
    Call AddLine(State, "  ret void")
    Call AddLine(State, "}")
    Call AddLine(State, "define internal void @ube.box.drop(ptr %ctx, ptr %block, i1 %contains.array) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %exists = icmp ne ptr %block, null")
    Call AddLine(State, "  br i1 %exists, label %inspect, label %done")
    Call AddLine(State, "inspect:")
    Call AddLine(State, "  %program = call ptr @ube.thread.program(ptr %ctx)")
    Call AddLine(State, "  call void @ube.program.storage.lock(ptr %program)")
    Call AddLine(State, "  %refs.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 1")
    Call AddLine(State, "  %refs = load atomic i64, ptr %refs.ptr acquire, align 8")
    Call AddLine(State, "  %last = icmp eq i64 %refs, 1")
    Call AddLine(State, "  %clear = and i1 %last, %contains.array")
    Call AddLine(State, "  br i1 %clear, label %clear.array, label %drop")
    Call AddLine(State, "clear.array:")
    Call AddLine(State, "  %array = getelementptr %ube.block, ptr %block, i64 1")
    Call AddLine(State, "  call void @ube.array.clear.locked(ptr %ctx, ptr %array)")
    Call AddLine(State, "  br label %drop")
    Call AddLine(State, "drop:")
    Call AddLine(State, "  call void @ube.block.drop(ptr %ctx, ptr %block)")
    Call AddLine(State, "  call void @ube.program.storage.unlock(ptr %program)")
    Call AddLine(State, "  br label %done")
    Call AddLine(State, "done:")
    Call AddLine(State, "  ret void")
    Call AddLine(State, "}")
    Call AddLine(State, "define internal void @ube.array.install(ptr %ctx, ptr %array, ptr %block, i64 %lower, i64 %upper) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %program = call ptr @ube.thread.program(ptr %ctx)")
    Call AddLine(State, "  call void @ube.program.storage.lock(ptr %program)")
    Call AddLine(State, "  call void @ube.array.lock(ptr %program, ptr %array)")
    Call AddLine(State, "  %upper.ptr = getelementptr i64, ptr %array, i64 1")
    Call AddLine(State, "  %data.ptr = getelementptr i64, ptr %array, i64 2")
    Call AddLine(State, "  %block.ptr = getelementptr i64, ptr %array, i64 3")
    Call AddLine(State, "  %old = load ptr, ptr %block.ptr")
    Call AddLine(State, "  %data = getelementptr %ube.block, ptr %block, i64 1")
    Call AddLine(State, "  store atomic i64 %lower, ptr %array monotonic, align 8")
    Call AddLine(State, "  store atomic i64 %upper, ptr %upper.ptr monotonic, align 8")
    Call AddLine(State, "  store ptr %data, ptr %data.ptr")
    Call AddLine(State, "  store ptr %block, ptr %block.ptr")
    Call AddLine(State, "  call void @ube.block.drop(ptr %ctx, ptr %old)")
    Call AddLine(State, "  call void @ube.array.unlock(ptr %program, ptr %array)")
    Call AddLine(State, "  call void @ube.program.storage.unlock(ptr %program)")
    Call AddLine(State, "  ret void")
    Call AddLine(State, "}")
    Call AddLine(State, "define internal void @ube.cells.copy(ptr %source, ptr %destination, i64 %count) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %empty = icmp eq i64 %count, 0")
    Call AddLine(State, "  br i1 %empty, label %done, label %copy")
    Call AddLine(State, "copy:")
    Call AddLine(State, "  %index = phi i64 [ 0, %entry ], [ %next, %copy ]")
    Call AddLine(State, "  %from = getelementptr i64, ptr %source, i64 %index")
    Call AddLine(State, "  %to = getelementptr i64, ptr %destination, i64 %index")
    Call AddLine(State, "  %value = load atomic volatile i64, ptr %from monotonic, align 8")
    Call AddLine(State, "  store atomic volatile i64 %value, ptr %to monotonic, align 8")
    Call AddLine(State, "  %next = add i64 %index, 1")
    Call AddLine(State, "  %more = icmp ult i64 %next, %count")
    Call AddLine(State, "  br i1 %more, label %copy, label %done")
    Call AddLine(State, "done:")
    Call AddLine(State, "  ret void")
    Call AddLine(State, "}")
    Call AddLine(State, "define internal i1 @ube.array.tryresize(ptr %ctx, ptr %array, i64 %count, i64 %preserve, i64 %stride) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %err = getelementptr %ube.thread, ptr %ctx, i32 0, i32 0")
    Call AddLine(State, "  %negative = icmp slt i64 %count, 0")
    Call AddLine(State, "  br i1 %negative, label %argument.fail, label %empty.test")
    Call AddLine(State, "empty.test:")
    Call AddLine(State, "  %empty = icmp eq i64 %count, 0")
    Call AddLine(State, "  br i1 %empty, label %empty.resize, label %allocate")
    Call AddLine(State, "empty.resize:")
    Call AddLine(State, "  call void @ube.array.clear(ptr %ctx, ptr %array)")
    Call AddLine(State, "  %empty.collected = call i1 @ube.memory.collect(ptr %ctx)")
    Call AddLine(State, "  ret i1 true")
    Call AddLine(State, "allocate:")
    Call AddLine(State, "  %block = call ptr @ube.memory.new(ptr %ctx, i64 %count, i64 %stride)")
    Call AddLine(State, "  %ok = icmp ne ptr %block, null")
    Call AddLine(State, "  br i1 %ok, label %prepared, label %memory.fail")
    Call AddLine(State, "prepared:")
    Call AddLine(State, "  %upper = sub i64 %count, 1")
    Call AddLine(State, "  %keep = icmp ne i64 %preserve, 0")
    Call AddLine(State, "  br i1 %keep, label %intersection, label %publish")
    Call AddLine(State, "intersection:")
    Call AddLine(State, "  %snapshot = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %array)")
    Call AddLine(State, "  %old.lower = extractvalue { i64, i64, ptr, ptr } %snapshot, 0")
    Call AddLine(State, "  %old.upper = extractvalue { i64, i64, ptr, ptr } %snapshot, 1")
    Call AddLine(State, "  %old.data = extractvalue { i64, i64, ptr, ptr } %snapshot, 2")
    Call AddLine(State, "  %old.block = extractvalue { i64, i64, ptr, ptr } %snapshot, 3")
    Call AddLine(State, "  %positive.lower = icmp sgt i64 %old.lower, 0")
    Call AddLine(State, "  %first = select i1 %positive.lower, i64 %old.lower, i64 0")
    Call AddLine(State, "  %smaller.upper = icmp slt i64 %old.upper, %upper")
    Call AddLine(State, "  %last = select i1 %smaller.upper, i64 %old.upper, i64 %upper")
    Call AddLine(State, "  %overlap = icmp sle i64 %first, %last")
    Call AddLine(State, "  br i1 %overlap, label %copy, label %publish")
    Call AddLine(State, "copy:")
    Call AddLine(State, "  %data = getelementptr %ube.block, ptr %block, i64 1")
    Call AddLine(State, "  %old.index = sub i64 %first, %old.lower")
    Call AddLine(State, "  %old.offset = mul i64 %old.index, %stride")
    Call AddLine(State, "  %new.offset = mul i64 %first, %stride")
    Call AddLine(State, "  %source = getelementptr i64, ptr %old.data, i64 %old.offset")
    Call AddLine(State, "  %destination = getelementptr i64, ptr %data, i64 %new.offset")
    Call AddLine(State, "  %distance = sub i64 %last, %first")
    Call AddLine(State, "  %elements = add i64 %distance, 1")
    Call AddLine(State, "  %cells = mul i64 %elements, %stride")
    Call AddLine(State, "  call void @ube.cells.copy(ptr %source, ptr %destination, i64 %cells)")
    Call AddLine(State, "  br label %publish")
    Call AddLine(State, "publish:")
    Call AddLine(State, "  %pin = phi ptr [null, %prepared], [%old.block, %intersection], [%old.block, %copy]")
    Call AddLine(State, "  call void @ube.array.install(ptr %ctx, ptr %array, ptr %block, i64 0, i64 %upper)")
    Call AddLine(State, "  call void @ube.block.drop(ptr %ctx, ptr %pin)")
    Call AddLine(State, "  %collected = call i1 @ube.memory.collect(ptr %ctx)")
    Call AddLine(State, "  ret i1 true")
    Call AddLine(State, "argument.fail:")
    Call AddLine(State, "  store atomic i64 5, ptr %err monotonic, align 8")
    Call AddLine(State, "  ret i1 false")
    Call AddLine(State, "memory.fail:")
    Call AddLine(State, "  store atomic i64 7, ptr %err monotonic, align 8")
    Call AddLine(State, "  ret i1 false")
    Call AddLine(State, "}")
    Call AddLine(State, "define internal i1 @ube.array.trycopy(ptr %ctx, ptr %destination, ptr %source, i64 %stride) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %err = getelementptr %ube.thread, ptr %ctx, i32 0, i32 0")
    Call AddLine(State, "  %snapshot = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %source)")
    Call AddLine(State, "  %lower = extractvalue { i64, i64, ptr, ptr } %snapshot, 0")
    Call AddLine(State, "  %upper = extractvalue { i64, i64, ptr, ptr } %snapshot, 1")
    Call AddLine(State, "  %source.data = extractvalue { i64, i64, ptr, ptr } %snapshot, 2")
    Call AddLine(State, "  %pin = extractvalue { i64, i64, ptr, ptr } %snapshot, 3")
    Call AddLine(State, "  %distance = sub i64 %upper, %lower")
    Call AddLine(State, "  %count = add i64 %distance, 1")
    Call AddLine(State, "  %empty = icmp eq i64 %count, 0")
    Call AddLine(State, "  br i1 %empty, label %empty.copy, label %allocate")
    Call AddLine(State, "empty.copy:")
    Call AddLine(State, "  call void @ube.array.clear(ptr %ctx, ptr %destination)")
    Call AddLine(State, "  call void @ube.block.drop(ptr %ctx, ptr %pin)")
    Call AddLine(State, "  %empty.collected = call i1 @ube.memory.collect(ptr %ctx)")
    Call AddLine(State, "  ret i1 true")
    Call AddLine(State, "allocate:")
    Call AddLine(State, "  %block = call ptr @ube.memory.new(ptr %ctx, i64 %count, i64 %stride)")
    Call AddLine(State, "  %ok = icmp ne ptr %block, null")
    Call AddLine(State, "  br i1 %ok, label %copy, label %memory.fail")
    Call AddLine(State, "copy:")
    Call AddLine(State, "  %destination.data = getelementptr %ube.block, ptr %block, i64 1")
    Call AddLine(State, "  %cells = mul i64 %count, %stride")
    Call AddLine(State, "  call void @ube.cells.copy(ptr %source.data, ptr %destination.data, i64 %cells)")
    Call AddLine(State, "  call void @ube.array.install(ptr %ctx, ptr %destination, ptr %block, i64 %lower, i64 %upper)")
    Call AddLine(State, "  call void @ube.block.drop(ptr %ctx, ptr %pin)")
    Call AddLine(State, "  %collected = call i1 @ube.memory.collect(ptr %ctx)")
    Call AddLine(State, "  ret i1 true")
    Call AddLine(State, "memory.fail:")
    Call AddLine(State, "  call void @ube.block.drop(ptr %ctx, ptr %pin)")
    Call AddLine(State, "  store atomic i64 7, ptr %err monotonic, align 8")
    Call AddLine(State, "  ret i1 false")
    Call AddLine(State, "}")
    Call AddLine(State, "define internal void @ube.program.storage.lock(ptr %program) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %lock = getelementptr %ube.program, ptr %program, i32 0, i32 6")
    Call AddLine(State, "  br label %attempt")
    Call AddLine(State, "attempt:")
    Call AddLine(State, "  %pair = cmpxchg ptr %lock, i64 0, i64 1 acquire monotonic")
    Call AddLine(State, "  %won = extractvalue { i64, i1 } %pair, 1")
    Call AddLine(State, "  br i1 %won, label %done, label %attempt")
    Call AddLine(State, "done:")
    Call AddLine(State, "  ret void")
    Call AddLine(State, "}")
    Call AddLine(State, "define internal void @ube.program.storage.unlock(ptr %program) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %lock = getelementptr %ube.program, ptr %program, i32 0, i32 6")
    Call AddLine(State, "  store atomic i64 0, ptr %lock release, align 8")
    Call AddLine(State, "  ret void")
    Call AddLine(State, "}")
    ' A padded program-owned stripe isolates descriptor publication from heap bookkeeping.
    Call AddLine(State, "define internal ptr @ube.array.lock.address(ptr %program, ptr %array) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %address = ptrtoint ptr %array to i64")
    Call AddLine(State, "  %low = lshr i64 %address, 3")
    Call AddLine(State, "  %page = lshr i64 %address, 12")
    Call AddLine(State, "  %stack = lshr i64 %address, 16")
    Call AddLine(State, "  %region = lshr i64 %address, 22")
    Call AddLine(State, "  %high = lshr i64 %address, 32")
    Call AddLine(State, "  %a = xor i64 %low, %page")
    Call AddLine(State, "  %b = xor i64 %a, %stack")
    Call AddLine(State, "  %c = xor i64 %b, %region")
    Call AddLine(State, "  %d = xor i64 %c, %high")
    Call AddLine(State, "  %stripe = and i64 %d, 63")
    Call AddLine(State, "  %index = add i64 %stripe, 1")
    Call AddLine(State, "  %lock = getelementptr %ube.program, ptr %program, i32 0, i32 13, i64 %index, i64 0")
    Call AddLine(State, "  ret ptr %lock")
    Call AddLine(State, "}")
    Call AddLine(State, "define internal void @ube.array.lock(ptr %program, ptr %array) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %lock = call ptr @ube.array.lock.address(ptr %program, ptr %array)")
    Call AddLine(State, "  br label %attempt")
    Call AddLine(State, "attempt:")
    Call AddLine(State, "  %pair = cmpxchg ptr %lock, i64 0, i64 1 acquire monotonic")
    Call AddLine(State, "  %won = extractvalue { i64, i1 } %pair, 1")
    Call AddLine(State, "  br i1 %won, label %done, label %attempt")
    Call AddLine(State, "done:")
    Call AddLine(State, "  ret void")
    Call AddLine(State, "}")
    Call AddLine(State, "define internal void @ube.array.unlock(ptr %program, ptr %array) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %lock = call ptr @ube.array.lock.address(ptr %program, ptr %array)")
    Call AddLine(State, "  store atomic i64 0, ptr %lock release, align 8")
    Call AddLine(State, "  ret void")
    Call AddLine(State, "}")
    Call AddLine(State, "define internal { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %array) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %empty = icmp eq ptr %array, null")
    Call AddLine(State, "  br i1 %empty, label %absent, label %capture")
    Call AddLine(State, "absent:")
    Call AddLine(State, "  ret { i64, i64, ptr, ptr } { i64 0, i64 -1, ptr null, ptr null }")
    Call AddLine(State, "capture:")
    Call AddLine(State, "  %program = call ptr @ube.thread.program(ptr %ctx)")
    Call AddLine(State, "  call void @ube.array.lock(ptr %program, ptr %array)")
    Call AddLine(State, "  %upper.ptr = getelementptr i64, ptr %array, i64 1")
    Call AddLine(State, "  %data.ptr = getelementptr i64, ptr %array, i64 2")
    Call AddLine(State, "  %block.ptr = getelementptr i64, ptr %array, i64 3")
    Call AddLine(State, "  %lower = load atomic i64, ptr %array monotonic, align 8")
    Call AddLine(State, "  %upper = load atomic i64, ptr %upper.ptr monotonic, align 8")
    Call AddLine(State, "  %data = load ptr, ptr %data.ptr")
    Call AddLine(State, "  %block = load ptr, ptr %block.ptr")
    Call AddLine(State, "  call void @ube.block.retain(ptr %block)")
    Call AddLine(State, "  call void @ube.array.unlock(ptr %program, ptr %array)")
    Call AddLine(State, "  %first = insertvalue { i64, i64, ptr, ptr } poison, i64 %lower, 0")
    Call AddLine(State, "  %second = insertvalue { i64, i64, ptr, ptr } %first, i64 %upper, 1")
    Call AddLine(State, "  %third = insertvalue { i64, i64, ptr, ptr } %second, ptr %data, 2")
    Call AddLine(State, "  %result = insertvalue { i64, i64, ptr, ptr } %third, ptr %block, 3")
    Call AddLine(State, "  ret { i64, i64, ptr, ptr } %result")
    Call AddLine(State, "}")
    Call AddLine(State, "define internal i64 @ube.array.length(ptr %ctx, ptr %array) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %snapshot = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %array)")
    Call AddLine(State, "  %lower = extractvalue { i64, i64, ptr, ptr } %snapshot, 0")
    Call AddLine(State, "  %upper = extractvalue { i64, i64, ptr, ptr } %snapshot, 1")
    Call AddLine(State, "  %block = extractvalue { i64, i64, ptr, ptr } %snapshot, 3")
    Call AddLine(State, "  %distance = sub i64 %upper, %lower")
    Call AddLine(State, "  %length = add i64 %distance, 1")
    Call AddLine(State, "  call void @ube.block.drop(ptr %ctx, ptr %block)")
    Call AddLine(State, "  ret i64 %length")
    Call AddLine(State, "}")
    Call AddLine(State, "define internal i1 @ube.memory.collect(ptr %ctx) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %program = call ptr @ube.thread.program(ptr %ctx)")
    Call AddLine(State, "  %pending = getelementptr %ube.program, ptr %program, i32 0, i32 12")
    Call AddLine(State, "  %retired = load atomic i64, ptr %pending acquire, align 8")
    Call AddLine(State, "  %needed = icmp ne i64 %retired, 0")
    Call AddLine(State, "  br i1 %needed, label %collect, label %idle")
    Call AddLine(State, "idle:")
    Call AddLine(State, "  ret i1 false")
    Call AddLine(State, "collect:")
    Call AddLine(State, "  call void @ube.program.storage.lock(ptr %program)")
    Call AddLine(State, "  %worked = call i1 @ube.memory.collect.locked(ptr %ctx)")
    Call AddLine(State, "  call void @ube.program.storage.unlock(ptr %program)")
    Call AddLine(State, "  ret i1 %worked")
    Call AddLine(State, "}")
    Call AddLine(State, "define internal ptr @ube.memory.new(ptr %ctx, i64 %count, i64 %stride) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %program = call ptr @ube.thread.program(ptr %ctx)")
    Call AddLine(State, "  call void @ube.program.storage.lock(ptr %program)")
    Call AddLine(State, "  %block = call ptr @ube.memory.new.locked(ptr %ctx, i64 %count, i64 %stride)")
    Call AddLine(State, "  call void @ube.program.storage.unlock(ptr %program)")
    Call AddLine(State, "  ret ptr %block")
    Call AddLine(State, "}")
    Call AddLine(State, "define internal { i1, i64 } @ube.memory.copybytes(ptr %ctx, ptr %arg.0, i64 %arg.1, ptr %arg.2, i64 %arg.3, i64 %arg.4) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %program = call ptr @ube.thread.program(ptr %ctx)")
    Call AddLine(State, "  call void @ube.program.storage.lock(ptr %program)")
    Call AddLine(State, "  %source.lower = load atomic i64, ptr %arg.0 monotonic, align 8")
    Call AddLine(State, "  %source.upper.ptr = getelementptr i64, ptr %arg.0, i64 1")
    Call AddLine(State, "  %source.upper = load atomic i64, ptr %source.upper.ptr monotonic, align 8")
    Call AddLine(State, "  %source.distance = sub i64 %source.upper, %source.lower")
    Call AddLine(State, "  %source.length = add i64 %source.distance, 1")
    Call AddLine(State, "  %err = getelementptr %ube.thread, ptr %ctx, i32 0, i32 0")
    Call AddLine(State, "  %count.invalid = icmp slt i64 %arg.4, 0")
    Call AddLine(State, "  br i1 %count.invalid, label %argument.fail, label %span.starts")
    Call AddLine(State, "span.starts:")
    Call AddLine(State, "  %destination.lower = load atomic i64, ptr %arg.2 monotonic, align 8")
    Call AddLine(State, "  %destination.upper.ptr = getelementptr i64, ptr %arg.2, i64 1")
    Call AddLine(State, "  %destination.upper = load atomic i64, ptr %destination.upper.ptr monotonic, align 8")
    Call AddLine(State, "  %destination.distance = sub i64 %destination.upper, %destination.lower")
    Call AddLine(State, "  %destination.length = add i64 %destination.distance, 1")
    Call AddLine(State, "  %source.negative = icmp slt i64 %arg.1, 0")
    Call AddLine(State, "  %destination.negative = icmp slt i64 %arg.3, 0")
    Call AddLine(State, "  %source.past = icmp sgt i64 %arg.1, %source.length")
    Call AddLine(State, "  %destination.past = icmp sgt i64 %arg.3, %destination.length")
    Call AddLine(State, "  %negative = or i1 %source.negative, %destination.negative")
    Call AddLine(State, "  %past = or i1 %source.past, %destination.past")
    Call AddLine(State, "  %start.invalid = or i1 %negative, %past")
    Call AddLine(State, "  br i1 %start.invalid, label %span.fail, label %span.count")
    Call AddLine(State, "span.count:")
    Call AddLine(State, "  %source.remaining = sub i64 %source.length, %arg.1")
    Call AddLine(State, "  %destination.remaining = sub i64 %destination.length, %arg.3")
    Call AddLine(State, "  %source.short = icmp sgt i64 %arg.4, %source.remaining")
    Call AddLine(State, "  %destination.short = icmp sgt i64 %arg.4, %destination.remaining")
    Call AddLine(State, "  %span.invalid = or i1 %source.short, %destination.short")
    Call AddLine(State, "  br i1 %span.invalid, label %span.fail, label %copy.test")
    Call AddLine(State, "copy.test:")
    Call AddLine(State, "  %empty = icmp eq i64 %arg.4, 0")
    Call AddLine(State, "  br i1 %empty, label %copy.done, label %copy.choose")
    Call AddLine(State, "copy.choose:")
    Call AddLine(State, "  %source.data.ptr = getelementptr i64, ptr %arg.0, i64 2")
    Call AddLine(State, "  %source.data = load ptr, ptr %source.data.ptr")
    Call AddLine(State, "  %destination.data.ptr = getelementptr i64, ptr %arg.2, i64 2")
    Call AddLine(State, "  %destination.data = load ptr, ptr %destination.data.ptr")
    Call AddLine(State, "  %same = icmp eq ptr %arg.0, %arg.2")
    Call AddLine(State, "  %later = icmp sgt i64 %arg.3, %arg.1")
    Call AddLine(State, "  %backward = and i1 %same, %later")
    Call AddLine(State, "  br i1 %backward, label %copy.backward, label %copy.forward")
    Call AddLine(State, "copy.forward:")
    Call AddLine(State, "  %forward.index = phi i64 [ 0, %copy.choose ], [ %forward.next, %copy.forward ]")
    Call AddLine(State, "  %forward.source.index = add i64 %arg.1, %forward.index")
    Call AddLine(State, "  %forward.destination.index = add i64 %arg.3, %forward.index")
    Call AddLine(State, "  %forward.source = getelementptr i64, ptr %source.data, i64 %forward.source.index")
    Call AddLine(State, "  %forward.destination = getelementptr i64, ptr %destination.data, i64 %forward.destination.index")
    Call AddLine(State, "  %forward.value = load atomic volatile i64, ptr %forward.source monotonic, align 8")
    Call AddLine(State, "  store atomic volatile i64 %forward.value, ptr %forward.destination monotonic, align 8")
    Call AddLine(State, "  %forward.next = add i64 %forward.index, 1")
    Call AddLine(State, "  %forward.more = icmp slt i64 %forward.next, %arg.4")
    Call AddLine(State, "  br i1 %forward.more, label %copy.forward, label %copy.done")
    Call AddLine(State, "copy.backward:")
    Call AddLine(State, "  %backward.remaining = phi i64 [ %arg.4, %copy.choose ], [ %backward.index, %copy.backward ]")
    Call AddLine(State, "  %backward.index = sub i64 %backward.remaining, 1")
    Call AddLine(State, "  %backward.source.index = add i64 %arg.1, %backward.index")
    Call AddLine(State, "  %backward.destination.index = add i64 %arg.3, %backward.index")
    Call AddLine(State, "  %backward.source = getelementptr i64, ptr %source.data, i64 %backward.source.index")
    Call AddLine(State, "  %backward.destination = getelementptr i64, ptr %destination.data, i64 %backward.destination.index")
    Call AddLine(State, "  %backward.value = load atomic volatile i64, ptr %backward.source monotonic, align 8")
    Call AddLine(State, "  store atomic volatile i64 %backward.value, ptr %backward.destination monotonic, align 8")
    Call AddLine(State, "  %backward.more = icmp ne i64 %backward.index, 0")
    Call AddLine(State, "  br i1 %backward.more, label %copy.backward, label %copy.done")
    Call AddLine(State, "argument.fail:")
    Call AddLine(State, "  store atomic i64 5, ptr %err monotonic, align 8")
    Call AddLine(State, "  call void @ube.program.storage.unlock(ptr %program)")
    Call AddLine(State, "  ret { i1, i64 } { i1 true, i64 0 }")
    Call AddLine(State, "span.fail:")
    Call AddLine(State, "  store atomic i64 9, ptr %err monotonic, align 8")
    Call AddLine(State, "  call void @ube.program.storage.unlock(ptr %program)")
    Call AddLine(State, "  ret { i1, i64 } { i1 true, i64 0 }")
    Call AddLine(State, "copy.done:")
    Call AddLine(State, "  call void @ube.program.storage.unlock(ptr %program)")
    Call AddLine(State, "  ret { i1, i64 } { i1 true, i64 -1 }")
    Call AddLine(State, "}")
End Sub

' Emits thread primitives without discarding their fresh completion outcomes.
Private Sub EmitThreadIntrinsic(ByRef Bound As BoundProject, ByRef State As EmissionState, ByVal Symbol As Long)
    Dim Parameter As Long, Index As Long
    Dim Arguments(0 To 1) As String, Signature As String, Role As String, Target As String
    Role = Bound.Symbols(Symbol).BindingId
    Signature = "ptr %ctx"
    Parameter = Bound.Symbols(Symbol).FirstParameter
    Do While Parameter <> 0
        Arguments(Index) = "%arg." & CStr(Parameter)
        Signature = Signature & ", i64 " & Arguments(Index)
        Index = Index + 1
        Parameter = Bound.Symbols(Parameter).NextParameter
    Loop
    Call AddLine(State, "define { i1, i64 } @ube.proc." & CStr(Symbol) & "(" & Signature & ") {")
    Call AddLine(State, "entry:")
    Select Case Role
    Case "thread.currentid": Target = "current"
    Case "thread.isalive": Target = "alive"
    Case "thread.wait": Target = "wait"
    Case "thread.requeststop": Target = "request.stop"
    End Select
    If Len(Target) > 0 Then
        Signature = "ptr %ctx"
        If Index > 0 Then Signature = Signature & ", i64 " & Arguments(0)
        If Index > 1 Then Signature = Signature & ", i64 " & Arguments(1)
        Call AddLine(State, "  %result = call { i1, i64 } @ube.thread." & Target & "(" & Signature & ")")
    Else
        If Role = "thread.stoprequested" Then
            Call AddLine(State, "  %requested = call i1 @ube.thread.stop.requested(ptr %ctx)")
            Call AddLine(State, "  %value = select i1 %requested, i64 -1, i64 0")
            Call AddLine(State, "  %result = insertvalue { i1, i64 } { i1 true, i64 0 }, i64 %value, 1")
        Else
            Call AddLine(State, "  call void @Sleep(i32 0)")
            Call AddLine(State, "  %result = call { i1, i64 } @ube.thread.value(i64 -1)")
        End If
    End If
    Call AddLine(State, "  ret { i1, i64 } %result")
    Call AddLine(State, "}")
End Sub

' Binds validated file roles to record-only runtime results without treating False as FAIL.
Private Sub EmitFileIntrinsic(ByRef Bound As BoundProject, ByRef State As EmissionState, ByVal Symbol As Long)
    Dim Parameter As Long, Index As Long
    Dim Arguments(0 To 5) As String, Signature As String, Role As String
    Role = Bound.Symbols(Symbol).BindingId
    State.ErrorNode = Bound.Symbols(Symbol).DeclarationNode
    Signature = "ptr %ctx"
    Parameter = Bound.Symbols(Symbol).FirstParameter
    Do While Parameter <> 0
        Arguments(Index) = "%arg." & CStr(Parameter)
        If Bound.Symbols(Parameter).PassingMode = "ByRef" Then
            Signature = Signature & ", ptr " & Arguments(Index)
        Else
            Signature = Signature & ", i64 " & Arguments(Index)
        End If
        Index = Index + 1
        Parameter = Bound.Symbols(Parameter).NextParameter
    Loop
    Call AddLine(State, "define { i1, i64 } @ube.proc." & CStr(Symbol) & "(" & Signature & ") {")
    Call AddLine(State, "entry:")
    Select Case Role
    Case "system.tryreadcommandline"
        Call AddLine(State, "  %accepted = call i1 @ube.system.commandline(ptr %ctx, ptr " & Arguments(0) & ", ptr " & Arguments(1) & ", ptr " & Arguments(2) & ")")
    Case "system.trywritestandard"
        Call AddLine(State, "  %accepted = call i1 @ube.system.write(ptr %ctx, i64 " & Arguments(0) & ", ptr " & Arguments(1) & ", i64 " & Arguments(2) & ", i64 " & Arguments(3) & ", ptr " & Arguments(4) & ", ptr " & Arguments(5) & ")")
    Case "file.tryfinalpath"
        Call AddLine(State, "  %accepted = call i1 @ube.path.resolve(ptr %ctx, ptr null, i64 " & Arguments(0) & ", ptr " & Arguments(1) & ", ptr " & Arguments(2) & ", ptr " & Arguments(3) & ", i1 true)")
    Case "path.tryfullpath"
        Call AddLine(State, "  %accepted = call i1 @ube.path.resolve(ptr %ctx, ptr " & Arguments(0) & ", i64 0, ptr " & Arguments(1) & ", ptr " & Arguments(2) & ", ptr " & Arguments(3) & ", i1 false)")
    Case "path.trycompareordinal"
        Call AddLine(State, "  %accepted = call i1 @ube.path.compare(ptr %ctx, ptr " & Arguments(0) & ", ptr " & Arguments(1) & ", ptr " & Arguments(2) & ", ptr " & Arguments(3) & ")")
    Case "process.trystart"
        Call AddLine(State, "  %accepted = call i1 @ube.process.start(ptr %ctx, ptr " & Arguments(0) & ", ptr " & Arguments(1) & ", ptr " & Arguments(2) & ", i64 " & Arguments(3) & ", ptr " & Arguments(4) & ", ptr " & Arguments(5) & ")")
    Case "process.trywait"
        Call AddLine(State, "  %accepted = call i1 @ube.process.wait(ptr %ctx, i64 " & Arguments(0) & ", i64 " & Arguments(1) & ", ptr " & Arguments(2) & ", ptr " & Arguments(3) & ", ptr " & Arguments(4) & ")")
    Case "process.tryterminate"
        Call AddLine(State, "  %accepted = call i1 @ube.process.terminate(ptr %ctx, i64 " & Arguments(0) & ", ptr " & Arguments(1) & ")")
    Case "process.tryclose"
        Call AddLine(State, "  %accepted = call i1 @ube.process.close(ptr %ctx, ptr " & Arguments(0) & ", ptr " & Arguments(1) & ")")
    Case "file.tryopendirectory"
        Call AddLine(State, "  %accepted = call i1 @ube.directory.open(ptr %ctx, ptr " & Arguments(0) & ", ptr " & Arguments(1) & ", ptr " & Arguments(2) & ")")
    Case "file.tryidentity"
        Call AddLine(State, "  %accepted = call i1 @ube.file.identity(ptr %ctx, i64 " & Arguments(0) & ", ptr " & Arguments(1) & ", ptr " & Arguments(2) & ")")
    Case "file.trylength"
        Call AddLine(State, "  %accepted = call i1 @ube.file.length(ptr %ctx, i64 " & Arguments(0) & ", ptr " & Arguments(1) & ", ptr " & Arguments(2) & ")")
    Case "system.tryexecutablepath"
        Call AddLine(State, "  %accepted = call i1 @ube.system.executable(ptr %ctx, ptr " & Arguments(0) & ", ptr " & Arguments(1) & ", ptr " & Arguments(2) & ")")
    Case "system.trymonotonicmilliseconds"
        Call AddLine(State, "  %accepted = call i1 @ube.system.clock(ptr %ctx, ptr " & Arguments(0) & ", ptr " & Arguments(1) & ")")
    Case "directory.trycreate"
        Call AddLine(State, "  %accepted = call i1 @ube.directory.create(ptr %ctx, ptr " & Arguments(0) & ", ptr " & Arguments(1) & ")")
    Case "directory.tryremove"
        Call AddLine(State, "  %accepted = call i1 @ube.directory.remove(ptr %ctx, ptr " & Arguments(0) & ", ptr " & Arguments(1) & ")")
    Case "file.trydelete"
        Call AddLine(State, "  %accepted = call i1 @ube.file.delete(ptr %ctx, ptr " & Arguments(0) & ", ptr " & Arguments(1) & ")")
    Case "file.tryreplace"
        Call AddLine(State, "  %accepted = call i1 @ube.file.replace(ptr %ctx, ptr " & Arguments(0) & ", ptr " & Arguments(1) & ", ptr " & Arguments(2) & ")")
    Case "path.trykind"
        Call AddLine(State, "  %accepted = call i1 @ube.path.kind(ptr %ctx, ptr " & Arguments(0) & ", ptr " & Arguments(1) & ", ptr " & Arguments(2) & ")")
    Case "file.tryopen"
        Call AddLine(State, "  %accepted = call i1 @ube.file.open(ptr %ctx, ptr " & Arguments(0) & ", i64 " & Arguments(1) & ", ptr " & Arguments(2) & ", ptr " & Arguments(3) & ", ptr " & Arguments(4) & ", i1 false)")
    Case "file.trycreatenew"
        Call AddLine(State, "  %length = alloca i64, align 8")
        Call AddLine(State, "  %accepted = call i1 @ube.file.open(ptr %ctx, ptr " & Arguments(0) & ", i64 2147483647, ptr " & Arguments(1) & ", ptr %length, ptr " & Arguments(2) & ", i1 true)")
    Case "file.tryread", "file.trywrite"
        Signature = "false"
        If Role = "file.trywrite" Then Signature = "true"
        Call AddLine(State, "  %accepted = call i1 @ube.file.transfer(ptr %ctx, i64 " & Arguments(0) & ", ptr " & Arguments(1) & ", i64 " & Arguments(2) & ", i64 " & Arguments(3) & ", ptr " & Arguments(4) & ", ptr " & Arguments(5) & ", i1 " & Signature & ")")
    Case "file.tryclose"
        Call AddLine(State, "  %accepted = call i1 @ube.file.close(ptr %ctx, ptr " & Arguments(0) & ", ptr " & Arguments(1) & ")")
    Case "file.tryflush"
        Call AddLine(State, "  %accepted = call i1 @ube.file.flush(ptr %ctx, i64 " & Arguments(0) & ", ptr " & Arguments(1) & ")")
    Case "error.set"
        Call AddLine(State, "  %positive = icmp sgt i64 " & Arguments(0) & ", 0")
        Call AddLine(State, "  %number = select i1 %positive, i64 " & Arguments(0) & ", i64 5")
        Call AddLine(State, "  %err = getelementptr %ube.thread, ptr %ctx, i32 0, i32 0")
        Call AddLine(State, "  store atomic i64 %number, ptr %err monotonic, align 8")
        Call AddLine(State, "  ret { i1, i64 } { i1 true, i64 0 }")
        Call AddLine(State, "}")
        Exit Sub
    End Select
    Call AddLine(State, "  %value = select i1 %accepted, i64 -1, i64 0")
    Call AddLine(State, "  %result = insertvalue { i1, i64 } { i1 true, i64 0 }, i64 %value, 1")
    Call AddLine(State, "  ret { i1, i64 } %result")
    Call AddLine(State, "}")
End Sub

' Emits array primitives using the same fresh-result ABI as ordinary source procedures.
Private Sub EmitArrayIntrinsic(ByRef Bound As BoundProject, ByRef State As EmissionState, ByVal Symbol As Long)
    Dim Signature As String, Parameter As Long, Index As Long
    Dim Arguments(0 To 4) As String, Role As String
    State.ErrorNode = Bound.Symbols(Symbol).DeclarationNode
    Role = Bound.Symbols(Symbol).BindingId
    Signature = "ptr %ctx"
    Parameter = Bound.Symbols(Symbol).FirstParameter
    Do While Parameter <> 0
        Arguments(Index) = "%arg." & CStr(Parameter)
        If Bound.Symbols(Parameter).PassingMode = "ByRef" Then
            Signature = Signature & ", ptr " & Arguments(Index)
        Else
            Signature = Signature & ", i64 " & Arguments(Index)
        End If
        Index = Index + 1
        Parameter = Bound.Symbols(Parameter).NextParameter
    Loop
    Call AddLine(State, "define { i1, i64 } @ube.proc." & CStr(Symbol) & "(" & Signature & ") {")
    Call AddLine(State, "entry:")
    If Role = "array.tryresize" Or Role = "array.trycopy" Then
        Parameter = Bound.Symbols(Symbol).FirstParameter
        If Role = "array.tryresize" Then
            Call AddLine(State, "  %accepted = call i1 @ube.array.tryresize(ptr %ctx, ptr " & Arguments(0) & ", i64 " & Arguments(1) & ", i64 " & Arguments(2) & ", i64 " & CStr(Bound.Symbols(Parameter).ElementCells) & ")")
        Else
            Call AddLine(State, "  %accepted = call i1 @ube.array.trycopy(ptr %ctx, ptr " & Arguments(0) & ", ptr " & Arguments(1) & ", i64 " & CStr(Bound.Symbols(Parameter).ElementCells) & ")")
        End If
        Call AddLine(State, "  %value = select i1 %accepted, i64 -1, i64 0")
        Call AddLine(State, "  %result = insertvalue { i1, i64 } { i1 true, i64 0 }, i64 %value, 1")
        Call AddLine(State, "  ret { i1, i64 } %result")
        Call AddLine(State, "}")
        Exit Sub
    End If
    If Role = "array.length" Then
        Call AddLine(State, "  %value = call i64 @ube.array.length(ptr %ctx, ptr " & Arguments(0) & ")")
        Call AddLine(State, "  %result = insertvalue { i1, i64 } { i1 true, i64 0 }, i64 %value, 1")
    Else
        Call AddLine(State, "  %result = call { i1, i64 } @ube.memory.copybytes(ptr %ctx, ptr " & Arguments(0) & ", i64 " & Arguments(1) & ", ptr " & Arguments(2) & ", i64 " & Arguments(3) & ", i64 " & Arguments(4) & ")")
    End If
    Call AddLine(State, "  ret { i1, i64 } %result")
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
        If Bound.Symbols(Parameter).PassingMode = "ByRef" Or Bound.Symbols(Parameter).ArrayRank <> 0 Or Bound.Symbols(Parameter).TypeSymbol <> 0 Then
            Signature = Signature & ", ptr %arg." & CStr(Parameter)
        Else
            Signature = Signature & ", i64 %arg." & CStr(Parameter)
        End If
        If OwnerParameter(Bound, State, Parameter) Then Signature = Signature & ", ptr %owner.arg." & CStr(Parameter)
        Parameter = Bound.Symbols(Parameter).NextParameter
    Loop
    Call AddLine(State, "define { i1, i64 } @ube.proc." & CStr(Symbol) & "(" & Signature & ") {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %err = getelementptr %ube.thread, ptr %ctx, i32 0, i32 0")
    Call AddLine(State, "  %depth.ptr = getelementptr %ube.thread, ptr %ctx, i32 0, i32 1")
    Call EmitFrame(Parsed, Bound, State)
    Depth = ValueName(State)
    Allowed = ValueName(State)
    Increased = ValueName(State)
    Initialized = ValueName(State)
    Call AddLine(State, "  " & Depth & " = load atomic i64, ptr %depth.ptr monotonic, align 8")
    Call AddLine(State, "  " & Allowed & " = icmp ult i64 " & Depth & ", " & CStr(MaximumNativeCallDepth))
    Call AddLine(State, "  br i1 " & Allowed & ", label %depth.enter, label %depth.refused")
    Call AddLine(State, "depth.refused:")
    Call AddLine(State, "  store atomic i64 28, ptr %err monotonic, align 8")
    Call AddLine(State, "  ret { i1, i64 } { i1 false, i64 0 }")
    Call AddLine(State, "depth.enter:")
    Call AddLine(State, "  " & Increased & " = add i64 " & Depth & ", 1")
    Call AddLine(State, "  store atomic i64 " & Increased & ", ptr %depth.ptr monotonic, align 8")
    Call EmitFrameBoxes(Bound, State)
    Call AddLine(State, "  " & Initialized & " = call i1 @ube.module.ensure." & CStr(State.CurrentModule) & "(ptr %ctx)")
    Child = Parsed.Nodes(Bound.Symbols(Symbol).DeclarationNode).FirstChild
    Do While Child <> 0
        If Parsed.Nodes(Child).Kind = "body" Then Body = Child
        Child = Parsed.Nodes(Child).NextSibling
    Loop
    Call AddLine(State, "  br label %" & SequenceEntry(Parsed, Body, "return.ok"))
    If Body <> 0 Then Call EmitSequence(Parsed, Bound, State, Body, "return.ok")
    Call EmitFailureDispatch(Parsed, Bound, State)
    Call EmitReturns(Parsed, Bound, State)
End Sub

' Adapts a statically selected procedure to the runtime worker entry signature.
Private Sub EmitThreadThunk(ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As EmissionState, ByVal Node As Long)
    Dim Values() As String, Owners() As String, Actuals() As Long
    Dim Symbol As Long, Parameter As Long, Argument As Long, Index As Long, Count As Long
    Dim Address As String, Arguments As String, Pair As String, Outcome As String, SavedError As String, Collected As String, Role As String
    Symbol = Bound.Nodes(Node).SymbolIndex
    Count = Bound.Symbols(Symbol).ParameterCount
    ReDim Values(0 To Count): ReDim Owners(0 To Count): ReDim Actuals(0 To Count)
    State.ValueNumber = 0: State.LabelNumber = 0
    Call AddLine(State, "define internal i1 @ube.thread.call." & CStr(Node) & "(ptr %ctx, ptr %capture) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %err = getelementptr %ube.thread, ptr %ctx, i32 0, i32 0")
    Parameter = Bound.Symbols(Symbol).FirstParameter
    Argument = Parsed.Nodes(Parsed.Nodes(Node).FirstChild).NextSibling
    Arguments = "ptr %ctx"
    Do While Argument <> 0
        Actuals(Index) = Argument
        Address = ValueName(State): Values(Index) = ValueName(State)
        Call AddLine(State, "  " & Address & " = getelementptr i64, ptr %capture, i64 " & CStr(Index * 2))
        Call AddLine(State, "  " & Values(Index) & " = load " & ArgumentType(Bound, Argument) & ", ptr " & Address)
        Address = ValueName(State): Owners(Index) = ValueName(State)
        Call AddLine(State, "  " & Address & " = getelementptr i64, ptr %capture, i64 " & CStr(Index * 2 + 1))
        Call AddLine(State, "  " & Owners(Index) & " = load ptr, ptr " & Address)
        Arguments = Arguments & ", " & ArgumentType(Bound, Argument) & " " & Values(Index)
        If OwnerParameter(Bound, State, Parameter) Then Arguments = Arguments & ", ptr " & Owners(Index)
        Parameter = Bound.Symbols(Parameter).NextParameter
        Argument = Parsed.Nodes(Argument).NextSibling
        Index = Index + 1
    Loop
    Role = Bound.Symbols(Symbol).BindingId
    If Role = "error.raise" Then
        Call AddLine(State, "  store atomic i64 " & Values(0) & ", ptr %err monotonic, align 8")
        Outcome = "false"
    ElseIf Role = "error.clear" Then
        Call AddLine(State, "  store atomic i64 0, ptr %err monotonic, align 8")
        Outcome = "true"
    Else
        Pair = ValueName(State): Outcome = ValueName(State)
        Call AddLine(State, "  " & Pair & " = call { i1, i64 } @ube.proc." & CStr(Symbol) & "(" & Arguments & ")")
        Call AddLine(State, "  " & Outcome & " = extractvalue { i1, i64 } " & Pair & ", 0")
    End If
    SavedError = ValueName(State)
    Call AddLine(State, "  " & SavedError & " = load atomic i64, ptr %err monotonic, align 8")
    Call DropCaptureOwners(Bound, State, Actuals, Owners, Count)
    Collected = ValueName(State)
    Call AddLine(State, "  " & Collected & " = call i1 @ube.memory.collect(ptr %ctx)")
    Call AddLine(State, "  store atomic i64 " & SavedError & ", ptr %err monotonic, align 8")
    Call AddLine(State, "  ret i1 " & Outcome)
    Call AddLine(State, "}")
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
    Call AddLine(State, "  %err = getelementptr %ube.thread, ptr %ctx, i32 0, i32 0")
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
    Call EmitReturns(Parsed, Bound, State)
    Call AddLine(State, "define internal i1 @ube.module.ensure." & CStr(ModuleIndex) & "(ptr %ctx) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %state.ptr = call ptr @ube.module.state(ptr %ctx, i64 " & CStr(ModuleIndex) & ")")
    Call AddLine(State, "  %owner.ptr = call ptr @ube.module.owner(ptr %ctx, i64 " & CStr(ModuleIndex) & ")")
    Call AddLine(State, "  br label %inspect")
    Call AddLine(State, "inspect:")
    Call AddLine(State, "  %state = load atomic i64, ptr %state.ptr acquire, align 8")
    Call AddLine(State, "  %done = icmp eq i64 %state, 2")
    Call AddLine(State, "  br i1 %done, label %complete, label %claim")
    Call AddLine(State, "claim:")
    Call AddLine(State, "  %pair = cmpxchg ptr %state.ptr, i64 0, i64 1 acq_rel acquire")
    Call AddLine(State, "  %won = extractvalue { i64, i1 } %pair, 1")
    Call AddLine(State, "  br i1 %won, label %initialize, label %owner")
    Call AddLine(State, "owner:")
    Call AddLine(State, "  %owning = load atomic ptr, ptr %owner.ptr acquire, align 8")
    Call AddLine(State, "  %same = icmp eq ptr %owning, %ctx")
    Call AddLine(State, "  br i1 %same, label %complete, label %inspect")
    Call AddLine(State, "initialize:")
    Call AddLine(State, "  store atomic ptr %ctx, ptr %owner.ptr release, align 8")
    Call AddLine(State, "  %result = call { i1, i64 } @ube.module.initialize." & CStr(ModuleIndex) & "(ptr %ctx)")
    Call AddLine(State, "  store atomic ptr null, ptr %owner.ptr release, align 8")
    Call AddLine(State, "  store atomic i64 2, ptr %state.ptr release, align 8")
    Call AddLine(State, "  br label %complete")
    Call AddLine(State, "complete:")
    Call AddLine(State, "  ret i1 true")
    Call AddLine(State, "}")
    Call AddLine(State, "")
End Sub

' Emits caller-owned context setup and manifest-order startup without hidden runtime allocation.
Private Sub EmitContext(ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef State As EmissionState)
    Dim Words As Long
    Dim Index As Long
    Words = 853 + Parsed.ModuleCount + Parsed.ModuleCount + State.FieldCount
    Call AddLine(State, "%ube.resource = type { i64, ptr, ptr, i64, i64 }")
    Call AddLine(State, "%ube.thread = type { i64, i64, ptr, ptr }")
    Call AddLine(State, "%ube.program = type { [" & CStr(Parsed.ModuleCount) & " x i64], [" & CStr(State.FieldCount) & " x i64], ptr, i64, i64, [64 x %ube.resource], i64, i64, i64, [" & CStr(Parsed.ModuleCount) & " x ptr], ptr, i64, i64, [65 x [8 x i64]] }")
    Call AddLine(State, "%ube.context = type { i64, i64, ptr, ptr, %ube.program }")
    Call AddLine(State, "")
    Call AddLine(State, "declare { i16, i1 } @llvm.sadd.with.overflow.i16(i16, i16)")
    Call AddLine(State, "declare { i32, i1 } @llvm.sadd.with.overflow.i32(i32, i32)")
    Call AddLine(State, "declare { i64, i1 } @llvm.sadd.with.overflow.i64(i64, i64)")
    Call AddLine(State, "declare { i16, i1 } @llvm.smul.with.overflow.i16(i16, i16)")
    Call AddLine(State, "declare { i32, i1 } @llvm.smul.with.overflow.i32(i32, i32)")
    Call AddLine(State, "declare { i64, i1 } @llvm.smul.with.overflow.i64(i64, i64)")
    Call AddLine(State, "declare { i16, i1 } @llvm.ssub.with.overflow.i16(i16, i16)")
    Call AddLine(State, "declare { i32, i1 } @llvm.ssub.with.overflow.i32(i32, i32)")
    Call AddLine(State, "declare { i64, i1 } @llvm.ssub.with.overflow.i64(i64, i64)")
    Call AddLine(State, "")
    Call AddLine(State, "define i64 @ube.context.size() {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  ret i64 " & CStr(Words * 8) & "")
    Call AddLine(State, "}")
    Call AddLine(State, "define void @ube.context.init(ptr %ctx) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  br label %zero")
    Call AddLine(State, "zero:")
    Call AddLine(State, "  %index = phi i64 [ 0, %entry ], [ %next, %zero ]")
    Call AddLine(State, "  %slot = getelementptr i64, ptr %ctx, i64 %index")
    Call AddLine(State, "  store atomic volatile i64 0, ptr %slot monotonic, align 8")
    Call AddLine(State, "  %next = add i64 %index, 1")
    Call AddLine(State, "  %more = icmp ult i64 %next, " & CStr(Words) & "")
    Call AddLine(State, "  br i1 %more, label %zero, label %done")
    Call AddLine(State, "done:")
    Call AddLine(State, "  %program = getelementptr %ube.context, ptr %ctx, i32 0, i32 4")
    Call AddLine(State, "  call void @ube.thread.init(ptr %ctx, ptr %program, ptr null)")
    Call AddLine(State, "  ret void")
    Call AddLine(State, "}")
    Call AddLine(State, "define i1 @ube.context.dispose(ptr %ctx) {")
    Call AddLine(State, "entry:")
    Call AddLine(State, "  %depth.ptr = getelementptr %ube.thread, ptr %ctx, i32 0, i32 1")
    Call AddLine(State, "  %depth = load atomic i64, ptr %depth.ptr monotonic, align 8")
    Call AddLine(State, "  %depth.active = icmp ne i64 %depth, 0")
    Call AddLine(State, "  %files.empty = call i1 @ube.resource.empty(ptr %ctx)")
    Call AddLine(State, "  %files.live = xor i1 %files.empty, true")
    Call AddLine(State, "  %program = call ptr @ube.thread.program(ptr %ctx)")
    Call AddLine(State, "  %workers.ptr = getelementptr %ube.program, ptr %program, i32 0, i32 7")
    Call AddLine(State, "  %workers = load atomic i64, ptr %workers.ptr acquire, align 8")
    Call AddLine(State, "  %workers.live = icmp ne i64 %workers, 0")
    Call AddLine(State, "  %owners.active = or i1 %depth.active, %files.live")
    Call AddLine(State, "  %active = or i1 %owners.active, %workers.live")
    Call AddLine(State, "  br i1 %active, label %busy, label %threads")
    Call AddLine(State, "busy:")
    Call AddLine(State, "  ret i1 false")
    Call AddLine(State, "threads:")
    Call AddLine(State, "  %threads.disposed = call i1 @ube.thread.program.dispose(ptr %ctx)")
    Call AddLine(State, "  br i1 %threads.disposed, label %release, label %busy")
    Call AddLine(State, "release:")
    For Index = 1 To Bound.SymbolCount
        If State.FieldIndex(Index) >= 0 And Bound.Symbols(Index).ArrayRank = 1 Then
    Call AddLine(State, "  %array." & CStr(Index) & " = call ptr @ube.storage.address(ptr %ctx, i64 " & CStr(State.FieldIndex(Index)) & ")")
    Call AddLine(State, "  call void @ube.array.clear(ptr %ctx, ptr %array." & CStr(Index) & ")")
        End If
    Next Index
    Call AddLine(State, "  %collected = call i1 @ube.memory.collect(ptr %ctx)")
    Call AddLine(State, "  %head.ptr = call ptr @ube.memory.head(ptr %ctx)")
    Call AddLine(State, "  %head = load ptr, ptr %head.ptr")
    Call AddLine(State, "  %empty = icmp eq ptr %head, null")
    Call AddLine(State, "  ret i1 %empty")
    Call AddLine(State, "}")
    Call AddLine(State, "define i1 @ube.project.init(ptr %ctx) {")
    Call AddLine(State, "entry:")
    For Index = 0 To Parsed.ModuleCount - 1
    Call AddLine(State, "  %module." & CStr(Index) & " = call i1 @ube.module.ensure." & CStr(Index) & "(ptr %ctx)")
    Next Index
    Call AddLine(State, "  ret i1 true")
    Call AddLine(State, "}")
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
    Call AddLine(State, "  br label %shutdown")
    Call AddLine(State, "unavailable:")
    Call AddLine(State, "  br label %shutdown")
    Call AddLine(State, "shutdown:")
    Call AddLine(State, "  %fresh.success = phi i1 [ true, %complete ], [ false, %unavailable ]")
    Call AddLine(State, "  %exit.status = phi i32 [ %status, %complete ], [ 1, %unavailable ]")
    Call AddLine(State, "  call void @ube.thread.root.complete(ptr @ube.entry.context, i1 %fresh.success)")
    Call AddLine(State, "  %drained = call i1 @ube.thread.drain(ptr @ube.entry.context)")
    Call AddLine(State, "  %disposed = call i1 @ube.context.dispose(ptr @ube.entry.context)")
    Call AddLine(State, "  %clean = and i1 %drained, %disposed")
    Call AddLine(State, "  ; Defensive native-launch transport status, never a successful UBE FAIL value.")
    Call AddLine(State, "  %final.status = select i1 %clean, i32 %exit.status, i32 1")
    Call AddLine(State, "  ret i32 %final.status")
    Call AddLine(State, "}")
End Sub

' Produces deterministic complete IR only after checking the admitted native execution boundary.
Public Function EmitProject(ByRef Project As ProjectContext, ByRef Parsed As ParsedProject, ByRef Bound As BoundProject, ByRef IRText As String, ByRef Diagnostic As String) As Boolean
    Dim State As EmissionState
    Dim Index As Long
    Dim Kind As String
    Dim FileLines() As String
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
    Call EmitContext(Parsed, Bound, State)
    Call EmitMemoryRuntime(State)
    FileLines = Split(NativeFileIR() & NativeProcessIR() & NativeThreadIR(), vbCrLf)
    For Index = 0 To UBound(FileLines)
        Call AddLine(State, FileLines(Index))
    Next Index
    For Index = 0 To Parsed.ModuleCount - 1
        Call EmitModuleInitializer(Parsed, Bound, State, Index)
        If State.Failed Then Exit For
    Next Index
    For Index = 1 To Bound.SymbolCount
        Kind = Bound.Symbols(Index).Kind
        If Bound.Symbols(Index).Origin = "source" Then
            If Kind = "sub" Or Kind = "function" Then
                If Bound.Symbols(Index).BindingId = "array.length" Or Bound.Symbols(Index).BindingId = "memory.copybytes" Or Bound.Symbols(Index).BindingId = "array.tryresize" Or Bound.Symbols(Index).BindingId = "array.trycopy" Then
                    Call EmitArrayIntrinsic(Bound, State, Index)
                ElseIf Left$(Bound.Symbols(Index).BindingId, 7) = "thread." Then
                    Call EmitThreadIntrinsic(Bound, State, Index)
                ElseIf Left$(Bound.Symbols(Index).BindingId, 5) = "file." Or Left$(Bound.Symbols(Index).BindingId, 5) = "path." Or Left$(Bound.Symbols(Index).BindingId, 10) = "directory." Or Left$(Bound.Symbols(Index).BindingId, 8) = "process." Or Left$(Bound.Symbols(Index).BindingId, 7) = "system." Or Bound.Symbols(Index).BindingId = "error.set" Then
                    Call EmitFileIntrinsic(Bound, State, Index)
                Else
                    Call EmitProcedure(Parsed, Bound, State, Index)
                End If
            End If
        End If
        If State.Failed Then Exit For
    Next Index
    For Index = 1 To Parsed.NodeCount
        If Parsed.Nodes(Index).Kind = "thread-start" Then Call EmitThreadThunk(Parsed, Bound, State, Index)
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
