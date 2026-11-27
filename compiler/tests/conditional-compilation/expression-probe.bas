UBE SOURCE 1 MODULE
Attribute UBE_Name = "ExpressionProbe"
Private Const Control As Long = 0

' Changes the sticky record without returning FAIL to the caller.
Private Intrinsic Function RecordError(ByVal Number As Long) As Boolean
Attribute RecordError.UBE_Primitive = "Error.Set"
End Function

Private Function Check(ByRef Source() As Byte, ByVal IDEValue As LongLong, ByVal ExpectedType As Long, ByVal ExpectedNumber As LongLong, ByVal ExpectedCode As Long, ByVal ExpectedReason As Long, ByVal ExpectedColumn As Long, ByRef ExpectedText() As Byte) As Boolean
    Dim Tokens() As SourceScanner.SourceToken
    Dim Count As Long
    Dim Finish As Long
    Dim ScanError As SourceScanner.ScanDiagnostic
    Dim Diagnostic As SourceParser.ParseDiagnostic
    Dim Symbols(0 To 2) As ConditionalExpressions.SymbolFact
    Dim Names(0 To 13) As Byte
    Dim Arena() As Byte
    Dim Used As Long = 5
    Dim Result As ConditionalExpressions.ValueFact
    Dim Status As Boolean
    Dim Index As Long
    On Error GoTo Unexpected
    Names(0) = 105: Names(1) = 115: Names(2) = 95: Names(3) = 105: Names(4) = 110
    Names(5) = 95: Names(6) = 105: Names(7) = 100: Names(8) = 101
    Names(9) = 110: Names(10) = 119: Names(11) = 111: Names(12) = 114: Names(13) = 100
    Symbols(0).NameLength = 9
    Symbols(0).Value.TypeCode = SyntaxTokens.KwBoolean
    Symbols(0).Value.Number = IDEValue
    Symbols(1).NameStart = 9: Symbols(1).NameLength = 1
    Symbols(1).Value.TypeCode = SyntaxTokens.KwInteger: Symbols(1).Value.Number = 7
    Symbols(2).NameStart = 10: Symbols(2).NameLength = 4
    Symbols(2).Value.TypeCode = SyntaxTokens.KwString: Symbols(2).Value.TextLength = 3
    If Not BufferPrimitives.TryResizeBytes(Arena, 5, False) Then Exit Function
    Arena(0) = 65: Arena(1) = 98: Arena(2) = 67: Arena(3) = 88: Arena(4) = 89
    If Not SourceScanner.TryScan(Source, Tokens, Count, ScanError) Then Exit Function
    Do While Finish < Count
        If Tokens(Finish).Kind = SourceScanner.NewlineToken Or Tokens(Finish).Kind = SourceScanner.EndToken Then Exit Do
        Finish = Finish + 1
    Loop
    Result.TypeCode = 777: Result.Number = 999: Result.TextStart = 77: Result.TextLength = 88
    Status = RecordError(42)
    Status = False
    Status = ConditionalExpressions.TryEvaluate(Source, Tokens, Count, 0, Finish, Names, Symbols, 3, Arena, Used, Result, Diagnostic)
    If Err.Number <> 42 Then Exit Function
    If ExpectedCode <> 0 Then
        If Status Or Diagnostic.Code <> ExpectedCode Or Diagnostic.Reason <> ExpectedReason Then Exit Function
        If Result.TypeCode <> 777 Or Result.Number <> 999 Or Result.TextStart <> 77 Or Result.TextLength <> 88 Then Exit Function
        If Used <> 5 Or BufferPrimitives.ByteStorageLength(Arena) <> 5 Then Exit Function
        If Diagnostic.Line <> 1 Or Diagnostic.Column <> ExpectedColumn Or Diagnostic.ByteOffset <> ExpectedColumn - 1 Then Exit Function
    Else
        If Not Status Or Diagnostic.Code <> 0 Then Exit Function
        If Result.TypeCode <> ExpectedType Then Exit Function
        If ExpectedType = SyntaxTokens.KwString Then
            If Result.TextLength <> BufferPrimitives.ByteStorageLength(ExpectedText) Then Exit Function
            Do While Index < Result.TextLength
                If Arena(Result.TextStart + Index) <> ExpectedText(Index) Then Exit Function
                Index = Index + 1
            Loop
        Else
            If Result.Number <> ExpectedNumber + Control Then Exit Function
        End If
    End If
    If Arena(0) <> 65 Or Arena(1) <> 98 Or Arena(2) <> 67 Or Arena(3) <> 88 Or Arena(4) <> 89 Then Exit Function
    Err.Clear
    Status = False
    Status = ConditionalExpressions.TryEvaluate(Source, Tokens, Count, 0, Finish, Names, Symbols, 3, Arena, Used, Result, Diagnostic)
    If Err.Number <> 0 Then Exit Function
    If ExpectedCode = 0 Then
        If Not Status Then Exit Function
    Else
        If Status Or Diagnostic.Code <> ExpectedCode Or Diagnostic.Reason <> ExpectedReason Then Exit Function
    End If
    Check = True
    Exit Function
