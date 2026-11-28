UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeEmission"
' Holds request-owned LLVM numbering and failure edges; source operations remain checked by the frontend.
Public Const MaximumWork As Long = 10000000
Public Const Cancelled As Long = 104
Public Type EmissionState
    ManagedRoles As ManagedSupport.RolePlan
    Text As LLVMWriter.WriterState
    Work As Long
    NodeCount As Long
    ValueNumber As Long
    BlockNumber As Long
    CurrentSymbol As Long
    CurrentModule As Long
    CurrentNode As Long
    CurrentNext As Long
    ResultSymbol As Long
    LoopExit As Long
    WhileExit As Long
    ForExit As Long
    OutermostLoopExit As Long
    LoopDepth As Long
    FirstConstruct As Long
    LastConstruct As Long
    FailureCount As Long
    CountedDepth As Boolean
    ErrorNode As Long
    FailureCode As Long
    FailureReason As Long
    FrameCells As Long
    FrameUsed As Long
End Type

' Preserves the first failure and records only a stop observed at this checkpoint.
Public Function TryContinue(ByRef State As EmissionState) As Boolean
    If State.Text.Failed Then Exit Function
    If ThreadPrimitives.StopRequested() Then
        State.Text.Failed = True
        State.FailureCode = Cancelled
        State.FailureReason = 0
        State.ErrorNode = State.CurrentNode
        Exit Function
    End If
    TryContinue = True
End Function

' Every traversal and generated identity contributes to one bounded emission request.
Public Function Charge(ByRef State As EmissionState) As Boolean
    If State.Text.Failed Then Exit Function
    If State.Work >= MaximumWork Then
        State.Text.Failed = True
        State.FailureCode = 6
        State.FailureReason = 56
        State.ErrorNode = State.CurrentNode
        Exit Function
    End If
    If State.Work Mod 256 = 0 Then
        If Not TryContinue(State) Then Exit Function
    End If
    State.Work = State.Work + 1
    Charge = True
End Function

' Parks only at boundaries where every live managed value already has an exact root.
Public Function Safepoint(ByRef State As EmissionState, ByRef Buffer() As Byte, ByVal Token As Long, ByRef Catalog() As Byte) As Boolean
    If State.Text.Failed Then Exit Function
    If State.ManagedRoles.CollectSymbol = 0 Then Safepoint = True: Exit Function
    Safepoint = TryLine(State, Buffer, Token, Catalog, LLVMTemplates.ManagedSafepoint, 0, 0, 0, 0)
End Function

' Source-node labels occupy 1..NodeCount, b0 returns success, and auxiliary labels follow them.
Public Sub BeginFunction(ByRef State As EmissionState, ByVal Symbol As Long, ByVal ModuleIndex As Long, ByVal NodeCount As Long, ByVal ResultSymbol As Long, ByVal CountedDepth As Boolean)
    State.CurrentSymbol = Symbol
    State.CurrentModule = ModuleIndex
    State.NodeCount = NodeCount
    State.ResultSymbol = ResultSymbol
    State.CountedDepth = CountedDepth
    State.CurrentNode = 0
    State.CurrentNext = 0
    State.LoopExit = 0
    State.WhileExit = 0
    State.ForExit = 0
    State.OutermostLoopExit = 0
    State.LoopDepth = 0
    State.FirstConstruct = 0
    State.LastConstruct = 0
    State.ValueNumber = 0
    State.BlockNumber = NodeCount
    State.FailureCount = 0
    State.FrameCells = 0
    State.FrameUsed = 0
End Sub

Public Function NewValue(ByRef State As EmissionState) As Long
    If Charge(State) = False Then Exit Function
    State.ValueNumber = State.ValueNumber + 1
    NewValue = State.ValueNumber
End Function

Public Function NewBlock(ByRef State As EmissionState) As Long
    If Charge(State) = False Then Exit Function
    State.BlockNumber = State.BlockNumber + 1
    NewBlock = State.BlockNumber
End Function

