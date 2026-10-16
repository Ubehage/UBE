UBE SOURCE 1 MODULE
Attribute UBE_Name = "Lexer"

Type LexicalToken
    TokenKind As Long
    SourceId As Long
    StartByte As Long
    ByteLength As Long
    LineNumber As Long
    ColumnNumber As Long
    Spelling As String
    Decoded As String
End Type

Function AppendLexicalToken(ByRef Tokens() As LexicalToken, ByRef Count As Long, ByRef Capacity As Long, ByVal Kind As Long, ByRef Source As SourceDocument, ByVal StartByte As Long, ByVal ByteLength As Long, ByVal Spelling As String, ByVal Decoded As String) As Long
    If Count >= LimitTokenCount() Then
        AppendLexicalToken = 0
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = 512
        If Capacity > 0 Then
            NewCapacity = Capacity * 2
        End If
        If NewCapacity > LimitTokenCount() Then
            NewCapacity = LimitTokenCount()
        End If
        If Capacity = 0 Then
            ReDim Tokens(NewCapacity - 1)
        Else
            ReDim Preserve Tokens(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    If StartByte < Source.LocationByte Then
        Source.LocationByte = 0
        Source.LocationLine = 1
        Source.LocationColumn = 1
    End If
    While Source.LocationByte < StartByte
        Dim LocationCurrentByte As Long = StringByteAt(Source.Contents, Source.LocationByte)
        If LocationCurrentByte = 10 Then
            Source.LocationLine = Source.LocationLine + 1
            Source.LocationColumn = 1
        Else
            If LocationCurrentByte <> 13 Then
                Source.LocationColumn = Source.LocationColumn + 1
            End If
        End If
        Dim LocationCharacterBytes As Long = 1
        If LocationCurrentByte >= 128 Then
            LocationCharacterBytes = Utf8SequenceLength(Source.Contents, Source.LocationByte, Source.ByteLength)
            If LocationCharacterBytes < 1 Then
                LocationCharacterBytes = 1
            End If
        End If
        Source.LocationByte = Source.LocationByte + LocationCharacterBytes
    Wend
    Tokens(Count).TokenKind = Kind
    Tokens(Count).SourceId = Source.SourceId
    Tokens(Count).StartByte = StartByte
    Tokens(Count).ByteLength = ByteLength
    Tokens(Count).LineNumber = Source.LocationLine
    Tokens(Count).ColumnNumber = Source.LocationColumn
    Tokens(Count).Spelling = Spelling
    Tokens(Count).Decoded = Decoded
    Count = Count + 1
    AppendLexicalToken = 1
End Function

Sub AddLexicalDiagnostic(ByRef Source As SourceDocument, ByVal StartByte As Long, ByVal Code As String, ByVal Message As String, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long)
    Dim LineNumber As Long = 1
    Dim ColumnNumber As Long = 1
    Call FindLineAndColumn(Source.Contents, StartByte, LineNumber, ColumnNumber)
    Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Code, Source.FilePath, LineNumber, ColumnNumber, Message)
End Sub

Function IsAsciiDigit(ByVal Value As Long) As Long
    If Value >= 48 And Value <= 57 Then
        IsAsciiDigit = 1
    Else
        IsAsciiDigit = 0
    End If
End Function

Function IsHexDigit(ByVal Value As Long) As Long
    If IsAsciiDigit(Value) <> 0 Or Value >= 65 And Value <= 70 Or Value >= 97 And Value <= 102 Then
        IsHexDigit = 1
    Else
        IsHexDigit = 0
    End If
End Function

Function IsOctalDigit(ByVal Value As Long) As Long
    If Value >= 48 And Value <= 55 Then
        IsOctalDigit = 1
    Else
        IsOctalDigit = 0
    End If
End Function

Function IdentifierStartBytes(ByVal Text As String, ByVal StartByte As Long, ByVal Length As Long) As Long
    Dim CurrentByte As Long = StringByteAt(Text, StartByte)
    If CurrentByte = 95 Then
        IdentifierStartBytes = 1
        Exit Function
    End If
    Dim CodePoint As Long = 0
    Dim ByteCount As Long = 0
    If DecodeUtf8CodePoint(Text, StartByte, CodePoint, ByteCount) = 0 Then
        IdentifierStartBytes = 0
        Exit Function
    End If
    If UnicodeIsLetter(CodePoint) <> 0 Then
        IdentifierStartBytes = ByteCount
    Else
        IdentifierStartBytes = 0
    End If
End Function

Function IdentifierPartBytes(ByVal Text As String, ByVal StartByte As Long, ByVal Length As Long) As Long
    Dim CurrentByte As Long = StringByteAt(Text, StartByte)
    If IsAsciiDigit(CurrentByte) <> 0 Then
        IdentifierPartBytes = 1
    Else
        IdentifierPartBytes = IdentifierStartBytes(Text, StartByte, Length)
    End If
End Function

