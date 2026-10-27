UBE SOURCE 1 MODULE
Attribute UBE_Name = "SupportApiTest"

Function Main() As Long
    Dim Buffer As String = ""
    Dim Path As String = ""
    Print AppendBoundedText(Buffer, "UBE", 3)
    Print Buffer
    Print AppendBoundedText(Buffer, "!", 3)
    Print NormalizeCompilerRelativePath("src\main.bas", Path)
    Print Path
    Print NormalizeCompilerRelativePath("../escape.bas", Path)
    Print AppendRecordField(Buffer, "phase", "shell", 64)
    Print Buffer
    Print AppendRecordField(Buffer, "bad key", "x", 64)
    If CompilerElapsedMilliseconds() < -1 Then
        Main = 10
        Exit Function
    End If
    If CompilerCpuMilliseconds() < -1 Then
        Main = 11
        Exit Function
    End If
    If CompilerPeakBytes() < -1 Then
        Main = 12
        Exit Function
    End If
    Main = 0
End Function
