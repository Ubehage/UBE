UBE SOURCE 1 MODULE
Attribute UBE_Name = "IdeLanguageService"

Type IdeLanguageRequest
    RequestId As Long
    DocumentVersion As Long
    Method As String
    DocumentPath As String
    Symbol As String
    LibraryPackage As String
    LibraryVersion As String
    LibraryIdentity As String
    LibraryPath As String
End Type

Type IdeLanguageResult
    RequestId As Long
    DocumentVersion As Long
    Status As String
    Code As String
    FilePath As String
    SourceLine As Long
    Column As Long
    Symbol As String
    Origin As String
    PackageName As String
    PackageVersion As String
    SourceIdentity As String
End Type

Sub IdeAppendLanguageValue(ByRef Result As String, ByVal Key As String, ByVal Value As String)
    Result = Result & Key & " = " & IdeQuoteValue(Value) & StringFromByte(10)
End Sub

Function IdeLanguageSingleLine(ByVal Value As String, ByVal MaximumLength As Long) As Long
    If StringLength(Value) > MaximumLength Then
        IdeLanguageSingleLine = 0
        Exit Function
    End If
    If StringIndexOf(Value, StringFromByte(10), 0) >= 0 Or StringIndexOf(Value, StringFromByte(13), 0) >= 0 Then
        IdeLanguageSingleLine = 0
        Exit Function
    End If
    IdeLanguageSingleLine = 1
End Function

Function IdeReadLanguageField(ByVal Contents As String, ByRef Cursor As Long, ByVal ExpectedKey As String, ByRef Value As String) As Long
    Dim LineText As String = ""
    If IdeReadLine(Contents, Cursor, LineText) = 0 Then
        IdeReadLanguageField = 0
        Exit Function
    End If
    Dim Key As String = ""
    If IdeParseAssignment(LineText, Key, Value) = 0 Then
        IdeReadLanguageField = 0
        Exit Function
    End If
    If IdeEqualsFolded(Key, ExpectedKey) = 0 Then
        IdeReadLanguageField = 0
        Exit Function
    End If
    IdeReadLanguageField = 1
End Function

Function IdeBuildLanguageRequest(ByRef Request As IdeLanguageRequest, ByRef Result As String) As Long
    If Request.RequestId < 1 Or Request.DocumentVersion < 1 Then
        IdeBuildLanguageRequest = 0
        Result = ""
        Exit Function
    End If
    If IdeLanguageSingleLine(Request.Method, 64) = 0 Or IdeLanguageSingleLine(Request.DocumentPath, 1024) = 0 Or IdeLanguageSingleLine(Request.Symbol, 256) = 0 Then
        IdeBuildLanguageRequest = 0
        Result = ""
        Exit Function
    End If
    If StringLength(Request.Method) = 0 Or StringLength(Request.DocumentPath) = 0 Or StringLength(Request.Symbol) = 0 Then
        IdeBuildLanguageRequest = 0
        Result = ""
        Exit Function
    End If
    If IdeLanguageSingleLine(Request.LibraryPackage, 128) = 0 Or IdeLanguageSingleLine(Request.LibraryVersion, 128) = 0 Or IdeLanguageSingleLine(Request.LibraryIdentity, 256) = 0 Or IdeLanguageSingleLine(Request.LibraryPath, 1024) = 0 Then
        IdeBuildLanguageRequest = 0
        Result = ""
        Exit Function
    End If
    Result = "UBE-IDE-Language-Request 1" & StringFromByte(10)
    Call IdeAppendLanguageValue(Result, "RequestId", LongToString(Request.RequestId))
    Call IdeAppendLanguageValue(Result, "DocumentVersion", LongToString(Request.DocumentVersion))
    Call IdeAppendLanguageValue(Result, "Method", Request.Method)
    Call IdeAppendLanguageValue(Result, "DocumentPath", Request.DocumentPath)
    Call IdeAppendLanguageValue(Result, "Symbol", Request.Symbol)
    Call IdeAppendLanguageValue(Result, "LibraryPackage", Request.LibraryPackage)
    Call IdeAppendLanguageValue(Result, "LibraryVersion", Request.LibraryVersion)
    Call IdeAppendLanguageValue(Result, "LibraryIdentity", Request.LibraryIdentity)
    Call IdeAppendLanguageValue(Result, "LibraryPath", Request.LibraryPath)
    IdeBuildLanguageRequest = 1
End Function

