UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeValues"

' A target operand is a scalar reference, not a replacement expression graph.
' Kind 1 is an already-checked literal; kind 2 names a generated SSA identity.
' Call arguments additionally retain kind 3 local/temporary addresses and kind
' 4 global addresses. Value emitters reject address operands; call emission
' consumes their selected pointer form without an incidental value load.
' TypeId retains nominal identity; Representation is the checked builtin ID.
' Records have no managed payload. Result publication is by scalar assignment
' only after emission succeeds, so an input/result alias does not change use.
Type NativeOperand
    Kind As Long
    TypeId As Long
    Representation As Long
    Value As LongLong
End Type

Function TryLLVMOperand(ByRef Writer As NativeLLVMWriter, ByRef Operand As NativeOperand) As Boolean
    TryLLVMOperand = False
    Call ResetNativeFailure(Writer.Failure)
    If Operand.Kind = 1 Then
        TryLLVMOperand = TryLLVMConstant(Writer, Operand.Representation, Operand.TypeId >= 6, Operand.Value)
        Exit Function
    End If
    If Operand.Kind <> 2 Or Operand.Value < 0 Then
        Exit Function
    End If
    If TryLLVMText(Writer, "%v") = False Then
        Exit Function
    End If
    TryLLVMOperand = TryLLVMNumber(Writer, Operand.Value)
End Function
Function TryLLVMTypedOperand(ByRef Writer As NativeLLVMWriter, ByRef Operand As NativeOperand) As Boolean
    TryLLVMTypedOperand = False
    Call ResetNativeFailure(Writer.Failure)
    If TryLLVMType(Writer, Operand.Representation, Operand.TypeId >= 6) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, " ") = False Then
        Exit Function
    End If
    TryLLVMTypedOperand = TryLLVMOperand(Writer, Operand)
End Function

' Emit the definition prefix, charging exactly one SSA identity. The caller
' completes the instruction before using Result and discards output on False.
Function TryLLVMInstruction(ByRef Writer As NativeLLVMWriter, ByVal TypeId As Long, ByVal Representation As Long, ByRef Result As NativeOperand) As Boolean
    TryLLVMInstruction = False
    Call ResetNativeFailure(Writer.Failure)
    If TypeId < 1 Or Representation < 1 Or Representation > 5 Then
        Exit Function
    End If
    If TypeId >= 6 And (Representation < 2 Or Representation > 4) Then
        Exit Function
    End If
    Dim Prepared As NativeOperand
    Prepared.Kind = 2
    Prepared.TypeId = TypeId
    Prepared.Representation = Representation
    If TryLLVMIdentity(Writer, Prepared.Value) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "  ") = False Then
        Exit Function
    End If
    If TryLLVMOperand(Writer, Prepared) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, " = ") = False Then
        Exit Function
    End If
    Result = Prepared
    TryLLVMInstruction = True
End Function

' The checker has selected one opaque native type and its Byte/Integer/Long
' representation. Pack/Unpack change that representation boundary only: no
' implicit numeric conversion, runtime call, allocation or Err update occurs.
' Inputs remain borrowed; publish the scalar result only after full emission.
Function TryEmitNativeRepresentation(ByRef Writer As NativeLLVMWriter, ByVal Role As Long, ByRef NativeType As SemanticType, ByVal NativeId As Long, ByRef Original As NativeOperand, ByRef Result As NativeOperand) As Boolean
    TryEmitNativeRepresentation = False
    Call ResetNativeFailure(Writer.Failure)
    If NativeId < 6 Or NativeType.Kind <> 3 Or (Role <> 1 And Role <> 2) Then
        Exit Function
    End If
    Dim Representation As Long = NativeType.Representation
    If Representation < 2 Or Representation > 4 Or Original.Representation <> Representation Then
        Exit Function
    End If
    Dim SourceType As Long = Representation
    Dim Destination As Long = NativeId
    If Role = 2 Then
        SourceType = NativeId
        Destination = Representation
    End If
    If Original.TypeId <> SourceType Or (Original.Kind <> 1 And Original.Kind <> 2) Then
        Exit Function
    End If
    Dim Prepared As NativeOperand
    If Original.Kind = 1 Then
        Prepared = Original
        Prepared.TypeId = Destination
    Else
        If TryLLVMInstruction(Writer, Destination, Representation, Prepared) = False Then
            Exit Function
        End If
        If Role = 1 Then
            If TryLLVMText(Writer, "insertvalue ") = False Then
                Exit Function
            End If
            If TryLLVMType(Writer, Representation, True) = False Then
                Exit Function
            End If
            If TryLLVMText(Writer, " zeroinitializer, ") = False Then
                Exit Function
            End If
        Else
            If TryLLVMText(Writer, "extractvalue ") = False Then
                Exit Function
            End If
        End If
        If TryLLVMTypedOperand(Writer, Original) = False Then
            Exit Function
        End If
        If TryLLVMLine(Writer, ", 0") = False Then
            Exit Function
        End If
    End If
    Result = Prepared
    TryEmitNativeRepresentation = True
