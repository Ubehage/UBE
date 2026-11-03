UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim zero As Long = 0
    Dim result As Long = 42 \ zero
    If result = 0 Then
        Main = 17
    Else
        Main = 99
    End If
End Function
