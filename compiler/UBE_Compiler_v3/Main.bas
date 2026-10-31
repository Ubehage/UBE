UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Intrinsic Function CommandArgumentCount() As Long
End Function
Intrinsic Function LongToString(ByVal Value As Long) As String
End Function

' Source policy diagnostics belong to the compiler; no source bytes enter String.
Sub PrintSourceFailure(ByRef Failure As SourceFailure, ByVal FileFailure As Long)
    Dim Prefix As String = "source(" & LongToString(Failure.Position.LineNumber) & "," & LongToString(Failure.Position.Column) & "): "
    If Failure.Kind = 3 Then
        Print Prefix & "error UBE1005: invalid UTF-8 at byte " & LongToString(Failure.Position.ByteOffset)
    Else
        If Failure.Kind = 4 Then
            Print Prefix & "error UBE1006: isolated carriage return at byte " & LongToString(Failure.Position.ByteOffset)
        Else
            If Failure.Kind = 2 Then
                Print Prefix & "error UBE1000: source byte limit exceeded"
            Else
                If Failure.Kind = 5 Then
                    Print Prefix & "error UBE1007: insufficient source storage"
                Else
                    If Failure.Kind = 6 Then
                        If FileFailure = 3 Then
                            Print Prefix & "error UBE1008: cannot open source; check its path and read permissions"
                        Else
                            If FileFailure = 8 Then
                                Print Prefix & "error UBE1007: insufficient file storage"
                            Else
                                If FileFailure = 7 Then
                                    Print Prefix & "error UBE1008: could not close source file"
                                Else
                                    If FileFailure = 6 Or FileFailure = 11 Then
                                        Print Prefix & "error UBE1008: source changed while reading; retry after saving it"
                                    Else
                                        If FileFailure = 2 Then
                                            Print Prefix & "error UBE1008: source path must be nonempty UTF-8 without zeroes"
                                        Else
                                            Print Prefix & "error UBE1008: could not read source file"
                                        End If
                                    End If
                                End If
                            End If
                        End If
                    Else
                        Print Prefix & "error UBE1009: invalid source input request"
                    End If
                End If
            End If
        End If
    End If
End Sub

