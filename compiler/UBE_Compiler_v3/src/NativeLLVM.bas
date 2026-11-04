UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeLLVM"

' One private writer owns its output and the build-wide native resource ledger.
' Pass it only ByRef; a record assignment would copy the managed byte owners.
' Graph/traversal consumers borrow this same Limits/Usage, never a copied ledger.
' Cancellation is retained by the caller through the whole operation.
' Internal append helpers leave a non-success fallback after a successful call,
' so a later managed-entry refusal cannot return False with stale success.
' Failure is meaningful on False; successful snapshot/disposal clears it.
Type NativeLLVMWriter
    Failure As NativeFailure
    Limits As NativeLimits
    Usage As NativeUsage
    Output As NativeOutput
    Cancellation As SourceCancellation
End Type

Function TryBeginNativeLLVM(ByRef Writer As NativeLLVMWriter) As Boolean
    TryBeginNativeLLVM = False
    Call ResetNativeFailure(Writer.Failure)
    If TryBeginNativeModule(Writer.Output, Writer.Cancellation, Writer.Failure) = False Then
        Exit Function
    End If
    Call ResetNativeFailure(Writer.Failure)
    TryBeginNativeLLVM = True
End Function

' Fixed compiler-owned ASCII, not source names or user text. Source/debug text
' uses counted escaping under its own contract instead of this entry point.
Function TryLLVMText(ByRef Writer As NativeLLVMWriter, ByVal Text As String) As Boolean
    TryLLVMText = False
    Call ResetNativeFailure(Writer.Failure)
    If TryAppendNativeAscii(Writer.Output, Writer.Limits, Writer.Usage, Text, Writer.Cancellation, Writer.Failure) = False Then
        Exit Function
    End If
    Call ResetNativeFailure(Writer.Failure)
    TryLLVMText = True
End Function
Function TryLLVMNumber(ByRef Writer As NativeLLVMWriter, ByVal Value As LongLong) As Boolean
    TryLLVMNumber = False
    Call ResetNativeFailure(Writer.Failure)
    If TryAppendNativeInteger(Writer.Output, Writer.Limits, Writer.Usage, Value, Writer.Cancellation, Writer.Failure) = False Then
        Exit Function
    End If
    Call ResetNativeFailure(Writer.Failure)
    TryLLVMNumber = True
End Function
Function TryLLVMLine(ByRef Writer As NativeLLVMWriter, ByVal Text As String) As Boolean
    TryLLVMLine = False
    Call ResetNativeFailure(Writer.Failure)
    If TryLLVMText(Writer, Text) = False Then
        Exit Function
    End If
    If TryAppendNativeByte(Writer.Output, Writer.Limits, Writer.Usage, 10, Writer.Cancellation, Writer.Failure) = False Then
        Exit Function
    End If
    Call ResetNativeFailure(Writer.Failure)
    TryLLVMLine = True
End Function

' Representation is the already-selected builtin ID, not SemanticType.Bits.
' The checked nominal identity remains in the graph; its private target ABI is
' the reviewed one-component aggregate. No type inference occurs here.
Function TryLLVMType(ByRef Writer As NativeLLVMWriter, ByVal Representation As Long, ByVal Aggregate As Boolean) As Boolean
    TryLLVMType = False
    Call ResetNativeFailure(Writer.Failure)
    If Representation < 0 Or Representation > 5 Then
        Exit Function
    End If
    If Aggregate Then
        If Representation < 2 Or Representation > 4 Then
            Exit Function
        End If
        If TryLLVMText(Writer, "{ ") = False Then
            Exit Function
        End If
    End If
    Dim Accepted As Boolean = False
    If Representation = 0 Then
        Accepted = TryLLVMText(Writer, "void")
    End If
    If Representation = 1 Then
        Accepted = TryLLVMText(Writer, "i1")
    End If
    If Representation = 2 Then
        Accepted = TryLLVMText(Writer, "i8")
    End If
    If Representation = 3 Then
        Accepted = TryLLVMText(Writer, "i16")
    End If
    If Representation = 4 Then
        Accepted = TryLLVMText(Writer, "i32")
    End If
    If Representation = 5 Then
        Accepted = TryLLVMText(Writer, "i64")
    End If
    If Accepted = False Then
        Exit Function
    End If
    If Aggregate Then
        If TryLLVMText(Writer, " }") = False Then
            Exit Function
        End If
    End If
    TryLLVMType = True
End Function

' Emit an already-checked constant, including a neutral native payload. Reject
' an inconsistent internal value instead of silently truncating target bits.
' Runtime conversion/error policy is not performed by this serialization.
Function TryLLVMConstant(ByRef Writer As NativeLLVMWriter, ByVal Representation As Long, ByVal Aggregate As Boolean, ByVal Value As LongLong) As Boolean
    TryLLVMConstant = False
    Call ResetNativeFailure(Writer.Failure)
    If Representation < 1 Or Representation > 5 Then
        Exit Function
    End If
    If Representation = 1 And (Value < 0 Or Value > 1) Then
        Exit Function
    End If
    If Representation = 2 And (Value < 0 Or Value > 255) Then
        Exit Function
    End If
    If Representation = 3 And (Value < -32768 Or Value > 32767) Then
        Exit Function
    End If
    If Representation = 4 And (Value < -2147483648 Or Value > 2147483647) Then
        Exit Function
    End If
    If Aggregate Then
        If Representation < 2 Or Representation > 4 Then
            Exit Function
        End If
        If TryLLVMText(Writer, "{ ") = False Then
            Exit Function
        End If
        If TryLLVMType(Writer, Representation, False) = False Then
            Exit Function
        End If
        If TryLLVMText(Writer, " ") = False Then
            Exit Function
        End If
    End If
    If TryLLVMNumber(Writer, Value) = False Then
        Exit Function
    End If
    If Aggregate Then
        If TryLLVMText(Writer, " }") = False Then
            Exit Function
        End If
    End If
    TryLLVMConstant = True
End Function

' Stable private identities are allocated once, in canonical lowering order.
' References reuse their already allocated ID and do not charge it again.
Function TryLLVMIdentity(ByRef Writer As NativeLLVMWriter, ByRef Id As LongLong) As Boolean
    TryLLVMIdentity = False
    Call ResetNativeFailure(Writer.Failure)
    Dim Prepared As LongLong = Writer.Usage.Identities
    If TryChargeNativeResource(Writer.Limits, Writer.Usage, 3, 1, Writer.Failure) = False Then
        Exit Function
    End If
    Id = Prepared
    Call ResetNativeFailure(Writer.Failure)
    TryLLVMIdentity = True
End Function
Function TrySnapshotNativeLLVM(ByRef Writer As NativeLLVMWriter) As Boolean
    Call ResetNativeFailure(Writer.Failure)
    TrySnapshotNativeLLVM = TrySnapshotNativeModule(Writer.Output, Writer.Limits, Writer.Usage, Writer.Cancellation, Writer.Failure)
End Function
Function TryDisposeNativeLLVM(ByRef Writer As NativeLLVMWriter) As Boolean
    Call ResetNativeFailure(Writer.Failure)
    TryDisposeNativeLLVM = TryDisposeNativeOutput(Writer.Output, Writer.Usage, Writer.Failure)
End Function
