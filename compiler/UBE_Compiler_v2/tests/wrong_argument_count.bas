Sub Helper(ByVal Value As Long)
End Sub

Sub Caller()
    Call Helper()
End Sub

Sub Main()
    Print "unreachable"
End Sub
