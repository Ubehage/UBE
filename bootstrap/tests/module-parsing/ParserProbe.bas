UBE SOURCE 1 MODULE
Attribute UBE_Name = "ParserProbe"
' Retains independent source/token/tree owners for native parser assertions.
Private InputPath() As Byte
Private CandidateSource() As Byte
Private CandidateTokens() As SourceScanner.SourceToken
Private CandidateCount As Long
Private ScanError As SourceScanner.ScanDiagnostic
Private FirstSource() As Byte
Private FirstTokens() As SourceScanner.SourceToken
Private FirstNodes() As SourceParser.SyntaxNode
Private FirstCount As Long
Private FirstRoot As Long
Private SecondSource() As Byte
Private SecondTokens() As SourceScanner.SourceToken
Private SecondNodes() As SourceParser.SyntaxNode
Private SecondCount As Long
Private SecondRoot As Long
Private Diagnostic As SourceParser.ParseDiagnostic

' Corrupts scanner metadata only in the isolated candidate to test parser admission.
Public Function CorruptCandidate(ByVal Mode As Long) As Long
    If Mode = 1 Then CandidateTokens(0).ByteStart = -1
    If Mode = 2 Then CandidateTokens(0).ByteLength = BufferPrimitives.ByteStorageLength(CandidateSource) + 1
    If Mode = 3 Then CandidateTokens(0).Kind = 99
    If Mode = 4 Then CandidateTokens(0).Kind = SourceScanner.EndToken
    CorruptCandidate = 0
End Function

' Exposes retained type/name token spans for independently authored spelling checks.
Public Function TokenByteStart(ByVal Slot As Long, ByVal Index As Long) As Long
    If Slot = 0 Then TokenByteStart = FirstTokens(Index).ByteStart Else TokenByteStart = SecondTokens(Index).ByteStart
End Function

' Measures retained node storage independently of a failed parse's published count.
Private Intrinsic Function NodeStorageLength(ByRef Values() As SourceParser.SyntaxNode) As Long
Attribute NodeStorageLength.UBE_Primitive = "Array.Length"
End Function

' Validates all retained links and spans with a bounded iterative traversal.
Private Function ValidateTree(ByRef Source() As Byte, ByRef Nodes() As SourceParser.SyntaxNode, ByVal Count As Long, ByVal Root As Long) As Long
    Dim Seen() As Byte
    Dim Status As Boolean
    Dim Length As Long
    Dim Index As Long
    Dim Child As Long
    Dim Last As Long
    Dim Walk As Long
    Dim Parent As Long
    Dim Visits As Long
    Dim Steps As Long
    Dim Budget As Long
    On Error GoTo InvalidTree
    If Count < 1 Or Root < 1 Or Root > Count Then ValidateTree = 1: Exit Function
    If Nodes(Root - 1).Kind <> 1 Or Nodes(Root - 1).Parent <> 0 Or Nodes(Root - 1).NextSibling <> 0 Then ValidateTree = 2: Exit Function
    Length = BufferPrimitives.ByteStorageLength(Source)
    Status = BufferPrimitives.TryResizeBytes(Seen, Count, False)
    If Status = False Then ValidateTree = 3: Exit Function
    Do While Index < Count
        If Nodes(Index).ByteStart < 0 Or Nodes(Index).ByteStart > Length Then ValidateTree = 4: Exit Function
        If Nodes(Index).ByteLength < 0 Or Nodes(Index).ByteLength > Length - Nodes(Index).ByteStart Then ValidateTree = 5: Exit Function
        If Nodes(Index).Utf16Start < 1 Or Nodes(Index).Utf16Length < 0 Or Nodes(Index).Line < 1 Or Nodes(Index).Column < 1 Then ValidateTree = 6: Exit Function
        Child = Nodes(Index).FirstChild
        Last = 0
        Steps = 0
        Do While Child <> 0
            If Child < 1 Or Child > Count Then ValidateTree = 7: Exit Function
            If Nodes(Child - 1).Parent <> Index + 1 Then ValidateTree = 8: Exit Function
            Last = Child
            Child = Nodes(Child - 1).NextSibling
            Steps = Steps + 1
            If Steps > Count Then ValidateTree = 9: Exit Function
        Loop
        If Last <> Nodes(Index).LastChild Then ValidateTree = 10: Exit Function
        Index = Index + 1
    Loop
    Walk = Root
    Steps = 0
    Budget = Count + Count + 1
    Do While Walk <> 0
        If Walk < 1 Or Walk > Count Then ValidateTree = 11: Exit Function
        If Seen(Walk - 1) <> 0 Then ValidateTree = 12: Exit Function
        Seen(Walk - 1) = 1
        Visits = Visits + 1
        Child = Nodes(Walk - 1).FirstChild
        If Child <> 0 Then
            Walk = Child
        Else
            Do While Walk <> 0
                Steps = Steps + 1
                If Steps > Budget Then ValidateTree = 13: Exit Function
                Child = Nodes(Walk - 1).NextSibling
                If Child <> 0 Then Walk = Child: Exit Do
                Parent = Nodes(Walk - 1).Parent
                If Parent < 0 Or Parent > Count Then ValidateTree = 14: Exit Function
                Walk = Parent
            Loop
        End If
    Loop
    If Visits <> Count Then ValidateTree = 15: Exit Function
    ValidateTree = 0
    Exit Function
