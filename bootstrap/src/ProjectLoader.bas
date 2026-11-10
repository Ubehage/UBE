Attribute VB_Name = "ProjectLoader"
Option Explicit

' Loads bounded native MODULE sources in manifest order for later compiler passes.
Public Const MaximumManifestBytes As Long = 65536
Public Const MaximumSourceBytes As Long = 1048576
Public Const MaximumProjectBytes As Long = 8388608
Public Const MaximumSources As Long = 128
Public Const MaximumIdentifierCharacters As Long = 128

Public Type SourceUnit
    ModuleName As String
    FilePath As String
    SourceText As String
    ByteCount As Long
End Type

Public Type ProjectContext
    ProjectName As String
    KindName As String
    StartupName As String
    OptimizationName As String
    DebugInformationName As String
    ManifestPath As String
    RootPath As String
    SourceCount As Long
    Sources() As SourceUnit
End Type

' Folds the supported ASCII identity subset without locale-sensitive casing.
Public Function FoldAscii(ByVal Text As String) As String
    Dim Index As Long
    Dim Code As Long
    For Index = 1 To Len(Text)
        Code = AscW(Mid$(Text, Index, 1))
        If Code >= 65 And Code <= 90 Then Mid$(Text, Index, 1) = ChrW$(Code + 32)
    Next Index
    FoldAscii = Text
End Function

' Trims only the horizontal whitespace allowed around manifest tokens.
Private Function TrimHorizontal(ByVal Text As String) As String
    Dim First As Long
    Dim Last As Long
    First = 1
    Last = Len(Text)
    Do While First <= Last
        If Mid$(Text, First, 1) <> " " And Mid$(Text, First, 1) <> vbTab Then Exit Do
        First = First + 1
    Loop
    Do While Last >= First
        If Mid$(Text, Last, 1) <> " " And Mid$(Text, Last, 1) <> vbTab Then Exit Do
        Last = Last - 1
    Loop
    If Last >= First Then TrimHorizontal = Mid$(Text, First, Last - First + 1)
End Function

' Returns a bounded ASCII name; Unicode identities await the versioned Unicode tables.
Private Function ValidIdentifier(ByVal Text As String) As Boolean
    Dim Index As Long
    Dim Code As Long
    If Len(Text) < 1 Or Len(Text) > MaximumIdentifierCharacters Then Exit Function
    For Index = 1 To Len(Text)
        Code = AscW(Mid$(Text, Index, 1))
        If Not ((Code >= 65 And Code <= 90) Or (Code >= 97 And Code <= 122) Or Code = 95) Then
            If Index = 1 Or Code < 48 Or Code > 57 Then Exit Function
        End If
    Next Index
    ValidIdentifier = True
End Function

' Parses one quoted value, accepting doubled quotes and rejecting trailing tokens.
Private Function QuotedValue(ByVal Text As String, ByRef Value As String) As Boolean
    Dim Index As Long
    Dim Character As String
    Text = TrimHorizontal(Text)
    If Len(Text) < 2 Then Exit Function
    If Left$(Text, 1) <> Chr$(34) Then Exit Function
    Index = 2
    Value = ""
    Do While Index <= Len(Text)
        Character = Mid$(Text, Index, 1)
        If Character = Chr$(34) Then
            If Index < Len(Text) Then
                If Mid$(Text, Index + 1, 1) = Chr$(34) Then
                    Value = Value & Character
                    Index = Index + 2
                Else
                    If Len(TrimHorizontal(Mid$(Text, Index + 1))) <> 0 Then Exit Function
                    QuotedValue = True
                    Exit Function
                End If
            Else
                QuotedValue = True
                Exit Function
            End If
        Else
            Value = Value & Character
            Index = Index + 1
        End If
    Loop
End Function

' Splits a scalar key/value line without treating equals signs inside its value as syntax.
Private Function ParseEntry(ByVal Line As String, ByRef Key As String, ByRef Value As String) As Boolean
    Dim Position As Long
    Position = InStr(Line, "=")
    If Position < 2 Then Exit Function
    Key = FoldAscii(TrimHorizontal(Left$(Line, Position - 1)))
    If Not ValidIdentifier(Key) Then Exit Function
    ParseEntry = QuotedValue(Mid$(Line, Position + 1), Value)
End Function

