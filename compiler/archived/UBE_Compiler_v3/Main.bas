UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Function IsCompilerExecutorFault(ByVal FaultSite As String) As Long
    If EqualsFolded(FaultSite, "worker-creation") <> 0 Then
        IsCompilerExecutorFault = 1
        Exit Function
    End If
    If EqualsFolded(FaultSite, "task-publication") <> 0 Then
        IsCompilerExecutorFault = 1
        Exit Function
    End If
    If EqualsFolded(FaultSite, "result-allocation") <> 0 Then
        IsCompilerExecutorFault = 1
        Exit Function
    End If
    If EqualsFolded(FaultSite, "cancellation") <> 0 Then
        IsCompilerExecutorFault = 1
        Exit Function
    End If
    If EqualsFolded(FaultSite, "merge") <> 0 Then
        IsCompilerExecutorFault = 1
        Exit Function
    End If
    If EqualsFolded(FaultSite, "frontend-worker-creation") <> 0 Then
        IsCompilerExecutorFault = 1
        Exit Function
    End If
    If EqualsFolded(FaultSite, "frontend-worker-wait") <> 0 Then
        IsCompilerExecutorFault = 1
        Exit Function
    End If
    If EqualsFolded(FaultSite, "frontend-merge") <> 0 Then
        IsCompilerExecutorFault = 1
        Exit Function
    End If
    If EqualsFolded(FaultSite, "semantic-worker-creation") <> 0 Then
        IsCompilerExecutorFault = 1
        Exit Function
    End If
    If EqualsFolded(FaultSite, "semantic-worker-wait") <> 0 Then
        IsCompilerExecutorFault = 1
        Exit Function
    End If
    If EqualsFolded(FaultSite, "semantic-merge") <> 0 Then
        IsCompilerExecutorFault = 1
        Exit Function
    End If
    If EqualsFolded(FaultSite, "semantic-transfer") <> 0 Then
        IsCompilerExecutorFault = 1
        Exit Function
    End If
    IsCompilerExecutorFault = 0
End Function

Sub PrintCompilerUsage()
    Print "usage: ube-v3-rp8 [--jobs N] [--dump-tokens|--dump-syntax|--dump-semantics|--dump-ir|--dump-managed] <project.UBE> <target-triple> [output.ll]"
    Print "       ube-v3-rp8 [--jobs N] --profile <project.UBE> <target-triple> <output.ll> <profile.txt>"
    Print "       ube-v3-rp8 [--jobs N] --build-native <project.UBE> <target-triple> <clang> <runtime.o> <unicode-runtime.o> <output> <intermediate.ll>"
End Sub

Function ParseCompilerJobCount(ByVal TextValue As String, ByRef Result As Long) As Long
    Dim Length As Long = StringLength(TextValue)
    If Length = 0 Then
        ParseCompilerJobCount = 0
        Exit Function
    End If
    Dim Index As Long = 0
    Dim Value As Long = 0
    While Index < Length
        Dim Digit As Long = StringByteAt(TextValue, Index) - 48
        If Digit < 0 Or Digit > 9 Then
            ParseCompilerJobCount = 0
            Exit Function
        End If
        If Value > 214748364 Or Value = 214748364 And Digit > 7 Then
            ParseCompilerJobCount = 0
            Exit Function
        End If
        Value = Value * 10 + Digit
        Index = Index + 1
    Wend
    If Value < 1 Then
        ParseCompilerJobCount = 0
        Exit Function
    End If
    Result = Value
    ParseCompilerJobCount = 1
End Function

