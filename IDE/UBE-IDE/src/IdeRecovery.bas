UBE SOURCE 1 MODULE
Attribute UBE_Name = "IdeRecovery"

Function IdePublishText(ByVal FilePath As String, ByVal Contents As String, ByVal SimulateFailure As Long, ByRef Diagnostics() As IdeDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    If StringLength(FilePath) = 0 Or StringLength(Contents) > IdeLimitTextBytes() Then
        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE4001", FilePath, 1, 1, 2)
        IdePublishText = 0
        Exit Function
    End If
    Dim InvalidByte As Long = -1
    If IdeValidateUtf8(Contents, InvalidByte) = 0 Then
        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE4005", FilePath, 1, InvalidByte + 1, 2)
        IdePublishText = 0
        Exit Function
    End If
    If SimulateFailure <> 0 Then
        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE4002", FilePath, 1, 1, 2)
        IdePublishText = 0
        Exit Function
    End If
    If WriteAllText(FilePath, Contents) <> 0 Then
        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE4003", FilePath, 1, 1, 2)
        IdePublishText = 0
        Exit Function
    End If
    IdePublishText = 1
End Function

Function IdeWriteRecovery(ByRef Document As IdeDocument, ByVal SimulateFailure As Long, ByRef Diagnostics() As IdeDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    If IdeDocumentIsDirty(Document) = 0 Then
        IdeWriteRecovery = 1
        Exit Function
    End If
    If IdePublishText(Document.RecoveryPath, Document.CurrentContents, SimulateFailure, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        IdeWriteRecovery = 0
        Exit Function
    End If
    Document.HasRecovery = 1
    IdeWriteRecovery = 1
End Function

Function IdeSaveDocument(ByRef Document As IdeDocument, ByVal SimulateFailure As Long, ByRef Diagnostics() As IdeDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    If IdePublishText(Document.FilePath, Document.CurrentContents, SimulateFailure, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        IdeSaveDocument = 0
        Exit Function
    End If
    Document.SavedContents = Document.CurrentContents
    Document.SavedVersion = Document.Version
    If Document.HasRecovery <> 0 Then
        Dim CleanupStatus As Long = CompilerDeleteFile(Document.RecoveryPath)
        If CleanupStatus = 0 Then
            Document.HasRecovery = 0
        Else
            Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE4004", Document.RecoveryPath, 1, 1, 1)
        End If
    End If
    IdeSaveDocument = 1
End Function

Function IdeRestoreRecovery(ByRef Document As IdeDocument, ByVal RecoveryText As String) As Long
    If StringLength(RecoveryText) > IdeLimitTextBytes() Then
        IdeRestoreRecovery = 0
        Exit Function
    End If
    Dim InvalidByte As Long = -1
    If IdeValidateUtf8(RecoveryText, InvalidByte) = 0 Then
        IdeRestoreRecovery = 0
        Exit Function
    End If
    Document.CurrentContents = RecoveryText
    Document.Version = Document.Version + 1
    Document.HasRecovery = 1
    IdeRestoreRecovery = 1
End Function

Function IdeDocumentHasExternalChange(ByRef Document As IdeDocument, ByVal DiskText As String) As Long
    If DiskText = Document.SavedContents Then
        IdeDocumentHasExternalChange = 0
    Else
        IdeDocumentHasExternalChange = 1
    End If
End Function
