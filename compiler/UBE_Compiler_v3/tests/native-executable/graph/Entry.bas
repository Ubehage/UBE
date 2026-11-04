UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeGraphFixture"

' Uses the maintained complete-source fixture only to enter the real frontend
' and checker. Publication and graph planning are the production operations.
Function CheckNativeGraphSource(ByRef Bytes() As Byte, ByVal Jobs As Long, ByRef Result As SemanticResult, ByRef Failure As SemanticFailure) As Boolean
    CheckNativeGraphSource = False
    Call ResetSemanticFailure(Failure)
    Dim Source As SemanticSource
    If TryMakeStatementSource(Bytes, 0, 0, Source, Failure) = False Then
        Exit Function
    End If
    Dim Cancellation As SourceCancellation
    Call ResetSemanticFailure(Failure)
    If TryMakeStatementCancellation(Cancellation) = False Then
        Exit Function
    End If
    Dim Limits As SemanticLimits
    Call DefaultSemanticLimits(Limits)
    Call ResetSemanticFailure(Failure)
    CheckNativeGraphSource = TryCheckStatementSource(Source, Jobs, Limits, Cancellation, Result, Failure)
End Function
Function LowerCheckedOperator(ByRef Result As SemanticResult, ByVal SourceId As Long, ByVal NodeId As Long, ByRef Writer As NativeLLVMWriter, ByRef Left As NativeOperand, ByRef Right As NativeOperand, ByRef Value As NativeOperand, ByRef OverflowSupport As Long, ByRef NeedsErrorSupport As Boolean) As Boolean
    LowerCheckedOperator = False
    Call ResetNativeFailure(Writer.Failure)
    If Result Is Nothing Then
        Exit Function
    End If
    If SourceId < 0 Or SourceId >= Result.Catalog.SourceCount Then
        Exit Function
    End If
    Dim Module As SemanticModuleResult
    Set Module = Result.Modules(SourceId)
    If Module Is Nothing Then
        Exit Function
    End If
    If NodeId < 0 Or NodeId >= Module.ValueCount Or Left.TypeId < 0 Or Left.TypeId >= Result.Catalog.TypeCount Then
        Exit Function
    End If
    Dim Node As BoundNode
    Call ReadBoundNode(Node, Module.Values(NodeId))
    Call ResetNativeFailure(Writer.Failure)
    If Node.Kind = 4 Then
        LowerCheckedOperator = TryEmitNativeUnary(Writer, Node, Left, Value, OverflowSupport, NeedsErrorSupport)
    Else
        LowerCheckedOperator = TryEmitNativeBinary(Writer, Node, Result.Catalog.Types(Left.TypeId), Left, Right, Value, OverflowSupport, NeedsErrorSupport)
    End If
End Function
Function PlanNativeGraphModule(ByRef Result As SemanticResult, ByVal SourceId As Long, ByRef Declarations As NativeDeclarationPlan, ByRef Plan As NativeGraphPlan, ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByRef Failure As NativeFailure) As Boolean
    PlanNativeGraphModule = False
    Call ResetNativeFailure(Failure)
    If Result Is Nothing Then
        Exit Function
    End If
    If SourceId < 0 Or SourceId >= Result.Catalog.SourceCount Then
        Exit Function
    End If
    Dim Module As SemanticModuleResult
    Set Module = Result.Modules(SourceId)
    If Module Is Nothing Then
        Exit Function
    End If
    Dim SyntaxCount As Long = Result.Catalog.Sources(SourceId).SyntaxInput.Syntax(0).NodeCount
    Dim Cancellation As SourceCancellation
    Call ResetNativeFailure(Failure)
    PlanNativeGraphModule = TryPrepareNativeGraph(Plan, Module.Values, Module.ValueCount, Module.Root, Module.Facts, Module.FactCount, SyntaxCount, Declarations, Limits, Usage, Cancellation, Failure)
End Function
Function Main() As Long
    Main = 0
End Function
Function EmitCheckedProcedure(ByRef Result As SemanticResult, ByVal SourceId As Long, ByVal Root As Long, ByRef State As NativeBodyState, ByRef Declarations As NativeDeclarationPlan, ByRef Plan As NativeGraphPlan, ByRef Writer As NativeLLVMWriter) As Boolean
    EmitCheckedProcedure = False
    Call ResetNativeFailure(Writer.Failure)
    If Result Is Nothing Then
        Exit Function
    End If
    If SourceId < 0 Or SourceId >= Result.Catalog.SourceCount Then
        Exit Function
    End If
    Dim Module As SemanticModuleResult
    Set Module = Result.Modules(SourceId)
    EmitCheckedProcedure = TryEmitNativeProcedure(State, Result.Catalog, Module, Declarations, Plan, Root, Writer)
