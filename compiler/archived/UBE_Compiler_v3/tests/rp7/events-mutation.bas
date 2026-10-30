UBE SOURCE 1 MODULE
Attribute UBE_Name = "RP7EventsMutationMain"

Private WithEvents FirstSource As EventSource
Private WithEvents SecondSource As EventSource
Private WithEvents ThirdSource As EventSource

Private Sub FirstSource_Progress(ByVal Value As Long)
    Print Value
    If Value = 1 Then
        Set SecondSource = Nothing
        Set ThirdSource = FirstSource
    End If
    If Value = 3 Then
        Call FirstSource.Emit(4)
    End If
End Sub

Private Sub SecondSource_Progress(ByVal Value As Long)
    Print Value + 100
End Sub

Private Sub ThirdSource_Progress(ByVal Value As Long)
    Print Value + 200
End Sub

Sub Main()
    Dim Source As New EventSource
    Set FirstSource = Source
    Set SecondSource = Source
    Call Source.Emit(1)
    Call Source.Emit(2)
    Call Source.Emit(3)
End Sub
