UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Function Main() As Long
If CommandArgumentCount() < 5 Or CommandArgumentCount() > 6 Then
Print IdeEmergencyText(3)
Main = 2
Exit Function
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
Dim ConfigurationText As String = ""
If IdeBuildShellConfiguration(Layout, LocaleKeys, LocaleValues, Locale.EntryCount, ConfigurationText) = 0 Then
Print IdeEmergencyText(1)
Main = 4
Exit Function
End If
If WriteAllText(ConfigurationPath, ConfigurationText) <> 0 Then
Print IdeEmergencyText(3)
Main = 5
Exit Function
End If
Call CompilerDeleteFile(ResultPath)

Dim HostArguments() As String
Dim HostArgumentCount As Long = 4
If CommandArgumentCount() = 6 Then
HostArgumentCount = 5
End If
ReDim HostArguments(HostArgumentCount - 1)
HostArguments(0) = "--config"
HostArguments(1) = ConfigurationPath
HostArguments(2) = "--result"
HostArguments(3) = ResultPath
If HostArgumentCount = 5 Then
HostArguments(4) = CommandArgument(5)
End If
Dim HostStatus As Long = CompilerRunTool(HostPath, HostArguments, HostArgumentCount)
If HostStatus <> 0 Then
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
If IdeSerializeLayout(ReturnedLayout, SavedText) = 0 Or WriteAllText(LayoutPath, SavedText) <> 0 Then
Print IdeEmergencyText(3)
Main = 8
Exit Function
End If
If HostArgumentCount = 5 Then
Print "STEP2 SHELL PASS"
End If
Main = 0
End Function
