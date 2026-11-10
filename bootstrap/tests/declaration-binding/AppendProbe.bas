UBE SOURCE 1 MODULE
Attribute UBE_Name = "AppendProbe"
' Checks retained project prefixes across every allocation boundary in a second append.
Private Bytes() As Byte
Private Tokens() As SourceScanner.SourceToken
Private Nodes() As SourceParser.SyntaxNode
Private Modules() As ProjectSyntax.ParsedModule
Private Counts As ProjectSyntax.ProjectCounts
Private SavedCounts As ProjectSyntax.ProjectCounts
Private SavedBytes() As Byte
Private SavedTokens() As SourceScanner.SourceToken
Private SavedNodes() As SourceParser.SyntaxNode
Private SavedModules() As ProjectSyntax.ParsedModule
Private NextSource() As Byte
Private Diagnostic As ProjectSyntax.ProjectDiagnostic

' Commits one module and independently snapshots each published prefix before injecting faults.
Public Function Prepare(ByRef First() As Byte, ByRef Second() As Byte) As Long
    If Not ProjectSyntax.TryAppendModule(First, Bytes, Tokens, Nodes, Modules, Counts, Diagnostic) Then Prepare = 1: Exit Function
    SavedBytes = Bytes
    SavedTokens = Tokens
    SavedNodes = Nodes
    SavedModules = Modules
    SavedCounts = Counts
    NextSource = Second
End Function

' Exposes one append result without additional helper work at an exhausted call depth.
Public Function AttemptAppend() As Boolean
    On Error GoTo Failed
    AttemptAppend = ProjectSyntax.TryAppendModule(NextSource, Bytes, Tokens, Nodes, Modules, Counts, Diagnostic)
    Exit Function
Failed:
End Function

' Checks success or preserved committed data after the harness restores the artificial call depth.
Public Function CheckDepth(ByVal Succeeded As Boolean, ByVal TailWritten As Boolean) As Long
    If Succeeded Then
        If Counts.ModuleCount <> 2 Then CheckDepth = 1
        Exit Function
    End If
    If Err.Number <> 28 Then CheckDepth = 2: Exit Function
    If Not Unchanged() Then CheckDepth = 3: Exit Function
    If TailWritten Then
        If Diagnostic.Stage <> 3 Or Diagnostic.Code <> 6 Or Diagnostic.Reason <> 2 Then CheckDepth = 4: Exit Function
        If Bytes(SavedCounts.ByteCount) <> NextSource(0) Then CheckDepth = 5: Exit Function
        If Tokens(SavedCounts.TokenCount).ByteStart <> SavedCounts.ByteCount Then CheckDepth = 6: Exit Function
    End If
End Function

' Rejects corrupted committed spans before appending and restores each synthetic corruption.
Public Function CheckCorruption(ByVal Mode As Long) As Long
    Dim Previous As Long
    If Mode = 1 Then
        Previous = Tokens(0).ByteStart
        Tokens(0).ByteStart = -1
    ElseIf Mode = 2 Then
        Previous = Nodes(0).NextSibling
        Nodes(0).NextSibling = Counts.NodeCount + 1
    ElseIf Mode = 3 Then
        Previous = Nodes(0).ByteLength
        Nodes(0).ByteLength = Counts.ByteCount + 1
    ElseIf Mode = 5 Then
        Previous = Tokens(0).Kind
        Tokens(0).Kind = 8
    ElseIf Mode = 6 Then
        Previous = Nodes(0).Kind
        Nodes(0).Kind = 30
    ElseIf Mode = 7 Then
        Previous = Tokens(0).Utf16Length
        Tokens(0).Utf16Length = -1
    ElseIf Mode = 8 Then
        Previous = Nodes(0).Line
        Nodes(0).Line = 0
    ElseIf Mode = 9 Then
        Previous = Tokens(0).Kind
        Tokens(0).Kind = 7
    ElseIf Mode = 10 Then
        Previous = Tokens(Counts.TokenCount - 1).Kind
        Tokens(Counts.TokenCount - 1).Kind = 1
    Else
        Previous = Nodes(0).FirstToken
        Nodes(0).FirstToken = Counts.TokenCount
    End If
    If ProjectSyntax.TryAppendModule(NextSource, Bytes, Tokens, Nodes, Modules, Counts, Diagnostic) Then CheckCorruption = 1: Exit Function
    If Diagnostic.Stage <> 3 Or Diagnostic.Code <> 6 Or Diagnostic.Reason <> 1 Then CheckCorruption = 2: Exit Function
    If Mode = 1 Then
        Tokens(0).ByteStart = Previous
    ElseIf Mode = 2 Then
        Nodes(0).NextSibling = Previous
    ElseIf Mode = 3 Then
        Nodes(0).ByteLength = Previous
    ElseIf Mode = 5 Then
        Tokens(0).Kind = Previous
    ElseIf Mode = 6 Then
        Nodes(0).Kind = Previous
    ElseIf Mode = 7 Then
        Tokens(0).Utf16Length = Previous
    ElseIf Mode = 8 Then
        Nodes(0).Line = Previous
    ElseIf Mode = 9 Then
        Tokens(0).Kind = Previous
    ElseIf Mode = 10 Then
        Tokens(Counts.TokenCount - 1).Kind = Previous
    Else
        Nodes(0).FirstToken = Previous
    End If
    If Not Unchanged() Then CheckCorruption = 3: Exit Function
