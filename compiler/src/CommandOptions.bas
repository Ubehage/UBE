UBE SOURCE 1 MODULE
Attribute UBE_Name = "CommandOptions"
' Parses the admitted compiler command forms without filesystem or process operations.
Public Type CommandRequest
    Mode As Long
    ClangArgument As Long
End Type

Public Type CommandDiagnostic
    Code As Long
    Argument As Long
End Type

' Compares complete case-sensitive flag spellings after establishing their byte bounds.
Private Function MatchesFlag(ByRef Value() As Byte, ByVal Flag As Long) As Boolean
    Dim Length As Long
    Length = BufferPrimitives.ByteStorageLength(Value)
    If Flag = 1 Then
        If Length <> 11 Then Exit Function
        If Value(0) <> 45 Or Value(1) <> 45 Or Value(2) <> 101 Or Value(3) <> 109 Then Exit Function
        If Value(4) <> 105 Or Value(5) <> 116 Or Value(6) <> 45 Or Value(7) <> 108 Then Exit Function
        If Value(8) <> 108 Or Value(9) <> 118 Or Value(10) <> 109 Then Exit Function
    ElseIf Flag = 2 Then
        If Length <> 7 Then Exit Function
        If Value(0) <> 45 Or Value(1) <> 45 Or Value(2) <> 98 Or Value(3) <> 117 Then Exit Function
        If Value(4) <> 105 Or Value(5) <> 108 Or Value(6) <> 100 Then Exit Function
    ElseIf Flag = 3 Then
        If Length <> 7 Then Exit Function
        If Value(0) <> 45 Or Value(1) <> 45 Or Value(2) <> 99 Or Value(3) <> 108 Then Exit Function
        If Value(4) <> 97 Or Value(5) <> 110 Or Value(6) <> 103 Then Exit Function
    Else
        Exit Function
    End If
    MatchesFlag = True
End Function

' Publishes options only for an exact command; diagnostic code 1 is usage and 2 is argument-reading failure.
Public Function TryParse(ByRef CommandLine() As Byte, ByRef Options As CommandRequest, ByRef Diagnostic As CommandDiagnostic) As Boolean
    Dim Candidate As CommandRequest
    Dim Value() As Byte
    Dim Found As Boolean
    Dim Index As Long
    On Error GoTo Failed
    Diagnostic.Code = 0
    Diagnostic.Argument = 0
    Do While Index <= 6
        If Not WindowsArguments.TryReadArgument(CommandLine, Index, Value, Found) Then GoTo Failed
        If Index = 0 Then
            If Not Found Then GoTo Usage
        ElseIf Index = 1 Then
            If Not Found Then GoTo Usage
            If MatchesFlag(Value, 1) Then Candidate.Mode = 1
            If MatchesFlag(Value, 2) Then Candidate.Mode = 2
            If Candidate.Mode = 0 Then GoTo Usage
        ElseIf Index = 2 Or Index = 3 Then
            If Not Found Then GoTo Usage
            If BufferPrimitives.ByteStorageLength(Value) = 0 Then GoTo Usage
        ElseIf Index = 4 Then
            If Not Found Then GoTo Publish
            If Candidate.Mode <> 2 Then GoTo Usage
            If Not MatchesFlag(Value, 3) Then GoTo Usage
        ElseIf Index = 5 Then
            If Not Found Then GoTo Usage
            If BufferPrimitives.ByteStorageLength(Value) = 0 Then GoTo Usage
            Candidate.ClangArgument = 5
        Else
            If Found Then GoTo Usage
            GoTo Publish
        End If
        Index = Index + 1
    Loop
Usage:
    Diagnostic.Code = 1
    Diagnostic.Argument = Index
    Exit Function
Failed:
    Diagnostic.Code = 2
    Diagnostic.Argument = Index
    Exit Function
Publish:
    Options = Candidate
    TryParse = True
End Function
