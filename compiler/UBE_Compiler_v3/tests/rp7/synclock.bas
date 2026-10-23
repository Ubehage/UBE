UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Intrinsic Function RuntimeThreadWait(ByVal Id As LongLong, ByVal TimeoutMilliseconds As LongLong) As Long
End Function

Sub Main()
    Dim CounterValue As New SyncCounter
    Dim First As LongLong
    Dim Second As LongLong
    First = CallNew Worker(CounterValue)
    Second = CallNew Worker(CounterValue)
    Print RuntimeThreadWait(First, 5000)
    Print RuntimeThreadWait(Second, 5000)
    SyncLock CounterValue
        SyncLock CounterValue
            CounterValue.Value = CounterValue.Value + 1
        End SyncLock
    End SyncLock
    Print CounterValue.Value
End Sub

Sub Worker(ByVal CounterValue As SyncCounter)
    SyncLock CounterValue
        CounterValue.Value = CounterValue.Value + 1
    End SyncLock
End Sub
