UBE SOURCE 1 MODULE
Attribute UBE_Name = "SourceEnvelope"

Type SourceEnvelopeInfo
    SourceId As Long
    FormatKind As Long
    FormatVersion As Long
    SourceKind As Long
    SourceName As String
    HeaderByteLength As Long
End Type

Function SourceKindForPath(ByVal Path As String) As Long
    If HasSuffix(Path, ".bas") <> 0 Then
        SourceKindForPath = 1
    Else
        If HasSuffix(Path, ".cls") <> 0 Then
            SourceKindForPath = 2
        Else
            If HasSuffix(Path, ".frm") <> 0 Then
                SourceKindForPath = 3
            Else
                If HasSuffix(Path, ".ctl") <> 0 Then
                    SourceKindForPath = 4
                Else
                    SourceKindForPath = 0
                End If
            End If
        End If
    End If
End Function

Function SourceKindForWord(ByVal Word As String) As Long
    If EqualsFolded(Word, "MODULE") <> 0 Then
        SourceKindForWord = 1
    Else
        If EqualsFolded(Word, "CLASS") <> 0 Then
            SourceKindForWord = 2
        Else
            If EqualsFolded(Word, "FORM") <> 0 Then
                SourceKindForWord = 3
            Else
                If EqualsFolded(Word, "CONTROL") <> 0 Then
                    SourceKindForWord = 4
                Else
                    SourceKindForWord = 0
                End If
            End If
        End If
    End If
End Function

Sub ReadPhysicalLine(ByVal Contents As String, ByVal StartByte As Long, ByRef LineText As String, ByRef NextByte As Long)
    Dim Length As Long = StringLength(Contents)
    Dim EndByte As Long = StringIndexOf(Contents, StringFromByte(10), StartByte)
    If EndByte < 0 Then
        EndByte = Length
        NextByte = Length
    Else
        NextByte = EndByte + 1
    End If
    Dim ContentEnd As Long = EndByte
    If ContentEnd > StartByte Then
        If StringByteAt(Contents, ContentEnd - 1) = 13 Then
            ContentEnd = ContentEnd - 1
        End If
    End If
    LineText = StringSlice(Contents, StartByte, ContentEnd - StartByte)
End Sub

Function ReadHeaderWord(ByVal Line As String, ByRef Cursor As Long, ByRef Word As String) As Long
    Dim Length As Long = StringLength(Line)
    While Cursor < Length
        If StringByteAt(Line, Cursor) = 32 Or StringByteAt(Line, Cursor) = 9 Then
            Cursor = Cursor + 1
        Else
            Exit While
        End If
    Wend
    Dim StartByte As Long = Cursor
    While Cursor < Length
        Dim CurrentByte As Long = StringByteAt(Line, Cursor)
        If CurrentByte = 32 Or CurrentByte = 9 Then
            Exit While
        End If
        Cursor = Cursor + 1
    Wend
    If Cursor = StartByte Then
        Word = ""
        ReadHeaderWord = 0
    Else
        Word = StringSlice(Line, StartByte, Cursor - StartByte)
        ReadHeaderWord = 1
    End If
End Function

Function ParseDecimalLong(ByVal Text As String, ByRef Value As Long) As Long
    Value = 0
    Dim Length As Long = StringLength(Text)
    If Length = 0 Then
        ParseDecimalLong = 0
        Exit Function
    End If
    Dim Index As Long = 0
    While Index < Length
        Dim CurrentByte As Long = StringByteAt(Text, Index)
        If CurrentByte < 48 Or CurrentByte > 57 Then
            ParseDecimalLong = 0
            Exit Function
        End If
        If Value > 214748364 Then
            ParseDecimalLong = 0
            Exit Function
        End If
        Value = Value * 10 + CurrentByte - 48
        Index = Index + 1
    Wend
    ParseDecimalLong = 1
End Function

