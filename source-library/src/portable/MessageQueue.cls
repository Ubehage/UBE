UBE SOURCE 1 CLASS
Attribute UBE_Name = "MessageQueue"

Private Handle As LongLong

' Creates an empty FIFO queue.
Private Sub Class_Initialize()
    Handle = RuntimeMessageQueueCreate()
End Sub

' Wakes current waiters, releases queued managed values, and frees the queue's
' internal resources. User-owned resources inside payload objects are untouched.
Private Sub Class_Terminate()
    Call RuntimeMessageQueueDestroy(Handle)
    Handle = 0
End Sub

' Copies Value into the FIFO. Object payloads keep shared object identity.
' Returns 1 on success, or 0 with Err when copying or admission fails.
Public Function Enqueue(ByVal Value As Variant) As Long
    Enqueue = RuntimeMessageQueueEnqueue(Handle, Value)
End Function

' Removes the oldest value. Value changes only on success. -1 waits forever;
' timeout or cooperative cancellation returns 0 without changing Value.
Public Function Dequeue(ByRef Value As Variant, ByVal TimeoutMilliseconds As LongLong) As Long
    Dequeue = RuntimeMessageQueueDequeue(Handle, Value, TimeoutMilliseconds)
End Function
