UBE SOURCE 1 CLASS
Attribute UBE_Name = "WorkerHost"
Option Explicit On

Public Event Completed(ByVal ThreadId As LongLong)
Private WithEvents Worker As WorkerHost
Private Gate As Object

Private Sub Worker_Completed(ByVal ThreadId As LongLong)
    RaiseEvent Completed(ThreadId)
End Sub

Private Sub RunWorker()
    SyncLock Gate
        RaiseEvent Completed(0)
    End SyncLock
End Sub

Public Function Start() As LongLong
    Start = CallNew RunWorker()
End Function

