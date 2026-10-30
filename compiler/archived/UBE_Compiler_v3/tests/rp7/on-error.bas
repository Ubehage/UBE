UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Sub Main()
    Call ResumeNextMode()
    Call HandlerResumeNext()
    Call HandlerRetry()
    Call HandlerResumeLabel()
    Call ExplicitError()
    Call DirectGoTo()
    Call DisabledHandler()
End Sub

Sub DirectGoTo()
    Print 1
    GoTo 100
    Print 99
100:
    Print 2
End Sub

Sub DisabledHandler()
    Dim Value As Long
    On Error GoTo Failed
    On Error GoTo 0
    Value = 10 \ 0
    Print Value
    Print 33
    Exit Sub
Failed:
    Print 99
End Sub

Sub ResumeNextMode()
    Dim Value As Long
    On Error Resume Next
    Value = 10 \ 0
    Print Value
    Print Err.Number
    On Error GoTo 0
End Sub

Sub HandlerResumeNext()
    Dim Value As Long
    On Error GoTo Failed
    Value = 10 \ 0
    Print 22
    Print Err.Number
    Exit Sub
Failed:
    Print Err.Number
    Resume Next
End Sub

Sub HandlerRetry()
    Dim Divisor As Long
    Dim Value As Long
    On Error GoTo Failed
    Value = 10 \ Divisor
    Print Value
    Exit Sub
Failed:
    Divisor = 2
    Resume
End Sub

Sub HandlerResumeLabel()
    Dim Value As Long
    On Error GoTo Failed
    Value = 10 \ 0
    Print 99
    Exit Sub
Failed:
    Resume Recovered
Recovered:
    Print 44
End Sub

Sub ExplicitError()
    On Error GoTo Failed
    Error 123
    Print 55
    Exit Sub
Failed:
    Print Err.Number
    Resume Next
End Sub
