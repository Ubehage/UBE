UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeInitialization"

' Checked source identities remain root-first; runtime initialization is the
' direct dependency first, then the root, in each manifest's written order.
' Validate once and retain only the package boundary, not another source map.
Function TryEmitNativeProjectInitialization(ByRef Writer As NativeLLVMWriter, ByVal Catalog As SemanticCatalog) As Boolean
    TryEmitNativeProjectInitialization = False
    Dim RootCount As Long = 0
    If TryReadNativeInitializationBoundary(Writer, Catalog, RootCount) = False Then
        Exit Function
    End If
    TryEmitNativeProjectInitialization = TryEmitNativeInitializationOrder(Writer, Catalog.SourceCount, RootCount)
End Function

Function TryReadNativeInitializationBoundary(ByRef Writer As NativeLLVMWriter, ByVal Catalog As SemanticCatalog, ByRef RootSources As Long) As Boolean
    TryReadNativeInitializationBoundary = False
    Call ResetNativeFailure(Writer.Failure)
    If Catalog Is Nothing Then
        Exit Function
    End If
    If Catalog.SourceCount < 1 Or Catalog.SourceCount > SemanticSourcesLength(Catalog.Sources) Or Catalog.PackageCount < 1 Or Catalog.PackageCount > 2 Then
        Exit Function
    End If
    Dim RootCount As Long = 0
    Dim PreviousPackage As Long = 0
    Dim Index As Long = 0
    While Index < Catalog.SourceCount
        If TryVisitNativeIndex(Writer.Limits, Writer.Usage, Writer.Cancellation, Writer.Failure) = False Then
            Exit Function
        End If
        Call ResetNativeFailure(Writer.Failure)
        Dim Source As SemanticSource
        Set Source = Catalog.Sources(Index)
        If Source Is Nothing Then
            Exit Function
        End If
        If Source.SourceId <> Index Or Source.PackageId < PreviousPackage Or Source.PackageId >= Catalog.PackageCount Then
            Exit Function
        End If
        PreviousPackage = Source.PackageId
        If Source.PackageId = 0 Then
            RootCount = RootCount + 1
        End If
        Index = Index + 1
    Wend
    If RootCount < 1 Or (Catalog.PackageCount = 2 And RootCount = Catalog.SourceCount) Then
        Exit Function
    End If
    RootSources = RootCount
    Writer.Failure.Code = 0
    TryReadNativeInitializationBoundary = True
End Function

' No owned payload. Each source contributes one emitted requirement and one
' continuation. The surrounding output consumer includes the shared helper.
Function TryEmitNativeInitializationOrder(ByRef Writer As NativeLLVMWriter, ByVal SourceCount As Long, ByVal RootCount As Long) As Boolean
    TryEmitNativeInitializationOrder = False
    Call ResetNativeFailure(Writer.Failure)
    If SourceCount < 1 Or RootCount < 1 Or RootCount > SourceCount Then
        Exit Function
    End If
    Dim Identities As LongLong = SourceCount
    Identities = Identities * 2 + 3
    If TryChargeNativeResource(Writer.Limits, Writer.Usage, 3, Identities, Writer.Failure) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "define internal i1 @ube.module.initialize() alwaysinline {") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "entry:") = False Then
        Exit Function
    End If
    Dim Index As Long = 0
    Dim SourceId As Long = RootCount
    If SourceId = SourceCount Then
        SourceId = 0
    End If
    While Index < SourceCount
        If TryVisitNativeIndex(Writer.Limits, Writer.Usage, Writer.Cancellation, Writer.Failure) = False Then
            Exit Function
        End If
        Call ResetNativeFailure(Writer.Failure)
        If TryLLVMText(Writer, "  %initialized") = False Then
            Exit Function
        End If
        If TryLLVMNumber(Writer, Index) = False Then
            Exit Function
        End If
        If TryLLVMText(Writer, " = call i1 @ube.module.require(i32 ") = False Then
            Exit Function
        End If
        If TryLLVMNumber(Writer, SourceId) = False Then
            Exit Function
        End If
        If TryLLVMLine(Writer, ", i32 -1)") = False Then
            Exit Function
        End If
        If TryLLVMText(Writer, "  br i1 %initialized") = False Then
            Exit Function
        End If
        If TryLLVMNumber(Writer, Index) = False Then
            Exit Function
        End If
        If TryLLVMText(Writer, ", label %next") = False Then
            Exit Function
        End If
        If TryLLVMNumber(Writer, Index) = False Then
            Exit Function
        End If
        If TryLLVMLine(Writer, ", label %failed") = False Then
            Exit Function
        End If
        If TryLLVMText(Writer, "next") = False Then
            Exit Function
        End If
        If TryLLVMNumber(Writer, Index) = False Then
            Exit Function
        End If
        If TryLLVMLine(Writer, ":") = False Then
            Exit Function
        End If
        SourceId = SourceId + 1
        If SourceId = SourceCount Then
            SourceId = 0
        End If
        Index = Index + 1
    Wend
    If TryLLVMLine(Writer, "  ret i1 true") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "failed:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  ret i1 false") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "}") = False Then
        Exit Function
    End If
    Writer.Failure.Code = 0
    TryEmitNativeInitializationOrder = True
End Function

