UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeEntry"

' Borrow the already selected Main; do not repeat name resolution or body work.
Function TryEmitNativeProgramEntry(ByRef Writer As NativeLLVMWriter, ByVal Catalog As SemanticCatalog, ByRef Declarations As NativeDeclarationPlan, ByVal MainId As Long) As Boolean
    TryEmitNativeProgramEntry = False
    Call ResetNativeFailure(Writer.Failure)
    If Catalog Is Nothing Or Declarations.Status <> 1 Then
        Exit Function
    End If
    If MainId < 0 Or MainId >= Declarations.Count Then
        Exit Function
    End If
    Dim RootCount As Long = 0
    If TryReadNativeInitializationBoundary(Writer, Catalog, RootCount) = False Then
        Exit Function
    End If
    If TryVisitNativeIndex(Writer.Limits, Writer.Usage, Writer.Cancellation, Writer.Failure) = False Then
        Exit Function
    End If
    Call ResetNativeFailure(Writer.Failure)
    Dim Selected As NativeDeclarationTarget
    Call ReadNativeDeclarationTarget(Selected, Declarations.Targets(MainId))
    If Selected.SourceId < 0 Or Selected.SourceId >= RootCount Or Selected.Scope <> Selected.SourceId Or Selected.Role <> 0 Or Selected.ParameterCount <> 0 Then
        Exit Function
    End If
    If (Selected.Kind = 5 And Selected.TypeId <> 0) Or (Selected.Kind = 6 And Selected.TypeId <> 4) Then
        Exit Function
    End If
    TryEmitNativeProgramEntry = TryEmitNativeEntry(Writer, Selected.Kind, Selected.ValueIdentity, Selected.FrameIndex, Catalog.SourceCount, RootCount, Declarations.FrameCount)
End Function

' Common startup, shared by ordinary and observed adapters. Platform setup is
' a private target mechanism; its own entry closure is separately qualified.
Function TryEmitNativeEntry(ByRef Writer As NativeLLVMWriter, ByVal MainKind As Long, ByVal MainIdentity As LongLong, ByVal MainFrame As Long, ByVal SourceCount As Long, ByVal RootCount As Long, ByVal OrdinaryFrames As Long) As Boolean
    TryEmitNativeEntry = False
    Call ResetNativeFailure(Writer.Failure)
    If (MainKind <> 5 And MainKind <> 6) Or MainIdentity < 0 Or SourceCount < 1 Or RootCount < 1 Or RootCount > SourceCount Then
        Exit Function
    End If
    If OrdinaryFrames < 1 Or MainFrame < 0 Or MainFrame >= OrdinaryFrames Or OrdinaryFrames >= 2147483647 - SourceCount Then
        Exit Function
    End If
    Dim FrameCount As Long = OrdinaryFrames + SourceCount + 1
    Dim FirstSource As Long = RootCount
    If FirstSource = SourceCount Then
        FirstSource = 0
    End If
    ' Setup declaration, program entry, six blocks and six/seven results.
    ' The selected Main identity was already charged by declaration preparation.
    Dim Identities As LongLong = 14
    If MainKind = 6 Then
        Identities = Identities + 1
    End If
    If TryChargeNativeResource(Writer.Limits, Writer.Usage, 3, Identities, Writer.Failure) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "target triple = ""x86_64-w64-windows-gnu""") = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "declare ") = False Then
        Exit Function
    End If
    If MainKind = 6 Then
        If TryLLVMText(Writer, "i32") = False Then
            Exit Function
        End If
    Else
        If TryLLVMText(Writer, "void") = False Then
            Exit Function
        End If
    End If
    If TryLLVMText(Writer, " @ube.f") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, MainIdentity) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "()") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "declare i1 @ube.stack.initialize(i64, i64)") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "define i32 @ube.program.run() {") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "entry:") = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "  %first = load i64, ptr getelementptr (") = False Then
        Exit Function
    End If
    If TryLLVMFrameReference(Writer, FrameCount, OrdinaryFrames + FirstSource) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "), align 8") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %sp = call i64 asm sideeffect ""movq %rsp, $0"", ""=r,~{memory}""()") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %ready = call i1 @ube.stack.initialize(i64 %sp, i64 %first)") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br i1 %ready, label %initialization, label %failed") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "initialization:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %initialized = call i1 @ube.module.initialize()") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br i1 %initialized, label %main, label %failed") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "main:") = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "  %needed = load i64, ptr getelementptr (") = False Then
        Exit Function
    End If
    If TryLLVMFrameReference(Writer, FrameCount, MainFrame) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "), align 8") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %admitted = call i1 @ube.stack.admit(i64 %needed)") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br i1 %admitted, label %invoke, label %refused") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "invoke:") = False Then
        Exit Function
    End If
    If MainKind = 6 Then
        If TryLLVMText(Writer, "  %returned = call i32 @ube.f") = False Then
            Exit Function
        End If
    Else
        If TryLLVMText(Writer, "  call void @ube.f") = False Then
            Exit Function
        End If
    End If
    If TryLLVMNumber(Writer, MainIdentity) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "()") = False Then
        Exit Function
    End If
    If MainKind = 6 Then
        If TryLLVMLine(Writer, "  ret i32 %returned") = False Then
            Exit Function
        End If
    Else
        If TryLLVMLine(Writer, "  ret i32 0") = False Then
            Exit Function
        End If
    End If
    If TryLLVMLine(Writer, "refused:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  call void @ube_err_set_stack_exhausted()") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  ret i32 0") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "failed:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  ret i32 1") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "}") = False Then
        Exit Function
    End If
    If TryEmitNativeInitializationOrder(Writer, SourceCount, RootCount) = False Then
        Exit Function
    End If
    If TryEmitNativeStackSupport(Writer, FrameCount) = False Then
        Exit Function
    End If
    If TryEmitNativeInitializationSupport(Writer, SourceCount, OrdinaryFrames) = False Then
        Exit Function
    End If
    TryEmitNativeEntry = True
End Function

' This sole platform process adapter can be replaced by the private observer.
Function TryEmitNativeProcessAdapter(ByRef Writer As NativeLLVMWriter) As Boolean
    TryEmitNativeProcessAdapter = False
    If TryChargeNativeResource(Writer.Limits, Writer.Usage, 3, 4, Writer.Failure) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "target triple = ""x86_64-w64-windows-gnu""") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "declare i32 @ube.program.run()") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "define i32 @main() {") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "entry:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %result = call i32 @ube.program.run()") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  ret i32 %result") = False Then
        Exit Function
    End If
    TryEmitNativeProcessAdapter = TryLLVMLine(Writer, "}")
End Function
