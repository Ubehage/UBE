UBE SOURCE 1 MODULE
Attribute UBE_Name = "Workers"
' Native ownership cases deliberately release the creator frame before worker access.
Private Ready As Boolean
Private Observed As Long
Private Results(1 To 2) As Long
Private Type Item
    Value As Long
End Type

Private Sub AwaitReady()
    Do While Not Ready
        ThreadPrimitives.Yield
    Loop
End Sub

Private Function ScalarWorker(ByRef Value As Long) As Long
    AwaitReady
    Value = Value + 1
    Observed = Value
    ScalarWorker = 99
End Function

Private Function Relay(ByRef Value As Long) As LongLong
    Relay = CallNew ScalarWorker(Value)
End Function

Private Function Bridge(ByRef Value As Long) As LongLong
    Bridge = Relay(Value)
End Function

Private Function StartScalar() As LongLong
    Dim Value As Long = 40
    StartScalar = Bridge(Value)
End Function

Private Function StartIndexed() As LongLong
    Dim Items(-2 To 1) As Item
    Items(-2).Value = 50
    StartIndexed = CallNew ScalarWorker(Items(-2).Value)
End Function

Private Sub RecordWorker(ByVal Value As Item)
    AwaitReady
    Observed = Value.Value
End Sub

Private Function StartRecord() As LongLong
    Dim Value As Item
    Value.Value = 61
    StartRecord = CallNew RecordWorker(Value)
    Value.Value = 99
End Function

Private Sub ArrayWorker(ByVal Values() As Item)
    AwaitReady
    Observed = Values(-2).Value
End Sub

Private Function StartArray() As LongLong
    Dim Values(-2 To 1) As Item
    Values(-2).Value = 71
    StartArray = CallNew ArrayWorker(Values)
    Values(-2).Value = 99
End Function

Private Sub TemporaryWorker(ByVal Index As Long, ByRef Value As Long)
    AwaitReady
    Results(Index) = Value
End Sub

Private Function CheckTemporaryReuse() As Long
    Dim Index As Long = 1
    Dim Ids(1 To 2) As LongLong
    Ready = False
    Do While Index <= 2
        Ids(Index) = CallNew TemporaryWorker(Index, (Index))
        Index = Index + 1
    Loop
    Ready = True
    If ThreadPrimitives.Wait(Ids(1), -1) <> 1 Then CheckTemporaryReuse = 1: Exit Function
    If ThreadPrimitives.Wait(Ids(2), -1) <> 1 Then CheckTemporaryReuse = 2: Exit Function
    If Results(1) <> 1 Or Results(2) <> 2 Then CheckTemporaryReuse = 3
End Function

Private Function ObserveZeroFailure(ByVal Id As LongLong) As Long
    Dim Status As Long
    On Error GoTo Failed
    Status = ThreadPrimitives.Wait(Id, -1)
    ObserveZeroFailure = 1
    Exit Function
Failed:
    If Err.Number <> 0 Then ObserveZeroFailure = 2
End Function

Public Function Run() As Long
    Dim Id As LongLong
    Ready = False
    Id = StartScalar()
    Ready = True
    If ThreadPrimitives.Wait(Id, -1) <> 1 Or Observed <> 41 Then Run = 1: Exit Function
    Ready = False
    Id = StartIndexed()
    Ready = True
    If ThreadPrimitives.Wait(Id, -1) <> 1 Or Observed <> 51 Then Run = 2: Exit Function
    Ready = False
    Id = StartRecord()
    Ready = True
    If ThreadPrimitives.Wait(Id, -1) <> 1 Or Observed <> 61 Then Run = 3: Exit Function
    Ready = False
    Id = StartArray()
    Ready = True
    If ThreadPrimitives.Wait(Id, -1) <> 1 Or Observed <> 71 Then Run = 4: Exit Function
    If CheckTemporaryReuse() <> 0 Then Run = 5: Exit Function
    Id = CallNew Err.Raise(0)
    If ObserveZeroFailure(Id) <> 0 Then Run = 6: Exit Function
    If ObserveZeroFailure(Id) <> 0 Then Run = 7: Exit Function
    Id = CallNew Err.Clear()
    If ThreadPrimitives.Wait(Id, -1) <> 1 Then Run = 8
End Function
