UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim minimum As Long = -2147483648
    Dim maximum As Long = 2147483647
    Dim one As Long = 1
    Dim negativeOne As Long = -1
    Dim belowMinimum As Long = minimum - one
    Dim aboveMaximum As Long = maximum - negativeOne
    Dim validMinimum As Long = minimum - negativeOne
    Dim validMaximum As Long = maximum - one
    If belowMinimum = 0 AndAlso aboveMaximum = 0 AndAlso validMinimum = -2147483647 AndAlso validMaximum = 2147483646 Then
        Main = 87
    Else
        Main = 99
    End If
End Function
