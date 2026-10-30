UBE SOURCE 1 MODULE
Attribute UBE_Name = "Preprocessor"

Type ConditionalValue
    ValueKind As Long
    NumberValue As Long
    TextValue As String
End Type

Sub SkipConditionalSpace(ByVal InputText As String, ByRef Cursor As Long, ByVal EndByte As Long)
    Dim ContinueSkipping As Long = 1
    While Cursor < EndByte And ContinueSkipping <> 0
        Dim CurrentByte As Long = StringByteAt(InputText, Cursor)
        If CurrentByte = 32 Or CurrentByte = 9 Or CurrentByte = 10 Or CurrentByte = 13 Then
            Cursor = Cursor + 1
        Else
            If CurrentByte = 95 Then
                Cursor = Cursor + 1
            Else
                If CurrentByte = 39 Then
                    While Cursor < EndByte
                        CurrentByte = StringByteAt(InputText, Cursor)
                        If CurrentByte = 10 Or CurrentByte = 13 Then
                            Exit While
                        End If
                        Cursor = Cursor + 1
                    Wend
                Else
                    ContinueSkipping = 0
                End If
            End If
        End If
    Wend
End Sub

Function ConditionalLogicalLineEnd(ByVal InputText As String, ByVal StartByte As Long) As Long
    Dim Length As Long = StringLength(InputText)
    Dim LineEnd As Long = StringIndexOf(InputText, StringFromByte(10), StartByte)
    If LineEnd < 0 Then
        ConditionalLogicalLineEnd = Length
        Exit Function
    End If
    LineEnd = LineEnd + 1
    Dim ScanStart As Long = StartByte
    Dim KeepScanning As Long = 1
    While KeepScanning <> 0 And LineEnd < Length
        KeepScanning = 0
        Dim Index As Long = ScanStart
        Dim InString As Long = 0
        While Index < LineEnd
            Dim CurrentByte As Long = StringByteAt(InputText, Index)
            If CurrentByte = 34 Then
                Dim EscapedQuote As Long = 0
                If InString <> 0 Then
                    If Index + 1 < LineEnd Then
                        If StringByteAt(InputText, Index + 1) = 34 Then
                            EscapedQuote = 1
                        End If
                    End If
                End If
                If EscapedQuote <> 0 Then
                    Index = Index + 1
                Else
                    If InString = 0 Then
                        InString = 1
                    Else
                        InString = 0
                    End If
                End If
            Else
                If CurrentByte = 39 And InString = 0 Then
                    Exit While
                End If
                If CurrentByte = 95 And InString = 0 And Index > ScanStart Then
                    If StringByteAt(InputText, Index - 1) = 32 Or StringByteAt(InputText, Index - 1) = 9 Then
                        Dim ContinuedAt As Long = ContinuationAfter(InputText, Index, Length)
                        If ContinuedAt >= LineEnd Then
                            ScanStart = ContinuedAt
                            Dim NextEnd As Long = StringIndexOf(InputText, StringFromByte(10), ContinuedAt)
                            If NextEnd < 0 Then
                                LineEnd = Length
                            Else
                                LineEnd = NextEnd + 1
                            End If
                            KeepScanning = 1
                        End If
                    End If
                End If
            End If
            Index = Index + 1
        Wend
    Wend
    ConditionalLogicalLineEnd = LineEnd
End Function

Function ConditionalWordAt(ByVal InputText As String, ByRef Cursor As Long, ByVal EndByte As Long, ByVal Word As String) As Long
    Call SkipConditionalSpace(InputText, Cursor, EndByte)
    Dim WordLength As Long = StringLength(Word)
    If Cursor + WordLength > EndByte Then
        ConditionalWordAt = 0
        Exit Function
    End If
    Dim Candidate As String = StringSlice(InputText, Cursor, WordLength)
    If EqualsFolded(Candidate, Word) = 0 Then
        ConditionalWordAt = 0
        Exit Function
    End If
    If Cursor + WordLength < EndByte Then
        If IdentifierPartBytes(InputText, Cursor + WordLength, EndByte) > 0 Then
            ConditionalWordAt = 0
            Exit Function
        End If
    End If
    Cursor = Cursor + WordLength
    ConditionalWordAt = 1
End Function

Function ConditionalSymbolAt(ByVal InputText As String, ByRef Cursor As Long, ByVal EndByte As Long, ByVal Symbol As String) As Long
    Call SkipConditionalSpace(InputText, Cursor, EndByte)
    Dim SymbolLength As Long = StringLength(Symbol)
    If Cursor + SymbolLength <= EndByte Then
        If StringSlice(InputText, Cursor, SymbolLength) = Symbol Then
            Cursor = Cursor + SymbolLength
            ConditionalSymbolAt = 1
            Exit Function
        End If
    End If
    ConditionalSymbolAt = 0
End Function

Function FindConditionalConstant(ByVal ConstantName As String, ByRef Names() As String, ByVal Count As Long) As Long
    Dim Index As Long = 0
    While Index < Count
        If EqualsFolded(ConstantName, Names(Index)) <> 0 Then
            FindConditionalConstant = Index
            Exit Function
        End If
        Index = Index + 1
    Wend
    FindConditionalConstant = -1
