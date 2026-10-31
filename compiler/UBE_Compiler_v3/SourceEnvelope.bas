UBE SOURCE 1 MODULE
Attribute UBE_Name = "SourceEnvelope"

' Immutable byte views; no source copies or cooked identity storage. One caller
' owns output. A failed recognition preserves the complete previous Envelope.
Type SourceEnvelope
    Format As Long
    Kind As Long
    IdentityFirst As Long
    IdentityLast As Long
    HasIdentity As Boolean
End Type

Intrinsic Function StringLength(ByVal Value As String) As Long
End Function

Function TryTakeEnvelopeWord(ByRef Bytes() As Byte, ByVal Length As Long, ByRef Cursor As Long, ByVal Expected As String, ByVal RequireSpace As Boolean, ByRef First As Long, ByRef Last As Long, ByRef Matches As Boolean) As Boolean
    TryTakeEnvelopeWord = False
    Matches = False
    Dim HadSpace As Boolean = False
    If TrySkipEnvelopeSpace(Bytes, Length, Cursor, HadSpace) = False Then
        Exit Function
    End If
    If TryEnvelopeWord(Bytes, Length, Cursor, First, Last) = False Then
        Exit Function
    End If
    If RequireSpace And HadSpace = False Then
        TryTakeEnvelopeWord = True
        Exit Function
    End If
    TryTakeEnvelopeWord = TryMatchEnvelopeWord(Bytes, First, Last, Expected, Matches)
End Function