Function IdeLoadLanguageRequest(ByVal Contents As String, ByRef Request As IdeLanguageRequest) As Long
    If StringLength(Contents) = 0 Or StringLength(Contents) > IdeLimitProtocolBytes() Then
        IdeLoadLanguageRequest = 0
        Exit Function
    End If
    Dim InvalidByte As Long = -1
    If IdeValidateUtf8(Contents, InvalidByte) = 0 Then
        IdeLoadLanguageRequest = 0
        Exit Function
    End If
    Dim Cursor As Long = 0
    Dim LineText As String = ""
    If IdeReadLine(Contents, Cursor, LineText) = 0 Then
        IdeLoadLanguageRequest = 0
        Exit Function
    End If
    If LineText <> "UBE-IDE-Language-Request 1" Then
        IdeLoadLanguageRequest = 0
        Exit Function
    End If
    Dim Value As String = ""
    If IdeReadLanguageField(Contents, Cursor, "RequestId", Value) = 0 Then
        IdeLoadLanguageRequest = 0
        Exit Function
    End If
    If IdeParseNonnegativeLong(Value, Request.RequestId) = 0 Or Request.RequestId < 1 Then
        IdeLoadLanguageRequest = 0
        Exit Function
    End If
    If IdeReadLanguageField(Contents, Cursor, "DocumentVersion", Value) = 0 Then
        IdeLoadLanguageRequest = 0
        Exit Function
    End If
    If IdeParseNonnegativeLong(Value, Request.DocumentVersion) = 0 Or Request.DocumentVersion < 1 Then
        IdeLoadLanguageRequest = 0
        Exit Function
    End If
    If IdeReadLanguageField(Contents, Cursor, "Method", Request.Method) = 0 Then
        IdeLoadLanguageRequest = 0
        Exit Function
    End If
    If IdeReadLanguageField(Contents, Cursor, "DocumentPath", Request.DocumentPath) = 0 Then
        IdeLoadLanguageRequest = 0
        Exit Function
    End If
    If IdeReadLanguageField(Contents, Cursor, "Symbol", Request.Symbol) = 0 Then
        IdeLoadLanguageRequest = 0
        Exit Function
    End If
    If IdeReadLanguageField(Contents, Cursor, "LibraryPackage", Request.LibraryPackage) = 0 Then
        IdeLoadLanguageRequest = 0
        Exit Function
    End If
    If IdeReadLanguageField(Contents, Cursor, "LibraryVersion", Request.LibraryVersion) = 0 Then
        IdeLoadLanguageRequest = 0
        Exit Function
    End If
    If IdeReadLanguageField(Contents, Cursor, "LibraryIdentity", Request.LibraryIdentity) = 0 Then
        IdeLoadLanguageRequest = 0
        Exit Function
    End If
    If IdeReadLanguageField(Contents, Cursor, "LibraryPath", Request.LibraryPath) = 0 Then
        IdeLoadLanguageRequest = 0
        Exit Function
    End If
    If IdeReadLine(Contents, Cursor, LineText) <> 0 Then
        IdeLoadLanguageRequest = 0
        Exit Function
    End If
    If IdeLanguageSingleLine(Request.Method, 64) = 0 Or IdeLanguageSingleLine(Request.DocumentPath, 1024) = 0 Or IdeLanguageSingleLine(Request.Symbol, 256) = 0 Then
        IdeLoadLanguageRequest = 0
        Exit Function
    End If
    If StringLength(Request.Method) = 0 Or StringLength(Request.DocumentPath) = 0 Or StringLength(Request.Symbol) = 0 Then
        IdeLoadLanguageRequest = 0
        Exit Function
    End If
    If IdeLanguageSingleLine(Request.LibraryPackage, 128) = 0 Or IdeLanguageSingleLine(Request.LibraryVersion, 128) = 0 Or IdeLanguageSingleLine(Request.LibraryIdentity, 256) = 0 Or IdeLanguageSingleLine(Request.LibraryPath, 1024) = 0 Then
        IdeLoadLanguageRequest = 0
        Exit Function
    End If
    IdeLoadLanguageRequest = 1
End Function

