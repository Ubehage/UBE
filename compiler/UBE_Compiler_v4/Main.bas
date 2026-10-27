UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Sub PrintCompilerUsage()
    Print "usage: ube-v4 [--test-fault allocation|tool|write|cancel] <project.UBE> <target-triple>"
    Print "       ube-v4 [--test-fault allocation|tool|write|cancel] --emit-shell-record <project.UBE> <target-triple> <output.record>"
End Sub

Function IsTask2Fault(ByVal Value As String) As Long
    If Value = "allocation" Or Value = "tool" Or Value = "write" Or Value = "cancel" Then
        IsTask2Fault = 1
    Else
        IsTask2Fault = 0
    End If
End Function

Function Main() As Long
    Dim Limits As CompilerLimits
    Call InitializeCompilerLimits(Limits)
    Dim ArgumentCount As Long = CompilerArgumentCount()
    Dim ArgumentBase As Long = 0
    Dim FaultSite As String = ""
    Dim ArgumentBytes As String = ""
    Dim Index As Long = 0
    While Index < ArgumentCount
        If AppendBoundedText(ArgumentBytes, CompilerArgumentAt(Index), Limits.MaximumArgumentBytes) = 0 Then
            Print "error UBE6000: command arguments exceed the 4096-byte session limit"
            Main = 2
            Exit Function
        End If
        Index = Index + 1
    Wend
    If ArgumentCount >= 2 Then
        If CompilerArgumentAt(0) = "--test-fault" Then
            FaultSite = CompilerArgumentAt(1)
            If IsTask2Fault(FaultSite) = 0 Then
                Print "error UBE6000: unknown Task 2 fault site: " & FaultSite
                Main = 2
                Exit Function
            End If
            ArgumentBase = 2
            ArgumentCount = ArgumentCount - 2
        End If
    End If

    Dim Configuration As CompilerConfiguration
    Configuration.FaultSite = FaultSite
    If ArgumentCount = 2 Then
        Configuration.ProjectPath = CompilerArgumentAt(ArgumentBase)
        Configuration.TargetTriple = CompilerArgumentAt(ArgumentBase + 1)
        Configuration.PublishRecord = 0
    Else
        If ArgumentCount = 4 Then
            If CompilerArgumentAt(ArgumentBase) = "--emit-shell-record" Then
                Configuration.ProjectPath = CompilerArgumentAt(ArgumentBase + 1)
                Configuration.TargetTriple = CompilerArgumentAt(ArgumentBase + 2)
                Configuration.OutputPath = CompilerArgumentAt(ArgumentBase + 3)
                Configuration.PublishRecord = 1
            Else
                Call PrintCompilerUsage()
                Main = 2
                Exit Function
            End If
        Else
            Call PrintCompilerUsage()
            Main = 2
            Exit Function
        End If
    End If
    If Configuration.TargetTriple <> "x86_64-w64-windows-gnu" Then
        Print "error UBE6001: unsupported Task 2 target: " & Configuration.TargetTriple
        Main = 2
        Exit Function
    End If
    If Configuration.PublishRecord <> 0 And Configuration.OutputPath = "" Then
        Print "error UBE6000: output path must not be empty"
        Main = 2
        Exit Function
    End If
    Dim Session As BuildSession
    If CreateBuildSession(Configuration, Limits, Session) = 0 Or Session.Sealed = 0 Then
        Print "error UBE6000: project path and target must not be empty"
        Main = 2
        Exit Function
    End If
    Main = RunCompilerSession(Session)
End Function
