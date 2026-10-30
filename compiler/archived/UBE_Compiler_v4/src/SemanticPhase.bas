UBE SOURCE 1 MODULE
Attribute UBE_Name = "SemanticPhase"

Type ProcedureResult
    Succeeded As Long
    ProcedureId As Long
    StringTypeId As Long
    StatementCount As Long
    PrintText As String
    WorkUnits As LongLong
    Dump As String
End Type

Sub ReleaseProcedureResult(ByRef Result As ProcedureResult)
    Result.Succeeded = 0: Result.PrintText = "": Result.Dump = ""
End Sub

Function ValidateProcedureResult(ByVal Result As ProcedureResult) As Long
    If Result.Succeeded <> 0 And Result.ProcedureId = 1 And Result.StringTypeId = 1 And Result.StatementCount = 1 Then ValidateProcedureResult = 1 Else ValidateProcedureResult = 0
End Function

Function RunSemanticPhase(ByVal Session As BuildSession, ByVal Source As SourceSetResult, ByVal Universe As FrozenUniverseResult, ByRef Result As ProcedureResult, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Call ReleaseProcedureResult(Result)
    If ValidateFrozenUniverse(Universe) = 0 Then RunSemanticPhase = 0: Exit Function
    Result.ProcedureId = Universe.DeclarationId: Result.StringTypeId = 1
    Result.StatementCount = 1: Result.PrintText = Universe.PrintText
    Result.WorkUnits = 1: Result.Succeeded = 1
    Call AppendPhaseField(Result.Dump, "phase", "semantics")
    Call AppendPhaseField(Result.Dump, "procedure-id", "1")
    Call AppendPhaseField(Result.Dump, "string-type-id", "1")
    Call AppendPhaseField(Result.Dump, "statements", "1")
    If Session.FaultSite = "semantic-envelope" Then Result.StringTypeId = 0
    If ValidateProcedureResult(Result) = 0 Then
        Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE6108", Source.SourcePath, "semantic phase published an invalid envelope")
        RunSemanticPhase = 0
        Exit Function
    End If
    RunSemanticPhase = 1
End Function