' ExtensionKind 1 MODULE, 2 CLASS, 3 FORM, 4 CONTROL. Envelope errors 101..107
' follow SCANNER-CONTRACT labels; admission/storage is 5, domain is 7.
Function TryReadSourceEnvelope(ByRef Document As SourceDocument, ByVal ExtensionKind As Long, ByRef Envelope As SourceEnvelope, ByRef Failure As ScannerFailure) As Boolean
    TryReadSourceEnvelope = False
    Failure.Kind = 7
    Dim InitialPosition As SourcePosition
    InitialPosition.LineNumber = 1
    InitialPosition.Column = 1
    Failure.First = InitialPosition
    Failure.Last = InitialPosition
    Dim Length As Long = ByteStorageLength(Document.Bytes)
    If ExtensionKind < 1 Or ExtensionKind > 4 Or Document.ContentStart < 0 Or Document.ContentStart > Length Then
        Exit Function
    End If
    If Document.ContentStart <> 0 And Document.ContentStart <> 3 Then
        Exit Function
    End If
    If Document.ContentStart = 3 Then
        If Document.Bytes(0) <> 239 Or Document.Bytes(1) <> 187 Or Document.Bytes(2) <> 191 Then
            Exit Function
        End If
    End If
    Failure.Kind = 5
    Dim Prepared As SourceEnvelope
    Prepared.Kind = ExtensionKind
    Dim Cursor As Long = Document.ContentStart
    Dim First As Long = Cursor
    Dim Last As Long = Cursor
    Dim Matches As Boolean = False
    If TryTakeEnvelopeWord(Document.Bytes, Length, Cursor, "ube", False, First, Last, Matches) = False Then
        Exit Function
    End If
    If Matches Then
        Prepared.Format = 1
        If TryTakeEnvelopeWord(Document.Bytes, Length, Cursor, "source", True, First, Last, Matches) = False Then
            Exit Function
        End If
        If Matches = False Then
            TryReadSourceEnvelope = FailSourceEnvelope(Document, Failure, 101, First, Last)
            Exit Function
        End If
        Dim HadSpace As Boolean = False
        If TrySkipEnvelopeSpace(Document.Bytes, Length, Cursor, HadSpace) = False Then
            Exit Function
        End If
        First = Cursor
        Dim VersionValue As Long = 0
        While Cursor < Length
            If Document.Bytes(Cursor) < 48 Or Document.Bytes(Cursor) > 57 Then
                Exit While
            End If
            If VersionValue < 2 Then
                VersionValue = VersionValue * 10 + Document.Bytes(Cursor) - 48
            End If
            Cursor = Cursor + 1
        Wend
        If HadSpace = False Or Cursor = First Or VersionValue <> 1 Then
            TryReadSourceEnvelope = FailSourceEnvelope(Document, Failure, 102, First, Cursor)
            Exit Function
        End If
        If TrySkipEnvelopeSpace(Document.Bytes, Length, Cursor, HadSpace) = False Then
            Exit Function
        End If
        If TryEnvelopeWord(Document.Bytes, Length, Cursor, First, Last) = False Then
            Exit Function
        End If
        Dim Kind As Long = 0
        If TryMatchEnvelopeWord(Document.Bytes, First, Last, "module", Matches) = False Then
            Exit Function
        End If
        If Matches Then
            Kind = 1
        End If
        If TryMatchEnvelopeWord(Document.Bytes, First, Last, "class", Matches) = False Then
            Exit Function
        End If
        If Matches Then
            Kind = 2
        End If
        If TryMatchEnvelopeWord(Document.Bytes, First, Last, "form", Matches) = False Then
            Exit Function
        End If
        If Matches Then
            Kind = 3
        End If
        If TryMatchEnvelopeWord(Document.Bytes, First, Last, "control", Matches) = False Then
            Exit Function
        End If
        If Matches Then
            Kind = 4
        End If
        If HadSpace = False Or Kind <> ExtensionKind Then
            TryReadSourceEnvelope = FailSourceEnvelope(Document, Failure, 103, First, Last)
            Exit Function
        End If
        Dim Accepted As Boolean = False
        If TryEnvelopeLineEnd(Document.Bytes, Length, Cursor, Accepted) = False Then
            Exit Function
        End If
        If Accepted = False Then
            TryReadSourceEnvelope = FailSourceEnvelope(Document, Failure, 104, Cursor, Cursor)
            Exit Function
        End If
        If TryTakeEnvelopeWord(Document.Bytes, Length, Cursor, "attribute", False, First, Last, Matches) = False Then
            Exit Function
        End If
        If Matches = False Then
            TryReadSourceEnvelope = FailSourceEnvelope(Document, Failure, 104, First, Last)
            Exit Function
        End If
        If TryTakeEnvelopeWord(Document.Bytes, Length, Cursor, "ube_name", True, First, Last, Matches) = False Then
            Exit Function
        End If
        If Matches = False Then
            TryReadSourceEnvelope = FailSourceEnvelope(Document, Failure, 104, First, Last)
            Exit Function
        End If
        If TrySkipEnvelopeSpace(Document.Bytes, Length, Cursor, HadSpace) = False Then
            Exit Function
        End If
        If Cursor >= Length Then
            TryReadSourceEnvelope = FailSourceEnvelope(Document, Failure, 104, Cursor, Cursor)
            Exit Function
        End If
        If Document.Bytes(Cursor) <> 61 Then
            TryReadSourceEnvelope = FailSourceEnvelope(Document, Failure, 104, Cursor, Cursor + 1)
            Exit Function
        End If
        Cursor = Cursor + 1
        If TrySkipEnvelopeSpace(Document.Bytes, Length, Cursor, HadSpace) = False Then
            Exit Function
        End If
        Dim Valid As Boolean = False
        Dim QuotedClosed As Boolean = False
        If TryEnvelopeQuotedName(Document.Bytes, Length, Cursor, First, Last, Valid, QuotedClosed) = False Then
            Exit Function
        End If
        If Valid = False Then
            Dim NameFailure As Long = 105
            If First < Length Then
                If Document.Bytes(First) = 34 And QuotedClosed = False Then
                    NameFailure = 2
                End If
            End If
            TryReadSourceEnvelope = FailSourceEnvelope(Document, Failure, NameFailure, First, Last)
            Exit Function
        End If
        Prepared.HasIdentity = True
        Prepared.IdentityFirst = First
        Prepared.IdentityLast = Last
        If TryEnvelopeLineEnd(Document.Bytes, Length, Cursor, Accepted) = False Then
            Exit Function
        End If
        If Accepted = False Then
            TryReadSourceEnvelope = FailSourceEnvelope(Document, Failure, 105, First, Last)
            Exit Function
        End If
    Else
        Prepared.Format = 2
        Dim Legacy As Boolean = False
        If TryMatchEnvelopeWord(Document.Bytes, First, Last, "version", Matches) = False Then
            Exit Function
        End If
        Legacy = Legacy Or Matches
        If TryMatchEnvelopeWord(Document.Bytes, First, Last, "object", Matches) = False Then
            Exit Function
        End If
        Legacy = Legacy Or Matches
        If TryMatchEnvelopeWord(Document.Bytes, First, Last, "reference", Matches) = False Then
            Exit Function
        End If
        Legacy = Legacy Or Matches
        If TryMatchEnvelopeWord(Document.Bytes, First, Last, "begin", Matches) = False Then
            Exit Function
        End If
        Legacy = Legacy Or Matches
        If TryMatchEnvelopeWord(Document.Bytes, First, Last, "attribute", Matches) = False Then
            Exit Function
        End If
        Legacy = Legacy Or Matches
        If Legacy = False Then
            TryReadSourceEnvelope = FailSourceEnvelope(Document, Failure, 101, First, Last)
            Exit Function
        End If
        Cursor = Document.ContentStart
    End If
    ' Inspect remaining attribute logical lines. Other metadata remains an exact
    ' original byte view; no implicit library/COM loading or designer execution.
    While Cursor < Length
        Dim LineStart As Long = Cursor
        Dim Skip As Boolean = False
        If TrySkipEnvelopeSpace(Document.Bytes, Length, Cursor, Skip) = False Then
            Exit Function
        End If
        Dim AttributeStart As Long = Cursor
        If TryEnvelopeWord(Document.Bytes, Length, Cursor, First, Last) = False Then
            Exit Function
        End If
        If TryMatchEnvelopeWord(Document.Bytes, First, Last, "attribute", Matches) = False Then
            Exit Function
        End If
        If Matches Then
            If TrySkipEnvelopeSpace(Document.Bytes, Length, Cursor, Skip) = False Then
                Exit Function
            End If
            AttributeStart = Cursor
            Dim Parts As Long = 0
            Dim AttributeLast As Long = Cursor
            Dim ContentFirst As Long = Cursor
            Dim ContentLast As Long = Cursor
            Dim More As Boolean = True
            While More
                Dim PartValid As Boolean = False
                If TryEnvelopeAttributePart(Document.Bytes, Length, Cursor, First, Last, ContentFirst, ContentLast, PartValid) = False Then
                    Exit Function
                End If
                If PartValid = False Then
                    Exit While
                End If
                Parts = Parts + 1
                AttributeLast = Last
                More = False
                If TrySkipEnvelopeSpace(Document.Bytes, Length, Cursor, Skip) = False Then
                    Exit Function
                End If
                If Cursor < Length Then
                    If Document.Bytes(Cursor) = 46 Then
                        Cursor = Cursor + 1
                        If TrySkipEnvelopeSpace(Document.Bytes, Length, Cursor, Skip) = False Then
                            Exit Function
                        End If
                        More = True
                    End If
                End If
            Wend
            Dim IsIdentity As Boolean = False
            If TryMatchEnvelopeWord(Document.Bytes, ContentFirst, ContentLast, "ube_name", IsIdentity) = False Then
                Exit Function
            End If
            If Prepared.Format = 1 And Parts = 1 And IsIdentity Then
                TryReadSourceEnvelope = FailSourceEnvelope(Document, Failure, 106, AttributeStart, AttributeLast)
                Exit Function
            End If
            Dim Reserved As Boolean = False
            If ContentLast - ContentFirst >= 4 Then
                If TryMatchEnvelopeWord(Document.Bytes, ContentFirst, ContentFirst + 4, "ube_", Reserved) = False Then
                    Exit Function
                End If
            End If
            If Reserved Then
                Dim Known As Boolean = False
                If TryMatchEnvelopeWord(Document.Bytes, ContentFirst, ContentLast, "ube_primitive", Known) = False Then
                    Exit Function
                End If
                If Known = False Or Parts < 2 Then
                    TryReadSourceEnvelope = FailSourceEnvelope(Document, Failure, 107, AttributeStart, AttributeLast)
                    Exit Function
                End If
            End If
            If Prepared.Format = 2 And Parts = 1 And Prepared.HasIdentity = False Then
                If TryMatchEnvelopeWord(Document.Bytes, ContentFirst, ContentLast, "vb_name", IsIdentity) = False Then
                    Exit Function
                End If
                If IsIdentity Then
                    If TrySkipEnvelopeSpace(Document.Bytes, Length, Cursor, Skip) = False Then
                        Exit Function
                    End If
                    If Cursor < Length Then
                        If Document.Bytes(Cursor) = 61 Then
                            Cursor = Cursor + 1
                            If TrySkipEnvelopeSpace(Document.Bytes, Length, Cursor, Skip) = False Then
                                Exit Function
                            End If
                            Dim ValidLegacy As Boolean = False
                            Dim LegacyQuotedClosed As Boolean = False
                            If TryEnvelopeQuotedName(Document.Bytes, Length, Cursor, First, Last, ValidLegacy, LegacyQuotedClosed) = False Then
                                Exit Function
                            End If
                            If ValidLegacy Then
                                Prepared.HasIdentity = True
                                Prepared.IdentityFirst = First
                                Prepared.IdentityLast = Last
                            End If
                        End If
                    End If
                End If
            End If
        End If
        If TrySkipEnvelopeLogicalLine(Document.Bytes, Length, Cursor) = False Then
            Exit Function
        End If
        If Cursor <= LineStart Then
            Exit Function
        End If
    Wend
    Envelope = Prepared
    Failure.Kind = 0
    TryReadSourceEnvelope = True