End Function
Function EmitCheckedInitializer(ByRef Result As SemanticResult, ByVal SourceId As Long, ByRef State As NativeBodyState, ByRef Declarations As NativeDeclarationPlan, ByRef Plan As NativeGraphPlan, ByRef Writer As NativeLLVMWriter) As Boolean
    EmitCheckedInitializer = False
    Call ResetNativeFailure(Writer.Failure)
    If Result Is Nothing Then
        Exit Function
    End If
    If SourceId < 0 Or SourceId >= Result.Catalog.SourceCount Then
        Exit Function
    End If
    Dim Module As SemanticModuleResult
    Set Module = Result.Modules(SourceId)
    EmitCheckedInitializer = TryEmitNativeInitializer(State, Result.Catalog, Module, Declarations, Plan, Writer)
End Function
Function PlanCheckedDeclarations(ByRef Result As SemanticResult, ByRef Plan As NativeDeclarationPlan, ByRef Writer As NativeLLVMWriter) As Boolean
    PlanCheckedDeclarations = False
    Call ResetNativeFailure(Writer.Failure)
    If Result Is Nothing Then
        Exit Function
    End If
    PlanCheckedDeclarations = TryPrepareNativeDeclarations(Plan, Result.Catalog.Declarations, Result.Catalog.DeclarationCount, Result.Catalog.Types, Result.Catalog.TypeCount, Result.Catalog.SourceCount, Writer)
End Function
Function LowerCheckedConversion(ByRef Result As SemanticResult, ByVal SourceId As Long, ByVal FactId As Long, ByRef Writer As NativeLLVMWriter, ByRef Original As NativeOperand, ByRef Converted As NativeOperand, ByRef NeedsErrorSupport As Boolean) As Boolean
    LowerCheckedConversion = False
    Call ResetNativeFailure(Writer.Failure)
    If Result Is Nothing Then
        Exit Function
    End If
    If SourceId < 0 Or SourceId >= Result.Catalog.SourceCount Then
        Exit Function
    End If
    Dim Module As SemanticModuleResult
    Set Module = Result.Modules(SourceId)
    If Module Is Nothing Then
        Exit Function
    End If
    If FactId < 0 Or FactId >= Module.FactCount Then
        Exit Function
    End If
    Dim Fact As SemanticFact
    Call ReadSemanticFact(Fact, Module.Facts(FactId))
    If Fact.TypeId < 0 Or Fact.TypeId >= Result.Catalog.TypeCount Then
        Exit Function
    End If
    Call ResetNativeFailure(Writer.Failure)
    LowerCheckedConversion = TryEmitNativeConversion(Writer, Fact, Result.Catalog.Types(Fact.TypeId), Original, Converted, NeedsErrorSupport)
End Function

Function EmitCheckedProjectInitialization(ByRef Result As SemanticResult, ByRef Writer As NativeLLVMWriter) As Boolean
    EmitCheckedProjectInitialization = False
    Call ResetNativeFailure(Writer.Failure)
    If Result Is Nothing Then
        Exit Function
    End If
    EmitCheckedProjectInitialization = TryEmitNativeProjectInitialization(Writer, Result.Catalog)
End Function

Function EmitCheckedModule(ByRef Result As SemanticResult, ByVal SourceId As Long, ByRef State As NativeBodyState, ByRef Declarations As NativeDeclarationPlan, ByRef Plan As NativeGraphPlan, ByRef Writer As NativeLLVMWriter) As Boolean
    EmitCheckedModule = False
    Call ResetNativeFailure(Writer.Failure)
    If Result Is Nothing Then
        Exit Function
    End If
    If SourceId < 0 Or SourceId >= Result.Catalog.SourceCount Then
        Exit Function
    End If
    Dim Module As SemanticModuleResult
    Set Module = Result.Modules(SourceId)
    EmitCheckedModule = TryEmitNativeModule(State, Result.Catalog, Module, Declarations, Plan, Writer)
End Function

Function EmitCheckedProgramEntry(ByRef Result As SemanticResult, ByRef Declarations As NativeDeclarationPlan, ByRef Writer As NativeLLVMWriter) As Boolean
    EmitCheckedProgramEntry = False
    Call ResetNativeFailure(Writer.Failure)
    If Result Is Nothing Then
        Exit Function
    End If
    EmitCheckedProgramEntry = TryEmitNativeProgramEntry(Writer, Result.Catalog, Declarations, Result.EntryDeclaration)
End Function
