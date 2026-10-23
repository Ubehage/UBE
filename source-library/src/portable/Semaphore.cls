UBE SOURCE 1 CLASS
Attribute UBE_Name = "Semaphore"

Private Handle As LongLong

' Creates a valid zero-permit semaphore for direct New expressions.
Private Sub Class_Initialize()
    Handle = RuntimeSemaphoreCreate(0, 1)
End Sub

' Wakes current waiters and releases the semaphore's internal resources.
Private Sub Class_Terminate()
    Call RuntimeSemaphoreDestroy(Handle)
    Handle = 0
End Sub

' Replaces the default semaphore with the bounds requested by the factory.
' Returns 0 with Err when the counts are invalid or allocation fails.
Public Function Configure(ByVal InitialCount As LongLong, ByVal MaximumCount As LongLong) As Long
    Call RuntimeSemaphoreDestroy(Handle)
    Handle = RuntimeSemaphoreCreate(InitialCount, MaximumCount)
    If Handle <> 0 Then
        Configure = 1
    Else
        Configure = 0
    End If
End Function

' Consumes one permit. -1 waits indefinitely and 0 performs a nonblocking
' check. Timeout or cooperative cancellation returns 0 without adding Err.
Public Function Wait(ByVal TimeoutMilliseconds As LongLong) As Long
    Wait = RuntimeSemaphoreWait(Handle, TimeoutMilliseconds)
End Function

' Adds PermitCount permits in FIFO waiter order. The default adds one. Invalid
' counts or exceeding the configured maximum return 0 and record Err.
Public Function Release(Optional ByVal PermitCount As LongLong = 1) As Long
    Release = RuntimeSemaphoreRelease(Handle, PermitCount)
End Function
