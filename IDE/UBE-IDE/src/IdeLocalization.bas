UBE SOURCE 1 MODULE
Attribute UBE_Name = "IdeLocalization"

Type IdeLocaleState
    FormatVersion As Long
    LocaleName As String
    FallbackName As String
    EntryCount As Long
End Type

Type IdeFormatArgument
    ArgumentName As String
    ArgumentKind As Long
    TextValue As String
    LongValue As Long
End Type

Function IdeValidateMessageTemplate(ByVal TemplateText As String) As Long
    Dim Cursor As Long = 0
    While Cursor < StringLength(TemplateText)
        Dim CurrentByte As Long = StringByteAt(TemplateText, Cursor)
        If CurrentByte = 123 Then
            If Cursor + 1 < StringLength(TemplateText) Then
                If StringByteAt(TemplateText, Cursor + 1) = 123 Then
                    Cursor = Cursor + 2
                Else
                    Dim CloseIndex As Long = StringIndexOf(TemplateText, "}", Cursor + 1)
                    If CloseIndex < 0 Then
                        IdeValidateMessageTemplate = 0
                        Exit Function
                    End If
                    Dim Descriptor As String = StringSlice(TemplateText, Cursor + 1, CloseIndex - Cursor - 1)
                    Dim ColonIndex As Long = StringIndexOf(Descriptor, ":", 0)
                    If ColonIndex < 1 Or ColonIndex >= StringLength(Descriptor) - 1 Then
                        IdeValidateMessageTemplate = 0
                        Exit Function
                    End If
                    If StringIndexOf(Descriptor, "{", 0) >= 0 Or StringIndexOf(Descriptor, "}", 0) >= 0 Then
                        IdeValidateMessageTemplate = 0
                        Exit Function
                    End If
                    Dim KindText As String = StringSlice(Descriptor, ColonIndex + 1, StringLength(Descriptor) - ColonIndex - 1)
                    If IdeEqualsFolded(KindText, "text") = 0 And IdeEqualsFolded(KindText, "long") = 0 Then
                        IdeValidateMessageTemplate = 0
                        Exit Function
                    End If
                    Cursor = CloseIndex + 1
                End If
            Else
                IdeValidateMessageTemplate = 0
                Exit Function
            End If
        Else
            If CurrentByte = 125 Then
                If Cursor + 1 >= StringLength(TemplateText) Then
                    IdeValidateMessageTemplate = 0
                    Exit Function
                End If
                If StringByteAt(TemplateText, Cursor + 1) <> 125 Then
                    IdeValidateMessageTemplate = 0
                    Exit Function
                End If
                Cursor = Cursor + 2
            Else
                Cursor = Cursor + 1
            End If
        End If
    Wend
    IdeValidateMessageTemplate = 1
End Function

Function IdeFindFormatArgument(ByRef Arguments() As IdeFormatArgument, ByVal ArgumentCount As Long, ByVal ArgumentName As String) As Long
    Dim Index As Long = 0
    While Index < ArgumentCount
        If IdeEqualsFolded(Arguments(Index).ArgumentName, ArgumentName) <> 0 Then
            IdeFindFormatArgument = Index
            Exit Function
        End If
        Index = Index + 1
    Wend
    IdeFindFormatArgument = -1
End Function

Function IdeFormatMessage(ByVal TemplateText As String, ByRef Arguments() As IdeFormatArgument, ByVal ArgumentCount As Long, ByRef Result As String) As Long
    Result = ""
    If IdeValidateMessageTemplate(TemplateText) = 0 Or ArgumentCount < 0 Or ArgumentCount > 64 Then
        IdeFormatMessage = 0
        Exit Function
    End If
    Dim Cursor As Long = 0
    While Cursor < StringLength(TemplateText)
        Dim CurrentByte As Long = StringByteAt(TemplateText, Cursor)
        If CurrentByte = 123 Then
            If StringByteAt(TemplateText, Cursor + 1) = 123 Then
                Result = Result & StringFromByte(123)
                Cursor = Cursor + 2
            Else
                Dim CloseIndex As Long = StringIndexOf(TemplateText, "}", Cursor + 1)
                Dim Descriptor As String = StringSlice(TemplateText, Cursor + 1, CloseIndex - Cursor - 1)
                Dim ColonIndex As Long = StringIndexOf(Descriptor, ":", 0)
                Dim ArgumentName As String = StringSlice(Descriptor, 0, ColonIndex)
                Dim KindText As String = StringSlice(Descriptor, ColonIndex + 1, StringLength(Descriptor) - ColonIndex - 1)
                Dim ArgumentIndex As Long = IdeFindFormatArgument(Arguments, ArgumentCount, ArgumentName)
                If ArgumentIndex < 0 Then
                    Result = ""
                    IdeFormatMessage = 0
                    Exit Function
                End If
                If IdeEqualsFolded(KindText, "text") <> 0 Then
                    If Arguments(ArgumentIndex).ArgumentKind <> 1 Then
                        Result = ""
                        IdeFormatMessage = 0
                        Exit Function
                    End If
                    Result = Result & Arguments(ArgumentIndex).TextValue
                Else
                    If Arguments(ArgumentIndex).ArgumentKind <> 2 Then
                        Result = ""
                        IdeFormatMessage = 0
                        Exit Function
                    End If
                    Result = Result & LongToString(Arguments(ArgumentIndex).LongValue)
                End If
                Cursor = CloseIndex + 1
            End If
        Else
            If CurrentByte = 125 Then
                Result = Result & StringFromByte(125)
                Cursor = Cursor + 2
            Else
                Result = Result & StringSlice(TemplateText, Cursor, 1)
                Cursor = Cursor + 1
            End If
        End If
        If StringLength(Result) > IdeLimitTextBytes() Then
            Result = ""
            IdeFormatMessage = 0
            Exit Function
        End If
    Wend
    IdeFormatMessage = 1