End Function

' A qualified attribute component keeps both its complete original spelling
' and an interior view for reservation tests. Bracket escapes cannot match a
' canonical known attribute, while a leading UBE_ still remains reserved.
' Borrows Bytes, retains nothing, performs bounded iteration without allocation.
Function TryEnvelopeAttributePart(ByRef Bytes() As Byte, ByVal Length As Long, ByRef Cursor As Long, ByRef First As Long, ByRef Last As Long, ByRef ContentFirst As Long, ByRef ContentLast As Long, ByRef Valid As Boolean) As Boolean
    TryEnvelopeAttributePart = False
    Valid = False
    First = Cursor
    Last = Cursor
    ContentFirst = Cursor
    ContentLast = Cursor
    If Cursor >= Length Then
        TryEnvelopeAttributePart = True
        Exit Function
    End If
    If Bytes(Cursor) <> 91 Then
        If TryEnvelopeWord(Bytes, Length, Cursor, First, Last) = False Then
            Exit Function
        End If
        ContentFirst = First
        ContentLast = Last
        Valid = Last > First
        TryEnvelopeAttributePart = True
        Exit Function
    End If
    Cursor = Cursor + 1
    ContentFirst = Cursor
    While Cursor < Length
        Dim Value As Long = Bytes(Cursor)
        If Value = 10 Or Value = 13 Then
            Exit While
        End If
        If Value = 93 Then
            If Cursor + 1 < Length Then
                If Bytes(Cursor + 1) = 93 Then
                    Cursor = Cursor + 2
                Else
                    ContentLast = Cursor
                    Cursor = Cursor + 1
                    Last = Cursor
                    Valid = ContentLast > ContentFirst
                    TryEnvelopeAttributePart = True
                    Exit Function
                End If
            Else
                ContentLast = Cursor
                Cursor = Cursor + 1
                Last = Cursor
                Valid = ContentLast > ContentFirst
                TryEnvelopeAttributePart = True
                Exit Function
            End If
        Else
            Cursor = Cursor + 1
        End If
    Wend
    Last = Cursor
    ContentLast = Cursor
    TryEnvelopeAttributePart = True