End Function

Sub SetConditionalNumber(ByRef Value As ConditionalValue, ByVal NumberValue As Long)
    Value.ValueKind = 1
    Value.NumberValue = NumberValue
    Value.TextValue = ""
End Sub

Sub SetConditionalText(ByRef Value As ConditionalValue, ByVal TextValue As String)
    Value.ValueKind = 2
    Value.NumberValue = 0
    Value.TextValue = TextValue
End Sub

Function ConditionalTruth(ByRef Value As ConditionalValue) As Long
    If Value.ValueKind = 1 And Value.NumberValue <> 0 Then
        ConditionalTruth = 1
    Else
        ConditionalTruth = 0
    End If
End Function

Function ParseConditionalExpression(ByVal InputText As String, ByRef Cursor As Long, ByVal EndByte As Long, ByRef Names() As String, ByRef Values() As ConditionalValue, ByVal ConstantCount As Long, ByRef Result As ConditionalValue) As Long
    ParseConditionalExpression = ParseConditionalImplication(InputText, Cursor, EndByte, Names, Values, ConstantCount, Result)
End Function

Function ParseConditionalPrimary(ByVal InputText As String, ByRef Cursor As Long, ByVal EndByte As Long, ByRef Names() As String, ByRef Values() As ConditionalValue, ByVal ConstantCount As Long, ByRef Result As ConditionalValue) As Long
    Call SkipConditionalSpace(InputText, Cursor, EndByte)
    If Cursor >= EndByte Then
        ParseConditionalPrimary = 0
        Exit Function
    End If
    If StringByteAt(InputText, Cursor) = 40 Then
        Cursor = Cursor + 1
        If ParseConditionalExpression(InputText, Cursor, EndByte, Names, Values, ConstantCount, Result) = 0 Then
            ParseConditionalPrimary = 0
            Exit Function
        End If
        If ConditionalSymbolAt(InputText, Cursor, EndByte, ")") = 0 Then
            ParseConditionalPrimary = 0
            Exit Function
        End If
        ParseConditionalPrimary = 1
        Exit Function
    End If
    If StringByteAt(InputText, Cursor) = 34 Then
        Cursor = Cursor + 1
        Dim Decoded As String = ""
        While Cursor < EndByte
            If StringByteAt(InputText, Cursor) = 34 Then
                Dim EscapedStringQuote As Long = 0
                If Cursor + 1 < EndByte Then
                    If StringByteAt(InputText, Cursor + 1) = 34 Then
                        EscapedStringQuote = 1
                    End If
                End If
                If EscapedStringQuote <> 0 Then
                    Decoded = Decoded & StringFromByte(34)
                    Cursor = Cursor + 2
                Else
                    Cursor = Cursor + 1
                    Call SetConditionalText(Result, Decoded)
                    ParseConditionalPrimary = 1
                    Exit Function
                End If
            Else
                Decoded = Decoded & StringFromByte(StringByteAt(InputText, Cursor))
                Cursor = Cursor + 1
            End If
        Wend
        ParseConditionalPrimary = 0
        Exit Function
    End If
    If StringByteAt(InputText, Cursor) = 35 Then
        Dim DateStart As Long = Cursor + 1
        Cursor = Cursor + 1
        While Cursor < EndByte
            If StringByteAt(InputText, Cursor) = 35 Then
                Exit While
            End If
            If StringByteAt(InputText, Cursor) = 10 Or StringByteAt(InputText, Cursor) = 13 Then
                ParseConditionalPrimary = 0
                Exit Function
            End If
            Cursor = Cursor + 1
        Wend
        If Cursor >= EndByte Then
            ParseConditionalPrimary = 0
            Exit Function
        End If
        Dim DateText As String = StringSlice(InputText, DateStart, Cursor - DateStart)
        If ValidateInvariantDateText(DateText) = 0 Then
            ParseConditionalPrimary = 0
            Exit Function
        End If
        Cursor = Cursor + 1
        Call SetConditionalText(Result, DateText)
        ParseConditionalPrimary = 1
        Exit Function
    End If
    If StringByteAt(InputText, Cursor) = 38 Then
        If Cursor + 2 < EndByte Then
            Dim BaseMarker As Long = StringByteAt(InputText, Cursor + 1)
            If BaseMarker = 72 Or BaseMarker = 104 Or BaseMarker = 79 Or BaseMarker = 111 Then
                Cursor = Cursor + 2
                Dim BaseValue As Long = 16
                If BaseMarker = 79 Or BaseMarker = 111 Then
                    BaseValue = 8
                End If
                Dim BasedValue As Long = 0
                Dim BasedDigits As Long = 0
                While Cursor < EndByte
                    Dim DigitValue As Long = -1
                    Dim DigitByte As Long = StringByteAt(InputText, Cursor)
                    If DigitByte >= 48 And DigitByte <= 57 Then
                        DigitValue = DigitByte - 48
                    Else
                        If DigitByte >= 65 And DigitByte <= 70 Then
                            DigitValue = DigitByte - 55
                        Else
                            If DigitByte >= 97 And DigitByte <= 102 Then
                                DigitValue = DigitByte - 87
                            End If
                        End If
                    End If
                    If DigitValue < 0 Or DigitValue >= BaseValue Then
                        Exit While
                    End If
                    If BasedValue > (2147483647 - DigitValue) \ BaseValue Then
                        ParseConditionalPrimary = 0
                        Exit Function
                    End If
                    BasedValue = BasedValue * BaseValue + DigitValue
                    BasedDigits = BasedDigits + 1
                    Cursor = Cursor + 1
                Wend
                If BasedDigits = 0 Then
                    ParseConditionalPrimary = 0
                    Exit Function
                End If
                If Cursor < EndByte Then
                    If StringByteAt(InputText, Cursor) = 37 Or StringByteAt(InputText, Cursor) = 38 Or StringByteAt(InputText, Cursor) = 94 Then
                        Cursor = Cursor + 1
                    End If
                End If
                Call SetConditionalNumber(Result, BasedValue)
                ParseConditionalPrimary = 1
                Exit Function
            End If
        End If
    End If
    If IsAsciiDigit(StringByteAt(InputText, Cursor)) <> 0 Then
        Dim NumberValue As Long = 0
        Dim FractionNonZero As Long = 0
        While Cursor < EndByte
            If IsAsciiDigit(StringByteAt(InputText, Cursor)) = 0 Then
                Exit While
            End If
            Dim DecimalDigit As Long = StringByteAt(InputText, Cursor) - 48
            If NumberValue > 214748364 Or NumberValue = 214748364 And DecimalDigit > 7 Then
                ParseConditionalPrimary = 0
                Exit Function
            End If
            NumberValue = NumberValue * 10 + DecimalDigit
            Cursor = Cursor + 1
        Wend
        Dim HasDecimalPoint As Long = 0
        If Cursor < EndByte Then
            If StringByteAt(InputText, Cursor) = 46 Then
                HasDecimalPoint = 1
            End If
        End If
        If HasDecimalPoint <> 0 Then
            Cursor = Cursor + 1
            While Cursor < EndByte
                If IsAsciiDigit(StringByteAt(InputText, Cursor)) = 0 Then
                    Exit While
                End If
                If StringByteAt(InputText, Cursor) <> 48 Then
                    FractionNonZero = 1
                End If
                Cursor = Cursor + 1
            Wend
        End If
        If Cursor < EndByte Then
            If StringByteAt(InputText, Cursor) = 69 Or StringByteAt(InputText, Cursor) = 101 Then
                Cursor = Cursor + 1
                If Cursor < EndByte Then
                    If StringByteAt(InputText, Cursor) = 43 Or StringByteAt(InputText, Cursor) = 45 Then
                        Cursor = Cursor + 1
                    End If
                End If
                Dim ExponentDigits As Long = 0
                While Cursor < EndByte
                    If IsAsciiDigit(StringByteAt(InputText, Cursor)) = 0 Then
                        Exit While
                    End If
                    ExponentDigits = ExponentDigits + 1
                    Cursor = Cursor + 1
                Wend
                If ExponentDigits = 0 Then
                    ParseConditionalPrimary = 0
                    Exit Function
                End If
            End If
        End If
        If NumberValue = 0 And FractionNonZero <> 0 Then
            NumberValue = 1
        End If
        If Cursor < EndByte Then
            Dim NumberSuffix As Long = StringByteAt(InputText, Cursor)
            If NumberSuffix = 37 Or NumberSuffix = 38 Or NumberSuffix = 94 Or NumberSuffix = 33 Or NumberSuffix = 35 Or NumberSuffix = 64 Or NumberSuffix = 70 Or NumberSuffix = 102 Or NumberSuffix = 82 Or NumberSuffix = 114 Or NumberSuffix = 68 Or NumberSuffix = 100 Then
                Cursor = Cursor + 1
            End If
        End If
        Call SetConditionalNumber(Result, NumberValue)
        ParseConditionalPrimary = 1
        Exit Function
    End If
    Dim IdentifierBytes As Long = IdentifierStartBytes(InputText, Cursor, EndByte)
    If IdentifierBytes = 0 Then
        ParseConditionalPrimary = 0
        Exit Function
    End If
    Dim NameStart As Long = Cursor
    Cursor = Cursor + IdentifierBytes
    While Cursor < EndByte
        IdentifierBytes = IdentifierPartBytes(InputText, Cursor, EndByte)
        If IdentifierBytes = 0 Then
            Exit While
        End If
        Cursor = Cursor + IdentifierBytes
    Wend
    Dim ConstantName As String = StringSlice(InputText, NameStart, Cursor - NameStart)
    If EqualsFolded(ConstantName, "True") <> 0 Then
        Call SetConditionalNumber(Result, -1)
        ParseConditionalPrimary = 1
        Exit Function
    End If
    If EqualsFolded(ConstantName, "False") <> 0 Or EqualsFolded(ConstantName, "Empty") <> 0 Or EqualsFolded(ConstantName, "Null") <> 0 Or EqualsFolded(ConstantName, "Nothing") <> 0 Then
        Call SetConditionalNumber(Result, 0)
        ParseConditionalPrimary = 1
        Exit Function
    End If
    Dim ConstantIndex As Long = FindConditionalConstant(ConstantName, Names, ConstantCount)
    If ConstantIndex < 0 Then
        ParseConditionalPrimary = 0
        Exit Function
    End If
    Result.ValueKind = Values(ConstantIndex).ValueKind
    Result.NumberValue = Values(ConstantIndex).NumberValue
    Result.TextValue = Values(ConstantIndex).TextValue
    ParseConditionalPrimary = 1
