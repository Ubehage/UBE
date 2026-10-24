UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Sub Step2Expect(ByVal Condition As Long, ByVal TestName As String, ByRef Failures As Long)
If Condition <> 0 Then
Print "PASS " & TestName
Else
Print "FAIL " & TestName
Failures = Failures + 1
End If
End Sub

Function Main() As Long
If CommandArgumentCount() <> 1 Then
Main = 2
Exit Function
End If
Dim LocalePath As String = CommandArgument(0)
Dim Failures As Long = 0
Dim Diagnostics() As IdeDiagnostic
Dim DiagnosticCount As Long = 0
Dim DiagnosticCapacity As Long = 0

Dim Layout As IdeLayoutState
Call IdeDefaultLayout(Layout)
Call Step2Expect(IdeValidateLayout(Layout), "default layout validates", Failures)
Call Step2Expect(Layout.ProjectExplorerMode = IdeLayoutDocked(), "project explorer defaults docked right", Failures)
Call Step2Expect(Layout.PropertiesMode = IdeLayoutDocked(), "properties defaults docked right", Failures)
Call Step2Expect(Layout.OutputMode = IdeLayoutDocked(), "output defaults docked bottom", Failures)

Dim Serialized As String = ""
Call Step2Expect(IdeSerializeLayout(Layout, Serialized), "layout serializes", Failures)
Dim Parsed As IdeLayoutState
Call Step2Expect(IdeLoadLayoutText("layout", Serialized, Parsed, Diagnostics, DiagnosticCount, DiagnosticCapacity), "layout round trip parses", Failures)
Call Step2Expect(Parsed.MainWidth = 1280 And Parsed.MainHeight = 800, "layout round trip preserves main bounds", Failures)

Call Step2Expect(IdeApplyLayoutCommand(Parsed, "Window.FloatProjectExplorer"), "float command routes", Failures)
Call Step2Expect(Parsed.ProjectExplorerMode = IdeLayoutFloating(), "float command changes model", Failures)
Call Step2Expect(IdeApplyLayoutCommand(Parsed, "Window.DockProjectExplorer"), "dock command routes", Failures)
Call Step2Expect(Parsed.ProjectExplorerMode = IdeLayoutDocked(), "dock command changes model", Failures)
Call Step2Expect(IdeApplyLayoutCommand(Parsed, "Window.FloatProperties"), "properties float command routes", Failures)
Call Step2Expect(IdeApplyLayoutCommand(Parsed, "Window.FloatOutput"), "output float command routes", Failures)
Call Step2Expect(IdeApplyLayoutCommand(Parsed, "Window.ResetLayout"), "reset layout command routes", Failures)
Call Step2Expect(Parsed.PropertiesMode = IdeLayoutDocked() And Parsed.OutputMode = IdeLayoutDocked(), "reset restores accepted docking", Failures)
Call Step2Expect(IdeApplyLayoutCommand(Parsed, "Unknown.Command") = 0, "unknown layout command rejected", Failures)

Dim SignedValue As Long = 0
Call Step2Expect(IdeParseSignedLong("-1920", SignedValue) And SignedValue = -1920, "negative monitor coordinate parses", Failures)
Call Step2Expect(IdeParseSignedLong("north", SignedValue) = 0, "invalid coordinate rejected", Failures)

Dim BeforeInvalid As Long = DiagnosticCount
Dim Corrupt As IdeLayoutState
Call Step2Expect(IdeLoadLayoutText("corrupt", "UBE-IDE-Layout 1" & StringFromByte(10) & "Main.Width = " & IdeQuoteValue("1") & StringFromByte(10), Corrupt, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0, "corrupt layout rejected", Failures)
Call Step2Expect(DiagnosticCount = BeforeInvalid + 1, "corrupt layout reports one diagnostic", Failures)
Call Step2Expect(Corrupt.MainWidth = 1280, "corrupt layout retains safe default", Failures)

Dim Commands() As IdeCommand
Dim CommandCount As Long = 0
Dim CommandCapacity As Long = 0
Call Step2Expect(IdeRegisterShellCommands(Commands, CommandCount, CommandCapacity), "shell commands register", Failures)
Call Step2Expect(CommandCount = 18, "complete shell command inventory registered", Failures)
Call Step2Expect(IdeRegisterShellCommands(Commands, CommandCount, CommandCapacity) = 0, "duplicate shell command inventory rejected", Failures)

Dim Locale As IdeLocaleState
Dim Keys() As String
Dim Values() As String
Dim LocaleCapacity As Long = 0
Dim LocaleText As String = ReadAllText(LocalePath)
DiagnosticCount = 0
Dim LocaleLoaded As Long = IdeLoadLocaleText(LocalePath, LocaleText, Locale, Keys, Values, LocaleCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity)
Call Step2Expect(LocaleLoaded, "source locale loads for shell", Failures)
If LocaleLoaded = 0 And DiagnosticCount > 0 Then
Print "LOCALE DIAGNOSTIC " & Diagnostics(DiagnosticCount - 1).Code & " LINE " & LongToString(Diagnostics(DiagnosticCount - 1).SourceLine)
End If
If LocaleLoaded <> 0 Then
Dim Configuration As String = ""
Call Step2Expect(IdeBuildShellConfiguration(Layout, Keys, Values, Locale.EntryCount, Configuration), "localized shell configuration builds", Failures)
Call Step2Expect(IdeStartsWith(Configuration, "UBE-IDE-Shell 1"), "shell configuration is versioned", Failures)
Call Step2Expect(StringIndexOf(Configuration, "Text.Shell.Title", 0) >= 0, "shell configuration contains localized title", Failures)
Call Step2Expect(StringIndexOf(Configuration, "Text.Tool.ProjectExplorer.Title", 0) >= 0, "shell configuration contains localized tool title", Failures)
End If

If Failures = 0 Then
Print "STEP2 MODEL PASS"
Main = 0
Else
Print "STEP2 MODEL FAIL " & LongToString(Failures)
Main = 1
End If
End Function
