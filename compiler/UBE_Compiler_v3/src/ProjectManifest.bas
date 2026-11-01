UBE SOURCE 1 MODULE
Attribute UBE_Name = "ProjectManifest"

' Compiler-owned manifest policy. All spans borrow the original qualified
' document; values exclude outer quotes but retain doubled-quote spelling.
Type ProjectDeclaration
    FirstByte As Long
    LastByte As Long
    ValueFirst As Long
    ValueLast As Long
End Type

' Reserved private construction state, immutable with its owning project after
' publication. Kind 1=Exe/2=Library; Optimization 4=Size; debug 0=None/1=Line/2=Full.
Type ProjectManifest
    NameFirst As Long
    NameLast As Long
    Kind As Long
    KindFirst As Long
    KindLast As Long
    StartupFirst As Long
    StartupLast As Long
    Optimization As Long
    DebugInformation As Long
    Sources() As ProjectDeclaration
    SourceCount As Long
    References() As ProjectDeclaration
    ReferenceCount As Long
    UnsupportedKind As Long
    UnsupportedFirst As Long
    UnsupportedLast As Long
End Type

' Entry kinds: Name1, Kind2, Startup3, Source4, Reference5, Optimization6,
' DebugInformation7, Resource8, StartupForm9, LibraryReference10. Zero is header.
Type ProjectManifestFailure
    Code As Long
    EntryKind As Long
    FirstByte As Long
    LastByte As Long
End Type

