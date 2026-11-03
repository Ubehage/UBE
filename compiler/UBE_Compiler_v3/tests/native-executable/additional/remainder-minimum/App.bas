UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim minimum As Long = -2147483648
    Dim negativeOne As Long = -1
    Dim value As Long = minimum Mod negativeOne
    If value = 0 Then
        Main = 83
    Else
        Main = 99
    End If
End Function
