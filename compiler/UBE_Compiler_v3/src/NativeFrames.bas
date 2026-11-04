UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeFrames"

Private Intrinsic Function NativeFrameBytesLength(ByRef Values() As LongLong) As Long
Attribute NativeFrameBytesLength.UBE_Primitive = "Array.Length"
End Function

' Borrow the build owner's already bound complete call footprints. Emission does
' not establish object identity, fixed stack use, call-site safety or reserve
' derivation. The build owner must retain that evidence and the exact objects.
' One indexed metadata visit per ordinary/initializer/wait slot; no scratch.
Function TryEmitNativeFrameData(ByRef Writer As NativeLLVMWriter, ByRef CallBytes() As LongLong, ByVal OrdinaryFrames As Long, ByVal SourceCount As Long, ByVal Reserve As LongLong) As Boolean
    TryEmitNativeFrameData = False
    Call ResetNativeFailure(Writer.Failure)
    If OrdinaryFrames < 1 Or SourceCount < 1 Or Reserve < 8 Then
        Exit Function
    End If
    If OrdinaryFrames >= 2147483647 - SourceCount Then
        Exit Function
    End If
    Dim FrameCount As Long = OrdinaryFrames + SourceCount + 1
    If NativeFrameBytesLength(CallBytes) <> FrameCount Then
        Exit Function
    End If
    If TryChargeNativeResource(Writer.Limits, Writer.Usage, 3, 2, Writer.Failure) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "target triple = ""x86_64-w64-windows-gnu""") = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "@ube.stack.reserve = constant i64 ") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, Reserve) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, ", align 8") = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "@ube.stack.frames = constant [") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, FrameCount) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, " x i64] [") = False Then
        Exit Function
    End If
    Dim Index As Long = 0
    While Index < FrameCount
        If TryVisitNativeIndex(Writer.Limits, Writer.Usage, Writer.Cancellation, Writer.Failure) = False Then
            Exit Function
        End If
        Call ResetNativeFailure(Writer.Failure)
        Dim Footprint As LongLong = CallBytes(Index)
        If Footprint < 8 Then
            Exit Function
        End If
        If Index > 0 Then
            If TryLLVMLine(Writer, ",") = False Then
                Exit Function
            End If
        End If
        If TryLLVMText(Writer, "  i64 ") = False Then
            Exit Function
        End If
        If TryLLVMNumber(Writer, Footprint) = False Then
            Exit Function
        End If
        Index = Index + 1
    Wend
    TryEmitNativeFrameData = TryLLVMLine(Writer, "] , align 8")
End Function