Function IsHardKeyword(ByVal Value As String) As Long
    IsHardKeyword = 0
    If EqualsFolded(Value, "Access") <> 0 Or EqualsFolded(Value, "AddressOf") <> 0 Or EqualsFolded(Value, "Alias") <> 0 Or EqualsFolded(Value, "And") <> 0 Or EqualsFolded(Value, "AndAlso") <> 0 Or EqualsFolded(Value, "Any") <> 0 Or EqualsFolded(Value, "Append") <> 0 Or EqualsFolded(Value, "As") <> 0 Or EqualsFolded(Value, "Asm") <> 0 Or EqualsFolded(Value, "Attribute") <> 0 Then
        IsHardKeyword = 1
    End If
    If EqualsFolded(Value, "Base") <> 0 Or EqualsFolded(Value, "Binary") <> 0 Or EqualsFolded(Value, "Boolean") <> 0 Or EqualsFolded(Value, "ByRef") <> 0 Or EqualsFolded(Value, "Byte") <> 0 Or EqualsFolded(Value, "Bytecode") <> 0 Or EqualsFolded(Value, "ByVal") <> 0 Then
        IsHardKeyword = 1
    End If
    If EqualsFolded(Value, "Call") <> 0 Or EqualsFolded(Value, "CallNew") <> 0 Or EqualsFolded(Value, "Case") <> 0 Or EqualsFolded(Value, "ChDir") <> 0 Or EqualsFolded(Value, "ChDrive") <> 0 Or EqualsFolded(Value, "Close") <> 0 Or EqualsFolded(Value, "Compare") <> 0 Or EqualsFolded(Value, "Const") <> 0 Or EqualsFolded(Value, "Currency") <> 0 Then
        IsHardKeyword = 1
    End If
    If EqualsFolded(Value, "Database") <> 0 Or EqualsFolded(Value, "Date") <> 0 Or EqualsFolded(Value, "Decimal") <> 0 Or EqualsFolded(Value, "Declare") <> 0 Or EqualsFolded(Value, "Default") <> 0 Or EqualsFolded(Value, "DefBool") <> 0 Or EqualsFolded(Value, "DefByte") <> 0 Or EqualsFolded(Value, "DefCur") <> 0 Or EqualsFolded(Value, "DefDate") <> 0 Or EqualsFolded(Value, "DefDbl") <> 0 Or EqualsFolded(Value, "DefInt") <> 0 Or EqualsFolded(Value, "DefLng") <> 0 Or EqualsFolded(Value, "DefObj") <> 0 Or EqualsFolded(Value, "DefSng") <> 0 Or EqualsFolded(Value, "DefStr") <> 0 Or EqualsFolded(Value, "DefVar") <> 0 Or EqualsFolded(Value, "Dim") <> 0 Or EqualsFolded(Value, "Do") <> 0 Or EqualsFolded(Value, "Double") <> 0 Then
        IsHardKeyword = 1
    End If
    If EqualsFolded(Value, "Each") <> 0 Or EqualsFolded(Value, "Else") <> 0 Or EqualsFolded(Value, "ElseIf") <> 0 Or EqualsFolded(Value, "Empty") <> 0 Or EqualsFolded(Value, "End") <> 0 Or EqualsFolded(Value, "Enum") <> 0 Or EqualsFolded(Value, "Eqv") <> 0 Or EqualsFolded(Value, "Erase") <> 0 Or EqualsFolded(Value, "Error") <> 0 Or EqualsFolded(Value, "Event") <> 0 Or EqualsFolded(Value, "Exit") <> 0 Or EqualsFolded(Value, "Explicit") <> 0 Or EqualsFolded(Value, "Export") <> 0 Then
        IsHardKeyword = 1
    End If
    If EqualsFolded(Value, "False") <> 0 Or EqualsFolded(Value, "FileCopy") <> 0 Or EqualsFolded(Value, "For") <> 0 Or EqualsFolded(Value, "ForceInline") <> 0 Or EqualsFolded(Value, "Friend") <> 0 Or EqualsFolded(Value, "Function") <> 0 Then
        IsHardKeyword = 1
    End If
    If EqualsFolded(Value, "Get") <> 0 Or EqualsFolded(Value, "Global") <> 0 Or EqualsFolded(Value, "GoSub") <> 0 Or EqualsFolded(Value, "GoTo") <> 0 Then
        IsHardKeyword = 1
    End If
    If EqualsFolded(Value, "If") <> 0 Or EqualsFolded(Value, "Imp") <> 0 Or EqualsFolded(Value, "Implements") <> 0 Or EqualsFolded(Value, "In") <> 0 Or EqualsFolded(Value, "Inline") <> 0 Or EqualsFolded(Value, "Input") <> 0 Or EqualsFolded(Value, "Integer") <> 0 Or EqualsFolded(Value, "Interface") <> 0 Or EqualsFolded(Value, "IntPtr") <> 0 Or EqualsFolded(Value, "Intrinsic") <> 0 Or EqualsFolded(Value, "Is") <> 0 Or EqualsFolded(Value, "IsNot") <> 0 Then
        IsHardKeyword = 1
    End If
    If EqualsFolded(Value, "Kill") <> 0 Or EqualsFolded(Value, "Len") <> 0 Or EqualsFolded(Value, "Let") <> 0 Or EqualsFolded(Value, "Lib") <> 0 Or EqualsFolded(Value, "Like") <> 0 Or EqualsFolded(Value, "Line") <> 0 Or EqualsFolded(Value, "Load") <> 0 Or EqualsFolded(Value, "Lock") <> 0 Or EqualsFolded(Value, "Long") <> 0 Or EqualsFolded(Value, "LongLong") <> 0 Or EqualsFolded(Value, "Loop") <> 0 Or EqualsFolded(Value, "LSet") <> 0 Then
        IsHardKeyword = 1
    End If
    If EqualsFolded(Value, "Me") <> 0 Or EqualsFolded(Value, "Mid") <> 0 Or EqualsFolded(Value, "MkDir") <> 0 Or EqualsFolded(Value, "Mod") <> 0 Then
        IsHardKeyword = 1
    End If
    If EqualsFolded(Value, "Name") <> 0 Or EqualsFolded(Value, "New") <> 0 Or EqualsFolded(Value, "Next") <> 0 Or EqualsFolded(Value, "Not") <> 0 Or EqualsFolded(Value, "Nothing") <> 0 Or EqualsFolded(Value, "Null") <> 0 Then
        IsHardKeyword = 1
    End If
    If EqualsFolded(Value, "Object") <> 0 Or EqualsFolded(Value, "Off") <> 0 Or EqualsFolded(Value, "On") <> 0 Or EqualsFolded(Value, "Open") <> 0 Or EqualsFolded(Value, "Option") <> 0 Or EqualsFolded(Value, "Optional") <> 0 Or EqualsFolded(Value, "Or") <> 0 Or EqualsFolded(Value, "OrElse") <> 0 Or EqualsFolded(Value, "Output") <> 0 Then
        IsHardKeyword = 1
    End If
    If EqualsFolded(Value, "ParamArray") <> 0 Or EqualsFolded(Value, "Preserve") <> 0 Or EqualsFolded(Value, "Print") <> 0 Or EqualsFolded(Value, "Private") <> 0 Or EqualsFolded(Value, "Property") <> 0 Or EqualsFolded(Value, "Public") <> 0 Or EqualsFolded(Value, "Put") <> 0 Then
        IsHardKeyword = 1
    End If
    If EqualsFolded(Value, "RaiseEvent") <> 0 Or EqualsFolded(Value, "Random") <> 0 Or EqualsFolded(Value, "Read") <> 0 Or EqualsFolded(Value, "ReDim") <> 0 Or EqualsFolded(Value, "Reference") <> 0 Or EqualsFolded(Value, "Rem") <> 0 Or EqualsFolded(Value, "Resume") <> 0 Or EqualsFolded(Value, "Return") <> 0 Or EqualsFolded(Value, "RmDir") <> 0 Or EqualsFolded(Value, "RSet") <> 0 Then
        IsHardKeyword = 1
    End If
    If EqualsFolded(Value, "SavePicture") <> 0 Or EqualsFolded(Value, "Seek") <> 0 Or EqualsFolded(Value, "Select") <> 0 Or EqualsFolded(Value, "Set") <> 0 Or EqualsFolded(Value, "Shared") <> 0 Or EqualsFolded(Value, "Single") <> 0 Or EqualsFolded(Value, "Spc") <> 0 Or EqualsFolded(Value, "Static") <> 0 Or EqualsFolded(Value, "Step") <> 0 Or EqualsFolded(Value, "Stop") <> 0 Or EqualsFolded(Value, "String") <> 0 Or EqualsFolded(Value, "Sub") <> 0 Or EqualsFolded(Value, "SyncLock") <> 0 Then
        IsHardKeyword = 1
    End If
    If EqualsFolded(Value, "Tab") <> 0 Or EqualsFolded(Value, "Text") <> 0 Or EqualsFolded(Value, "Then") <> 0 Or EqualsFolded(Value, "To") <> 0 Or EqualsFolded(Value, "True") <> 0 Or EqualsFolded(Value, "Type") <> 0 Or EqualsFolded(Value, "TypeOf") <> 0 Then
        IsHardKeyword = 1
    End If
    If EqualsFolded(Value, "UIntPtr") <> 0 Or EqualsFolded(Value, "Unload") <> 0 Or EqualsFolded(Value, "Unlock") <> 0 Or EqualsFolded(Value, "Until") <> 0 Then
        IsHardKeyword = 1
    End If
    If EqualsFolded(Value, "Variable") <> 0 Or EqualsFolded(Value, "Variant") <> 0 Or EqualsFolded(Value, "Wend") <> 0 Or EqualsFolded(Value, "While") <> 0 Or EqualsFolded(Value, "Width") <> 0 Or EqualsFolded(Value, "With") <> 0 Or EqualsFolded(Value, "WithEvents") <> 0 Or EqualsFolded(Value, "Write") <> 0 Or EqualsFolded(Value, "Xor") <> 0 Then
        IsHardKeyword = 1
    End If
