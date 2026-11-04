UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeOutput"

' One private current-module buffer and at most one published snapshot.
' All state is caller-owned, passed ByRef and never copied. Limits/Usage belong
' to the whole build. Status: 0 neutral, 1 appending, 2 snapshot, 3 released,
' 4 failed, 5 written. Failure poisons this module; only cleanup is then allowed.
' Capacity shadows successful Core reservations, never reserved Core fields.
' The caller seeds Failure before entering managed code. Managed admission
' can fail before these bodies run. No operation publishes a destination file.
' Cancellation is borrowed ByRef, never reassigned; its caller retains the
' owner and may only set Requested=True through the existing synchronization.
Type NativeOutput
    Buffer As ByteBuffer
    Snapshot() As Byte
    Capacity As Long
    Length As Long
    SnapshotLength As Long
    Status As Long
End Type

Function TryContinueNativeOutput(ByRef Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryContinueNativeOutput = False
    Call ResetNativeFailure(Failure)
    Dim Requested As Boolean = False
    If TryThreadStopRequested(Requested) = False Then
        Exit Function
    End If
    If (Cancellation Is Nothing) = False Then
        Requested = Requested Or Cancellation.Requested
    End If
    If Requested Then
        Failure.Code = 1507
        Exit Function
    End If
    Failure.Code = 0
    TryContinueNativeOutput = True
End Function

Function FailNativeOutput(ByRef Status As Long, ByRef Failure As NativeFailure, ByVal Code As Long, ByVal Resource As Long) As Boolean
    FailNativeOutput = False
    Status = 4
    Failure.Code = Code
    Failure.Resource = Resource
End Function

Function TryBeginNativeModule(ByRef State As NativeOutput, ByRef Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryBeginNativeModule = False
    Call ResetNativeFailure(Failure)
    If State.Status <> 0 And State.Status <> 3 Then
        Exit Function
    End If
    If State.SnapshotLength <> 0 Then
        Exit Function
    End If
    Call ResetNativeFailure(Failure)
    If TryContinueNativeOutput(Cancellation, Failure) = False Then
        State.Status = 4
        Exit Function
    End If
    Call ResetNativeFailure(Failure)
    If ClearByteBuffer(State.Buffer) = False Then
        State.Status = 4
        Exit Function
    End If
    State.Length = 0
    State.Status = 1
    Failure.Code = 0
    TryBeginNativeModule = True
End Function

' Admit the complete requested append, then reserve geometric capacity. The
' cumulative LLVM charge is committed only for bytes actually appended.
' Growth reserves old+new payload before allocation, releases the new charge
' on failed admission, or the old charge after a successful replacement.
Private Function TryPrepareNativeAppend(ByRef State As NativeOutput, ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByVal Count As Long, ByRef Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryPrepareNativeAppend = False
    Call ResetNativeFailure(Failure)
    If State.Status <> 1 Or Count < 0 Or State.Length < 0 Or State.Length > State.Capacity Then
        Exit Function
    End If
    Dim Prepared As NativeUsage
    Prepared = Usage
    If TryChargeNativeResource(Limits, Prepared, 2, Count, Failure) = False Then
        State.Status = 4
        Exit Function
    End If
    If Count > 2147483647 - State.Length Then
        TryPrepareNativeAppend = FailNativeOutput(State.Status, Failure, 1502, 2)
        Exit Function
    End If
    Call ResetNativeFailure(Failure)
    If TryContinueNativeOutput(Cancellation, Failure) = False Then
        State.Status = 4
        Exit Function
    End If
    Dim Required As Long = State.Length + Count
    If Required > State.Capacity Then
        Dim Capacity As Long = State.Capacity
        If Capacity < 8 Then
            Capacity = 8
        End If
        While Capacity < Required
            If Capacity > 1073741823 Then
                Capacity = Required
            Else
                Capacity = Capacity * 2
            End If
        Wend
        If TryChargeNativeResource(Limits, Usage, 1, Capacity, Failure) = False Then
            State.Status = 4
            Exit Function
        End If
        Dim Cleanup As NativeFailure
        Call ResetNativeFailure(Failure)
        If TryReserveByteBuffer(State.Buffer, Required) = False Then
            Call TryReleaseNativeResource(Usage, 1, Capacity, Cleanup)
            TryPrepareNativeAppend = FailNativeOutput(State.Status, Failure, 1502, 1)
            Exit Function
        End If
        Call TryReleaseNativeResource(Usage, 1, State.Capacity, Cleanup)
        State.Capacity = Capacity
        Call ResetNativeFailure(Failure)
        If TryContinueNativeOutput(Cancellation, Failure) = False Then
            State.Status = 4
            Exit Function
        End If
    End If
    Failure.Code = 0
    Failure.Resource = 0
    TryPrepareNativeAppend = True
End Function

' Private bounded loops call this only after admitting/reserving their full
' range. A failed append preserves the earlier prefix and poisons the module.
Private Function TryAppendNativeReservedByte(ByRef State As NativeOutput, ByRef Usage As NativeUsage, ByVal Value As Byte, ByRef Failure As NativeFailure) As Boolean
    TryAppendNativeReservedByte = False
    Call ResetNativeFailure(Failure)
    If TryAppendByte(State.Buffer, Value) = False Then
        TryAppendNativeReservedByte = FailNativeOutput(State.Status, Failure, 1502, 1)
        Exit Function
    End If
    State.Length = State.Length + 1
    Usage.LLVMBytes = Usage.LLVMBytes + 1
    Failure.Code = 0
    TryAppendNativeReservedByte = True
End Function

Function TryAppendNativeByte(ByRef State As NativeOutput, ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByVal Value As Byte, ByRef Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryAppendNativeByte = False
    Call ResetNativeFailure(Failure)
    If TryPrepareNativeAppend(State, Limits, Usage, 1, Cancellation, Failure) = False Then
        Exit Function
    End If
    Call ResetNativeFailure(Failure)
    TryAppendNativeByte = TryAppendNativeReservedByte(State, Usage, Value, Failure)
End Function

' Fixed LLVM ASCII snippets only; source spellings use the counted byte path.
' The existing bootstrap String helpers borrow the fixed literal. This routine
' neither concatenates Strings nor builds a second generated-module buffer.
Function TryAppendNativeAscii(ByRef State As NativeOutput, ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByVal Value As String, ByRef Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryAppendNativeAscii = False
    Dim Count As Long = StringLength(Value)
    If Count > 65536 Then
        TryAppendNativeAscii = FailNativeOutput(State.Status, Failure, 1509, 0)
        Exit Function
    End If
    Call ResetNativeFailure(Failure)
    If TryPrepareNativeAppend(State, Limits, Usage, Count, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Index As Long = 0
    While Index < Count
        Dim Current As Long = StringByteAt(Value, Index)
        If Current < 0 Or Current > 127 Then
            TryAppendNativeAscii = FailNativeOutput(State.Status, Failure, 1509, 0)
            Exit Function
        End If
        Call ResetNativeFailure(Failure)
        If TryAppendNativeReservedByte(State, Usage, Current, Failure) = False Then
            Exit Function
        End If
        Index = Index + 1
    Wend
    TryAppendNativeAscii = True
End Function

Function TryAppendNativeInteger(ByRef State As NativeOutput, ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByVal Value As LongLong, ByRef Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryAppendNativeInteger = False
    Dim Encoder As DecimalIntegerEncoder
    Dim Count As Long = 0
    Call BeginDecimalIntegerEncoding(Value, Encoder, Count)
    Call ResetNativeFailure(Failure)
    If TryPrepareNativeAppend(State, Limits, Usage, Count, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Index As Long = 0
    While Index < Count
        Dim Current As Byte = 0
        Dim HasByte As Boolean = False
        If TryNextDecimalIntegerByte(Encoder, Current, HasByte) = False Or HasByte = False Then
            TryAppendNativeInteger = FailNativeOutput(State.Status, Failure, 1509, 0)
            Exit Function
        End If
        Call ResetNativeFailure(Failure)
        If TryAppendNativeReservedByte(State, Usage, Current, Failure) = False Then
            Exit Function
        End If
        Index = Index + 1
    Wend
    TryAppendNativeInteger = True
End Function

' Source is borrowed immutable bytes. No source or whole-module copy occurs
' here; the Core range append copies only the exact requested emitted bytes.
Function TryAppendNativeRange(ByRef State As NativeOutput, ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByRef Source() As Byte, ByVal Start As Long, ByVal Count As Long, ByRef Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryAppendNativeRange = False
    Call ResetNativeFailure(Failure)
    Dim Available As Long = ByteStorageLength(Source)
    If Start < 0 Or Count < 0 Or Start > Available Then
        Exit Function
    End If
    If Count > Available - Start Then
        Exit Function
    End If
    Call ResetNativeFailure(Failure)
    If TryPrepareNativeAppend(State, Limits, Usage, Count, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim AtByte As Long = 0
    While AtByte < Count
        Call ResetNativeFailure(Failure)
        If TryContinueNativeOutput(Cancellation, Failure) = False Then
            State.Status = 4
            Exit Function
        End If
        Dim Chunk As Long = Count - AtByte
        If Chunk > 65536 Then
            Chunk = 65536
        End If
        Call ResetNativeFailure(Failure)
        If TryAppendBytes(State.Buffer, Source, Start + AtByte, Chunk) = False Then
            TryAppendNativeRange = FailNativeOutput(State.Status, Failure, 1502, 1)
            Exit Function
        End If
        State.Length = State.Length + Chunk
        Usage.LLVMBytes = Usage.LLVMBytes + Chunk
        AtByte = AtByte + Chunk
    Wend
    Failure.Code = 0
    TryAppendNativeRange = True
End Function

Function TrySnapshotNativeModule(ByRef State As NativeOutput, ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByRef Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TrySnapshotNativeModule = False
    Call ResetNativeFailure(Failure)
    If State.Status <> 1 Or State.SnapshotLength <> 0 Then
        Exit Function
    End If
    Call ResetNativeFailure(Failure)
    If TryContinueNativeOutput(Cancellation, Failure) = False Then
        State.Status = 4
        Exit Function
    End If
    Dim Bytes As LongLong = State.Length
    If TryChargeNativeResource(Limits, Usage, 1, Bytes * 2, Failure) = False Then
        State.Status = 4
        Exit Function
    End If
    Dim Cleanup As NativeFailure
    Call ResetNativeFailure(Failure)
    If TrySnapshotByteBuffer(State.Buffer, State.Snapshot) = False Then
        Call TryReleaseNativeResource(Usage, 1, Bytes * 2, Cleanup)
        TrySnapshotNativeModule = FailNativeOutput(State.Status, Failure, 1502, 1)
        Exit Function
    End If
    State.SnapshotLength = State.Length
    State.Status = 2
    Call TryReleaseNativeResource(Usage, 1, Bytes, Cleanup)
    Call ResetNativeFailure(Failure)
    If TryContinueNativeOutput(Cancellation, Failure) = False Then
        State.Status = 4
        Exit Function
    End If
    TrySnapshotNativeModule = True
End Function

' Writes only an already-owned temporary token. The enclosing build owns close
' and its separate cleanup failure on every path. Failed/zero progress abandons
' this module; no output token is opened, reopened or published here.
Function TryWriteNativeModule(ByRef State As NativeOutput, ByVal Token As Long, ByRef Cancellation As SourceCancellation, ByRef Failure As NativeFailure, ByRef FileFailure As Long) As Boolean
    TryWriteNativeModule = False
    Call ResetNativeFailure(Failure)
    FileFailure = 0
    If State.Status <> 2 Then
        Exit Function
    End If
    Dim AtByte As Long = 0
    While AtByte < State.SnapshotLength
        Call ResetNativeFailure(Failure)
        If TryContinueNativeOutput(Cancellation, Failure) = False Then
            State.Status = 4
            Exit Function
        End If
        Dim Count As Long = State.SnapshotLength - AtByte
        If Count > 65536 Then
            Count = 65536
        End If
        Dim Written As Long = 0
        Call ResetNativeFailure(Failure)
        FileFailure = 8
        If TryWriteByteFile(Token, State.Snapshot, AtByte, Count, Written, FileFailure) = False Then
            TryWriteNativeModule = FailNativeOutput(State.Status, Failure, 1508, 0)
            Exit Function
        End If
        If Written <= 0 Or Written > Count Then
            FileFailure = 15
            TryWriteNativeModule = FailNativeOutput(State.Status, Failure, 1508, 0)
            Exit Function
        End If
        AtByte = AtByte + Written
    Wend
    Call ResetNativeFailure(Failure)
    If TryContinueNativeOutput(Cancellation, Failure) = False Then
        State.Status = 4
        Exit Function
    End If
    FileFailure = 8
    If TryFlushByteFile(Token, FileFailure) = False Then
        TryWriteNativeModule = FailNativeOutput(State.Status, Failure, 1508, 0)
        Exit Function
    End If
    Call ResetNativeFailure(Failure)
    If TryContinueNativeOutput(Cancellation, Failure) = False Then
        State.Status = 4
        Exit Function
    End If
    State.Status = 5
    TryWriteNativeModule = True
End Function

' Cleanup is deliberately independent of cancellation. Ownership charges end
' only after the corresponding Core release succeeds; a failure is retryable.
Function TryReleaseNativeSnapshot(ByRef State As NativeOutput, ByRef Usage As NativeUsage, ByRef Failure As NativeFailure) As Boolean
    TryReleaseNativeSnapshot = False
    Call ResetNativeFailure(Failure)
    If State.Status <> 2 And State.Status <> 4 And State.Status <> 5 Then
        Exit Function
    End If
    If TryResizeByteStorage(State.Snapshot, 0, False) = False Then
        Failure.Code = 1502
        Failure.Resource = 1
        Exit Function
    End If
    If TryReleaseNativeResource(Usage, 1, State.SnapshotLength, Failure) = False Then
        Exit Function
    End If
    State.SnapshotLength = 0
    If State.Status = 2 Or State.Status = 5 Then
        State.Status = 3
    End If
    TryReleaseNativeSnapshot = True
End Function

Function TryDisposeNativeOutput(ByRef State As NativeOutput, ByRef Usage As NativeUsage, ByRef Failure As NativeFailure) As Boolean
    TryDisposeNativeOutput = False
    Call ResetNativeFailure(Failure)
    If State.Status = 2 Or State.Status = 4 Or State.Status = 5 Then
        Call ResetNativeFailure(Failure)
        If TryReleaseNativeSnapshot(State, Usage, Failure) = False Then
            Exit Function
        End If
    End If
    Call ResetNativeFailure(Failure)
    If TryReleaseByteBuffer(State.Buffer) = False Then
        Failure.Code = 1502
        Failure.Resource = 1
        Exit Function
    End If
    If TryReleaseNativeResource(Usage, 1, State.Capacity, Failure) = False Then
        Exit Function
    End If
    State.Capacity = 0
    State.Length = 0
    State.Status = 0
    TryDisposeNativeOutput = True
End Function