Function ParseNativeNameAttribute(ByVal Line As String, ByRef SourceName As String) As Long
    Dim EqualsIndex As Long = StringIndexOf(Line, "=", 0)
    If EqualsIndex < 0 Then
        ParseNativeNameAttribute = 0
        Exit Function
    End If
    Dim LeftText As String = ""
    Dim RawValue As String = ""
    Call TrimText(StringSlice(Line, 0, EqualsIndex), LeftText)
    Call TrimText(StringSlice(Line, EqualsIndex + 1, StringLength(Line) - EqualsIndex - 1), RawValue)
    If EqualsFolded(LeftText, "Attribute UBE_Name") = 0 Then
        ParseNativeNameAttribute = 0
        Exit Function
    End If
    If ParseQuotedManifestValue(RawValue, SourceName) = 0 Then
        ParseNativeNameAttribute = 0
        Exit Function
    End If
    ParseNativeNameAttribute = IsProjectIdentifier(SourceName)
End Function

Function ParseLegacyNameAttribute(ByVal Line As String, ByRef SourceName As String) As Long
    Dim EqualsIndex As Long = StringIndexOf(Line, "=", 0)
    If EqualsIndex < 0 Then
        ParseLegacyNameAttribute = 0
        Exit Function
    End If
    Dim LeftText As String = ""
    Dim RawValue As String = ""
    Call TrimText(StringSlice(Line, 0, EqualsIndex), LeftText)
    Call TrimText(StringSlice(Line, EqualsIndex + 1, StringLength(Line) - EqualsIndex - 1), RawValue)
    If EqualsFolded(LeftText, "Attribute VB_Name") = 0 Then
        ParseLegacyNameAttribute = 0
        Exit Function
    End If
    If ParseQuotedManifestValue(RawValue, SourceName) = 0 Then
        ParseLegacyNameAttribute = 0
        Exit Function
    End If
    ParseLegacyNameAttribute = IsProjectIdentifier(SourceName)
End Function

Function IsLegacyHeaderStart(ByVal Line As String) As Long
    Dim Trimmed As String = ""
    Call TrimText(Line, Trimmed)
    Dim Cursor As Long = 0
    Dim FirstWord As String = ""
    Call ReadHeaderWord(Trimmed, Cursor, FirstWord)
    If EqualsFolded(FirstWord, "VERSION") <> 0 Or EqualsFolded(FirstWord, "Object") <> 0 Or EqualsFolded(FirstWord, "Reference") <> 0 Or EqualsFolded(FirstWord, "BEGIN") <> 0 Or EqualsFolded(FirstWord, "Begin") <> 0 Or EqualsFolded(FirstWord, "Attribute") <> 0 Then
        IsLegacyHeaderStart = 1
    Else
        IsLegacyHeaderStart = 0
    End If
End Function

