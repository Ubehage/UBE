UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Function Main() As Long
    Dim ArgumentCount As Long = CommandArgumentCount()
    Dim HasDocument As Long = 0
    Dim HasWorkspace As Long = 0
    Dim VerifyMode As Long = 0
    If ArgumentCount = 5 Or ArgumentCount = 6 Then
        If ArgumentCount = 6 Then
            VerifyMode = 1
        End If
    Else
        If ArgumentCount = 9 Or ArgumentCount = 10 Or ArgumentCount = 11 Then
            HasDocument = 1
            If ArgumentCount = 10 Then
                If CommandArgument(9) = "--verify" Then
                    VerifyMode = 1
                Else
                    HasWorkspace = 1
                End If
            ElseIf ArgumentCount = 11 Then
                HasWorkspace = 1
                VerifyMode = 1
            End If
        Else
            Print IdeEmergencyText(3)
            Main = 2
            Exit Function
        End If
    End If

    Dim HostPath As String = CommandArgument(0)
    Dim LocalePath As String = CommandArgument(1)
    Dim LayoutPath As String = CommandArgument(2)
    Dim ConfigurationPath As String = CommandArgument(3)
    Dim ResultPath As String = CommandArgument(4)

    Dim Diagnostics() As IdeDiagnostic
    Dim DiagnosticCount As Long = 0
    Dim DiagnosticCapacity As Long = 0
    Dim Locale As IdeLocaleState
    Dim LocaleKeys() As String
    Dim LocaleValues() As String
    Dim LocaleCapacity As Long = 0
    Dim LocaleText As String = ReadAllText(LocalePath)
    If IdeLoadLocaleText(LocalePath, LocaleText, Locale, LocaleKeys, LocaleValues, LocaleCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        Print IdeEmergencyText(1)
        Main = 3
        Exit Function
    End If

    Dim Layout As IdeLayoutState
    Dim LayoutText As String = ReadAllText(LayoutPath)
    Call IdeLoadLayoutText(LayoutPath, LayoutText, Layout, Diagnostics, DiagnosticCount, DiagnosticCapacity)

    Dim Documents() As IdeDocument
    Dim DocumentCount As Long = 0
    Dim DocumentCapacity As Long = 0
    Dim DocumentIndex As Long = -1
    Dim DocumentPath As String = ""
    Dim DocumentInputPath As String = ""
    Dim DocumentOutputPath As String = ""
    Dim DocumentActionPath As String = ""
    Dim UndoEntries() As IdeUndoEntry
    Dim UndoCount As Long = 0
    Dim UndoCapacity As Long = 0
    Dim UndoCursor As Long = 0
    Dim WorkspaceProject As IdeProjectState
    Dim WorkspaceSources() As String
    Dim WorkspaceSourceCapacity As Long = 0
    Dim WorkspaceUnknownKeys() As String
    Dim WorkspaceUnknownValues() As String
    Dim WorkspaceUnknownCapacity As Long = 0
    Dim WorkspaceProjectText As String = ""
    Dim WorkspacePropertiesText As String = ""
    Dim WorkspaceOutputText As String = ""
    If HasDocument <> 0 Then
        DocumentPath = CommandArgument(5)
        DocumentInputPath = CommandArgument(6)
        DocumentOutputPath = CommandArgument(7)
        DocumentActionPath = CommandArgument(8)
        Dim SourceText As String = ReadAllText(DocumentPath)
        DocumentIndex = IdeOpenDocument(Documents, DocumentCount, DocumentCapacity, DocumentPath, SourceText)
        If DocumentIndex < 0 Then
            Print IdeEmergencyText(3)
            Main = 9
            Exit Function
        End If
        If IdeAttachDocumentView(Documents(DocumentIndex)) = 0 Then
            Print IdeEmergencyText(3)
            Main = 9
            Exit Function
        End If
        Call CompilerDeleteFile(DocumentOutputPath)
        Call CompilerDeleteFile(DocumentActionPath)
        If IdePublishText(DocumentInputPath, Documents(DocumentIndex).CurrentContents, 0, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
            Print IdeEmergencyText(3)
            Main = 10
            Exit Function
        End If
    End If

    If HasWorkspace <> 0 Then
        Dim WorkspacePath As String = CommandArgument(9)
        If IdeLoadProjectText(WorkspacePath, ReadAllText(WorkspacePath), WorkspaceProject, WorkspaceSources, WorkspaceSourceCapacity, WorkspaceUnknownKeys, WorkspaceUnknownValues, WorkspaceUnknownCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
            Print IdeEmergencyText(3)
            Main = 14
            Exit Function
        End If
        Dim SourceLabel As String = ""
        Dim NameLabel As String = ""
        Dim KindLabel As String = ""
        Dim StartupLabel As String = ""
        Dim PathLabel As String = ""
        Dim LoadedTemplate As String = ""
        If IdeShellText(LocaleKeys, LocaleValues, Locale.EntryCount, "Tool.ProjectExplorer.Source", SourceLabel) = 0 Then
            Print IdeEmergencyText(1)
            Main = 15
            Exit Function
        End If
        If IdeShellText(LocaleKeys, LocaleValues, Locale.EntryCount, "Property.Name", NameLabel) = 0 Then
            Print IdeEmergencyText(1)
            Main = 15
            Exit Function
        End If
        If IdeShellText(LocaleKeys, LocaleValues, Locale.EntryCount, "Property.Kind", KindLabel) = 0 Then
            Print IdeEmergencyText(1)
            Main = 15
            Exit Function
        End If
        If IdeShellText(LocaleKeys, LocaleValues, Locale.EntryCount, "Property.Startup", StartupLabel) = 0 Then
            Print IdeEmergencyText(1)
            Main = 15
            Exit Function
        End If
        If IdeShellText(LocaleKeys, LocaleValues, Locale.EntryCount, "Property.Path", PathLabel) = 0 Then
            Print IdeEmergencyText(1)
            Main = 15
            Exit Function
        End If
        If IdeShellText(LocaleKeys, LocaleValues, Locale.EntryCount, "Output.ProjectLoaded", LoadedTemplate) = 0 Then
            Print IdeEmergencyText(1)
            Main = 15
            Exit Function
        End If
        If IdeBuildProjectExplorerText(WorkspaceProject, WorkspaceSources, SourceLabel, WorkspaceProjectText) = 0 Then
            Print IdeEmergencyText(3)
            Main = 15
            Exit Function
        End If
        Dim WorkspaceSelection As IdeWorkspaceSelection
        Call IdeSelectWorkspaceItem(WorkspaceProject, WorkspaceSelection, 0)
        If IdeBuildWorkspacePropertiesText(WorkspaceProject, WorkspaceSources, WorkspaceSelection, NameLabel, KindLabel, StartupLabel, PathLabel, WorkspacePropertiesText) = 0 Then
            Print IdeEmergencyText(3)
            Main = 15
            Exit Function
        End If
        Dim FormatArguments() As IdeFormatArgument
        ReDim FormatArguments(0)
        FormatArguments(0).ArgumentName = "name"
        FormatArguments(0).ArgumentKind = 1
        FormatArguments(0).TextValue = WorkspaceProject.ProjectName
        If IdeFormatMessage(LoadedTemplate, FormatArguments, 1, WorkspaceOutputText) = 0 Then
            Print IdeEmergencyText(1)
            Main = 15
            Exit Function
        End If
    End If

    Dim ConfigurationText As String = ""
    Dim ConfigurationBuilt As Long = 0
    If HasDocument <> 0 Then
        ConfigurationBuilt = IdeBuildDocumentShellConfiguration(Layout, LocaleKeys, LocaleValues, Locale.EntryCount, Documents(DocumentIndex), ConfigurationText)
    Else
        ConfigurationBuilt = IdeBuildShellConfiguration(Layout, LocaleKeys, LocaleValues, Locale.EntryCount, ConfigurationText)
    End If
    If ConfigurationBuilt = 0 Then
        Print IdeEmergencyText(1)
        Main = 4
        Exit Function
    End If
    If HasWorkspace <> 0 Then
        If IdeAppendWorkspaceConfiguration(ConfigurationText, WorkspaceProjectText, WorkspacePropertiesText, WorkspaceOutputText) = 0 Then
            Print IdeEmergencyText(3)
            Main = 15
            Exit Function
        End If
    End If
    If WriteAllText(ConfigurationPath, ConfigurationText) <> 0 Then
        Print IdeEmergencyText(3)
        Main = 5
        Exit Function
    End If
    Call CompilerDeleteFile(ResultPath)

    Dim HostArgumentCount As Long = 4
    If HasDocument <> 0 Then
        HostArgumentCount = 10
    End If
    If VerifyMode <> 0 Then
        HostArgumentCount = HostArgumentCount + 1
    End If
    Dim HostArguments() As String
    ReDim HostArguments(HostArgumentCount - 1)
    HostArguments(0) = "--config"
    HostArguments(1) = ConfigurationPath
    HostArguments(2) = "--result"
    HostArguments(3) = ResultPath
    Dim HostCursor As Long = 4
    If HasDocument <> 0 Then
        HostArguments(HostCursor) = "--document-input"
        HostArguments(HostCursor + 1) = DocumentInputPath
        HostArguments(HostCursor + 2) = "--document-output"
        HostArguments(HostCursor + 3) = DocumentOutputPath
        HostArguments(HostCursor + 4) = "--document-action"
        HostArguments(HostCursor + 5) = DocumentActionPath
        HostCursor = HostCursor + 6
    End If
    If VerifyMode <> 0 Then
        HostArguments(HostCursor) = "--verify"
    End If

    Dim HostStatus As Long = CompilerRunTool(HostPath, HostArguments, HostArgumentCount)
    If HostStatus <> 0 Then
        If HasDocument <> 0 Then
            Dim RecoveryActionText As String = ReadAllText(DocumentActionPath)
            If StringLength(RecoveryActionText) > 0 Then
                Dim RecoverySession As IdeDocumentSessionResult
                If IdeLoadDocumentSessionResult(RecoveryActionText, RecoverySession, Diagnostics, DiagnosticCount, DiagnosticCapacity) <> 0 Then
                    If RecoverySession.Action = "Recover" Then
                        If IdeDocumentSessionIsCurrent(RecoverySession, Documents(DocumentIndex)) <> 0 Then
                            Dim RecoverySnapshot As String = ReadAllText(DocumentOutputPath)
                            If IdeApplyDocumentText(Documents, DocumentCount, DocumentIndex, RecoverySnapshot, UndoEntries, UndoCount, UndoCapacity, UndoCursor) <> 0 Then
                                Call IdeWriteRecovery(Documents(DocumentIndex), 0, Diagnostics, DiagnosticCount, DiagnosticCapacity)
                            End If
                        End If
                    End If
                End If
            End If
        End If
        Print IdeEmergencyText(3)
        Main = 6
        Exit Function
    End If

    Dim ReturnedText As String = ReadAllText(ResultPath)
    Dim ReturnedLayout As IdeLayoutState
    If IdeLoadLayoutText(ResultPath, ReturnedText, ReturnedLayout, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        Print IdeEmergencyText(3)
        Main = 7
        Exit Function
    End If
    Dim SavedText As String = ""
    If IdeSerializeLayout(ReturnedLayout, SavedText) = 0 Then
        Print IdeEmergencyText(3)
        Main = 8
        Exit Function
    End If
    If WriteAllText(LayoutPath, SavedText) <> 0 Then
        Print IdeEmergencyText(3)
        Main = 8
        Exit Function
    End If

    If HasDocument <> 0 Then
        Dim SessionText As String = ReadAllText(DocumentActionPath)
        Dim Session As IdeDocumentSessionResult
        If IdeLoadDocumentSessionResult(SessionText, Session, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
            Print IdeEmergencyText(3)
            Main = 11
            Exit Function
        End If
        If IdeDocumentSessionIsCurrent(Session, Documents(DocumentIndex)) = 0 Then
            Print IdeEmergencyText(3)
            Main = 11
            Exit Function
        End If
        If Session.Action = "Save" Then
            Dim SnapshotText As String = ReadAllText(DocumentOutputPath)
            If IdeApplyDocumentText(Documents, DocumentCount, DocumentIndex, SnapshotText, UndoEntries, UndoCount, UndoCapacity, UndoCursor) = 0 Then
                Print IdeEmergencyText(3)
                Main = 12
                Exit Function
            End If
            Dim ObservedDiskText As String = ReadAllText(DocumentPath)
            If IdeResolveDocumentClose(Documents(DocumentIndex), IdeCloseSave(), ObservedDiskText, 0, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
                Print IdeEmergencyText(3)
                Main = 13
                Exit Function
            End If
        End If
        Call IdeDetachDocumentView(Documents(DocumentIndex))
        Call CompilerDeleteFile(DocumentInputPath)
        Call CompilerDeleteFile(DocumentOutputPath)
        Call CompilerDeleteFile(DocumentActionPath)
        If VerifyMode <> 0 Then
            If HasWorkspace <> 0 Then
                Print "STEP4 WORKSPACE PASS"
            Else
                Print "STEP3 DOCUMENT PASS"
            End If
        End If
    Else
        If VerifyMode <> 0 Then
            Print "STEP2 SHELL PASS"
        End If
    End If
    Main = 0
End Function
