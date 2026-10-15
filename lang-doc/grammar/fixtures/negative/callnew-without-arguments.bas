UBE SOURCE 1 MODULE
Attribute UBE_Name = "BrokenCallNew"
Option Explicit On

Private Sub Worker()
End Sub

Public Sub Main()
    CallNew Worker ' INTENTIONAL-ERROR: CallNew requires ().
End Sub

