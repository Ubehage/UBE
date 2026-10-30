UBE SOURCE 1 MODULE
Attribute UBE_Name = "LexerPhase"

Type TokenUnitResult
    Succeeded As Long
    SourceId As Long
    TokenCount As Long
    TokenData As String
    WorkUnits As LongLong
    Dump As String
End Type

Sub ReleaseTokenUnit(ByRef Result As TokenUnitResult)
    Result.Succeeded = 0
    Result.TokenData = ""
    Result.Dump = ""
End Sub

Function AppendMinimalToken(ByRef Result As TokenUnitResult, ByVal Kind As String, ByVal StartOffset As Long, ByVal Length As Long, ByVal Value As String, ByVal MaximumTokens As Long) As Long
    If Result.TokenCount >= MaximumTokens Or StartOffset < 0 Or Length <= 0 Then AppendMinimalToken = 0: Exit Function
    Dim TokenLine As String = Kind & ":" & CompilerLongToText(StartOffset) & ":" & CompilerLongToText(Length) & ":" & Value & CompilerTextFromByte(10)
    If AppendBoundedText(Result.TokenData, TokenLine, 16777216) = 0 Then AppendMinimalToken = 0: Exit Function
    Result.TokenCount = Result.TokenCount + 1
    AppendMinimalToken = 1
End Function

Function ValidateTokenUnit(ByVal Result As TokenUnitResult) As Long
    If Result.Succeeded = 0 Or Result.SourceId <> 1 Or Result.TokenCount <= 0 Or Result.TokenData = "" Then ValidateTokenUnit = 0 Else ValidateTokenUnit = 1
End Function

