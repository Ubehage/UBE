UBE SOURCE 1 MODULE
Attribute UBE_Name = "Workload"
Option Explicit
Public Const IterationsPerBatch As Long = 20000

Private Sub Increment(ByVal Target As Counter, ByVal Count As Long, ByVal Seed As Long)
    Dim Index As Long
    On Error GoTo Failed
    For Index = 1 To Count
        SyncLock Target
            Target.Add Index + Seed
        End SyncLock
    Next Index
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

Public Function Run(ByVal Count As Long, ByVal Seed As Long) As LongLong
    Dim Target As Counter
    Dim First As LongLong
    Dim Second As LongLong
    Dim Completed As Long
    On Error GoTo Failed
    If Count = 0 Then Exit Function
    Set Target = New Counter
    First = CallNew Increment(Target, Count, Seed)
    Second = CallNew Increment(Target, Count, Seed)
    Completed = ThreadPrimitives.Wait(First, 20000)
    If Completed <> 1 Then Err.Raise 5
    Completed = ThreadPrimitives.Wait(Second, 20000)
    If Completed <> 1 Then Err.Raise 5
    Run = Target.ReadValue()
    Exit Function
Failed:
    Err.Raise Err.Number
End Function
