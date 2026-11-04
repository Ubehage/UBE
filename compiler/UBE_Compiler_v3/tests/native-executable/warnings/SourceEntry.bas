UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeWarningSourceFixture"

Function CheckNativeWarningProject(ByRef PathUtf8() As Byte, ByVal Jobs As Long, ByRef Result As SemanticResult, ByRef Failure As SemanticFailure) As Boolean
    CheckNativeWarningProject = False
    Call ResetSemanticFailure(Failure)
    Dim SyntaxInput As ProjectSyntax
    Dim Cancellation As SourceCancellation
    If TryMakeStatementCancellation(Cancellation) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Failure)
    If TryMakeStatementProject(PathUtf8, Jobs, Cancellation, SyntaxInput, Failure) = False Then
        Exit Function
    End If
    Dim Limits As SemanticLimits
    Call DefaultSemanticLimits(Limits)
    Call ResetSemanticFailure(Failure)
    CheckNativeWarningProject = TryCheckStatementProject(SyntaxInput, Jobs, Limits, Cancellation, Result, Failure)
End Function
Function PrepareWarningDeclarations(ByRef Result As SemanticResult, ByRef Plan As NativeDeclarationPlan, ByRef Writer As NativeLLVMWriter) As Boolean
    PrepareWarningDeclarations = TryPrepareNativeDeclarations(Plan, Result.Catalog.Declarations, Result.Catalog.DeclarationCount, Result.Catalog.Types, Result.Catalog.TypeCount, Result.Catalog.SourceCount, Writer)
End Function
Function Main() As Long
    Main = 0
End Function
