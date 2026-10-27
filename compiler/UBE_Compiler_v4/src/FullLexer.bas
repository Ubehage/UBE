UBE SOURCE 1 MODULE
Attribute UBE_Name = "FullLexer"

Type FullLexicalToken
    TokenKind As Long
    SourceId As Long
    StartByte As Long
    ByteLength As Long
    LineNumber As Long
    ColumnNumber As Long
    Spelling As String
    Decoded As String
End Type

Type FullTokenSetResult
    Succeeded As Long
    SourceCount As Long
    TokenCount As Long
    WorkUnits As LongLong
    Dump As String
End Type

Function FullTokenKindName(ByVal Kind As Long) As String
    If Kind = 1 Then FullTokenKindName = "keyword"
    If Kind = 2 Then FullTokenKindName = "identifier"
    If Kind = 3 Then FullTokenKindName = "bracket-identifier"
    If Kind = 4 Then FullTokenKindName = "integer"
    If Kind = 5 Then FullTokenKindName = "real"
    If Kind = 6 Then FullTokenKindName = "string"
    If Kind = 7 Then FullTokenKindName = "date"
    If Kind = 8 Then FullTokenKindName = "punctuation"
    If Kind = 9 Then FullTokenKindName = "newline"
    If Kind = 10 Then FullTokenKindName = "comment"
    If Kind = 11 Then FullTokenKindName = "spacing"
    If Kind = 12 Then FullTokenKindName = "continuation"
    If Kind = 13 Then FullTokenKindName = "eof"
End Function

Function LexicalHexDigit(ByVal DigitValue As Long) As String
    If DigitValue < 10 Then
        LexicalHexDigit = CompilerTextFromByte(48 + DigitValue)
    Else
        LexicalHexDigit = CompilerTextFromByte(55 + DigitValue)
    End If
End Function

Function EncodeLexicalHex(ByVal Value As String) As String
    Dim Result As String = ""
    Dim Index As Long = 0
    While Index < CompilerTextLength(Value)
        Dim Current As Long = CompilerTextByteAt(Value, Index)
        Result = Result & LexicalHexDigit(Current \ 16) & LexicalHexDigit(Current Mod 16)
        Index = Index + 1
    Wend
    EncodeLexicalHex = Result
End Function

Function IsFullLexerKeyword(ByVal Value As String) As Long
    Dim Words As String = "Access|AddressOf|Alias|And|AndAlso|Any|Append|As|Asm|Attribute|Base|Binary|Boolean|ByRef|Byte|Bytecode|ByVal|Call|CallNew|Case|ChDir|ChDrive|Close|Compare|Const|Currency|Database|Date|Decimal|Declare|Default|DefBool|DefByte|DefCur|DefDate|DefDbl|DefInt|DefLng|DefObj|DefSng|DefStr|DefVar|Dim|Do|Double|Each|Else|ElseIf|Empty|End|Enum|Eqv|Erase|Error|Event|Exit|Explicit|Export|False|FileCopy|For|ForceInline|Friend|Function|Get|Global|GoSub|GoTo|If|Imp|Implements|In|Inline|Input|Integer|Interface|IntPtr|Intrinsic|Is|IsNot|Kill|Len|Let|Lib|Like|Line|Load|Lock|Long|LongLong|Loop|LSet|Me|Mid|MkDir|Mod|Name|New|Next|Not|Nothing|Null|Object|Off|On|Open|Option|Optional|Or|OrElse|Output|ParamArray|Preserve|Print|Private|Property|Public|Put|RaiseEvent|Random|Read|ReDim|Reference|Rem|Resume|Return|RmDir|RSet|SavePicture|Seek|Select|Set|Shared|Single|Spc|Static|Step|Stop|String|Sub|SyncLock|Tab|Text|Then|To|True|Type|TypeOf|UIntPtr|Unload|Unlock|Until|Variable|Variant|Wend|While|Width|With|WithEvents|Write|Xor|"
    Dim Cursor As Long = 0
    While Cursor < CompilerTextLength(Words)
        Dim EndOffset As Long = Cursor
        While EndOffset < CompilerTextLength(Words) And CompilerTextByteAt(Words, EndOffset) <> 124
            EndOffset = EndOffset + 1
        Wend
        Dim Word As String = ""
        Call CompilerTextSlice(Words, Cursor, EndOffset - Cursor, Word)
        If CompilerAsciiEqualsFolded(Value, Word) <> 0 Then IsFullLexerKeyword = 1: Exit Function
        Cursor = EndOffset + 1
    Wend
    IsFullLexerKeyword = 0
