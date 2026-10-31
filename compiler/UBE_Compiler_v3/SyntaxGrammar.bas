UBE SOURCE 1 MODULE
Attribute UBE_Name = "SyntaxGrammar"

' Grammar policy over borrowed source/token views. Pending nodes and explicit
' control frames belong to the invocation. No source payload is copied and no
' source-controlled recursion is used. The caller publishes only a complete tree.
Type SyntaxControlFrame
    Mode As Long
    Stage As Long
    Node As Long
    Tail As Long
    Body As Long
    BodyTail As Long
    EndKind As Long
    HasSeparator As Boolean
    SawElse As Boolean
    EnclosingElse As Boolean
End Type

' Returns frame-array capacity without copying its owned workspace.
Intrinsic Function SyntaxControlLength(ByRef Values() As SyntaxControlFrame) As Long
Attribute SyntaxControlLength.UBE_Primitive = "Array.Length"
End Function

' A frame is scalar-only. Capacity growth is geometric and every caller budget
' is checked before allocation. Frame copies retain no source or managed roots.
Function TryGrammarPush(ByRef Frames() As SyntaxControlFrame, ByRef Count As Long, ByRef Frame As SyntaxControlFrame, ByRef State As SyntaxState) As Boolean
    TryGrammarPush = False
    If Count >= State.MaximumPending Then
        TryGrammarPush = SyntaxFail(State, 2)
        Exit Function
    End If
    Dim Capacity As Long = SyntaxControlLength(Frames)
    Dim Prepared As Long = 0
    If TrySyntaxCapacity(Capacity, Count + 1, State.MaximumPending, Prepared) = False Then
        TryGrammarPush = SyntaxFail(State, 2)
        Exit Function
    End If
    If Prepared <> Capacity Then
        State.Failure.Kind = 5
        If TryResizeSyntaxControls(Frames, Prepared, True) = False Then
            Exit Function
        End If
    End If
    Frames(Count) = Frame
    Count = Count + 1
    State.ControlPending = Count
    If Count > State.Metrics.MaximumPending Then
        State.Metrics.MaximumPending = Count
    End If
    State.Metrics.Transitions = State.Metrics.Transitions + 1
    TryGrammarPush = True
End Function

' Only source nesting contributes to ActiveDepth; internal line-reader frames
' consume workspace budget independently and never masquerade as syntax depth.
Function TryGrammarEnterDepth(ByRef State As SyntaxState) As Boolean
    TryGrammarEnterDepth = False
    If State.ActiveDepth >= State.MaximumDepth Then
        TryGrammarEnterDepth = SyntaxFail(State, 2)
        Exit Function
    End If
    State.ActiveDepth = State.ActiveDepth + 1
    If State.ActiveDepth > State.Metrics.MaximumDepth Then
        State.Metrics.MaximumDepth = State.ActiveDepth
    End If
    TryGrammarEnterDepth = True
End Function

