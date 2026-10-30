UBE SOURCE 1 MODULE
Attribute UBE_Name = "IoProcessTest"

Function Main() As Long
    If CompilerArgumentCount() <> 3 Then
        Main = 1
        Exit Function
    End If
    Dim InputPath As String = CompilerArgumentAt(0)
    Dim OutputPath As String = CompilerArgumentAt(1)
    Dim ToolPath As String = CompilerArgumentAt(2)
    Dim Contents As String = ""
    If ReadRequiredCompilerText(InputPath, Contents) = 0 Then
        Main = 2
        Exit Function
    End If
    If PublishCompilerText(OutputPath, Contents) <> 0 Then
        Main = 3
        Exit Function
    End If
    Dim Published As String = ""
    If ReadRequiredCompilerText(OutputPath, Published) = 0 Or Published <> Contents Then
        Main = 4
        Exit Function
    End If
    Dim ToolArguments() As String
    ReDim ToolArguments(0)
    ToolArguments(0) = "cmd.exe"
    If RunCompilerTool(ToolPath, ToolArguments, 1) <> 0 Then
        Main = 5
        Exit Function
    End If
    If RemoveCompilerArtifact(OutputPath) <> 0 Then
        Main = 6
        Exit Function
    End If
    Print "io-process-cleanup-passed"
    Main = 0
End Function
