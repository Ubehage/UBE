UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Public EvaluationOrder As Long
Public Observed As Long
Public CapturedObserved As Long

Type CapturedValue
    Number As Long
End Type

Intrinsic Function RuntimeThreadWait(ByVal Id As LongLong, ByVal TimeoutMilliseconds As LongLong) As Long
End Function

Intrinsic Sub RuntimeThreadYield()
End Sub

Function NextArgument(ByVal Marker As Long) As Long
    EvaluationOrder = EvaluationOrder * 10 + Marker
    NextArgument = Marker * 10
End Function

Sub Worker(ByVal First As Long, ByVal Second As Long)
    Observed = First + Second
End Sub

Sub SnapshotWorker(ByVal Snapshot As CapturedValue, ByVal Gate As SyncCounter)
    While Gate.Value = 0
        Call RuntimeThreadYield()
    Wend
    CapturedObserved = Snapshot.Number
End Sub

Sub Main()
    Dim Id As LongLong
    Id = CallNew Worker(NextArgument(1), NextArgument(2))
    Print EvaluationOrder
    Print RuntimeThreadWait(Id, 5000)
    Print Observed

    Dim Snapshot As CapturedValue
    Snapshot.Number = 31
    Dim Gate As New SyncCounter
    Id = CallNew SnapshotWorker(Snapshot, Gate)
    Snapshot.Number = 99
    Gate.Value = 1
    Print RuntimeThreadWait(Id, 5000)
    Print CapturedObserved
End Sub
