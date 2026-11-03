UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Private trace As Long
Private Function Mark(ByVal value As Long) As Long
    trace = trace * 10 + value
    Mark = value
End Function
Function Main() As Long
    Dim zero As Long = 0
    Dim result As Long = (Mark(1) \ zero) + Mark(2)
    If result = 2 AndAlso trace = 12 Then
        Main = 68
    Else
        Main = 99
    End If
End Function
