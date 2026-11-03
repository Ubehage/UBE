UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim low As Long = -2
    Dim high As Long = 3
    If low < high AndAlso low <= high AndAlso high > low AndAlso high >= low AndAlso low <> high AndAlso low = low Then
        Main = 59
    Else
        Main = 99
    End If
End Function
