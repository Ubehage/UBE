UBE SOURCE 1 MODULE
Attribute UBE_Name = "ParserAllocationProbe"
' Observes parser output publication independently of candidate allocation and runtime depth.
Private Source() As Byte
Private Tokens() As SourceScanner.SourceToken
Private TokenCount As Long
Private Nodes() As SourceParser.SyntaxNode
Private NodeCount As Long
Private RootNode As Long
Private Diagnostic As SourceParser.ParseDiagnostic

' Creates caller-owned sentinel output before injecting parser allocation faults.
Private Intrinsic Function ResizeNodes(ByRef Values() As SourceParser.SyntaxNode, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeNodes.UBE_Primitive = "Array.TryResize"
End Function

' Measures retained array storage independently of the output count.
Private Intrinsic Function NodeLength(ByRef Values() As SourceParser.SyntaxNode) As Long
Attribute NodeLength.UBE_Primitive = "Array.Length"
End Function

' Scans the input before fault injection and installs distinct values in every prior node field.
Public Function Prepare(ByRef Data() As Byte) As Long
    Dim Status As Boolean
    Dim ScanError As SourceScanner.ScanDiagnostic
    On Error GoTo Failed
    Source = Data
    Status = SourceScanner.TryScan(Source, Tokens, TokenCount, ScanError)
    If Status = False Then Prepare = 1: Exit Function
    Status = ResizeNodes(Nodes, 1, False)
    If Status = False Then Prepare = 2: Exit Function
    Nodes(0).Kind = 101
    Nodes(0).Value = 102
    Nodes(0).Modifier = 103
    Nodes(0).Suffix = 104
    Nodes(0).IsIntrinsic = True
    Nodes(0).NameToken = 106
    Nodes(0).TypeFirstToken = 107
    Nodes(0).TypeLastToken = 108
    Nodes(0).FirstToken = 109
    Nodes(0).LastToken = 110
    Nodes(0).Parent = 111
    Nodes(0).FirstChild = 112
    Nodes(0).LastChild = 113
    Nodes(0).NextSibling = 114
    Nodes(0).ByteStart = 115
    Nodes(0).ByteLength = 116
    Nodes(0).Utf16Start = 117
    Nodes(0).Utf16Length = 118
    Nodes(0).Line = 119
    Nodes(0).Column = 120
    NodeCount = 777
    RootNode = 888
    Call Err.Clear()
    Prepare = 0
    Exit Function
Failed:
    Prepare = 99
End Function

' Checks every field of the old independent output after a rejected parse.
Private Function OldOutput() As Boolean
    On Error GoTo Failed
    If NodeLength(Nodes) <> 1 Then OldOutput = False: Exit Function
    If Nodes(0).Kind <> 101 Then OldOutput = False: Exit Function
    If Nodes(0).Value <> 102 Then OldOutput = False: Exit Function
    If Nodes(0).Modifier <> 103 Then OldOutput = False: Exit Function
    If Nodes(0).Suffix <> 104 Then OldOutput = False: Exit Function
    If Nodes(0).IsIntrinsic <> True Then OldOutput = False: Exit Function
    If Nodes(0).NameToken <> 106 Then OldOutput = False: Exit Function
    If Nodes(0).TypeFirstToken <> 107 Then OldOutput = False: Exit Function
    If Nodes(0).TypeLastToken <> 108 Then OldOutput = False: Exit Function
    If Nodes(0).FirstToken <> 109 Then OldOutput = False: Exit Function
    If Nodes(0).LastToken <> 110 Then OldOutput = False: Exit Function
    If Nodes(0).Parent <> 111 Then OldOutput = False: Exit Function
    If Nodes(0).FirstChild <> 112 Then OldOutput = False: Exit Function
    If Nodes(0).LastChild <> 113 Then OldOutput = False: Exit Function
    If Nodes(0).NextSibling <> 114 Then OldOutput = False: Exit Function
    If Nodes(0).ByteStart <> 115 Then OldOutput = False: Exit Function
    If Nodes(0).ByteLength <> 116 Then OldOutput = False: Exit Function
    If Nodes(0).Utf16Start <> 117 Then OldOutput = False: Exit Function
    If Nodes(0).Utf16Length <> 118 Then OldOutput = False: Exit Function
    If Nodes(0).Line <> 119 Then OldOutput = False: Exit Function
    If Nodes(0).Column <> 120 Then OldOutput = False: Exit Function
    OldOutput = True
    Exit Function
Failed:
    OldOutput = False
End Function

' Requires allocator failure to publish no tree while preserving all prior node fields.
Public Function RejectAllocation() As Long
    Dim Status As Boolean
    On Error GoTo Failed
    Status = SourceParser.TryParseModule(Source, Tokens, TokenCount, Nodes, NodeCount, RootNode, Diagnostic)
    If Status Then RejectAllocation = 1: Exit Function
    If NodeCount <> 0 Or RootNode <> 0 Then RejectAllocation = 2: Exit Function
    If Diagnostic.Code <> 5 Or Diagnostic.Reason <> 6 Then RejectAllocation = 3: Exit Function
    If Err.Number <> 7 Then RejectAllocation = 4: Exit Function
    If OldOutput() = False Then RejectAllocation = 5: Exit Function
    RejectAllocation = 0
    Exit Function
Failed:
    RejectAllocation = 99
End Function

' Checks the complete tree after fault removal and retains the preceding allocation error.
Public Function RetryParse() As Long
    Dim Status As Boolean
    On Error GoTo Failed
    Status = SourceParser.TryParseModule(Source, Tokens, TokenCount, Nodes, NodeCount, RootNode, Diagnostic)
    If Status = False Then RetryParse = 1: Exit Function
    If NodeCount <> 304 Or RootNode <> 1 Then RetryParse = 2: Exit Function
    If NodeLength(Nodes) <> 512 Then RetryParse = 3: Exit Function
    If Nodes(0).Kind <> SourceParser.ModuleNode Or Nodes(0).FirstChild <> 2 Then RetryParse = 4: Exit Function
    If Diagnostic.Code <> 0 Or Err.Number <> 7 Then RetryParse = 5: Exit Function
    RetryParse = 0
    Exit Function
Failed:
    RetryParse = 99
End Function

' Gives the outer caller an ordinary False if parser entry or a helper is refused.
Public Function DepthAttempt() As Boolean
    On Error GoTo Failed
    DepthAttempt = SourceParser.TryParseModule(Source, Tokens, TokenCount, Nodes, NodeCount, RootNode, Diagnostic)
    Exit Function
Failed:
    DepthAttempt = False
End Function

' Checks a complete successful parse or a preserved old tree after restoring the normal call depth.
Public Function CheckDepth(ByVal Success As Boolean) As Long
    On Error GoTo Failed
    If Success Then
        If NodeCount <> 304 Or RootNode <> 1 Then CheckDepth = 1: Exit Function
        If NodeLength(Nodes) <> 512 Or Diagnostic.Code <> 0 Then CheckDepth = 2: Exit Function
    Else
        If Err.Number <> 28 Then CheckDepth = 3: Exit Function
        If OldOutput() = False Then CheckDepth = 4: Exit Function
        If Diagnostic.Code = 0 Then
            If NodeCount <> 777 Or RootNode <> 888 Then CheckDepth = 5: Exit Function
        Else
            If NodeCount <> 0 Or RootNode <> 0 Then CheckDepth = 6: Exit Function
            If Diagnostic.Line < 1 Or Diagnostic.Column < 1 Or Diagnostic.Utf16Offset < 1 Then CheckDepth = 7: Exit Function
        End If
    End If
    CheckDepth = 0
    Exit Function
Failed:
    CheckDepth = 99
End Function