' Classifies deferred statement families without claiming their inner validity.
Function TryGrammarDeferred(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByRef Deferred As Boolean) As Boolean
    TryGrammarDeferred = False
    Deferred = False
    If TrySyntaxPeek(Document, Tokens, State) = False Then
        Exit Function
    End If
    Dim Matches As Boolean = False
    If TrySyntaxAt(Document, Tokens, State, "For", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Do", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Select", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "SyncLock", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "GoSub", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "On", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Resume", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Error", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Stop", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Asm", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Bytecode", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Load", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Unload", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "RaiseEvent", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "ReDim", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Erase", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Open", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Close", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Input", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Get", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Put", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Kill", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Name", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "FileCopy", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "ChDir", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "ChDrive", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "MkDir", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "RmDir", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Line", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Lock", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Unlock", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Write", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Width", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "SavePicture", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    TryGrammarDeferred = True
End Function

' Complete a compound terminator as one diagnostic extent. Invalid End pairs
' are not split into a deferred standalone End and a fabricated following call.
Function TryGrammarTerminator(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByVal EndKind As Long, ByRef FirstByte As Long, ByRef LastByte As Long) As Boolean
    TryGrammarTerminator = False
    If TrySyntaxPeek(Document, Tokens, State) = False Then
        Exit Function
    End If
    FirstByte = State.Cursor.Token.First.ByteOffset
    Dim Matches As Boolean = False
    If EndKind = 2 Then
        If TryGrammarTake(Document, Tokens, State, "Wend") = False Then
            Exit Function
        End If
        LastByte = State.Cursor.LastByte
        TryGrammarTerminator = True
        Exit Function
    End If
    If TryGrammarTake(Document, Tokens, State, "End") = False Then
        Exit Function
    End If
    If TryGrammarSpace(Document, Tokens, State) = False Then
        Exit Function
    End If
    If TrySyntaxPeek(Document, Tokens, State) = False Then
        Exit Function
    End If
    LastByte = State.Cursor.Token.Last.ByteOffset
    If EndKind = 1 Then
        If TrySyntaxAt(Document, Tokens, State, "If", Matches) = False Then
            Exit Function
        End If
    End If
    If EndKind = 3 Then
        If TrySyntaxAt(Document, Tokens, State, "With", Matches) = False Then
            Exit Function
        End If
    End If
    If EndKind = 4 Then
        If TrySyntaxAt(Document, Tokens, State, "Sub", Matches) = False Then
            Exit Function
        End If
        If Matches = False Then
            If TrySyntaxAt(Document, Tokens, State, "Function", Matches) = False Then
                Exit Function
            End If
        End If
    End If
    If EndKind = 5 Then
        If TrySyntaxAt(Document, Tokens, State, "Type", Matches) = False Then
            Exit Function
        End If
    End If
    If Matches = False Then
        State.Failure.Kind = 107
        State.Failure.FirstByte = FirstByte
        State.Failure.LastByte = LastByte
        Exit Function
    End If
    Call SyntaxConsume(State.Cursor, State.Metrics)
    TryGrammarTerminator = True
End Function

' Parses only an If/ElseIf condition under its contextual Then delimiter.
' Restoring the old flag is allocation-free and occurs on success and failure;
' the same expression parser keeps every legal member/postfix continuation.
Function TryGrammarIfCondition(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByRef Root As Long) As Boolean
    TryGrammarIfCondition = False
    Root = -1
    Dim PreviousCondition As Boolean = State.IfCondition
    Dim PreviousAmbiguity As Long = State.AmbiguousSuffixByte
    State.IfCondition = True
    State.AmbiguousSuffixByte = -1
    State.Failure.Kind = 5
    Dim Accepted As Boolean = TryParseSyntaxExpression(Document, Tokens, State, Root)
    If Accepted And State.AmbiguousSuffixByte >= 0 Then
        Dim HasThen As Boolean = False
        Accepted = TrySyntaxAt(Document, Tokens, State, "Then", HasThen)
        If Accepted And HasThen = False Then
            ' A spaced suffix/member boundary followed by a parenthesized body
            ' opener remains explicitly unresolved when the Bang interpretation
            ' leaves no real Then delimiter. Do not fabricate malformed syntax.
            State.Failure.Kind = 3
            State.Failure.FirstByte = State.AmbiguousSuffixByte
            State.Failure.LastByte = State.AmbiguousSuffixByte + 1
            Accepted = False
        End If
    End If
    State.IfCondition = PreviousCondition
    State.AmbiguousSuffixByte = PreviousAmbiguity
    TryGrammarIfCondition = Accepted
End Function

' Explicit continuation machine for statement lines, inline If branches and
' structured blocks. Mode1 owns a logical line, Mode2 an inline If, Mode4 a
' block. Returned carries exactly one completed child to its owning frame.
Function TryGrammarStatements(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByVal ProcedureBody As Boolean, ByRef Root As Long) As Boolean
    TryGrammarStatements = False
    Dim Frames() As SyntaxControlFrame
    Dim FrameCount As Long = 0
    Dim Initial As SyntaxControlFrame
    Initial.Mode = 1
    Initial.Node = -1
    Initial.Tail = -1
    Initial.Body = -1
    Initial.BodyTail = -1
    If ProcedureBody Then
        Initial.Mode = 4
        Initial.EndKind = 4
        Dim ProcedureFirst As Long = State.Cursor.LastByte
        If TrySyntaxPeek(Document, Tokens, State) = False Then
            Exit Function
        End If
        If TrySyntaxNewNode(State, 46, ProcedureFirst, ProcedureFirst, Initial.Body) = False Then
            Exit Function
        End If
    End If
    If TryGrammarPush(Frames, FrameCount, Initial, State) = False Then
        Exit Function
    End If
    Dim Returned As Long = -1
    Dim ReturnedLabel As Boolean = False
    While FrameCount > 0
        State.Metrics.Transitions = State.Metrics.Transitions + 1
        Dim Frame As SyntaxControlFrame = Frames(FrameCount - 1)
        If TrySyntaxPeek(Document, Tokens, State) = False Then
            Exit Function
        End If
        Dim Matches As Boolean = False
        Dim FirstByte As Long = State.Cursor.Token.First.ByteOffset
        If Frame.Mode = 1 Then
            If Returned >= 0 Then
                If Frame.Node < 0 Then
                    Frame.Node = Returned
                Else
                    If Frame.HasSeparator = False Then
                        Dim Wrapped As Long = -1
                        If TrySyntaxNewNode(State, 48, State.Pending(0).Nodes(Frame.Node).FirstByte, State.Pending(0).Nodes(Returned).LastByte, Wrapped) = False Then
                            Exit Function
                        End If
                        Dim WrappedTail As Long = -1
                        If TrySyntaxAttach(State, Wrapped, Frame.Node, WrappedTail) = False Then
                            Exit Function
                        End If
                        Frame.Node = Wrapped
                        Frame.Tail = WrappedTail
                        Frame.HasSeparator = True
                    End If
                    If TrySyntaxAttach(State, Frame.Node, Returned, Frame.Tail) = False Then
                        Exit Function
                    End If
                    State.Pending(0).Nodes(Frame.Node).LastByte = State.Pending(0).Nodes(Returned).LastByte
                End If
                Returned = -1
                Frame.Stage = 1
                Frame.EndKind = 0
                If ReturnedLabel Then
                    Frame.EndKind = 1
                End If
                ReturnedLabel = False
            End If
            If Frame.Stage = 1 Then
                If TrySyntaxAt(Document, Tokens, State, ":", Matches) = False Then
                    Exit Function
                End If
                If Matches Then
                    Call SyntaxConsume(State.Cursor, State.Metrics)
                    If Frame.HasSeparator = False Then
                        Dim ListNode As Long = -1
                        If TrySyntaxNewNode(State, 48, State.Pending(0).Nodes(Frame.Node).FirstByte, State.Cursor.LastByte, ListNode) = False Then
                            Exit Function
                        End If
                        Dim ListTail As Long = -1
                        If TrySyntaxAttach(State, ListNode, Frame.Node, ListTail) = False Then
                            Exit Function
                        End If
                        Frame.Node = ListNode
                        Frame.Tail = ListTail
                        Frame.HasSeparator = True
                    End If
                    State.Pending(0).Nodes(Frame.Node).LastByte = State.Cursor.LastByte
                    Frame.Stage = 0
                    If TrySyntaxPeek(Document, Tokens, State) = False Then
                        Exit Function
                    End If
                    If State.Cursor.Token.Kind = 13 Or State.Cursor.Token.Kind = 15 Then
                        Frame.Stage = 2
                    End If
                    If TrySyntaxAt(Document, Tokens, State, "Else", Matches) = False Then
                        Exit Function
                    End If
                    If Matches Then
                        Frame.Stage = 2
                    End If
                Else
                    Frame.Stage = 2
                    If Frame.EndKind = 1 And State.Cursor.Token.Kind <> 13 And State.Cursor.Token.Kind <> 15 Then
                        Frame.Stage = 0
                    End If
                End If
            End If
            If Frame.Stage = 2 Then
                Returned = Frame.Node
                FrameCount = FrameCount - 1
                State.ControlPending = FrameCount
            Else
                Frames(FrameCount - 1) = Frame
                If Frame.Node >= 0 Then
                    If TrySyntaxAt(Document, Tokens, State, ":", Matches) = False Then
                        Exit Function
                    End If
                    If Matches Then
                        TryGrammarStatements = SyntaxFail(State, 103)
                        Exit Function
                    End If
                End If
                Dim Deferred As Boolean = False
                If TryGrammarDeferred(Document, Tokens, State, Deferred) = False Then
                    Exit Function
                End If
                If Deferred Then
                    TryGrammarStatements = SyntaxFail(State, 3)
                    Exit Function
                End If
                If TrySyntaxAt(Document, Tokens, State, "End", Matches) = False Then
                    Exit Function
                End If
                If Matches Then
                    Call SyntaxConsume(State.Cursor, State.Metrics)
                    If TrySyntaxPeek(Document, Tokens, State) = False Then
                        Exit Function
                    End If
                    State.Failure.Kind = 3
                    State.Failure.FirstByte = FirstByte
                    State.Failure.LastByte = State.Cursor.LastByte
                    If State.Cursor.Token.Kind <> 13 And State.Cursor.Token.Kind <> 15 Then
                        State.Failure.Kind = 107
                        State.Failure.LastByte = State.Cursor.Token.Last.ByteOffset
                    End If
                    Exit Function
                End If
                Dim IfWord As Boolean = False
                Dim WhileWord As Boolean = False
                Dim WithWord As Boolean = False
                If TrySyntaxAt(Document, Tokens, State, "If", IfWord) = False Then
                    Exit Function
                End If
                If TrySyntaxAt(Document, Tokens, State, "While", WhileWord) = False Then
                    Exit Function
                End If
                If TrySyntaxAt(Document, Tokens, State, "With", WithWord) = False Then
                    Exit Function
                End If
                If IfWord Or WhileWord Or WithWord Then
                    If TryGrammarEnterDepth(State) = False Then
                        Exit Function
                    End If
                    Call SyntaxConsume(State.Cursor, State.Metrics)
                    If TryGrammarSpace(Document, Tokens, State) = False Then
                        Exit Function
                    End If
                    Dim Condition As Long = -1
                    Dim ConditionAccepted As Boolean = False
                    If IfWord Then
                        ConditionAccepted = TryGrammarIfCondition(Document, Tokens, State, Condition)
                    Else
                        ConditionAccepted = TryParseSyntaxExpression(Document, Tokens, State, Condition)
                    End If
                    If ConditionAccepted = False Then
                        Exit Function
                    End If
                    If IfWord Then
                        If TryGrammarSpacedTake(Document, Tokens, State, "Then") = False Then
                            Exit Function
                        End If
                    End If
                    If TrySyntaxPeek(Document, Tokens, State) = False Then
                        Exit Function
                    End If
                    Dim Control As SyntaxControlFrame
                    Control.Mode = 4
                    Control.Node = -1
                    Control.Tail = -1
                    Control.Body = -1
                    Control.BodyTail = -1
                    Dim ConstructKind As Long = 68
                    Control.EndKind = 1
                    If WhileWord Then
                        ConstructKind = 71
                        Control.EndKind = 2
                    End If
                    If WithWord Then
                        ConstructKind = 72
                        Control.EndKind = 3
                        State.WithDepth = State.WithDepth + 1
                    End If
                    If IfWord And State.Cursor.Token.Kind <> 13 Then
                        If TryGrammarSpace(Document, Tokens, State) = False Then
                            Exit Function
                        End If
                        Control.Mode = 2
                        ConstructKind = 67
                    End If
                    Control.EnclosingElse = False
                    If Control.Mode = 2 And FrameCount > 1 Then
                        ' Cache only the immediately enclosing inline branch's
                        ' available alternative. Structured blocks mask it; no
                        ' frame scan or depth-dependent context lookup occurs.
                        Dim EnclosingControl As SyntaxControlFrame = Frames(FrameCount - 2)
                        State.Metrics.Transitions = State.Metrics.Transitions + 1
                        If EnclosingControl.Mode = 2 Then
                            Control.EnclosingElse = EnclosingControl.Stage = 0 Or EnclosingControl.EnclosingElse
                        End If
                    End If
                    If TrySyntaxNewNode(State, ConstructKind, FirstByte, State.Pending(0).Nodes(Condition).LastByte, Control.Node) = False Then
                        Exit Function
                    End If
                    If TrySyntaxAttach(State, Control.Node, Condition, Control.Tail) = False Then
                        Exit Function
                    End If
                    If Control.Mode = 4 Then
                        If TryGrammarNewline(Document, Tokens, State) = False Then
                            Exit Function
                        End If
                        If TryGrammarSkipLines(Document, Tokens, State) = False Then
                            Exit Function
                        End If
                        Dim BodyAt As Long = State.Cursor.Token.First.ByteOffset
                        If TrySyntaxNewNode(State, 46, BodyAt, BodyAt, Control.Body) = False Then
                            Exit Function
                        End If
                        If TrySyntaxAttach(State, Control.Node, Control.Body, Control.Tail) = False Then
                            Exit Function
                        End If
                    End If
                    If TryGrammarPush(Frames, FrameCount, Control, State) = False Then
                        Exit Function
                    End If
                Else
                    ' Only this line's immediate inline-If parent makes Else a
                    ' possible delimiter. An outer inline If must not change
                    ' member spelling inside a nested While/With/block body.
                    Dim PreviousInlineElse As Boolean = State.InlineElse
                    State.InlineElse = False
                    State.Failure.Kind = 5
                    If FrameCount > 1 Then
                        Dim InlineParent As SyntaxControlFrame = Frames(FrameCount - 2)
                        State.Metrics.Transitions = State.Metrics.Transitions + 1
                        If InlineParent.Mode = 2 Then
                            State.InlineElse = InlineParent.Stage = 0 Or InlineParent.EnclosingElse
                        End If
                    End If
                    Dim StatementAccepted As Boolean = TryGrammarSimpleStatement(Document, Tokens, State, Frame.Node < 0, Returned, ReturnedLabel)
                    State.InlineElse = PreviousInlineElse
                    If StatementAccepted = False Then
                        Exit Function
                    End If
                End If
            End If
        Else
            If Frame.Mode = 2 Then
                If Returned >= 0 Then
                    If TrySyntaxAttach(State, Frame.Node, Returned, Frame.Tail) = False Then
                        Exit Function
                    End If
                    State.Pending(0).Nodes(Frame.Node).LastByte = State.Pending(0).Nodes(Returned).LastByte
                    Returned = -1
                    Frame.Stage = Frame.Stage + 1
                End If
                If Frame.Stage = 1 Then
                    If TrySyntaxAt(Document, Tokens, State, "Else", Matches) = False Then
                        Exit Function
                    End If
                    If Matches Then
                        If TryGrammarSpace(Document, Tokens, State) = False Then
                            Exit Function
                        End If
                        Call SyntaxConsume(State.Cursor, State.Metrics)
                        If TryGrammarSpace(Document, Tokens, State) = False Then
                            Exit Function
                        End If
                        Frame.Stage = 2
                    Else
                        Frame.Stage = 3
                    End If
                End If
                If Frame.Stage = 3 Then
                    Returned = Frame.Node
                    FrameCount = FrameCount - 1
                    State.ControlPending = FrameCount
                    State.ActiveDepth = State.ActiveDepth - 1
                Else
                    Frames(FrameCount - 1) = Frame
                    Dim BranchLine As SyntaxControlFrame
                    BranchLine.Mode = 1
                    BranchLine.Node = -1
                    BranchLine.Tail = -1
                    If TryGrammarPush(Frames, FrameCount, BranchLine, State) = False Then
                        Exit Function
                    End If
                End If
            Else
                If Returned >= 0 Then
                    If Frame.EndKind <> 4 And State.Pending(0).Nodes(Frame.Body).ChildCount = 0 Then
                        State.Pending(0).Nodes(Frame.Body).FirstByte = State.Pending(0).Nodes(Returned).FirstByte
                    End If
                    If TrySyntaxAttach(State, Frame.Body, Returned, Frame.BodyTail) = False Then
                        Exit Function
                    End If
                    State.Pending(0).Nodes(Frame.Body).LastByte = State.Pending(0).Nodes(Returned).LastByte
                    If Frame.Stage > 0 Then
                        State.Pending(0).Nodes(Frame.Stage - 1).LastByte = State.Pending(0).Nodes(Frame.Body).LastByte
                    End If
                    Returned = -1
                    If TryGrammarNewline(Document, Tokens, State) = False Then
                        Exit Function
                    End If
                End If
                If TryGrammarSkipLines(Document, Tokens, State) = False Then
                    Exit Function
                End If
                If State.Cursor.Token.Kind = 15 Then
                    TryGrammarStatements = SyntaxFail(State, 106)
                    Exit Function
                End If
                If Frame.EndKind <> 4 And State.Pending(0).Nodes(Frame.Body).ChildCount = 0 Then
                    State.Pending(0).Nodes(Frame.Body).FirstByte = State.Cursor.Token.First.ByteOffset
                    State.Pending(0).Nodes(Frame.Body).LastByte = State.Cursor.Token.First.ByteOffset
                End If
                If Frame.Stage > 0 Then
                    ' Empty Else/ElseIf bodies still own their zero-width end
                    ' boundary; retain it inside the enclosing part's extent.
                    State.Pending(0).Nodes(Frame.Stage - 1).LastByte = State.Pending(0).Nodes(Frame.Body).LastByte
                End If
                Dim EndWord As Boolean = False
                If TrySyntaxAt(Document, Tokens, State, "End", EndWord) = False Then
                    Exit Function
                End If
                Dim WendWord As Boolean = False
                If TrySyntaxAt(Document, Tokens, State, "Wend", WendWord) = False Then
                    Exit Function
                End If
                If EndWord Or WendWord Then
                    If Frame.EndKind = 4 Then
                        If State.Pending(0).Nodes(Frame.Body).ChildCount = 0 Then
                            State.Pending(0).Nodes(Frame.Body).FirstByte = State.Cursor.Token.First.ByteOffset
                        End If
                        State.Pending(0).Nodes(Frame.Body).LastByte = State.Cursor.Token.First.ByteOffset
                        Returned = Frame.Body
                        FrameCount = FrameCount - 1
                        State.ControlPending = FrameCount
                    Else
                        Dim EndFirst As Long = 0
                        Dim EndLast As Long = 0
                        If TryGrammarTerminator(Document, Tokens, State, Frame.EndKind, EndFirst, EndLast) = False Then
                            Exit Function
                        End If
                        State.Pending(0).Nodes(Frame.Node).LastByte = EndLast
                        Returned = Frame.Node
                        FrameCount = FrameCount - 1
                        State.ControlPending = FrameCount
                        State.ActiveDepth = State.ActiveDepth - 1
                        If Frame.EndKind = 3 Then
                            State.WithDepth = State.WithDepth - 1
                        End If
                    End If
                Else
                    Dim ElseWord As Boolean = False
                    Dim ElseIfWord As Boolean = False
                    If TrySyntaxAt(Document, Tokens, State, "Else", ElseWord) = False Then
                        Exit Function
                    End If
                    If TrySyntaxAt(Document, Tokens, State, "ElseIf", ElseIfWord) = False Then
                        Exit Function
                    End If
                    If ElseWord Or ElseIfWord Then
                        If Frame.EndKind <> 1 Or Frame.SawElse Then
                            TryGrammarStatements = SyntaxFail(State, 107)
                            Exit Function
                        End If
                        Dim PartFirst As Long = State.Cursor.Token.First.ByteOffset
                        Call SyntaxConsume(State.Cursor, State.Metrics)
                        Dim PartKind As Long = 70
                        If ElseIfWord Then
                            PartKind = 69
                        End If
                        Dim PartNode As Long = -1
                        Dim PartTail As Long = -1
                        If TrySyntaxNewNode(State, PartKind, PartFirst, PartFirst, PartNode) = False Then
                            Exit Function
                        End If
                        If ElseIfWord Then
                            Dim ElseCondition As Long = -1
                            If TryGrammarSpace(Document, Tokens, State) = False Then
                                Exit Function
                            End If
                            If TryGrammarIfCondition(Document, Tokens, State, ElseCondition) = False Then
                                Exit Function
                            End If
                            If TrySyntaxAttach(State, PartNode, ElseCondition, PartTail) = False Then
                                Exit Function
                            End If
                            If TryGrammarSpacedTake(Document, Tokens, State, "Then") = False Then
                                Exit Function
                            End If
                        Else
                            Frame.SawElse = True
                        End If
                        If TryGrammarNewline(Document, Tokens, State) = False Then
                            Exit Function
                        End If
                        If TryGrammarSkipLines(Document, Tokens, State) = False Then
                            Exit Function
                        End If
                        If TrySyntaxNewNode(State, 46, State.Cursor.Token.First.ByteOffset, State.Cursor.Token.First.ByteOffset, Frame.Body) = False Then
                            Exit Function
                        End If
                        Frame.BodyTail = -1
                        If TrySyntaxAttach(State, PartNode, Frame.Body, PartTail) = False Then
                            Exit Function
                        End If
                        If TrySyntaxAttach(State, Frame.Node, PartNode, Frame.Tail) = False Then
                            Exit Function
                        End If
                        ' The part extent is advanced with each child below.
                        Frame.Stage = PartNode + 1
                        Frames(FrameCount - 1) = Frame
                    Else
                        If Frame.Stage > 0 Then
                            State.Pending(0).Nodes(Frame.Stage - 1).LastByte = State.Pending(0).Nodes(Frame.Body).LastByte
                        End If
                        Frames(FrameCount - 1) = Frame
                        Dim BodyLine As SyntaxControlFrame
                        BodyLine.Mode = 1
                        BodyLine.Node = -1
                        BodyLine.Tail = -1
                        If TryGrammarPush(Frames, FrameCount, BodyLine, State) = False Then
                            Exit Function
                        End If
                    End If
                End If
            End If
        End If
    Wend
    Root = Returned
    TryGrammarStatements = Root >= 0
End Function

' Validates ordered parameters and retains each as an original-span leaf.
Function TryGrammarParameters(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByRef Root As Long) As Boolean
    TryGrammarParameters = False
    If TrySyntaxPeek(Document, Tokens, State) = False Then
        Exit Function
    End If
    Dim FirstByte As Long = State.Cursor.Token.First.ByteOffset
    If TryGrammarTake(Document, Tokens, State, "(") = False Then
        Exit Function
    End If
    If TrySyntaxNewNode(State, 47, FirstByte, FirstByte, Root) = False Then
        Exit Function
    End If
    Dim Tail As Long = -1
    Dim Matches As Boolean = False
    If TrySyntaxAt(Document, Tokens, State, ")", Matches) = False Then
        Exit Function
    End If
    Dim More As Boolean = Matches = False
    While More
        If TrySyntaxPeek(Document, Tokens, State) = False Then
            Exit Function
        End If
        Dim ParameterFirst As Long = State.Cursor.Token.First.ByteOffset
        Dim SavedCount As Long = State.Count
        If TrySyntaxAt(Document, Tokens, State, "Optional", Matches) = False Then
            Exit Function
        End If
        If Matches Then
            Call SyntaxConsume(State.Cursor, State.Metrics)
            If TryGrammarSpace(Document, Tokens, State) = False Then
                Exit Function
            End If
        End If
        If TrySyntaxAt(Document, Tokens, State, "ByVal", Matches) = False Then
            Exit Function
        End If
        If Matches = False Then
            If TrySyntaxAt(Document, Tokens, State, "ByRef", Matches) = False Then
                Exit Function
            End If
        End If
        If Matches = False Then
            If TrySyntaxAt(Document, Tokens, State, "ParamArray", Matches) = False Then
                Exit Function
            End If
        End If
        If Matches Then
            Call SyntaxConsume(State.Cursor, State.Metrics)
            If TryGrammarSpace(Document, Tokens, State) = False Then
                Exit Function
            End If
        End If
        Dim NameFirst As Long = 0
        Dim NameLast As Long = 0
        If TryGrammarTypedName(Document, Tokens, State, NameFirst, NameLast) = False Then
            Exit Function
        End If
        If TrySyntaxAt(Document, Tokens, State, "(", Matches) = False Then
            Exit Function
        End If
        If Matches Then
            If TryGrammarRank(Document, Tokens, State) = False Then
                Exit Function
            End If
        End If
        If TrySyntaxAt(Document, Tokens, State, "As", Matches) = False Then
            Exit Function
        End If
        If Matches Then
            If TryGrammarAs(Document, Tokens, State, False, False) = False Then
                Exit Function
            End If
        End If
        If TrySyntaxAt(Document, Tokens, State, "=", Matches) = False Then
            Exit Function
        End If
        If Matches Then
            Call SyntaxConsume(State.Cursor, State.Metrics)
            Dim DefaultNode As Long = -1
            If TryParseSyntaxExpression(Document, Tokens, State, DefaultNode) = False Then
                Exit Function
            End If
        End If
        Dim ParameterLast As Long = State.Cursor.LastByte
        State.Count = SavedCount
        Dim ParameterNode As Long = -1
        If TrySyntaxNewNode(State, 56, ParameterFirst, ParameterLast, ParameterNode) = False Then
            Exit Function
        End If
        If TrySyntaxAttach(State, Root, ParameterNode, Tail) = False Then
            Exit Function
        End If
        If TrySyntaxAt(Document, Tokens, State, ",", More) = False Then
            Exit Function
        End If
        If More Then
            Call SyntaxConsume(State.Cursor, State.Metrics)
        End If
    Wend
    If TryGrammarTake(Document, Tokens, State, ")") = False Then
        Exit Function
    End If
    State.Pending(0).Nodes(Root).LastByte = State.Cursor.LastByte
    TryGrammarParameters = True
End Function

' Builds procedure header, metadata, body and the written terminator.
Function TryGrammarProcedure(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByVal FirstByte As Long, ByVal IsIntrinsic As Boolean, ByRef Root As Long) As Boolean
    TryGrammarProcedure = False
    Dim IsFunction As Boolean = False
    If TrySyntaxAt(Document, Tokens, State, "Function", IsFunction) = False Then
        Exit Function
    End If
    Call SyntaxConsume(State.Cursor, State.Metrics)
    If TryGrammarSpace(Document, Tokens, State) = False Then
        Exit Function
    End If
    Dim NameFirst As Long = 0
    Dim NameLast As Long = 0
    Dim RawNameLast As Long = State.Cursor.Token.Last.ByteOffset
    If TryGrammarTypedName(Document, Tokens, State, NameFirst, NameLast) = False Then
        Exit Function
    End If
    If IsFunction = False And NameLast > RawNameLast Then
        State.Failure.Kind = 102
        State.Failure.FirstByte = RawNameLast
        State.Failure.LastByte = NameLast
        Exit Function
    End If
    Dim Kind As Long = 65
    If IsIntrinsic Then
        Kind = 66
    End If
    If TrySyntaxNewNode(State, Kind, FirstByte, NameLast, Root) = False Then
        Exit Function
    End If
    Dim RootTail As Long = -1
    Dim Header As Long = -1
    If TrySyntaxNewNode(State, 50, FirstByte, NameLast, Header) = False Then
        Exit Function
    End If
    If TrySyntaxAttach(State, Root, Header, RootTail) = False Then
        Exit Function
    End If
    Dim HeaderTail As Long = -1
    Dim NameNode As Long = -1
    If TrySyntaxNewNode(State, 1, NameFirst, NameLast, NameNode) = False Then
        Exit Function
    End If
    If TrySyntaxAttach(State, Header, NameNode, HeaderTail) = False Then
        Exit Function
    End If
    Dim Matches As Boolean = False
    If TrySyntaxAt(Document, Tokens, State, "(", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Dim Parameters As Long = -1
        If TryGrammarParameters(Document, Tokens, State, Parameters) = False Then
            Exit Function
        End If
        If TrySyntaxAttach(State, Header, Parameters, HeaderTail) = False Then
            Exit Function
        End If
    End If
    If TrySyntaxAt(Document, Tokens, State, "As", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        If IsFunction = False Then
            TryGrammarProcedure = SyntaxFail(State, 102)
            Exit Function
        End If
        Dim ResultFirst As Long = State.Cursor.Token.First.ByteOffset
        Dim SavedCount As Long = State.Count
        If TryGrammarAs(Document, Tokens, State, False, True) = False Then
            Exit Function
        End If
        Dim ResultLast As Long = State.Cursor.LastByte
        State.Count = SavedCount
        Dim ResultType As Long = -1
        If TrySyntaxNewNode(State, 57, ResultFirst, ResultLast, ResultType) = False Then
            Exit Function
        End If
        If TrySyntaxAttach(State, Header, ResultType, HeaderTail) = False Then
            Exit Function
        End If
    End If
    State.Pending(0).Nodes(Header).LastByte = State.Cursor.LastByte
    If TryGrammarNewline(Document, Tokens, State) = False Then
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Attribute", Matches) = False Then
        Exit Function
    End If
    While Matches
        Dim AttributeNode As Long = -1
        If TryGrammarAttribute(Document, Tokens, State, AttributeNode) = False Then
            Exit Function
        End If
        If TrySyntaxAttach(State, Root, AttributeNode, RootTail) = False Then
            Exit Function
        End If
        If TryGrammarNewline(Document, Tokens, State) = False Then
            Exit Function
        End If
        If TrySyntaxAt(Document, Tokens, State, "Attribute", Matches) = False Then
            Exit Function
        End If
    Wend
    If IsIntrinsic Then
        If TrySyntaxAt(Document, Tokens, State, "End", Matches) = False Then
            Exit Function
        End If
        If Matches = False Then
            Dim BadFirst As Long = State.Cursor.Token.First.ByteOffset
            Dim BadLast As Long = State.Cursor.Token.Last.ByteOffset
            ' The intrinsic body diagnostic covers the first complete logical
            ' statement rather than treating it as an implemented body.
            While State.Cursor.Token.Kind <> 13 And State.Cursor.Token.Kind <> 15
                BadLast = State.Cursor.Token.Last.ByteOffset
                Call SyntaxConsume(State.Cursor, State.Metrics)
                If TrySyntaxPeek(Document, Tokens, State) = False Then
                    Exit Function
                End If
            Wend
            State.Failure.Kind = 103
            State.Failure.FirstByte = BadFirst
            State.Failure.LastByte = BadLast
            Exit Function
        End If
    Else
        Dim Body As Long = -1
        If TryGrammarStatements(Document, Tokens, State, True, Body) = False Then
            Exit Function
        End If
        If TrySyntaxAttach(State, Root, Body, RootTail) = False Then
            Exit Function
        End If
    End If
    Dim EndFirst As Long = 0
    Dim EndLast As Long = 0
    If TryGrammarTerminator(Document, Tokens, State, 4, EndFirst, EndLast) = False Then
        Exit Function
    End If
    Dim EndMarker As Long = -1
    If TrySyntaxNewNode(State, 58, EndFirst, EndLast, EndMarker) = False Then
        Exit Function
    End If
    If TrySyntaxAttach(State, Root, EndMarker, RootTail) = False Then
        Exit Function
    End If
    State.Pending(0).Nodes(Root).LastByte = EndLast
    TryGrammarProcedure = True
End Function

' Distinguishes native representation headers from nonempty field-only Types.
Function TryGrammarType(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByVal FirstByte As Long, ByRef Root As Long) As Boolean
    TryGrammarType = False
    If TryGrammarTake(Document, Tokens, State, "Type") = False Then
        Exit Function
    End If
    If TryGrammarSpace(Document, Tokens, State) = False Then
        Exit Function
    End If
    Dim NameFirst As Long = 0
    Dim NameLast As Long = 0
    Dim RawNameLast As Long = State.Cursor.Token.Last.ByteOffset
    If TryGrammarTypedName(Document, Tokens, State, NameFirst, NameLast) = False Then
        Exit Function
    End If
    If NameLast > RawNameLast Then
        State.Failure.Kind = 102
        State.Failure.FirstByte = RawNameLast
        State.Failure.LastByte = NameLast
        Exit Function
    End If
    Dim Native As Boolean = False
    If TrySyntaxAt(Document, Tokens, State, "As", Native) = False Then
        Exit Function
    End If
    Dim Kind As Long = 63
    If Native Then
        Kind = 64
    End If
    If TrySyntaxNewNode(State, Kind, FirstByte, NameLast, Root) = False Then
        Exit Function
    End If
    Dim Tail As Long = -1
    Dim NameNode As Long = -1
    If TrySyntaxNewNode(State, 1, NameFirst, NameLast, NameNode) = False Then
        Exit Function
    End If
    If TrySyntaxAttach(State, Root, NameNode, Tail) = False Then
        Exit Function
    End If
    If Native Then
        Call SyntaxConsume(State.Cursor, State.Metrics)
        If TryGrammarSpace(Document, Tokens, State) = False Then
            Exit Function
        End If
        Dim Representation As Long = -1
        If TrySyntaxTypeName(Document, Tokens, State, Representation) = False Then
            Exit Function
        End If
        State.Pending(0).Nodes(Representation).Kind = 74
        If TrySyntaxAttach(State, Root, Representation, Tail) = False Then
            Exit Function
        End If
    End If
    If TryGrammarNewline(Document, Tokens, State) = False Then
        Exit Function
    End If
    Dim EndWord As Boolean = False
    If TrySyntaxAt(Document, Tokens, State, "End", EndWord) = False Then
        Exit Function
    End If
    If Native Then
        If EndWord = False Then
            TryGrammarType = SyntaxFail(State, 102)
            Exit Function
        End If
    Else
        If EndWord Then
            Dim BadFirst As Long = State.Cursor.Token.First.ByteOffset
            Call SyntaxConsume(State.Cursor, State.Metrics)
            If TrySyntaxPeek(Document, Tokens, State) = False Then
                Exit Function
            End If
            State.Failure.Kind = 104
            State.Failure.FirstByte = BadFirst
            State.Failure.LastByte = State.Cursor.Token.Last.ByteOffset
            Exit Function
        End If
        While EndWord = False
            If State.Cursor.Token.Kind = 15 Then
                TryGrammarType = SyntaxFail(State, 106)
                Exit Function
            End If
            Dim FieldFirst As Long = State.Cursor.Token.First.ByteOffset
            Dim FieldNode As Long = -1
            If TryGrammarVariable(Document, Tokens, State, FieldFirst, False, True, FieldNode) = False Then
                Exit Function
            End If
            If TrySyntaxAttach(State, Root, FieldNode, Tail) = False Then
                Exit Function
            End If
            If TryGrammarNewline(Document, Tokens, State) = False Then
                Exit Function
            End If
            If TrySyntaxAt(Document, Tokens, State, "End", EndWord) = False Then
                Exit Function
            End If
        Wend
    End If
    Dim EndFirst As Long = 0
    Dim EndLast As Long = 0
    If TryGrammarTerminator(Document, Tokens, State, 5, EndFirst, EndLast) = False Then
        Exit Function
    End If
    Dim Marker As Long = -1
    If TrySyntaxNewNode(State, 58, EndFirst, EndLast, Marker) = False Then
        Exit Function
    End If
    If TrySyntaxAttach(State, Root, Marker, Tail) = False Then
        Exit Function
    End If
    State.Pending(0).Nodes(Root).LastByte = EndLast
    TryGrammarType = True
End Function

' Dispatches module declarations before statements using canonical modifiers.
Function TryGrammarModuleItem(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByRef Root As Long) As Boolean
    TryGrammarModuleItem = False
    If TrySyntaxPeek(Document, Tokens, State) = False Then
        Exit Function
    End If
    Dim FirstByte As Long = State.Cursor.Token.First.ByteOffset
    Dim Matches As Boolean = False
    If TrySyntaxAt(Document, Tokens, State, "Option", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        TryGrammarModuleItem = TryGrammarOption(Document, Tokens, State, Root)
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Attribute", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        TryGrammarModuleItem = TryGrammarAttribute(Document, Tokens, State, Root)
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "End", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Dim EndFirst As Long = 0
        Dim EndLast As Long = 0
        If TryGrammarTerminator(Document, Tokens, State, 0, EndFirst, EndLast) = False Then
            Exit Function
        End If
        Exit Function
    End If
    Dim HasVisibility As Boolean = False
    If TrySyntaxAt(Document, Tokens, State, "Public", HasVisibility) = False Then
        Exit Function
    End If
    Dim PublicVisibility As Boolean = HasVisibility
    If HasVisibility = False Then
        If TrySyntaxAt(Document, Tokens, State, "Private", HasVisibility) = False Then
            Exit Function
        End If
    End If
    If HasVisibility = False Then
        If TrySyntaxAt(Document, Tokens, State, "Friend", HasVisibility) = False Then
            Exit Function
        End If
    End If
    If HasVisibility = False Then
        If TrySyntaxAt(Document, Tokens, State, "Global", HasVisibility) = False Then
            Exit Function
        End If
    End If
    If HasVisibility Then
        Call SyntaxConsume(State.Cursor, State.Metrics)
        If TryGrammarSpace(Document, Tokens, State) = False Then
            Exit Function
        End If
    End If
    If TrySyntaxAt(Document, Tokens, State, "Export", Matches) = False Then
        Exit Function
    End If
    Dim Exported As Boolean = Matches
    If Matches Then
        If PublicVisibility = False Then
            TryGrammarModuleItem = SyntaxFail(State, 102)
            Exit Function
        End If
        Call SyntaxConsume(State.Cursor, State.Metrics)
        If TryGrammarSpace(Document, Tokens, State) = False Then
            Exit Function
        End If
    End If
    If TrySyntaxAt(Document, Tokens, State, "Static", Matches) = False Then
        Exit Function
    End If
    Dim StaticModifier As Boolean = Matches
    If Matches Then
        If Exported Then
            TryGrammarModuleItem = SyntaxFail(State, 102)
            Exit Function
        End If
        Call SyntaxConsume(State.Cursor, State.Metrics)
        If TryGrammarSpace(Document, Tokens, State) = False Then
            Exit Function
        End If
    End If
    If TrySyntaxAt(Document, Tokens, State, "Inline", Matches) = False Then
        Exit Function
    End If
    Dim InlineModifier As Boolean = Matches
    If Matches = False Then
        If TrySyntaxAt(Document, Tokens, State, "ForceInline", Matches) = False Then
            Exit Function
        End If
        If Matches And Exported Then
            TryGrammarModuleItem = SyntaxFail(State, 102)
            Exit Function
        End If
    End If
    If Matches Then
        InlineModifier = True
    End If
    If Matches Then
        Call SyntaxConsume(State.Cursor, State.Metrics)
        If TryGrammarSpace(Document, Tokens, State) = False Then
            Exit Function
        End If
    End If
    Dim IsIntrinsic As Boolean = False
    If TrySyntaxAt(Document, Tokens, State, "Intrinsic", IsIntrinsic) = False Then
        Exit Function
    End If
    If IsIntrinsic Then
        If StaticModifier Or InlineModifier Or Exported Then
            TryGrammarModuleItem = SyntaxFail(State, 102)
            Exit Function
        End If
        Call SyntaxConsume(State.Cursor, State.Metrics)
        If TryGrammarSpace(Document, Tokens, State) = False Then
            Exit Function
        End If
    End If
    Dim ProcedureWord As Boolean = False
    If TrySyntaxAt(Document, Tokens, State, "Sub", ProcedureWord) = False Then
        Exit Function
    End If
    If ProcedureWord = False Then
        If TrySyntaxAt(Document, Tokens, State, "Function", ProcedureWord) = False Then
            Exit Function
        End If
    End If
    If ProcedureWord Then
        TryGrammarModuleItem = TryGrammarProcedure(Document, Tokens, State, FirstByte, IsIntrinsic, Root)
        Exit Function
    End If
    If IsIntrinsic Then
        TryGrammarModuleItem = SyntaxFail(State, 102)
        Exit Function
    End If
    If InlineModifier Or Exported Then
        TryGrammarModuleItem = SyntaxFail(State, 102)
        Exit Function
    End If
    If StaticModifier Then
        TryGrammarModuleItem = TryGrammarVariable(Document, Tokens, State, FirstByte, False, False, Root)
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Type", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        TryGrammarModuleItem = TryGrammarType(Document, Tokens, State, FirstByte, Root)
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Const", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Call SyntaxConsume(State.Cursor, State.Metrics)
        TryGrammarModuleItem = TryGrammarVariable(Document, Tokens, State, FirstByte, True, False, Root)
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Dim", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Call SyntaxConsume(State.Cursor, State.Metrics)
        TryGrammarModuleItem = TryGrammarVariable(Document, Tokens, State, FirstByte, False, False, Root)
        Exit Function
    End If
    If HasVisibility And (State.Cursor.Token.Kind = 1 Or State.Cursor.Token.Kind = 6) Then
        TryGrammarModuleItem = TryGrammarVariable(Document, Tokens, State, FirstByte, False, False, Root)
        Exit Function
    End If
    Dim Deferred As Boolean = False
    If TryGrammarDeferred(Document, Tokens, State, Deferred) = False Then
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "Enum", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Declare", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Property", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Default", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Interface", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Event", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "WithEvents", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "Implements", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "DefBool", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "DefByte", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "DefCur", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "DefDate", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "DefDbl", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "DefInt", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "DefLng", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "DefObj", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "DefSng", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "DefStr", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If TrySyntaxAt(Document, Tokens, State, "DefVar", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Deferred = True
    End If
    If Deferred Then
        TryGrammarModuleItem = SyntaxFail(State, 3)
    Else
        TryGrammarModuleItem = SyntaxFail(State, 103)
    End If
End Function

' Requires decimal source-format version 1 using its original spelling. Leading
' zeros retain the qualified envelope's existing meaning; suffixes and other
' numeric spellings are rejected without integer conversion or overflow. This
' is one spelling comparison; actual per-byte reads are observed separately as
' header/name work through the qualified byte reader, not token-based actions.
Function TryGrammarSourceVersion(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState) As Boolean
    TryGrammarSourceVersion = False
    If TryGrammarSpace(Document, Tokens, State) = False Then
        Exit Function
    End If
    If State.Cursor.Token.Kind <> 3 Then
        TryGrammarSourceVersion = SyntaxFail(State, 102)
        Exit Function
    End If
    Dim AtByte As Long = State.Cursor.Token.First.ByteOffset
    Dim LastByte As Long = State.Cursor.Token.Last.ByteOffset
    If AtByte >= LastByte Then
        TryGrammarSourceVersion = SyntaxFail(State, 102)
        Exit Function
    End If
    State.Metrics.NameReads = State.Metrics.NameReads + 1
    While AtByte < LastByte
        Dim Value As Long = -1
        State.Failure.Kind = 5
        If TryScannerByte(Document.Bytes, State.SourceLength, AtByte, Value) = False Then
            Exit Function
        End If
        Dim Expected As Long = 48
        If AtByte = LastByte - 1 Then
            Expected = 49
        End If
        If Value <> Expected Then
            TryGrammarSourceVersion = SyntaxFail(State, 102)
            Exit Function
        End If
        AtByte = AtByte + 1
    Wend
    Call SyntaxConsume(State.Cursor, State.Metrics)
    If TryGrammarSpace(Document, Tokens, State) = False Then
        Exit Function
    End If
    TryGrammarSourceVersion = True
End Function

' Consumes a native MODULE and preserves its entire immutable source extent.
Function TryGrammarUnit(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByRef Root As Long) As Boolean
    TryGrammarUnit = False
    If TrySyntaxPeek(Document, Tokens, State) = False Then
        Exit Function
    End If
    Dim FirstByte As Long = State.Cursor.Token.First.ByteOffset
    Dim Native As Boolean = False
    If TrySyntaxAt(Document, Tokens, State, "UBE", Native) = False Then
        Exit Function
    End If
    If Native = False Then
        TryGrammarUnit = SyntaxFail(State, 3)
        Exit Function
    End If
    If TryGrammarTake(Document, Tokens, State, "UBE") = False Then
        Exit Function
    End If
    If TryGrammarSpacedTake(Document, Tokens, State, "SOURCE") = False Then
        Exit Function
    End If
    If TryGrammarSourceVersion(Document, Tokens, State) = False Then
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "MODULE", Native) = False Then
        Exit Function
    End If
    If Native = False Then
        TryGrammarUnit = SyntaxFail(State, 3)
        Exit Function
    End If
    If TryGrammarSpace(Document, Tokens, State) = False Then
        Exit Function
    End If
    Call SyntaxConsume(State.Cursor, State.Metrics)
    If TryGrammarNewline(Document, Tokens, State) = False Then
        Exit Function
    End If
    If TryGrammarTake(Document, Tokens, State, "Attribute") = False Then
        Exit Function
    End If
    If TryGrammarSpacedTake(Document, Tokens, State, "UBE_Name") = False Then
        Exit Function
    End If
    If TryGrammarTake(Document, Tokens, State, "=") = False Then
        Exit Function
    End If
    If TrySyntaxPeek(Document, Tokens, State) = False Then
        Exit Function
    End If
    If State.Cursor.Token.Kind <> 5 Then
        TryGrammarUnit = SyntaxFail(State, 102)
        Exit Function
    End If
    Call SyntaxConsume(State.Cursor, State.Metrics)
    If TryGrammarNewline(Document, Tokens, State) = False Then
        Exit Function
    End If
    Dim HeaderLast As Long = State.Cursor.LastByte
    If TrySyntaxNewNode(State, 45, FirstByte, State.SourceLength, Root) = False Then
        Exit Function
    End If
    Dim Tail As Long = -1
    Dim Header As Long = -1
    If TrySyntaxNewNode(State, 50, FirstByte, HeaderLast, Header) = False Then
        Exit Function
    End If
    If TrySyntaxAttach(State, Root, Header, Tail) = False Then
        Exit Function
    End If
    If TryGrammarSkipLines(Document, Tokens, State) = False Then
        Exit Function
    End If
    While State.Cursor.Token.Kind <> 15
        Dim Item As Long = -1
        If TryGrammarModuleItem(Document, Tokens, State, Item) = False Then
            Exit Function
        End If
        If TrySyntaxAttach(State, Root, Item, Tail) = False Then
            Exit Function
        End If
        If TryGrammarNewline(Document, Tokens, State) = False Then
            Exit Function
        End If
        If TryGrammarSkipLines(Document, Tokens, State) = False Then
            Exit Function
        End If
    Wend
    TryGrammarUnit = True
End Function

' Routes statement/unit requests without publishing private pending syntax.
Function TryParseSyntaxGrammar(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByVal EntryKind As Long, ByRef Root As Long) As Boolean
    TryParseSyntaxGrammar = False
    Root = -1
    If EntryKind = 3 Then
        TryParseSyntaxGrammar = TryGrammarUnit(Document, Tokens, State, Root)
    Else
        If EntryKind = 2 Then
            TryParseSyntaxGrammar = TryGrammarStatements(Document, Tokens, State, False, Root)
        Else
            TryParseSyntaxGrammar = SyntaxFail(State, 1)
        End If
    End If
End Function
' Replaces frame storage atomically through the bounded array primitive.
Intrinsic Function TryResizeSyntaxControls(ByRef Values() As SyntaxControlFrame, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeSyntaxControls.UBE_Primitive = "Array.TryResize"
End Function

' Requires one exact folded grammar token and advances only after a match.
Function TryGrammarTake(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByVal Expected As String) As Boolean
    TryGrammarTake = False
    Dim Matches As Boolean = False
    If TrySyntaxAt(Document, Tokens, State, Expected, Matches) = False Then
        Exit Function
    End If
    If Matches = False Then
        TryGrammarTake = SyntaxFail(State, 102)
        Exit Function
    End If
    Call SyntaxConsume(State.Cursor, State.Metrics)
    TryGrammarTake = True
End Function

' Enforces the grammar's spacing1 without skipping a logical line terminator.
Function TryGrammarSpace(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState) As Boolean
    TryGrammarSpace = False
    If TrySyntaxPeek(Document, Tokens, State) = False Then
        Exit Function
    End If
    If State.Cursor.HadSpace = False Then
        TryGrammarSpace = SyntaxFail(State, 102)
        Exit Function
    End If
    TryGrammarSpace = True
End Function

' Requires a word token at a spacing1 boundary, preserving original trivia.
Function TryGrammarSpacedTake(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByVal Expected As String) As Boolean
    TryGrammarSpacedTake = False
    If TryGrammarSpace(Document, Tokens, State) = False Then
        Exit Function
    End If
    TryGrammarSpacedTake = TryGrammarTake(Document, Tokens, State, Expected)
End Function

' Requires a physical or scanner-supplied logical newline.
Function TryGrammarNewline(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState) As Boolean
    TryGrammarNewline = False
    If TrySyntaxPeek(Document, Tokens, State) = False Then
        Exit Function
    End If
    If State.Cursor.Token.Kind <> 13 Then
        TryGrammarNewline = SyntaxFail(State, 102)
        Exit Function
    End If
    Call SyntaxConsume(State.Cursor, State.Metrics)
    TryGrammarNewline = True
End Function

' Skips complete empty/comment lines while preserving original source bytes.
Function TryGrammarSkipLines(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState) As Boolean
    TryGrammarSkipLines = False
    If TrySyntaxPeek(Document, Tokens, State) = False Then
        Exit Function
    End If
    While State.Cursor.Token.Kind = 13
        Call SyntaxConsume(State.Cursor, State.Metrics)
        If TrySyntaxPeek(Document, Tokens, State) = False Then
            Exit Function
        End If
    Wend
    TryGrammarSkipLines = True
End Function

' Suffixes are retained in the typed-name extent, while name identity remains
' independent. Only an immediately adjacent scalar type character is consumed.
Function TryGrammarTypedName(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByRef FirstByte As Long, ByRef LastByte As Long) As Boolean
    TryGrammarTypedName = False
    If TrySyntaxPeek(Document, Tokens, State) = False Then
        Exit Function
    End If
    If State.Cursor.Token.Kind <> 1 And State.Cursor.Token.Kind <> 6 Then
        TryGrammarTypedName = SyntaxFail(State, 104)
        Exit Function
    End If
    FirstByte = State.Cursor.Token.First.ByteOffset
    LastByte = State.Cursor.Token.Last.ByteOffset
    Call SyntaxConsume(State.Cursor, State.Metrics)
    If TrySyntaxPeek(Document, Tokens, State) = False Then
        Exit Function
    End If
    If State.Cursor.Token.Kind = 7 And State.Cursor.Token.First.ByteOffset = LastByte And State.Cursor.Token.Last.ByteOffset = LastByte + 1 Then
        Dim Character As Long = Document.Bytes(LastByte)
        If Character = 37 Or Character = 38 Or Character = 94 Or Character = 33 Or Character = 35 Or Character = 64 Or Character = 36 Then
            LastByte = State.Cursor.Token.Last.ByteOffset
            Call SyntaxConsume(State.Cursor, State.Metrics)
        End If
    End If
    TryGrammarTypedName = True
End Function

' Accepts rank punctuation independently of later type and rank restrictions.
Function TryGrammarRank(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState) As Boolean
    TryGrammarRank = False
    If TryGrammarTake(Document, Tokens, State, "(") = False Then
        Exit Function
    End If
    Dim Comma As Boolean = False
    If TrySyntaxAt(Document, Tokens, State, ",", Comma) = False Then
        Exit Function
    End If
    While Comma
        Call SyntaxConsume(State.Cursor, State.Metrics)
        If TrySyntaxAt(Document, Tokens, State, ",", Comma) = False Then
            Exit Function
        End If
    Wend
    TryGrammarRank = TryGrammarTake(Document, Tokens, State, ")")
End Function

' Declaration array syntax has either rank punctuation or complete bounds;
' numeric expressions are never accepted as a parameter rank.
Function TryGrammarArray(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByVal RankOnly As Boolean) As Boolean
    TryGrammarArray = False
    If RankOnly Then
        TryGrammarArray = TryGrammarRank(Document, Tokens, State)
        Exit Function
    End If
    If TryGrammarTake(Document, Tokens, State, "(") = False Then
        Exit Function
    End If
    Dim Matches As Boolean = False
    If TrySyntaxAt(Document, Tokens, State, ")", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Call SyntaxConsume(State.Cursor, State.Metrics)
        TryGrammarArray = True
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, ",", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        While Matches
            Call SyntaxConsume(State.Cursor, State.Metrics)
            If TrySyntaxAt(Document, Tokens, State, ",", Matches) = False Then
                Exit Function
            End If
        Wend
        TryGrammarArray = TryGrammarTake(Document, Tokens, State, ")")
        Exit Function
    End If
    Dim More As Boolean = True
    Dim Ignored As Long = -1
    While More
        If TryParseSyntaxExpression(Document, Tokens, State, Ignored) = False Then
            Exit Function
        End If
        If TrySyntaxAt(Document, Tokens, State, "To", Matches) = False Then
            Exit Function
        End If
        If Matches Then
            If TryGrammarSpace(Document, Tokens, State) = False Then
                Exit Function
            End If
            Call SyntaxConsume(State.Cursor, State.Metrics)
            If TryGrammarSpace(Document, Tokens, State) = False Then
                Exit Function
            End If
            If TryParseSyntaxExpression(Document, Tokens, State, Ignored) = False Then
                Exit Function
            End If
        End If
        If TrySyntaxAt(Document, Tokens, State, ",", More) = False Then
            Exit Function
        End If
        If More Then
            Call SyntaxConsume(State.Cursor, State.Metrics)
        End If
    Wend
    TryGrammarArray = TryGrammarTake(Document, Tokens, State, ")")
End Function

' Validates an As type phrase with the caller-permitted New/result rank.
Function TryGrammarAs(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByVal AllowNew As Boolean, ByVal AllowRank As Boolean) As Boolean
    TryGrammarAs = False
    If TryGrammarSpacedTake(Document, Tokens, State, "As") = False Then
        Exit Function
    End If
    If TryGrammarSpace(Document, Tokens, State) = False Then
        Exit Function
    End If
    Dim Matches As Boolean = False
    If AllowNew Then
        If TrySyntaxAt(Document, Tokens, State, "New", Matches) = False Then
            Exit Function
        End If
        If Matches Then
            Call SyntaxConsume(State.Cursor, State.Metrics)
            If TryGrammarSpace(Document, Tokens, State) = False Then
                Exit Function
            End If
        End If
    End If
    Dim Ignored As Long = -1
    If TrySyntaxTypeName(Document, Tokens, State, Ignored) = False Then
        Exit Function
    End If
    If AllowRank Then
        If TrySyntaxAt(Document, Tokens, State, "(", Matches) = False Then
            Exit Function
        End If
        If Matches Then
            If TryGrammarRank(Document, Tokens, State) = False Then
                Exit Function
            End If
        End If
    End If
    TryGrammarAs = True
End Function

' Declaration internals are validated directly; the logical leaf retains their
' exact original spelling. Temporary validation nodes are never published.
Function TryGrammarVariable(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByVal FirstByte As Long, ByVal IsConstant As Boolean, ByVal IsField As Boolean, ByRef Root As Long) As Boolean
    TryGrammarVariable = False
    Dim SavedCount As Long = State.Count
    Dim More As Boolean = True
    Dim NameFirst As Long = 0
    Dim NameLast As Long = 0
    Dim Matches As Boolean = False
    Dim Ignored As Long = -1
    Dim FirstItem As Boolean = True
    While More
        If TrySyntaxPeek(Document, Tokens, State) = False Then
            Exit Function
        End If
        Dim RawNameEnd As Long = State.Cursor.Token.Last.ByteOffset
        If FirstItem And IsField = False Then
            If TryGrammarSpace(Document, Tokens, State) = False Then
                Exit Function
            End If
        End If
        FirstItem = False
        If TryGrammarTypedName(Document, Tokens, State, NameFirst, NameLast) = False Then
            Exit Function
        End If
        If TrySyntaxAt(Document, Tokens, State, "(", Matches) = False Then
            Exit Function
        End If
        If Matches Then
            If IsConstant Then
                TryGrammarVariable = SyntaxFail(State, 102)
                Exit Function
            End If
            If TryGrammarArray(Document, Tokens, State, False) = False Then
                Exit Function
            End If
        End If
        If TrySyntaxAt(Document, Tokens, State, "As", Matches) = False Then
            Exit Function
        End If
        If Matches Then
            If TryGrammarAs(Document, Tokens, State, IsField = False, False) = False Then
                Exit Function
            End If
        Else
            If IsField And NameLast = RawNameEnd Then
                TryGrammarVariable = SyntaxFail(State, 102)
                Exit Function
            End If
        End If
        If TrySyntaxAt(Document, Tokens, State, "=", Matches) = False Then
            Exit Function
        End If
        If Matches Then
            If IsField Then
                TryGrammarVariable = SyntaxFail(State, 103)
                Exit Function
            End If
            Call SyntaxConsume(State.Cursor, State.Metrics)
            If TryParseSyntaxExpression(Document, Tokens, State, Ignored) = False Then
                Exit Function
            End If
        Else
            If IsConstant Then
                TryGrammarVariable = SyntaxFail(State, 102)
                Exit Function
            End If
        End If
        If TrySyntaxAt(Document, Tokens, State, ",", More) = False Then
            Exit Function
        End If
        If IsField And More Then
            TryGrammarVariable = SyntaxFail(State, 102)
            Exit Function
        End If
        If More Then
            Call SyntaxConsume(State.Cursor, State.Metrics)
        End If
    Wend
    Dim LastByte As Long = State.Cursor.LastByte
    State.Count = SavedCount
    Dim NodeKind As Long = 54
    If IsConstant Then
        NodeKind = 55
    End If
    If IsField Then
        NodeKind = 53
    End If
    TryGrammarVariable = TrySyntaxNewNode(State, NodeKind, FirstByte, LastByte, Root)
End Function

' Retains inert metadata after validating its qualified target and values.
Function TryGrammarAttribute(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByRef Root As Long) As Boolean
    TryGrammarAttribute = False
    If TrySyntaxPeek(Document, Tokens, State) = False Then
        Exit Function
    End If
    Dim FirstByte As Long = State.Cursor.Token.First.ByteOffset
    Dim SavedCount As Long = State.Count
    If TryGrammarTake(Document, Tokens, State, "Attribute") = False Then
        Exit Function
    End If
    If TryGrammarSpace(Document, Tokens, State) = False Then
        Exit Function
    End If
    Dim Ignored As Long = -1
    If TrySyntaxQualifiedName(Document, Tokens, State, Ignored) = False Then
        Exit Function
    End If
    If TryGrammarTake(Document, Tokens, State, "=") = False Then
        Exit Function
    End If
    Dim More As Boolean = True
    While More
        If TrySyntaxPeek(Document, Tokens, State) = False Then
            Exit Function
        End If
        Dim TokenKind As Long = State.Cursor.Token.Kind
        Dim DateCandidate As Boolean = TokenKind = 14
        Dim Matches As Boolean = False
        If DateCandidate = False Then
            If TrySyntaxAt(Document, Tokens, State, "#", DateCandidate) = False Then
                Exit Function
            End If
        End If
        If DateCandidate Then
            Dim DateFirst As Long = 0
            Dim DateLast As Long = 0
            If TrySyntaxDateLiteral(Document, Tokens, State, DateFirst, DateLast) = False Then
                Exit Function
            End If
        Else
            Dim Signed As Boolean = False
            If TrySyntaxAt(Document, Tokens, State, "+", Signed) = False Then
                Exit Function
            End If
            If Signed = False Then
                If TrySyntaxAt(Document, Tokens, State, "-", Signed) = False Then
                    Exit Function
                End If
            End If
            If Signed Then
                Call SyntaxConsume(State.Cursor, State.Metrics)
                If TrySyntaxPeek(Document, Tokens, State) = False Then
                    Exit Function
                End If
                TokenKind = State.Cursor.Token.Kind
                If TokenKind <> 3 And TokenKind <> 4 Then
                    TryGrammarAttribute = SyntaxFail(State, 102)
                    Exit Function
                End If
            End If
            Dim Allowed As Boolean = TokenKind = 1 Or TokenKind = 3 Or TokenKind = 4 Or TokenKind = 5 Or TokenKind = 6
            If TokenKind = 2 Then
                If TrySyntaxAt(Document, Tokens, State, "True", Matches) = False Then
                    Exit Function
                End If
                Allowed = Matches
                If TrySyntaxAt(Document, Tokens, State, "False", Matches) = False Then
                    Exit Function
                End If
                If Matches Then
                    Allowed = True
                End If
                If TrySyntaxAt(Document, Tokens, State, "Nothing", Matches) = False Then
                    Exit Function
                End If
                If Matches Then
                    Allowed = True
                End If
                If TrySyntaxAt(Document, Tokens, State, "Null", Matches) = False Then
                    Exit Function
                End If
                If Matches Then
                    Allowed = True
                End If
                If TrySyntaxAt(Document, Tokens, State, "Empty", Matches) = False Then
                    Exit Function
                End If
                If Matches Then
                    Allowed = True
                End If
            End If
            If Allowed = False Then
                TryGrammarAttribute = SyntaxFail(State, 102)
                Exit Function
            End If
            Call SyntaxConsume(State.Cursor, State.Metrics)
        End If
        If TrySyntaxAt(Document, Tokens, State, ",", More) = False Then
            Exit Function
        End If
        If More Then
            Call SyntaxConsume(State.Cursor, State.Metrics)
        End If
    Wend
    Dim LastByte As Long = State.Cursor.LastByte
    State.Count = SavedCount
    TryGrammarAttribute = TrySyntaxNewNode(State, 52, FirstByte, LastByte, Root)
End Function

' Recognizes option spellings while leaving semantic policy to later checking.
Function TryGrammarOption(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByRef Root As Long) As Boolean
    TryGrammarOption = False
    Dim FirstByte As Long = State.Cursor.Token.First.ByteOffset
    If TryGrammarTake(Document, Tokens, State, "Option") = False Then
        Exit Function
    End If
    If TryGrammarSpace(Document, Tokens, State) = False Then
        Exit Function
    End If
    Dim Matches As Boolean = False
    If TrySyntaxAt(Document, Tokens, State, "Explicit", Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Call SyntaxConsume(State.Cursor, State.Metrics)
        If TrySyntaxAt(Document, Tokens, State, "On", Matches) = False Then
            Exit Function
        End If
        If Matches Then
            Call SyntaxConsume(State.Cursor, State.Metrics)
        Else
            If TrySyntaxAt(Document, Tokens, State, "Off", Matches) = False Then
                Exit Function
            End If
            If Matches Then
                Call SyntaxConsume(State.Cursor, State.Metrics)
            End If
        End If
    Else
        If TrySyntaxAt(Document, Tokens, State, "Compare", Matches) = False Then
            Exit Function
        End If
        If Matches Then
            Call SyntaxConsume(State.Cursor, State.Metrics)
            If TrySyntaxAt(Document, Tokens, State, "Binary", Matches) = False Then
                Exit Function
            End If
            If Matches = False Then
                If TrySyntaxAt(Document, Tokens, State, "Text", Matches) = False Then
                    Exit Function
                End If
            End If
            If Matches = False Then
                If TrySyntaxAt(Document, Tokens, State, "Database", Matches) = False Then
                    Exit Function
                End If
            End If
            If Matches = False Then
                TryGrammarOption = SyntaxFail(State, 102)
                Exit Function
            End If
            Call SyntaxConsume(State.Cursor, State.Metrics)
        Else
            If TrySyntaxAt(Document, Tokens, State, "Base", Matches) = False Then
                Exit Function
            End If
            If Matches Then
                Call SyntaxConsume(State.Cursor, State.Metrics)
                If TrySyntaxAt(Document, Tokens, State, "0", Matches) = False Then
                    Exit Function
                End If
                If Matches = False Then
                    If TrySyntaxAt(Document, Tokens, State, "1", Matches) = False Then
                        Exit Function
                    End If
                End If
                If Matches = False Then
                    TryGrammarOption = SyntaxFail(State, 102)
                    Exit Function
                End If
                Call SyntaxConsume(State.Cursor, State.Metrics)
            Else
                If TryGrammarTake(Document, Tokens, State, "Private") = False Then
                    Exit Function
                End If
                If TryGrammarTake(Document, Tokens, State, "Module") = False Then
                    Exit Function
                End If
            End If
        End If
    End If
    TryGrammarOption = TrySyntaxNewNode(State, 51, FirstByte, State.Cursor.LastByte, Root)
End Function

' Appends argument and omission nodes in source order with constant linking work.
Function TryGrammarArguments(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByVal Parent As Long, ByRef Tail As Long, ByVal Parenthesized As Boolean) As Boolean
    TryGrammarArguments = False
    Dim Matches As Boolean = False
    If Parenthesized Then
        If TryGrammarTake(Document, Tokens, State, "(") = False Then
            Exit Function
        End If
        If TrySyntaxAt(Document, Tokens, State, ")", Matches) = False Then
            Exit Function
        End If
        If Matches Then
            Call SyntaxConsume(State.Cursor, State.Metrics)
            TryGrammarArguments = True
            Exit Function
        End If
    End If
    Dim More As Boolean = True
    While More
        Dim ArgumentNode As Long = -1
        If TrySyntaxAt(Document, Tokens, State, ",", Matches) = False Then
            Exit Function
        End If
        Dim Omitted As Boolean = Matches
        If Parenthesized Then
            If TrySyntaxAt(Document, Tokens, State, ")", Matches) = False Then
                Exit Function
            End If
            If Matches Then
                Omitted = True
            End If
        Else
            If State.Cursor.Token.Kind = 13 Or State.Cursor.Token.Kind = 15 Then
                Omitted = True
            End If
        End If
        If Omitted Then
            Dim AtByte As Long = State.Cursor.Token.First.ByteOffset
            If TrySyntaxNewNode(State, 73, AtByte, AtByte, ArgumentNode) = False Then
                Exit Function
            End If
        Else
            If TryParseSyntaxArgument(Document, Tokens, State, ArgumentNode) = False Then
                Exit Function
            End If
        End If
        If TrySyntaxAttach(State, Parent, ArgumentNode, Tail) = False Then
            Exit Function
        End If
        If TrySyntaxAt(Document, Tokens, State, ",", More) = False Then
            Exit Function
        End If
        If More Then
            Call SyntaxConsume(State.Cursor, State.Metrics)
        End If
    Wend
    If Parenthesized Then
        If TryGrammarTake(Document, Tokens, State, ")") = False Then
            Exit Function
        End If
    End If
    TryGrammarArguments = True
End Function

' Print's leading hash is a date candidate only when its closing hash precedes
' every comma, semicolon and logical newline. Invariant dates contain neither
' separator; locale-mode dates and file/format Print remain deferred. Lookahead
' borrows existing tokens, counts actual reads, and restores only scalar cursor
' state. Physical continuations are checked by the eventual date consumer,
' allowing continued file Print to retain its distinct deferred disposition.
' This classifier never converts a date or copies source payload.
Function TryGrammarPrintDate(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByRef IsDate As Boolean) As Boolean
    TryGrammarPrintDate = False
    IsDate = False
    Dim SavedCursor As SyntaxCursor = State.Cursor
    Call SyntaxConsume(State.Cursor, State.Metrics)
    Dim Done As Boolean = False
    While Done = False
        If TrySyntaxPeek(Document, Tokens, State) = False Then
            Exit Function
        End If
        If State.Cursor.Token.Kind = 13 Or State.Cursor.Token.Kind = 15 Then
            Done = True
        Else
            Dim Matches As Boolean = False
            If State.Cursor.Token.Kind = 4 Then
                ' Raw scanning can retain a real literal's adjacent Double
                ' suffix as its final byte. Only this date context interprets
                ' that existing boundary character as the closing hash.
                Dim FinalByte As Long = -1
                If TryScannerByte(Document.Bytes, State.SourceLength, State.Cursor.Token.Last.ByteOffset - 1, FinalByte) = False Then
                    Exit Function
                End If
                Matches = FinalByte = 35
            End If
            If Matches = False Then
                If TrySyntaxAt(Document, Tokens, State, "#", Matches) = False Then
                    Exit Function
                End If
            End If
            If Matches Then
                IsDate = True
                Done = True
            Else
                If TrySyntaxAt(Document, Tokens, State, ",", Matches) = False Then
                    Exit Function
                End If
                If Matches = False Then
                    If TrySyntaxAt(Document, Tokens, State, ";", Matches) = False Then
                        Exit Function
                    End If
                End If
                If Matches Then
                    Done = True
                Else
                    Call SyntaxConsume(State.Cursor, State.Metrics)
                End If
            End If
        End If
    Wend
    State.Cursor = SavedCursor
    TryGrammarPrintDate = True
End Function

' Parses a nonstructured statement preserving assignment/call disambiguation.
Function TryGrammarSimpleStatement(ByRef Document As SourceDocument, ByRef Tokens() As SourceToken, ByRef State As SyntaxState, ByVal AllowLabel As Boolean, ByRef Root As Long, ByRef IsLabel As Boolean) As Boolean
    TryGrammarSimpleStatement = False
    IsLabel = False
    If TrySyntaxPeek(Document, Tokens, State) = False Then
        Exit Function
    End If
    Dim FirstByte As Long = State.Cursor.Token.First.ByteOffset
    Dim Matches As Boolean = False
    Dim ExplicitCall As Boolean = False
    Dim AssignmentKind As Long = 40
    If TrySyntaxAt(Document, Tokens, State, "Call", ExplicitCall) = False Then
        Exit Function
    End If
    If ExplicitCall Then
        Call SyntaxConsume(State.Cursor, State.Metrics)
        If TryGrammarSpace(Document, Tokens, State) = False Then
            Exit Function
        End If
    Else
        If TrySyntaxAt(Document, Tokens, State, "Set", Matches) = False Then
            Exit Function
        End If
        If Matches Then
            AssignmentKind = 42
            Call SyntaxConsume(State.Cursor, State.Metrics)
            If TryGrammarSpace(Document, Tokens, State) = False Then
                Exit Function
            End If
        Else
            If TrySyntaxAt(Document, Tokens, State, "Let", Matches) = False Then
                Exit Function
            End If
            If Matches Then
                AssignmentKind = 41
                Call SyntaxConsume(State.Cursor, State.Metrics)
                If TryGrammarSpace(Document, Tokens, State) = False Then
                    Exit Function
                End If
            Else
                If TrySyntaxAt(Document, Tokens, State, "LSet", Matches) = False Then
                    Exit Function
                End If
                If Matches Then
                    AssignmentKind = 75
                Else
                    If TrySyntaxAt(Document, Tokens, State, "RSet", Matches) = False Then
                        Exit Function
                    End If
                    If Matches Then
                        AssignmentKind = 76
                    End If
                End If
                If Matches Then
                    Call SyntaxConsume(State.Cursor, State.Metrics)
                    If TryGrammarSpace(Document, Tokens, State) = False Then
                        Exit Function
                    End If
                End If
            End If
        End If
    End If
    If ExplicitCall = False And AssignmentKind = 40 Then
        If TrySyntaxAt(Document, Tokens, State, "Dim", Matches) = False Then
            Exit Function
        End If
        If Matches = False Then
            If TrySyntaxAt(Document, Tokens, State, "Static", Matches) = False Then
                Exit Function
            End If
        End If
        If Matches Then
            Call SyntaxConsume(State.Cursor, State.Metrics)
            TryGrammarSimpleStatement = TryGrammarVariable(Document, Tokens, State, FirstByte, False, False, Root)
            Exit Function
        End If
        If TrySyntaxAt(Document, Tokens, State, "Const", Matches) = False Then
            Exit Function
        End If
        If Matches Then
            Call SyntaxConsume(State.Cursor, State.Metrics)
            TryGrammarSimpleStatement = TryGrammarVariable(Document, Tokens, State, FirstByte, True, False, Root)
            Exit Function
        End If
        If TrySyntaxAt(Document, Tokens, State, "Exit", Matches) = False Then
            Exit Function
        End If
        If Matches Then
            Call SyntaxConsume(State.Cursor, State.Metrics)
            If TryGrammarSpace(Document, Tokens, State) = False Then
                Exit Function
            End If
            If TrySyntaxPeek(Document, Tokens, State) = False Then
                Exit Function
            End If
            If State.Cursor.Token.Kind <> 2 Then
                TryGrammarSimpleStatement = SyntaxFail(State, 102)
                Exit Function
            End If
            Dim ExitKind As Boolean = False
            If TrySyntaxAt(Document, Tokens, State, "Sub", ExitKind) = False Then
                Exit Function
            End If
            If ExitKind = False Then
                If TrySyntaxAt(Document, Tokens, State, "Function", ExitKind) = False Then
                    Exit Function
                End If
            End If
            If ExitKind = False Then
                If TrySyntaxAt(Document, Tokens, State, "Property", ExitKind) = False Then
                    Exit Function
                End If
            End If
            If ExitKind = False Then
                If TrySyntaxAt(Document, Tokens, State, "For", ExitKind) = False Then
                    Exit Function
                End If
            End If
            If ExitKind = False Then
                If TrySyntaxAt(Document, Tokens, State, "Do", ExitKind) = False Then
                    Exit Function
                End If
            End If
            If ExitKind = False Then
                If TrySyntaxAt(Document, Tokens, State, "While", ExitKind) = False Then
                    Exit Function
                End If
            End If
            If ExitKind = False Then
                TryGrammarSimpleStatement = SyntaxFail(State, 102)
                Exit Function
            End If
            Call SyntaxConsume(State.Cursor, State.Metrics)
            TryGrammarSimpleStatement = TrySyntaxNewNode(State, 59, FirstByte, State.Cursor.LastByte, Root)
            Exit Function
        End If
        If TrySyntaxAt(Document, Tokens, State, "GoTo", Matches) = False Then
            Exit Function
        End If
        If Matches Then
            Call SyntaxConsume(State.Cursor, State.Metrics)
            If TryGrammarSpace(Document, Tokens, State) = False Then
                Exit Function
            End If
            If TrySyntaxPeek(Document, Tokens, State) = False Then
                Exit Function
            End If
            If State.Cursor.Token.Kind <> 1 And State.Cursor.Token.Kind <> 6 Then
                If State.Cursor.Token.Kind = 3 Then
                    TryGrammarSimpleStatement = SyntaxFail(State, 3)
                    Exit Function
                End If
                TryGrammarSimpleStatement = SyntaxFail(State, 104)
                Exit Function
            End If
            Call SyntaxConsume(State.Cursor, State.Metrics)
            TryGrammarSimpleStatement = TrySyntaxNewNode(State, 61, FirstByte, State.Cursor.LastByte, Root)
            Exit Function
        End If
        If TrySyntaxAt(Document, Tokens, State, "Return", Matches) = False Then
            Exit Function
        End If
        If Matches Then
            Call SyntaxConsume(State.Cursor, State.Metrics)
            TryGrammarSimpleStatement = TrySyntaxNewNode(State, 62, FirstByte, State.Cursor.LastByte, Root)
            Exit Function
        End If
        If TrySyntaxAt(Document, Tokens, State, "Print", Matches) = False Then
            Exit Function
        End If
        If Matches Then
            Call SyntaxConsume(State.Cursor, State.Metrics)
            If TrySyntaxPeek(Document, Tokens, State) = False Then
                Exit Function
            End If
            If State.Cursor.Token.Kind = 13 Or State.Cursor.Token.Kind = 15 Then
                TryGrammarSimpleStatement = SyntaxFail(State, 3)
                Exit Function
            End If
            If TrySyntaxAt(Document, Tokens, State, ":", Matches) = False Then
                Exit Function
            End If
            Dim PrintBoundary As Boolean = Matches
            If TrySyntaxAt(Document, Tokens, State, "Else", Matches) = False Then
                Exit Function
            End If
            If PrintBoundary Or Matches Then
                TryGrammarSimpleStatement = SyntaxFail(State, 3)
                Exit Function
            End If
            If TryGrammarSpace(Document, Tokens, State) = False Then
                Exit Function
            End If
            If TrySyntaxPeek(Document, Tokens, State) = False Then
                Exit Function
            End If
            If TrySyntaxAt(Document, Tokens, State, "#", Matches) = False Then
                Exit Function
            End If
            If Matches Then
                Dim PrintDate As Boolean = False
                If TryGrammarPrintDate(Document, Tokens, State, PrintDate) = False Then
                    Exit Function
                End If
                If PrintDate = False Then
                    TryGrammarSimpleStatement = SyntaxFail(State, 3)
                    Exit Function
                End If
            End If
            Dim PrintFormat As Boolean = False
            If TrySyntaxAt(Document, Tokens, State, ",", PrintFormat) = False Then
                Exit Function
            End If
            If PrintFormat = False Then
                If TrySyntaxAt(Document, Tokens, State, ";", PrintFormat) = False Then
                    Exit Function
                End If
            End If
            If PrintFormat = False Then
                If TrySyntaxAt(Document, Tokens, State, "Spc", PrintFormat) = False Then
                    Exit Function
                End If
            End If
            If PrintFormat = False Then
                If TrySyntaxAt(Document, Tokens, State, "Tab", PrintFormat) = False Then
                    Exit Function
                End If
            End If
            If PrintFormat Then
                TryGrammarSimpleStatement = SyntaxFail(State, 3)
                Exit Function
            End If
            Dim ValueNode As Long = -1
            If TryParseSyntaxExpression(Document, Tokens, State, ValueNode) = False Then
                Exit Function
            End If
            If TrySyntaxAt(Document, Tokens, State, ",", PrintFormat) = False Then
                Exit Function
            End If
            If PrintFormat = False Then
                If TrySyntaxAt(Document, Tokens, State, ";", PrintFormat) = False Then
                    Exit Function
                End If
            End If
            If PrintFormat Then
                TryGrammarSimpleStatement = SyntaxFail(State, 3)
                Exit Function
            End If
            If TrySyntaxNewNode(State, 49, FirstByte, State.Pending(0).Nodes(ValueNode).LastByte, Root) = False Then
                Exit Function
            End If
            Dim PrintTail As Long = -1
            TryGrammarSimpleStatement = TrySyntaxAttach(State, Root, ValueNode, PrintTail)
            Exit Function
        End If
    End If
    Dim Target As Long = -1
    Dim TargetCursor As SyntaxCursor = State.Cursor
    Dim TargetMark As Long = State.Count
    If TryParseSyntaxPostfix(Document, Tokens, State, False, Target) = False Then
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "(", Matches) = False Then
        Exit Function
    End If
    If ExplicitCall = False And Matches Then
        Dim HadArgumentSpace As Boolean = State.Cursor.HadSpace
        State.Cursor = TargetCursor
        State.Count = TargetMark
        If TryParseSyntaxPostfix(Document, Tokens, State, True, Target) = False Then
            Exit Function
        End If
        If TrySyntaxAt(Document, Tokens, State, "=", Matches) = False Then
            Exit Function
        End If
        If Matches = False And HadArgumentSpace Then
            ' A spaced group is a bare call argument unless a following '='
            ' makes the complete postfix phrase the structural assignment lhs.
            State.Cursor = TargetCursor
            State.Count = TargetMark
            If TryParseSyntaxPostfix(Document, Tokens, State, False, Target) = False Then
                Exit Function
            End If
        End If
    End If
    Dim TargetLast As Long = State.Pending(0).Nodes(Target).LastByte
    If TrySyntaxAt(Document, Tokens, State, "=", Matches) = False Then
        Exit Function
    End If
    If ExplicitCall = False And Matches Then
        Call SyntaxConsume(State.Cursor, State.Metrics)
        Dim RightNode As Long = -1
        If TryParseSyntaxExpression(Document, Tokens, State, RightNode) = False Then
            Exit Function
        End If
        If TrySyntaxNewNode(State, AssignmentKind, FirstByte, State.Pending(0).Nodes(RightNode).LastByte, Root) = False Then
            Exit Function
        End If
        Dim AssignmentTail As Long = -1
        If TrySyntaxAttach(State, Root, Target, AssignmentTail) = False Then
            Exit Function
        End If
        TryGrammarSimpleStatement = TrySyntaxAttach(State, Root, RightNode, AssignmentTail)
        Exit Function
    End If
    If AssignmentKind <> 40 Then
        TryGrammarSimpleStatement = SyntaxFail(State, 102)
        Exit Function
    End If
    If ExplicitCall = False And State.Pending(0).Nodes(Target).Kind = 39 Then
        Root = Target
        TryGrammarSimpleStatement = True
        Exit Function
    End If
    If AllowLabel And ExplicitCall = False And State.Pending(0).Nodes(Target).Kind = 2 Then
        Dim DecimalLabel As Boolean = True
        Dim DigitAt As Long = State.Pending(0).Nodes(Target).FirstByte
        Dim DigitLast As Long = State.Pending(0).Nodes(Target).LastByte
        While DigitAt < DigitLast
            Dim DigitValue As Long = Document.Bytes(DigitAt)
            If DigitValue < 48 Or DigitValue > 57 Then
                DecimalLabel = False
            End If
            DigitAt = DigitAt + 1
            State.Metrics.Transitions = State.Metrics.Transitions + 1
        Wend
        If DecimalLabel Then
            TryGrammarSimpleStatement = SyntaxFail(State, 3)
            Exit Function
        End If
    End If
    ' A line-start plain identifier plus colon is the frozen label choice.
    If AllowLabel And ExplicitCall = False And State.Pending(0).Nodes(Target).Kind = 1 Then
        If TrySyntaxAt(Document, Tokens, State, ":", Matches) = False Then
            Exit Function
        End If
        If Matches Then
            Call SyntaxConsume(State.Cursor, State.Metrics)
            State.Pending(0).Nodes(Target).Kind = 60
            State.Pending(0).Nodes(Target).LastByte = State.Cursor.LastByte
            Root = Target
            IsLabel = True
            TryGrammarSimpleStatement = True
            Exit Function
        End If
    End If
    Dim CallableBoundary As Long = Target
    Dim CallableKind As Long = State.Pending(0).Nodes(CallableBoundary).Kind
    While CallableKind = 34 Or CallableKind = 35
        CallableBoundary = State.Pending(0).Nodes(CallableBoundary).FirstChild
        CallableKind = State.Pending(0).Nodes(CallableBoundary).Kind
        State.Metrics.Transitions = State.Metrics.Transitions + 1
    Wend
    If ExplicitCall = False And CallableKind = 38 Then
        ' Rewind only the diagnostic coordinate: the expression is already
        ' private and will be discarded. The call's first '(' is its boundary.
        Dim Probe As Long = State.Pending(0).Nodes(State.Pending(0).Nodes(CallableBoundary).FirstChild).LastByte
        While Probe < State.Pending(0).Nodes(CallableBoundary).LastByte
            If Document.Bytes(Probe) = 40 Then
                Exit While
            End If
            Probe = Probe + 1
        Wend
        State.Failure.Kind = 105
        State.Failure.FirstByte = Probe
        State.Failure.LastByte = Probe + 1
        Exit Function
    End If
    Dim CallKind As Long = 43
    If ExplicitCall Then
        CallKind = 44
    End If
    If TrySyntaxNewNode(State, CallKind, FirstByte, TargetLast, Root) = False Then
        Exit Function
    End If
    Dim CallTail As Long = -1
    If TrySyntaxAttach(State, Root, Target, CallTail) = False Then
        Exit Function
    End If
    If TrySyntaxAt(Document, Tokens, State, "(", Matches) = False Then
        Exit Function
    End If
    If ExplicitCall Then
        If Matches Then
            If TryGrammarArguments(Document, Tokens, State, Root, CallTail, True) = False Then
                Exit Function
            End If
        Else
            If State.Cursor.Token.Kind <> 13 And State.Cursor.Token.Kind <> 15 Then
                If TrySyntaxAt(Document, Tokens, State, ":", Matches) = False Then
                    Exit Function
                End If
                If Matches = False Then
                    If TrySyntaxAt(Document, Tokens, State, "Else", Matches) = False Then
                        Exit Function
                    End If
                    If Matches = False Then
                        TryGrammarSimpleStatement = SyntaxFail(State, 102)
                        Exit Function
                    End If
                End If
            End If
        End If
    Else
        If State.Cursor.Token.Kind <> 13 And State.Cursor.Token.Kind <> 15 Then
            Dim Separator As Boolean = False
            If TrySyntaxAt(Document, Tokens, State, ":", Separator) = False Then
                Exit Function
            End If
            If Separator = False Then
                If TrySyntaxAt(Document, Tokens, State, "Else", Separator) = False Then
                    Exit Function
                End If
            End If
            If Separator = False Then
                If State.Cursor.HadSpace = False Then
                    TryGrammarSimpleStatement = SyntaxFail(State, 105)
                    Exit Function
                End If
                If TryGrammarArguments(Document, Tokens, State, Root, CallTail, False) = False Then
                    Exit Function
                End If
            End If
        End If
    End If
    State.Pending(0).Nodes(Root).LastByte = State.Cursor.LastByte
    TryGrammarSimpleStatement = True
End Function

