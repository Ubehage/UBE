UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Function Main() As Long
    If CommandArgumentCount() = 2 Then
        Main = RunCompilerDriver(CommandArgument(0), CommandArgument(1), 0)
        Exit Function
    End If
    If CommandArgumentCount() = 3 Then
        If CommandArgument(0) = "--dump-tokens" Then
            Main = RunCompilerDriver(CommandArgument(1), CommandArgument(2), 1)
            Exit Function
        End If
        If CommandArgument(0) = "--dump-syntax" Then
            Main = RunCompilerDriver(CommandArgument(1), CommandArgument(2), 2)
            Exit Function
        End If
        If CommandArgument(0) = "--dump-semantics" Then
            Main = RunCompilerDriver(CommandArgument(1), CommandArgument(2), 3)
            Exit Function
        End If
    End If
    If CommandArgumentCount() <> 2 Then
        Print "usage: ube-v3-rp4 [--dump-tokens|--dump-syntax|--dump-semantics] <project.UBE> <target-triple>"
        Main = 2
        Exit Function
    End If
End Function
