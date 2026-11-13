UBE SOURCE 1 MODULE
Attribute UBE_Name = "ContextProbe"
' Supplies validated private planning facts to the actual context emitter and writes its bytes.
Private OutputPath() As Byte
Private CatalogPath() As Byte

' Keeps synthetic planning records off the bounded native invocation frame.
Private Intrinsic Function ResizePlans(ByRef Values() As NativePlanning.NativeSymbolPlan, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizePlans.UBE_Primitive = "Array.TryResize"
End Function

' Receives separate output and catalog paths for each independent emission.
Public Function ConfigurePath(ByVal Kind As Long, ByVal Count As Long) As Boolean
    If Kind = 0 Then ConfigurePath = BufferPrimitives.TryResizeBytes(OutputPath, Count, False)
    If Kind = 1 Then ConfigurePath = BufferPrimitives.TryResizeBytes(CatalogPath, Count, False)
End Function

' Supplies a UTF-8 path through ordinary source calls.
Public Sub SetPathByte(ByVal Kind As Long, ByVal Index As Long, ByVal Value As Byte)
    If Kind = 0 Then OutputPath(Index) = Value
    If Kind = 1 Then CatalogPath(Index) = Value
End Sub

' Emits two modules, two owned arrays, one scalar and one non-context array.
Public Function Emit(ByVal Entry As Boolean) As Long
    Dim Symbols(0 To 3) As DeclarationBinder.BoundSymbol
    Dim Plans() As NativePlanning.NativeSymbolPlan
    Dim Summary As NativePlanning.NativePlanSummary
    Dim State As LLVMWriter.WriterState
    Dim Buffer() As Byte
    Dim Catalog() As Byte
    Dim Token As Long
    Dim Failure As Long
    Dim Result As Long
    On Error GoTo Failed
    If Not ResizePlans(Plans, 4, False) Then Emit = 10: Exit Function
    If FileBytes.TryReadAllBytes(CatalogPath, 1048576, Catalog, Token, Failure) = False Then Emit = 1: Exit Function
    If LLVMFormat.TryValidateCatalog(Catalog) = False Then Emit = 2: Exit Function
    Symbols(0).ArrayRank = 1
    Plans(0).ContextOffset = 0
    Plans(1).ContextOffset = 4
    Symbols(2).ArrayRank = 1
    Plans(2).ContextOffset = -1
    Symbols(3).ArrayRank = 1
    Plans(3).ContextOffset = 5
    Summary.SymbolCount = 4
    Summary.ModuleCount = 2
    Summary.ContextCells = 9
    Summary.EntrySymbol = 17
    If FilePrimitives.TryCreateNew(OutputPath, Token, Failure) = False Then Emit = 3: Exit Function
    If LLVMWriter.TryInitialize(State, Buffer) = False Then Result = 4: GoTo Cleanup
    If NativeContext.TryEmitContext(Symbols, Plans, Summary, State, Buffer, Token, Catalog) = False Then Result = 5: GoTo Cleanup
    If Entry Then
        If NativeContext.TryEmitEntry(17, State, Buffer, Token, Catalog) = False Then Result = 6: GoTo Cleanup
    End If
    If LLVMWriter.TryFinish(State, Buffer, Token) = False Then Result = 7: GoTo Cleanup
Cleanup:
    If FilePrimitives.TryClose(Token, Failure) = False Then Emit = 8: Exit Function
    Emit = Result
    Exit Function
Failed:
    Result = 9
    GoTo Cleanup
End Function
