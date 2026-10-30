UBE SOURCE 1 MODULE
Attribute UBE_Name = "ProjectSources"

Type ImmutableSourceSnapshot
    SourceId As Long
    FilePath As String
    Contents As String
    ByteCount As Long
    ScalarCount As Long
    SourceKind As Long
    FormatKind As Long
    SourceName As String
    HeaderByteLength As Long
End Type

Type ProjectSourceSetResult
    Succeeded As Long
    ProjectId As Long
    ProjectName As String
    ProjectKind As String
    StartupName As String
    SourceCount As Long
    CombinedBytes As Long
    WorkUnits As LongLong
    Dump As String
End Type

Function SourceKindForPath(ByVal Path As String) As Long
    If CompilerTextLength(Path) < 4 Then SourceKindForPath = 0: Exit Function
    Dim Suffix As String = ""
    Call CompilerTextSlice(Path, CompilerTextLength(Path) - 4, 4, Suffix)
    If CompilerAsciiEqualsFolded(Suffix, ".bas") <> 0 Then SourceKindForPath = 1: Exit Function
    If CompilerAsciiEqualsFolded(Suffix, ".cls") <> 0 Then SourceKindForPath = 2: Exit Function
    If CompilerAsciiEqualsFolded(Suffix, ".frm") <> 0 Then SourceKindForPath = 3: Exit Function
    If CompilerAsciiEqualsFolded(Suffix, ".ctl") <> 0 Then
        SourceKindForPath = 4
    Else
        SourceKindForPath = 0
    End If
End Function

Function SourceKindWord(ByVal Kind As Long) As String
    If Kind = 1 Then SourceKindWord = "MODULE"
    If Kind = 2 Then SourceKindWord = "CLASS"
    If Kind = 3 Then SourceKindWord = "FORM"
    If Kind = 4 Then SourceKindWord = "CONTROL"
End Function

Function ParseManifestQuotedValue(ByVal ManifestLine As String, ByRef KeyText As String, ByRef ValueText As String) As Long
    KeyText = "": ValueText = ""
    Dim EqualOffset As Long = 0
    While EqualOffset < CompilerTextLength(ManifestLine) And CompilerTextByteAt(ManifestLine, EqualOffset) <> 61
        EqualOffset = EqualOffset + 1
    Wend
    If EqualOffset < 2 Or EqualOffset + 3 >= CompilerTextLength(ManifestLine) Then ParseManifestQuotedValue = 0: Exit Function
    Dim KeyEnd As Long = EqualOffset
    While KeyEnd > 0 And (CompilerTextByteAt(ManifestLine, KeyEnd - 1) = 32 Or CompilerTextByteAt(ManifestLine, KeyEnd - 1) = 9)
        KeyEnd = KeyEnd - 1
    Wend
    Call CompilerTextSlice(ManifestLine, 0, KeyEnd, KeyText)
    Dim Cursor As Long = EqualOffset + 1
    While Cursor < CompilerTextLength(ManifestLine) And (CompilerTextByteAt(ManifestLine, Cursor) = 32 Or CompilerTextByteAt(ManifestLine, Cursor) = 9)
        Cursor = Cursor + 1
    Wend
    If Cursor >= CompilerTextLength(ManifestLine) Or CompilerTextByteAt(ManifestLine, Cursor) <> 34 Then ParseManifestQuotedValue = 0: Exit Function
    Cursor = Cursor + 1
    While Cursor < CompilerTextLength(ManifestLine)
        Dim Current As Long = CompilerTextByteAt(ManifestLine, Cursor)
        If Current = 34 Then
            If Cursor + 1 < CompilerTextLength(ManifestLine) And CompilerTextByteAt(ManifestLine, Cursor + 1) = 34 Then
                ValueText = ValueText & CompilerTextFromByte(34)
                Cursor = Cursor + 2
            Else
                Cursor = Cursor + 1
                While Cursor < CompilerTextLength(ManifestLine) And (CompilerTextByteAt(ManifestLine, Cursor) = 32 Or CompilerTextByteAt(ManifestLine, Cursor) = 9)
                    Cursor = Cursor + 1
                Wend
                If Cursor = CompilerTextLength(ManifestLine) Then
                    ParseManifestQuotedValue = 1
                Else
                    ParseManifestQuotedValue = 0
                End If
                Exit Function
            End If
        Else
            If Current = 10 Or Current = 13 Then ParseManifestQuotedValue = 0: Exit Function
            ValueText = ValueText & CompilerTextFromByte(Current)
            Cursor = Cursor + 1
        End If
    Wend
    ParseManifestQuotedValue = 0