Unexpected:
    Check = False
End Function

Private Function InvalidInputs() As Boolean
    Dim B(0 To 3) As Byte
    Dim Tokens() As SourceScanner.SourceToken
    Dim Count As Long
    Dim ScanError As SourceScanner.ScanDiagnostic
    Dim Diagnostic As SourceParser.ParseDiagnostic
    Dim Names() As Byte
    Dim Symbols() As ConditionalExpressions.SymbolFact
    Dim Arena() As Byte
    Dim Used As Long
    Dim Result As ConditionalExpressions.ValueFact
    Dim Status As Boolean
    B(0) = 84: B(1) = 114: B(2) = 117: B(3) = 101
    If Not SourceScanner.TryScan(B, Tokens, Count, ScanError) Then Exit Function
    Result.TypeCode = 777: Result.Number = 99
    Status = RecordError(42)
    Status = ConditionalExpressions.TryEvaluate(B, Tokens, Count, -1, 1, Names, Symbols, 0, Arena, Used, Result, Diagnostic)
    If Status Or Diagnostic.Code <> 3 Or Diagnostic.Reason <> 4 Or Err.Number <> 42 Then Exit Function
    If Result.TypeCode <> 777 Or Result.Number <> 99 Or Used <> 0 Then Exit Function
    Status = ConditionalExpressions.TryEvaluate(B, Tokens, Count + 1, 0, 1, Names, Symbols, 0, Arena, Used, Result, Diagnostic)
    If Status Or Diagnostic.Code <> 3 Or Result.TypeCode <> 777 Or Result.Number <> 99 Then Exit Function
    Status = ConditionalExpressions.TryEvaluate(B, Tokens, Count, 0, 1, Names, Symbols, 1, Arena, Used, Result, Diagnostic)
    If Status Or Diagnostic.Code <> 3 Or Result.TypeCode <> 777 Or Result.Number <> 99 Then Exit Function
    If Used <> 0 Or BufferPrimitives.ByteStorageLength(Arena) <> 0 Then Exit Function
    Err.Clear
    Status = ConditionalExpressions.TryEvaluate(B, Tokens, Count, 0, 1, Names, Symbols, 0, Arena, Used, Result, Diagnostic)
    If Not Status Or Result.TypeCode <> SyntaxTokens.KwBoolean Or Result.Number <> -1 Or Err.Number <> 0 Then Exit Function
    InvalidInputs = True
End Function

Private Function TextConversions() As Boolean
    Dim B(0 To 0) As Byte
    Dim Arena() As Byte
    Dim Used As Long
    Dim Start As Long = 77
    Dim Length As Long = 88
    Dim Value As LongLong = 99
    Dim Status As Boolean
    B(0) = 48
    Status = RecordError(42)
    Status = True
    Status = ConstantValues.TryTextValue(B, 0, 1, SyntaxTokens.KwString, Value)
    If Status Or Value <> 99 Or Err.Number <> 42 Then Exit Function
    Err.Clear
    Status = True
    Status = ConstantValues.TryTextValue(B, 0, 1, 0, Value)
    If Status Or Value <> 99 Or Err.Number <> 0 Then Exit Function
    Status = False
    Status = ConstantValues.TryTextValue(B, 0, 1, SyntaxTokens.KwBoolean, Value)
    If Not Status Or Value <> 0 Or Err.Number <> 0 Then Exit Function
    Status = True
    Status = ConstantText.TryAppendScalar(0, SyntaxTokens.KwString, Arena, Used, Start, Length)
    If Status Or Used <> 0 Or Start <> 77 Or Length <> 88 Then Exit Function
    If BufferPrimitives.ByteStorageLength(Arena) <> 0 Or Err.Number <> 0 Then Exit Function
    TextConversions = True
End Function

' GENERATED CASES
