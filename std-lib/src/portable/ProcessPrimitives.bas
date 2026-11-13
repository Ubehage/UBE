UBE SOURCE 1 MODULE
Attribute UBE_Name = "ProcessPrimitives"
' Declares owned child-process operations; ordinary callers choose deadlines and diagnostic policy.

' Starts a contained child with null stdin and one private log for stdout/stderr; failures may retain a cleanup owner.
Public Intrinsic Function TryStart(ByRef Application() As Byte, ByRef CommandLine() As Byte, ByRef Directory() As Byte, ByVal LogToken As Long, ByRef Token As Long, ByRef Failure As Long) As Boolean
Attribute TryStart.UBE_Primitive = "Process.TryStart"
End Function

' Observes bounded waiting; state one requires root exit and an empty contained job.
Public Intrinsic Function TryWait(ByVal Token As Long, ByVal Milliseconds As Long, ByRef State As Long, ByRef ExitCode As Long, ByRef Failure As Long) As Boolean
Attribute TryWait.UBE_Primitive = "Process.TryWait"
End Function

' Requests termination of the owned process tree without claiming that it has completed.
Public Intrinsic Function TryTerminate(ByVal Token As Long, ByRef Failure As Long) As Boolean
Attribute TryTerminate.UBE_Primitive = "Process.TryTerminate"
End Function

' Releases a stopped owner; failed close retains every unreleased native handle for retry.
Public Intrinsic Function TryClose(ByRef Token As Long, ByRef Failure As Long) As Boolean
Attribute TryClose.UBE_Primitive = "Process.TryClose"
End Function