End Function

Function ParseConditionalUnary(ByVal InputText As String, ByRef Cursor As Long, ByVal EndByte As Long, ByRef Names() As String, ByRef Values() As ConditionalValue, ByVal ConstantCount As Long, ByRef Result As ConditionalValue) As Long
    Dim Probe As Long = Cursor
    If ConditionalSymbolAt(InputText, Probe, EndByte, "+") <> 0 Then
        Cursor = Probe
        ParseConditionalUnary = ParseConditionalUnary(InputText, Cursor, EndByte, Names, Values, ConstantCount, Result)
        Exit Function
    End If
    Probe = Cursor
    If ConditionalSymbolAt(InputText, Probe, EndByte, "-") <> 0 Then
        Cursor = Probe
        If ParseConditionalUnary(InputText, Cursor, EndByte, Names, Values, ConstantCount, Result) = 0 Or Result.ValueKind <> 1 Then
            ParseConditionalUnary = 0
            Exit Function
        End If
        Result.NumberValue = 0 - Result.NumberValue
        ParseConditionalUnary = 1
        Exit Function
    End If
    ParseConditionalUnary = ParseConditionalPrimary(InputText, Cursor, EndByte, Names, Values, ConstantCount, Result)
End Function

Function ParseConditionalMultiplicative(ByVal InputText As String, ByRef Cursor As Long, ByVal EndByte As Long, ByRef Names() As String, ByRef Values() As ConditionalValue, ByVal ConstantCount As Long, ByRef Result As ConditionalValue) As Long
    If ParseConditionalUnary(InputText, Cursor, EndByte, Names, Values, ConstantCount, Result) = 0 Then
        ParseConditionalMultiplicative = 0
        Exit Function
    End If
    While Cursor < EndByte
        Dim Probe As Long = Cursor
        Dim Operator As Long = 0
        If ConditionalSymbolAt(InputText, Probe, EndByte, "*") <> 0 Then
            Operator = 1
        Else
            Probe = Cursor
            If ConditionalSymbolAt(InputText, Probe, EndByte, "/") <> 0 Then
                Operator = 2
            Else
                Probe = Cursor
                If ConditionalSymbolAt(InputText, Probe, EndByte, "\") <> 0 Then
                    Operator = 3
                Else
                    Probe = Cursor
                    If ConditionalWordAt(InputText, Probe, EndByte, "Mod") <> 0 Then
                        Operator = 4
                    End If
                End If
            End If
        End If
        If Operator = 0 Then
            Exit While
        End If
        Cursor = Probe
        Dim RightValue As ConditionalValue
        If ParseConditionalUnary(InputText, Cursor, EndByte, Names, Values, ConstantCount, RightValue) = 0 Or Result.ValueKind <> 1 Or RightValue.ValueKind <> 1 Or RightValue.NumberValue = 0 And Operator <> 1 Then
            ParseConditionalMultiplicative = 0
            Exit Function
        End If
        If Operator = 1 Then
            Result.NumberValue = Result.NumberValue * RightValue.NumberValue
        Else
            If Operator = 2 Then
                Result.NumberValue = Result.NumberValue \ RightValue.NumberValue
            Else
                If Operator = 3 Then
                    Result.NumberValue = Result.NumberValue \ RightValue.NumberValue
                Else
                    Result.NumberValue = Result.NumberValue Mod RightValue.NumberValue
                End If
            End If
        End If
    Wend
    ParseConditionalMultiplicative = 1
End Function

Function ParseConditionalAdditive(ByVal InputText As String, ByRef Cursor As Long, ByVal EndByte As Long, ByRef Names() As String, ByRef Values() As ConditionalValue, ByVal ConstantCount As Long, ByRef Result As ConditionalValue) As Long
    If ParseConditionalMultiplicative(InputText, Cursor, EndByte, Names, Values, ConstantCount, Result) = 0 Then
        ParseConditionalAdditive = 0
        Exit Function
    End If
    While Cursor < EndByte
        Dim Probe As Long = Cursor
        Dim Operator As Long = 0
        If ConditionalSymbolAt(InputText, Probe, EndByte, "+") <> 0 Then
            Operator = 1
        Else
            Probe = Cursor
            If ConditionalSymbolAt(InputText, Probe, EndByte, "-") <> 0 Then
                Operator = 2
            Else
                Probe = Cursor
                If ConditionalSymbolAt(InputText, Probe, EndByte, "&") <> 0 Then
                    Operator = 3
                End If
            End If
        End If
        If Operator = 0 Then
            Exit While
        End If
        Cursor = Probe
        Dim RightValue As ConditionalValue
        If ParseConditionalMultiplicative(InputText, Cursor, EndByte, Names, Values, ConstantCount, RightValue) = 0 Then
            ParseConditionalAdditive = 0
            Exit Function
        End If
        If Operator = 3 Then
            If Result.ValueKind <> 2 Or RightValue.ValueKind <> 2 Then
                ParseConditionalAdditive = 0
                Exit Function
            End If
            Result.TextValue = Result.TextValue & RightValue.TextValue
        Else
            If Result.ValueKind <> 1 Or RightValue.ValueKind <> 1 Then
                ParseConditionalAdditive = 0
                Exit Function
            End If
            If Operator = 1 Then
                Result.NumberValue = Result.NumberValue + RightValue.NumberValue
            Else
                Result.NumberValue = Result.NumberValue - RightValue.NumberValue
            End If
        End If
    Wend
    ParseConditionalAdditive = 1
End Function

Function ParseConditionalComparison(ByVal InputText As String, ByRef Cursor As Long, ByVal EndByte As Long, ByRef Names() As String, ByRef Values() As ConditionalValue, ByVal ConstantCount As Long, ByRef Result As ConditionalValue) As Long
    If ParseConditionalAdditive(InputText, Cursor, EndByte, Names, Values, ConstantCount, Result) = 0 Then
        ParseConditionalComparison = 0
        Exit Function
    End If
    Dim Probe As Long = Cursor
    Dim Operator As Long = 0
    If ConditionalSymbolAt(InputText, Probe, EndByte, "<>") <> 0 Then
        Operator = 2
    Else
        Probe = Cursor
        If ConditionalSymbolAt(InputText, Probe, EndByte, "<=") <> 0 Then
            Operator = 4
        Else
            Probe = Cursor
            If ConditionalSymbolAt(InputText, Probe, EndByte, ">=") <> 0 Then
                Operator = 6
            Else
                Probe = Cursor
                If ConditionalSymbolAt(InputText, Probe, EndByte, "=") <> 0 Then
                    Operator = 1
                Else
                    Probe = Cursor
                    If ConditionalSymbolAt(InputText, Probe, EndByte, "<") <> 0 Then
                        Operator = 3
                    Else
                        Probe = Cursor
                        If ConditionalSymbolAt(InputText, Probe, EndByte, ">") <> 0 Then
                            Operator = 5
                        End If
                    End If
                End If
            End If
        End If
    End If
    If Operator = 0 Then
        ParseConditionalComparison = 1
        Exit Function
    End If
    Cursor = Probe
    Dim RightValue As ConditionalValue
    If ParseConditionalAdditive(InputText, Cursor, EndByte, Names, Values, ConstantCount, RightValue) = 0 Or Result.ValueKind <> RightValue.ValueKind Then
        ParseConditionalComparison = 0
        Exit Function
    End If
    Dim Comparison As Long = 0
    If Result.ValueKind = 1 Then
        If Operator = 1 And Result.NumberValue = RightValue.NumberValue Or Operator = 2 And Result.NumberValue <> RightValue.NumberValue Or Operator = 3 And Result.NumberValue < RightValue.NumberValue Or Operator = 4 And Result.NumberValue <= RightValue.NumberValue Or Operator = 5 And Result.NumberValue > RightValue.NumberValue Or Operator = 6 And Result.NumberValue >= RightValue.NumberValue Then
            Comparison = -1
        End If
    Else
        If Operator = 1 And Result.TextValue = RightValue.TextValue Or Operator = 2 And Result.TextValue <> RightValue.TextValue Then
            Comparison = -1
        End If
    End If
    Call SetConditionalNumber(Result, Comparison)
    ParseConditionalComparison = 1
End Function

Function ParseConditionalNot(ByVal InputText As String, ByRef Cursor As Long, ByVal EndByte As Long, ByRef Names() As String, ByRef Values() As ConditionalValue, ByVal ConstantCount As Long, ByRef Result As ConditionalValue) As Long
    Dim Negate As Long = 0
    Dim Probe As Long = Cursor
    While ConditionalWordAt(InputText, Probe, EndByte, "Not") <> 0
        Negate = Negate + 1
        Cursor = Probe
        Probe = Cursor
    Wend
    If ParseConditionalComparison(InputText, Cursor, EndByte, Names, Values, ConstantCount, Result) = 0 Then
        ParseConditionalNot = 0
        Exit Function
    End If
    If Negate Mod 2 <> 0 Then
        If ConditionalTruth(Result) <> 0 Then
            Call SetConditionalNumber(Result, 0)
        Else
            Call SetConditionalNumber(Result, -1)
        End If
    End If
    ParseConditionalNot = 1
End Function

Function ParseConditionalBooleanLevel(ByVal InputText As String, ByRef Cursor As Long, ByVal EndByte As Long, ByRef Names() As String, ByRef Values() As ConditionalValue, ByVal ConstantCount As Long, ByRef Result As ConditionalValue, ByVal Level As Long) As Long
    If Level = 1 Then
        If ParseConditionalNot(InputText, Cursor, EndByte, Names, Values, ConstantCount, Result) = 0 Then
            ParseConditionalBooleanLevel = 0
            Exit Function
        End If
    Else
        If ParseConditionalBooleanLevel(InputText, Cursor, EndByte, Names, Values, ConstantCount, Result, Level - 1) = 0 Then
            ParseConditionalBooleanLevel = 0
            Exit Function
        End If
    End If
    While Cursor < EndByte
        Dim Probe As Long = Cursor
        Dim Matched As Long = 0
        If Level = 1 Then
            If ConditionalWordAt(InputText, Probe, EndByte, "And") <> 0 Or ConditionalWordAt(InputText, Probe, EndByte, "AndAlso") <> 0 Then
                Matched = 1
            End If
        Else
            If Level = 2 Then
                If ConditionalWordAt(InputText, Probe, EndByte, "Or") <> 0 Or ConditionalWordAt(InputText, Probe, EndByte, "OrElse") <> 0 Then
                    Matched = 1
                End If
            Else
                If Level = 3 Then
                    If ConditionalWordAt(InputText, Probe, EndByte, "Xor") <> 0 Then
                        Matched = 1
                    End If
                Else
                    If Level = 4 Then
                        If ConditionalWordAt(InputText, Probe, EndByte, "Eqv") <> 0 Then
                            Matched = 1
                        End If
                    Else
                        If ConditionalWordAt(InputText, Probe, EndByte, "Imp") <> 0 Then
                            Matched = 1
                        End If
                    End If
                End If
            End If
        End If
        If Matched = 0 Then
            Exit While
        End If
        Cursor = Probe
        Dim RightValue As ConditionalValue
        If Level = 1 Then
            If ParseConditionalNot(InputText, Cursor, EndByte, Names, Values, ConstantCount, RightValue) = 0 Then
                ParseConditionalBooleanLevel = 0
                Exit Function
            End If
        Else
            If ParseConditionalBooleanLevel(InputText, Cursor, EndByte, Names, Values, ConstantCount, RightValue, Level - 1) = 0 Then
                ParseConditionalBooleanLevel = 0
                Exit Function
            End If
        End If
        Dim LeftTruth As Long = ConditionalTruth(Result)
        Dim RightTruth As Long = ConditionalTruth(RightValue)
        Dim Combined As Long = 0
        If Level = 1 Then
            If LeftTruth <> 0 And RightTruth <> 0 Then
                Combined = -1
            End If
        Else
            If Level = 2 Then
                If LeftTruth <> 0 Or RightTruth <> 0 Then
                    Combined = -1
                End If
            Else
                If Level = 3 Then
                    If LeftTruth <> RightTruth Then
                        Combined = -1
                    End If
                Else
                    If Level = 4 Then
                        If LeftTruth = RightTruth Then
                            Combined = -1
                        End If
                    Else
                        If LeftTruth = 0 Or RightTruth <> 0 Then
                            Combined = -1
                        End If
                    End If
                End If
            End If
        End If
        Call SetConditionalNumber(Result, Combined)
    Wend
    ParseConditionalBooleanLevel = 1
End Function

Function ParseConditionalImplication(ByVal InputText As String, ByRef Cursor As Long, ByVal EndByte As Long, ByRef Names() As String, ByRef Values() As ConditionalValue, ByVal ConstantCount As Long, ByRef Result As ConditionalValue) As Long
    ParseConditionalImplication = ParseConditionalBooleanLevel(InputText, Cursor, EndByte, Names, Values, ConstantCount, Result, 5)
End Function

Function AppendConditionalConstant(ByVal ConstantName As String, ByRef Value As ConditionalValue, ByRef Names() As String, ByRef Values() As ConditionalValue, ByRef Count As Long, ByRef Capacity As Long) As Long
    If Count >= LimitConditionalConstants() Then
        AppendConditionalConstant = 0
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = 32
        If Capacity > 0 Then
            NewCapacity = Capacity * 2
        End If
        If NewCapacity > LimitConditionalConstants() Then
            NewCapacity = LimitConditionalConstants()
        End If
        If Capacity = 0 Then
            ReDim Names(NewCapacity - 1)
            ReDim Values(NewCapacity - 1)
        Else
            ReDim Preserve Names(NewCapacity - 1)
            ReDim Preserve Values(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Names(Count) = ConstantName
    Values(Count).ValueKind = Value.ValueKind
    Values(Count).NumberValue = Value.NumberValue
    Values(Count).TextValue = Value.TextValue
    Count = Count + 1
    AppendConditionalConstant = 1
End Function

Function BlankPreservingLines(ByVal InputText As String) As String
    Dim Result As String = ""
    Dim Index As Long = 0
    While Index < StringLength(InputText)
        Dim CurrentByte As Long = StringByteAt(InputText, Index)
        If CurrentByte = 10 Or CurrentByte = 13 Then
            Result = Result & StringFromByte(CurrentByte)
        Else
            Result = Result & " "
        End If
        Index = Index + 1
    Wend
    BlankPreservingLines = Result
End Function

Function PreprocessOneSource(ByRef Source As SourceDocument, ByRef OutputText As String, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim Names() As String
    Dim Values() As ConditionalValue
    Dim ConstantCount As Long = 0
    Dim ConstantCapacity As Long = 0
    Dim ParentActive() As Long
    Dim BranchTaken() As Long
    Dim CurrentActive() As Long
    Dim ElseSeen() As Long
    ReDim ParentActive(LimitConditionalDepth() - 1)
    ReDim BranchTaken(LimitConditionalDepth() - 1)
    ReDim CurrentActive(LimitConditionalDepth() - 1)
    ReDim ElseSeen(LimitConditionalDepth() - 1)
    Dim Depth As Long = 0
    Dim Active As Long = 1
    Dim Cursor As Long = 0
    Dim Length As Long = StringLength(Source.Contents)
    OutputText = ""
    Dim InitialDiagnostics As Long = DiagnosticCount
    While Cursor < Length
        Dim LineStart As Long = Cursor
        Dim LineEnd As Long = ConditionalLogicalLineEnd(Source.Contents, Cursor)
        Dim ContentEnd As Long = LineEnd
        While ContentEnd > LineStart And (StringByteAt(Source.Contents, ContentEnd - 1) = 10 Or StringByteAt(Source.Contents, ContentEnd - 1) = 13)
            ContentEnd = ContentEnd - 1
        Wend
        Dim DirectiveCursor As Long = LineStart
        Call SkipConditionalSpace(Source.Contents, DirectiveCursor, ContentEnd)
        Dim IsDirective As Long = 0
        If DirectiveCursor < ContentEnd And StringByteAt(Source.Contents, DirectiveCursor) = 35 Then
            IsDirective = 1
            DirectiveCursor = DirectiveCursor + 1
        End If
        If IsDirective = 0 Then
            If Active <> 0 Then
                OutputText = OutputText & StringSlice(Source.Contents, LineStart, LineEnd - LineStart)
            Else
                OutputText = OutputText & BlankPreservingLines(StringSlice(Source.Contents, LineStart, LineEnd - LineStart))
            End If
        Else
            Dim Handled As Long = 0
            Dim Probe As Long = DirectiveCursor
            If ConditionalWordAt(Source.Contents, Probe, ContentEnd, "Const") <> 0 Then
                Handled = 1
                If Active <> 0 Then
                    Call SkipConditionalSpace(Source.Contents, Probe, ContentEnd)
                    Dim NameStart As Long = Probe
                    Dim NameBytes As Long = IdentifierStartBytes(Source.Contents, Probe, ContentEnd)
                    If NameBytes > 0 Then
                        Probe = Probe + NameBytes
                        While Probe < ContentEnd
                            NameBytes = IdentifierPartBytes(Source.Contents, Probe, ContentEnd)
                            If NameBytes = 0 Then
                                Exit While
                            End If
                            Probe = Probe + NameBytes
                        Wend
                    End If
                    Dim ConstantName As String = StringSlice(Source.Contents, NameStart, Probe - NameStart)
                    Dim Value As ConditionalValue
                    If StringLength(ConstantName) = 0 Or FindConditionalConstant(ConstantName, Names, ConstantCount) >= 0 Or ConditionalSymbolAt(Source.Contents, Probe, ContentEnd, "=") = 0 Or ParseConditionalExpression(Source.Contents, Probe, ContentEnd, Names, Values, ConstantCount, Value) = 0 Then
                        Call AddLexicalDiagnostic(Source, LineStart, "UBE3501", "malformed or duplicate #Const directive", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    Else
                        Call SkipConditionalSpace(Source.Contents, Probe, ContentEnd)
                        If Probe <> ContentEnd Or AppendConditionalConstant(ConstantName, Value, Names, Values, ConstantCount, ConstantCapacity) = 0 Then
                            Call AddLexicalDiagnostic(Source, LineStart, "UBE3502", "invalid #Const value or conditional constant limit exceeded", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        End If
                    End If
                End If
            Else
                Probe = DirectiveCursor
                If ConditionalWordAt(Source.Contents, Probe, ContentEnd, "If") <> 0 Then
                    Handled = 1
                    If Depth >= LimitConditionalDepth() Then
                        Call AddLexicalDiagnostic(Source, LineStart, "UBE3503", "conditional compilation nesting limit exceeded", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    Else
                        Dim Condition As ConditionalValue
                        Dim ConditionOkay As Long = 1
                        If Active <> 0 Then
                            If ParseConditionalExpression(Source.Contents, Probe, ContentEnd, Names, Values, ConstantCount, Condition) = 0 Or ConditionalWordAt(Source.Contents, Probe, ContentEnd, "Then") = 0 Then
                                ConditionOkay = 0
                                Call AddLexicalDiagnostic(Source, LineStart, "UBE3504", "malformed #If condition", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                            Else
                                Call SkipConditionalSpace(Source.Contents, Probe, ContentEnd)
                                If Probe <> ContentEnd Then
                                    ConditionOkay = 0
                                    Call AddLexicalDiagnostic(Source, LineStart, "UBE3504", "malformed #If condition", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                End If
                            End If
                        End If
                        ParentActive(Depth) = Active
                        CurrentActive(Depth) = 0
                        If Active <> 0 And ConditionOkay <> 0 And ConditionalTruth(Condition) <> 0 Then
                            CurrentActive(Depth) = 1
                        End If
                        BranchTaken(Depth) = CurrentActive(Depth)
                        ElseSeen(Depth) = 0
                        Active = CurrentActive(Depth)
                        Depth = Depth + 1
                    End If
                Else
                    Probe = DirectiveCursor
                    If ConditionalWordAt(Source.Contents, Probe, ContentEnd, "ElseIf") <> 0 Then
                        Handled = 1
                        Dim ElseIfInvalid As Long = 0
                        If Depth = 0 Then
                            ElseIfInvalid = 1
                        Else
                            If ElseSeen(Depth - 1) <> 0 Then
                                ElseIfInvalid = 1
                            End If
                        End If
                        If ElseIfInvalid <> 0 Then
                            Call AddLexicalDiagnostic(Source, LineStart, "UBE3505", "#ElseIf has no matching open #If", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        Else
                            Dim ElseIfCondition As ConditionalValue
                            Dim ElseIfOkay As Long = 1
                            If ParentActive(Depth - 1) <> 0 And BranchTaken(Depth - 1) = 0 Then
                                If ParseConditionalExpression(Source.Contents, Probe, ContentEnd, Names, Values, ConstantCount, ElseIfCondition) = 0 Or ConditionalWordAt(Source.Contents, Probe, ContentEnd, "Then") = 0 Then
                                    ElseIfOkay = 0
                                    Call AddLexicalDiagnostic(Source, LineStart, "UBE3506", "malformed #ElseIf condition", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                Else
                                    Call SkipConditionalSpace(Source.Contents, Probe, ContentEnd)
                                    If Probe <> ContentEnd Then
                                        ElseIfOkay = 0
                                        Call AddLexicalDiagnostic(Source, LineStart, "UBE3506", "malformed #ElseIf condition", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                    End If
                                End If
                            End If
                            CurrentActive(Depth - 1) = 0
                            If ParentActive(Depth - 1) <> 0 And BranchTaken(Depth - 1) = 0 And ElseIfOkay <> 0 And ConditionalTruth(ElseIfCondition) <> 0 Then
                                CurrentActive(Depth - 1) = 1
                                BranchTaken(Depth - 1) = 1
                            End If
                            Active = CurrentActive(Depth - 1)
                        End If
                    Else
                        Probe = DirectiveCursor
                        If ConditionalWordAt(Source.Contents, Probe, ContentEnd, "Else") <> 0 Then
                            Handled = 1
                            Call SkipConditionalSpace(Source.Contents, Probe, ContentEnd)
                            Dim ElseInvalid As Long = 0
                            If Probe <> ContentEnd Then
                                ElseInvalid = 1
                                Call AddLexicalDiagnostic(Source, LineStart, "UBE3511", "unexpected text after #Else", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                            End If
                            If Depth = 0 Then
                                ElseInvalid = 1
                            Else
                                If ElseSeen(Depth - 1) <> 0 Then
                                    ElseInvalid = 1
                                End If
                            End If
                            If ElseInvalid <> 0 Then
                                Call AddLexicalDiagnostic(Source, LineStart, "UBE3507", "#Else has no matching open #If", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                            Else
                                ElseSeen(Depth - 1) = 1
                                CurrentActive(Depth - 1) = 0
                                If ParentActive(Depth - 1) <> 0 And BranchTaken(Depth - 1) = 0 Then
                                    CurrentActive(Depth - 1) = 1
                                    BranchTaken(Depth - 1) = 1
                                End If
                                Active = CurrentActive(Depth - 1)
                            End If
                        Else
                            Probe = DirectiveCursor
                            If ConditionalWordAt(Source.Contents, Probe, ContentEnd, "End") <> 0 Then
                                If ConditionalWordAt(Source.Contents, Probe, ContentEnd, "If") <> 0 Then
                                    Handled = 1
                                    Call SkipConditionalSpace(Source.Contents, Probe, ContentEnd)
                                    If Probe <> ContentEnd Then
                                        Call AddLexicalDiagnostic(Source, LineStart, "UBE3512", "unexpected text after #End If", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                    Else
                                    If Depth = 0 Then
                                        Call AddLexicalDiagnostic(Source, LineStart, "UBE3508", "#End If has no matching open #If", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                    Else
                                        Depth = Depth - 1
                                        Active = ParentActive(Depth)
                                    End If
                                    End If
                                End If
                            End If
                        End If
                    End If
                End If
            End If
            If Handled = 0 And Active <> 0 Then
                Call AddLexicalDiagnostic(Source, LineStart, "UBE3509", "unknown conditional-compilation directive", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            End If
            OutputText = OutputText & BlankPreservingLines(StringSlice(Source.Contents, LineStart, LineEnd - LineStart))
        End If
        Cursor = LineEnd
    Wend
    If Depth <> 0 Then
        Call AddLexicalDiagnostic(Source, Length, "UBE3510", "unterminated #If directive", Diagnostics, DiagnosticCount, DiagnosticCapacity)
    End If
    If DiagnosticCount = InitialDiagnostics Then
        PreprocessOneSource = 1
    Else
        PreprocessOneSource = 0
    End If
End Function
