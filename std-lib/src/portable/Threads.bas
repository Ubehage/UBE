UBE SOURCE 1 MODULE
Attribute UBE_Name = "Threads"

' Fresh status for existing thread identities and cooperative completion/stop.
' Contract: ../../THREADS-CONTRACT.md. Outputs are borrowed, preserved on False;
' True publishes a fresh value and preserves Err. No compiler or scheduler state.

' Returns the positive calling thread identity; failure preserves Id and sets Err.
Intrinsic Function TryCurrentThreadId(ByRef Id As LongLong) As Boolean
Attribute TryCurrentThreadId.UBE_Primitive = "Thread.TryCurrentId"
End Function

' Observes an issued identity. A completed issued worker is successful Alive=False.
Intrinsic Function TryThreadIsAlive(ByVal Id As LongLong, ByRef Alive As Boolean) As Boolean
Attribute TryThreadIsAlive.UBE_Primitive = "Thread.TryIsAlive"
End Function

' Requests sticky cooperative stop; Requested=False means an already completed ID.
Intrinsic Function TryThreadRequestStop(ByVal Id As LongLong, ByRef Requested As Boolean) As Boolean
Attribute TryThreadRequestStop.UBE_Primitive = "Thread.TryRequestStop"
End Function

' Observes the caller's sticky stop request; it never clears or forcibly stops it.
Intrinsic Function TryThreadStopRequested(ByRef Requested As Boolean) As Boolean
Attribute TryThreadStopRequested.UBE_Primitive = "Thread.TryStopRequested"
End Function

' Timeout is milliseconds or -1. Only Completed=True permits completion cleanup.
Intrinsic Function TryThreadWait(ByVal Id As LongLong, ByVal Timeout As LongLong, ByRef Completed As Boolean) As Boolean
Attribute TryThreadWait.UBE_Primitive = "Thread.TryWait"
End Function

' Issues a scheduling hint, retaining no input, output, capture or external handle.
Intrinsic Function TryThreadYield() As Boolean
Attribute TryThreadYield.UBE_Primitive = "Thread.TryYield"
End Function
