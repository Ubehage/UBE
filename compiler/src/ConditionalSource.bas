UBE SOURCE 1 MODULE
Attribute UBE_Name = "ConditionalSource"
' Selects source ranges using file-local directive state and immutable supplied symbols.
Private Type BranchState
    ParentActive As Boolean
    BranchTaken As Boolean
    Active As Boolean
    SawElse As Boolean
    Opening As SourceScanner.SourcePosition
End Type

Private Type SelectionState
    Depth As Long
    SelectedCount As Long
    SymbolCount As Long
    TextUsed As Long
    SpanCapacity As Long
    BranchCapacity As Long
    Active As Boolean
End Type

Private Intrinsic Function ResizeBranches(ByRef Values() As BranchState, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeBranches.UBE_Primitive = "Array.TryResize"
End Function

' Standalone scanning uses the ordinary False execution context.
Public Function TryScan(ByRef Source() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByRef Count As Long, ByRef Diagnostic As SourceScanner.ScanDiagnostic) As Boolean
    TryScan = TryScanWithContext(Source, False, Tokens, Count, Diagnostic)
End Function

' Supplied context is copied into this file's private conditional symbol table.
Public Function TryScanWithContext(ByRef Source() As Byte, ByVal IsInIDE As Boolean, ByRef Tokens() As SourceScanner.SourceToken, ByRef Count As Long, ByRef Diagnostic As SourceScanner.ScanDiagnostic) As Boolean
    Dim Names() As Byte
    Dim Symbols() As ConditionalExpressions.SymbolFact
    Dim Text() As Byte
    Dim Selected() As SourceScanner.SourceSpan
    Dim SelectedCount As Long
    Dim Failure As SourceParser.ParseDiagnostic
    On Error GoTo Failed
    Count = 0
    If Not BufferPrimitives.TryResizeBytes(Names, 9, False) Then GoTo Failed
    If Not ResizeSymbols(Symbols, 1, False) Then GoTo Failed
    Names(0) = 105: Names(1) = 115: Names(2) = 95
    Names(3) = 105: Names(4) = 110: Names(5) = 95
    Names(6) = 105: Names(7) = 100: Names(8) = 101
    Symbols(0).NameLength = 9
    Symbols(0).Value.TypeCode = SyntaxTokens.KwBoolean
    If IsInIDE Then Symbols(0).Value.Number = -1
    If Not TrySelect(Source, Names, Symbols, 1, Text, 0, Selected, SelectedCount, Failure) Then
        Diagnostic.Code = Failure.Code
        Diagnostic.Reason = Failure.Reason
        Diagnostic.ByteOffset = Failure.ByteOffset
        Diagnostic.Utf16Offset = Failure.Utf16Offset
        Diagnostic.Line = Failure.Line
        Diagnostic.Column = Failure.Column
        Exit Function
    End If
    TryScanWithContext = SourceScanner.TryScanSelected(Source, Selected, SelectedCount, Tokens, Count, Diagnostic)
    Exit Function
Failed:
    Diagnostic.Code = 5
    Diagnostic.Reason = 1
End Function
Private Intrinsic Function ResizeSpans(ByRef Values() As SourceScanner.SourceSpan, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeSpans.UBE_Primitive = "Array.TryResize"
End Function
Private Intrinsic Function MoveSpans(ByRef Destination() As SourceScanner.SourceSpan, ByRef Source() As SourceScanner.SourceSpan) As Boolean
Attribute MoveSpans.UBE_Primitive = "Array.Move"
End Function
Private Intrinsic Function CopySymbols(ByRef Destination() As ConditionalExpressions.SymbolFact, ByRef Source() As ConditionalExpressions.SymbolFact) As Boolean
Attribute CopySymbols.UBE_Primitive = "Array.TryCopy"
End Function
Private Intrinsic Function ResizeSymbols(ByRef Values() As ConditionalExpressions.SymbolFact, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeSymbols.UBE_Primitive = "Array.TryResize"
End Function
Private Intrinsic Function SymbolLength(ByRef Values() As ConditionalExpressions.SymbolFact) As Long
Attribute SymbolLength.UBE_Primitive = "Array.Length"
End Function

' Diagnostics refer to original physical source, including removed logical lines.
Private Function Reject(ByRef Diagnostic As SourceParser.ParseDiagnostic, ByVal Code As Long, ByVal Reason As Long, ByRef Position As SourceScanner.SourcePosition) As Boolean
    Diagnostic.Code = Code
    Diagnostic.Reason = Reason
    Diagnostic.ByteOffset = Position.ByteOffset
    Diagnostic.Utf16Offset = Position.Utf16Offset
    Diagnostic.Line = Position.Line
    Diagnostic.Column = Position.Column
End Function

Private Function ScanFailure(ByRef Diagnostic As SourceParser.ParseDiagnostic, ByRef Failure As SourceScanner.ScanDiagnostic) As Boolean
    Diagnostic.Code = Failure.Code
    Diagnostic.Reason = Failure.Reason
    Diagnostic.ByteOffset = Failure.ByteOffset
    Diagnostic.Utf16Offset = Failure.Utf16Offset
    Diagnostic.Line = Failure.Line
    Diagnostic.Column = Failure.Column
End Function

' Only the directive word is read here; inactive expression text is not tokenized.
Private Function DirectiveWord(ByRef Source() As Byte, ByRef Span As SourceScanner.SourceSpan, ByRef Start As Long) As Long
    Dim Finish As Long
    Dim Word As Long
    Dim Value As Long
    Dim Tokens(0 To 0) As SourceScanner.SourceToken
    Start = Span.Start.ByteOffset
    Finish = Span.Finish.ByteOffset
    Do While Start < Finish
        Value = Source(Start)
        If Value <> 32 And Value <> 9 Then Exit Do
        Start = Start + 1
    Loop
    If Start >= Finish Then Exit Function
    If Source(Start) <> 35 Then Exit Function
    DirectiveWord = -1
    Start = Start + 1
    Word = Start
    Do While Word < Finish
        Value = Source(Word)
        If Value >= 65 And Value <= 90 Then Value = Value + 32
        If Value < 97 Or Value > 122 Then Exit Do
        Word = Word + 1
    Loop
    If Word = Start Then Exit Function
    If Word < Finish Then
        Value = Source(Word)
        If (Value >= 48 And Value <= 57) Or Value = 95 Then Exit Function
    End If
    Tokens(0).Kind = SourceScanner.WordToken
    Tokens(0).ByteStart = Start
    Tokens(0).ByteLength = Word - Start
    Value = SyntaxTokens.TokenCode(Source, Tokens, 0, 1)
    If Value = SyntaxTokens.KwIf Or Value = SyntaxTokens.KwElseif Or Value = SyntaxTokens.KwElse Or Value = SyntaxTokens.KwEnd Or Value = SyntaxTokens.KwConst Then DirectiveWord = Value
End Function

' Geometric growth keeps selection linear in the number of source lines.
Private Function AppendSpan(ByRef Values() As SourceScanner.SourceSpan, ByRef State As SelectionState, ByRef Span As SourceScanner.SourceSpan) As Boolean
    Dim Capacity As Long
    If State.SelectedCount = 2147483647 Then Exit Function
    If State.SelectedCount = State.SpanCapacity Then
        Capacity = State.SpanCapacity
        If Capacity < 16 Then Capacity = 16
        If Capacity > 1073741823 Then
            Capacity = 2147483647
        Else
            Capacity = Capacity + Capacity
        End If
        If Not ResizeSpans(Values, Capacity, True) Then Exit Function
        State.SpanCapacity = Capacity
    End If
    Values(State.SelectedCount) = Span
    State.SelectedCount = State.SelectedCount + 1
    AppendSpan = True
End Function

Private Function ReserveBranch(ByRef Values() As BranchState, ByRef State As SelectionState) As Boolean
    Dim Capacity As Long
    If State.Depth = 2147483647 Then Exit Function
    If State.Depth = State.BranchCapacity Then
        Capacity = State.BranchCapacity
        If Capacity < 8 Then Capacity = 8
        If Capacity > 1073741823 Then
            Capacity = 2147483647
        Else
            Capacity = Capacity + Capacity
        End If
        If Not ResizeBranches(Values, Capacity, True) Then Exit Function
        State.BranchCapacity = Capacity
    End If
    ReserveBranch = True
End Function

' Range scanning reuses the ordinary scanner, retaining its source coordinates.
Private Function ScanDirective(ByRef Source() As Byte, ByVal Start As Long, ByRef Span As SourceScanner.SourceSpan, ByRef Tokens() As SourceScanner.SourceToken, ByRef Count As Long, ByRef After As Long, ByRef Diagnostic As SourceParser.ParseDiagnostic) As Boolean
    Dim Failure As SourceScanner.ScanDiagnostic
    If Not SourceScanner.TryScanRange(Source, Start, Span.Finish.ByteOffset, Tokens, Count, Failure) Then ScanDirective = ScanFailure(Diagnostic, Failure): Exit Function
    After = Count
    Do While After > 0
        If Tokens(After - 1).Kind <> SourceScanner.NewlineToken And Tokens(After - 1).Kind <> SourceScanner.EndToken Then Exit Do
        After = After - 1
    Loop
    If After > 1 Then
        If Tokens(1).ByteStart <= Tokens(0).ByteStart + Tokens(0).ByteLength Then ScanDirective = Reject(Diagnostic, 2, 1, Span.Start): Exit Function
    End If
    ScanDirective = True
End Function

Private Function Condition(ByRef Source() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByVal Count As Long, ByVal After As Long, ByRef Names() As Byte, ByRef Symbols() As ConditionalExpressions.SymbolFact, ByRef Text() As Byte, ByRef State As SelectionState, ByRef Span As SourceScanner.SourceSpan, ByRef Truth As Boolean, ByRef Diagnostic As SourceParser.ParseDiagnostic) As Boolean
    Dim Value As ConditionalExpressions.ValueFact
    Dim Number As LongLong
    Dim Reason As Long
    If After < 3 Then Condition = Reject(Diagnostic, 2, 1, Span.Start): Exit Function
    If SyntaxTokens.TokenCode(Source, Tokens, After - 1, Count) <> SyntaxTokens.KwThen Then Condition = Reject(Diagnostic, 2, 1, Span.Start): Exit Function
    If Tokens(After - 1).ByteStart <= Tokens(After - 2).ByteStart + Tokens(After - 2).ByteLength Then Condition = Reject(Diagnostic, 2, 1, Span.Start): Exit Function
    If Not ConditionalExpressions.TryEvaluate(Source, Tokens, Count, 1, After - 1, Names, Symbols, State.SymbolCount, Text, State.TextUsed, Value, Diagnostic) Then Exit Function
    If Value.TypeCode = SyntaxTokens.KwString Then
        If Not ConstantValues.TryTextValue(Text, Value.TextStart, Value.TextLength, SyntaxTokens.KwBoolean, Number) Then Condition = Reject(Diagnostic, 2, 2, Span.Start): Exit Function
    Else
        If Not ConstantValues.TryConvert(Value.Number, Value.TypeCode, SyntaxTokens.KwBoolean, Number, Reason) Then Condition = Reject(Diagnostic, 2, 2, Span.Start): Exit Function
    End If
    Truth = Number <> 0
    Condition = True
End Function

Private Function AddConstant(ByRef Source() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByVal Count As Long, ByVal After As Long, ByRef Names() As Byte, ByRef Symbols() As ConditionalExpressions.SymbolFact, ByRef Text() As Byte, ByRef State As SelectionState, ByRef Span As SourceScanner.SourceSpan, ByRef Diagnostic As SourceParser.ParseDiagnostic) As Boolean
    Dim Value As ConditionalExpressions.ValueFact
    Dim Size As Long
    Dim Length As Long
    Dim Index As Long
    Dim Cursor As Long
    Dim Same As Boolean
    If After < 4 Then AddConstant = Reject(Diagnostic, 2, 1, Span.Start): Exit Function
    If Not SyntaxTokens.IsIdentifierToken(Source, Tokens, 1, Count, False) Then AddConstant = Reject(Diagnostic, 2, 1, Span.Start): Exit Function
    If SyntaxTokens.TokenCode(Source, Tokens, 2, Count) <> SyntaxTokens.SymEqual Then AddConstant = Reject(Diagnostic, 2, 1, Span.Start): Exit Function
    Do While SyntaxTokens.SpellingByte(Source, Tokens, 1, Count, Length) >= 0
        Length = Length + 1
        If Length > 128 Then AddConstant = Reject(Diagnostic, 4, 1, Span.Start): Exit Function
    Loop
    Do While Index < State.SymbolCount
        Same = Symbols(Index).NameLength = Length
        Cursor = 0
        Do While Same And Cursor < Length
            Same = Names(Symbols(Index).NameStart + Cursor) = SyntaxTokens.SpellingByte(Source, Tokens, 1, Count, Cursor)
            Cursor = Cursor + 1
        Loop
        If Same Then AddConstant = Reject(Diagnostic, 2, 3, Span.Start): Exit Function
        Index = Index + 1
    Loop
    If Not ConditionalExpressions.TryEvaluate(Source, Tokens, Count, 3, After, Names, Symbols, State.SymbolCount, Text, State.TextUsed, Value, Diagnostic) Then Exit Function
    Size = BufferPrimitives.ByteStorageLength(Names)
    If Length > 2147483647 - Size Or State.SymbolCount = 2147483647 Then AddConstant = Reject(Diagnostic, 4, 1, Span.Start): Exit Function
    If Not BufferPrimitives.TryResizeBytes(Names, Size + Length, True) Then AddConstant = Reject(Diagnostic, 5, 1, Span.Start): Exit Function
    If Not ResizeSymbols(Symbols, State.SymbolCount + 1, True) Then AddConstant = Reject(Diagnostic, 5, 1, Span.Start): Exit Function
    Cursor = 0
    Do While Cursor < Length
        Names(Size + Cursor) = SyntaxTokens.SpellingByte(Source, Tokens, 1, Count, Cursor)
        Cursor = Cursor + 1
    Loop
    Symbols(State.SymbolCount).NameStart = Size
    Symbols(State.SymbolCount).NameLength = Length
    Symbols(State.SymbolCount).Value = Value
    State.SymbolCount = State.SymbolCount + 1
    AddConstant = True
End Function

Private Function ApplyDirective(ByRef Source() As Byte, ByVal Start As Long, ByVal Word As Long, ByRef Span As SourceScanner.SourceSpan, ByRef Names() As Byte, ByRef Symbols() As ConditionalExpressions.SymbolFact, ByRef Text() As Byte, ByRef State As SelectionState, ByRef Branches() As BranchState, ByRef Diagnostic As SourceParser.ParseDiagnostic) As Boolean
    Dim Tokens() As SourceScanner.SourceToken
    Dim Count As Long
    Dim After As Long
    Dim Truth As Boolean
    Dim MustScan As Boolean
    On Error GoTo Failed
    MustScan = State.Active Or Word = SyntaxTokens.KwElse Or Word = SyntaxTokens.KwEnd
    If Word = SyntaxTokens.KwElseif Then
        If State.Depth = 0 Then GoTo Invalid
        MustScan = Branches(State.Depth - 1).ParentActive And Not Branches(State.Depth - 1).BranchTaken
    End If
    If MustScan Then
        If Not ScanDirective(Source, Start, Span, Tokens, Count, After, Diagnostic) Then Exit Function
    End If
    If Word = SyntaxTokens.KwIf Then
        Truth = False
        If State.Active Then
            If Not Condition(Source, Tokens, Count, After, Names, Symbols, Text, State, Span, Truth, Diagnostic) Then Exit Function
        End If
        If Not ReserveBranch(Branches, State) Then GoTo Failed
        Branches(State.Depth).ParentActive = State.Active
        Branches(State.Depth).BranchTaken = Truth
        Branches(State.Depth).Active = State.Active And Truth
        Branches(State.Depth).SawElse = False
        Branches(State.Depth).Opening = Span.Start
        State.Active = Branches(State.Depth).Active
        State.Depth = State.Depth + 1
    ElseIf Word = SyntaxTokens.KwElseif Then
        If Branches(State.Depth - 1).SawElse Then GoTo Invalid
        Truth = False
        If MustScan Then
            If Not Condition(Source, Tokens, Count, After, Names, Symbols, Text, State, Span, Truth, Diagnostic) Then Exit Function
        End If
        Branches(State.Depth - 1).Active = MustScan And Truth
        If Truth Then Branches(State.Depth - 1).BranchTaken = True
        State.Active = Branches(State.Depth - 1).Active
    ElseIf Word = SyntaxTokens.KwElse Then
        If State.Depth = 0 Or After <> 1 Then GoTo Invalid
        If Branches(State.Depth - 1).SawElse Then GoTo Invalid
        Branches(State.Depth - 1).SawElse = True
        State.Active = Branches(State.Depth - 1).ParentActive And Not Branches(State.Depth - 1).BranchTaken
        Branches(State.Depth - 1).Active = State.Active
        Branches(State.Depth - 1).BranchTaken = True
    ElseIf Word = SyntaxTokens.KwEnd Then
        If State.Depth = 0 Or After <> 2 Then GoTo Invalid
        If SyntaxTokens.TokenCode(Source, Tokens, 1, Count) <> SyntaxTokens.KwIf Then GoTo Invalid
        State.Depth = State.Depth - 1
        State.Active = Branches(State.Depth).ParentActive
    ElseIf Word = SyntaxTokens.KwConst Then
        If State.Active Then
            If Not AddConstant(Source, Tokens, Count, After, Names, Symbols, Text, State, Span, Diagnostic) Then Exit Function
        End If
    ElseIf State.Active Then
        GoTo Invalid
    End If
    ApplyDirective = True
    Exit Function
Invalid:
    ApplyDirective = Reject(Diagnostic, 2, 1, Span.Start)
    Exit Function
Failed:
    ApplyDirective = Reject(Diagnostic, 5, 1, Span.Start)
End Function

' Selected ranges publish only after all directive nesting has closed successfully.
Public Function TrySelect(ByRef Source() As Byte, ByRef SuppliedNames() As Byte, ByRef SuppliedSymbols() As ConditionalExpressions.SymbolFact, ByVal SuppliedCount As Long, ByRef SuppliedText() As Byte, ByVal SuppliedTextUsed As Long, ByRef Selected() As SourceScanner.SourceSpan, ByRef SelectedCount As Long, ByRef Diagnostic As SourceParser.ParseDiagnostic) As Boolean
    Dim Position As SourceScanner.SourcePosition
    Dim Span As SourceScanner.SourceSpan
    Dim Failure As SourceScanner.ScanDiagnostic
    Dim State As SelectionState
    Dim Branches() As BranchState
    Dim Candidate() As SourceScanner.SourceSpan
    Dim Names() As Byte
    Dim Symbols() As ConditionalExpressions.SymbolFact
    Dim Text() As Byte
    Dim Start As Long
    Dim Word As Long
    On Error GoTo Failed
    If Not SourceScanner.TryBeginSource(Source, Position, Failure) Then TrySelect = ScanFailure(Diagnostic, Failure): Exit Function
    If SuppliedCount < 0 Or SuppliedCount > SymbolLength(SuppliedSymbols) Then GoTo Invalid
    If SuppliedTextUsed < 0 Or SuppliedTextUsed > BufferPrimitives.ByteStorageLength(SuppliedText) Then GoTo Invalid
    If Not BufferPrimitives.TryCopyBytes(Names, SuppliedNames) Then GoTo Failed
    If Not CopySymbols(Symbols, SuppliedSymbols) Then GoTo Failed
    If Not BufferPrimitives.TryCopyBytes(Text, SuppliedText) Then GoTo Failed
    State.SymbolCount = SuppliedCount
    State.TextUsed = SuppliedTextUsed
    State.Active = True
    Do
        If Not SourceScanner.TryReadLogicalLine(Source, Position, Span, Failure) Then TrySelect = ScanFailure(Diagnostic, Failure): Exit Function
        If Span.Kind = SourceScanner.EndSpan Then Exit Do
        Word = 0
        If Span.Kind = SourceScanner.LogicalLineSpan Then Word = DirectiveWord(Source, Span, Start)
        If Word = 0 Then
            If State.Active Then
                If Not AppendSpan(Candidate, State, Span) Then GoTo Failed
            End If
        Else
            If Not ApplyDirective(Source, Start, Word, Span, Names, Symbols, Text, State, Branches, Diagnostic) Then Exit Function
        End If
    Loop
    If State.Depth <> 0 Then
        TrySelect = Reject(Diagnostic, 2, 4, Branches(State.Depth - 1).Opening)
        Exit Function
    End If
    If Not MoveSpans(Selected, Candidate) Then GoTo Failed
    SelectedCount = State.SelectedCount
    Diagnostic.Code = 0
    TrySelect = True
    Exit Function
Invalid:
    TrySelect = Reject(Diagnostic, 2, 1, Span.Start)
    Exit Function
Failed:
    TrySelect = Reject(Diagnostic, 5, 1, Position)
End Function
