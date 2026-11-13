UBE SOURCE 1 MODULE
Attribute UBE_Name = "ResourceOwners"
Private Ready As Boolean
Private Stages(0 To 7) As Long
Private Results(0 To 7) As Long
Private Tokens(0 To 255) As Long
Private BusyResult As Long

Private Sub Path(ByRef Bytes() As Byte, ByVal Worker As Long, ByVal Iteration As Long)
    Bytes(0) = 114
    Bytes(1) = 65 + Worker
    Bytes(2) = 65 + Iteration
    Bytes(3) = 46
    Bytes(4) = 98
    Bytes(5) = 105
    Bytes(6) = 110
End Sub

Private Sub Work(ByVal Worker As Long, ByVal Schedule As Long)
    Dim FilePath(0 To 6) As Byte
    Dim Bytes(0 To 3) As Byte
    Dim ReadBytes(0 To 3) As Byte
    Dim Token As Long
    Dim Failure As Long
    Dim Count As Long
    Dim Length As Long
    Dim Iteration As Long
    Dim Other As Long
    Dim Cell As Long
    Dim TokenIndex As Long
    Other = 0
    Do While Other < Worker
        TokenIndex = TokenIndex + 32
        Other = Other + 1
    Loop
    Do While Not Ready
        ThreadPrimitives.Yield
    Loop
    Iteration = 0
    Do While Iteration <= 15
        If Worker = Schedule Or Iteration = Schedule Then ThreadPrimitives.Yield
        Path FilePath, Worker, Iteration
        If Not FilePrimitives.TryCreateNew(FilePath, Token, Failure) Then Results(Worker) = 1: Exit Sub
        If Failure <> 0 Or Token <= 0 Then Results(Worker) = 2: Exit Sub
        Tokens(TokenIndex) = Token
        Stages(Worker) = Iteration + 1
        Other = 0
        Do While Other <= 7
            Do While Stages(Other) < Iteration + 1
                ThreadPrimitives.Yield
            Loop
            Other = Other + 1
        Loop
        Bytes(0) = Worker
        Bytes(1) = Iteration
        Bytes(2) = Schedule
        Bytes(3) = 255
        If Not FilePrimitives.TryWrite(Token, Bytes, 0, 4, Count, Failure) Then Results(Worker) = 3: Exit Sub
        If Count <> 4 Or Failure <> 0 Then Results(Worker) = 4: Exit Sub
        If Not FilePrimitives.TryClose(Token, Failure) Then Results(Worker) = 5: Exit Sub
        If Token <> 0 Or Failure <> 0 Then Results(Worker) = 6: Exit Sub
        If Not FilePrimitives.TryOpen(FilePath, 4, Token, Length, Failure) Then Results(Worker) = 7: Exit Sub
        If Length <> 4 Or Failure <> 0 Or Token <= 0 Then Results(Worker) = 8: Exit Sub
        Tokens(TokenIndex + 1) = Token
        If Not FilePrimitives.TryRead(Token, ReadBytes, 0, 4, Count, Failure) Then Results(Worker) = 9: Exit Sub
        If Count <> 4 Or Failure <> 0 Then Results(Worker) = 10: Exit Sub
        Cell = 0
        Do While Cell <= 3
            If ReadBytes(Cell) <> Bytes(Cell) Then Results(Worker) = 11: Exit Sub
            Cell = Cell + 1
        Loop
        If Not FilePrimitives.TryClose(Token, Failure) Then Results(Worker) = 12: Exit Sub
        If Token <> 0 Or Failure <> 0 Then Results(Worker) = 13: Exit Sub
        If Not FilePrimitives.TryDelete(FilePath, Failure) Then Results(Worker) = 14: Exit Sub
        Iteration = Iteration + 1
        TokenIndex = TokenIndex + 2
    Loop
End Sub

Public Function Exercise(ByVal Schedule As Long) As Long
    Dim Ids(0 To 7) As LongLong
    Dim Worker As Long
    Dim Left As Long
    Dim Right As Long
    Ready = False
    Worker = 0
    Do While Worker <= 7
        Ids(Worker) = CallNew Work(Worker, Schedule)
        Worker = Worker + 1
    Loop
    Ready = True
    Worker = 0
    Do While Worker <= 7
        If ThreadPrimitives.Wait(Ids(Worker), 5000) <> 1 Then Exercise = 20: Exit Function
        If Results(Worker) <> 0 Then Exercise = Results(Worker): Exit Function
        Worker = Worker + 1
    Loop
    Left = 0
    Do While Left <= 255
        If Tokens(Left) <= 0 Then Exercise = 21: Exit Function
        Right = Left + 1
        Do While Right <= 255
            If Tokens(Left) = Tokens(Right) Then Exercise = 22: Exit Function
            Right = Right + 1
        Loop
        Left = Left + 1
    Loop
End Function

Public Function OpenOwner(ByRef Token As Long) As Long
    Dim FilePath(0 To 6) As Byte
    Dim Failure As Long
    Path FilePath, 8, 0
    If Not FilePrimitives.TryCreateNew(FilePath, Token, Failure) Then OpenOwner = 1
End Function

Private Sub Contend(ByVal Token As Long)
    Dim Bytes(0 To 0) As Byte
    Dim Count As Long = 99
    Dim Failure As Long
    Err.Clear
    If FilePrimitives.TryWrite(Token, Bytes, 0, 1, Count, Failure) Then BusyResult = 1: Exit Sub
    If Failure <> 13 Or Err.Number <> 5 Or Count <> 0 Then BusyResult = 2
End Sub

Public Function Busy(ByVal Token As Long) As Long
    Dim Id As LongLong
    Id = CallNew Contend(Token)
    If ThreadPrimitives.Wait(Id, 5000) <> 1 Then Busy = 3: Exit Function
    Busy = BusyResult
End Function

Public Function CloseOwner(ByRef Token As Long) As Long
    Dim FilePath(0 To 6) As Byte
    Dim Failure As Long
    If Not FilePrimitives.TryClose(Token, Failure) Then CloseOwner = 1: Exit Function
    If Token <> 0 Or Failure <> 0 Then CloseOwner = 2: Exit Function
    Path FilePath, 8, 0
    If Not FilePrimitives.TryDelete(FilePath, Failure) Then CloseOwner = 3
End Function

' Keeps one stable test bridge for both independent lowerers.
Public Function Probe(ByVal Mode As Long, ByRef Value As Long) As Long
    If Mode = 0 Then Probe = Exercise(Value): Exit Function
    If Mode = 1 Then Probe = OpenOwner(Value): Exit Function
    If Mode = 2 Then Probe = Busy(Value): Exit Function
    If Mode = 3 Then Probe = CloseOwner(Value): Exit Function
    Probe = 99
End Function
