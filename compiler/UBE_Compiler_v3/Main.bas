Function Main() As Long
    If CommandArgumentCount() <> 2 Then
        Print "usage: ube-v3-rp1 <project.UBE> <target-triple>"
        Main = 2
        Exit Function
    End If
    Main = RunCompilerDriver(CommandArgument(0), CommandArgument(1))
End Function
