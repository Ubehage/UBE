UBE SOURCE 1 MODULE
Attribute UBE_Name = "MonitorSupport"
' Reentrant ownership uses native atomics; ordinary waiting policy remains portable UBE.
' The compiler retains the object root before calling and marks acquired only on success.
Public Function Enter(ByVal Identity As LongLong) As Boolean
    On Error GoTo Failed
    Do
        If ObjectPrimitives.TryEnter(Identity) <> 0 Then
            Enter = True
            Exit Function
        End If
        Call ObjectPrimitives.YieldWait()
    Loop
Failed:
    Err.Raise Err.Number
End Function
