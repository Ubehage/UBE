UBE SOURCE 1 FORM
Attribute UBE_Name = "LifecycleForm"

Public RefuseUnload As Integer

Private Sub Form_Load()
    Print 10
End Sub

Private Sub Form_Unload(ByRef Cancel As Integer)
    Print 20
    Cancel = RefuseUnload
End Sub
