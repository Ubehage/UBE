UBE SOURCE 1 MODULE
Attribute UBE_Name = "IdeShell"

Sub IdeAppendShellValue(ByRef Result As String, ByVal Key As String, ByVal Value As String)
Result = Result & Key & " = " & IdeQuoteValue(Value) & StringFromByte(10)
End Sub

Function IdeShellText(ByRef Keys() As String, ByRef Values() As String, ByVal Count As Long, ByVal Key As String, ByRef Value As String) As Long
IdeShellText = IdeGetLocalizedText(Keys, Values, Count, Keys, Values, Count, Key, Value)
End Function

Function IdeBuildShellConfiguration(ByRef Layout As IdeLayoutState, ByRef LocaleKeys() As String, ByRef LocaleValues() As String, ByVal LocaleCount As Long, ByRef Result As String) As Long
If IdeValidateLayout(Layout) = 0 Then
Result = ""
IdeBuildShellConfiguration = 0
Exit Function
End If
Result = "UBE-IDE-Shell 1" & StringFromByte(10)
Dim LayoutText As String = ""
If IdeSerializeLayout(Layout, LayoutText) = 0 Then
Result = ""
IdeBuildShellConfiguration = 0
Exit Function
End If
Dim Cursor As Long = 0
Dim LineText As String = ""
Call IdeReadLine(LayoutText, Cursor, LineText)
While IdeReadLine(LayoutText, Cursor, LineText) <> 0
Result = Result & LineText & StringFromByte(10)
Wend
Dim TextValue As String = ""
Dim RequiredKeys() As String
ReDim RequiredKeys(32)
RequiredKeys(0) = "Shell.Title"
RequiredKeys(1) = "Menu.File"
RequiredKeys(2) = "Menu.Edit"
RequiredKeys(3) = "Menu.View"
RequiredKeys(4) = "Menu.Window"
RequiredKeys(5) = "Menu.Help"
RequiredKeys(6) = "Command.File.New"
RequiredKeys(7) = "Command.File.Open"
RequiredKeys(8) = "Command.File.Save"
RequiredKeys(9) = "Command.File.Exit"
RequiredKeys(10) = "Command.Edit.Undo"
RequiredKeys(11) = "Command.Edit.Redo"
RequiredKeys(12) = "Command.View.ProjectExplorer"
RequiredKeys(13) = "Command.View.Properties"
RequiredKeys(14) = "Command.View.Output"
RequiredKeys(15) = "Command.Window.FloatProjectExplorer"
RequiredKeys(16) = "Command.Window.DockProjectExplorer"
RequiredKeys(17) = "Command.Window.FloatProperties"
RequiredKeys(18) = "Command.Window.DockProperties"
RequiredKeys(19) = "Command.Window.FloatOutput"
RequiredKeys(20) = "Command.Window.DockOutput"
RequiredKeys(21) = "Command.Window.FocusNextPane"
RequiredKeys(22) = "Command.Window.ResetLayout"
RequiredKeys(23) = "Command.Help.About"
RequiredKeys(24) = "Tool.ProjectExplorer.Title"
RequiredKeys(25) = "Tool.Properties.Title"
RequiredKeys(26) = "Tool.Output.Title"
RequiredKeys(27) = "Document.Welcome.Title"
RequiredKeys(28) = "Document.Welcome.Text"
RequiredKeys(29) = "Status.Ready"
RequiredKeys(30) = "Shell.Placeholder.Project"
RequiredKeys(31) = "Shell.Placeholder.Properties"
RequiredKeys(32) = "Shell.Placeholder.Output"
Dim Index As Long = 0
While Index <= 32
If IdeShellText(LocaleKeys, LocaleValues, LocaleCount, RequiredKeys(Index), TextValue) = 0 Then
Result = ""
IdeBuildShellConfiguration = 0
Exit Function
End If
Call IdeAppendShellValue(Result, "Text." & RequiredKeys(Index), TextValue)
Index = Index + 1
Wend
IdeBuildShellConfiguration = 1
End Function

Function IdeRegisterShellCommands(ByRef Commands() As IdeCommand, ByRef Count As Long, ByRef Capacity As Long) As Long
Dim Success As Long = 1
Success = Success And IdeRegisterCommand(Commands, Count, Capacity, "File.New", "Command.File.New")
Success = Success And IdeRegisterCommand(Commands, Count, Capacity, "File.Open", "Command.File.Open")
Success = Success And IdeRegisterCommand(Commands, Count, Capacity, "File.Save", "Command.File.Save")
Success = Success And IdeRegisterCommand(Commands, Count, Capacity, "File.Exit", "Command.File.Exit")
Success = Success And IdeRegisterCommand(Commands, Count, Capacity, "Edit.Undo", "Command.Edit.Undo")
Success = Success And IdeRegisterCommand(Commands, Count, Capacity, "Edit.Redo", "Command.Edit.Redo")
Success = Success And IdeRegisterCommand(Commands, Count, Capacity, "View.ProjectExplorer", "Command.View.ProjectExplorer")
Success = Success And IdeRegisterCommand(Commands, Count, Capacity, "View.Properties", "Command.View.Properties")
Success = Success And IdeRegisterCommand(Commands, Count, Capacity, "View.Output", "Command.View.Output")
Success = Success And IdeRegisterCommand(Commands, Count, Capacity, "Window.FloatProjectExplorer", "Command.Window.FloatProjectExplorer")
Success = Success And IdeRegisterCommand(Commands, Count, Capacity, "Window.DockProjectExplorer", "Command.Window.DockProjectExplorer")
Success = Success And IdeRegisterCommand(Commands, Count, Capacity, "Window.FloatProperties", "Command.Window.FloatProperties")
Success = Success And IdeRegisterCommand(Commands, Count, Capacity, "Window.DockProperties", "Command.Window.DockProperties")
Success = Success And IdeRegisterCommand(Commands, Count, Capacity, "Window.FloatOutput", "Command.Window.FloatOutput")
Success = Success And IdeRegisterCommand(Commands, Count, Capacity, "Window.DockOutput", "Command.Window.DockOutput")
Success = Success And IdeRegisterCommand(Commands, Count, Capacity, "Window.FocusNextPane", "Command.Window.FocusNextPane")
Success = Success And IdeRegisterCommand(Commands, Count, Capacity, "Window.ResetLayout", "Command.Window.ResetLayout")
Success = Success And IdeRegisterCommand(Commands, Count, Capacity, "Help.About", "Command.Help.About")
IdeRegisterShellCommands = Success
End Function