End Function

Function IsLeapYear(ByVal YearValue As Long) As Long
    If YearValue Mod 400 = 0 Then
        IsLeapYear = 1
    Else
        If YearValue Mod 100 = 0 Then
            IsLeapYear = 0
        Else
            If YearValue Mod 4 = 0 Then
                IsLeapYear = 1
            Else
                IsLeapYear = 0
            End If
        End If
    End If
End Function

Function ParseFixedDigits(ByVal Text As String, ByVal StartByte As Long, ByVal Count As Long, ByRef Value As Long) As Long
    If StartByte + Count > StringLength(Text) Then
        ParseFixedDigits = 0
        Exit Function
    End If
    Value = 0
    Dim Index As Long = 0
    While Index < Count
        Dim CurrentByte As Long = StringByteAt(Text, StartByte + Index)
        If IsAsciiDigit(CurrentByte) = 0 Then
            ParseFixedDigits = 0
            Exit Function
        End If
        Value = Value * 10 + CurrentByte - 48
        Index = Index + 1
    Wend
    ParseFixedDigits = 1
End Function

Function ValidateDatePart(ByVal Text As String, ByVal StartByte As Long) As Long
    Dim YearValue As Long = 0
    Dim MonthValue As Long = 0
    Dim DayValue As Long = 0
    If ParseFixedDigits(Text, StartByte, 4, YearValue) = 0 Or ParseFixedDigits(Text, StartByte + 5, 2, MonthValue) = 0 Or ParseFixedDigits(Text, StartByte + 8, 2, DayValue) = 0 Then
        ValidateDatePart = 0
        Exit Function
    End If
    If StringByteAt(Text, StartByte + 4) <> 45 Or StringByteAt(Text, StartByte + 7) <> 45 Or YearValue < 1 Or YearValue > 9999 Or MonthValue < 1 Or MonthValue > 12 Then
        ValidateDatePart = 0
        Exit Function
    End If
    Dim MaximumDay As Long = 31
    If MonthValue = 4 Or MonthValue = 6 Or MonthValue = 9 Or MonthValue = 11 Then
        MaximumDay = 30
    Else
        If MonthValue = 2 Then
            MaximumDay = 28
            If IsLeapYear(YearValue) <> 0 Then
                MaximumDay = 29
            End If
        End If
    End If
    If DayValue < 1 Or DayValue > MaximumDay Then
        ValidateDatePart = 0
    Else
        ValidateDatePart = 1
    End If
