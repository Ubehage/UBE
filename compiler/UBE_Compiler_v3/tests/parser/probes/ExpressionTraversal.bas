UBE SOURCE 1 MODULE
Attribute UBE_Name = "ExpressionTraversal"

' Independent test-candidate host-frame budget. Semantic depth alone does not
' bound recursive precedence frames inside nested groups. This is not a UBE
' language limit or a production parser policy; hitting it disqualifies this
' candidate for that measured input while preserving the caller's old output.
Function TraversalFrameLimit() As Long
    TraversalFrameLimit = 384
End Function

' Test-only traversal comparison. Borrow qualified immutable documents/tokens;
' all pending arrays and commands belong to one call. No production ABI is chosen.
' Failure 1 domain, 2 configured budget, 5 storage/admission, 101 expression,
' 102 token/spacing, 103 unexpected token, 104 identifier. Callers preseed 5.
Type TraversalFailure
    Kind As Long
    FirstByte As Long
    LastByte As Long
End Type

Type TraversalMetrics
    TokenReads As Long
    Transitions As Long
    MaximumPending As Long
    MaximumDepth As Long
End Type

Type TraversalCursor
    Index As Long
    Token As SourceToken
    Ready As Boolean
    HadSpace As Boolean
End Type

Type TraversalSpan
    FirstByte As Long
    LastByte As Long
End Type

Type TraversalOperator
    Kind As Long
    Precedence As Long
    FirstByte As Long
    LastByte As Long
End Type

