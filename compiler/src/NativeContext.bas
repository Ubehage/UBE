UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeContext"
' Emits private execution contexts and native launchers from matching validated plans.

' Emits exact module storage, disposal ownership and manifest-order initialization.
' The outer emitter supplies freshly checked facts and a validated template catalog.
Public Function TryEmitContext(ByRef Symbols() As DeclarationBinder.BoundSymbol, ByRef Plans() As NativePlanning.NativeSymbolPlan, ByRef Summary As NativePlanning.NativePlanSummary, ByRef State As LLVMWriter.WriterState, ByRef Buffer() As Byte, ByVal Token As Long, ByRef Catalog() As Byte) As Boolean
    Dim Words As Long
    Dim Bytes As Long
    Dim Index As Long
    On Error GoTo Failed
    If State.Failed Then Exit Function
    Words = 860 + Summary.ModuleCount + Summary.ModuleCount + Summary.ContextCells
    Bytes = Words + Words
    Bytes = Bytes + Bytes
    Bytes = Bytes + Bytes
    If LLVMFormat.TryFormat(State, Buffer, Token, Catalog, LLVMTemplates.ContextPrefix, Summary.ModuleCount, Summary.ContextCells, Bytes, Words) = False Then Exit Function
    Do While Index < Summary.SymbolCount
        If Plans(Index).ContextOffset >= 0 And Symbols(Index).ArrayRank = 1 Then
            If LLVMFormat.TryFormat(State, Buffer, Token, Catalog, LLVMTemplates.ContextArrayRelease, Index + 1, Plans(Index).ContextOffset, 0, 0) = False Then Exit Function
        End If
        Index = Index + 1
    Loop
    If LLVMFormat.TryFormat(State, Buffer, Token, Catalog, LLVMTemplates.ContextMiddle, 0, 0, 0, 0) = False Then Exit Function
    If Summary.ManagedRoles.CollectSymbol <> 0 Then
        If Not LLVMFormat.TryFormat(State, Buffer, Token, Catalog, LLVMTemplates.ManagedProjectInitialize, Summary.ManagedRoles.CollectSymbol, 0, 0, 0) Then Exit Function
    End If
    Index = 0
    Do While Index < Summary.SymbolCount
        If Plans(Index).IsReachable And (Symbols(Index).Kind = SourceParser.ModuleNode Or Symbols(Index).Kind = SourceParser.ClassNode) Then
            If LLVMFormat.TryFormat(State, Buffer, Token, Catalog, LLVMTemplates.EnsureModule, Symbols(Index).ModuleIndex, 0, 0, 0) = False Then Exit Function
        End If
        Index = Index + 1
    Loop
    If LLVMFormat.TryFormat(State, Buffer, Token, Catalog, LLVMTemplates.ContextSuffix, 0, 0, 0, 0) = False Then Exit Function
    TryEmitContext = True
    Exit Function
Failed:
    State.Failed = True
    State.Failure = 1
    State.ErrorNumber = Err.Number
End Function

' Emits the private executable launcher; successful procedure payload becomes process status.
Public Function TryEmitEntry(ByVal EntrySymbol As Long, ByRef State As LLVMWriter.WriterState, ByRef Buffer() As Byte, ByVal Token As Long, ByRef Catalog() As Byte) As Boolean
    TryEmitEntry = TryEmitEntryWithContext(EntrySymbol, False, State, Buffer, Token, Catalog)
End Function

' Rejects a hosted launch before execution-context or source initialization.
Public Function TryEmitEntryWithContext(ByVal EntrySymbol As Long, ByVal IsInIDE As Boolean, ByRef State As LLVMWriter.WriterState, ByRef Buffer() As Byte, ByVal Token As Long, ByRef Catalog() As Byte) As Boolean
    On Error GoTo Failed
    If State.Failed Then Exit Function
    If Not LLVMFormat.TryFormat(State, Buffer, Token, Catalog, LLVMTemplates.EntryStart, 0, 0, 0, 0) Then Exit Function
    If IsInIDE Then
        If Not LLVMFormat.TryFormat(State, Buffer, Token, Catalog, LLVMTemplates.HostedEntryGuard, 0, 0, 0, 0) Then Exit Function
    End If
    TryEmitEntryWithContext = LLVMFormat.TryFormat(State, Buffer, Token, Catalog, LLVMTemplates.Entry, EntrySymbol, 0, 0, 0)
    Exit Function
Failed:
    State.Failed = True
    State.Failure = 1
    State.ErrorNumber = Err.Number
End Function
