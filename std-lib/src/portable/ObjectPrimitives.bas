UBE SOURCE 1 MODULE
Attribute UBE_Name = "ObjectPrimitives"
' Internal compiler support: identities here do not make integers valid SyncLock operands.
' The caller publishes an exact object root throughout every operation and wait.
Public Intrinsic Function TryEnter(ByVal Identity As LongLong) As Long
Attribute TryEnter.UBE_Primitive = "Object.MonitorTryEnter"
End Function

Public Intrinsic Function Leave(ByVal Identity As LongLong) As Boolean
Attribute Leave.UBE_Primitive = "Object.MonitorLeave"
End Function

Public Intrinsic Function YieldWait() As Boolean
Attribute YieldWait.UBE_Primitive = "Object.MonitorYield"
End Function
