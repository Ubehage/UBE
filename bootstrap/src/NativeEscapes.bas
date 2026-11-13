Attribute VB_Name = "NativeEscapes"
Option Explicit
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

Private Function ResizeFacts(ByRef Values() As EscapeFact, ByVal Count As Long, ByVal PreserveValues As Boolean) As Boolean
    ReDim Values(0 To Count - 1)
    ResizeFacts = True
End Function

Private Function ResizeNumbers(ByRef Values() As Long, ByVal Count As Long, ByVal PreserveValues As Boolean) As Boolean
    ReDim Values(0 To Count - 1)
    ResizeNumbers = True
End Function

' Charges receiver and graph traversal against the existing native planning work bound.
Private Function Charge(ByRef Work As Long, ByRef D As Long) As Boolean
    On Error GoTo Failed
    If Work >= 10000000 Then
        D = 6
        Exit Function
    End If
    Work = Work + 1
    Charge = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Finds the owner of an alias without confusing an array payload with its descriptor.
Private Function FindOwner(ByRef Parsed As SourceParser.ParsedProject, ByRef Bound As SourceSemantics.BoundProject, ByRef F() As EscapeFact, ByVal Argument As Long, ByRef Work As Long, ByRef D As Long) As Boolean
    Dim Node As Long
    Dim Symbol As Long
    Dim Scope As Long
    On Error GoTo Failed
    If Bound.Nodes(Argument).ArgumentMode <> "alias" Then
        F(Argument - 1).OwnerKind = TemporaryOwner
        F(Argument - 1).OwnerIdentity = Argument
        FindOwner = True
        Exit Function
    End If
    Node = Argument
    Do
        If Charge(Work, D) = False Then Exit Function
        If Bound.Nodes(Node).AccessKind = "index" Then
            F(Argument - 1).OwnerKind = PayloadOwner
            F(Argument - 1).OwnerIdentity = Node
            FindOwner = True
            Exit Function
        End If
        If Bound.Nodes(Node).AccessKind <> "field" Then Exit Do
        Node = Parsed.Nodes(Node).FirstChild
    Loop
    Symbol = Bound.Nodes(Node).SymbolIndex
    Scope = Bound.Symbols(Symbol).ScopeSymbol
    F(Argument - 1).OwnerKind = SymbolOwner
    If Bound.Symbols(Scope).Kind = "module" Then F(Argument - 1).OwnerKind = ProgramOwner
    F(Argument - 1).OwnerIdentity = Symbol
    FindOwner = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Marks each storage symbol once; only parameter symbols have incoming call edges.
Private Sub RequireOwner(ByRef Parsed As SourceParser.ParsedProject, ByRef Bound As SourceSemantics.BoundProject, ByRef F() As EscapeFact, ByRef Marked() As Long, ByRef Queue() As Long, ByRef Tail As Long, ByVal Argument As Long)
    Dim Symbol As Long
    Dim Receiver As Long
    On Error GoTo Failed
    F(Argument - 1).NeedsOwner = True
    If F(Argument - 1).OwnerKind = PayloadOwner Then
        Receiver = Parsed.Nodes(F(Argument - 1).OwnerIdentity).FirstChild
        Symbol = Bound.Nodes(Receiver).SymbolIndex
        If Bound.Symbols(Bound.Symbols(Symbol).ScopeSymbol).Kind = "module" Then Exit Sub
    ElseIf F(Argument - 1).OwnerKind = SymbolOwner Then
        Symbol = F(Argument - 1).OwnerIdentity
    Else
        Exit Sub
    End If
    If Marked(Symbol - 1) <> 0 Then Exit Sub
    Marked(Symbol - 1) = 1
    F(Bound.Symbols(Symbol).DeclarationNode - 1).StorageEscapes = True
    Queue(Tail) = Symbol
    Tail = Tail + 1
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

