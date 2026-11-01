UBE SOURCE 1 MODULE
Attribute UBE_Name = "SyntaxTree"

' Private compiler syntax storage. Source bytes and token arrays are borrowed,
' never retained or copied. The document owner keeps the source alive for all
' returned spans. One invocation owns pending storage; published values are
' immutable, and independent invocations may share only immutable input.
Type SyntaxNode
    Kind As Long
    FirstByte As Long
    LastByte As Long
    FirstChild As Long
    NextSibling As Long
    ChildCount As Long
End Type

Type SyntaxResult
    Nodes() As SyntaxNode
    NodeCount As Long
    Root As Long
    SourceId As Long
End Type

' Fresh failure status: 1 domain, 2 caller budget, 3 deferred, 5 storage/root
' admission; 101..107 are the contracted first syntax diagnostics. Callers seed
' Kind=5 before entry because managed admission can fail before the body runs.
Type SyntaxFailure
    Kind As Long
    FirstByte As Long
    LastByte As Long
End Type

' Counts executed record reads, state changes and spelling comparisons. NameReads
' counts comparison calls, not decoded scalars. Scanner/preflight costs are
' separate. Native observers additionally measure real allocation/copy/root work.
Type SyntaxMetrics
    TokenReads As Long
    Transitions As Long
    NameReads As Long
    MaximumPending As Long
    MaximumDepth As Long
End Type

Type SyntaxCursor
    Index As Long
    Token As SourceToken
    Ready As Boolean
    HadSpace As Boolean
    LastByte As Long
End Type

Type SyntaxState
    Pending() As SyntaxResult
    Count As Long
    MaximumNodes As Long
    MaximumPending As Long
    MaximumDepth As Long
    ActiveDepth As Long
    ControlPending As Long
    WithDepth As Long
    IfCondition As Boolean
    InlineElse As Boolean
    AmbiguousSuffixByte As Long
    TokenCount As Long
    SourceLength As Long
    Cursor As SyntaxCursor
    Metrics As SyntaxMetrics
    Failure As SyntaxFailure
End Type

