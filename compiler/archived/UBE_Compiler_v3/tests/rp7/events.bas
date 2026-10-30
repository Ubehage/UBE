UBE SOURCE 1 MODULE
Attribute UBE_Name = "RP7EventsMain"

Private WithEvents FirstSource As EventSource
Private WithEvents SecondSource As EventSource

Private Sub FirstSource_Progress(ByVal Value As Long)
    Print Value
End Sub

Private Sub SecondSource_Progress(ByVal Value As Long)
    Print Value + 100
End Sub

Sub Main()
    Dim Source As New EventSource
    Set FirstSource = Source
    Set SecondSource = Source
    Call Source.Emit(1)
    Set FirstSource = Nothing
    Call Source.Emit(2)
End Sub