InvalidTree:
    ValidateTree = 16
End Function

' Checks complete reachability and source ownership for one independently retained module.
Public Function CheckTree(ByVal Slot As Long) As Long
    If Slot = 0 Then CheckTree = ValidateTree(FirstSource, FirstNodes, FirstCount, FirstRoot) Else CheckTree = ValidateTree(SecondSource, SecondNodes, SecondCount, SecondRoot)
End Function

' Allocates the exact path buffer consumed by the real file reader.
Public Function ConfigurePath(ByVal Length As Long) As Long
    Dim Status As Boolean
    Status = BufferPrimitives.TryResizeBytes(InputPath, Length, False)
    If Status = False Then ConfigurePath = 1 Else ConfigurePath = 0
End Function

' Installs one counted UTF-8 path byte through source-level storage.
Public Function SetPathByte(ByVal Index As Long, ByVal Value As Long) As Long
    InputPath(Index) = Value
    SetPathByte = 0
End Function

' Reads and scans new source without altering either previously retained module tree.
Public Function PrepareCandidate() As Long
    Dim Status As Boolean
    Dim Token As Long
    Dim Failure As Long
    Status = FileBytes.TryReadAllBytes(InputPath, 1048576, CandidateSource, Token, Failure)
    If Status = False Then
        Status = FilePrimitives.TryClose(Token, Failure)
        PrepareCandidate = 2
        Exit Function
    End If
    Status = SourceScanner.TryScan(CandidateSource, CandidateTokens, CandidateCount, ScanError)
    If Status = False Then PrepareCandidate = 1 Else PrepareCandidate = 0
End Function

' Parses into one caller-owned module slot and retains matching source only on success.
Public Function ParseCandidate(ByVal Slot As Long) As Long
    Dim Status As Boolean
    On Error GoTo Failed
    If Slot = 0 Then
        Status = SourceParser.TryParseModule(CandidateSource, CandidateTokens, CandidateCount, FirstNodes, FirstCount, FirstRoot, Diagnostic)
        If Status = False Then ParseCandidate = 1: Exit Function
        FirstSource = CandidateSource
        FirstTokens = CandidateTokens
    Else
        Status = SourceParser.TryParseModule(CandidateSource, CandidateTokens, CandidateCount, SecondNodes, SecondCount, SecondRoot, Diagnostic)
        If Status = False Then ParseCandidate = 1: Exit Function
        SecondSource = CandidateSource
        SecondTokens = CandidateTokens
    End If
    ParseCandidate = 0
    Exit Function
Failed:
    ParseCandidate = 2
End Function

' Returns the successful published count for one independent module slot.
Public Function TreeCount(ByVal Slot As Long) As Long
    If Slot = 0 Then TreeCount = FirstCount Else TreeCount = SecondCount
End Function

' Returns the caller-owned module root identity.
Public Function TreeRoot(ByVal Slot As Long) As Long
    If Slot = 0 Then TreeRoot = FirstRoot Else TreeRoot = SecondRoot
End Function

