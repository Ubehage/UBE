UBE SOURCE 1 MODULE
Attribute UBE_Name = "IdeDocumentSession"

Type IdeDocumentSessionResult
    StableId As Long
    BaseVersion As Long
    Action As String
End Type

Function IdeBuildDocumentShellConfiguration(ByRef Layout As IdeLayoutState, ByRef LocaleKeys() As String, ByRef LocaleValues() As String, ByVal LocaleCount As Long, ByRef Document As IdeDocument, ByRef Result As String) As Long
    If IdeBuildShellConfiguration(Layout, LocaleKeys, LocaleValues, LocaleCount, Result) = 0 Then
        IdeBuildDocumentShellConfiguration = 0
        Exit Function
    End If
    If Document.StableId <= 0 Or Document.Version <= 0 Or StringLength(Document.FilePath) = 0 Then
        Result = ""
        IdeBuildDocumentShellConfiguration = 0
        Exit Function
    End If
    Call IdeAppendShellValue(Result, "Document.Enabled", "1")
    Call IdeAppendShellValue(Result, "Document.StableId", LongToString(Document.StableId))
    Call IdeAppendShellValue(Result, "Document.BaseVersion", LongToString(Document.Version))
    Call IdeAppendShellValue(Result, "Document.DisplayName", Document.FilePath)
    IdeBuildDocumentShellConfiguration = 1
End Function

Function IdeLoadDocumentSessionResult(ByVal Contents As String, ByRef Session As IdeDocumentSessionResult, ByRef Diagnostics() As IdeDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Session.StableId = 0
    Session.BaseVersion = 0
    Session.Action = ""
    Dim InitialDiagnosticCount As Long = DiagnosticCount
    If StringLength(Contents) > IdeLimitProtocolBytes() Then
        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE3001", "<document-session>", 1, 1, 2)
        IdeLoadDocumentSessionResult = 0
        Exit Function
    End If
    Dim InvalidByte As Long = -1
    If IdeValidateUtf8(Contents, InvalidByte) = 0 Then
        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE3009", "<document-session>", 1, InvalidByte + 1, 2)
        IdeLoadDocumentSessionResult = 0
        Exit Function
    End If
    Dim Cursor As Long = 0
    Dim LineText As String = ""
    Dim HeaderValid As Long = 0
    If IdeReadLine(Contents, Cursor, LineText) <> 0 Then
        If StringLength(LineText) = StringLength("UBE-IDE-Document-Session 1") Then
            If LineText = "UBE-IDE-Document-Session 1" Then
                HeaderValid = 1
            End If
        End If
    End If
    If HeaderValid = 0 Then
        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE3002", "<document-session>", 1, 1, 2)
        IdeLoadDocumentSessionResult = 0
        Exit Function
    End If
    Dim SeenStableId As Long = 0
    Dim SeenBaseVersion As Long = 0
    Dim SeenAction As Long = 0
    Dim LineNumber As Long = 1
    While IdeReadLine(Contents, Cursor, LineText) <> 0
        LineNumber = LineNumber + 1
        Dim Trimmed As String = ""
        Call IdeTrim(LineText, Trimmed)
        If StringLength(Trimmed) > 0 Then
            Dim Key As String = ""
            Dim Value As String = ""
            If IdeParseAssignment(Trimmed, Key, Value) = 0 Then
                Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE3003", "<document-session>", LineNumber, 1, 2)
            Else
                If IdeEqualsFolded(Key, "StableId") <> 0 Then
                    If SeenStableId <> 0 Or IdeParseNonnegativeLong(Value, Session.StableId) = 0 Or Session.StableId = 0 Then
                        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE3003", "<document-session>", LineNumber, 1, 2)
                    Else
                        SeenStableId = 1
                    End If
                Else
                    If IdeEqualsFolded(Key, "BaseVersion") <> 0 Then
                        If SeenBaseVersion <> 0 Or IdeParseNonnegativeLong(Value, Session.BaseVersion) = 0 Or Session.BaseVersion = 0 Then
                            Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE3003", "<document-session>", LineNumber, 1, 2)
                        Else
                            SeenBaseVersion = 1
                        End If
                    Else
                        If IdeEqualsFolded(Key, "Action") <> 0 Then
                            If SeenAction <> 0 Or (Value <> "Save" And Value <> "Discard" And Value <> "Close" And Value <> "Recover") Then
                                Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE3003", "<document-session>", LineNumber, 1, 2)
                            Else
                                Session.Action = Value
                                SeenAction = 1
                            End If
                        Else
                            Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE3007", "<document-session>", LineNumber, 1, 2)
                        End If
                    End If
                End If
            End If
        End If
    Wend
    If SeenStableId = 0 Or SeenBaseVersion = 0 Or SeenAction = 0 Then
        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE3008", "<document-session>", 1, 1, 2)
    End If
    If DiagnosticCount = InitialDiagnosticCount Then
        IdeLoadDocumentSessionResult = 1
    Else
        IdeLoadDocumentSessionResult = 0
    End If
End Function

Function IdeDocumentSessionIsCurrent(ByRef Session As IdeDocumentSessionResult, ByRef Document As IdeDocument) As Long
    If Session.StableId = Document.StableId And Session.BaseVersion = Document.Version Then
        IdeDocumentSessionIsCurrent = 1
    Else
        IdeDocumentSessionIsCurrent = 0
    End If
End Function