End Function

' Seek the next logical line, shielding quoted/bracketed content and comments.
' Bytes are already strict UTF-8: non-ASCII bytes cannot contain ASCII syntax,
' so seeking needs no decoding pass. Only an actual outside-quote HSPACE + _
' continuation joins physical lines. A continued tail cannot become metadata.
Function TrySkipEnvelopeLogicalLine(ByRef Bytes() As Byte, ByVal Length As Long, ByRef Cursor As Long) As Boolean
    TrySkipEnvelopeLogicalLine = False
    Dim Delimiter As Long = 0
    While Cursor < Length
        Dim Value As Long = Bytes(Cursor)
        If Value = 10 Then
            Cursor = Cursor + 1
            TrySkipEnvelopeLogicalLine = True
            Exit Function
        End If
        If Delimiter <> 0 Then
            Cursor = Cursor + 1
            If Value = Delimiter Then
                If Cursor < Length Then
                    If Bytes(Cursor) = Delimiter Then
                        Cursor = Cursor + 1
                    Else
                        Delimiter = 0
                    End If
                Else
                    Delimiter = 0
                End If
            End If
        Else
            If Value = 34 Or Value = 91 Then
                Delimiter = 34
                If Value = 91 Then
                    Delimiter = 93
                End If
                Cursor = Cursor + 1
            Else
                If Value = 39 Then
                    While Cursor < Length
                        If Bytes(Cursor) = 10 Then
                            Exit While
                        End If
                        Cursor = Cursor + 1
                    Wend
                Else
                    If Value = 32 Or Value = 9 Then
                        Dim HadSpace As Boolean = False
                        If TrySkipEnvelopeSpace(Bytes, Length, Cursor, HadSpace) = False Then
                            Exit Function
                        End If
                    Else
                        Cursor = Cursor + 1
                    End If
                End If
            End If
        End If
    Wend
    TrySkipEnvelopeLogicalLine = True
