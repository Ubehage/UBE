UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeCalls"

' Target-specific call admission over separately linked, immutable frame data.
' The startup adapter must establish the native TLS floor before user code.
' Metadata validation must bind every frame index and the recovery reserve to
' the actual non-LTO objects. Unknown footprints are never supplied as zero.
' These helpers own no payload and publish operands only after full emission.
Function TryEmitNativeCallGuard(ByRef Writer As NativeLLVMWriter, ByVal FrameCount As Long, ByVal FrameIndex As Long, ByRef Result As NativeOperand) As Boolean
    TryEmitNativeCallGuard = False
    Call ResetNativeFailure(Writer.Failure)
    If FrameCount < 1 Or FrameIndex < 0 Or FrameIndex >= FrameCount Then
        Exit Function
    End If
    Dim Footprint As NativeOperand
    If TryLLVMInstruction(Writer, 5, 5, Footprint) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "load i64, ptr getelementptr (") = False Then
        Exit Function
    End If
    If TryLLVMFrameReference(Writer, FrameCount, FrameIndex) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "), align 8") = False Then
        Exit Function
    End If
    Dim Prepared As NativeOperand
    If TryLLVMInstruction(Writer, 1, 1, Prepared) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "call i1 @ube.stack.admit(") = False Then
        Exit Function
    End If
    If TryLLVMTypedOperand(Writer, Footprint) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, ")") = False Then
        Exit Function
    End If
    Result = Prepared
    TryEmitNativeCallGuard = True
End Function

' This fixed helper reads the actual post-argument stack pointer. The inline
' assembly memory clobber retains ordering with argument memory/error effects.
' Hot admission performs no OS query. Fatal disposition is a separate private
' support entry and never resumes user code. Qualification of its implementation
' and all linked machine-code footprints remains the native builder's duty.
Function TryEmitNativeStackSupport(ByRef Writer As NativeLLVMWriter, ByVal FrameCount As Long) As Boolean
    TryEmitNativeStackSupport = False
    Call ResetNativeFailure(Writer.Failure)
    If FrameCount < 1 Then
        Exit Function
    End If
    ' Three globals, two external functions, one helper, its parameter,
    ' three blocks and eleven SSA results: twenty-one distinct identities.
    If TryChargeNativeResource(Writer.Limits, Writer.Usage, 3, 21, Writer.Failure) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "@ube.stack.floor = external thread_local global i64") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "@ube.stack.reserve = external constant i64") = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "@ube.stack.frames = external constant [") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, FrameCount) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, " x i64]") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "declare void @ube_err_set_stack_exhausted()") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "declare void @ube.stack.abort() noreturn") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "define internal i1 @ube.stack.admit(i64 %needed) alwaysinline {") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "entry:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %sp = call i64 asm sideeffect ""movq %rsp, $0"", ""=r,~{memory}""()") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %floor = load i64, ptr @ube.stack.floor, align 8") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %reserve = load i64, ptr @ube.stack.reserve, align 8") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %above = icmp uge i64 %sp, %floor") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %nonzero = icmp ne i64 %floor, 0") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %available = sub i64 %sp, %floor") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %room = icmp uge i64 %available, %reserve") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %validfloor = and i1 %above, %nonzero") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %safe = and i1 %validfloor, %room") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br i1 %safe, label %recoverable, label %fatal") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "recoverable:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %remaining = sub i64 %available, %reserve") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  %permitted = icmp ule i64 %needed, %remaining") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  ret i1 %permitted") = False Then
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
    TryEmitNativeStackSupport = TryLLVMLine(Writer, "}")
End Function

' Reuse the selected frame-table type and resolved ordinal without a scan.
Function TryLLVMFrameReference(ByRef Writer As NativeLLVMWriter, ByVal FrameCount As Long, ByVal FrameIndex As Long) As Boolean
    TryLLVMFrameReference = False
    Call ResetNativeFailure(Writer.Failure)
    If FrameCount < 1 Or FrameIndex < 0 Or FrameIndex >= FrameCount Then
        Exit Function
    End If
    If TryLLVMText(Writer, "[") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, FrameCount) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, " x i64], ptr @ube.stack.frames, i64 0, i64 ") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, FrameIndex) = False Then
        Exit Function
    End If
    TryLLVMFrameReference = True
End Function
