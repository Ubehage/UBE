UBE SOURCE 1 MODULE
Attribute UBE_Name = "Threads"

' Returns the stable, process-local identifier of the calling thread.
Public Function CurrentThreadId() As LongLong
    CurrentThreadId = RuntimeCurrentThreadId()
End Function

' Returns True while Id names a worker that has not completed. An issued,
' completed identifier returns False without changing Err.
Public Function ThreadIsAlive(ByVal Id As LongLong) As Boolean
    ThreadIsAlive = RuntimeThreadIsAlive(Id)
End Function

' Waits indefinitely for Id to complete. The result is 1 on completion and 0
' on cancellation or failure; a genuine failure is also recorded in Err.
Public Function ThreadWait(ByVal Id As LongLong) As Long
    ThreadWait = RuntimeThreadWait(Id, -1)
End Function

' Waits at most TimeoutMilliseconds for Id. A timeout returns 0 without
' changing Err; -1 selects an unlimited wait.
Public Function ThreadWaitTimeout(ByVal Id As LongLong, ByVal TimeoutMilliseconds As LongLong) As Long
    ThreadWaitTimeout = RuntimeThreadWait(Id, TimeoutMilliseconds)
End Function

' Requests cooperative termination. The target observes this request through
' ThreadStopRequested and returns normally so ordinary cleanup still runs.
Public Function ThreadRequestStop(ByVal Id As LongLong) As Long
    ThreadRequestStop = RuntimeThreadRequestStop(Id)
End Function

' Returns True when cooperative stop has been requested for this worker.
Public Function ThreadStopRequested() As Boolean
    ThreadStopRequested = RuntimeThreadStopRequested()
End Function

' Offers another runnable thread an opportunity to execute.
Public Sub ThreadYield()
    Call RuntimeThreadYield()
End Sub
