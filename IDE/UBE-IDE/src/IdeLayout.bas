UBE SOURCE 1 MODULE
Attribute UBE_Name = "IdeLayout"

Type IdeLayoutState
FormatVersion As Long
MainLeft As Long
MainTop As Long
MainWidth As Long
MainHeight As Long
MainMaximized As Long
ProjectExplorerMode As Long
ProjectExplorerLeft As Long
ProjectExplorerTop As Long
ProjectExplorerWidth As Long
ProjectExplorerHeight As Long
PropertiesMode As Long
PropertiesLeft As Long
PropertiesTop As Long
PropertiesWidth As Long
PropertiesHeight As Long
OutputMode As Long
OutputLeft As Long
OutputTop As Long
OutputWidth As Long
OutputHeight As Long
End Type

Function IdeLayoutDocked() As Long
IdeLayoutDocked = 0
End Function

Function IdeLayoutFloating() As Long
IdeLayoutFloating = 1
End Function

Function IdeLayoutHidden() As Long
IdeLayoutHidden = 2
End Function

Sub IdeDefaultLayout(ByRef Layout As IdeLayoutState)
Layout.FormatVersion = 1
Layout.MainLeft = 80
Layout.MainTop = 60
Layout.MainWidth = 1280
Layout.MainHeight = 800
Layout.MainMaximized = 0
Layout.ProjectExplorerMode = IdeLayoutDocked()
Layout.ProjectExplorerLeft = 880
Layout.ProjectExplorerTop = 100
Layout.ProjectExplorerWidth = 320
Layout.ProjectExplorerHeight = 360
Layout.PropertiesMode = IdeLayoutDocked()
Layout.PropertiesLeft = 900
Layout.PropertiesTop = 470
Layout.PropertiesWidth = 300
Layout.PropertiesHeight = 300
Layout.OutputMode = IdeLayoutDocked()
Layout.OutputLeft = 180
Layout.OutputTop = 560
Layout.OutputWidth = 800
Layout.OutputHeight = 220
End Sub

Function IdeParseSignedLong(ByVal Value As String, ByRef Result As Long) As Long
If StringLength(Value) = 0 Then
IdeParseSignedLong = 0
Exit Function
End If
Dim IsNegative As Long = 0
Dim Digits As String = Value
If StringByteAt(Value, 0) = 45 Then
IsNegative = 1
If StringLength(Value) = 1 Then
IdeParseSignedLong = 0
Exit Function
End If
Digits = StringSlice(Value, 1, StringLength(Value) - 1)
End If
Dim Magnitude As Long = 0
If IdeParseNonnegativeLong(Digits, Magnitude) = 0 Then
IdeParseSignedLong = 0
Exit Function
End If
If IsNegative <> 0 Then
Result = 0 - Magnitude
Else
Result = Magnitude
End If
IdeParseSignedLong = 1
End Function

Function IdeLayoutValueInRange(ByVal Value As Long, ByVal Minimum As Long, ByVal Maximum As Long) As Long
If Value < Minimum Or Value > Maximum Then
IdeLayoutValueInRange = 0
Else
IdeLayoutValueInRange = 1
End If
End Function

Function IdeValidateToolLayout(ByVal Mode As Long, ByVal LeftValue As Long, ByVal TopValue As Long, ByVal WidthValue As Long, ByVal HeightValue As Long) As Long
If Mode < IdeLayoutDocked() Or Mode > IdeLayoutHidden() Then
IdeValidateToolLayout = 0
Exit Function
End If
If IdeLayoutValueInRange(LeftValue, -100000, 100000) = 0 Or IdeLayoutValueInRange(TopValue, -100000, 100000) = 0 Then
IdeValidateToolLayout = 0
Exit Function
End If
If IdeLayoutValueInRange(WidthValue, 180, 8192) = 0 Or IdeLayoutValueInRange(HeightValue, 120, 8192) = 0 Then
IdeValidateToolLayout = 0
Exit Function
End If
IdeValidateToolLayout = 1
End Function

Function IdeValidateLayout(ByRef Layout As IdeLayoutState) As Long
If Layout.FormatVersion <> 1 Then
IdeValidateLayout = 0
Exit Function
End If
If IdeLayoutValueInRange(Layout.MainLeft, -100000, 100000) = 0 Or IdeLayoutValueInRange(Layout.MainTop, -100000, 100000) = 0 Then
IdeValidateLayout = 0
Exit Function
End If
If IdeLayoutValueInRange(Layout.MainWidth, 640, 8192) = 0 Or IdeLayoutValueInRange(Layout.MainHeight, 480, 8192) = 0 Then
IdeValidateLayout = 0
Exit Function
End If
If Layout.MainMaximized < 0 Or Layout.MainMaximized > 1 Then
IdeValidateLayout = 0
Exit Function
End If
If IdeValidateToolLayout(Layout.ProjectExplorerMode, Layout.ProjectExplorerLeft, Layout.ProjectExplorerTop, Layout.ProjectExplorerWidth, Layout.ProjectExplorerHeight) = 0 Then
IdeValidateLayout = 0
Exit Function
End If
If IdeValidateToolLayout(Layout.PropertiesMode, Layout.PropertiesLeft, Layout.PropertiesTop, Layout.PropertiesWidth, Layout.PropertiesHeight) = 0 Then
IdeValidateLayout = 0
Exit Function
End If
If IdeValidateToolLayout(Layout.OutputMode, Layout.OutputLeft, Layout.OutputTop, Layout.OutputWidth, Layout.OutputHeight) = 0 Then
IdeValidateLayout = 0
Exit Function
End If
IdeValidateLayout = 1
End Function

