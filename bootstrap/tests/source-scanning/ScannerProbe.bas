UBE SOURCE 1 MODULE
Attribute UBE_Name = "ScannerProbe"
' Exposes actual retained scanner records to independent native acceptance assertions.
Private InputPath() As Byte
Private SourceBytes() As Byte
Private Tokens() As SourceScanner.SourceToken
Private Count As Long
Private Diagnostic As SourceScanner.ScanDiagnostic

' Measures retained storage separately from the published successful token count.
Private Intrinsic Function TokenStorageLength(ByRef Values() As SourceScanner.SourceToken) As Long
Attribute TokenStorageLength.UBE_Primitive = "Array.Length"
End Function

' Allocates the exact counted path used by the file-backed scanner entry.
Public Function ConfigurePath(ByVal Length As Long) As Long
    Dim Status As Boolean
    Status = BufferPrimitives.TryResizeBytes(InputPath, Length, False)
    If Status = False Then ConfigurePath = 1 Else ConfigurePath = 0
End Function

' Installs one path byte through ordinary source-level assignment.
Public Function SetPathByte(ByVal Index As Long, ByVal Value As Long) As Long
    InputPath(Index) = Value
    SetPathByte = 0
End Function

' Reads real file bytes before invoking the production scanner.
Public Function LoadAndScan() As Long
    Dim Status As Boolean
    Dim Token As Long
    Dim Failure As Long
    Status = FileBytes.TryReadAllBytes(InputPath, 4096, SourceBytes, Token, Failure)
    If Status = False Then
        Status = FilePrimitives.TryClose(Token, Failure)
        LoadAndScan = 2
        Exit Function
    End If
    Status = SourceScanner.TryScan(SourceBytes, Tokens, Count, Diagnostic)
    If Status = False Then LoadAndScan = 1 Else LoadAndScan = 0
End Function

' Returns the separately published count, which is zero after any failed scan.
Public Function TokenCount() As Long
    TokenCount = Count
End Function

' Returns prior retained allocation length even after a rejected replacement scan.
Public Function RetainedCount() As Long
    RetainedCount = TokenStorageLength(Tokens)
End Function

' Returns one declared token field without implementing any lexical logic in the fixture.
Public Function TokenField(ByVal Index As Long, ByVal Field As Long) As Long
    If Field = 0 Then TokenField = Tokens(Index).Kind: Exit Function
    If Field = 1 Then TokenField = Tokens(Index).ByteStart: Exit Function
    If Field = 2 Then TokenField = Tokens(Index).ByteLength: Exit Function
    If Field = 3 Then TokenField = Tokens(Index).Line: Exit Function
    If Field = 4 Then TokenField = Tokens(Index).Column: Exit Function
    If Field = 5 Then TokenField = Tokens(Index).Utf16Start: Exit Function
    If Field = 6 Then TokenField = Tokens(Index).Utf16Length: Exit Function
    Err.Raise 5
End Function

' Returns the scanner's first numeric diagnostic and exact physical source location.
Public Function DiagnosticField(ByVal Field As Long) As Long
    If Field = 0 Then DiagnosticField = Diagnostic.Code: Exit Function
    If Field = 1 Then DiagnosticField = Diagnostic.Reason: Exit Function
    If Field = 2 Then DiagnosticField = Diagnostic.ByteOffset: Exit Function
    If Field = 3 Then DiagnosticField = Diagnostic.Utf16Offset: Exit Function
    If Field = 4 Then DiagnosticField = Diagnostic.Line: Exit Function
    If Field = 5 Then DiagnosticField = Diagnostic.Column: Exit Function
    Err.Raise 5
End Function
