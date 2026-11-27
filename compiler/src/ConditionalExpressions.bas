UBE SOURCE 1 MODULE
Attribute UBE_Name = "ConditionalExpressions"
' Evaluates the directive grammar using caller-owned symbols and scalar constant operations.
Public Type ValueFact
    TypeCode As Long
    Number As LongLong
    TextStart As Long
    TextLength As Long
End Type

Public Type SymbolFact
    NameStart As Long
    NameLength As Long
    Value As ValueFact
End Type

Private Type EvaluationState
    Position As Long
    Finish As Long
    TokenCount As Long
    SymbolCount As Long
    TextUsed As Long
    Depth As Long
    Work As Long
End Type

Private Intrinsic Function TokenLength(ByRef Values() As SourceScanner.SourceToken) As Long
Attribute TokenLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function SymbolLength(ByRef Values() As SymbolFact) As Long
Attribute SymbolLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function MoveBytes(ByRef Destination() As Byte, ByRef Source() As Byte) As Boolean
Attribute MoveBytes.UBE_Primitive = "Array.Move"
End Function
Private Intrinsic Function RecordError(ByVal Number As Long) As Boolean
Attribute RecordError.UBE_Primitive = "Error.Set"
End Function

' Returns the first physical location without replacing an earlier diagnostic.
Private Function Reject(ByRef T() As SourceScanner.SourceToken, ByRef S As EvaluationState, ByRef D As SourceParser.ParseDiagnostic, ByVal Index As Long, ByVal Code As Long, ByVal Reason As Long) As Boolean
    If D.Code <> 0 Then Exit Function
    D.Code = Code
    D.Reason = Reason
    If Index >= S.TokenCount Then Index = S.TokenCount - 1
    If Index < 0 Then Index = 0
    D.TokenIndex = Index
    If S.TokenCount > 0 Then
        D.ByteOffset = T(Index).ByteStart
        D.Utf16Offset = T(Index).Utf16Start
        D.Line = T(Index).Line
        D.Column = T(Index).Column
    End If
End Function

Private Function CodeAt(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef S As EvaluationState) As Long
    If S.Position >= S.Finish Then CodeAt = SyntaxTokens.CodeEnd: Exit Function
    CodeAt = SyntaxTokens.TokenCode(B, T, S.Position, S.TokenCount)
End Function

' Conditional precedence is specified separately from the core expression grammar.
Private Function OperatorRank(ByVal Code As Long) As Long
    If Code = SyntaxTokens.KwImp Then OperatorRank = 1
    If Code = SyntaxTokens.KwEqv Then OperatorRank = 2
    If Code = SyntaxTokens.KwXor Then OperatorRank = 3
    If Code = SyntaxTokens.KwOr Or Code = SyntaxTokens.KwOrElse Then OperatorRank = 4
    If Code = SyntaxTokens.KwAnd Or Code = SyntaxTokens.KwAndAlso Then OperatorRank = 5
    If Code = SyntaxTokens.SymEqual Or Code = SyntaxTokens.SymNotEqual Or Code = SyntaxTokens.SymLess Or Code = SyntaxTokens.SymGreater Or Code = SyntaxTokens.SymLessEqual Or Code = SyntaxTokens.SymGreaterEqual Then OperatorRank = 7
    If Code = SyntaxTokens.SymPlus Or Code = SyntaxTokens.SymMinus Or Code = SyntaxTokens.SymAmpersand Then OperatorRank = 8
    If Code = SyntaxTokens.SymStar Or Code = SyntaxTokens.SymSlash Or Code = SyntaxTokens.SymBackslash Or Code = SyntaxTokens.KwMod Then OperatorRank = 9
End Function

Private Function IsScalar(ByVal TypeCode As Long) As Boolean
    IsScalar = TypeCode = SyntaxTokens.KwBoolean Or TypeCode = SyntaxTokens.KwString Or ConstantValues.IsNumeric(TypeCode)
End Function

Private Function ValidSpan(ByVal Capacity As Long, ByVal Start As Long, ByVal Length As Long) As Boolean
    If Start < 0 Or Length < 0 Or Start > Capacity Then Exit Function
    ValidSpan = Length <= Capacity - Start
End Function

