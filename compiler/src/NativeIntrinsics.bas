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
    Dim LayoutSymbol As Long
    On Error GoTo Failed
    If State.Failed Then Exit Function
    Do While Index < SymbolCount
        If Symbols(Index).Kind = SourceParser.FunctionNode Or Symbols(Index).Kind = SourceParser.SubNode Then
            Node = Symbols(Index).DeclarationNode
            Role = Roles(Node - 1)
            Template = 0
            Stride = 0
            LayoutSymbol = 0
            If Role = PrimitiveRoles.MemoryCollect Then Template = LLVMTemplates.IntrinsicMemoryCollect
            If Role = PrimitiveRoles.ManagedWorkspace Then Template = LLVMTemplates.IntrinsicManagedWorkspace
            If Role = PrimitiveRoles.ArrayLength Then Template = LLVMTemplates.IntrinsicArrayLength
            If Role = PrimitiveRoles.MemoryCopyBytes Then Template = LLVMTemplates.IntrinsicMemoryCopyBytes
            If Role = PrimitiveRoles.ArrayTryResize Then Template = LLVMTemplates.IntrinsicArrayResize
            If Role = PrimitiveRoles.ArrayTryCopy Then Template = LLVMTemplates.IntrinsicArrayCopy
            If Role = PrimitiveRoles.ArrayMove Then Template = LLVMTemplates.IntrinsicArrayMove
            If Role = PrimitiveRoles.ManagedBeginCollection Then Template = LLVMTemplates.IntrinsicManagedBeginCollection
            If Role = PrimitiveRoles.ManagedEndCollection Then Template = LLVMTemplates.IntrinsicManagedEndCollection
            If Role = PrimitiveRoles.ManagedSnapshotCounts Then Template = LLVMTemplates.IntrinsicManagedSnapshotCounts
            If Role = PrimitiveRoles.ManagedAllocationAt Then Template = LLVMTemplates.IntrinsicManagedAllocationAt
            If Role = PrimitiveRoles.ManagedRootAt Then Template = LLVMTemplates.IntrinsicManagedRootAt
            If Role = PrimitiveRoles.ManagedMark Then Template = LLVMTemplates.IntrinsicManagedMark
            If Role = PrimitiveRoles.ManagedMarked Then Template = LLVMTemplates.IntrinsicManagedMarked
            If Role = PrimitiveRoles.ManagedEdgeCount Then Template = LLVMTemplates.IntrinsicManagedEdgeCount
            If Role = PrimitiveRoles.ManagedEdgeAt Then Template = LLVMTemplates.IntrinsicManagedEdgeAt
            If Role = PrimitiveRoles.ManagedSealCollection Then Template = LLVMTemplates.IntrinsicManagedSealCollection
            If Role = PrimitiveRoles.ManagedReclaim Then Template = LLVMTemplates.IntrinsicManagedReclaim
            If Role = PrimitiveRoles.TextByteLength Then Template = LLVMTemplates.IntrinsicTextByteLength
            If Role = PrimitiveRoles.TextScalarLength Then Template = LLVMTemplates.IntrinsicTextScalarLength
            If Role = PrimitiveRoles.TextReadByte Then Template = LLVMTemplates.IntrinsicTextReadByte
            If Role = PrimitiveRoles.TextCreate Then Template = LLVMTemplates.IntrinsicTextCreate
            If Role = PrimitiveRoles.TextWriteByte Then Template = LLVMTemplates.IntrinsicTextWriteByte
            If Role = PrimitiveRoles.TextPublish Then Template = LLVMTemplates.IntrinsicTextPublish
            If Role = PrimitiveRoles.TextAbandon Then Template = LLVMTemplates.IntrinsicTextAbandon
            If Role = PrimitiveRoles.FileTryOpen Then Template = LLVMTemplates.IntrinsicFileOpen
            If Role = PrimitiveRoles.FileTryCreateNew Then Template = LLVMTemplates.IntrinsicFileCreateNew
            If Role = PrimitiveRoles.FileTryRead Then Template = LLVMTemplates.IntrinsicFileRead
            If Role = PrimitiveRoles.FileTryWrite Then Template = LLVMTemplates.IntrinsicFileWrite
            If Role = PrimitiveRoles.FileTryClose Then Template = LLVMTemplates.IntrinsicFileClose
            If Role = PrimitiveRoles.FileTryFlush Then Template = LLVMTemplates.IntrinsicFileFlush
            If Role = PrimitiveRoles.ErrorSet Then Template = LLVMTemplates.IntrinsicErrorSet
            If Role = PrimitiveRoles.SystemReadCommandLine Then Template = LLVMTemplates.IntrinsicSystemCommandLine
            If Role = PrimitiveRoles.SystemWriteStandard Then Template = LLVMTemplates.IntrinsicSystemWrite
            If Role = PrimitiveRoles.FileFinalPath Then Template = LLVMTemplates.IntrinsicFileFinalPath
            If Role = PrimitiveRoles.PathFullPath Then Template = LLVMTemplates.IntrinsicPathFullPath
            If Role = PrimitiveRoles.PathCompareOrdinal Then Template = LLVMTemplates.IntrinsicPathCompareOrdinal
            If Role = PrimitiveRoles.ProcessStart Then Template = LLVMTemplates.IntrinsicProcessStart
            If Role = PrimitiveRoles.ProcessWait Then Template = LLVMTemplates.IntrinsicProcessWait
            If Role = PrimitiveRoles.ProcessTerminate Then Template = LLVMTemplates.IntrinsicProcessTerminate
            If Role = PrimitiveRoles.ProcessClose Then Template = LLVMTemplates.IntrinsicProcessClose
            If Role = PrimitiveRoles.FileOpenDirectory Then Template = LLVMTemplates.IntrinsicFileOpenDirectory
            If Role = PrimitiveRoles.FileIdentity Then Template = LLVMTemplates.IntrinsicFileIdentity
            If Role = PrimitiveRoles.FileLength Then Template = LLVMTemplates.IntrinsicFileLength
            If Role = PrimitiveRoles.SystemExecutablePath Then Template = LLVMTemplates.IntrinsicSystemExecutablePath
            If Role = PrimitiveRoles.SystemMonotonicMilliseconds Then Template = LLVMTemplates.IntrinsicSystemMonotonicMilliseconds
            If Role = PrimitiveRoles.DirectoryCreate Then Template = LLVMTemplates.IntrinsicDirectoryCreate
            If Role = PrimitiveRoles.DirectoryRemove Then Template = LLVMTemplates.IntrinsicDirectoryRemove
            If Role = PrimitiveRoles.FileDelete Then Template = LLVMTemplates.IntrinsicFileDelete
            If Role = PrimitiveRoles.FileReplace Then Template = LLVMTemplates.IntrinsicFileReplace
            If Role = PrimitiveRoles.PathKind Then Template = LLVMTemplates.IntrinsicPathKind
            If Role = PrimitiveRoles.ThreadCurrentId Then Template = LLVMTemplates.IntrinsicThreadCurrentId
            If Role = PrimitiveRoles.ThreadIsAlive Then Template = LLVMTemplates.IntrinsicThreadIsAlive
            If Role = PrimitiveRoles.ThreadWait Then Template = LLVMTemplates.IntrinsicThreadWait
            If Role = PrimitiveRoles.ThreadRequestStop Then Template = LLVMTemplates.IntrinsicThreadRequestStop
            If Role = PrimitiveRoles.ThreadStopRequested Then Template = LLVMTemplates.IntrinsicThreadStopRequested
            If Role = PrimitiveRoles.ThreadYield Then Template = LLVMTemplates.IntrinsicThreadYield
            If Template <> 0 Then
                If Role = PrimitiveRoles.ArrayTryResize Or Role = PrimitiveRoles.ArrayTryCopy Then
                    Parameter = Symbols(Index).FirstParameter
                    Stride = Layouts(Symbols(Parameter - 1).DeclarationNode - 1).ElementCells
                    If Not ManagedLayouts.ValidPublication(Symbols, Layouts, Symbols(Parameter - 1).TypeCode, Symbols(Parameter - 1).TypeSymbol, Stride, Layouts(Symbols(Parameter - 1).DeclarationNode - 1).ManagedReferences) Then
                        State.Failed = True
                        State.Failure = 1
                        Exit Function
                    End If
                    If Layouts(Symbols(Parameter - 1).DeclarationNode - 1).ManagedReferences > 0 Then
                        LayoutSymbol = Symbols(Parameter - 1).TypeSymbol
                        If Role = PrimitiveRoles.ArrayTryResize Then Template = LLVMTemplates.IntrinsicArrayResizeManaged
                        If Role = PrimitiveRoles.ArrayTryCopy Then Template = LLVMTemplates.IntrinsicArrayCopyManaged
                    End If
                End If
                If LLVMFormat.TryFormat(State, Buffer, Token, Catalog, Template, Index + 1, Stride, LayoutSymbol, 0) = False Then Exit Function
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
