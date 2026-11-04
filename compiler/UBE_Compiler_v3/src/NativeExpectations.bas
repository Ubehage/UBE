UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeExpectations"

Type NativeExpectedDefinition
    Name As NativeObjectName
    UnitKind As Long
    SourceId As Long
    DeclarationId As Long
    Family As Long
    RequireObject As Long
    StorageBytes As Long
    TypeId As Long
    Representation As Long
End Type
Type NativeExpectedDefinitions
    Rows() As NativeExpectedDefinition
    Names() As Byte
    Capacity As Long
    Count As Long
    NameCapacity As Long
    NameLength As Long
    SourceCount As Long
    Status As Long
End Type
Intrinsic Function NativeExpectedRowsLength(ByRef Values() As NativeExpectedDefinition) As Long
Attribute NativeExpectedRowsLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function NativeExpectedTargetsLength(ByRef Values() As NativeDeclarationTarget) As Long
Attribute NativeExpectedTargetsLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function TryResizeNativeExpectedRows(ByRef Values() As NativeExpectedDefinition, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeNativeExpectedRows.UBE_Primitive = "Array.TryResize"
End Function
Private Function NativeExpectedPrefix(ByVal Family As Long) As String
    NativeExpectedPrefix = ""
    If Family = 1 Then
        NativeExpectedPrefix = "ube.f"
    End If
    If Family = 2 Then
        NativeExpectedPrefix = "ube.g"
    End If
    If Family = 3 Then
        NativeExpectedPrefix = "ube.module.init"
    End If
    If Family = 4 Then
        NativeExpectedPrefix = "ube.stack.admit"
    End If
    If Family = 5 Then
        NativeExpectedPrefix = "ube.module.require"
    End If
    If Family = 6 Then
        NativeExpectedPrefix = "ube.module.initialize"
    End If
    If Family = 7 Then
        NativeExpectedPrefix = "ube.program.run"
    End If
    If Family = 8 Then
        NativeExpectedPrefix = "main"
    End If
    If Family = 9 Then
        NativeExpectedPrefix = "ube.module.states"
    End If
    If Family = 10 Then
        NativeExpectedPrefix = "ube.module.failed"
    End If
    If Family = 11 Then
        NativeExpectedPrefix = "ube.module.initializers"
    End If
    If Family = 12 Then
        NativeExpectedPrefix = "ube.stack.floor"
    End If
    If Family = 13 Then
        NativeExpectedPrefix = "ube.stack.initialize"
    End If
    If Family = 14 Then
        NativeExpectedPrefix = "ube.stack.abort"
    End If
    If Family = 15 Then
        NativeExpectedPrefix = "ube.module.wait"
    End If
    If Family = 16 Then
        NativeExpectedPrefix = "ube.stack.reserve"
    End If
    If Family = 17 Then
        NativeExpectedPrefix = "ube.stack.frames"
    End If
    If Family = 18 Then
        NativeExpectedPrefix = "ube_err_set"
    End If
    If Family = 19 Then
        NativeExpectedPrefix = "ube_err_set_stack_exhausted"
    End If
    If Family = 20 Then
        NativeExpectedPrefix = "ube_err_number"
    End If
    If Family = 21 Then
        NativeExpectedPrefix = "ube_err_clear"
    End If
    If Family = 22 Then
        NativeExpectedPrefix = "ube_thread_error"
    End If
    If Family = 23 Then
        NativeExpectedPrefix = "ube.error.if"
    End If
End Function

Private Function TryAppendNativeExpected(ByRef State As NativeExpectedDefinitions, ByRef Row As NativeExpectedDefinition, ByVal Identity As LongLong, ByRef Inspection As NativeInspection, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryAppendNativeExpected = False
    Call ResetNativeFailure(Failure)
    If State.Status <> 4 Or State.Count < 0 Or State.Count >= State.Capacity Or Row.Family < 1 Or Row.Family > 23 Then
        Exit Function
    End If
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    Call ResetNativeFailure(Failure)
    Dim Prefix As String = NativeExpectedPrefix(Row.Family)
    Dim PrefixLength As Long = StringLength(Prefix)
    Dim Encoder As DecimalIntegerEncoder
    Dim Digits As Long = 0
    If Row.Family <= 3 Then
        If Identity < 0 Then
            Exit Function
        End If
        Call BeginDecimalIntegerEncoding(Identity, Encoder, Digits)
    Else
        If Identity <> 0 Then
            Exit Function
        End If
    End If
    Call ResetNativeFailure(Failure)
    Dim Length As Long = PrefixLength + Digits
    If PrefixLength < 1 Or Length > 48 Or State.NameLength < 0 Or State.NameLength > State.NameCapacity Then
        Exit Function
    End If
    If Length > State.NameCapacity - State.NameLength Then
        Exit Function
    End If
    Row.Name.First = State.NameLength
    Row.Name.Count = Length
    Dim Index As Long = 0
    While Index < Length
        Call ResetNativeFailure(Failure)
        If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim Value As Byte = 0
        If Index < PrefixLength Then
            Dim Current As Long = StringByteAt(Prefix, Index)
            Call ResetNativeFailure(Failure)
            If Current < 1 Or Current > 127 Then
                Exit Function
            End If
            Value = Current
        Else
            Dim HasByte As Boolean = False
            Call ResetNativeFailure(Failure)
            If TryNextDecimalIntegerByte(Encoder, Value, HasByte) = False Or HasByte = False Then
                Exit Function
            End If
        End If
        State.Names(State.NameLength) = Value
        State.NameLength = State.NameLength + 1
        Index = Index + 1
    Wend
    State.Rows(State.Count) = Row
    State.Count = State.Count + 1
    Failure.Code = 0
    Failure.Resource = 0
    TryAppendNativeExpected = True
End Function

Function TryPrepareNativeExpectations(ByRef State As NativeExpectedDefinitions, ByRef Declarations As NativeDeclarationPlan, ByVal SourceCount As Long, ByVal MainDeclaration As Long, ByRef Inspection As NativeInspection, ByRef Storage As NativeInspectionStorage, ByRef Limits As NativeLimits, ByRef Usage As NativeUsage, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryPrepareNativeExpectations = False
    Call ResetNativeFailure(Failure)
    If State.Status <> 0 Or State.Capacity <> 0 Or State.Count <> 0 Or State.NameCapacity <> 0 Or State.NameLength <> 0 Or State.SourceCount <> 0 Then
        Exit Function
    End If
    If NativeExpectedRowsLength(State.Rows) <> 0 Or ByteStorageLength(State.Names) <> 0 Or Declarations.Status <> 1 Then
        Exit Function
    End If
    If SourceCount < 1 Or Declarations.Count < SourceCount Or Declarations.Count <> NativeExpectedTargetsLength(Declarations.Targets) Or MainDeclaration < SourceCount Or MainDeclaration >= Declarations.Count Or Declarations.FrameCount < 1 Or Declarations.FrameCount > Declarations.Count Then
        Exit Function
    End If
    Dim Capacity As LongLong = SourceCount
    Capacity = Capacity * 3 + Declarations.Count + 19
    Dim FrameBytes As LongLong = Declarations.FrameCount
    FrameBytes = (FrameBytes + SourceCount + 1) * 8
    Failure.Code = 1502
    Failure.Resource = 7
    If Capacity > 44739242 Or FrameBytes > 2147483647 Then
        Exit Function
    End If
    State.Status = 4
    State.SourceCount = SourceCount
    Call ResetNativeFailure(Failure)
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReserveNativeInspectionStorage(Storage, Limits, Usage, Capacity * 40, Failure) = False Then
        Exit Function
    End If
    Dim Cleanup As NativeFailure
    If TryResizeNativeExpectedRows(State.Rows, Capacity, False) = False Then
        Call TryReleaseNativeInspectionStorage(Storage, Usage, Capacity * 40, Cleanup)
        Failure.Code = 1502
        Failure.Resource = 7
        Exit Function
    End If
    State.Capacity = Capacity
    Call ResetNativeFailure(Failure)
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReserveNativeInspectionStorage(Storage, Limits, Usage, Capacity * 48, Failure) = False Then
        Exit Function
    End If
    If TryResizeByteStorage(State.Names, Capacity * 48, False) = False Then
        Call TryReleaseNativeInspectionStorage(Storage, Usage, Capacity * 48, Cleanup)
        Failure.Code = 1502
        Failure.Resource = 7
        Exit Function
    End If
    State.NameCapacity = Capacity * 48
    Dim Empty As NativeExpectedDefinition
    Dim Id As Long = 0
    Dim FoundMain As Boolean = False
    While Id < Declarations.Count
        Call ResetNativeFailure(Failure)
        If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
            Exit Function
        End If
        Call ResetNativeFailure(Failure)
        If TryVisitNativeIndex(Limits, Usage, Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim Target As NativeDeclarationTarget
        Call ReadNativeDeclarationTarget(Target, Declarations.Targets(Id))
        Call ResetNativeFailure(Failure)
        If Target.Kind < 1 Or Target.Kind > 7 Or Target.SourceId < 0 Or Target.SourceId >= SourceCount Then
            Exit Function
        End If
        Dim Row As NativeExpectedDefinition
        Row = Empty
        Row.SourceId = Target.SourceId
        Row.DeclarationId = Id
        Row.TypeId = Target.TypeId
        Row.Representation = Target.Representation
        If Id < SourceCount Then
            If Target.Kind <> 1 Or Target.SourceId <> Id Or Target.Scope <> -1 Then
                Exit Function
            End If
            Row.Family = 3
            Row.RequireObject = 1
            If TryAppendNativeExpected(State, Row, Id, Inspection, Cancellation, Failure) = False Then
                Exit Function
            End If
            Row.DeclarationId = -1
            Row.RequireObject = 0
            Row.Family = 4
            If TryAppendNativeExpected(State, Row, 0, Inspection, Cancellation, Failure) = False Then
                Exit Function
            End If
            Row.Family = 5
            If TryAppendNativeExpected(State, Row, 0, Inspection, Cancellation, Failure) = False Then
                Exit Function
            End If
            Row.Family = 23
            If TryAppendNativeExpected(State, Row, 0, Inspection, Cancellation, Failure) = False Then
                Exit Function
            End If
        Else
            If Target.Kind = 1 Or Target.Scope < 0 Or Target.Scope >= Id Then
                Exit Function
            End If
            Dim Identity As LongLong = -1
            If (Target.Kind = 5 Or Target.Kind = 6) And Target.Role = 0 Then
                If Target.Scope <> Target.SourceId Then
                    Exit Function
                End If
                Row.Family = 1
                Identity = Target.ValueIdentity
                If Id = MainDeclaration Then
                    Row.RequireObject = 1
                    FoundMain = True
                End If
            End If
            If Target.Kind = 2 And Target.Scope < SourceCount Then
                If Target.Scope <> Target.SourceId Or Target.Representation < 1 Or Target.Representation > 5 Then
                    Exit Function
                End If
                Row.Family = 2
                Identity = Target.AddressIdentity
                Row.StorageBytes = 1
                If Target.Representation = 3 Then
                    Row.StorageBytes = 2
                End If
                If Target.Representation = 4 Then
                    Row.StorageBytes = 4
                End If
                If Target.Representation = 5 Then
                    Row.StorageBytes = 8
                End If
            End If
            If Row.Family > 0 Then
                If TryAppendNativeExpected(State, Row, Identity, Inspection, Cancellation, Failure) = False Then
                    Exit Function
                End If
            End If
        End If
        Id = Id + 1
    Wend
    Call ResetNativeFailure(Failure)
    If FoundMain = False Then
        Exit Function
    End If
    Dim Family As Long = 4
    While Family <= 22
        Dim Support As NativeExpectedDefinition
        Support = Empty
        Support.Family = Family
        Support.SourceId = -1
        Support.DeclarationId = -1
        Support.UnitKind = 1
        If Family >= 7 Then
            Support.RequireObject = 1
        End If
        If Family = 8 Then
            Support.UnitKind = 2
        End If
        If Family >= 9 And Family <= 11 Then
            Support.UnitKind = 3
            Support.StorageBytes = SourceCount
            If Family = 10 Then
                Support.StorageBytes = 1
            End If
            If Family = 11 Then
                Support.StorageBytes = SourceCount * 8
            End If
        End If
        If Family >= 12 And Family <= 15 Then
            Support.UnitKind = 4
            If Family = 12 Then
                Support.StorageBytes = 8
            End If
        End If
        If Family = 16 Or Family = 17 Then
            Support.UnitKind = 5
            Support.StorageBytes = 8
            If Family = 17 Then
                Support.StorageBytes = FrameBytes
            End If
        End If
        If Family >= 18 Then
            Support.UnitKind = 6
            If Family = 22 Then
                Support.StorageBytes = 784
            End If
        End If
        If TryAppendNativeExpected(State, Support, 0, Inspection, Cancellation, Failure) = False Then
            Exit Function
        End If
        Family = Family + 1
    Wend
    Call ResetNativeFailure(Failure)
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    State.Status = 1
    Failure.Code = 0
    TryPrepareNativeExpectations = True
End Function

Function TryDisposeNativeExpectations(ByRef State As NativeExpectedDefinitions, ByRef Storage As NativeInspectionStorage, ByRef Usage As NativeUsage, ByRef Failure As NativeFailure) As Boolean
    TryDisposeNativeExpectations = False
    Call ResetNativeFailure(Failure)
    If State.Capacity < 0 Or State.NameCapacity < 0 Or NativeExpectedRowsLength(State.Rows) <> State.Capacity Or ByteStorageLength(State.Names) <> State.NameCapacity Then
        Exit Function
    End If
    Dim Payload As LongLong = State.Capacity
    Payload = Payload * 40 + State.NameCapacity
    If Payload > Storage.Payload Or Payload > Usage.Payload Then
        Exit Function
    End If
    State.Status = 4
    If TryResizeByteStorage(State.Names, 0, False) = False Then
        Exit Function
    End If
    If TryReleaseNativeInspectionStorage(Storage, Usage, State.NameCapacity, Failure) = False Then
        Exit Function
    End If
    State.NameCapacity = 0
    Call ResetNativeFailure(Failure)
    If TryResizeNativeExpectedRows(State.Rows, 0, False) = False Then
        Exit Function
    End If
    Payload = State.Capacity
    If TryReleaseNativeInspectionStorage(Storage, Usage, Payload * 40, Failure) = False Then
        Exit Function
    End If
    State.Capacity = 0
    State.Count = 0
    State.NameLength = 0
    State.SourceCount = 0
    State.Status = 0
    Failure.Code = 0
    TryDisposeNativeExpectations = True
End Function
