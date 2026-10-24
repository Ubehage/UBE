UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Sub Step4Expect(ByVal Condition As Long, ByVal TestName As String, ByRef Failures As Long, ByRef Assertions As Long)
    Assertions = Assertions + 1
    If Condition <> 0 Then
        Print "PASS " & TestName
    Else
        Print "FAIL " & TestName
        Failures = Failures + 1
    End If
End Sub

Function Main() As Long
    Dim Failures As Long = 0
    Dim Assertions As Long = 0
    Dim Diagnostics() As IdeDiagnostic
    Dim DiagnosticCount As Long = 0
    Dim DiagnosticCapacity As Long = 0
    Dim Project As IdeProjectState
    Dim Sources() As String
    Dim SourceCapacity As Long = 0
    Dim UnknownKeys() As String
    Dim UnknownValues() As String
    Dim UnknownCapacity As Long = 0
    Dim Manifest As String = "UBE-Project 1" & StringFromByte(10) & "Name = " & IdeQuoteValue("OrderedProject") & StringFromByte(10) & "Kind = " & IdeQuoteValue("Exe") & StringFromByte(10) & "Startup = " & IdeQuoteValue("Main") & StringFromByte(10) & "Source = " & IdeQuoteValue("src/Zeta.bas") & StringFromByte(10) & "Source = " & IdeQuoteValue("src/Alpha.bas") & StringFromByte(10)
    Dim ProjectLoaded As Long = IdeLoadProjectText("ordered.UBE", Manifest, Project, Sources, SourceCapacity, UnknownKeys, UnknownValues, UnknownCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity)
    Call Step4Expect(ProjectLoaded, "real project model loads", Failures, Assertions)
    Call Step4Expect(Project.SourceCount = 2, "project exposes exact source count", Failures, Assertions)
    If ProjectLoaded = 0 Or Project.SourceCount <> 2 Then
        Print "STEP4 MODEL FAIL " & LongToString(Failures)
        Main = 1
        Exit Function
    End If
    Call Step4Expect(Sources(0) = "src/Zeta.bas" And Sources(1) = "src/Alpha.bas", "manifest source order is preserved", Failures, Assertions)

    Dim ExplorerText As String = ""
    Call Step4Expect(IdeBuildProjectExplorerText(Project, Sources, "Source", ExplorerText), "project explorer text builds", Failures, Assertions)
    Call Step4Expect(StringIndexOf(ExplorerText, "Zeta.bas", 0) < StringIndexOf(ExplorerText, "Alpha.bas", 0), "project explorer keeps manifest order", Failures, Assertions)
    Dim Selection As IdeWorkspaceSelection
    Call Step4Expect(IdeSelectWorkspaceItem(Project, Selection, 0), "project selection succeeds", Failures, Assertions)
    Dim PropertiesText As String = ""
    Call Step4Expect(IdeBuildWorkspacePropertiesText(Project, Sources, Selection, "Name", "Kind", "Startup", "Path", PropertiesText), "project properties build", Failures, Assertions)
    Call Step4Expect(StringIndexOf(PropertiesText, "OrderedProject", 0) >= 0, "properties reflect selected project", Failures, Assertions)
    Call Step4Expect(IdeSelectWorkspaceItem(Project, Selection, 2), "source selection succeeds", Failures, Assertions)
    Call Step4Expect(IdeBuildWorkspacePropertiesText(Project, Sources, Selection, "Name", "Kind", "Startup", "Path", PropertiesText), "source properties build", Failures, Assertions)
    Call Step4Expect(StringIndexOf(PropertiesText, "src/Alpha.bas", 0) >= 0, "properties follow selected source", Failures, Assertions)
    Call Step4Expect(IdeSelectWorkspaceItem(Project, Selection, 3) = 0, "invalid project selection is rejected", Failures, Assertions)

    Dim OutputBuffer As IdeOutputBuffer
    Call Step4Expect(IdeAppendOutput(OutputBuffer, "Project loaded"), "output accepts first bounded entry", Failures, Assertions)
    Call Step4Expect(IdeAppendOutput(OutputBuffer, "Build ready"), "output accepts ordered second entry", Failures, Assertions)
    Call Step4Expect(OutputBuffer.EntryCount = 2 And StringIndexOf(OutputBuffer.Contents, "Project loaded", 0) = 0, "output preserves bounded order", Failures, Assertions)
    Dim Oversized As String = ""
    Dim Index As Long = 0
    While Index <= IdeOutputEntryLimit()
        Oversized = Oversized & "x"
        Index = Index + 1
    Wend
    Call Step4Expect(IdeAppendOutput(OutputBuffer, Oversized) = 0, "oversized output entry is rejected", Failures, Assertions)
    Call Step4Expect(OutputBuffer.DroppedCount = 1 And OutputBuffer.EntryCount = 2, "rejected output cannot disturb retained entries", Failures, Assertions)

    Dim Layout As IdeLayoutState
    Call IdeDefaultLayout(Layout)
    Call Step4Expect(IdeApplyLayoutCommand(Layout, "Window.AutoHideOutput"), "output auto-hide command routes", Failures, Assertions)
    Call Step4Expect(Layout.OutputMode = IdeLayoutAutoHidden(), "output enters auto-hide mode", Failures, Assertions)
    Call Step4Expect(IdeApplyLayoutCommand(Layout, "Window.HideProperties"), "properties hide command routes", Failures, Assertions)
    Call Step4Expect(Layout.PropertiesMode = IdeLayoutHidden(), "properties enters hidden mode", Failures, Assertions)
    Call Step4Expect(IdeApplyLayoutCommand(Layout, "Window.GroupOutputRight"), "tool regroup command routes", Failures, Assertions)
    Call Step4Expect(Layout.OutputGroup = Layout.ProjectExplorerGroup, "output joins requested tool group", Failures, Assertions)
    Dim Serialized As String = ""
    Call Step4Expect(IdeSerializeLayout(Layout, Serialized), "custom workspace layout serializes", Failures, Assertions)
    Dim Restored As IdeLayoutState
    Call Step4Expect(IdeLoadLayoutText("layout", Serialized, Restored, Diagnostics, DiagnosticCount, DiagnosticCapacity), "custom workspace layout restores", Failures, Assertions)
    Call Step4Expect(Restored.OutputMode = IdeLayoutAutoHidden() And Restored.PropertiesMode = IdeLayoutHidden(), "hidden and auto-hidden state survives restart", Failures, Assertions)
    Call Step4Expect(Restored.OutputGroup = Restored.ProjectExplorerGroup, "tool grouping survives restart", Failures, Assertions)
    Call Step4Expect(IdeApplyLayoutCommand(Restored, "Window.ResetLayout"), "workspace reset routes", Failures, Assertions)
    Call Step4Expect(Restored.ProjectExplorerMode = IdeLayoutDocked() And Restored.PropertiesMode = IdeLayoutDocked() And Restored.OutputMode = IdeLayoutDocked(), "reset restores all real tools", Failures, Assertions)

    Dim Configuration As String = "UBE-IDE-Shell 1" & StringFromByte(10)
    Call Step4Expect(IdeAppendWorkspaceConfiguration(Configuration, ExplorerText, PropertiesText, OutputBuffer.Contents), "workspace configuration appends", Failures, Assertions)
    Call Step4Expect(StringIndexOf(Configuration, "Workspace.ProjectExplorer", 0) >= 0 And StringIndexOf(Configuration, "Zeta.bas", 0) >= 0, "configuration carries real ordered project state", Failures, Assertions)

    If Failures = 0 Then
        Print "STEP4 MODEL PASS " & LongToString(Assertions)
        Main = 0
    Else
        Print "STEP4 MODEL FAIL " & LongToString(Failures)
        Main = 1
    End If
End Function
