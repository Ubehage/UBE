UBE SOURCE 1 MODULE
Attribute UBE_Name = "DeclarationPhase"

Type FrozenUniverseResult
    Succeeded As Long
    DeclarationId As Long
    ScopeId As Long
    NameId As Long
    ProcedureName As String
    PrintText As String
    WorkUnits As LongLong
    Dump As String
End Type

Sub ReleaseFrozenUniverse(ByRef Result As FrozenUniverseResult)
    Result.Succeeded = 0: Result.ProcedureName = "": Result.PrintText = "": Result.Dump = ""
End Sub

Function ValidateFrozenUniverse(ByVal Result As FrozenUniverseResult) As Long
    If Result.Succeeded <> 0 And Result.DeclarationId = 1 And Result.ScopeId = 1 And Result.NameId = 1 And Result.ProcedureName = "Main" Then ValidateFrozenUniverse = 1 Else ValidateFrozenUniverse = 0
End Function

Function RunDeclarationPhase(ByVal Session As BuildSession, ByVal Source As SourceSetResult, ByVal Syntax As SyntaxUnitResult, ByRef Result As FrozenUniverseResult, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Call ReleaseFrozenUniverse(Result)
    If ValidateSyntaxUnit(Syntax) = 0 Then RunDeclarationPhase = 0: Exit Function
    If Syntax.ProcedureName <> "Main" Then
        Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE4002", Source.SourcePath, "Task 3 startup procedure must be named Main")
        RunDeclarationPhase = 0
        Exit Function
    End If
    Result.DeclarationId = 1: Result.ScopeId = 1: Result.NameId = 1
    Result.ProcedureName = Syntax.ProcedureName: Result.PrintText = Syntax.PrintText
    Result.WorkUnits = 1: Result.Succeeded = 1
    Call AppendPhaseField(Result.Dump, "phase", "declarations")
    Call AppendPhaseField(Result.Dump, "declaration-id", "1")
    Call AppendPhaseField(Result.Dump, "scope-id", "1")
    Call AppendPhaseField(Result.Dump, "name-id", "1")
    If Session.FaultSite = "declaration-envelope" Then Result.DeclarationId = 0
    If ValidateFrozenUniverse(Result) = 0 Then
        Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE6108", Source.SourcePath, "declaration phase published an invalid envelope")
        RunDeclarationPhase = 0
        Exit Function
    End If
    RunDeclarationPhase = 1
End Function