End Function

Function IsLexerPunctuationByte(ByVal Value As Long) As Long
    If Value = 40 Or Value = 41 Or Value = 44 Or Value = 46 Or Value = 58 Or Value = 59 Or Value = 33 Or Value = 64 Or Value = 36 Or Value = 37 Or Value = 43 Or Value = 45 Or Value = 42 Or Value = 47 Or Value = 92 Or Value = 94 Or Value = 38 Or Value = 61 Or Value = 60 Or Value = 62 Then
        IsLexerPunctuationByte = 1
    Else
        IsLexerPunctuationByte = 0
    End If
End Function

Function ParseLexicalFixedDigits(ByVal InputText As String, ByVal StartByte As Long, ByVal Count As Long, ByRef NumberValue As Long) As Long
    If StartByte < 0 Or Count < 1 Or StartByte + Count > CompilerTextLength(InputText) Then ParseLexicalFixedDigits = 0: Exit Function
    NumberValue = 0
    Dim Index As Long = 0
    While Index < Count
        Dim Current As Long = CompilerTextByteAt(InputText, StartByte + Index)
        If Current < 48 Or Current > 57 Then ParseLexicalFixedDigits = 0: Exit Function
        NumberValue = NumberValue * 10 + Current - 48: Index = Index + 1
    Wend
    ParseLexicalFixedDigits = 1
End Function

Function IsLexicalLeapYear(ByVal YearValue As Long) As Long
    If YearValue Mod 400 = 0 Then IsLexicalLeapYear = 1: Exit Function
    If YearValue Mod 100 = 0 Then IsLexicalLeapYear = 0: Exit Function
    If YearValue Mod 4 = 0 Then
        IsLexicalLeapYear = 1
    Else
        IsLexicalLeapYear = 0
    End If
End Function

Function ValidateLexicalDatePart(ByVal InputText As String, ByVal StartByte As Long) As Long
    Dim YearValue As Long = 0
    Dim MonthValue As Long = 0
    Dim DayValue As Long = 0
    If ParseLexicalFixedDigits(InputText, StartByte, 4, YearValue) = 0 Or ParseLexicalFixedDigits(InputText, StartByte + 5, 2, MonthValue) = 0 Or ParseLexicalFixedDigits(InputText, StartByte + 8, 2, DayValue) = 0 Then ValidateLexicalDatePart = 0: Exit Function
    If CompilerTextByteAt(InputText, StartByte + 4) <> 45 Or CompilerTextByteAt(InputText, StartByte + 7) <> 45 Or YearValue < 1 Or YearValue > 9999 Or MonthValue < 1 Or MonthValue > 12 Then ValidateLexicalDatePart = 0: Exit Function
    Dim MaximumDay As Long = 31
    If MonthValue = 4 Or MonthValue = 6 Or MonthValue = 9 Or MonthValue = 11 Then MaximumDay = 30
    If MonthValue = 2 Then
        MaximumDay = 28
        If IsLexicalLeapYear(YearValue) <> 0 Then MaximumDay = 29
    End If
    If DayValue < 1 Or DayValue > MaximumDay Then
        ValidateLexicalDatePart = 0
    Else
        ValidateLexicalDatePart = 1
    End If
End Function