' Returns retained allocation length even when a subsequent parse reset its output count.
Public Function RetainedCount(ByVal Slot As Long) As Long
    If Slot = 0 Then RetainedCount = NodeStorageLength(FirstNodes) Else RetainedCount = NodeStorageLength(SecondNodes)
End Function

' Exposes scalar node fields without interpreting or reconstructing syntax.
Private Function FieldValue(ByRef Node As SourceParser.SyntaxNode, ByVal Field As Long) As Long
    If Field = 0 Then FieldValue = Node.Kind: Exit Function
    If Field = 1 Then FieldValue = Node.Value: Exit Function
    If Field = 2 Then FieldValue = Node.NameToken: Exit Function
    If Field = 3 Then FieldValue = Node.TypeFirstToken: Exit Function
    If Field = 4 Then FieldValue = Node.TypeLastToken: Exit Function
    If Field = 5 Then FieldValue = Node.FirstToken: Exit Function
    If Field = 6 Then FieldValue = Node.LastToken: Exit Function
    If Field = 7 Then FieldValue = Node.Parent: Exit Function
    If Field = 8 Then FieldValue = Node.FirstChild: Exit Function
    If Field = 9 Then FieldValue = Node.LastChild: Exit Function
    If Field = 10 Then FieldValue = Node.NextSibling: Exit Function
    If Field = 11 Then FieldValue = Node.ByteStart: Exit Function
    If Field = 12 Then FieldValue = Node.ByteLength: Exit Function
    If Field = 13 Then FieldValue = Node.Utf16Start: Exit Function
    If Field = 14 Then FieldValue = Node.Utf16Length: Exit Function
    If Field = 15 Then FieldValue = Node.Line: Exit Function
    If Field = 16 Then FieldValue = Node.Column: Exit Function
    If Field = 17 Then FieldValue = Node.Modifier: Exit Function
    If Field = 18 Then FieldValue = Node.Suffix: Exit Function
    If Field = 19 Then FieldValue = Node.IsIntrinsic: Exit Function
    Err.Raise 5
End Function

' Reads one retained node selected by its local one-based identity.
Public Function NodeField(ByVal Slot As Long, ByVal Identity As Long, ByVal Field As Long) As Long
    If Slot = 0 Then NodeField = FieldValue(FirstNodes(Identity - 1), Field) Else NodeField = FieldValue(SecondNodes(Identity - 1), Field)
End Function

' Locates a unique node by independently known syntax kind and original byte span.
Private Function FindInTree(ByRef Nodes() As SourceParser.SyntaxNode, ByVal Count As Long, ByVal Kind As Long, ByVal Start As Long, ByVal Length As Long) As Long
    Dim Index As Long
    Dim Found As Long
    Do While Index < Count
        If Nodes(Index).Kind = Kind And Nodes(Index).ByteStart = Start And Nodes(Index).ByteLength = Length Then
            If Found <> 0 Then FindInTree = -1: Exit Function
            Found = Index + 1
        End If
        Index = Index + 1
    Loop
    FindInTree = Found
End Function

' Exposes structural lookup without depending on incidental allocation order.
Public Function FindNode(ByVal Slot As Long, ByVal Kind As Long, ByVal Start As Long, ByVal Length As Long) As Long
    If Slot = 0 Then FindNode = FindInTree(FirstNodes, FirstCount, Kind, Start, Length) Else FindNode = FindInTree(SecondNodes, SecondCount, Kind, Start, Length)
End Function

' Exposes the exact first controlled diagnostic for host-authored source expectations.
Public Function DiagnosticField(ByVal Field As Long) As Long
    If Field = 0 Then DiagnosticField = Diagnostic.Code: Exit Function
    If Field = 1 Then DiagnosticField = Diagnostic.Reason: Exit Function
    If Field = 2 Then DiagnosticField = Diagnostic.TokenIndex: Exit Function
    If Field = 3 Then DiagnosticField = Diagnostic.ByteOffset: Exit Function
    If Field = 4 Then DiagnosticField = Diagnostic.Utf16Offset: Exit Function
    If Field = 5 Then DiagnosticField = Diagnostic.Line: Exit Function
    If Field = 6 Then DiagnosticField = Diagnostic.Column: Exit Function
    Err.Raise 5
End Function
