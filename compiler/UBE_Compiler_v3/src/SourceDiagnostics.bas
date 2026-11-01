UBE SOURCE 1 MODULE
Attribute UBE_Name = "SourceDiagnostics"

' Rootless checked decimal-size calculation; diagnostic positions are nonnegative.
Function DiagnosticDecimalLength(ByVal Value As Long) As Long
    DiagnosticDecimalLength = 1
    While Value >= 10
        Value = Value \ 10
        DiagnosticDecimalLength = DiagnosticDecimalLength + 1
    Wend
End Function

' Every allocating piece is validated before one join and final replacement.
Function TryFormatSourceDiagnosticLine(ByRef Position As SourcePosition, ByVal Lead As String, ByVal Message As String, ByVal IncludeByte As Boolean, ByRef Published As String) As Boolean
    TryFormatSourceDiagnosticLine = False
    If Position.LineNumber < 1 Or Position.Column < 1 Or Position.ByteOffset < 0 Then
        Exit Function
    End If
    Dim Pieces() As String
    If TryResizeProjectDisplayPieces(Pieces, 9, False) = False Then
        Exit Function
    End If
    Pieces(0) = "source("
    Pieces(1) = LongToString(Position.LineNumber)
    If StringLength(Pieces(1)) <> DiagnosticDecimalLength(Position.LineNumber) Then
        Exit Function
    End If
    Pieces(2) = ","
    Pieces(3) = LongToString(Position.Column)
    If StringLength(Pieces(3)) <> DiagnosticDecimalLength(Position.Column) Then
        Exit Function
    End If
    Pieces(4) = "): "
    Pieces(5) = Lead
    Pieces(6) = Message
    If IncludeByte Then
        Pieces(7) = " at byte "
        Pieces(8) = LongToString(Position.ByteOffset)
        If StringLength(Pieces(8)) <> DiagnosticDecimalLength(Position.ByteOffset) Then
            Exit Function
        End If
    End If
    Dim Expected As Long = 0
    Dim Index As Long = 0
    While Index < 9
        Expected = Expected + StringLength(Pieces(Index))
        Index = Index + 1
    Wend
    Dim Prepared As String = StringArrayJoin(Pieces, 9)
    If StringLength(Prepared) <> Expected Then
        Exit Function
    End If
    Published = Prepared
    TryFormatSourceDiagnosticLine = True
End Function

Function TryFormatSourceInputFailure(ByRef Failure As SourceFailure, ByVal FileFailure As Long, ByRef Published As String) As Boolean
    TryFormatSourceInputFailure = False
    Dim Tail As String = SourceInputDiagnosticTail(Failure.Kind, FileFailure)
    TryFormatSourceInputFailure = TryFormatSourceDiagnosticLine(Failure.Position, Tail, "", Failure.Kind = 3 Or Failure.Kind = 4, Published)
End Function

Function TryFormatSourceScannerFailure(ByRef Failure As ScannerFailure, ByRef Published As String) As Boolean
    TryFormatSourceScannerFailure = False
    Dim Message As String = SourceScannerMessage(Failure.Kind)
    TryFormatSourceScannerFailure = TryFormatSourceDiagnosticLine(Failure.First, "error UBE1100: ", Message, True, Published)
End Function

Sub PrintSourceFailure(ByRef Failure As SourceFailure, ByVal FileFailure As Long)
    Dim Prepared As String
    If TryFormatSourceInputFailure(Failure, FileFailure, Prepared) Then
        Print Prepared
    Else
        Print "error UBE1007: insufficient source storage"
    End If
End Sub

Sub PrintScannerFailure(ByRef Failure As ScannerFailure)
    Dim Prepared As String
    If TryFormatSourceScannerFailure(Failure, Prepared) Then
        Print Prepared
    Else
        Print "error UBE1100: insufficient scanner storage"
    End If
End Sub

' Shared source diagnostic wording and complete preparation; no source String conversion.

