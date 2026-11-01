Function EqualBytePathTestBytes(ByRef LeftBytes() As Byte, ByRef RightBytes() As Byte) As Boolean
    EqualBytePathTestBytes = False
    Dim Count As Long = ByteStorageLength(LeftBytes)
    If Count <> ByteStorageLength(RightBytes) Then
        Exit Function
    End If
    Dim Index As Long = 0
    While Index < Count
        If LeftBytes(Index) <> RightBytes(Index) Then
            Exit Function
        End If
        Index = Index + 1
    Wend
    EqualBytePathTestBytes = True
End Function

Function CheckBytePathCase(ByVal Resolve As Boolean, ByRef BaseBytes() As Byte, ByRef InputBytes() As Byte, ByRef Expected() As Byte, ByVal ExpectedParents As Long, ByVal ExpectedFailure As Long) As Boolean
    CheckBytePathCase = False
    Dim OriginalInput() As Byte
    Dim OriginalBase() As Byte
    If TryCopyByteStorage(OriginalInput, InputBytes) = False Then
        Exit Function
    End If
    If TryCopyByteStorage(OriginalBase, BaseBytes) = False Then
        Exit Function
    End If
    Dim OutputBytes() As Byte
    If TryResizeByteStorage(OutputBytes, 2, False) = False Then
        Exit Function
    End If
    OutputBytes(0) = 77
    OutputBytes(1) = 78
    Dim Failure As Long = 8
    Dim Parents As Long = 0
    Call RecordErrorNumber(91)
    Dim Succeeded As Boolean = False
    If Resolve Then
        Succeeded = TryResolvePathBytes(BaseBytes, InputBytes, OutputBytes, Failure)
    Else
        Succeeded = TryNormalizeRelativePathBytes(InputBytes, OutputBytes, Parents, Failure)
    End If
    If Failure <> ExpectedFailure Then
        Exit Function
    End If
    If ExpectedFailure = 0 Then
        If Succeeded = False Or Parents <> ExpectedParents Or ReadBytePathTestError() <> 91 Then
            Exit Function
        End If
        If EqualBytePathTestBytes(OutputBytes, Expected) = False Then
            Exit Function
        End If
    Else
        If Succeeded Or Parents <> 0 Then
            Exit Function
        End If
        Dim ExpectedError As Long = 5
        If ExpectedFailure = 4 Then
            ExpectedError = 6
        End If
        If ReadBytePathTestError() <> ExpectedError Then
            Exit Function
        End If
        If ByteStorageLength(OutputBytes) <> 2 Then
            Exit Function
        End If
        If OutputBytes(0) <> 77 Or OutputBytes(1) <> 78 Then
            Exit Function
        End If
    End If
    If EqualBytePathTestBytes(InputBytes, OriginalInput) = False Or EqualBytePathTestBytes(BaseBytes, OriginalBase) = False Then
        Exit Function
    End If
    If ByteStorageLength(OutputBytes) > 0 Then
        OutputBytes(0) = 99
    End If
    If EqualBytePathTestBytes(InputBytes, OriginalInput) = False Or EqualBytePathTestBytes(BaseBytes, OriginalBase) = False Then
        Exit Function
    End If
    CheckBytePathCase = True
End Function
' Test-only observer replaced with the existing native Err getter by the
' harness after raw LLVM equality. No language binding is added for this test.
Function ReadBytePathTestError() As Long
    ReadBytePathTestError = 0
End Function

