UBE SOURCE 1 MODULE
Attribute UBE_Name = "SourceSyntax"

' Admission notices the first pending conditional directive before requesting a
' complete raw scan. It does not evaluate directives or inspect inactive text.
' In particular, an unclosed quote after that directive cannot be required to
' scan successfully. This is a conservative scope decision, never acceptance.
' Source is borrowed. No payload allocation/copy or mutable global state occurs.
Function TrySyntaxConditionalInput(ByRef Document As SourceDocument, ByRef Deferred As Boolean, ByRef Failure As SyntaxFailure) As Boolean
    TrySyntaxConditionalInput = False
    Deferred = False
    Failure.Kind = 5
    Dim Length As Long = ByteStorageLength(Document.Bytes)
    Dim AtByte As Long = Document.ContentStart
    If AtByte < 0 Or AtByte > Length Or Length > 16777216 Then
        Failure.Kind = 1
        Exit Function
    End If
    Dim LineStart As Boolean = True
    Dim Continued As Boolean = False
    Dim InString As Boolean = False
    Dim InBracket As Boolean = False
    Dim InDate As Boolean = False
    Dim InComment As Boolean = False
    Dim StatementStart As Boolean = True
    Dim AfterMember As Boolean = False
    Dim Parentheses As Long = 0
    Dim PreviousSpace As Boolean = True
    Dim Continuation As Boolean = False
    While AtByte < Length
        Dim Value As Long = Document.Bytes(AtByte)
        If Value = 13 Or Value = 10 Then
            ' A malformed quote before any directive belongs to raw scanning.
            If InString Or InBracket Then
                TrySyntaxConditionalInput = True
                Exit Function
            End If
            ' A hash can introduce a file number as well as a date candidate.
            ' Neither spans a physical newline. Defer their interpretation to
            ' their real consumer, while still noticing a later directive.
            InDate = False
            If Value = 13 And AtByte + 1 < Length Then
                If Document.Bytes(AtByte + 1) = 10 Then
                    AtByte = AtByte + 1
                End If
            End If
            Continued = Continuation
            If Continued = False Then
                StatementStart = True
                AfterMember = False
                Parentheses = 0
            End If
            LineStart = True
            InComment = False
            PreviousSpace = True
            Continuation = False
        Else
            If InComment = False Then
                If InString Then
                    If Value = 34 Then
                        If AtByte + 1 < Length Then
                            If Document.Bytes(AtByte + 1) = 34 Then
                                AtByte = AtByte + 1
                            Else
                                InString = False
                            End If
                        Else
                            InString = False
                        End If
                    End If
                Else
                    If InBracket Then
                        If Value = 93 Then
                            If AtByte + 1 < Length Then
                                If Document.Bytes(AtByte + 1) = 93 Then
                                    AtByte = AtByte + 1
                                Else
                                    InBracket = False
                                End If
                            Else
                                InBracket = False
                            End If
                        End If
                    Else
                    If InDate Then
                        If Value = 35 Then
                            InDate = False
                        End If
                    Else
                        If Value = 39 Then
                            InComment = True
                        Else
                            If Value = 32 Or Value = 9 Then
                                PreviousSpace = True
                            Else
                                If LineStart And Continued = False And Value = 35 Then
                                    Dim Probe As Long = AtByte + 1
                                    Dim First As Long = Probe
                                    Dim Last As Long = Probe
                                    If TryEnvelopeWord(Document.Bytes, Length, Probe, First, Last) = False Then
                                        Exit Function
                                    End If
                                    Dim Matches As Boolean = False
                                    If TryMatchEnvelopeWord(Document.Bytes, First, Last, "if", Matches) = False Then
                                        Exit Function
                                    End If
                                    If Matches = False Then
                                        If TryMatchEnvelopeWord(Document.Bytes, First, Last, "const", Matches) = False Then
                                            Exit Function
                                        End If
                                    End If
                                    If Matches = False Then
                                        If TryMatchEnvelopeWord(Document.Bytes, First, Last, "elseif", Matches) = False Then
                                            Exit Function
                                        End If
                                    End If
                                    If Matches = False Then
                                        If TryMatchEnvelopeWord(Document.Bytes, First, Last, "else", Matches) = False Then
                                            Exit Function
                                        End If
                                    End If
                                    If Matches = False Then
                                        If TryMatchEnvelopeWord(Document.Bytes, First, Last, "end", Matches) = False Then
                                            Exit Function
                                        End If
                                    End If
                                    If Matches Then
                                        Deferred = True
                                        Failure.Kind = 3
                                        Failure.FirstByte = AtByte
                                        Failure.LastByte = Last
                                        TrySyntaxConditionalInput = True
                                        Exit Function
                                    End If
                                End If
                                ' Reuse the scanner's word boundaries and
                                ' statement-start policy. Rem after Then/Else
                                ' or a colon is a comment, but a member or
                                ' parenthesized argument named Rem is not.
                                Dim WordLast As Long = AtByte
                                If Value <> 34 And Value <> 91 Then
                                    Dim WordProbe As Long = AtByte
                                    Dim WordFirst As Long = AtByte
                                    If TryEnvelopeWord(Document.Bytes, Length, WordProbe, WordFirst, WordLast) = False Then
                                        Exit Function
                                    End If
                                    Dim IsRem As Boolean = False
                                    If StatementStart And AfterMember = False And Parentheses = 0 Then
                                        If TryMatchEnvelopeWord(Document.Bytes, WordFirst, WordLast, "rem", IsRem) = False Then
                                            Exit Function
                                        End If
                                    End If
                                    If IsRem Then
                                        If WordLast = Length Then
                                            InComment = True
                                        Else
                                            Dim Following As Long = Document.Bytes(WordLast)
                                            InComment = Following = 32 Or Following = 9 Or Following = 10 Or Following = 13
                                        End If
                                    End If
                                    If WordLast > WordFirst And InComment = False Then
                                        Dim StartsStatement As Boolean = False
                                        If AfterMember = False And Parentheses = 0 Then
                                            If TryMatchEnvelopeWord(Document.Bytes, WordFirst, WordLast, "then", StartsStatement) = False Then
                                                Exit Function
                                            End If
                                            If StartsStatement = False Then
                                                If TryMatchEnvelopeWord(Document.Bytes, WordFirst, WordLast, "else", StartsStatement) = False Then
                                                    Exit Function
                                                End If
                                            End If
                                        End If
                                        StatementStart = StartsStatement
                                        AfterMember = False
                                    End If
                                End If
                                If InComment = False Then
                                    Continuation = Value = 95 And PreviousSpace And WordLast = AtByte + 1
                                    PreviousSpace = False
                                    If Value = 34 Then
                                        InString = True
                                    End If
                                    If Value = 91 Then
                                        InBracket = True
                                    End If
                                    If Value = 35 Then
                                        InDate = True
                                    End If
                                    If WordLast > AtByte Then
                                        AtByte = WordLast - 1
                                    Else
                                        StatementStart = False
                                        AfterMember = Value = 46 Or Value = 33
                                        If Value = 58 And Parentheses = 0 Then
                                            StatementStart = True
                                            If AtByte + 1 < Length Then
                                                If Document.Bytes(AtByte + 1) = 61 Then
                                                    StatementStart = False
                                                End If
                                            End If
                                        End If
                                        If Value = 40 Then
                                            Parentheses = Parentheses + 1
                                        End If
                                        If Value = 41 And Parentheses > 0 Then
                                            Parentheses = Parentheses - 1
                                        End If
                                    End If
                                    LineStart = False
                                End If
                            End If
                        End If
                    End If
                    End If
                End If
            End If
        End If
        AtByte = AtByte + 1
    Wend
    TrySyntaxConditionalInput = True
