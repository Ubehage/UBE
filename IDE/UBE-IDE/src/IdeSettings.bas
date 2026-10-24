UBE SOURCE 1 MODULE
Attribute UBE_Name = "IdeSettings"

Type IdeSettingsState
    FormatVersion As Long
    EntryCount As Long
End Type

Function IdeLoadSettingsText(ByVal FilePath As String, ByVal Contents As String, ByRef Settings As IdeSettingsState, ByRef Keys() As String, ByRef Values() As String, ByRef Capacity As Long, ByRef Diagnostics() As IdeDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Settings.FormatVersion = 0
    Settings.EntryCount = 0
    Dim InitialDiagnosticCount As Long = DiagnosticCount
    If StringLength(Contents) > IdeLimitTextBytes() Then
        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE2001", FilePath, 1, 1, 2)
        IdeLoadSettingsText = 0
        Exit Function
    End If
    Dim InvalidByte As Long = -1
    If IdeValidateUtf8(Contents, InvalidByte) = 0 Then
        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE2006", FilePath, 1, InvalidByte + 1, 2)
        IdeLoadSettingsText = 0
        Exit Function
    End If
    Dim Cursor As Long = 0
    Dim LineText As String = ""
    If IdeReadLine(Contents, Cursor, LineText) = 0 Or LineText <> "UBE-IDE-Settings 1" Then
        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE2002", FilePath, 1, 1, 2)
        IdeLoadSettingsText = 0
        Exit Function
    End If
    Settings.FormatVersion = 1
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
                    Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE2003", FilePath, LineNumber, 1, 2)
                Else
                    If IdeFindFolded(Keys, Settings.EntryCount, Key) >= 0 Then
                        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE2004", FilePath, LineNumber, 1, 2)
                    Else
                        If Settings.EntryCount >= IdeLimitCatalogEntries() Then
                            Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE2005", FilePath, LineNumber, 1, 2)
                        Else
                            If Settings.EntryCount = Capacity Then
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
                            Keys(Settings.EntryCount) = Key
                            Values(Settings.EntryCount) = Value
                            Settings.EntryCount = Settings.EntryCount + 1
                        End If
                    End If
                End If
            End If
        End If
    Wend
    If DiagnosticCount = InitialDiagnosticCount Then
        IdeLoadSettingsText = 1
    Else
        IdeLoadSettingsText = 0
    End If
End Function

Function IdeGetSetting(ByRef Keys() As String, ByRef Values() As String, ByVal Count As Long, ByVal Key As String, ByRef Value As String) As Long
    Dim Index As Long = IdeFindFolded(Keys, Count, Key)
    If Index < 0 Then
        IdeGetSetting = 0
    Else
        Value = Values(Index)
        IdeGetSetting = 1
    End If
End Function

Function IdeSetSetting(ByRef Keys() As String, ByRef Values() As String, ByRef Settings As IdeSettingsState, ByRef Capacity As Long, ByVal Key As String, ByVal Value As String) As Long
    If StringLength(Key) = 0 Or StringIndexOf(Key, "=", 0) >= 0 Or StringIndexOf(Key, StringFromByte(10), 0) >= 0 Or StringLength(Value) > IdeLimitTextBytes() Then
        IdeSetSetting = 0
        Exit Function
    End If
    Dim InvalidByte As Long = -1
    If IdeValidateUtf8(Key, InvalidByte) = 0 Or IdeValidateUtf8(Value, InvalidByte) = 0 Then
        IdeSetSetting = 0
        Exit Function
    End If
    Dim Index As Long = IdeFindFolded(Keys, Settings.EntryCount, Key)
    If Index >= 0 Then
        Values(Index) = Value
        IdeSetSetting = 1
        Exit Function
    End If
    If Settings.EntryCount >= IdeLimitCatalogEntries() Then
        IdeSetSetting = 0
        Exit Function
    End If
    If Settings.EntryCount = Capacity Then
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
    Keys(Settings.EntryCount) = Key
    Values(Settings.EntryCount) = Value
    Settings.EntryCount = Settings.EntryCount + 1
    IdeSetSetting = 1
End Function

Function IdeQuoteValue(ByVal Value As String) As String
    Dim QuoteText As String = StringFromByte(34)
    Dim Result As String = QuoteText
    Dim Index As Long = 0
    While Index < StringLength(Value)
        If StringByteAt(Value, Index) = 34 Then
            Result = Result & QuoteText & QuoteText
        Else
            Result = Result & StringSlice(Value, Index, 1)
        End If
        Index = Index + 1
    Wend
    IdeQuoteValue = Result & QuoteText
End Function

Function IdeSerializeSettings(ByRef Keys() As String, ByRef Values() As String, ByVal Count As Long, ByRef Result As String) As Long
    If Count < 0 Or Count > IdeLimitCatalogEntries() Then
        IdeSerializeSettings = 0
        Exit Function
    End If
    Dim N As String = StringFromByte(10)
    Result = "UBE-IDE-Settings 1" & N
    Dim Index As Long = 0
    While Index < Count
        If StringLength(Keys(Index)) = 0 Or StringIndexOf(Keys(Index), "=", 0) >= 0 Or StringIndexOf(Keys(Index), N, 0) >= 0 Then
            Result = ""
            IdeSerializeSettings = 0
            Exit Function
        End If
        Result = Result & Keys(Index) & " = " & IdeQuoteValue(Values(Index)) & N
        If StringLength(Result) > IdeLimitTextBytes() Then
            Result = ""
            IdeSerializeSettings = 0
            Exit Function
        End If
        Index = Index + 1
    Wend
    IdeSerializeSettings = 1
End Function
