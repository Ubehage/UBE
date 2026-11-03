UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim minimum As Integer = -32768
    Dim negativeOne As Integer = -1
    Dim value As Integer = minimum Mod negativeOne
    If value = 0 Then
        Main = 85
    Else
        Main = 99
    End If
End Function
