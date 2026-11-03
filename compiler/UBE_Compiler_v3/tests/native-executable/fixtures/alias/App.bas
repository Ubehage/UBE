UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Sub SetValue(ByRef x As Long)
    x = 9
End Sub
Function Main() As Long
    Dim x As Long = 2
    SetValue x
    If x = 9 Then
        x = 2
        SetValue (x)
        Main = x
    Else
        Main = 99
    End If
End Function
