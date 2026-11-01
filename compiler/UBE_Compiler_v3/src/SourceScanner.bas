UBE SOURCE 1 MODULE
Attribute UBE_Name = "SourceScanner"

' Raw source policy over a borrowed immutable qualified SourceDocument. Spans
' own no roots: the document owner keeps Bytes alive while consumers use them.
' Each invocation owns its cursor and private arrays. Independent invocations
' may share the document; no mutable global state, recursion or source copying.
Type SourceToken
    Kind As Long
    First As SourcePosition
    Last As SourcePosition
End Type

Type ScannerFailure
    Kind As Long
    First As SourcePosition
    Last As SourcePosition
End Type

Intrinsic Function ScannerTokenLength(ByRef Values() As SourceToken) As Long
    Attribute ScannerTokenLength.UBE_Primitive = "Array.Length"
End Function

Intrinsic Function TryResizeScannerTokens(ByRef Values() As SourceToken, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
    Attribute TryResizeScannerTokens.UBE_Primitive = "Array.TryResize"
End Function

Intrinsic Function TryCopyScannerTokens(ByRef Destination() As SourceToken, ByRef Source() As SourceToken) As Boolean
    Attribute TryCopyScannerTokens.UBE_Primitive = "Array.TryCopy"
End Function

' One rootless record copy, also the narrow observation boundary used by the
' native cost gate. It retains neither input and allocates no storage.
Sub CopyScannerToken(ByRef Destination As SourceToken, ByRef Original As SourceToken)
    Destination = Original
End Sub

' Fresh status is separate from the byte: managed root admission can return
' neutral False before this body. -1 denotes an absent byte only on success;
' zero remains an actual source byte. ByteCount is the borrowed snapshot size.
Function TryScannerByte(ByRef Bytes() As Byte, ByVal ByteCount As Long, ByVal Offset As Long, ByRef Value As Long) As Boolean
    TryScannerByte = False
    Value = -1
    If Offset >= 0 And Offset < ByteCount Then
        Value = Bytes(Offset)
    End If
    TryScannerByte = True
End Function

Function ScannerDigit(ByVal Value As Long) As Boolean
    ScannerDigit = Value >= 48 And Value <= 57
End Function

Function ScannerHSpace(ByVal Value As Long) As Boolean
    ScannerHSpace = Value = 32 Or Value = 9
End Function

Function ScannerIntegerSuffix(ByVal Value As Long) As Boolean
    ScannerIntegerSuffix = Value = 37 Or Value = 38 Or Value = 94
End Function

Function ScannerRealSuffix(ByVal Value As Long) As Boolean
    ScannerRealSuffix = Value = 33 Or Value = 35 Or Value = 64 Or Value = 70 Or Value = 102 Or Value = 82 Or Value = 114 Or Value = 68 Or Value = 100
End Function

' Advance exactly one decoded scalar. CRLF is two scalars and one line;
' the initial BOM is handled separately because it has no content scalar.
Sub ScannerAdvance(ByRef Cursor As SourcePosition, ByVal Scalar As Long, ByVal ScalarWidth As Long)
    Cursor.ByteOffset = Cursor.ByteOffset + ScalarWidth
    Cursor.ScalarOffset = Cursor.ScalarOffset + 1
    If Scalar = 10 Then
        Cursor.LineNumber = Cursor.LineNumber + 1
        Cursor.Column = 1
    Else
        If Scalar <> 13 Then
            Cursor.Column = Cursor.Column + 1
        End If
    End If
End Sub

Sub ScannerAdvanceAscii(ByRef Cursor As SourcePosition, ByVal Count As Long)
    Cursor.ByteOffset = Cursor.ByteOffset + Count
    Cursor.ScalarOffset = Cursor.ScalarOffset + Count
    Cursor.Column = Cursor.Column + Count
End Sub

' Starts at eight records and doubles. No whole-array value copy on append.
' The explicit maximum includes physical trivia and the two synthetic records.
Function ScannerAppendToken(ByRef Pending() As SourceToken, ByRef Count As Long, ByVal MaximumRecords As Long, ByVal Kind As Long, ByRef First As SourcePosition, ByRef Last As SourcePosition, ByRef Failure As ScannerFailure) As Boolean
    ScannerAppendToken = False
    Failure.Kind = 5
    Failure.First = First
    Failure.Last = Last
    If Count >= MaximumRecords Then
        Failure.Kind = 6
        Exit Function
    End If
    Dim Capacity As Long = ScannerTokenLength(Pending)
    If Count = Capacity Then
        Dim NewCapacity As Long = 8
        If Capacity > 0 Then
            If Capacity > 1073741823 Then
                NewCapacity = MaximumRecords
            Else
                NewCapacity = Capacity * 2
            End If
        End If
        If NewCapacity > MaximumRecords Then
            NewCapacity = MaximumRecords
        End If
        If TryResizeScannerTokens(Pending, NewCapacity, True) = False Then
            Exit Function
        End If
    End If
    Pending(Count).Kind = Kind
    Pending(Count).First = First
    Pending(Count).Last = Last
    Count = Count + 1
    ScannerAppendToken = True
End Function

' Exponent lookahead commits only when the exponent contains an ASCII digit.
' False is a fresh managed failure; successful nonmatch returns Offset.
Function TryScannerExponentEnd(ByRef Bytes() As Byte, ByVal ByteCount As Long, ByVal Offset As Long, ByRef EndOffset As Long) As Boolean
    TryScannerExponentEnd = False
    EndOffset = Offset
    Dim Value As Long = -1
    If TryScannerByte(Bytes, ByteCount, Offset, Value) = False Then
        Exit Function
    End If
    If Value <> 69 And Value <> 101 And Value <> 68 And Value <> 100 Then
        TryScannerExponentEnd = True
        Exit Function
    End If
    Dim Probe As Long = Offset + 1
    If TryScannerByte(Bytes, ByteCount, Probe, Value) = False Then
        Exit Function
    End If
    If Value = 43 Or Value = 45 Then
        Probe = Probe + 1
        If TryScannerByte(Bytes, ByteCount, Probe, Value) = False Then
            Exit Function
        End If
    End If
    If ScannerDigit(Value) = False Then
        TryScannerExponentEnd = True
        Exit Function
    End If
    While ScannerDigit(Value)
        Probe = Probe + 1
        If TryScannerByte(Bytes, ByteCount, Probe, Value) = False Then
            Exit Function
        End If
    Wend
    EndOffset = Probe
    TryScannerExponentEnd = True
End Function

' Longest valid numeric spelling, with separate signs and no value conversion.
' False never represents a successful nonmatch. No root-neutral scalar return
' can masquerade as an end offset, punctuation or a byte of source content.
Function TryScannerNumberEnd(ByRef Bytes() As Byte, ByVal ByteCount As Long, ByVal Offset As Long, ByRef Kind As Long, ByRef EndOffset As Long) As Boolean
    TryScannerNumberEnd = False
    EndOffset = Offset
    Kind = 3
    Dim Probe As Long = Offset
    Dim Value As Long = -1
    If TryScannerByte(Bytes, ByteCount, Probe, Value) = False Then
        Exit Function
    End If
    If Value = 38 Then
        Dim Radix As Long = -1
        If TryScannerByte(Bytes, ByteCount, Probe + 1, Radix) = False Then
            Exit Function
        End If
        Dim Base As Long = 0
        If Radix = 72 Or Radix = 104 Then
            Base = 16
        End If
        If Radix = 79 Or Radix = 111 Then
            Base = 8
        End If
        If Base = 0 Then
            TryScannerNumberEnd = True
            Exit Function
        End If
        Probe = Probe + 2
        Dim DigitsStart As Long = Probe
        Dim More As Boolean = True
        While More
            If TryScannerByte(Bytes, ByteCount, Probe, Value) = False Then
                Exit Function
            End If
            More = False
            If Base = 8 Then
                More = Value >= 48 And Value <= 55
            Else
                More = ScannerDigit(Value) Or (Value >= 65 And Value <= 70) Or (Value >= 97 And Value <= 102)
            End If
            If More Then
                Probe = Probe + 1
            End If
        Wend
        If Probe = DigitsStart Then
            TryScannerNumberEnd = True
            Exit Function
        End If
        If ScannerIntegerSuffix(Value) Then
            Probe = Probe + 1
        End If
        EndOffset = Probe
        TryScannerNumberEnd = True
        Exit Function
    End If
    While ScannerDigit(Value)
        Probe = Probe + 1
        If TryScannerByte(Bytes, ByteCount, Probe, Value) = False Then
            Exit Function
        End If
    Wend
    Dim HadDigits As Boolean = Probe > Offset
    If Value = 46 Then
        Dim Following As Long = -1
        If TryScannerByte(Bytes, ByteCount, Probe + 1, Following) = False Then
            Exit Function
        End If
        If HadDigits Or ScannerDigit(Following) Then
            Kind = 4
            Probe = Probe + 1
            Value = Following
            While ScannerDigit(Value)
                Probe = Probe + 1
                If TryScannerByte(Bytes, ByteCount, Probe, Value) = False Then
                    Exit Function
                End If
            Wend
        End If
    End If
    If HadDigits = False And Kind <> 4 Then
        TryScannerNumberEnd = True
        Exit Function
    End If
    Dim ExponentEnd As Long = Probe
    If TryScannerExponentEnd(Bytes, ByteCount, Probe, ExponentEnd) = False Then
        Exit Function
    End If
    If ExponentEnd > Probe Then
        Kind = 4
        Probe = ExponentEnd
    End If
    If TryScannerByte(Bytes, ByteCount, Probe, Value) = False Then
        Exit Function
    End If
    If Kind = 4 Then
        If ScannerRealSuffix(Value) Then
            Probe = Probe + 1
        End If
    Else
        If ScannerIntegerSuffix(Value) Then
            Probe = Probe + 1
        End If
    End If
    EndOffset = Probe
    TryScannerNumberEnd = True
End Function

' Successful nonmatch leaves Cursor untouched; False propagates storage/root
' failure separately. Probe work is bounded and allocates no source storage.
Function TryScannerContinuation(ByRef Bytes() As Byte, ByVal ByteCount As Long, ByRef Cursor As SourcePosition, ByRef Matches As Boolean) As Boolean
    TryScannerContinuation = False
    Matches = False
    Dim Value As Long = -1
    If TryScannerByte(Bytes, ByteCount, Cursor.ByteOffset, Value) = False Then
        Exit Function
    End If
    If Value <> 95 Then
        TryScannerContinuation = True
        Exit Function
    End If
    Dim Probe As SourcePosition = Cursor
    Call ScannerAdvanceAscii(Probe, 1)
    If TryScannerByte(Bytes, ByteCount, Probe.ByteOffset, Value) = False Then
        Exit Function
    End If
    While ScannerHSpace(Value)
        Call ScannerAdvanceAscii(Probe, 1)
        If TryScannerByte(Bytes, ByteCount, Probe.ByteOffset, Value) = False Then
            Exit Function
        End If
    Wend
    If Value = 39 Then
        While Value <> -1 And Value <> 10 And Value <> 13
            Dim Scalar As Long = 0
            Dim ScalarWidth As Long = 0
            If TryReadSourceScalar(Bytes, Probe.ByteOffset, Scalar, ScalarWidth) = False Then
                Exit Function
            End If
            Call ScannerAdvance(Probe, Scalar, ScalarWidth)
            If TryScannerByte(Bytes, ByteCount, Probe.ByteOffset, Value) = False Then
                Exit Function
            End If
        Wend
    End If
    If Value = 13 Then
        Dim NextByte As Long = -1
        If TryScannerByte(Bytes, ByteCount, Probe.ByteOffset + 1, NextByte) = False Then
            Exit Function
        End If
        If NextByte <> 10 Then
            TryScannerContinuation = True
            Exit Function
        End If
        Call ScannerAdvance(Probe, 13, 1)
        Call ScannerAdvance(Probe, 10, 1)
    Else
        If Value <> 10 Then
            TryScannerContinuation = True
            Exit Function
        End If
        Call ScannerAdvance(Probe, 10, 1)
    End If
    If TryScannerByte(Bytes, ByteCount, Probe.ByteOffset, Value) = False Then
        Exit Function
    End If
    While ScannerHSpace(Value)
        Call ScannerAdvanceAscii(Probe, 1)
        If TryScannerByte(Bytes, ByteCount, Probe.ByteOffset, Value) = False Then
            Exit Function
        End If
    Wend
    Cursor = Probe
    Matches = True
    TryScannerContinuation = True
End Function

' Context is a grammar witness: 0 ordinary, 1 expression/date, 2 file-number,
' 3 statement. Contextual words stay names. MaximumRecords is explicit, with
' the initial consumer selecting 1048576. Failure preserves all old Tokens.
' Caller initializes Failure.Kind=5 before this managed entry: root admission
' may return neutral False before this body. Domain success preserves Err.
Function TryScanSource(ByRef Document As SourceDocument, ByVal Context As Long, ByVal MaximumRecords As Long, ByRef Tokens() As SourceToken, ByRef Failure As ScannerFailure) As Boolean
    TryScanSource = False
    Dim Cursor As SourcePosition
    Cursor.LineNumber = 1
    Cursor.Column = 1
    Failure.Kind = 7
    Failure.First = Cursor
    Failure.Last = Cursor
    Dim ByteCount As Long = ByteStorageLength(Document.Bytes)
    If Context < 0 Or Context > 3 Or MaximumRecords < 1 Or ByteCount > 16777216 Then
        Exit Function
    End If
    If Document.ContentStart <> 0 And Document.ContentStart <> 3 Then
        Exit Function
    End If
    If Document.ContentStart > ByteCount Then
        Exit Function
    End If
    Failure.Kind = 5
    Dim Pending() As SourceToken
    Dim Count As Long = 0
    Dim LastKind As Long = 0
    Dim StatementStart As Boolean = Context <> 1
    Dim AfterMember As Boolean = False
    Dim Parentheses As Long = 0
    Dim First As SourcePosition = Cursor
    Dim Lookahead As Long = -1
    If Document.ContentStart = 3 Then
        If TryScannerByte(Document.Bytes, ByteCount, 0, Lookahead) = False Then
            Exit Function
        End If
        If Lookahead <> 239 Then
            Failure.Kind = 7
            Exit Function
        End If
        If TryScannerByte(Document.Bytes, ByteCount, 1, Lookahead) = False Then
            Exit Function
        End If
        If Lookahead <> 187 Then
            Failure.Kind = 7
            Exit Function
        End If
        If TryScannerByte(Document.Bytes, ByteCount, 2, Lookahead) = False Then
            Exit Function
        End If
        If Lookahead <> 191 Then
            Failure.Kind = 7
            Exit Function
        End If
        Cursor.ByteOffset = 3
        If ScannerAppendToken(Pending, Count, MaximumRecords, 12, First, Cursor, Failure) = False Then
            Exit Function
        End If
        LastKind = 12
    End If
    While Cursor.ByteOffset < ByteCount
        First = Cursor
        Dim Scalar As Long = 0
        Dim ScalarWidth As Long = 0
        Failure.Kind = 5
        Failure.First = First
        Failure.Last = First
        If TryReadSourceScalar(Document.Bytes, Cursor.ByteOffset, Scalar, ScalarWidth) = False Then
            ' Qualified snapshots already prove UTF-8 validity. A fresh False
            ' here is managed admission/storage failure, never a source NUL.
            Exit Function
        End If
        Dim Kind As Long = 0
        If ScannerHSpace(Scalar) Then
            Kind = 8
            Lookahead = Scalar
            While ScannerHSpace(Lookahead)
                Call ScannerAdvanceAscii(Cursor, 1)
                If TryScannerByte(Document.Bytes, ByteCount, Cursor.ByteOffset, Lookahead) = False Then
                    Exit Function
                End If
            Wend
            Dim Continued As SourcePosition = Cursor
            Dim HasContinuation As Boolean = False
            If TryScannerContinuation(Document.Bytes, ByteCount, Continued, HasContinuation) = False Then
                Exit Function
            End If
            If HasContinuation Then
                Cursor = Continued
                Kind = 11
            End If
        Else
            If Scalar = 10 Or Scalar = 13 Then
                Kind = 13
                If Scalar = 13 Then
                    If TryScannerByte(Document.Bytes, ByteCount, Cursor.ByteOffset + 1, Lookahead) = False Then
                        Exit Function
                    End If
                    If Lookahead <> 10 Then
                        Failure.Kind = 1
                        Call ScannerAdvance(Cursor, Scalar, ScalarWidth)
                        Failure.Last = Cursor
                        Exit Function
                    End If
                    Call ScannerAdvance(Cursor, 13, 1)
                End If
                Call ScannerAdvance(Cursor, 10, 1)
                StatementStart = True
                AfterMember = False
                Parentheses = 0
            Else
                If Scalar = 34 Or Scalar = 91 Then
                    Dim Delimiter As Long = 34
                    Kind = 5
                    If Scalar = 91 Then
                        Delimiter = 93
                        Kind = 6
                    End If
                    Call ScannerAdvance(Cursor, Scalar, ScalarWidth)
                    Dim Closed As Boolean = False
                    Dim ContentCount As Long = 0
                    While Cursor.ByteOffset < ByteCount And Closed = False
                        Scalar = 0
                        ScalarWidth = 0
                        If TryReadSourceScalar(Document.Bytes, Cursor.ByteOffset, Scalar, ScalarWidth) = False Then
                            Exit Function
                        End If
                        If Scalar = 10 Or Scalar = 13 Then
                            Exit While
                        End If
                        Call ScannerAdvance(Cursor, Scalar, ScalarWidth)
                        If Scalar = Delimiter Then
                            If TryScannerByte(Document.Bytes, ByteCount, Cursor.ByteOffset, Lookahead) = False Then
                                Exit Function
                            End If
                            If Lookahead = Delimiter Then
                                Call ScannerAdvanceAscii(Cursor, 1)
                                ContentCount = ContentCount + 1
                            Else
                                Closed = True
                            End If
                        Else
                            ContentCount = ContentCount + 1
                        End If
                    Wend
                    If Closed = False Then
                        Failure.Kind = 2
                        If Kind = 6 Then
                            Failure.Kind = 3
                        End If
                        Failure.Last = Cursor
                        Exit Function
                    End If
                    If Kind = 6 And ContentCount = 0 Then
                        Failure.Kind = 4
                        Failure.Last = Cursor
                        Exit Function
                    End If
                    StatementStart = False
                    AfterMember = False
                Else
                    If Scalar = 39 Then
                        Kind = 9
                        While Cursor.ByteOffset < ByteCount
                            If TryReadSourceScalar(Document.Bytes, Cursor.ByteOffset, Scalar, ScalarWidth) = False Then
                                Exit Function
                            End If
                            If Scalar = 10 Or Scalar = 13 Then
                                Exit While
                            End If
                            Call ScannerAdvance(Cursor, Scalar, ScalarWidth)
                        Wend
                    Else
                        If Scalar = 95 Or IsUnicodeLetter(Scalar) Then
                            Kind = 1
                            Dim WordState As Long = 0
                            Dim NameCount As Long = 0
                            Dim RemMatch As Boolean = True
                            While Cursor.ByteOffset < ByteCount
                                If TryReadSourceScalar(Document.Bytes, Cursor.ByteOffset, Scalar, ScalarWidth) = False Then
                                    Exit Function
                                End If
                                If Scalar <> 95 And ScannerDigit(Scalar) = False And IsUnicodeLetter(Scalar) = False Then
                                    Exit While
                                End If
                                Dim Folded As Long = SimpleFoldUnicode(Scalar)
                                WordState = ScannerWordStep(WordState, Folded)
                                If NameCount = 0 And Folded <> 114 Then
                                    RemMatch = False
                                End If
                                If NameCount = 1 And Folded <> 101 Then
                                    RemMatch = False
                                End If
                                If NameCount = 2 And Folded <> 109 Then
                                    RemMatch = False
                                End If
                                NameCount = NameCount + 1
                                Call ScannerAdvance(Cursor, Scalar, ScalarWidth)
                            Wend
                            Dim Role As Long = ScannerWordRole(WordState)
                            If Role = 1 Or Role = 5 Then
                                Kind = 2
                            End If
                            Dim Following As Long = -1
                            If TryScannerByte(Document.Bytes, ByteCount, Cursor.ByteOffset, Following) = False Then
                                Exit Function
                            End If
                            If RemMatch And NameCount = 3 And StatementStart And Parentheses = 0 Then
                                If ScannerHSpace(Following) Or Following = 10 Or Following = 13 Or Following = -1 Then
                                    Kind = 10
                                    While Cursor.ByteOffset < ByteCount
                                        If TryReadSourceScalar(Document.Bytes, Cursor.ByteOffset, Scalar, ScalarWidth) = False Then
                                            Exit Function
                                        End If
                                        If Scalar = 10 Or Scalar = 13 Then
                                            Exit While
                                        End If
                                        Call ScannerAdvance(Cursor, Scalar, ScalarWidth)
                                    Wend
                                End If
                            End If
                            StatementStart = False
                            If AfterMember = False And Parentheses = 0 Then
                                StatementStart = ScannerWordStartsStatement(WordState)
                            End If
                            AfterMember = False
                        Else
                            Dim NumberKind As Long = 3
                            Dim NumberEnd As Long = Cursor.ByteOffset
                            If ScannerDigit(Scalar) Or Scalar = 46 Or Scalar = 38 Then
                                If TryScannerNumberEnd(Document.Bytes, ByteCount, Cursor.ByteOffset, NumberKind, NumberEnd) = False Then
                                    Exit Function
                                End If
                            End If
                            If NumberEnd > Cursor.ByteOffset Then
                                Kind = NumberKind
                                Call ScannerAdvanceAscii(Cursor, NumberEnd - Cursor.ByteOffset)
                                StatementStart = False
                                AfterMember = False
                            Else
                                If Scalar = 35 And Context = 1 Then
                                    Dim DateEnd As SourcePosition = Cursor
                                    Call ScannerAdvanceAscii(DateEnd, 1)
                                    Dim Paired As Boolean = False
                                    While DateEnd.ByteOffset < ByteCount And Paired = False
                                        If TryReadSourceScalar(Document.Bytes, DateEnd.ByteOffset, Scalar, ScalarWidth) = False Then
                                            Exit Function
                                        End If
                                        If Scalar = 10 Or Scalar = 13 Then
                                            Exit While
                                        End If
                                        Call ScannerAdvance(DateEnd, Scalar, ScalarWidth)
                                        If Scalar = 35 Then
                                            Paired = True
                                        End If
                                    Wend
                                    Kind = 7
                                    If Paired Then
                                        Kind = 14
                                        Cursor = DateEnd
                                    Else
                                        Call ScannerAdvanceAscii(Cursor, 1)
                                    End If
                                    StatementStart = False
                                    AfterMember = False
                                Else
                                    Kind = 7
                                    Dim Symbol As Boolean = False
                                    If Scalar = 33 Or Scalar = 35 Or Scalar = 36 Or Scalar = 37 Or Scalar = 38 Or Scalar = 40 Or Scalar = 41 Or Scalar = 42 Or Scalar = 43 Or Scalar = 44 Or Scalar = 45 Or Scalar = 46 Or Scalar = 47 Or Scalar = 58 Or Scalar = 59 Or Scalar = 60 Or Scalar = 61 Or Scalar = 62 Or Scalar = 64 Or Scalar = 92 Or Scalar = 94 Then
                                        Symbol = True
                                    End If
                                    If Symbol = False Then
                                        Failure.Kind = 1
                                        Call ScannerAdvance(Cursor, Scalar, ScalarWidth)
                                        Failure.Last = Cursor
                                        Exit Function
                                    End If
                                    Dim NextByte As Long = -1
                                    If TryScannerByte(Document.Bytes, ByteCount, Cursor.ByteOffset + 1, NextByte) = False Then
                                        Exit Function
                                    End If
                                    Call ScannerAdvanceAscii(Cursor, 1)
                                    AfterMember = Scalar = 46 Or Scalar = 33
                                    If (Scalar = 58 And NextByte = 61) Or (Scalar = 60 And (NextByte = 61 Or NextByte = 62)) Or (Scalar = 62 And NextByte = 61) Then
                                        Call ScannerAdvanceAscii(Cursor, 1)
                                        StatementStart = False
                                    Else
                                        If Scalar = 58 And Parentheses = 0 Then
                                            StatementStart = True
                                        Else
                                            StatementStart = False
                                            If Scalar = 40 Then
                                                Parentheses = Parentheses + 1
                                            End If
                                            If Scalar = 41 And Parentheses > 0 Then
                                                Parentheses = Parentheses - 1
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
        If Cursor.ByteOffset <= First.ByteOffset Then
            Exit Function
        End If
        If ScannerAppendToken(Pending, Count, MaximumRecords, Kind, First, Cursor, Failure) = False Then
            Exit Function
        End If
        LastKind = Kind
    Wend
    If LastKind <> 13 Then
        If ScannerAppendToken(Pending, Count, MaximumRecords, 13, Cursor, Cursor, Failure) = False Then
            Exit Function
        End If
    End If
    If ScannerAppendToken(Pending, Count, MaximumRecords, 15, Cursor, Cursor, Failure) = False Then
        Exit Function
    End If
    ' Exact-sized publication costs two bounded record copies and two managed
    ' arrays; failed preparation or final TryCopy leaves old Tokens intact.
    Failure.Kind = 5
    Failure.First = Cursor
    Failure.Last = Cursor
    Dim Prepared() As SourceToken
    If TryResizeScannerTokens(Prepared, Count, False) = False Then
        Exit Function
    End If
    Dim Index As Long = 0
    While Index < Count
        Call CopyScannerToken(Prepared(Index), Pending(Index))
        Index = Index + 1
    Wend
    If TryCopyScannerTokens(Tokens, Prepared) = False Then
        Exit Function
    End If
    Failure.Kind = 0
    TryScanSource = True
End Function