' Lookup decodes names through the scanner's common spelling interface.
Private Function ResolveName(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef Names() As Byte, ByRef Symbols() As SymbolFact, ByRef S As EvaluationState, ByRef D As SourceParser.ParseDiagnostic, ByVal Token As Long, ByRef Result As ValueFact) As Boolean
    Dim Index As Long
    Dim Offset As Long
    Dim Character As Long
    Dim Same As Boolean
    Dim Found As Boolean
    Do While Index < S.SymbolCount
        Same = True
        Offset = 0
        Do While Offset < Symbols(Index).NameLength
            If S.Work >= 10000000 Then ResolveName = Reject(T, S, D, Token, 4, 2): Exit Function
            S.Work = S.Work + 1
            Character = SyntaxTokens.SpellingByte(B, T, Token, S.TokenCount, Offset)
            If Character <> Names(Symbols(Index).NameStart + Offset) Then Same = False: Exit Do
            Offset = Offset + 1
        Loop
        If Same Then
            If SyntaxTokens.SpellingByte(B, T, Token, S.TokenCount, Offset) <> -1 Then Same = False
        End If
        If Same Then
            If Found Then ResolveName = Reject(T, S, D, Token, 3, 2): Exit Function
            Result = Symbols(Index).Value
            Found = True
        End If
        Index = Index + 1
    Loop
    If Not Found Then ResolveName = Reject(T, S, D, Token, 3, 1): Exit Function
    ResolveName = True
End Function

' Converts a scalar to invariant text using the same library algorithms as ordinary constants.
Private Function AsText(ByRef Value As ValueFact, ByRef Arena() As Byte, ByRef S As EvaluationState, ByRef Start As Long, ByRef Length As Long) As Boolean
    If Value.TypeCode = SyntaxTokens.KwString Then
        Start = Value.TextStart
        Length = Value.TextLength
        AsText = True
        Exit Function
    End If
    AsText = ConstantText.TryAppendScalar(Value.Number, Value.TypeCode, Arena, S.TextUsed, Start, Length)
End Function

' Text operands are validated even when short-circuit evaluation suppresses their values.
Private Function TextBinary(ByRef T() As SourceScanner.SourceToken, ByRef Arena() As Byte, ByRef S As EvaluationState, ByRef D As SourceParser.ParseDiagnostic, ByVal Token As Long, ByVal Operator As Long, ByVal Enabled As Boolean, ByRef LeftValue As ValueFact, ByRef RightValue As ValueFact, ByRef Result As ValueFact) As Boolean
    Dim LeftStart As Long
    Dim LeftLength As Long
    Dim RightStart As Long
    Dim RightLength As Long
    Dim Order As Long
    Dim Reason As Long
    If Operator = SyntaxTokens.SymAmpersand Then
        Result.TypeCode = SyntaxTokens.KwString
    Else
        If LeftValue.TypeCode <> SyntaxTokens.KwString Or RightValue.TypeCode <> SyntaxTokens.KwString Or OperatorRank(Operator) <> 7 Then TextBinary = Reject(T, S, D, Token, 3, 3): Exit Function
        Result.TypeCode = SyntaxTokens.KwBoolean
    End If
    If Not Enabled Then TextBinary = True: Exit Function
    If Not AsText(LeftValue, Arena, S, LeftStart, LeftLength) Then TextBinary = Reject(T, S, D, Token, 5, 1): Exit Function
    If Not AsText(RightValue, Arena, S, RightStart, RightLength) Then TextBinary = Reject(T, S, D, Token, 5, 1): Exit Function
    If Operator = SyntaxTokens.SymAmpersand Then
        If Not ConstantText.TryConcatenate(Arena, S.TextUsed, LeftStart, LeftLength, RightStart, RightLength, Result.TextStart, Result.TextLength) Then TextBinary = Reject(T, S, D, Token, 5, 1): Exit Function
    Else
        If Not ConstantText.TryCompare(Arena, S.TextUsed, LeftStart, LeftLength, RightStart, RightLength, Order) Then TextBinary = Reject(T, S, D, Token, 5, 1): Exit Function
        If Not ConstantValues.TryBinary(Operator, Order, SyntaxTokens.KwLong, 0, SyntaxTokens.KwLong, Result.Number, Result.TypeCode, Reason) Then TextBinary = Reject(T, S, D, Token, 6, Reason): Exit Function
    End If
    TextBinary = True
End Function