Function IdeBuildLanguageResult(ByRef LanguageResult As IdeLanguageResult, ByRef Result As String) As Long
    If LanguageResult.RequestId < 1 Or LanguageResult.DocumentVersion < 1 Then
        IdeBuildLanguageResult = 0
        Exit Function
    End If
    If LanguageResult.SourceLine < 0 Or LanguageResult.Column < 0 Then
        IdeBuildLanguageResult = 0
        Exit Function
    End If
    Result = "UBE-IDE-Language-Result 1" & StringFromByte(10)
    Call IdeAppendLanguageValue(Result, "RequestId", LongToString(LanguageResult.RequestId))
    Call IdeAppendLanguageValue(Result, "DocumentVersion", LongToString(LanguageResult.DocumentVersion))
    Call IdeAppendLanguageValue(Result, "Status", LanguageResult.Status)
    Call IdeAppendLanguageValue(Result, "Code", LanguageResult.Code)
    Call IdeAppendLanguageValue(Result, "Path", LanguageResult.FilePath)
    Call IdeAppendLanguageValue(Result, "Line", LongToString(LanguageResult.SourceLine))
    Call IdeAppendLanguageValue(Result, "Column", LongToString(LanguageResult.Column))
    Call IdeAppendLanguageValue(Result, "Symbol", LanguageResult.Symbol)
    Call IdeAppendLanguageValue(Result, "Origin", LanguageResult.Origin)
    Call IdeAppendLanguageValue(Result, "Package", LanguageResult.PackageName)
    Call IdeAppendLanguageValue(Result, "PackageVersion", LanguageResult.PackageVersion)
    Call IdeAppendLanguageValue(Result, "SourceIdentity", LanguageResult.SourceIdentity)
    If StringLength(Result) > IdeLimitProtocolBytes() Then
        Result = ""
        IdeBuildLanguageResult = 0
        Exit Function
    End If
    IdeBuildLanguageResult = 1
End Function

Function IdeLoadLanguageResult(ByVal Contents As String, ByRef LanguageResult As IdeLanguageResult) As Long
    If StringLength(Contents) = 0 Or StringLength(Contents) > IdeLimitProtocolBytes() Then
        IdeLoadLanguageResult = 0
        Exit Function
    End If
    Dim InvalidByte As Long = -1
    If IdeValidateUtf8(Contents, InvalidByte) = 0 Then
        IdeLoadLanguageResult = 0
        Exit Function
    End If
    Dim Cursor As Long = 0
    Dim LineText As String = ""
    If IdeReadLine(Contents, Cursor, LineText) = 0 Then
        IdeLoadLanguageResult = 0
        Exit Function
    End If
    If LineText <> "UBE-IDE-Language-Result 1" Then
        IdeLoadLanguageResult = 0
        Exit Function
    End If
    Dim Value As String = ""
    If IdeReadLanguageField(Contents, Cursor, "RequestId", Value) = 0 Then
        IdeLoadLanguageResult = 0
        Exit Function
    End If
    If IdeParseNonnegativeLong(Value, LanguageResult.RequestId) = 0 Then
        IdeLoadLanguageResult = 0
        Exit Function
    End If
    If IdeReadLanguageField(Contents, Cursor, "DocumentVersion", Value) = 0 Then
        IdeLoadLanguageResult = 0
        Exit Function
    End If
    If IdeParseNonnegativeLong(Value, LanguageResult.DocumentVersion) = 0 Then
        IdeLoadLanguageResult = 0
        Exit Function
    End If
    If IdeReadLanguageField(Contents, Cursor, "Status", LanguageResult.Status) = 0 Then
        IdeLoadLanguageResult = 0
        Exit Function
    End If
    If IdeReadLanguageField(Contents, Cursor, "Code", LanguageResult.Code) = 0 Then
        IdeLoadLanguageResult = 0
        Exit Function
    End If
    If IdeReadLanguageField(Contents, Cursor, "Path", LanguageResult.FilePath) = 0 Then
        IdeLoadLanguageResult = 0
        Exit Function
    End If
    If IdeReadLanguageField(Contents, Cursor, "Line", Value) = 0 Then
        IdeLoadLanguageResult = 0
        Exit Function
    End If
    If IdeParseNonnegativeLong(Value, LanguageResult.SourceLine) = 0 Then
        IdeLoadLanguageResult = 0
        Exit Function
    End If
    If IdeReadLanguageField(Contents, Cursor, "Column", Value) = 0 Then
        IdeLoadLanguageResult = 0
        Exit Function
    End If
    If IdeParseNonnegativeLong(Value, LanguageResult.Column) = 0 Then
        IdeLoadLanguageResult = 0
        Exit Function
    End If
    If IdeReadLanguageField(Contents, Cursor, "Symbol", LanguageResult.Symbol) = 0 Then
        IdeLoadLanguageResult = 0
        Exit Function
    End If
    If IdeReadLanguageField(Contents, Cursor, "Origin", LanguageResult.Origin) = 0 Then
        IdeLoadLanguageResult = 0
        Exit Function
    End If
    If IdeReadLanguageField(Contents, Cursor, "Package", LanguageResult.PackageName) = 0 Then
        IdeLoadLanguageResult = 0
        Exit Function
    End If
    If IdeReadLanguageField(Contents, Cursor, "PackageVersion", LanguageResult.PackageVersion) = 0 Then
        IdeLoadLanguageResult = 0
        Exit Function
    End If
    If IdeReadLanguageField(Contents, Cursor, "SourceIdentity", LanguageResult.SourceIdentity) = 0 Then
        IdeLoadLanguageResult = 0
        Exit Function
    End If
    If IdeReadLine(Contents, Cursor, LineText) <> 0 Then
        IdeLoadLanguageResult = 0
        Exit Function
    End If
    If LanguageResult.RequestId < 1 Or LanguageResult.DocumentVersion < 1 Then
        IdeLoadLanguageResult = 0
        Exit Function
    End If
    If LanguageResult.Status <> "Ok" And LanguageResult.Status <> "Diagnostic" And LanguageResult.Status <> "Cancelled" And LanguageResult.Status <> "Failed" Then
        IdeLoadLanguageResult = 0
        Exit Function
    End If
    IdeLoadLanguageResult = 1