' Returns the physical node-array count without changing its contents.
Intrinsic Function SyntaxNodeLength(ByRef Values() As SyntaxNode) As Long
Attribute SyntaxNodeLength.UBE_Primitive = "Array.Length"
End Function
' Prepares replacement node storage; failed allocation preserves the old array.
Intrinsic Function TryResizeSyntaxNodes(ByRef Values() As SyntaxNode, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeSyntaxNodes.UBE_Primitive = "Array.TryResize"
End Function
' Returns the physical count of complete owned result wrappers.
Intrinsic Function SyntaxResultLength(ByRef Values() As SyntaxResult) As Long
Attribute SyntaxResultLength.UBE_Primitive = "Array.Length"
End Function
' Prepares private result wrappers without exposing a partially built result.
Intrinsic Function TryResizeSyntaxResults(ByRef Values() As SyntaxResult, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeSyntaxResults.UBE_Primitive = "Array.TryResize"
End Function
' Atomically copies a complete owned result, preserving Destination on failure.
Intrinsic Function TryCopySyntaxResults(ByRef Destination() As SyntaxResult, ByRef Source() As SyntaxResult) As Boolean
Attribute TryCopySyntaxResults.UBE_Primitive = "Array.TryCopy"
End Function

' Capacity policy is checked before multiplication. A resource limit is distinct
' from allocation failure. Required=0 does not require storage.
Function TrySyntaxCapacity(ByVal Capacity As Long, ByVal Required As Long, ByVal Maximum As Long, ByRef Prepared As Long) As Boolean
    TrySyntaxCapacity = False
    Prepared = Capacity
    If Capacity < 0 Or Required < 0 Or Maximum < 0 Or Required > Maximum Then
        Exit Function
    End If
    If Required > Prepared Then
        If Prepared = 0 Then
            Prepared = 8
            If Prepared > Maximum Then
                Prepared = Maximum
            End If
        End If
        While Prepared < Required
            If Prepared > 1073741823 Then
                Prepared = Maximum
            Else
                Prepared = Prepared * 2
                If Prepared > Maximum Then
                    Prepared = Maximum
                End If
            End If
        Wend
    End If
    TrySyntaxCapacity = True
End Function

' Records the current original token extent as the first required failure.
Function SyntaxFail(ByRef State As SyntaxState, ByVal Kind As Long) As Boolean
    SyntaxFail = False
    State.Failure.Kind = Kind
    State.Failure.FirstByte = State.Cursor.Token.First.ByteOffset
    State.Failure.LastByte = State.Cursor.Token.Last.ByteOffset
End Function

' An actual token read is counted once even when several grammar decisions
' inspect the cached token. Only physical trivia is skipped. Logical newlines
' remain significant, and only space/continuation satisfies spacing1.
Function TrySyntaxPeek(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState) As Boolean
    TrySyntaxPeek = False
    If State.Cursor.Ready Then
        TrySyntaxPeek = True
        Exit Function
    End If
    State.Cursor.HadSpace = False
    While State.Cursor.Index < State.TokenCount
        State.Failure.Kind = 5
        Call CopyScannerToken(State.Cursor.Token, Tokens(State.Cursor.Index))
        State.Metrics.TokenReads = State.Metrics.TokenReads + 1
        Dim Kind As Long = State.Cursor.Token.Kind
        If Kind < 8 Or Kind > 12 Then
            State.Cursor.Ready = True
            TrySyntaxPeek = True
            Exit Function
        End If
        If Kind = 8 Or Kind = 11 Then
            State.Cursor.HadSpace = True
        End If
        State.Cursor.Index = State.Cursor.Index + 1
        State.Metrics.Transitions = State.Metrics.Transitions + 1
    Wend
    TrySyntaxPeek = SyntaxFail(State, 1)
End Function

' Advances rootless cursor state; root admission cannot silently prevent progress.
Sub SyntaxConsume(ByRef Cursor As SyntaxCursor, ByRef Metrics As SyntaxMetrics)
    Cursor.LastByte = Cursor.Token.Last.ByteOffset
    Cursor.Index = Cursor.Index + 1
    Cursor.Ready = False
    Metrics.Transitions = Metrics.Transitions + 1
End Sub

' ASCII grammar spellings compare with the already qualified Unicode folding
' helper. Fresh Boolean status prevents a root-admission failure becoming a miss.
Function TrySyntaxAt(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByVal Expected As String, ByRef Matches As Boolean) As Boolean
    TrySyntaxAt = False
    Matches = False
    State.Failure.Kind = 5
    If TrySyntaxPeek(Document, Tokens, State) = False Then
        Exit Function
    End If
    State.Metrics.NameReads = State.Metrics.NameReads + 1
    Dim AtByte As Long = State.Cursor.Token.First.ByteOffset
    Dim LastByte As Long = State.Cursor.Token.Last.ByteOffset
    Dim Index As Long = 0
    Dim ExpectedLength As Long = StringLength(Expected)
    While AtByte < LastByte And Index < ExpectedLength
        Dim Scalar As Long = 0
        Dim ScalarWidth As Long = 0
        If TryReadSourceScalar(Document.Bytes, AtByte, Scalar, ScalarWidth) = False Then
            Exit Function
        End If
        If SimpleFoldUnicode(Scalar) <> SimpleFoldUnicode(StringByteAt(Expected, Index)) Then
            TrySyntaxAt = True
            Exit Function
        End If
        AtByte = AtByte + ScalarWidth
        Index = Index + 1
    Wend
    Matches = AtByte = LastByte And Index = ExpectedLength
    TrySyntaxAt = True
End Function

' One rootless record write/read is a direct native observation boundary.
Sub WriteSyntaxNode(ByRef Destination As SyntaxNode, ByRef Original As SyntaxNode)
    Destination = Original
End Sub
' Reads one scalar-only node without retaining any managed value.
Sub ReadSyntaxNode(ByRef Destination As SyntaxNode, ByRef Original As SyntaxNode)
    Destination = Original
End Sub
' Links an already validated sibling in constant work, without copying subtrees.
Sub LinkSyntaxSibling(ByRef Node As SyntaxNode, ByVal Sibling As Long)
    Node.NextSibling = Sibling
End Sub

' Builds directly in the private result wrapper. No command stream, subtree
' copy, or public intermediate is created. Node identities are private indexes.
Function TrySyntaxNewNode(ByRef State As SyntaxState, ByVal Kind As Long, ByVal FirstByte As Long, ByVal LastByte As Long, ByRef NodeId As Long) As Boolean
    TrySyntaxNewNode = False
    NodeId = -1
    If Kind < 1 Or FirstByte < 0 Or LastByte < FirstByte Or LastByte > State.SourceLength Then
        TrySyntaxNewNode = SyntaxFail(State, 1)
        Exit Function
    End If
    If State.Count >= State.MaximumNodes Then
        TrySyntaxNewNode = SyntaxFail(State, 2)
        Exit Function
    End If
    State.Failure.Kind = 5
    Dim Capacity As Long = SyntaxNodeLength(State.Pending(0).Nodes)
    Dim Prepared As Long = 0
    If TrySyntaxCapacity(Capacity, State.Count + 1, State.MaximumNodes, Prepared) = False Then
        TrySyntaxNewNode = SyntaxFail(State, 2)
        Exit Function
    End If
    If Prepared <> Capacity Then
        If TryResizeSyntaxNodes(State.Pending(0).Nodes, Prepared, True) = False Then
            Exit Function
        End If
    End If
    Dim Node As SyntaxNode
    Node.Kind = Kind
    Node.FirstByte = FirstByte
    Node.LastByte = LastByte
    Node.FirstChild = -1
    Node.NextSibling = -1
    Call WriteSyntaxNode(State.Pending(0).Nodes(State.Count), Node)
    NodeId = State.Count
    State.Count = State.Count + 1
    State.Metrics.Transitions = State.Metrics.Transitions + 1
    TrySyntaxNewNode = True
End Function

' Tail is private construction state held by the parent frame. A caller can
' append each child once in constant work, regardless of the parent's width.
Function TrySyntaxAttach(ByRef State As SyntaxState, ByVal Parent As Long, ByVal Child As Long, ByRef Tail As Long) As Boolean
    TrySyntaxAttach = False
    If Parent < 0 Or Parent >= State.Count Or Child < 0 Or Child >= State.Count Or Parent = Child Then
        TrySyntaxAttach = SyntaxFail(State, 1)
        Exit Function
    End If
    Dim ChildNode As SyntaxNode
    Call ReadSyntaxNode(ChildNode, State.Pending(0).Nodes(Child))
    If ChildNode.NextSibling <> -1 Then
        TrySyntaxAttach = SyntaxFail(State, 1)
        Exit Function
    End If
    If Tail = -1 Then
        If State.Pending(0).Nodes(Parent).ChildCount <> 0 Then
            TrySyntaxAttach = SyntaxFail(State, 1)
            Exit Function
        End If
        State.Pending(0).Nodes(Parent).FirstChild = Child
    Else
        If Tail < 0 Or Tail >= State.Count Then
            TrySyntaxAttach = SyntaxFail(State, 1)
            Exit Function
        End If
        Call LinkSyntaxSibling(State.Pending(0).Nodes(Tail), Child)
    End If
    State.Pending(0).Nodes(Parent).ChildCount = State.Pending(0).Nodes(Parent).ChildCount + 1
    Tail = Child
    State.Metrics.Transitions = State.Metrics.Transitions + 1
    TrySyntaxAttach = True
End Function

' Token entry for callers which already hold qualified source/token views.
' EntryKind is an internal diagnostic entry: 1 expression, 2 statement, 3 unit.
' It establishes syntax only. No semantic, literal-value or codegen claim follows.
Function TryParseSyntax(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByVal EntryKind As Long, ByVal SourceId As Long, ByVal MaximumNodes As Long, ByVal MaximumPending As Long, ByVal MaximumDepth As Long, ByRef Published() As SyntaxResult, ByRef Failure As SyntaxFailure, ByRef Metrics As SyntaxMetrics) As Boolean
    TryParseSyntax = False
    Dim EmptyMetrics As SyntaxMetrics
    Metrics = EmptyMetrics
    Failure.Kind = 1
    Failure.FirstByte = 0
    Failure.LastByte = 0
    Dim TokenCount As Long = ScannerTokenLength(Tokens)
    Dim Length As Long = ByteStorageLength(Document.Bytes)
    If EntryKind < 1 Or EntryKind > 3 Or SourceId < 0 Or MaximumNodes < 0 Or MaximumPending < 0 Or MaximumDepth < 0 Then
        Exit Function
    End If
    If TokenCount < 2 Or TokenCount > 1048576 Or Length > 16777216 Then
        Exit Function
    End If
    Failure.Kind = 5
    Dim State As SyntaxState
    State.MaximumNodes = MaximumNodes
    State.MaximumPending = MaximumPending
    State.MaximumDepth = MaximumDepth
    State.TokenCount = TokenCount
    State.SourceLength = Length
    State.AmbiguousSuffixByte = -1
    State.Failure.Kind = 5
    If TryResizeSyntaxResults(State.Pending, 1, False) = False Then
        Exit Function
    End If
    Dim Root As Long = -1
    Dim Accepted As Boolean = False
    If EntryKind = 1 Then
        Accepted = TryParseSyntaxExpression(Document, Tokens, State, Root)
    Else
        Accepted = TryParseSyntaxGrammar(Document, Tokens, State, EntryKind, Root)
    End If
    If Accepted Then
        State.Failure.Kind = 5
        Accepted = TrySyntaxPeek(Document, Tokens, State)
        While Accepted And State.Cursor.Token.Kind = 13
            Call SyntaxConsume(State.Cursor, State.Metrics)
            Accepted = TrySyntaxPeek(Document, Tokens, State)
        Wend
        If Accepted Then
            If State.Cursor.Token.Kind <> 15 Then
                Accepted = SyntaxFail(State, 103)
            End If
        End If
    End If
    If Accepted Then
        State.Failure.Kind = 5
        Accepted = TryResizeSyntaxNodes(State.Pending(0).Nodes, State.Count, True)
        If Accepted Then
            State.Pending(0).NodeCount = State.Count
            State.Pending(0).Root = Root
            State.Pending(0).SourceId = SourceId
            Accepted = TryCopySyntaxResults(Published, State.Pending)
        End If
    End If
    Metrics = State.Metrics
    If Accepted Then
        Failure.Kind = 0
        Failure.FirstByte = 0
        Failure.LastByte = 0
        TryParseSyntax = True
    Else
        Failure = State.Failure
    End If
End Function