' Formats one instruction without exposing partially accepted compiler output.
Public Function TryLine(ByRef State As EmissionState, ByRef Buffer() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal Template As Long, ByVal P0 As LongLong, ByVal P1 As LongLong, ByVal P2 As LongLong, ByVal P3 As LongLong) As Boolean
    Dim Cells As LongLong
    On Error GoTo Failed
    If State.Text.Failed Then Exit Function
    ' Allocation templates name typed addresses inside one checked invocation block.
    If Template = LLVMTemplates.FrameControls Or Template = LLVMTemplates.ManagedEntryFrame Then Cells = 4
    If Template = LLVMTemplates.AllocateSlot Or Template = LLVMTemplates.AllocateAggregateTemporary Then Cells = P1
    If Template = LLVMTemplates.AllocateTemporary Or Template = LLVMTemplates.AllocatePin Or Template = LLVMTemplates.AllocateLocalOwner Or Template = LLVMTemplates.AllocateTemporaryOwner Then Cells = 1
    If Template = LLVMTemplates.ManagedTextSlots Then Cells = P0 + 4
    If Template = LLVMTemplates.ManagedSymbolRoot Or Template = LLVMTemplates.ManagedArraySymbolRoot Or Template = LLVMTemplates.ManagedTemporaryRoot Or Template = LLVMTemplates.ManagedArrayTemporaryRoot Then Cells = 4
    If Template = LLVMTemplates.ManagedLocalOwnerRoot Or Template = LLVMTemplates.ManagedTemporaryOwnerRoot Or Template = LLVMTemplates.ManagedPinRoot Then Cells = 4
    If Template = LLVMTemplates.EnumerationRoot Then Cells = 4
    If Template = LLVMTemplates.MonitorSlots Then Cells = 6
    If Template = LLVMTemplates.ConstructState Then Cells = 1
    If Template = LLVMTemplates.AllocateVariantConversion Then Cells = 1
    If Template = LLVMTemplates.ManagedIncomingOwnerRoot Then Cells = 5
    If Template = LLVMTemplates.InstanceRoot Then Cells = 5
    If Template = LLVMTemplates.ManagedTemporaryTable Then Cells = P0
    If Cells <> 0 Then
        If Cells < 0 Or State.FrameUsed < 0 Or State.FrameUsed > State.FrameCells Then GoTo InvalidFrame
        If Cells > State.FrameCells - State.FrameUsed Then GoTo InvalidFrame
        P3 = State.FrameUsed
        State.FrameUsed = State.FrameUsed + Cells
    End If
    TryLine = LLVMFormat.TryLine(State.Text, Buffer, Token, Catalog, Template, P0, P1, P2, P3)
    If State.Text.Failed Then State.ErrorNode = State.CurrentNode
    Exit Function
InvalidFrame:
    State.Text.Failed = True
    State.FailureCode = 9
    State.FailureReason = 62
    State.ErrorNode = State.CurrentNode
    Exit Function
Failed:
    State.Text.Failed = True
    State.Text.Failure = 1
    State.Text.ErrorNumber = Err.Number
    State.ErrorNode = State.CurrentNode
End Function

' Materializes a checked constant so all dynamic operands have deterministic SSA identities.
Public Function Literal(ByRef State As EmissionState, ByRef Buffer() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal Value As LongLong) As Long
    Dim Result As Long
    On Error GoTo Failed
    Result = NewValue(State)
    If Result = 0 Then Exit Function
    If TryLine(State, Buffer, Token, Catalog, LLVMTemplates.IntegerValue, Result, Value, 0, 0) = False Then Exit Function
    Literal = Result
    Exit Function
Failed:
    State.Text.Failed = True
    State.Text.Failure = 1
    State.Text.ErrorNumber = Err.Number
    State.ErrorNode = State.CurrentNode
End Function

