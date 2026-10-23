UBE SOURCE 1 FORM
Attribute UBE_Name = "DrainForm"

Private Sub Form_Load()
    Print 10
End Sub

Private Sub Form_Unload(ByRef Cancel As Integer)
    Print 20
End Sub

Public Sub CloseSelf(ByVal Target As DrainForm)
    Print 30
    Unload Target
    Print 40
End Sub