Function IdeAssignLayoutValue(ByRef Layout As IdeLayoutState, ByVal Key As String, ByVal Value As String) As Long
Dim Parsed As Long = 0
If IdeParseSignedLong(Value, Parsed) = 0 Then
IdeAssignLayoutValue = 0
Exit Function
End If
If IdeEqualsFolded(Key, "Main.Left") <> 0 Then
Layout.MainLeft = Parsed
ElseIf IdeEqualsFolded(Key, "Main.Top") <> 0 Then
Layout.MainTop = Parsed
ElseIf IdeEqualsFolded(Key, "Main.Width") <> 0 Then
Layout.MainWidth = Parsed
ElseIf IdeEqualsFolded(Key, "Main.Height") <> 0 Then
Layout.MainHeight = Parsed
ElseIf IdeEqualsFolded(Key, "Main.Maximized") <> 0 Then
Layout.MainMaximized = Parsed
ElseIf IdeEqualsFolded(Key, "ProjectExplorer.Mode") <> 0 Then
Layout.ProjectExplorerMode = Parsed
ElseIf IdeEqualsFolded(Key, "ProjectExplorer.Left") <> 0 Then
Layout.ProjectExplorerLeft = Parsed
ElseIf IdeEqualsFolded(Key, "ProjectExplorer.Top") <> 0 Then
Layout.ProjectExplorerTop = Parsed
ElseIf IdeEqualsFolded(Key, "ProjectExplorer.Width") <> 0 Then
Layout.ProjectExplorerWidth = Parsed
ElseIf IdeEqualsFolded(Key, "ProjectExplorer.Height") <> 0 Then
Layout.ProjectExplorerHeight = Parsed
ElseIf IdeEqualsFolded(Key, "Properties.Mode") <> 0 Then
Layout.PropertiesMode = Parsed
ElseIf IdeEqualsFolded(Key, "Properties.Left") <> 0 Then
Layout.PropertiesLeft = Parsed
ElseIf IdeEqualsFolded(Key, "Properties.Top") <> 0 Then
Layout.PropertiesTop = Parsed
ElseIf IdeEqualsFolded(Key, "Properties.Width") <> 0 Then
Layout.PropertiesWidth = Parsed
ElseIf IdeEqualsFolded(Key, "Properties.Height") <> 0 Then
Layout.PropertiesHeight = Parsed
ElseIf IdeEqualsFolded(Key, "Output.Mode") <> 0 Then
Layout.OutputMode = Parsed
ElseIf IdeEqualsFolded(Key, "Output.Left") <> 0 Then
Layout.OutputLeft = Parsed
ElseIf IdeEqualsFolded(Key, "Output.Top") <> 0 Then
Layout.OutputTop = Parsed
ElseIf IdeEqualsFolded(Key, "Output.Width") <> 0 Then
Layout.OutputWidth = Parsed
ElseIf IdeEqualsFolded(Key, "Output.Height") <> 0 Then
Layout.OutputHeight = Parsed
Else
IdeAssignLayoutValue = 0
Exit Function
End If
IdeAssignLayoutValue = 1
End Function

