UBE SOURCE 1 MODULE
Attribute UBE_Name = "ProjectManifest"
' Parses the bounded native manifest without I/O or mutable shared state.
Public Type ValueSpan
    Start As Long
    Length As Long
    [Line] As Long
End Type

Public Type ManifestInfo
    NameStart As Long
    NameLength As Long
    SourceCount As Long
    IsExecutable As Boolean
    Optimization As Long
    DebugInformation As Long
End Type

Public Type ManifestDiagnostic
    Code As Long
    [Line] As Long
    Column As Long
End Type

' Resizes caller-owned finite path-span storage with checked allocation.
Private Intrinsic Function ResizeSpans(ByRef Values() As ValueSpan, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeSpans.UBE_Primitive = "Array.TryResize"
End Function

' Folds only the admitted ASCII spelling without locale-dependent identity.
Private Function Fold(ByVal Character As Long) As Long
    Fold = Character
    If Character >= 65 And Character <= 90 Then Fold = Character + 32
End Function

' Exact byte comparisons avoid hash-based authority or managed text dependencies.
Private Function MatchesWord(ByRef Text() As Byte, ByVal Start As Long, ByVal Length As Long, ByVal Word As Long) As Boolean
    If Word = 1 Then MatchesWord = MatchesName(Text, Start, Length): Exit Function
    If Word = 2 Then MatchesWord = MatchesKind(Text, Start, Length): Exit Function
    If Word = 3 Then MatchesWord = MatchesStartup(Text, Start, Length): Exit Function
    If Word = 4 Then MatchesWord = MatchesSource(Text, Start, Length): Exit Function
    If Word = 5 Then MatchesWord = MatchesOptimization(Text, Start, Length): Exit Function
    If Word = 6 Then MatchesWord = MatchesDebuginformation(Text, Start, Length): Exit Function
    If Word = 7 Then MatchesWord = MatchesResource(Text, Start, Length): Exit Function
    If Word = 8 Then MatchesWord = MatchesReference(Text, Start, Length): Exit Function
    If Word = 9 Then MatchesWord = MatchesLibraryreference(Text, Start, Length): Exit Function
    If Word = 10 Then MatchesWord = MatchesStartupform(Text, Start, Length): Exit Function
    If Word = 11 Then MatchesWord = MatchesExe(Text, Start, Length): Exit Function
    If Word = 12 Then MatchesWord = MatchesLibrary(Text, Start, Length): Exit Function
    If Word = 13 Then MatchesWord = MatchesMain(Text, Start, Length): Exit Function
    If Word = 14 Then MatchesWord = MatchesSize(Text, Start, Length): Exit Function
    If Word = 15 Then MatchesWord = MatchesNone(Text, Start, Length): Exit Function
    If Word = 16 Then MatchesWord = MatchesLine(Text, Start, Length): Exit Function
    If Word = 17 Then MatchesWord = MatchesFull(Text, Start, Length): Exit Function
    If Word = 18 Then MatchesWord = MatchesUbeProject(Text, Start, Length): Exit Function
End Function

' Matches the complete name spelling within an already bounded span.
Private Function MatchesName(ByRef Text() As Byte, ByVal Start As Long, ByVal Length As Long) As Boolean
    If Length <> 4 Then Exit Function
    If Fold(Text(Start + 0)) <> 110 Then Exit Function
    If Fold(Text(Start + 1)) <> 97 Then Exit Function
    If Fold(Text(Start + 2)) <> 109 Then Exit Function
    If Fold(Text(Start + 3)) <> 101 Then Exit Function
    MatchesName = True
End Function

' Matches the complete kind spelling within an already bounded span.
Private Function MatchesKind(ByRef Text() As Byte, ByVal Start As Long, ByVal Length As Long) As Boolean
    If Length <> 4 Then Exit Function
    If Fold(Text(Start + 0)) <> 107 Then Exit Function
    If Fold(Text(Start + 1)) <> 105 Then Exit Function
    If Fold(Text(Start + 2)) <> 110 Then Exit Function
    If Fold(Text(Start + 3)) <> 100 Then Exit Function
    MatchesKind = True
End Function

' Matches the complete startup spelling within an already bounded span.
Private Function MatchesStartup(ByRef Text() As Byte, ByVal Start As Long, ByVal Length As Long) As Boolean
    If Length <> 7 Then Exit Function
    If Fold(Text(Start + 0)) <> 115 Then Exit Function
    If Fold(Text(Start + 1)) <> 116 Then Exit Function
    If Fold(Text(Start + 2)) <> 97 Then Exit Function
    If Fold(Text(Start + 3)) <> 114 Then Exit Function
    If Fold(Text(Start + 4)) <> 116 Then Exit Function
    If Fold(Text(Start + 5)) <> 117 Then Exit Function
    If Fold(Text(Start + 6)) <> 112 Then Exit Function
    MatchesStartup = True
End Function

' Matches the complete source spelling within an already bounded span.
Private Function MatchesSource(ByRef Text() As Byte, ByVal Start As Long, ByVal Length As Long) As Boolean
    If Length <> 6 Then Exit Function
    If Fold(Text(Start + 0)) <> 115 Then Exit Function
    If Fold(Text(Start + 1)) <> 111 Then Exit Function
    If Fold(Text(Start + 2)) <> 117 Then Exit Function
    If Fold(Text(Start + 3)) <> 114 Then Exit Function
    If Fold(Text(Start + 4)) <> 99 Then Exit Function
    If Fold(Text(Start + 5)) <> 101 Then Exit Function
    MatchesSource = True
End Function

' Matches the complete optimization spelling within an already bounded span.
Private Function MatchesOptimization(ByRef Text() As Byte, ByVal Start As Long, ByVal Length As Long) As Boolean
    If Length <> 12 Then Exit Function
    If Fold(Text(Start + 0)) <> 111 Then Exit Function
    If Fold(Text(Start + 1)) <> 112 Then Exit Function
    If Fold(Text(Start + 2)) <> 116 Then Exit Function
    If Fold(Text(Start + 3)) <> 105 Then Exit Function
    If Fold(Text(Start + 4)) <> 109 Then Exit Function
    If Fold(Text(Start + 5)) <> 105 Then Exit Function
    If Fold(Text(Start + 6)) <> 122 Then Exit Function
    If Fold(Text(Start + 7)) <> 97 Then Exit Function
    If Fold(Text(Start + 8)) <> 116 Then Exit Function
    If Fold(Text(Start + 9)) <> 105 Then Exit Function
    If Fold(Text(Start + 10)) <> 111 Then Exit Function
    If Fold(Text(Start + 11)) <> 110 Then Exit Function
    MatchesOptimization = True
End Function

' Matches the complete debuginformation spelling within an already bounded span.
Private Function MatchesDebuginformation(ByRef Text() As Byte, ByVal Start As Long, ByVal Length As Long) As Boolean
    If Length <> 16 Then Exit Function
    If Fold(Text(Start + 0)) <> 100 Then Exit Function
    If Fold(Text(Start + 1)) <> 101 Then Exit Function
    If Fold(Text(Start + 2)) <> 98 Then Exit Function
    If Fold(Text(Start + 3)) <> 117 Then Exit Function
    If Fold(Text(Start + 4)) <> 103 Then Exit Function
    If Fold(Text(Start + 5)) <> 105 Then Exit Function
    If Fold(Text(Start + 6)) <> 110 Then Exit Function
    If Fold(Text(Start + 7)) <> 102 Then Exit Function
    If Fold(Text(Start + 8)) <> 111 Then Exit Function
    If Fold(Text(Start + 9)) <> 114 Then Exit Function
    If Fold(Text(Start + 10)) <> 109 Then Exit Function
    If Fold(Text(Start + 11)) <> 97 Then Exit Function
    If Fold(Text(Start + 12)) <> 116 Then Exit Function
    If Fold(Text(Start + 13)) <> 105 Then Exit Function
    If Fold(Text(Start + 14)) <> 111 Then Exit Function
    If Fold(Text(Start + 15)) <> 110 Then Exit Function
    MatchesDebuginformation = True
End Function

' Matches the complete resource spelling within an already bounded span.
Private Function MatchesResource(ByRef Text() As Byte, ByVal Start As Long, ByVal Length As Long) As Boolean
    If Length <> 8 Then Exit Function
    If Fold(Text(Start + 0)) <> 114 Then Exit Function
    If Fold(Text(Start + 1)) <> 101 Then Exit Function
    If Fold(Text(Start + 2)) <> 115 Then Exit Function
    If Fold(Text(Start + 3)) <> 111 Then Exit Function
    If Fold(Text(Start + 4)) <> 117 Then Exit Function
    If Fold(Text(Start + 5)) <> 114 Then Exit Function
    If Fold(Text(Start + 6)) <> 99 Then Exit Function
    If Fold(Text(Start + 7)) <> 101 Then Exit Function
    MatchesResource = True
End Function

' Matches the complete reference spelling within an already bounded span.
Private Function MatchesReference(ByRef Text() As Byte, ByVal Start As Long, ByVal Length As Long) As Boolean
    If Length <> 9 Then Exit Function
    If Fold(Text(Start + 0)) <> 114 Then Exit Function
    If Fold(Text(Start + 1)) <> 101 Then Exit Function
    If Fold(Text(Start + 2)) <> 102 Then Exit Function
    If Fold(Text(Start + 3)) <> 101 Then Exit Function
    If Fold(Text(Start + 4)) <> 114 Then Exit Function
    If Fold(Text(Start + 5)) <> 101 Then Exit Function
    If Fold(Text(Start + 6)) <> 110 Then Exit Function
    If Fold(Text(Start + 7)) <> 99 Then Exit Function
    If Fold(Text(Start + 8)) <> 101 Then Exit Function
    MatchesReference = True
End Function

' Matches the complete libraryreference spelling within an already bounded span.
Private Function MatchesLibraryreference(ByRef Text() As Byte, ByVal Start As Long, ByVal Length As Long) As Boolean
    If Length <> 16 Then Exit Function
    If Fold(Text(Start + 0)) <> 108 Then Exit Function
    If Fold(Text(Start + 1)) <> 105 Then Exit Function
    If Fold(Text(Start + 2)) <> 98 Then Exit Function
    If Fold(Text(Start + 3)) <> 114 Then Exit Function
    If Fold(Text(Start + 4)) <> 97 Then Exit Function
    If Fold(Text(Start + 5)) <> 114 Then Exit Function
    If Fold(Text(Start + 6)) <> 121 Then Exit Function
    If Fold(Text(Start + 7)) <> 114 Then Exit Function
    If Fold(Text(Start + 8)) <> 101 Then Exit Function
    If Fold(Text(Start + 9)) <> 102 Then Exit Function
    If Fold(Text(Start + 10)) <> 101 Then Exit Function
    If Fold(Text(Start + 11)) <> 114 Then Exit Function
    If Fold(Text(Start + 12)) <> 101 Then Exit Function
    If Fold(Text(Start + 13)) <> 110 Then Exit Function
    If Fold(Text(Start + 14)) <> 99 Then Exit Function
    If Fold(Text(Start + 15)) <> 101 Then Exit Function
    MatchesLibraryreference = True
End Function

' Matches the complete startupform spelling within an already bounded span.
Private Function MatchesStartupform(ByRef Text() As Byte, ByVal Start As Long, ByVal Length As Long) As Boolean
    If Length <> 11 Then Exit Function
    If Fold(Text(Start + 0)) <> 115 Then Exit Function
    If Fold(Text(Start + 1)) <> 116 Then Exit Function
    If Fold(Text(Start + 2)) <> 97 Then Exit Function
    If Fold(Text(Start + 3)) <> 114 Then Exit Function
    If Fold(Text(Start + 4)) <> 116 Then Exit Function
    If Fold(Text(Start + 5)) <> 117 Then Exit Function
    If Fold(Text(Start + 6)) <> 112 Then Exit Function
    If Fold(Text(Start + 7)) <> 102 Then Exit Function
    If Fold(Text(Start + 8)) <> 111 Then Exit Function
    If Fold(Text(Start + 9)) <> 114 Then Exit Function
    If Fold(Text(Start + 10)) <> 109 Then Exit Function
    MatchesStartupform = True
End Function

' Matches the complete exe spelling within an already bounded span.
Private Function MatchesExe(ByRef Text() As Byte, ByVal Start As Long, ByVal Length As Long) As Boolean
    If Length <> 3 Then Exit Function
    If Fold(Text(Start + 0)) <> 101 Then Exit Function
    If Fold(Text(Start + 1)) <> 120 Then Exit Function
    If Fold(Text(Start + 2)) <> 101 Then Exit Function
    MatchesExe = True
End Function

' Matches the complete library spelling within an already bounded span.
Private Function MatchesLibrary(ByRef Text() As Byte, ByVal Start As Long, ByVal Length As Long) As Boolean
    If Length <> 7 Then Exit Function
    If Fold(Text(Start + 0)) <> 108 Then Exit Function
    If Fold(Text(Start + 1)) <> 105 Then Exit Function
    If Fold(Text(Start + 2)) <> 98 Then Exit Function
    If Fold(Text(Start + 3)) <> 114 Then Exit Function
    If Fold(Text(Start + 4)) <> 97 Then Exit Function
    If Fold(Text(Start + 5)) <> 114 Then Exit Function
    If Fold(Text(Start + 6)) <> 121 Then Exit Function
    MatchesLibrary = True
End Function

' Matches the complete main spelling within an already bounded span.
Private Function MatchesMain(ByRef Text() As Byte, ByVal Start As Long, ByVal Length As Long) As Boolean
    If Length <> 4 Then Exit Function
    If Fold(Text(Start + 0)) <> 109 Then Exit Function
    If Fold(Text(Start + 1)) <> 97 Then Exit Function
    If Fold(Text(Start + 2)) <> 105 Then Exit Function
    If Fold(Text(Start + 3)) <> 110 Then Exit Function
    MatchesMain = True
End Function

' Matches the complete size spelling within an already bounded span.
Private Function MatchesSize(ByRef Text() As Byte, ByVal Start As Long, ByVal Length As Long) As Boolean
    If Length <> 4 Then Exit Function
    If Fold(Text(Start + 0)) <> 115 Then Exit Function
    If Fold(Text(Start + 1)) <> 105 Then Exit Function
    If Fold(Text(Start + 2)) <> 122 Then Exit Function
    If Fold(Text(Start + 3)) <> 101 Then Exit Function
    MatchesSize = True
End Function

' Matches the complete none spelling within an already bounded span.
Private Function MatchesNone(ByRef Text() As Byte, ByVal Start As Long, ByVal Length As Long) As Boolean
    If Length <> 4 Then Exit Function
    If Fold(Text(Start + 0)) <> 110 Then Exit Function
    If Fold(Text(Start + 1)) <> 111 Then Exit Function
    If Fold(Text(Start + 2)) <> 110 Then Exit Function
    If Fold(Text(Start + 3)) <> 101 Then Exit Function
    MatchesNone = True
End Function

' Matches the complete line spelling within an already bounded span.
Private Function MatchesLine(ByRef Text() As Byte, ByVal Start As Long, ByVal Length As Long) As Boolean
    If Length <> 4 Then Exit Function
    If Fold(Text(Start + 0)) <> 108 Then Exit Function
    If Fold(Text(Start + 1)) <> 105 Then Exit Function
    If Fold(Text(Start + 2)) <> 110 Then Exit Function
    If Fold(Text(Start + 3)) <> 101 Then Exit Function
    MatchesLine = True
End Function

' Matches the complete full spelling within an already bounded span.
Private Function MatchesFull(ByRef Text() As Byte, ByVal Start As Long, ByVal Length As Long) As Boolean
    If Length <> 4 Then Exit Function
    If Fold(Text(Start + 0)) <> 102 Then Exit Function
    If Fold(Text(Start + 1)) <> 117 Then Exit Function
    If Fold(Text(Start + 2)) <> 108 Then Exit Function
    If Fold(Text(Start + 3)) <> 108 Then Exit Function
    MatchesFull = True
End Function

' Matches the complete ube-project spelling within an already bounded span.
Private Function MatchesUbeProject(ByRef Text() As Byte, ByVal Start As Long, ByVal Length As Long) As Boolean
    If Length <> 11 Then Exit Function
    If Fold(Text(Start + 0)) <> 117 Then Exit Function
    If Fold(Text(Start + 1)) <> 98 Then Exit Function
    If Fold(Text(Start + 2)) <> 101 Then Exit Function
    If Fold(Text(Start + 3)) <> 45 Then Exit Function
    If Fold(Text(Start + 4)) <> 112 Then Exit Function
    If Fold(Text(Start + 5)) <> 114 Then Exit Function
    If Fold(Text(Start + 6)) <> 111 Then Exit Function
    If Fold(Text(Start + 7)) <> 106 Then Exit Function
    If Fold(Text(Start + 8)) <> 101 Then Exit Function
    If Fold(Text(Start + 9)) <> 99 Then Exit Function
    If Fold(Text(Start + 10)) <> 116 Then Exit Function
    MatchesUbeProject = True
End Function


' Recognizes the only permitted horizontal manifest whitespace.
Private Function IsHorizontal(ByVal Character As Long) As Boolean
    IsHorizontal = Character = 32 Or Character = 9
End Function

' Trims a validated half-open line span without reading outside it.
Private Sub TrimSpan(ByRef Text() As Byte, ByRef Start As Long, ByRef Finish As Long)
    Do While Start < Finish
        If IsHorizontal(Text(Start)) = False Then Exit Do
        Start = Start + 1
    Loop
    Do While Finish > Start
        If IsHorizontal(Text(Finish - 1)) = False Then Exit Do
        Finish = Finish - 1
    Loop
End Sub

' Checks the current bounded ASCII project and key identifier profile.
Private Function IsIdentifier(ByRef Text() As Byte, ByVal Start As Long, ByVal Length As Long) As Boolean
    Dim Index As Long
    Dim Character As Long
    If Length < 1 Or Length > 128 Then Exit Function
    Do While Index < Length
        Character = Fold(Text(Start + Index))
        If Character <> 95 Then
            If Character < 97 Or Character > 122 Then
                If Index = 0 Or Character < 48 Or Character > 57 Then Exit Function
            End If
        End If
        Index = Index + 1
    Loop
    IsIdentifier = True
End Function

' Decodes a previously retained quoted interior; destination changes only on success.
Public Function TryCopyValue(ByRef Text() As Byte, ByVal Start As Long, ByVal Length As Long, ByRef Result() As Byte) As Boolean
    Dim Candidate() As Byte
    Dim Index As Long
    Dim Used As Long
    Dim Actual As Long
    Dim Character As Long
    On Error GoTo Failed
    Actual = BufferPrimitives.ByteStorageLength(Text)
    If Start < 0 Or Length < 0 Or Start > Actual Then Exit Function
    If Length > Actual - Start Then Exit Function
    Do While Index < Length
        Character = Text(Start + Index)
        If Character = 34 Then
            Index = Index + 1
            If Index >= Length Then Exit Function
            If Text(Start + Index) <> 34 Then Exit Function
        End If
        If Character = 10 Or Character = 13 Then Exit Function
        Index = Index + 1
        Used = Used + 1
    Loop
    If BufferPrimitives.TryResizeBytes(Candidate, Used, False) = False Then Exit Function
    Index = 0
    Used = 0
    Do While Index < Length
        Character = Text(Start + Index)
        Candidate(Used) = Character
        If Character = 34 Then Index = Index + 1
        Index = Index + 1
        Used = Used + 1
    Loop
    TryCopyValue = BufferPrimitives.TryCopyBytes(Result, Candidate)
    Exit Function
Failed:
    Exit Function
End Function

' Checks relative spelling; normalization and physical containment belong to the loader.
Private Function ValidSourcePath(ByRef Text() As Byte, ByVal Start As Long, ByVal Length As Long) As Boolean
    Dim Index As Long
    Dim Character As Long
    Dim ByteWidth As Long
    Dim Units As Long
    Dim Characters As Long
    If Length < 1 Then Exit Function
    Character = Text(Start)
    If Character = 47 Or Character = 92 Then Exit Function
    Do While Index < Length
        Character = Text(Start + Index)
        If Character < 32 Or Character = 34 Or Character = 42 Or Character = 58 Or Character = 60 Or Character = 62 Or Character = 63 Or Character = 124 Then Exit Function
        If Utf8.TrySequenceWidth(Text, Start + Index, Start + Length, ByteWidth, Units) = False Then Exit Function
        Characters = Characters + Units
        If Characters > 32767 Then Exit Function
        Index = Index + ByteWidth
    Loop
    ValidSourcePath = True
End Function

' Codes: 1 header, 2 syntax, 3 duplicate key, 4 identifier, 5 value,
' 6 unsupported, 7 unknown key, 8 required, 9 limit, 10 encoding,
' 11 path, 12 storage/runtime. Columns are one-based byte positions for syntax.
' The original Text must remain unchanged while retained value spans are used.
Public Function TryParse(ByRef Text() As Byte, ByRef Sources() As ValueSpan, ByRef Info As ManifestInfo, ByRef Diagnostic As ManifestDiagnostic) As Boolean
    Dim Candidate() As ValueSpan
    Dim NextInfo As ManifestInfo
    Dim Seen(0 To 10) As Boolean
    Dim Length As Long
    Dim Position As Long
    Dim LineStart As Long
    Dim LineEnd As Long
    Dim Start As Long
    Dim Finish As Long
    Dim KeyEnd As Long
    Dim ValueStart As Long
    Dim ValueLength As Long
    Dim Scan As Long
    Dim Key As Long
    Dim Character As Long
    Dim ByteWidth As Long
    Dim Units As Long
    Dim HeaderSeen As Boolean
    Dim Closed As Boolean
    Dim LineNumber As Long = 1
    On Error GoTo Failed
    Diagnostic.Code = 9
    Diagnostic.Line = 1
    Diagnostic.Column = 1
    Length = BufferPrimitives.ByteStorageLength(Text)
    If Length > 65536 Then Exit Function
    Diagnostic.Code = 10
    Do While Position < Length
        Character = Text(Position)
        If Utf8.TrySequenceWidth(Text, Position, Length, ByteWidth, Units) = False Then Exit Function
        If Character < 32 And Character <> 9 And Character <> 10 And Character <> 13 Then Exit Function
        If Character = 127 Then Exit Function
        If Character = 13 Then
            If Position + 1 >= Length Then Exit Function
            If Text(Position + 1) <> 10 Then Exit Function
        End If
        Position = Position + ByteWidth
        Diagnostic.Column = Diagnostic.Column + Units
        If Character = 10 Then
            Diagnostic.Line = Diagnostic.Line + 1
            Diagnostic.Column = 1
        End If
    Loop
    Position = 0
    If Length >= 3 Then
        If Text(0) = 239 And Text(1) = 187 And Text(2) = 191 Then Position = 3
    End If
    NextInfo.Optimization = 2
    NextInfo.DebugInformation = 2
    Diagnostic.Code = 12
    If ResizeSpans(Candidate, 128, False) = False Then Exit Function
    Do While Position < Length
        LineStart = Position
        LineEnd = Position
        Do While LineEnd < Length
            If Text(LineEnd) = 10 Then Exit Do
            LineEnd = LineEnd + 1
        Loop
        Position = LineEnd
        If Position < Length Then Position = Position + 1
        Start = LineStart
        Finish = LineEnd
        If Finish > Start Then
            If Text(Finish - 1) = 13 Then Finish = Finish - 1
        End If
        TrimSpan Text, Start, Finish
        Diagnostic.Line = LineNumber
        Diagnostic.Column = Start - LineStart + 1
        LineNumber = LineNumber + 1
        If Start < Finish Then
            If Text(Start) <> 39 Then
                If HeaderSeen = False Then
                    Diagnostic.Code = 1
                    If Finish - Start < 13 Then Exit Function
                    If MatchesWord(Text, Start, 11, 18) = False Then Exit Function
                    Scan = Start + 11
                    If IsHorizontal(Text(Scan)) = False Then Exit Function
                    Do While Scan < Finish
                        If IsHorizontal(Text(Scan)) = False Then Exit Do
                        Scan = Scan + 1
                    Loop
                    If Finish - Scan <> 1 Then Exit Function
                    If Text(Scan) <> 49 Then Exit Function
                    HeaderSeen = True
                Else
                    Diagnostic.Code = 2
                    Scan = Start
                    Do While Scan < Finish
                        If Text(Scan) = 61 Then Exit Do
                        Scan = Scan + 1
                    Loop
                    If Scan >= Finish Then Exit Function
                    KeyEnd = Scan
                    TrimSpan Text, Start, KeyEnd
                    If IsIdentifier(Text, Start, KeyEnd - Start) = False Then Exit Function
                    Scan = Scan + 1
                    Do While Scan < Finish
                        If IsHorizontal(Text(Scan)) = False Then Exit Do
                        Scan = Scan + 1
                    Loop
                    If Scan >= Finish Then Exit Function
                    If Text(Scan) <> 34 Then Exit Function
                    ValueStart = Scan + 1
                    Scan = ValueStart
                    Closed = False
                    Do While Scan < Finish
                        If Text(Scan) = 34 Then
                            If Scan + 1 < Finish Then
                                If Text(Scan + 1) = 34 Then
                                    Scan = Scan + 2
                                Else
                                    Closed = True
                                    Exit Do
                                End If
                            Else
                                Closed = True
                                Exit Do
                            End If
                        Else
                            Scan = Scan + 1
                        End If
                    Loop
                    If Closed = False Then Exit Function
                    ValueLength = Scan - ValueStart
                    Scan = Scan + 1
                    Do While Scan < Finish
                        If IsHorizontal(Text(Scan)) = False Then Exit Function
                        Scan = Scan + 1
                    Loop
                    Key = 1
                    Do While Key <= 10
                        If MatchesWord(Text, Start, KeyEnd - Start, Key) Then Exit Do
                        Key = Key + 1
                    Loop
                    Diagnostic.Code = 7
                    If Key > 10 Then Exit Function
                    Diagnostic.Code = 3
                    If Key <> 4 And Seen(Key) Then Exit Function
                    Seen(Key) = True
                    Diagnostic.Code = 5
                    If Key = 1 Then
                        Diagnostic.Code = 4
                        If IsIdentifier(Text, ValueStart, ValueLength) = False Then Exit Function
                        NextInfo.NameStart = ValueStart
                        NextInfo.NameLength = ValueLength
                    ElseIf Key = 2 Then
                        If MatchesWord(Text, ValueStart, ValueLength, 11) Then
                            NextInfo.IsExecutable = True
                        ElseIf MatchesWord(Text, ValueStart, ValueLength, 12) = False Then
                            Exit Function
                        End If
                    ElseIf Key = 3 Then
                        If MatchesWord(Text, ValueStart, ValueLength, 13) = False Then Exit Function
                    ElseIf Key = 4 Then
                        Diagnostic.Code = 11
                        If ValidSourcePath(Text, ValueStart, ValueLength) = False Then Exit Function
                        Diagnostic.Code = 6
                        If ValueLength < 4 Then Exit Function
                        Scan = ValueStart + ValueLength - 4
                        If Text(Scan) <> 46 Or Fold(Text(Scan + 1)) <> 98 Or Fold(Text(Scan + 2)) <> 97 Or Fold(Text(Scan + 3)) <> 115 Then Exit Function
                        Diagnostic.Code = 9
                        If NextInfo.SourceCount >= 128 Then Exit Function
                        Candidate(NextInfo.SourceCount).Start = ValueStart
                        Candidate(NextInfo.SourceCount).Length = ValueLength
                        Candidate(NextInfo.SourceCount).Line = Diagnostic.Line
                        NextInfo.SourceCount = NextInfo.SourceCount + 1
                    ElseIf Key = 5 Then
                        If MatchesWord(Text, ValueStart, ValueLength, 14) Then
                            NextInfo.Optimization = 4
                        Else
                            If ValueLength <> 1 Then Exit Function
                            Character = Text(ValueStart)
                            If Character < 48 Or Character > 51 Then Exit Function
                            NextInfo.Optimization = Character - 48
                        End If
                    ElseIf Key = 6 Then
                        If MatchesWord(Text, ValueStart, ValueLength, 15) Then
                            NextInfo.DebugInformation = 0
                        ElseIf MatchesWord(Text, ValueStart, ValueLength, 16) Then
                            NextInfo.DebugInformation = 1
                        ElseIf MatchesWord(Text, ValueStart, ValueLength, 17) = False Then
                            Exit Function
                        End If
                    Else
                        Diagnostic.Code = 6
                        Exit Function
                    End If
                End If
            End If
        End If
    Loop
    Diagnostic.Code = 1
    If HeaderSeen = False Then Exit Function
    Diagnostic.Code = 8
    If Seen(1) = False Or Seen(2) = False Or NextInfo.SourceCount = 0 Then Exit Function
    If NextInfo.IsExecutable And Seen(3) = False Then Exit Function
    Diagnostic.Code = 5
    If NextInfo.IsExecutable = False And Seen(3) Then Exit Function
    Diagnostic.Code = 12
    If ResizeSpans(Candidate, NextInfo.SourceCount, True) = False Then Exit Function
    Sources = Candidate
    Info = NextInfo
    Diagnostic.Code = 0
    Diagnostic.Line = 0
    Diagnostic.Column = 0
    TryParse = True
    Exit Function
Failed:
    Diagnostic.Code = 12
    Exit Function
End Function

