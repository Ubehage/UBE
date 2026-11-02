UBE SOURCE 1 MODULE
Attribute UBE_Name = "SemanticDiagnostics"

' Exact messages are fixed by SEMANTIC-DIAGNOSTICS.md before CLI integration.
Function SemanticDiagnosticHeader(ByVal Code As Long) As String
    If Code = 1401 Then
        SemanticDiagnosticHeader = "error UBE1401: declaration requires an explicit type (next lines: line, column, byte)"
    End If
    If Code = 1402 Then
        SemanticDiagnosticHeader = "error UBE1402: duplicate declaration name (next lines: line, column, byte)"
    End If
    If Code = 1403 Then
        SemanticDiagnosticHeader = "error UBE1403: type character does not match the declared type (next lines: line, column, byte)"
    End If
    If Code = 1404 Then
        SemanticDiagnosticHeader = "error UBE1404: type name is not declared (next lines: line, column, byte)"
    End If
    If Code = 1405 Then
        SemanticDiagnosticHeader = "error UBE1405: declaration or type is not valid in this context (next lines: line, column, byte)"
    End If
    If Code = 1406 Then
        SemanticDiagnosticHeader = "error UBE1406: name is not declared (next lines: line, column, byte)"
    End If
    If Code = 1407 Then
        SemanticDiagnosticHeader = "error UBE1407: name is ambiguous (next lines: line, column, byte)"
    End If
    If Code = 1408 Then
        SemanticDiagnosticHeader = "error UBE1408: declaration is not accessible (next lines: line, column, byte)"
    End If
    If Code = 1409 Then
        SemanticDiagnosticHeader = "error UBE1409: target is not a callable procedure (next lines: line, column, byte)"
    End If
    If Code = 1410 Then
        SemanticDiagnosticHeader = "error UBE1410: constant value is outside its selected integer range (next lines: line, column, byte)"
    End If
    If Code = 1411 Then
        SemanticDiagnosticHeader = "error UBE1411: constant integer division by zero (next lines: line, column, byte)"
    End If
    If Code = 1412 Then
        SemanticDiagnosticHeader = "error UBE1412: operator is not valid for these operand types (next lines: line, column, byte)"
    End If
    If Code = 1413 Then
        SemanticDiagnosticHeader = "error UBE1413: expression is not a permitted constant (next lines: line, column, byte)"
    End If
    If Code = 1414 Then
        SemanticDiagnosticHeader = "error UBE1414: target is not writable storage (next lines: line, column, byte)"
    End If
    If Code = 1415 Then
        SemanticDiagnosticHeader = "error UBE1415: assignment form is not valid for this target (next lines: line, column, byte)"
    End If
    If Code = 1416 Then
        SemanticDiagnosticHeader = "error UBE1416: value type is not compatible with the destination (next lines: line, column, byte)"
    End If
    If Code = 1417 Then
        SemanticDiagnosticHeader = "error UBE1417: ByRef requires writable storage of the exact parameter type (next lines: line, column, byte)"
    End If
    If Code = 1418 Then
        SemanticDiagnosticHeader = "error UBE1418: arguments do not match the procedure signature (next lines: line, column, byte)"
    End If
    If Code = 1419 Then
        SemanticDiagnosticHeader = "error UBE1419: invalid parameter declaration (next lines: line, column, byte)"
    End If
    If Code = 1420 Then
        SemanticDiagnosticHeader = "error UBE1420: procedure terminator does not match its declaration (next lines: line, column, byte)"
    End If
    If Code = 1421 Then
        SemanticDiagnosticHeader = "error UBE1421: Exit does not match an enclosing construct (next lines: line, column, byte)"
    End If
    If Code = 1422 Then
        SemanticDiagnosticHeader = "error UBE1422: executable requires one parameterless Sub Main or Function Main As Long (next lines: line, column, byte)"
    End If
    If Code = 1423 Then
        SemanticDiagnosticHeader = "error UBE1423: implicit typing is disabled (next lines: line, column, byte)"
    End If
    If Code = 1424 Then
        SemanticDiagnosticHeader = "error UBE1424: option value is not valid (next lines: line, column, byte)"
    End If
    If Code = 1425 Then
        SemanticDiagnosticHeader = "error UBE1425: invalid primitive declaration or binding (next lines: line, column, byte)"
    End If
    If Code = 1400 Then
        SemanticDiagnosticHeader = "error UBE1400: semantic facility is not implemented (next lines: line, column, byte)"
    End If
    If Code = 1430 Then
        SemanticDiagnosticHeader = "error UBE1430: literal semantics are not implemented (next lines: line, column, byte)"
    End If
    If Code = 1431 Then
        SemanticDiagnosticHeader = "error UBE1431: local declaration lifetime case is not implemented (next lines: line, column, byte)"
    End If
    If Code = 1432 Then
        SemanticDiagnosticHeader = "error UBE1432: operator semantics are not implemented (next lines: line, column, byte)"
    End If
    If Code = 1433 Then
        SemanticDiagnosticHeader = "error UBE1433: datatype semantics are not implemented (next lines: line, column, byte)"
    End If
    If Code = 1434 Then
        SemanticDiagnosticHeader = "error UBE1434: native representation is not implemented (next lines: line, column, byte)"
    End If
    If Code = 1435 Then
        SemanticDiagnosticHeader = "error UBE1435: primitive semantics are not implemented (next lines: line, column, byte)"
    End If
    If Code = 1426 Then
        SemanticDiagnosticHeader = "error UBE1426: invalid semantic checking request (next lines: line, column, byte)"
    End If
    If Code = 1427 Then
        SemanticDiagnosticHeader = "error UBE1427: semantic resource limit exceeded (next lines: line, column, byte)"
    End If
    If Code = 1428 Then
        SemanticDiagnosticHeader = "error UBE1428: insufficient semantic storage (next lines: line, column, byte)"
    End If
    If Code = 1429 Then
        SemanticDiagnosticHeader = "error UBE1429: semantic checking was cancelled (next lines: line, column, byte)"
    End If
    If Code = 1436 Then
        SemanticDiagnosticHeader = "error UBE1436: cannot start semantic worker (next lines: line, column, byte)"
    End If
    If Code = 1437 Then
        SemanticDiagnosticHeader = "error UBE1437: cannot wait for semantic worker (next lines: line, column, byte)"
    End If
