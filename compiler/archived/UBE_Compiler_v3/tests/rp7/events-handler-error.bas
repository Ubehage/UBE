UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Sub Main()
    Dim Source As New EventSource
    Dim Listener As New EventErrorSubscriber
    Call Listener.Connect(Source)
    On Error Resume Next
    Call Source.Emit(222)
    Print Err.Number
End Sub