Intrinsic Function TraversalOperatorLength(ByRef Values() As TraversalOperator) As Long
Attribute TraversalOperatorLength.UBE_Primitive = "Array.Length"
End Function
Intrinsic Function TryResizeTraversalOperators(ByRef Values() As TraversalOperator, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeTraversalOperators.UBE_Primitive = "Array.TryResize"
End Function
Intrinsic Function TraversalSpanLength(ByRef Values() As TraversalSpan) As Long
Attribute TraversalSpanLength.UBE_Primitive = "Array.Length"
End Function
Intrinsic Function TryResizeTraversalSpans(ByRef Values() As TraversalSpan, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeTraversalSpans.UBE_Primitive = "Array.TryResize"
End Function

' Count only an actual indexed record read; fresh status separates admission.
Function TryReadTraversalToken(ByRef Tokens() As SourceToken, ByVal Count As Long, ByVal Index As Long, ByRef Token As SourceToken, ByRef Metrics As TraversalMetrics) As Boolean
    TryReadTraversalToken = False
    If Index < 0 Or Index >= Count Then
        Exit Function
    End If
    Metrics.TokenReads = Metrics.TokenReads + 1
    Token = Tokens(Index)
    TryReadTraversalToken = True
End Function

Function TryPeekTraversalToken(ByRef Tokens() As SourceToken, ByVal Count As Long, ByRef Cursor As TraversalCursor, ByRef Metrics As TraversalMetrics) As Boolean
    TryPeekTraversalToken = False
    If Cursor.Ready Then
        TryPeekTraversalToken = True
        Exit Function
    End If
    Cursor.HadSpace = False
    While Cursor.Index < Count
        If TryReadTraversalToken(Tokens, Count, Cursor.Index, Cursor.Token, Metrics) = False Then
            Exit Function
        End If
        Dim Kind As Long = Cursor.Token.Kind
        If Kind <> 8 And Kind <> 9 And Kind <> 10 And Kind <> 11 And Kind <> 12 Then
            Cursor.Ready = True
            TryPeekTraversalToken = True
            Exit Function
        End If
        If Kind = 8 Or Kind = 11 Then
            Cursor.HadSpace = True
        End If
        Cursor.Index = Cursor.Index + 1
        Metrics.Transitions = Metrics.Transitions + 1
    Wend
End Function

Sub ConsumeTraversalToken(ByRef Cursor As TraversalCursor, ByRef Metrics As TraversalMetrics)
    Cursor.Index = Cursor.Index + 1
    Cursor.Ready = False
    Metrics.Transitions = Metrics.Transitions + 1
End Sub

Sub FailTraversal(ByRef Failure As TraversalFailure, ByVal Kind As Long, ByRef Token As SourceToken)
    Failure.Kind = Kind
    Failure.FirstByte = Token.First.ByteOffset
    Failure.LastByte = Token.Last.ByteOffset
End Sub

Function TraversalPrecedence(ByVal Kind As Long) As Long
    TraversalPrecedence = 0
    If Kind = 30 Then
        TraversalPrecedence = 1
    End If
    If Kind = 29 Then
        TraversalPrecedence = 2
    End If
    If Kind = 28 Then
        TraversalPrecedence = 3
    End If
    If Kind = 26 Or Kind = 27 Then
        TraversalPrecedence = 4
    End If
    If Kind = 24 Or Kind = 25 Then
        TraversalPrecedence = 5
    End If
    If Kind = 6 Then
        TraversalPrecedence = 6
    End If
    If Kind >= 15 And Kind <= 23 Then
        TraversalPrecedence = 7
    End If
    If Kind = 14 Then
        TraversalPrecedence = 8
    End If
    If Kind = 12 Or Kind = 13 Then
        TraversalPrecedence = 9
    End If
    If Kind = 8 Or Kind = 9 Then
        TraversalPrecedence = 10
    End If
    If Kind = 10 Then
        TraversalPrecedence = 11
    End If
    If Kind = 11 Then
        TraversalPrecedence = 12
    End If
    If Kind = 4 Or Kind = 5 Then
        TraversalPrecedence = 13
    End If
    If Kind = 7 Then
        TraversalPrecedence = 14
    End If
End Function

Function TraversalIsPrefix(ByVal Kind As Long) As Boolean
    TraversalIsPrefix = Kind = 4 Or Kind = 5 Or Kind = 6
End Function

Function TraversalCountsDepth(ByVal Kind As Long) As Boolean
    TraversalCountsDepth = Kind = -1 Or Kind = 7 Or TraversalIsPrefix(Kind)
End Function

Function TraversalWordOperator(ByVal Kind As Long) As Boolean
    TraversalWordOperator = Kind = 6 Or Kind = 11 Or Kind >= 24
End Function

' Consumes one operator phrase and leaves its following significant token ready.
' Comparison words have spacing (not spacing1); Is Not has an internal spacing1.
Function TryConsumeTraversalOperator(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByVal Count As Long, ByRef Cursor As TraversalCursor, ByRef Kind As Long, ByRef Metrics As TraversalMetrics, ByRef Failure As TraversalFailure) As Boolean
    TryConsumeTraversalOperator = False
    If Kind <> 6 And TraversalWordOperator(Kind) And Cursor.HadSpace = False Then
        Call FailTraversal(Failure, 102, Cursor.Token)
        Exit Function
    End If
    Call ConsumeTraversalToken(Cursor, Metrics)
    If TryPeekTraversalToken(Tokens, Count, Cursor, Metrics) = False Then
        Exit Function
    End If
    If Kind = 22 And Cursor.HadSpace Then
        Dim FollowingKind As Long = 0
        If TryClassifyTraversalToken(Document, Cursor.Token, FollowingKind, Metrics) = False Then
            Exit Function
        End If
        If FollowingKind = 6 Then
            Kind = 23
            Call ConsumeTraversalToken(Cursor, Metrics)
            If TryPeekTraversalToken(Tokens, Count, Cursor, Metrics) = False Then
                Exit Function
            End If
        End If
    End If
    If TraversalWordOperator(Kind) And Cursor.HadSpace = False Then
        Call FailTraversal(Failure, 102, Cursor.Token)
        Exit Function
    End If
    TryConsumeTraversalOperator = True
End Function

Function TryPushTraversalOperator(ByRef Operators() As TraversalOperator, ByRef Count As Long, ByVal MaximumPending As Long, ByRef Value As TraversalOperator, ByRef Metrics As TraversalMetrics) As Boolean
    TryPushTraversalOperator = False
    If Count >= MaximumPending Then
        Exit Function
    End If
    Dim Capacity As Long = TraversalOperatorLength(Operators)
    If Count = Capacity Then
        Dim PreparedCapacity As Long = 8
        If Capacity > 0 Then
            PreparedCapacity = Capacity * 2
        End If
        If PreparedCapacity > MaximumPending Then
            PreparedCapacity = MaximumPending
        End If
        If TryResizeTraversalOperators(Operators, PreparedCapacity, True) = False Then
            Exit Function
        End If
    End If
    Operators(Count) = Value
    Count = Count + 1
    Metrics.Transitions = Metrics.Transitions + 1
    TryPushTraversalOperator = True
End Function

Function TryPushTraversalSpan(ByRef Values() As TraversalSpan, ByRef Count As Long, ByVal MaximumPending As Long, ByRef Value As TraversalSpan, ByRef Metrics As TraversalMetrics) As Boolean
    TryPushTraversalSpan = False
    If Count >= MaximumPending Then
        Exit Function
    End If
    Dim Capacity As Long = TraversalSpanLength(Values)
    If Count = Capacity Then
        Dim PreparedCapacity As Long = 8
        If Capacity > 0 Then
            PreparedCapacity = Capacity * 2
        End If
        If PreparedCapacity > MaximumPending Then
            PreparedCapacity = MaximumPending
        End If
        If TryResizeTraversalSpans(Values, PreparedCapacity, True) = False Then
            Exit Function
        End If
    End If
    Values(Count) = Value
    Count = Count + 1
    Metrics.Transitions = Metrics.Transitions + 1
    TryPushTraversalSpan = True
End Function

' Each reduction pops at least one pending operator and replaces its operands.
Function TryReduceTraversal(ByRef Operators() As TraversalOperator, ByRef OperatorCount As Long, ByRef Values() As TraversalSpan, ByRef ValueCount As Long, ByRef Depth As Long, ByRef Builder As SyntaxCommandBuilder, ByRef Metrics As TraversalMetrics, ByRef Failure As TraversalFailure) As Boolean
    TryReduceTraversal = False
    If OperatorCount < 1 Or ValueCount < 1 Then
        Exit Function
    End If
    Dim Op As TraversalOperator = Operators(OperatorCount - 1)
    If Op.Kind < 1 Then
        Exit Function
    End If
    Dim Span As TraversalSpan = Values(ValueCount - 1)
    Dim ChildCount As Long = 1
    If TraversalIsPrefix(Op.Kind) Then
        Span.FirstByte = Op.FirstByte
    Else
        If ValueCount < 2 Then
            Exit Function
        End If
        ChildCount = 2
        Span.FirstByte = Values(ValueCount - 2).FirstByte
    End If
    If TryEmitTraversalCommand(Builder, Op.Kind, Span, ChildCount, Metrics, Failure) = False Then
        Exit Function
    End If
    OperatorCount = OperatorCount - 1
    ValueCount = ValueCount - ChildCount + 1
    Values(ValueCount - 1) = Span
    If TraversalCountsDepth(Op.Kind) Then
        Depth = Depth - 1
    End If
    Metrics.Transitions = Metrics.Transitions + 1
    TryReduceTraversal = True
End Function

' Depth counts active open groups, prefix operators and pending right-power
' operands. Left-associative chains reduce as they arrive and do not add depth.
' MaximumPending is actual live operator+operand records, not an input formula.
Function TryTraverseStack(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByVal MaximumDepth As Long, ByVal MaximumCommands As Long, ByRef Commands() As SyntaxCommand, ByRef Failure As TraversalFailure, ByRef Metrics As TraversalMetrics) As Boolean
    TryTraverseStack = False
    Dim EmptyMetrics As TraversalMetrics
    Metrics = EmptyMetrics
    Failure.Kind = 1
    Failure.FirstByte = 0
    Failure.LastByte = 0
    Dim TokenCount As Long = ScannerTokenLength(Tokens)
    If MaximumDepth < 0 Or MaximumDepth > 256 Or MaximumCommands < 1 Or TokenCount < 2 Then
        Exit Function
    End If
    Failure.Kind = 5
    Dim Builder As SyntaxCommandBuilder
    Builder.MaximumRecords = MaximumCommands
    Dim Cursor As TraversalCursor
    Dim Operators() As TraversalOperator
    Dim Values() As TraversalSpan
    Dim OperatorCount As Long = 0
    Dim ValueCount As Long = 0
    Dim Depth As Long = 0
    Dim WantOperand As Boolean = True
    Dim OperandMinimum As Long = 1
    Dim Done As Boolean = False
    Dim Top As TraversalOperator
    While Done = False
        If TryPeekTraversalToken(Tokens, TokenCount, Cursor, Metrics) = False Then
            Exit Function
        End If
        Dim Kind As Long = 0
        If TryClassifyTraversalToken(Document, Cursor.Token, Kind, Metrics) = False Then
            Exit Function
        End If
        Dim Op As TraversalOperator
        Op.Kind = Kind
        Op.FirstByte = Cursor.Token.First.ByteOffset
        Op.LastByte = Cursor.Token.Last.ByteOffset
        Dim Span As TraversalSpan
        Span.FirstByte = Op.FirstByte
        Span.LastByte = Op.LastByte
        If WantOperand Then
            If Kind = 1 Or Kind = 2 Then
                If TryEmitTraversalCommand(Builder, Kind, Span, 0, Metrics, Failure) = False Then
                    Exit Function
                End If
                If ValueCount >= MaximumCommands Then
                    Call FailTraversal(Failure, 2, Cursor.Token)
                    Exit Function
                End If
                If TryPushTraversalSpan(Values, ValueCount, MaximumCommands, Span, Metrics) = False Then
                    Exit Function
                End If
                Call ConsumeTraversalToken(Cursor, Metrics)
                WantOperand = False
            Else
                If Kind = 12 Then
                    Kind = 4
                End If
                If Kind = 13 Then
                    Kind = 5
                End If
                If Kind <> -1 And TraversalIsPrefix(Kind) = False Then
                    Call FailTraversal(Failure, 101, Cursor.Token)
                    Exit Function
                End If
                If Kind = 6 And OperandMinimum > 6 Then
                    Call FailTraversal(Failure, 101, Cursor.Token)
                    Exit Function
                End If
                If Depth >= MaximumDepth Then
                    Call FailTraversal(Failure, 2, Cursor.Token)
                    Exit Function
                End If
                Op.Kind = Kind
                Op.Precedence = TraversalPrecedence(Kind)
                If OperatorCount >= MaximumCommands Then
                    Call FailTraversal(Failure, 2, Cursor.Token)
                    Exit Function
                End If
                If TryPushTraversalOperator(Operators, OperatorCount, MaximumCommands, Op, Metrics) = False Then
                    Exit Function
                End If
                Depth = Depth + 1
                If Depth > Metrics.MaximumDepth Then
                    Metrics.MaximumDepth = Depth
                End If
                If OperatorCount + ValueCount > Metrics.MaximumPending Then
                    Metrics.MaximumPending = OperatorCount + ValueCount
                End If
                If Kind = -1 Then
                    OperandMinimum = 1
                    Call ConsumeTraversalToken(Cursor, Metrics)
                Else
                    OperandMinimum = TraversalPrecedence(Kind)
                    If TryConsumeTraversalOperator(Document, Tokens, TokenCount, Cursor, Kind, Metrics, Failure) = False Then
                        Exit Function
                    End If
                End If
            End If
        Else
            If Kind = -2 Then
                Dim FoundOpen As Boolean = False
                While OperatorCount > 0 And FoundOpen = False
                    Top = Operators(OperatorCount - 1)
                    If Top.Kind = -1 Then
                        FoundOpen = True
                    Else
                        If TryReduceTraversal(Operators, OperatorCount, Values, ValueCount, Depth, Builder, Metrics, Failure) = False Then
                            Exit Function
                        End If
                    End If
                Wend
                If FoundOpen = False Then
                    Call FailTraversal(Failure, 103, Cursor.Token)
                    Exit Function
                End If
                Span = Values(ValueCount - 1)
                Span.FirstByte = Operators(OperatorCount - 1).FirstByte
                Span.LastByte = Cursor.Token.Last.ByteOffset
                If TryEmitTraversalCommand(Builder, 3, Span, 1, Metrics, Failure) = False Then
                    Exit Function
                End If
                Values(ValueCount - 1) = Span
                OperatorCount = OperatorCount - 1
                Depth = Depth - 1
                Metrics.Transitions = Metrics.Transitions + 1
                Call ConsumeTraversalToken(Cursor, Metrics)
            Else
                If Kind = -3 Then
                    Done = True
                Else
                    If Kind < 7 Or Kind > 30 Then
                        Call FailTraversal(Failure, 103, Cursor.Token)
                        Exit Function
                    End If
                    Op.Precedence = TraversalPrecedence(Kind)
                    Dim Reduce As Boolean = True
                    While OperatorCount > 0 And Reduce
                        Top = Operators(OperatorCount - 1)
                        Reduce = Top.Kind <> -1 And (Top.Precedence > Op.Precedence Or (Top.Precedence = Op.Precedence And Kind <> 7))
                        If Reduce Then
                            If Op.Precedence = 7 And Top.Precedence = 7 Then
                                Call FailTraversal(Failure, 103, Cursor.Token)
                                Exit Function
                            End If
                            If TryReduceTraversal(Operators, OperatorCount, Values, ValueCount, Depth, Builder, Metrics, Failure) = False Then
                                Exit Function
                            End If
                        End If
                    Wend
                    If Kind = 7 And Depth >= MaximumDepth Then
                        Call FailTraversal(Failure, 2, Cursor.Token)
                        Exit Function
                    End If
                    If OperatorCount >= MaximumCommands Then
                        Call FailTraversal(Failure, 2, Cursor.Token)
                        Exit Function
                    End If
                    If TryConsumeTraversalOperator(Document, Tokens, TokenCount, Cursor, Kind, Metrics, Failure) = False Then
                        Exit Function
                    End If
                    Op.Kind = Kind
                    If TryPushTraversalOperator(Operators, OperatorCount, MaximumCommands, Op, Metrics) = False Then
                        Exit Function
                    End If
                    If Kind = 7 Then
                        Depth = Depth + 1
                        OperandMinimum = 13
                    Else
                        OperandMinimum = Op.Precedence + 1
                    End If
                    WantOperand = True
                End If
            End If
        End If
        If Depth > Metrics.MaximumDepth Then
            Metrics.MaximumDepth = Depth
        End If
        If OperatorCount + ValueCount > Metrics.MaximumPending Then
            Metrics.MaximumPending = OperatorCount + ValueCount
        End If
    Wend
    While OperatorCount > 0
        If Operators(OperatorCount - 1).Kind = -1 Then
            Call FailTraversal(Failure, 102, Cursor.Token)
            Exit Function
        End If
        If TryReduceTraversal(Operators, OperatorCount, Values, ValueCount, Depth, Builder, Metrics, Failure) = False Then
            Exit Function
        End If
    Wend
    If ValueCount <> 1 Then
        Call FailTraversal(Failure, 101, Cursor.Token)
        Exit Function
    End If
    If TryFinishTraversal(Tokens, TokenCount, Cursor, Metrics, Failure) = False Then
        Exit Function
    End If
    Dim StorageFailure As SyntaxProbeFailure
    StorageFailure.Kind = 5
    StorageFailure.CommandIndex = -1
    If TryPublishSyntaxCommands(Builder, Commands, StorageFailure) = False Then
        Failure.Kind = StorageFailure.Kind
        Exit Function
    End If
    Failure.Kind = 0
    TryTraverseStack = True
End Function

Function TryTraversalWord(ByRef Document As SourceDocument, ByRef Token As SourceToken, ByVal Word As String, ByRef Matches As Boolean, ByRef Metrics As TraversalMetrics) As Boolean
    Metrics.Transitions = Metrics.Transitions + 1
    TryTraversalWord = TryMatchEnvelopeWord(Document.Bytes, Token.First.ByteOffset, Token.Last.ByteOffset, Word, Matches)
End Function

' Negative codes are open group, close group and logical end. Unknown is zero.
' Word matching uses the qualified Unicode simple-fold helper; no host casing.
Function TryClassifyTraversalToken(ByRef Document As SourceDocument, ByRef Token As SourceToken, ByRef Kind As Long, ByRef Metrics As TraversalMetrics) As Boolean
    TryClassifyTraversalToken = False
    Kind = 0
    Metrics.Transitions = Metrics.Transitions + 1
    If Token.Kind = 1 Or Token.Kind = 6 Then
        Kind = 1
        TryClassifyTraversalToken = True
        Exit Function
    End If
    If Token.Kind = 3 Or Token.Kind = 4 Or Token.Kind = 5 Then
        Kind = 2
        TryClassifyTraversalToken = True
        Exit Function
    End If
    If Token.Kind = 13 Or Token.Kind = 15 Then
        Kind = -3
        TryClassifyTraversalToken = True
        Exit Function
    End If
    If Token.Kind = 7 Then
        Dim Value As Long = -1
        If TryScannerByte(Document.Bytes, ByteStorageLength(Document.Bytes), Token.First.ByteOffset, Value) = False Then
            Exit Function
        End If
        Dim Width As Long = Token.Last.ByteOffset - Token.First.ByteOffset
        If Width = 1 Then
            If Value = 40 Then
                Kind = -1
            End If
            If Value = 41 Then
                Kind = -2
            End If
            If Value = 94 Then
                Kind = 7
            End If
            If Value = 42 Then
                Kind = 8
            End If
            If Value = 47 Then
                Kind = 9
            End If
            If Value = 92 Then
                Kind = 10
            End If
            If Value = 43 Then
                Kind = 12
            End If
            If Value = 45 Then
                Kind = 13
            End If
            If Value = 38 Then
                Kind = 14
            End If
            If Value = 61 Then
                Kind = 15
            End If
            If Value = 60 Then
                Kind = 17
            End If
            If Value = 62 Then
                Kind = 19
            End If
        Else
            If Width = 2 Then
                Dim NextByte As Long = -1
                If TryScannerByte(Document.Bytes, ByteStorageLength(Document.Bytes), Token.First.ByteOffset + 1, NextByte) = False Then
                    Exit Function
                End If
                If Value = 60 And NextByte = 62 Then
                    Kind = 16
                End If
                If Value = 60 And NextByte = 61 Then
                    Kind = 18
                End If
                If Value = 62 And NextByte = 61 Then
                    Kind = 20
                End If
            End If
        End If
        TryClassifyTraversalToken = True
        Exit Function
    End If
    If Token.Kind <> 2 Then
        TryClassifyTraversalToken = True
        Exit Function
    End If
    Dim Matches As Boolean = False
    If TryTraversalWord(Document, Token, "not", Matches, Metrics) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 6
        TryClassifyTraversalToken = True
        Exit Function
    End If
    If TryTraversalWord(Document, Token, "mod", Matches, Metrics) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 11
        TryClassifyTraversalToken = True
        Exit Function
    End If
    If TryTraversalWord(Document, Token, "like", Matches, Metrics) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 21
        TryClassifyTraversalToken = True
        Exit Function
    End If
    If TryTraversalWord(Document, Token, "is", Matches, Metrics) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 22
        TryClassifyTraversalToken = True
        Exit Function
    End If
    If TryTraversalWord(Document, Token, "isnot", Matches, Metrics) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 23
        TryClassifyTraversalToken = True
        Exit Function
    End If
    If TryTraversalWord(Document, Token, "and", Matches, Metrics) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 24
        TryClassifyTraversalToken = True
        Exit Function
    End If
    If TryTraversalWord(Document, Token, "andalso", Matches, Metrics) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 25
        TryClassifyTraversalToken = True
        Exit Function
    End If
    If TryTraversalWord(Document, Token, "or", Matches, Metrics) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 26
        TryClassifyTraversalToken = True
        Exit Function
    End If
    If TryTraversalWord(Document, Token, "orelse", Matches, Metrics) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 27
        TryClassifyTraversalToken = True
        Exit Function
    End If
    If TryTraversalWord(Document, Token, "xor", Matches, Metrics) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 28
        TryClassifyTraversalToken = True
        Exit Function
    End If
    If TryTraversalWord(Document, Token, "eqv", Matches, Metrics) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 29
        TryClassifyTraversalToken = True
        Exit Function
    End If
    If TryTraversalWord(Document, Token, "imp", Matches, Metrics) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 30
        TryClassifyTraversalToken = True
        Exit Function
    End If
    If TryTraversalWord(Document, Token, "true", Matches, Metrics) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 2
        TryClassifyTraversalToken = True
        Exit Function
    End If
    If TryTraversalWord(Document, Token, "false", Matches, Metrics) = False Then
        Exit Function
    End If
    If Matches Then
        Kind = 2
    End If
    TryClassifyTraversalToken = True
End Function

' Common event boundary; only private builder changes before final publication.
Function TryEmitTraversalCommand(ByRef Builder As SyntaxCommandBuilder, ByVal Kind As Long, ByRef Span As TraversalSpan, ByVal ChildCount As Long, ByRef Metrics As TraversalMetrics, ByRef Failure As TraversalFailure) As Boolean
    TryEmitTraversalCommand = False
    Dim StorageFailure As SyntaxProbeFailure
    StorageFailure.Kind = 5
    StorageFailure.CommandIndex = -1
    Metrics.Transitions = Metrics.Transitions + 1
    If TryAppendSyntaxCommand(Builder, Kind, Span.FirstByte, Span.LastByte, ChildCount, StorageFailure) = False Then
        Failure.Kind = StorageFailure.Kind
        Failure.FirstByte = Span.FirstByte
        Failure.LastByte = Span.LastByte
        Exit Function
    End If
    TryEmitTraversalCommand = True
End Function

Function TryFinishTraversal(ByRef Tokens() As SourceToken, ByVal Count As Long, ByRef Cursor As TraversalCursor, ByRef Metrics As TraversalMetrics, ByRef Failure As TraversalFailure) As Boolean
    TryFinishTraversal = False
    While Cursor.Index < Count
        If TryReadTraversalToken(Tokens, Count, Cursor.Index, Cursor.Token, Metrics) = False Then
            Exit Function
        End If
        Dim Kind As Long = Cursor.Token.Kind
        If Kind <> 8 And Kind <> 9 And Kind <> 10 And Kind <> 11 And Kind <> 12 And Kind <> 13 And Kind <> 15 Then
            Call FailTraversal(Failure, 103, Cursor.Token)
            Exit Function
        End If
        Call ConsumeTraversalToken(Cursor, Metrics)
    Wend
    TryFinishTraversal = True
End Function

' Precedence climbing has a bounded structural depth, not a limit on flat chains.
' FrameCount measures actual recursive calls separately from that shared depth.
' This is deliberately a separate candidate: no explicit operator/operand arrays.
Function TryTraversePrecedence(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByVal TokenCount As Long, ByRef Cursor As TraversalCursor, ByVal MinimumPrecedence As Long, ByVal Depth As Long, ByVal FrameCount As Long, ByVal MaximumDepth As Long, ByRef Builder As SyntaxCommandBuilder, ByRef Span As TraversalSpan, ByRef Metrics As TraversalMetrics, ByRef Failure As TraversalFailure) As Boolean
    TryTraversePrecedence = False
    Metrics.Transitions = Metrics.Transitions + 1
    If Depth > Metrics.MaximumDepth Then
        Metrics.MaximumDepth = Depth
    End If
    If FrameCount > Metrics.MaximumPending Then
        Metrics.MaximumPending = FrameCount
    End If
    If TryPeekTraversalToken(Tokens, TokenCount, Cursor, Metrics) = False Then
        Exit Function
    End If
    Dim Kind As Long = 0
    If TryClassifyTraversalToken(Document, Cursor.Token, Kind, Metrics) = False Then
        Exit Function
    End If
    Dim FirstByte As Long = Cursor.Token.First.ByteOffset
    If Kind = 1 Or Kind = 2 Then
        Span.FirstByte = FirstByte
        Span.LastByte = Cursor.Token.Last.ByteOffset
        If TryEmitTraversalCommand(Builder, Kind, Span, 0, Metrics, Failure) = False Then
            Exit Function
        End If
        Call ConsumeTraversalToken(Cursor, Metrics)
    Else
        If Kind = -1 Then
            If Depth >= MaximumDepth Then
                Call FailTraversal(Failure, 2, Cursor.Token)
                Exit Function
            End If
            If FrameCount >= TraversalFrameLimit() Then
                Call FailTraversal(Failure, 2, Cursor.Token)
                Exit Function
            End If
            If Depth + 1 > Metrics.MaximumDepth Then
                Metrics.MaximumDepth = Depth + 1
            End If
            Call ConsumeTraversalToken(Cursor, Metrics)
            If TryTraversePrecedence(Document, Tokens, TokenCount, Cursor, 1, Depth + 1, FrameCount + 1, MaximumDepth, Builder, Span, Metrics, Failure) = False Then
                Exit Function
            End If
            If TryPeekTraversalToken(Tokens, TokenCount, Cursor, Metrics) = False Then
                Exit Function
            End If
            If TryClassifyTraversalToken(Document, Cursor.Token, Kind, Metrics) = False Then
                Exit Function
            End If
            If Kind <> -2 Then
                Call FailTraversal(Failure, 102, Cursor.Token)
                Exit Function
            End If
            Span.FirstByte = FirstByte
            Span.LastByte = Cursor.Token.Last.ByteOffset
            If TryEmitTraversalCommand(Builder, 3, Span, 1, Metrics, Failure) = False Then
                Exit Function
            End If
            Call ConsumeTraversalToken(Cursor, Metrics)
        Else
            If Kind = 12 Then
                Kind = 4
            End If
            If Kind = 13 Then
                Kind = 5
            End If
            If TraversalIsPrefix(Kind) = False Then
                Call FailTraversal(Failure, 101, Cursor.Token)
                Exit Function
            End If
            If Kind = 6 And MinimumPrecedence > 6 Then
                Call FailTraversal(Failure, 101, Cursor.Token)
                Exit Function
            End If
            If Depth >= MaximumDepth Then
                Call FailTraversal(Failure, 2, Cursor.Token)
                Exit Function
            End If
            If FrameCount >= TraversalFrameLimit() Then
                Call FailTraversal(Failure, 2, Cursor.Token)
                Exit Function
            End If
            If Depth + 1 > Metrics.MaximumDepth Then
                Metrics.MaximumDepth = Depth + 1
            End If
            Dim Prefix As Long = Kind
            Dim PrefixPrecedence As Long = TraversalPrecedence(Kind)
            If TryConsumeTraversalOperator(Document, Tokens, TokenCount, Cursor, Kind, Metrics, Failure) = False Then
                Exit Function
            End If
            If TryTraversePrecedence(Document, Tokens, TokenCount, Cursor, PrefixPrecedence, Depth + 1, FrameCount + 1, MaximumDepth, Builder, Span, Metrics, Failure) = False Then
                Exit Function
            End If
            Span.FirstByte = FirstByte
            If TryEmitTraversalCommand(Builder, Prefix, Span, 1, Metrics, Failure) = False Then
                Exit Function
            End If
        End If
    End If
    Dim SeenComparison As Boolean = False
    Dim More As Boolean = True
    While More
        If TryPeekTraversalToken(Tokens, TokenCount, Cursor, Metrics) = False Then
            Exit Function
        End If
        If TryClassifyTraversalToken(Document, Cursor.Token, Kind, Metrics) = False Then
            Exit Function
        End If
        Dim Precedence As Long = TraversalPrecedence(Kind)
        More = Kind >= 7 And Kind <= 30 And Precedence >= MinimumPrecedence
        If More Then
            If Precedence = 7 Then
                If SeenComparison Then
                    Call FailTraversal(Failure, 103, Cursor.Token)
                    Exit Function
                End If
                SeenComparison = True
            End If
            Dim RightDepth As Long = Depth
            Dim RightMinimum As Long = Precedence + 1
            If Kind = 7 Then
                If Depth >= MaximumDepth Then
                    Call FailTraversal(Failure, 2, Cursor.Token)
                    Exit Function
                End If
                RightDepth = Depth + 1
                RightMinimum = Precedence
                If RightDepth > Metrics.MaximumDepth Then
                    Metrics.MaximumDepth = RightDepth
                End If
            End If
            If FrameCount >= TraversalFrameLimit() Then
                Call FailTraversal(Failure, 2, Cursor.Token)
                Exit Function
            End If
            If TryConsumeTraversalOperator(Document, Tokens, TokenCount, Cursor, Kind, Metrics, Failure) = False Then
                Exit Function
            End If
            Dim OperatorKind As Long = Kind
            Dim RightSpan As TraversalSpan
            If TryTraversePrecedence(Document, Tokens, TokenCount, Cursor, RightMinimum, RightDepth, FrameCount + 1, MaximumDepth, Builder, RightSpan, Metrics, Failure) = False Then
                Exit Function
            End If
            Span.LastByte = RightSpan.LastByte
            If TryEmitTraversalCommand(Builder, OperatorKind, Span, 2, Metrics, Failure) = False Then
                Exit Function
            End If
        End If
    Wend
    TryTraversePrecedence = True
End Function

Function TryTraverseRecursive(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByVal MaximumDepth As Long, ByVal MaximumCommands As Long, ByRef Commands() As SyntaxCommand, ByRef Failure As TraversalFailure, ByRef Metrics As TraversalMetrics) As Boolean
    TryTraverseRecursive = False
    Dim EmptyMetrics As TraversalMetrics
    Metrics = EmptyMetrics
    Failure.Kind = 1
    Failure.FirstByte = 0
    Failure.LastByte = 0
    Dim TokenCount As Long = ScannerTokenLength(Tokens)
    If MaximumDepth < 0 Or MaximumDepth > 256 Or MaximumCommands < 1 Or TokenCount < 2 Then
        Exit Function
    End If
    Failure.Kind = 5
    Dim Builder As SyntaxCommandBuilder
    Builder.MaximumRecords = MaximumCommands
    Dim Cursor As TraversalCursor
    Dim Span As TraversalSpan
    If TryTraversePrecedence(Document, Tokens, TokenCount, Cursor, 1, 0, 1, MaximumDepth, Builder, Span, Metrics, Failure) = False Then
        Exit Function
    End If
    If TryFinishTraversal(Tokens, TokenCount, Cursor, Metrics, Failure) = False Then
        Exit Function
    End If
    Dim StorageFailure As SyntaxProbeFailure
    StorageFailure.Kind = 5
    StorageFailure.CommandIndex = -1
    If TryPublishSyntaxCommands(Builder, Commands, StorageFailure) = False Then
        Failure.Kind = StorageFailure.Kind
        Exit Function
    End If
    Failure.Kind = 0
    TryTraverseRecursive = True
End Function
