UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim sourceValue As Long = 4
    Dim doubled As Long = MathOps.DoubleIt(sourceValue)
    If MathOps.hits = 1 Then
        Main = doubled
    Else
        Main = 99
    End If
End Function
