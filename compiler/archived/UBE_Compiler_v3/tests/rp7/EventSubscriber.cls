UBE SOURCE 1 CLASS
Attribute UBE_Name = "EventSubscriber"

Private WithEvents Source As EventSource
Private Total As Long
Private HandlerThread As LongLong

Intrinsic Function RuntimeCurrentThreadId() As LongLong
End Function

Public Sub Connect(ByVal Value As EventSource)
    Set Source = Value
End Sub

Private Sub Source_Progress(ByVal Value As Long)
    Total = Total + Value
    HandlerThread = RuntimeCurrentThreadId()
    Print Total
End Sub

Public Function TotalValue() As Long
    TotalValue = Total
End Function

Public Function LastThread() As LongLong
    LastThread = HandlerThread
End Function
