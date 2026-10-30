UBE SOURCE 1 CLASS
Attribute UBE_Name = "Counter"

Public Value As Long

Private Sub Class_Initialize()
    Value = 1
End Sub

Private Sub Class_Terminate()
    Print 99
    Value = 0
End Sub
