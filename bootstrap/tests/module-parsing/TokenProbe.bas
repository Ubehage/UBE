UBE SOURCE 1 MODULE
Attribute UBE_Name = "TokenProbe"
' Compares production token helpers with independently supplied classification and spelling oracles.

' Runs scanned bytes through every token-classification API without constructing tokens by hand.
Public Function Run(ByRef Source() As Byte, ByRef Expected() As Long, ByVal ExpectedCount As Long, ByRef Pairs() As Long, ByVal PairCount As Long) As Long
    Dim Tokens() As SourceScanner.SourceToken
    Dim Diagnostic As SourceScanner.ScanDiagnostic
    Dim Count As Long
    Dim Index As Long
    Dim Offset As Long
    Dim PairOffset As Long
    Dim Failures As Long
    Dim Value As Long
    Dim Status As Boolean
    On Error GoTo Failed
    Status = SourceScanner.TryScan(Source, Tokens, Count, Diagnostic)
    If Status = False Then Run = 10001: Exit Function
    If Count <> ExpectedCount Then Run = 10002: Exit Function
    Do While Index < Count
        Value = SyntaxTokens.TokenCode(Source, Tokens, Index, Count)
        If Value <> Expected(Offset) Then Failures = Failures + 1
        Status = SyntaxTokens.IsIdentifierToken(Source, Tokens, Index, Count, False)
        If Status <> (Expected(Offset + 1) <> 0) Then Failures = Failures + 1
        Status = SyntaxTokens.IsIdentifierToken(Source, Tokens, Index, Count, True)
        If Status <> (Expected(Offset + 2) <> 0) Then Failures = Failures + 1
        Status = SyntaxTokens.IsIntegerToken(Source, Tokens, Index, Count)
        If Status <> (Expected(Offset + 3) <> 0) Then Failures = Failures + 1
        Status = SyntaxTokens.IsDecimalLabelToken(Source, Tokens, Index, Count)
        If Status <> (Expected(Offset + 4) <> 0) Then Failures = Failures + 1
        Status = SyntaxTokens.IsModuleNameToken(Source, Tokens, Index, Count)
        If Status <> (Expected(Offset + 5) <> 0) Then Failures = Failures + 1
        Index = Index + 1
        Offset = Offset + 6
    Loop
    Index = 0
    Do While Index < PairCount
        If Pairs(PairOffset) = 3 Then
            Value = SyntaxTokens.DecodedIdentifierCode(Source, Tokens, Pairs(PairOffset + 1), Count)
            If Value <> Pairs(PairOffset + 3) Then Failures = Failures + 1
        ElseIf Pairs(PairOffset) = 1 Then
            Status = SyntaxTokens.SameIdentifier(Source, Tokens, Pairs(PairOffset + 1), Pairs(PairOffset + 2), Count)
        Else
            Status = SyntaxTokens.StringEqualsIdentifier(Source, Tokens, Pairs(PairOffset + 1), Pairs(PairOffset + 2), Count)
        End If
        If Pairs(PairOffset) <> 3 Then
            If Status <> (Pairs(PairOffset + 3) <> 0) Then Failures = Failures + 1
        End If
        PairOffset = PairOffset + 4
        Index = Index + 1
    Loop
    If SyntaxTokens.TokenCode(Source, Tokens, -1, Count) <> SyntaxTokens.CodeEnd Then Failures = Failures + 1
    If SyntaxTokens.TokenCode(Source, Tokens, Count + 9, Count) <> SyntaxTokens.CodeEnd Then Failures = Failures + 1
    If SyntaxTokens.IsIdentifierToken(Source, Tokens, Count, Count, True) Then Failures = Failures + 1
    If SyntaxTokens.SameIdentifier(Source, Tokens, -1, 0, Count) Then Failures = Failures + 1
    If SyntaxTokens.StringEqualsIdentifier(Source, Tokens, Count, 0, Count) Then Failures = Failures + 1
    If SyntaxTokens.IsModuleNameToken(Source, Tokens, -1, Count) Then Failures = Failures + 1
    If SyntaxTokens.IsIntegerToken(Source, Tokens, Count, Count) Then Failures = Failures + 1
    If SyntaxTokens.IsDecimalLabelToken(Source, Tokens, -1, Count) Then Failures = Failures + 1
    Run = Failures
    Exit Function
Failed:
    Run = 10003
End Function