Function SourceInputDiagnosticTail(ByVal Kind As Long, ByVal FileFailure As Long) As String
    If Kind = 3 Then
        SourceInputDiagnosticTail = "error UBE1005: invalid UTF-8"
    Else
        If Kind = 4 Then
            SourceInputDiagnosticTail = "error UBE1006: isolated carriage return"
        Else
            If Kind = 2 Then
                SourceInputDiagnosticTail = "error UBE1000: source byte limit exceeded"
            Else
                If Kind = 5 Then
                    SourceInputDiagnosticTail = "error UBE1007: insufficient source storage"
                Else
                    If Kind = 6 Then
                        If FileFailure = 3 Then
                            SourceInputDiagnosticTail = "error UBE1008: cannot open source; check its path and read permissions"
                        Else
                            If FileFailure = 8 Then
                                SourceInputDiagnosticTail = "error UBE1007: insufficient file storage"
                            Else
                                If FileFailure = 7 Then
                                    SourceInputDiagnosticTail = "error UBE1008: could not close source file"
                                Else
                                    If FileFailure = 6 Or FileFailure = 11 Then
                                        SourceInputDiagnosticTail = "error UBE1008: source changed while reading; retry after saving it"
                                    Else
                                        If FileFailure = 2 Then
                                            SourceInputDiagnosticTail = "error UBE1008: source path must be nonempty UTF-8 without zeroes"
                                        Else
                                            SourceInputDiagnosticTail = "error UBE1008: could not read source file"
                                        End If
                                    End If
                                End If
                            End If
                        End If
                    Else
                        SourceInputDiagnosticTail = "error UBE1009: invalid source input request"
                    End If
                End If
            End If
        End If
    End If
End Function

Function SourceSyntaxHeader(ByVal Kind As Long) As String
    SourceSyntaxHeader = "error UBE1209: invalid parser input (next lines: line, column, byte)"
    If Kind = 2 Then
        SourceSyntaxHeader = "error UBE1208: parser resource limit exceeded (next lines: line, column, byte)"
    End If
    If Kind = 3 Then
        SourceSyntaxHeader = "error UBE1200: source syntax family is not implemented (next lines: line, column, byte)"
    End If
    If Kind = 5 Then
        SourceSyntaxHeader = "error UBE1210: insufficient syntax storage (next lines: line, column, byte)"
    End If
    If Kind = 101 Then
        SourceSyntaxHeader = "error UBE1201: expected expression (next lines: line, column, byte)"
    End If
    If Kind = 102 Then
        SourceSyntaxHeader = "error UBE1202: expected token (next lines: line, column, byte)"
    End If
    If Kind = 103 Then
        SourceSyntaxHeader = "error UBE1203: unexpected token (next lines: line, column, byte)"
    End If
    If Kind = 104 Then
        SourceSyntaxHeader = "error UBE1204: expected identifier (next lines: line, column, byte)"
    End If
    If Kind = 105 Then
        SourceSyntaxHeader = "error UBE1205: invalid call syntax (next lines: line, column, byte)"
    End If
    If Kind = 106 Then
        SourceSyntaxHeader = "error UBE1206: unterminated block (next lines: line, column, byte)"
    End If
    If Kind = 107 Then
        SourceSyntaxHeader = "error UBE1207: unexpected terminator (next lines: line, column, byte)"
    End If
End Function

Function SourceScannerMessage(ByVal Kind As Long) As String
    SourceScannerMessage = "invalid source request"
    If Kind = 1 Then
        SourceScannerMessage = "unexpected character"
    End If
    If Kind = 2 Then
        SourceScannerMessage = "unterminated string"
    End If
    If Kind = 3 Then
        SourceScannerMessage = "unterminated bracketed identifier"
    End If
    If Kind = 4 Then
        SourceScannerMessage = "empty bracketed identifier"
    End If
    If Kind = 5 Then
        SourceScannerMessage = "insufficient scanner storage"
    End If
    If Kind = 6 Then
        SourceScannerMessage = "scanner record limit exceeded"
    End If
    If Kind = 101 Then
        SourceScannerMessage = "missing source header"
    End If
    If Kind = 102 Then
        SourceScannerMessage = "unsupported source format version"
    End If
    If Kind = 103 Then
        SourceScannerMessage = "source kind does not match the file extension"
    End If
    If Kind = 104 Then
        SourceScannerMessage = "missing source identity"
    End If
    If Kind = 105 Then
        SourceScannerMessage = "invalid source identity"
    End If
    If Kind = 106 Then
        SourceScannerMessage = "duplicate source identity"
    End If
    If Kind = 107 Then
        SourceScannerMessage = "unknown reserved source attribute"
    End If
End Function

Function TryPrintSourceSyntaxFailure(ByRef Document As SourceDocument, ByRef Failure As SyntaxFailure) As Boolean
    TryPrintSourceSyntaxFailure = False
    Dim Position As SourcePosition
    Position.LineNumber = 1
    Position.Column = 1
    If TryEnvelopePosition(Document, Failure.FirstByte, Position) = False Then
        Exit Function
    End If
    Dim Header As String = SourceSyntaxHeader(Failure.Kind)
    Print Header
    Print Position.LineNumber
    Print Position.Column
    Print Failure.FirstByte
    TryPrintSourceSyntaxFailure = True
End Function

Sub PrintSyntaxStorageFailure()
    Print "error UBE1210: insufficient syntax storage"
End Sub
