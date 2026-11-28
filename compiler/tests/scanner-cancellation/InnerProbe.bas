UBE SOURCE 1 MODULE
Attribute UBE_Name = "InnerCancellationProbe"
Private Intrinsic Function TextLength(ByRef Value As String) As LongLong
Attribute TextLength.UBE_Primitive = "Text.ByteLength"
End Function
Private Intrinsic Function ReadText(ByRef Value As String, ByVal Index As LongLong, ByRef Result As Byte) As Boolean
Attribute ReadText.UBE_Primitive = "Text.ReadByte"
End Function
Private Intrinsic Function ResizeSpans(ByRef Values() As SourceScanner.SourceSpan, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeSpans.UBE_Primitive = "Array.TryResize"
End Function
Private Intrinsic Function ResizeNodes(ByRef Values() As SourceParser.SyntaxNode, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeNodes.UBE_Primitive = "Array.TryResize"
End Function
Private Function Repeated(ByVal Value As String, ByVal Count As Long) As String
    Dim Index As Long
    For Index = 1 To Count
        Repeated = Repeated & Value
    Next Index
End Function
Private Sub Bytes(ByVal Text As String, ByRef Result() As Byte)
    Dim Size As Long
    Dim Index As Long
    Size = TextLength(Text)
    If Not BufferPrimitives.TryResizeBytes(Result, Size, False) Then Err.Raise 5
    For Index = 0 To Size - 1
        If Not ReadText(Text, Index, Result(Index)) Then Err.Raise 5
    Next Index
End Sub
Private Function CaseText1(ByRef NL As String, ByRef Header As String, ByRef Body As String) As String
    CaseText1 = """" & Repeated("x", 600) & """"
End Function
Private Function CaseText2(ByRef NL As String, ByRef Header As String, ByRef Body As String) As String
    CaseText2 = Repeated("1", 600)
End Function
Private Function CaseText3(ByRef NL As String, ByRef Header As String, ByRef Body As String) As String
    CaseText3 = "'" & Repeated("x", 600)
End Function
Private Function CaseText4(ByRef NL As String, ByRef Header As String, ByRef Body As String) As String
    CaseText4 = "X _" & Repeated(" ", 600) & NL & "X"
End Function
Private Function CaseText5(ByRef NL As String, ByRef Header As String, ByRef Body As String) As String
    CaseText5 = Repeated(" ", 600) & "Asm" & NL & "End Asm" & NL
End Function
Private Function CaseText6(ByRef NL As String, ByRef Header As String, ByRef Body As String) As String
    CaseText6 = "Asm" & NL & Repeated("x" & NL, 600) & "End Asm" & NL
End Function
Private Function CaseText7(ByRef NL As String, ByRef Header As String, ByRef Body As String) As String
    CaseText7 = Repeated("x", 600)
End Function
Private Function CaseText8(ByRef NL As String, ByRef Header As String, ByRef Body As String) As String
    CaseText8 = Repeated(" ", 600) & "X"
End Function
Private Function CaseText9(ByRef NL As String, ByRef Header As String, ByRef Body As String) As String
    CaseText9 = Repeated("X" & NL, 600)
End Function
Private Function CaseText10(ByRef NL As String, ByRef Header As String, ByRef Body As String) As String
    CaseText10 = Repeated(" X" & NL, 600)
End Function
Private Function CaseText11(ByRef NL As String, ByRef Header As String, ByRef Body As String) As String
    CaseText11 = Repeated(NL, 600) & Header & Body & "End Function" & NL
End Function
Private Function CaseText12(ByRef NL As String, ByRef Header As String, ByRef Body As String) As String
    CaseText12 = Header & Body & "Value(" & Repeated("1,", 300) & "1) = 2" & NL & "End Function" & NL
End Function
Private Function CaseText13(ByRef NL As String, ByRef Header As String, ByRef Body As String) As String
    CaseText13 = Header & Body & "Value = " & Repeated("1+", 300) & "1" & NL & "End Function" & NL
End Function
Private Function CaseText14(ByRef NL As String, ByRef Header As String, ByRef Body As String) As String
    CaseText14 = Header & Repeated("Dim Value As Long" & NL, 600) & Body & "End Function" & NL
End Function
Private Function CaseText15(ByRef NL As String, ByRef Header As String, ByRef Body As String) As String
    CaseText15 = Header & Body & Repeated("Value = 1" & NL, 600) & "End Function" & NL
End Function
Private Function FixtureText(ByVal Kind As Long) As String
    Dim NL As String
    Dim Header As String
    Dim Body As String
    Dim Candidate As LongLong
    If Not TextPrimitives.TryCreate(1, 1, Candidate) Then Err.Raise 5
    If Not TextPrimitives.TryWriteByte(Candidate, 0, 10) Then Err.Raise 5
    If Not TextPrimitives.TryPublish(NL, Candidate) Then Err.Raise 5
    Header = "UBE SOURCE 1 MODULE" & NL & "Attribute UBE_Name = ""Probe""" & NL
    Body = "Public Function Main() As Long" & NL & "Dim Value As Long" & NL
    If Kind = 1 Then
        FixtureText = CaseText1(NL, Header, Body)
    ElseIf Kind = 2 Then
        FixtureText = CaseText2(NL, Header, Body)
    ElseIf Kind = 3 Then
        FixtureText = CaseText3(NL, Header, Body)
    ElseIf Kind = 4 Then
        FixtureText = CaseText4(NL, Header, Body)
    ElseIf Kind = 5 Then
        FixtureText = CaseText5(NL, Header, Body)
    ElseIf Kind = 6 Then
        FixtureText = CaseText6(NL, Header, Body)
    ElseIf Kind = 7 Then
        FixtureText = CaseText7(NL, Header, Body)
    ElseIf Kind = 8 Then
        FixtureText = CaseText8(NL, Header, Body)
    ElseIf Kind = 9 Then
        FixtureText = CaseText9(NL, Header, Body)
    ElseIf Kind = 10 Then
        FixtureText = CaseText10(NL, Header, Body)
    ElseIf Kind = 11 Or Kind = 12 Then
        FixtureText = CaseText11(NL, Header, Body)
    ElseIf Kind = 13 Then
        FixtureText = CaseText12(NL, Header, Body)
    ElseIf Kind = 14 Then
        FixtureText = CaseText13(NL, Header, Body)
    ElseIf Kind = 16 Then
        FixtureText = CaseText14(NL, Header, Body)
    Else
        FixtureText = CaseText15(NL, Header, Body)
    End If
End Function
Private Sub CheckCase(ByVal Kind As Long, ByRef Outcome As Long)
    Dim Source() As Byte
    Dim Tokens() As SourceScanner.SourceToken
    Dim Nodes() As SourceParser.SyntaxNode
    Dim Selected() As SourceScanner.SourceSpan
    Dim Diagnostic As SourceScanner.ScanDiagnostic
    Dim Parsed As SourceParser.ParseDiagnostic
    Dim Position As SourceScanner.SourcePosition
    Dim Span As SourceScanner.SourceSpan
    Dim Count As Long
    Dim NodeCount As Long
    Dim Root As Long
    Dim Index As Long
    Dim Status As Boolean
    On Error GoTo Failed
    Outcome = 1
    CancellationSchedule.Target = 0
    Bytes FixtureText(Kind), Source
    If Not SourceScanner.TryBeginSource(Source, Position, Diagnostic) Then Exit Sub
    If Kind = 9 Then
        If Not ResizeSpans(Selected, 600, False) Then Exit Sub
        For Index = 0 To 599
            If Not SourceScanner.TryReadLogicalLine(Source, Position, Selected(Index), Diagnostic) Then Exit Sub
        Next Index
    End If
    If Kind >= 11 Then
        If Not SourceScanner.TryScan(Source, Tokens, Count, Diagnostic) Then Exit Sub
        If Not ResizeNodes(Nodes, 1, False) Then Exit Sub
        Nodes(0).Kind = 777
    End If
    CancellationSchedule.Owner = ThreadPrimitives.CurrentId()
    CancellationSchedule.Visits = 0
    CancellationSchedule.ObservedAt = 0
    CancellationSchedule.Target = Kind
    Call FilePrimitives.SetError(55)
    Outcome = 2
    If Kind >= 11 Then
        NodeCount = 77
        Root = 77
        If SourceParser.TryParseModule(Source, Tokens, Count, Nodes, NodeCount, Root, Parsed) Then Exit Sub
        If Parsed.Code <> 104 Or Parsed.Reason <> 0 Or NodeCount <> 0 Or Root <> 0 Or Nodes(0).Kind <> 777 Then Exit Sub
    ElseIf Kind >= 4 And Kind <= 7 Then
        Span.Kind = 777
        If SourceScanner.TryReadLogicalLine(Source, Position, Span, Diagnostic) Then Exit Sub
        If Diagnostic.Code <> 104 Or Span.Kind <> 777 Or Position.ByteOffset <> 0 Then Exit Sub
    Else
        Count = 77
        If Kind = 8 Then
            Status = SourceScanner.TryScanRange(Source, 600, 601, Tokens, Count, Diagnostic)
        ElseIf Kind = 9 Then
            Status = SourceScanner.TryScanSelected(Source, Selected, 600, Tokens, Count, Diagnostic)
        Else
            Status = SourceScanner.TryScan(Source, Tokens, Count, Diagnostic)
        End If
        If Status Or Diagnostic.Code <> 104 Or Diagnostic.Reason <> 0 Or Count <> 0 Then Exit Sub
    End If
    Outcome = 3
    If CancellationSchedule.ObservedAt <> 17 Then Exit Sub
    If CancellationSchedule.Visits < 17 Or CancellationSchedule.Visits > 273 Then Exit Sub
    If Err.Number <> 55 Then Exit Sub
    Diagnostic.Code = 77
    Position.ByteOffset = 0
    Position.Utf16Offset = 1
    Position.Line = 1
    Position.Column = 1
    If SourceScanner.TryReadLogicalLine(Source, Position, Span, Diagnostic) Then Exit Sub
    If Diagnostic.Code <> 77 Then Exit Sub
    Outcome = 0
    Exit Sub
Failed:
    Outcome = 99
End Sub
Public Function Main() As Long
    Dim Kind As Long
    Dim Outcome As Long
    Dim Worker As LongLong
    Dim Source() As Byte
    Dim Tokens() As SourceScanner.SourceToken
    Dim Diagnostic As SourceScanner.ScanDiagnostic
    Dim Count As Long
    On Error GoTo Failed
    Call FilePrimitives.SetError(77)
    For Kind = 1 To 17
        Worker = CallNew CheckCase(Kind, Outcome)
        If ThreadPrimitives.Wait(Worker, 20000) <> 1 Then Main = 90: Exit Function
        If Outcome <> 0 Then Main = Kind * 100 + Outcome: Exit Function
        If Err.Number <> 77 Then Main = 91: Exit Function
        Bytes "X", Source
        If Not SourceScanner.TryScan(Source, Tokens, Count, Diagnostic) Then Main = 92: Exit Function
        If Count <> 3 Then Main = 93: Exit Function
    Next Kind
    Exit Function
Failed:
    Main = 99
End Function
