UBE SOURCE 1 MODULE
Attribute UBE_Name = "ConditionalCancellationProbe"
Private Intrinsic Function ResizeSymbols(ByRef Values() As ConditionalExpressions.SymbolFact, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeSymbols.UBE_Primitive = "Array.TryResize"
End Function
Private Intrinsic Function ResizeSpans(ByRef Values() As SourceScanner.SourceSpan, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeSpans.UBE_Primitive = "Array.TryResize"
End Function
Private Function Repeated(ByVal Value As String, ByVal Count As Long) As String
    Dim Index As Long
    For Index = 1 To Count
        Repeated = Repeated & Value
    Next Index
End Function
Private Sub Bytes(ByVal Value As String, ByRef Result() As Byte)
    Dim Size As Long
    Dim Index As Long
    Size = TextPrimitives.ByteLength(Value)
    If Not BufferPrimitives.TryResizeBytes(Result, Size, False) Then Err.Raise 5
    For Index = 0 To Size - 1
        If Not TextPrimitives.TryReadByte(Value, Index, Result(Index)) Then Err.Raise 5
    Next Index
End Sub
Private Function FixtureText(ByVal Kind As Long) As String
    Dim NL As String
    Dim Candidate As LongLong
    If Not TextPrimitives.TryCreate(1, 1, Candidate) Then Err.Raise 5
    If Not TextPrimitives.TryWriteByte(Candidate, 0, 10) Then Err.Raise 5
    If Not TextPrimitives.TryPublish(NL, Candidate) Then Err.Raise 5
    If Kind = 1 Then
        FixtureText = Repeated(" ", 600) & "#If True Then" & NL & "#End If" & NL
    ElseIf Kind = 2 Then
        FixtureText = "#Const abcdefghijklmnopqrstuvwxyz = 1" & NL
    ElseIf Kind = 3 Then
        FixtureText = Repeated("X" & NL, 600)
    ElseIf Kind = 4 Then
        FixtureText = "x"
    Else
        FixtureText = Repeated("1+", 600) & "1"
    End If
End Function
Private Sub CheckCase(ByVal Kind As Long, ByRef Outcome As Long)
    Dim Source() As Byte
    Dim Tokens() As SourceScanner.SourceToken
    Dim Names() As Byte
    Dim Symbols() As ConditionalExpressions.SymbolFact
    Dim Arena() As Byte
    Dim Selected() As SourceScanner.SourceSpan
    Dim Value As ConditionalExpressions.ValueFact
    Dim Diagnostic As SourceParser.ParseDiagnostic
    Dim Scan As SourceScanner.ScanDiagnostic
    Dim Count As Long
    Dim SelectedCount As Long = 77
    Dim SymbolCount As Long
    Dim Used As Long
    Dim Index As Long
    On Error GoTo Failed
    Outcome = 1
    CancellationSchedule.Target = 0
    Bytes FixtureText(Kind), Source
    If Kind <= 3 Then
        If Not ResizeSpans(Selected, 1, False) Then Exit Sub
        Selected(0).Kind = 777
    Else
        If Not SourceScanner.TryScan(Source, Tokens, Count, Scan) Then Exit Sub
        If Kind = 4 Then
            SymbolCount = 600
            If Not ResizeSymbols(Symbols, SymbolCount, False) Then Exit Sub
            Bytes "y", Names
            For Index = 0 To SymbolCount - 1
                Symbols(Index).NameLength = 1
                Symbols(Index).Value.TypeCode = SyntaxTokens.KwLong
            Next Index
        End If
        Value.Number = 777
    End If
    CancellationSchedule.Target = Kind
    CancellationSchedule.Owner = ThreadPrimitives.CurrentId()
    CancellationSchedule.Visits = 0
    CancellationSchedule.ObservedAt = 0
    Call FilePrimitives.SetError(55)
    Outcome = 2
    If Kind <= 3 Then
        If ConditionalSource.TrySelect(Source, Names, Symbols, 0, Arena, 0, Selected, SelectedCount, Diagnostic) Then Exit Sub
        If Selected(0).Kind <> 777 Or SelectedCount <> 77 Then Exit Sub
    Else
        If ConditionalExpressions.TryEvaluate(Source, Tokens, Count, 0, Count - 2, Names, Symbols, SymbolCount, Arena, Used, Value, Diagnostic) Then Exit Sub
        If Value.Number <> 777 Or Used <> 0 Then Exit Sub
    End If
    If Diagnostic.Code <> 104 Or Diagnostic.Reason <> 0 Then Exit Sub
    Outcome = 3
    If CancellationSchedule.ObservedAt <> 17 Or CancellationSchedule.Visits > 273 Then Exit Sub
    If Err.Number <> 55 Then Exit Sub
    Outcome = 0
    Exit Sub
Failed:
    Outcome = 99
End Sub
Public Function Main() As Long
    Dim Kind As Long
    Dim Worker As LongLong
    Dim Outcome As Long
    Call FilePrimitives.SetError(77)
    For Kind = 1 To 6
        Worker = CallNew CheckCase(Kind, Outcome)
        If ThreadPrimitives.Wait(Worker, 20000) <> 1 Then Main = 90: Exit Function
        If Outcome <> 0 Then Main = Kind * 100 + Outcome: Exit Function
        If Err.Number <> 77 Then Main = 91: Exit Function
    Next Kind
End Function
