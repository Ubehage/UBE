UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeResources"

' Compiler-owned accounting selected by NATIVE-RESOURCE-CONTRACT.md.
' These scalar records contain no managed owner. Borrow them ByRef; each build
' has one writer. Admission reserves before an operation, and release follows
' the end of ownership, not collection or an assumed return of physical memory.
' Categories: 1 lowering-storage, 2 generated-bytes, 3 target-symbols,
' 4 pending-work, 5 lowering-work, 6 structural-depth, 7 debug-information,
' 8 candidate-bytes. NativeInspection owns the byte/event ledger for token 7.
' Native failure Code=0 means success; 1502 is a configured resource rejection,
' 1509 is an invalid internal request. Success never clears the runtime Err.
Type NativeFailure
    Code As Long
    Resource As Long
End Type

Type NativeLimits
    MaximumPayload As LongLong
    MaximumLLVMBytes As LongLong
    MaximumIdentities As LongLong
    MaximumPending As LongLong
    MaximumWork As LongLong
    MaximumDepth As LongLong
    MaximumCandidateBytes As LongLong
End Type

Type NativeUsage
    Payload As LongLong
    PeakPayload As LongLong
    LLVMBytes As LongLong
    Identities As LongLong
    Pending As LongLong
    PeakPending As LongLong
    Work As LongLong
    Depth As LongLong
    PeakDepth As LongLong
End Type

Sub DefaultNativeLimits(ByRef Limits As NativeLimits)
    Limits.MaximumPayload = 1073741824
    Limits.MaximumLLVMBytes = 268435456
    Limits.MaximumIdentities = 4194304
    Limits.MaximumPending = 1048576
    Limits.MaximumWork = 268435456
    Limits.MaximumDepth = 256
    Limits.MaximumCandidateBytes = 268435456
End Sub

Sub ResetNativeFailure(ByRef Failure As NativeFailure)
    Failure.Code = 1509
    Failure.Resource = 0
End Sub

Function ValidNativeLimits(ByRef Limits As NativeLimits) As Boolean
    ValidNativeLimits = Limits.MaximumPayload >= 0 And Limits.MaximumLLVMBytes >= 0 And Limits.MaximumIdentities >= 0 And Limits.MaximumPending >= 0 And Limits.MaximumWork >= 0 And Limits.MaximumDepth >= 0 And Limits.MaximumCandidateBytes >= 0
End Function

' A rejection preserves every usage field. Checked subtraction precedes addition
' even at LongLong's maximum, so resource accounting itself cannot overflow.
' Amount counts actual work/capacity at its caller; it is not an input-size
' estimate. Only payload, pending entries and active depth may later be released.
Function TryChargeNativeResource(ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByVal Category As Long, ByVal Amount As LongLong, ByRef Failure As NativeFailure) As Boolean
    TryChargeNativeResource = False
    Call ResetNativeFailure(Failure)
    If ValidNativeLimits(Limits) = False Or Amount < 0 Then
        Exit Function
    End If
    Dim Maximum As LongLong = 0
    Dim Current As LongLong = 0
    If Category < 1 Or Category > 6 Then
        Exit Function
    End If
    If Category = 1 Then
        Maximum = Limits.MaximumPayload
        Current = Usage.Payload
    End If
    If Category = 2 Then
        Maximum = Limits.MaximumLLVMBytes
        Current = Usage.LLVMBytes
    End If
    If Category = 3 Then
        Maximum = Limits.MaximumIdentities
        Current = Usage.Identities
    End If
    If Category = 4 Then
        Maximum = Limits.MaximumPending
        Current = Usage.Pending
    End If
    If Category = 5 Then
        Maximum = Limits.MaximumWork
        Current = Usage.Work
    End If
    If Category = 6 Then
        Maximum = Limits.MaximumDepth
        Current = Usage.Depth
    End If
    If Current < 0 Then
        Exit Function
    End If
    Failure.Code = 1502
    Failure.Resource = Category
    If Current > Maximum Then
        Exit Function
    End If
    If Amount > Maximum - Current Then
        Exit Function
    End If
    Dim Prepared As LongLong = Current + Amount
    If Category = 1 Then
        Usage.Payload = Prepared
        If Prepared > Usage.PeakPayload Then
            Usage.PeakPayload = Prepared
        End If
    End If
    If Category = 2 Then
        Usage.LLVMBytes = Prepared
    End If
    If Category = 3 Then
        Usage.Identities = Prepared
    End If
    If Category = 4 Then
        Usage.Pending = Prepared
        If Prepared > Usage.PeakPending Then
            Usage.PeakPending = Prepared
        End If
    End If
    If Category = 5 Then
        Usage.Work = Prepared
    End If
    If Category = 6 Then
        Usage.Depth = Prepared
        If Prepared > Usage.PeakDepth Then
            Usage.PeakDepth = Prepared
        End If
    End If
    Failure.Code = 0
    Failure.Resource = 0
    TryChargeNativeResource = True
End Function

' End a live ownership charge. Invalid releases preserve accounting and return
' the internal failure; cumulative output/identity/work counts cannot be undone.
Function TryReleaseNativeResource(ByRef Usage As NativeUsage, ByVal Category As Long, ByVal Amount As LongLong, ByRef Failure As NativeFailure) As Boolean
    TryReleaseNativeResource = False
    Call ResetNativeFailure(Failure)
    If Amount < 0 Then
        Exit Function
    End If
    Dim Current As LongLong = 0
    If Category <> 1 And Category <> 4 And Category <> 6 Then
        Exit Function
    End If
    If Category = 1 Then
        Current = Usage.Payload
    End If
    If Category = 4 Then
        Current = Usage.Pending
    End If
    If Category = 6 Then
        Current = Usage.Depth
    End If
    If Current < 0 Or Amount > Current Then
        Exit Function
    End If
    If Category = 1 Then
        Usage.Payload = Current - Amount
    End If
    If Category = 4 Then
        Usage.Pending = Current - Amount
    End If
    If Category = 6 Then
        Usage.Depth = Current - Amount
    End If
    Failure.Code = 0
    Failure.Resource = 0
    TryReleaseNativeResource = True
End Function

' Post-write admission only. The contained tool must have stopped writing.
' This does not reserve disk space or constrain a tool's temporary disk usage.
Function TryAdmitNativeCandidateLength(ByRef Limits As NativeLimits, ByVal Length As LongLong, ByRef Failure As NativeFailure) As Boolean
    TryAdmitNativeCandidateLength = False
    Call ResetNativeFailure(Failure)
    If ValidNativeLimits(Limits) = False Or Length < 0 Then
        Exit Function
    End If
    If Length > Limits.MaximumCandidateBytes Then
        Failure.Code = 1502
        Failure.Resource = 8
        Exit Function
    End If
    Failure.Code = 0
    Failure.Resource = 0
    TryAdmitNativeCandidateLength = True
End Function
