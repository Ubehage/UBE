UBE SOURCE 1 MODULE
Attribute UBE_Name = "IdeWorkspaceTools"

Type IdeWorkspaceSelection
    ItemIndex As Long
End Type

Type IdeOutputBuffer
    Contents As String
    EntryCount As Long
    DroppedCount As Long
End Type

Function IdeOutputByteLimit() As Long
    IdeOutputByteLimit = 65536
End Function

Function IdeOutputEntryLimit() As Long
    IdeOutputEntryLimit = 4096
End Function

Function IdeSelectWorkspaceItem(ByRef Project As IdeProjectState, ByRef Selection As IdeWorkspaceSelection, ByVal ItemIndex As Long) As Long
    If ItemIndex < 0 Or ItemIndex > Project.SourceCount Then
        IdeSelectWorkspaceItem = 0
        Exit Function
    End If
    Selection.ItemIndex = ItemIndex
    IdeSelectWorkspaceItem = 1
End Function

Function IdeBuildProjectExplorerText(ByRef Project As IdeProjectState, ByRef Sources() As String, ByVal SourceLabel As String, ByRef Result As String) As Long
    If StringLength(Project.ProjectName) = 0 Or Project.SourceCount < 1 Then
        Result = ""
        IdeBuildProjectExplorerText = 0
        Exit Function
    End If
    Result = Project.ProjectName
    Dim Index As Long = 0
    While Index < Project.SourceCount
        Result = Result & StringFromByte(10) & "  " & SourceLabel & " " & LongToString(Index + 1) & ": " & Sources(Index)
        If StringLength(Result) > IdeLimitProtocolBytes() Then
            Result = ""
            IdeBuildProjectExplorerText = 0
            Exit Function
        End If
        Index = Index + 1
    Wend
    IdeBuildProjectExplorerText = 1
End Function

Function IdeBuildWorkspacePropertiesText(ByRef Project As IdeProjectState, ByRef Sources() As String, ByRef Selection As IdeWorkspaceSelection, ByVal NameLabel As String, ByVal KindLabel As String, ByVal StartupLabel As String, ByVal PathLabel As String, ByRef Result As String) As Long
    If Selection.ItemIndex < 0 Or Selection.ItemIndex > Project.SourceCount Then
        Result = ""
        IdeBuildWorkspacePropertiesText = 0
        Exit Function
    End If
    If Selection.ItemIndex = 0 Then
        Result = NameLabel & ": " & Project.ProjectName & StringFromByte(10) & KindLabel & ": " & Project.ProjectKind
        If StringLength(Project.Startup) > 0 Then
            Result = Result & StringFromByte(10) & StartupLabel & ": " & Project.Startup
        End If
    Else
        Result = NameLabel & ": " & Sources(Selection.ItemIndex - 1) & StringFromByte(10) & PathLabel & ": " & Sources(Selection.ItemIndex - 1)
    End If
    IdeBuildWorkspacePropertiesText = 1
End Function

Function IdeAppendOutput(ByRef Buffer As IdeOutputBuffer, ByVal EntryText As String) As Long
    Dim InvalidByte As Long = -1
    Dim EntryBytes As Long = StringLength(EntryText)
    If EntryBytes = 0 Or EntryBytes > IdeOutputEntryLimit() Or IdeValidateUtf8(EntryText, InvalidByte) = 0 Then
        Buffer.DroppedCount = Buffer.DroppedCount + 1
        IdeAppendOutput = 0
        Exit Function
    End If
    Dim Candidate As String = EntryText
    If StringLength(Buffer.Contents) > 0 Then
        Candidate = Buffer.Contents & StringFromByte(10) & EntryText
    End If
    While StringLength(Candidate) > IdeOutputByteLimit()
        Dim FirstBreak As Long = StringIndexOf(Candidate, StringFromByte(10), 0)
        If FirstBreak < 0 Then
            Buffer.DroppedCount = Buffer.DroppedCount + 1
            IdeAppendOutput = 0
            Exit Function
        End If
        Candidate = StringSlice(Candidate, FirstBreak + 1, StringLength(Candidate) - FirstBreak - 1)
        If Buffer.EntryCount > 0 Then
            Buffer.EntryCount = Buffer.EntryCount - 1
        End If
        Buffer.DroppedCount = Buffer.DroppedCount + 1
    Wend
    Buffer.Contents = Candidate
    Buffer.EntryCount = Buffer.EntryCount + 1
    IdeAppendOutput = 1
End Function

Function IdeWorkspaceDisplayLine(ByVal Value As String, ByRef Result As String) As Long
    Result = ""
    Dim Index As Long = 0
    While Index < StringLength(Value)
        Dim CurrentByte As Long = StringByteAt(Value, Index)
        If CurrentByte = 10 Then
            Result = Result & " | "
        ElseIf CurrentByte <> 13 Then
            Result = Result & StringSlice(Value, Index, 1)
        End If
        If StringLength(Result) >= 2000 Then
            IdeWorkspaceDisplayLine = 0
            Result = ""
            Exit Function
        End If
        Index = Index + 1
    Wend
    IdeWorkspaceDisplayLine = 1
End Function

Function IdeAppendWorkspaceConfiguration(ByRef Configuration As String, ByVal ProjectText As String, ByVal PropertiesText As String, ByVal OutputText As String) As Long
    Dim ProjectLine As String = ""
    Dim PropertiesLine As String = ""
    Dim OutputLine As String = ""
    If IdeWorkspaceDisplayLine(ProjectText, ProjectLine) = 0 Then
        IdeAppendWorkspaceConfiguration = 0
        Exit Function
    End If
    If IdeWorkspaceDisplayLine(PropertiesText, PropertiesLine) = 0 Then
        IdeAppendWorkspaceConfiguration = 0
        Exit Function
    End If
    If IdeWorkspaceDisplayLine(OutputText, OutputLine) = 0 Then
        IdeAppendWorkspaceConfiguration = 0
        Exit Function
    End If
    Call IdeAppendShellValue(Configuration, "Workspace.Enabled", "1")
    Call IdeAppendShellValue(Configuration, "Workspace.ProjectExplorer", ProjectLine)
    Call IdeAppendShellValue(Configuration, "Workspace.Properties", PropertiesLine)
    Call IdeAppendShellValue(Configuration, "Workspace.Output", OutputLine)
    IdeAppendWorkspaceConfiguration = 1
End Function
