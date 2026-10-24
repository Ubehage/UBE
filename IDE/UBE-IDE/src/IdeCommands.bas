UBE SOURCE 1 MODULE
Attribute UBE_Name = "IdeCommands"

Type IdeCommand
    CommandId As String
    LabelKey As String
    IsEnabled As Long
End Type

Function IdeRegisterCommand(ByRef Commands() As IdeCommand, ByRef Count As Long, ByRef Capacity As Long, ByVal CommandId As String, ByVal LabelKey As String) As Long
    If StringLength(CommandId) = 0 Or StringLength(LabelKey) = 0 Or Count >= IdeLimitCommands() Then
        IdeRegisterCommand = 0
        Exit Function
    End If
    Dim Index As Long = 0
    While Index < Count
        If IdeEqualsFolded(Commands(Index).CommandId, CommandId) <> 0 Then
            IdeRegisterCommand = 0
            Exit Function
        End If
        Index = Index + 1
    Wend
    If Count = Capacity Then
        Dim NewCapacity As Long = 16
        If Capacity > 0 Then
            NewCapacity = Capacity * 2
        End If
        If Capacity = 0 Then
            ReDim Commands(NewCapacity - 1)
        Else
            ReDim Preserve Commands(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Commands(Count).CommandId = CommandId
    Commands(Count).LabelKey = LabelKey
    Commands(Count).IsEnabled = 1
    Count = Count + 1
    IdeRegisterCommand = 1
End Function

Function IdeSetCommandEnabled(ByRef Commands() As IdeCommand, ByVal Count As Long, ByVal CommandId As String, ByVal IsEnabled As Long) As Long
    Dim Index As Long = 0
    While Index < Count
        If IdeEqualsFolded(Commands(Index).CommandId, CommandId) <> 0 Then
            If IsEnabled = 0 Then
                Commands(Index).IsEnabled = 0
            Else
                Commands(Index).IsEnabled = 1
            End If
            IdeSetCommandEnabled = 1
            Exit Function
        End If
        Index = Index + 1
    Wend
    IdeSetCommandEnabled = 0
End Function

