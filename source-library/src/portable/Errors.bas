UBE SOURCE 1 MODULE
Attribute UBE_Name = "Errors"

' Returns 1 when Status is the successful status value zero.
Public Function StatusSucceeded(ByVal Status As Long) As Long
    If Status = 0 Then
        StatusSucceeded = 1
    Else
        StatusSucceeded = 0
    End If
End Function

' Returns 1 when Status reports a failure and 0 for success.
Public Function StatusFailed(ByVal Status As Long) As Long
    If Status = 0 Then
        StatusFailed = 0
    Else
        StatusFailed = 1
    End If
End Function