End Function

Function ValidateTimePart(ByVal Text As String, ByVal StartByte As Long, ByVal Length As Long) As Long
    If Length < 5 Then
        ValidateTimePart = 0
        Exit Function
    End If
    Dim HourValue As Long = 0
    Dim MinuteValue As Long = 0
    If ParseFixedDigits(Text, StartByte, 2, HourValue) = 0 Or ParseFixedDigits(Text, StartByte + 3, 2, MinuteValue) = 0 Then
        ValidateTimePart = 0
        Exit Function
    End If
    If StringByteAt(Text, StartByte + 2) <> 58 Or HourValue > 23 Or MinuteValue > 59 Then
        ValidateTimePart = 0
        Exit Function
    End If
    If Length = 5 Then
        ValidateTimePart = 1
        Exit Function
    End If
    If Length < 8 Or StringByteAt(Text, StartByte + 5) <> 58 Then
        ValidateTimePart = 0
        Exit Function
    End If
    Dim SecondValue As Long = 0
    If ParseFixedDigits(Text, StartByte + 6, 2, SecondValue) = 0 Or SecondValue > 59 Then
        ValidateTimePart = 0
        Exit Function
    End If
    If Length = 8 Then
        ValidateTimePart = 1
        Exit Function
    End If
    If StringByteAt(Text, StartByte + 8) <> 46 Or Length < 10 Or Length > 18 Then
        ValidateTimePart = 0
        Exit Function
    End If
    Dim FractionIndex As Long = StartByte + 9
    While FractionIndex < StartByte + Length
        If IsAsciiDigit(StringByteAt(Text, FractionIndex)) = 0 Then
            ValidateTimePart = 0
            Exit Function
        End If
        FractionIndex = FractionIndex + 1
    Wend
    ValidateTimePart = 1
End Function

Function ValidateInvariantDateText(ByVal Text As String) As Long
    Dim Length As Long = StringLength(Text)
    If Length >= 10 Then
        If StringByteAt(Text, 4) = 45 Then
            If Length = 10 Then
            ValidateInvariantDateText = ValidateDatePart(Text, 0)
                Exit Function
            End If
            If Length < 16 Or Length > 29 Then
                ValidateInvariantDateText = 0
                Exit Function
            End If
            If ValidateDatePart(Text, 0) = 0 Then
                ValidateInvariantDateText = 0
                Exit Function
            End If
            Dim Separator As Long = StringByteAt(Text, 10)
            If Separator <> 84 And Separator <> 32 Then
                ValidateInvariantDateText = 0
                Exit Function
            End If
            ValidateInvariantDateText = ValidateTimePart(Text, 11, Length - 11)
            Exit Function
        End If
    End If
    If Length >= 5 And Length <= 18 Then
        ValidateInvariantDateText = ValidateTimePart(Text, 0, Length)
        Exit Function
    End If
    ValidateInvariantDateText = 0
End Function

