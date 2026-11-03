UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim wide As Long = 40000
    Dim narrow As Integer = wide
    Dim flag As Boolean = wide
    Dim number As Long = flag
    If narrow = 0 AndAlso number = -1 Then
        Main = 43
    Else
        Main = 99
    End If
End Function
