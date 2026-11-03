UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim positive As Long = 17
    Dim negative As Long = -17
    Dim divisor As Long = 5
    Dim negativeDivisor As Long = -5
    If positive \ divisor <> 3 OrElse positive Mod divisor <> 2 Then
        Main = 91
        Exit Function
    End If
    If positive \ negativeDivisor <> -3 OrElse positive Mod negativeDivisor <> 2 Then
        Main = 92
        Exit Function
    End If
    If negative \ divisor <> -3 OrElse negative Mod divisor <> -2 Then
        Main = 93
        Exit Function
    End If
    If negative \ negativeDivisor <> 3 OrElse negative Mod negativeDivisor <> -2 Then
        Main = 94
        Exit Function
    End If
    Main = 69
End Function
