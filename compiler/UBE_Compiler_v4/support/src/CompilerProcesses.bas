UBE SOURCE 1 MODULE
Attribute UBE_Name = "CompilerProcesses"

' Runs one executable with separately captured arguments. The call waits and
' releases process resources. It returns the child status or -1/-2/-3 for the
' documented validation, launch, and wait failures.
Public Function RunCompilerTool(ByVal ExecutablePath As String, ByRef Arguments() As String, ByVal ArgumentCount As Long) As Long
    RunCompilerTool = CompilerRunTool(ExecutablePath, Arguments, ArgumentCount)
End Function