End Function

Private Function TryLLVMIntegerCast(ByRef Writer As NativeLLVMWriter, ByRef Original As NativeOperand, ByVal Destination As Long, ByVal Widening As Boolean, ByRef Result As NativeOperand) As Boolean
    TryLLVMIntegerCast = False
    Call ResetNativeFailure(Writer.Failure)
    Dim Prepared As NativeOperand
    If TryLLVMInstruction(Writer, Destination, Destination, Prepared) = False Then
        Exit Function
    End If
    Dim Accepted As Boolean = False
    If Widening Then
        If Original.Representation = 2 Then
            Accepted = TryLLVMText(Writer, "zext ")
        Else
            Accepted = TryLLVMText(Writer, "sext ")
        End If
    Else
        Accepted = TryLLVMText(Writer, "trunc ")
    End If
    If Accepted = False Then
        Exit Function
    End If
    If TryLLVMTypedOperand(Writer, Original) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, " to ") = False Then
        Exit Function
    End If
    If TryLLVMType(Writer, Destination, False) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "") = False Then
        Exit Function
    End If
    Result = Prepared
    TryLLVMIntegerCast = True
End Function

Private Function TryLLVMRangeComparison(ByRef Writer As NativeLLVMWriter, ByRef Wide As NativeOperand, ByVal Bound As LongLong, ByVal Lower As Boolean, ByRef Result As NativeOperand) As Boolean
    TryLLVMRangeComparison = False
    Call ResetNativeFailure(Writer.Failure)
    Dim Prepared As NativeOperand
    If TryLLVMInstruction(Writer, 1, 1, Prepared) = False Then
        Exit Function
    End If
    Dim Accepted As Boolean = False
    If Lower Then
        Accepted = TryLLVMText(Writer, "icmp sge i64 ")
    Else
        Accepted = TryLLVMText(Writer, "icmp sle i64 ")
    End If
    If Accepted = False Then
        Exit Function
    End If
    If TryLLVMOperand(Writer, Wide) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, ", ") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, Bound) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "") = False Then
        Exit Function
    End If
    Result = Prepared
    TryLLVMRangeComparison = True
End Function

