Type ProjectDescription
    Name As String
    Kind As String
    Startup As String
    StartupForm As String
    ManifestPath As String
    ProjectDirectory As String
    SourceCount As Long
    ResourceCount As Long
    ReferenceCount As Long
End Type

Function HasSuffix(ByVal Value As String, ByVal Suffix As String) As Long
    Dim ValueLength As Long = StringLength(Value)
    Dim SuffixLength As Long = StringLength(Suffix)
    If ValueLength < SuffixLength Then
        HasSuffix = 0
        Exit Function
    End If
    HasSuffix = EqualsFolded(StringSlice(Value, ValueLength - SuffixLength, SuffixLength), Suffix)
End Function

Function IsSupportedSourcePath(ByVal Value As String) As Long
    If HasSuffix(Value, ".bas") <> 0 Or HasSuffix(Value, ".cls") <> 0 Or HasSuffix(Value, ".frm") <> 0 Or HasSuffix(Value, ".ctl") <> 0 Then
        IsSupportedSourcePath = 1
    Else
        IsSupportedSourcePath = 0
    End If
End Function

Function NormalizeRelativePath(ByVal Value As String, ByRef Normalized As String) As Long
    Normalized = ""
    Dim ValueLength As Long = StringLength(Value)
    If ValueLength = 0 Then
        NormalizeRelativePath = 0
        Exit Function
    End If
    Dim FirstByte As Long = StringByteAt(Value, 0)
    If FirstByte = 47 Or FirstByte = 92 Then
        NormalizeRelativePath = 0
        Exit Function
    End If
    If StringIndexOf(Value, ":", 0) >= 0 Then
        NormalizeRelativePath = 0
        Exit Function
    End If
    Dim SegmentStart As Long = 0
    Dim Index As Long = 0
    While Index <= ValueLength
        Dim Separator As Long = 0
        If Index = ValueLength Then
            Separator = 1
        Else
            Dim CurrentByte As Long = StringByteAt(Value, Index)
            If CurrentByte = 47 Or CurrentByte = 92 Then
                Separator = 1
            End If
        End If
        If Separator <> 0 Then
            Dim SegmentLength As Long = Index - SegmentStart
            If SegmentLength = 0 Then
                NormalizeRelativePath = 0
                Exit Function
            End If
            Dim Segment As String = StringSlice(Value, SegmentStart, SegmentLength)
            If Segment = ".." Then
                NormalizeRelativePath = 0
                Exit Function
            End If
            If Segment <> "." Then
                If StringLength(Normalized) > 0 Then
                    Normalized = Normalized & "/"
                End If
                Normalized = Normalized & Segment
            End If
            SegmentStart = Index + 1
        End If
        Index = Index + 1
    Wend
    If StringLength(Normalized) = 0 Then
        NormalizeRelativePath = 0
    Else
        NormalizeRelativePath = 1
    End If
End Function

Function ParseQuotedManifestValue(ByVal RawValue As String, ByRef Result As String) As Long
    Result = ""
    Dim Length As Long = StringLength(RawValue)
    If Length < 2 Then
        ParseQuotedManifestValue = 0
        Exit Function
    End If
    If StringByteAt(RawValue, 0) <> 34 Or StringByteAt(RawValue, Length - 1) <> 34 Then
        ParseQuotedManifestValue = 0
        Exit Function
    End If
    Dim Index As Long = 1
    While Index < Length - 1
        Dim CurrentByte As Long = StringByteAt(RawValue, Index)
        If CurrentByte = 34 Then
            If Index + 1 >= Length - 1 Then
                ParseQuotedManifestValue = 0
                Exit Function
            End If
            If StringByteAt(RawValue, Index + 1) <> 34 Then
                ParseQuotedManifestValue = 0
                Exit Function
            End If
            Result = Result & StringFromByte(34)
            Index = Index + 2
        Else
            Result = Result & StringFromByte(CurrentByte)
            Index = Index + 1
        End If
    Wend
    ParseQuotedManifestValue = 1
End Function