Function Main() As Long
    Main = 2
    If CommandArgumentCount() <> 2 Then
        Print "usage: ube --check <source-file>"
        Exit Function
    End If
    Dim OptionBytes() As Byte
    Dim ArgumentFailure As Long = 0
    If TryCommandArgument(0, OptionBytes, ArgumentFailure) = False Then
        Print "error UBE1010: cannot read command argument"
        Exit Function
    End If
    Dim CheckOption As Boolean = False
    If ByteStorageLength(OptionBytes) = 7 Then
        CheckOption = OptionBytes(0) = 45 And OptionBytes(1) = 45 And OptionBytes(2) = 99 And OptionBytes(3) = 104 And OptionBytes(4) = 101 And OptionBytes(5) = 99 And OptionBytes(6) = 107
    End If
    If CheckOption = False Then
        Print "usage: ube --check <source-file>"
        Exit Function
    End If
    Dim PathUtf8() As Byte
    If TryCommandArgument(1, PathUtf8, ArgumentFailure) = False Then
        Print "error UBE1010: cannot read command argument"
        Exit Function
    End If
    Dim Document As SourceDocument
    Dim Failure As SourceFailure
    Dim FileFailure As Long = 0
    Dim OpenToken As Long = 0
    Main = 1
    Failure.Kind = 5
    Failure.Position.LineNumber = 1
    Failure.Position.Column = 1
    If TryReadSourceFile(PathUtf8, 16777216, Document, Failure, FileFailure, OpenToken) = False Then
        Call PrintSourceFailure(Failure, FileFailure)
        If OpenToken <> 0 Then
            Dim CloseFailure As Long = 0
            If TryCloseByteFile(OpenToken, CloseFailure) = False Then
                Print "error UBE1011: could not release source file; operating system cleanup is required"
            End If
        End If
        Exit Function
    End If
    ' A pending conditional stream is outside this grammar consumer. Notice it
    ' before an inactive quote/attribute could fail whole-file scan/envelope work.
    Dim SyntaxFailure As SyntaxFailure
    SyntaxFailure.Kind = 5
    Dim PendingConditional As Boolean = False
    If TrySyntaxConditionalInput(Document, PendingConditional, SyntaxFailure) = False Then
        If TryPrintSourceSyntaxFailure(Document, SyntaxFailure) = False Then
            Call PrintSyntaxStorageFailure()
        End If
        Exit Function
    End If
    If PendingConditional Then
        If TryPrintSourceSyntaxFailure(Document, SyntaxFailure) = False Then
            Call PrintSyntaxStorageFailure()
        End If
        Exit Function
    End If
    Dim Envelope As SourceEnvelope
    Dim ScanFailure As ScannerFailure
    ScanFailure.Kind = 5
    ScanFailure.First.ByteOffset = Document.ContentStart
    ScanFailure.First.LineNumber = 1
    ScanFailure.First.Column = 1
    ScanFailure.Last = ScanFailure.First
    Dim ExtensionKind As Long = SourcePathKind(PathUtf8)
    Dim EnvelopeAccepted As Boolean = TryReadSourceEnvelope(Document, ExtensionKind, Envelope, ScanFailure)
    ' The raw scanner owns core tokens; opaque designer/legacy fragments remain
    ' exact source views for their grammar consumer, not fabricated core tokens.
    Dim LexicalFailure As ScannerFailure
    LexicalFailure.Kind = 5
    LexicalFailure.First.ByteOffset = Document.ContentStart
    LexicalFailure.First.LineNumber = 1
    LexicalFailure.First.Column = 1
    LexicalFailure.Last = LexicalFailure.First
    Dim LexicalAccepted As Boolean = True
    Dim ScanCore As Boolean = EnvelopeAccepted And Envelope.Format = 1 And Envelope.Kind = 1
    If EnvelopeAccepted = False And ScanFailure.Kind >= 100 And ExtensionKind = 1 Then
        ScanCore = True
    End If
    If ScanCore Then
        Dim Tokens() As SourceToken
        LexicalAccepted = TryScanSource(Document, 0, 1048576, Tokens, LexicalFailure)
    End If
    If LexicalAccepted = False Then
        Dim PreferLexical As Boolean = EnvelopeAccepted
        If LexicalFailure.Kind = 5 Or LexicalFailure.Kind = 6 Then
            PreferLexical = True
        End If
        If LexicalFailure.First.ByteOffset <= ScanFailure.First.ByteOffset Then
            PreferLexical = True
        End If
        If PreferLexical Then
            Call PrintScannerFailure(LexicalFailure)
            Exit Function
        End If
    End If
    If EnvelopeAccepted = False Then
        Call PrintScannerFailure(ScanFailure)
        Exit Function
    End If
    If ScanCore Then
        Dim Syntax() As SyntaxResult
        Dim SyntaxMetrics As SyntaxMetrics
        SyntaxFailure.Kind = 5
        If TryParseSyntax(Document, Tokens, 3, 0, 1048576, 1048576, 256, Syntax, SyntaxFailure, SyntaxMetrics) = False Then
            If TryPrintSourceSyntaxFailure(Document, SyntaxFailure) = False Then
                Call PrintSyntaxStorageFailure()
            End If
            Exit Function
        End If
    Else
        SyntaxFailure.Kind = 5
        If TryDeferredSyntaxEnvelope(Document, Envelope, SyntaxFailure) = False Then
            SyntaxFailure.Kind = 5
        End If
        If TryPrintSourceSyntaxFailure(Document, SyntaxFailure) = False Then
            Call PrintSyntaxStorageFailure()
        End If
        Exit Function
    End If
    Print "error UBE1012: source checking is not implemented"
End Function

