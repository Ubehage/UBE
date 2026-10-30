UBE SOURCE 1 MODULE
Attribute UBE_Name = "VerticalSlice"

Function BuildTask3Dump(ByVal Source As SourceSetResult, ByVal Tokens As TokenUnitResult, ByVal Syntax As SyntaxUnitResult, ByVal Universe As FrozenUniverseResult, ByVal Procedure As ProcedureResult, ByVal FunctionResult As VerifiedFunctionResult, ByVal Backend As BackendFragmentResult, ByRef Dump As String) As Long
    Dump = ""
    If AppendBoundedText(Dump, Source.Dump, 268435456) = 0 Then BuildTask3Dump = 0: Exit Function
    If AppendBoundedText(Dump, Tokens.Dump, 268435456) = 0 Then BuildTask3Dump = 0: Exit Function
    If AppendBoundedText(Dump, Syntax.Dump, 268435456) = 0 Then BuildTask3Dump = 0: Exit Function
    If AppendBoundedText(Dump, Universe.Dump, 268435456) = 0 Then BuildTask3Dump = 0: Exit Function
    If AppendBoundedText(Dump, Procedure.Dump, 268435456) = 0 Then BuildTask3Dump = 0: Exit Function
    If AppendBoundedText(Dump, FunctionResult.Dump, 268435456) = 0 Then BuildTask3Dump = 0: Exit Function
    If AppendBoundedText(Dump, Backend.Dump, 268435456) = 0 Then BuildTask3Dump = 0: Exit Function
    BuildTask3Dump = 1
End Function

Function RunVerticalSlice(ByVal Session As BuildSession, ByVal EmitDump As Long) As Long
    Dim Diagnostics() As CompilerDiagnostic
    Dim DiagnosticCount As Long = 0
    Dim DiagnosticCapacity As Long = 0
    Dim Source As SourceSetResult
    Dim Tokens As TokenUnitResult
    Dim Syntax As SyntaxUnitResult
    Dim Universe As FrozenUniverseResult
    Dim Procedure As ProcedureResult
    Dim FunctionResult As VerifiedFunctionResult
    Dim Backend As BackendFragmentResult
    Dim Status As Long = 1
    If RemoveCompilerArtifact(Session.OutputPath) <> 0 Then
        Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE6008", Session.OutputPath, "could not remove the previous output artifact")
    Else
        If RunSourcePhase(Session, Source, Diagnostics, DiagnosticCount, DiagnosticCapacity) <> 0 Then
            If RunLexerPhase(Session, Source, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity) <> 0 Then
                If RunSyntaxPhase(Session, Source, Tokens, Syntax, Diagnostics, DiagnosticCount, DiagnosticCapacity) <> 0 Then
                    If RunDeclarationPhase(Session, Source, Syntax, Universe, Diagnostics, DiagnosticCount, DiagnosticCapacity) <> 0 Then
                        If RunSemanticPhase(Session, Source, Universe, Procedure, Diagnostics, DiagnosticCount, DiagnosticCapacity) <> 0 Then
                            If RunIrPhase(Session, Source, Procedure, FunctionResult, Diagnostics, DiagnosticCount, DiagnosticCapacity) <> 0 Then
                                If RunBackendPhase(Session, Source, FunctionResult, Backend, Diagnostics, DiagnosticCount, DiagnosticCapacity) <> 0 Then
                                    Dim PublishedText As String = Backend.LlvmText
                                    If EmitDump <> 0 Then
                                        If BuildTask3Dump(Source, Tokens, Syntax, Universe, Procedure, FunctionResult, Backend, PublishedText) = 0 Then PublishedText = ""
                                    End If
                                    If PublishedText <> "" And PublishCompilerText(Session.OutputPath, PublishedText) = 0 Then Status = 0
                                End If
                            End If
                        End If
                    End If
                End If
            End If
        End If
    End If
    If Status <> 0 Then Call RemoveCompilerArtifact(Session.OutputPath)
    If DiagnosticCount > 0 Then Call ReportCompilerDiagnostics(Diagnostics, DiagnosticCount)
    Call ReleaseBackendFragment(Backend): Call ReleaseVerifiedFunction(FunctionResult)
    Call ReleaseProcedureResult(Procedure): Call ReleaseFrozenUniverse(Universe)
    Call ReleaseSyntaxUnit(Syntax): Call ReleaseTokenUnit(Tokens): Call ReleaseSourceSet(Source)
    RunVerticalSlice = Status
End Function
