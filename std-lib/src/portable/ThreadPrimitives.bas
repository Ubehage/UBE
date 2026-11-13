UBE SOURCE 1 MODULE
Attribute UBE_Name = "ThreadPrimitives"
' Declares native worker observations with explicit timeouts and fresh failure outcomes.

' Returns the stable process-wide identity of the calling UBE thread.
Public Intrinsic Function CurrentId() As LongLong
Attribute CurrentId.UBE_Primitive = "Thread.CurrentId"
End Function

' Observes whether a known thread in this program is still executing.
Public Intrinsic Function IsAlive(ByVal Id As LongLong) As Boolean
Attribute IsAlive.UBE_Primitive = "Thread.IsAlive"
End Function

' Returns one for completion or zero for timeout/caller stop; worker FAIL is delivered freshly.
Public Intrinsic Function Wait(ByVal Id As LongLong, ByVal Timeout As LongLong) As Long
Attribute Wait.UBE_Primitive = "Thread.Wait"
End Function

' Requests cooperative stopping and returns one only while the target is running.
Public Intrinsic Function RequestStop(ByVal Id As LongLong) As Long
Attribute RequestStop.UBE_Primitive = "Thread.RequestStop"
End Function

' Observes only the calling thread's stop request.
Public Intrinsic Function StopRequested() As Boolean
Attribute StopRequested.UBE_Primitive = "Thread.StopRequested"
End Function

' Gives another ready native thread a scheduling opportunity.
Private Intrinsic Function YieldCore() As Boolean
Attribute YieldCore.UBE_Primitive = "Thread.Yield"
End Function

' Exposes scheduling without manufacturing a source result value.
Public Sub Yield()
    Call YieldCore()
End Sub