Private Function ApplyBinary(ByRef T() As SourceScanner.SourceToken, ByRef Arena() As Byte, ByRef S As EvaluationState, ByRef D As SourceParser.ParseDiagnostic, ByVal Token As Long, ByVal Operator As Long, ByVal Enabled As Boolean, ByRef LeftValue As ValueFact, ByRef RightValue As ValueFact, ByRef Result As ValueFact) As Boolean
    Dim Reason As Long
    If Operator = SyntaxTokens.KwAndAlso Or Operator = SyntaxTokens.KwOrElse Then
        If LeftValue.TypeCode <> SyntaxTokens.KwBoolean Or RightValue.TypeCode <> SyntaxTokens.KwBoolean Then ApplyBinary = Reject(T, S, D, Token, 3, 3): Exit Function
        Result.TypeCode = SyntaxTokens.KwBoolean
        If Enabled Then
            If Operator = SyntaxTokens.KwAndAlso Then
                If LeftValue.Number <> 0 And RightValue.Number <> 0 Then Result.Number = -1
            Else
                If LeftValue.Number <> 0 Or RightValue.Number <> 0 Then Result.Number = -1
            End If
        End If
    ElseIf Operator = SyntaxTokens.SymAmpersand Or LeftValue.TypeCode = SyntaxTokens.KwString Or RightValue.TypeCode = SyntaxTokens.KwString Then
        ApplyBinary = TextBinary(T, Arena, S, D, Token, Operator, Enabled, LeftValue, RightValue, Result)
        Exit Function
    Else
        Result.TypeCode = ConstantValues.BinaryResultType(Operator, LeftValue.TypeCode, RightValue.TypeCode)
        If Result.TypeCode = 0 Then ApplyBinary = Reject(T, S, D, Token, 3, 3): Exit Function
        If Enabled Then
            If Not ConstantValues.TryBinary(Operator, LeftValue.Number, LeftValue.TypeCode, RightValue.Number, RightValue.TypeCode, Result.Number, Result.TypeCode, Reason) Then ApplyBinary = Reject(T, S, D, Token, 6, Reason): Exit Function
        End If
    End If
    ApplyBinary = True
End Function

' Reads values and unary forms; the directly attached minus uses authoritative literal rules.
Private Function ReadPrimary(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef Names() As Byte, ByRef Symbols() As SymbolFact, ByRef Arena() As Byte, ByRef S As EvaluationState, ByRef D As SourceParser.ParseDiagnostic, ByVal Enabled As Boolean, ByRef Result As ValueFact) As Boolean
    Dim Token As Long
    Dim Code As Long
    Dim Minimum As Long
    Dim Reason As Long
    Dim Operand As ValueFact
    Dim Ignored As LongLong
    Token = S.Position
    Code = CodeAt(B, T, S)
    If S.Position >= S.Finish Then ReadPrimary = Reject(T, S, D, Token, 2, 1): Exit Function
    S.Position = S.Position + 1
    If Code = SyntaxTokens.SymPlus Or Code = SyntaxTokens.SymMinus Or Code = SyntaxTokens.KwNot Then
        Minimum = 10
        If Code = SyntaxTokens.KwNot Then
            Minimum = 6
            If S.Position >= S.Finish Then ReadPrimary = Reject(T, S, D, Token, 2, 1): Exit Function
            If T(S.Position).ByteStart <= T(Token).ByteStart + T(Token).ByteLength Then ReadPrimary = Reject(T, S, D, Token, 2, 2): Exit Function
        ElseIf Code = SyntaxTokens.SymMinus And S.Position < S.Finish Then
            If T(S.Position).Kind = SourceScanner.NumberToken Then
                If T(S.Position).ByteStart = T(Token).ByteStart + T(Token).ByteLength Then
                    If Not ConstantValues.TryLiteral(B, T(S.Position), 0, True, Result.Number, Result.TypeCode, Reason) Then ReadPrimary = Reject(T, S, D, S.Position, 6, Reason): Exit Function
                    S.Position = S.Position + 1
                    ReadPrimary = True
                    Exit Function
                End If
            End If
        End If
        If Not ReadExpression(B, T, Names, Symbols, Arena, S, D, Minimum, Enabled, Operand) Then Exit Function
        If Not ConstantValues.TryUnary(Code, 0, Operand.TypeCode, Ignored, Result.TypeCode, Reason) Then ReadPrimary = Reject(T, S, D, Token, 3, 3): Exit Function
        If Enabled Then
            If Not ConstantValues.TryUnary(Code, Operand.Number, Operand.TypeCode, Result.Number, Result.TypeCode, Reason) Then ReadPrimary = Reject(T, S, D, Token, 6, Reason): Exit Function
        End If
    ElseIf Code = SyntaxTokens.SymOpen Then
        If Not ReadExpression(B, T, Names, Symbols, Arena, S, D, 1, Enabled, Result) Then Exit Function
        If CodeAt(B, T, S) <> SyntaxTokens.SymClose Then ReadPrimary = Reject(T, S, D, S.Position, 2, 3): Exit Function
        S.Position = S.Position + 1
    ElseIf T(Token).Kind = SourceScanner.NumberToken Then
        If Not ConstantValues.TryLiteral(B, T(Token), 0, False, Result.Number, Result.TypeCode, Reason) Then ReadPrimary = Reject(T, S, D, Token, 6, Reason): Exit Function
    ElseIf T(Token).Kind = SourceScanner.StringToken Then
        Result.TypeCode = SyntaxTokens.KwString
        If Not ConstantText.TryAppendLiteral(B, T(Token).ByteStart, T(Token).ByteLength, Arena, S.TextUsed, Result.TextStart, Result.TextLength) Then ReadPrimary = Reject(T, S, D, Token, 5, 1): Exit Function
    ElseIf Code = SyntaxTokens.KwTrue Or Code = SyntaxTokens.KwFalse Then
        Result.TypeCode = SyntaxTokens.KwBoolean
        If Code = SyntaxTokens.KwTrue Then Result.Number = -1
    ElseIf SyntaxTokens.IsIdentifierToken(B, T, Token, S.TokenCount, False) Then
        If Not ResolveName(B, T, Names, Symbols, S, D, Token, Result) Then Exit Function
    Else
        ReadPrimary = Reject(T, S, D, Token, 2, 4): Exit Function
    End If
    ReadPrimary = True
