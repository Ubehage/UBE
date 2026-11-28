UBE SOURCE 1 MODULE
Attribute UBE_Name = "LeasePrimitives"
' Owns fail-immediate, process-lifetime named reservations at the operating-system boundary.

' Acquires a case-insensitive named lease; failure 19 means another live owner holds the key.
' A false result can retain a token when releasing a rejected acquisition fails; close it explicitly.
Public Intrinsic Function TryAcquire(ByRef KeyUtf8() As Byte, ByRef Token As Long, ByRef Failure As Long) As Boolean
Attribute TryAcquire.UBE_Primitive = "Lease.TryAcquire"
End Function

' Releases only a lease owner, retaining its token when the operating-system close fails.
Public Intrinsic Function TryClose(ByRef Token As Long, ByRef Failure As Long) As Boolean
Attribute TryClose.UBE_Primitive = "Lease.TryClose"
End Function