End Function

Function IdeEmergencyText(ByVal EmergencyCode As Long) As String
    If EmergencyCode = 1 Then
        IdeEmergencyText = "UBE could not load its language resources."
        Exit Function
    End If
    If EmergencyCode = 2 Then
        IdeEmergencyText = "Open recovery"
        Exit Function
    End If
    IdeEmergencyText = "Exit"
End Function

Function IdeLoadLocaleText(ByVal FilePath As String, ByVal Contents As String, ByRef Locale As IdeLocaleState, ByRef Keys() As String, ByRef Values() As String, ByRef Capacity As Long, ByRef Diagnostics() As IdeDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Locale.FormatVersion = 0
    Locale.LocaleName = ""
    Locale.FallbackName = ""
    Locale.EntryCount = 0
    Dim InitialDiagnosticCount As Long = DiagnosticCount
    If StringLength(Contents) > IdeLimitTextBytes() Then
        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE2101", FilePath, 1, 1, 2)
        IdeLoadLocaleText = 0
        Exit Function
    End If
    Dim InvalidByte As Long = -1
    If IdeValidateUtf8(Contents, InvalidByte) = 0 Then
        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE2109", FilePath, 1, InvalidByte + 1, 2)
        IdeLoadLocaleText = 0
        Exit Function
    End If
    Dim Cursor As Long = 0
    Dim LineText As String = ""
    If IdeReadLine(Contents, Cursor, LineText) = 0 Or LineText <> "UBE-Locale 1" Then
        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE2102", FilePath, 1, 1, 2)
        IdeLoadLocaleText = 0
        Exit Function
    End If
    Locale.FormatVersion = 1
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
                    Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE2103", FilePath, LineNumber, 1, 2)
                Else
                    If IdeEqualsFolded(Key, "Locale") <> 0 Then
                        If StringLength(Locale.LocaleName) > 0 Then
                            Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE2104", FilePath, LineNumber, 1, 2)
                        Else
                            Locale.LocaleName = Value
                        End If
                    Else
                        If IdeEqualsFolded(Key, "Fallback") <> 0 Then
                            If StringLength(Locale.FallbackName) > 0 Then
                                Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE2105", FilePath, LineNumber, 1, 2)
                            Else
                                Locale.FallbackName = Value
                            End If
                        Else
                            If IdeFindFolded(Keys, Locale.EntryCount, Key) >= 0 Then
                                Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE2106", FilePath, LineNumber, 1, 2)
                            Else
                                If IdeValidateMessageTemplate(Value) = 0 Then
                                    Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE2110", FilePath, LineNumber, 1, 2)
                                Else
                                If Locale.EntryCount >= IdeLimitCatalogEntries() Then
                                    Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE2107", FilePath, LineNumber, 1, 2)
                                Else
                                    If Locale.EntryCount = Capacity Then
                                        Dim NewCapacity As Long = 16
                                        If Capacity > 0 Then
                                            NewCapacity = Capacity * 2
                                        End If
                                        If Capacity = 0 Then
                                            ReDim Keys(NewCapacity - 1)
                                            ReDim Values(NewCapacity - 1)
                                        Else
                                            ReDim Preserve Keys(NewCapacity - 1)
                                            ReDim Preserve Values(NewCapacity - 1)
                                        End If
                                        Capacity = NewCapacity
                                    End If
                                    Keys(Locale.EntryCount) = Key
                                    Values(Locale.EntryCount) = Value
                                    Locale.EntryCount = Locale.EntryCount + 1
                                End If
                                End If
                            End If
                        End If
                    End If
                End If
            End If
        End If
    Wend
    If StringLength(Locale.LocaleName) = 0 Then
        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE2108", FilePath, 1, 1, 2)
    End If
    If DiagnosticCount = InitialDiagnosticCount Then
        IdeLoadLocaleText = 1
    Else
        IdeLoadLocaleText = 0
    End If
End Function

Function IdeGetLocalizedText(ByRef PrimaryKeys() As String, ByRef PrimaryValues() As String, ByVal PrimaryCount As Long, ByRef FallbackKeys() As String, ByRef FallbackValues() As String, ByVal FallbackCount As Long, ByVal Key As String, ByRef Value As String) As Long
    Dim Index As Long = IdeFindFolded(PrimaryKeys, PrimaryCount, Key)
    If Index >= 0 Then
        Value = PrimaryValues(Index)
        IdeGetLocalizedText = 1
        Exit Function
    End If
    Index = IdeFindFolded(FallbackKeys, FallbackCount, Key)
    If Index >= 0 Then
        Value = FallbackValues(Index)
        IdeGetLocalizedText = 1
        Exit Function
    End If
    Value = "[" & Key & "]"
    IdeGetLocalizedText = 0
End Function
