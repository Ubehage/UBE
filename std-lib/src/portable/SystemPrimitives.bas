UBE SOURCE 1 MODULE
Attribute UBE_Name = "SystemPrimitives"
' Declares counted operating-system input and standard-stream output boundaries.

' Copies the raw UTF-8 command line atomically into caller-provided capacity.
Public Intrinsic Function TryReadCommandLine(ByRef Destination() As Byte, ByRef Count As Long, ByRef Failure As Long) As Boolean
Attribute TryReadCommandLine.UBE_Primitive = "System.TryReadCommandLine"
End Function

' Writes one bounded chunk to stdout (1) or stderr (2), reporting confirmed progress.
Public Intrinsic Function TryWriteStandard(ByVal Stream As Long, ByRef Source() As Byte, ByVal Start As Long, ByVal Count As Long, ByRef Written As Long, ByRef Failure As Long) As Boolean
Attribute TryWriteStandard.UBE_Primitive = "System.TryWriteStandard"
End Function

' Returns the running executable's UTF-8 path into caller-provided capacity.
Public Intrinsic Function TryExecutablePath(ByRef Destination() As Byte, ByRef Count As Long, ByRef Failure As Long) As Boolean
Attribute TryExecutablePath.UBE_Primitive = "System.TryExecutablePath"
End Function

' Reads the monotonic operating-system millisecond counter without clearing Err.
Public Intrinsic Function TryMonotonicMilliseconds(ByRef Value As LongLong, ByRef Failure As Long) As Boolean
Attribute TryMonotonicMilliseconds.UBE_Primitive = "System.TryMonotonicMilliseconds"
End Function
