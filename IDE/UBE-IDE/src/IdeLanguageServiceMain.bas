UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Function IdeStartsWithFolded(ByVal Value As String, ByVal Prefix As String) As Long
    If StringLength(Value) < StringLength(Prefix) Then
        IdeStartsWithFolded = 0
        Exit Function
    End If
    IdeStartsWithFolded = IdeEqualsFolded(StringSlice(Value, 0, StringLength(Prefix)), Prefix)
End Function

Function IdeDeclarationName(ByVal LineText As String, ByRef DeclarationName As String, ByRef Column As Long) As Long
    Dim Trimmed As String = ""
    Call IdeTrim(LineText, Trimmed)
    Dim Prefixes() As String
    ReDim Prefixes(11)
    Prefixes(0) = "Function "
    Prefixes(1) = "Sub "
    Prefixes(2) = "Type "
    Prefixes(3) = "Enum "
    Prefixes(4) = "Const "
    Prefixes(5) = "Public Function "
    Prefixes(6) = "Public Sub "
    Prefixes(7) = "Public Type "
    Prefixes(8) = "Public Enum "
    Prefixes(9) = "Public Const "
    Prefixes(10) = "Private Function "
    Prefixes(11) = "Private Sub "
    Dim PrefixIndex As Long = 0
    While PrefixIndex <= 11
        If IdeStartsWithFolded(Trimmed, Prefixes(PrefixIndex)) <> 0 Then
            Dim StartIndex As Long = StringLength(Prefixes(PrefixIndex))
            Dim EndIndex As Long = StartIndex
            While EndIndex < StringLength(Trimmed)
                Dim CurrentByte As Long = StringByteAt(Trimmed, EndIndex)
                If CurrentByte = 32 Or CurrentByte = 9 Or CurrentByte = 40 Or CurrentByte = 61 Then
                    Exit While
                End If
                EndIndex = EndIndex + 1
            Wend
            If EndIndex > StartIndex Then
                DeclarationName = StringSlice(Trimmed, StartIndex, EndIndex - StartIndex)
                Column = StringIndexOf(LineText, DeclarationName, 0) + 1
                IdeDeclarationName = 1
                Exit Function
            End If
        End If
        PrefixIndex = PrefixIndex + 1
    Wend
    IdeDeclarationName = 0
End Function

Function IdeFindDeclaration(ByVal Contents As String, ByVal Symbol As String, ByRef SourceLine As Long, ByRef Column As Long) As Long
    Dim Cursor As Long = 0
    Dim LineText As String = ""
    Dim LineNumber As Long = 0
    While IdeReadLine(Contents, Cursor, LineText) <> 0
        LineNumber = LineNumber + 1
        Dim DeclarationName As String = ""
        Dim NameColumn As Long = 0
        If IdeDeclarationName(LineText, DeclarationName, NameColumn) <> 0 Then
            If IdeEqualsFolded(DeclarationName, Symbol) <> 0 Then
                SourceLine = LineNumber
                Column = NameColumn
                IdeFindDeclaration = 1
                Exit Function
            End If
        End If
    Wend
    IdeFindDeclaration = 0
End Function

Sub IdeFindSymbolUse(ByVal Contents As String, ByVal Symbol As String, ByRef SourceLine As Long, ByRef Column As Long)
    SourceLine = 1
    Column = 1
    Dim Cursor As Long = 0
    Dim LineText As String = ""
    Dim LineNumber As Long = 0
    While IdeReadLine(Contents, Cursor, LineText) <> 0
        LineNumber = LineNumber + 1
        Dim Found As Long = StringIndexOf(LineText, Symbol, 0)
        If Found >= 0 Then
            SourceLine = LineNumber
            Column = Found + 1
            Exit Sub
        End If
    Wend
End Sub

Function Main() As Long
    If CommandArgumentCount() <> 2 Then
        Main = 2
        Exit Function
    End If
    Dim RequestPath As String = CommandArgument(0)
    Dim ResultPath As String = CommandArgument(1)
    Dim Request As IdeLanguageRequest
    If IdeLoadLanguageRequest(ReadAllText(RequestPath), Request) = 0 Then
        Main = 3
        Exit Function
    End If
    Dim LanguageResult As IdeLanguageResult
    LanguageResult.RequestId = Request.RequestId
    LanguageResult.DocumentVersion = Request.DocumentVersion
    LanguageResult.Symbol = Request.Symbol
    If Request.Method = "Cancel" Then
        LanguageResult.Status = "Cancelled"
    Else
        Dim DocumentText As String = ReadAllText(Request.DocumentPath)
        If StringLength(DocumentText) = 0 Then
            LanguageResult.Status = "Failed"
        ElseIf Request.Method = "Diagnose" Then
            If IdeFindDeclaration(DocumentText, Request.Symbol, LanguageResult.SourceLine, LanguageResult.Column) <> 0 Then
                LanguageResult.Status = "Ok"
                LanguageResult.FilePath = Request.DocumentPath
                LanguageResult.Origin = "Project"
            Else
                LanguageResult.Status = "Diagnostic"
                LanguageResult.Code = "IDE5001"
                LanguageResult.FilePath = Request.DocumentPath
                Call IdeFindSymbolUse(DocumentText, Request.Symbol, LanguageResult.SourceLine, LanguageResult.Column)
            End If
        ElseIf Request.Method = "ViewDefinition" Then
            If IdeFindDeclaration(DocumentText, Request.Symbol, LanguageResult.SourceLine, LanguageResult.Column) <> 0 Then
                LanguageResult.Status = "Ok"
                LanguageResult.FilePath = Request.DocumentPath
                LanguageResult.Origin = "Project"
            ElseIf Request.LibraryPackage = "UBECore" And StringLength(Request.LibraryVersion) > 0 And StringLength(Request.LibraryIdentity) > 0 And StringLength(Request.LibraryPath) > 0 Then
                Dim LibraryText As String = ReadAllText(Request.LibraryPath)
                If StringLength(LibraryText) > 0 Then
                    If IdeFindDeclaration(LibraryText, Request.Symbol, LanguageResult.SourceLine, LanguageResult.Column) <> 0 Then
                        LanguageResult.Status = "Ok"
                        LanguageResult.FilePath = Request.LibraryPath
                        LanguageResult.Origin = "UBECore"
                        LanguageResult.PackageName = Request.LibraryPackage
                        LanguageResult.PackageVersion = Request.LibraryVersion
                        LanguageResult.SourceIdentity = Request.LibraryIdentity
                    Else
                        LanguageResult.Status = "Diagnostic"
                        LanguageResult.Code = "IDE5001"
                        LanguageResult.FilePath = Request.DocumentPath
                        Call IdeFindSymbolUse(DocumentText, Request.Symbol, LanguageResult.SourceLine, LanguageResult.Column)
                    End If
                Else
                    LanguageResult.Status = "Failed"
                End If
            Else
                LanguageResult.Status = "Diagnostic"
                LanguageResult.Code = "IDE5001"
                LanguageResult.FilePath = Request.DocumentPath
                Call IdeFindSymbolUse(DocumentText, Request.Symbol, LanguageResult.SourceLine, LanguageResult.Column)
            End If
        Else
            LanguageResult.Status = "Failed"
        End If
    End If
    Dim ResultText As String = ""
    If IdeBuildLanguageResult(LanguageResult, ResultText) = 0 Then
        Main = 4
        Exit Function
    End If
    If WriteAllText(ResultPath, ResultText) <> 0 Then
        Main = 5
        Exit Function
    End If
    Main = 0
End Function
