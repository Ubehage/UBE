UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim maximum As Long = 2147483647
    Dim one As Long = 1
    Dim zero As Long = 0
    Dim division As Long = one \ zero
    Dim overflow As Long = maximum + one
    If division = 0 AndAlso overflow = 0 Then
        Main = 89
    Else
        Main = 99
    End If
End Function
