UBE SOURCE 1 MODULE
Attribute UBE_Name = "ReadCancellationProbe"
Private Sub CheckRead(ByVal Mode As Long, ByRef Outcome As Long)
    Dim Result() As Byte
    Dim Failure As Long
    Dim Token As Long = 123
    Dim Cancelled As Boolean
    Dim Index As Long
    On Error GoTo Failed
    Outcome = 1
    If Not BufferPrimitives.TryResizeBytes(Result, 1, False) Then Exit Sub
    Result(0) = 99
    FilePrimitives.Mode = Mode
    FilePrimitives.Reads = 0
    FilePrimitives.Closes = 0
    Call FilePrimitives.SetError(55)
    If Mode = 2 Then
        If Not FileBytes.TryReadOpenBytes(Token, 196608, Result, Failure) Then Exit Sub
        If Failure <> 0 Or FilePrimitives.Reads <> 4 Then Exit Sub
        If BufferPrimitives.ByteStorageLength(Result) <> 196608 Then Exit Sub
        For Index = 0 To 196607
            If Result(Index) <> 42 Then Exit Sub
        Next Index
    Else
        If FileBytes.TryReadOpenBytesCancellable(Token, 196608, Result, Failure, Cancelled) Then Exit Sub
        If FilePrimitives.Reads <> 1 Or BufferPrimitives.ByteStorageLength(Result) <> 1 Or Result(0) <> 99 Then Exit Sub
        If Mode = 1 Then
            If Not Cancelled Or Failure <> 0 Or Err.Number <> 55 Then Exit Sub
        Else
            If Cancelled Or Failure <> 23 Or Err.Number <> 57 Then Exit Sub
        End If
    End If
    Outcome = 2
    If Token <> 123 Or FilePrimitives.Closes <> 0 Then Exit Sub
    If Not ThreadPrimitives.StopRequested() Then Exit Sub
    Failure = 104
    Call FilePrimitives.SetError(55)
    If FileBytes.TryClosePreservingError(Token, Failure) Then Exit Sub
    If Token <> 123 Or Failure <> 104 Or Err.Number <> 55 Then Exit Sub
    If Not FileBytes.TryClosePreservingError(Token, Failure) Then Exit Sub
    If Token <> 0 Or Failure <> 104 Or Err.Number <> 55 Then Exit Sub
    Outcome = 0
    Exit Sub
Failed:
    Outcome = 99
End Sub
Public Function Main() As Long
    Dim Mode As Long
    Dim Outcome As Long
    Dim Worker As LongLong
    Call FilePrimitives.SetError(77)
    For Mode = 1 To 3
        Worker = CallNew CheckRead(Mode, Outcome)
        If ThreadPrimitives.Wait(Worker, 20000) <> 1 Then Main = 90: Exit Function
        If Outcome <> 0 Then Main = Mode * 100 + Outcome: Exit Function
        If Err.Number <> 77 Then Main = 91: Exit Function
    Next Mode
End Function