Function RunLexerPhase(ByVal Session As BuildSession, ByVal Source As SourceSetResult, ByRef Result As TokenUnitResult, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Call ReleaseTokenUnit(Result)
    If ValidateSourceSet(Source) = 0 Then RunLexerPhase = 0: Exit Function
    Result.SourceId = Source.SourceId
    Dim Index As Long = 0
    While Index < Source.ByteCount
        Dim ByteValue As Long = CompilerTextByteAt(Source.SourceBytes, Index)
        If ByteValue = 32 Or ByteValue = 9 Or ByteValue = 13 Or ByteValue = 10 Then
            Index = Index + 1
        Else
            If ByteValue = 39 Then
                While Index < Source.ByteCount And CompilerTextByteAt(Source.SourceBytes, Index) <> 10
                    Index = Index + 1
                Wend
            Else
                Dim StartOffset As Long = Index
                Dim Kind As String = ""
                Dim Value As String = ""
                If (ByteValue >= 65 And ByteValue <= 90) Or (ByteValue >= 97 And ByteValue <= 122) Or ByteValue = 95 Then
                    Index = Index + 1
                    While Index < Source.ByteCount
                        ByteValue = CompilerTextByteAt(Source.SourceBytes, Index)
                        If (ByteValue >= 65 And ByteValue <= 90) Or (ByteValue >= 97 And ByteValue <= 122) Or (ByteValue >= 48 And ByteValue <= 57) Or ByteValue = 95 Then
                            Index = Index + 1
                        Else
                            Exit While
                        End If
                    Wend
                    Kind = "I"
                    Call CompilerTextSlice(Source.SourceBytes, StartOffset, Index - StartOffset, Value)
                Else
                    If ByteValue >= 48 And ByteValue <= 57 Then
                        Index = Index + 1
                        While Index < Source.ByteCount And CompilerTextByteAt(Source.SourceBytes, Index) >= 48 And CompilerTextByteAt(Source.SourceBytes, Index) <= 57
                            Index = Index + 1
                        Wend
                        Kind = "N"
                        Call CompilerTextSlice(Source.SourceBytes, StartOffset, Index - StartOffset, Value)
                    Else
                        If ByteValue = 34 Then
                            Index = Index + 1
                            Dim ValueStart As Long = Index
                            While Index < Source.ByteCount And CompilerTextByteAt(Source.SourceBytes, Index) <> 34
                                ByteValue = CompilerTextByteAt(Source.SourceBytes, Index)
                                If ByteValue < 32 Or ByteValue = 92 Then Exit While
                                Index = Index + 1
                            Wend
                            If Index >= Source.ByteCount Or CompilerTextByteAt(Source.SourceBytes, Index) <> 34 Then
                                Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3700", Source.SourcePath, "source does not match the Task 3 string literal grammar")
                                RunLexerPhase = 0
                                Exit Function
                            End If
                            Kind = "S"
                            Call CompilerTextSlice(Source.SourceBytes, ValueStart, Index - ValueStart, Value)
                            Index = Index + 1
                        Else
                            If ByteValue = 40 Or ByteValue = 41 Or ByteValue = 61 Then
                                Kind = "P"
                                Call CompilerTextSlice(Source.SourceBytes, Index, 1, Value)
                                Index = Index + 1
                            Else
                                Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3700", Source.SourcePath, "source contains a token outside the Task 3 grammar")
                                RunLexerPhase = 0
                                Exit Function
                            End If
                        End If
                    End If
                End If
                If AppendMinimalToken(Result, Kind, StartOffset, Index - StartOffset, Value, Session.MaximumTokens) = 0 Then
                    Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE6101", Source.SourcePath, "token limit or serialization limit exceeded")
                    RunLexerPhase = 0
                    Exit Function
                End If
            End If
        End If
    Wend
    Result.WorkUnits = Source.ByteCount
    Result.Succeeded = 1
    Call AppendPhaseField(Result.Dump, "phase", "lexer")
    Call AppendPhaseField(Result.Dump, "source-id", CompilerLongToText(Result.SourceId))
    Call AppendPhaseField(Result.Dump, "tokens", CompilerLongToText(Result.TokenCount))
    Call AppendPhaseField(Result.Dump, "work", CompilerLongToText(Source.ByteCount))
    If Session.FaultSite = "token-envelope" Then Result.SourceId = 0
    If ValidateTokenUnit(Result) = 0 Then
        Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE6108", Source.SourcePath, "lexer published an invalid envelope")
        RunLexerPhase = 0
        Exit Function
    End If
    RunLexerPhase = 1
End Function

' Reads one canonical token record by zero-based ordinal.
Function ReadMinimalToken(ByVal Data As String, ByVal Ordinal As Long, ByRef Kind As String, ByRef StartOffset As Long, ByRef Length As Long, ByRef Value As String) As Long
    Kind = "": Value = "": StartOffset = 0: Length = 0
    Dim Cursor As Long = 0
    Dim Current As Long = 0
    Dim TokenLine As String = ""
    Dim IgnoredStart As Long = 0
    While ReadCompilerLine(Data, Cursor, TokenLine, IgnoredStart) <> 0
        If Current = Ordinal Then
            Dim Field As Long = 0
            Dim FieldStart As Long = 0
            Dim Index As Long = 0
            While Index <= CompilerTextLength(TokenLine)
                If Index = CompilerTextLength(TokenLine) Or CompilerTextByteAt(TokenLine, Index) = 58 Then
                    Dim Part As String = ""
                    Call CompilerTextSlice(TokenLine, FieldStart, Index - FieldStart, Part)
                    If Field = 0 Then Kind = Part
                    If Field = 1 Then Call ParseCompilerLong(Part, StartOffset)
                    If Field = 2 Then Call ParseCompilerLong(Part, Length)
                    If Field = 3 Then Value = Part
                    Field = Field + 1
                    FieldStart = Index + 1
                End If
                Index = Index + 1
            Wend
            If Field = 4 Then ReadMinimalToken = 1 Else ReadMinimalToken = 0
            Exit Function
        End If
        Current = Current + 1
    Wend
    ReadMinimalToken = 0
End Function