' Seen stores the owning procedure/module symbol; continuations are statement labels or b0.
Private Function RegisterFailure(ByRef State As EmissionState, ByRef Seen() As Long, ByRef Continuations() As Long) As Boolean
    Dim Index As Long
    On Error GoTo Failed
    If State.Text.Failed Then Exit Function
    If State.CurrentNode < 1 Or State.CurrentNode > State.NodeCount Or State.CurrentSymbol < 1 Then
        State.Text.Failed = True
        State.FailureCode = 9
        State.FailureReason = 60
        State.ErrorNode = State.CurrentNode
        Exit Function
    End If
    Index = State.CurrentNode - 1
    If Seen(Index) = 0 Then
        Seen(Index) = State.CurrentSymbol
        Continuations(Index) = State.CurrentNext
        State.FailureCount = State.FailureCount + 1
    ElseIf Seen(Index) <> State.CurrentSymbol Or Continuations(Index) <> State.CurrentNext Then
        State.Text.Failed = True
        State.FailureCode = 9
        State.FailureReason = 60
        State.ErrorNode = State.CurrentNode
        Exit Function
    End If
    RegisterFailure = True
    Exit Function
Failed:
    State.Text.Failed = True
    State.Text.Failure = 1
    State.Text.ErrorNumber = Err.Number
    State.ErrorNode = State.CurrentNode
End Function

' An actual operation failure sets Err and uses the procedure's statement dispatcher.
Public Function GuardError(ByRef State As EmissionState, ByRef Buffer() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Continuations() As Long, ByVal FailedValue As Long, ByVal ErrorNumber As Long) As Boolean
    Dim FailedBlock As Long
    Dim SuccessBlock As Long
    On Error GoTo Failed
    If RegisterFailure(State, Seen, Continuations) = False Then Exit Function
    FailedBlock = NewBlock(State)
    SuccessBlock = NewBlock(State)
    If TryLine(State, Buffer, Token, Catalog, LLVMTemplates.ConditionalBranch, FailedValue, FailedBlock, SuccessBlock, 0) = False Then Exit Function
    If TryLine(State, Buffer, Token, Catalog, LLVMTemplates.Label, FailedBlock, 0, 0, 0) = False Then Exit Function
    If TryLine(State, Buffer, Token, Catalog, LLVMTemplates.StoreError, ErrorNumber, 0, 0, 0) = False Then Exit Function
    If TryLine(State, Buffer, Token, Catalog, LLVMTemplates.FailureBranch, 0, 0, 0, 0) = False Then Exit Function
    GuardError = TryLine(State, Buffer, Token, Catalog, LLVMTemplates.Label, SuccessBlock, 0, 0, 0)
    Exit Function
Failed:
    State.Text.Failed = True
    State.Text.Failure = 1
    State.Text.ErrorNumber = Err.Number
    State.ErrorNode = State.CurrentNode
End Function

' Converts a fresh Boolean operation status into a failure edge without touching sticky Err.
Public Function GuardStatus(ByRef State As EmissionState, ByRef Buffer() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Continuations() As Long, ByVal Success As Long) As Boolean
    Dim SuccessBlock As Long
    On Error GoTo Failed
    If RegisterFailure(State, Seen, Continuations) = False Then Exit Function
    SuccessBlock = NewBlock(State)
    If TryLine(State, Buffer, Token, Catalog, LLVMTemplates.CallSuccessBranch, Success, SuccessBlock, 0, 0) = False Then Exit Function
    GuardStatus = TryLine(State, Buffer, Token, Catalog, LLVMTemplates.Label, SuccessBlock, 0, 0, 0)
    Exit Function
Failed:
    State.Text.Failed = True
    State.Text.Failure = 1
    State.Text.ErrorNumber = Err.Number
    State.ErrorNode = State.CurrentNode
End Function

' Reads only the fresh success field before the caller may extract a usable result.
Public Function GuardCall(ByRef State As EmissionState, ByRef Buffer() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Continuations() As Long, ByVal Pair As Long) As Boolean
    Dim Success As Long
    On Error GoTo Failed
    Success = NewValue(State)
    If TryLine(State, Buffer, Token, Catalog, LLVMTemplates.CallSuccess, Success, Pair, 0, 0) = False Then Exit Function
    GuardCall = GuardStatus(State, Buffer, Token, Catalog, Seen, Continuations, Success)
    Exit Function
Failed:
    State.Text.Failed = True
    State.Text.Failure = 1
    State.Text.ErrorNumber = Err.Number
    State.ErrorNode = State.CurrentNode
End Function