Intrinsic Function TryResizeProjectDeclarations(ByRef Values() As ProjectDeclaration, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeProjectDeclarations.UBE_Primitive = "Array.TryResize"
End Function

Intrinsic Function TryResizeProjectSeen(ByRef Values() As Boolean, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeProjectSeen.UBE_Primitive = "Array.TryResize"
End Function

Function RejectProjectManifest(ByRef Failure As ProjectManifestFailure, ByVal Code As Long, ByVal EntryKind As Long, ByVal FirstByte As Long, ByVal LastByte As Long) As Boolean
    RejectProjectManifest = False
    Failure.Code = Code
    Failure.EntryKind = EntryKind
    Failure.FirstByte = FirstByte
    Failure.LastByte = LastByte
End Function

' Fallible match versus an immutable trusted lowercase ASCII word. Does not
' apply UBE Unicode identifier folding to file-format keys or enum values.
Function TryMatchProjectWord(ByRef Bytes() As Byte, ByVal FirstByte As Long, ByVal LastByte As Long, ByVal Expected As String, ByRef Matches As Boolean) As Boolean
    TryMatchProjectWord = False
    Matches = False
    Dim Count As Long = StringLength(Expected)
    If LastByte - FirstByte <> Count Then
        TryMatchProjectWord = True
        Exit Function
    End If
    Dim Index As Long = 0
    While Index < Count
        Dim Value As Long = Bytes(FirstByte + Index)
        If Value >= 65 And Value <= 90 Then
            Value = Value + 32
        End If
        If Value <> StringByteAt(Expected, Index) Then
            TryMatchProjectWord = True
            Exit Function
        End If
        Index = Index + 1
    Wend
    Matches = True
    TryMatchProjectWord = True
End Function

Function TrySkipProjectSpace(ByRef Bytes() As Byte, ByVal LastByte As Long, ByRef Cursor As Long) As Boolean
    TrySkipProjectSpace = False
    While Cursor < LastByte
        If Bytes(Cursor) <> 32 And Bytes(Cursor) <> 9 Then
            Exit While
        End If
        Cursor = Cursor + 1
    Wend
    TrySkipProjectSpace = True
End Function

' Keeps the earliest structural witness while scanning independent later lines
' for scalar combinations, e.g. StartupForm preceding Kind=Library.
Sub KeepProjectManifestFailure(ByRef FirstFailure As ProjectManifestFailure, ByRef Candidate As ProjectManifestFailure)
    If FirstFailure.Code = 0 Or Candidate.FirstByte < FirstFailure.FirstByte Then
        FirstFailure = Candidate
    End If
End Sub

Function TryReadProjectHeader(ByRef Bytes() As Byte, ByVal FirstByte As Long, ByVal LastByte As Long, ByRef Failure As ProjectManifestFailure) As Boolean
    TryReadProjectHeader = False
    Dim Cursor As Long = FirstByte
    Dim WordLast As Long = Cursor
    While WordLast < LastByte
        If Bytes(WordLast) = 32 Or Bytes(WordLast) = 9 Then
            Exit While
        End If
        WordLast = WordLast + 1
    Wend
    Dim Matches As Boolean = False
    If TryMatchProjectWord(Bytes, Cursor, WordLast, "ube-project", Matches) = False Then
        Exit Function
    End If
    If Matches = False Then
        Call RejectProjectManifest(Failure, 1300, 0, FirstByte, WordLast)
        Exit Function
    End If
    Cursor = WordLast
    If TrySkipProjectSpace(Bytes, LastByte, Cursor) = False Then
        Exit Function
    End If
    Dim VersionFirst As Long = Cursor
    Dim VersionOne As Boolean = True
    While Cursor < LastByte
        Dim Value As Long = Bytes(Cursor)
        If Value < 48 Or Value > 57 Then
            Exit While
        End If
        If Value <> 48 Then
            If Value <> 49 Then
                VersionOne = False
            Else
                If Cursor + 1 < LastByte Then
                    Dim NextByte As Long = Bytes(Cursor + 1)
                    If NextByte >= 48 And NextByte <= 57 Then
                        VersionOne = False
                    End If
                End If
            End If
        End If
        Cursor = Cursor + 1
    Wend
    Dim VersionLast As Long = Cursor
    If VersionLast = VersionFirst Then
        Dim BadLast As Long = Cursor
        If BadLast < LastByte Then
            BadLast = BadLast + 1
        End If
        Call RejectProjectManifest(Failure, 1300, 0, Cursor, BadLast)
        Exit Function
    End If
    If Bytes(VersionLast - 1) <> 49 Then
        VersionOne = False
    End If
    If TrySkipProjectSpace(Bytes, LastByte, Cursor) = False Then
        Exit Function
    End If
    If Cursor <> LastByte Then
        Dim WitnessLast As Long = Cursor + 1
        Call RejectProjectManifest(Failure, 1300, 0, Cursor, WitnessLast)
        Exit Function
    End If
    If VersionOne = False Then
        Call RejectProjectManifest(Failure, 1301, 0, VersionFirst, VersionLast)
        Exit Function
    End If
    Failure.Code = 0
    TryReadProjectHeader = True
End Function

Function TryReadProjectEntry(ByRef Bytes() As Byte, ByVal FirstByte As Long, ByVal LastByte As Long, ByRef EntryKind As Long, ByRef Entry As ProjectDeclaration, ByRef Failure As ProjectManifestFailure) As Boolean
    TryReadProjectEntry = False
    EntryKind = 0
    Entry.FirstByte = FirstByte
    Dim Cursor As Long = FirstByte
    While Cursor < LastByte
        Dim Value As Long = Bytes(Cursor)
        If Value = 32 Or Value = 9 Or Value = 61 Then
            Exit While
        End If
        If (Value < 65 Or Value > 90) And (Value < 97 Or Value > 122) And (Value < 48 Or Value > 57) And Value <> 95 Then
            Call RejectProjectManifest(Failure, 1302, 0, Cursor, Cursor + 1)
            Exit Function
        End If
        Cursor = Cursor + 1
    Wend
    Entry.LastByte = Cursor
    If Cursor = FirstByte Then
        Call RejectProjectManifest(Failure, 1302, 0, Cursor, Cursor)
        Exit Function
    End If
    If TrySkipProjectSpace(Bytes, LastByte, Cursor) = False Then
        Exit Function
    End If
    If Cursor = LastByte Then
        Call RejectProjectManifest(Failure, 1302, 0, Cursor, Cursor)
        Exit Function
    End If
    If Bytes(Cursor) <> 61 Then
        Call RejectProjectManifest(Failure, 1302, 0, Cursor, Cursor + 1)
        Exit Function
    End If
    Cursor = Cursor + 1
    If TrySkipProjectSpace(Bytes, LastByte, Cursor) = False Then
        Exit Function
    End If
    If Cursor = LastByte Then
        Call RejectProjectManifest(Failure, 1302, 0, Cursor, Cursor)
        Exit Function
    End If
    If Bytes(Cursor) <> 34 Then
        Call RejectProjectManifest(Failure, 1302, 0, Cursor, LastByte)
        Exit Function
    End If
    Cursor = Cursor + 1
    Entry.ValueFirst = Cursor
    Dim Closed As Boolean = False
    While Cursor < LastByte
        Value = Bytes(Cursor)
        If Value = 0 Then
            Call RejectProjectManifest(Failure, 1302, 0, Cursor, Cursor + 1)
            Exit Function
        End If
        If Value = 34 Then
            Dim Doubled As Boolean = False
            If Cursor + 1 < LastByte Then
                Doubled = Bytes(Cursor + 1) = 34
            End If
            If Doubled Then
                Cursor = Cursor + 2
            Else
                Entry.ValueLast = Cursor
                Cursor = Cursor + 1
                Closed = True
                Exit While
            End If
        Else
            Cursor = Cursor + 1
        End If
    Wend
    If Closed = False Then
        Call RejectProjectManifest(Failure, 1302, 0, LastByte, LastByte)
        Exit Function
    End If
    If TrySkipProjectSpace(Bytes, LastByte, Cursor) = False Then
        Exit Function
    End If
    If Cursor <> LastByte Then
        Call RejectProjectManifest(Failure, 1302, 0, Cursor, LastByte)
        Exit Function
    End If
    Dim KeyIndex As Long = 1
    While KeyIndex <= 10
        Dim Word As String = "name"
        If KeyIndex = 2 Then
            Word = "kind"
        End If
        If KeyIndex = 3 Then
            Word = "startup"
        End If
        If KeyIndex = 4 Then
            Word = "source"
        End If
        If KeyIndex = 5 Then
            Word = "reference"
        End If
        If KeyIndex = 6 Then
            Word = "optimization"
        End If
        If KeyIndex = 7 Then
            Word = "debuginformation"
        End If
        If KeyIndex = 8 Then
            Word = "resource"
        End If
        If KeyIndex = 9 Then
            Word = "startupform"
        End If
        If KeyIndex = 10 Then
            Word = "libraryreference"
        End If
        Dim Matches As Boolean = False
        If TryMatchProjectWord(Bytes, FirstByte, Entry.LastByte, Word, Matches) = False Then
            Exit Function
        End If
        If Matches Then
            EntryKind = KeyIndex
            Failure.Code = 0
            TryReadProjectEntry = True
            Exit Function
        End If
        KeyIndex = KeyIndex + 1
    Wend
    Call RejectProjectManifest(Failure, 1303, 0, FirstByte, Entry.LastByte)
End Function

' Called only on private, previously zeroed metadata. It retains original spans
' and no input references. Failure permits partial metadata, never publication.
' Document must satisfy SourceDocument's UTF-8/newline contract. Failure.Code
' must be seeded 1310 before managed entry; success preserves earlier Err.
Function TryReadProjectManifest(ByRef Document As SourceDocument, ByRef Metadata As ProjectManifest, ByRef Failure As ProjectManifestFailure) As Boolean
    TryReadProjectManifest = False
    Failure.Code = 1310
    Failure.EntryKind = 0
    Failure.FirstByte = 0
    Failure.LastByte = 0
    Dim Length As Long = ByteStorageLength(Document.Bytes)
    If Length > 1048576 Then
        TryReadProjectManifest = RejectProjectManifest(Failure, 1309, 0, 0, 0)
        Exit Function
    End If
    If Document.ContentStart < 0 Or Document.ContentStart > Length Then
        TryReadProjectManifest = RejectProjectManifest(Failure, 1320, 0, 0, 0)
        Exit Function
    End If
    If Document.ContentStart <> 0 And Document.ContentStart <> 3 Then
        TryReadProjectManifest = RejectProjectManifest(Failure, 1320, 0, 0, 0)
        Exit Function
    End If
    ' Manifest text forbids NUL even in a comment or blank/header line. Source
    ' documents deliberately permit that scalar, so enforce this format rule
    ' before interpreting version-one entries or allocating metadata vectors.
    Dim CheckByte As Long = Document.ContentStart
    While CheckByte < Length
        If Document.Bytes(CheckByte) = 0 Then
            TryReadProjectManifest = RejectProjectManifest(Failure, 1302, 0, CheckByte, CheckByte + 1)
            Exit Function
        End If
        CheckByte = CheckByte + 1
    Wend
    Metadata.Optimization = 2
    Metadata.DebugInformation = 2
    If TryResizeProjectDeclarations(Metadata.Sources, 256, False) = False Then
        Exit Function
    End If
    If TryResizeProjectDeclarations(Metadata.References, 2, False) = False Then
        Exit Function
    End If
    Dim FirstFailure As ProjectManifestFailure
    Dim Seen() As Boolean
    If TryResizeProjectSeen(Seen, 11, False) = False Then
        Exit Function
    End If
    Dim HeaderSeen As Boolean = False
    Dim StartupForm As ProjectDeclaration
    Dim Cursor As Long = Document.ContentStart
    While Cursor < Length
        Dim LineFirst As Long = Cursor
        While Cursor < Length
            If Document.Bytes(Cursor) = 10 Then
                Exit While
            End If
            Cursor = Cursor + 1
        Wend
        Dim LineLast As Long = Cursor
        If LineLast > LineFirst Then
            If Document.Bytes(LineLast - 1) = 13 Then
                LineLast = LineLast - 1
            End If
        End If
        Dim NextLine As Long = Cursor
        If NextLine < Length Then
            NextLine = NextLine + 1
        End If
        Cursor = LineFirst
        Failure.Code = 1310
        If TrySkipProjectSpace(Document.Bytes, LineLast, Cursor) = False Then
            Exit Function
        End If
        Dim Meaningful As Boolean = Cursor < LineLast
        If Meaningful Then
            Meaningful = Document.Bytes(Cursor) <> 39
        End If
        If Meaningful Then
            If HeaderSeen = False Then
                If TryReadProjectHeader(Document.Bytes, Cursor, LineLast, Failure) = False Then
                    Exit Function
                End If
                HeaderSeen = True
            Else
                Dim Entry As ProjectDeclaration
                Dim EntryKind As Long = 0
                Failure.Code = 1310
                If TryReadProjectEntry(Document.Bytes, Cursor, LineLast, EntryKind, Entry, Failure) = False Then
                    If Failure.Code = 1310 Then
                        Exit Function
                    End If
                    Call KeepProjectManifestFailure(FirstFailure, Failure)
                Else
                    Failure.Code = 1310
                    If TryApplyProjectEntry(Document, Metadata, Seen, StartupForm, EntryKind, Entry, Failure) = False Then
                        If Failure.Code = 1310 Then
                            Exit Function
                        End If
                        Call KeepProjectManifestFailure(FirstFailure, Failure)
                    End If
                End If
            End If
        End If
        Cursor = NextLine
    Wend
    If HeaderSeen = False Then
        TryReadProjectManifest = RejectProjectManifest(Failure, 1300, 0, Length, Length)
        Exit Function
    End If
    If Metadata.Kind = 2 Then
        If Seen(3) Then
            Call RejectProjectManifest(Failure, 1306, 3, Metadata.StartupFirst, Metadata.StartupLast)
            Call KeepProjectManifestFailure(FirstFailure, Failure)
        End If
        If Seen(9) Then
            Call RejectProjectManifest(Failure, 1306, 9, StartupForm.ValueFirst, StartupForm.ValueLast)
            Call KeepProjectManifestFailure(FirstFailure, Failure)
        End If
    End If
    Dim MissingKind As Long = 0
    If Seen(1) = False Then
        MissingKind = 1
    Else
        If Seen(2) = False Then
            MissingKind = 2
        Else
            If Metadata.Kind = 1 And Seen(3) = False Then
                MissingKind = 3
            Else
                If Metadata.SourceCount = 0 Then
                    MissingKind = 4
                End If
            End If
        End If
    End If
    If MissingKind <> 0 Then
        Call RejectProjectManifest(Failure, 1305, MissingKind, Length, Length)
        Call KeepProjectManifestFailure(FirstFailure, Failure)
    End If
    If FirstFailure.Code <> 0 Then
        Failure = FirstFailure
        Exit Function
    End If
    Failure.Code = 0
    Failure.EntryKind = 0
    Failure.FirstByte = 0
    Failure.LastByte = 0
    TryReadProjectManifest = True
End Function

Function TryApplyProjectEntry(ByRef Document As SourceDocument, ByRef Metadata As ProjectManifest, ByRef Seen() As Boolean, ByRef StartupForm As ProjectDeclaration, ByVal EntryKind As Long, ByRef Entry As ProjectDeclaration, ByRef Failure As ProjectManifestFailure) As Boolean
    TryApplyProjectEntry = False
    If EntryKind <> 4 And EntryKind <> 5 And EntryKind <> 8 And EntryKind <> 10 Then
        If Seen(EntryKind) Then
            Call RejectProjectManifest(Failure, 1304, EntryKind, Entry.FirstByte, Entry.LastByte)
            Exit Function
        End If
        Seen(EntryKind) = True
    End If
    Dim ValueFirst As Long = Entry.ValueFirst
    Dim ValueLast As Long = Entry.ValueLast
    If EntryKind = 1 Then
        Metadata.NameFirst = ValueFirst - 1
        Metadata.NameLast = ValueLast + 1
        Dim Cursor As Long = Metadata.NameFirst
        Dim FirstByte As Long = 0
        Dim LastByte As Long = 0
        Dim Valid As Boolean = False
        Dim Closed As Boolean = False
        If TryEnvelopeQuotedName(Document.Bytes, ValueLast + 1, Cursor, FirstByte, LastByte, Valid, Closed) = False Then
            Exit Function
        End If
        If Valid = False Or Closed = False Then
            Call RejectProjectManifest(Failure, 1306, EntryKind, ValueFirst, ValueLast)
            Exit Function
        End If
    Else
        If EntryKind = 2 Then
            Metadata.KindFirst = ValueFirst
            Metadata.KindLast = ValueLast
            Dim Matches As Boolean = False
            If TryMatchProjectWord(Document.Bytes, ValueFirst, ValueLast, "exe", Matches) = False Then
                Exit Function
            End If
            If Matches Then
                Metadata.Kind = 1
            Else
                If TryMatchProjectWord(Document.Bytes, ValueFirst, ValueLast, "library", Matches) = False Then
                    Exit Function
                End If
                If Matches Then
                    Metadata.Kind = 2
                Else
                    Call RejectProjectManifest(Failure, 1306, EntryKind, ValueFirst, ValueLast)
                    Exit Function
                End If
            End If
        Else
            If EntryKind = 3 Then
                Metadata.StartupFirst = ValueFirst
                Metadata.StartupLast = ValueLast
                Dim MainMatches As Boolean = False
                If TryMatchProjectWord(Document.Bytes, ValueFirst, ValueLast, "main", MainMatches) = False Then
                    Exit Function
                End If
                If MainMatches = False Then
                    Call RejectProjectManifest(Failure, 1306, EntryKind, ValueFirst, ValueLast)
                    Exit Function
                End If
            Else
                If EntryKind = 4 Then
                    If ValueFirst = ValueLast Then
                        Call RejectProjectManifest(Failure, 1306, EntryKind, ValueFirst, ValueLast)
                        Exit Function
                    End If
                    If Metadata.SourceCount >= 256 Then
                        Call RejectProjectManifest(Failure, 1309, EntryKind, ValueFirst, ValueLast)
                        Exit Function
                    End If
                    Metadata.Sources(Metadata.SourceCount) = Entry
                    Metadata.SourceCount = Metadata.SourceCount + 1
                Else
                    If EntryKind = 5 Then
                        If ValueFirst = ValueLast Then
                            Call RejectProjectManifest(Failure, 1306, EntryKind, ValueFirst, ValueLast)
                            Exit Function
                        End If
                        If Metadata.ReferenceCount < 2 Then
                            Metadata.References(Metadata.ReferenceCount) = Entry
                        End If
                        Metadata.ReferenceCount = Metadata.ReferenceCount + 1
                    Else
                        If EntryKind = 6 Then
                            Dim Numeric As Boolean = False
                            If ValueLast - ValueFirst = 1 Then
                                Dim Value As Long = Document.Bytes(ValueFirst)
                                If Value >= 48 And Value <= 51 Then
                                    Numeric = True
                                    Metadata.Optimization = Value - 48
                                End If
                            End If
                            If Numeric = False Then
                                Dim SizeMatches As Boolean = False
                                If TryMatchProjectWord(Document.Bytes, ValueFirst, ValueLast, "size", SizeMatches) = False Then
                                    Exit Function
                                End If
                                If SizeMatches = False Then
                                    Call RejectProjectManifest(Failure, 1306, EntryKind, ValueFirst, ValueLast)
                                    Exit Function
                                End If
                                Metadata.Optimization = 4
                            End If
                        Else
                            If EntryKind = 7 Then
                                Dim Setting As Long = 0
                                Dim SettingAccepted As Boolean = False
                                While Setting <= 2
                                    Dim Word As String = "none"
                                    If Setting = 1 Then
                                        Word = "line"
                                    End If
                                    If Setting = 2 Then
                                        Word = "full"
                                    End If
                                    Dim SettingMatches As Boolean = False
                                    If TryMatchProjectWord(Document.Bytes, ValueFirst, ValueLast, Word, SettingMatches) = False Then
                                        Exit Function
                                    End If
                                    If SettingMatches Then
                                        Metadata.DebugInformation = Setting
                                        SettingAccepted = True
                                        Exit While
                                    End If
                                    Setting = Setting + 1
                                Wend
                                If SettingAccepted = False Then
                                    Call RejectProjectManifest(Failure, 1306, EntryKind, ValueFirst, ValueLast)
                                    Exit Function
                                End If
                            Else
                                If ValueFirst = ValueLast Then
                                    Call RejectProjectManifest(Failure, 1306, EntryKind, ValueFirst, ValueLast)
                                    Exit Function
                                End If
                                If EntryKind = 9 Then
                                    StartupForm = Entry
                                End If
                                If EntryKind = 10 Then
                                    If TryValidateProjectBinaryReference(Document.Bytes, ValueFirst, ValueLast, Failure) = False Then
                                        Exit Function
                                    End If
                                End If
                                If Metadata.UnsupportedKind = 0 Then
                                    Metadata.UnsupportedKind = EntryKind
                                    Metadata.UnsupportedFirst = Entry.FirstByte
                                    Metadata.UnsupportedLast = Entry.LastByte
                                End If
                            End If
                        End If
                    End If
                End If
            End If
        End If
    End If
    Failure.Code = 0
    TryApplyProjectEntry = True
End Function

' Lexical triple only; loading/linking a binary library remains unavailable.
Function TryValidateProjectBinaryReference(ByRef Bytes() As Byte, ByVal FirstByte As Long, ByVal LastByte As Long, ByRef Failure As ProjectManifestFailure) As Boolean
    TryValidateProjectBinaryReference = False
    Dim Cursor As Long = FirstByte
    Dim FirstSeparator As Long = -1
    Dim SecondSeparator As Long = -1
    While Cursor < LastByte
        If Bytes(Cursor) = 124 Then
            If FirstSeparator < 0 Then
                FirstSeparator = Cursor
            Else
                If SecondSeparator < 0 Then
                    SecondSeparator = Cursor
                Else
                    Call RejectProjectManifest(Failure, 1306, 10, FirstByte, LastByte)
                    Exit Function
                End If
            End If
        End If
        Cursor = Cursor + 1
    Wend
    If FirstSeparator <= FirstByte Or SecondSeparator <= FirstSeparator + 1 Or LastByte - SecondSeparator - 1 <> 64 Then
        Call RejectProjectManifest(Failure, 1306, 10, FirstByte, LastByte)
        Exit Function
    End If
    Dim SuffixMatches As Boolean = False
    If FirstSeparator - FirstByte >= 4 Then
        If TryMatchProjectWord(Bytes, FirstSeparator - 4, FirstSeparator, ".ubl", SuffixMatches) = False Then
            Exit Function
        End If
    End If
    If SuffixMatches = False Then
        Call RejectProjectManifest(Failure, 1306, 10, FirstByte, LastByte)
        Exit Function
    End If
    Cursor = SecondSeparator + 1
    While Cursor < LastByte
        Dim Value As Long = Bytes(Cursor)
        If (Value < 48 Or Value > 57) And (Value < 65 Or Value > 70) Then
            Call RejectProjectManifest(Failure, 1306, 10, FirstByte, LastByte)
            Exit Function
        End If
        Cursor = Cursor + 1
    Wend
    Failure.Code = 0
    TryValidateProjectBinaryReference = True
End Function
