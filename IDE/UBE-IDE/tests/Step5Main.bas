UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Sub Step5Expect(ByVal Condition As Long, ByVal TestName As String, ByRef Failures As Long, ByRef Assertions As Long)
    Assertions = Assertions + 1
    If Condition <> 0 Then
        Print "PASS " & TestName
    Else
        Print "FAIL " & TestName
        Failures = Failures + 1
    End If
End Sub

Function Step5RunRequest(ByVal ServicePath As String, ByVal RequestPath As String, ByVal ResultPath As String, ByRef Request As IdeLanguageRequest, ByRef LanguageResult As IdeLanguageResult) As Long
    Dim RequestText As String = ""
    If IdeBuildLanguageRequest(Request, RequestText) = 0 Then
        Step5RunRequest = 0
        Exit Function
    End If
    If WriteAllText(RequestPath, RequestText) <> 0 Then
        Step5RunRequest = 0
        Exit Function
    End If
    Call CompilerDeleteFile(ResultPath)
    Dim Arguments() As String
    ReDim Arguments(1)
    Arguments(0) = RequestPath
    Arguments(1) = ResultPath
    If CompilerRunTool(ServicePath, Arguments, 2) <> 0 Then
        Step5RunRequest = 0
        Exit Function
    End If
    Step5RunRequest = IdeLoadLanguageResult(ReadAllText(ResultPath), LanguageResult)
End Function

