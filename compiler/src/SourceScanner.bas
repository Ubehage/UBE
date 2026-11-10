UBE SOURCE 1 MODULE
Attribute UBE_Name = "SourceScanner"
' Scans immutable zero-based UTF-8 bytes into retained spans; source storage must outlive its tokens.
Public Const WordToken As Long = 1
Public Const IdentifierToken As Long = 2
Public Const NumberToken As Long = 3
Public Const StringToken As Long = 4
Public Const SymbolToken As Long = 5
Public Const NewlineToken As Long = 6
Public Const EndToken As Long = 7

Public Type SourceToken
    Kind As Long
    ByteStart As Long
    ByteLength As Long
    [Line] As Long
    Column As Long
    Utf16Start As Long
    Utf16Length As Long
End Type

Public Type ScanDiagnostic
    Code As Long
    Reason As Long
    ByteOffset As Long
    Utf16Offset As Long
    [Line] As Long
    Column As Long
End Type

Private Type SourcePosition
    ByteOffset As Long
    Utf16Offset As Long
    [Line] As Long
    Column As Long
End Type

' Grows retained token records through the existing typed array storage primitive.
Private Intrinsic Function ResizeTokens(ByRef Values() As SourceToken, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeTokens.UBE_Primitive = "Array.TryResize"
End Function

' Scans a quoted spelling, decoding only escape length for the ASCII identifier bound.
Private Function ScanQuoted(ByRef Source() As Byte, ByVal Length As Long, ByRef Position As SourcePosition, ByVal Kind As Long, ByRef Diagnostic As ScanDiagnostic) As Boolean
    Dim Start As SourcePosition
    Dim Closing As Long
    Dim Value As Long
    Dim Decoded As Long
    Dim Closed As Boolean
    On Error GoTo InvalidStorage
    Start = Position
    Closing = 34
    If Kind = IdentifierToken Then Closing = 93
    Advance Source, Length, Position
    Do While Position.ByteOffset < Length
        Value = ByteAt(Source, Position.ByteOffset, Length)
        If Value = 13 Or Value = 10 Then Exit Do
        If Value = Closing Then
            Advance Source, Length, Position
            If ByteAt(Source, Position.ByteOffset, Length) <> Closing Then Closed = True: Exit Do
        End If
        If Kind = IdentifierToken Then
            If Value < 32 Or Value > 126 Then ScanQuoted = Reject(Diagnostic, 3, 2, Start): Exit Function
        End If
        Decoded = Decoded + 1
        Advance Source, Length, Position
    Loop
    If Closed = False Then ScanQuoted = Reject(Diagnostic, 2, 1, Start): Exit Function
    If Kind = IdentifierToken Then
        If Decoded = 0 Or Decoded > 128 Then ScanQuoted = Reject(Diagnostic, 4, 4, Start): Exit Function
    End If
    ScanQuoted = True
    Exit Function
InvalidStorage:
    Err.Raise Err.Number
End Function

' Recognizes one digit in the requested lexical radix without interpreting numeric magnitude.
Private Function RadixDigit(ByVal Value As Long, ByVal Radix As Long) As Boolean
    On Error GoTo InvalidStorage
    Value = FoldAscii(Value)
    If Radix = 16 Then RadixDigit = Digit(Value) Or (Value >= 97 And Value <= 102): Exit Function
    If Radix = 8 Then RadixDigit = Value >= 48 And Value <= 55: Exit Function
    RadixDigit = Digit(Value)
    Exit Function
InvalidStorage:
    Err.Raise Err.Number
End Function

' Scans complete decimal, based and real spellings, retaining authoritative adjacent suffixes.
Private Function ScanNumber(ByRef Source() As Byte, ByVal Length As Long, ByRef Position As SourcePosition, ByRef Diagnostic As ScanDiagnostic) As Boolean
    Dim Start As SourcePosition
    Dim DigitsStart As Long
    Dim Value As Long
    Dim Radix As Long = 10
    Dim RealNumber As Boolean
    On Error GoTo InvalidStorage
    Start = Position
    If ByteAt(Source, Position.ByteOffset, Length) = 38 Then
        Radix = 8
        If FoldAscii(ByteAt(Source, Position.ByteOffset + 1, Length)) = 104 Then Radix = 16
        Advance Source, Length, Position
        Advance Source, Length, Position
    End If
    DigitsStart = Position.ByteOffset
    Do While RadixDigit(ByteAt(Source, Position.ByteOffset, Length), Radix)
        Advance Source, Length, Position
    Loop
    If Radix <> 10 And Position.ByteOffset = DigitsStart Then ScanNumber = Reject(Diagnostic, 2, 2, Start): Exit Function
    If Radix = 10 Then
        If ByteAt(Source, Position.ByteOffset, Length) = 46 Then
            RealNumber = True
            Advance Source, Length, Position
            Do While Digit(ByteAt(Source, Position.ByteOffset, Length))
                Advance Source, Length, Position
            Loop
        End If
        If FoldAscii(ByteAt(Source, Position.ByteOffset, Length)) = 101 Then
            RealNumber = True
            Advance Source, Length, Position
            Value = ByteAt(Source, Position.ByteOffset, Length)
            If Value = 43 Or Value = 45 Then Advance Source, Length, Position
            DigitsStart = Position.ByteOffset
            Do While Digit(ByteAt(Source, Position.ByteOffset, Length))
                Advance Source, Length, Position
            Loop
            If DigitsStart = Position.ByteOffset Then ScanNumber = Reject(Diagnostic, 2, 2, Start): Exit Function
        End If
    End If
    Value = FoldAscii(ByteAt(Source, Position.ByteOffset, Length))
    If (Value = 37 Or Value = 38 Or Value = 94) And Not RealNumber Then
        Advance Source, Length, Position
    Else
        If Radix = 10 And (Value = 33 Or Value = 35 Or Value = 64 Or Value = 102 Or Value = 114 Or Value = 100) Then Advance Source, Length, Position
    End If
    Value = ByteAt(Source, Position.ByteOffset, Length)
    If NameStart(Value) Or Digit(Value) Then ScanNumber = Reject(Diagnostic, 2, 2, Start): Exit Function
    ScanNumber = True
    Exit Function
InvalidStorage:
    Err.Raise Err.Number
End Function

' Recognizes admitted one-byte punctuation before longest-match pairs are consumed.
Private Function SymbolCharacter(ByVal Value As Long) As Boolean
    SymbolCharacter = Value = 40 Or Value = 41 Or Value = 43 Or Value = 45 Or Value = 42 Or Value = 47 Or Value = 92 Or Value = 94 Or Value = 38 Or Value = 61 Or Value = 60 Or Value = 62 Or Value = 46 Or Value = 44 Or Value = 58 Or Value = 59 Or Value = 37 Or Value = 33 Or Value = 64 Or Value = 36
End Function

' Recognizes the two contextual words that permit a following inline Rem comment.
Private Function InlineStatementWord(ByRef Source() As Byte, ByVal Start As Long, ByVal Count As Long, ByVal Length As Long) As Boolean
    Dim First As Long
    On Error GoTo InvalidStorage
    If Count <> 4 Then InlineStatementWord = False: Exit Function
    First = FoldAscii(ByteAt(Source, Start, Length))
    If First = 116 Then
        InlineStatementWord = FoldAscii(ByteAt(Source, Start + 1, Length)) = 104 And FoldAscii(ByteAt(Source, Start + 2, Length)) = 101 And FoldAscii(ByteAt(Source, Start + 3, Length)) = 110
    Else
        InlineStatementWord = First = 101 And FoldAscii(ByteAt(Source, Start + 1, Length)) = 108 And FoldAscii(ByteAt(Source, Start + 2, Length)) = 115 And FoldAscii(ByteAt(Source, Start + 3, Length)) = 101
    End If
    Exit Function
InvalidStorage:
    Err.Raise Err.Number
End Function

' Scans at most 4096 bytes and publishes only complete tokens; Count/Diagnostic must not alias Tokens storage.
' Independent outputs guarantee Count zero and preservation of the previous token array on failure.
Public Function TryScan(ByRef Source() As Byte, ByRef Tokens() As SourceToken, ByRef Count As Long, ByRef Diagnostic As ScanDiagnostic) As Boolean
    Dim Candidate() As SourceToken
    Dim CandidateCount As Long
    Dim Capacity As Long
    Dim Position As SourcePosition
    Dim Start As SourcePosition
    Dim Look As SourcePosition
    Dim Initial As SourcePosition
    Dim Length As Long
    Dim Value As Long
    Dim Following As Long
    Dim Kind As Long
    Dim Depth As Long
    Dim Index As Long
    Dim Previous As Long
    Dim Status As Boolean
    Dim StatementStart As Boolean = True
    Dim NumericLabel As Boolean
    Dim MemberWord As Boolean
    On Error GoTo InvalidStorage
    Position.Utf16Offset = 1
    Position.Line = 1
    Position.Column = 1
    Count = 0
    Diagnostic.Code = 0
    Diagnostic.Reason = 0
    Diagnostic.ByteOffset = 0
    Diagnostic.Utf16Offset = 1
    Diagnostic.Line = 1
    Diagnostic.Column = 1
    Length = BufferPrimitives.ByteStorageLength(Source)
    Status = ValidateSource(Source, Length, Initial, Diagnostic)
    If Status = False Then TryScan = False: Exit Function
    Position = Initial
    Do While Position.ByteOffset < Length
        Start = Position
        Value = ByteAt(Source, Position.ByteOffset, Length)
        If Horizontal(Value) Then
            Advance Source, Length, Position
            GoTo NextPosition
        End If
        If Value = 13 Or Value = 10 Then
            AdvanceNewline Source, Length, Position
            Status = AddToken(Candidate, CandidateCount, Capacity, NewlineToken, Start, Position, Diagnostic)
            If Status = False Then TryScan = False: Exit Function
            StatementStart = True
            GoTo NextPosition
        End If
        If Value = 39 Or (StatementStart And RemAt(Source, Position.ByteOffset, Length)) Then
            Do While Position.ByteOffset < Length
                Value = ByteAt(Source, Position.ByteOffset, Length)
                If Value = 13 Or Value = 10 Then Exit Do
                Advance Source, Length, Position
            Loop
            GoTo NextPosition
        End If
        If Value = 95 And Position.ByteOffset > Initial.ByteOffset Then
            Previous = ByteAt(Source, Position.ByteOffset - 1, Length)
            If Horizontal(Previous) Then
                Look = Position
                Advance Source, Length, Look
                Do While Horizontal(ByteAt(Source, Look.ByteOffset, Length))
                    Advance Source, Length, Look
                Loop
                Following = ByteAt(Source, Look.ByteOffset, Length)
                If Following = 39 Or RemAt(Source, Look.ByteOffset, Length) Then
                    Do While Look.ByteOffset < Length
                        Following = ByteAt(Source, Look.ByteOffset, Length)
                        If Following = 13 Or Following = 10 Then Exit Do
                        Advance Source, Length, Look
                    Loop
                End If
                Following = ByteAt(Source, Look.ByteOffset, Length)
                If Following = -1 Then TryScan = Reject(Diagnostic, 2, 3, Start): Exit Function
                If Following = 13 Or Following = 10 Then
                    AdvanceNewline Source, Length, Look
                    Position = Look
                    GoTo NextPosition
                End If
            End If
        End If
        Kind = SymbolToken
        If Value = 34 Or Value = 91 Then
            Kind = StringToken
            If Value = 91 Then Kind = IdentifierToken
            Status = ScanQuoted(Source, Length, Position, Kind, Diagnostic)
            If Status = False Then TryScan = False: Exit Function
        Else
            If NameStart(Value) Then
                Kind = WordToken
                Do
                    Advance Source, Length, Position
                    Following = ByteAt(Source, Position.ByteOffset, Length)
                Loop While NameStart(Following) Or Digit(Following)
                If Position.ByteOffset - Start.ByteOffset > 128 Then TryScan = Reject(Diagnostic, 4, 4, Start): Exit Function
                If StatementStart And Position.ByteOffset - Start.ByteOffset = 3 Then
                    If FoldAscii(Value) = 97 And FoldAscii(ByteAt(Source, Start.ByteOffset + 1, Length)) = 115 And FoldAscii(ByteAt(Source, Start.ByteOffset + 2, Length)) = 109 Then TryScan = Reject(Diagnostic, 3, 1, Start): Exit Function
                End If
            Else
                Following = FoldAscii(ByteAt(Source, Position.ByteOffset + 1, Length))
                If Digit(Value) Or (Value = 46 And Digit(Following)) Or (Value = 38 And (Following = 104 Or Following = 111)) Then
                    Kind = NumberToken
                    Status = ScanNumber(Source, Length, Position, Diagnostic)
                    If Status = False Then TryScan = False: Exit Function
                Else
                    If Value > 127 Or Value = 35 Then TryScan = Reject(Diagnostic, 3, 2, Start): Exit Function
                    If Not SymbolCharacter(Value) Then TryScan = Reject(Diagnostic, 2, 4, Start): Exit Function
                    Advance Source, Length, Position
                    Following = ByteAt(Source, Position.ByteOffset, Length)
                    If ((Value = 60 Or Value = 62 Or Value = 58) And Following = 61) Or (Value = 60 And Following = 62) Then Advance Source, Length, Position
                End If
            End If
        End If
        Status = AddToken(Candidate, CandidateCount, Capacity, Kind, Start, Position, Diagnostic)
        If Status = False Then TryScan = False: Exit Function
        MemberWord = False
        If CandidateCount > 1 Then
            Previous = Candidate(CandidateCount - 2).ByteStart
            Following = ByteAt(Source, Previous, Length)
            MemberWord = Candidate(CandidateCount - 2).Kind = SymbolToken And Candidate(CandidateCount - 2).ByteLength = 1 And (Following = 46 Or Following = 33)
        End If
        NumericLabel = StatementStart And Kind = NumberToken And Depth = 0
        If NumericLabel Then
            Index = Start.ByteOffset
            Do While Index < Position.ByteOffset
                If Not Digit(ByteAt(Source, Index, Length)) Then NumericLabel = False
                Index = Index + 1
            Loop
        End If
        If Kind = SymbolToken Then
            If Value = 40 Then Depth = Depth + 1
            If Value = 41 Then Depth = Depth - 1
        End If
        StatementStart = NumericLabel Or (Value = 58 And Kind = SymbolToken And Position.ByteOffset - Start.ByteOffset = 1 And Depth = 0) Or (Kind = WordToken And Not MemberWord And InlineStatementWord(Source, Start.ByteOffset, Position.ByteOffset - Start.ByteOffset, Length))
NextPosition:
    Loop
    Kind = 0
    If CandidateCount > 0 Then Kind = Candidate(CandidateCount - 1).Kind
    If Kind <> NewlineToken Then
        Status = AddToken(Candidate, CandidateCount, Capacity, NewlineToken, Position, Position, Diagnostic)
        If Status = False Then TryScan = False: Exit Function
    End If
    Status = AddToken(Candidate, CandidateCount, Capacity, EndToken, Position, Position, Diagnostic)
    If Status = False Then TryScan = False: Exit Function
    Status = ResizeTokens(Candidate, CandidateCount, True)
    If Status = False Then TryScan = Reject(Diagnostic, 5, 1, Position): Exit Function
    Status = CopyTokens(Tokens, Candidate)
    If Status = False Then TryScan = Reject(Diagnostic, 5, 1, Position): Exit Function
    Count = CandidateCount
    TryScan = True
    Exit Function
InvalidStorage:
    Count = 0
    Diagnostic.Code = 6
    Diagnostic.Reason = 1
    Diagnostic.ByteOffset = Position.ByteOffset
    Diagnostic.Utf16Offset = Position.Utf16Offset
    Diagnostic.Line = Position.Line
    Diagnostic.Column = Position.Column
    TryScan = False
End Function

' Publishes a complete token sequence as an independent array value.
Private Intrinsic Function CopyTokens(ByRef Destination() As SourceToken, ByRef Source() As SourceToken) As Boolean
Attribute CopyTokens.UBE_Primitive = "Array.TryCopy"
End Function

' Reads one ASCII byte or the distinct end-of-input sentinel without indexing out of range.
Private Function ByteAt(ByRef Source() As Byte, ByVal Offset As Long, ByVal Length As Long) As Long
    On Error GoTo InvalidStorage
    If Offset < 0 Or Offset >= Length Then ByteAt = -1: Exit Function
    ByteAt = Source(Offset)
    Exit Function
InvalidStorage:
    Err.Raise Err.Number
End Function

' Folds only the explicitly admitted ASCII identifier alphabet.
Private Function FoldAscii(ByVal Value As Long) As Long
    FoldAscii = Value
    If Value >= 65 And Value <= 90 Then FoldAscii = Value + 32
End Function

' Recognizes an ASCII bare-name initial character.
Private Function NameStart(ByVal Value As Long) As Boolean
    NameStart = (Value >= 65 And Value <= 90) Or (Value >= 97 And Value <= 122) Or Value = 95
End Function

' Recognizes one decimal digit, excluding the negative end sentinel.
Private Function Digit(ByVal Value As Long) As Boolean
    Digit = Value >= 48 And Value <= 57
End Function

' Recognizes whitespace that can participate in explicit continuation syntax.
Private Function Horizontal(ByVal Value As Long) As Boolean
    Horizontal = Value = 32 Or Value = 9
End Function

' Recognizes Rem only with its required following whitespace or end boundary.
Private Function RemAt(ByRef Source() As Byte, ByVal Offset As Long, ByVal Length As Long) As Boolean
    Dim Value As Long
    On Error GoTo InvalidStorage
    If FoldAscii(ByteAt(Source, Offset, Length)) <> 114 Then RemAt = False: Exit Function
    If FoldAscii(ByteAt(Source, Offset + 1, Length)) <> 101 Then RemAt = False: Exit Function
    If FoldAscii(ByteAt(Source, Offset + 2, Length)) <> 109 Then RemAt = False: Exit Function
    Value = ByteAt(Source, Offset + 3, Length)
    RemAt = Horizontal(Value) Or Value = 13 Or Value = 10 Or Value = -1
    Exit Function
InvalidStorage:
    Err.Raise Err.Number
End Function

' Records one deterministic numeric diagnostic without touching the caller's token array.
Private Function Reject(ByRef Diagnostic As ScanDiagnostic, ByVal Code As Long, ByVal Reason As Long, ByRef Position As SourcePosition) As Boolean
    Diagnostic.Code = Code
    Diagnostic.Reason = Reason
    Diagnostic.ByteOffset = Position.ByteOffset
    Diagnostic.Utf16Offset = Position.Utf16Offset
    Diagnostic.Line = Position.Line
    Diagnostic.Column = Position.Column
    Reject = False
End Function

' Advances one prevalidated non-newline scalar while retaining UTF-16 physical columns.
Private Sub Advance(ByRef Source() As Byte, ByVal Length As Long, ByRef Position As SourcePosition)
    Dim ByteWidth As Long
    Dim Units As Long
    Dim Status As Boolean
    On Error GoTo InvalidStorage
    Status = Utf8.TrySequenceWidth(Source, Position.ByteOffset, Length, ByteWidth, Units)
    If Status = False Then Err.Raise 5
    Position.ByteOffset = Position.ByteOffset + ByteWidth
    Position.Utf16Offset = Position.Utf16Offset + Units
    Position.Column = Position.Column + Units
    Exit Sub
InvalidStorage:
    Err.Raise Err.Number
End Sub

' Consumes a validated LF or CRLF as one physical line break.
Private Sub AdvanceNewline(ByRef Source() As Byte, ByVal Length As Long, ByRef Position As SourcePosition)
    Dim ByteWidth As Long = 1
    On Error GoTo InvalidStorage
    If ByteAt(Source, Position.ByteOffset, Length) = 13 Then ByteWidth = 2
    Position.ByteOffset = Position.ByteOffset + ByteWidth
    Position.Utf16Offset = Position.Utf16Offset + ByteWidth
    Position.Line = Position.Line + 1
    Position.Column = 1
    Exit Sub
InvalidStorage:
    Err.Raise Err.Number
End Sub

' Validates all bytes, including ignored comments and quoted text, before tokenization.
Private Function ValidateSource(ByRef Source() As Byte, ByVal Length As Long, ByRef Initial As SourcePosition, ByRef Diagnostic As ScanDiagnostic) As Boolean
    Dim Position As SourcePosition
    Dim Value As Long
    Dim ByteWidth As Long
    Dim Units As Long
    Dim Status As Boolean
    On Error GoTo InvalidStorage
    Initial.ByteOffset = 0
    Initial.Utf16Offset = 1
    Initial.Line = 1
    Initial.Column = 1
    Position = Initial
    If Length > 4096 Then ValidateSource = Reject(Diagnostic, 4, 1, Initial): Exit Function
    If ByteAt(Source, 0, Length) = 239 And ByteAt(Source, 1, Length) = 187 And ByteAt(Source, 2, Length) = 191 Then Initial.ByteOffset = 3
    Position = Initial
    Do While Position.ByteOffset < Length
        Value = ByteAt(Source, Position.ByteOffset, Length)
        Status = Utf8.TrySequenceWidth(Source, Position.ByteOffset, Length, ByteWidth, Units)
        If Status = False Then ValidateSource = Reject(Diagnostic, 1, 1, Position): Exit Function
        If Value = 127 Or (Value < 32 And Value <> 9 And Value <> 10 And Value <> 13) Then ValidateSource = Reject(Diagnostic, 1, 2, Position): Exit Function
        If Value = 13 Then
            If ByteAt(Source, Position.ByteOffset + 1, Length) <> 10 Then ValidateSource = Reject(Diagnostic, 1, 3, Position): Exit Function
        End If
        If Value = 13 Or Value = 10 Then
            AdvanceNewline Source, Length, Position
        Else
            Position.ByteOffset = Position.ByteOffset + ByteWidth
            Position.Utf16Offset = Position.Utf16Offset + Units
            Position.Column = Position.Column + Units
        End If
    Loop
    ValidateSource = True
    Exit Function
InvalidStorage:
    Err.Raise Err.Number
End Function

' Appends within fixed limits, retaining original byte spelling instead of allocating String text.
Private Function AddToken(ByRef Candidate() As SourceToken, ByRef Count As Long, ByRef Capacity As Long, ByVal Kind As Long, ByRef Start As SourcePosition, ByRef Finish As SourcePosition, ByRef Diagnostic As ScanDiagnostic) As Boolean
    Dim Status As Boolean
    Dim Token As SourceToken
    On Error GoTo InvalidStorage
    If Count >= 4096 Then AddToken = Reject(Diagnostic, 4, 3, Start): Exit Function
    If Finish.Utf16Offset - Start.Utf16Offset > 4096 Then AddToken = Reject(Diagnostic, 4, 2, Start): Exit Function
    If Count = Capacity Then
        If Capacity = 0 Then Capacity = 32 Else Capacity = Capacity + Capacity
        If Capacity > 4096 Then Capacity = 4096
        Status = ResizeTokens(Candidate, Capacity, True)
        If Status = False Then AddToken = Reject(Diagnostic, 5, 1, Start): Exit Function
    End If
    Token.Kind = Kind
    Token.ByteStart = Start.ByteOffset
    Token.ByteLength = Finish.ByteOffset - Start.ByteOffset
    Token.Line = Start.Line
    Token.Column = Start.Column
    Token.Utf16Start = Start.Utf16Offset
    Token.Utf16Length = Finish.Utf16Offset - Start.Utf16Offset
    Candidate(Count) = Token
    Count = Count + 1
    AddToken = True
    Exit Function
InvalidStorage:
    Err.Raise Err.Number
End Function