End Function

' Anchors an already recognized envelope outside the native MODULE domain.
' Native source kinds retain their exact written span; legacy input points to
' its original header. This describes deferral, not validation of its body.
Function TryDeferredSyntaxEnvelope(ByRef Document As SourceDocument, ByRef Envelope As SourceEnvelope, ByRef Failure As SyntaxFailure) As Boolean
    TryDeferredSyntaxEnvelope = False
    Failure.Kind = 5
    Dim First As Long = Document.ContentStart
    Dim Last As Long = First
    If Envelope.Format = 1 Then
        Dim Length As Long = ByteStorageLength(Document.Bytes)
        Dim Cursor As Long = Document.ContentStart
        Dim Matches As Boolean = False
        If TryTakeEnvelopeWord(Document.Bytes, Length, Cursor, "ube", False, First, Last, Matches) = False Then
            Exit Function
        End If
        If Matches = False Then
            Exit Function
        End If
        If TryTakeEnvelopeWord(Document.Bytes, Length, Cursor, "source", True, First, Last, Matches) = False Then
            Exit Function
        End If
        If Matches = False Then
            Exit Function
        End If
        Dim HadSpace As Boolean = False
        If TrySkipEnvelopeSpace(Document.Bytes, Length, Cursor, HadSpace) = False Then
            Exit Function
        End If
        While Cursor < Length
            Dim Value As Long = Document.Bytes(Cursor)
            If Value < 48 Or Value > 57 Then
                Exit While
            End If
            Cursor = Cursor + 1
        Wend
        If TrySkipEnvelopeSpace(Document.Bytes, Length, Cursor, HadSpace) = False Then
            Exit Function
        End If
        If TryEnvelopeWord(Document.Bytes, Length, Cursor, First, Last) = False Then
            Exit Function
        End If
    End If
    Failure.Kind = 3
    Failure.FirstByte = First
    Failure.LastByte = Last
    TryDeferredSyntaxEnvelope = True