Function ContinuationAfter(ByVal Text As String, ByVal UnderscoreByte As Long, ByVal Length As Long) As Long
    Dim Cursor As Long = UnderscoreByte + 1
    While Cursor < Length
        If StringByteAt(Text, Cursor) = 32 Or StringByteAt(Text, Cursor) = 9 Then
            Cursor = Cursor + 1
        Else
            Exit While
        End If
    Wend
    Dim HasContinuationComment As Long = 0
    If Cursor < Length Then
        If StringByteAt(Text, Cursor) = 39 Then
            HasContinuationComment = 1
        End If
    End If
    If HasContinuationComment <> 0 Then
        While Cursor < Length
            If StringByteAt(Text, Cursor) = 10 Or StringByteAt(Text, Cursor) = 13 Then
                Exit While
            End If
            Cursor = Cursor + 1
        Wend
    End If
    If Cursor >= Length Then
        ContinuationAfter = -1
        Exit Function
    End If
    If StringByteAt(Text, Cursor) = 13 Then
        If Cursor + 1 >= Length Then
            ContinuationAfter = -2
            Exit Function
        End If
        If StringByteAt(Text, Cursor + 1) <> 10 Then
            ContinuationAfter = -2
            Exit Function
        End If
        Cursor = Cursor + 2
    Else
        If StringByteAt(Text, Cursor) <> 10 Then
            ContinuationAfter = -1
            Exit Function
        End If
        Cursor = Cursor + 1
    End If
    While Cursor < Length
        If StringByteAt(Text, Cursor) = 32 Or StringByteAt(Text, Cursor) = 9 Then
            Cursor = Cursor + 1
        Else
            Exit While
        End If
    Wend
    ContinuationAfter = Cursor
End Function

Function IsPunctuationByte(ByVal Value As Long) As Long
    If Value = 40 Or Value = 41 Or Value = 44 Or Value = 46 Or Value = 58 Or Value = 59 Or Value = 33 Or Value = 64 Or Value = 36 Or Value = 37 Or Value = 43 Or Value = 45 Or Value = 42 Or Value = 47 Or Value = 92 Or Value = 94 Or Value = 38 Or Value = 61 Or Value = 60 Or Value = 62 Then
        IsPunctuationByte = 1
    Else
        IsPunctuationByte = 0
    End If
End Function