' Writes a parser diagnostic without building a String. The selected header is
' an immutable literal; the next three numeric lines are original line, column
' and byte offset. Fresh False covers root admission or position preparation.
Function TryPrintSourceSyntaxFailure(ByRef Document As SourceDocument, ByRef Failure As SyntaxFailure) As Boolean
    TryPrintSourceSyntaxFailure = False
    Dim Position As SourcePosition
    Position.LineNumber = 1
    Position.Column = 1
    If TryEnvelopePosition(Document, Failure.FirstByte, Position) = False Then
        Exit Function
    End If
    Dim Header As String = "error UBE1209: invalid parser input (next lines: line, column, byte)"
    If Failure.Kind = 2 Then
        Header = "error UBE1208: parser resource limit exceeded (next lines: line, column, byte)"
    End If
    If Failure.Kind = 3 Then
        Header = "error UBE1200: source syntax family is not implemented (next lines: line, column, byte)"
    End If
    If Failure.Kind = 5 Then
        Header = "error UBE1210: insufficient syntax storage (next lines: line, column, byte)"
    End If
    If Failure.Kind = 101 Then
        Header = "error UBE1201: expected expression (next lines: line, column, byte)"
    End If
    If Failure.Kind = 102 Then
        Header = "error UBE1202: expected token (next lines: line, column, byte)"
    End If
    If Failure.Kind = 103 Then
        Header = "error UBE1203: unexpected token (next lines: line, column, byte)"
    End If
    If Failure.Kind = 104 Then
        Header = "error UBE1204: expected identifier (next lines: line, column, byte)"
    End If
    If Failure.Kind = 105 Then
        Header = "error UBE1205: invalid call syntax (next lines: line, column, byte)"
    End If
    If Failure.Kind = 106 Then
        Header = "error UBE1206: unterminated block (next lines: line, column, byte)"
    End If
    If Failure.Kind = 107 Then
        Header = "error UBE1207: unexpected terminator (next lines: line, column, byte)"
    End If
    Print Header
    Print Position.LineNumber
    Print Position.Column
    Print Failure.FirstByte
    TryPrintSourceSyntaxFailure = True
End Function

' Rootless static fallback also works when a formatter cannot enter managed code.
Sub PrintSyntaxStorageFailure()
    Print "error UBE1210: insufficient syntax storage"
End Sub


Function SourcePathKind(ByRef PathUtf8() As Byte) As Long
    SourcePathKind = 0
    Dim Length As Long = ByteStorageLength(PathUtf8)
    If Length < 4 Then
        Exit Function
    End If
    If PathUtf8(Length - 4) <> 46 Then
        Exit Function
    End If
    Dim First As Long = PathUtf8(Length - 3)
    Dim Second As Long = PathUtf8(Length - 2)
    Dim Third As Long = PathUtf8(Length - 1)
    If First >= 65 And First <= 90 Then
        First = First + 32
    End If
    If Second >= 65 And Second <= 90 Then
        Second = Second + 32
    End If
    If Third >= 65 And Third <= 90 Then
        Third = Third + 32
    End If
    If First = 98 And Second = 97 And Third = 115 Then
        SourcePathKind = 1
    End If
    If First = 99 And Second = 108 And Third = 115 Then
        SourcePathKind = 2
    End If
    If First = 102 And Second = 114 And Third = 109 Then
        SourcePathKind = 3
    End If
    If First = 99 And Second = 116 And Third = 108 Then
        SourcePathKind = 4
    End If
End Function

Sub PrintScannerFailure(ByRef Failure As ScannerFailure)
    Dim Prefix As String = "source(" & LongToString(Failure.First.LineNumber) & "," & LongToString(Failure.First.Column) & "): "
    Dim Message As String = "invalid source request"
    If Failure.Kind = 1 Then
        Message = "unexpected character"
    End If
    If Failure.Kind = 2 Then
        Message = "unterminated string"
    End If
    If Failure.Kind = 3 Then
        Message = "unterminated bracketed identifier"
    End If
    If Failure.Kind = 4 Then
        Message = "empty bracketed identifier"
    End If
    If Failure.Kind = 5 Then
        Message = "insufficient scanner storage"
    End If
    If Failure.Kind = 6 Then
        Message = "scanner record limit exceeded"
    End If
    If Failure.Kind = 101 Then
        Message = "missing source header"
    End If
    If Failure.Kind = 102 Then
        Message = "unsupported source format version"
    End If
    If Failure.Kind = 103 Then
        Message = "source kind does not match the file extension"
    End If
    If Failure.Kind = 104 Then
        Message = "missing source identity"
    End If
    If Failure.Kind = 105 Then
        Message = "invalid source identity"
    End If
    If Failure.Kind = 106 Then
        Message = "duplicate source identity"
    End If
    If Failure.Kind = 107 Then
        Message = "unknown reserved source attribute"
    End If
    Print Prefix & "error UBE1100: " & Message & " at byte " & LongToString(Failure.First.ByteOffset)
End Sub
