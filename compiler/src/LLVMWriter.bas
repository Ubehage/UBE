UBE SOURCE 1 MODULE
Attribute UBE_Name = "LLVMWriter"
' Streams bounded ASCII IR into a caller-owned private staging token, never a published destination.
Public Const MaximumBytes As Long = 16777216
Public Const MaximumLines As Long = 500000
Public Const BufferSize As Long = 65536

Public Type WriterState
    Used As Long
    TotalBytes As Long
    LineCount As Long
    Failed As Boolean
    Failure As Long
    FileFailure As Long
    ErrorNumber As Long
End Type

' Failure codes: 1 runtime, 2 output limit, 3 invalid span/text, 4 file progress/flush.
Private Function Reject(ByRef State As WriterState, ByVal Failure As Long) As Boolean
    State.Failed = True
    State.Failure = Failure
    State.ErrorNumber = Err.Number
End Function

' The scratch buffer and counters are private to one emission request.
Public Function TryInitialize(ByRef State As WriterState, ByRef Buffer() As Byte) As Boolean
    On Error GoTo Failed
    State.Used = 0
    State.TotalBytes = 0
    State.LineCount = 0
    State.Failed = False
    State.Failure = 0
    State.FileFailure = 0
    State.ErrorNumber = 0
    If BufferPrimitives.TryResizeBytes(Buffer, BufferSize, False) = False Then GoTo Failed
    TryInitialize = True
    Exit Function
Failed:
    State.Failed = True
    State.Failure = 1
    State.ErrorNumber = Err.Number
End Function

' Writes only occupied bytes. A failed private stage cannot be resumed or published.
Private Function FlushBuffer(ByRef State As WriterState, ByRef Buffer() As Byte, ByVal Token As Long) As Boolean
    On Error GoTo Failed
    If State.Failed Then Exit Function
    If State.Used = 0 Then FlushBuffer = True: Exit Function
    If FileBytes.TryWriteByteRange(Token, Buffer, 0, State.Used, State.FileFailure) = False Then FlushBuffer = Reject(State, 4): Exit Function
    State.Used = 0
    FlushBuffer = True
    Exit Function
Failed:
    State.Failed = True
    State.Failure = 1
    State.ErrorNumber = Err.Number
End Function

' Validates the entire fragment and output limits before consuming any fragment bytes.
Public Function TryAppendSpan(ByRef State As WriterState, ByRef Buffer() As Byte, ByVal Token As Long, ByRef Text() As Byte, ByVal Start As Long, ByVal Count As Long) As Boolean
    Dim Length As Long
    Dim Index As Long
    Dim Character As Long
    Dim Lines As Long
    Dim Copied As Long
    Dim Take As Long
    Dim Probe As Long
    On Error GoTo Failed
    If State.Failed Then Exit Function
    Length = BufferPrimitives.ByteStorageLength(Text)
    If Start < 0 Or Count < 0 Or Start > Length Then TryAppendSpan = Reject(State, 3): Exit Function
    If Count > Length - Start Then TryAppendSpan = Reject(State, 3): Exit Function
    If State.TotalBytes < 0 Or State.TotalBytes > MaximumBytes Then TryAppendSpan = Reject(State, 3): Exit Function
    If State.LineCount < 0 Or State.LineCount > MaximumLines Then TryAppendSpan = Reject(State, 3): Exit Function
    If State.Used < 0 Or State.Used > BufferSize Then TryAppendSpan = Reject(State, 3): Exit Function
    If BufferPrimitives.ByteStorageLength(Buffer) <> BufferSize Then TryAppendSpan = Reject(State, 3): Exit Function
    Probe = Buffer(0)
    Probe = Buffer(BufferSize - 1)
    If Length > 0 Then
        Probe = Text(0)
        Probe = Text(Length - 1)
    End If
    If Count > MaximumBytes - State.TotalBytes Then TryAppendSpan = Reject(State, 2): Exit Function
    Do While Index < Count
        Character = Text(Start + Index)
        If Character <> 9 And Character <> 10 And Character <> 13 Then
            If Character < 32 Or Character > 126 Then TryAppendSpan = Reject(State, 3): Exit Function
        End If
        If Character = 10 Then Lines = Lines + 1
        Index = Index + 1
    Loop
    If Lines > MaximumLines - State.LineCount Then TryAppendSpan = Reject(State, 2): Exit Function
    Do While Copied < Count
        If State.Used = BufferSize Then
            If FlushBuffer(State, Buffer, Token) = False Then Exit Function
        End If
        Take = Count - Copied
        If Take > BufferSize - State.Used Then Take = BufferSize - State.Used
        If BufferPrimitives.CopyByteRange(Text, Start + Copied, Buffer, State.Used, Take) = False Then GoTo Failed
        State.Used = State.Used + Take
        State.TotalBytes = State.TotalBytes + Take
        Copied = Copied + Take
    Loop
    State.LineCount = State.LineCount + Lines
    TryAppendSpan = True
    Exit Function
Failed:
    State.Failed = True
    State.Failure = 1
    State.ErrorNumber = Err.Number
End Function

' Formats identifiers, source coordinates and exact integer literals without managed Strings.
Public Function TryAppendInteger(ByRef State As WriterState, ByRef Buffer() As Byte, ByVal Token As Long, ByVal Value As LongLong) As Boolean
    Dim Text(0 To 19) As Byte
    Dim Used As Long
    On Error GoTo Failed
    If State.Failed Then Exit Function
    If ByteText.TryAppendInteger(Text, Used, Value) = False Then GoTo Failed
    TryAppendInteger = TryAppendSpan(State, Buffer, Token, Text, 0, Used)
    Exit Function
Failed:
    State.Failed = True
    State.Failure = 1
    State.ErrorNumber = Err.Number
End Function

Public Function TryEndLine(ByRef State As WriterState, ByRef Buffer() As Byte, ByVal Token As Long) As Boolean
    Dim Text(0 To 1) As Byte
    On Error GoTo Failed
    If State.Failed Then Exit Function
    Text(0) = 13
    Text(1) = 10
    TryEndLine = TryAppendSpan(State, Buffer, Token, Text, 0, 2)
    Exit Function
Failed:
    State.Failed = True
    State.Failure = 1
    State.ErrorNumber = Err.Number
End Function

' Completion flushes the stage, but ownership, close and atomic final publication remain with the driver.
Public Function TryFinish(ByRef State As WriterState, ByRef Buffer() As Byte, ByVal Token As Long) As Boolean
    On Error GoTo Failed
    If State.Failed Then Exit Function
    If FlushBuffer(State, Buffer, Token) = False Then Exit Function
    If FilePrimitives.TryFlush(Token, State.FileFailure) = False Then TryFinish = Reject(State, 4): Exit Function
    TryFinish = True
    Exit Function
Failed:
    State.Failed = True
    State.Failure = 1
    State.ErrorNumber = Err.Number
End Function