End Function

' Parses every operand, but performs checked value operations only on selected operands.
Private Function ReadExpression(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef Names() As Byte, ByRef Symbols() As SymbolFact, ByRef Arena() As Byte, ByRef S As EvaluationState, ByRef D As SourceParser.ParseDiagnostic, ByVal Minimum As Long, ByVal Enabled As Boolean, ByRef Result As ValueFact) As Boolean
    Dim LeftValue As ValueFact
    Dim RightValue As ValueFact
    Dim Combined As ValueFact
    Dim EmptyValue As ValueFact
    Dim Code As Long
    Dim Rank As Long
    Dim Token As Long
    Dim ComparisonSeen As Boolean
    Dim RightEnabled As Boolean
    If S.Depth >= 48 Then ReadExpression = Reject(T, S, D, S.Position, 4, 1): Exit Function
    S.Depth = S.Depth + 1
    If Minimum > 6 And CodeAt(B, T, S) = SyntaxTokens.KwNot Then ReadExpression = Reject(T, S, D, S.Position, 2, 4): Exit Function
    If Not ReadPrimary(B, T, Names, Symbols, Arena, S, D, Enabled, LeftValue) Then Exit Function
    Do
        Code = CodeAt(B, T, S)
        Rank = OperatorRank(Code)
        If Rank = 0 Or Rank < Minimum Then Exit Do
        Token = S.Position
        If Rank = 7 Then
            If ComparisonSeen Then ReadExpression = Reject(T, S, D, Token, 2, 5): Exit Function
            ComparisonSeen = True
        End If
        If Rank <= 5 Then
            If Token = 0 Or Token + 1 >= S.Finish Then ReadExpression = Reject(T, S, D, Token, 2, 2): Exit Function
            If T(Token).ByteStart <= T(Token - 1).ByteStart + T(Token - 1).ByteLength Or T(Token + 1).ByteStart <= T(Token).ByteStart + T(Token).ByteLength Then ReadExpression = Reject(T, S, D, Token, 2, 2): Exit Function
        End If
        S.Position = S.Position + 1
        RightEnabled = Enabled
        If Code = SyntaxTokens.KwAndAlso Or Code = SyntaxTokens.KwOrElse Then
            If LeftValue.TypeCode <> SyntaxTokens.KwBoolean Then ReadExpression = Reject(T, S, D, Token, 3, 3): Exit Function
            If Code = SyntaxTokens.KwAndAlso And LeftValue.Number = 0 Then RightEnabled = False
            If Code = SyntaxTokens.KwOrElse And LeftValue.Number <> 0 Then RightEnabled = False
        End If
        RightValue = EmptyValue
        If Not ReadExpression(B, T, Names, Symbols, Arena, S, D, Rank + 1, RightEnabled, RightValue) Then Exit Function
        Combined = EmptyValue
        If Not ApplyBinary(T, Arena, S, D, Token, Code, Enabled, LeftValue, RightValue, Combined) Then Exit Function
        LeftValue = Combined
    Loop
    S.Depth = S.Depth - 1
    Result = LeftValue
    ReadExpression = True