End Function
Intrinsic Function StringByteAt(ByVal Value As String, ByVal Index As Long) As Long
End Function

' Compares source scalars with a trusted canonical ASCII word. Fresh success is
' separate from Match so managed admission failure is never a syntax mismatch.
Function TryMatchEnvelopeWord(ByRef Bytes() As Byte, ByVal First As Long, ByVal Last As Long, ByVal Word As String, ByRef Matches As Boolean) As Boolean
    TryMatchEnvelopeWord = False
    Matches = False
    Dim AtByte As Long = First
    Dim Index As Long = 0
    Dim Count As Long = StringLength(Word)
    While AtByte < Last And Index < Count
        Dim Scalar As Long = 0
        Dim ScalarWidth As Long = 0
        If TryReadSourceScalar(Bytes, AtByte, Scalar, ScalarWidth) = False Then
            Exit Function
        End If
        If SimpleFoldUnicode(Scalar) <> StringByteAt(Word, Index) Then
            TryMatchEnvelopeWord = True
            Exit Function
        End If
        AtByte = AtByte + ScalarWidth
        Index = Index + 1
    Wend
    Matches = AtByte = Last And Index = Count
    TryMatchEnvelopeWord = True
End Function

Function TryEnvelopePosition(ByRef Document As SourceDocument, ByVal Last As Long, ByRef Position As SourcePosition) As Boolean
    TryEnvelopePosition = False
    Position.ByteOffset = Document.ContentStart
    Position.ScalarOffset = 0
    Position.LineNumber = 1
    Position.Column = 1
    While Position.ByteOffset < Last
        Dim Scalar As Long = 0
        Dim ScalarWidth As Long = 0
        If TryReadSourceScalar(Document.Bytes, Position.ByteOffset, Scalar, ScalarWidth) = False Then
            Exit Function
        End If
        Position.ByteOffset = Position.ByteOffset + ScalarWidth
        Position.ScalarOffset = Position.ScalarOffset + 1
        If Scalar = 10 Then
            Position.LineNumber = Position.LineNumber + 1
            Position.Column = 1
        Else
            If Scalar <> 13 Then
                Position.Column = Position.Column + 1
            End If
        End If
    Wend
    TryEnvelopePosition = True
End Function