Function IsProjectIdentifier(ByVal Value As String) As Long
    Dim Length As Long = StringLength(Value)
    If Length = 0 Then
        IsProjectIdentifier = 0
        Exit Function
    End If
    Dim Index As Long = 0
    Dim First As Long = 1
    While Index < Length
        Dim CodePoint As Long = 0
        Dim ByteCount As Long = 0
        If DecodeUtf8CodePoint(Value, Index, CodePoint, ByteCount) = 0 Then
            IsProjectIdentifier = 0
            Exit Function
        End If
        Dim Valid As Long = 0
        If UnicodeIsLetter(CodePoint) <> 0 Or CodePoint = 95 Then
            Valid = 1
        Else
            If First = 0 And CodePoint >= 48 And CodePoint <= 57 Then
                Valid = 1
            End If
        End If
        If Valid = 0 Then
            IsProjectIdentifier = 0
            Exit Function
        End If
        First = 0
        Index = Index + ByteCount
    Wend
    IsProjectIdentifier = 1
End Function

Function PathAlreadyListed(ByRef Paths() As String, ByVal Count As Long, ByVal Candidate As String) As Long
    Dim Index As Long = 0
    While Index < Count
        If EqualsFolded(Paths(Index), Candidate) <> 0 Then
            PathAlreadyListed = 1
            Exit Function
        End If
        Index = Index + 1
    Wend
    PathAlreadyListed = 0
End Function

Sub FindProjectDirectory(ByVal ManifestPath As String, ByRef Directory As String)
    Directory = ""
    Dim Index As Long = StringLength(ManifestPath) - 1
    While Index >= 0
        Dim CurrentByte As Long = StringByteAt(ManifestPath, Index)
        If CurrentByte = 47 Or CurrentByte = 92 Then
            Directory = StringSlice(ManifestPath, 0, Index + 1)
            Exit Sub
        End If
        Index = Index - 1
    Wend
End Sub

