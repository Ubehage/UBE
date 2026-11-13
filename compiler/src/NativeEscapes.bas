UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeEscapes"
' Determines the storage owners that must survive asynchronous procedure calls.
Public Const ProgramOwner As Long = 1
Public Const SymbolOwner As Long = 2
Public Const TemporaryOwner As Long = 3
Public Const PayloadOwner As Long = 4

Public Type EscapeFact
    StorageEscapes As Boolean
    NeedsOwner As Boolean
    OwnerKind As Long
    OwnerIdentity As Long
End Type

Private Intrinsic Function ResizeFacts(ByRef Values() As EscapeFact, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeFacts.UBE_Primitive = "Array.TryResize"
End Function

Private Intrinsic Function ResizeNumbers(ByRef Values() As Long, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeNumbers.UBE_Primitive = "Array.TryResize"
End Function

' Charges receiver and graph traversal against the existing native planning work bound.
Private Function Charge(ByRef Work As Long, ByRef D As DeclarationBinder.BindingDiagnostic) As Boolean
    On Error GoTo Failed
    If Work >= 10000000 Then
        D.Code = 6
        D.Reason = 55
        Exit Function
    End If
    Work = Work + 1
    Charge = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Finds the owner of an alias without confusing an array payload with its descriptor.
Private Function FindOwner(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByRef F() As EscapeFact, ByVal Argument As Long, ByRef Work As Long, ByRef D As DeclarationBinder.BindingDiagnostic) As Boolean
    Dim Node As Long
    Dim Symbol As Long
    Dim Scope As Long
    On Error GoTo Failed
    If E(Argument - 1).ArgumentMode <> 2 Then
        F(Argument - 1).OwnerKind = TemporaryOwner
        F(Argument - 1).OwnerIdentity = Argument
        FindOwner = True
        Exit Function
    End If
    Node = Argument
    Do
        If Charge(Work, D) = False Then Exit Function
        If E(Node - 1).AccessKind = 2 Then
            F(Argument - 1).OwnerKind = PayloadOwner
            F(Argument - 1).OwnerIdentity = Node
            FindOwner = True
            Exit Function
        End If
        If E(Node - 1).AccessKind <> 1 Then Exit Do
        Node = N(Node - 1).FirstChild
    Loop
    Symbol = E(Node - 1).SymbolIndex
    Scope = A(Symbol - 1).ScopeSymbol
    F(Argument - 1).OwnerKind = SymbolOwner
    If A(Scope - 1).Kind = SourceParser.ModuleNode Then F(Argument - 1).OwnerKind = ProgramOwner
    F(Argument - 1).OwnerIdentity = Symbol
    FindOwner = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Marks each storage symbol once; only parameter symbols have incoming call edges.
Private Sub RequireOwner(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByRef F() As EscapeFact, ByRef Marked() As Long, ByRef Queue() As Long, ByRef Tail As Long, ByVal Argument As Long)
    Dim Symbol As Long
    Dim Receiver As Long
    On Error GoTo Failed
    F(Argument - 1).NeedsOwner = True
    If F(Argument - 1).OwnerKind = PayloadOwner Then
        Receiver = N(F(Argument - 1).OwnerIdentity - 1).FirstChild
        Symbol = E(Receiver - 1).SymbolIndex
        If A(A(Symbol - 1).ScopeSymbol - 1).Kind = SourceParser.ModuleNode Then Exit Sub
    ElseIf F(Argument - 1).OwnerKind = SymbolOwner Then
        Symbol = F(Argument - 1).OwnerIdentity
    Else
        Exit Sub
    End If
    If Marked(Symbol - 1) <> 0 Then Exit Sub
    Marked(Symbol - 1) = 1
    F(A(Symbol - 1).DeclarationNode - 1).StorageEscapes = True
    Queue(Tail) = Symbol
    Tail = Tail + 1
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

' Builds reverse parameter-to-actual edges and seeds direct asynchronous aliases.
Private Function BuildEdges(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByVal NodeCount As Long, ByRef F() As EscapeFact, ByRef Heads() As Long, ByRef Nexts() As Long, ByRef Marked() As Long, ByRef Queue() As Long, ByRef Tail As Long, ByRef Work As Long, ByRef D As DeclarationBinder.BindingDiagnostic) As Boolean
    Dim Node As Long
    Dim Symbol As Long
    Dim Parameter As Long
    Dim Argument As Long
    Dim Kind As Long
    Dim Mode As Long
    Dim Linked As Boolean
    On Error GoTo Failed
    Node = 1
    Do While Node <= NodeCount
        If Charge(Work, D) = False Then Exit Function
        Kind = N(Node - 1).Kind
        If (Kind = SourceParser.CallNode Or Kind = SourceParser.ThreadStartNode) And E(Node - 1).AccessKind <> 2 Then
            Symbol = E(Node - 1).SymbolIndex
            If Symbol <> 0 Then
                Parameter = A(Symbol - 1).FirstParameter
                Argument = N(N(Node - 1).FirstChild - 1).NextSibling
                Do While Parameter <> 0 And Argument <> 0
                    If Charge(Work, D) = False Then Exit Function
                    Mode = E(Argument - 1).ArgumentMode
                    Linked = Mode = 2 Or Mode = 3
                    If Mode = 1 And (A(Parameter - 1).TypeSymbol <> 0 Or A(Parameter - 1).ArrayRank <> 0) Then Linked = True
                    If Linked Then
                        If FindOwner(N, A, E, F, Argument, Work, D) = False Then Exit Function
                        Nexts(Argument - 1) = Heads(Parameter - 1)
                        Heads(Parameter - 1) = Argument
                        If Kind = SourceParser.ThreadStartNode Then RequireOwner N, A, E, F, Marked, Queue, Tail, Argument
                    End If
                    Parameter = A(Parameter - 1).NextParameter
                    Argument = N(Argument - 1).NextSibling
                Loop
            End If
        End If
        Node = Node + 1
    Loop
    BuildEdges = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Publishes one complete plan; failed allocation or bounded work preserves previous facts.
' Input syntax and binding identities must come from the checked project pipeline.
Public Function TryAnalyzeEscapes(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByVal NodeCount As Long, ByVal SymbolCount As Long, ByRef Facts() As EscapeFact, ByRef FactCount As Long, ByRef Diagnostic As DeclarationBinder.BindingDiagnostic) As Boolean
    Dim Candidate() As EscapeFact
    Dim Heads() As Long
    Dim Nexts() As Long
    Dim Marked() As Long
    Dim Queue() As Long
    Dim Head As Long
    Dim Tail As Long
    Dim Symbol As Long
    Dim Argument As Long
    Dim Work As Long
    On Error GoTo StorageFailure
    FactCount = 0
    Diagnostic.Code = 0
    Diagnostic.Reason = 0
    Diagnostic.Node = 0
    Diagnostic.ModuleIndex = -1
    Diagnostic.TokenIndex = -1
    Diagnostic.ByteOffset = 0
    Diagnostic.Utf16Offset = 1
    Diagnostic.Line = 1
    Diagnostic.Column = 1
    If NodeCount < 1 Or NodeCount > 131072 Or SymbolCount < 1 Or SymbolCount > 16384 Then
        Diagnostic.Code = 6
        Diagnostic.Reason = 55
        Exit Function
    End If
    If ResizeFacts(Candidate, NodeCount, False) = False Then GoTo StorageFailure
    If ResizeNumbers(Heads, SymbolCount, False) = False Then GoTo StorageFailure
    If ResizeNumbers(Nexts, NodeCount, False) = False Then GoTo StorageFailure
    If ResizeNumbers(Marked, SymbolCount, False) = False Then GoTo StorageFailure
    If ResizeNumbers(Queue, SymbolCount, False) = False Then GoTo StorageFailure
    If BuildEdges(N, A, E, NodeCount, Candidate, Heads, Nexts, Marked, Queue, Tail, Work, Diagnostic) = False Then Exit Function
    Do While Head < Tail
        Symbol = Queue(Head)
        Head = Head + 1
        Argument = Heads(Symbol - 1)
        Do While Argument <> 0
            If Charge(Work, Diagnostic) = False Then Exit Function
            RequireOwner N, A, E, Candidate, Marked, Queue, Tail, Argument
            Argument = Nexts(Argument - 1)
        Loop
    Loop
    Facts = Candidate
    FactCount = NodeCount
    TryAnalyzeEscapes = True
    Exit Function
StorageFailure:
    FactCount = 0
    Diagnostic.Code = 7
    Diagnostic.Reason = 1
End Function
