UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim maximum As Long = 2147483647
    Dim one As Long = 1
    Dim zero As Long = 0
    Dim overflow As Long = maximum + one
    Dim division As Long = one \ zero
    If overflow = 0 AndAlso division = 0 Then
        Main = 88
    Else
        Main = 99
    End If
End Function