Function FailSourceEnvelope(ByRef Document As SourceDocument, ByRef Failure As ScannerFailure, ByVal Kind As Long, ByVal First As Long, ByVal Last As Long) As Boolean
    FailSourceEnvelope = False
    Failure.Kind = 5
    Dim Position As SourcePosition
    If First = Last And Last < ByteStorageLength(Document.Bytes) Then
        If Kind = 101 Or Kind = 104 Then
            Dim AnchorScalar As Long = 0
            Dim AnchorWidth As Long = 0
            If TryReadSourceScalar(Document.Bytes, First, AnchorScalar, AnchorWidth) = False Then
                Exit Function
            End If
            Last = Last + AnchorWidth
        End If
    End If
    If TryEnvelopePosition(Document, First, Position) = False Then
        Exit Function
    End If
    Failure.First = Position
    While Position.ByteOffset < Last
        Dim Scalar As Long = 0
        Dim ScalarWidth As Long = 0
        If TryReadSourceScalar(Document.Bytes, Position.ByteOffset, Scalar, ScalarWidth) = False Then
            Exit Function
        End If
        Position.ByteOffset = Position.ByteOffset + ScalarWidth
        Position.ScalarOffset = Position.ScalarOffset + 1
        If Scalar = 10 Then
            Position.LineNumber = Position.LineNumber + 1
            Position.Column = 1
        Else
            If Scalar <> 13 Then
                Position.Column = Position.Column + 1
            End If
        End If
    Wend
    Failure.Last = Position
    Failure.Kind = Kind
End Function

' Skip only grammar spacing, never a plain empty/comment line. Continuation is
' recognized only after horizontal space and leaves neighbor words separated.
Function TrySkipEnvelopeSpace(ByRef Bytes() As Byte, ByVal Length As Long, ByRef Cursor As Long, ByRef HadSpace As Boolean) As Boolean
    TrySkipEnvelopeSpace = False
    HadSpace = False
    Dim Continue As Boolean = True
    While Continue And Cursor < Length
        Continue = False
        Dim Before As Long = Cursor
        While Cursor < Length
            If Bytes(Cursor) <> 32 And Bytes(Cursor) <> 9 Then
                Exit While
            End If
            Cursor = Cursor + 1
        Wend
        If Cursor > Before Then
            HadSpace = True
            If Cursor < Length Then
                If Bytes(Cursor) = 95 Then
                    Dim Probe As Long = Cursor + 1
                    While Probe < Length
                        If Bytes(Probe) <> 32 And Bytes(Probe) <> 9 Then
                            Exit While
                        End If
                        Probe = Probe + 1
                    Wend
                    If Probe < Length Then
                        If Bytes(Probe) = 39 Then
                            While Probe < Length
                                If Bytes(Probe) = 10 Or Bytes(Probe) = 13 Then
                                    Exit While
                                End If
                                Probe = Probe + 1
                            Wend
                        End If
                    End If
                    If Probe < Length Then
                        If Bytes(Probe) = 13 Then
                            Probe = Probe + 1
                        End If
                        If Probe < Length Then
                            If Bytes(Probe) = 10 Then
                                Cursor = Probe + 1
                                Continue = True
                            End If
                        End If
                    End If
                End If
            End If
        End If
    Wend
    TrySkipEnvelopeSpace = True
End Function

Function TryEnvelopeWord(ByRef Bytes() As Byte, ByVal Length As Long, ByRef Cursor As Long, ByRef First As Long, ByRef Last As Long) As Boolean
    TryEnvelopeWord = False
    First = Cursor
    While Cursor < Length
        Dim Scalar As Long = 0
        Dim ScalarWidth As Long = 0
        If TryReadSourceScalar(Bytes, Cursor, Scalar, ScalarWidth) = False Then
            Exit Function
        End If
        Dim Allowed As Boolean = IsUnicodeLetter(Scalar) Or Scalar = 95
        If Cursor > First Then
            Allowed = Allowed Or (Scalar >= 48 And Scalar <= 57)
        End If
        If Allowed = False Then
            Exit While
        End If
        Cursor = Cursor + ScalarWidth
    Wend
    Last = Cursor
    TryEnvelopeWord = True
End Function