Function Main() As Long
    If CommandArgumentCount() <> 5 Then
        Main = 2
        Exit Function
    End If
    Dim ServicePath As String = CommandArgument(0)
    Dim WorkRoot As String = CommandArgument(1)
    Dim DocumentPath As String = CommandArgument(2)
    Dim LibraryPath As String = CommandArgument(3)
    Dim LibraryIdentity As String = CommandArgument(4)
    Dim RequestPath As String = WorkRoot & "\request.txt"
    Dim ResultPath As String = WorkRoot & "\result.txt"
    Dim Failures As Long = 0
    Dim Assertions As Long = 0

    Dim Original As String = "UBE SOURCE 1 MODULE" & StringFromByte(10) & "Attribute UBE_Name = ""NavigationSample""" & StringFromByte(10) & "Public Function TargetValue() As Long" & StringFromByte(10) & "    TargetValue = 7" & StringFromByte(10) & "End Function" & StringFromByte(10)
    Dim Edited As String = Original & "Public Function Main() As Long" & StringFromByte(10) & "    Main = TargetValue() + MissingProcedure()" & StringFromByte(10) & "End Function" & StringFromByte(10)
    Dim Documents() As IdeDocument
    Dim DocumentCount As Long = 0
    Dim DocumentCapacity As Long = 0
    Dim DocumentIndex As Long = IdeOpenDocument(Documents, DocumentCount, DocumentCapacity, DocumentPath, Original)
    Dim UndoEntries() As IdeUndoEntry
    Dim UndoCount As Long = 0
    Dim UndoCapacity As Long = 0
    Dim UndoCursor As Long = 0
    Call Step5Expect(DocumentIndex = 0, "source opens before language request", Failures, Assertions)
    Call Step5Expect(IdeApplyDocumentText(Documents, DocumentCount, DocumentIndex, Edited, UndoEntries, UndoCount, UndoCapacity, UndoCursor), "edit advances authoritative document", Failures, Assertions)
    Call Step5Expect(Documents(DocumentIndex).Version = 2, "edited document has version two", Failures, Assertions)
    Call Step5Expect(WriteAllText(DocumentPath, Documents(DocumentIndex).CurrentContents) = 0, "versioned service snapshot publishes", Failures, Assertions)

    Dim Request As IdeLanguageRequest
    Request.RequestId = 41
    Request.DocumentVersion = Documents(DocumentIndex).Version
    Request.Method = "Diagnose"
    Request.DocumentPath = DocumentPath
    Request.Symbol = "MissingProcedure"
    Dim LanguageResult As IdeLanguageResult
    Call Step5Expect(Step5RunRequest(ServicePath, RequestPath, ResultPath, Request, LanguageResult), "diagnostic request runs out of process", Failures, Assertions)
    Call Step5Expect(LanguageResult.Status = "Diagnostic" And LanguageResult.Code = "IDE5001", "unresolved call returns semantic diagnostic", Failures, Assertions)
    Dim Diagnostics() As IdeDiagnostic
    Dim DiagnosticCount As Long = 0
    Dim DiagnosticCapacity As Long = 0
    Call Step5Expect(IdeApplyLanguageDiagnostic(LanguageResult, 41, Documents(DocumentIndex).Version, Diagnostics, DiagnosticCount, DiagnosticCapacity), "current diagnostic applies", Failures, Assertions)
    Call Step5Expect(DiagnosticCount = 1 And Diagnostics(0).FilePath = DocumentPath And Diagnostics(0).SourceLine = 7, "diagnostic carries correct source navigation", Failures, Assertions)
    Dim DiagnosticDisplay As String = ""
    Call Step5Expect(IdeBuildDiagnosticDisplay(LanguageResult, "Name cannot be resolved.", DiagnosticDisplay), "diagnostic display builds", Failures, Assertions)
    Dim OutputBuffer As IdeOutputBuffer
    Call Step5Expect(IdeAppendOutput(OutputBuffer, DiagnosticDisplay), "diagnostic displays in bounded output", Failures, Assertions)
    Call Step5Expect(StringIndexOf(OutputBuffer.Contents, "IDE5001", 0) >= 0 And StringIndexOf(OutputBuffer.Contents, DocumentPath, 0) >= 0, "displayed diagnostic retains navigation identity", Failures, Assertions)
    Call Step5Expect(IdeApplyLanguageDiagnostic(LanguageResult, 41, Documents(DocumentIndex).Version + 1, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0, "stale diagnostic is rejected", Failures, Assertions)
    Call Step5Expect(DiagnosticCount = 1, "stale diagnostic cannot disturb current display", Failures, Assertions)

    Request.RequestId = 42
    Request.Method = "ViewDefinition"
    Request.Symbol = "TargetValue"
    Call Step5Expect(Step5RunRequest(ServicePath, RequestPath, ResultPath, Request, LanguageResult), "project definition request runs out of process", Failures, Assertions)
    Call Step5Expect(IdeDefinitionCanNavigate(LanguageResult, 42, Documents(DocumentIndex).Version, ""), "current project definition can navigate", Failures, Assertions)
    Call Step5Expect(LanguageResult.FilePath = DocumentPath And LanguageResult.SourceLine = 3 And LanguageResult.Origin = "Project", "View Definition reaches compiler-resolved project declaration", Failures, Assertions)

    Request.RequestId = 43
    Request.Symbol = "StringIsEmpty"
    Request.LibraryPackage = "UBECore"
    Request.LibraryVersion = "0.1.0-rp1"
    Request.LibraryIdentity = LibraryIdentity
    Request.LibraryPath = LibraryPath
    Call Step5Expect(Step5RunRequest(ServicePath, RequestPath, ResultPath, Request, LanguageResult), "UBECore definition request runs out of process", Failures, Assertions)
    Call Step5Expect(IdeDefinitionCanNavigate(LanguageResult, 43, Documents(DocumentIndex).Version, LibraryIdentity), "exact-version UBECore definition can navigate", Failures, Assertions)
    Call Step5Expect(LanguageResult.Origin = "UBECore" And LanguageResult.PackageVersion = "0.1.0-rp1", "library navigation retains package version", Failures, Assertions)
    Call Step5Expect(LanguageResult.SourceIdentity = LibraryIdentity And LanguageResult.FilePath = LibraryPath And LanguageResult.SourceLine = 11, "library navigation retains exact source identity and range", Failures, Assertions)
    Dim VerifiedIdentity As String = LanguageResult.SourceIdentity
    LanguageResult.SourceIdentity = "sha256:wrong"
    Call Step5Expect(IdeDefinitionCanNavigate(LanguageResult, 43, Documents(DocumentIndex).Version, LibraryIdentity) = 0, "mismatched library source identity blocks navigation", Failures, Assertions)
    LanguageResult.SourceIdentity = VerifiedIdentity

    Request.RequestId = 44
    Request.Method = "Cancel"
    Request.Symbol = "TargetValue"
    Call Step5Expect(Step5RunRequest(ServicePath, RequestPath, ResultPath, Request, LanguageResult), "cancelled request completes out of process", Failures, Assertions)
    Call Step5Expect(LanguageResult.Status = "Cancelled", "cancellation is an ordinary result", Failures, Assertions)
    Dim BeforeCancel As Long = DiagnosticCount
    Call Step5Expect(IdeApplyLanguageDiagnostic(LanguageResult, 44, Documents(DocumentIndex).Version, Diagnostics, DiagnosticCount, DiagnosticCapacity), "cancelled result is safely ignored", Failures, Assertions)
    Call Step5Expect(DiagnosticCount = BeforeCancel, "cancelled result cannot disturb editing", Failures, Assertions)

    Request.RequestId = 45
    Request.Method = "UnsupportedMethod"
    Request.DocumentPath = DocumentPath
    Request.Symbol = "MissingProcedure"
    Call Step5Expect(Step5RunRequest(ServicePath, RequestPath, ResultPath, Request, LanguageResult), "failed service request returns bounded result", Failures, Assertions)
    Call Step5Expect(LanguageResult.Status = "Failed", "unsupported request reports service failure", Failures, Assertions)
    Call Step5Expect(Documents(DocumentIndex).CurrentContents = Edited And Documents(DocumentIndex).Version = 2, "failed request cannot disturb editing", Failures, Assertions)

    Dim Malformed As IdeLanguageResult
    Call Step5Expect(IdeLoadLanguageResult("UBE-IDE-Language-Result 999", Malformed) = 0, "malformed result is rejected without crash", Failures, Assertions)
    Call Step5Expect(IdeLoadLanguageRequest("UBE-IDE-Language-Request 999", Request) = 0, "malformed request is rejected without crash", Failures, Assertions)

    If Failures = 0 Then
        Print "STEP5 PASS " & LongToString(Assertions)
        Main = 0
    Else
        Print "STEP5 FAIL " & LongToString(Failures)
        Main = 1
    End If
End Function
