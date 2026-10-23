UBE SOURCE 1 MODULE
Attribute UBE_Name = "RP7EventsClassMain"

Sub Main()
    Dim Source As New EventSource
    Dim Listener As New EventSubscriber
    Call Listener.Connect(Source)
    Call Source.Emit(5)
    Call Source.Emit(7)
End Sub
