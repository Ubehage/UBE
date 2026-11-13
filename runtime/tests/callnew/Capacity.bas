UBE SOURCE 1 MODULE
Attribute UBE_Name = "WorkerCapacity"
' Checks the admitted 64-live-worker bound without changing any runtime limit.
Private Released As Boolean
Private Completed(0 To 63) As Long

' Keeps every admitted worker live until the refusal has been observed.
Private Sub Worker(ByVal Index As Long)
    Do While Not Released
        ThreadPrimitives.Yield
    Loop
    Completed(Index) = Index + 1
End Sub

' Releases and joins all owners even when the expected admission refusal differs.
Public Function Run() As Long
    Dim Ids(0 To 63) As LongLong
    Dim Id As LongLong
    Dim Index As Long
    Dim Count As Long
    On Error GoTo Refused
    Released = False
    Do While Index < 64
        Ids(Index) = CallNew Worker(Index)
        Count = Count + 1
        Index = Index + 1
    Loop
    Id = CallNew Worker(64)
    Run = 1
    GoTo Cleanup
Refused:
    If Err.Number <> 7 Or Count <> 64 Then Run = 2
Cleanup:
    Released = True
    Index = 0
    Do While Index < Count
        If ThreadPrimitives.Wait(Ids(Index), 5000) <> 1 Then Run = 3
        If Completed(Index) <> Index + 1 Then Run = 4
        Index = Index + 1
    Loop
End Function
