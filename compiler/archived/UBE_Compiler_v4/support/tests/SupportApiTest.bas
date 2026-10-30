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
    Print CompilerTextByteAt("UBE", 1)
    Print CompilerTextByteAt("UBE", 3)
    Dim Slice As String = "stale"
    Print CompilerTextSlice("compiler", 1, 3, Slice)
    Print Slice
    Print CompilerTextSlice("compiler", 7, 2, Slice)
    Print CompilerTextFromByte(65)
    Print CompilerTextFromByte(256)
    Print CompilerTextLength("three")
    Print CompilerLongToText(1203)
    Print CompilerLongToText(-1)
    Print CompilerCodePointIsLetter(197)
    Print CompilerCodePointIsLetter(48)
    Print CompilerFoldCodePoint(65)
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
