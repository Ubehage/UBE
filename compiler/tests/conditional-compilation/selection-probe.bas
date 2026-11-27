UBE SOURCE 1 MODULE
Attribute UBE_Name = "SelectionProbe"

Private Intrinsic Function SpanLength(ByRef Values() As SourceScanner.SourceSpan) As Long
Attribute SpanLength.UBE_Primitive = "Array.Length"
End Function

' Compares selected ordinary token spellings, independently scanning the expected text.
Private Function Matches(ByRef Source() As Byte, ByRef Expected() As Byte, ByVal Hosted As Boolean, ByVal RejectSource As Boolean) As Boolean
    Dim Names(0 To 8) As Byte
    Dim Symbols(0 To 0) As ConditionalExpressions.SymbolFact
    Dim Text() As Byte
    Dim Selected() As SourceScanner.SourceSpan
    Dim Tokens() As SourceScanner.SourceToken
    Dim Reference() As SourceScanner.SourceToken
    Dim Diagnostic As SourceParser.ParseDiagnostic
    Dim ScanError As SourceScanner.ScanDiagnostic
    Dim SelectedCount As Long = 91
    Dim Count As Long
    Dim ReferenceCount As Long
    Dim Left As Long
    Dim Right As Long
    Dim Offset As Long
    Dim Status As Boolean
    On Error GoTo Failed
    Names(0) = 105: Names(1) = 115: Names(2) = 95
    Names(3) = 105: Names(4) = 110: Names(5) = 95
    Names(6) = 105: Names(7) = 100: Names(8) = 101
    Symbols(0).NameLength = 9
    Symbols(0).Value.TypeCode = SyntaxTokens.KwBoolean
    If Hosted Then Symbols(0).Value.Number = -1
    Status = False
    Status = ConditionalSource.TrySelect(Source, Names, Symbols, 1, Text, 0, Selected, SelectedCount, Diagnostic)
    If RejectSource Then
        If Status Or Diagnostic.Code = 0 Then Exit Function
        If SelectedCount <> 91 Or SpanLength(Selected) <> 0 Then Exit Function
        Matches = True
        Exit Function
    End If
    If Not Status Or Diagnostic.Code <> 0 Then Exit Function
    Status = False
    Status = SourceScanner.TryScanSelected(Source, Selected, SelectedCount, Tokens, Count, ScanError)
    If Not Status Then Exit Function
    Status = False
    Status = SourceScanner.TryScan(Expected, Reference, ReferenceCount, ScanError)
    If Not Status Then Exit Function
    Do
        Do While Left < Count
            If Tokens(Left).Kind <> SourceScanner.NewlineToken Then Exit Do
            Left = Left + 1
        Loop
        Do While Right < ReferenceCount
            If Reference(Right).Kind <> SourceScanner.NewlineToken Then Exit Do
            Right = Right + 1
        Loop
        If Left = Count Or Right = ReferenceCount Then Exit Do
        If Tokens(Left).Kind <> Reference(Right).Kind Then Exit Function
        If Tokens(Left).ByteLength <> Reference(Right).ByteLength Then Exit Function
        Offset = 0
        Do While Offset < Tokens(Left).ByteLength
            If Source(Tokens(Left).ByteStart + Offset) <> Expected(Reference(Right).ByteStart + Offset) Then Exit Function
            Offset = Offset + 1
        Loop
        Left = Left + 1
        Right = Right + 1
    Loop
    If Left <> Count Or Right <> ReferenceCount Then Exit Function
    If Names(0) <> 105 Or Symbols(0).NameLength <> 9 Or BufferPrimitives.ByteStorageLength(Text) <> 0 Then Exit Function
    Matches = True
    Exit Function
Failed:
    Matches = False
End Function

' Generated test functions below contain literal byte arrays for independent source cases.
' CASE FUNCTIONS

Public Function Main() As Long
    Dim Passed As Boolean
    On Error GoTo Failed
    ' CASE CALLS
    Main = 0
    Exit Function
Failed:
    Main = 99
End Function