' Consume a conversion selected by the checker. Boolean True sign-extends to
' -1 for numeric conversion; Byte is unsigned, so True-to-Byte is checked.
' Successful narrowing preserves Err; a failed narrowing selects neutral zero
' and records Err 6. LLVM truncation only sees an admitted value or that zero.
' Destination is the retained target SemanticType row, including its bounds.
' NeedsErrorSupport accumulates across the module; support is emitted once by
' its owner after bodies, and the shared error unit is linked only when needed.
Function TryEmitNativeConversion(ByRef Writer As NativeLLVMWriter, ByRef Fact As SemanticFact, ByRef Destination As SemanticType, ByRef Original As NativeOperand, ByRef Result As NativeOperand, ByRef NeedsErrorSupport As Boolean) As Boolean
    TryEmitNativeConversion = False
    Call ResetNativeFailure(Writer.Failure)
    If Fact.Kind <> 3 Or Fact.Left <> Original.TypeId Or Fact.TypeId < 1 Or (Original.Kind <> 1 And Original.Kind <> 2) Then
        Exit Function
    End If
    If Fact.Left = Fact.TypeId Then
        Result = Original
        TryEmitNativeConversion = True
        Exit Function
    End If
    If Fact.Left < 1 Or Fact.Left > 5 Or Fact.TypeId > 5 Or Original.Representation <> Fact.Left Then
        Exit Function
    End If
    Dim Prepared As NativeOperand
    Prepared.TypeId = Fact.TypeId
    Prepared.Representation = Fact.TypeId
    If (Fact.Flags And 2) <> 0 Then
        Prepared.Kind = 1
        Prepared.Value = Fact.Value
        Result = Prepared
        TryEmitNativeConversion = True
        Exit Function
    End If
    If Fact.TypeId = 1 Then
        If TryLLVMInstruction(Writer, 1, 1, Prepared) = False Then
            Exit Function
        End If
        If TryLLVMText(Writer, "icmp ne ") = False Then
            Exit Function
        End If
        If TryLLVMTypedOperand(Writer, Original) = False Then
            Exit Function
        End If
        If TryLLVMLine(Writer, ", 0") = False Then
            Exit Function
        End If
        Result = Prepared
        TryEmitNativeConversion = True
        Exit Function
    End If
    If Fact.TypeId > Fact.Left And (Fact.Left <> 1 Or Fact.TypeId <> 2) Then
        TryEmitNativeConversion = TryLLVMIntegerCast(Writer, Original, Fact.TypeId, True, Result)
        Exit Function
    End If
    If Destination.Kind <> 2 Or Destination.Minimum > Destination.Maximum Then
        Exit Function
    End If
    Dim Wide As NativeOperand
    Wide = Original
    If Original.Representation <> 5 Then
        If TryLLVMIntegerCast(Writer, Original, 5, True, Wide) = False Then
            Exit Function
        End If
    End If
    Dim Lower As NativeOperand
    Dim Upper As NativeOperand
    If TryLLVMRangeComparison(Writer, Wide, Destination.Minimum, True, Lower) = False Then
        Exit Function
    End If
    If TryLLVMRangeComparison(Writer, Wide, Destination.Maximum, False, Upper) = False Then
        Exit Function
    End If
    Dim Admitted As NativeOperand
    If TryLLVMInstruction(Writer, 1, 1, Admitted) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "and i1 ") = False Then
        Exit Function
    End If
    If TryLLVMOperand(Writer, Lower) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, ", ") = False Then
        Exit Function
    End If
    If TryLLVMOperand(Writer, Upper) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "") = False Then
        Exit Function
    End If
    Dim Rejected As NativeOperand
    If TryLLVMInstruction(Writer, 1, 1, Rejected) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "xor i1 ") = False Then
        Exit Function
    End If
    If TryLLVMOperand(Writer, Admitted) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, ", true") = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "  call void @ube.error.if(i1 ") = False Then
        Exit Function
    End If
    If TryLLVMOperand(Writer, Rejected) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, ", i32 6)") = False Then
        Exit Function
    End If
    NeedsErrorSupport = True
    Dim Checked As NativeOperand
    If TryLLVMInstruction(Writer, 5, 5, Checked) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "select i1 ") = False Then
        Exit Function
    End If
    If TryLLVMOperand(Writer, Admitted) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, ", i64 ") = False Then
        Exit Function
    End If
    If TryLLVMOperand(Writer, Wide) = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, ", i64 0") = False Then
        Exit Function
    End If
    TryEmitNativeConversion = TryLLVMIntegerCast(Writer, Checked, Fact.TypeId, False, Result)
End Function

' The complete fixed helper has one external function declaration, one helper
' definition, two parameter values and three blocks: seven unique identities.
' Its caller emits it once per module that actually generated an error check.
' This is compiler-emitted control policy; TLS recording stays in the one
' shared native error-support unit. There is no second error store.
Function TryEmitNativeErrorSupport(ByRef Writer As NativeLLVMWriter) As Boolean
    TryEmitNativeErrorSupport = False
    Call ResetNativeFailure(Writer.Failure)
    If TryChargeNativeResource(Writer.Limits, Writer.Usage, 3, 7, Writer.Failure) = False Then
        Exit Function
    End If
    Call ResetNativeFailure(Writer.Failure)
    If TryLLVMLine(Writer, "declare void @ube_err_set(i32, ptr, ptr)") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "define internal void @ube.error.if(i1 %failed, i32 %number) alwaysinline {") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "entry:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br i1 %failed, label %record, label %done") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "record:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  call void @ube_err_set(i32 %number, ptr null, ptr null)") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  br label %done") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "done:") = False Then
        Exit Function
    End If
    If TryLLVMLine(Writer, "  ret void") = False Then
        Exit Function
    End If
    TryEmitNativeErrorSupport = TryLLVMLine(Writer, "}")
End Function
