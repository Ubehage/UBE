Sub Helper(ByVal Value As Long)
End Sub

Sub Caller()
    Call Helper(1, )
End Sub

Sub Main()
    Print "unreachable"
End Sub
