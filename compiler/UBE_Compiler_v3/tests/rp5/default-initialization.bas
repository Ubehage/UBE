UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Sub Main()
    Dim Number As Long
    Dim Message As String
    If Number = 0 Then
        If Message = "" Then
            Print "defaults-ok"
        Else
            Print "string-not-empty"
        End If
    Else
        Print "number-not-zero"
    End If
End Sub