End Function

Function AppendProjectSource(ByRef Sources() As ImmutableSourceSnapshot, ByRef Count As Long, ByRef Capacity As Long, ByVal MaximumCount As Long, ByVal Path As String) As Long
    If Count >= MaximumCount Then AppendProjectSource = 0: Exit Function
    Dim Index As Long = 0
    While Index < Count
        If CompilerAsciiEqualsFolded(Sources(Index).FilePath, Path) <> 0 Then AppendProjectSource = 0: Exit Function
        Index = Index + 1
    Wend
    If Count = Capacity Then
        Dim NewCapacity As Long = 4
        If Capacity > 0 Then NewCapacity = Capacity * 2
        If NewCapacity > MaximumCount Then NewCapacity = MaximumCount
        If Capacity = 0 Then
            ReDim Sources(NewCapacity - 1)
        Else
            ReDim Preserve Sources(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Sources(Count).SourceId = Count + 1
    Sources(Count).FilePath = Path
    Count = Count + 1
    AppendProjectSource = 1
End Function

Function ValidateSourceHeader(ByRef Source As ImmutableSourceSnapshot) As Long
    Dim Cursor As Long = 0
    If Source.ByteCount >= 3 And CompilerTextByteAt(Source.Contents, 0) = 239 And CompilerTextByteAt(Source.Contents, 1) = 187 And CompilerTextByteAt(Source.Contents, 2) = 191 Then Cursor = 3
    Dim FirstLine As String = ""
    Dim FirstStart As Long = 0
    If ReadCompilerLine(Source.Contents, Cursor, FirstLine, FirstStart) = 0 Then ValidateSourceHeader = 0: Exit Function
    Dim Expected As String = "UBE SOURCE 1 " & SourceKindWord(Source.SourceKind)
    If CompilerAsciiEqualsFolded(FirstLine, Expected) = 0 Then
        If CompilerTextMatchesAt(FirstLine, 0, "VERSION ") = 0 And CompilerTextMatchesAt(FirstLine, 0, "Attribute VB_Name = ") = 0 Then ValidateSourceHeader = 0: Exit Function
        Source.FormatKind = 2
        Source.SourceName = "legacy"
        Source.HeaderByteLength = Cursor
        ValidateSourceHeader = 1
        Exit Function
    End If
    Dim SecondLine As String = ""
    Dim SecondStart As Long = 0
    If ReadCompilerLine(Source.Contents, Cursor, SecondLine, SecondStart) = 0 Then ValidateSourceHeader = 0: Exit Function
    Dim Prefix As String = "Attribute UBE_Name = "
    If CompilerTextMatchesAt(SecondLine, 0, Prefix) = 0 Or CompilerTextLength(SecondLine) <= CompilerTextLength(Prefix) + 1 Then ValidateSourceHeader = 0: Exit Function
    Source.SourceName = SecondLine
    Source.FormatKind = 1
    Source.HeaderByteLength = Cursor
    ValidateSourceHeader = 1
End Function

Function RunProjectSourcePhase(ByVal Session As BuildSession, ByRef Sources() As ImmutableSourceSnapshot, ByRef Result As ProjectSourceSetResult, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Result.Succeeded = 0
    Dim Manifest As String = ""
    If ReadRequiredCompilerText(Session.ProjectPath, Manifest) = 0 Then RunProjectSourcePhase = 0: Exit Function
    If CompilerTextLength(Manifest) > Session.MaximumManifestBytes Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3001", Session.ProjectPath, "project manifest exceeds the byte limit"): RunProjectSourcePhase = 0: Exit Function
    Dim Cursor As Long = 0
    Dim ManifestLine As String = ""
    Dim LineStart As Long = 0
    Dim LineNumber As Long = 0
    Dim SourceCapacity As Long = 0
    Dim HeaderSeen As Long = 0
    While ReadCompilerLine(Manifest, Cursor, ManifestLine, LineStart) <> 0
        LineNumber = LineNumber + 1
        If LineNumber > Session.MaximumManifestLines Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3001", Session.ProjectPath, "project manifest exceeds the line limit"): RunProjectSourcePhase = 0: Exit Function
        If HeaderSeen = 0 Then
            If ManifestLine <> "UBE-Project 1" Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3002", Session.ProjectPath, "invalid project header"): RunProjectSourcePhase = 0: Exit Function
            HeaderSeen = 1
        Else
            Dim TrimCursor As Long = 0
            While TrimCursor < CompilerTextLength(ManifestLine) And (CompilerTextByteAt(ManifestLine, TrimCursor) = 32 Or CompilerTextByteAt(ManifestLine, TrimCursor) = 9)
                TrimCursor = TrimCursor + 1
            Wend
            If TrimCursor < CompilerTextLength(ManifestLine) And CompilerTextByteAt(ManifestLine, TrimCursor) <> 39 Then
                Dim KeyText As String = ""
                Dim ValueText As String = ""
                If ParseManifestQuotedValue(ManifestLine, KeyText, ValueText) = 0 Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3003", Session.ProjectPath, "malformed project entry"): RunProjectSourcePhase = 0: Exit Function
                If CompilerAsciiEqualsFolded(KeyText, "Name") <> 0 Then
                    If Result.ProjectName <> "" Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3004", Session.ProjectPath, "duplicate project Name"): RunProjectSourcePhase = 0: Exit Function
                    Result.ProjectName = ValueText
                Else
                    If CompilerAsciiEqualsFolded(KeyText, "Kind") <> 0 Then
                        If Result.ProjectKind <> "" Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3004", Session.ProjectPath, "duplicate project Kind"): RunProjectSourcePhase = 0: Exit Function
                        Result.ProjectKind = ValueText
                    Else
                        If CompilerAsciiEqualsFolded(KeyText, "Startup") <> 0 Then
                            Result.StartupName = ValueText
                        Else
                            If CompilerAsciiEqualsFolded(KeyText, "Source") <> 0 Then
                                Dim Normalized As String = ""
                                If NormalizeCompilerRelativePath(ValueText, Normalized) = 0 Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3005", Session.ProjectPath, "invalid or escaping source path"): RunProjectSourcePhase = 0: Exit Function
                                Dim FullPath As String = CompilerPathPrefix(Session.ProjectPath) & Normalized
                                If SourceKindForPath(FullPath) = 0 Or AppendProjectSource(Sources, Result.SourceCount, SourceCapacity, Session.MaximumProjectSources, FullPath) = 0 Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3006", Session.ProjectPath, "unsupported, duplicate, or excessive source entry"): RunProjectSourcePhase = 0: Exit Function
                            Else
                                If CompilerAsciiEqualsFolded(KeyText, "Optimization") = 0 And CompilerAsciiEqualsFolded(KeyText, "DebugInformation") = 0 Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3007", Session.ProjectPath, "unknown Task 4 project key"): RunProjectSourcePhase = 0: Exit Function
                            End If
                        End If
                    End If
                End If
            End If
        End If
    Wend
    If Result.ProjectName = "" Or Result.ProjectKind = "" Or Result.SourceCount = 0 Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3008", Session.ProjectPath, "project requires Name, Kind, and Source"): RunProjectSourcePhase = 0: Exit Function
    Dim Index As Long = 0
    While Index < Result.SourceCount
        Sources(Index).Contents = ReadCompilerText(Sources(Index).FilePath)
        Sources(Index).ByteCount = CompilerTextLength(Sources(Index).Contents)
        Sources(Index).SourceKind = SourceKindForPath(Sources(Index).FilePath)
        If Sources(Index).ByteCount = 0 Or Sources(Index).ByteCount > Session.MaximumSourceBytes Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3009", Sources(Index).FilePath, "source is empty, unreadable, or exceeds the byte limit"): RunProjectSourcePhase = 0: Exit Function
        Dim InvalidOffset As Long = 0
        If ValidateCompilerUtf8(Sources(Index).Contents, InvalidOffset, Sources(Index).ScalarCount) = 0 Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3400", Sources(Index).FilePath, "source is not strict UTF-8 or contains a bare CR"): RunProjectSourcePhase = 0: Exit Function
        If ValidateSourceHeader(Sources(Index)) = 0 Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3401", Sources(Index).FilePath, "missing, unsupported, or mismatched source header"): RunProjectSourcePhase = 0: Exit Function
        Result.CombinedBytes = Result.CombinedBytes + Sources(Index).ByteCount
        If Result.CombinedBytes > Session.MaximumCombinedSourceBytes Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3010", Session.ProjectPath, "combined source bytes exceed the limit"): RunProjectSourcePhase = 0: Exit Function
        Index = Index + 1
    Wend
    Result.ProjectId = 1: Result.WorkUnits = CompilerTextLength(Manifest) + Result.CombinedBytes: Result.Succeeded = 1
    Call AppendPhaseField(Result.Dump, "phase", "project-sources")
    Call AppendPhaseField(Result.Dump, "sources", CompilerLongToText(Result.SourceCount))
    Call AppendPhaseField(Result.Dump, "bytes", CompilerLongToText(Result.CombinedBytes))
    RunProjectSourcePhase = 1
End Function
