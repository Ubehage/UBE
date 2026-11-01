UBE SOURCE 1 MODULE
Attribute UBE_Name = "ProjectDiagnostics"

' No output until all fallible preparation completes. Primary failure is borrowed
' read-only; this module does not change its context, code or file ownership.
Function TryFormatProjectFailurePath(ByRef Invocation() As Byte, ByRef Failure As ProjectFailure, ByRef Published As String) As Boolean
    TryFormatProjectFailurePath = False
    If (Failure.Context Is Nothing) = False Then
        If Failure.Location = 2 And Failure.SourceId >= 0 And Failure.SourceId < Failure.Context.SourceCount Then
            Dim SourceInfo As ProjectSource = Failure.Context.Sources(Failure.SourceId)
            If SourceInfo Is Nothing Then
                Exit Function
            End If
            TryFormatProjectFailurePath = TryFormatProjectPath(SourceInfo.Path.Resolved, Published)
            Exit Function
        End If
        If Failure.Location = 1 And Failure.PackageId >= 0 And Failure.PackageId < Failure.Context.PackageCount Then
            Dim PackageInfo As ProjectPackage = Failure.Context.Packages(Failure.PackageId)
            If PackageInfo Is Nothing Then
                Exit Function
            End If
            TryFormatProjectFailurePath = TryFormatProjectPath(PackageInfo.ResolvedPath, Published)
            Exit Function
        End If
    End If
    TryFormatProjectFailurePath = TryFormatProjectPath(Invocation, Published)
End Function

Function TryProjectFailurePosition(ByRef Failure As ProjectFailure, ByRef Position As SourcePosition) As Boolean
    TryProjectFailurePosition = False
    Position.ByteOffset = Failure.FirstByte
    Position.LineNumber = 1
    Position.Column = 1
    If Failure.FirstByte = 0 Then
        TryProjectFailurePosition = True
        Exit Function
    End If
    If Failure.FirstByte < 0 Or Failure.Context Is Nothing Then
        Exit Function
    End If
    If Failure.Location = 1 And Failure.PackageId >= 0 And Failure.PackageId < Failure.Context.PackageCount Then
        Dim PackageInfo As ProjectPackage = Failure.Context.Packages(Failure.PackageId)
        If PackageInfo Is Nothing Then
            Exit Function
        End If
        TryProjectFailurePosition = TryEnvelopePosition(PackageInfo.Document, Failure.FirstByte, Position)
        Exit Function
    End If
    If Failure.Location = 2 And Failure.SourceId >= 0 And Failure.SourceId < Failure.Context.SourceCount Then
        Dim SourceInfo As ProjectSource = Failure.Context.Sources(Failure.SourceId)
        If SourceInfo Is Nothing Then
            Exit Function
        End If
        If SourceInfo.Owner Is Nothing Then
            Exit Function
        End If
        TryProjectFailurePosition = TryEnvelopePosition(SourceInfo.Owner.Document, Failure.FirstByte, Position)
    End If
End Function

Function TryPrepareProjectSourceDiagnostic(ByRef Failure As ProjectFailure, ByRef Header As String, ByRef Position As SourcePosition, ByRef InlineCoordinates As Boolean) As Boolean
    TryPrepareProjectSourceDiagnostic = False
    InlineCoordinates = True
    If Failure.Kind = 6 Then
        Position = Failure.InputFailure.Position
        TryPrepareProjectSourceDiagnostic = TryFormatSourceInputFailure(Failure.InputFailure, Failure.FileFailure, Header)
        Exit Function
    End If
    If Failure.Kind <> 7 Then
        Exit Function
    End If
    If TryProjectFailurePosition(Failure, Position) = False Then
        Exit Function
    End If
    If Failure.UnitFailure.Kind >= 200 Then
        Dim ScanFailure As ScannerFailure
        ScanFailure.Kind = Failure.UnitFailure.Kind - 200
        ScanFailure.First = Position
        ScanFailure.Last = Position
        TryPrepareProjectSourceDiagnostic = TryFormatSourceScannerFailure(ScanFailure, Header)
        Exit Function
    End If
    InlineCoordinates = False
    Header = SourceSyntaxHeader(Failure.UnitFailure.Kind)
    TryPrepareProjectSourceDiagnostic = True
End Function

