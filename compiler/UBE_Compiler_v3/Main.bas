UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Function Main() As Long
    If CommandArgumentCount() = 2 Then
        If HasSuffix(CommandArgument(0), ".UBG") <> 0 Then
            Main = RunProjectGroupDriver(CommandArgument(0), CommandArgument(1))
        Else
            Main = RunCompilerDriver(CommandArgument(0), CommandArgument(1), 0, "", "")
        End If
        Exit Function
    End If
    If CommandArgumentCount() = 3 Then
        If CommandArgument(0) = "--dump-tokens" Then
            Main = RunCompilerDriver(CommandArgument(1), CommandArgument(2), 1, "", "")
            Exit Function
        End If
        If CommandArgument(0) = "--dump-syntax" Then
            Main = RunCompilerDriver(CommandArgument(1), CommandArgument(2), 2, "", "")
            Exit Function
        End If
        If CommandArgument(0) = "--dump-semantics" Then
            Main = RunCompilerDriver(CommandArgument(1), CommandArgument(2), 3, "", "")
            Exit Function
        End If
        If CommandArgument(0) = "--dump-ir" Then
            Main = RunCompilerDriver(CommandArgument(1), CommandArgument(2), 4, "", "")
            Exit Function
        End If
        If CommandArgument(0) = "--dump-managed" Then
            Main = RunCompilerDriver(CommandArgument(1), CommandArgument(2), 6, "", "")
            Exit Function
        End If
    End If
    If CommandArgumentCount() = 4 Then
        If CommandArgument(0) = "--emit-llvm" Then
            Main = RunCompilerDriver(CommandArgument(1), CommandArgument(2), 5, CommandArgument(3), "")
            Exit Function
        End If
    End If
    If CommandArgumentCount() = 5 Then
        If CommandArgument(0) = "--profile" Then
            Main = RunCompilerDriver(CommandArgument(1), CommandArgument(2), 5, CommandArgument(3), CommandArgument(4))
            Exit Function
        End If
    End If
    If CommandArgumentCount() = 8 Then
        If CommandArgument(0) = "--build-native" Then
            Main = RunNativeCompilerDriver(CommandArgument(1), CommandArgument(2), CommandArgument(3), CommandArgument(4), CommandArgument(5), CommandArgument(6), CommandArgument(7))
            Exit Function
        End If
    End If
    If CommandArgumentCount() <> 2 Then
        Print "usage: ube-v3-rp8 [--dump-tokens|--dump-syntax|--dump-semantics|--dump-ir|--dump-managed] <project.UBE> <target-triple> [output.ll]"
        Print "       ube-v3-rp8 --profile <project.UBE> <target-triple> <output.ll> <profile.txt>"
        Print "       ube-v3-rp8 --build-native <project.UBE> <target-triple> <clang> <runtime.o> <unicode-runtime.o> <output> <intermediate.ll>"
        Main = 2
        Exit Function
    End If
End Function