End Function

' Printing stays rootless when a managed command/formatter cannot be entered.
Sub PrintCompilerStorageFailure(ByVal Code As Long)
    If Code = 1428 Then
        Print "error UBE1428: insufficient semantic storage"
    Else
        If Code = 1210 Then
            Call PrintSyntaxStorageFailure()
        Else
            If Code = 1007 Then
                Print "error UBE1007: insufficient source storage"
            Else
                If Code = 1100 Then
                    Print "error UBE1100: insufficient scanner storage"
                Else
                    Call PrintProjectStorageFailure()
                End If
            End If
        End If
    End If
End Sub

' All strings, decimal coordinates and path escapes are prepared before output.
' The final Print adds the sole trailing LF; intermediate separators live here.
Function TryComposeSemanticDiagnostic(ByVal Header As String, ByVal Display As String, ByVal IncludePath As Boolean, ByRef Position As SourcePosition, ByVal ByteOffset As Long, ByRef Published As String) As Boolean
    TryComposeSemanticDiagnostic = False
    If StringLength(Header) = 0 Or Position.LineNumber < 1 Or Position.Column < 1 Or ByteOffset < 0 Then
        Exit Function
    End If
    Dim Pieces() As String
    Dim HeaderLength As Long = StringLength(Header)
    Dim DisplayLength As Long = StringLength(Display)
    If TryResizeProjectDisplayPieces(Pieces, 9, False) = False Then
        Exit Function
    End If
    Dim Newline As String = StringFromByte(10)
    If StringLength(Newline) <> 1 Then
        Exit Function
    End If
    If IncludePath Then
        If StringLength(Display) = 0 Then
            Exit Function
        End If
        Pieces(0) = Display
        Pieces(1) = Newline
    End If
    Pieces(2) = Header
    Pieces(3) = Newline
    Pieces(4) = LongToString(Position.LineNumber)
    Pieces(5) = Newline
    Pieces(6) = LongToString(Position.Column)
    Pieces(7) = Newline
    Pieces(8) = LongToString(ByteOffset)
    If StringLength(Pieces(2)) <> HeaderLength Or StringLength(Pieces(3)) <> 1 Or StringLength(Pieces(5)) <> 1 Or StringLength(Pieces(7)) <> 1 Then
        Exit Function
    End If
    If IncludePath Then
        If StringLength(Pieces(0)) <> DisplayLength Or StringLength(Pieces(1)) <> 1 Then
            Exit Function
        End If
    End If
    If StringLength(Pieces(4)) <> DiagnosticDecimalLength(Position.LineNumber) Or StringLength(Pieces(6)) <> DiagnosticDecimalLength(Position.Column) Or StringLength(Pieces(8)) <> DiagnosticDecimalLength(ByteOffset) Then
        Exit Function
    End If
    Dim Expected As Long = 0
    Dim Index As Long = 0
    While Index < 9
        Dim Length As Long = StringLength(Pieces(Index))
        If Length < 0 Or Length > 2147483647 - Expected Then
            Exit Function
        End If
        Expected = Expected + Length
        Index = Index + 1
    Wend
    Dim Prepared As String = StringArrayJoin(Pieces, 9)
    If StringLength(Prepared) <> Expected Then
        Exit Function
    End If
    Published = Prepared
    TryComposeSemanticDiagnostic = True
End Function

