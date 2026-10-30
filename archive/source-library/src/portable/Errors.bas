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

' Returns the current thread's error number. A zero result means no error is
' currently recorded; successful operations do not clear an earlier value.
Public Function CurrentErrorNumber() As Long
    CurrentErrorNumber = RuntimeErrorNumber()
End Function

' Returns the current thread's error description as an independent String.
Public Function CurrentErrorDescription() As String
    CurrentErrorDescription = RuntimeErrorDescription()
End Function

' Returns the source recorded for the current thread's error.
Public Function CurrentErrorSource() As String
    CurrentErrorSource = RuntimeErrorSource()
End Function

' Explicitly clears the current thread's recoverable error state.
Public Sub ClearError()
    Call RuntimeErrorClear()
End Sub

' Records an application-defined recoverable error in the current thread.
Public Sub RaiseError(ByVal Number As Long, ByVal Description As String, ByVal Source As String)
    Call RuntimeErrorSet(Number, Description, Source)
End Sub
