UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Intrinsic Function RuntimeThreadWait(ByVal Id As LongLong, ByVal TimeoutMilliseconds As LongLong) As Long
End Function

Sub RaiseOnWorker(ByVal Source As EventSource)
    Call Source.Emit(9)
End Sub

Sub Main()
    Dim Source As New EventSource
    Dim Listener As New EventSubscriber
    Call Listener.Connect(Source)
    Dim Worker As LongLong
    Worker = CallNew RaiseOnWorker(Source)
    Print RuntimeThreadWait(Worker, 5000)
    Print Listener.TotalValue()
    Print Listener.LastThread() = Worker
End Sub
