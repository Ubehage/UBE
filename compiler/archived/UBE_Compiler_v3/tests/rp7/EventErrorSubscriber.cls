UBE SOURCE 1 CLASS
Attribute UBE_Name = "EventErrorSubscriber"

Private WithEvents Source As EventSource

Public Sub Connect(ByVal Value As EventSource)
    Set Source = Value
End Sub

Private Sub Source_Progress(ByVal Value As Long)
    Error Value
End Sub