Function TryEnvelopeLineEnd(ByRef Bytes() As Byte, ByVal Length As Long, ByRef Cursor As Long, ByRef Accepted As Boolean) As Boolean
    TryEnvelopeLineEnd = False
    Accepted = False
    Dim HadSpace As Boolean = False
    If TrySkipEnvelopeSpace(Bytes, Length, Cursor, HadSpace) = False Then
        Exit Function
    End If
    If Cursor < Length Then
        If Bytes(Cursor) = 39 Then
            While Cursor < Length
                If Bytes(Cursor) = 13 Or Bytes(Cursor) = 10 Then
                    Exit While
                End If
                Cursor = Cursor + 1
            Wend
        End If
    End If
    If Cursor = Length Then
        Accepted = True
    Else
        If Bytes(Cursor) = 13 Then
            Cursor = Cursor + 1
        End If
        If Cursor < Length Then
            If Bytes(Cursor) = 10 Then
                Cursor = Cursor + 1
                Accepted = True
            End If
        End If
    End If
    TryEnvelopeLineEnd = True
End Function

Function TryEnvelopeQuotedName(ByRef Bytes() As Byte, ByVal Length As Long, ByRef Cursor As Long, ByRef First As Long, ByRef Last As Long, ByRef Valid As Boolean, ByRef QuotedClosed As Boolean) As Boolean
    TryEnvelopeQuotedName = False
    First = Cursor
    Last = Cursor
    Valid = False
    QuotedClosed = False
    If Cursor >= Length Then
        TryEnvelopeQuotedName = True
        Exit Function
    End If
    If Bytes(Cursor) <> 34 Then
        TryEnvelopeQuotedName = True
        Exit Function
    End If
    Cursor = Cursor + 1
    Dim BodyFirst As Long = Cursor
    Dim Bracketed As Boolean = False
    If Cursor < Length Then
        Bracketed = Bytes(Cursor) = 91
    End If
    Dim Count As Long = 0
    Dim WordState As Long = 0
    Dim ClosedBracket As Boolean = False
    Dim NameValid As Boolean = True
    While Cursor < Length
        Dim Scalar As Long = 0
        Dim ScalarWidth As Long = 0
        If TryReadSourceScalar(Bytes, Cursor, Scalar, ScalarWidth) = False Then
            Exit Function
        End If
        If Scalar = 10 Or Scalar = 13 Then
            Exit While
        End If
        If Scalar = 34 Then
            If Bracketed = False And ScannerWordRole(WordState) Mod 2 = 1 Then
                NameValid = False
            End If
            If Cursor + 1 < Length Then
                If Bytes(Cursor + 1) = 34 Then
                    ScalarWidth = 2
                Else
                    Last = Cursor + 1
                    QuotedClosed = True
                    Cursor = Last
                    Valid = NameValid And Count > 0 And (Bracketed = False Or ClosedBracket)
                    TryEnvelopeQuotedName = True
                    Exit Function
                End If
            Else
                Last = Cursor + 1
                QuotedClosed = True
                Cursor = Last
                Valid = NameValid And Count > 0 And (Bracketed = False Or ClosedBracket)
                TryEnvelopeQuotedName = True
                Exit Function
            End If
        End If
        If Bracketed Then
            If Cursor = BodyFirst Then
                Cursor = Cursor + ScalarWidth
            Else
                If ClosedBracket Then
                    NameValid = False
                Else
                    If Scalar = 93 Then
                        If Cursor + 1 < Length Then
                            If Bytes(Cursor + 1) = 93 Then
                                ScalarWidth = 2
                                Count = Count + 1
                            Else
                                ClosedBracket = True
                            End If
                        Else
                            ClosedBracket = True
                        End If
                    Else
                        Count = Count + 1
                    End If
                End If
                Cursor = Cursor + ScalarWidth
            End If
        Else
            WordState = ScannerWordStep(WordState, SimpleFoldUnicode(Scalar))
            Dim Allowed As Boolean = IsUnicodeLetter(Scalar) Or Scalar = 95
            If Count > 0 Then
                Allowed = Allowed Or (Scalar >= 48 And Scalar <= 57)
            End If
            NameValid = NameValid And Allowed
            Count = Count + 1
            Cursor = Cursor + ScalarWidth
        End If
    Wend
    Last = Cursor
    TryEnvelopeQuotedName = True
End Function