End Function

Function IdeLanguageResultIsCurrent(ByRef LanguageResult As IdeLanguageResult, ByVal RequestId As Long, ByVal DocumentVersion As Long) As Long
    If LanguageResult.RequestId = RequestId And LanguageResult.DocumentVersion = DocumentVersion Then
        IdeLanguageResultIsCurrent = 1
    Else
        IdeLanguageResultIsCurrent = 0
    End If
End Function

Function IdeApplyLanguageDiagnostic(ByRef LanguageResult As IdeLanguageResult, ByVal RequestId As Long, ByVal DocumentVersion As Long, ByRef Diagnostics() As IdeDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    If IdeLanguageResultIsCurrent(LanguageResult, RequestId, DocumentVersion) = 0 Then
        IdeApplyLanguageDiagnostic = 0
        Exit Function
    End If
    If LanguageResult.Status = "Cancelled" Or LanguageResult.Status = "Failed" Or LanguageResult.Status = "Ok" Then
        IdeApplyLanguageDiagnostic = 1
        Exit Function
    End If
    If LanguageResult.Status <> "Diagnostic" Or StringLength(LanguageResult.Code) = 0 Or LanguageResult.SourceLine < 1 Or LanguageResult.Column < 1 Then
        IdeApplyLanguageDiagnostic = 0
        Exit Function
    End If
    IdeApplyLanguageDiagnostic = IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, LanguageResult.Code, LanguageResult.FilePath, LanguageResult.SourceLine, LanguageResult.Column, 2)
End Function

Function IdeDefinitionCanNavigate(ByRef LanguageResult As IdeLanguageResult, ByVal RequestId As Long, ByVal DocumentVersion As Long, ByVal ExpectedSourceIdentity As String) As Long
    If IdeLanguageResultIsCurrent(LanguageResult, RequestId, DocumentVersion) = 0 Then
        IdeDefinitionCanNavigate = 0
        Exit Function
    End If
    If LanguageResult.Status <> "Ok" Or StringLength(LanguageResult.FilePath) = 0 Or LanguageResult.SourceLine < 1 Or LanguageResult.Column < 1 Then
        IdeDefinitionCanNavigate = 0
        Exit Function
    End If
    If LanguageResult.Origin = "UBECore" Then
        If LanguageResult.PackageName <> "UBECore" Or StringLength(LanguageResult.PackageVersion) = 0 Or StringLength(LanguageResult.SourceIdentity) = 0 Then
            IdeDefinitionCanNavigate = 0
            Exit Function
        End If
        If StringLength(ExpectedSourceIdentity) = 0 Or LanguageResult.SourceIdentity <> ExpectedSourceIdentity Then
            IdeDefinitionCanNavigate = 0
            Exit Function
        End If
    End If
    IdeDefinitionCanNavigate = 1
End Function

Function IdeBuildDiagnosticDisplay(ByRef LanguageResult As IdeLanguageResult, ByVal MessageText As String, ByRef Result As String) As Long
    If LanguageResult.Status <> "Diagnostic" Or StringLength(LanguageResult.Code) = 0 Or StringLength(LanguageResult.FilePath) = 0 Then
        IdeBuildDiagnosticDisplay = 0
        Result = ""
        Exit Function
    End If
    Result = LanguageResult.FilePath & "(" & LongToString(LanguageResult.SourceLine) & "," & LongToString(LanguageResult.Column) & "): " & LanguageResult.Code & ": " & MessageText
    If StringLength(Result) > 4096 Then
        Result = ""
        IdeBuildDiagnosticDisplay = 0
        Exit Function
    End If
    IdeBuildDiagnosticDisplay = 1
End Function
