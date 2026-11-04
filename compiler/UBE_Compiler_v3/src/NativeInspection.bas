UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeInspection"

' Per-candidate scalar budget, borrowed by every object/debug reader. Actual
' read attempts include rereads. Payload ownership remains with the build owner.
Type NativeInspection
    MaximumBytes As LongLong
    MaximumEvents As LongLong
    Bytes As LongLong
    Events As LongLong
End Type

' Shared live parser payload, separately constrained by the global native ledger.
Type NativeInspectionStorage
    MaximumPayload As LongLong
    Payload As LongLong
    PeakPayload As LongLong
End Type

Sub DefaultNativeInspectionStorage(ByRef State As NativeInspectionStorage)
    State.MaximumPayload = 16777216
    State.Payload = 0
    State.PeakPayload = 0
End Sub

Function TryReserveNativeInspectionStorage(ByRef State As NativeInspectionStorage, ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByVal Amount As LongLong, ByRef Failure As NativeFailure) As Boolean
    TryReserveNativeInspectionStorage = False
    Call ResetNativeFailure(Failure)
    If State.MaximumPayload < 0 Or State.Payload < 0 Or Amount < 0 Then
        Exit Function
    End If
    Failure.Code = 1502
    Failure.Resource = 7
    If State.Payload > State.MaximumPayload Then
        Exit Function
    End If
    If Amount > State.MaximumPayload - State.Payload Then
        Exit Function
    End If
    If TryChargeNativeResource(Limits, Usage, 1, Amount, Failure) = False Then
        Exit Function
    End If
    State.Payload = State.Payload + Amount
    If State.Payload > State.PeakPayload Then
        State.PeakPayload = State.Payload
    End If
    Failure.Code = 0
    Failure.Resource = 0
    TryReserveNativeInspectionStorage = True
End Function

' Native byte-equivalence decisions share scalar read admission and diagnostics.
Function TryCompareNativeByteSpan(ByRef LeftBytes() As Byte, ByVal LeftFirst As Long, ByRef RightBytes() As Byte, ByVal RightFirst As Long, ByVal Count As Long, ByRef Inspection As NativeInspection, ByRef Equal As Boolean, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryCompareNativeByteSpan = False
    Call ResetNativeFailure(Failure)
    If Count < 0 Or LeftFirst < 0 Or RightFirst < 0 Or LeftFirst > ByteStorageLength(LeftBytes) Or RightFirst > ByteStorageLength(RightBytes) Then
        Exit Function
    End If
    If Count > ByteStorageLength(LeftBytes) - LeftFirst Or Count > ByteStorageLength(RightBytes) - RightFirst Then
        Exit Function
    End If
    Dim Index As Long = 0
    While Index < Count
        Dim Width As Long = Count - Index
        If Width > 8 Then
            Width = 8
        End If
        Dim Left As LongLong = 0
        Dim Right As LongLong = 0
        If TryReadNativeBits(LeftBytes, Inspection, LeftFirst + Index, Width, Left, Cancellation, Failure) = False Then
            Exit Function
        End If
        If TryReadNativeBits(RightBytes, Inspection, RightFirst + Index, Width, Right, Cancellation, Failure) = False Then
            Exit Function
        End If
        If Left <> Right Then
            Equal = False
            Failure.Code = 0
            Failure.Resource = 0
            TryCompareNativeByteSpan = True
            Exit Function
        End If
        Index = Index + Width
    Wend
    Equal = True
    Failure.Code = 0
    Failure.Resource = 0
    TryCompareNativeByteSpan = True
End Function

Function TryReleaseNativeInspectionStorage(ByRef State As NativeInspectionStorage, ByRef Usage As NativeUsage, ByVal Amount As LongLong, ByRef Failure As NativeFailure) As Boolean
    TryReleaseNativeInspectionStorage = False
    Call ResetNativeFailure(Failure)
    If State.Payload < 0 Or Amount < 0 Or Amount > State.Payload Then
        Exit Function
    End If
    If TryReleaseNativeResource(Usage, 1, Amount, Failure) = False Then
        Exit Function
    End If
    State.Payload = State.Payload - Amount
    TryReleaseNativeInspectionStorage = True
End Function

Sub DefaultNativeInspection(ByRef State As NativeInspection)
    State.MaximumBytes = 67108864
    State.MaximumEvents = 16777216
    State.Bytes = 0
    State.Events = 0
End Sub

Function TryVisitNativeInspection(ByRef State As NativeInspection, ByVal ByteCount As Long, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryVisitNativeInspection = False
    Call ResetNativeFailure(Failure)
    If State.MaximumBytes < 0 Or State.MaximumEvents < 0 Or State.Bytes < 0 Or State.Events < 0 Or ByteCount < 0 Then
        Exit Function
    End If
    If Cancellation Is Nothing Then
    Else
        If Cancellation.Requested Then
            Failure.Code = 1507
            Exit Function
        End If
    End If
    Failure.Code = 1502
    Failure.Resource = 7
    If State.Bytes > State.MaximumBytes Or State.Events >= State.MaximumEvents Then
        Exit Function
    End If
    If ByteCount > State.MaximumBytes - State.Bytes Then
        Exit Function
    End If
    State.Bytes = State.Bytes + ByteCount
    State.Events = State.Events + 1
    Failure.Code = 0
    Failure.Resource = 0
    TryVisitNativeInspection = True
End Function

' Admit before reading. Every scalar read uses the shared event/byte ledger.
Function TryReadNativeBits(ByRef Bytes() As Byte, ByRef State As NativeInspection, ByVal First As Long, ByVal Width As Long, ByRef Value As LongLong, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryReadNativeBits = False
    Call ResetNativeFailure(Failure)
    Dim Length As Long = ByteStorageLength(Bytes)
    Failure.Code = 1506
    If First < 0 Or First > Length Or Width < 1 Or Width > 8 Then
        Exit Function
    End If
    If Width > Length - First Then
        Exit Function
    End If
    If TryVisitNativeInspection(State, Width, Cancellation, Failure) = False Then
        Exit Function
    End If
    Call ResetNativeFailure(Failure)
    If TryReadLittleEndianBits(Bytes, First, Width, Value) = False Then
        Exit Function
    End If
    Failure.Code = 0
    TryReadNativeBits = True
End Function
