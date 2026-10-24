UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Sub Step3Expect(ByVal Condition As Long, ByVal TestName As String, ByRef Failures As Long, ByRef Assertions As Long)
    Assertions = Assertions + 1
    If Condition <> 0 Then
        Print "PASS " & TestName
    Else
        Print "FAIL " & TestName
        Failures = Failures + 1
    End If
End Sub

Function Main() As Long
    If CommandArgumentCount() <> 2 Then
        Main = 2
        Exit Function
    End If
    Dim LocalePath As String = CommandArgument(0)
    Dim WorkRoot As String = CommandArgument(1)
    Dim Failures As Long = 0
    Dim Assertions As Long = 0
    Dim Diagnostics() As IdeDiagnostic
    Dim DiagnosticCount As Long = 0
    Dim DiagnosticCapacity As Long = 0
    Dim Documents() As IdeDocument
    Dim DocumentCount As Long = 0
    Dim DocumentCapacity As Long = 0
    Dim UndoEntries() As IdeUndoEntry
    Dim UndoCount As Long = 0
    Dim UndoCapacity As Long = 0
    Dim UndoCursor As Long = 0
    Dim Original As String = "UBE SOURCE 1 MODULE" & StringFromByte(10) & "Attribute UBE_Name = ""Sample""" & StringFromByte(10)
    Dim Edited As String = Original & "' edited" & StringFromByte(10)
    Dim RealPath As String = WorkRoot & "\real-document.bas"
    Call Step3Expect(WriteAllText(RealPath, Original) = 0, "real UBE source fixture publishes", Failures, Assertions)
    Dim DocumentIndex As Long = IdeOpenDocument(Documents, DocumentCount, DocumentCapacity, RealPath, ReadAllText(RealPath))
    Call Step3Expect(DocumentIndex = 0, "real UBE source opens through document model", Failures, Assertions)
    Call Step3Expect(IdeAttachDocumentView(Documents(DocumentIndex)) = 1, "first native view attaches", Failures, Assertions)
    Call Step3Expect(IdeApplyDocumentText(Documents, DocumentCount, DocumentIndex, Edited, UndoEntries, UndoCount, UndoCapacity, UndoCursor), "view edit enters authoritative model", Failures, Assertions)
    Call Step3Expect(IdeDocumentIsDirty(Documents(DocumentIndex)), "view edit marks document dirty", Failures, Assertions)
    Call Step3Expect(IdeDetachDocumentView(Documents(DocumentIndex)), "document view detaches", Failures, Assertions)
    Call Step3Expect(Documents(DocumentIndex).CurrentContents = Edited And UndoCount = 1, "detaching view preserves buffer and undo", Failures, Assertions)
    Call Step3Expect(IdeAttachDocumentView(Documents(DocumentIndex)) = 2, "recreated view receives new generation", Failures, Assertions)
    Call Step3Expect(IdeUndo(Documents, DocumentCount, UndoEntries, UndoCursor), "undo survives view recreation", Failures, Assertions)
    Call Step3Expect(Documents(DocumentIndex).CurrentContents = Original, "undo restores exact source", Failures, Assertions)
    Call Step3Expect(IdeRedo(Documents, DocumentCount, UndoEntries, UndoCount, UndoCursor), "redo survives view recreation", Failures, Assertions)
    Call Step3Expect(Documents(DocumentIndex).CurrentContents = Edited, "redo restores exact edit", Failures, Assertions)
    Call Step3Expect(IdeObserveDocumentDisk(Documents(DocumentIndex), 1, Original) = IdeDocumentDiskUnchanged(), "unchanged disk is recognized", Failures, Assertions)
    Call Step3Expect(IdeObserveDocumentDisk(Documents(DocumentIndex), 1, "external") = IdeDocumentDiskChanged(), "external disk edit is recognized", Failures, Assertions)
    Call Step3Expect(IdeObserveDocumentDisk(Documents(DocumentIndex), 0, "") = IdeDocumentDiskMissing(), "missing disk file is distinct", Failures, Assertions)

    Dim Locale As IdeLocaleState
    Dim Keys() As String
    Dim Values() As String
    Dim LocaleCapacity As Long = 0
    Dim LocaleLoaded As Long = IdeLoadLocaleText(LocalePath, ReadAllText(LocalePath), Locale, Keys, Values, LocaleCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity)
    Call Step3Expect(LocaleLoaded, "source locale loads for document shell", Failures, Assertions)
    If LocaleLoaded = 0 And DiagnosticCount > 0 Then
        Print "LOCALE DIAGNOSTIC " & Diagnostics(DiagnosticCount - 1).Code & " LINE " & LongToString(Diagnostics(DiagnosticCount - 1).SourceLine)
        Main = 1
        Exit Function
    End If
    Dim Layout As IdeLayoutState
    Call IdeDefaultLayout(Layout)
    Dim Configuration As String = ""
    Call Step3Expect(IdeBuildDocumentShellConfiguration(Layout, Keys, Values, Locale.EntryCount, Documents(DocumentIndex), Configuration), "versioned document shell configuration builds", Failures, Assertions)
    Call Step3Expect(StringIndexOf(Configuration, "Document.StableId = ""1""", 0) >= 0, "configuration carries stable document identity", Failures, Assertions)
    Call Step3Expect(StringIndexOf(Configuration, "Prompt.CloseDirty.Message", 0) >= 0, "close prompt is localized", Failures, Assertions)

    Dim SessionText As String = "UBE-IDE-Document-Session 1" & StringFromByte(10) & "StableId = ""1""" & StringFromByte(10) & "BaseVersion = ""2""" & StringFromByte(10) & "Action = ""Save""" & StringFromByte(10)
    Dim Session As IdeDocumentSessionResult
    Call Step3Expect(IdeLoadDocumentSessionResult(SessionText, Session, Diagnostics, DiagnosticCount, DiagnosticCapacity), "document-session result parses", Failures, Assertions)
    Call Step3Expect(IdeDocumentSessionIsCurrent(Session, Documents(DocumentIndex)), "current document-session result accepted", Failures, Assertions)
    Session.BaseVersion = Session.BaseVersion - 1
    Call Step3Expect(IdeDocumentSessionIsCurrent(Session, Documents(DocumentIndex)) = 0, "stale document-session result rejected", Failures, Assertions)
    Dim BeforeMalformed As Long = DiagnosticCount
    Call Step3Expect(IdeLoadDocumentSessionResult("UBE-IDE-Document-Session 999", Session, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0, "malformed document-session result rejected", Failures, Assertions)
    Call Step3Expect(DiagnosticCount = BeforeMalformed + 1, "malformed session reports one controlled diagnostic", Failures, Assertions)

    Call Step3Expect(IdeResolveDocumentClose(Documents(DocumentIndex), IdeCloseCancel(), Original, 0, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0, "cancel keeps dirty document open", Failures, Assertions)
    Call Step3Expect(IdeResolveDocumentClose(Documents(DocumentIndex), IdeCloseDiscard(), Original, 0, Diagnostics, DiagnosticCount, DiagnosticCapacity), "explicit discard permits close", Failures, Assertions)
    Call Step3Expect(Documents(DocumentIndex).CurrentContents = Edited, "close decision does not destroy buffer early", Failures, Assertions)

    Dim Boundary As Long = 1
    While Boundary <= 4
        Dim BoundaryPath As String = WorkRoot & "\boundary-" & LongToString(Boundary) & ".bas"
        Call WriteAllText(BoundaryPath, Original)
        Dim BoundaryDocuments() As IdeDocument
        Dim BoundaryCount As Long = 0
        Dim BoundaryCapacity As Long = 0
        Dim BoundaryUndo() As IdeUndoEntry
        Dim BoundaryUndoCount As Long = 0
        Dim BoundaryUndoCapacity As Long = 0
        Dim BoundaryUndoCursor As Long = 0
        Dim BoundaryIndex As Long = IdeOpenDocument(BoundaryDocuments, BoundaryCount, BoundaryCapacity, BoundaryPath, Original)
        Call IdeApplyDocumentText(BoundaryDocuments, BoundaryCount, BoundaryIndex, Edited, BoundaryUndo, BoundaryUndoCount, BoundaryUndoCapacity, BoundaryUndoCursor)
        Dim BoundaryResult As Long = IdeSaveDocumentTransaction(BoundaryDocuments(BoundaryIndex), Original, 1, Boundary, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        Call Step3Expect(BoundaryResult = 0 - Boundary, "save interruption boundary " & LongToString(Boundary) & " is explicit", Failures, Assertions)
        Dim BoundaryDisk As String = ReadAllText(BoundaryPath)
        If Boundary <= 2 Then
            Call Step3Expect(BoundaryDisk = Original, "early interruption retains last good disk file", Failures, Assertions)
        Else
            Call Step3Expect(BoundaryDisk = Edited, "late interruption retains complete new disk file", Failures, Assertions)
        End If
        If Boundary >= 2 Then
            Call Step3Expect(ReadAllText(BoundaryDocuments(BoundaryIndex).RecoveryPath) = Edited, "interruption retains usable recovery copy", Failures, Assertions)
        Else
            Call Step3Expect(BoundaryDocuments(BoundaryIndex).HasRecovery = 0, "pre-publication interruption leaves original authoritative", Failures, Assertions)
        End If
        Call CompilerDeleteFile(BoundaryPath)
        Call CompilerDeleteFile(BoundaryDocuments(BoundaryIndex).RecoveryPath)
        Boundary = Boundary + 1
    Wend

    Dim ConflictPath As String = WorkRoot & "\external-conflict.bas"
    Call WriteAllText(ConflictPath, Original)
    Dim ConflictDocuments() As IdeDocument
    Dim ConflictCount As Long = 0
    Dim ConflictCapacity As Long = 0
    Dim ConflictUndo() As IdeUndoEntry
    Dim ConflictUndoCount As Long = 0
    Dim ConflictUndoCapacity As Long = 0
    Dim ConflictUndoCursor As Long = 0
    Dim ConflictIndex As Long = IdeOpenDocument(ConflictDocuments, ConflictCount, ConflictCapacity, ConflictPath, Original)
    Call IdeApplyDocumentText(ConflictDocuments, ConflictCount, ConflictIndex, Edited, ConflictUndo, ConflictUndoCount, ConflictUndoCapacity, ConflictUndoCursor)
    Call WriteAllText(ConflictPath, "external")
    Call Step3Expect(IdeSaveDocumentTransaction(ConflictDocuments(ConflictIndex), "external", 1, 0, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0, "external change blocks overwrite", Failures, Assertions)
    Call Step3Expect(ReadAllText(ConflictPath) = "external", "external content remains untouched", Failures, Assertions)
    Call Step3Expect(ReadAllText(ConflictDocuments(ConflictIndex).RecoveryPath) = Edited, "conflict retains unsaved recovery", Failures, Assertions)

    Dim SavePath As String = WorkRoot & "\complete-save.bas"
    Call WriteAllText(SavePath, Original)
    Dim SaveDocuments() As IdeDocument
    Dim SaveCount As Long = 0
    Dim SaveCapacity As Long = 0
    Dim SaveUndo() As IdeUndoEntry
    Dim SaveUndoCount As Long = 0
    Dim SaveUndoCapacity As Long = 0
    Dim SaveUndoCursor As Long = 0
    Dim SaveIndex As Long = IdeOpenDocument(SaveDocuments, SaveCount, SaveCapacity, SavePath, Original)
    Call IdeApplyDocumentText(SaveDocuments, SaveCount, SaveIndex, Edited, SaveUndo, SaveUndoCount, SaveUndoCapacity, SaveUndoCursor)
    Call Step3Expect(IdeResolveDocumentClose(SaveDocuments(SaveIndex), IdeCloseSave(), Original, 0, Diagnostics, DiagnosticCount, DiagnosticCapacity), "save close completes transaction", Failures, Assertions)
    Call Step3Expect(ReadAllText(SavePath) = Edited, "complete save publishes exact edit", Failures, Assertions)
    Call Step3Expect(IdeDocumentIsDirty(SaveDocuments(SaveIndex)) = 0 And SaveDocuments(SaveIndex).HasRecovery = 0, "complete save commits clean model and removes recovery", Failures, Assertions)

    If Failures = 0 Then
        Print "STEP3 MODEL PASS " & LongToString(Assertions)
        Main = 0
    Else
        Print "STEP3 MODEL FAIL " & LongToString(Failures)
        Main = 1
    End If
End Function