Function ValidateOneSourceEnvelope(ByRef Source As SourceDocument, ByRef Envelope As SourceEnvelopeInfo, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Envelope.SourceId = Source.SourceId
    Envelope.SourceKind = SourceKindForPath(Source.FilePath)
    Dim StartByte As Long = 0
    If Source.ByteLength >= 3 Then
        If StringByteAt(Source.Contents, 0) = 239 And StringByteAt(Source.Contents, 1) = 187 And StringByteAt(Source.Contents, 2) = 191 Then
            StartByte = 3
        End If
    End If
    Dim FirstLine As String = ""
    Dim SecondLine As String = ""
    Dim NextByte As Long = 0
    Dim AfterSecondLine As Long = 0
    Call ReadPhysicalLine(Source.Contents, StartByte, FirstLine, NextByte)
    If IsLegacyHeaderStart(FirstLine) <> 0 Then
        Envelope.FormatKind = 2
        Envelope.FormatVersion = 6
        Envelope.HeaderByteLength = NextByte
        Dim ScanByte As Long = StartByte
        Dim ScanLines As Long = 0
        While ScanByte < Source.ByteLength And ScanLines < 10000
            Dim LegacyLine As String = ""
            Dim LegacyNext As Long = 0
            Call ReadPhysicalLine(Source.Contents, ScanByte, LegacyLine, LegacyNext)
            If ParseLegacyNameAttribute(LegacyLine, Envelope.SourceName) <> 0 Then
                Exit While
            End If
            If LegacyNext <= ScanByte Then
                Exit While
            End If
            ScanByte = LegacyNext
            ScanLines = ScanLines + 1
        Wend
        If StringLength(Envelope.SourceName) = 0 Then
            Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3306", Source.FilePath, 1, 1, "recognized VB6 source requires Attribute VB_Name with a valid identifier")
            ValidateOneSourceEnvelope = 0
            Exit Function
        End If
        ValidateOneSourceEnvelope = 1
        Exit Function
    End If

    Dim Cursor As Long = 0
    Dim WordUbe As String = ""
    Dim WordSource As String = ""
    Dim WordVersion As String = ""
    Dim WordKind As String = ""
    If ReadHeaderWord(FirstLine, Cursor, WordUbe) = 0 Or ReadHeaderWord(FirstLine, Cursor, WordSource) = 0 Or ReadHeaderWord(FirstLine, Cursor, WordVersion) = 0 Or ReadHeaderWord(FirstLine, Cursor, WordKind) = 0 Then
        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3300", Source.FilePath, 1, 1, "source must begin with a native UBE header or recognized VB6 header")
        ValidateOneSourceEnvelope = 0
        Exit Function
    End If
    Dim Trailing As String = ""
    Call TrimText(StringSlice(FirstLine, Cursor, StringLength(FirstLine) - Cursor), Trailing)
    Dim HeaderVersion As Long = 0
    If EqualsFolded(WordUbe, "UBE") = 0 Or EqualsFolded(WordSource, "SOURCE") = 0 Or ParseDecimalLong(WordVersion, HeaderVersion) = 0 Or StringLength(Trailing) <> 0 Then
        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3301", Source.FilePath, 1, 1, "malformed native source header")
        ValidateOneSourceEnvelope = 0
        Exit Function
    End If
    If HeaderVersion <> 1 Then
        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3302", Source.FilePath, 1, 1, "unsupported native source format version")
        ValidateOneSourceEnvelope = 0
        Exit Function
    End If
    Dim HeaderKind As Long = SourceKindForWord(WordKind)
    If HeaderKind = 0 Or HeaderKind <> Envelope.SourceKind Then
        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3303", Source.FilePath, 1, 1, "source header kind does not match its file extension")
        ValidateOneSourceEnvelope = 0
        Exit Function
    End If
    Call ReadPhysicalLine(Source.Contents, NextByte, SecondLine, AfterSecondLine)
    If ParseNativeNameAttribute(SecondLine, Envelope.SourceName) = 0 Then
        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3304", Source.FilePath, 2, 1, "native source requires Attribute UBE_Name with a valid identifier")
        ValidateOneSourceEnvelope = 0
        Exit Function
    End If
    Envelope.FormatKind = 1
    Envelope.FormatVersion = 1
    Envelope.SourceKind = HeaderKind
    Envelope.HeaderByteLength = AfterSecondLine
    ValidateOneSourceEnvelope = 1
End Function

Function ValidateSourceEnvelopes(ByRef Sources() As SourceDocument, ByVal SourceCount As Long, ByRef Envelopes() As SourceEnvelopeInfo, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    ReDim Envelopes(SourceCount - 1)
    Dim Index As Long = 0
    While Index < SourceCount
        If ValidateOneSourceEnvelope(Sources(Index), Envelopes(Index), Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
            ValidateSourceEnvelopes = 0
            Exit Function
        End If
        If StringLength(Envelopes(Index).SourceName) > 0 Then
            Dim Existing As Long = 0
            While Existing < Index
                If StringLength(Envelopes(Existing).SourceName) > 0 Then
                    If EqualsFolded(Envelopes(Existing).SourceName, Envelopes(Index).SourceName) <> 0 Then
                        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3305", Sources(Index).FilePath, 2, 1, "duplicate source identity: " & Envelopes(Index).SourceName)
                        ValidateSourceEnvelopes = 0
                        Exit Function
                    End If
                End If
                Existing = Existing + 1
            Wend
        End If
        Index = Index + 1
    Wend
    ValidateSourceEnvelopes = 1
End Function
