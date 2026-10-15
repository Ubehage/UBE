UBE SOURCE 1 MODULE
Attribute UBE_Name = "MismatchedTerminator"
Option Explicit On

Public Sub Main()
    If True Then
        Stop
    End Select ' INTENTIONAL-ERROR: expected End If.
End Sub

