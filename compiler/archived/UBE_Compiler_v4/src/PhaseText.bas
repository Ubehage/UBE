UBE SOURCE 1 MODULE
Attribute UBE_Name = "PhaseText"

' Returns 1 when Needle occurs at StartIndex in Value.
Function CompilerTextMatchesAt(ByVal Value As String, ByVal StartIndex As Long, ByVal Needle As String) As Long
    Dim ValueLength As Long = CompilerTextLength(Value)
    Dim NeedleLength As Long = CompilerTextLength(Needle)
    If StartIndex < 0 Or StartIndex > ValueLength Or NeedleLength > ValueLength - StartIndex Then
        CompilerTextMatchesAt = 0
        Exit Function
    End If
    Dim Index As Long = 0
    While Index < NeedleLength
        If CompilerTextByteAt(Value, StartIndex + Index) <> CompilerTextByteAt(Needle, Index) Then
            CompilerTextMatchesAt = 0
            Exit Function
        End If
        Index = Index + 1
    Wend
    CompilerTextMatchesAt = 1
End Function

' Finds the next LF-delimited line and advances Cursor. A final unterminated
' line is valid. Result is 0 only when Cursor is already at end.
Function ReadCompilerLine(ByVal Value As String, ByRef Cursor As Long, ByRef LineText As String, ByRef LineStart As Long) As Long
    LineText = ""
    Dim ValueLength As Long = CompilerTextLength(Value)
    If Cursor < 0 Or Cursor >= ValueLength Then
        ReadCompilerLine = 0
        Exit Function
    End If
    LineStart = Cursor
    Dim LineEnd As Long = Cursor
    While LineEnd < ValueLength And CompilerTextByteAt(Value, LineEnd) <> 10
        LineEnd = LineEnd + 1
    Wend
    Dim Length As Long = LineEnd - Cursor
    If Length > 0 And CompilerTextByteAt(Value, LineEnd - 1) = 13 Then Length = Length - 1
    If CompilerTextSlice(Value, Cursor, Length, LineText) = 0 Then
        ReadCompilerLine = 0
        Exit Function
    End If
    If LineEnd < ValueLength Then
        Cursor = LineEnd + 1
    Else
        Cursor = ValueLength
    End If
    ReadCompilerLine = 1
End Function

' Returns the directory portion of Path, including its final separator.
Function CompilerPathPrefix(ByVal Path As String) As String
    Dim Index As Long = CompilerTextLength(Path) - 1
    While Index >= 0
        Dim Value As Long = CompilerTextByteAt(Path, Index)
        If Value = 47 Or Value = 92 Then
            Dim Result As String = ""
            If CompilerTextSlice(Path, 0, Index + 1, Result) <> 0 Then CompilerPathPrefix = Result
            Exit Function
        End If
        Index = Index - 1
    Wend
    CompilerPathPrefix = ""
End Function

' Appends a canonical dump field within the artifact limit.
Function AppendPhaseField(ByRef Dump As String, ByVal FieldName As String, ByVal Value As String) As Long
    AppendPhaseField = AppendRecordField(Dump, FieldName, Value, 268435456)
End Function

' Computes a one-based line and column for a byte offset.
Sub CompilerLineColumn(ByVal Value As String, ByVal Offset As Long, ByRef LineNumber As Long, ByRef Column As Long)
    LineNumber = 1
    Column = 1
    Dim Index As Long = 0
    While Index < Offset And Index < CompilerTextLength(Value)
        If CompilerTextByteAt(Value, Index) = 10 Then
            LineNumber = LineNumber + 1
            Column = 1
        Else
            Column = Column + 1
        End If
        Index = Index + 1
    Wend
End Sub

' Parses a nonnegative decimal Long used by the private token serialization.
Function ParseCompilerLong(ByVal Value As String, ByRef Result As Long) As Long
    Result = 0
    If CompilerTextLength(Value) = 0 Then ParseCompilerLong = 0: Exit Function
    Dim Index As Long = 0
    While Index < CompilerTextLength(Value)
        Dim ByteValue As Long = CompilerTextByteAt(Value, Index)
        If ByteValue < 48 Or ByteValue > 57 Then ParseCompilerLong = 0: Exit Function
        If Result > 214748364 Then ParseCompilerLong = 0: Exit Function
        Result = Result * 10 + ByteValue - 48
        Index = Index + 1
    Wend
    ParseCompilerLong = 1
End Function