Function ValidateLexicalTimePart(ByVal InputText As String, ByVal StartByte As Long, ByVal PartLength As Long) As Long
    If PartLength < 5 Then ValidateLexicalTimePart = 0: Exit Function
    Dim HourValue As Long = 0
    Dim MinuteValue As Long = 0
    If ParseLexicalFixedDigits(InputText, StartByte, 2, HourValue) = 0 Or ParseLexicalFixedDigits(InputText, StartByte + 3, 2, MinuteValue) = 0 Then ValidateLexicalTimePart = 0: Exit Function
    If CompilerTextByteAt(InputText, StartByte + 2) <> 58 Or HourValue > 23 Or MinuteValue > 59 Then ValidateLexicalTimePart = 0: Exit Function
    If PartLength = 5 Then ValidateLexicalTimePart = 1: Exit Function
    If PartLength < 8 Or CompilerTextByteAt(InputText, StartByte + 5) <> 58 Then ValidateLexicalTimePart = 0: Exit Function
    Dim SecondValue As Long = 0
    If ParseLexicalFixedDigits(InputText, StartByte + 6, 2, SecondValue) = 0 Or SecondValue > 59 Then ValidateLexicalTimePart = 0: Exit Function
    If PartLength = 8 Then ValidateLexicalTimePart = 1: Exit Function
    If CompilerTextByteAt(InputText, StartByte + 8) <> 46 Or PartLength < 10 Or PartLength > 18 Then ValidateLexicalTimePart = 0: Exit Function
    Dim FractionIndex As Long = StartByte + 9
    While FractionIndex < StartByte + PartLength
        If CompilerTextByteAt(InputText, FractionIndex) < 48 Or CompilerTextByteAt(InputText, FractionIndex) > 57 Then ValidateLexicalTimePart = 0: Exit Function
        FractionIndex = FractionIndex + 1
    Wend
    ValidateLexicalTimePart = 1
End Function

Function ValidateInvariantDateLiteral(ByVal InputText As String) As Long
    Dim InputLength As Long = CompilerTextLength(InputText)
    If InputLength >= 10 And CompilerTextByteAt(InputText, 4) = 45 Then
        If InputLength = 10 Then ValidateInvariantDateLiteral = ValidateLexicalDatePart(InputText, 0): Exit Function
        If InputLength < 16 Or InputLength > 29 Or ValidateLexicalDatePart(InputText, 0) = 0 Then ValidateInvariantDateLiteral = 0: Exit Function
        If CompilerTextByteAt(InputText, 10) <> 84 And CompilerTextByteAt(InputText, 10) <> 32 Then ValidateInvariantDateLiteral = 0: Exit Function
        ValidateInvariantDateLiteral = ValidateLexicalTimePart(InputText, 11, InputLength - 11): Exit Function
    End If
    If InputLength >= 5 And InputLength <= 18 Then ValidateInvariantDateLiteral = ValidateLexicalTimePart(InputText, 0, InputLength): Exit Function
    ValidateInvariantDateLiteral = 0
End Function

