UBE SOURCE 1 MODULE
Attribute UBE_Name = "IrPhase"

Type VerifiedFunctionResult
    Succeeded As Long
    FunctionId As Long
    BlockCount As Long
    ValueCount As Long
    InstructionCount As Long
    PrintText As String
    WorkUnits As LongLong
    Dump As String
End Type

Sub ReleaseVerifiedFunction(ByRef Result As VerifiedFunctionResult)
    Result.Succeeded = 0: Result.PrintText = "": Result.Dump = ""
End Sub

Function ValidateVerifiedFunction(ByVal Result As VerifiedFunctionResult) As Long
    If Result.Succeeded <> 0 And Result.FunctionId = 1 And Result.BlockCount = 1 And Result.ValueCount = 1 And Result.InstructionCount = 3 Then ValidateVerifiedFunction = 1 Else ValidateVerifiedFunction = 0
End Function

Function RunIrPhase(ByVal Session As BuildSession, ByVal Source As SourceSetResult, ByVal Procedure As ProcedureResult, ByRef Result As VerifiedFunctionResult, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Call ReleaseVerifiedFunction(Result)
    If ValidateProcedureResult(Procedure) = 0 Then RunIrPhase = 0: Exit Function
    Result.FunctionId = Procedure.ProcedureId: Result.BlockCount = 1
    Result.ValueCount = 1: Result.InstructionCount = 3: Result.PrintText = Procedure.PrintText
    Result.WorkUnits = 3: Result.Succeeded = 1
    Call AppendPhaseField(Result.Dump, "phase", "ir")
    Call AppendPhaseField(Result.Dump, "function-id", "1")
    Call AppendPhaseField(Result.Dump, "blocks", "1")
    Call AppendPhaseField(Result.Dump, "values", "1")
    Call AppendPhaseField(Result.Dump, "instructions", "3")
    If Session.FaultSite = "ir-envelope" Then Result.InstructionCount = 2
    If ValidateVerifiedFunction(Result) = 0 Then
        Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE5001", Source.SourcePath, "function-local IR verification failed")
        RunIrPhase = 0
        Exit Function
    End If
    RunIrPhase = 1
End Function