Function TryFormatSourceSemanticFailure(ByVal SyntaxInput As SourceWork, ByRef Failure As SemanticFailure, ByRef Published As String) As Boolean
    TryFormatSourceSemanticFailure = False
    If SyntaxInput Is Nothing Then
        Exit Function
    End If
    If Failure.Code < 1400 Or Failure.Code > 1437 Then
        Exit Function
    End If
    Dim Position As SourcePosition
    Position.LineNumber = 1
    Position.Column = 1
    Dim ByteOffset As Long = 0
    If Failure.SourceId = 0 Then
        ByteOffset = Failure.FirstByte
        If TrySemanticFailurePosition(SyntaxInput, ByteOffset, Position) = False Then
            Exit Function
        End If
    Else
        If Failure.SourceId <> -1 Then
            Exit Function
        End If
    End If
    Dim Header As String = SemanticDiagnosticHeader(Failure.Code)
    If StringLength(Header) = 0 Then
        Exit Function
    End If
    TryFormatSourceSemanticFailure = TryComposeSemanticDiagnostic(Header, "", False, Position, ByteOffset, Published)
End Function

Function TryFormatProjectSemanticFailure(ByRef Invocation() As Byte, ByVal SyntaxInput As ProjectSyntax, ByRef Failure As SemanticFailure, ByRef Published As String) As Boolean
    TryFormatProjectSemanticFailure = False
    If SyntaxInput Is Nothing Then
        Exit Function
    End If
    If SyntaxInput.Project Is Nothing Or Failure.Code < 1400 Or Failure.Code > 1437 Then
        Exit Function
    End If
    Dim PathFailure As ProjectFailure
    Set PathFailure.Context = SyntaxInput.Project
    If (PathFailure.Context Is SyntaxInput.Project) = False Then
        Exit Function
    End If
    PathFailure.SourceId = -1
    PathFailure.PackageId = -1
    Dim Position As SourcePosition
    Position.LineNumber = 1
    Position.Column = 1
    Dim ByteOffset As Long = 0
    If Failure.SourceId >= 0 Then
        If Failure.SourceId >= SyntaxInput.Project.SourceCount Then
            Exit Function
        End If
        PathFailure.Location = 2
        PathFailure.SourceId = Failure.SourceId
        ByteOffset = Failure.FirstByte
        If TrySemanticFailurePosition(SyntaxInput.Work(Failure.SourceId), ByteOffset, Position) = False Then
            Exit Function
        End If
    Else
        If Failure.SourceId <> -1 Then
            Exit Function
        End If
    End If
    Dim Display As String
    If TryFormatProjectFailurePath(Invocation, PathFailure, Display) = False Then
        Exit Function
    End If
    Dim Header As String = SemanticDiagnosticHeader(Failure.Code)
    If StringLength(Header) = 0 Then
        Exit Function
    End If
    TryFormatProjectSemanticFailure = TryComposeSemanticDiagnostic(Header, Display, True, Position, ByteOffset, Published)
End Function

' Every ordinary semantic primary begins at an already-qualified token. Reuse
' its original scalar/line/column coordinates; never rescan or normalize source.
' Zero is also the contracted source-independent infrastructure point.
Function TrySemanticFailurePosition(ByVal SyntaxInput As SourceWork, ByVal ByteOffset As Long, ByRef Position As SourcePosition) As Boolean
    TrySemanticFailurePosition = False
    If SyntaxInput Is Nothing Or ByteOffset < 0 Then
        Exit Function
    End If
    Dim Prepared As SourcePosition
    Prepared.LineNumber = 1
    Prepared.Column = 1
    If ByteOffset = 0 Then
        Position = Prepared
        TrySemanticFailurePosition = True
        Exit Function
    End If
    Dim Token As SourceToken
    Dim Failure As Long = 5
    If TryFindSemanticSourceToken(SyntaxInput.Tokens, ByteOffset, Token, Failure) = False Then
        Exit Function
    End If
    Position = Token.First
    TrySemanticFailurePosition = True
End Function

Function TryPrintSourceSemanticFailure(ByVal SyntaxInput As SourceWork, ByRef Failure As SemanticFailure) As Boolean
    TryPrintSourceSemanticFailure = False
    Dim Prepared As String
    If TryFormatSourceSemanticFailure(SyntaxInput, Failure, Prepared) = False Then
        Exit Function
    End If
    Print Prepared
    TryPrintSourceSemanticFailure = True
End Function

Function TryPrintProjectSemanticFailure(ByRef Invocation() As Byte, ByVal SyntaxInput As ProjectSyntax, ByRef Failure As SemanticFailure) As Boolean
    TryPrintProjectSemanticFailure = False
    Dim Prepared As String
    If TryFormatProjectSemanticFailure(Invocation, SyntaxInput, Failure, Prepared) = False Then
        Exit Function
    End If
    Print Prepared
    TryPrintProjectSemanticFailure = True
End Function
