UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Sub ExpectTrue(ByVal Condition As Long, ByVal TestName As String, ByRef FailureCount As Long)
    If Condition <> 0 Then
        Print "PASS " & TestName
    Else
        Print "FAIL " & TestName
        FailureCount = FailureCount + 1
    End If
End Sub

Function Main() As Long
    If CommandArgumentCount() <> 2 Then
        Print "usage: UBE-IDE-Step1 <work-directory> <source-locale>"
        Main = 2
        Exit Function
    End If
    Dim WorkPath As String = CommandArgument(0)
    Dim SourceLocalePath As String = CommandArgument(1)
    Dim N As String = StringFromByte(10)
    Dim Failures As Long = 0

    Dim Diagnostics() As IdeDiagnostic
    Dim DiagnosticCount As Long = 0
    Dim DiagnosticCapacity As Long = 0
    Dim PackagedLocale As IdeLocaleState
    Dim PackagedLocaleKeys() As String
    Dim PackagedLocaleValues() As String
    Dim PackagedLocaleCapacity As Long = 0
    Call ExpectTrue(IdeLoadLocaleText(SourceLocalePath, ReadAllText(SourceLocalePath), PackagedLocale, PackagedLocaleKeys, PackagedLocaleValues, PackagedLocaleCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity), "packaged source locale loads", Failures)
    Call ExpectTrue(PackagedLocale.EntryCount > 0, "packaged source locale is not empty", Failures)
    DiagnosticCount = 0
    Dim Project As IdeProjectState
    Dim Sources() As String
    Dim SourceCapacity As Long = 0
    Dim UnknownKeys() As String
    Dim UnknownValues() As String
    Dim UnknownCapacity As Long = 0
    Dim ProjectText As String = "UBE-Project 1" & N & "Name = " & StringFromByte(34) & "Sample" & StringFromByte(34) & N & "Kind = " & StringFromByte(34) & "Exe" & StringFromByte(34) & N & "Startup = " & StringFromByte(34) & "Main" & StringFromByte(34) & N & "Source = " & StringFromByte(34) & "src/Main.bas" & StringFromByte(34) & N & "Optimization = " & StringFromByte(34) & "2" & StringFromByte(34) & N
    Call ExpectTrue(IdeLoadProjectText("Sample.UBE", ProjectText, Project, Sources, SourceCapacity, UnknownKeys, UnknownValues, UnknownCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity), "project loads", Failures)
    Call ExpectTrue(Project.SourceCount = 1 And Project.UnknownCount = 1, "project order and unknown field preserved", Failures)
    Call ExpectTrue(Sources(0) = "src/Main.bas" And UnknownKeys(0) = "Optimization", "project values retained", Failures)
    Call ExpectTrue(Project.OriginalContents = ProjectText, "project original text retained for lossless save", Failures)
    Call ExpectTrue(IdeEqualsFolded("Å", "å"), "Unicode folded identity matches", Failures)

    Dim WorkspaceManifestPath As String = WorkPath & "/Workspace.UBE"
    Call ExpectTrue(WriteAllText(WorkspaceManifestPath, ProjectText) = 0, "workspace manifest published", Failures)
    DiagnosticCount = 0
    Dim DiskProject As IdeProjectState
    Dim DiskSources() As String
    Dim DiskSourceCapacity As Long = 0
    Dim DiskUnknownKeys() As String
    Dim DiskUnknownValues() As String
    Dim DiskUnknownCapacity As Long = 0
    Call ExpectTrue(IdeLoadProjectText(WorkspaceManifestPath, ReadAllText(WorkspaceManifestPath), DiskProject, DiskSources, DiskSourceCapacity, DiskUnknownKeys, DiskUnknownValues, DiskUnknownCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity), "workspace opens from disk", Failures)

    DiagnosticCount = 0
    Dim BadProject As IdeProjectState
    Dim BadSources() As String
    Dim BadSourceCapacity As Long = 0
    Dim BadUnknownKeys() As String
    Dim BadUnknownValues() As String
    Dim BadUnknownCapacity As Long = 0
    Dim BadProjectText As String = "UBE-Project 1" & N & "Name = " & StringFromByte(34) & "Bad" & StringFromByte(34) & N & "Kind = " & StringFromByte(34) & "Exe" & StringFromByte(34) & N & "Source = " & StringFromByte(34) & "../escape.bas" & StringFromByte(34) & N
    Call ExpectTrue(IdeLoadProjectText("Bad.UBE", BadProjectText, BadProject, BadSources, BadSourceCapacity, BadUnknownKeys, BadUnknownValues, BadUnknownCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 And DiagnosticCount > 0, "escaping project path rejected", Failures)
    DiagnosticCount = 0
    Call ExpectTrue(IdeLoadProjectText("InvalidUtf8.UBE", ProjectText & StringFromByte(255), BadProject, BadSources, BadSourceCapacity, BadUnknownKeys, BadUnknownValues, BadUnknownCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 And DiagnosticCount > 0, "invalid UTF-8 project rejected", Failures)
    DiagnosticCount = 0
    Dim DuplicateProject As IdeProjectState
    Dim DuplicateSources() As String
    Dim DuplicateSourceCapacity As Long = 0
    Dim DuplicateUnknownKeys() As String
    Dim DuplicateUnknownValues() As String
    Dim DuplicateUnknownCapacity As Long = 0
    Dim DuplicateProjectText As String = "UBE-Project 1" & N & "Name = " & StringFromByte(34) & "Duplicate" & StringFromByte(34) & N & "Kind = " & StringFromByte(34) & "Exe" & StringFromByte(34) & N & "Source = " & StringFromByte(34) & "src/Main.bas" & StringFromByte(34) & N & "Source = " & StringFromByte(34) & "src\Main.bas" & StringFromByte(34) & N
    Call ExpectTrue(IdeLoadProjectText("Duplicate.UBE", DuplicateProjectText, DuplicateProject, DuplicateSources, DuplicateSourceCapacity, DuplicateUnknownKeys, DuplicateUnknownValues, DuplicateUnknownCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 And DiagnosticCount > 0, "duplicate normalized project path rejected", Failures)

    Dim Documents() As IdeDocument
    Dim DocumentCount As Long = 0
    Dim DocumentCapacity As Long = 0
    Dim DocumentPath As String = WorkPath & "/Main.bas"
    Call ExpectTrue(WriteAllText(DocumentPath, "old") = 0, "initial document published", Failures)
    Dim DocumentIndex As Long = IdeOpenDocument(Documents, DocumentCount, DocumentCapacity, DocumentPath, "old")
    Call ExpectTrue(DocumentIndex = 0 And IdeDocumentIsDirty(Documents(0)) = 0, "document opens clean", Failures)
    Dim UndoEntries() As IdeUndoEntry
    Dim UndoCount As Long = 0
    Dim UndoCapacity As Long = 0
    Dim UndoCursor As Long = 0
    Call ExpectTrue(IdeApplyDocumentText(Documents, DocumentCount, 0, "new", UndoEntries, UndoCount, UndoCapacity, UndoCursor), "document edit applies", Failures)
    Call ExpectTrue(IdeDocumentIsDirty(Documents(0)) <> 0 And Documents(0).Version = 2, "edit updates dirty version", Failures)
    Call ExpectTrue(IdeUndo(Documents, DocumentCount, UndoEntries, UndoCursor) And Documents(0).CurrentContents = "old", "undo restores content", Failures)
    Call ExpectTrue(IdeRedo(Documents, DocumentCount, UndoEntries, UndoCount, UndoCursor) And Documents(0).CurrentContents = "new", "redo restores edit", Failures)

    DiagnosticCount = 0
    Call ExpectTrue(IdeWriteRecovery(Documents(0), 0, Diagnostics, DiagnosticCount, DiagnosticCapacity), "recovery publishes", Failures)
    Call ExpectTrue(ReadAllText(Documents(0).RecoveryPath) = "new", "recovery content is readable", Failures)
    DiagnosticCount = 0
    Call ExpectTrue(IdeSaveDocument(Documents(0), 1, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0, "injected save failure is controlled", Failures)
    Call ExpectTrue(ReadAllText(DocumentPath) = "old" And IdeDocumentIsDirty(Documents(0)) <> 0, "failed save preserves old file and dirty state", Failures)
    DiagnosticCount = 0
    Call ExpectTrue(IdeSaveDocument(Documents(0), 0, Diagnostics, DiagnosticCount, DiagnosticCapacity), "atomic save succeeds", Failures)
    Call ExpectTrue(ReadAllText(DocumentPath) = "new" And IdeDocumentIsDirty(Documents(0)) = 0, "save publishes exact text and marks clean", Failures)
    Call ExpectTrue(IdeDocumentHasExternalChange(Documents(0), "external") <> 0, "external change detected", Failures)
    Call ExpectTrue(IdeRestoreRecovery(Documents(0), "recovered") And IdeDocumentIsDirty(Documents(0)) <> 0, "recovery restoration remains unsaved", Failures)
    Call ExpectTrue(IdeRestoreRecovery(Documents(0), StringFromByte(255)) = 0 And Documents(0).CurrentContents = "recovered", "invalid recovery is rejected without changing document", Failures)

    Dim Commands() As IdeCommand
    Dim CommandCount As Long = 0
    Dim CommandCapacity As Long = 0
    Call ExpectTrue(IdeRegisterCommand(Commands, CommandCount, CommandCapacity, "File.Save", "Command.File.Save"), "command registers", Failures)
    Call ExpectTrue(IdeRegisterCommand(Commands, CommandCount, CommandCapacity, "file.save", "Duplicate") = 0, "duplicate command rejected case-insensitively", Failures)
    Call ExpectTrue(IdeSetCommandEnabled(Commands, CommandCount, "FILE.SAVE", 0) And Commands(0).IsEnabled = 0, "command enablement updates", Failures)

    DiagnosticCount = 0
    Dim Settings As IdeSettingsState
    Dim SettingKeys() As String
    Dim SettingValues() As String
    Dim SettingCapacity As Long = 0
    Dim SettingsText As String = "UBE-IDE-Settings 1" & N & "Layout.Name = " & StringFromByte(34) & "Code" & StringFromByte(34) & N & "Future.Option = " & StringFromByte(34) & "preserve" & StringFromByte(34) & N
    Call ExpectTrue(IdeLoadSettingsText("settings.txt", SettingsText, Settings, SettingKeys, SettingValues, SettingCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity), "settings load", Failures)
    Dim SettingValue As String = ""
    Call ExpectTrue(IdeGetSetting(SettingKeys, SettingValues, Settings.EntryCount, "future.option", SettingValue) And SettingValue = "preserve", "unknown setting remains available", Failures)
    Call ExpectTrue(IdeSetSetting(SettingKeys, SettingValues, Settings, SettingCapacity, "Layout.Name", "Debug"), "setting updates", Failures)
    Dim SerializedSettings As String = ""
    Call ExpectTrue(IdeSerializeSettings(SettingKeys, SettingValues, Settings.EntryCount, SerializedSettings), "settings serialize deterministically", Failures)
    DiagnosticCount = 0
    Dim ReloadedSettings As IdeSettingsState
    Dim ReloadedKeys() As String
    Dim ReloadedValues() As String
    Dim ReloadedCapacity As Long = 0
    Call ExpectTrue(IdeLoadSettingsText("settings-roundtrip.txt", SerializedSettings, ReloadedSettings, ReloadedKeys, ReloadedValues, ReloadedCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity), "serialized settings reload", Failures)
    Call ExpectTrue(IdeGetSetting(ReloadedKeys, ReloadedValues, ReloadedSettings.EntryCount, "Layout.Name", SettingValue) And SettingValue = "Debug", "settings round trip exactly", Failures)
    DiagnosticCount = 0
    Dim QuoteText As String = StringFromByte(34)
    Dim QuotedSettings As IdeSettingsState
    Dim QuotedKeys() As String
    Dim QuotedValues() As String
    Dim QuotedCapacity As Long = 0
    Dim QuotedSettingsText As String = "UBE-IDE-Settings 1" & N & "Message = " & QuoteText & "Say " & QuoteText & QuoteText & "Hello" & QuoteText & QuoteText & QuoteText & N
    Call ExpectTrue(IdeLoadSettingsText("quoted.txt", QuotedSettingsText, QuotedSettings, QuotedKeys, QuotedValues, QuotedCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity), "quoted setting loads", Failures)
    Call ExpectTrue(QuotedValues(0) = "Say " & QuoteText & "Hello" & QuoteText, "doubled quotes decode", Failures)

    DiagnosticCount = 0
    Dim English As IdeLocaleState
    Dim EnglishKeys() As String
    Dim EnglishValues() As String
    Dim EnglishCapacity As Long = 0
    Dim EnglishText As String = "UBE-Locale 1" & N & "Locale = " & StringFromByte(34) & "en" & StringFromByte(34) & N & "Command.File.Save = " & StringFromByte(34) & "Save" & StringFromByte(34) & N & "Emergency.Exit = " & StringFromByte(34) & "Exit" & StringFromByte(34) & N & "Build.Summary = " & StringFromByte(34) & "Built {project:text} with {errors:long} errors" & StringFromByte(34) & N
    Call ExpectTrue(IdeLoadLocaleText("en.locale", EnglishText, English, EnglishKeys, EnglishValues, EnglishCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity), "source locale loads", Failures)
    DiagnosticCount = 0
    Dim Danish As IdeLocaleState
    Dim DanishKeys() As String
    Dim DanishValues() As String
    Dim DanishCapacity As Long = 0
    Dim DanishText As String = "UBE-Locale 1" & N & "Locale = " & StringFromByte(34) & "da" & StringFromByte(34) & N & "Fallback = " & StringFromByte(34) & "en" & StringFromByte(34) & N & "Command.File.Save = " & StringFromByte(34) & "Gem" & StringFromByte(34) & N
    Call ExpectTrue(IdeLoadLocaleText("da.locale", DanishText, Danish, DanishKeys, DanishValues, DanishCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity), "translated locale loads", Failures)
    Dim Localized As String = ""
    Call ExpectTrue(IdeGetLocalizedText(DanishKeys, DanishValues, Danish.EntryCount, EnglishKeys, EnglishValues, English.EntryCount, "Command.File.Save", Localized) And Localized = "Gem", "primary translation resolves", Failures)
    Call ExpectTrue(IdeGetLocalizedText(DanishKeys, DanishValues, Danish.EntryCount, EnglishKeys, EnglishValues, English.EntryCount, "Emergency.Exit", Localized) And Localized = "Exit", "translation fallback resolves", Failures)
    Call ExpectTrue(IdeGetLocalizedText(DanishKeys, DanishValues, Danish.EntryCount, EnglishKeys, EnglishValues, English.EntryCount, "Missing.Key", Localized) = 0 And Localized = "[Missing.Key]", "missing translation remains visible", Failures)
    Dim FormatArguments() As IdeFormatArgument
    ReDim FormatArguments(1)
    FormatArguments(0).ArgumentName = "project"
    FormatArguments(0).ArgumentKind = 1
    FormatArguments(0).TextValue = "Paint"
    FormatArguments(1).ArgumentName = "errors"
    FormatArguments(1).ArgumentKind = 2
    FormatArguments(1).LongValue = 3
    Dim FormattedText As String = ""
    Call ExpectTrue(IdeFormatMessage("Built {project:text} with {errors:long} errors", FormatArguments, 2, FormattedText) And FormattedText = "Built Paint with 3 errors", "typed named placeholders format", Failures)
    FormatArguments(1).ArgumentKind = 1
    Call ExpectTrue(IdeFormatMessage("{errors:long}", FormatArguments, 2, FormattedText) = 0 And FormattedText = "", "placeholder type mismatch rejected", Failures)
    Call ExpectTrue(StringLength(IdeEmergencyText(1)) > 0 And IdeEmergencyText(99) = "Exit", "emergency text remains available", Failures)
    DiagnosticCount = 0
    Dim InvalidLocale As IdeLocaleState
    Dim InvalidLocaleKeys() As String
    Dim InvalidLocaleValues() As String
    Dim InvalidLocaleCapacity As Long = 0
    Call ExpectTrue(IdeLoadLocaleText("invalid.locale", DanishText & StringFromByte(255), InvalidLocale, InvalidLocaleKeys, InvalidLocaleValues, InvalidLocaleCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 And DiagnosticCount > 0, "invalid UTF-8 locale rejected", Failures)
    DiagnosticCount = 0
    Dim BadTemplateText As String = "UBE-Locale 1" & N & "Locale = " & StringFromByte(34) & "bad" & StringFromByte(34) & N & "Broken = " & StringFromByte(34) & "{missing-type}" & StringFromByte(34) & N
    Call ExpectTrue(IdeLoadLocaleText("bad-template.locale", BadTemplateText, InvalidLocale, InvalidLocaleKeys, InvalidLocaleValues, InvalidLocaleCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 And DiagnosticCount > 0, "malformed locale placeholder rejected", Failures)

    DiagnosticCount = 0
    Dim Envelope As IdeServiceEnvelope
    Dim EnvelopeText As String = "UBE-IDE-Protocol 1" & N & "RequestId = " & StringFromByte(34) & "7" & StringFromByte(34) & N & "DocumentVersion = " & StringFromByte(34) & "2" & StringFromByte(34) & N & "Method = " & StringFromByte(34) & "textDocument/definition" & StringFromByte(34) & N & "Status = " & StringFromByte(34) & "ok" & StringFromByte(34) & N & "Payload = " & StringFromByte(34) & "Main.bas:1:1" & StringFromByte(34) & N
    Call ExpectTrue(IdeLoadServiceEnvelope(EnvelopeText, Envelope, Diagnostics, DiagnosticCount, DiagnosticCapacity), "service envelope loads", Failures)
    Call ExpectTrue(IdeServiceResultIsCurrent(Envelope, 7, 2), "matching service result accepted", Failures)
    Call ExpectTrue(IdeServiceResultIsCurrent(Envelope, 7, 3) = 0, "stale service result rejected", Failures)

    DiagnosticCount = 0
    Dim BadEnvelope As IdeServiceEnvelope
    Call ExpectTrue(IdeLoadServiceEnvelope("UBE-IDE-Protocol 9" & N, BadEnvelope, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 And DiagnosticCount > 0, "incompatible service protocol rejected", Failures)
    DiagnosticCount = 0
    Call ExpectTrue(IdePublishText(WorkPath & "/missing-parent/file.txt", "data", 0, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 And DiagnosticCount > 0, "real host publication failure is controlled", Failures)

    If Failures = 0 Then
        Print "STEP1 PASS"
        Main = 0
    Else
        Print "STEP1 FAIL count=" & LongToString(Failures)
        Main = 1
    End If
End Function
