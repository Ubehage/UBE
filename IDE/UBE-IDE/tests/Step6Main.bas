UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Sub Step6Expect(ByVal Condition As Long, ByVal TestName As String, ByRef Failures As Long, ByRef Assertions As Long)
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
    Dim Supervisor As IdeServiceSupervisorState
    Call IdeInitializeServiceSupervisor(Supervisor)
    Call Step6Expect(Supervisor.State = IdeServiceIdle() And Supervisor.Generation = 1, "supervisor starts ready", Failures, Assertions)
    Call Step6Expect(IdeServiceStartRequest(Supervisor, 1, 7, 1000, 500), "bounded request starts", Failures, Assertions)
    Call Step6Expect(Supervisor.State = IdeServiceRunning() And Supervisor.DeadlineMilliseconds = 1500, "request records deadline", Failures, Assertions)
    Call Step6Expect(IdeServiceAcceptResult(Supervisor, 2, 7) = 0, "wrong request result is stale", Failures, Assertions)
    Call Step6Expect(Supervisor.State = IdeServiceRunning(), "stale result leaves request intact", Failures, Assertions)
    Call Step6Expect(IdeServiceAcceptResult(Supervisor, 1, 8) = 0, "wrong document version is stale", Failures, Assertions)
    Call Step6Expect(IdeServiceAcceptResult(Supervisor, 1, 7), "matching result completes", Failures, Assertions)
    Call Step6Expect(Supervisor.State = IdeServiceIdle() And Supervisor.LastOutcome = "Completed", "completion returns ready", Failures, Assertions)

    Call Step6Expect(IdeServiceStartRequest(Supervisor, 2, 8, 2000, 250), "timeout request starts", Failures, Assertions)
    Call Step6Expect(IdeServiceTick(Supervisor, 2249, 1) And Supervisor.State = IdeServiceRunning(), "request remains before deadline", Failures, Assertions)
    Call Step6Expect(IdeServiceTick(Supervisor, 2250, 1) And Supervisor.State = IdeServiceRestartWaiting(), "hang reaches timeout state", Failures, Assertions)
    Call Step6Expect(Supervisor.LastOutcome = "TimedOut" And Supervisor.RestartAtMilliseconds = 2500, "timeout schedules bounded restart", Failures, Assertions)
    Call Step6Expect(IdeEditingRemainsAvailable(Supervisor), "editing survives service timeout", Failures, Assertions)
    Call Step6Expect(IdeServiceTick(Supervisor, 2500, 1) And Supervisor.State = IdeServiceIdle(), "service restarts after timeout", Failures, Assertions)
    Call Step6Expect(Supervisor.Generation = 2 And Supervisor.LastOutcome = "Restarted", "restart advances generation", Failures, Assertions)

    Call Step6Expect(IdeServiceStartRequest(Supervisor, 3, 9, 3000, 500), "crash request starts", Failures, Assertions)
    Call IdeServiceCrashed(Supervisor, 3100)
    Call Step6Expect(Supervisor.State = IdeServiceRestartWaiting() And Supervisor.LastOutcome = "Crashed", "crash is isolated", Failures, Assertions)
    Call Step6Expect(IdeEditingRemainsAvailable(Supervisor), "editing survives service crash", Failures, Assertions)
    Call Step6Expect(IdeServiceTick(Supervisor, Supervisor.RestartAtMilliseconds, 1) And Supervisor.State = IdeServiceIdle(), "service restarts after crash", Failures, Assertions)

    Call Step6Expect(IdeServiceStartRequest(Supervisor, 4, 10, 4000, 500), "cancellable request starts", Failures, Assertions)
    Call Step6Expect(IdeServiceCancel(Supervisor, 99) = 0, "wrong cancellation is ignored", Failures, Assertions)
    Call Step6Expect(IdeServiceCancel(Supervisor, 4), "matching request cancels", Failures, Assertions)
    Call Step6Expect(Supervisor.State = IdeServiceIdle() And Supervisor.LastOutcome = "Cancelled", "cancellation is ordinary", Failures, Assertions)
    Call Step6Expect(IdeServiceStartRequest(Supervisor, 0, 1, 0, 500) = 0, "invalid request id rejected", Failures, Assertions)
    Call Step6Expect(IdeServiceStartRequest(Supervisor, 5, 0, 0, 500) = 0, "invalid document version rejected", Failures, Assertions)
    Call Step6Expect(IdeServiceStartRequest(Supervisor, 5, 1, 0, 49) = 0, "unsafe timeout rejected", Failures, Assertions)
    Call Step6Expect(IdeServiceStartRequest(Supervisor, 5, 1, 2147483600, 500) = 0, "deadline overflow rejected", Failures, Assertions)

    Call IdeServiceCrashed(Supervisor, 5000)
    Call Step6Expect(IdeServiceTick(Supervisor, Supervisor.RestartAtMilliseconds, 0) And Supervisor.State = IdeServiceRestartWaiting(), "first restart failure remains bounded", Failures, Assertions)
    Call Step6Expect(IdeServiceTick(Supervisor, Supervisor.RestartAtMilliseconds, 0) And Supervisor.State = IdeServiceRestartWaiting(), "second restart failure remains bounded", Failures, Assertions)
    Call Step6Expect(IdeServiceTick(Supervisor, Supervisor.RestartAtMilliseconds, 0) And Supervisor.State = IdeServiceUnavailable(), "retry limit reaches explicit unavailable state", Failures, Assertions)
    Call Step6Expect(IdeEditingRemainsAvailable(Supervisor), "editing remains available when service unavailable", Failures, Assertions)

    Dim Result As IdeLanguageResult
    Call Step6Expect(IdeLoadLanguageResult("", Result) = 0, "empty service message rejected", Failures, Assertions)
    Call Step6Expect(IdeLoadLanguageResult("UBE-IDE-Language-Result 1" & StringFromByte(10) & "RequestId = ""999999999999999999""", Result) = 0, "overflowing service field rejected", Failures, Assertions)
    Call Step6Expect(IdeLoadLanguageResult("UBE-IDE-Language-Result 999", Result) = 0, "incompatible protocol rejected", Failures, Assertions)

    If Failures = 0 Then
        Print "STEP6 PASS " & LongToString(Assertions)
        Main = 0
    Else
        Print "STEP6 FAIL " & LongToString(Failures)
        Main = 1
    End If
End Function
