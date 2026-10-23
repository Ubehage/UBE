UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Intrinsic Function RuntimeThreadWait(ByVal Id As LongLong, ByVal TimeoutMilliseconds As LongLong) As Long
End Function

Sub Main()
    Dim CounterValue As New SyncCounter
    Call RetryInsideLock(CounterValue)
    Print CounterValue.Value
    Call LeaveLockFromHandler(CounterValue)
    Dim WorkerId As LongLong
    WorkerId = CallNew Worker(CounterValue)
    Print RuntimeThreadWait(WorkerId, 5000)
    Print CounterValue.Value
End Sub

Sub RetryInsideLock(ByVal CounterValue As SyncCounter)
    Dim Divisor As Long
    Dim Value As Long
    On Error GoTo Failed
    SyncLock CounterValue
        Value = 10 \ Divisor
        CounterValue.Value = CounterValue.Value + Value
    End SyncLock
    Exit Sub
Failed:
    Divisor = 2
    Resume
End Sub

Sub LeaveLockFromHandler(ByVal CounterValue As SyncCounter)
    Dim Value As Long
    On Error GoTo Failed
    SyncLock CounterValue
        Value = 10 \ 0
    End SyncLock
    Exit Sub
Failed:
    Resume Recovered
Recovered:
    Print 44
End Sub

Sub Worker(ByVal CounterValue As SyncCounter)
    SyncLock CounterValue
        CounterValue.Value = CounterValue.Value + 1
    End SyncLock
End Sub