Function LoadProjectManifest(ByVal ManifestPath As String, ByRef Project As ProjectDescription, ByRef SourcePaths() As String, ByRef SourceCount As Long, ByRef SourceCapacity As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    If HasSuffix(ManifestPath, ".UBE") = 0 Then
        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3000", ManifestPath, 1, 1, "normal builds require a .UBE project manifest")
        LoadProjectManifest = 0
        Exit Function
    End If
    Dim Contents As String = ReadAllText(ManifestPath)
    Dim ContentsLength As Long = StringLength(Contents)
    If ContentsLength > LimitManifestBytes() Then
        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3001", ManifestPath, 1, 1, "project manifest exceeds the 1048576-byte limit")
        LoadProjectManifest = 0
        Exit Function
    End If
    Dim InvalidByte As Long = -1
    If ValidateUtf8(Contents, InvalidByte) = 0 Then
        Dim InvalidLine As Long = 1
        Dim InvalidColumn As Long = 1
        Call FindLineAndColumn(Contents, InvalidByte, InvalidLine, InvalidColumn)
        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3002", ManifestPath, InvalidLine, InvalidColumn, "project manifest is not valid UTF-8")
        LoadProjectManifest = 0
        Exit Function
    End If

    Project.ManifestPath = ManifestPath
    Call FindProjectDirectory(ManifestPath, Project.ProjectDirectory)
    SourceCount = 0
    Dim ResourcePaths() As String
    Dim ResourceCount As Long = 0
    Dim ResourceCapacity As Long = 0
    Dim ReferencePaths() As String
    Dim ReferenceCount As Long = 0
    Dim ReferenceCapacity As Long = 0
    Dim SawHeader As Long = 0
    Dim SawName As Long = 0
    Dim SawKind As Long = 0
    Dim SawStartup As Long = 0
    Dim SawStartupForm As Long = 0
    Dim Cursor As Long = 0
    Dim LineNumber As Long = 0
    While Cursor <= ContentsLength
        Dim LineEnd As Long = StringIndexOf(Contents, StringFromByte(10), Cursor)
        If LineEnd < 0 Then
            LineEnd = ContentsLength
        End If
        LineNumber = LineNumber + 1
        If LineNumber > LimitManifestLines() Then
            Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3003", ManifestPath, LineNumber, 1, "project manifest exceeds the 100000-line limit")
            LoadProjectManifest = 0
            Exit Function
        End If
        Dim Line As String = ""
        Call TrimText(StringSlice(Contents, Cursor, LineEnd - Cursor), Line)
        If StringLength(Line) > 0 Then
            If StringByteAt(Line, 0) <> 39 Then
                If SawHeader = 0 Then
                    If Line <> "UBE-Project 1" Then
                        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3004", ManifestPath, LineNumber, 1, "project manifest must begin with UBE-Project 1")
                        LoadProjectManifest = 0
                        Exit Function
                    End If
                    SawHeader = 1
                Else
                    Dim EqualsIndex As Long = StringIndexOf(Line, "=", 0)
                    If EqualsIndex < 1 Then
                        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3005", ManifestPath, LineNumber, 1, "malformed project entry")
                        LoadProjectManifest = 0
                        Exit Function
                    End If
                    Dim Key As String = ""
                    Dim RawValue As String = ""
                    Call TrimText(StringSlice(Line, 0, EqualsIndex), Key)
                    Call TrimText(StringSlice(Line, EqualsIndex + 1, StringLength(Line) - EqualsIndex - 1), RawValue)
                    Dim EntryValue As String = ""
                    If ParseQuotedManifestValue(RawValue, EntryValue) = 0 Then
                        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3006", ManifestPath, LineNumber, EqualsIndex + 2, "project values must be complete quoted strings")
                        LoadProjectManifest = 0
                        Exit Function
                    End If
                    If EqualsFolded(Key, "Name") <> 0 Then
                        If SawName <> 0 Or IsProjectIdentifier(EntryValue) = 0 Then
                            Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3007", ManifestPath, LineNumber, 1, "Name must be one unique UBE identifier")
                            LoadProjectManifest = 0
                            Exit Function
                        End If
                        Project.Name = EntryValue
                        SawName = 1
                    Else
                        If EqualsFolded(Key, "Kind") <> 0 Then
                            If SawKind <> 0 Then
                                Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3008", ManifestPath, LineNumber, 1, "duplicate project Kind")
                                LoadProjectManifest = 0
                                Exit Function
                            End If
                            If EqualsFolded(EntryValue, "Exe") = 0 And EqualsFolded(EntryValue, "Library") = 0 Then
                                Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3009", ManifestPath, LineNumber, 1, "Kind must be Exe or Library")
                                LoadProjectManifest = 0
                                Exit Function
                            End If
                            Project.Kind = EntryValue
                            SawKind = 1
                        Else
                            If EqualsFolded(Key, "Startup") <> 0 Then
                                If SawStartup <> 0 Then
                                    Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3010", ManifestPath, LineNumber, 1, "duplicate project Startup")
                                    LoadProjectManifest = 0
                                    Exit Function
                                End If
                                Project.Startup = EntryValue
                                SawStartup = 1
                            Else
                                If EqualsFolded(Key, "StartupForm") <> 0 Then
                                    If SawStartupForm <> 0 Or IsProjectIdentifier(EntryValue) = 0 Then
                                        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3011", ManifestPath, LineNumber, 1, "StartupForm must be one unique UBE identifier")
                                        LoadProjectManifest = 0
                                        Exit Function
                                    End If
                                    Project.StartupForm = EntryValue
                                    SawStartupForm = 1
                                Else
                                    Dim NormalizedPath As String = ""
                                    If EqualsFolded(Key, "Source") <> 0 Then
                                        If NormalizeRelativePath(EntryValue, NormalizedPath) = 0 Or IsSupportedSourcePath(NormalizedPath) = 0 Then
                                            Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3012", ManifestPath, LineNumber, 1, "Source must be a safe relative .bas, .cls, .frm, or .ctl path")
                                            LoadProjectManifest = 0
                                            Exit Function
                                        End If
                                        If PathAlreadyListed(SourcePaths, SourceCount, NormalizedPath) <> 0 Then
                                            Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3013", ManifestPath, LineNumber, 1, "duplicate Source after path normalization: " & EntryValue)
                                            LoadProjectManifest = 0
                                            Exit Function
                                        End If
                                        If AppendString(SourcePaths, SourceCount, SourceCapacity, NormalizedPath, LimitProjectSources()) = 0 Then
                                            Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3014", ManifestPath, LineNumber, 1, "project exceeds the 1024-source limit")
                                            LoadProjectManifest = 0
                                            Exit Function
                                        End If
                                    Else
                                        If EqualsFolded(Key, "Resource") <> 0 Then
                                            If NormalizeRelativePath(EntryValue, NormalizedPath) = 0 Or HasSuffix(NormalizedPath, ".UBR") = 0 Then
                                                Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3015", ManifestPath, LineNumber, 1, "Resource must be a safe relative .UBR path")
                                                LoadProjectManifest = 0
                                                Exit Function
                                            End If
                                            If PathAlreadyListed(ResourcePaths, ResourceCount, NormalizedPath) <> 0 Or AppendString(ResourcePaths, ResourceCount, ResourceCapacity, NormalizedPath, LimitProjectResources()) = 0 Then
                                                Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3016", ManifestPath, LineNumber, 1, "duplicate Resource or resource limit exceeded")
                                                LoadProjectManifest = 0
                                                Exit Function
                                            End If
                                        Else
                                            If EqualsFolded(Key, "Reference") <> 0 Then
                                                If NormalizeRelativePath(EntryValue, NormalizedPath) = 0 Or HasSuffix(NormalizedPath, ".UBE") = 0 Then
                                                    Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3017", ManifestPath, LineNumber, 1, "Reference must be a safe relative .UBE path")
                                                    LoadProjectManifest = 0
                                                    Exit Function
                                                End If
                                                If PathAlreadyListed(ReferencePaths, ReferenceCount, NormalizedPath) <> 0 Or AppendString(ReferencePaths, ReferenceCount, ReferenceCapacity, NormalizedPath, LimitProjectReferences()) = 0 Then
                                                    Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3018", ManifestPath, LineNumber, 1, "duplicate Reference or reference limit exceeded")
                                                    LoadProjectManifest = 0
                                                    Exit Function
                                                End If
                                            Else
                                                Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3019", ManifestPath, LineNumber, 1, "unsupported project key: " & Key)
                                                LoadProjectManifest = 0
                                                Exit Function
                                            End If
                                        End If
                                    End If
                                End If
                            End If
                        End If
                    End If
                End If
            End If
        End If
        If LineEnd = ContentsLength Then
            Exit While
        End If
        Cursor = LineEnd + 1
    Wend

    If SawHeader = 0 Or SawName = 0 Or SawKind = 0 Or SourceCount = 0 Then
        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3020", ManifestPath, 1, 1, "project requires Name, Kind, and at least one Source")
        LoadProjectManifest = 0
        Exit Function
    End If
    If EqualsFolded(Project.Kind, "Exe") <> 0 Then
        If SawStartup = 0 Or EqualsFolded(Project.Startup, "Main") = 0 Then
            Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3021", ManifestPath, 1, 1, "executable projects require Startup = " & StringFromByte(34) & "Main" & StringFromByte(34))
            LoadProjectManifest = 0
            Exit Function
        End If
    Else
        If SawStartup <> 0 Or SawStartupForm <> 0 Then
            Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3022", ManifestPath, 1, 1, "library projects cannot declare Startup or StartupForm")
            LoadProjectManifest = 0
            Exit Function
        End If
    End If

    Project.SourceCount = SourceCount
    Project.ResourceCount = ResourceCount
    Project.ReferenceCount = ReferenceCount
    Dim SourceIndex As Long = 0
    While SourceIndex < SourceCount
        SourcePaths(SourceIndex) = Project.ProjectDirectory & SourcePaths(SourceIndex)
        SourceIndex = SourceIndex + 1
    Wend
    LoadProjectManifest = 1
End Function
