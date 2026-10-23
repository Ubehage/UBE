UBE SOURCE 1 FORM
Attribute UBE_Name = "FailingLoadForm"

Public Attempts As Long

Private Sub Form_Load()
    Attempts = Attempts + 1
    If Attempts = 1 Then
        Dim Zero As Long = 0
        Dim Failed As Long = 10 \ Zero
    End If
End Sub