End Function

' Validates caller inventories before any lookup or transactional arena preparation.
Private Function ValidateInputs(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef Names() As Byte, ByRef Symbols() As SymbolFact, ByRef Arena() As Byte, ByRef S As EvaluationState) As Boolean
    Dim Index As Long
    Dim Size As Long
    Dim NameSize As Long
    Dim Value As LongLong
    Dim Reason As Long
    If S.TokenCount < 0 Or S.TokenCount > TokenLength(T) Then Exit Function
    If S.Position < 0 Or S.Finish < S.Position Or S.Finish > S.TokenCount Then Exit Function
    If S.SymbolCount < 0 Or S.SymbolCount > SymbolLength(Symbols) Then Exit Function
    If S.TextUsed < 0 Or S.TextUsed > BufferPrimitives.ByteStorageLength(Arena) Then Exit Function
    Size = BufferPrimitives.ByteStorageLength(B)
    Index = 0
    Do While Index < S.TokenCount
        If Not ValidSpan(Size, T(Index).ByteStart, T(Index).ByteLength) Then Exit Function
        Index = Index + 1
    Loop
    NameSize = BufferPrimitives.ByteStorageLength(Names)
    Index = 0
    Do While Index < S.SymbolCount
        If Symbols(Index).NameLength < 1 Or Symbols(Index).NameLength > 128 Then Exit Function
        If Not ValidSpan(NameSize, Symbols(Index).NameStart, Symbols(Index).NameLength) Then Exit Function
        If Not IsScalar(Symbols(Index).Value.TypeCode) Then Exit Function
        If Symbols(Index).Value.TypeCode = SyntaxTokens.KwString Then
            If Not ValidSpan(S.TextUsed, Symbols(Index).Value.TextStart, Symbols(Index).Value.TextLength) Then Exit Function
        Else
            If Not ConstantValues.TryConvert(Symbols(Index).Value.Number, Symbols(Index).Value.TypeCode, Symbols(Index).Value.TypeCode, Value, Reason) Then Exit Function
        End If
        Index = Index + 1
    Loop
    ValidateInputs = True
End Function

' Token bounds are zero-based and half-open; names are decoded, ASCII-folded bytes.
' Only success replaces Result and the text arena. Source, Names and TextArena must be distinct.
Public Function TryEvaluate(ByRef Source() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByVal TokenCount As Long, ByVal FirstToken As Long, ByVal AfterToken As Long, ByRef Names() As Byte, ByRef Symbols() As SymbolFact, ByVal SymbolCount As Long, ByRef TextArena() As Byte, ByRef TextUsed As Long, ByRef Result As ValueFact, ByRef Diagnostic As SourceParser.ParseDiagnostic) As Boolean
    Dim S As EvaluationState
    Dim D As SourceParser.ParseDiagnostic
    Dim Candidate As ValueFact
    Dim Arena() As Byte
    Dim PriorError As Long
    Dim Restored As Boolean
    On Error GoTo Failed
    PriorError = Err.Number
    S.Position = FirstToken
    S.Finish = AfterToken
    S.TokenCount = TokenCount
    S.SymbolCount = SymbolCount
    S.TextUsed = TextUsed
    If Not ValidateInputs(Source, Tokens, Names, Symbols, TextArena, S) Then
        D.Code = 3
        D.Reason = 4
        GoTo Rejected
    End If
    If Not BufferPrimitives.TryResizeBytes(Arena, TextUsed, False) Then GoTo Failed
    If TextUsed > 0 Then
        If Not BufferPrimitives.CopyByteRange(TextArena, 0, Arena, 0, TextUsed) Then GoTo Failed
    End If
    If Not ReadExpression(Source, Tokens, Names, Symbols, Arena, S, D, 1, True, Candidate) Then GoTo Rejected
    If S.Position <> S.Finish Then
        Reject Tokens, S, D, S.Position, 2, 6
        GoTo Rejected
    End If
    If Not MoveBytes(TextArena, Arena) Then GoTo Failed
    TextUsed = S.TextUsed
    Result = Candidate
    Diagnostic = D
    If PriorError = 0 Then Err.Clear Else Restored = RecordError(PriorError)
    TryEvaluate = True
    Exit Function
Failed:
    If D.Code = 0 Then D.Code = 5: D.Reason = 1
Rejected:
    Diagnostic = D
    If PriorError = 0 Then Err.Clear Else Restored = RecordError(PriorError)
End Function