' Private target support for the reviewed single-language-thread executable.
' No owned compiler payload; bounded writer prefixes remain disposable on failure.
' See NATIVE-INITIALIZATION-IMPLEMENTATION.md for state, ABI and stack obligations.
Function TryEmitNativeInitializationSupport(ByRef Writer As NativeLLVMWriter, ByVal SourceCount As Long, ByVal OrdinaryFrames As Long) As Boolean
    TryEmitNativeInitializationSupport = False
    Call ResetNativeFailure(Writer.Failure)
    If SourceCount < 1 Or OrdinaryFrames < 0 Then
        Exit Function
    End If
    If OrdinaryFrames >= 2147483647 - SourceCount Then
        Exit Function
    End If
    Dim TotalFrames As Long = OrdinaryFrames + SourceCount + 1
    Dim WaitFrame As Long = TotalFrames - 1
    ' Five support globals/functions, two parameters, 14 blocks and 20 results.
    If TryChargeNativeResource(Writer.Limits, Writer.Usage, 3, 41, Writer.Failure) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "@ube.module.initializers = external constant [") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, SourceCount) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, " x ptr]") = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "@ube.module.states = external global [") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, SourceCount) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, " x i8]") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "@ube.module.failed = external global i1") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "declare void @ube.module.wait() noreturn") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "define internal i1 @ube.module.require(i32 %owner, i32 %lexical) alwaysinline {") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "entry:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %prior = load i1, ptr @ube.module.failed, align 1") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br i1 %prior, label %failed, label %check") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "check:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %local = icmp eq i32 %owner, -1") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %own = icmp eq i32 %owner, %lexical") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %skip = or i1 %local, %own") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br i1 %skip, label %success, label %bound") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "bound:") = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "  %valid = icmp ult i32 %owner, ") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, SourceCount) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br i1 %valid, label %lookup, label %fatal") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "lookup:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %index = zext i32 %owner to i64") = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "  %slot = getelementptr [") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, SourceCount) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, " x i8], ptr @ube.module.states, i64 0, i64 %index") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %state = load i8, ptr %slot, align 1") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  switch i8 %state, label %fail [ i8 0, label %start i8 1, label %busy i8 2, label %success ]") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "busy:") = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "  %waitsize = load i64, ptr getelementptr ([") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, TotalFrames) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, " x i64], ptr @ube.stack.frames, i64 0, i64 ") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, WaitFrame) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "), align 8") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %waitroom = call i1 @ube.stack.admit(i64 %waitsize)") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br i1 %waitroom, label %wait, label %fatal") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "wait:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  call void @ube.module.wait()") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  unreachable") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "start:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  store i8 1, ptr %slot, align 1") = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "  %frame = add i64 %index, ") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, OrdinaryFrames) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "") = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "  %frameptr = getelementptr [") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, TotalFrames) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, " x i64], ptr @ube.stack.frames, i64 0, i64 %frame") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %needed = load i64, ptr %frameptr, align 8") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %room = call i1 @ube.stack.admit(i64 %needed)") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br i1 %room, label %admitted, label %refused") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "admitted:") = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "  %calleeaddr = getelementptr [") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, SourceCount) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, " x ptr], ptr @ube.module.initializers, i64 0, i64 %index") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %callee = load ptr, ptr %calleeaddr, align 8") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %result = call i1 %callee()") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %broken = load i1, ptr @ube.module.failed, align 1") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %healthy = xor i1 %broken, true") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %completed = and i1 %result, %healthy") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br i1 %completed, label %complete, label %fail") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "refused:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  call void @ube_err_set_stack_exhausted()") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br label %fail") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "complete:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  store i8 2, ptr %slot, align 1") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br label %success") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "fail:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  store i8 3, ptr %slot, align 1") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  store i1 true, ptr @ube.module.failed, align 1") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br label %failed") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "success:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  ret i1 true") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "failed:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  ret i1 false") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "fatal:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  call void @ube.stack.abort()") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  unreachable") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "}") = False Then
        Exit Function
    End If
    TryEmitNativeInitializationSupport = True
End Function

' Emit the single shared storage/table unit. Per-module inline support refers to
' these external definitions; no module gets its own initialization state.
Function TryEmitNativeInitializationData(ByRef Writer As NativeLLVMWriter, ByVal SourceCount As Long) As Boolean
    TryEmitNativeInitializationData = False
    Call ResetNativeFailure(Writer.Failure)
    If SourceCount < 1 Then
        Exit Function
    End If
    Dim Identities As LongLong = SourceCount
    Identities = Identities + 3
    If TryChargeNativeResource(Writer.Limits, Writer.Usage, 3, Identities, Writer.Failure) = False Then
        Exit Function
    End If
    Dim Index As Long = 0
    While Index < SourceCount
        If TryVisitNativeIndex(Writer.Limits, Writer.Usage, Writer.Cancellation, Writer.Failure) = False Then
            Exit Function
        End If
        Call ResetNativeFailure(Writer.Failure)
        If TryLLVMText(Writer, "declare i1 @ube.module.init") = False Then
            Exit Function
        End If
        If TryLLVMNumber(Writer, Index) = False Then
            Exit Function
        End If
        If TryLLVMLine(Writer, "()") = False Then
            Exit Function
        End If
        Index = Index + 1
    Wend
    If TryLLVMText(Writer, "@ube.module.states = global [") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, SourceCount) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, " x i8] zeroinitializer, align 1") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "@ube.module.failed = global i1 false, align 1") = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "@ube.module.initializers = constant [") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, SourceCount) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, " x ptr] [") = False Then
        Exit Function
    End If
    Index = 0
    While Index < SourceCount
        If TryVisitNativeIndex(Writer.Limits, Writer.Usage, Writer.Cancellation, Writer.Failure) = False Then
            Exit Function
        End If
        Call ResetNativeFailure(Writer.Failure)
        If Index > 0 Then
            If TryLLVMText(Writer, ", ") = False Then
                Exit Function
            End If
        End If
        If TryLLVMText(Writer, "ptr @ube.module.init") = False Then
            Exit Function
        End If
        If TryLLVMNumber(Writer, Index) = False Then
            Exit Function
        End If
        Index = Index + 1
    Wend
    TryEmitNativeInitializationData = TryLLVMLine(Writer, "], align 8")
End Function