Function AppendFullToken(ByRef Tokens() As FullLexicalToken, ByRef Count As Long, ByRef Capacity As Long, ByVal MaximumCount As Long, ByVal Kind As Long, ByVal SourceId As Long, ByVal StartByte As Long, ByVal ByteLength As Long, ByVal LineNumber As Long, ByVal ColumnNumber As Long, ByVal Spelling As String, ByVal Decoded As String) As Long
    If Count >= MaximumCount Then AppendFullToken = 0: Exit Function
    If Count = Capacity Then
        Dim NewCapacity As Long = 256
        If Capacity > 0 Then NewCapacity = Capacity * 2
        If NewCapacity > MaximumCount Then NewCapacity = MaximumCount
        If Capacity = 0 Then
            ReDim Tokens(NewCapacity - 1)
        Else
            ReDim Preserve Tokens(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Tokens(Count).TokenKind = Kind: Tokens(Count).SourceId = SourceId: Tokens(Count).StartByte = StartByte
    Tokens(Count).ByteLength = ByteLength: Tokens(Count).LineNumber = LineNumber: Tokens(Count).ColumnNumber = ColumnNumber
    Tokens(Count).Spelling = Spelling: Tokens(Count).Decoded = Decoded: Count = Count + 1
    AppendFullToken = 1
End Function

Sub AdvanceLexicalLocation(ByVal InputText As String, ByVal StartByte As Long, ByVal EndByte As Long, ByRef LineNumber As Long, ByRef ColumnNumber As Long)
    Dim Cursor As Long = StartByte
    While Cursor < EndByte
        Dim Value As Long = CompilerTextByteAt(InputText, Cursor)
        If Value = 10 Then
            LineNumber = LineNumber + 1: ColumnNumber = 1: Cursor = Cursor + 1
        Else
            If Value = 13 Then
                Cursor = Cursor + 1
            Else
                Dim CodePoint As Long = 0
                Dim ByteCount As Long = 1
                If Value >= 128 Then Call DecodeCompilerUtf8(InputText, Cursor, CodePoint, ByteCount)
                ColumnNumber = ColumnNumber + 1: Cursor = Cursor + ByteCount
            End If
        End If
    Wend
End Sub

Function FindContinuationEnd(ByVal InputText As String, ByVal StartByte As Long) As Long
    If CompilerTextByteAt(InputText, StartByte) <> 95 Then FindContinuationEnd = 0: Exit Function
    Dim Cursor As Long = StartByte + 1
    While Cursor < CompilerTextLength(InputText) And (CompilerTextByteAt(InputText, Cursor) = 32 Or CompilerTextByteAt(InputText, Cursor) = 9)
        Cursor = Cursor + 1
    Wend
    If Cursor < CompilerTextLength(InputText) And CompilerTextByteAt(InputText, Cursor) = 39 Then
        While Cursor < CompilerTextLength(InputText) And CompilerTextByteAt(InputText, Cursor) <> 10
            Cursor = Cursor + 1
        Wend
    End If
    If Cursor >= CompilerTextLength(InputText) Or CompilerTextByteAt(InputText, Cursor) <> 10 Then FindContinuationEnd = 0: Exit Function
    Cursor = Cursor + 1
    While Cursor < CompilerTextLength(InputText) And (CompilerTextByteAt(InputText, Cursor) = 32 Or CompilerTextByteAt(InputText, Cursor) = 9)
        Cursor = Cursor + 1
    Wend
    FindContinuationEnd = Cursor
End Function

Function RunFullLexerForSource(ByVal Session As BuildSession, ByRef Source As ImmutableSourceSnapshot, ByRef Preprocessed As PreprocessedSource, ByRef Tokens() As FullLexicalToken, ByRef TokenCount As Long, ByRef TokenCapacity As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim InputText As String = Preprocessed.ProcessedText
    Dim Cursor As Long = 0
    Dim LineNumber As Long = 1
    Dim ColumnNumber As Long = 1
    Dim StatementStart As Long = 1
    If CompilerTextLength(InputText) >= 3 And CompilerTextByteAt(InputText, 0) = 239 And CompilerTextByteAt(InputText, 1) = 187 And CompilerTextByteAt(InputText, 2) = 191 Then Cursor = 3
    While Cursor < CompilerTextLength(InputText)
        Dim StartByte As Long = Cursor
        Dim StartLine As Long = LineNumber
        Dim StartColumn As Long = ColumnNumber
        Dim Value As Long = CompilerTextByteAt(InputText, Cursor)
        Dim Kind As Long = 0
        Dim Decoded As String = ""
        If Value = 32 Or Value = 9 Then
            Cursor = Cursor + 1
            While Cursor < CompilerTextLength(InputText) And (CompilerTextByteAt(InputText, Cursor) = 32 Or CompilerTextByteAt(InputText, Cursor) = 9)
                Cursor = Cursor + 1
            Wend
            Kind = 11
        Else
            If Value = 10 Or Value = 13 Then
                If Value = 13 Then Cursor = Cursor + 1
                Cursor = Cursor + 1: Kind = 9: StatementStart = 1
            Else
                Dim ContinuationEnd As Long = FindContinuationEnd(InputText, Cursor)
                If ContinuationEnd > 0 Then
                    Cursor = ContinuationEnd: Kind = 12
                Else
                    If Value = 39 Then
                        Cursor = Cursor + 1
                        While Cursor < CompilerTextLength(InputText) And CompilerTextByteAt(InputText, Cursor) <> 10 And CompilerTextByteAt(InputText, Cursor) <> 13
                            Cursor = Cursor + 1
                        Wend
                        Kind = 10
                        Call CompilerTextSlice(InputText, StartByte + 1, Cursor - StartByte - 1, Decoded)
                    Else
                        If Value = 34 Then
                            Cursor = Cursor + 1
                            While Cursor < CompilerTextLength(InputText)
                                Value = CompilerTextByteAt(InputText, Cursor)
                                If Value = 34 Then
                                    If Cursor + 1 < CompilerTextLength(InputText) And CompilerTextByteAt(InputText, Cursor + 1) = 34 Then
                                        Decoded = Decoded & CompilerTextFromByte(34): Cursor = Cursor + 2
                                    Else
                                        Cursor = Cursor + 1: Exit While
                                    End If
                                Else
                                    If Value = 10 Or Value = 13 Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3402", Source.FilePath, "unterminated string literal"): RunFullLexerForSource = 0: Exit Function
                                    Dim CharBytes As Long = 1
                                    Dim CodePoint As Long = 0
                                    If Value >= 128 Then Call DecodeCompilerUtf8(InputText, Cursor, CodePoint, CharBytes)
                                    Dim Fragment As String = ""
                                    Call CompilerTextSlice(InputText, Cursor, CharBytes, Fragment)
                                    Decoded = Decoded & Fragment: Cursor = Cursor + CharBytes
                                End If
                            Wend
                            If Cursor > CompilerTextLength(InputText) Or CompilerTextByteAt(InputText, Cursor - 1) <> 34 Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3402", Source.FilePath, "unterminated string literal"): RunFullLexerForSource = 0: Exit Function
                            Kind = 6
                        Else
                            If Value = 91 Then
                                Cursor = Cursor + 1
                                While Cursor < CompilerTextLength(InputText)
                                    Value = CompilerTextByteAt(InputText, Cursor)
                                    If Value = 93 Then
                                        If Cursor + 1 < CompilerTextLength(InputText) And CompilerTextByteAt(InputText, Cursor + 1) = 93 Then
                                            Decoded = Decoded & "]": Cursor = Cursor + 2
                                        Else
                                            Cursor = Cursor + 1: Exit While
                                        End If
                                    Else
                                        If Value = 10 Or Value = 13 Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3403", Source.FilePath, "unterminated bracketed identifier"): RunFullLexerForSource = 0: Exit Function
                                        Dim BracketBytes As Long = 1
                                        Dim BracketPoint As Long = 0
                                        If Value >= 128 Then Call DecodeCompilerUtf8(InputText, Cursor, BracketPoint, BracketBytes)
                                        Dim BracketFragment As String = ""
                                        Call CompilerTextSlice(InputText, Cursor, BracketBytes, BracketFragment)
                                        Decoded = Decoded & BracketFragment: Cursor = Cursor + BracketBytes
                                    End If
                                Wend
                                If Decoded = "" Or CompilerTextByteAt(InputText, Cursor - 1) <> 93 Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3403", Source.FilePath, "empty or unterminated bracketed identifier"): RunFullLexerForSource = 0: Exit Function
                                Kind = 3
                            Else
                                If Value = 35 Then
                                    Cursor = Cursor + 1
                                    While Cursor < CompilerTextLength(InputText) And CompilerTextByteAt(InputText, Cursor) <> 35 And CompilerTextByteAt(InputText, Cursor) <> 10 And CompilerTextByteAt(InputText, Cursor) <> 13
                                        Cursor = Cursor + 1
                                    Wend
                                    If Cursor >= CompilerTextLength(InputText) Or CompilerTextByteAt(InputText, Cursor) <> 35 Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3404", Source.FilePath, "unterminated date literal"): RunFullLexerForSource = 0: Exit Function
                                    Call CompilerTextSlice(InputText, StartByte + 1, Cursor - StartByte - 1, Decoded)
                                    If ValidateInvariantDateLiteral(Decoded) = 0 Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3407", Source.FilePath, "invalid invariant date/time literal"): RunFullLexerForSource = 0: Exit Function
                                    Cursor = Cursor + 1: Kind = 7
                                Else
                                    Dim IdentifierBytes As Long = CompilerIdentifierStartBytes(InputText, Cursor)
                                    If IdentifierBytes > 0 Then
                                        Cursor = Cursor + IdentifierBytes
                                        While Cursor < CompilerTextLength(InputText)
                                            IdentifierBytes = CompilerIdentifierPartBytes(InputText, Cursor)
                                            If IdentifierBytes = 0 Then Exit While
                                            Cursor = Cursor + IdentifierBytes
                                        Wend
                                        Call CompilerTextSlice(InputText, StartByte, Cursor - StartByte, Decoded)
                                        If StatementStart <> 0 And CompilerAsciiEqualsFolded(Decoded, "Rem") <> 0 And Cursor < CompilerTextLength(InputText) And (CompilerTextByteAt(InputText, Cursor) = 32 Or CompilerTextByteAt(InputText, Cursor) = 9 Or CompilerTextByteAt(InputText, Cursor) = 10 Or CompilerTextByteAt(InputText, Cursor) = 13) Then
                                            While Cursor < CompilerTextLength(InputText) And CompilerTextByteAt(InputText, Cursor) <> 10 And CompilerTextByteAt(InputText, Cursor) <> 13
                                                Cursor = Cursor + 1
                                            Wend
                                            Call CompilerTextSlice(InputText, StartByte + 3, Cursor - StartByte - 3, Decoded): Kind = 10
                                        Else
                                            If IsFullLexerKeyword(Decoded) <> 0 Then
                                                Kind = 1
                                            Else
                                                Kind = 2
                                            End If
                                        End If
                                    Else
                                        Dim IsNumber As Long = 0
                                        If Value >= 48 And Value <= 57 Then IsNumber = 1
                                        If Value = 38 And Cursor + 2 < CompilerTextLength(InputText) And (CompilerTextByteAt(InputText, Cursor + 1) = 72 Or CompilerTextByteAt(InputText, Cursor + 1) = 104 Or CompilerTextByteAt(InputText, Cursor + 1) = 79 Or CompilerTextByteAt(InputText, Cursor + 1) = 111) Then IsNumber = 1
                                        If IsNumber <> 0 Then
                                            Dim RealNumber As Long = 0
                                            If Value = 38 Then
                                                Dim BaseMarker As Long = CompilerTextByteAt(InputText, Cursor + 1)
                                                Cursor = Cursor + 2
                                                Dim BaseDigitStart As Long = Cursor
                                                If BaseMarker = 72 Or BaseMarker = 104 Then
                                                    While Cursor < CompilerTextLength(InputText) And ((CompilerTextByteAt(InputText, Cursor) >= 48 And CompilerTextByteAt(InputText, Cursor) <= 57) Or (CompilerTextByteAt(InputText, Cursor) >= 65 And CompilerTextByteAt(InputText, Cursor) <= 70) Or (CompilerTextByteAt(InputText, Cursor) >= 97 And CompilerTextByteAt(InputText, Cursor) <= 102))
                                                        Cursor = Cursor + 1
                                                    Wend
                                                Else
                                                    While Cursor < CompilerTextLength(InputText) And CompilerTextByteAt(InputText, Cursor) >= 48 And CompilerTextByteAt(InputText, Cursor) <= 55
                                                        Cursor = Cursor + 1
                                                    Wend
                                                End If
                                                If Cursor = BaseDigitStart Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3403", Source.FilePath, "base-prefixed integer requires digits"): RunFullLexerForSource = 0: Exit Function
                                            Else
                                                While Cursor < CompilerTextLength(InputText) And CompilerTextByteAt(InputText, Cursor) >= 48 And CompilerTextByteAt(InputText, Cursor) <= 57
                                                    Cursor = Cursor + 1
                                                Wend
                                                If Cursor < CompilerTextLength(InputText) And CompilerTextByteAt(InputText, Cursor) = 46 Then
                                                    RealNumber = 1: Cursor = Cursor + 1
                                                    While Cursor < CompilerTextLength(InputText) And CompilerTextByteAt(InputText, Cursor) >= 48 And CompilerTextByteAt(InputText, Cursor) <= 57
                                                        Cursor = Cursor + 1
                                                    Wend
                                                End If
                                                If Cursor < CompilerTextLength(InputText) And (CompilerTextByteAt(InputText, Cursor) = 69 Or CompilerTextByteAt(InputText, Cursor) = 101) Then
                                                    RealNumber = 1: Cursor = Cursor + 1
                                                    If Cursor < CompilerTextLength(InputText) And (CompilerTextByteAt(InputText, Cursor) = 43 Or CompilerTextByteAt(InputText, Cursor) = 45) Then Cursor = Cursor + 1
                                                    Dim ExponentDigits As Long = Cursor
                                                    While Cursor < CompilerTextLength(InputText) And CompilerTextByteAt(InputText, Cursor) >= 48 And CompilerTextByteAt(InputText, Cursor) <= 57
                                                        Cursor = Cursor + 1
                                                    Wend
                                                    If Cursor = ExponentDigits Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3404", Source.FilePath, "real exponent requires decimal digits"): RunFullLexerForSource = 0: Exit Function
                                                End If
                                            End If
                                            If Cursor < CompilerTextLength(InputText) Then
                                                Value = CompilerTextByteAt(InputText, Cursor)
                                                If RealNumber <> 0 And (Value = 33 Or Value = 35 Or Value = 64 Or Value = 70 Or Value = 102 Or Value = 82 Or Value = 114 Or Value = 68 Or Value = 100) Then
                                                    RealNumber = 1: Cursor = Cursor + 1
                                                Else
                                                    If RealNumber = 0 And (Value = 37 Or Value = 38 Or Value = 94) Then Cursor = Cursor + 1
                                                End If
                                            End If
                                            Call CompilerTextSlice(InputText, StartByte, Cursor - StartByte, Decoded)
                                            If RealNumber <> 0 Then
                                                Kind = 5
                                            Else
                                                Kind = 4
                                            End If
                                        Else
                                            If Value < 32 Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3409", Source.FilePath, "invalid control character"): RunFullLexerForSource = 0: Exit Function
                                            If IsLexerPunctuationByte(Value) = 0 Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3410", Source.FilePath, "unrecognized source character"): RunFullLexerForSource = 0: Exit Function
                                            Cursor = Cursor + 1
                                            If Cursor < CompilerTextLength(InputText) And ((Value = 60 And (CompilerTextByteAt(InputText, Cursor) = 61 Or CompilerTextByteAt(InputText, Cursor) = 62)) Or (Value = 62 And CompilerTextByteAt(InputText, Cursor) = 61) Or (Value = 58 And CompilerTextByteAt(InputText, Cursor) = 61)) Then Cursor = Cursor + 1
                                            Kind = 8
                                            Call CompilerTextSlice(InputText, StartByte, Cursor - StartByte, Decoded)
                                        End If
                                    End If
                                End If
                            End If
                        End If
                    End If
                End If
            End If
        End If
        Dim Spelling As String = ""
        Call CompilerTextSlice(InputText, StartByte, Cursor - StartByte, Spelling)
        If AppendFullToken(Tokens, TokenCount, TokenCapacity, Session.MaximumTokens, Kind, Source.SourceId, StartByte, Cursor - StartByte, StartLine, StartColumn, Spelling, Decoded) = 0 Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3405", Source.FilePath, "token limit exceeded"): RunFullLexerForSource = 0: Exit Function
        Call AdvanceLexicalLocation(InputText, StartByte, Cursor, LineNumber, ColumnNumber)
        If Kind <> 11 And Kind <> 12 Then
            If Kind = 9 Or (Kind = 8 And Decoded = ":") Then
                StatementStart = 1
            Else
                StatementStart = 0
            End If
        End If
    Wend
    If CompilerTextLength(InputText) = 0 Or CompilerTextByteAt(InputText, CompilerTextLength(InputText) - 1) <> 10 Then
        If AppendFullToken(Tokens, TokenCount, TokenCapacity, Session.MaximumTokens, 9, Source.SourceId, CompilerTextLength(InputText), 0, LineNumber, ColumnNumber, "", "") = 0 Then RunFullLexerForSource = 0: Exit Function
        LineNumber = LineNumber + 1: ColumnNumber = 1
    End If
    If AppendFullToken(Tokens, TokenCount, TokenCapacity, Session.MaximumTokens, 13, Source.SourceId, CompilerTextLength(InputText), 0, LineNumber, ColumnNumber, "", "") = 0 Then RunFullLexerForSource = 0: Exit Function
    RunFullLexerForSource = 1
End Function

Function BuildFullTokenDump(ByRef Tokens() As FullLexicalToken, ByVal TokenCount As Long, ByRef Dump As String) As Long
    Dump = "UBE-TOKENS 1"
    Dim Index As Long = 0
    While Index < TokenCount
        Dim TokenLine As String = CompilerTextFromByte(10) & CompilerLongToText(Tokens(Index).SourceId) & ":" & CompilerLongToText(Tokens(Index).StartByte) & ":" & CompilerLongToText(Tokens(Index).ByteLength) & ":" & CompilerLongToText(Tokens(Index).LineNumber) & ":" & CompilerLongToText(Tokens(Index).ColumnNumber) & "|" & FullTokenKindName(Tokens(Index).TokenKind) & "|" & EncodeLexicalHex(Tokens(Index).Spelling) & "|" & EncodeLexicalHex(Tokens(Index).Decoded)
        If AppendBoundedText(Dump, TokenLine, 268435456) = 0 Then BuildFullTokenDump = 0: Exit Function
        Index = Index + 1
    Wend
    BuildFullTokenDump = 1
End Function