Function DispatchCompilerCommand(ByVal ArgumentBase As Long, ByVal ArgumentCount As Long, ByVal RequestedJobs As Long, ByVal FaultSite As String) As Long
    Dim Task As CompilerTask
    If ArgumentCount = 2 Then
        Task.Argument1 = CommandArgument(ArgumentBase)
        Task.Argument2 = CommandArgument(ArgumentBase + 1)
        If HasSuffix(Task.Argument1, ".UBG") <> 0 Then
            Task.TaskKind = 2
        Else
            Task.TaskKind = 1
            Task.OutputMode = 0
        End If
        DispatchCompilerCommand = RunCompilerExecutorTask(Task, RequestedJobs, FaultSite)
        Exit Function
    End If
    If ArgumentCount = 3 Then
        Task.TaskKind = 1
        Task.Argument1 = CommandArgument(ArgumentBase + 1)
        Task.Argument2 = CommandArgument(ArgumentBase + 2)
        If CommandArgument(ArgumentBase) = "--dump-tokens" Then
            Task.OutputMode = 1
            DispatchCompilerCommand = RunCompilerExecutorTask(Task, RequestedJobs, FaultSite)
            Exit Function
        End If
        If CommandArgument(ArgumentBase) = "--dump-syntax" Then
            Task.OutputMode = 2
            DispatchCompilerCommand = RunCompilerExecutorTask(Task, RequestedJobs, FaultSite)
            Exit Function
        End If
        If CommandArgument(ArgumentBase) = "--dump-semantics" Then
            Task.OutputMode = 3
            DispatchCompilerCommand = RunCompilerExecutorTask(Task, RequestedJobs, FaultSite)
            Exit Function
        End If
        If CommandArgument(ArgumentBase) = "--dump-ir" Then
            Task.OutputMode = 4
            DispatchCompilerCommand = RunCompilerExecutorTask(Task, RequestedJobs, FaultSite)
            Exit Function
        End If
        If CommandArgument(ArgumentBase) = "--dump-managed" Then
            Task.OutputMode = 6
            DispatchCompilerCommand = RunCompilerExecutorTask(Task, RequestedJobs, FaultSite)
            Exit Function
        End If
    End If
    If ArgumentCount = 4 Then
        If CommandArgument(ArgumentBase) = "--emit-llvm" Then
            Task.TaskKind = 1
            Task.OutputMode = 5
            Task.Argument1 = CommandArgument(ArgumentBase + 1)
            Task.Argument2 = CommandArgument(ArgumentBase + 2)
            Task.Argument3 = CommandArgument(ArgumentBase + 3)
            DispatchCompilerCommand = RunCompilerExecutorTask(Task, RequestedJobs, FaultSite)
            Exit Function
        End If
    End If
    If ArgumentCount = 5 Then
        If CommandArgument(ArgumentBase) = "--profile" Then
            Task.TaskKind = 1
            Task.OutputMode = 5
            Task.Argument1 = CommandArgument(ArgumentBase + 1)
            Task.Argument2 = CommandArgument(ArgumentBase + 2)
            Task.Argument3 = CommandArgument(ArgumentBase + 3)
            Task.Argument4 = CommandArgument(ArgumentBase + 4)
            DispatchCompilerCommand = RunCompilerExecutorTask(Task, RequestedJobs, FaultSite)
            Exit Function
        End If
    End If
    If ArgumentCount = 8 Then
        If CommandArgument(ArgumentBase) = "--build-native" Then
            Task.TaskKind = 3
            Task.Argument1 = CommandArgument(ArgumentBase + 1)
            Task.Argument2 = CommandArgument(ArgumentBase + 2)
            Task.Argument3 = CommandArgument(ArgumentBase + 3)
            Task.Argument4 = CommandArgument(ArgumentBase + 4)
            Task.Argument5 = CommandArgument(ArgumentBase + 5)
            Task.Argument6 = CommandArgument(ArgumentBase + 6)
            Task.Argument7 = CommandArgument(ArgumentBase + 7)
            DispatchCompilerCommand = RunCompilerExecutorTask(Task, RequestedJobs, FaultSite)
            Exit Function
        End If
    End If
    Call PrintCompilerUsage()
    DispatchCompilerCommand = 2
End Function

Function Main() As Long
    Dim ArgumentBase As Long = 0
    Dim Remaining As Long = CommandArgumentCount()
    Dim RequestedJobs As Long = 1
    Dim FaultSite As String = ""
    Dim ParsingOptions As Long = 1
    While ParsingOptions <> 0
        ParsingOptions = 0
        If Remaining >= 2 Then
            If CommandArgument(ArgumentBase) = "--jobs" Then
                If ParseCompilerJobCount(CommandArgument(ArgumentBase + 1), RequestedJobs) = 0 Then
                    Call ReportExecutorFailure("UBE5300", "--jobs requires a positive decimal Long value")
                    Main = 2
                    Exit Function
                End If
                ArgumentBase = ArgumentBase + 2
                Remaining = Remaining - 2
                ParsingOptions = 1
            End If
        End If
        If ParsingOptions = 0 And Remaining >= 2 Then
            If CommandArgument(ArgumentBase) = "--executor-fault" Then
                FaultSite = CommandArgument(ArgumentBase + 1)
                If IsCompilerExecutorFault(FaultSite) = 0 Then
                    Call ReportExecutorFailure("UBE5300", "unknown compiler executor fault site: " & FaultSite)
                    Main = 2
                    Exit Function
                End If
                ArgumentBase = ArgumentBase + 2
                Remaining = Remaining - 2
                ParsingOptions = 1
            End If
        End If
    Wend
    Main = DispatchCompilerCommand(ArgumentBase, Remaining, RequestedJobs, FaultSite)
End Function
