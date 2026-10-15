Type SourceDocument
    SourceId As Long
    FilePath As String
    Contents As String
    CombinedStartByte As Long
    ByteLength As Long
End Type

Function LoadProjectSources(ByRef SourcePaths() As String, ByVal SourceCount As Long, ByRef Sources() As SourceDocument, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    If SourceCount <= 0 Or SourceCount > LimitProjectSources() Then
        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3100", "<project>", 1, 1, "project source count exceeds the configured limit")
        LoadProjectSources = 0
        Exit Function
    End If
    ReDim Sources(SourceCount - 1)
    Dim CombinedLength As Long = 0
    Dim Index As Long = 0
    While Index < SourceCount
        Sources(Index).SourceId = Index + 1
        Sources(Index).FilePath = SourcePaths(Index)
        Sources(Index).Contents = ReadAllText(SourcePaths(Index))
        Sources(Index).CombinedStartByte = CombinedLength
        Sources(Index).ByteLength = StringLength(Sources(Index).Contents)
        If Sources(Index).ByteLength > LimitSourceBytes() Then
            Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3101", Sources(Index).FilePath, 1, 1, "source exceeds the 16777216-byte limit")
            LoadProjectSources = 0
            Exit Function
        End If
        Dim InvalidByte As Long = -1
        If ValidateUtf8(Sources(Index).Contents, InvalidByte) = 0 Then
            Dim InvalidLine As Long = 1
            Dim InvalidColumn As Long = 1
            Call FindLineAndColumn(Sources(Index).Contents, InvalidByte, InvalidLine, InvalidColumn)
            Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3102", Sources(Index).FilePath, InvalidLine, InvalidColumn, "source is not valid UTF-8")
            LoadProjectSources = 0
            Exit Function
        End If
        CombinedLength = CombinedLength + Sources(Index).ByteLength
        If CombinedLength > LimitCombinedSourceBytes() Then
            Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3103", Sources(Index).FilePath, 1, 1, "combined project source exceeds the 67108864-byte limit")
            LoadProjectSources = 0
            Exit Function
        End If
        Index = Index + 1
    Wend
    LoadProjectSources = 1
End Function
