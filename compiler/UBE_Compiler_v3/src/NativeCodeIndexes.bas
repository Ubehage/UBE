UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeCodeIndexes"

Type NativeOwnedCode
    UnitKind As Long
    SourceId As Long
    Contribution As NativeRetainedDefinition
End Type
Type NativeCodeIndex
    Keys() As ByteKey
    Bytes() As Byte
    Order() As Long
    KeyCapacity As Long
    ByteCapacity As Long
    OrderCapacity As Long
    Count As Long
    SourceCount As Long
    Status As Long
End Type
Private Intrinsic Function NativeOwnedCodeLength(ByRef Values() As NativeOwnedCode) As Long
Attribute NativeOwnedCodeLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function NativeCodeKeyLength(ByRef Values() As ByteKey) As Long
Attribute NativeCodeKeyLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function NativeCodeOrderLength(ByRef Values() As Long) As Long
Attribute NativeCodeOrderLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function TryResizeNativeCodeKeys(ByRef Values() As ByteKey, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeNativeCodeKeys.UBE_Primitive = "Array.TryResize"
End Function
Private Intrinsic Function TryResizeNativeCodeOrder(ByRef Values() As Long, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeNativeCodeOrder.UBE_Primitive = "Array.TryResize"
End Function

Private Function TryReleaseNativeCodeKeys(ByRef State As NativeCodeIndex, ByRef Storage As NativeInspectionStorage, ByRef Usage As NativeUsage, ByRef Failure As NativeFailure) As Boolean
    TryReleaseNativeCodeKeys = False
    If TryResizeNativeCodeKeys(State.Keys, 0, False) = False Then
        Exit Function
    End If
    Dim Payload As LongLong = State.KeyCapacity
    If TryReleaseNativeInspectionStorage(Storage, Usage, Payload * 16, Failure) = False Then
        Exit Function
    End If
    State.KeyCapacity = 0
    If TryResizeByteStorage(State.Bytes, 0, False) = False Then
        Exit Function
    End If
    Payload = State.ByteCapacity
    If TryReleaseNativeInspectionStorage(Storage, Usage, Payload, Failure) = False Then
        Exit Function
    End If
    State.ByteCapacity = 0
    TryReleaseNativeCodeKeys = True
End Function

Private Function TryReleaseNativeCodeOrder(ByRef State As NativeCodeIndex, ByRef Storage As NativeInspectionStorage, ByRef Usage As NativeUsage, ByRef Failure As NativeFailure) As Boolean
    TryReleaseNativeCodeOrder = False
    If TryResizeNativeCodeOrder(State.Order, 0, False) = False Then
        Exit Function
    End If
    Dim Payload As LongLong = State.OrderCapacity
    If TryReleaseNativeInspectionStorage(Storage, Usage, Payload * 4, Failure) = False Then
        Exit Function
    End If
    State.OrderCapacity = 0
    TryReleaseNativeCodeOrder = True
End Function

Function TryDisposeNativeCodeIndex(ByRef State As NativeCodeIndex, ByRef Storage As NativeInspectionStorage, ByRef Usage As NativeUsage, ByRef Failure As NativeFailure) As Boolean
    TryDisposeNativeCodeIndex = False
    Call ResetNativeFailure(Failure)
    If State.KeyCapacity < 0 Or State.ByteCapacity < 0 Or State.OrderCapacity < 0 Then
        Exit Function
    End If
    If NativeCodeKeyLength(State.Keys) <> State.KeyCapacity Or ByteStorageLength(State.Bytes) <> State.ByteCapacity Or NativeCodeOrderLength(State.Order) <> State.OrderCapacity Then
        Exit Function
    End If
    Dim Payload As LongLong = State.KeyCapacity
    Dim Ordered As LongLong = State.OrderCapacity
    Payload = Payload * 16 + State.ByteCapacity + Ordered * 4
    If Payload > Storage.Payload Or Payload > Usage.Payload Then
        Exit Function
    End If
    State.Status = 4
    If TryReleaseNativeCodeKeys(State, Storage, Usage, Failure) = False Then
        Exit Function
    End If
    If TryReleaseNativeCodeOrder(State, Storage, Usage, Failure) = False Then
        Exit Function
    End If
    State.Count = 0
    State.SourceCount = 0
    State.Status = 0
    Failure.Code = 0
    Failure.Resource = 0
    TryDisposeNativeCodeIndex = True
End Function

Function TryPrepareNativeCodeIndex(ByRef State As NativeCodeIndex, ByRef Contributions() As NativeOwnedCode, ByVal SourceCount As Long, ByRef Inspection As NativeInspection, ByRef Storage As NativeInspectionStorage, ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryPrepareNativeCodeIndex = False
    Call ResetNativeFailure(Failure)
    If State.Status <> 0 Or State.KeyCapacity <> 0 Or State.ByteCapacity <> 0 Or State.OrderCapacity <> 0 Or State.Count <> 0 Or State.SourceCount <> 0 Or SourceCount < 0 Or SourceCount > 2147483641 Then
        Exit Function
    End If
    If NativeCodeKeyLength(State.Keys) <> 0 Or ByteStorageLength(State.Bytes) <> 0 Or NativeCodeOrderLength(State.Order) <> 0 Then
        Exit Function
    End If
    State.Status = 4
    State.Count = NativeOwnedCodeLength(Contributions)
    State.SourceCount = SourceCount
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Position As Long = 0
    Dim ImageBase As LongLong = 0
    While Position < State.Count
        If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim Owned As NativeOwnedCode
        Owned = Contributions(Position)
        Call ResetNativeFailure(Failure)
        If Owned.UnitKind < 0 Or Owned.UnitKind > 6 Or ValidNativeCodeContribution(Owned.Contribution) = False Then
            Exit Function
        End If
        If Owned.UnitKind = 0 Then
            If Owned.SourceId < 0 Or Owned.SourceId >= SourceCount Then
                Exit Function
            End If
        Else
            If Owned.SourceId <> -1 Then
                Exit Function
            End If
        End If
        Dim Base As LongLong = Owned.Contribution.ImageRange.Address - Owned.Contribution.ImageRange.RelativeAddress
        If Position = 0 Then
            ImageBase = Base
        End If
        If Base <> ImageBase Then
            Exit Function
        End If
        Position = Position + 1
    Wend
    Dim Payload As LongLong = State.Count
    Payload = Payload * 16
    Dim Cleanup As NativeFailure
    If TryReserveNativeInspectionStorage(Storage, Limits, Usage, Payload, Failure) = False Then
        Exit Function
    End If
    If TryResizeNativeCodeKeys(State.Keys, State.Count, False) = False Then
        Call TryReleaseNativeInspectionStorage(Storage, Usage, Payload, Cleanup)
        Failure.Code = 1502
        Failure.Resource = 7
        Exit Function
    End If
    State.KeyCapacity = State.Count
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    Payload = State.Count
    If TryReserveNativeInspectionStorage(Storage, Limits, Usage, Payload, Failure) = False Then
        Exit Function
    End If
    If TryResizeByteStorage(State.Bytes, State.Count, False) = False Then
        Call TryReleaseNativeInspectionStorage(Storage, Usage, Payload, Cleanup)
        Failure.Code = 1502
        Failure.Resource = 7
        Exit Function
    End If
    State.ByteCapacity = State.Count
    Dim Domain As Long = 0
    While Domain < 3
        Position = 0
        While Position < State.Count
            If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
                Exit Function
            End If
            Dim Current As NativeOwnedCode
            Current = Contributions(Position)
            Dim Key As ByteKey
            Key.FirstByte = Position
            Key.ByteCount = 1
            Key.Value = Position
            If Domain = 0 Then
                Key.Partition = Current.SourceId
                If Current.UnitKind <> 0 Then
                    Key.Partition = SourceCount + Current.UnitKind - 1
                End If
                State.Bytes(Position) = Current.Contribution.ObjectRange.SectionIndex
            End If
            If Domain = 1 Then
                Key.Partition = Current.Contribution.ImageRange.FileFirst
                Key.ByteCount = 0
            End If
            If Domain = 2 Then
                Key.Partition = Current.Contribution.ImageRange.RelativeAddress \ 2
                State.Bytes(Position) = Current.Contribution.ImageRange.RelativeAddress Mod 2
            End If
            State.Keys(Position) = Key
            Position = Position + 1
        Wend
        If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
            Exit Function
        End If
        If TryReleaseNativeCodeOrder(State, Storage, Usage, Failure) = False Then
            Exit Function
        End If
        Payload = State.Count
        Payload = Payload * 8
        If TryReserveNativeInspectionStorage(Storage, Limits, Usage, Payload, Failure) = False Then
            Exit Function
        End If
        Dim Budget As ByteKeyBudget
        Call ReadNativeKeyBudget(Budget, Inspection)
        Dim Code As Long = 5
        Dim Ordered As Boolean = False
        Dim NeverCancelled As Boolean = False
        If Cancellation Is Nothing Then
            Ordered = TryOrderByteKeysBudgeted(State.Bytes, State.Keys, State.Count, State.KeyCapacity, State.Order, Code, Budget, NeverCancelled)
        Else
            Ordered = TryOrderByteKeysBudgeted(State.Bytes, State.Keys, State.Count, State.KeyCapacity, State.Order, Code, Budget, Cancellation.Requested)
        End If
        Call FinishNativeKeyBudget(Inspection, Budget, Code, Failure)
        If Ordered Then
            State.OrderCapacity = State.Count
            Payload = Payload \ 2
        End If
        If TryReleaseNativeInspectionStorage(Storage, Usage, Payload, Cleanup) = False Then
            Failure = Cleanup
            Exit Function
        End If
        If Ordered = False Then
            Exit Function
        End If
        Position = 0
        While Position < State.Count
            If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
                Exit Function
            End If
            If Position > 0 Then
                Dim Previous As NativeOwnedCode
                Dim Following As NativeOwnedCode
                Previous = Contributions(State.Order(Position - 1))
                Following = Contributions(State.Order(Position))
                Failure.Code = 1506
                If Domain = 0 Then
                    If Previous.UnitKind = Following.UnitKind And Previous.SourceId = Following.SourceId And Previous.Contribution.ObjectRange.SectionIndex = Following.Contribution.ObjectRange.SectionIndex Then
                        Exit Function
                    End If
                End If
                If Domain = 1 Then
                    Dim LastFile As LongLong = Previous.Contribution.ImageRange.FileFirst
                    LastFile = LastFile + Previous.Contribution.ImageRange.ByteCount
                    If LastFile > Following.Contribution.ImageRange.FileFirst Then
                        Exit Function
                    End If
                End If
                If Domain = 2 Then
                    If Previous.Contribution.ImageRange.RelativeAddress + Previous.Contribution.ImageRange.ByteCount > Following.Contribution.ImageRange.RelativeAddress Then
                        Exit Function
                    End If
                End If
            End If
            Position = Position + 1
        Wend
        Domain = Domain + 1
    Wend
    If TryReleaseNativeCodeKeys(State, Storage, Usage, Failure) = False Then
        Exit Function
    End If
    State.Status = 1
    Failure.Code = 0
    Failure.Resource = 0
    TryPrepareNativeCodeIndex = True
End Function