' Collapses whitespace in unquoted native-header words only.
Private Function HeaderWords(ByVal Text As String) As String
    Text = TrimHorizontal(Replace(Text, vbTab, " "))
    Do While InStr(Text, "  ") > 0
        Text = Replace(Text, "  ", " ")
    Loop
    HeaderWords = FoldAscii(Text)
End Function

' Removes a UBE apostrophe comment outside strings for identity-header validation.
Private Function WithoutComment(ByVal Text As String) As String
    Dim Index As Long
    Dim InString As Boolean
    Dim Character As String
    For Index = 1 To Len(Text)
        Character = Mid$(Text, Index, 1)
        If Character = Chr$(34) Then InString = Not InString
        If Character = "'" And Not InString Then
            WithoutComment = Left$(Text, Index - 1)
            Exit Function
        End If
    Next Index
    WithoutComment = Text
End Function

' Validates native source identity without claiming that the body is parsed.
Private Function ValidateSource(ByRef Source As SourceUnit, ByRef Diagnostic As String) As Boolean
    Dim Lines() As String
    Dim Index As Long
    Dim Line As String
    Dim Key As String
    Dim Value As String
    Dim State As Long
    Dim Context As String
    Lines = Split(Replace(Source.SourceText, vbCrLf, vbLf), vbLf)
    For Index = 0 To UBound(Lines)
        Line = TrimHorizontal(WithoutComment(Lines(Index)))
        If Len(Line) > 0 Then
            Context = Source.FilePath & ":" & CStr(Index + 1)
            If State = 0 Then
                If HeaderWords(Line) <> "ube source 1 module" Then
                    ValidateSource = Reject(Diagnostic, "E_SOURCE_HEADER", Context & " expected UBE SOURCE 1 MODULE")
                    Exit Function
                End If
                State = 1
            ElseIf State = 1 Then
                If FoldAscii(Left$(Line, 10)) <> "attribute " And FoldAscii(Left$(Line, 10)) <> "attribute" & vbTab Then
                    ValidateSource = Reject(Diagnostic, "E_SOURCE_IDENTITY", Context & " expected Attribute UBE_Name")
                    Exit Function
                End If
                If Not ParseEntry(TrimHorizontal(Mid$(Line, 10)), Key, Value) Then
                    ValidateSource = Reject(Diagnostic, "E_SOURCE_IDENTITY", Context & " invalid identity attribute")
                    Exit Function
                End If
                If Key <> "ube_name" Then
                    ValidateSource = Reject(Diagnostic, "E_SOURCE_IDENTITY", Context & " expected UBE_Name")
                    Exit Function
                End If
                If Not ValidIdentifier(Value) Then
                    ValidateSource = Reject(Diagnostic, "E_IDENTIFIER", Context & " unsupported module identifier")
                    Exit Function
                End If
                Source.ModuleName = Value
                State = 2
            Else
                If FoldAscii(Left$(Line, 10)) = "attribute " Or FoldAscii(Left$(Line, 10)) = "attribute" & vbTab Then
                    If ParseEntry(TrimHorizontal(Mid$(Line, 10)), Key, Value) Then
                        If Key = "ube_name" Then
                            ValidateSource = Reject(Diagnostic, "E_SOURCE_IDENTITY", Context & " duplicate UBE_Name")
                            Exit Function
                        End If
                        If Left$(Key, 4) = "ube_" Then
                            ValidateSource = Reject(Diagnostic, "E_SOURCE_IDENTITY", Context & " unknown reserved UBE attribute")
                            Exit Function
                        End If
                    Else
                        ValidateSource = Reject(Diagnostic, "E_SOURCE_IDENTITY", Context & " malformed header attribute")
                        Exit Function
                    End If
                Else
                    Exit For
                End If
            End If
        End If
    Next Index
    If State <> 2 Then
        If State = 0 Then
            ValidateSource = Reject(Diagnostic, "E_SOURCE_HEADER", Source.FilePath & " missing native source header")
        Else
            ValidateSource = Reject(Diagnostic, "E_SOURCE_IDENTITY", Source.FilePath & " missing native source identity")
        End If
        Exit Function
    End If
    ValidateSource = True
End Function

