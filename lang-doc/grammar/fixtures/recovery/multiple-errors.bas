UBE SOURCE 1 MODULE
Attribute UBE_Name = "Recovery"
Option Explicit On

Public Sub Main()
    If True ' INTENTIONAL-ERROR: missing Then.
        Stop
    End If

    Select Case 1
        Case ' INTENTIONAL-ERROR: missing case clause.
            Stop
    End Select
End Sub