Function TryPrintProjectFailure(ByRef Invocation() As Byte, ByRef Failure As ProjectFailure) As Boolean
    TryPrintProjectFailure = False
    Dim Display As String
    If TryFormatProjectFailurePath(Invocation, Failure, Display) = False Then
        Exit Function
    End If
    Dim Position As SourcePosition
    Dim Header As String
    Dim InlineCoordinates As Boolean = False
    If Failure.Code = 0 Then
        If TryPrepareProjectSourceDiagnostic(Failure, Header, Position, InlineCoordinates) = False Then
            Exit Function
        End If
        Print Display
        Print Header
    Else
        If Failure.Code < 1300 Or Failure.Code > 1320 Then
            Exit Function
        End If
        Header = ProjectDiagnosticHeader(Failure.Code)
        If TryProjectFailurePosition(Failure, Position) = False Then
            Exit Function
        End If
        Print Header
        Print Display
    End If
    If InlineCoordinates = False Then
        Print Position.LineNumber
        Print Position.Column
        Print Failure.FirstByte
    End If
    TryPrintProjectFailure = True
End Function

Sub PrintProjectStorageFailure()
    Print "error UBE1310: insufficient project storage"
End Sub

Function ProjectDiagnosticHeader(ByVal Code As Long) As String
    ProjectDiagnosticHeader = "error UBE1320: invalid project input request (next lines: path, line, column, byte)"
    If Code = 1300 Then
        ProjectDiagnosticHeader = "error UBE1300: missing or malformed project header (next lines: path, line, column, byte)"
    End If
    If Code = 1301 Then
        ProjectDiagnosticHeader = "error UBE1301: project format version is not implemented (next lines: path, line, column, byte)"
    End If
    If Code = 1302 Then
        ProjectDiagnosticHeader = "error UBE1302: malformed project entry (next lines: path, line, column, byte)"
    End If
    If Code = 1303 Then
        ProjectDiagnosticHeader = "error UBE1303: unknown project key (next lines: path, line, column, byte)"
    End If
    If Code = 1304 Then
        ProjectDiagnosticHeader = "error UBE1304: duplicate scalar project key (next lines: path, line, column, byte)"
    End If
    If Code = 1305 Then
        ProjectDiagnosticHeader = "error UBE1305: missing required project key (next lines: path, line, column, byte)"
    End If
    If Code = 1306 Then
        ProjectDiagnosticHeader = "error UBE1306: invalid project value (next lines: path, line, column, byte)"
    End If
    If Code = 1307 Then
        ProjectDiagnosticHeader = "error UBE1307: project input facility is not implemented (next lines: path, line, column, byte)"
    End If
    If Code = 1308 Then
        ProjectDiagnosticHeader = "error UBE1308: invalid project path (next lines: path, line, column, byte)"
    End If
    If Code = 1309 Then
        ProjectDiagnosticHeader = "error UBE1309: project resource limit exceeded (next lines: path, line, column, byte)"
    End If
    If Code = 1310 Then
        ProjectDiagnosticHeader = "error UBE1310: insufficient project storage (next lines: path, line, column, byte)"
    End If
    If Code = 1311 Then
        ProjectDiagnosticHeader = "error UBE1311: cannot read project input (next lines: path, line, column, byte)"
    End If
    If Code = 1312 Then
        ProjectDiagnosticHeader = "error UBE1312: duplicate project source path (next lines: path, line, column, byte)"
    End If
    If Code = 1313 Then
        ProjectDiagnosticHeader = "error UBE1313: invalid project reference (next lines: path, line, column, byte)"
    End If
    If Code = 1314 Then
        ProjectDiagnosticHeader = "error UBE1314: project reference cycle (next lines: path, line, column, byte)"
    End If
    If Code = 1315 Then
        ProjectDiagnosticHeader = "error UBE1315: duplicate package identity (next lines: path, line, column, byte)"
    End If
    If Code = 1316 Then
        ProjectDiagnosticHeader = "error UBE1316: duplicate source identity in package (next lines: path, line, column, byte)"
    End If
    If Code = 1317 Then
        ProjectDiagnosticHeader = "error UBE1317: project input was cancelled (next lines: path, line, column, byte)"
    End If
    If Code = 1318 Then
        ProjectDiagnosticHeader = "error UBE1318: cannot start source worker (next lines: path, line, column, byte)"
    End If
    If Code = 1319 Then
        ProjectDiagnosticHeader = "error UBE1319: cannot wait for source worker (next lines: path, line, column, byte)"
    End If
    If Code = 1320 Then
        ProjectDiagnosticHeader = "error UBE1320: invalid project input request (next lines: path, line, column, byte)"
    End If
End Function
