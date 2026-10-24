UBE SOURCE 1 MODULE
Attribute UBE_Name = "IdeDocuments"

Type IdeDocument
    StableId As Long
    FilePath As String
CurrentContents As String
SavedContents As String
    RecoveryPath As String
    Version As Long
    SavedVersion As Long
    HasRecovery As Long
End Type

Type IdeUndoEntry
    DocumentIndex As Long
    BeforeText As String
    AfterText As String
    BeforeVersion As Long
    AfterVersion As Long
End Type

Function IdeDocumentIsDirty(ByRef Document As IdeDocument) As Long
    If Document.CurrentContents = Document.SavedContents Then
        IdeDocumentIsDirty = 0
    Else
        IdeDocumentIsDirty = 1
    End If
End Function

Function IdeOpenDocument(ByRef Documents() As IdeDocument, ByRef Count As Long, ByRef Capacity As Long, ByVal FilePath As String, ByVal Contents As String) As Long
    If Count >= IdeLimitDocuments() Or StringLength(Contents) > IdeLimitTextBytes() Then
        IdeOpenDocument = -1
        Exit Function
    End If
    Dim InvalidByte As Long = -1
    If IdeValidateUtf8(Contents, InvalidByte) = 0 Then
        IdeOpenDocument = -1
        Exit Function
    End If
    Dim Existing As Long = 0
    While Existing < Count
        If IdeEqualsFolded(Documents(Existing).FilePath, FilePath) <> 0 Then
            IdeOpenDocument = Existing
            Exit Function
        End If
        Existing = Existing + 1
    Wend
    If Count = Capacity Then
        Dim NewCapacity As Long = 8
        If Capacity > 0 Then
            NewCapacity = Capacity * 2
        End If
        If NewCapacity > IdeLimitDocuments() Then
            NewCapacity = IdeLimitDocuments()
        End If
        If Capacity = 0 Then
            ReDim Documents(NewCapacity - 1)
        Else
            ReDim Preserve Documents(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Documents(Count).StableId = Count + 1
    Documents(Count).FilePath = FilePath
    Documents(Count).CurrentContents = Contents
    Documents(Count).SavedContents = Contents
    Documents(Count).RecoveryPath = FilePath & ".ube-recovery"
    Documents(Count).Version = 1
    Documents(Count).SavedVersion = 1
    Documents(Count).HasRecovery = 0
    IdeOpenDocument = Count
    Count = Count + 1
End Function

Function IdeApplyDocumentText(ByRef Documents() As IdeDocument, ByVal DocumentCount As Long, ByVal DocumentIndex As Long, ByVal NewText As String, ByRef UndoEntries() As IdeUndoEntry, ByRef UndoCount As Long, ByRef UndoCapacity As Long, ByRef UndoCursor As Long) As Long
    If DocumentIndex < 0 Or DocumentIndex >= DocumentCount Or StringLength(NewText) > IdeLimitTextBytes() Then
        IdeApplyDocumentText = 0
        Exit Function
    End If
    Dim InvalidByte As Long = -1
    If IdeValidateUtf8(NewText, InvalidByte) = 0 Then
        IdeApplyDocumentText = 0
        Exit Function
    End If
    If Documents(DocumentIndex).CurrentContents = NewText Then
        IdeApplyDocumentText = 1
        Exit Function
    End If
    If UndoCursor < UndoCount Then
        UndoCount = UndoCursor
    End If
    If UndoCount >= IdeLimitUndoEntries() Then
        IdeApplyDocumentText = 0
        Exit Function
    End If
    If UndoCount = UndoCapacity Then
        Dim NewCapacity As Long = 16
        If UndoCapacity > 0 Then
            NewCapacity = UndoCapacity * 2
        End If
        If NewCapacity > IdeLimitUndoEntries() Then
            NewCapacity = IdeLimitUndoEntries()
        End If
        If UndoCapacity = 0 Then
            ReDim UndoEntries(NewCapacity - 1)
        Else
            ReDim Preserve UndoEntries(NewCapacity - 1)
        End If
        UndoCapacity = NewCapacity
    End If
    UndoEntries(UndoCount).DocumentIndex = DocumentIndex
    UndoEntries(UndoCount).BeforeText = Documents(DocumentIndex).CurrentContents
    UndoEntries(UndoCount).AfterText = NewText
    UndoEntries(UndoCount).BeforeVersion = Documents(DocumentIndex).Version
    UndoEntries(UndoCount).AfterVersion = Documents(DocumentIndex).Version + 1
    Documents(DocumentIndex).CurrentContents = NewText
    Documents(DocumentIndex).Version = Documents(DocumentIndex).Version + 1
    UndoCount = UndoCount + 1
    UndoCursor = UndoCount
    IdeApplyDocumentText = 1
End Function

Function IdeUndo(ByRef Documents() As IdeDocument, ByVal DocumentCount As Long, ByRef UndoEntries() As IdeUndoEntry, ByRef UndoCursor As Long) As Long
    If UndoCursor <= 0 Then
        IdeUndo = 0
        Exit Function
    End If
    Dim EntryIndex As Long = UndoCursor - 1
    Dim DocumentIndex As Long = UndoEntries(EntryIndex).DocumentIndex
    If DocumentIndex < 0 Or DocumentIndex >= DocumentCount Then
        IdeUndo = 0
        Exit Function
    End If
    Documents(DocumentIndex).CurrentContents = UndoEntries(EntryIndex).BeforeText
    Documents(DocumentIndex).Version = UndoEntries(EntryIndex).BeforeVersion
    UndoCursor = EntryIndex
    IdeUndo = 1
End Function

Function IdeRedo(ByRef Documents() As IdeDocument, ByVal DocumentCount As Long, ByRef UndoEntries() As IdeUndoEntry, ByVal UndoCount As Long, ByRef UndoCursor As Long) As Long
    If UndoCursor < 0 Or UndoCursor >= UndoCount Then
        IdeRedo = 0
        Exit Function
    End If
    Dim DocumentIndex As Long = UndoEntries(UndoCursor).DocumentIndex
    If DocumentIndex < 0 Or DocumentIndex >= DocumentCount Then
        IdeRedo = 0
        Exit Function
    End If
    Documents(DocumentIndex).CurrentContents = UndoEntries(UndoCursor).AfterText
    Documents(DocumentIndex).Version = UndoEntries(UndoCursor).AfterVersion
    UndoCursor = UndoCursor + 1
    IdeRedo = 1
End Function