' Admits only explicit relative source paths and keeps lexical and physical containment.
Private Function LoadSource(ByVal Relative As String, ByRef Project As ProjectContext, ByRef TotalBytes As Long, ByRef Diagnostic As String) As Boolean
    Dim Path As String
    Dim Canonical As String
    Dim Index As Long
    Dim Current As Long
    Dim Character As String
    If Len(Relative) = 0 Or Len(Relative) > MaximumPathCharacters Then GoTo InvalidPath
    Relative = Replace(Relative, "/", "\")
    If Left$(Relative, 1) = "\" Then GoTo InvalidPath
    For Index = 1 To Len(Relative)
        Character = Mid$(Relative, Index, 1)
        If InStr(":*?<>|" & Chr$(34), Character) > 0 Or (AscW(Character) And &HFFFF&) < 32 Then GoTo InvalidPath
    Next Index
    If FoldAscii(Right$(Relative, 4)) <> ".bas" Then
        LoadSource = Reject(Diagnostic, "E_UNSUPPORTED", "only native .bas MODULE sources are supported")
        Exit Function
    End If
    If Project.SourceCount >= MaximumSources Then
        LoadSource = Reject(Diagnostic, "E_LIMIT", "too many source modules")
        Exit Function
    End If
    If Not FullPath(Project.RootPath & "\" & Relative, Path, Diagnostic) Then Exit Function
    If Not PathWithin(Project.RootPath, Path) Then GoTo InvalidPath
    For Index = 0 To Project.SourceCount - 1
        If SamePath(Path, Project.Sources(Index).FilePath) Then GoTo DuplicateSource
    Next Index
    Current = Project.SourceCount
    If Not ReadUtf8File(Path, MaximumSourceBytes, Project.Sources(Current).SourceText, Canonical, Project.Sources(Current).ByteCount, Diagnostic, Project.RootPath) Then Exit Function
    If Not PathWithin(Project.RootPath, Canonical) Then GoTo InvalidPath
    For Index = 0 To Project.SourceCount - 1
        If SamePath(Canonical, Project.Sources(Index).FilePath) Then GoTo DuplicateSource
    Next Index
    If Project.Sources(Current).ByteCount > MaximumProjectBytes - TotalBytes Then
        LoadSource = Reject(Diagnostic, "E_LIMIT", "project source byte limit exceeded")
        Exit Function
    End If
    Project.Sources(Current).FilePath = Canonical
    If Not ValidateSource(Project.Sources(Current), Diagnostic) Then Exit Function
    For Index = 0 To Project.SourceCount - 1
        If FoldAscii(Project.Sources(Index).ModuleName) = FoldAscii(Project.Sources(Current).ModuleName) Then
            LoadSource = Reject(Diagnostic, "E_DUPLICATE_MODULE", Project.Sources(Current).ModuleName)
            Exit Function
        End If
    Next Index
    TotalBytes = TotalBytes + Project.Sources(Current).ByteCount
    Project.SourceCount = Project.SourceCount + 1
    LoadSource = True
    Exit Function
InvalidPath:
    LoadSource = Reject(Diagnostic, "E_PATH", "source path is invalid or escapes project directory: " & Relative)
    Exit Function
DuplicateSource:
    LoadSource = Reject(Diagnostic, "E_DUPLICATE_SOURCE", Relative)
End Function

' Reads a manifest and retains validated source texts in the caller-owned context.
Public Function LoadProject(ByVal Path As String, ByRef Project As ProjectContext, ByRef Diagnostic As String) As Boolean
    Dim Text As String
    Dim Canonical As String
    Dim Bytes As Long
    Dim TotalBytes As Long
    Dim Lines() As String
    Dim Index As Long
    Dim Position As Long
    Dim Line As String
    Dim Key As String
    Dim Value As String
    Dim Seen As String
    Dim HeaderSeen As Boolean
    Dim Context As String
    On Error GoTo Unexpected
    Project.SourceCount = 0
    Project.ProjectName = ""
    Project.KindName = ""
    Project.StartupName = ""
    Project.OptimizationName = "2"
    Project.DebugInformationName = "Full"
    ReDim Project.Sources(0 To MaximumSources - 1)
    If FoldAscii(Right$(Path, 4)) <> ".ube" Then
        LoadProject = Reject(Diagnostic, "E_UNSUPPORTED", "expected a .UBE project manifest")
        Exit Function
    End If
    If Not FullPath(Path, Canonical, Diagnostic) Then Exit Function
    If Not ReadUtf8File(Canonical, MaximumManifestBytes, Text, Project.ManifestPath, Bytes, Diagnostic) Then Exit Function
    Position = InStrRev(Project.ManifestPath, "\")
    If Position = 0 Then
        LoadProject = Reject(Diagnostic, "E_PATH", "manifest directory is unavailable")
        Exit Function
    End If
    Project.RootPath = Left$(Project.ManifestPath, Position - 1)
    Lines = Split(Replace(Text, vbCrLf, vbLf), vbLf)
    For Index = 0 To UBound(Lines)
        Line = TrimHorizontal(Lines(Index))
        If Len(Line) > 0 Then
            If Left$(Line, 1) <> "'" Then
                Context = Project.ManifestPath & ":" & CStr(Index + 1)
                If Not HeaderSeen Then
                    If HeaderWords(Line) <> "ube-project 1" Then
                        LoadProject = Reject(Diagnostic, "E_MANIFEST_HEADER", Context & " expected UBE-Project 1")
                        Exit Function
                    End If
                    HeaderSeen = True
                Else
                    If Not ParseEntry(Line, Key, Value) Then
                        LoadProject = Reject(Diagnostic, "E_MANIFEST_SYNTAX", Context & " expected key = quoted value")
                        Exit Function
                    End If
                    If Key <> "source" Then
                        If InStr(Seen, "|" & Key & "|") <> 0 Then
                            LoadProject = Reject(Diagnostic, "E_DUPLICATE_KEY", Context & " " & Key)
                            Exit Function
                        End If
                        Seen = Seen & "|" & Key & "|"
                    End If
                    Select Case Key
                    Case "name"
                        If Not ValidIdentifier(Value) Then
                            LoadProject = Reject(Diagnostic, "E_IDENTIFIER", Context & " unsupported project identifier")
                            Exit Function
                        End If
                        Project.ProjectName = Value
                    Case "kind"
                        If FoldAscii(Value) <> "exe" And FoldAscii(Value) <> "library" Then GoTo InvalidValue
                        Project.KindName = FoldAscii(Value)
                    Case "startup"
                        If FoldAscii(Value) <> "main" Then GoTo InvalidValue
                        Project.StartupName = Value
                    Case "optimization"
                        If Value <> "0" And Value <> "1" And Value <> "2" And Value <> "3" And FoldAscii(Value) <> "size" Then GoTo InvalidValue
                        Project.OptimizationName = Value
                    Case "debuginformation"
                        If FoldAscii(Value) <> "none" And FoldAscii(Value) <> "line" And FoldAscii(Value) <> "full" Then GoTo InvalidValue
                        Project.DebugInformationName = Value
                    Case "source"
                        If Not LoadSource(Value, Project, TotalBytes, Diagnostic) Then Exit Function
                    Case "resource", "reference", "libraryreference", "startupform"
                        LoadProject = Reject(Diagnostic, "E_UNSUPPORTED", Context & " " & Key & " is not supported by this bootstrap profile")
                        Exit Function
                    Case Else
                        LoadProject = Reject(Diagnostic, "E_UNKNOWN_KEY", Context & " " & Key)
                        Exit Function
                    End Select
                End If
            End If
        End If
    Next Index
    If Not HeaderSeen Then
        LoadProject = Reject(Diagnostic, "E_MANIFEST_HEADER", "missing UBE-Project 1 header")
        Exit Function
    End If
    If Len(Project.ProjectName) = 0 Or Len(Project.KindName) = 0 Or Project.SourceCount = 0 Then
        LoadProject = Reject(Diagnostic, "E_REQUIRED", "Name, Kind and at least one Source are required")
        Exit Function
    End If
    If Project.KindName = "exe" And Len(Project.StartupName) = 0 Then
        LoadProject = Reject(Diagnostic, "E_REQUIRED", "executable projects require Startup = " & Chr$(34) & "Main" & Chr$(34))
        Exit Function
    End If
    If Project.KindName = "library" And Len(Project.StartupName) > 0 Then
        LoadProject = Reject(Diagnostic, "E_VALUE", "library projects cannot specify Startup")
        Exit Function
    End If
    LoadProject = True
    Exit Function
InvalidValue:
    LoadProject = Reject(Diagnostic, "E_VALUE", Context & " invalid " & Key)
    Exit Function
Unexpected:
    On Error Resume Next
    LoadProject = Reject(Diagnostic, "E_IO", "unable to load bounded project inputs")
End Function
