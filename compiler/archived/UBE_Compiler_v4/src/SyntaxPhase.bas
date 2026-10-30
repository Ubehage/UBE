UBE SOURCE 1 MODULE
Attribute UBE_Name = "SyntaxPhase"

Type SyntaxUnitResult
    Succeeded As Long
    SourceId As Long
    SyntaxNodeCount As Long
    ModuleName As String
    ProcedureName As String
    PrintText As String
    ProcedureStart As Long
    ProcedureLength As Long
    WorkUnits As LongLong
    Dump As String
End Type

Sub ReleaseSyntaxUnit(ByRef Result As SyntaxUnitResult)
    Result.Succeeded = 0
    Result.ModuleName = "": Result.ProcedureName = "": Result.PrintText = "": Result.Dump = ""
End Sub

Function ValidateSyntaxUnit(ByVal Result As SyntaxUnitResult) As Long
    If Result.Succeeded = 0 Or Result.SourceId <> 1 Or Result.SyntaxNodeCount <> 4 Then ValidateSyntaxUnit = 0: Exit Function
    If Result.ModuleName = "" Or Result.ProcedureName = "" Or Result.ProcedureStart < 0 Or Result.ProcedureLength <= 0 Then ValidateSyntaxUnit = 0: Exit Function
    ValidateSyntaxUnit = 1
End Function

Function TokenMatches(ByVal Tokens As TokenUnitResult, ByVal Ordinal As Long, ByVal ExpectedKind As String, ByVal ExpectedValue As String) As Long
    Dim Kind As String = ""
    Dim Value As String = ""
    Dim StartOffset As Long = 0
    Dim Length As Long = 0
    If ReadMinimalToken(Tokens.TokenData, Ordinal, Kind, StartOffset, Length, Value) = 0 Then TokenMatches = 0: Exit Function
    If Kind = ExpectedKind And (ExpectedValue = "" Or Value = ExpectedValue) Then TokenMatches = 1 Else TokenMatches = 0
End Function

Function RunSyntaxPhase(ByVal Session As BuildSession, ByVal Source As SourceSetResult, ByVal Tokens As TokenUnitResult, ByRef Result As SyntaxUnitResult, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Call ReleaseSyntaxUnit(Result)
    If ValidateTokenUnit(Tokens) = 0 Then RunSyntaxPhase = 0: Exit Function
    Dim ShapeOk As Long = 1
    If Tokens.TokenCount <> 17 Then ShapeOk = 0
    If TokenMatches(Tokens, 0, "I", "UBE") = 0 Then ShapeOk = 0
    If TokenMatches(Tokens, 1, "I", "SOURCE") = 0 Then ShapeOk = 0
    If TokenMatches(Tokens, 2, "N", "1") = 0 Then ShapeOk = 0
    If TokenMatches(Tokens, 3, "I", "MODULE") = 0 Then ShapeOk = 0
    If TokenMatches(Tokens, 4, "I", "Attribute") = 0 Then ShapeOk = 0
    If TokenMatches(Tokens, 5, "I", "UBE_Name") = 0 Then ShapeOk = 0
    If TokenMatches(Tokens, 6, "P", "=") = 0 Then ShapeOk = 0
    If TokenMatches(Tokens, 7, "S", "") = 0 Then ShapeOk = 0
    If TokenMatches(Tokens, 8, "I", "Public") = 0 Then ShapeOk = 0
    If TokenMatches(Tokens, 9, "I", "Sub") = 0 Then ShapeOk = 0
    If TokenMatches(Tokens, 10, "I", "") = 0 Then ShapeOk = 0
    If TokenMatches(Tokens, 11, "P", "(") = 0 Then ShapeOk = 0
    If TokenMatches(Tokens, 12, "P", ")") = 0 Then ShapeOk = 0
    If TokenMatches(Tokens, 13, "I", "Print") = 0 Then ShapeOk = 0
    If TokenMatches(Tokens, 14, "S", "") = 0 Then ShapeOk = 0
    If TokenMatches(Tokens, 15, "I", "End") = 0 Then ShapeOk = 0
    If TokenMatches(Tokens, 16, "I", "Sub") = 0 Then ShapeOk = 0
    If ShapeOk = 0 Then
        Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3700", Source.SourcePath, "source does not match the Task 3 minimal module grammar")
        RunSyntaxPhase = 0
        Exit Function
    End If
    Dim Kind As String = ""
    Dim StartOffset As Long = 0
    Dim Length As Long = 0
    Call ReadMinimalToken(Tokens.TokenData, 7, Kind, StartOffset, Length, Result.ModuleName)
    Call ReadMinimalToken(Tokens.TokenData, 10, Kind, Result.ProcedureStart, Length, Result.ProcedureName)
    Call ReadMinimalToken(Tokens.TokenData, 14, Kind, StartOffset, Length, Result.PrintText)
    Dim EndStart As Long = 0
    Call ReadMinimalToken(Tokens.TokenData, 16, Kind, EndStart, Length, Kind)
    Result.ProcedureLength = EndStart + Length - Result.ProcedureStart
    Result.SourceId = Tokens.SourceId
    Result.SyntaxNodeCount = 4
    Result.WorkUnits = Tokens.TokenCount
    Result.Succeeded = 1
    Call AppendPhaseField(Result.Dump, "phase", "syntax")
    Call AppendPhaseField(Result.Dump, "nodes", "4")
    Call AppendPhaseField(Result.Dump, "module", Result.ModuleName)
    Call AppendPhaseField(Result.Dump, "procedure", Result.ProcedureName)
    Call AppendPhaseField(Result.Dump, "print-bytes", CompilerLongToText(CompilerTextLength(Result.PrintText)))
    If Session.FaultSite = "syntax-envelope" Then Result.SyntaxNodeCount = 0
    If ValidateSyntaxUnit(Result) = 0 Then
        Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE6108", Source.SourcePath, "parser published an invalid envelope")
        RunSyntaxPhase = 0
        Exit Function
    End If
    RunSyntaxPhase = 1
End Function