' Build large inputs at runtime, keeping fixture size independent of the bounds.
Function CheckBytePathLimits() As Boolean
    CheckBytePathLimits = False
    Dim BaseBytes() As Byte
    Dim InputBytes() As Byte
    Dim Expected() As Byte
    Dim Index As Long = 0
    If TryResizeByteStorage(InputBytes, 32767, False) = False Then
        Exit Function
    End If
    While Index < 32767
        InputBytes(Index) = 97
        Index = Index + 1
    Wend
    If TryCopyByteStorage(Expected, InputBytes) = False Then
        Exit Function
    End If
    If CheckBytePathCase(False, BaseBytes, InputBytes, Expected, 0, 0) = False Then
        Exit Function
    End If
    If TryResizeByteStorage(InputBytes, 32768, True) = False Then
        Exit Function
    End If
    InputBytes(32767) = 97
    If CheckBytePathCase(False, BaseBytes, InputBytes, Expected, 0, 4) = False Then
        Exit Function
    End If
    If TryResizeByteStorage(InputBytes, 98301, False) = False Then
        Exit Function
    End If
    Index = 0
    While Index < 98301
        InputBytes(Index) = 231
        InputBytes(Index + 1) = 149
        InputBytes(Index + 2) = 140
        Index = Index + 3
    Wend
    If TryCopyByteStorage(Expected, InputBytes) = False Then
        Exit Function
    End If
    If CheckBytePathCase(False, BaseBytes, InputBytes, Expected, 0, 0) = False Then
        Exit Function
    End If
    If TryResizeByteStorage(InputBytes, 98304, True) = False Then
        Exit Function
    End If
    InputBytes(98301) = 231
    InputBytes(98302) = 149
    InputBytes(98303) = 140
    If CheckBytePathCase(False, BaseBytes, InputBytes, Expected, 0, 4) = False Then
        Exit Function
    End If
    If TryResizeByteStorage(InputBytes, 65533, False) = False Then
        Exit Function
    End If
    Index = 0
    While Index < 65532
        InputBytes(Index) = 240
        InputBytes(Index + 1) = 159
        InputBytes(Index + 2) = 152
        InputBytes(Index + 3) = 128
        Index = Index + 4
    Wend
    InputBytes(65532) = 97
    If TryCopyByteStorage(Expected, InputBytes) = False Then
        Exit Function
    End If
    If CheckBytePathCase(False, BaseBytes, InputBytes, Expected, 0, 0) = False Then
        Exit Function
    End If
    If TryResizeByteStorage(InputBytes, 65534, True) = False Then
        Exit Function
    End If
    InputBytes(65533) = 97
    If CheckBytePathCase(False, BaseBytes, InputBytes, Expected, 0, 4) = False Then
        Exit Function
    End If
    If TryResizeByteStorage(InputBytes, 131068, False) = False Then
        Exit Function
    End If
    InputBytes(0) = 255
    If CheckBytePathCase(False, BaseBytes, InputBytes, Expected, 0, 2) = False Then
        Exit Function
    End If
    If TryResizeByteStorage(InputBytes, 131069, False) = False Then
        Exit Function
    End If
    If CheckBytePathCase(False, BaseBytes, InputBytes, Expected, 0, 4) = False Then
        Exit Function
    End If
    If TryResizeByteStorage(BaseBytes, 3, False) = False Then
        Exit Function
    End If
    BaseBytes(0) = 67
    BaseBytes(1) = 58
    BaseBytes(2) = 47
    If TryResizeByteStorage(InputBytes, 32764, False) = False Then
        Exit Function
    End If
    If TryResizeByteStorage(Expected, 32767, False) = False Then
        Exit Function
    End If
    Expected(0) = 67
    Expected(1) = 58
    Expected(2) = 47
    Index = 0
    While Index < 32764
        InputBytes(Index) = 97
        Expected(Index + 3) = 97
        Index = Index + 1
    Wend
    If CheckBytePathCase(True, BaseBytes, InputBytes, Expected, 0, 0) = False Then
        Exit Function
    End If
    If TryResizeByteStorage(InputBytes, 32765, True) = False Then
        Exit Function
    End If
    InputBytes(32764) = 97
    If CheckBytePathCase(True, BaseBytes, InputBytes, Expected, 0, 4) = False Then
        Exit Function
    End If
    CheckBytePathLimits = True
End Function

