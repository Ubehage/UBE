UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeEmission"
' Holds request-owned LLVM numbering and failure edges; source operations remain checked by the frontend.
Public Const MaximumWork As Long = 10000000
Public Type EmissionState
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
    FailureCount As Long
    CountedDepth As Boolean
    ErrorNode As Long
    FailureCode As Long
    FailureReason As Long
End Type

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
    State.Work = State.Work + 1
    Charge = True
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
    State.ValueNumber = 0
    State.BlockNumber = NodeCount
    State.FailureCount = 0
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
    On Error GoTo Failed
    If State.Text.Failed Then Exit Function
    TryLine = LLVMFormat.TryLine(State.Text, Buffer, Token, Catalog, Template, P0, P1, P2, P3)
    If State.Text.Failed Then State.ErrorNode = State.CurrentNode
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
