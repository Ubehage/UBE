UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim minimum As LongLong = -9223372036854775808
    Dim negativeOne As LongLong = -1
    Dim value As LongLong = minimum Mod negativeOne
    If value = 0 Then
        Main = 86
    Else
        Main = 99
    End If
End Function