Function IdeLoadLayoutText(ByVal FilePath As String, ByVal Contents As String, ByRef Layout As IdeLayoutState, ByRef Diagnostics() As IdeDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
Call IdeDefaultLayout(Layout)
If StringLength(Contents) = 0 Then
IdeLoadLayoutText = 1
Exit Function
End If
If StringLength(Contents) > IdeLimitTextBytes() Then
Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE4101", FilePath, 1, 1, 2)
IdeLoadLayoutText = 0
Exit Function
End If
Dim InvalidByte As Long = -1
If IdeValidateUtf8(Contents, InvalidByte) = 0 Then
Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE4101", FilePath, 1, InvalidByte + 1, 2)
IdeLoadLayoutText = 0
Exit Function
End If
Dim Candidate As IdeLayoutState
Call IdeDefaultLayout(Candidate)
Dim Cursor As Long = 0
Dim LineText As String = ""
If IdeReadLine(Contents, Cursor, LineText) = 0 Or LineText <> "UBE-IDE-Layout 1" Then
Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE4101", FilePath, 1, 1, 2)
IdeLoadLayoutText = 0
Exit Function
End If
Dim LineNumber As Long = 1
While IdeReadLine(Contents, Cursor, LineText) <> 0
LineNumber = LineNumber + 1
Dim Trimmed As String = ""
Call IdeTrim(LineText, Trimmed)
If StringLength(Trimmed) > 0 Then
Dim Key As String = ""
Dim Value As String = ""
If IdeParseAssignment(Trimmed, Key, Value) = 0 Or IdeAssignLayoutValue(Candidate, Key, Value) = 0 Then
Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE4101", FilePath, LineNumber, 1, 2)
IdeLoadLayoutText = 0
Exit Function
End If
End If
Wend
If IdeValidateLayout(Candidate) = 0 Then
Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE4101", FilePath, 1, 1, 2)
IdeLoadLayoutText = 0
Exit Function
End If
Layout = Candidate
IdeLoadLayoutText = 1
End Function

Sub IdeAppendLayoutValue(ByRef Result As String, ByVal Key As String, ByVal Value As Long)
Result = Result & Key & " = " & IdeQuoteValue(LongToString(Value)) & StringFromByte(10)
End Sub

Function IdeSerializeLayout(ByRef Layout As IdeLayoutState, ByRef Result As String) As Long
If IdeValidateLayout(Layout) = 0 Then
Result = ""
IdeSerializeLayout = 0
Exit Function
End If
Result = "UBE-IDE-Layout 1" & StringFromByte(10)
Call IdeAppendLayoutValue(Result, "Main.Left", Layout.MainLeft)
Call IdeAppendLayoutValue(Result, "Main.Top", Layout.MainTop)
Call IdeAppendLayoutValue(Result, "Main.Width", Layout.MainWidth)
Call IdeAppendLayoutValue(Result, "Main.Height", Layout.MainHeight)
Call IdeAppendLayoutValue(Result, "Main.Maximized", Layout.MainMaximized)
Call IdeAppendLayoutValue(Result, "ProjectExplorer.Mode", Layout.ProjectExplorerMode)
Call IdeAppendLayoutValue(Result, "ProjectExplorer.Left", Layout.ProjectExplorerLeft)
Call IdeAppendLayoutValue(Result, "ProjectExplorer.Top", Layout.ProjectExplorerTop)
Call IdeAppendLayoutValue(Result, "ProjectExplorer.Width", Layout.ProjectExplorerWidth)
Call IdeAppendLayoutValue(Result, "ProjectExplorer.Height", Layout.ProjectExplorerHeight)
Call IdeAppendLayoutValue(Result, "Properties.Mode", Layout.PropertiesMode)
Call IdeAppendLayoutValue(Result, "Properties.Left", Layout.PropertiesLeft)
Call IdeAppendLayoutValue(Result, "Properties.Top", Layout.PropertiesTop)
Call IdeAppendLayoutValue(Result, "Properties.Width", Layout.PropertiesWidth)
Call IdeAppendLayoutValue(Result, "Properties.Height", Layout.PropertiesHeight)
Call IdeAppendLayoutValue(Result, "Output.Mode", Layout.OutputMode)
Call IdeAppendLayoutValue(Result, "Output.Left", Layout.OutputLeft)
Call IdeAppendLayoutValue(Result, "Output.Top", Layout.OutputTop)
Call IdeAppendLayoutValue(Result, "Output.Width", Layout.OutputWidth)
Call IdeAppendLayoutValue(Result, "Output.Height", Layout.OutputHeight)
IdeSerializeLayout = 1
End Function

Function IdeApplyLayoutCommand(ByRef Layout As IdeLayoutState, ByVal CommandId As String) As Long
If IdeEqualsFolded(CommandId, "Window.ResetLayout") <> 0 Then
Call IdeDefaultLayout(Layout)
ElseIf IdeEqualsFolded(CommandId, "Window.FloatProjectExplorer") <> 0 Then
Layout.ProjectExplorerMode = IdeLayoutFloating()
ElseIf IdeEqualsFolded(CommandId, "Window.DockProjectExplorer") <> 0 Then
Layout.ProjectExplorerMode = IdeLayoutDocked()
ElseIf IdeEqualsFolded(CommandId, "Window.FloatProperties") <> 0 Then
Layout.PropertiesMode = IdeLayoutFloating()
ElseIf IdeEqualsFolded(CommandId, "Window.DockProperties") <> 0 Then
Layout.PropertiesMode = IdeLayoutDocked()
ElseIf IdeEqualsFolded(CommandId, "Window.FloatOutput") <> 0 Then
Layout.OutputMode = IdeLayoutFloating()
ElseIf IdeEqualsFolded(CommandId, "Window.DockOutput") <> 0 Then
Layout.OutputMode = IdeLayoutDocked()
Else
IdeApplyLayoutCommand = 0
Exit Function
End If
IdeApplyLayoutCommand = 1
End Function
