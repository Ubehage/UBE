UBE SOURCE 1 MODULE
Attribute UBE_Name = "ProjectGroup"

' UBE-ProjectGroup 1 is deliberately an orchestration format. Each listed
' project keeps its own compilation settings and is checked independently.
Function RunProjectGroupDriver(ByVal GroupPath As String, ByVal TargetTriple As String) As Long
    Dim Diagnostics() As CompilerDiagnostic
    Dim DiagnosticCount As Long = 0
    Dim DiagnosticCapacity As Long = 0
    If HasSuffix(GroupPath, ".UBG") = 0 Then
        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3032", GroupPath, 1, 1, "project groups require a .UBG manifest")
        Call ReportDiagnostics(Diagnostics, DiagnosticCount)
        RunProjectGroupDriver = 1
        Exit Function
    End If

    Dim Contents As String = ReadAllText(GroupPath)
    If StringLength(Contents) > LimitManifestBytes() Then
        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3033", GroupPath, 1, 1, "project-group manifest exceeds the 1048576-byte limit")
        Call ReportDiagnostics(Diagnostics, DiagnosticCount)
        RunProjectGroupDriver = 1
        Exit Function
    End If
    Dim InvalidByte As Long = -1
    If ValidateUtf8(Contents, InvalidByte) = 0 Then
        Dim InvalidLine As Long = 1
        Dim InvalidColumn As Long = 1
        Call FindLineAndColumn(Contents, InvalidByte, InvalidLine, InvalidColumn)
        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3034", GroupPath, InvalidLine, InvalidColumn, "project-group manifest is not valid UTF-8")
        Call ReportDiagnostics(Diagnostics, DiagnosticCount)
        RunProjectGroupDriver = 1
        Exit Function
    End If

    Dim GroupDirectory As String = ""
    Call FindProjectDirectory(GroupPath, GroupDirectory)
    Dim GroupName As String = ""
    Dim ProjectPaths() As String
    Dim ProjectCount As Long = 0
    Dim ProjectCapacity As Long = 0
    Dim SawHeader As Long = 0
    Dim SawName As Long = 0
    Dim Cursor As Long = 0
    Dim LineNumber As Long = 0
    While Cursor <= StringLength(Contents)
        Dim LineEnd As Long = StringIndexOf(Contents, StringFromByte(10), Cursor)
        If LineEnd < 0 Then
            LineEnd = StringLength(Contents)
        End If
        LineNumber = LineNumber + 1
        If LineNumber > LimitManifestLines() Then
            Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3035", GroupPath, LineNumber, 1, "project-group manifest exceeds the configured line limit")
            Call ReportDiagnostics(Diagnostics, DiagnosticCount)
            RunProjectGroupDriver = 1
            Exit Function
        End If
        Dim GroupLine As String = ""
        Call TrimText(StringSlice(Contents, Cursor, LineEnd - Cursor), GroupLine)
        If StringLength(GroupLine) > 0 Then
            If StringByteAt(GroupLine, 0) <> 39 Then
                If SawHeader = 0 Then
                    If GroupLine <> "UBE-ProjectGroup 1" Then
                        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3036", GroupPath, LineNumber, 1, "project-group manifest must begin with UBE-ProjectGroup 1")
                        Call ReportDiagnostics(Diagnostics, DiagnosticCount)
                        RunProjectGroupDriver = 1
                        Exit Function
                    End If
                    SawHeader = 1
                Else
                    Dim EqualsIndex As Long = StringIndexOf(GroupLine, "=", 0)
                    If EqualsIndex < 1 Then
                        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3037", GroupPath, LineNumber, 1, "malformed project-group entry")
                        Call ReportDiagnostics(Diagnostics, DiagnosticCount)
                        RunProjectGroupDriver = 1
                        Exit Function
                    End If
                    Dim Key As String = ""
                    Dim RawValue As String = ""
                    Dim EntryValue As String = ""
                    Call TrimText(StringSlice(GroupLine, 0, EqualsIndex), Key)
                    Call TrimText(StringSlice(GroupLine, EqualsIndex + 1, StringLength(GroupLine) - EqualsIndex - 1), RawValue)
                    If ParseQuotedManifestValue(RawValue, EntryValue) = 0 Then
                        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3038", GroupPath, LineNumber, EqualsIndex + 2, "project-group values must be complete quoted strings")
                        Call ReportDiagnostics(Diagnostics, DiagnosticCount)
                        RunProjectGroupDriver = 1
                        Exit Function
                    End If
                    If EqualsFolded(Key, "Name") <> 0 Then
                        If SawName <> 0 Or StringLength(EntryValue) = 0 Then
                            Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3039", GroupPath, LineNumber, 1, "project-group Name must be present once and cannot be empty")
                            Call ReportDiagnostics(Diagnostics, DiagnosticCount)
                            RunProjectGroupDriver = 1
                            Exit Function
                        End If
                        GroupName = EntryValue
                        SawName = 1
                    Else
                        If EqualsFolded(Key, "Project") <> 0 Then
                            Dim NormalizedPath As String = ""
                            If NormalizeRelativePath(EntryValue, NormalizedPath) = 0 Or HasSuffix(NormalizedPath, ".UBE") = 0 Then
                                Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3040", GroupPath, LineNumber, 1, "Project must be a safe relative .UBE path")
                                Call ReportDiagnostics(Diagnostics, DiagnosticCount)
                                RunProjectGroupDriver = 1
                                Exit Function
                            End If
                            If PathAlreadyListed(ProjectPaths, ProjectCount, NormalizedPath) <> 0 Then
                                Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3041", GroupPath, LineNumber, 1, "duplicate Project after path normalization: " & EntryValue)
                                Call ReportDiagnostics(Diagnostics, DiagnosticCount)
                                RunProjectGroupDriver = 1
                                Exit Function
                            End If
                            If AppendString(ProjectPaths, ProjectCount, ProjectCapacity, NormalizedPath, LimitProjectReferences()) = 0 Then
                                Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3042", GroupPath, LineNumber, 1, "project group exceeds the configured project limit")
                                Call ReportDiagnostics(Diagnostics, DiagnosticCount)
                                RunProjectGroupDriver = 1
                                Exit Function
                            End If
                        Else
                            Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3043", GroupPath, LineNumber, 1, "unsupported project-group key: " & Key)
                            Call ReportDiagnostics(Diagnostics, DiagnosticCount)
                            RunProjectGroupDriver = 1
                            Exit Function
                        End If
                    End If
                End If
            End If
        End If
        If LineEnd = StringLength(Contents) Then
            Exit While
        End If
        Cursor = LineEnd + 1
    Wend

    If SawHeader = 0 Or SawName = 0 Or ProjectCount = 0 Then
        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3044", GroupPath, 1, 1, "project group requires Name and at least one Project")
        Call ReportDiagnostics(Diagnostics, DiagnosticCount)
        RunProjectGroupDriver = 1
        Exit Function
    End If

    Dim ProjectIndex As Long = 0
    While ProjectIndex < ProjectCount
        If RunCompilerDriver(GroupDirectory & ProjectPaths(ProjectIndex), TargetTriple, 0, "", "") <> 0 Then
            RunProjectGroupDriver = 1
            Exit Function
        End If
        ProjectIndex = ProjectIndex + 1
    Wend
    Print "UBE Compiler v3 RP8: project group " & GroupName & ", " & LongToString(ProjectCount) & " project(s), target " & TargetTriple
    RunProjectGroupDriver = 0
End Function