' Builds reverse parameter-to-actual edges and seeds direct asynchronous aliases.
Private Function BuildEdges(ByRef Parsed As SourceParser.ParsedProject, ByRef Bound As SourceSemantics.BoundProject, ByVal NodeCount As Long, ByRef F() As EscapeFact, ByRef Heads() As Long, ByRef Nexts() As Long, ByRef Marked() As Long, ByRef Queue() As Long, ByRef Tail As Long, ByRef Work As Long, ByRef D As Long) As Boolean
    Dim Node As Long
    Dim Symbol As Long
    Dim Parameter As Long
    Dim Argument As Long
    Dim Kind As String
    Dim Mode As String
    Dim Linked As Boolean
    On Error GoTo Failed
    Node = 1
    Do While Node <= NodeCount
        If Charge(Work, D) = False Then Exit Function
        Kind = Parsed.Nodes(Node).Kind
        If (Kind = "call" Or Kind = "thread-start") And Bound.Nodes(Node).AccessKind <> "index" Then
            Symbol = Bound.Nodes(Node).SymbolIndex
            If Symbol <> 0 Then
                Parameter = Bound.Symbols(Symbol).FirstParameter
                Argument = Parsed.Nodes(Parsed.Nodes(Node).FirstChild).NextSibling
                Do While Parameter <> 0 And Argument <> 0
                    If Charge(Work, D) = False Then Exit Function
                    Mode = Bound.Nodes(Argument).ArgumentMode
                    Linked = Mode = "alias" Or Mode = "temp"
                    If Mode = "value" And (Bound.Symbols(Parameter).TypeSymbol <> 0 Or Bound.Symbols(Parameter).ArrayRank <> 0) Then Linked = True
                    If Linked Then
                        If FindOwner(Parsed, Bound, F, Argument, Work, D) = False Then Exit Function
                        Nexts(Argument - 1) = Heads(Parameter - 1)
                        Heads(Parameter - 1) = Argument
                        If Kind = "thread-start" Then RequireOwner Parsed, Bound, F, Marked, Queue, Tail, Argument
                    End If
                    Parameter = Bound.Symbols(Parameter).NextParameter
                    Argument = Parsed.Nodes(Argument).NextSibling
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
Public Function TryAnalyzeEscapes(ByRef Parsed As SourceParser.ParsedProject, ByRef Bound As SourceSemantics.BoundProject, ByVal NodeCount As Long, ByVal SymbolCount As Long, ByRef Facts() As EscapeFact, ByRef FactCount As Long, ByRef Diagnostic As Long) As Boolean
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
    Diagnostic = 0
    If NodeCount < 1 Or NodeCount > 131072 Or SymbolCount < 1 Or SymbolCount > 16384 Then
        Diagnostic = 6
        Exit Function
    End If
    If ResizeFacts(Candidate, NodeCount, False) = False Then GoTo StorageFailure
    If ResizeNumbers(Heads, SymbolCount, False) = False Then GoTo StorageFailure
    If ResizeNumbers(Nexts, NodeCount, False) = False Then GoTo StorageFailure
    If ResizeNumbers(Marked, SymbolCount, False) = False Then GoTo StorageFailure
    If ResizeNumbers(Queue, SymbolCount, False) = False Then GoTo StorageFailure
    If BuildEdges(Parsed, Bound, NodeCount, Candidate, Heads, Nexts, Marked, Queue, Tail, Work, Diagnostic) = False Then Exit Function
    Do While Head < Tail
        Symbol = Queue(Head)
        Head = Head + 1
        Argument = Heads(Symbol - 1)
        Do While Argument <> 0
            If Charge(Work, Diagnostic) = False Then Exit Function
            RequireOwner Parsed, Bound, Candidate, Marked, Queue, Tail, Argument
            Argument = Nexts(Argument - 1)
        Loop
    Loop
    Facts = Candidate
    FactCount = NodeCount
    TryAnalyzeEscapes = True
    Exit Function
StorageFailure:
    FactCount = 0
    Diagnostic = 7
End Function