Function LexOneSource(ByRef Source As SourceDocument, ByVal SourceText As String, ByRef Tokens() As LexicalToken, ByRef TokenCount As Long, ByRef TokenCapacity As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim InitialDiagnosticCount As Long = DiagnosticCount
    Dim Length As Long = StringLength(SourceText)
    Dim Index As Long = 0
    If Length >= 3 Then
        If StringByteAt(SourceText, 0) = 239 And StringByteAt(SourceText, 1) = 187 And StringByteAt(SourceText, 2) = 191 Then
            Index = 3
            Source.LocationByte = 3
            Source.LocationLine = 1
            Source.LocationColumn = 1
        End If
    End If
    Dim AtStatementStart As Long = 1
    Dim PreviousWasSpace As Long = 0
    Dim LastWasNewline As Long = 0
    While Index < Length
        If TokenCount >= LimitTokenCount() - 2 Then
            Call AddLexicalDiagnostic(Source, Index, "UBE3400", "token limit exceeded", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Exit While
        End If
        Dim CurrentByte As Long = StringByteAt(SourceText, Index)
        If CurrentByte = 0 Then
            Call AddLexicalDiagnostic(Source, Index, "UBE3401", "source contains a NUL byte", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Index = Index + 1
        Else
            If CurrentByte = 32 Or CurrentByte = 9 Then
                Dim SpaceStart As Long = Index
                While Index < Length
                    If StringByteAt(SourceText, Index) = 32 Or StringByteAt(SourceText, Index) = 9 Then
                        Index = Index + 1
                    Else
                        Exit While
                    End If
                Wend
                Call AppendLexicalToken(Tokens, TokenCount, TokenCapacity, 11, Source, SpaceStart, Index - SpaceStart, StringSlice(SourceText, SpaceStart, Index - SpaceStart), "")
                PreviousWasSpace = 1
                LastWasNewline = 0
            Else
                Dim ContinuedAt As Long = -1
                If CurrentByte = 95 And PreviousWasSpace <> 0 Then
                    ContinuedAt = ContinuationAfter(SourceText, Index, Length)
                End If
                If ContinuedAt = -2 Then
                    Call AddLexicalDiagnostic(Source, Index, "UBE3402", "lone carriage return is not a valid line ending", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    Index = Index + 1
                Else
                    If ContinuedAt >= 0 Then
                        Call AppendLexicalToken(Tokens, TokenCount, TokenCapacity, 12, Source, Index, ContinuedAt - Index, StringSlice(SourceText, Index, ContinuedAt - Index), "")
                        Index = ContinuedAt
                        PreviousWasSpace = 1
                        LastWasNewline = 0
                    Else
                        PreviousWasSpace = 0
                        If CurrentByte = 10 Or CurrentByte = 13 Then
                            Dim NewlineStart As Long = Index
                            If CurrentByte = 13 Then
                                Dim HasCrLf As Long = 0
                                If Index + 1 < Length Then
                                    If StringByteAt(SourceText, Index + 1) = 10 Then
                                        HasCrLf = 1
                                    End If
                                End If
                                If HasCrLf <> 0 Then
                                    Index = Index + 2
                                Else
                                    Call AddLexicalDiagnostic(Source, Index, "UBE3402", "lone carriage return is not a valid line ending", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                    Index = Index + 1
                                End If
                            Else
                                Index = Index + 1
                            End If
                            Call AppendLexicalToken(Tokens, TokenCount, TokenCapacity, 9, Source, NewlineStart, Index - NewlineStart, StringSlice(SourceText, NewlineStart, Index - NewlineStart), "")
                            AtStatementStart = 1
                            LastWasNewline = 1
                        Else
                            LastWasNewline = 0
                            If CurrentByte = 39 Then
                                Dim CommentStart As Long = Index
                                Index = Index + 1
                                While Index < Length
                                    If StringByteAt(SourceText, Index) = 10 Or StringByteAt(SourceText, Index) = 13 Then
                                        Exit While
                                    End If
                                    Index = Index + 1
                                Wend
                                Call AppendLexicalToken(Tokens, TokenCount, TokenCapacity, 10, Source, CommentStart, Index - CommentStart, StringSlice(SourceText, CommentStart, Index - CommentStart), StringSlice(SourceText, CommentStart + 1, Index - CommentStart - 1))
                            Else
                                Dim FirstIdentifierBytes As Long = IdentifierStartBytes(SourceText, Index, Length)
                                If FirstIdentifierBytes > 0 Then
                                    Dim IdentifierStart As Long = Index
                                    Index = Index + FirstIdentifierBytes
                                    While Index < Length
                                        Dim PartBytes As Long = IdentifierPartBytes(SourceText, Index, Length)
                                        If PartBytes = 0 Then
                                            Exit While
                                        End If
                                        Index = Index + PartBytes
                                    Wend
                                    Dim IdentifierText As String = StringSlice(SourceText, IdentifierStart, Index - IdentifierStart)
                                    Dim RemIsComment As Long = 0
                                    If AtStatementStart <> 0 And EqualsFolded(IdentifierText, "Rem") <> 0 Then
                                        If Index = Length Or StringByteAt(SourceText, Index) = 32 Or StringByteAt(SourceText, Index) = 9 Or StringByteAt(SourceText, Index) = 10 Or StringByteAt(SourceText, Index) = 13 Then
                                            RemIsComment = 1
                                        End If
                                    End If
                                    If RemIsComment <> 0 Then
                                        While Index < Length
                                            If StringByteAt(SourceText, Index) = 10 Or StringByteAt(SourceText, Index) = 13 Then
                                                Exit While
                                            End If
                                            Index = Index + 1
                                        Wend
                                        Call AppendLexicalToken(Tokens, TokenCount, TokenCapacity, 10, Source, IdentifierStart, Index - IdentifierStart, StringSlice(SourceText, IdentifierStart, Index - IdentifierStart), StringSlice(SourceText, IdentifierStart + 3, Index - IdentifierStart - 3))
                                    Else
                                        Dim IdentifierKind As Long = 2
                                        If IsHardKeyword(IdentifierText) <> 0 Then
                                            IdentifierKind = 1
                                        End If
                                        Call AppendLexicalToken(Tokens, TokenCount, TokenCapacity, IdentifierKind, Source, IdentifierStart, Index - IdentifierStart, IdentifierText, IdentifierText)
                                        AtStatementStart = 0
                                    End If
                                Else
                                    Dim StartsNumber As Long = IsAsciiDigit(CurrentByte)
                                    If StartsNumber = 0 And CurrentByte = 38 Then
                                        If Index + 1 < Length Then
                                            Dim PrefixByte As Long = StringByteAt(SourceText, Index + 1)
                                            If PrefixByte = 72 Or PrefixByte = 104 Or PrefixByte = 79 Or PrefixByte = 111 Then
                                                StartsNumber = 1
                                            End If
                                        End If
                                    End If
                                    If StartsNumber <> 0 Then
                                        Dim NumberStart As Long = Index
                                        Dim NumberKind As Long = 4
                                        If CurrentByte = 38 Then
                                            Dim BaseMarker As Long = StringByteAt(SourceText, Index + 1)
                                            Index = Index + 2
                                            Dim DigitStart As Long = Index
                                            If BaseMarker = 72 Or BaseMarker = 104 Then
                                                While Index < Length
                                                    If IsHexDigit(StringByteAt(SourceText, Index)) = 0 Then
                                                        Exit While
                                                    End If
                                                    Index = Index + 1
                                                Wend
                                            Else
                                                While Index < Length
                                                    If IsOctalDigit(StringByteAt(SourceText, Index)) = 0 Then
                                                        Exit While
                                                    End If
                                                    Index = Index + 1
                                                Wend
                                            End If
                                            If Index = DigitStart Then
                                                Call AddLexicalDiagnostic(Source, NumberStart, "UBE3403", "base-prefixed integer requires digits", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                            End If
                                        Else
                                            While Index < Length
                                                If IsAsciiDigit(StringByteAt(SourceText, Index)) = 0 Then
                                                    Exit While
                                                End If
                                                Index = Index + 1
                                            Wend
                                            Dim SawRealPart As Long = 0
                                            Dim HasRealPoint As Long = 0
                                            If Index < Length Then
                                                If StringByteAt(SourceText, Index) = 46 Then
                                                    HasRealPoint = 1
                                                End If
                                            End If
                                            If HasRealPoint <> 0 Then
                                                SawRealPart = 1
                                                Index = Index + 1
                                                While Index < Length
                                                    If IsAsciiDigit(StringByteAt(SourceText, Index)) = 0 Then
                                                        Exit While
                                                    End If
                                                    Index = Index + 1
                                                Wend
                                            End If
                                            Dim HasExponent As Long = 0
                                            If Index < Length Then
                                                If StringByteAt(SourceText, Index) = 69 Or StringByteAt(SourceText, Index) = 101 Then
                                                    HasExponent = 1
                                                End If
                                            End If
                                            If HasExponent <> 0 Then
                                                SawRealPart = 1
                                                Dim ExponentStart As Long = Index
                                                Index = Index + 1
                                                If Index < Length Then
                                                    If StringByteAt(SourceText, Index) = 43 Or StringByteAt(SourceText, Index) = 45 Then
                                                        Index = Index + 1
                                                    End If
                                                End If
                                                Dim ExponentDigits As Long = Index
                                                While Index < Length
                                                    If IsAsciiDigit(StringByteAt(SourceText, Index)) = 0 Then
                                                        Exit While
                                                    End If
                                                    Index = Index + 1
                                                Wend
                                                If Index = ExponentDigits Then
                                                    Call AddLexicalDiagnostic(Source, ExponentStart, "UBE3404", "real exponent requires decimal digits", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                                End If
                                            End If
                                            If SawRealPart <> 0 Then
                                                NumberKind = 5
                                            End If
                                        End If
                                        If Index < Length Then
                                            Dim SuffixByte As Long = StringByteAt(SourceText, Index)
                                            If NumberKind = 4 Then
                                                If SuffixByte = 37 Or SuffixByte = 38 Or SuffixByte = 94 Then
                                                    Index = Index + 1
                                                End If
                                            Else
                                                If SuffixByte = 33 Or SuffixByte = 35 Or SuffixByte = 64 Or SuffixByte = 70 Or SuffixByte = 102 Or SuffixByte = 82 Or SuffixByte = 114 Or SuffixByte = 68 Or SuffixByte = 100 Then
                                                    Index = Index + 1
                                                End If
                                            End If
                                        End If
                                        Dim NumberText As String = StringSlice(SourceText, NumberStart, Index - NumberStart)
                                        Call AppendLexicalToken(Tokens, TokenCount, TokenCapacity, NumberKind, Source, NumberStart, Index - NumberStart, NumberText, NumberText)
                                        AtStatementStart = 0
                                    Else
                                        If CurrentByte = 34 Then
                                            Dim StringStart As Long = Index
                                            Dim StringClosed As Long = 0
                                            Dim StringDecoded As String = ""
                                            Index = Index + 1
                                            Dim SegmentStart As Long = Index
                                            While Index < Length
                                                If StringByteAt(SourceText, Index) = 10 Or StringByteAt(SourceText, Index) = 13 Then
                                                    Exit While
                                                End If
                                                If StringByteAt(SourceText, Index) = 34 Then
                                                    Dim HasEscapedQuote As Long = 0
                                                    If Index + 1 < Length Then
                                                        If StringByteAt(SourceText, Index + 1) = 34 Then
                                                            HasEscapedQuote = 1
                                                        End If
                                                    End If
                                                    If HasEscapedQuote <> 0 Then
                                                        StringDecoded = StringDecoded & StringSlice(SourceText, SegmentStart, Index - SegmentStart) & StringFromByte(34)
                                                        Index = Index + 2
                                                        SegmentStart = Index
                                                    Else
                                                        StringDecoded = StringDecoded & StringSlice(SourceText, SegmentStart, Index - SegmentStart)
                                                        Index = Index + 1
                                                        StringClosed = 1
                                                        Exit While
                                                    End If
                                                Else
                                                    Index = Index + 1
                                                End If
                                            Wend
                                            If StringClosed = 0 Then
                                                Call AddLexicalDiagnostic(Source, StringStart, "UBE3405", "unterminated string literal", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                            Else
                                                Call AppendLexicalToken(Tokens, TokenCount, TokenCapacity, 6, Source, StringStart, Index - StringStart, StringSlice(SourceText, StringStart, Index - StringStart), StringDecoded)
                                            End If
                                            AtStatementStart = 0
                                        Else
                                            If CurrentByte = 35 Then
                                                Dim DateStart As Long = Index
                                                Index = Index + 1
                                                Dim DateContentStart As Long = Index
                                                While Index < Length
                                                    If StringByteAt(SourceText, Index) = 35 Or StringByteAt(SourceText, Index) = 10 Or StringByteAt(SourceText, Index) = 13 Then
                                                        Exit While
                                                    End If
                                                    Index = Index + 1
                                                Wend
                                                Dim DateClosed As Long = 0
                                                If Index < Length Then
                                                    If StringByteAt(SourceText, Index) = 35 Then
                                                        DateClosed = 1
                                                    End If
                                                End If
                                                If DateClosed = 0 Then
                                                    Call AddLexicalDiagnostic(Source, DateStart, "UBE3406", "unterminated date/time literal", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                                Else
                                                    Dim DateText As String = StringSlice(SourceText, DateContentStart, Index - DateContentStart)
                                                    Index = Index + 1
                                                    If ValidateInvariantDateText(DateText) = 0 Then
                                                        Call AddLexicalDiagnostic(Source, DateStart, "UBE3407", "invalid invariant date/time literal", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                                    End If
                                                    Call AppendLexicalToken(Tokens, TokenCount, TokenCapacity, 7, Source, DateStart, Index - DateStart, StringSlice(SourceText, DateStart, Index - DateStart), DateText)
                                                End If
                                                AtStatementStart = 0
                                            Else
                                                If CurrentByte = 91 Then
                                                    Dim BracketStart As Long = Index
                                                    Dim BracketDecoded As String = ""
                                                    Dim BracketClosed As Long = 0
                                                    Index = Index + 1
                                                    Dim BracketSegment As Long = Index
                                                    While Index < Length
                                                        If StringByteAt(SourceText, Index) = 10 Or StringByteAt(SourceText, Index) = 13 Then
                                                            Exit While
                                                        End If
                                                        If StringByteAt(SourceText, Index) = 93 Then
                                                            Dim HasEscapedBracket As Long = 0
                                                            If Index + 1 < Length Then
                                                                If StringByteAt(SourceText, Index + 1) = 93 Then
                                                                    HasEscapedBracket = 1
                                                                End If
                                                            End If
                                                            If HasEscapedBracket <> 0 Then
                                                                BracketDecoded = BracketDecoded & StringSlice(SourceText, BracketSegment, Index - BracketSegment) & StringFromByte(93)
                                                                Index = Index + 2
                                                                BracketSegment = Index
                                                            Else
                                                                BracketDecoded = BracketDecoded & StringSlice(SourceText, BracketSegment, Index - BracketSegment)
                                                                Index = Index + 1
                                                                BracketClosed = 1
                                                                Exit While
                                                            End If
                                                        Else
                                                            Index = Index + 1
                                                        End If
                                                    Wend
                                                    If BracketClosed = 0 Or StringLength(BracketDecoded) = 0 Then
                                                        Call AddLexicalDiagnostic(Source, BracketStart, "UBE3408", "invalid bracketed identifier", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                                    Else
                                                        Call AppendLexicalToken(Tokens, TokenCount, TokenCapacity, 3, Source, BracketStart, Index - BracketStart, StringSlice(SourceText, BracketStart, Index - BracketStart), BracketDecoded)
                                                    End If
                                                    AtStatementStart = 0
                                                Else
                                                    If CurrentByte < 32 Then
                                                        Call AddLexicalDiagnostic(Source, Index, "UBE3409", "invalid control character", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                                        Index = Index + 1
                                                    Else
                                                        If IsPunctuationByte(CurrentByte) <> 0 Then
                                                            Dim PunctuationStart As Long = Index
                                                            Dim PunctuationLength As Long = 1
                                                            If Index + 1 < Length Then
                                                                Dim NextByte As Long = StringByteAt(SourceText, Index + 1)
                                                                If CurrentByte = 60 And (NextByte = 61 Or NextByte = 62) Or CurrentByte = 62 And NextByte = 61 Or CurrentByte = 58 And NextByte = 61 Then
                                                                    PunctuationLength = 2
                                                                End If
                                                            End If
                                                            Index = Index + PunctuationLength
                                                            Dim PunctuationText As String = StringSlice(SourceText, PunctuationStart, PunctuationLength)
                                                            Call AppendLexicalToken(Tokens, TokenCount, TokenCapacity, 8, Source, PunctuationStart, PunctuationLength, PunctuationText, PunctuationText)
                                                            If PunctuationText = ":" Then
                                                                AtStatementStart = 1
                                                            Else
                                                                AtStatementStart = 0
                                                            End If
                                                        Else
                                                            Call AddLexicalDiagnostic(Source, Index, "UBE3410", "unrecognized source character", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                                            Dim InvalidBytes As Long = Utf8SequenceLength(SourceText, Index, Length)
                                                            If InvalidBytes < 1 Then
                                                                InvalidBytes = 1
                                                            End If
                                                            Index = Index + InvalidBytes
                                                        End If
                                                    End If
                                                End If
                                            End If
                                        End If
                                    End If
                                End If
                            End If
                        End If
                    End If
                End If
            End If
        End If
    Wend
    If LastWasNewline = 0 Then
        Call AppendLexicalToken(Tokens, TokenCount, TokenCapacity, 9, Source, Length, 0, "", "")
    End If
    Call AppendLexicalToken(Tokens, TokenCount, TokenCapacity, 13, Source, Length, 0, "", "")
    If DiagnosticCount = InitialDiagnosticCount Then
        LexOneSource = 1
    Else
        LexOneSource = 0
    End If
End Function
