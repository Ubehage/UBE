UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim outer As Long = 0
    Dim inner As Long = 0
    Dim visits As Long = 0
    While outer < 3
        outer = outer + 1
        inner = 0
        While inner < 5
            inner = inner + 1
            visits = visits + 1
            If inner = 2 Then
                Exit While
            End If
        Wend
        If inner <> 2 Then
            Main = 91
            Exit Function
        End If
    Wend
    If outer = 3 AndAlso visits = 6 Then
        Main = 64
    Else
        Main = 92
    End If
End Function