End Function

' Source diagnostic entry. Raw scanner failures retain their original category
' in the 200+ range; source syntax failures use SyntaxFailure's separate domain.
' Both are non-success and preserve the entire prior Published value. Scanner
' and conditional admission work is intentionally outside parser-only Metrics.
Function TryParseSourceSyntax(ByRef Document As SourceDocument, ByVal EntryKind As Long, ByVal SourceId As Long, ByVal MaximumNodes As Long, ByVal MaximumPending As Long, ByVal MaximumDepth As Long, ByRef Published() As SyntaxResult, ByRef Failure As SyntaxFailure, ByRef Metrics As SyntaxMetrics) As Boolean
    TryParseSourceSyntax = False
    Failure.Kind = 1
    Failure.FirstByte = 0
    Failure.LastByte = 0
    Dim EmptyMetrics As SyntaxMetrics
    Metrics = EmptyMetrics
    If EntryKind < 1 Or EntryKind > 3 Or SourceId < 0 Or MaximumNodes < 0 Or MaximumPending < 0 Or MaximumDepth < 0 Then
        Exit Function
    End If
    Failure.Kind = 5
    If EntryKind <> 1 Then
        Dim Deferred As Boolean = False
        If TrySyntaxConditionalInput(Document, Deferred, Failure) = False Then
            Exit Function
        End If
        If Deferred Then
            Exit Function
        End If
    End If
    Dim Tokens() As SourceToken
    Dim ScanFailure As ScannerFailure
    ScanFailure.Kind = 5
    Dim Context As Long = 0
    If EntryKind = 1 Then
        Context = 1
    End If
    If TryScanSource(Document, Context, 1048576, Tokens, ScanFailure) = False Then
        If ScanFailure.Kind = 5 Then
            Failure.Kind = 5
        Else
            Failure.Kind = 200 + ScanFailure.Kind
        End If
        Failure.FirstByte = ScanFailure.First.ByteOffset
        Failure.LastByte = ScanFailure.Last.ByteOffset
        Exit Function
    End If
    TryParseSourceSyntax = TryParseSyntax(Document, Tokens, EntryKind, SourceId, MaximumNodes, MaximumPending, MaximumDepth, Published, Failure, Metrics)
End Function
