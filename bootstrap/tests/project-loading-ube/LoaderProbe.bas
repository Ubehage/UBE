UBE SOURCE 1 MODULE
Attribute UBE_Name = "LoaderProbe"
' Observes project loading, diagnostic locations and explicit owner cleanup.

' Compares a checked span against independently supplied bytes.
Private Function SameSpan(ByRef Data() As Byte, ByVal Start As Long, ByVal Length As Long, ByRef Expected() As Byte) As Boolean
    Dim Index As Long
    If Start < 0 Or Length < 0 Then Exit Function
    If Length <> BufferPrimitives.ByteStorageLength(Expected) Then Exit Function
    If Start > BufferPrimitives.ByteStorageLength(Data) Then Exit Function
    If Length > BufferPrimitives.ByteStorageLength(Data) - Start Then Exit Function
    Do While Index < Length
        If Data(Start + Index) <> Expected(Index) Then Exit Function
        Index = Index + 1
    Loop
    SameSpan = True
End Function

' Mode1 rejects incoming ownership unchanged; mode2 requires retained failed-close ownership; mode3 expects allocation rejection.
Public Function CheckLoad(ByRef Path() As Byte, ByRef ExpectedBytes() As Byte, ByRef ExpectedFirst() As Byte, ByRef ExpectedLast() As Byte, ByVal Count As Long, ByVal Stage As Long, ByVal Code As Long, ByVal ModuleIndex As Long, ByVal LineNumber As Long, ByVal Mode As Long) As Long
    Dim PackageName() As Byte
    Dim PathBytes() As Byte
    Dim Paths() As ProjectLoader.SourcePath
    Dim Bytes() As Byte
    Dim Tokens() As SourceScanner.SourceToken
    Dim Nodes() As SourceParser.SyntaxNode
    Dim Modules() As ProjectSyntax.ParsedModule
    Dim Counts As ProjectSyntax.ProjectCounts
    Dim Info As ProjectManifest.ManifestInfo
    Dim Diagnostic As ProjectLoader.LoadDiagnostic
    Dim Token As Long
    Dim PreviousToken As Long
    Dim Length As Long
    Dim Failure As Long
    Dim Status As Boolean
    On Error GoTo Failed
    Counts.ModuleCount = 77
    Info.SourceCount = 88
    If Mode = 1 Then
        If FilePrimitives.TryOpen(Path, 65536, Token, Length, Failure) = False Then CheckLoad = 1: GoTo Cleanup
        PreviousToken = Token
    End If
    Status = FilePrimitives.SetError(91)
    Status = ProjectLoader.TryLoad(Path, PackageName, PathBytes, Paths, Bytes, Tokens, Nodes, Modules, Counts, Info, Diagnostic, Token)
    If Mode = 1 Then
        If Status Or Token <> PreviousToken Or Counts.ModuleCount <> 77 Or Info.SourceCount <> 88 Then CheckLoad = 2: GoTo Cleanup
    ElseIf Stage <> 0 Or Mode = 3 Then
        If Status Or Counts.ModuleCount <> 0 Or Counts.ByteCount <> 0 Or Counts.TokenCount <> 0 Or Counts.NodeCount <> 0 Or Info.SourceCount <> 0 Then CheckLoad = 3: GoTo Cleanup
    Else
        If Status = False Or Counts.ModuleCount <> Count Or Info.SourceCount <> Count Then CheckLoad = 4: GoTo Cleanup
        If Err.Number <> 91 Then CheckLoad = 5: GoTo Cleanup
        If ProjectSyntax.IsValidProject(Bytes, Tokens, Nodes, Modules, Counts) = False Then CheckLoad = 6: GoTo Cleanup
        If SameSpan(Bytes, 0, Counts.ByteCount, ExpectedBytes) = False Then CheckLoad = 7: GoTo Cleanup
        If SameSpan(PathBytes, Paths(0).Start, Paths(0).Length, ExpectedFirst) = False Then CheckLoad = 8: GoTo Cleanup
        If SameSpan(PathBytes, Paths(Count - 1).Start, Paths(Count - 1).Length, ExpectedLast) = False Then CheckLoad = 9: GoTo Cleanup
    End If
    If Mode = 3 Then
        If Diagnostic.Stage = 0 Or Diagnostic.Code = 0 Then CheckLoad = 10: GoTo Cleanup
    Else
        If Diagnostic.Stage <> Stage Or Diagnostic.Code <> Code Then CheckLoad = 11: GoTo Cleanup
        If Code = 5 And (Stage = 3 Or Stage = 7) And Err.Number <> 57 Then CheckLoad = 18: GoTo Cleanup
        If Stage <> 0 Then
            If Diagnostic.ModuleIndex <> ModuleIndex Or Diagnostic.Line <> LineNumber Then CheckLoad = 12: GoTo Cleanup
            If Diagnostic.Stage = 8 Then
                If SameSpan(PathBytes, Diagnostic.PathStart, Diagnostic.PathLength, ExpectedLast) = False Then CheckLoad = 13: GoTo Cleanup
            End If
        End If
    End If
    If Mode = 2 Then
        If Token <= 0 Then CheckLoad = 14: GoTo Cleanup
    ElseIf Mode <> 1 Then
        If Token <> 0 Then CheckLoad = 15: GoTo Cleanup
    End If
Cleanup:
    If Token <> 0 Then
        If FilePrimitives.TryClose(Token, Failure) = False Then CheckLoad = 16
    End If
    Exit Function
Failed:
    CheckLoad = 17
    GoTo Cleanup
End Function

