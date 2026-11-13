UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeCompilation"
' Coordinates bounded independent emission while retaining ordered results and private publication.
Public Const MaximumWorkers As Long = 2
Public Type RangeResult
    FirstSymbol As Long
    LastSymbol As Long
    ThreadId As LongLong
    WaitError As Long
    WaitFailed As Boolean
    SourceFinished As Boolean
    Completed As Boolean
    Cancelled As Boolean
    FileToken As Long
    Failure As Long
    State As NativeEmission.EmissionState
End Type

' Allocates retained work ownership before any worker is published.
Private Intrinsic Function ResizeRanges(ByRef Values() As RangeResult, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeRanges.UBE_Primitive = "Array.TryResize"
End Function

' Reads only the caller-owned range descriptor capacity.
Private Intrinsic Function RangeCount(ByRef Values() As RangeResult) As Long
Attribute RangeCount.UBE_Primitive = "Array.Length"
End Function

' Allocates deterministic source-scope weights without copying semantic facts.
Private Intrinsic Function ResizeWeights(ByRef Values() As Long, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeWeights.UBE_Primitive = "Array.TryResize"
End Function

' Partitions the stable symbol order by existing bound-node counts; empty ranges remain valid.
Private Function TryPartition(ByRef Expressions() As ExpressionBinder.BoundExpression, ByVal NodeCount As Long, ByVal SymbolCount As Long, ByVal WorkerCount As Long, ByRef Ranges() As RangeResult) As Boolean
    Dim Weights() As Long
    Dim Index As Long
    Dim Scope As Long
    Dim Total As Long
    Dim Prefix As Long
    Dim Boundary As Long
    On Error GoTo Failed
    If WorkerCount < 1 Or WorkerCount > MaximumWorkers Then Exit Function
    If Not ResizeRanges(Ranges, MaximumWorkers + 1, False) Then Exit Function
    Ranges(0).FirstSymbol = 1
    Ranges(0).LastSymbol = SymbolCount
    If WorkerCount = 1 Then TryPartition = True: Exit Function
    If Not ResizeWeights(Weights, SymbolCount, False) Then Exit Function
    Do While Index < NodeCount
        Scope = Expressions(Index).ScopeSymbol
        If Scope > 0 And Scope <= SymbolCount Then
            Weights(Scope - 1) = Weights(Scope - 1) + 1
            Total = Total + 1
        End If
        Index = Index + 1
    Loop
    Boundary = 1
    Do While Boundary < SymbolCount
        Prefix = Prefix + Weights(Boundary - 1)
        If Prefix + Prefix >= Total Then Exit Do
        Boundary = Boundary + 1
    Loop
    Ranges(0).LastSymbol = Boundary
    Ranges(1).FirstSymbol = Boundary + 1
    Ranges(1).LastSymbol = SymbolCount
    TryPartition = True
    Exit Function
Failed:
End Function

' Emits with private numbering, traversal and buffering; shared semantic facts are read-only until join.
' The ByVal catalog supplies each renderer an owned copy of the validated immutable bytes.
Private Sub EmitRange(ByRef Nodes() As SourceParser.SyntaxNode, ByRef Symbols() As DeclarationBinder.BoundSymbol, ByVal SymbolCount As Long, ByRef Expressions() As ExpressionBinder.BoundExpression, ByRef Layouts() As AggregateLayout.StorageFact, ByRef Plans() As NativePlanning.NativeSymbolPlan, ByRef Pins() As Long, ByRef Escapes() As NativeEscapes.EscapeFact, ByRef Roles() As Long, ByVal NodeCount As Long, ByVal Catalog() As Byte, ByRef Stage() As Byte, ByVal Ordinal As Long, ByRef Result As RangeResult, ByVal WorkBase As Long, ByVal ByteBase As Long, ByVal LineBase As Long)
    Dim Buffer() As Byte
    Dim Seen() As Long
    Dim Nexts() As Long
    Dim Path() As Byte
    Dim Symbol As Long
    Dim Status As Boolean
    On Error GoTo Failed
    If Not LLVMWriter.TryInitialize(Result.State.Text, Buffer) Then GoTo Cleanup
    Result.State.Work = WorkBase
    Result.State.Text.TotalBytes = ByteBase
    Result.State.Text.LineCount = LineBase
    If Not NativeLowering.TryInitializeTraversal(NodeCount, Seen, Nexts, Result.State) Then GoTo Cleanup
    If Not OutputPublication.TryEmissionPath(Stage, Ordinal, Path, Result.Failure) Then GoTo Cleanup
    If Not FilePrimitives.TryCreateNew(Path, Result.FileToken, Result.Failure) Then GoTo Cleanup
    Symbol = Result.FirstSymbol
    Do While Symbol <= Result.LastSymbol
        If ThreadPrimitives.StopRequested() Then Result.Cancelled = True: GoTo Cleanup
        If Not NativeLowering.TryEmitRange(Nodes, Symbols, SymbolCount, Expressions, Layouts, Plans, Pins, Escapes, Roles, NodeCount, Catalog, Symbol, Symbol, Result.FileToken, Result.State, Buffer, Seen, Nexts) Then GoTo Cleanup
        Symbol = Symbol + 1
    Loop
    If Not LLVMWriter.TryFinish(Result.State.Text, Buffer, Result.FileToken) Then GoTo Cleanup
    Result.Completed = True
Cleanup:
    If Result.FileToken <> 0 Then
        If Not FileBytes.TryClosePreservingError(Result.FileToken, Result.Failure) Then Result.Completed = False
    End If
    Exit Sub
Failed:
    Result.Completed = False
    Result.State.Text.Failed = True
    Result.State.Text.Failure = 1
    Result.State.Text.ErrorNumber = Err.Number
    GoTo Cleanup
End Sub

' Observes completed source/capture access; runtime-owned native handles remain retained for program drain.
' Fresh worker failure is recorded separately even when its error number is zero.
Private Function TryObserveCompletion(ByRef Result As RangeResult) As Boolean
    Dim Observed As Long
    Dim Status As Long
    On Error GoTo Failed
    If Result.ThreadId = 0 Then TryObserveCompletion = True: Exit Function
    If Result.SourceFinished And Not Result.WaitFailed Then TryObserveCompletion = True: Exit Function
    Do
        If ThreadPrimitives.StopRequested() Then Status = ThreadPrimitives.RequestStop(Result.ThreadId)
        Observed = ThreadPrimitives.Wait(Result.ThreadId, 50)
        If Observed = 1 Then Result.SourceFinished = True: TryObserveCompletion = True: Exit Function
        Call ThreadPrimitives.Yield()
    Loop
Failed:
    Result.WaitError = Err.Number
    Result.WaitFailed = True
    If Not ThreadPrimitives.IsAlive(Result.ThreadId) Then Result.SourceFinished = True
End Function

' Observes every started source worker before closing any chunk, retaining unsuccessful owners for retry.
Public Function TryCleanup(ByRef Ranges() As RangeResult, ByRef Failure As Long) As Boolean
    Dim Index As Long
    Dim Count As Long
    Dim Status As Boolean
    Dim Complete As Boolean = True
    On Error GoTo Failed
    Count = RangeCount(Ranges)
    Do While Index < Count
        Status = TryObserveCompletion(Ranges(Index))
        If Ranges(Index).ThreadId <> 0 And Not Ranges(Index).SourceFinished Then Complete = False
        Index = Index + 1
    Loop
    Index = 0
    Do While Index < Count
        If Ranges(Index).ThreadId = 0 Or Ranges(Index).SourceFinished Then
            If Ranges(Index).FileToken <> 0 Then
                If Not FileBytes.TryClosePreservingError(Ranges(Index).FileToken, Failure) Then Complete = False
            End If
        End If
        Index = Index + 1
    Loop
    TryCleanup = Complete
    Exit Function
Failed:
    Failure = 1
End Function

' Copies a closed private chunk after ordered quota checks; worker validation and exact length remain authoritative.
Private Function TryAppendRange(ByRef Stage() As Byte, ByVal Ordinal As Long, ByRef Range As RangeResult, ByVal Token As Long, ByRef State As NativeEmission.EmissionState, ByRef Buffer() As Byte) As Boolean
    Dim Path() As Byte
    Dim ReadBuffer() As Byte
    Dim Length As Long
    Dim Offset As Long
    Dim Wanted As Long
    Dim Progress As Long
    Dim Status As Boolean
    On Error GoTo Failed
    If Not OutputPublication.TryEmissionPath(Stage, Ordinal, Path, Range.Failure) Then Exit Function
    If Not FilePrimitives.TryOpen(Path, LLVMWriter.MaximumBytes, Range.FileToken, Length, Range.Failure) Then Exit Function
    If Length <> Range.State.Text.TotalBytes Then Range.Failure = 1: GoTo Cleanup
    If Not BufferPrimitives.TryResizeBytes(ReadBuffer, LLVMWriter.BufferSize, False) Then GoTo Cleanup
    Do While Offset < Length
        Wanted = Length - Offset
        If Wanted > LLVMWriter.BufferSize Then Wanted = LLVMWriter.BufferSize
        If Not FilePrimitives.TryRead(Range.FileToken, ReadBuffer, 0, Wanted, Progress, Range.Failure) Then GoTo Cleanup
        If Progress <= 0 Or Progress > Wanted Then Range.Failure = 1: GoTo Cleanup
        If Not FileBytes.TryWriteByteRange(Token, ReadBuffer, 0, Progress, Range.Failure) Then GoTo Cleanup
        Offset = Offset + Progress
    Loop
    If Not FilePrimitives.TryRead(Range.FileToken, ReadBuffer, 0, 1, Progress, Range.Failure) Then GoTo Cleanup
    If Progress <> 0 Then Range.Failure = 1: GoTo Cleanup
    State.Text.TotalBytes = State.Text.TotalBytes + Range.State.Text.TotalBytes
    State.Text.LineCount = State.Text.LineCount + Range.State.Text.LineCount
    TryAppendRange = True
Cleanup:
    If Not FileBytes.TryClosePreservingError(Range.FileToken, Range.Failure) Then TryAppendRange = False
    Exit Function
Failed:
    Range.Failure = 1
    GoTo Cleanup
End Function

' Preserves the accepted diagnostic cursor without adding an aggregate temporary to the request frame.
Private Sub PrepareReplay(ByRef Source As RangeResult, ByRef Replay As RangeResult, ByRef State As NativeEmission.EmissionState)
    Replay.FirstSymbol = Source.FirstSymbol
    Replay.LastSymbol = Source.LastSymbol
    Replay.State = State
End Sub

' Prepares facts once, joins all writers, checks cumulative charges and assembles only in symbol order.
Public Function TryEmit(ByRef Bytes() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByRef Nodes() As SourceParser.SyntaxNode, ByRef Modules() As ProjectSyntax.ParsedModule, ByRef Counts As ProjectSyntax.ProjectCounts, ByRef PackageName() As Byte, ByVal IsExecutable As Boolean, ByRef Catalog() As Byte, ByRef RuntimeText() As Byte, ByRef Stage() As Byte, ByVal WorkerCount As Long, ByVal Token As Long, ByRef Ranges() As RangeResult, ByRef State As NativeEmission.EmissionState, ByRef Diagnostic As DeclarationBinder.BindingDiagnostic) As Boolean
    Dim Symbols() As DeclarationBinder.BoundSymbol
    Dim Expressions() As ExpressionBinder.BoundExpression
    Dim Layouts() As AggregateLayout.StorageFact
    Dim Plans() As NativePlanning.NativeSymbolPlan
    Dim Pins() As Long
    Dim Escapes() As NativeEscapes.EscapeFact
    Dim Roles() As Long
    Dim Dependencies() As Byte
    Dim Buffer() As Byte
    Dim Seen() As Long
    Dim Nexts() As Long
    Dim Summary As NativePlanning.NativePlanSummary
    Dim SymbolCount As Long
    Dim EntrySymbol As Long
    Dim Index As Long
    Dim Failure As Long
    Dim Status As Boolean
    Dim Accepted As Boolean
    On Error GoTo Failed
    If WorkerCount < 1 Or WorkerCount > MaximumWorkers Then GoTo Rejected
    If Not NativeLowering.TryInitialize(Catalog, RuntimeText, State, Buffer) Then GoTo Rejected
    If Not NativeLowering.TryPrepare(Bytes, Tokens, Nodes, Modules, Counts, PackageName, IsExecutable, Symbols, SymbolCount, EntrySymbol, Expressions, Layouts, Plans, Pins, Escapes, Roles, Dependencies, Summary, Diagnostic) Then GoTo Rejected
    If Not TryPartition(Expressions, Counts.NodeCount, SymbolCount, WorkerCount, Ranges) Then GoTo Rejected
    If Not NativeLowering.TryBegin(Symbols, SymbolCount, Layouts, Plans, Roles, Summary, Counts.NodeCount, Catalog, RuntimeText, Token, State, Buffer, Seen, Nexts) Then GoTo Rejected
    If Not LLVMWriter.TryFinish(State.Text, Buffer, Token) Then GoTo Rejected
    If Not ResizeWeights(Seen, 0, False) Then GoTo Rejected
    If Not ResizeWeights(Nexts, 0, False) Then GoTo Rejected
    Do While Index < WorkerCount
        If ThreadPrimitives.StopRequested() Then GoTo Rejected
        If WorkerCount = 1 Then
            Call EmitRange(Nodes, Symbols, SymbolCount, Expressions, Layouts, Plans, Pins, Escapes, Roles, Counts.NodeCount, Catalog, Stage, Index, Ranges(Index), 0, 0, 0)
        Else
            Ranges(Index).ThreadId = CallNew EmitRange(Nodes, Symbols, SymbolCount, Expressions, Layouts, Plans, Pins, Escapes, Roles, Counts.NodeCount, Catalog, Stage, Index, Ranges(Index), 0, 0, 0)
            If Ranges(Index).ThreadId = 0 Then GoTo Rejected
        End If
        Index = Index + 1
    Loop
    Index = 0
    Do While Index < WorkerCount
        Status = TryObserveCompletion(Ranges(Index))
        If Ranges(Index).ThreadId <> 0 And Not Ranges(Index).SourceFinished Then GoTo Rejected
        Index = Index + 1
    Loop
    Index = 0
    Do While Index < WorkerCount
        If Ranges(Index).WaitFailed Then
            State.Text.ErrorNumber = Ranges(Index).WaitError
            State.Text.Failure = 1
            GoTo Rejected
        End If
        If Ranges(Index).State.Text.Failure = 2 Or (Ranges(Index).State.FailureCode = 6 And Ranges(Index).State.FailureReason = 56) Or Ranges(Index).State.Work > NativeEmission.MaximumWork - State.Work Or Ranges(Index).State.Text.TotalBytes > LLVMWriter.MaximumBytes - State.Text.TotalBytes Or Ranges(Index).State.Text.LineCount > LLVMWriter.MaximumLines - State.Text.LineCount Then
            Call PrepareReplay(Ranges(Index), Ranges(MaximumWorkers), State)
            Call EmitRange(Nodes, Symbols, SymbolCount, Expressions, Layouts, Plans, Pins, Escapes, Roles, Counts.NodeCount, Catalog, Stage, MaximumWorkers, Ranges(MaximumWorkers), State.Work, State.Text.TotalBytes, State.Text.LineCount)
            State = Ranges(MaximumWorkers).State
            GoTo Rejected
        End If
        If Not Ranges(Index).Completed Then
            State = Ranges(Index).State
            If State.Text.Failure = 0 Then State.Text.Failure = Ranges(Index).Failure
            GoTo Rejected
        End If
        If Not TryAppendRange(Stage, Index, Ranges(Index), Token, State, Buffer) Then GoTo Rejected
        State.Work = State.Work + Ranges(Index).State.Work
        State.CurrentSymbol = Ranges(Index).State.CurrentSymbol
        State.CurrentModule = Ranges(Index).State.CurrentModule
        State.CurrentNode = Ranges(Index).State.CurrentNode
        State.ErrorNode = Ranges(Index).State.ErrorNode
        Index = Index + 1
    Loop
    If Not NativeLowering.TryEnd(IsExecutable, EntrySymbol, Catalog, Token, State, Buffer) Then GoTo Rejected
    Accepted = True
Cleanup:
    If Not TryCleanup(Ranges, Failure) Then Accepted = False
    If Accepted Then TryEmit = True: Exit Function
    State.Text.Failed = True
    If State.Text.Failure = 0 Then State.Text.Failure = 1
    Call NativeLowering.ReportFailure(Nodes, Modules, Counts, State, Diagnostic)
    Exit Function
Rejected:
    GoTo Cleanup
Failed:
    State.Text.Failed = True
    State.Text.Failure = 1
    State.Text.ErrorNumber = Err.Number
    GoTo Cleanup
End Function
