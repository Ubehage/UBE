UBE SOURCE 1 MODULE
Attribute UBE_Name = "ValuesProbe"
' Executes actual scalar LLVM helpers into privately owned files for independent native assertions.
Private OutputPath() As Byte
Private CatalogPath() As Byte

' Receives separate output and catalog paths for independent emission.
Public Function ConfigurePath(ByVal Kind As Long, ByVal Count As Long) As Boolean
    If Kind = 0 Then ConfigurePath = BufferPrimitives.TryResizeBytes(OutputPath, Count, False)
    If Kind = 1 Then ConfigurePath = BufferPrimitives.TryResizeBytes(CatalogPath, Count, False)
End Function

' Supplies counted UTF-8 path bytes through ordinary source calls.
Public Sub SetPathByte(ByVal Kind As Long, ByVal Index As Long, ByVal Value As Byte)
    If Kind = 0 Then OutputPath(Index) = Value
    If Kind = 1 Then CatalogPath(Index) = Value
End Sub

' Resets one test emission request without accumulating record-copy temporaries in its caller.
Private Sub ResetState(ByRef State As NativeEmission.EmissionState)
    Dim EmptyState As NativeEmission.EmissionState
    State = EmptyState
End Sub

' Checks internal refusal and helper FAIL paths latch unusable output rather than return an SSA identity.
Public Function CheckFailures() As Long
    Dim State As NativeEmission.EmissionState
    Dim Buffer() As Byte
    Dim Catalog() As Byte
    Dim Seen() As Long
    Dim Continuations() As Long
    Dim Token As Long
    Dim Failure As Long
    Dim Value As Long
    On Error GoTo Failed
    If Not FileBytes.TryReadAllBytes(CatalogPath, 1048576, Catalog, Token, Failure) Then CheckFailures = 1: Exit Function
    State.Text.Failed = True
    Value = NativeValues.Complement(State, Buffer, 0, Catalog, Seen, Continuations, 1, SyntaxTokens.KwLong)
    If Value <> 0 Or Not State.Text.Failed Or State.ValueNumber <> 0 Then CheckFailures = 2: Exit Function
    ResetState State
    State.CurrentNode = 1
    Value = NativeValues.ConvertValue(State, Buffer, 0, Catalog, Seen, Continuations, 0, SyntaxTokens.KwLong, SyntaxTokens.KwByte)
    If Value <> 0 Or Not State.Text.Failed Or State.FailureCode <> 9 Or State.FailureReason <> 61 Or State.ErrorNode <> 1 Then CheckFailures = 3: Exit Function
    ResetState State
    State.Work = 10000000
    Value = NativeValues.Complement(State, Buffer, 0, Catalog, Seen, Continuations, 1, SyntaxTokens.KwLongLong)
    If Value <> 0 Or Not State.Text.Failed Or State.FailureCode <> 6 Or State.FailureReason <> 56 Then CheckFailures = 4: Exit Function
    ResetState State
    If Not LLVMWriter.TryInitialize(State.Text, Buffer) Then CheckFailures = 5: Exit Function
    NativeEmission.BeginFunction State, 7, 0, 1, 0, False
    State.ValueNumber = 3
    Value = NativeValues.ConvertValue(State, Buffer, 0, Catalog, Seen, Continuations, 1, SyntaxTokens.KwLong, SyntaxTokens.KwByte)
    If Value <> 0 Or Not State.Text.Failed Or State.FailureCode <> 9 Or State.FailureReason <> 60 Then CheckFailures = 6: Exit Function
    ResetState State
    If Not LLVMWriter.TryInitialize(State.Text, Buffer) Then CheckFailures = 7: Exit Function
    NativeEmission.BeginFunction State, 7, 0, 1, 0, False
    State.ValueNumber = 3
    State.CurrentNode = 1
    Value = NativeValues.ConvertValue(State, Buffer, 0, Catalog, Seen, Continuations, 1, SyntaxTokens.KwLong, SyntaxTokens.KwByte)
    If Value <> 0 Or Not State.Text.Failed Or State.Text.ErrorNumber <> 9 Or State.ErrorNode <> 1 Then CheckFailures = 8: Exit Function
    Exit Function
Failed:
    CheckFailures = 9
End Function

' Emits an instruction fragment and checks the failure-edge bookkeeping used by the eventual dispatcher.
Public Function Emit(ByVal Operation As Long, ByVal SourceType As Long, ByVal DestinationType As Long, ByVal ExpectedGuard As Boolean) As Long
    Dim State As NativeEmission.EmissionState
    Dim Buffer() As Byte
    Dim Catalog() As Byte
    Dim Seen(0 To 0) As Long
    Dim Continuations(0 To 0) As Long
    Dim Token As Long
    Dim Failure As Long
    Dim Value As Long
    Dim Result As Long
    On Error GoTo Failed
    If Not FileBytes.TryReadAllBytes(CatalogPath, 1048576, Catalog, Token, Failure) Then Emit = 1: Exit Function
    If Not LLVMFormat.TryValidateCatalog(Catalog) Then Emit = 2: Exit Function
    If Not FilePrimitives.TryCreateNew(OutputPath, Token, Failure) Then Emit = 3: Exit Function
    If Not LLVMWriter.TryInitialize(State.Text, Buffer) Then Result = 4: GoTo Cleanup
    NativeEmission.BeginFunction State, 7, 0, 1, 0, False
    State.CurrentNode = 1
    State.ValueNumber = 3
    If Operation = 0 Then Value = NativeValues.ConvertValue(State, Buffer, Token, Catalog, Seen, Continuations, 1, SourceType, DestinationType)
    If Operation = 1 Then Value = NativeValues.CheckedArithmetic(State, Buffer, Token, Catalog, Seen, Continuations, 1, 2, SourceType, False)
    If Operation = 2 Then Value = NativeValues.CheckedArithmetic(State, Buffer, Token, Catalog, Seen, Continuations, 1, 2, SourceType, True)
    If Operation = 3 Then Value = NativeValues.Complement(State, Buffer, Token, Catalog, Seen, Continuations, 1, SourceType)
    If Operation = 4 Then Value = NativeEmission.Literal(State, Buffer, Token, Catalog, -9223372036854775808^)
    If Operation = 5 Then Value = NativeEmission.Literal(State, Buffer, Token, Catalog, 9223372036854775807^)
    If Value = 0 Or State.Text.Failed Then Result = 5: GoTo Cleanup
    If ExpectedGuard Then
        If State.FailureCount <> 1 Or Seen(0) <> 7 Or Continuations(0) <> 0 Then Result = 6: GoTo Cleanup
    Else
        If State.FailureCount <> 0 Or Seen(0) <> 0 Or Continuations(0) <> 0 Then Result = 7: GoTo Cleanup
    End If
    If Not NativeEmission.TryLine(State, Buffer, Token, Catalog, LLVMTemplates.StoreValue, Value, 3, 0, 0) Then Result = 8: GoTo Cleanup
    If Not LLVMWriter.TryFinish(State.Text, Buffer, Token) Then Result = 9: GoTo Cleanup
Cleanup:
    If Not FilePrimitives.TryClose(Token, Failure) Then Emit = 10: Exit Function
    Emit = Result
    Exit Function
Failed:
    Result = 11
    GoTo Cleanup
End Function
