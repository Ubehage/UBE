UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeIntrinsics"
' Emits identity-bound primitive wrappers from freshly validated declarations and role facts.

' Selects reviewed private ABI bodies; ordinary source spellings never confer authority.
Public Function TryEmit(ByRef Symbols() As DeclarationBinder.BoundSymbol, ByVal SymbolCount As Long, ByRef Layouts() As AggregateLayout.StorageFact, ByRef Roles() As Long, ByRef State As LLVMWriter.WriterState, ByRef Buffer() As Byte, ByVal Token As Long, ByRef Catalog() As Byte) As Boolean
    Dim Index As Long
    Dim Node As Long
    Dim Role As Long
    Dim Template As Long
    Dim Parameter As Long
    Dim Stride As Long
    On Error GoTo Failed
    If State.Failed Then Exit Function
    Do While Index < SymbolCount
        If Symbols(Index).Kind = SourceParser.FunctionNode Or Symbols(Index).Kind = SourceParser.SubNode Then
            Node = Symbols(Index).DeclarationNode
            Role = Roles(Node - 1)
            Template = 0
            Stride = 0
            If Role = PrimitiveRoles.ArrayLength Then Template = LLVMTemplates.IntrinsicArrayLength
            If Role = PrimitiveRoles.MemoryCopyBytes Then Template = LLVMTemplates.IntrinsicMemoryCopyBytes
            If Role = PrimitiveRoles.ArrayTryResize Then Template = LLVMTemplates.IntrinsicArrayResize
            If Role = PrimitiveRoles.ArrayTryCopy Then Template = LLVMTemplates.IntrinsicArrayCopy
            If Role = PrimitiveRoles.FileTryOpen Then Template = LLVMTemplates.IntrinsicFileOpen
            If Role = PrimitiveRoles.FileTryCreateNew Then Template = LLVMTemplates.IntrinsicFileCreateNew
            If Role = PrimitiveRoles.FileTryRead Then Template = LLVMTemplates.IntrinsicFileRead
            If Role = PrimitiveRoles.FileTryWrite Then Template = LLVMTemplates.IntrinsicFileWrite
            If Role = PrimitiveRoles.FileTryClose Then Template = LLVMTemplates.IntrinsicFileClose
            If Role = PrimitiveRoles.FileTryFlush Then Template = LLVMTemplates.IntrinsicFileFlush
            If Role = PrimitiveRoles.ErrorSet Then Template = LLVMTemplates.IntrinsicErrorSet
            If Template <> 0 Then
                If Role = PrimitiveRoles.ArrayTryResize Or Role = PrimitiveRoles.ArrayTryCopy Then
                    Parameter = Symbols(Index).FirstParameter
                    Stride = Layouts(Symbols(Parameter - 1).DeclarationNode - 1).ElementCells
                End If
                If LLVMFormat.TryFormat(State, Buffer, Token, Catalog, Template, Index + 1, Stride, 0, 0) = False Then Exit Function
            End If
        End If
        Index = Index + 1
    Loop
    TryEmit = True
    Exit Function
Failed:
    State.Failed = True
    State.Failure = 1
    State.ErrorNumber = Err.Number
End Function