End Function

' Compares complete record contents in all committed prefixes, ignoring permitted spare capacity.
Private Function Unchanged() As Boolean
    Dim I As Long
    If Counts <> SavedCounts Then Exit Function
    Do While I < Counts.ByteCount
        If Bytes(I) <> SavedBytes(I) Then Exit Function
        I = I + 1
    Loop
    I = 0
    Do While I < Counts.TokenCount
        If Tokens(I) <> SavedTokens(I) Then Exit Function
        I = I + 1
    Loop
    I = 0
    Do While I < Counts.NodeCount
        If Nodes(I) <> SavedNodes(I) Then Exit Function
        I = I + 1
    Loop
    I = 0
    Do While I < Counts.ModuleCount
        If Modules(I) <> SavedModules(I) Then Exit Function
        I = I + 1
    Loop
    Unchanged = True
End Function

' Requires a rejected allocation to preserve every published value and its original error record.
Public Function RejectAllocation() As Long
    If ProjectSyntax.TryAppendModule(NextSource, Bytes, Tokens, Nodes, Modules, Counts, Diagnostic) Then RejectAllocation = 1: Exit Function
    If Diagnostic.Code <> 5 Or Err.Number <> 7 Then RejectAllocation = 2: Exit Function
    If Not Unchanged() Then RejectAllocation = 3: Exit Function
End Function

' Retries after failure, checks rebased ownership, and rejects a case-insensitive duplicate without publication.
Public Function RetryAppend() As Long
    Dim Before As ProjectSyntax.ProjectCounts
    If Not ProjectSyntax.TryAppendModule(NextSource, Bytes, Tokens, Nodes, Modules, Counts, Diagnostic) Then RetryAppend = 1: Exit Function
    If Counts.ModuleCount <> 2 Then RetryAppend = 2: Exit Function
    If Modules(1).ByteBase <> SavedCounts.ByteCount Or Modules(1).TokenBase <> SavedCounts.TokenCount Or Modules(1).NodeBase <> SavedCounts.NodeCount Then RetryAppend = 3: Exit Function
    If Nodes(Modules(1).RootNode - 1).NameToken <> Modules(1).NameToken Then RetryAppend = 4: Exit Function
    If Tokens(Modules(1).NameToken).Line <> 2 Then RetryAppend = 5: Exit Function
    Before = Counts
    NextSource(Tokens(Modules(1).NameToken).ByteStart - Modules(1).ByteBase + 1) = 115
    If ProjectSyntax.TryAppendModule(NextSource, Bytes, Tokens, Nodes, Modules, Counts, Diagnostic) Then RetryAppend = 6: Exit Function
    If Diagnostic.Stage <> 3 Or Diagnostic.Code <> 3 Or Counts <> Before Then RetryAppend = 7: Exit Function
    Counts.ByteCount = Counts.ByteCount + 1
    If ProjectSyntax.IsValidProject(Bytes, Tokens, Nodes, Modules, Counts) Then RetryAppend = 8: Exit Function
    Counts = Before
End Function
