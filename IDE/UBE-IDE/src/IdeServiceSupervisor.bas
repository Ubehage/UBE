UBE SOURCE 1 MODULE
Attribute UBE_Name = "IdeServiceSupervisor"

Type IdeServiceSupervisorState
    State As Long
    Generation As Long
    RequestId As Long
    DocumentVersion As Long
    DeadlineMilliseconds As Long
    RestartCount As Long
    RestartAtMilliseconds As Long
    LastOutcome As String
End Type

Function IdeServiceIdle() As Long
    IdeServiceIdle = 0
End Function

Function IdeServiceRunning() As Long
    IdeServiceRunning = 1
End Function

Function IdeServiceRestartWaiting() As Long
    IdeServiceRestartWaiting = 2
End Function

Function IdeServiceUnavailable() As Long
    IdeServiceUnavailable = 3
End Function

Sub IdeInitializeServiceSupervisor(ByRef Supervisor As IdeServiceSupervisorState)
    Supervisor.State = IdeServiceIdle()
    Supervisor.Generation = 1
    Supervisor.RequestId = 0
    Supervisor.DocumentVersion = 0
    Supervisor.DeadlineMilliseconds = 0
    Supervisor.RestartCount = 0
    Supervisor.RestartAtMilliseconds = 0
    Supervisor.LastOutcome = "Ready"
End Sub

Function IdeServiceStartRequest(ByRef Supervisor As IdeServiceSupervisorState, ByVal RequestId As Long, ByVal DocumentVersion As Long, ByVal NowMilliseconds As Long, ByVal TimeoutMilliseconds As Long) As Long
    If Supervisor.State <> IdeServiceIdle() Or RequestId < 1 Or DocumentVersion < 1 Then
        IdeServiceStartRequest = 0
        Exit Function
    End If
    If NowMilliseconds < 0 Or TimeoutMilliseconds < 50 Or TimeoutMilliseconds > 60000 Then
        IdeServiceStartRequest = 0
        Exit Function
    End If
    If NowMilliseconds > 2147483647 - TimeoutMilliseconds Then
        IdeServiceStartRequest = 0
        Exit Function
    End If
    Supervisor.State = IdeServiceRunning()
    Supervisor.RequestId = RequestId
    Supervisor.DocumentVersion = DocumentVersion
    Supervisor.DeadlineMilliseconds = NowMilliseconds + TimeoutMilliseconds
    Supervisor.LastOutcome = "Running"
    IdeServiceStartRequest = 1
End Function

Function IdeServiceAcceptResult(ByRef Supervisor As IdeServiceSupervisorState, ByVal RequestId As Long, ByVal DocumentVersion As Long) As Long
    If Supervisor.State <> IdeServiceRunning() Or Supervisor.RequestId <> RequestId Or Supervisor.DocumentVersion <> DocumentVersion Then
        IdeServiceAcceptResult = 0
        Exit Function
    End If
    Supervisor.State = IdeServiceIdle()
    Supervisor.RequestId = 0
    Supervisor.DocumentVersion = 0
    Supervisor.DeadlineMilliseconds = 0
    Supervisor.RestartCount = 0
    Supervisor.LastOutcome = "Completed"
    IdeServiceAcceptResult = 1
End Function

Sub IdeServiceScheduleRestart(ByRef Supervisor As IdeServiceSupervisorState, ByVal NowMilliseconds As Long, ByVal Outcome As String)
    Supervisor.RequestId = 0
    Supervisor.DocumentVersion = 0
    Supervisor.DeadlineMilliseconds = 0
    Supervisor.RestartCount = Supervisor.RestartCount + 1
    Supervisor.LastOutcome = Outcome
    If Supervisor.RestartCount > 3 Then
        Supervisor.State = IdeServiceUnavailable()
        Supervisor.RestartAtMilliseconds = 0
    Else
        Dim Delay As Long = Supervisor.RestartCount * 250
        Supervisor.State = IdeServiceRestartWaiting()
        If NowMilliseconds > 2147483647 - Delay Then
            Supervisor.RestartAtMilliseconds = 2147483647
        Else
            Supervisor.RestartAtMilliseconds = NowMilliseconds + Delay
        End If
    End If
End Sub

Function IdeServiceCancel(ByRef Supervisor As IdeServiceSupervisorState, ByVal RequestId As Long) As Long
    If Supervisor.State <> IdeServiceRunning() Or Supervisor.RequestId <> RequestId Then
        IdeServiceCancel = 0
        Exit Function
    End If
    Supervisor.State = IdeServiceIdle()
    Supervisor.RequestId = 0
    Supervisor.DocumentVersion = 0
    Supervisor.DeadlineMilliseconds = 0
    Supervisor.LastOutcome = "Cancelled"
    IdeServiceCancel = 1
End Function

Function IdeServiceTick(ByRef Supervisor As IdeServiceSupervisorState, ByVal NowMilliseconds As Long, ByVal HostAvailable As Long) As Long
    If NowMilliseconds < 0 Then
        IdeServiceTick = 0
        Exit Function
    End If
    If Supervisor.State = IdeServiceRunning() And NowMilliseconds >= Supervisor.DeadlineMilliseconds Then
        Call IdeServiceScheduleRestart(Supervisor, NowMilliseconds, "TimedOut")
        IdeServiceTick = 1
        Exit Function
    End If
    If Supervisor.State = IdeServiceRestartWaiting() And NowMilliseconds >= Supervisor.RestartAtMilliseconds Then
        If HostAvailable <> 0 Then
            Supervisor.State = IdeServiceIdle()
            Supervisor.Generation = Supervisor.Generation + 1
            Supervisor.RestartCount = 0
            Supervisor.LastOutcome = "Restarted"
        Else
            Call IdeServiceScheduleRestart(Supervisor, NowMilliseconds, "RestartFailed")
        End If
        IdeServiceTick = 1
        Exit Function
    End If
    IdeServiceTick = 1
End Function

Sub IdeServiceCrashed(ByRef Supervisor As IdeServiceSupervisorState, ByVal NowMilliseconds As Long)
    Call IdeServiceScheduleRestart(Supervisor, NowMilliseconds, "Crashed")
End Sub

Function IdeEditingRemainsAvailable(ByRef Supervisor As IdeServiceSupervisorState) As Long
    IdeEditingRemainsAvailable = 1
End Function
