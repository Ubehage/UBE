UBE SOURCE 1 MODULE
Attribute UBE_Name = "IdeProject"

Type IdeProjectState
    ProjectName As String
    ProjectKind As String
    Startup As String
    StartupForm As String
    SourceCount As Long
    UnknownCount As Long
    OriginalContents As String
End Type

Function IdeAppendString(ByRef Values() As String, ByRef Count As Long, ByRef Capacity As Long, ByVal Value As String, ByVal Limit As Long) As Long
    If Count >= Limit Then
        IdeAppendString = 0
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = 16
        If Capacity > 0 Then
            NewCapacity = Capacity * 2
        End If
        If NewCapacity > Limit Then
            NewCapacity = Limit
        End If
        If Capacity = 0 Then
            ReDim Values(NewCapacity - 1)
        Else
            ReDim Preserve Values(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Values(Count) = Value
    Count = Count + 1
    IdeAppendString = 1
End Function

Function IdeFindFolded(ByRef Values() As String, ByVal Count As Long, ByVal Value As String) As Long
    Dim Index As Long = 0
    While Index < Count
        If IdeEqualsFolded(Values(Index), Value) <> 0 Then
            IdeFindFolded = Index
            Exit Function
        End If
        Index = Index + 1
    Wend
    IdeFindFolded = -1
End Function

Function IdeLoadProjectText(ByVal FilePath As String, ByVal Contents As String, ByRef Project As IdeProjectState, ByRef Sources() As String, ByRef SourceCapacity As Long, ByRef UnknownKeys() As String, ByRef UnknownValues() As String, ByRef UnknownCapacity As Long, ByRef Diagnostics() As IdeDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Project.ProjectName = ""
    Project.ProjectKind = ""
    Project.Startup = ""
    Project.StartupForm = ""
    Project.SourceCount = 0
    Project.UnknownCount = 0
    Project.OriginalContents = Contents
    Dim InitialDiagnosticCount As Long = DiagnosticCount
    If StringLength(Contents) > IdeLimitTextBytes() Then
        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE1001", FilePath, 1, 1, 2)
        IdeLoadProjectText = 0
        Exit Function
    End If
    Dim InvalidByte As Long = -1
    If IdeValidateUtf8(Contents, InvalidByte) = 0 Then
        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE1015", FilePath, 1, InvalidByte + 1, 2)
        IdeLoadProjectText = 0
        Exit Function
    End If
    Dim Cursor As Long = 0
    Dim LineText As String = ""
    If IdeReadLine(Contents, Cursor, LineText) = 0 Or LineText <> "UBE-Project 1" Then
        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE1002", FilePath, 1, 1, 2)
        IdeLoadProjectText = 0
        Exit Function
    End If
    Dim LineNumber As Long = 1
    While IdeReadLine(Contents, Cursor, LineText) <> 0
        LineNumber = LineNumber + 1
        Dim Trimmed As String = ""
        Call IdeTrim(LineText, Trimmed)
        If StringLength(Trimmed) > 0 Then
            If StringByteAt(Trimmed, 0) <> 39 Then
                Dim Key As String = ""
                Dim Value As String = ""
                If IdeParseAssignment(Trimmed, Key, Value) = 0 Then
                    Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE1003", FilePath, LineNumber, 1, 2)
                Else
                    If IdeEqualsFolded(Key, "Name") <> 0 Then
                        If StringLength(Project.ProjectName) > 0 Then
                            Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE1004", FilePath, LineNumber, 1, 2)
                        Else
                            Project.ProjectName = Value
                        End If
                    Else
                        If IdeEqualsFolded(Key, "Kind") <> 0 Then
                            If StringLength(Project.ProjectKind) > 0 Then
                                Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE1005", FilePath, LineNumber, 1, 2)
                            Else
                                Project.ProjectKind = Value
                            End If
                        Else
                            If IdeEqualsFolded(Key, "Startup") <> 0 Then
                                If StringLength(Project.Startup) > 0 Then
                                    Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE1006", FilePath, LineNumber, 1, 2)
                                Else
                                    Project.Startup = Value
                                End If
                            Else
                                If IdeEqualsFolded(Key, "StartupForm") <> 0 Then
                                    If StringLength(Project.StartupForm) > 0 Then
                                        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE1007", FilePath, LineNumber, 1, 2)
                                    Else
                                        Project.StartupForm = Value
                                    End If
                                Else
                                    If IdeEqualsFolded(Key, "Source") <> 0 Then
                                        Dim NormalizedSource As String = ""
                                        If IdeNormalizeRelativePath(Value, NormalizedSource) = 0 Then
                                            Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE1008", FilePath, LineNumber, 1, 2)
                                        Else
                                            If IdeFindFolded(Sources, Project.SourceCount, NormalizedSource) >= 0 Then
                                                Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE1009", FilePath, LineNumber, 1, 2)
                                            Else
                                                If IdeAppendString(Sources, Project.SourceCount, SourceCapacity, NormalizedSource, IdeLimitProjectSources()) = 0 Then
                                                    Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE1010", FilePath, LineNumber, 1, 2)
                                                End If
                                            End If
                                        End If
                                    Else
                                        If Project.UnknownCount < IdeLimitCatalogEntries() Then
                                            If Project.UnknownCount = UnknownCapacity Then
                                                Dim NewUnknownCapacity As Long = 16
                                                If UnknownCapacity > 0 Then
                                                    NewUnknownCapacity = UnknownCapacity * 2
                                                End If
                                                If NewUnknownCapacity > IdeLimitCatalogEntries() Then
                                                    NewUnknownCapacity = IdeLimitCatalogEntries()
                                                End If
                                                If UnknownCapacity = 0 Then
                                                    ReDim UnknownKeys(NewUnknownCapacity - 1)
                                                    ReDim UnknownValues(NewUnknownCapacity - 1)
                                                Else
                                                    ReDim Preserve UnknownKeys(NewUnknownCapacity - 1)
                                                    ReDim Preserve UnknownValues(NewUnknownCapacity - 1)
                                                End If
                                                UnknownCapacity = NewUnknownCapacity
                                            End If
                                            UnknownKeys(Project.UnknownCount) = Key
                                            UnknownValues(Project.UnknownCount) = Value
                                            Project.UnknownCount = Project.UnknownCount + 1
                                        Else
                                            Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE1011", FilePath, LineNumber, 1, 2)
                                        End If
                                    End If
                                End If
                            End If
                        End If
                    End If
                End If
            End If
        End If
    Wend
    If StringLength(Project.ProjectName) = 0 Then
        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE1012", FilePath, 1, 1, 2)
    End If
    If StringLength(Project.ProjectKind) = 0 Then
        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE1013", FilePath, 1, 1, 2)
    End If
    If Project.SourceCount = 0 Then
        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE1014", FilePath, 1, 1, 2)
    End If
    If DiagnosticCount = InitialDiagnosticCount Then
        IdeLoadProjectText = 1
    Else
        IdeLoadProjectText = 0
    End If
End Function
