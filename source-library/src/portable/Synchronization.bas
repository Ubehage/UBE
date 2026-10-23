UBE SOURCE 1 MODULE
Attribute UBE_Name = "Synchronization"

' Creates a configured thread event. ManualReset keeps a signal available to
' all waiters until Reset; InitiallySignaled controls its first state.
Public Function CreateThreadEvent(Optional ByVal ManualReset As Boolean = False, Optional ByVal InitiallySignaled As Boolean = False) As ThreadEvent
    Dim Result As New ThreadEvent
    If Result.Configure(ManualReset, InitiallySignaled) <> 0 Then
        Set CreateThreadEvent = Result
    Else
        Set CreateThreadEvent = Nothing
    End If
End Function

' Creates a FIFO semaphore with the requested initial and maximum permit
' counts. Invalid bounds return Nothing and record Err.
Public Function CreateSemaphore(ByVal InitialCount As LongLong, ByVal MaximumCount As LongLong) As Semaphore
    Dim Result As New Semaphore
    If Result.Configure(InitialCount, MaximumCount) <> 0 Then
        Set CreateSemaphore = Result
    Else
        Set CreateSemaphore = Nothing
    End If
End Function
